-- mickey: the 🎤 key as a hardware-style mic switch.
-- tap = toggle mute. hold = temporary invert (push-to-talk while muted).
-- Karabiner turns the physical F5 (🎤) into F18; this file binds F18.

local M = {}

local HOLD_MS    = 250   -- held longer than this = hold, not tap
local HUD_SECS   = 2.0   -- bezel stays this long, then folds back into the icon
local SOUND_VOL  = 0.3
local SOUND_MUTE = "/System/Library/Sounds/Bottle.aiff"
local SOUND_LIVE = "/System/Library/Sounds/Pop.aiff"
-- bezel: one-row card under the menu bar icon, same material/corners/offset as the
-- macOS 26 volume HUD (16 pt corners on 64 pt; scaled to 44 pt), measured from a screenshot
local HUD = { h = 44, radius = 14, gap = 11, pad = 14, icon = 18 }
-- motion: springs, written as SwiftUI's .spring(response:dampingFraction:). Tune by eye.
local POP       = { 0.35, 0.72 }   -- bezel grows out of the menu bar icon: quick, lands with a small overshoot
local MORPH     = { 0.45, 0.80 }   -- slash, label and width change state: a beat behind the pop, so the change is seen
local FOLD      = { 0.30, 1.00 }   -- bezel folds back into the icon: quicker, no bounce
local POP_SCALE = 0.6              -- the bezel's size where it leaves and rejoins the icon
local SLIDE     = 6                -- pt the changing word travels as it swaps

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
-- One word for the CLI: muted | live | no-mic
function M.status()
  local d = dev()
  return not d and "no-mic" or stateOf(d) and "muted" or "live"
end

---------------------------------------------------------------- feedback
local sounds = { [true] = hs.sound.getByFile(SOUND_MUTE), [false] = hs.sound.getByFile(SOUND_LIVE) }   -- loaded now, not on the first press
local function click()
  local s = sounds[M.muted]
  if not s then return end
  if s:isPlaying() then s:stop() end
  s:volume(SOUND_VOL)
  s:play()
end

---------------------------------------------------------------- icon
-- Apple's own SF Symbols (mic.fill / mic.slash.fill) at the size and weight of the mic in the system recording indicator, 14 pt medium.
-- Hammerspoon cannot load SF Symbols, so icons.swift renders them once and they live here as PNG@2x.
local ICON = {
  live = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAiCAYAAABIiGl0AAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAAB6gAwAEAAAAAQAAACIAAAAAxLqLhAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAjRJREFUWAntlk9IVFEUxieRUMRIK0yJNiZtgmoR1CJCiCDIhUEuA1cRJIEQgQsXLUJatGlVi9C127ZtFP9QGyFoFQUSVBYUEVqk5u+re4Yzr+ubO1OPFs2Bb+6553znfO/d9+6dVyo1LH8FuknfAy/AR7AEboIWUJgdpvNb8COCeWKtoBBbpGtM1GITRagerSIq8Q+gKVU8lXgsoeEeOAcSeD8pqcK7Ehum8tKXJlE4mZZ6x8kNU4kNYa1UF+gHOzT5A2uj9hxIPlh0HGpfXgdmIzh2UOSNR6yAcTrUTLlY2Y09496QPVRm1edYvfWr6BITriAUNckT9rnviRfgeVavR/ObWdInVsNER6DZa3Nyxk1yb1ze6tdcrOzGhJdDtq/MKpVm8L+4ecydJfg5JNoZtTtk1u/XLOf3Pjktj+5gv+PdCPHYW60lPuW4Fx33sovnugOu6E6GOcZcS+fFtbwXMry5wNEF7cvktp1q+Z8BNf8KTgJve5lcAlfAeZD97LlGzC7sAX5Ndhb2BlCDFXAGpNhVSLpL1enDoAfUbKNU2JWv4z8Ex0H2KN1JTEfjY2D8b/inQd02TGX2mb4n9hRISF+ZettNUKO2nn/RmNZnOvomgS2hF/H+Jzi3QAf4q7abboPgNtB+lehzMA76gZa8cHuFgoQn61XS1vkn1lxFdYh8dh+rpDPUnWC8G3wbtA31X/zEArWOBynwL08t/stqYnlL/Y7ihWoNInnd8aNI/D8PbQH465v/Gx1I+AAAAABJRU5ErkJggg==",   -- mic.fill 15x17 pt
  muted = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAYAAACe0YppAAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAAB6gAwAEAAAAAQAAACQAAAAAS/p+JAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAptJREFUWAntls2LzlEUx2cYCaUkxutGyc7LsJnSiEQpiZSdjbz8AzY2Q2JpLGYxJWnK2LFhpfSwUESEhTwWNih5nbIhb59vzuG47szvPi+ze059n3Puueec7+/ce3/393R1daSzAv+uwCyGx8Aj8BE8B2dBL5gymUPle+BnBq/wrQBNS41MFV+SqTCEL0fqvpuZnCLXdKLeAhV6BiJ5D+Nxm3OinF5FTFOygSztXUq+2Hw5sujb1xSrJeXIu5m7VEB+sBVi5ebItRVjIHaY2i0TN0veFmKRrwcfgDqrAx24yTpvGzE8DZG3RDwbsm1A2qW080g8jeQtYKEXqdJ+eqWj9DGoWvZIfJR4bdHTWGQy+64lSLv4ZZKSLyUg7nkkHmFOxF+9SNRajhIR8SB4ALYCXTIrQQ0sAvvBGGhJvOP7ocoabD29yCXrwHsgXx145wPYLucwNJ/t2IOirlnCi+Ccbz4VOm7+HLluOJcrGIr/5I4qPWoJX9DxZN8x/0Tk+jarc5cnGIp97I4qfcASlLQzBG/C/hbmTthc7DySX7TYYYurVPoSfbekW0n0bsZvbE4P5uRrsX3PnVynXeTbQbFcIFKFhSNJlpZ/BzgM9gLfDpG/A8pxcr013aBYlhPpl4VO5aHCzBx5YerfsM2YIvXOr2PrHZ4BoqgjXal7zKlXL+3cpsrVRkJfAyeX/gweghtA/8+cRHMngSQlX/bb3div3uFTYBzEB0htrc55MA9I2kKuQjOBvjaDQH8GRazL4TTYBeaCVCJ5vAnTuOKxvlwirhdkrCbmJbgWY3viYIps3Vz/7XEVcT9JOq26DKL02WAB+kycMPs2+nLGX+zSEqWHqGT8gzzdgBNK1ff4Kpkq0qioY71mHfmzAr8ATboKU/6C84IAAAAASUVORK5CYII=",   -- mic.slash.fill 15x18 pt
}
local LIVE, MUTED = hs.image.imageFromURL(ICON.live), hs.image.imageFromURL(ICON.muted)
local SIZE  = LIVE:size()
local STEPS = SIZE.w   -- the slash is drawn on in 1 pt steps

-- Frame i of the slash being drawn on, the way SF Symbols swaps a symbol with its .slash twin: the slashed symbol
-- left of x = i, the plain one right of it. hs.canvas clips an image to its frame and skips an empty frame, and the
-- two symbols share a bottom edge, so two frames that meet at x = i are the whole wipe.
-- tint: a colour for the bezel; nil = a template for the menu bar. Baked off screen once per frame and colour.
local baked = {}
local function glyph(i, tint)
  local key = i .. (tint and tint.white or "bar")
  if not baked[key] then
    local scr = hs.screen.primaryScreen()   -- where an unshown canvas renders; k keeps 2 px per pt on a 1x screen too
    local k = 2 / (scr and scr:currentMode().scale or 2)
    local c = hs.canvas.new({ x = 0, y = 0, w = SIZE.w * k, h = SIZE.h * k })
    c:transformation({ m11 = k, m12 = 0, m21 = 0, m22 = k, tX = 0, tY = 0 })
    c[1] = { type = "image", image = MUTED, imageScaling = "none", imageAlignment = "bottomLeft",
             frame = { x = 0, y = 0, w = i, h = SIZE.h } }
    c[2] = { type = "image", image = LIVE, imageScaling = "none", imageAlignment = "bottomRight",
             frame = { x = i, y = 0, w = SIZE.w - i, h = SIZE.h } }
    if tint then c[3] = { type = "rectangle", action = "fill", fillColor = tint, compositeRule = "sourceIn" } end
    baked[key] = c:imageFromCanvas():size(SIZE):template(not tint)
    c:delete()
  end
  return baked[key]
end
bar = hs.menubar.new(true, "mickey"); M.bar = bar   -- named so macOS remembers where you drag it; exposed for tests/debug
function M.icon(muted) return glyph(muted and STEPS or 0) end
local FG = { [true] = { white = 1 }, [false] = { white = 0.1 } }   -- the bezel's ink, by dark mode
for i = 0, STEPS do glyph(i); glyph(i, FG[true]); glyph(i, FG[false]) end   -- bake every frame now, not during the first press

---------------------------------------------------------------- motion
-- Two springs drive everything that moves. P: the bezel's presence, 0 hidden .. 1 shown. S: the state, 0 live .. 1 muted.
-- Springs, not timed curves: a press in mid-flight retargets from where things are, at the speed they have.
local P = { x = 0, v = 0, to = 0, k = 0, c = 0 }
local S = { x = 0, v = 0, to = 0, k = 0, c = 0 }
M.motion = { P = P, S = S }   -- exposed for tests/debug
local function aim(sp, to, spring)
  local w = 2 * math.pi / spring[1]
  sp.to, sp.k, sp.c = to, w * w, 2 * spring[2] * w
end
-- System Settings › Accessibility › Display › Reduce Motion: the bezel only fades, icon and label swap at once
local function calm() return hs.screen.accessibilitySettings().ReduceMotion end

local render   -- draws one frame from P and S; defined with the bezel
local ticker, last
local function step()
  local now = hs.timer.absoluteTime()
  local dt = math.min((now - last) / 1e9, 1 / 30) / 4   -- 4 substeps; a stalled frame slows the motion, it does not jump
  last = now
  local moving = false
  for _, sp in ipairs({ P, S }) do
    for _ = 1, 4 do
      sp.v = sp.v + (sp.k * (sp.to - sp.x) - sp.c * sp.v) * dt
      sp.x = sp.x + sp.v * dt
    end
    if math.abs(sp.to - sp.x) < 0.001 and math.abs(sp.v) < 0.01 then sp.x, sp.v = sp.to, 0 else moving = true end
  end
  if not moving then ticker:stop() end
  render()
end
local function animate()
  ticker = ticker or hs.timer.new(1 / 120, step)
  last = hs.timer.absoluteTime()   -- the clock starts here: time spent setting up is not time the springs moved
  if not ticker:running() then ticker:start() end
end

---------------------------------------------------------------- bezel
-- Where the bezel goes: on the screen with the focused window (where you are looking,
-- also in fullscreen, where the menu bar is hidden), at our icon's distance from the
-- right edge, so it hangs under the icon whenever the menu bar is visible.
local function anchor()
  local scr = hs.screen.mainScreen()
  local sf, f, fromRight = scr:frame(), bar:frame(), 120
  if f and f.x > 0 then   -- otherwise the item is not in the bar: README, "Allow in the Menu Bar"
    local best = math.huge
    for _, s in ipairs(hs.screen.allScreens()) do   -- the icon's own screen: contains f.x, nearest top edge
      local ff = s:fullFrame()
      if f.x >= ff.x and f.x <= ff.x + ff.w and math.abs(ff.y - f.y) < best then
        best, fromRight = math.abs(ff.y - f.y), ff.x + ff.w - (f.x + f.w / 2)
      end
    end
  end
  return sf.x + sf.w - fromRight, sf.y + HUD.gap
end

local MARGIN = 12   -- canvas room around the card: the pop starts higher up and overshoots a little
local hud, hudTimer, lay   -- lay: the layout render() works from, set by showHUD
local barStep

function render()
  local s = math.max(0, math.min(1, S.x))
  local i = math.floor(s * STEPS + 0.5)
  if i ~= barStep then barStep = i; bar:setIcon(glyph(i), true) end
  if not hud then return end
  if P.x == 0 and P.to == 0 then hud:delete(); hud, M.hud = nil, nil; return end   -- folded away
  -- grow out of the icon: scale about its centre, which sits above the card
  local k = lay.calm and 1 or POP_SCALE + (1 - POP_SCALE) * P.x
  hud:transformation({ m11 = k, m12 = 0, m21 = 0, m22 = k, tX = lay.cw / 2 * (1 - k), tY = (MARGIN - HUD.gap - 12) * (1 - k) })
  hud:alpha(math.max(0, math.min(1, P.x * 2)))
  local w = lay.live + (lay.muted - lay.live) * S.x   -- not clamped: the width keeps the spring's overshoot
  local x = (lay.cw - w) / 2
  hud[1].frame = { x = x + 0.5, y = MARGIN + 0.5, w = w - 1, h = HUD.h - 1 }
  hud[2].frame = { x = x + HUD.pad + (HUD.icon - SIZE.w) / 2, y = MARGIN + (HUD.h - SIZE.h) / 2, w = SIZE.w, h = SIZE.h }
  if i ~= lay.step then lay.step = i; hud[2].image = glyph(i, lay.fg) end
  local tx, ty = x + HUD.pad + HUD.icon + 8, MARGIN + (HUD.h - 18) / 2
  hud[3].frame = { x = tx, y = ty, w = lay.head + 4, h = 18 }
  -- only the word that changes moves: "On" drops out while "Muted" drops in, and back
  hud[4].frame = { x = tx + lay.head, y = ty + SLIDE * s, w = lay.on + 4, h = 18 }
  hud[4].textColor = { white = lay.fg.white, alpha = math.max(0, 1 - 2 * s) }
  hud[5].frame = { x = tx + lay.head, y = ty - SLIDE * (1 - s), w = lay.tail + 4, h = 18 }
  hud[5].textColor = { white = lay.fg.white, alpha = math.max(0, 2 * s - 1) }
end

-- Real Liquid Glass: the mickey-bezel helper (bezel.swift), when it has been built next to this file.
-- It lives as long as Hammerspoon does and takes one line per press on stdin. Without it, the bezel below is drawn here.
local helper = hs.fs.pathToAbsolute(debug.getinfo(1, "S").source:sub(2)):gsub("[^/]*$", "mickey-bezel")
local glass = hs.fs.attributes(helper) and hs.task.new(helper, nil, function() return true end)
if glass then glass:start() end
M.glass = glass   -- exposed for tests/debug

local function showHUD(label)
  if glass and glass:isRunning() then
    local cx, top = anchor()
    glass:setInput(table.concat({ "show", cx, top, M.muted and 1 or 0, HUD_SECS,
                                  label or (M.muted and "Mic Muted" or "Mic On") }, "\t") .. "\n")
    return
  end
  local head, on, tail = "Mic ", "On", "Muted"
  if label then head, on, tail = label, "", "" end   -- a plain label ("No Microphone"): no word to swap
  local dark = hs.host.interfaceStyle() == "Dark"
  local fg = FG[dark]
  local bg = dark and { white = 0.15, alpha = 0.98 } or { white = 0.95, alpha = 0.98 }   -- ponytail: near-opaque, hs.canvas cannot blur
  local edge = dark and { white = 1, alpha = 0.12 } or { white = 0, alpha = 0.1 }
  local font = { name = ".AppleSystemUIFontDemi", size = 13 }
  local function tw(t) return hs.drawing.getTextDrawingSize(hs.styledtext.new(t, { font = font })).w end
  -- card width for a label; even, so the centred card sits on whole pixels at rest
  local function cardW(t) return 2 * math.ceil((HUD.pad + HUD.icon + 8 + tw(head .. t) + HUD.pad) / 2) end
  local live, muted = cardW(on), cardW(tail)
  local cw = math.max(live, muted) + 2 * MARGIN
  local cx, top = anchor()
  local x0 = math.floor(cx - cw / 2 + 0.5)
  if hud and (x0 ~= lay.x0 or top ~= lay.top or dark ~= lay.dark) then hud:delete(); hud = nil end   -- other screen, size or appearance
  if not hud then   -- a press while the bezel is up morphs it in place instead
    P.x, P.v = 0, 0
    hud = hs.canvas.new({ x = x0, y = top - MARGIN, w = cw, h = HUD.h + 2 * MARGIN })
    hud:level(hs.canvas.windowLevels.overlay)
    hud:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
    hud[1] = { type = "rectangle", fillColor = bg, strokeColor = edge, strokeWidth = 1,
               roundedRectRadii = { xRadius = HUD.radius, yRadius = HUD.radius } }
    hud[2] = { type = "image", imageAlpha = 1 }   -- 1: hs.canvas draws a template image at half strength otherwise
    for n = 3, 5 do hud[n] = { type = "text", textColor = fg, textSize = font.size, textFont = font.name } end
    M.hud = hud   -- exposed for tests/debug
  end
  hud[3].text, hud[4].text, hud[5].text = head, on, tail
  lay = { x0 = x0, top = top, dark = dark, fg = fg, cw = cw, live = live, muted = muted,
          head = tw(head), on = tw(on), tail = tw(tail), calm = calm() }
  if hudTimer then hudTimer:stop() end
  aim(P, 1, lay.calm and FOLD or POP)
  render(); hud:show(); animate()
  hudTimer = hs.timer.doAfter(HUD_SECS, function() aim(P, 0, FOLD); animate() end)
end

---------------------------------------------------------------- state
local function refreshBar()
  aim(S, M.muted and 1 or 0, MORPH)
  if calm() then S.x, S.v = S.to, 0 end
  animate()
end

function M.set(m)
  local d = dev()
  if not d then M.muted = true; refreshBar(); showHUD("No Microphone"); return end
  M.muted = m
  if not apply(d) then
    M.muted = not m
    hs.alert.show("mickey: cannot mute " .. d:name())
    return
  end
  click(); refreshBar(); showHUD()   -- sound first: hs.sound blocks ~20 ms, better before the motion starts than inside it
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
S.x = M.muted and 1 or 0; refreshBar()   -- the icon starts in place: nothing animates at load
hs.audiodevice.watcher.setCallback(function(event) if event == "dIn " then M.onDeviceChange() end end)
hs.audiodevice.watcher.start()
return M
