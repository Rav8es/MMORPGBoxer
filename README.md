# MMORPG Boxer

**Multiboxing for EverQuest, EverQuest II, Monsters & Memories and EVE Online on Windows.** Lay your game windows out on screen, switch between them with one key, and use the extras each game's rules allow: broadcasting keys, mirrored clicks, clickable views of another client's hotbar, team commands, per-character settings and more.

**[Download the latest installer](https://github.com/Rav8es/MMORPGBoxer/releases/latest)** · **[Guide (wiki)](https://github.com/Rav8es/MMORPGBoxer/wiki)** · **[What's new](https://github.com/Rav8es/MMORPGBoxer/blob/main/CHANGELOG.md)**

## Features
- **Window layouts** with a picture and an explanation of each: grids, one big window with smaller ones, side by side, your own saved layouts, and a resolution per slot. Title bars are hidden so windows sit edge to edge.
- **Instant switching:** Ctrl+F1–F8, an on-screen toolbar, and a red frame around the client you're playing.
- **Sound from the active client only**, CPU cores and priority per client.
- **Clickable views:** a live copy of part of one client (for example its hotbar) anywhere on screen; clicking it clicks the real button.
- **EverQuest extras:** key broadcasting, mirror mode, team commands (follow me, assist me...), key maps, a separate eqclient.ini per character, frame-rate caps, and the login name filled in by Launch All.
- **Setup Wizard, control panel with tooltips, dark mode,** and automatic updates.

Each game only gets the features its publisher's rules allow; see [Supported games](#supported-games) and the [official rules for each game](#official-rules-for-each-game).

## Quick start
1. Download **[MMORPGBoxer-Setup.exe](https://github.com/Rav8es/MMORPGBoxer/releases/latest)** and run it. If Windows SmartScreen warns, click **More info → Run anyway** (the installer isn't code-signed).
2. Leave **Start MMORPG Boxer** ticked at the end and accept the administrator prompt. The **Setup Wizard** opens: pick your game and its folder, the number of slots, names, a layout and the features you want.
3. Click **Launch All** (Ctrl+Alt+L). For EverQuest it starts every client in its slot; for the other games it opens the game's launcher, and each window goes into the next free slot as you start it.
4. Play: **Ctrl+F1–F8** switches clients, **Ctrl+Alt+H** opens the control panel, **Ctrl+Alt+K** shows or hides the toolbar. Point at any button to see its shortcut.

MMORPG Boxer was called **EQ Boxer Pro** up to version 1.2.2. Updating, or running the new installer, moves your settings over and removes the old copy.

---

## Contents
- [Requirements](#requirements)
- [Installation](#installation)
  - [With the installer (recommended)](#with-the-installer-recommended)
  - [Without the installer](#without-the-installer)
- [Supported games](#supported-games)
  - [Choosing the game](#choosing-the-game)
  - [What each game gets](#what-each-game-gets)
  - [Why](#why)
  - [Starting the other games](#starting-the-other-games)
- [First-time setup](#first-time-setup)
  - [Setup Wizard (easiest)](#setup-wizard-easiest)
  - [Turn off Windows scaling for EverQuest (required on 4K)](#turn-off-windows-scaling-for-everquest-required-on-4k)
  - [Check eqclient.ini](#check-eqclientini)
  - [Set up MMORPGBoxer.ini by hand (optional)](#set-up-mmorpgboxerini-by-hand-optional)
- [Daily use](#daily-use)
- [Hotkey reference](#hotkey-reference)
- [Control panel, toolbar and tray menu](#control-panel-toolbar-and-tray-menu)
  - [Sound from the active client only](#sound-from-the-active-client-only)
  - [On-screen toolbar](#on-screen-toolbar)
- [Slots and launching](#slots-and-launching)
  - [Character and account names](#character-and-account-names)
- [Window layouts](#window-layouts)
  - [The Layouts window](#the-layouts-window)
  - [Grid (recommended)](#grid-recommended)
  - [Resolution per slot](#resolution-per-slot)
  - [Taskbar](#taskbar)
  - [Layout presets](#layout-presets)
  - [Your own layouts](#your-own-layouts)
  - [Swap](#swap)
  - [Borders](#borders)
  - [Active client highlight](#active-client-highlight)
- [Broadcasting (how it works)](#broadcasting-how-it-works)
  - [Turning it on](#turning-it-on)
  - [What happens when you press a key (Switch method, default)](#what-happens-when-you-press-a-key-switch-method-default)
  - [Making switching faster](#making-switching-faster)
  - [Why the Switch method exists](#why-the-switch-method-exists)
  - [Which keys are broadcast](#which-keys-are-broadcast)
  - [Movement](#movement)
  - [If broadcasting still doesn't work](#if-broadcasting-still-doesnt-work)
- [Mirror mode and mouse broadcast](#mirror-mode-and-mouse-broadcast)
  - [Mirror mode (Ctrl+Alt+M)](#mirror-mode-ctrlaltm)
  - [Mouse button 4 (one-off mirrored click)](#mouse-button-4-one-off-mirrored-click)
- [Clickable views (Video FX)](#clickable-views-video-fx)
  - [The Clickable Views window](#the-clickable-views-window)
  - [Create a view](#create-a-view)
  - [Use it](#use-it)
  - [Shortcuts and the config file](#shortcuts-and-the-config-file)
  - [View settings](#view-settings)
- [Team and Performance](#team-and-performance)
  - [In-game names](#in-game-names)
  - [Team commands (follow, assist, formations)](#team-commands-follow-assist-formations)
  - [CPU cores and priority](#cpu-cores-and-priority)
  - [Frame-rate caps](#frame-rate-caps)
  - [Separate EverQuest settings for each character](#separate-everquest-settings-for-each-character)
- [Key maps](#key-maps)
- [Configuration reference (MMORPGBoxer.ini)](#configuration-reference-mmorpgboxerini)
- [Troubleshooting](#troubleshooting)
- [Updates and diagnostics](#updates-and-diagnostics)
  - [Updates](#updates)
  - [Diagnostics](#diagnostics)
- [Rules and fair play](#rules-and-fair-play)
  - [Official rules for each game](#official-rules-for-each-game)

---

## Requirements
- Windows 10 or 11 (64-bit)
- One of the [supported games](#supported-games), installed and patched: EverQuest Live, EverQuest II, Monsters & Memories or EVE Online
- Built on a **3840×2160 (4K)** monitor. Other sizes work: pick a layout and resolutions that fit your screen.
- AutoHotkey v2 is **included** in the installer. You don't need to install it separately.

## Installation

### With the installer (recommended)
1. Run **MMORPGBoxer-Setup.exe**. No administrator rights are needed to install.
   - Windows SmartScreen may say it *protected your PC*, because the installer isn't code-signed. Click **More info → Run anyway**.
2. Choose what to install:
   - **MMORPG Boxer** (always): the app, its icon, this guide, and its own private copy of **AutoHotkey v2**.
   - **AutoHotkey v2 with AutoHotkey Dash** (on by default): installs AutoHotkey for your Windows user, using AutoHotkey's own installer. That adds **AutoHotkey Dash** and the AutoHotkey help to the Start Menu, and lets you open `.ahk` scripts by double-clicking. MMORPG Boxer works with or without it.
   - **Desktop shortcut** (on by default).
   - **Start MMORPG Boxer when Windows starts** (off by default). Because the app runs as administrator, Windows asks for permission each time you sign in.
3. Pick the install folder. The default is `%LOCALAPPDATA%\Programs\MMORPG Boxer`.
4. On the last page, leave **Start MMORPG Boxer** ticked. Windows asks for administrator permission; click **Yes**. Games such as EverQuest run as administrator, and the app can only send keys and clicks to them if it does too.
5. The **Setup Wizard** opens and walks you through the rest (see [Setup Wizard](#setup-wizard-easiest)).

**Start Menu → MMORPG Boxer** has shortcuts to the app, this guide (**MMORPG Boxer Guide**), the settings folder and the uninstaller. **Settings** (`MMORPGBoxer.ini`, plus `MMORPGBoxer-<game>.ini` for the other games) and the log live in the install folder. Installing a newer version over the top keeps them.

**Coming from EQ Boxer Pro:** the installer finds your old install, copies `EQBoxer.ini` to `MMORPGBoxer.ini` (and the log), keeps "start when Windows starts" and the desktop shortcut if you had them, and removes the old files, shortcuts and uninstall entry. Copies without the installer pick up an `EQBoxer.ini` in the same folder by themselves.

**Uninstall:** use *Settings → Apps → Installed apps → MMORPG Boxer → Uninstall*, or the Start Menu shortcut. It asks whether to also delete your settings. If you installed AutoHotkey with Dash, it stays installed; uninstall it separately under *Installed apps → AutoHotkey* if you want.

### Without the installer
1. Install AutoHotkey v2 from https://www.autohotkey.com.
2. Put `MMORPGBoxer.ahk` in its own folder (for example `Documents\MMORPGBoxer`) and double-click it. Accept the administrator prompt.
3. On the first run the app creates **`MMORPGBoxer.ini`** in the same folder.

## Supported games
### Choosing the game
Pick the game in the **Game** box at the top of the control panel or on the first page of the Setup Wizard. Each game keeps its own slots, layouts and settings: EverQuest uses `MMORPGBoxer.ini`, the others `MMORPGBoxer-<game>.ini` (for example `MMORPGBoxer-EVEOnline.ini`). Switching restarts MMORPG Boxer; the first time you switch to a game, its Setup Wizard opens.

### What each game gets
Every game follows its publisher's rules about software. Features a game doesn't allow are greyed out, and their hotkeys only show a message:

| | EverQuest | EverQuest II | Monsters & Memories | EVE Online |
|---|---|---|---|---|
| Layouts, slot switching, toolbar, panel | yes | yes | yes | yes |
| Sound from the active client, CPU settings | yes | yes | yes | yes |
| Clickable views | yes | yes | yes | no |
| Broadcasting, mirror mode, mouse-button-4 click, team commands, key maps | yes | no | no | no |
| Most slots | 8 | 8 | 3 | 8 |
| Launch All | starts the clients | opens LaunchPad | opens the M&M launcher | opens the EVE launcher |
| eqclient.ini features (per-character settings, frame-rate caps, login name) | yes | no | no | no |

### Why
- **EverQuest II:** boxing is allowed, but Daybreak's stated policy is that software may not issue simultaneous commands to several characters.
- **Monsters & Memories:** boxing is allowed only on its 3-box server (Nunavoth), and every character must be played by hand.
- **EVE Online:** multiboxing is allowed, but CCP bans input broadcasting and multiplexing, and overlays that use parts of other clients to act in them. Window positions and arrangements are allowed. MMORPG Boxer also keeps EVE's own window titles (`EVE - <character>`).

The publishers' own pages are linked in [Official rules for each game](#official-rules-for-each-game).

### Starting the other games
For the games started from their own launcher, start each character from the launcher (with LaunchPad, start it again for each account). MMORPG Boxer puts each window into the next free slot as it opens; Ctrl+Alt+F1… moves a client to another slot. Play in **windowed** mode, and set frame-rate limits in the game's own options.

Support for EverQuest II, Monsters & Memories and EVE Online is new. If a client keeps jumping back to its own size when MMORPG Boxer arranges it, set the game's windowed resolution to the slot's size, and send MMORPGBoxer.log.

## First-time setup

### Setup Wizard (easiest)
The **Setup Wizard** opens by itself the first time you start MMORPG Boxer. Open it again any time with **Ctrl+Alt+W**, the **Setup Wizard...** button in the control panel, or the tray menu. It walks you through seven steps:

1. **Welcome:** the **game**, its folder (with a **Browse...** button and a check that the game is there), and whether MMORPG Boxer runs as administrator. Changing the game restarts the app with that game's own setup.
2. **Number of slots:** how many clients you play at once (1–8, or 1–3 for Monsters & Memories).
3. **Characters & accounts:** for each slot, a label (for example *Tank*), the character's **in-game name** (used by follow and assist), the account name and a resolution. No passwords are stored.
4. **Layout:** pick a layout from the list and see a **live preview** of where each slot will go, labelled with its names, with an explanation of the layout. Choose whether windows stay above the taskbar and whether borders are removed.
5. **Team & performance:** separate EverQuest settings for each character, how CPU cores are shared, and frame-rate caps for slot 1 and the other slots (active and background). It also lists the team command hotkeys.
6. **Features:** sound only from the active client, the coloured frame, the button bar, opening the control panel on start, filling in the account name at login, which keys are broadcast, tooltips, checking for updates, and the appearance (System, Light or Dark).
7. **Finish:** a summary of everything. Click **Finish** to save, and MMORPG Boxer restarts with your settings.

The steps adapt to the game: features it doesn't allow are greyed out.

**Cancel** closes the wizard without saving and stops it opening by itself. For EverQuest you'll still need to do the [scaling step](#turn-off-windows-scaling-for-everquest-required-on-4k) yourself, since the wizard can't change Windows settings for the game.

### Turn off Windows scaling for EverQuest (required on 4K)
1. Close all EverQuest clients.
2. Right-click **eqgame.exe** in your EverQuest folder and choose **Properties**.
3. Go to the **Compatibility** tab and click **Change high DPI settings**.
4. Check **Override high DPI scaling behavior** and choose **Application**.
5. Click OK twice.

If you skip this, the mouse only lines up in the top-left client. The app warns you if it detects this problem.

For the other games, do the same only if the mouse doesn't line up with where you point: the game file is `EverQuest2.exe`, `mnm.exe` or `exefile.exe` (EVE's is in its `bin64` folder).

### Check eqclient.ini
*EverQuest only.* In your EverQuest folder, `eqclient.ini` should contain:
```
[Defaults]
WindowedMode=TRUE
[VideoMode]
WindowedWidth=1920
WindowedHeight=1080
```
You don't need to set `WindowedModeXOffset` and `WindowedModeYOffset` yourself. With `PrepareIni=1`, the app writes them before each client starts, so each client opens in its own slot.

### Set up MMORPGBoxer.ini by hand (optional)
The Setup Wizard and the control panel cover everything here; editing the file is only needed for the finer settings in the [configuration reference](#configuration-reference-mmorpgboxerini). Press **Ctrl+Alt+H** to open the control panel, then click **Edit Config**.
1. Check that **`EQPath`** points to your EverQuest folder.
2. Set **`Slots`** to the number of clients you play, from 1 to 8.
3. Give each slot a name and username, either in the **Characters & Accounts** window (Ctrl+Alt+A) or under **`[Characters]`** and **`[Usernames]`**. The names are labels for window titles and for Launch All.
   ```
   [Characters]
   1=Tank
   2=Healer
   3=DPS1
   4=DPS2
   ```
4. Save the file and press **Ctrl+Alt+R** to reload.

## Daily use
1. Start **MMORPG Boxer** (Start Menu or desktop shortcut). The control panel opens; its **Game** box shows which game is set up.
2. Start your clients:
   - **EverQuest:** **Launch All** (Ctrl+Alt+L) starts one client for each named slot, in order, each in its slot, with the account name already in the login box. Or start them from LaunchPad **one at a time**, waiting for each window before starting the next.
   - **EverQuest II, Monsters & Memories, EVE Online:** **Launch All** opens the game's launcher. Start each character from it; each window goes into the next free slot as it opens. Ctrl+Alt+F1–F8 moves the client you're in to another slot.
3. Play. **Ctrl+F1–F8** jumps between clients. In EverQuest, **Ctrl+Alt+B** broadcasts keys and **Ctrl+Alt+F** makes everyone follow you; clickable views let you use one client's hotbar from another.
4. If a picture ever looks stretched, press **Ctrl+Alt+G** (Arrange).
5. Before typing in chat with broadcast on, press **Ctrl+Alt+P** to pause the app's hotkeys.

## Hotkey reference
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
| Ctrl+Alt+E | `ViewManager` | Open the Clickable Views window |
| Ctrl+Alt+F | `FollowMe` | Team: every other client follows you |
| Ctrl+Alt+X | `StopFollow` | Team: stop following |
| Ctrl+Alt+T | `AssistMe` | Team: every other client assists you |
| Ctrl+Alt+L | `LaunchAll` | EverQuest: launch a client for every named slot (username pre-filled). Other games: open the game's launcher |
| Ctrl+Alt+A | `Accounts` | Open the Characters & Accounts window |
| Ctrl+Alt+G | `Arrange` | Put any client that isn't in its slot back into place, and make every client redraw at its window size (fixes a stretched picture) |
| Ctrl+Alt+S | `ToggleLayout` | Switch to the next layout (Grid, Swap, presets, your own) |
| (none) | `LayoutsWindow` | Open the Layouts window |
| Ctrl+Alt+U | `RestoreBorders` | Put window borders back on all clients |
| Ctrl+Alt+H | `ControlPanel` | Show/hide the control panel |
| Ctrl+Alt+K | `ToggleToolbar` | Show/hide the on-screen toolbar |
| Ctrl+Alt+O | `ToggleAudio` | Sound from the active client only / from all clients |
| Ctrl+Alt+W | `SetupWizard` | Open the Setup Wizard |
| Ctrl+Alt+P | `Pause` | Pause/resume **all** app hotkeys |
| Ctrl+Alt+R | `ReloadConfig` | Reload MMORPGBoxer.ini |
| Ctrl+Alt+Q | `Quit` | Exit the app |

Broadcast, key maps and mouse broadcast only work while a game window is active. The other hotkeys work from anywhere.

Broadcasting, mirror mode, mouse button 4, team commands and key maps are EverQuest only, and clickable views aren't available for EVE Online (see [Supported games](#supported-games)). For the other games those hotkeys just show a message saying why, and mouse button 4 is left to the game.

**Tooltips:** point at any button on the toolbar or in the control panel to see what it does and its keyboard shortcut. Turn them off or on with **Show tooltips with shortcuts** in the control panel (`ShowTooltips` in `[General]`). The tooltips show the shortcuts you've actually set in `[Hotkeys]`.

## Control panel, toolbar and tray menu
The panel opens automatically when MMORPG Boxer starts (turn this off with `ShowPanelOnStart=0` in `[General]`). Open or close it any time with **Ctrl+Alt+H**, the **Panel** button on the toolbar, or by double-clicking the tray icon. Closing it with the X only hides it; MMORPG Boxer keeps running in the tray.

- **Game:** which game is set up. Choosing another one restarts the app with that game's own slots, layouts and settings (see [Supported games](#supported-games)).
- **Slot list:** every slot with its character name, account name, resolution and whether it's running. Click a slot to edit its names in the boxes below the list. Double-click a slot to switch to that client.
- **Layout:** shows the layout in use. **Layouts...** opens the [Layouts window](#the-layouts-window).
- **Buttons:** Launch All, Arrange, Save Layout..., Mirror On/Off, Broadcast On/Off, Views On/Off, Clickable Views..., Characters..., Show/Hide Toolbar, Setup Wizard..., Edit Config, Reload Config, Team & Performance..., Team Commands..., Diagnostics..., Check for Updates. Buttons for features the game doesn't allow are greyed out; point at one to see why.
- **Show tooltips with shortcuts:** turns the button tooltips on or off.
- **Appearance:** **System** (follows Windows' light or dark app mode, and switches when Windows does), **Light** or **Dark**. It applies to the control panel, every other window of the app, and its menus. The toolbar keeps its own colours (its **Bar** menu). `Appearance` in `[General]`.
- **Number of slots:** choose 1–8 (1–3 for Monsters & Memories). The app saves the setting and reloads.
- **Status line** (at the bottom): what the app just did, then the layout, broadcast, mirror and views state and the client count.

The tray menu (right-click the tray icon) has Control Panel, Show/Hide Toolbar, Launch All, Characters & Accounts..., Layouts..., Clickable Views..., Team & Performance..., Setup Wizard..., Diagnostics..., Check for Updates..., Online Guide (this guide, on the wiki), Arrange, Edit Config, Reload Config and Exit. The **?** button on the toolbar lists every shortcut and offers to open the guide.

### Sound from the active client only
By default (`FollowActive=1` in `[Audio]`), only the client you're playing in makes sound. All the other game clients are muted, and the sound follows you as you switch.
- Switch it with **Ctrl+Alt+O** or the **Sound** button on the toolbar. **Sound: Active** means only the active client is heard, and **Sound: All** means every client is heard.
- If you click away from the game (to Discord, a browser, the desktop), the last client you played keeps its sound.
- It uses the same per-program mute as the Windows **Volume Mixer**, so you'll see the other game entries (for example `eqgame.exe`) muted there. When you turn it off or quit MMORPG Boxer, every client is unmuted.
- It works on your **default playback device**. If the game plays through a different device, set that device as the default in Windows Sound settings.

### On-screen toolbar
A button bar that stays on top of the game, so you don't need to remember hotkeys. Show or hide it with **Ctrl+Alt+K**, the **X** on the bar, the tray menu, or the control panel.

```
:: | 1 Tank | 2 Healer | 3 DPS1 | Broadcast | Mirror | Views | Sound | Edit Views | Team | Arrange | Layout | Launch All | Pause | Panel | Bar | ? | X
```
That's the EverQuest bar. For the other games, buttons for features the game doesn't allow (Broadcast, Mirror, Team, and for EVE Online also Views and Edit Views) are left off.
- **Slot buttons** switch to that client. The client you're in is marked with `>` and shown in the ON colour.
- **Broadcast, Mirror, Views, Sound, Pause** are toggles. They change text and turn the ON colour (green by default) while active.
- **Edit Views** opens the Clickable Views window. **Team** opens the team commands menu. **Arrange** fixes misplaced windows. **Layout** opens the Layouts window. **Launch All** starts the clients (or the game's launcher). **Panel** opens the control panel.
- **Bar** opens the bar's settings menu. **?** lists every hotkey. **X** hides the bar.
- Point at a button to see what it does and its keyboard shortcut.
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

Each colour menu has 15 ready-made colours plus **Custom...**, which opens the Windows colour picker. You can also right-click by clicking the **Bar** button. Every setting is saved in `[Toolbar]` in MMORPGBoxer.ini.

While broadcasting is on, a **BROADCAST ON** label stays at the top-left of the screen.

## Slots and launching
- A **slot** is a numbered position (1–8). Each slot has a screen position and, optionally, a character name.
- Each client's window title becomes **`EQ<slot> - <name>`**, for example `EQ2 - Healer` (for every game except EVE Online, which keeps its own `EVE - <character>` titles). After a reload, clients go back to their slots based on these titles, or otherwise by where they are on screen.
- The rest of this section describes **EverQuest**. For the other games, Launch All opens the game's launcher and each window goes into the next free slot as it opens (see [Supported games](#supported-games)); settling and title-bar hiding work the same way.
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
- **Where they're saved:** usernames live in `[Usernames]` in MMORPGBoxer.ini, and names in `[Characters]`.
- **Skipping a slot:** an empty name means Launch All skips that slot.

## Window layouts

### The Layouts window
Open it with **Layouts...** in the control panel, the **Layout** button on the toolbar, or the tray menu. Every layout is listed on the left. Click one to see:
- a **picture** of where each of your slots goes, labelled with its names,
- an **explanation** of the layout and what it's good for,
- each slot's **size** in pixels, and any slot the layout has no place for.

**Use This Layout** (or double-click) switches to it; running clients move straight away. **Save Current Positions...** saves where your windows are now as a new layout, and **Delete Layout** removes one you saved (the built-in ones can't be deleted). **Ctrl+Alt+S** still steps to the next layout without opening the window.

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
- Stored in `[Resolutions]` in MMORPGBoxer.ini as `slot=WidthxHeight` (empty = fill slot).

### Taskbar
With `UseWorkArea=1` (the default), every layout fits in the area **above the taskbar**, so the bottom row is never hidden behind it. The windows are then slightly shorter than the full screen. For example, with a 72-pixel taskbar a 2×2 grid uses 1920×1044 windows. **Restart your clients** after changing this, so EverQuest starts at the new size.

To use the full screen height instead, set `UseWorkArea=0` and turn on **Automatically hide the taskbar** (Windows Settings → Personalization → Taskbar → Taskbar behaviors).

### Layout presets
Pick a layout in the [Layouts window](#the-layouts-window), or press **Ctrl+Alt+S** to step through them. Built-in presets scale to any monitor. Sizes below are for 4K:

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

**Important (EverQuest): restart the clients after changing layout.** EverQuest picks its drawing size and mouse position when it starts. Before each client launches, the app writes that slot's size and position for the chosen layout into eqclient.ini. Clients that were already running get moved and stretched, and their mouse may be off until they're restarted.

### Your own layouts
- **Easiest:** turn borders on (Ctrl+Alt+U), drag and size each client where you want it, then click **Save Current Positions...** in the Layouts window (or **Save Layout...** in the control panel) and give it a name. It's added to the list and saved in MMORPGBoxer.ini.
- **By hand:** add a section to MMORPGBoxer.ini (pixels from the monitor's top-left, as `x,y,width,height`):
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

By default (`BorderMode=Clip`) the app doesn't remove EverQuest's title bar. EverQuest keeps putting it back, which squashes its picture. Instead, the app places each window so its **picture** sits exactly on the slot, and tells Windows to show only the picture area. The title bar and border still exist for EverQuest, but they're invisible, can't be clicked, and don't cover neighbouring windows. On Windows 10 and 11 the title bar is normally drawn by the Desktop Window Manager on top of the window, where a clip can't reach it, so the app also tells Windows not to draw each client's frame that way. If Windows refuses for a client, the app removes that client's title bar instead. `BorderMode=Strip` goes back to removing the title bar for every client.

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

## Broadcasting (how it works)

*EverQuest only. The rules of the other supported games don't allow it (see [Supported games](#supported-games)).*

Broadcasting means that **one key press is repeated once in every client**. Press `1` in your tank's window and every client presses its own hotbar button 1. All 12 hotbar keys (`1`–`0`, `-`, `=`) are broadcast by default.

### Turning it on
1. Click into any EverQuest client.
2. Press **Ctrl+Alt+B**. **BROADCAST ON** appears at the top-left of the screen.
3. Press a broadcast key (by default the 12 hotbar keys `1`–`0`, `-` and `=`). Each client presses that key in turn.
4. Press **Ctrl+Alt+B** again to turn it off. The label disappears.

Broadcast only reacts while an **EverQuest window is active**. Pressing `1` in Notepad does nothing.

### What happens when you press a key (Switch method, default)
```
You press 1 in slot 1
  -> slot 1 presses 1, and the app waits StayDelay ms so slot 1 reads it
  -> app switches to slot 2, waits SwitchDelay ms, presses 1
  -> app switches to slot 3, waits SwitchDelay ms, presses 1
  -> app switches to slot 4, waits SwitchDelay ms, presses 1
  -> app switches back to slot 1
```
- The whole sequence takes about 0.1–0.3 seconds with 4 clients.
- Modifier keys you're holding still apply: **Shift+1** becomes Shift+1 in every client, which is useful for hotbar pages.
- Holding a key doesn't repeat it: one press is one action per client.

### Making switching faster
Every hop waits for the client to notice it is in front. EverQuest redraws background clients only `MaxBGFPS` times per second, and that is the main source of lag:
- In `eqclient.ini` under `[Options]`, set **`MaxBGFPS=30`** (or 60). You can also set the background frame rate in-game under Alt+O → Display. At 9 FPS each hop can take over 100 ms. At 60 FPS it takes about 16 ms. A higher value uses more graphics power.
- Then lower `SwitchDelay` (`[Broadcast]` and `[VFX]`, default 20) until clicks or keys start getting missed, and go back up a little.

It can't be fully instant: that would mean hooking into the game itself, which this app deliberately doesn't do.

### Why the Switch method exists
EverQuest reads the keyboard only while its window is in front. Keys sent to background windows (the **Send** method, and what earlier versions of this app did) are usually ignored. That's why broadcasting appeared to do nothing.

This app uses only normal Windows features and never hooks into the game, so it briefly brings each client to the front instead.

### Which keys are broadcast
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

### Movement
The Switch method presses keys once, so **holding W to run is not copied**. To move a group, use EverQuest's `/follow`. The example key map `FollowMe` (F12) makes every other client press its F12. Put a `/follow` social on F12 in those clients.

### If broadcasting still doesn't work
| Symptom | Fix |
|---|---|
| Keys do nothing at all in EQ, and no "Broadcast 1 -> …" message appears | EverQuest runs as administrator, so MMORPG Boxer must too. Leave `RunAsAdmin=1` and accept the Windows prompt when the app starts. The startup message says **(admin)** when this is right. |
| No **BROADCAST ON** label | Click into an EQ window first, then press Ctrl+Alt+B. Check that the app isn't paused (Ctrl+Alt+P). |
| Label shows, but other clients don't react | Make sure `Method=Switch` (or that the line is missing). Raise `SwitchDelay` to 60–100 and reload. |
| The other clients react, but the client you pressed the key in doesn't (for example `=` Sit/Stand only sits slots 2 and 3) | That client lost focus before it read the key. Raise `StayDelay` in `[Broadcast]` (default 50) to 80–120 and reload. |
| Only some clients react | Those clients aren't in a slot. Open the control panel and check that each one shows "running". If not, click into it and press Ctrl+Alt+F<n> to assign it. |
| The key reaches the wrong hotbar button | That client has a different hotbar setup or page. Broadcast presses the same *key*, not the same *spell*. |
| Screen flickers when broadcasting | That's normal with the Switch method, since each client is brought forward briefly. |
| The key you press does nothing at all | It's used by a key map, or not in the `Keys=` list. |

## Mirror mode and mouse broadcast

*EverQuest only (see [Supported games](#supported-games)).*

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
- **If the markers move but the other clients don't click:** raise `ClickDelay` in `[Mirror]` (default 60 ms; try 100–150). Also raise `MaxBGFPS` in eqclient.ini to 30–60 so background clients react faster (see [Making switching faster](#making-switching-faster)). After each mirrored click the app shows **"Mirrored Left click to N client(s)"**. If N is 0, the other clients couldn't be brought to the front, so check the app is running as administrator.
- `[Mirror]` settings: `MarkerColor`, `ClickDelay`, `HoldTime` (how long the button is held, default 40 ms), `StayDelay` (how long to stay in the client you clicked in before hopping away, default 50 ms), `ShowFeedback`.

### Mouse button 4 (one-off mirrored click)
Press **mouse button 4** (the back button on the side of most mice) over a client to make one mirrored left-click there and in every other client, without turning mirror mode on. Change or disable it with `MouseBroadcast=` in `[Hotkeys]` (leave it empty to disable).

## Clickable views (Video FX)
*Not available for EVE Online, whose rules don't allow overlays that act in other clients.*

A **view** is a live copy of part of one client, shown anywhere on screen. **Clicking the copy clicks the real button in the source client.** This is how you use slot 2's hotbar from slot 1.

### The Clickable Views window
Open it with **Ctrl+Alt+E**, the **Edit Views** button on the toolbar, or **Clickable Views...** in the control panel. It lists every view and lets you:
- **New View...:** make a view (see [Create a view](#create-a-view)).
- **Change Area...:** pick a new area for the selected view to copy, from any client.
- **Move / Resize...:** drag a new box for where the selected view is shown, or just click to move it without changing its size.
- **Rename...** (or double-click a view), **Delete**, **Delete All...**
- **Show Where:** flashes a red box where the selected view is.
- **Copies from slot:** make the selected view copy the same area from a different client.
- **Opacity:** how see-through the selected view is.
- **Show views**, **Show views when MMORPG Boxer starts**, and **Clicking a view** (Switch, Send or Focus; see [View settings](#view-settings)).

The window hides itself while you drag boxes on screen and comes back afterwards.

### Create a view
1. Click **New View...** in the Clickable Views window, or press **Ctrl+Alt+C**. The screen dims.
2. **Step 1:** drag a red box around the area to copy, for example slot 2's hotbar.
3. **Step 2:** drag a box where the copy should appear, for example a corner of slot 1. Or just **click once** to place it at the same size.
4. The view appears immediately and is saved in `[VFX]`.

Press **Esc** at either step to cancel.

### Use it
- **Left- or right-click** a button in the view. The app switches to the source client, clicks the real button, then switches back with the mouse where it was.
- Modifier keys you hold (Shift, Ctrl, Alt) still apply to the click.

### Shortcuts and the config file
- **Ctrl+Alt+D:** delete the view under the mouse.
- **Ctrl+Alt+V:** hide or show all views.
- Each view is one line in `[VFX]` that you can edit by hand:
  ```
  View1=2|0,950,600,80|1300,950,600,80|255
  ```
  The parts are: source slot | source x,y,w,h (in a 1920×1080 client) | destination x,y,w,h (screen) | opacity 0–255.

### View settings
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

## Team and Performance
Open **Team & Performance...** in the control panel or the tray menu. It lists every slot. Click one, change its settings, then click **Save**.

CPU cores and priority work for every game. In-game names, team commands, frame-rate caps and the separate settings file per character are EverQuest only.

### In-game names
Type each slot's **character name as it is in EverQuest** (for example *Danadaf*). Follow and assist use it to target that character. The slot's label (*Tank*, *Healer*) can stay as it is.

### Team commands (follow, assist, formations)
Use the **Team** button on the toolbar, **Team Commands...** in the control panel, or the hotkeys. They act from the client you're in, and the app types EverQuest's own commands into each other client in turn, the same way broadcast reaches them.

| Command | Default hotkey | What every other client does |
|---|---|---|
| Follow me | Ctrl+Alt+F | `/target <you>` then `/follow` |
| Follow in a line | (none) | Each follows the one before it, in slot order: a line behind you instead of a crowd |
| Stop following | Ctrl+Alt+X | Taps the walk-backwards key (`StopFollowKey`, default Down arrow), which breaks `/follow` |
| Assist me | Ctrl+Alt+T | `/assist <you>` (takes your target) |
| Attack my target | (none) | `/assist <you>` then `/attack on` |
| Back off | (none) | `/attack off` |
| Everyone sit / stand | (none) | `/sit on` / `/sit off` (you too) |

Give any of them a hotkey in `[Hotkeys]`: `FollowMe`, `FollowLine`, `StopFollow`, `AssistMe`, `AttackMyTarget`, `BackOff`, `SitAll`, `StandAll`.

The commands are typed into the chat box (Enter, the command, Enter), so leave the chat box empty. EverQuest needs a background frame rate of about 25 or more for `/follow` to keep up (see [Frame-rate caps](#frame-rate-caps)).

### CPU cores and priority
- **CPU cores:** `all` (normal), or the logical core numbers the client may use, for example `0-3` or `4-11,14`. The tooltip shows how many cores your PC has.
- **Priority:** Normal, Above normal, High or Below normal.
- **Auto-assign CPU Cores** gives your main slot (slot 1, or `MainSlot` in `[CPU]`) about a quarter of the cores to itself, at Above normal priority, and lets the other clients share the rest. **Reset CPU to Normal** undoes it.
- Settings apply straight away to running clients and to every client as it starts. Most PCs run fine with everything on `all`; try auto-assign if your main stutters when every client is busy.

### Frame-rate caps
**Max FPS** has two boxes: the cap while the client is the one you're in, and the cap while it's in the background. They're EverQuest's own settings (`MaxFPS` and `MaxBGFPS`), written for that client before it starts, so a change takes effect the next time the client starts. Leave both blank to keep what you set in EverQuest (Alt+O → Display). Lower background caps save CPU and graphics power, but keep them at about 25 or more so `/follow` works.

### Separate EverQuest settings for each character
With **Separate EverQuest settings file for each character** ticked (the default), each character keeps its own `eqclient.ini` (and `eqlsPlayerData.ini`, which holds the login screen's choices) in the **Profiles** folder next to the app:
- Before a client starts, its character's own copy is put in place, so each character keeps its own graphics settings, window size and frame-rate caps.
- While you play, EverQuest's `eqclient.ini` holds the settings of the client you're in. When that client re-reads it (for example when you log out to server select), it gets its own resolution, not another slot's. That stops the stretched picture after logging out.
- When EverQuest saves its settings, they go back into the copy of the client that saved them.
- The first time, every character starts from a copy of your current `eqclient.ini`, and the original is backed up to `Profiles\_original`.
- Profiles are named after the in-game name, or the slot's character label if there isn't one. Changing the name starts a new profile from the current settings.

This works by swapping files; nothing is injected into the game.

## Key maps
*EverQuest only.*

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

## Configuration reference (MMORPGBoxer.ini)
Keep comments on their own lines. A `;` after a value becomes part of the value. After editing, press **Ctrl+Alt+R**.

EverQuest's settings are in `MMORPGBoxer.ini`; each other game has its own `MMORPGBoxer-<game>.ini` with the same sections. `[General] Game` in `MMORPGBoxer.ini` holds the game that's chosen.

### [General]
| Key | Default | Meaning |
|---|---|---|
| Game | `EverQuest` | (MMORPGBoxer.ini only) the chosen game: `EverQuest`, `EverQuest II`, `Monsters & Memories` or `EVE Online` |
| EQPath | `C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest` | The game's folder (for the other games, the folder with its launcher) |
| EQExe | `eqgame.exe` | Game executable (`EverQuest2.exe`, `mnm.exe`, `exefile.exe`) |
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
| ShowPanelOnStart | `1` | Open the control panel when MMORPG Boxer starts |
| ShowTooltips | `1` | Show what each button does and its shortcut when you point at it |
| Appearance | `System` | `System` (follow Windows' app mode), `Light` or `Dark` |
| RunAsAdmin | `1` | Restart MMORPG Boxer as administrator (needed when EverQuest runs as admin) |

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
`MarkerColor` (RRGGBB), `ClickDelay` (ms to let a client notice the pointer before clicking, default 60), `HoldTime` (ms the button is held, default 40), `StayDelay` (ms to stay in the client you clicked in before hopping to the others, default 50), `ShowFeedback` (1/0). Clickable views use the same click settings.

### [Highlight]
`Enabled` (1/0), `Color` (RRGGBB), `Thickness` (pixels): the frame around the active client.

### [Grid]
`Columns`, `Width`, `Height`: grid shape and cell size.

### [Layout.Name]
Your own layouts: `slot=x,y,width,height`, in pixels from the monitor's top-left. Created by **Save Layout...** or by hand.

### [SwapLayout]
`Main` and `Small1`–`Small7` as `x,y,width,height`, relative to the monitor's top-left.

### [Broadcast]
`Mode` (Whitelist/Blacklist), `Keys`, `Method` (Switch/Send), `SwitchDelay`, `StayDelay` (ms to stay in the client you pressed the key in before hopping to the others, default 50), `ShowFeedback` (1 = show "Broadcast 1 -> 4 client(s)" after each key).

### [Profiles]
`PerCharacter` (1/0, EverQuest): each character keeps its own eqclient.ini in the Profiles folder. See [Team and Performance](#team-and-performance).

### [InGameNames]
`slot=character name in EverQuest`, used by follow and assist.

### [CPU]
`Slot<n>` (`all`, or core numbers like `0-3,8`), `Priority<n>` (Normal, Above normal, High, Below normal), `MainSlot` (the slot Auto-assign gives cores of its own).

### [FPS]
`Slot<n>=<active>,<background>` (EverQuest): frame-rate caps written into eqclient.ini before the client starts. Empty = keep EverQuest's own.

### [Team]
`StopFollowKey` (default `Down`): the key that walks backwards and breaks `/follow`.

### [Hotkeys]
See the [hotkey reference](#hotkey-reference). Leave a value empty to disable that hotkey.

### [KeyMap.Name]
See [Key maps](#key-maps).

### [VFX]
See [Clickable views](#clickable-views-video-fx).

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| An error message when MMORPG Boxer starts | Update to the latest version (download the installer from the releases page if the app can't start), and send the message if it persists. |
| Mouse lines up in only one client | Set the DPI override to **Application** (see [Turn off Windows scaling](#turn-off-windows-scaling-for-everquest-required-on-4k)). Then close **all** clients and relaunch with the app running, so each one starts in its slot. |
| Mouse is off in one client | That client was moved after it started. Close it and relaunch it with the app running. Don't drag clients. |
| One client draws a smaller picture than its window (black space right and below) | It was arranged while still starting up. **Quick fix:** in that client press Alt+O → Display and choose its windowed resolution again, or close it and start it again. To prevent it, raise `SettleTime` (try 20000) and start clients with Launch All. |
| A client draws a small picture with black around it, or looks stretched after Arrange | EverQuest doesn't redraw when its window is resized while it's running. Close that client and start it again. |
| A client's picture keeps changing size | That slot's window may be too wide for EverQuest (full-width slots). Use a layout whose slots are 1920×1080 or smaller (for example Top Center + 2 Bottom). |
| A client looks stretched or squashed | EverQuest's own size doesn't match its window. Make sure `WindowedWidth/Height` match the grid `Width/Height`, then restart that client, or re-select 1920×1080 in Alt+O → Display. |
| All clients open on top of each other | They were started too quickly from LaunchPad. Start them one at a time, or use Launch All. |
| A client isn't arranged | It's still settling (wait about 15 s), it's beyond the `Slots` count, or it kept fighting the layout. Press Ctrl+Alt+G. |
| Launch All says it can't find eqgame.exe | Fix `EQPath`. |
| Launch All starts the client but it closes | The game needs patching. Run LaunchPad once, then try again. |
| Broadcast or key maps do nothing | Run MMORPG Boxer as administrator (`RunAsAdmin=1`, accept the Windows prompt). Then see [If broadcasting still doesn't work](#if-broadcasting-still-doesnt-work). |
| Typing in chat spams other clients | Pause the app with Ctrl+Alt+P while typing, or turn broadcast off. |
| A hotkey error appears at startup | A hotkey in the INI is invalid. Fix or clear it. |
| Views are black | The source client is minimized or closed. |
| A client's picture is stretched or cut off after logging out or changing screens | EverQuest reloaded another slot's resolution from the shared eqclient.ini. The app re-syncs the client automatically a few seconds later; if it doesn't, press **Ctrl+Alt+G** (Arrange). |
| A view shows a different area than you selected | Send MMORPGBoxer.log: it has a "view ..." line for each view showing how it lined up. |
| A view click lands in the wrong place | Delete it (Ctrl+Alt+D) and re-create it after the clients are arranged. |
| Account name isn't filled in | Set it in the control panel (click the slot, type the Account name, Save), and start clients with **Launch All**. Clients started from LaunchPad don't get it. |
| Control panel says "opened off-slot, restart it" | That client opened somewhere other than its slot, so its mouse is off. Close it and start it again with MMORPG Boxer running. Start clients one at a time, or use Launch All. |
| Clients stay muted after MMORPG Boxer crashed | Open the Windows Volume Mixer and unmute the `eqgame.exe` entries, or start MMORPG Boxer and press Ctrl+Alt+O twice. |
| Nothing responds | The app may be paused (Ctrl+Alt+P), or not running. Check for the tray icon. |
| A button is greyed out, or a hotkey only shows "isn't available for ..." | The chosen game's rules don't allow that feature (see [Supported games](#supported-games)). |
| EverQuest II, Monsters & Memories or EVE Online: Launch All can't find the launcher | Set the game's folder in the Setup Wizard (Ctrl+Alt+W): the folder with `LaunchPad.exe`, `MnMLauncher.exe` or `eve-online.exe`. |
| EverQuest II, Monsters & Memories or EVE Online: a window keeps jumping back to its own size | Play in windowed mode and set the game's windowed resolution to the slot's size. Send MMORPGBoxer.log if it keeps happening. |

## Updates and diagnostics
### Updates
MMORPG Boxer updates itself from its GitHub releases.
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
If windows don't end up where they should, click **Diagnostics...** in the control panel (or the tray menu). It writes **MMORPGBoxer-diagnostics.txt** next to the script, opens it in Notepad, and copies it to the clipboard. It shows:
- your screen, border size and eqclient.ini values,
- for every slot, where it **should** be and where its window and picture **actually** are,
- the recent **MMORPGBoxer.log**: every client found, settled, arranged, and anything that moved it afterwards (with a check 1 s and 5 s after each arrangement).

Send that file to whoever is helping you fix a layout problem. The log is cleared automatically when it grows past 1 MB.

## Rules and fair play
- MMORPG Boxer never plays for you: nothing runs unless you press a key or click, and there are no timed sequences or automation.
- For each game it only offers what that game's publisher allows (see [Supported games](#supported-games)): broadcasting and mirroring for EverQuest; one key or click acting in one client for EverQuest II and Monsters & Memories; window layout and switching for EVE Online.
- No publisher officially endorses any multiboxing software. Use the features at your own risk, and check your server's rules: some servers (for example EverQuest's True Box progression servers, or Monsters & Memories' no-boxing servers) limit or forbid running several accounts on one PC.

### Official rules for each game
These are the publishers' own pages on boxing, third-party software and unattended play. The rules can change, so check them before you play. If a link has moved, please [open an issue](https://github.com/Rav8es/MMORPGBoxer/issues). Links checked November 2026.

**EverQuest** (Daybreak Game Company)
- [EverQuest Rules of Conduct and Play Nice Policies](https://help.daybreakgames.com/hc/en-us/articles/230629007-What-are-the-EverQuest-Rules-of-Conduct)
- [AFK or unattended gameplay](https://help.daybreakgames.com/hc/en-us/articles/231115088-EverQuest-AFK-or-Unattended-Gameplay-): every character must be played while you're at the keyboard.
- [What isn't allowed on True Box and other special-rules servers](https://help.daybreakgames.com/hc/en-us/articles/230630767): extra limits on some progression servers, including how many characters you may box.
- [Regarding Third Party Cheat Programs](https://forums.daybreakgames.com/eq/index.php?threads/regarding-third-party-cheat-programs.250451/): the EverQuest team's forum post on third-party programs.
- [EverQuest End User License Agreement](https://lpj.daybreakgames.com/eq/live/) and [Daybreak Terms of Service](https://www.daybreakgames.com/terms-of-service)
- Not official: [Fanra's EverQuest Wiki, Utilities](https://everquest.fanra.info/wiki/Utilities) collects Daybreak staff answers on third-party programs, including that window management and key replication (but not automation) are allowed.

**EverQuest II** (Daybreak Game Company)
- [EverQuest II Rules of Conduct](https://help.daybreakgames.com/hc/en-us/articles/230625747-What-are-the-EverQuest-II-Rules-of-Conduct)
- [AFK or unattended gameplay](https://help.daybreakgames.com/hc/en-us/articles/230625867-What-is-the-EverQuest-II-policy-on-AFK-or-Unattended-Gameplay)
- [EverQuest II End User License Agreement](https://lpj.daybreakgames.com/eq2/live/) and [Daybreak Terms of Service](https://www.daybreakgames.com/terms-of-service)
- The 2009 statement that boxing is allowed but software issuing simultaneous commands to several characters isn't. The original post on the old SOE forums is gone; [EQ2Wire's article](https://eq2wire.com/?p=2689) quotes it. MMORPG Boxer follows it, which is why broadcasting is off for EverQuest II.

**Monsters & Memories** (Niche Worlds Cult)
- [Early Access FAQ, "What servers are available?"](https://monstersandmemories.com/early-access-faq): Nunavoth (US PvE, 3 box) is the only server that allows boxing; the others are no boxing.
- [What counts as boxing](https://account2.monstersandmemories.com/community/faqs?search=boxing) (official FAQ)
- [Play Nice Policy](https://account2.monstersandmemories.com/policy/pnp)
- [Master User Agreement](https://account2.monstersandmemories.com/policy/mau)

**EVE Online** (CCP Games)
- [Update regarding Multiboxing and input automation](https://forums-archive.eveonline.com/message/5241022) (CCP Falcon, 2014): multiboxing is allowed; input broadcasting and multiplexing of actions that affect the game are banned.
- [Third Party Policies](https://support.eveonline.com/hc/en-us/articles/8564030965660-Third-Party-Policies): third-party software and client modification.
- [Third party applications](https://support.eveonline.com/hc/en-us/articles/5888034246428-Third-party-applications): CCP's summary, with links to the EULA and Terms of Service.
