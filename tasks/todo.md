# mickey — todo

Plan: docs/superpowers/plans/2026-09-27-mickey.md
Spec: docs/superpowers/specs/2026-09-27-mickey-design.md

- [x] Task 1: wire-up (hs.ipc, symlink, Karabiner f5→f18, probes, user presses 🎤)
- [x] Task 2: mute engine + tap/hold + click sound + menu bar icon + check.sh
- [x] Task 3: HUD bezel matched to native volume HUD by screenshot
- [ ] Task 4: README done, review fixes done; pending user: Wispr rebind, Meet acceptance, retire toggleMute

## Review

- Probes: built-in mic has a mute flag; SF Symbols unavailable in Hammerspoon 1.1.1 (canvas glyph); iPhone Continuity mic unmutable.
- hs CLI hang root cause: it reads stdin when stdin is a pipe. Fix: `< /dev/null`.
- hs.canvas has no `roundedRectangle`; use `rectangle` + `roundedRectRadii`.
- Native macOS 26 volume HUD: 290x64 pt card, 16 pt radius, 11 pt under the menu bar, centered under the Sound icon, semibold device name + icon/track/icon. Synthetic key events change volume but never show it; captured from a real key press.
- Menu bar position cannot be seeded via NSStatusItem Preferred Position; autosave name + one user drag.
- Root cause of the invisible icon: macOS 26 System Settings › Menu Bar › "Allow in the Menu Bar" had Hammerspoon off. Toggled on.
- Bezel changed on user request to a compact one-row card under the icon (glyph + "Microphone Muted"/"Microphone On").
- Final review: 2 Important fixed test-first (check.sh restores the mic on failure; watcher only touches a disagreeing device). 5 minors deferred (see git log / final message).
- Deferred: mute surviving reboot; light-mode bezel not captured.
