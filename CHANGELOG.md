# Changelog

## 1.3.0
- EQ Boxer Pro is now **MMORPG Boxer**. The app, installer, Start Menu entries and files have the new name: `MMORPGBoxer.ahk`, `MMORPGBoxer.ini`, `MMORPGBoxer.log`, and `MMORPGBoxer-Setup.exe`. It installs to `%LOCALAPPDATA%\Programs\MMORPG Boxer`.
- Updating from EQ Boxer Pro moves your settings and log over, keeps your desktop shortcut and "start with Windows" choice, and removes the old copy.
- Updates now come from the **Rav8es/MMORPGBoxer** repository (the old address keeps working).

## 1.2.2
- Fix: a client's picture could end up stretched after logging out to server select (seen on the full-width slot 1). EverQuest reloads its resolution from eqclient.ini when it changes screens, and that shared file holds another slot's size. EQ Boxer Pro now notices EverQuest changing screens and makes that client redraw at its real window size a few seconds later.
- **Arrange** (Ctrl+Alt+G) now also makes every client redraw at its window size, so it fixes a stretched picture straight away.

## 1.2.1
- Fix: 1.2.0 wouldn't start ("Error: Missing """ at line 2716). A message in the new Clickable Views window had a semicolon that AutoHotkey read as the start of a comment.
- Every build is now checked for this kind of mistake before it's released.

## 1.2.0
- New **Clickable Views** window (Ctrl+Alt+E, **Edit Views** on the toolbar, or **Clickable Views...** in the control panel): make views, change the area a view copies, move or resize it, rename, delete, flash where it is, change which slot it copies from, set its opacity, and choose whether views show at start-up and what clicking one does. It replaces the toolbar's New View button.
- Tooltips on every toolbar and control panel button showing what it does and its keyboard shortcut. Turn them off with **Show tooltips with shortcuts** in the control panel (`[General] ShowTooltips`).
- The control panel's "Video FX On/Off" button is now "Views On/Off", and Diagnostics and Check for Updates sit together on one row.
- The README no longer refers to other multiboxing software.

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
