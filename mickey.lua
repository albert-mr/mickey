-- mickey: the 🎤 key as a hardware-style mic switch.
-- tap = toggle mute. hold = temporary invert (push-to-talk while muted).
-- Karabiner turns the physical F5 (🎤) into F18; this file binds F18.

local M = {}

local HOLD_MS    = 250   -- held longer than this = hold, not tap
local HUD_SECS   = 2.0   -- bezel stays this long, then fades
local HUD_FADE   = 0.5
local SOUND_VOL  = 0.3
local SOUND_MUTE = "/System/Library/Sounds/Bottle.aiff"
local SOUND_LIVE = "/System/Library/Sounds/Pop.aiff"
-- bezel: one-row card under the menu bar icon, same material/corners/offset as the
-- macOS 26 volume HUD (16 pt corners on 64 pt; scaled to 44 pt), measured on this Mac
local HUD = { h = 44, radius = 14, gap = 11, pad = 14, icon = 18 }

M.muted = false
local savedVolume   -- for devices with no mute flag
local downAt        -- hs.timer.absoluteTime() at key-down
local bar           -- menu bar item, created below

---------------------------------------------------------------- mute engine
local function dev() return hs.audiodevice.defaultInputDevice() end

-- Push M.muted into a device. Returns true if the device took it.
local function apply(d)
  if not d then return false end
  if d:inputMuted() ~= nil then d:setInputMuted(M.muted); return true end
  local v = d:inputVolume()
  if v == nil then return false end
  if M.muted then
    if v > 0 then savedVolume = v end
    d:setInputVolume(0)
  else
    d:setInputVolume((savedVolume or 0) > 0 and savedVolume or 75)
  end
  return true
end

-- What the hardware says right now. No device counts as muted.
local function stateOf(d)
  if not d then return true end
  local m = d:inputMuted()
  if m ~= nil then return m end
  return (d:inputVolume() or 1) == 0
end
function M.readState() return stateOf(dev()) end

---------------------------------------------------------------- feedback
local sounds = {}
local function click()
  local path = M.muted and SOUND_MUTE or SOUND_LIVE
  local s = sounds[path] or hs.sound.getByFile(path)
  if not s then return end
  sounds[path] = s
  if s:isPlaying() then s:stop() end
  s:volume(SOUND_VOL)
  s:play()
end

-- Mic glyph as canvas elements inside the box {x, y, size}. Slashed when muted.
local function micElements(x, y, s, fg, bg, muted)
  local cx, cy, r, lw = x + s / 2, y + s * 0.42, s * 0.28, s * 0.09
  local u = {}
  for i = 0, 16 do
    local a = math.pi * i / 16
    u[#u + 1] = { x = cx + r * math.cos(a), y = cy + r * math.sin(a) }
  end
  local function line(a, b, color, w)
    return { type = "segments", coordinates = { a, b }, strokeColor = color,
             strokeWidth = w, strokeCapStyle = "round", action = "stroke" }
  end
  local el = {
    { type = "rectangle", fillColor = fg, strokeColor = fg,
      frame = { x = cx - s * 0.14, y = y + s * 0.02, w = s * 0.28, h = s * 0.56 },
      roundedRectRadii = { xRadius = s * 0.14, yRadius = s * 0.14 } },
    { type = "segments", coordinates = u, strokeColor = fg, strokeWidth = lw,
      strokeCapStyle = "round", closed = false, action = "stroke" },
    line({ x = cx, y = cy + r }, { x = cx, y = y + s * 0.86 }, fg, lw),
    line({ x = cx - s * 0.2, y = y + s * 0.9 }, { x = cx + s * 0.2, y = y + s * 0.9 }, fg, lw),
  }
  if muted then
    local a, b = { x = x + s * 0.12, y = y + s * 0.08 }, { x = x + s * 0.88, y = y + s * 0.88 }
    el[#el + 1] = line(a, b, bg, lw * 3)   -- gap around the slash, like SF mic.slash
    el[#el + 1] = line(a, b, fg, lw)
  end
  return el
end

-- Center x of our menu bar icon and the y just under the menu bar of that screen.
local function anchor()
  local f = bar:frame()
  if not f or f.x <= 0 then   -- item not in the bar: see README, "Allow in the Menu Bar"
    local s = hs.screen.mainScreen():frame()
    return s.x + s.w - 120, s.y + HUD.gap
  end
  local cx, scr, best = f.x + f.w / 2, hs.screen.mainScreen(), math.huge
  for _, sc in ipairs(hs.screen.allScreens()) do   -- the screen whose top edge holds the item
    local ff = sc:fullFrame()
    if cx >= ff.x and cx <= ff.x + ff.w and math.abs(ff.y - f.y) < best then scr, best = sc, math.abs(ff.y - f.y) end
  end
  return cx, scr:frame().y + HUD.gap
end

local hud, hudTimer
local function showHUD(label)
  local dark = hs.host.interfaceStyle() == "Dark"
  local fg = dark and { white = 1 } or { white = 0.1 }
  local bg = dark and { white = 0.15, alpha = 0.98 } or { white = 0.95, alpha = 0.98 }   -- ponytail: near-opaque, hs.canvas cannot blur
  local edge = dark and { white = 1, alpha = 0.12 } or { white = 0, alpha = 0.1 }
  local font = { name = ".AppleSystemUIFontDemi", size = 13 }
  local text = label or (M.muted and "Microphone Muted" or "Microphone On")
  local tw = hs.drawing.getTextDrawingSize(hs.styledtext.new(text, { font = font })).w
  local tx = HUD.pad + HUD.icon + 8
  local w = math.ceil(tx + tw + HUD.pad)
  local cx, top = anchor()
  if hudTimer then hudTimer:stop() end
  if hud then hud:delete() end
  hud = hs.canvas.new({ x = cx - w / 2, y = top, w = w, h = HUD.h })
  hud:level(hs.canvas.windowLevels.overlay)
  hud:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
  hud[1] = { type = "rectangle", fillColor = bg, strokeColor = edge, strokeWidth = 1,
             frame = { x = 0.5, y = 0.5, w = w - 1, h = HUD.h - 1 },
             roundedRectRadii = { xRadius = HUD.radius, yRadius = HUD.radius } }
  for _, e in ipairs(micElements(HUD.pad, (HUD.h - HUD.icon) / 2, HUD.icon, fg, bg, M.muted)) do hud[#hud + 1] = e end
  hud[#hud + 1] = { type = "text", text = text, textColor = fg, textSize = 13, textFont = font.name,
                    frame = { x = tx, y = (HUD.h - 18) / 2, w = tw + 4, h = 18 } }
  hud:show()
  hudTimer = hs.timer.doAfter(HUD_SECS, function() hud:hide(HUD_FADE) end)
  M.hud = hud   -- exposed for tests/debug
end

bar = hs.menubar.new(true, "mickey"); M.bar = bar   -- named so macOS remembers where you drag it; exposed for tests/debug
local function barIcon()
  local img = hs.image.imageFromName(M.muted and "mic.slash" or "mic")
  if not img then  -- no SF Symbols in this Hammerspoon: draw it
    local c = hs.canvas.new({ x = 0, y = 0, w = 18, h = 18 })
    for _, e in ipairs(micElements(1, 0, 18, { white = 0 }, { alpha = 0 }, M.muted)) do c[#c + 1] = e end
    img = c:imageFromCanvas(); c:delete()
  end
  img:template(true)
  return img
end
local function refreshBar() bar:setIcon(barIcon(), true) end

---------------------------------------------------------------- state
function M.set(m)
  local d = dev()
  if not d then M.muted = true; refreshBar(); showHUD("No mic"); return end
  M.muted = m
  if not apply(d) then
    M.muted = not m
    hs.alert.show("mickey: cannot mute " .. d:name())
    return
  end
  refreshBar(); showHUD(); click()
end

-- key-down flips immediately (zero delay for push-to-talk);
-- key-up reverts only if it was a hold.
function M.onDown()
  downAt = hs.timer.absoluteTime()
  M.set(not M.muted)
end
function M.onUp()
  if not downAt then return end
  local heldMs = (hs.timer.absoluteTime() - downAt) / 1e6
  downAt = nil
  if heldMs >= HOLD_MS then M.set(not M.muted) end
end

hs.hotkey.bind({}, "f18", M.onDown, M.onUp)   -- no repeatfn: key repeats are ignored
bar:setClickCallback(function() M.set(not M.muted) end)

-- default input changed (AirPods, USB mic): keep the new device in the same state,
-- touching it only when it disagrees (a live mic keeps its own gain). `false` = no device.
function M.onDeviceChange(d)
  if d == nil then d = dev() end
  if not d then M.muted = true; refreshBar(); return end
  if stateOf(d) ~= M.muted and not apply(d) then hs.alert.show("mickey: cannot mute " .. d:name()) end
  refreshBar()
end

M.muted = M.readState()   -- trust the hardware, not a default
refreshBar()
hs.audiodevice.watcher.setCallback(function(event) if event == "dIn " then M.onDeviceChange() end end)
hs.audiodevice.watcher.start()
return M
