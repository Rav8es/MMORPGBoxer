# EQ Boxer Pro

A multiboxing tool for **EverQuest Live** on Windows, modeled on ISBoxer. It runs on AutoHotkey v2 and is configured with a single INI file.

It helps you run several EverQuest clients at once:
- Launch them and lay them out in a grid on screen.
- Switch between them instantly.
- Copy key presses to all of them.
- Show and click one client's hotbar inside another.

---

## Contents
1. [Requirements](#1-requirements)
2. [Installation](#2-installation)
3. [First-time setup](#3-first-time-setup)
4. [Daily use](#4-daily-use)
5. [Hotkey reference](#5-hotkey-reference)
6. [Control panel and tray menu](#6-control-panel-and-tray-menu)
7. [Slots and launching](#7-slots-and-launching)
8. [Window layouts](#8-window-layouts)
9. [Broadcasting (how it works)](#9-broadcasting-how-it-works)
10. [Mirror mode and mouse broadcast](#10-mirror-mode-and-mouse-broadcast)
11. [Clickable views (Video FX)](#11-clickable-views-video-fx)
12. [Key maps](#12-key-maps)
13. [Configuration reference (EQBoxer.ini)](#13-configuration-reference-eqboxerini)
14. [Troubleshooting](#14-troubleshooting)
15. [Rules and fair play](#15-rules-and-fair-play)

---

## 1. Requirements
- Windows 10 or 11 (64-bit)
- EverQuest Live installed and patched through LaunchPad
- Built for a **3840×2160 (4K)** monitor. Other sizes work. Pick a layout and resolutions that fit your screen.
- AutoHotkey v2 is **included** in the installer. You don't need to install it separately.

## 2. Installation

### With the installer (recommended)
1. Run **EQBoxerPro-Setup.exe**. No administrator rights are needed to install.
   - Windows SmartScreen may say it *protected your PC*, because the installer isn't code-signed. Click **More info → Run anyway**.
2. Choose what to install:
   - **EQ Boxer Pro** (always): the app, its icon, this guide, and its own private copy of **AutoHotkey v2**.
   - **AutoHotkey v2 with AutoHotkey Dash** (on by default): installs AutoHotkey for your Windows user, using AutoHotkey's own installer. That adds **AutoHotkey Dash** and the AutoHotkey help to the Start Menu, and lets you open `.ahk` scripts by double-clicking. EQ Boxer Pro works with or without it.
   - **Desktop shortcut** (on by default).
   - **Start EQ Boxer Pro when Windows starts** (off by default). Because the app runs as administrator, Windows asks for permission each time you sign in.
3. Pick the install folder. The default is `%LOCALAPPDATA%\Programs\EQ Boxer Pro`.
4. On the last page, leave **Start EQ Boxer Pro** ticked. Windows asks for administrator permission; click **Yes**. EverQuest runs as administrator, and the app can only send keys to it if it does too.
5. The **Setup Wizard** opens and walks you through the rest (section 3.0).

**Start Menu → EQ Boxer Pro** has shortcuts to the app, this guide (**EQ Boxer Pro Guide**), the settings folder and the uninstaller. **Settings** (`EQBoxer.ini`) and the log live in the install folder. Installing a newer version over the top keeps them.

**Uninstall:** use *Settings → Apps → Installed apps → EQ Boxer Pro → Uninstall*, or the Start Menu shortcut. It asks whether to also delete your settings. If you installed AutoHotkey with Dash, it stays installed; uninstall it separately under *Installed apps → AutoHotkey* if you want.

### Without the installer
1. Install AutoHotkey v2 from https://www.autohotkey.com.
2. Put `EQBoxerPro.ahk` in its own folder (for example `Documents\EQBoxer`) and double-click it. Accept the administrator prompt.
3. On the first run the app creates **`EQBoxer.ini`** in the same folder.

## 3. First-time setup

### 3.0 Setup Wizard (easiest)
The **Setup Wizard** opens by itself the first time you start EQ Boxer. Open it again any time with **Ctrl+Alt+W**, the **Setup Wizard...** button in the control panel, or the tray menu. It walks you through six steps:

1. **Welcome:** your EverQuest folder (with a **Browse...** button and a check that `eqgame.exe` is there), and whether EQ Boxer runs as administrator.
2. **Number of slots:** how many clients you play at once (1–8).
3. **Characters & accounts:** a character name and an account name for each slot. No passwords are stored.
4. **Layout:** pick a layout and see a **live preview** of where each slot will go, labelled with its character names. Choose whether windows stay above the taskbar and whether borders are removed.
5. **Features:** sound only from the active client, the coloured frame, the button bar, opening the control panel on start, filling in the account name at login, and which keys are broadcast.
6. **Finish:** a summary of everything. Click **Finish** to save, and EQ Boxer restarts with your settings.

**Cancel** closes the wizard without saving and stops it opening by itself. You'll still need to do the scaling step in 3.1 yourself, since the wizard can't change Windows settings for EverQuest.

### 3.1 Turn off Windows scaling for EverQuest (required on 4K)
1. Close all EverQuest clients.
2. Right-click **eqgame.exe** in your EverQuest folder and choose **Properties**.
3. Go to the **Compatibility** tab and click **Change high DPI settings**.
4. Check **Override high DPI scaling behavior** and choose **Application**.
5. Click OK twice.

If you skip this, the mouse only lines up in the top-left client. The app warns you if it detects this problem.

### 3.2 Check eqclient.ini
In your EverQuest folder, `eqclient.ini` should contain:
```
[Defaults]
WindowedMode=TRUE
[VideoMode]
WindowedWidth=1920
WindowedHeight=1080
```
You don't need to set `WindowedModeXOffset` and `WindowedModeYOffset` yourself. With `PrepareIni=1`, the app writes them before each client starts, so each client opens in its own slot.

### 3.3 Set up EQBoxer.ini
Press **Ctrl+Alt+H** to open the control panel, then click **Edit Config**.
1. Check that **`EQPath`** points to your EverQuest folder.
2. Set **`Slots`** to the number of clients you play, from 1 to 8.
3. Give each slot a name and username, either in the **Slots** window (Ctrl+Alt+A) or under **`[Characters]`** and **`[Usernames]`**. The names are labels for window titles and for Launch All.
   ```
   [Characters]
   1=Tank
   2=Healer
   3=DPS1
   4=DPS2
   ```
4. Save the file and press **Ctrl+Alt+R** to reload.

## 4. Daily use
1. Start `EQBoxerPro.ahk`.
2. Start your clients:
   - **Launch All (Ctrl+Alt+L):** starts one client for each named slot, in order. Each client opens in its slot.
   - **Or LaunchPad:** start clients **one at a time**, waiting until each window appears before starting the next. The app always prepares eqclient.ini for the next empty slot.
3. Log in on each client. The username is already filled in, so you only type the password.
4. Play. Use **Ctrl+F1–F8** to jump between clients, **Ctrl+Alt+B** to broadcast, and clickable views to use one client's hotbar from another.
5. Before typing in chat with broadcast on, press **Ctrl+Alt+P** to pause the app.

## 5. Hotkey reference
`^` = Ctrl, `!` = Alt, `+` = Shift, `#` = Win. You can change all of these in `[Hotkeys]`.

| Default | Name in INI | What it does |
|---|---|---|
| Ctrl+F1 … F8 | `FocusSlotModifier` | Switch to client 1…8 |
| Ctrl+Alt+F1 … F8 | `AssignSlotModifier` | Move the active client into slot 1…8 (swaps with whatever was there) |
| Ctrl+Alt+N | `NextClient` | Switch to the next client |
| Ctrl+Alt+B | `ToggleBroadcast` | Turn key broadcasting on/off |
| Ctrl+Alt+M | `ToggleMirror` | Mirror mode on/off: every click is repeated in all clients |
| Mouse button 4 | `MouseBroadcast` | One mirrored left-click in every client |
| Ctrl+Alt+C | `CreateView` | Create a clickable view (drag two boxes) |
| Ctrl+Alt+D | `DeleteView` | Delete the view under the mouse |
| Ctrl+Alt+V | `ToggleVFX` | Show/hide all views |
| Ctrl+Alt+L | `LaunchAll` | Launch a client for every named slot (username pre-filled) |
| Ctrl+Alt+A | `Accounts` | Open the Characters & Accounts window |
| Ctrl+Alt+G | `Arrange` | Put any client that isn't in its slot back into place |
| Ctrl+Alt+S | `ToggleLayout` | Switch to the next layout (Grid, Swap, presets, your own) |
| Ctrl+Alt+U | `RestoreBorders` | Put window borders back on all clients |
| Ctrl+Alt+H | `ControlPanel` | Show/hide the control panel |
| Ctrl+Alt+K | `ToggleToolbar` | Show/hide the on-screen toolbar |
| Ctrl+Alt+O | `ToggleAudio` | Sound from the active client only / from all clients |
| Ctrl+Alt+W | `SetupWizard` | Open the Setup Wizard |
| Ctrl+Alt+P | `Pause` | Pause/resume **all** app hotkeys |
| Ctrl+Alt+R | `ReloadConfig` | Reload EQBoxer.ini |
| Ctrl+Alt+Q | `Quit` | Exit the app |

Broadcast, key maps and mouse broadcast only work while an EverQuest window is active. The other hotkeys work from anywhere.

## 6. Control panel and tray menu
The panel opens automatically when EQ Boxer starts (turn this off with `ShowPanelOnStart=0` in `[General]`). Open or close it any time with **Ctrl+Alt+H**, the **Panel** button on the toolbar, or by double-clicking the tray icon. Closing it with the X only hides it; EQ Boxer keeps running in the tray.

- **Slot list:** every slot with its character name, account name, resolution and whether it's running. Click a slot to edit its names in the boxes below the list. Double-click a slot to switch to that client.
- **Layout dropdown:** choose Grid, Swap, a preset, or your own saved layout.
- **Buttons:** Launch All, Arrange, Save Layout..., Mirror On/Off, Broadcast On/Off, Video FX On/Off, Edit Config, Reload Config, Show/Hide Toolbar, Characters..., Setup Wizard....
- **Number of slots:** choose 1–8. The app saves the setting and reloads.
- **Status bar:** shows the layout, broadcast state, Video FX state and client count.

The tray menu (right-click the tray icon) has Control Panel, Launch All, Arrange, Edit Config, Reload Config and Exit.

### Sound from the active client only
By default (`FollowActive=1` in `[Audio]`), only the client you're playing in makes sound. All the other EverQuest clients are muted, and the sound follows you as you switch.
- Switch it with **Ctrl+Alt+O** or the **Sound** button on the toolbar. **Sound: Active** means only the active client is heard, and **Sound: All** means every client is heard.
- If you click away from EverQuest (to Discord, a browser, the desktop), the last client you played keeps its sound.
- It uses the same per-program mute as the Windows **Volume Mixer**, so you'll see the other `eqgame.exe` entries muted there. When you turn it off or quit EQ Boxer, every client is unmuted.
- It works on your **default playback device**. If EverQuest plays through a different device, set that device as the default in Windows Sound settings.

### On-screen toolbar
A button bar that stays on top of the game, so you don't need to remember hotkeys. Show or hide it with **Ctrl+Alt+K**, the **X** on the bar, the tray menu, or the control panel.

```
:: | 1 Tank | 2 Healer | 3 DPS1 | Broadcast | Mirror | Views | Sound | New View | Arrange | Layout | Launch All | Pause | Panel | Bar | ? | X
```
- **Slot buttons** switch to that client. The client you're in is marked with `>` and shown in the ON colour.
- **Broadcast, Mirror, Views, Sound, Pause** are toggles. They change text and turn the ON colour (green by default) while active.
- **New View** creates a clickable view. **Arrange** fixes misplaced windows. **Layout** steps to the next layout. **Launch All** starts the clients. **Panel** opens the control panel.
- **Bar** opens the bar's settings menu. **?** lists every hotkey. **X** hides the bar.
- Clicking the bar **never takes focus from your game**, so buttons act on the client you're playing in.
- **Move it:** drag the `::` grip on the left (or any gap between buttons). The position is remembered.

**Customising the bar**
| To change | How |
|---|---|
| **Size** (text, buttons and spacing together) | Hold **Ctrl** and scroll the mouse wheel over the bar, or right-click → **Size** |
| **Transparency** | Hold **Shift** and scroll over the bar, or right-click → **Transparency** (100% = solid, down to 20%) |
| **Bar colour** | Right-click → **Bar colour** |
| **Button colour** | Right-click → **Button colour** |
| **Text colour** | Right-click → **Text colour** |
| **ON / active colour** | Right-click → **ON / active colour** (toggles that are on, and the slot you're in) |
| **Horizontal / vertical** | Right-click → **Lay out vertically / horizontally** |
| **Back to defaults** | Right-click → **Reset look** |

Each colour menu has 15 ready-made colours plus **Custom...**, which opens the Windows colour picker. You can also right-click by clicking the **Bar** button. Every setting is saved in `[Toolbar]` in EQBoxer.ini.

While broadcasting is on, a **BROADCAST ON** label stays at the top-left of the screen.

## 7. Slots and launching
- A **slot** is a numbered position (1–8). Each slot has a screen position and, optionally, a character name.
- Each client's window title becomes **`EQ<slot> - <name>`**, for example `EQ2 - Healer`. After a reload, clients go back to their slots based on these titles.
- **Launch All** runs `eqgame.exe patchme` from `EQPath` for each named slot that has no client yet. It waits for each window before starting the next.
  - `patchme` skips LaunchPad and goes straight to the login screen, so patch with LaunchPad first after every game update.
- **Before each launch** (`PrepareIni=1`), the app writes the slot's position and size into eqclient.ini, so EverQuest opens exactly in its slot. This matters because EverQuest maps the mouse from the position it started at. Moving a client afterward makes the mouse drift.
- **Settling:** the app leaves a new client alone until its window size has stayed the same for `SettleTime` ms (15 seconds by default), because EverQuest resizes itself while starting. Touching it earlier can leave it drawing a smaller picture than its window.
- **One at a time:** Launch All waits for each client to settle and be arranged before starting the next, plus `LaunchDelay` (12 seconds). It's slower, but clients no longer start up on top of each other.
- **Title bar hidden straight away:** with the default `BorderMode=Clip`, a client's title bar is hidden as soon as its window appears, while it is still loading. Hiding it this way doesn't move or resize the window, so it's safe during start-up. Until the client is arranged, its picture may sit slightly below or beside its slot.
- **Arranged once:** after the client has settled, the app moves it so its picture sits exactly on its slot, then leaves its size alone. Fighting EverQuest over size makes the picture shrink, grow or stretch.
- **Hidden title bars stay hidden:** the app checks several times a second and hides a title bar again if it comes back. It doesn't otherwise touch a client that's already been arranged.
- If a client isn't in its slot, the control panel shows **"not in its slot, restart it"**. Close that client and start it again.
- Clients beyond the `Slots` count are left alone.

### Character and account names
Each slot has a **character name** and an **account name** (your EverQuest login name).

**In the control panel (easiest):**
1. Open the control panel (**Ctrl+Alt+H**, or the **Panel** button on the toolbar). All slots are listed with their character and account names.
2. Click a slot in the list.
3. Type the **Character** and **Account name** in the boxes under the list, and click **Save**.

You can also use the **Characters & Accounts** window: press **Ctrl+Alt+A**, or use the button in the control panel or the tray menu.

Window titles, the toolbar and Launch All update immediately.

- **Account names:** Launch All starts each client with EverQuest's own `/login:<account>` option, so the account name is already in the login box. You type the password yourself.
- **No passwords:** the app doesn't store any passwords. Earlier versions could save them in Windows Credential Manager. This version deletes any it finds and keeps only the username.
- **Where they're saved:** usernames live in `[Usernames]` in EQBoxer.ini, and names in `[Characters]`.
- **Skipping a slot:** an empty name means Launch All skips that slot.

## 8. Window layouts

### Grid (recommended)
With `Columns=2`, `Width=1920` and `Height=1080`, a 2×2 grid fills a 4K screen exactly:
```
+-----------+-----------+
|  Slot 1   |  Slot 2   |
| 0,0       | 1920,0    |
+-----------+-----------+
|  Slot 3   |  Slot 4   |
| 0,1080    | 1920,1080 |
+-----------+-----------+
```
Each client runs at its real 1920×1080 resolution, so nothing is stretched and the mouse lines up.

### Resolution per slot
Each slot can have its own game resolution. EverQuest draws at exactly the size of its window, so a slot's resolution is its window size.

- **Control panel:** click a slot, pick its **Resolution**, and click **Save**.
- **Setup Wizard:** use the **Resolution** column on the *Characters & accounts* page. The layout preview on the next page shows the result.
- **Choices:** **Fill slot** (default) uses the slot's whole space in the layout. You can also pick a common size like 1920x1080, 2560x1440, 3440x1440 or 1280x720, or **Custom...** to type any size, e.g. 2200x1000.
- **Placement:** a slot with its own resolution is **centred in its slot's space**, and kept on screen if it's bigger.
- **Running clients change straight away.** The app resizes the window and tells EverQuest to redraw at the new size.
- Stored in `[Resolutions]` in EQBoxer.ini as `slot=WidthxHeight` (empty = fill slot).

### Taskbar
With `UseWorkArea=1` (the default), every layout fits in the area **above the taskbar**, so the bottom row is never hidden behind it. The windows are then slightly shorter than the full screen. For example, with a 72-pixel taskbar a 2×2 grid uses 1920×1044 windows. **Restart your clients** after changing this, so EverQuest starts at the new size.

To use the full screen height instead, set `UseWorkArea=0` and turn on **Automatically hide the taskbar** (Windows Settings → Personalization → Taskbar → Taskbar behaviors).

### Layout presets
Pick a layout from the **Layout** dropdown in the control panel, or press **Ctrl+Alt+S** to step through them. Built-in presets scale to any monitor. Sizes below are for 4K:

| Preset | Slots |
|---|---|
| **Top + 2 Bottom** | 1 = whole top half (3840×1080) · 2, 3 = bottom halves (1920×1080). See the note below. |
| **Top Center + 2 Bottom** | 1 = 1920×1080 centered on top · 2, 3 = bottom halves. Every window is 1080p, so it's the most reliable. |
| **Top + 3 Bottom** | 1 = whole top half · 2, 3, 4 = bottom thirds (1280×1080) |
| **Left + 2 Right** | 1 = whole left half (1920×2160) · 2, 3 = right quarters |
| **Big + 3 Right** | 1 = 2880×1620 top-left · 2, 3, 4 = 960×540 down the right |
| **Big + 4 Bottom** | 1 = 3840×1620 across the top · 2–5 = 960×540 along the bottom |
| **Side by Side** | 1, 2 = left and right halves |
| **Top / Bottom** | 1, 2 = top and bottom halves |

```
+-----------------------+        Top + 2 Bottom
|        Slot 1         |
+-----------+-----------+
|  Slot 2   |  Slot 3   |
+-----------+-----------+
```

Slots that a layout has no place for are left where they are.

**Note on full-width slots:** EverQuest starts every client with a title bar and border around the picture. A slot as wide as the whole monitor wouldn't fit on screen with that border, so Windows would squeeze it, and the picture would end up smaller than the slot with black space around it. The app therefore makes any slot that's too big for that slightly smaller and centres it. On a 4K screen, a full-width slot is 3808 wide with a 16-pixel gap at each side. After changing layout, close and relaunch your clients so they start at the right size.

**Important: restart the clients after changing layout.** EverQuest picks its drawing size and mouse position when it starts. Before each client launches, the app writes that slot's size and position for the chosen layout into eqclient.ini. Clients that were already running get moved and stretched, and their mouse may be off until they're restarted.

### Your own layouts
- **Easiest:** turn borders on (Ctrl+Alt+U), drag and size each client where you want it, then click **Save Layout...** and give it a name. It's added to the dropdown and saved in EQBoxer.ini.
- **By hand:** add a section to EQBoxer.ini (pixels from the monitor's top-left, as `x,y,width,height`):
  ```
  [Layout.My Layout]
  1=0,0,3840,1080
  2=0,1080,1920,1080
  3=1920,1080,1920,1080
  ```

### Swap
The active client sits in a large **main** region (2880×1620 by default) and the others go in small 960×540 regions around it. Pressing a client's hotkey or clicking it moves it into the main region.

**Limitation:** EverQuest stretches instead of redrawing when its window is resized, and moving a client after it starts breaks the mouse. Swap therefore looks and behaves worse than Grid with EverQuest. The regions are defined in `[SwapLayout]`.

### Borders
`HideBorders=1` hides title bars and borders so clients sit edge to edge. **Ctrl+Alt+U** shows them again until the next Arrange (**Ctrl+Alt+G**).

By default (`BorderMode=Clip`) the app doesn't remove EverQuest's title bar. EverQuest keeps putting it back, which squashes its picture. Instead, the app places each window so its **picture** sits exactly on the slot, and tells Windows to show only the picture area. The title bar and border still exist for EverQuest, but they're invisible, can't be clicked, and don't cover neighbouring windows. `BorderMode=Strip` goes back to removing the title bar.

### Active client highlight
A red frame is drawn around the client you're playing in, so you always know which slot has the keyboard. It's click-through, so it never blocks the game. Set it in `[Highlight]`:
```
[Highlight]
Enabled=1
; RRGGBB hex colour
Color=FF0000
; pixels
Thickness=4
```

## 9. Broadcasting (how it works)

Broadcasting means that **one key press is repeated once in every client**. Press `1` in your tank's window and every client presses its own hotbar button 1. All 12 hotbar keys (`1`–`0`, `-`, `=`) are broadcast by default.

### 9.1 Turning it on
1. Click into any EverQuest client.
2. Press **Ctrl+Alt+B**. **BROADCAST ON** appears at the top-left of the screen.
3. Press a broadcast key (by default the 12 hotbar keys `1`–`0`, `-` and `=`). Each client presses that key in turn.
4. Press **Ctrl+Alt+B** again to turn it off. The label disappears.

Broadcast only reacts while an **EverQuest window is active**. Pressing `1` in Notepad does nothing.

### 9.2 What happens when you press a key (Switch method, default)
```
You press 1 in slot 1
  -> slot 1 presses 1
  -> app switches to slot 2, waits SwitchDelay ms, presses 1
  -> app switches to slot 3, waits SwitchDelay ms, presses 1
  -> app switches to slot 4, waits SwitchDelay ms, presses 1
  -> app switches back to slot 1
```
- The whole sequence takes about 0.1–0.3 seconds with 4 clients.
- Modifier keys you're holding still apply: **Shift+1** becomes Shift+1 in every client, which is useful for hotbar pages.
- Holding a key doesn't repeat it: one press is one action per client.

### 9.3 Making switching faster
Every hop waits for the client to notice it is in front. EverQuest redraws background clients only `MaxBGFPS` times per second, and that is the main source of lag:
- In `eqclient.ini` under `[Options]`, set **`MaxBGFPS=30`** (or 60). You can also set the background frame rate in-game under Alt+O → Display. At 9 FPS each hop can take over 100 ms. At 60 FPS it takes about 16 ms. A higher value uses more graphics power.
- Then lower `SwitchDelay` (`[Broadcast]` and `[VFX]`, default 20) until clicks or keys start getting missed, and go back up a little.

It can't be fully instant. ISBoxer is instant because it hooks into the game itself, and this app deliberately doesn't.

### 9.4 Why the Switch method exists
EverQuest reads the keyboard only while its window is in front. Keys sent to background windows (the **Send** method, and what earlier versions of this app did) are usually ignored. That's why broadcasting appeared to do nothing.

ISBoxer gets around this by hooking into the game. This app uses only normal Windows features, so it briefly brings each client to the front instead.

### 9.5 Which keys are broadcast
Set in `[Broadcast]`:
```
Mode=Whitelist
Keys=1,2,3,4,5,6,7,8,9,0,-,=
Method=Switch
SwitchDelay=20
```
- **Whitelist:** only the listed keys are broadcast. This is the default and is recommended.
- **Blacklist:** every key **except** the listed ones is broadcast. This doesn't suit the Switch method, because every letter you type would hop between all clients.
- Keys that a key map uses are never broadcast.
- Key names use AutoHotkey names: `a`, `1`, `F5`, `Numpad3`, `Space`, `-`, `=` and so on.

### 9.6 Movement
The Switch method presses keys once, so **holding W to run is not copied**. To move a group, use EverQuest's `/follow`. The example key map `FollowMe` (F12) makes every other client press its F12. Put a `/follow` social on F12 in those clients.

### 9.7 If broadcasting still doesn't work
| Symptom | Fix |
|---|---|
| Keys do nothing at all in EQ, and no "Broadcast 1 -> …" message appears | EverQuest runs as administrator, so EQ Boxer must too. Leave `RunAsAdmin=1` and accept the Windows prompt when the app starts. The startup message says **(admin)** when this is right. |
| No **BROADCAST ON** label | Click into an EQ window first, then press Ctrl+Alt+B. Check that the app isn't paused (Ctrl+Alt+P). |
| Label shows, but other clients don't react | Make sure `Method=Switch` (or that the line is missing). Raise `SwitchDelay` to 60–100 and reload. |
| Only some clients react | Those clients aren't in a slot. Open the control panel and check that each one shows "running". If not, click into it and press Ctrl+Alt+F<n> to assign it. |
| The key reaches the wrong hotbar button | That client has a different hotbar setup or page. Broadcast presses the same *key*, not the same *spell*. |
| Screen flickers when broadcasting | That's normal with the Switch method, since each client is brought forward briefly. |
| The key you press does nothing at all | It's used by a key map, or not in the `Keys=` list. |

## 10. Mirror mode and mouse broadcast

### Mirror mode (Ctrl+Alt+M)
With mirror mode on, every **left or right click** you make in a client is repeated at the **same spot** in every other client. Use it to press the same button everywhere at once, for example Accept, a hotbar button, or a dialog option.

1. Press **Ctrl+Alt+M**, or click **Mirror On/Off** in the control panel. **MIRROR ON** appears at the top-left of the screen.
2. Small yellow markers follow your pointer in the other clients, showing exactly where each click will land.
3. Click as normal. Your click happens first, then the app briefly switches to each other client, clicks the same spot, and comes back. This is the same quick switching broadcast uses, for the same reason: EverQuest only accepts input in the window in front.
4. Press **Ctrl+Alt+M** again to turn it off.

Things to know:
- Spots are relative to each window's size, so mirroring works across different slot sizes. It works best when all clients use the **same UI layout**.
- Clicks in the 3D world land on the same *screen* spot, which shows something different in each client's camera. Use mirror mode for buttons, not for clicking on mobs.
- Dragging (moving items, resizing windows) is not mirrored, only clicks.
- Turn it off before rearranging your UI or typing in chat.
- **If the markers move but the other clients don't click:** raise `ClickDelay` in `[Mirror]` (default 60 ms; try 100–150). Also raise `MaxBGFPS` in eqclient.ini to 30–60 so background clients react faster (see [9.3](#93-making-switching-faster)). After each mirrored click the app shows **"Mirrored Left click to N client(s)"**. If N is 0, the other clients couldn't be brought to the front, so check the app is running as administrator.
- `[Mirror]` settings: `MarkerColor`, `ClickDelay`, `HoldTime` (how long the button is held, default 40 ms), `ShowFeedback`.

### Mouse button 4 (one-off mirrored click)
Press **mouse button 4** (the back button on the side of most mice) over a client to make one mirrored left-click there and in every other client, without turning mirror mode on. Change or disable it with `MouseBroadcast=` in `[Hotkeys]` (leave it empty to disable).

## 11. Clickable views (Video FX)
A **view** is a live copy of part of one client, shown anywhere on screen. **Clicking the copy clicks the real button in the source client.** This is how you use slot 2's hotbar from slot 1.

### 11.1 Create a view
1. Press **Ctrl+Alt+C**. The screen dims.
2. **Step 1:** drag a red box around the area to copy, for example slot 2's hotbar.
3. **Step 2:** drag a box where the copy should appear, for example a corner of slot 1. Or just **click once** to place it at the same size.
4. The view appears immediately and is saved in `[VFX]`.

Press **Esc** at either step to cancel.

### 11.2 Use it
- **Left- or right-click** a button in the view. The app switches to the source client, clicks the real button, then switches back with the mouse where it was.
- Modifier keys you hold (Shift, Ctrl, Alt) still apply to the click.

### 11.3 Manage views
- **Ctrl+Alt+D:** delete the view under the mouse.
- **Ctrl+Alt+V:** hide or show all views.
- Each view is one line in `[VFX]` that you can edit by hand:
  ```
  View1=2|0,950,600,80|1300,950,600,80|255
  ```
  The parts are: source slot | source x,y,w,h (in a 1920×1080 client) | destination x,y,w,h (screen) | opacity 0–255.

### 11.4 View settings
```
[VFX]
; 1 = show views when the app starts
StartOn=0
; Switch | Send | Focus
ClickMode=Switch
; ms to wait around the click in Switch mode
SwitchDelay=20
ReferenceWidth=1920
ReferenceHeight=1080
```
- **Switch:** hops to the client to click. This is reliable.
- **Send:** background click only. It's smoother but often ignored by EverQuest.
- **Focus:** clicking a view just switches to that client.

Views use Windows' own live-thumbnail feature and never touch the game itself. The source client must not be minimized.

## 12. Key maps
Key maps are custom hotkeys that send a key to chosen clients, optionally rotating through them.

```
[KeyMap.NukeRotation]
; Shift+F10
Hotkey=+F10
; first press: slot 3 presses 6
Step1=3:6
; second press: slot 4 presses 6
Step2=4:6
; back to Step1 after 10 s idle
ResetAfter=10
```
- **`Hotkey`:** the trigger, only active while an EQ window is active.
- **`StepN`:** the actions for the Nth press. With several steps, each press runs the next one (round robin).
- **Action format:** `Target:Key`. Join several actions in one step with `&&`.
  - **Target:** `All`, `Others`, `Active`, a slot number (`2`), or a group name from `[Groups]`.
  - **Key:** one AutoHotkey key, for example `{F1}`, `5`, `+2` (Shift+2) or `{Numpad5}`.
- **`Focus:N`** switches to slot N, for example `Step1=Healers:5 && Focus:2`.

Built-in examples:
| Key map | Hotkey | Does |
|---|---|---|
| AssistAll | F11 | All other clients press F11 (put an `/assist` there) |
| FollowMe | F12 | All other clients press F12 (put a `/follow` there) |
| NukeRotation | Shift+F10 | Slot 3, then slot 4, press 6 |
| HealAndBack | Shift+F9 | The Healers group presses 5 |

**Note:** key maps that target *other* clients use background sending, which EverQuest may ignore, the same problem broadcast had. If a key map doesn't reach the other clients, use broadcast or a clickable view instead.

Groups are defined like this:
```
[Groups]
Healers=2
DPS=3,4
Party=1,2,3,4
```

## 13. Configuration reference (EQBoxer.ini)
Keep comments on their own lines. A `;` after a value becomes part of the value. After editing, press **Ctrl+Alt+R**.

### [General]
| Key | Default | Meaning |
|---|---|---|
| EQPath | `C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest` | EverQuest folder |
| EQExe | `eqgame.exe` | Game executable |
| LaunchArgs | `patchme` | Arguments for Launch All |
| LaunchDelay | `12000` | ms between launches (after the previous client has settled) |
| Slots | `4` | Slots in use (1–8) |
| Monitor | `1` | Monitor number for the layout |
| Layout | `Grid` | `Grid`, `Swap`, a preset name, or one of your `[Layout.Name]` layouts |
| AutoArrange | `1` | Keep clients in their slots automatically |
| HideBorders | `1` | Hide title bars and borders |
| BorderMode | `Clip` | `Clip` = show only the picture area (reliable). `Strip` = remove the title bar |
| SwapOnActivate | `1` | Swap layout: activating a client moves it to main |
| SettleTime | `15000` | ms a new client must be stable before arranging |
| PrepareIni | `1` | Write slot position into eqclient.ini before launch |
| UseWorkArea | `1` | Fit layouts above the taskbar (1) or use the whole screen (0) |
| ShowPanelOnStart | `1` | Open the control panel when EQ Boxer starts |
| RunAsAdmin | `1` | Restart EQ Boxer as administrator (needed when EverQuest runs as admin) |

### [Characters]
`slot=name`, for example `1=Tank`. You can also edit these in the control panel. Launch All starts a client for every named slot.

### [Groups]
`name=slot,slot,...`, used as key map targets.

### [Login]
| Key | Default | Meaning |
|---|---|---|
| UseLoginArg | `1` | Launch with `/login:<username>` so EverQuest pre-fills the username |

### [Resolutions]
`slot=WidthxHeight`, for example `1=2560x1440`. Empty = fill the slot's space. Set in the control panel or Setup Wizard.

### [Usernames]
`slot=account name`, for example `1=myaccount`. Set these in the control panel. No passwords are stored anywhere.

### [Audio]
`FollowActive` (1/0): only the active client makes sound.

### [Toolbar]
| Key | Default | Meaning |
|---|---|---|
| Show | `1` | Show the bar at startup |
| Vertical | `0` | 1 = buttons in a column |
| FontSize | `12` | Text size 7–36. Buttons and spacing grow with it |
| Opacity | `100` | 20–100 (100 = solid) |
| Color | `1E1E1E` | Bar background (RRGGBB) |
| ButtonColor | `3A3A3A` | Buttons |
| TextColor | `FFFFFF` | Button text |
| OnColor | `2E7D32` | Toggles that are on, and the active slot |
| X / Y | (saved) | Where you last dragged the bar |

### [Update]
`Repo` (GitHub `owner/name`, empty = built-in), `CheckOnStart` (1/0), `SkipVersion`.

### [Mirror]
`MarkerColor` (RRGGBB), `ClickDelay` (ms to let a client notice the pointer before clicking, default 60), `HoldTime` (ms the button is held, default 40), `ShowFeedback` (1/0). Clickable views use the same click settings.

### [Highlight]
`Enabled` (1/0), `Color` (RRGGBB), `Thickness` (pixels): the frame around the active client.

### [Grid]
`Columns`, `Width`, `Height`: grid shape and cell size.

### [Layout.Name]
Your own layouts: `slot=x,y,width,height`, in pixels from the monitor's top-left. Created by **Save Layout...** or by hand.

### [SwapLayout]
`Main` and `Small1`–`Small7` as `x,y,width,height`, relative to the monitor's top-left.

### [Broadcast]
`Mode` (Whitelist/Blacklist), `Keys`, `Method` (Switch/Send), `SwitchDelay`, `ShowFeedback` (1 = show "Broadcast 1 -> 4 client(s)" after each key).

### [Hotkeys]
See the [hotkey reference](#5-hotkey-reference). Leave a value empty to disable that hotkey.

### [KeyMap.Name]
See [Key maps](#12-key-maps).

### [VFX]
See [Clickable views](#11-clickable-views-video-fx).

## 14. Troubleshooting

| Problem | Cause and fix |
|---|---|
| **"This function declaration conflicts…"** error | You have an old copy of the script. Use the latest EQBoxerPro.ahk. |
| Mouse lines up in only one client | Set the DPI override to **Application** (section 3.1). Then close **all** clients and relaunch with the app running, so each one starts in its slot. |
| Mouse is off in one client | That client was moved after it started. Close it and relaunch it with the app running. Don't drag clients. |
| One client draws a smaller picture than its window (black space right and below) | It was arranged while still starting up. **Quick fix:** in that client press Alt+O → Display and choose its windowed resolution again, or close it and start it again. To prevent it, raise `SettleTime` (try 20000) and start clients with Launch All. |
| A client draws a small picture with black around it, or looks stretched after Arrange | EverQuest doesn't redraw when its window is resized while it's running. Close that client and start it again. |
| A client draws a small picture with black around it, or its picture keeps changing size (older versions) | That slot's window is too wide for EverQuest (full-width slots). Restart it with the latest script. If it persists, use a layout whose slots are 1920×1080 or smaller (for example Top Center + 2 Bottom). |
| A client looks stretched or squashed | EverQuest's own size doesn't match its window. Make sure `WindowedWidth/Height` match the grid `Width/Height`, then restart that client, or re-select 1920×1080 in Alt+O → Display. |
| All clients open on top of each other | They were started too quickly from LaunchPad. Start them one at a time, or use Launch All. |
| A client isn't arranged | It's still settling (wait about 8 s), it's beyond the `Slots` count, or it kept fighting the layout. Press Ctrl+Alt+G. |
| Launch All says it can't find eqgame.exe | Fix `EQPath`. |
| Launch All starts the client but it closes | The game needs patching. Run LaunchPad once, then try again. |
| Broadcast or key maps do nothing | Run EQ Boxer as administrator (`RunAsAdmin=1`, accept the Windows prompt). Then see [9.7](#97-if-broadcasting-still-doesnt-work). |
| Typing in chat spams other clients | Pause the app with Ctrl+Alt+P while typing, or turn broadcast off. |
| A hotkey error appears at startup | A hotkey in the INI is invalid. Fix or clear it. |
| Views are black | The source client is minimized or closed. |
| A view click lands in the wrong place | Delete it (Ctrl+Alt+D) and re-create it after the clients are arranged. |
| Account name isn't filled in | Set it in the control panel (click the slot, type the Account name, Save), and start clients with **Launch All**. Clients started from LaunchPad don't get it. |
| Control panel says "opened off-slot, restart it" | That client opened somewhere other than its slot, so its mouse is off. Close it and start it again with EQ Boxer running. Start clients one at a time, or use Launch All. |
| Clients stay muted after EQ Boxer crashed | Open the Windows Volume Mixer and unmute the `eqgame.exe` entries, or start EQ Boxer and press Ctrl+Alt+O twice. |
| Nothing responds | The app may be paused (Ctrl+Alt+P), or not running. Check for the tray icon. |

### Updates
EQ Boxer Pro updates itself from its GitHub releases.
- **Automatic check:** about 15 seconds after it starts, it checks for a newer version (`CheckOnStart=1` in `[Update]`). If there is one, a window shows **what's new**, with **Update now**, **Later** and **Skip this version**.
- **Check by hand:** the **Check for Updates** button in the control panel, or **Check for Updates...** in the tray menu.
- **Update now:**
  1. The app downloads the new installer.
  2. It checks the download's SHA-256 checksum against the one published with the release. If they don't match, nothing is installed.
  3. It closes, installs the update silently, and starts again.
  Your settings, layouts, views and log are kept. Your installer choices are kept too: AutoHotkey Dash isn't reinstalled, and a desktop shortcut is only recreated if you had one.
- **Version number:** shown in the control panel, the **?** hotkey list, and the tray icon tooltip.
- `[Update]` settings: `Repo` (the GitHub repository, `owner/name`; empty uses the built-in one), `CheckOnStart` (1/0), `SkipVersion` (set by *Skip this version*).

### Diagnostics
If windows don't end up where they should, click **Diagnostics...** in the control panel (or the tray menu). It writes **EQBoxer-diagnostics.txt** next to the script, opens it in Notepad, and copies it to the clipboard. It shows:
- your screen, border size and eqclient.ini values,
- for every slot, where it **should** be and where its window and picture **actually** are,
- the recent **EQBoxer.log**: every client found, settled, arranged, and anything that moved it afterwards (with a check 1 s and 5 s after each arrangement).

Send that file to whoever is helping you fix a layout problem. The log is cleared automatically when it grows past 1 MB.

## 15. Rules and fair play
- The app follows the long-standing community rule of thumb: **one key press = one action per client**. There are no delays, no timed sequences, and nothing runs unless you press a key or click.
- Daybreak has never officially endorsed any multiboxing software, ISBoxer included. Use broadcasting at your own risk.
- Some servers (for example certain progression servers) limit how many accounts you may run at once. Check your server's rules.
