-- mickey: the 🎤 key as a hardware-style mic switch.
-- tap = toggle mute. hold = temporary invert (push-to-talk while muted).
-- Karabiner turns the physical F5 (🎤) into F18; this file binds F18.

local M = {}

local HOLD_MS    = 250   -- held longer than this = hold, not tap
local HUD_SECS   = 1.5   -- bezel stays this long, then fades
local HUD_FADE   = 0.3
local SOUND_VOL  = 0.3
local SOUND_MUTE = "/System/Library/Sounds/Bottle.aiff"
local SOUND_LIVE = "/System/Library/Sounds/Pop.aiff"
-- bezel geometry, matched against the native volume HUD (Task 3)
local HUD = { w = 200, h = 40, radius = 20, right = 10, top = 8 }

M.muted = false
local savedVolume   -- for devices with no mute flag
local downAt        -- hs.timer.absoluteTime() at key-down

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
function M.readState()
  local d = dev(); if not d then return true end
  local m = d:inputMuted()
  if m ~= nil then return m end
  return (d:inputVolume() or 1) == 0
end

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

-- Replaced by the canvas bezel in Task 3.
local function showHUD(label)
  hs.alert.show(label or (M.muted and "Mic muted" or "Mic live"), 1)
end

local bar = hs.menubar.new(); M.bar = bar   -- exposed for tests/debug
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

-- default input changed (AirPods, USB mic): keep the new device in the same state
hs.audiodevice.watcher.setCallback(function(event)
  if event ~= "dIn " then return end
  local d = dev()
  if not apply(d) and d then hs.alert.show("mickey: cannot mute " .. d:name()) end
  refreshBar()
end)
hs.audiodevice.watcher.start()

M.muted = M.readState()   -- trust the hardware, not a default
refreshBar()
return M
