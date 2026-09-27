#!/bin/bash
# Smoke test. Needs Hammerspoon running with hs.ipc and mickey loaded.
# Toggles the real mic a few times; you will see HUDs and hear clicks.
out=$(hs -t 10 -c '
local m = mickey
local start = m.muted
assert(m.muted == m.readState(), "state != hardware")
m.set(not start); assert(m.readState() == (not start), "set did not reach device")
m.set(start);     assert(m.readState() == start, "restore failed")
-- tap = toggle
m.onDown(); m.onUp(); assert(m.muted == (not start) and m.readState() == (not start), "tap did not toggle")
m.onDown(); m.onUp(); assert(m.muted == start, "double tap did not return to start")
-- hold = temporary invert
m.onDown(); assert(m.muted == (not start), "hold did not invert on key-down")
hs.timer.usleep(400000)
m.onUp();   assert(m.muted == start and m.readState() == start, "hold did not revert on key-up")
print("mickey check: OK (muted=" .. tostring(start) .. ")")
' 2>&1 < /dev/null)
echo "$out"
echo "$out" | grep -q "mickey check: OK"
