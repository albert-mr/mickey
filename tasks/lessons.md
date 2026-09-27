# Lessons

- macOS 26 (Tahoe): if a Hammerspoon (or any app's) menu bar item never shows and nothing errors, check System Settings › Menu Bar › "Allow in the Menu Bar" first. An app switched off there is silently blocked. Cost me ~40 minutes of AX/CGWindowList archaeology.
- "As native as possible" means match the family (material, corners, offset, type), not clone the nearest control. A binary state gets a one-row card, not a slider. Propose the compact version first, offer the full copy as an option.
- The `hs` CLI blocks when stdin is a pipe (it reads stdin for code). Always `hs -c ... < /dev/null` in scripts.
- Synthetic media keys via hs.eventtap change volume but never trigger Apple's OSD. To study a native HUD, record the screen while the user presses the real key.
- Don't assume the HUD layout of a new macOS from memory; measure it.
