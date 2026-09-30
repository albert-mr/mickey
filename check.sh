#!/bin/bash
# Smoke test. Needs Hammerspoon running with hs.ipc and mickey loaded.
# Toggles the real mic a few times; you will see HUDs and hear clicks.
# Always puts the mic back in its starting state, even when an assert fails.
out=$(hs -t 10 -c '
local m = mickey
local start = m.muted
local ok, err = pcall(function()
  assert(m.muted == m.readState(), "state != hardware")
  m.set(not start); assert(m.readState() == (not start), "set did not reach device")
  m.set(start);     assert(m.readState() == start, "restore failed")
  -- tap = toggle
  m.onDown(); m.onUp(); assert(m.muted == (not start) and m.readState() == (not start), "tap did not toggle")
  m.onDown(); m.onUp(); assert(m.muted == start and m.readState() == start, "double tap did not return to start")
  -- hold = temporary invert
  m.onDown(); assert(m.muted == (not start), "hold did not invert on key-down")
  hs.timer.usleep(400000)
  m.onUp();   assert(m.muted == start and m.readState() == start, "hold did not revert on key-up")
  -- default input changed: touch the new device only when it disagrees with the desired state
  local calls = {}
  local fake = { name = function() return "Fake" end, inputMuted = function() return nil end,
                 inputVolume = function() return 40 end, setInputVolume = function(_, v) calls[#calls + 1] = v end }
  m.set(false); m.onDeviceChange(fake); assert(#calls == 0, "live: touched a live device (" .. tostring(calls[1]) .. ")")
  m.set(true);  m.onDeviceChange(fake); assert(calls[1] == 0, "muted: did not mute the new device")
  m.set(false); m.onDeviceChange(false); assert(m.muted == true, "no device should count as muted")
end)
if m.muted ~= start then m.set(start) end
if not ok then error(err, 0) end
print("mickey check: OK (muted=" .. tostring(start) .. ")")
' 2>&1 < /dev/null)
echo "$out"
echo "$out" | grep -q "mickey check: OK" || exit 1

# CLI: the same module through the `mickey` script. Restores the start state on failure.
cli="$(dirname "$0")/mickey"
start=$("$cli" status) || exit 1
restore() { if [ "$start" = muted ]; then "$cli" mute >/dev/null; else "$cli" unmute >/dev/null; fi; }
fail() { echo "mickey cli: FAIL: $1"; restore; exit 1; }
[ "$("$cli" mute)"   = muted ] || fail "mute did not print muted"
[ "$("$cli" unmute)" = live ]  || fail "unmute did not print live"
[ "$("$cli" toggle)" = muted ] || fail "toggle did not print muted"
[ "$("$cli" status)" = "$(hs -c 'return mickey.readState() and "muted" or "live"' < /dev/null)" ] || fail "status disagrees with readState"
[ "$("$cli" up)"     = muted ] || fail "up did not print the state"
restore
[ "$("$cli" status)" = "$start" ] || fail "restore failed"
echo "mickey cli: OK"
