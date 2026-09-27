# mickey — hardware-style mic mute on the 🎤 key

Date: 2026-09-27. Status: approved design, pre-implementation.

## Goal

Make the 🎤 key (F5) on the MacBook Pro a physical-style microphone switch.
Press: the mic is muted at the OS level. Press again: live. Meeting apps
(Meet, Zoom, Teams) see an open mic sending silence and show no "muted"
badge. Feedback looks native: a bezel like the volume HUD on each press, and
a menu bar icon that shows state and toggles on click. Runs at every boot
with no window and no dock icon.

## Non-goals (deferred)

- Push-to-talk / hold mode.
- Click sound on toggle.
- Persisting mute state across reboot.
- Background blur on the HUD (Hammerspoon cannot do vibrancy). If it matters
  later, that is the trigger to rewrite as a native Swift app.

## Machine facts that drive the design

- MacBook Pro Mac16,7 (M4), macOS 26.6.2.
- The 🎤 key sends a "dictation" HID consumer code, not a key code. Normal
  hotkey APIs and Hammerspoon never see it. Karabiner-Elements 16.3 does.
- Karabiner is installed, running, in the login chain, and already remaps
  F4 and F6 via `fn_function_keys` in `~/.config/karabiner/karabiner.json`.
- Hammerspoon 1.1.1 is installed, in login items, and runs the user's window
  manager from `~/.hammerspoon/init.lua`. The `hs` CLI exists at
  `/opt/homebrew/bin/hs` but `hs.ipc` is not loaded yet.
- toggleMute.app 1.5 (brew cask) currently does OS-level mute on ⌘⇧M and is
  a login item. It proves the approach works with Meet. It gets replaced.
- Wispr Flow currently claims the 🎤 key.

## Architecture

Two already-running programs, one new file.

```
🎤 key ──Karabiner──▶ F18 ──Hammerspoon──▶ mickey.lua
                                            ├─ CoreAudio: mute default input
                                            ├─ HUD bezel (hs.canvas)
                                            └─ menu bar icon (hs.menubar)
```

### 1. Key path

- `karabiner.json`, profile "Default profile", `fn_function_keys`: add
  `{"from":{"key_code":"f5"},"to":[{"key_code":"f18"}]}` beside the existing
  f4/f6 entries. 🎤 becomes F18 system-wide. `fn+F5` stays a real F5.
- `mickey.lua`: `hs.hotkey.bind({}, "f18", toggle)`.
- Manual step (user): move Wispr Flow's hotkey off the 🎤 key in its
  settings.

### 2. Mute engine (`mickey.lua`)

- State: one boolean `muted`, the desired state.
- `apply(dev)`: if `dev:inputMuted() ~= nil` the device supports a mute
  flag, so `dev:setInputMuted(muted)`. Otherwise fall back to volume: on
  mute remember `dev:inputVolume()` and set 0; on unmute restore it (default
  to 75 if the remembered value is 0 or nil).
- `toggle()`: flip `muted`, `apply(defaultInputDevice)`, refresh HUD and
  icon.
- Device watcher: `hs.audiodevice.watcher` on the default-input-changed
  event (`dIn `) re-applies `muted` to the new device. Switching to AirPods
  cannot silently unmute you.
- On load: `muted = dev:inputMuted() or (dev:inputVolume() == 0)`. Read the
  hardware, do not assume.

### 3. Feedback

- HUD: an `hs.canvas` bezel showing a mic icon (live) or mic-slash icon
  (muted). Geometry, position, corner radius, translucency and fade timing
  copy the native volume HUD of macOS 26 on this machine. Verified during
  implementation by triggering a volume key from Hammerspoon and comparing
  screenshots side by side, not from memory. Adapts to light/dark mode via
  `hs.host.interfaceStyle()`. Shown on `hs.screen.mainScreen()`. Auto-hides
  after the native delay; a new press restarts the timer.
- Menu bar: `hs.menubar` with a template image. `mic` when live,
  `mic.slash` when muted. Click toggles. No dropdown. User cmd-drags it once
  next to the sound icon; macOS remembers.
- Icon source: `hs.image.imageFromName` with SF Symbol names if Hammerspoon
  1.1.1 resolves them; otherwise the AppKit named images
  `NSTouchBarAudioInputTemplate` / `NSTouchBarAudioInputMuteTemplate`;
  otherwise draw in canvas. Decided by the first implementation task.

### 4. Files and install

```
~/projects/mickey/
  mickey.lua      the module (~80 lines)
  check.sh        smoke test: toggle twice via `hs -c`, assert device flips
  README.md       what it is, the two install lines, the manual steps
~/.hammerspoon/mickey.lua -> ~/projects/mickey/mickey.lua   (symlink)
~/.hammerspoon/init.lua   += require("hs.ipc"); require("mickey")
```

`hs.ipc` is loaded so `hs -c "hs.reload()"` and `check.sh` work from the
terminal.

Retirement of toggleMute, only after the user confirms mickey works in a
real Meet call: quit it, remove from login items,
`brew uninstall --cask togglemute`.

## Error handling

- No default input device: HUD shows "No mic", icon shows mic-slash, no
  crash. Retry on next toggle.
- Device with neither mute flag nor input volume control: `hs.alert`
  "mickey: cannot mute <name>", state unchanged.
- Hammerspoon quit or crashed: F18 does nothing. Same failure mode as the
  existing window shortcuts. Nothing triggers dictation or Wispr.

## Testing

- `check.sh`: reads state, toggles, asserts the default input device's
  mute/volume flipped, toggles back, asserts restored. Exit non-zero on
  failure.
- Manual acceptance: in a Google Meet call, press 🎤. Meet shows no mute
  badge, the other side hears silence. Press again, audio returns. HUD and
  icon match state each time.
- Device switch: mute, connect AirPods, confirm still muted on AirPods.

## Boot behavior

Karabiner (system extension + daemon) and Hammerspoon (login item) both
start at login. Hammerspoon loads `init.lua`, which loads mickey. State on
boot is whatever the hardware reports, usually live; the icon shows the
truth.
