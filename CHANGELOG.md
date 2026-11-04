# Changelog

## 1.1.6
- Fix: clickable views showed an area offset from the one you selected (shifted up and to the left by about the size of the title bar and border). Windows' image of a client can include its hidden title bar and border; the app now measures where the picture starts in that image instead of assuming. Existing views are fixed too; there's no need to make them again.
- Views rebuild themselves if a client's frame changes after the view was made.
- EQBoxer.log records how each view lines up, to help if one is still off.

## 1.1.5
- Fix: with broadcast on, the client you pressed a key in could miss it while the other clients got it (for example `=` Sit/Stand sat slots 2 and 3 but not slot 1). The app hopped to the next client before EverQuest had read the key, and EverQuest drops keys it hasn't read when it loses focus. It now waits briefly first (`[Broadcast] StayDelay`, default 50 ms).
- The same wait applies to your own click in mirror mode (`[Mirror] StayDelay`), and the one-click mirror button (mouse button 4) now clicks the client under the pointer the same way it clicks the others.

## 1.1.4
- Fix: title bars stayed visible on slots whose title bar is on screen (for example the bottom slots in "Top + 2 Bottom"), even though they were clipped. On Windows 10 and 11 the title bar is drawn by the Desktop Window Manager, which ignores a clip set by another program. EQ Boxer Pro now tells Windows not to draw the frame of each client it hides; the window's size and picture don't change.
- If Windows refuses that for a client, that client's title bar is removed instead.
- The window log and Diagnostics show "(drawn by DWM)" when Windows is still drawing a client's title bar.

## 1.1.3
- Fix: a client's title bar showed while it was loading (for example slot 2's title bar across the bottom of slot 1 during Launch All). It's now hidden as soon as the window appears, without moving or resizing it.
- The clip now follows a client when EverQuest resizes or redraws its window, instead of counting that as the clip being lost.
- Ctrl+Alt+U (Restore borders) now keeps the borders visible until the next Arrange; before, they were hidden again within a second.

## 1.1.2
- Fix: "Check for Updates" said updates weren't set up on new installs. The empty `Repo=` line in a freshly created EQBoxer.ini now means "use the built-in repository".

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
