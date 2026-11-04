# Changelog

## 1.1.1
- Fix: title bars could stay visible on slots whose title bar is on screen (for example the bottom slots). EQ Boxer Pro now checks several times a second that each client is really clipped to its picture and puts the clip back if it's gone.
- If a client keeps losing its clip, EQ Boxer Pro switches just that client to removing its title bar instead.
- The window log and Diagnostics now show each window's actual clip.

## 1.1.0
- Automatic updates from GitHub releases (Update now / Later / Skip this version), with SHA-256 checksum verification; settings are kept.
- "Check for Updates" in the control panel and tray menu; version shown in the control panel.
- Title bars are hidden by clipping each window to its picture area instead of removing them (EverQuest kept putting them back).
- Full-width slots fill the screen edge to edge; per-slot resolution picker.
- Window placement log and Diagnostics report.

## 1.0.0
- First packaged release: installer with AutoHotkey v2.0.31 and AutoHotkey Dash, Setup Wizard, control panel, toolbar, layouts, broadcast, mirror mode, clickable views, sound follows the active client.
