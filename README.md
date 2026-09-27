# mickey

The 🎤 key (F5) on the MacBook Pro as a hardware-style mic switch.

- Tap: mute / unmute the mic at the OS level. Meet, Zoom and Teams see an open mic sending silence, no "muted" badge.
- Hold: temporarily invert while held (push-to-talk while muted, quick mute while live).
- Compact bezel under the menu bar icon (mic glyph + "Microphone Muted" / "Microphone On"), styled like the macOS 26 volume HUD. Menu bar icon (click toggles). Click sound.

Runs inside Hammerspoon. Karabiner turns the physical F5 into F18.

## Install

```bash
ln -sfn ~/projects/mickey/mickey.lua ~/.hammerspoon/mickey.lua
printf '\nrequire("hs.ipc")\nmickey = require("mickey")\n' >> ~/.hammerspoon/init.lua
```

Karabiner, selected profile, `fn_function_keys`:

```json
{"from": {"key_code": "f5"}, "to": [{"key_code": "f18"}]}
```

Reload Hammerspoon. Move any other app's hotkey (Wispr Flow) off the 🎤 key.

**macOS 26:** System Settings › Menu Bar › "Allow in the Menu Bar" must have
Hammerspoon switched on. When it is off, none of Hammerspoon's menu bar items
ever appear, with no error anywhere. The icon lands wherever macOS puts new
items; ⌘-drag it once next to the sound icon and macOS remembers (the item has
a fixed autosave name).

## Tune

Constants at the top of `mickey.lua`: `HOLD_MS`, `HUD_SECS`, `HUD_FADE`, `SOUND_MUTE`, `SOUND_LIVE`, `SOUND_VOL`, `HUD` geometry.

## Test

`./check.sh` toggles the real mic and asserts the device followed. Hammerspoon must be running.
The `hs` CLI blocks when stdin is a pipe; the script feeds it `/dev/null`.

## Known limits

- No background blur on the bezel (Hammerspoon cannot do vibrancy); it is near-opaque instead.
- Bezel hangs under mickey's own menu bar icon; if the icon is not in the bar it sits near the right edge.
- Devices without a mute flag are muted by setting input volume to 0; an app that auto-adjusts mic gain could raise it again.
- The iPhone Continuity mic has neither, so it cannot be muted; mickey says so.
- Mute does not survive a reboot; the icon always shows the real state.
