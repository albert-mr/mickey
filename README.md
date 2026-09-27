# mickey

Turn the 🎤 key (F5) on your MacBook into a real microphone switch.

- **Tap**: mute or unmute the mic at the operating-system level. Google Meet, Zoom and Teams see an open mic that sends silence, so no "muted" badge, no "are you talking?" nag.
- **Hold**: temporarily invert while the key is down. Push-to-talk while muted, quick mute while live.
- **Native feel**: a menu bar icon next to the sound icon (click toggles it), a compact bezel under it in the style of the macOS 26 volume HUD, and a click sound.
- **Always on**: it runs inside Hammerspoon, which starts at login. No app window, no dock icon.

<p align="center">
  <img src="docs/bezel.png" width="400" alt="menu bar with a slashed mic icon and, under it, a dark card reading Microphone Muted">
</p>

## Why not just mute in Meet?

Meet's own mute is a request to the app. mickey cuts the device: the mic is muted in CoreAudio, so every app gets silence at once, and switching tabs or apps changes nothing. It is the software equivalent of a hardware mute switch.

## Requirements

- A Mac whose F5 key carries the microphone symbol (MacBook Pro and MacBook Air from 2021 on; on older keyboards F5 is keyboard brightness).
- macOS 14 or later. Tested on macOS 26.
- [Hammerspoon](https://www.hammerspoon.org) — runs the Lua module. `brew install --cask hammerspoon`
- [Karabiner-Elements](https://karabiner-elements.pqrs.org) — turns the physical 🎤 key into F18, which Hammerspoon can bind. `brew install --cask karabiner-elements`

Both are free and open source. Give each the permissions it asks for on first launch (Accessibility for Hammerspoon, Input Monitoring and its driver for Karabiner), and enable "Launch at login" in both.

## Install

1. Clone anywhere and link the module into Hammerspoon:

   ```bash
   git clone https://github.com/albert-mr/mickey.git
   cd mickey
   ln -sfn "$(pwd)/mickey.lua" ~/.hammerspoon/mickey.lua
   printf '\nrequire("hs.ipc")\nmickey = require("mickey")\n' >> ~/.hammerspoon/init.lua
   ```

2. Map the 🎤 key to F18 in Karabiner-Elements. Either in the app: **Settings → Function Keys → f5 → f18**, or add this entry to `fn_function_keys` of your selected profile in `~/.config/karabiner/karabiner.json` (Karabiner reloads the file on its own):

   ```json
   {"from": {"key_code": "f5"}, "to": [{"key_code": "f18"}]}
   ```

   `fn+F5` stays a normal F5.

3. Reload Hammerspoon (menu bar icon → Reload Config, or `hs -c 'hs.reload()'`). Tap 🎤. You should hear a click and see the bezel.

4. If another app owns the 🎤 key (Wispr Flow, dictation tools), move its hotkey elsewhere in that app's settings.

5. The menu bar icon appears wherever macOS puts new items. ⌘-drag it once next to the sound icon; macOS remembers, because the item has a fixed autosave name.

### macOS 26 and later: "Allow in the Menu Bar"

If no icon appears at all, open **System Settings → Menu Bar → Allow in the Menu Bar** and make sure **Hammerspoon** is switched on. When it is off, macOS silently blocks every menu bar item Hammerspoon creates, with no error anywhere.

## Tune

Constants at the top of `mickey.lua`:

| Constant | Default | Meaning |
|---|---|---|
| `HOLD_MS` | 250 | held longer than this counts as a hold, not a tap |
| `HUD_SECS`, `HUD_FADE` | 2.0, 0.5 | how long the bezel stays, fade time |
| `SOUND_MUTE`, `SOUND_LIVE`, `SOUND_VOL` | Bottle, Pop, 0.3 | click sounds from `/System/Library/Sounds`, volume |
| `HUD` | 44 pt card, 14 pt corners, 11 pt gap | bezel geometry |

## Test

```bash
./check.sh
```

Toggles the real mic a few times, drives the tap and hold paths, feeds the device-change handler a fake device, and asserts the hardware followed. It always puts the mic back in its starting state. Hammerspoon must be running.

## How it works

`mickey.lua` is about 190 lines of Lua:

- `hs.hotkey.bind({}, "f18", onDown, onUp)`. Key-down flips the mic immediately, so a hold has no delay. Key-up reverts only if the key was held longer than `HOLD_MS`.
- `hs.audiodevice` mutes the default input device with its mute flag, or sets input volume to 0 for devices without one and restores the previous level on unmute.
- A watcher re-applies the state when the default input changes (AirPods connect), touching the new device only when it disagrees.
- `hs.menubar` for the icon, `hs.canvas` for the bezel, `hs.sound` for the click. The mic glyph is drawn with canvas primitives because Hammerspoon cannot load SF Symbols.
- On load it reads the real hardware state instead of assuming.

## Known limits

- No background blur on the bezel (Hammerspoon cannot do vibrancy); it is near-opaque instead.
- Devices without a mute flag are muted by setting input volume to 0; an app that auto-adjusts mic gain could raise it again.
- The iPhone Continuity microphone exposes neither a mute flag nor volume, so it cannot be muted; mickey says so.
- Mute does not survive a reboot; the icon always shows the real state.

## License

MIT. See [LICENSE](LICENSE).
