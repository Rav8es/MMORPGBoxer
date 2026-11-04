#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
; =====================================================================
;  MMORPG Boxer - a multiboxing tool for EverQuest Live
;
;  Features
;    - Character slots and a launcher (Launch All)
;    - Two window layouts: Grid, and Swap (focused client in a big main
;      region, the rest in small regions; click a small one to swap it in)
;    - Instant client switching hotkeys and slot reassignment
;    - Key maps with targets (All / Others / Active / slot / group) and
;      round-robin steps
;    - Keyboard broadcasting (whitelist or blacklist, key down/up so
;      movement works)
;    - Mouse broadcasting (one click -> same spot in every client)
;    - Video FX: live views of part of one client shown anywhere on screen
;      (Windows DWM thumbnails - no injection into the game)
;    - Control panel and tray menu
;
;  Everything is configured in MMORPGBoxer.ini (created on first run).
;  Design rule: one key press = one action per client. No delays, no
;  timed sequences, nothing runs without you pressing a key.
; =====================================================================

SetWinDelay(0)
SetControlDelay(-1)
SetKeyDelay(-1, -1)
CoordMode("Mouse", "Client")
CoordMode("ToolTip", "Screen")
CoordMode("Pixel", "Screen")

global APP := "MMORPG Boxer"
global APP_VERSION := "1.8.1"
; GitHub repository ("owner/name") that updates are published to
global DEFAULT_UPDATE_REPO := "Rav8es/MMORPGBoxer"
global OLD_UPDATE_REPO := "Rav8es/BoxerPro"     ; its name before the rename
; installed copies ship an icon next to the script
if FileExist(A_ScriptDir "\MMORPGBoxer.ico")
    TraySetIcon(A_ScriptDir "\MMORPGBoxer.ico")
; MMORPGBoxer.ini holds the EverQuest setup and which game is chosen
; ([General] Game). Other games keep their own file, MMORPGBoxer-<game>.ini.
global MAIN_CFG := A_ScriptDir "\MMORPGBoxer.ini"
global LOG_FILE := A_ScriptDir "\MMORPGBoxer.log"     ; window placement log (Diagnostics)
; This app used to be called EQ Boxer Pro: pick up its settings and log.
if (!FileExist(MAIN_CFG) && FileExist(A_ScriptDir "\EQBoxer.ini"))
    try FileCopy(A_ScriptDir "\EQBoxer.ini", MAIN_CFG)
if (!FileExist(LOG_FILE) && FileExist(A_ScriptDir "\EQBoxer.log"))
    try FileCopy(A_ScriptDir "\EQBoxer.log", LOG_FILE)
global GAME := GameIdOf(IniRead(MAIN_CFG, "General", "Game", "EverQuest"))
global GameDef := GameInfo(GAME)
global CFG_FILE := (GAME = "EverQuest") ? MAIN_CFG : A_ScriptDir "\MMORPGBoxer-" GAME ".ini"
if !FileExist(CFG_FILE) {
    WriteDefaultConfig()
    if (GAME != "EverQuest")
        WriteGameDefaults()
}

; EverQuest usually runs as administrator. Windows then blocks a normal
; program from seeing keys pressed in it or sending keys to it, so the
; boxer must run as administrator too.
if (!A_IsAdmin && Cfg("General", "RunAsAdmin", "1") = "1") {
    try {
        Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        ExitApp()
    }
}

; Number of client slots in use (1-8), set in [General] Slots= or the control panel
global MAX_SLOTS := Max(1, Min(GameDef.maxSlots, ToInt(Cfg("General", "Slots", "4"), 4)))

; ------------------------------ Settings ------------------------------
global EQPath         := Cfg("General", "EQPath", GameDef.folder)
global EQExe          := Cfg("General", "EQExe", GameDef.exe)
global LaunchArgs     := Cfg("General", "LaunchArgs", "patchme")
; Older versions used 4000 / 8000. Those were too short: a client was still
; starting up when the next one launched or when its borders were removed,
; and it then drew a smaller picture than its window. Raise old defaults.
if (Cfg("General", "LaunchDelay", "") = "4000")
    IniWrite(12000, CFG_FILE, "General", "LaunchDelay")
if (Cfg("General", "SettleTime", "") = "8000")
    IniWrite(15000, CFG_FILE, "General", "SettleTime")
global LaunchDelay    := ToInt(Cfg("General", "LaunchDelay", "12000"), 12000)
global MonitorNum     := ToInt(Cfg("General", "Monitor", "1"), 1)
global Layout         := Cfg("General", "Layout", "Grid")   ; Grid, Swap, or a preset name
global AutoArrange    := Cfg("General", "AutoArrange", "1") = "1"
global HideBorders    := Cfg("General", "HideBorders", "1") = "1"
global SwapOnActivate := Cfg("General", "SwapOnActivate", "1") = "1"
; Wait until a new client's window size has been stable this long (ms)
; before arranging it - EverQuest resizes itself while starting up.
global SettleTime     := ToInt(Cfg("General", "SettleTime", "15000"), 15000)
; Write the next free slot's position/size into eqclient.ini before a client
; starts, so EverQuest opens right in its slot (keeps the mouse aligned).
global PrepareIni     := GameDef.eqIni && Cfg("General", "PrepareIni", "1") = "1"
; Fit layouts inside the area above the taskbar instead of the whole screen
global UseWorkArea    := Cfg("General", "UseWorkArea", "1") = "1"
global EQ             := "ahk_exe " EQExe

global GridCols := ToInt(Cfg("Grid", "Columns", "2"), 2)
global GridW    := ToInt(Cfg("Grid", "Width", "1920"), 1920)
global GridH    := ToInt(Cfg("Grid", "Height", "1080"), 1080)

global MainRegion := ParseRect(Cfg("SwapLayout", "Main", "0,0,2880,1620"))
global SmallRegions := []
Loop MAX_SLOTS {
    r := Cfg("SwapLayout", "Small" A_Index, "")
    if (r = "")
        break
    SmallRegions.Push(ParseRect(r))
}

; ---------------------------- Layout presets ----------------------------
; Each preset maps slot number -> rect {x, y, w, h} relative to the monitor.
global Presets := Map()
Presets.CaseSense := false
global PresetOrder := []
global BuiltinLayouts := ["Grid", "Swap"]   ; layouts that can't be deleted
LoadPresets()
if !(Layout = "Grid" || Layout = "Swap" || Presets.Has(Layout))
    Layout := "Grid"
global LayoutDDL := 0

global Chars := []
Loop MAX_SLOTS
    Chars.Push(Cfg("Characters", String(A_Index), ""))

global Groups := Map()
Groups.CaseSense := false
for line in StrSplit(CfgSection("Groups"), "`n") {
    kv := StrSplit(line, "=", , 2)
    if (kv.Length < 2)
        continue
    arr := []
    for s in StrSplit(kv[2], ",", " `t")
        if IsInteger(s)
            arr.Push(Integer(s))
    Groups[Trim(kv[1])] := arr
}

; ------------------------------- State --------------------------------
global Slots := []               ; Slots[n] = window ID of the client in slot n (0 = empty)
Loop MAX_SLOTS
    Slots.Push(0)
global MainSlot := 1             ; client shown in the main region (Swap layout)
global Broadcasting := false
global VFXOn := false
global Launching := false
global ForceResync := false
global Enforcing := false
global Settle := Map()       ; id -> {w, h, t, ok}  start-up settle tracking
global Fixes := Map()        ; id -> [tick, ...]    recent auto-corrections
global ArrangedAt := Map()   ; id -> when it was last arranged
global ClipFor := Map()      ; id -> picture area the window is clipped to
global StripFallback := Map() ; id -> true: clip didn't hold, remove title bar instead
global KeepFrame := Map()     ; id -> true: "Restore borders" - leave its frame visible until the next Arrange
global Placed := Map()       ; id -> true once a client has been arranged
global Unmanaged := Map()    ; id -> true           clients we stopped fighting
global KeyMaps := []
global KeyMapBaseKeys := Map()
KeyMapBaseKeys.CaseSense := false
global BcKeys := []
global BcHotkeys := []       ; hotkey names created for broadcasting
global BcHeld := Map()       ; keys currently held (ignore auto-repeat)
global BcMethod := (Cfg("Broadcast", "Method", "Switch") = "Send") ? "Send" : "Switch"
global Switching := false
global AudioFollow := false  ; sound only from the client you're playing in
global AudioPid := 0         ; process that currently has sound
global Mirroring := false    ; mirror mode: clicks are repeated in every client
global MirrorDots := Map()   ; slot -> marker window    ; true while hopping between clients
global VFX := []
global AccGui := 0, AccDDL := 0, AccName := 0, AccUser := 0, AccInfo := 0
global Wiz := 0              ; Setup Wizard state
global StartPos := Map()     ; id -> {x, y} where the client first opened
global OffSlotWarned := Map()
global TB := 0, TBBtns := Map(), TBVertical := false, TBPos := 0
global HL := []              ; active-client frame pieces
global HLLast := ""
global VfxByHwnd := Map()    ; view overlay window -> view
global Panel := 0, LV := 0, SB := 0
global PanelSel := 1, PEName := 0, PEUser := 0, PESlot := 0, PEInfo := 0, PERes := 0
global VM := 0                ; Clickable Views window and its controls
global TipsOn := Cfg("General", "ShowTooltips", "1") = "1"
global Tips := Map()          ; control hwnd -> tooltip text
global TipHwnd := 0           ; control the pointer is over
global ProfilesOn := GameDef.eqIni && Cfg("Profiles", "PerCharacter", "1") = "1"
global IniHolder := 0         ; slot whose own settings eqclient.ini holds right now
global IniStamp := ""         ; eqclient.ini's time/size when we last wrote or saved it
global LastClosed := {n: 0, t: 0}   ; the slot whose client closed most recently
global CpuDone := Map()       ; id -> CPU settings applied to that client
global PF := 0                ; Team & Performance window
global Appearance := Cfg("General", "Appearance", "System")   ; System | Light | Dark
global Hints := Map()         ; control hwnd -> grey hint text
global NoTheme := Map()       ; control hwnd -> keeps its own colours
global ThemedGuis := []       ; windows that follow the appearance setting
global LVDrawn := Map()       ; ListViews that draw their own selection colours
global DarkNow := false       ; dark appearance currently applied
global LW := 0                ; Layouts window

; ------------------------------ Hotkeys -------------------------------
; App hotkeys first (they take priority over broadcast hotkeys on the same key).
focusMod  := Cfg("Hotkeys", "FocusSlotModifier", "^")
assignMod := Cfg("Hotkeys", "AssignSlotModifier", "^!")
Loop MAX_SLOTS {
    n := A_Index
    TryHotkey(focusMod "F" n, FocusSlot.Bind(n))
    TryHotkey(assignMod "F" n, AssignSlot.Bind(n))
}
BindHotkey("NextClient",      "^!n", FocusNext)
BindHotkey("ToggleBroadcast", "^!b", ToggleBroadcast)
BindHotkey("Arrange",         "^!g", ManualArrange)
BindHotkey("ToggleLayout",    "^!s", ToggleLayout)
BindHotkey("RestoreBorders",  "^!u", RestoreBorders)
BindHotkey("ControlPanel",    "^!h", TogglePanel)
BindHotkey("ToggleVFX",       "^!v", ToggleVFX)
BindHotkey("CreateView",      "^!c", CreateView)
BindHotkey("DeleteView",      "^!d", DeleteView)
BindHotkey("ViewManager",     "^!e", ShowViews)
BindHotkey("LayoutsWindow",   "",    ShowLayouts)
BindHotkey("FollowMe",        "^!f", TeamDo.Bind("follow"))
BindHotkey("StopFollow",      "^!x", TeamDo.Bind("stop"))
BindHotkey("AssistMe",        "^!t", TeamDo.Bind("assist"))
BindHotkey("FollowLine",      "",    TeamDo.Bind("line"))
BindHotkey("AttackMyTarget",  "",    TeamDo.Bind("attack"))
BindHotkey("BackOff",         "",    TeamDo.Bind("backoff"))
BindHotkey("SitAll",          "",    TeamDo.Bind("sit"))
BindHotkey("StandAll",        "",    TeamDo.Bind("stand"))
BindHotkey("LaunchAll",       "^!l", LaunchAll)
BindHotkey("Accounts",        "^!a", ShowAccounts)
BindHotkey("ReloadConfig",    "^!r", (*) => Reload(), "S")
BindHotkey("Pause",           "^!p", TogglePause, "S")
BindHotkey("Quit",            "^!q", (*) => ExitApp(), "S")

HotIfWinActive(EQ)
Hotkey("~LButton up", MirrorUp.Bind("Left"), "Off")
Hotkey("~RButton up", MirrorUp.Bind("Right"), "Off")
HotIfWinActive()
BindHotkey("ToggleMirror",    "^!m", ToggleMirror)
BindHotkey("ToggleToolbar",   "^!k", ToggleToolbar)
BindHotkey("ToggleAudio",     "^!o", ToggleAudio)
BindHotkey("SetupWizard",     "^!w", ShowWizard)

mouseKey := Cfg("Hotkeys", "MouseBroadcast", "XButton1")
if (mouseKey != "" && GameDef.together) {
    HotIfWinActive(EQ)
    TryHotkey(mouseKey, MouseBroadcast)
    HotIfWinActive()
}

LoadKeyMaps()
; EverQuest hotbars have 12 buttons (1-0, - and =). Older configs only
; listed 1-0, so add the last two if the list is still the old default.
if (StrReplace(Cfg("Broadcast", "Keys", ""), " ") = "1,2,3,4,5,6,7,8,9,0")
    IniWrite("1,2,3,4,5,6,7,8,9,0,-,=", CFG_FILE, "Broadcast", "Keys")
SetupBroadcast()
LoadVFX()
OnMessage(0x201, VfxMouse)   ; WM_LBUTTONDOWN on a view
OnMessage(0x204, VfxMouse)   ; WM_RBUTTONDOWN on a view
OnMessage(0x201, ToolbarLButton)   ; drag the toolbar
OnMessage(0x200, TipMouseMove)     ; WM_MOUSEMOVE: tooltips on buttons
OnMessage(0x1A, OnSettingChange)   ; WM_SETTINGCHANGE: Windows light/dark mode
ApplyMenuTheme()
OnMessage(0x232, ToolbarMoved)     ; WM_EXITSIZEMOVE: save toolbar position

; ------------------------------ Tray menu -----------------------------
A_IconTip := APP " " APP_VERSION
A_TrayMenu.Delete()
A_TrayMenu.Add("Control Panel", TogglePanel)
A_TrayMenu.Add("Show/Hide Toolbar", ToggleToolbar)
A_TrayMenu.Add("Launch All", LaunchAll)
A_TrayMenu.Add("Characters && Accounts...", ShowAccounts)
A_TrayMenu.Add("Layouts...", ShowLayouts)
A_TrayMenu.Add("Clickable Views...", ShowViews)
A_TrayMenu.Add("Team && Performance...", ShowPerf)
A_TrayMenu.Add("Setup Wizard...", ShowWizard)
A_TrayMenu.Add("Diagnostics...", Diagnostics)
A_TrayMenu.Add("Check for Updates...", (*) => CheckForUpdates(false))
A_TrayMenu.Add("Online Guide", OpenGuide)
A_TrayMenu.Add("Arrange", ManualArrange)
A_TrayMenu.Add("Edit Config", EditConfig)
A_TrayMenu.Add("Reload Config", (*) => Reload())
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Control Panel"

OnExit(Cleanup)
try {
    if (FileGetSize(LOG_FILE) > 1000000)
        FileDelete(LOG_FILE)
}
WriteLog("===== " APP " started (admin=" (A_IsAdmin ? "yes" : "no") ", layout=" Layout ", slots=" MAX_SLOTS ")")
MigrateCredentials()
try IniDelete(CFG_FILE, "General", "ClientInset")   ; from the reverted border-measuring version
InitHighlight()
BuildPanel()
BuildToolbar()
if (Cfg("Toolbar", "Show", "1") = "1")
    ShowToolbar()
HotIf(MouseOverToolbar)
Hotkey("^WheelUp", ToolbarResize.Bind(1))
Hotkey("^WheelDown", ToolbarResize.Bind(-1))
Hotkey("+WheelUp", ToolbarOpacity.Bind(10))
Hotkey("+WheelDown", ToolbarOpacity.Bind(-10))
HotIf()
AudioFollow := Cfg("Audio", "FollowActive", "1") = "1"
SetTimer(AudioTick, 250)
UpdateToolbar()
WatchClients()
SetTimer(WatchClients, 1000)
SetTimer(CheckActive, 150)
SetTimer(ClipGuard, 300)               ; keep hidden title bars hidden
SetTimer(ProfileTick, 500)             ; per-character eqclient.ini
; Open the control panel when the app starts ([General] ShowPanelOnStart)
if (Cfg("General", "ShowPanelOnStart", "1") = "1" && !DllCall("IsWindowVisible", "Ptr", Panel.Hwnd))
    TogglePanel()
; Look for a newer version a little after start-up ([Update] CheckOnStart)
if (Cfg("Update", "CheckOnStart", "1") = "1")
    SetTimer(() => CheckForUpdates(true), -15000)
; First start (or never finished): open the Setup Wizard
if (Cfg("General", "WizardDone", "") != "1")
    SetTimer(ShowWizard, -500)
Status(APP " ready" (A_IsAdmin ? " (admin)" : " (NOT admin - broadcast may not work)") " - "
    . CountClients() " client(s). Ctrl+Alt+H opens the control panel.", 5000)

; =====================================================================
;                               Functions
; =====================================================================

; -------------------------------- Games --------------------------------
; What MMORPG Boxer knows about each game, and which features the game's
; rules allow. together = features where one key press or click acts in
; several clients (broadcast, mirror mode, team commands, key maps).
GameInfo(id) {
    ; Fields: exe (the game client), folder (where to look by default),
    ; launchers (started instead of the client when the game logs in through
    ; its own launcher), maxSlots, defSlots, defLayout, together (one key
    ; press or click may act in several clients: broadcast, mirror, team
    ; commands, key maps), views (clickable views allowed), eqIni and
    ; loginArg (EverQuest's eqclient.ini features and /login:), titles
    ; (MMORPG Boxer may rename the windows "EQ<slot> - <name>"), settle (ms),
    ; why (shown when a feature is left out) and rules (wizard page 1).
    switch id {
        case "MonstersAndMemories":
            return {id: id, name: "Monsters & Memories", exe: "mnm.exe", folder: "C:\MnM"
                , launchers: ["MnMLauncher.exe", "mnm_launcher.exe"], maxSlots: 3, defSlots: 3, defLayout: "Top + 2 Bottom"
                , together: false, views: true, eqIni: false, loginArg: false, titles: true, settle: 10000
                , why: "every character must be played by hand"
                , hint: "Boxing: 3-box server only, every character by hand."
                , rules: "Monsters & Memories allows boxing only on its 3-box server (Nunavoth), and every character must be played by hand. "
                    . "So for this game MMORPG Boxer leaves out broadcasting, mirror mode, team commands and key maps, and allows at most 3 slots."}
        case "EverQuest2":
            return {id: id, name: "EverQuest II", exe: "EverQuest2.exe"
                , folder: "C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest II"
                , launchers: ["LaunchPad.exe"], maxSlots: 8, defSlots: 4, defLayout: "Grid"
                , together: false, views: true, eqIni: false, loginArg: false, titles: true, settle: 15000
                , why: "Daybreak's policy for EverQuest II doesn't allow software to send one command to several characters"
                , hint: "Boxing allowed; one key = one character."
                , rules: "EverQuest II allows boxing, but Daybreak's stated policy is that software may not issue simultaneous commands to several characters. "
                    . "So for EverQuest II MMORPG Boxer leaves out broadcasting, mirror mode, team commands and key maps. Layouts, switching, clickable views, sound and CPU settings work as usual."}
        case "EVEOnline":
            return {id: id, name: "EVE Online", exe: "exefile.exe", folder: EnvGet("LOCALAPPDATA") "\eve-online"
                , launchers: ["eve-online.exe", "evelauncher.exe"], maxSlots: 8, defSlots: 4, defLayout: "Grid"
                , together: false, views: false, eqIni: false, loginArg: false, titles: false, settle: 10000
                , why: "CCP bans input broadcasting and multiplexing, and overlays that act in other clients"
                , hint: "Window layout and switching only."
                , rules: "EVE Online allows multiboxing, but CCP bans input broadcasting and multiplexing, and overlays that use parts of other clients to act in them. "
                    . "So for EVE MMORPG Boxer leaves out broadcasting, mirror mode, team commands, key maps and clickable views. Arranging, switching and sound work as usual (CCP allows window positions and arrangements)."}
    }
    return {id: "EverQuest", name: "EverQuest", exe: "eqgame.exe"
        , folder: "C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest"
        , launchers: [], maxSlots: 8, defSlots: 4, defLayout: "Grid"
        , together: true, views: true, eqIni: true, loginArg: true, titles: true, settle: 15000
        , why: "", hint: "Each game keeps its own setup.", rules: ""}
}

GameIds() => ["EverQuest", "EverQuest2", "MonstersAndMemories", "EVEOnline"]

GameNames() {
    names := []
    for id in GameIds()
        names.Push(GameInfo(id).name)
    return names
}

; game id from its name (as shown, or as saved in [General] Game)
GameIdOf(name) {
    for id in GameIds()
        if (name = id || name = GameInfo(id).name)
            return id
    return InStr(name, "Monsters") ? "MonstersAndMemories" : "EverQuest"
}

GameIndex() {
    for i, id in GameIds()
        if (id = GAME)
            return i
    return 1
}

; Status message for a feature this game's rules don't allow; true if blocked.
NotForGame(what, allowed := "") {
    if (allowed = "")
        allowed := GameDef.together
    if allowed
        return false
    Status(what " isn't available for " GameDef.name ": " GameDef.why ".", 6000)
    return true
}

; First start for a game other than EverQuest: its own sensible defaults,
; and the look of the app copied from the EverQuest settings.
WriteGameDefaults() {
    W(sec, key, val) => IniWrite(val, CFG_FILE, sec, key)
    W("General", "Game", GameDef.name)
    W("General", "EQPath", GameDef.folder)
    W("General", "EQExe", GameDef.exe)
    W("General", "LaunchArgs", "")
    W("General", "Slots", GameDef.defSlots)
    W("General", "Layout", GameDef.defLayout)
    W("General", "SettleTime", GameDef.settle)
    W("General", "PrepareIni", 0)
    W("Profiles", "PerCharacter", 0)
    W("Login", "UseLoginArg", 0)
    for sec in StrSplit(IniRead(CFG_FILE), "`n")
        if (SubStr(sec, 1, 7) = "KeyMap.")
            IniDelete(CFG_FILE, sec)
    for key in ["Appearance", "ShowTooltips", "ShowPanelOnStart", "RunAsAdmin", "Monitor", "UseWorkArea"]
        try {
            v := IniRead(MAIN_CFG, "General", key)
            W("General", key, v)
        }
    for key in ["Show", "Vertical", "FontSize", "Opacity", "Color", "ButtonColor", "TextColor", "OnColor"]
        try {
            v := IniRead(MAIN_CFG, "Toolbar", key)
            W("Toolbar", key, v)
        }
}

; Is this the game's folder (it has the game or its launcher in it)?
GamePathOK(path) {
    path := Trim(path)
    if FileExist(path "\" GameDef.exe)
        return true
    for f in GameDef.launchers
        if FileExist(path "\" f)
            return true
    return FileExist(path "\mnm\" GameDef.exe) != ""
}

; The game's own launcher (games MMORPG Boxer can't start directly).
LauncherExe() {
    for f in GameDef.launchers
        if FileExist(EQPath "\" f)
            return EQPath "\" f
    return ""
}

; Switch to another game: remember it and restart with that game's setup.
SetGame(name, *) {
    id := GameIdOf(name)
    if (id = GAME)
        return
    if (MsgBox("Switch MMORPG Boxer to " GameInfo(id).name "?`n`nEach game keeps its own slots, layouts and settings. MMORPG Boxer restarts"
        . (FileExist(id = "EverQuest" ? MAIN_CFG : A_ScriptDir "\MMORPGBoxer-" id ".ini") ? "." : " and opens the Setup Wizard for it."), APP, "YesNo Iconi 262144") != "Yes")
        return false
    IniWrite(GameInfo(id).name, MAIN_CFG, "General", "Game")
    Reload()
}

; ----------------------------- Config I/O -----------------------------
Cfg(sec, key, def := "") {
    try return IniRead(CFG_FILE, sec, key, def)
    return def
}

CfgSection(sec) {
    try return IniRead(CFG_FILE, sec)
    return ""
}

ToInt(s, def) => IsInteger(s) ? Integer(s) : def

ParseRect(s) {
    p := StrSplit(s, ",", " `t")
    if (p.Length = 4 && IsInteger(p[1]) && IsInteger(p[2]) && IsInteger(p[3]) && IsInteger(p[4]))
        return {x: Integer(p[1]), y: Integer(p[2]), w: Integer(p[3]), h: Integer(p[4])}
    return {x: 0, y: 0, w: 960, h: 540}
}

TryHotkey(key, fn, opts := "") {
    try {
        Hotkey(key, fn, opts)
        return true
    } catch as e {
        MsgBox("Could not create hotkey '" key "':`n" e.Message, APP, "Icon!")
        return false
    }
}

BindHotkey(name, def, fn, opts := "") {
    key := Cfg("Hotkeys", name, def)
    if (key != "")
        TryHotkey(key, fn, opts)
}

EditConfig(*) => Run('notepad.exe "' CFG_FILE '"')

; ------------------------------- Clients ------------------------------
IsGameWindow(id) {
    try {
        WinGetPos(, , &w, &h, "ahk_id " id)
        return (w >= 300 && h >= 200)
    }
    return false
}

SlotOf(id) {
    for n, s in Slots
        if (s = id)
            return n
    return 0
}

FirstFreeSlot() {
    for n, s in Slots
        if !s
            return n
    return 0
}

FirstSlot() {
    for n, s in Slots
        if s
            return n
    return 1
}

CountClients() {
    c := 0
    for s in Slots
        if s
            c++
    return c
}

HasVal(arr, val) {
    for v in arr
        if (v = val)
            return true
    return false
}

RefreshSlots() {
    changed := false
    Loop MAX_SLOTS {
        if (Slots[A_Index] && !WinExist("ahk_id " Slots[A_Index])) {
            Slots[A_Index] := 0
            LastClosed.n := A_Index, LastClosed.t := A_TickCount
            changed := true
        }
    }
    if Launching
        return changed
    for id in WinGetList(EQ) {
        if (SlotOf(id) || !IsGameWindow(id))
            continue
        n := 0
        ; After a reload, put clients back in the slot shown in their title.
        try {
            if RegExMatch(WinGetTitle("ahk_id " id), "^EQ(\d+)\b", &m) {
                k := Integer(m[1])
                if (k >= 1 && k <= MAX_SLOTS && !Slots[k])
                    n := k
            }
        }
        if !n
            n := SlotByPosition(id)
        if !n
            n := FirstFreeSlot()
        if !n
            break
        Slots[n] := id
        NoteStart(id)
        WriteLog("slot " n ": client found - " WinDesc(id))
        changed := true
    }
    return changed
}

UpdateTitles() {
    if !GameDef.titles
        return                  ; keep the game's own window titles
    for n, id in Slots {
        if !id
            continue
        want := "EQ" n (Chars[n] != "" ? " - " Chars[n] : "")
        try {
            cur := WinGetTitle("ahk_id " id)
            if (cur != want) {
                ; EverQuest resets its title when it changes screens (for
                ; example logging out to server select). It also reloads its
                ; resolution from the shared eqclient.ini then, which holds
                ; another slot's size, so its picture ends up stretched.
                ; Once it has finished switching, make it redraw at its
                ; real window size.
                if (GameDef.eqIni && Placed.Has(id) && !RegExMatch(cur, "^EQ" n "\b")) {
                    WriteLog("slot " n ": EverQuest changed its title to '" cur "' (changing screens) - will re-sync it")
                    SetTimer(ResyncLater.Bind(id, 0), -3000)
                }
                WinSetTitle(want, "ahk_id " id)
            }
        }
    }
}

; Wait until the client's window has stopped changing, then re-sync it.
ResyncLater(id, tries, *) {
    static last := Map()
    if !WinExist("ahk_id " id)
        return
    desc := WinDesc(id)
    if (tries < 10 && (!last.Has(id) || last[id] != desc)) {
        last[id] := desc
        SetTimer(ResyncLater.Bind(id, tries + 1), -1000)
        return
    }
    if last.Has(id)
        last.Delete(id)
    ResyncClient(id, "after changing screens")
}

; Make EverQuest redraw at its window's real size: a tiny resize and back,
; wrapped in the "resize started/finished" messages a window-edge drag sends.
; Fixes a stretched or squashed picture after EverQuest picked up another
; slot's resolution from eqclient.ini.
ResyncClient(id, why) {
    try {
        if (WinGetMinMax("ahk_id " id) = -1)
            return
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " id)
    } catch
        return
    WriteLog("slot " SlotOf(id) ": re-sync (" why ") - telling EverQuest to redraw at its window size - " WinDesc(id))
    try SendMessage(0x231, 0, 0, , "ahk_id " id, , , , 1000)          ; WM_ENTERSIZEMOVE
    DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", ox, "Int", oy, "Int", ow, "Int", oh - 2, "UInt", 0x14)
    DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", ox, "Int", oy, "Int", ow, "Int", oh, "UInt", 0x14)
    try SendMessage(0x232, 0, 0, , "ahk_id " id, , , , 1000)          ; WM_EXITSIZEMOVE
    ArrangedAt[id] := A_TickCount
    SetTimer(LogAfter.Bind(id, "2 s after re-sync"), -2000)
}

ResyncAll(*) {
    for n, id in Slots
        if (id && Placed.Has(id))
            ResyncClient(id, "Arrange")
}

; ------------------ Per-character EverQuest settings -------------------
; Every EverQuest client shares one eqclient.ini. Each character gets its own
; copy instead (Profiles\<name>\eqclient.ini, plus eqlsPlayerData.ini for
; the login screen):
; - before a client starts, its character's copy is put in place;
; - while you play, eqclient.ini holds the copy of the client you're in, so
;   when that client re-reads it (for example logging out to server select)
;   it gets its own resolution and settings, not another slot's;
; - when EverQuest saves eqclient.ini, the change goes back into the copy of
;   the client that saved it (the one that just closed, or the one you're in).
; [Profiles] PerCharacter=0 turns this off.

InGameName(n) => Trim(Cfg("InGameNames", String(n), ""))

ProfileName(n) {
    name := InGameName(n)
    if (name = "")
        name := Chars[n]
    if (name = "")
        name := "Slot " n
    return RegExReplace(name, '[\\/:*?"<>|]', "_")
}

ProfileDir(n) => A_ScriptDir "\Profiles\" ProfileName(n)

EqIni() => EQPath "\eqclient.ini"

FileStamp(f) {
    try return FileGetTime(f, "M") "/" FileGetSize(f)
    return ""
}

; Make sure slot n's character has its own copies (first time: a copy of the
; current shared ones). Returns its folder.
EnsureProfile(n) {
    dir := ProfileDir(n)
    try {
        if !DirExist(A_ScriptDir "\Profiles\_original") && FileExist(EqIni()) {
            DirCreate(A_ScriptDir "\Profiles\_original")
            FileCopy(EqIni(), A_ScriptDir "\Profiles\_original\eqclient.ini", 1)
            if FileExist(EQPath "\eqlsPlayerData.ini")
                FileCopy(EQPath "\eqlsPlayerData.ini", A_ScriptDir "\Profiles\_original\eqlsPlayerData.ini", 1)
            WriteLog("profiles: backed up the original eqclient.ini to Profiles\_original")
        }
        if !DirExist(dir)
            DirCreate(dir)
        if (!FileExist(dir "\eqclient.ini") && FileExist(EqIni())) {
            FileCopy(EqIni(), dir "\eqclient.ini", 1)
            WriteLog("profiles: created " ProfileName(n) "'s own eqclient.ini from the shared one")
        }
        if (!FileExist(dir "\eqlsPlayerData.ini") && FileExist(EQPath "\eqlsPlayerData.ini"))
            FileCopy(EQPath "\eqlsPlayerData.ini", dir "\eqlsPlayerData.ini", 1)
    }
    return dir
}

; Put slot n's own settings in place (withLogin: also its login-screen file).
LoadProfile(n, withLogin := false) {
    global IniHolder, IniStamp
    if (!n || !FileExist(EqIni()))
        return
    dir := EnsureProfile(n)
    try {
        if FileExist(dir "\eqclient.ini")
            FileCopy(dir "\eqclient.ini", EqIni(), 1)
        if (withLogin && FileExist(dir "\eqlsPlayerData.ini"))
            FileCopy(dir "\eqlsPlayerData.ini", EQPath "\eqlsPlayerData.ini", 1)
    } catch as e {
        WriteLog("profiles: couldn't load " ProfileName(n) "'s settings: " e.Message)
        return
    }
    IniHolder := n
    WriteSlotGeometry(n)
    IniStamp := FileStamp(EqIni())
}

; Write slot n's window position/size and frame-rate caps into eqclient.ini:
; the real ones while it runs, otherwise the ones it should start with.
WriteSlotGeometry(n) {
    ini := EqIni()
    id := Slots[n]
    if (id && WinExist("ahk_id " id)) {
        try {
            WinGetPos(&ox, &oy, , , "ahk_id " id)
            WinGetClientPos(, , &pw, &ph, "ahk_id " id)
            IniWrite(ox, ini, "Defaults", "WindowedModeXOffset")
            IniWrite(oy, ini, "Defaults", "WindowedModeYOffset")
            IniWrite(0, ini, "Defaults", "Maximized")
            IniWrite(pw, ini, "VideoMode", "WindowedWidth")
            IniWrite(ph, ini, "VideoMode", "WindowedHeight")
            WriteFpsCaps(ini, n)
        }
    } else
        PrepareSlotIni(n, true)
}

; Copy the shared eqclient.ini (just saved by EverQuest) into slot n's copy.
SaveToProfile(n) {
    global IniStamp
    dir := EnsureProfile(n)
    try {
        FileCopy(EqIni(), dir "\eqclient.ini", 1)
        WriteLog("profiles: EverQuest saved its settings - kept them as " ProfileName(n) "'s")
    }
    IniStamp := FileStamp(EqIni())
}

ProfileTick() {
    global IniStamp
    static lastActive := 0, since := 0
    if (!ProfilesOn || !FileExist(EqIni()))
        return
    st := FileStamp(EqIni())
    if (IniStamp != "" && st != IniStamp && !Launching) {
        ; EverQuest wrote eqclient.ini: who? A client that just closed, else
        ; the one you're in, else the one whose settings were in the file.
        owner := (LastClosed.n && A_TickCount - LastClosed.t < 8000) ? LastClosed.n : SlotOf(WinActive(EQ))
        if !owner
            owner := IniHolder
        if owner
            SaveToProfile(owner)
        else
            IniStamp := st
    } else if (IniStamp = "")
        IniStamp := st
    if (Launching || Switching)
        return
    ; Which client's settings should be in the file now? The next free slot
    ; (ready for you to start it by hand), otherwise the client you're in.
    free := FirstFreeSlot()
    act := SlotOf(WinActive(EQ))
    if (act != lastActive)
        lastActive := act, since := A_TickCount
    target := (free && Chars[free] != "") ? free : (act && A_TickCount - since > 700) ? act : 0
    if (target && target != IniHolder)
        LoadProfile(target)
}

; Layout or resolution changed: get eqclient.ini ready for the next client.
PrepFreeSlotIni() {
    global IniHolder
    if ProfilesOn
        IniHolder := 0          ; ProfileTick reloads it with the new values
    else
        PrepareSlotIni(FirstFreeSlot(), true)
}

OpenProfiles(*) {
    DirCreate(A_ScriptDir "\Profiles")
    Run('explorer.exe "' A_ScriptDir '\Profiles"')
}

; ---------------------- Frame-rate caps (per slot) ----------------------
; EverQuest's own caps ([Options] MaxFPS / MaxBGFPS in eqclient.ini) are set
; for each client before it starts. [FPS] Slot<n>=<active>,<background>
SlotFps(n) {
    p := StrSplit(Cfg("FPS", "Slot" n, ""), ",", " `t")
    return {fg: (p.Length >= 1 && IsInteger(p[1])) ? Integer(p[1]) : ""
          , bg: (p.Length >= 2 && IsInteger(p[2])) ? Integer(p[2]) : ""}
}

WriteFpsCaps(ini, n) {
    f := SlotFps(n)
    try {
        if (f.fg != "")
            IniWrite(f.fg, ini, "Options", "MaxFPS")
        if (f.bg != "")
            IniWrite(f.bg, ini, "Options", "MaxBGFPS")
    }
}

; ---------------------- CPU cores and priority ----------------------
; [CPU] Slot<n>=all | 0-3,8 (logical core numbers)   Priority<n>=Normal...
CpuCount() => Max(1, Min(64, ToInt(EnvGet("NUMBER_OF_PROCESSORS"), 1)))

AllCoresMask() => CpuCount() >= 64 ? -1 : (1 << CpuCount()) - 1

; "0-3,8" -> bit mask (0 = all cores / not set)
CoresMask(spec) {
    spec := Trim(spec)
    if (spec = "" || spec = "all")
        return 0
    mask := 0
    for part in StrSplit(spec, ",", " `t") {
        if RegExMatch(part, "^(\d+)\s*-\s*(\d+)$", &m) {
            Loop (Integer(m[2]) - Integer(m[1]) + 1)
                if (Integer(m[1]) + A_Index - 1 < CpuCount())
                    mask |= 1 << (Integer(m[1]) + A_Index - 1)
        } else if (IsInteger(part) && Integer(part) < CpuCount())
            mask |= 1 << Integer(part)
    }
    return mask
}

PriorityNames() => ["Normal", "Above normal", "High", "Below normal"]

PriorityClass(name) {
    switch name, false {
        case "Above normal", "AboveNormal": return 0x8000
        case "High": return 0x80
        case "Below normal", "BelowNormal": return 0x4000
    }
    return 0x20
}

SlotCores(n) => Trim(Cfg("CPU", "Slot" n, "all"))
SlotPriority(n) => Cfg("CPU", "Priority" n, "Normal")

ApplyCpu(n) {
    id := Slots[n]
    if !id
        return
    key := SlotCores(n) "|" SlotPriority(n)
    CpuDone[id] := key
    if (key = "all|Normal" && !CpuDone.Has("touched" id))
        return                          ; nothing to change
    CpuDone["touched" id] := true
    try pid := WinGetPID("ahk_id " id)
    catch
        return
    h := DllCall("OpenProcess", "UInt", 0x0600, "Int", 0, "UInt", pid, "Ptr")   ; SET_INFORMATION | QUERY_INFORMATION
    if !h {
        WriteLog("slot " n ": couldn't change CPU settings (error " A_LastError ")")
        return
    }
    mask := CoresMask(SlotCores(n))
    ok1 := DllCall("SetProcessAffinityMask", "Ptr", h, "UPtr", mask ? mask : AllCoresMask())
    ok2 := DllCall("SetPriorityClass", "Ptr", h, "UInt", PriorityClass(SlotPriority(n)))
    DllCall("CloseHandle", "Ptr", h)
    WriteLog("slot " n ": CPU cores " SlotCores(n) ", priority " SlotPriority(n) ((ok1 && ok2) ? "" : " (Windows refused part of it)"))
}

ApplyCpuAll(*) {
    for n, id in Slots
        if id {
            CpuDone.Delete(id)
            ApplyCpu(n)
        }
}

; ------------------------- Team helpers -------------------------
; Follow / assist / attack using EverQuest's own commands, typed into each
; other client in turn (the same way broadcast reaches them). Needs each
; slot's in-game character name (Team & Performance window).
TeamDo(kind, *) {
    global Switching
    static busy := false
    if (busy || NotForGame("Team commands"))
        return
    act := SlotOf(WinActive(EQ))
    if !act {
        Status("Click into the EverQuest client that should lead first")
        return
    }
    KeyWait("Ctrl", "T1"), KeyWait("Alt", "T1"), KeyWait("Shift", "T1")
    me := InGameName(act)
    others := []
    for n, id in Slots
        if (id && n != act)
            others.Push(n)
    if (kind = "sit" || kind = "stand")
        others.InsertAt(1, act)
    needNames := (kind = "follow" || kind = "assist" || kind = "attack" || kind = "line")
    if (needNames && me = "") {
        MsgBox("Set the in-game character name for slot " act " first (Team && Performance window).", APP, "Iconi")
        ShowPerf()
        return
    }
    if (kind = "line")
        for n in others
            if (InGameName(n) = "") {
                MsgBox("Set the in-game character name for slot " n " first (Team && Performance window).", APP, "Iconi")
                ShowPerf()
                return
            }
    busy := true
    Switching := true
    prev := Slots[act]
    delay := ToInt(Cfg("Broadcast", "SwitchDelay", "20"), 20)
    leader := me
    done := 0
    for n in others {
        id := Slots[n]
        cmds := []
        switch kind {
            case "follow": cmds := ["/target " me, "/follow"]
            case "line":   cmds := ["/target " leader, "/follow"], leader := InGameName(n)
            case "assist": cmds := ["/assist " me]
            case "attack": cmds := ["/assist " me, "/attack on"]
            case "backoff": cmds := ["/attack off"]
            case "sit":    cmds := ["/sit on"]
            case "stand":  cmds := ["/sit off"]
        }
        try {
            if (id != WinActive("A")) {
                WinActivate("ahk_id " id)
                if !WinWaitActive("ahk_id " id, , 0.5)
                    continue
            }
            Sleep(delay + 30)
            if (kind = "stop") {
                k := Cfg("Team", "StopFollowKey", "Down")
                SendInput("{" k " down}")
                Sleep(150)
                SendInput("{" k " up}")
            } else {
                for c in cmds {
                    SendInput("{Enter}")
                    Sleep(40)
                    SendInput("{Raw}" c)
                    Sleep(20)
                    SendInput("{Enter}")
                    Sleep(60)
                }
            }
            done++
        }
    }
    try WinActivate("ahk_id " prev)
    Switching := false
    busy := false
    label := Map("follow", "Follow me", "line", "Follow in a line", "stop", "Stop following", "assist", "Assist me"
        , "attack", "Attack my target", "backoff", "Back off", "sit", "Sit", "stand", "Stand")[kind]
    Status(label " - " done " client(s)", 2500)
}

TeamMenu(*) {
    if NotForGame("Team commands")
        return
    H(name, def) => (k := Cfg("Hotkeys", name, def)) != "" ? "`t" NiceKey(k) : ""
    m := Menu()
    m.Add("Follow me" H("FollowMe", "^!f"), TeamDo.Bind("follow"))
    m.Add("Follow in a line (each follows the one before)" H("FollowLine", ""), TeamDo.Bind("line"))
    m.Add("Stop following" H("StopFollow", "^!x"), TeamDo.Bind("stop"))
    m.Add()
    m.Add("Assist me (take my target)" H("AssistMe", "^!t"), TeamDo.Bind("assist"))
    m.Add("Attack my target" H("AttackMyTarget", ""), TeamDo.Bind("attack"))
    m.Add("Back off (stop attacking)" H("BackOff", ""), TeamDo.Bind("backoff"))
    m.Add()
    m.Add("Everyone sit" H("SitAll", ""), TeamDo.Bind("sit"))
    m.Add("Everyone stand" H("StandAll", ""), TeamDo.Bind("stand"))
    m.Add()
    m.Add("Team && Performance settings...", ShowPerf)
    prev := WinActive("A")
    if TB
        DllCall("SetForegroundWindow", "Ptr", TB.Hwnd)
    m.Show()
    if (prev && WinExist("ahk_id " prev))
        try WinActivate("ahk_id " prev)
}

; ---------------------- Team & Performance window ----------------------
ShowPerf(*) {
    global PF
    g := 0
    PBtn(opts, label, fn, tip) {
        btn := g.AddButton(opts, label)
        btn.OnEvent("Click", fn)
        AddTip(btn, tip)
    }
    if !PF {
        g := Gui(, APP " - Team & Performance")
        g.SetFont("s10", "Segoe UI")
        PF := {gui: g}
        PF.list := g.AddListView("xm w700 r8 -Multi", ["Slot", "Character", "In-game name", "CPU cores", "Priority", "Max FPS (active / background)"])
        PF.list.OnEvent("ItemSelect", (*) => PerfLoad())
        g.AddGroupBox("xm y+10 w700 h150", "Selected slot")
        PF.slotTxt := g.AddText("xp+12 yp+26 w60 h26 0x200", "Slot 1")
        g.AddText("x+4 yp w110 h26 0x200", "In-game name:")
        PF.name := g.AddEdit("x+4 yp w170")
        AddTip(PF.name, "The character's name in EverQuest. Follow and assist use it to target this character.")
        g.AddText("x+16 yp w80 h26 0x200", "CPU cores:")
        PF.cores := g.AddEdit("x+4 yp w170")
        AddTip(PF.cores, "all = every core (normal), or core numbers like 0-3 or 4-11,14 (this PC has " CpuCount() " logical cores: 0-" (CpuCount() - 1) ")")
        g.AddText("xm+76 y+10 w110 h26 0x200", "Priority:")
        PF.prio := g.AddDropDownList("x+4 yp w170", PriorityNames())
        AddTip(PF.prio, "How Windows prioritises this client. Above normal for your main is usually enough.")
        g.AddText("x+16 yp w80 h26 0x200", "Max FPS:")
        PF.fg := g.AddEdit("x+4 yp w56 Number")
        AddTip(PF.fg, "Frame-rate cap while this client is the one you're in (blank = leave EverQuest's setting)")
        g.AddText("x+4 yp w14 h26 0x200 Center", "/")
        PF.bg := g.AddEdit("x+4 yp w56 Number")
        AddTip(PF.bg, "Frame-rate cap while this client is in the background (blank = leave EverQuest's setting).`nEverQuest needs about 25 or more for /follow to keep up.")
        PBtn("xm+76 y+12 w150 h30", "Save", (*) => PerfSave(), "Save this slot's settings and apply the CPU settings now")
        Hint(g.AddText("x+12 yp w450 h30 0x200 cGray", "Frame-rate caps apply the next time this client starts."))
        PF.prof := g.AddCheckbox("xm y+22 w440" (ProfilesOn ? " Checked" : ""), "Separate EverQuest settings file for each character")
        PF.prof.OnEvent("Click", PerfProfiles)
        AddTip(PF.prof, "Each character keeps its own eqclient.ini (graphics, window, frame-rate caps) in the Profiles folder.`nAlso stops a client picking up another slot's resolution when you log out.")
        PBtn("x+8 yp-4 w250 h30", "Open Profiles Folder", OpenProfiles, "Where each character's eqclient.ini is kept")
        PBtn("xm y+14 w220 h32", "Auto-assign CPU Cores", (*) => PerfAutoCores(), "Give your main slot cores of its own and share the rest between the others")
        PBtn("x+8 yp w220 h32", "Reset CPU to Normal", (*) => PerfResetCores(), "Every client uses every core at normal priority")
        PBtn("x+8 yp w244 h32", "Team Commands...", TeamMenu, "Follow me, assist me, attack, sit, stand ...")
        g.AddText("xm y+14 w160 h26 0x200", "Stop-following key:")
        PF.stop := g.AddEdit("x+4 yp w120", Cfg("Team", "StopFollowKey", "Down"))
        PF.stop.OnEvent("Change", (c, *) => IniWrite(Trim(c.Value), CFG_FILE, "Team", "StopFollowKey"))
        AddTip(PF.stop, "The key that walks backwards in EverQuest (pressing it breaks /follow). AutoHotkey key name, e.g. Down or s.")
        if !GameDef.together
            for c in [PF.name, PF.stop]
                c.Enabled := false
        if !GameDef.eqIni
            for c in [PF.fg, PF.bg, PF.prof]
                c.Enabled := false
        Hint(g.AddText("xm y+12 w700 cGray", !GameDef.together ? "Team commands, frame-rate caps and per-character settings files aren't used for " GameDef.name ". CPU cores and priority work as usual." : "Follow and assist type EverQuest's own commands (/target, /follow, /assist, /attack) into each other client in turn, the same way broadcast reaches them."))
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())
        ThemeGui(g)
    }
    PF.gui.Show()
    PerfRefresh()
}

PerfRefresh(keep := 0) {
    if !(PF && DllCall("IsWindowVisible", "Ptr", PF.gui.Hwnd))
        return
    if !keep
        keep := Max(1, PF.list.GetNext(0))
    PF.list.Opt("-Redraw")
    PF.list.Delete()
    Loop MAX_SLOTS {
        f := SlotFps(A_Index)
        PF.list.Add(, A_Index, Chars[A_Index], InGameName(A_Index), SlotCores(A_Index), SlotPriority(A_Index)
            , (f.fg = "" && f.bg = "") ? "EverQuest's own" : (f.fg = "" ? "-" : f.fg) " / " (f.bg = "" ? "-" : f.bg))
    }
    Loop 6
        PF.list.ModifyCol(A_Index, "AutoHdr")
    PF.list.Modify(Min(keep, MAX_SLOTS), "Select Focus Vis")
    PF.list.Opt("+Redraw")
    PerfLoad()
}

PerfLoad() {
    n := PF.list.GetNext(0)
    if !n
        return
    PF.slotTxt.Text := "Slot " n
    PF.name.Value := InGameName(n)
    PF.cores.Value := SlotCores(n)
    try PF.prio.Text := SlotPriority(n)
    catch
        PF.prio.Choose(1)
    f := SlotFps(n)
    PF.fg.Value := f.fg, PF.bg.Value := f.bg
}

PerfSave() {
    n := PF.list.GetNext(0)
    if !n
        return
    cores := Trim(PF.cores.Value)
    if (cores != "" && cores != "all" && !CoresMask(cores)) {
        MsgBox("CPU cores: use all, or numbers between 0 and " (CpuCount() - 1) " such as 0-3 or 4-11,14.", APP, "Icon! Owner" PF.gui.Hwnd)
        return
    }
    IniWrite(Trim(PF.name.Value), CFG_FILE, "InGameNames", String(n))
    IniWrite(cores = "" ? "all" : cores, CFG_FILE, "CPU", "Slot" n)
    IniWrite(PF.prio.Text, CFG_FILE, "CPU", "Priority" n)
    fg := Trim(PF.fg.Value), bg := Trim(PF.bg.Value)
    IniWrite((fg = "" && bg = "") ? "" : fg "," bg, CFG_FILE, "FPS", "Slot" n)
    if Slots[n] {
        CpuDone.Delete(Slots[n])
        ApplyCpu(n)
    }
    PerfRefresh(n)
    Status("Saved slot " n)
}

PerfProfiles(ctrl, *) {
    global ProfilesOn, IniHolder
    ProfilesOn := !!ctrl.Value
    IniWrite(ProfilesOn ? 1 : 0, CFG_FILE, "Profiles", "PerCharacter")
    IniHolder := 0
    Status("Separate settings per character " (ProfilesOn ? "on" : "off"))
}

; Main slot (slot 1, or [CPU] MainSlot) gets about a quarter of the cores
; (at least 2, an even number so it keeps whole physical cores); everyone
; else shares the rest. Main gets Above normal priority.
PerfAutoCores() {
    total := CpuCount()
    if (total < 4) {
        MsgBox("This PC has " total " logical cores - too few to split. Leave every client on all cores.", APP, "Iconi Owner" PF.gui.Hwnd)
        return
    }
    Status(AutoCoresWrite(MAX_SLOTS))
    ApplyCpuAll()
    PerfRefresh()
}

; Write the auto-assigned cores for slots 1..cnt; returns a description.
AutoCoresWrite(cnt) {
    total := CpuCount()
    if (total < 4)
        return "Too few cores to split - every client uses all " total
    main := ToInt(Cfg("CPU", "MainSlot", "1"), 1)
    k := Max(2, (total // 4) & ~1)
    Loop cnt {
        n := A_Index
        IniWrite(n = main ? "0-" (k - 1) : k "-" (total - 1), CFG_FILE, "CPU", "Slot" n)
        IniWrite(n = main ? "Above normal" : "Normal", CFG_FILE, "CPU", "Priority" n)
    }
    return "Slot " main " has cores 0-" (k - 1) " to itself, the others share " k "-" (total - 1)
}

PerfResetCores() {
    Loop MAX_SLOTS {
        IniWrite("all", CFG_FILE, "CPU", "Slot" A_Index)
        IniWrite("Normal", CFG_FILE, "CPU", "Priority" A_Index)
    }
    ApplyCpuAll()
    PerfRefresh()
    Status("Every client uses every core at normal priority")
}

WatchClients() {
    global Enforcing
    changed := RefreshSlots()
    UpdateTitles()
    if (!Launching && !ProfilesOn)
        PrepareSlotIni(FirstFreeSlot())
    if !Launching
        for n, id in Slots
            if (id && !CpuDone.Has(id))
                ApplyCpu(n)
    CheckOffSlot()
    VfxCheck()
    if changed {
        CheckDpi()
        if AutoArrange
            Arrange()
        else
            RefreshVFX()
        RefreshPanel()
    } else if (AutoArrange && !Launching && !A_IsSuspended) {
        ; EverQuest resets its own window size, borders and position while it
        ; starts up (after we first placed it). Keep every client in its slot.
        Enforcing := true
        moved := ArrangeCurrent()
        Enforcing := false
        if moved
            RefreshVFX()
    }
}

; If Windows is scaling a client (DPI virtualization), the game's mouse
; mapping breaks for any window not at the top-left of the screen.
CheckDpi() {
    static warned := false
    if (warned || A_ScreenDPI <= 96)
        return
    for n, id in Slots {
        if !id
            continue
        try {
            ctx := DllCall("GetWindowDpiAwarenessContext", "Ptr", id, "Ptr")
            aware := DllCall("GetAwarenessFromDpiAwarenessContext", "Ptr", ctx, "Int")
        } catch
            continue
        if (aware = 0) {
            warned := true
            MsgBox("Windows is scaling the " GameDef.name " clients (display scale "
                . Round(A_ScreenDPI / 96 * 100) "%).`n`n"
                . "This makes the mouse line up only in the top-left window.`n`n"
                . "Fix: right-click " EQExe " > Properties > Compatibility >`n"
                . "Change high DPI settings > check 'Override high DPI scaling`n"
                . "behavior' and choose 'Application'. Then restart the clients."
                , APP, "Icon! T60")
            return
        }
    }
}

; ------------------------------ Diagnostics ------------------------------
; Window events are written to MMORPGBoxer.log so placement problems can be seen
; exactly (what EverQuest did to a window, and when).
WriteLog(msg) {
    try FileAppend(FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec) "  " msg "`n", LOG_FILE, "UTF-8")
}

; One-line description of a window: outer rect, picture (client) rect, borders.
WinDesc(id) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " id)
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " id)
        st := WinGetStyle("ahk_id " id)
        rk := RegionKey(id)
        return Format("window {},{} {}x{} | picture {},{} {}x{} | {}{} | clip {}", x, y, w, h, cx, cy, cw, ch
            , (st & 0xC00000) ? "title bar" : "no title bar", ((st & 0xC00000) && DwmFrameOn(id)) ? " (drawn by DWM)" : ""
            , rk = "" ? "none" : rk)
    }
    return "(window gone)"
}

; Writes a report (settings, every slot's window vs its slot, recent log)
; to MMORPGBoxer-diagnostics.txt, copies it to the clipboard and opens it.
Diagnostics(*) {
    t := APP " diagnostics  " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
    t .= "Game: " GameDef.name " (" EQExe ")   Admin: " (A_IsAdmin ? "yes" : "no") "   Screen DPI: " A_ScreenDPI "   Layout: " Layout "   Slots: " MAX_SLOTS "`r`n"
    MonitorGet(MonitorNum, &mL, &mT, &mR, &mB)
    MonitorGetWorkArea(MonitorNum, &wL, &wT, &wR, &wB)
    t .= Format("Monitor {}: {},{} - {},{}   work area: {},{} - {},{}", MonitorNum, mL, mT, mR, mB, wL, wT, wR, wB) "`r`n"
    bs := BorderSize()
    t .= "Border size (w x h added): " bs.w " x " bs.h "   UseWorkArea=" UseWorkArea "  HideBorders=" HideBorders "`r`n"
    ini := EQPath "\eqclient.ini"
    if GameDef.eqIni
        try t .= "eqclient.ini now: XOffset=" IniRead(ini, "Defaults", "WindowedModeXOffset", "?")
        . " YOffset=" IniRead(ini, "Defaults", "WindowedModeYOffset", "?")
        . " WindowedWidth=" IniRead(ini, "VideoMode", "WindowedWidth", "?")
        . " WindowedHeight=" IniRead(ini, "VideoMode", "WindowedHeight", "?")
        . " AllowResize=" IniRead(ini, "Defaults", "AllowResize", "?") "`r`n"
    t .= "`r`n"
    Loop MAX_SLOTS {
        n := A_Index, id := Slots[n], c := CellFor(n)
        t .= "Slot " n " (" Chars[n] "):`r`n"
        t .= "   should be: " (c ? Format("{},{} {}x{}", c.x, c.y, c.w, c.h) : "(no place in this layout)") "`r`n"
        if !id {
            t .= "   not running`r`n"
            continue
        }
        t .= "   now:       " WinDesc(id) "`r`n"
        if StartPos.Has(id)
            t .= "   opened at: " StartPos[id].x "," StartPos[id].y "`r`n"
        t .= "   settled=" ((Settle.Has(id) && Settle[id].ok) ? "yes" : "no")
            . "  arranged=" (Placed.Has(id) ? "yes" : "no")
            . "  gave up=" (Unmanaged.Has(id) ? "yes" : "no")
        try t .= "  DPI awareness=" DllCall("GetAwarenessFromDpiAwarenessContext", "Ptr", DllCall("GetWindowDpiAwarenessContext", "Ptr", id, "Ptr"), "Int")
        t .= "`r`n"
    }
    t .= "`r`n--- recent log ---`r`n"
    try {
        lines := StrSplit(FileRead(LOG_FILE, "UTF-8"), "`n")
        first := Max(1, lines.Length - 200)
        Loop lines.Length - first + 1
            t .= lines[first + A_Index - 1] "`r`n"
    }
    out := A_ScriptDir "\MMORPGBoxer-diagnostics.txt"
    try FileDelete(out)
    FileAppend(t, out, "UTF-8")
    A_Clipboard := t
    Run('notepad.exe "' out '"')
    Status("Diagnostics saved to MMORPGBoxer-diagnostics.txt and copied to the clipboard", 6000)
}

; ------------------------------- Updates -------------------------------
; New versions are published as GitHub releases. Each release has the
; installer (MMORPGBoxer-Setup.exe) and its SHA-256 checksum
; (MMORPGBoxer-Setup.exe.sha256). The download is only run if the checksums
; match. The installer runs silently (/S /UPDATE), keeps the settings and
; restarts MMORPG Boxer.
; An empty "Repo=" line (as in a freshly created MMORPGBoxer.ini) means "use the
; built-in repository", the same as no line at all.
UpdateRepo() {
    v := Trim(Cfg("Update", "Repo", ""))
    return (v != "") ? v : DEFAULT_UPDATE_REPO
}

HttpGet(url) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "MMORPGBoxer-Updater/" APP_VERSION)
    req.SetRequestHeader("Accept", "application/vnd.github+json")
    req.Send()
    if (req.Status != 200)
        throw Error("HTTP " req.Status " from " url)
    return req.ResponseText
}

; the "browser_download_url" of the release asset with exactly this file name
FindAsset(json, name) {
    if RegExMatch(json, '"browser_download_url"\s*:\s*"([^"]*/\Q' name '\E)"', &m)
        return m[1]
    return ""
}

; a JSON string value (unescaped) by key
JsonStr(json, key) {
    if !RegExMatch(json, '"' key '"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
        return ""
    s := m[1], out := "", i := 1
    while (i <= StrLen(s)) {
        c := SubStr(s, i, 1)
        if (c != "\") {
            out .= c, i++
            continue
        }
        e := SubStr(s, i + 1, 1)
        switch e, true {
            case "n": out .= "`n"
            case "r": out .= ""
            case "t": out .= "`t"
            case "u":
                out .= Chr(Integer("0x" SubStr(s, i + 2, 4)))
                i += 4
            default: out .= e
        }
        i += 2
    }
    return out
}

FileSHA256(path) {
    data := FileRead(path, "RAW")
    hAlg := 0, hHash := 0
    DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "WStr", "SHA256", "Ptr", 0, "UInt", 0)
    DllCall("bcrypt\BCryptCreateHash", "Ptr", hAlg, "Ptr*", &hHash, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0)
    DllCall("bcrypt\BCryptHashData", "Ptr", hHash, "Ptr", data, "UInt", data.Size, "UInt", 0)
    digest := Buffer(32, 0)
    DllCall("bcrypt\BCryptFinishHash", "Ptr", hHash, "Ptr", digest, "UInt", 32, "UInt", 0)
    DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
    DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    hex := ""
    Loop 32
        hex .= Format("{:02x}", NumGet(digest, A_Index - 1, "UChar"))
    return hex
}

; silent = the automatic check at start-up: says nothing unless there's an update
CheckForUpdates(silent := false, *) {
    repo := UpdateRepo()
    if (repo = "") {
        if !silent
            MsgBox("Updates aren't set up yet (no repository in [Update] Repo).", APP, "Iconi")
        return
    }
    try {
        try {
            json := HttpGet("https://api.github.com/repos/" repo "/releases/latest")
        } catch as e1 {
            ; before the repository is renamed, releases are under the old name
            if (repo != DEFAULT_UPDATE_REPO || !InStr(e1.Message, "HTTP 404"))
                throw e1
            json := HttpGet("https://api.github.com/repos/" OLD_UPDATE_REPO "/releases/latest")
        }
    } catch as e {
        WriteLog("update check failed: " e.Message)
        if !silent
            MsgBox("Couldn't check for updates right now.`n`n" e.Message, APP, "Icon!")
        return
    }
    if !RegExMatch(json, '"tag_name"\s*:\s*"v?([0-9][^"]*)"', &m) {
        if !silent
            MsgBox("No releases found yet.", APP, "Iconi")
        return
    }
    latest := m[1]
    if (VerCompare(latest, APP_VERSION) <= 0) {
        if !silent
            MsgBox("You have the latest version (" APP_VERSION ").", APP, "Iconi")
        return
    }
    if (silent && Cfg("Update", "SkipVersion", "") = latest)
        return
    WriteLog("update available: " latest " (running " APP_VERSION ")")
    exe := FindAsset(json, "MMORPGBoxer-Setup.exe"), sha := FindAsset(json, "MMORPGBoxer-Setup.exe.sha256")
    if (exe = "" || sha = "")      ; a release from before the rename
        exe := FindAsset(json, "EQBoxerPro-Setup.exe"), sha := FindAsset(json, "EQBoxerPro-Setup.exe.sha256")
    ShowUpdatePrompt(latest, JsonStr(json, "body"), exe, sha)
}

ShowUpdatePrompt(ver, notes, exeUrl, shaUrl) {
    g := Gui("+AlwaysOnTop", APP " - Update available")
    g.SetFont("s10", "Segoe UI")
    g.SetFont("s12 w600")
    g.AddText("w560", APP " " ver " is available")
    g.SetFont("s10 w400")
    Hint(g.AddText("w560 cGray", "You have version " APP_VERSION ". Updating closes MMORPG Boxer, installs the new version and starts it again. Your settings are kept."))
    g.AddText("w560 y+12", "What's new:")
    g.AddEdit("w560 r12 ReadOnly", notes != "" ? notes : "(no notes)")
    g.AddButton("w180 h32 Default", "Update now").OnEvent("Click", (*) => (g.Destroy(), InstallUpdate(ver, exeUrl, shaUrl)))
    g.AddButton("x+10 yp w180 h32", "Later").OnEvent("Click", (*) => g.Destroy())
    g.AddButton("x+10 yp w180 h32", "Skip this version").OnEvent("Click"
        , (*) => (IniWrite(ver, CFG_FILE, "Update", "SkipVersion"), g.Destroy()))
    ThemeGui(g)
    g.Show()
}

InstallUpdate(ver, exeUrl, shaUrl) {
    if (exeUrl = "" || shaUrl = "") {
        MsgBox("This release doesn't include the installer and its checksum, so it can't be installed automatically.", APP, "Icon!")
        return
    }
    tmp := A_Temp "\MMORPGBoxer-Setup-" ver ".exe"
    Status("Downloading " APP " " ver "...", 0)
    try {
        try FileDelete(tmp)
        Download(exeUrl, tmp)
        shaText := HttpGet(shaUrl)
    } catch as e {
        Status("Update download failed", 3000)
        MsgBox("The update couldn't be downloaded.`n`n" e.Message, APP, "Icon!")
        return
    }
    want := RegExMatch(shaText, "i)\b([0-9a-f]{64})\b", &h) ? StrLower(h[1]) : ""
    got := FileSHA256(tmp)
    if (want = "" || got != want) {
        try FileDelete(tmp)
        WriteLog("update " ver " rejected: checksum " got " does not match " want)
        Status("Update rejected - checksum mismatch", 4000)
        MsgBox("The downloaded update didn't pass its integrity check, so it was NOT installed.`n`nPlease try again later.", APP, "Iconx")
        return
    }
    WriteLog("installing update " ver " (checksum ok)")
    Status("Installing " APP " " ver "...", 0)
    Run('"' tmp '" /S /UPDATE')
    ExitApp()
}

; ------------------------------ Accounts ------------------------------
; Usernames live in [Usernames] in MMORPGBoxer.ini. No passwords are stored.
; The Cred* helpers below only exist to clean up what older versions saved.
CredTarget(n) => "EQBoxerPro:Slot" n

CredOffsets() {
    P := A_PtrSize
    oBlob := (P = 8) ? 40 : 28
    oUser := oBlob + P + 8 + 2 * P
    return {size: oUser + P, blobSize: 16 + 2 * P, blob: oBlob, persist: oBlob + P, user: oUser}
}


CredLoad(n) {
    pCred := 0
    if !DllCall("advapi32\CredReadW", "Str", CredTarget(n), "UInt", 1, "UInt", 0, "Ptr*", &pCred)
        return 0
    o := CredOffsets()
    size := NumGet(pCred, o.blobSize, "UInt")
    bp := NumGet(pCred, o.blob, "Ptr")
    up := NumGet(pCred, o.user, "Ptr")
    acct := {user: up ? StrGet(up, "UTF-16") : "", pass: (bp && size) ? StrGet(bp, size // 2, "UTF-16") : ""}
    DllCall("advapi32\CredFree", "Ptr", pCred)
    return acct
}

CredDelete(n) => DllCall("advapi32\CredDeleteW", "Str", CredTarget(n), "UInt", 1, "UInt", 0)


ShowAccounts(*) {
    global AccGui, AccDDL, AccName, AccUser, AccInfo
    if !AccGui {
        AccGui := Gui(, APP " - Characters & Accounts")
        AccGui.SetFont("s10", "Segoe UI")
        AccGui.AddText("xm", "Slot:")
        AccDDL := AccGui.AddDropDownList("x+8 yp-4 w250")
        AccDDL.OnEvent("Change", (*) => AccLoadSelected())
        AccGui.AddText("xm y+14", "Character name (window title / Launch All):")
        AccName := AccGui.AddEdit("xm w320")
        AccGui.AddText("xm y+10", "Account name (pre-filled at the EverQuest login screen):")
        AccUser := AccGui.AddEdit("xm w320")
        AccInfo := Hint(AccGui.AddText("xm w320 cGray", ""))
        AccGui.AddButton("xm w100 Default", "Save").OnEvent("Click", (*) => AccSave())
        AccGui.AddButton("x+10 w100", "Close").OnEvent("Click", (*) => AccGui.Hide())
        Hint(AccGui.AddText("xm w320 cGray y+12"
            , "Launch All starts each client with its username already in the login box. You type the password. An empty name means Launch All skips that slot."))
        AccGui.OnEvent("Close", (*) => AccGui.Hide())
        ThemeGui(AccGui)
    }
    n := SlotOf(WinActive(EQ))
    AccFillSlots(n ? n : 1)
    AccLoadSelected()
    AccGui.Show()
}

AccFillSlots(choose) {
    items := []
    Loop MAX_SLOTS
        items.Push(A_Index (Chars[A_Index] != "" ? " - " Chars[A_Index] : ""))
    AccDDL.Delete()
    AccDDL.Add(items)
    AccDDL.Choose(choose)
}

AccLoadSelected() {
    n := AccDDL.Value
    AccName.Value := Chars[n]
    AccUser.Value := SlotUser(n)
    AccInfo.Value := ""
}

AccSave() {
    n := AccDDL.Value
    SaveSlotInfo(n, AccName.Value, AccUser.Value)
    AccInfo.Value := "Saved slot " n "."
    if (Panel && PanelSel = n)
        PanelLoad(n)
}

SlotUser(n) => Cfg("Usernames", String(n), "")

; Earlier versions kept a username + password per slot in Windows Credential
; Manager. Move the username into MMORPGBoxer.ini and delete the stored password.
MigrateCredentials() {
    Loop 8 {
        a := CredLoad(A_Index)
        if !a
            continue
        if (a.user != "" && SlotUser(A_Index) = "")
            IniWrite(a.user, CFG_FILE, "Usernames", String(A_Index))
        CredDelete(A_Index)
    }
}











; ---------------------- Start-up position (eqclient.ini) ----------------------
; Where slot n lives in the current layout (screen coordinates).
; forStart = the size/position EverQuest should OPEN at (small enough that
; its bordered window fits on screen). Otherwise the slot's final size.
CellFor(n, forStart := false) => CellIn(Layout, n, forStart)

; Where slot n goes in layout `name` (screen coordinates), or 0 if that
; layout has no place for it.
CellIn(name, n, forStart := false) {
    LayoutArea(&mL, &mT, &mW, &mH)
    if Presets.Has(name) {
        P := Presets[name]
        if !P.Has(n)
            return 0                    ; this layout has no place for slot n
        r := P[n]
        return SlotSize(ApplyRes(n, {x: mL + r.x, y: mT + r.y, w: r.w, h: r.h}), forStart)
    }
    if (name = "Swap") {
        if (n = 1 || SmallRegions.Length = 0)
            r := MainRegion
        else
            r := SmallRegions[Min(n - 1, SmallRegions.Length)]
        return {x: mL + r.x, y: mT + r.y, w: r.w, h: r.h}
    }
    GridCell(mW, mH, &cw, &ch)
    col := Mod(n - 1, GridCols)
    row := (n - 1) // GridCols
    return SlotSize(ApplyRes(n, {x: mL + col * cw, y: mT + row * ch, w: cw, h: ch}), forStart)
}

; ---- per-slot resolution ([Resolutions] n=WxH; empty = fill the slot) ----
ResolutionChoices() {
    return ["Fill slot", "3840x2160", "3440x1440", "2560x1440", "2560x1080", "1920x1200"
        , "1920x1080", "1680x1050", "1600x900", "1440x900", "1366x768", "1280x720", "1024x768", "Custom..."]
}

SlotRes(n) {
    if RegExMatch(Cfg("Resolutions", String(n), ""), "^\s*(\d{3,5})\s*[xX]\s*(\d{3,5})\s*$", &m)
        return {w: Integer(m[1]), h: Integer(m[2])}
    return 0
}

SlotResText(n) {
    r := SlotRes(n)
    return r ? r.w "x" r.h : "Fill slot"
}

; A slot with its own resolution gets a window exactly that size (EverQuest
; draws at its window size), centred in the slot's space and kept on screen.
ApplyRes(n, c) {
    r := SlotRes(n)
    if !r
        return c
    MonitorGet(MonitorNum, &monL, &monT, &monR, &monB)
    nx := c.x + (c.w - r.w) // 2, ny := c.y + (c.h - r.h) // 2
    nx := Max(monL, Min(nx, monR - r.w)), ny := Max(monT, Min(ny, monB - r.h))
    return {x: nx, y: ny, w: r.w, h: r.h}
}

; "Custom..." -> ask for WxH. Returns "WxH", "" for fill, or 0 if cancelled.
AskResolution(cur := "") {
    ib := InputBox("Resolution for this slot, as width x height (for example 2560x1440):", APP " - Resolution", "w340 h130", cur)
    if (ib.Result != "OK")
        return 0
    v := Trim(ib.Value)
    if RegExMatch(v, "^(\d{3,5})\s*[xX]\s*(\d{3,5})$", &m)
        return m[1] "x" m[2]
    MsgBox("Please type it like 1920x1080.", APP, "Icon!")
    return 0
}

; Save a slot's resolution and apply it straight away if the client is running.
SaveSlotRes(n, text) {
    v := (text = "Fill slot") ? "" : text
    if (v = (SlotRes(n) ? SlotResText(n) : ""))
        return false
    IniWrite(v, CFG_FILE, "Resolutions", String(n))
    WriteLog("slot " n ": resolution set to " (v = "" ? "fill slot" : v))
    if Slots[n] {
        Placed.Delete(Slots[n])
        Unmanaged.Delete(Slots[n])
        Arrange()            ; resizes it now; EverQuest redraws at the new size
    }
    PrepFreeSlotIni()
    return true
}

; FillSlots=1 (default): clients open slightly smaller if needed, then are
; widened to fill the whole slot (EverQuest is told the resize finished, so
; it redraws at the new size). FillSlots=0: slots that don't fit with a
; border stay that slightly smaller size, with a small margin.
SlotSize(c, forStart) {
    if (forStart || Cfg("General", "FillSlots", "1") != "1")
        return FitCell(c)
    return c
}

; Size of a normal window's title bar + borders (width added, height added).
BorderSize() {
    static b := 0
    if !b {
        rc := Buffer(16, 0)
        try DllCall("AdjustWindowRectExForDpi", "Ptr", rc, "UInt", 0xCF0000, "Int", 0, "UInt", 0, "UInt", A_ScreenDPI)
        catch
            DllCall("AdjustWindowRectEx", "Ptr", rc, "UInt", 0xCF0000, "Int", 0, "UInt", 0)
        b := {w: NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int"), h: NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")}
    }
    return b
}

; EverQuest starts every client with a title bar and border around the
; picture. If that bordered window is wider (or taller) than the monitor,
; Windows squeezes it, EverQuest picks a smaller picture, and after the border
; is removed the picture no longer fills its slot (black space). So a slot
; that's too big for that is made a little smaller and centred in its space.
FitCell(c) {
    ; (AutoHotkey names ignore case, so the border size can't be called "b"
    ; next to the monitor's bottom edge "B")
    MonitorGet(MonitorNum, &monL, &monT, &monR, &monB)
    bs := BorderSize()
    if (c.w + bs.w > monR - monL) {
        d := c.w + 2 * bs.w - (monR - monL)
        c.w -= d, c.x += d // 2
    }
    if (c.h + bs.h > monB - monT) {
        d := c.h + 2 * bs.h - (monB - monT)
        c.h -= d, c.y += d // 2
    }
    return c
}

; EverQuest opens at WindowedModeXOffset/YOffset with WindowedWidth/Height
; and maps the mouse from there. Writing the slot's cell before a client
; starts makes it open exactly in its slot.
PrepareSlotIni(n, force := false) {
    if (!PrepareIni || !n)
        return
    ini := EQPath "\eqclient.ini"
    if !FileExist(ini)
        return
    WriteFpsCaps(ini, n)
    c := CellFor(n, true)               ; the size it can safely open at
    if !c
        return
    v := c
    ; Only write when the file differs (running clients may have changed it).
    try {
        same := IniRead(ini, "Defaults", "WindowedModeXOffset", "") = String(v.x)
             && IniRead(ini, "Defaults", "WindowedModeYOffset", "") = String(v.y)
             && IniRead(ini, "VideoMode", "WindowedWidth", "") = String(v.w)
             && IniRead(ini, "VideoMode", "WindowedHeight", "") = String(v.h)
        if (same && !force)
            return
        WriteLog("eqclient.ini set for slot " n ": offset " v.x "," v.y " size " v.w "x" v.h)
        IniWrite(v.x, ini, "Defaults", "WindowedModeXOffset")
        IniWrite(v.y, ini, "Defaults", "WindowedModeYOffset")
        IniWrite(0, ini, "Defaults", "Maximized")
        IniWrite(v.w, ini, "VideoMode", "WindowedWidth")
        IniWrite(v.h, ini, "VideoMode", "WindowedHeight")
    }
}


; A client that opened in a slot's cell belongs to that slot.
SlotByPosition(id) {
    try WinGetPos(&x, &y, , , "ahk_id " id)
    catch
        return 0
    Loop MAX_SLOTS {
        if Slots[A_Index]
            continue
        c := CellFor(A_Index, true)
        if !c
            continue
        if (Abs(x - c.x) <= 40 && Abs(y - c.y) <= 60)
            return A_Index
    }
    return 0
}

; ------------------------------- Layouts ------------------------------
IsSettled(id) {
    if ForceResync
        return true
    try WinGetPos(, , &w, &h, "ahk_id " id)
    catch
        return false
    now := A_TickCount
    if !Settle.Has(id) {
        Settle[id] := {w: w, h: h, t: now, ok: false}
        return false
    }
    st := Settle[id]
    if st.ok
        return true
    if (st.w != w || st.h != h) {
        st.w := w, st.h := h, st.t := now
        return false
    }
    if (now - st.t >= SettleTime) {
        st.ok := true
        WriteLog("slot " SlotOf(id) ": settled - " WinDesc(id))
    }
    return st.ok
}

; ------------------- Borderless by clipping (default) -------------------
; EverQuest insists on its title bar: when it's removed, EverQuest often puts
; it straight back and squashes its picture (MMORPGBoxer.log). So by default the
; title bar and border are left alone. The window is placed so its PICTURE
; lands exactly on the slot, and Windows is told to show only the picture
; area (a window region). The frame still exists for EverQuest, but it's
; invisible, can't be clicked and doesn't cover neighbouring windows.
; [General] BorderMode=Strip brings back the old remove-the-title-bar way.
BorderMode() => (Cfg("General", "BorderMode", "Clip") = "Strip") ? "Strip" : "Clip"

; window-relative rectangle of the picture area, as "l,t,w,h"
ClipKey(id) {
    WinGetPos(&ox, &oy, , , "ahk_id " id)
    WinGetClientPos(&px, &py, &pw, &ph, "ahk_id " id)
    return (px - ox) "," (py - oy) "," pw "," ph
}

; The clip a window ACTUALLY has right now ("l,t,w,h"), or "" for none.
RegionKey(id) {
    rc := Buffer(16, 0)
    t := DllCall("GetWindowRgnBox", "Ptr", id, "Ptr", rc, "Int")
    if (t != 2 && t != 3)                       ; SIMPLEREGION / COMPLEXREGION
        return ""
    l := NumGet(rc, 0, "Int"), tp := NumGet(rc, 4, "Int")
    return l "," tp "," (NumGet(rc, 8, "Int") - l) "," (NumGet(rc, 12, "Int") - tp)
}

; Windows 10/11 don't draw a window's title bar inside the window: the
; Desktop Window Manager (DWM) draws it on top, and it ignores a clip set by
; another program (MMORPGBoxer.log: clip in place, title bar still showing). So
; DWM is told not to draw this window's frame; Windows then draws a plain
; frame inside the window, which the clip does hide. This doesn't change the
; window's size or picture area, so EverQuest doesn't react to it.
DwmFrameOn(id) {
    on := 0
    hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", id, "UInt", 1, "Int*", &on, "UInt", 4, "Int")   ; DWMWA_NCRENDERING_ENABLED
    return (hr = 0 && on)
}

; policy: 0 = Windows decides (normal), 1 = DWM doesn't draw the frame
SetDwmFrame(id, policy) {
    return DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", id, "UInt", 2, "Int*", policy, "UInt", 4, "Int")   ; DWMWA_NCRENDERING_POLICY
}

ClipIsRight(id) => (RegionKey(id) = ClipKey(id) && !DwmFrameOn(id))

ClipToPicture(id) {
    static failLogged := Map(), frameTries := Map()
    if (KeepFrame.Has(id) || StripFallback.Has(id))
        return false
    try {
        key := ClipKey(id)
        p := StrSplit(key, ",")
        if (p[3] < 64 || p[4] < 64)                ; no real picture yet: an empty clip would hide the window
            return false
        if DwmFrameOn(id) {
            hr := SetDwmFrame(id, 1)
            tries := frameTries.Has(id) ? frameTries[id] + 1 : 1
            frameTries[id] := tries
            if (hr != 0 || (tries > 10 && DwmFrameOn(id))) {
                ; Windows won't let us stop DWM drawing this title bar, so a
                ; clip can't hide it: remove the title bar for this client.
                WriteLog("slot " SlotOf(id) ": Windows keeps drawing the title bar over the clip (DwmSetWindowAttribute=" Format("0x{:08X}", hr & 0xFFFFFFFF) ") - removing this client's title bar instead - " WinDesc(id))
                UseStripFor(id)
                return false
            }
            if (tries = 1)
                WriteLog("slot " SlotOf(id) ": told Windows not to draw the title bar over the picture")
        }
        rgn := DllCall("CreateRectRgn", "Int", p[1], "Int", p[2], "Int", p[1] + p[3], "Int", p[2] + p[4], "Ptr")
        ok := DllCall("SetWindowRgn", "Ptr", id, "Ptr", rgn, "Int", 1)    ; Windows owns rgn now
        err := A_LastError
        ClipFor[id] := key
        if (ok && ClipIsRight(id))
            return true
        if (!failLogged.Has(id) || A_TickCount - failLogged[id] > 10000) {
            failLogged[id] := A_TickCount
            WriteLog("slot " SlotOf(id) ": clipping to the picture did not take effect (SetWindowRgn=" ok ", error " err ") - " WinDesc(id))
        }
    }
    return false
}

; Switch one client from clipping to removing its title bar.
UseStripFor(id) {
    StripFallback[id] := true
    ClipFor.Delete(id)
    try DllCall("SetWindowRgn", "Ptr", id, "Ptr", 0, "Int", 1)
    try SetDwmFrame(id, 0)
    Placed.Delete(id)
    Unmanaged.Delete(id)
    SetTimer(Arrange, -200)
}

; Hides the title bar of every client several times a second:
; - a client that has just started is clipped straight away, so its title
;   bar never shows while it loads (clipping doesn't move or resize it, so
;   EverQuest doesn't react to it);
; - when a client changes size or its frame changes, the clip follows it;
; - if the clip disappears it's put back. If an arranged client keeps losing
;   it, that client is switched to removing its title bar instead.
ClipGuard() {
    static drops := Map(), noted := Map()
    if (!HideBorders || BorderMode() != "Clip" || Switching)
        return
    for n, id in Slots {
        if (!id || StripFallback.Has(id) || KeepFrame.Has(id))
            continue
        try {
            if (WinGetMinMax("ahk_id " id) = -1)          ; minimized
                continue
            have := RegionKey(id)
            if (have = ClipKey(id) && !DwmFrameOn(id))
                continue
            if (!ClipFor.Has(id)) {
                if ClipToPicture(id)
                    WriteLog("slot " n ": title bar hidden as soon as the client appeared - " WinDesc(id))
                continue
            }
            if (have != "" || !Placed.Has(id)) {
                ; still clipped but the window changed (EverQuest resized it
                ; or redrew its frame), or the client is still starting up
                ClipToPicture(id)
                if (!noted.Has(id) || A_TickCount - noted[id] > 5000) {
                    noted[id] := A_TickCount
                    WriteLog("slot " n ": window changed - clip follows it - " WinDesc(id))
                }
                continue
            }
            now := A_TickCount
            if !drops.Has(id)
                drops[id] := []
            list := drops[id]
            list.Push(now)
            while (list.Length && now - list[1] > 10000)
                list.RemoveAt(1)
            if (list.Length > 6) {
                WriteLog("slot " n ": the clip keeps disappearing - switching this client to removing its title bar instead - " WinDesc(id))
                UseStripFor(id)
                continue
            }
            WriteLog("slot " n ": clip was gone - putting it back - " WinDesc(id))
            ClipToPicture(id)
        }
    }
}

PlaceClipped(id, x, y, w, h) {
    try {
        if (WinGetMinMax("ahk_id " id) = -1)
            WinRestore("ahk_id " id)
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " id)
        WinGetClientPos(&px, &py, &pw, &ph, "ahk_id " id)
    } catch
        return false
    n := SlotOf(id)
    sizeOK := (Abs(pw - w) <= 1 && Abs(ph - h) <= 1)
    posOK := (px = x && py = y)
    clipOK := ClipIsRight(id) || KeepFrame.Has(id)
    Placed[id] := true
    if (sizeOK && posOK && clipOK)
        return false
    if (sizeOK && posOK) {
        ; only the clip is missing: put it back, nothing else to change
        WriteLog("slot " n ": picture in place, applying the clip - " WinDesc(id))
        ClipToPicture(id)
        return true
    }
    ; while running, a size EverQuest chose itself is accepted (no fighting)
    if (Enforcing && !sizeOK && posOK && clipOK)
        return false
    ; while running (not a manual Arrange), never fight EverQuest over size
    resizing := !sizeOK && !Enforcing
    tw := resizing ? w : pw, th := resizing ? h : ph
    ; frame sizes around the picture (0 if it has none)
    fl := px - ox, ft := py - oy, fr := ox + ow - px - pw, fb := oy + oh - py - ph
    WriteLog("slot " n ": placing picture at " x "," y " " tw "x" th
        . (resizing ? " (picture " pw "x" ph " -> " w "x" h ", telling EverQuest to redraw)" : "")
        . (Enforcing ? " (it had moved)" : "") " - before: " WinDesc(id))
    if resizing
        try SendMessage(0x231, 0, 0, , "ahk_id " id, , , , 1000)        ; WM_ENTERSIZEMOVE
    ; SWP_NOZORDER | SWP_NOACTIVATE
    DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x - fl, "Int", y - ft
        , "Int", tw + fl + fr, "Int", th + ft + fb, "UInt", 0x14)
    if resizing
        try SendMessage(0x232, 0, 0, , "ahk_id " id, , , , 1000)        ; WM_EXITSIZEMOVE
    ClipToPicture(id)
    ArrangedAt[id] := A_TickCount
    SetTimer(FollowUpClip.Bind(id, x, y, w, h, 14), -900)
    SetTimer(LogAfter.Bind(id, "1 s after placing"), -1000)
    if Enforcing
        NoteFix(id)
    return true
}

; After placing, check until the picture is exactly the slot and clipped.
; Only act once the window looked the same on two checks in a row (EverQuest
; adjusts its window a moment after a resize).
FollowUpClip(id, x, y, w, h, tries, *) {
    static lastSeen := Map()
    if (!WinExist("ahk_id " id) || StripFallback.Has(id))
        return
    n := SlotOf(id)
    desc := WinDesc(id)
    if (!lastSeen.Has(id) || lastSeen[id] != desc) {
        lastSeen[id] := desc
        if (tries > 1)
            SetTimer(FollowUpClip.Bind(id, x, y, w, h, tries - 1), -900)
        return
    }
    try {
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " id)
        WinGetClientPos(&px, &py, &pw, &ph, "ahk_id " id)
        sizeOK := (Abs(pw - w) <= 1 && Abs(ph - h) <= 1)
        posOK := (px = x && py = y)
        clipOK := ClipIsRight(id) || KeepFrame.Has(id)
        if (sizeOK && posOK && clipOK) {
            WriteLog("slot " n ": in place - " desc)
            lastSeen.Delete(id)
            return
        }
        fl := px - ox, ft := py - oy, fr := ox + ow - px - pw, fb := oy + oh - py - ph
        if !sizeOK {
            WriteLog("slot " n ": picture is " pw "x" ph ", want " w "x" h " - resizing (keeping its frame) - " desc)
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x - fl, "Int", y - ft
                , "Int", w + fl + fr, "Int", h + ft + fb, "UInt", 0x14)
        } else if !posOK {
            WriteLog("slot " n ": picture at " px "," py ", want " x "," y " - moving - " desc)
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x - fl, "Int", y - ft, "Int", 0, "Int", 0, "UInt", 0x15)
        }
        ClipToPicture(id)
        ArrangedAt[id] := A_TickCount
    }
    lastSeen[id] := ""
    if (tries > 1)
        SetTimer(FollowUpClip.Bind(id, x, y, w, h, tries - 1), -900)
    else
        SetTimer(LogAfter.Bind(id, "after the last check"), -900)
}

; EverQuest's behaviour (seen in MMORPGBoxer.log): whenever its picture area
; changes size, it adopts that size as its resolution and puts its title bar
; back. So after arranging, check a few times and steer it to "no borders,
; picture exactly the slot size", never letting the picture pass through a
; wrong size on the way.
FollowUpPlace(id, x, y, w, h, tries, *) {
    if !WinExist("ahk_id " id)
        return
    static lastSeen := Map()
    n := SlotOf(id)
    ; EverQuest re-applies its frame a moment AFTER a resize. Changing the
    ; window while it is still doing that gets undone (MMORPGBoxer.log showed it
    ; flip back and forth). So only act once the window looked the same on
    ; two checks in a row.
    desc := WinDesc(id)
    if (!lastSeen.Has(id) || lastSeen[id] != desc) {
        lastSeen[id] := desc
        if (tries > 1)
            SetTimer(FollowUpPlace.Bind(id, x, y, w, h, tries - 1), -900)
        return
    }
    try {
        WinGetClientPos(&px, &py, &pw, &ph, "ahk_id " id)
        bordered := WinGetStyle("ahk_id " id) & 0xC40000
        sizeOK := (Abs(pw - w) <= 1 && Abs(ph - h) <= 1)
        if (bordered && sizeOK) {
            ; picture is right, just the title bar is back: remove it while
            ; keeping the picture exactly where and how big it is
            WriteLog("slot " n ": EverQuest redrew at " pw "x" ph " and put its title bar back - removing it in one step - " WinDesc(id))
            SetNoBorderStyle(id)
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x34)
        } else if bordered {
            ; picture is the wrong size: size the bordered window so the
            ; picture becomes the slot size; next check removes the border
            WriteLog("slot " n ": picture is " pw "x" ph ", want " w "x" h " - resizing it (with its border) - " WinDesc(id))
            ResizeBorderedTo(id, x, y, w, h)
        } else if !sizeOK {
            WriteLog("slot " n ": picture is " pw "x" ph " without border, want " w "x" h " - resizing - " WinDesc(id))
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x34)
        } else if (px != x || py != y) {
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x15)
        } else {
            WriteLog("slot " n ": in place - " WinDesc(id))
            lastSeen.Delete(id)
            return                                ; done: no border, right size, right place
        }
        ArrangedAt[id] := A_TickCount
    }
    lastSeen[id] := ""                            ; we just changed it: wait for it to settle again
    if (tries > 1)
        SetTimer(FollowUpPlace.Bind(id, x, y, w, h, tries - 1), -900)
    else
        SetTimer(LogAfter.Bind(id, "after the last check"), -900)
}

; Remove title bar + sizing border from the style WITHOUT re-laying out the
; window. The next SetWindowPos (with SWP_FRAMECHANGED) applies it together
; with the final size, so the picture area never changes size on its own.
SetNoBorderStyle(id) {
    st := DllCall("GetWindowLongPtrW", "Ptr", id, "Int", -16, "Ptr")     ; GWL_STYLE
    DllCall("SetWindowLongPtrW", "Ptr", id, "Int", -16, "Ptr", st & ~0xC40000, "Ptr")
}

; Size a window that has its border so its PICTURE is w x h at x,y.
ResizeBorderedTo(id, x, y, w, h) {
    rc := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", w, "Int", h, rc)
    DllCall("AdjustWindowRectEx", "Ptr", rc, "UInt", WinGetStyle("ahk_id " id), "Int", 0, "UInt", WinGetExStyle("ahk_id " id))
    l := NumGet(rc, 0, "Int"), t := NumGet(rc, 4, "Int"), r := NumGet(rc, 8, "Int"), bt := NumGet(rc, 12, "Int")
    DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x + l, "Int", y + t, "Int", r - l, "Int", bt - t, "UInt", 0x14)
}

LogAfter(id, label, *) {
    WriteLog("slot " SlotOf(id) ": " label " - " WinDesc(id))
}

NoteFix(id) {
    ; If a client keeps undoing our layout, stop fighting it.
    now := A_TickCount
    if !Fixes.Has(id)
        Fixes[id] := []
    list := Fixes[id]
    list.Push(now)
    while (list.Length && now - list[1] > 15000)
        list.RemoveAt(1)
    if (list.Length >= 3) {
        Unmanaged[id] := true
        WriteLog("slot " SlotOf(id) ": keeps moving/resizing itself - stopped arranging it - " WinDesc(id))
        n := SlotOf(id)
        Status("Slot " n " keeps resizing itself - stopped auto-arranging it. Ctrl+Alt+G to retry.", 6000)
    }
}

PlaceWindow(id, x, y, w, h) {
    moved := false
    if !IsSettled(id)
        return false
    if (Enforcing && Unmanaged.Has(id))
        return false
    if (HideBorders && BorderMode() = "Clip" && !StripFallback.Has(id))
        return PlaceClipped(id, x, y, w, h)
    ; After a client has been arranged once, leave its size alone: fighting
    ; EverQuest over size makes the picture shrink, grow or stretch. Only step
    ; in again if EverQuest has put its title bar/borders back on.
    if (Enforcing && Unmanaged.Has(id))
        return false
    if (Enforcing && Placed.Has(id)) {
        try {
            if !(HideBorders && (WinGetStyle("ahk_id " id) & 0xC40000)) {
                ; Borders still off. If EverQuest moved its window but kept the
                ; size, move it back (moving is safe - only resizing makes
                ; EverQuest draw a wrong-sized picture). Never resize here.
                WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " id)
                if (HideBorders && Abs(cw - w) <= 2 && Abs(ch - h) <= 2 && (cx != x || cy != y)) {
                    ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
                    WriteLog("slot " SlotOf(id) ": moved by EverQuest, moving back to " x "," y " - was " WinDesc(id))
                    DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x15)
                    NoteFix(id)
                    return true
                }
                return false
            }
        } catch
            return false
    }
    try {
        if (WinGetMinMax("ahk_id " id) = -1)
            WinRestore("ahk_id " id)
        ; picture size BEFORE anything changes, and the picture size we want
        WinGetClientPos(, , &pw, &ph, "ahk_id " id)
        tw := w, th := h
        ; Borders are removed in the same step as the final size is set (see
        ; below). Removing them on their own makes the picture area briefly
        ; as big as the whole old window, and EverQuest adopts that size.
        styleChanged := HideBorders && (WinGetStyle("ahk_id " id) & 0xC40000)
        if !HideBorders {
            ; Keep borders but size the window so the CLIENT area (what the
            ; game draws and maps the mouse to) is exactly w x h at x,y.
            rc := Buffer(16, 0)
            NumPut("Int", 0, "Int", 0, "Int", w, "Int", h, rc)
            DllCall("AdjustWindowRectEx", "Ptr", rc, "UInt", WinGetStyle("ahk_id " id)
                  , "Int", 0, "UInt", WinGetExStyle("ahk_id " id))
            l := NumGet(rc, 0, "Int"), t := NumGet(rc, 4, "Int")
            r := NumGet(rc, 8, "Int"), b := NumGet(rc, 12, "Int")
            x += l, y += t, w := r - l, h := b - t
        }
        WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " id)
        if (styleChanged || cx != x || cy != y || cw != w || ch != h) {
            ; SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
            flags := 0x0004 | 0x0010 | 0x0020
            ; Only a change of PICTURE size needs EverQuest to redraw. Then we
            ; tell it a resize started and finished (as when you drag a window
            ; edge) so it redraws at the new size. When the picture size stays
            ; the same (just taking borders off, or moving) we must NOT send
            ; that: EverQuest would rebuild its window with a border again,
            ; and repeating it makes the window grow every time.
            resizing := (Abs(pw - tw) > 1 || Abs(ph - th) > 1)
            WriteLog("slot " SlotOf(id) ": arranging to " x "," y " " w "x" h
                . (resizing ? " (picture " pw "x" ph " -> " tw "x" th ", telling EverQuest to redraw)" : " (picture size unchanged)")
                . (Enforcing ? " (borders came back)" : "") " - before: " WinDesc(id))
            if resizing
                try SendMessage(0x231, 0, 0, , "ahk_id " id, , , , 1000)    ; WM_ENTERSIZEMOVE
            if styleChanged
                SetNoBorderStyle(id)              ; style only - applied by the SetWindowPos below
            DllCall("SetWindowPos", "Ptr", id, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
            if resizing
                try SendMessage(0x232, 0, 0, , "ahk_id " id, , , , 1000)    ; WM_EXITSIZEMOVE
            ; EverQuest answers a new picture size by redrawing at it AND
            ; putting its title bar back. Check a few times and tidy up.
            if HideBorders
                SetTimer(FollowUpPlace.Bind(id, x, y, w, h, 14), -900)
            ArrangedAt[id] := A_TickCount
            SetTimer(LogAfter.Bind(id, "1 s after arranging"), -1000)
            SetTimer(LogAfter.Bind(id, "5 s after arranging"), -5000)
            moved := true
            if Enforcing
                NoteFix(id)
        }
    }
    if (moved || IsSettled(id))
        Placed[id] := true
    return moved
}

Arrange(*) {
    RefreshSlots()
    ArrangeCurrent()
    RefreshVFX()
    RefreshPanel()
}

; Manual Arrange: re-send position and size to every client even if it
; already looks right, so each game re-reads its window area (fixes a
; client whose mouse no longer lines up).
ManualArrange(*) {
    global ForceResync
    Unmanaged.Clear()
    Fixes.Clear()
    KeepFrame.Clear()
    ForceResync := true
    try Arrange()
    ForceResync := false
    ; also make every client redraw at its window size (fixes a stretched
    ; picture, e.g. after logging out to server select)
    SetTimer(ResyncAll, -1500)
    Status("Arranged and re-synced " CountClients() " client(s).", 4000)
}

; The screen area layouts use: the whole monitor, or (UseWorkArea=1) the part
; above/beside the taskbar.
LayoutArea(&L, &T, &W, &H) {
    if UseWorkArea
        MonitorGetWorkArea(MonitorNum, &L, &T, &R, &B)
    else
        MonitorGet(MonitorNum, &L, &T, &R, &B)
    W := R - L, H := B - T
}

; Grid cell size: [Grid] Width/Height, shrunk if the grid doesn't fit the area.
GridCell(areaW, areaH, &cw, &ch) {
    rows := Ceil(MAX_SLOTS / GridCols)
    cw := Min(GridW, areaW // GridCols)
    ch := Min(GridH, areaH // Max(1, rows))
}

ArrangeGrid() {
    moved := 0
    LayoutArea(&mL, &mT, &mW, &mH)
    for n, id in Slots {
        if !id
            continue
        c := CellFor(n)
        moved += PlaceWindow(id, c.x, c.y, c.w, c.h)
    }
    return moved
}

ArrangeSwap() {
    global MainSlot
    LayoutArea(&mL, &mT, &mW, &mH)
    if !(MainSlot >= 1 && MainSlot <= MAX_SLOTS && Slots[MainSlot])
        MainSlot := FirstSlot()
    moved := 0
    i := 0
    for n, id in Slots {
        if !id
            continue
        if (n = MainSlot) {
            r := MainRegion
        } else {
            if (SmallRegions.Length = 0)
                continue
            i++
            r := SmallRegions[Min(i, SmallRegions.Length)]
        }
        moved += PlaceWindow(id, mL + r.x, mT + r.y, r.w, r.h)
    }
    return moved
}

ArrangeCurrent() {
    if (Layout = "Swap")
        return ArrangeSwap()
    if Presets.Has(Layout)
        return ArrangePreset()
    return ArrangeGrid()
}

ArrangePreset() {
    moved := 0
    LayoutArea(&mL, &mT, &mW, &mH)
    P := Presets[Layout]
    for n, id in Slots {
        if (!id || !P.Has(n))
            continue
        c := CellFor(n)
        moved += PlaceWindow(id, c.x, c.y, c.w, c.h)
    }
    return moved
}

LayoutNames() {
    names := ["Grid", "Swap"]
    for name in PresetOrder
        names.Push(name)
    return names
}

; Ctrl+Alt+S: next layout in the list
; What each built-in layout is for (shown in the Layouts window and wizard).
LayoutDesc(name) {
    static d := 0
    if !d {
        d := Map()
        d["Grid"] := "Equal windows in rows ([Grid] Columns per row), each up to the grid size. Every client is the same size: good for 2 to 4 clients you play equally."
        d["Swap"] := "One big main area and a column of small windows. The client you switch to (Ctrl+F1...F8, or clicking it) swaps into the big area, so you always play in the big window and glance at the rest."
        d["Top + 2 Bottom"] := "Slot 1 fills the whole top half. Slots 2 and 3 share the bottom half side by side. For 3 clients: a main you watch closely and two you glance at."
        d["Top Center + 2 Bottom"] := "Slot 1 sits in the middle of the top half at the same size as the others, leaving the top corners free for chat, a map or the toolbar. Slots 2 and 3 share the bottom half."
        d["Top + 3 Bottom"] := "Slot 1 fills the whole top half. Slots 2, 3 and 4 share the bottom half in thirds. For 4 clients with one main."
        d["Left + 2 Right"] := "Slot 1 takes the left half at full height. Slots 2 and 3 are stacked on the right half. A tall main window, good for 3 clients."
        d["Big + 3 Right"] := "Slot 1 gets three quarters of the width and height. Slots 2, 3 and 4 are small windows down the right edge. The strip along the bottom stays free (toolbar, chat)."
        d["Side by Side"] := "Two clients, each half the width and the full height."
        d["Top / Bottom"] := "Two clients, each the full width and half the height."
        d["Big + 4 Bottom"] := "Slot 1 fills the top three quarters. Slots 2 to 5 are small windows along the bottom. For 5 clients with one main."
    }
    if d.Has(name)
        return d[name]
    return "Your own layout, saved from where your windows were. Each slot goes back to that exact place and size."
}

; how many slots a layout has room for (8 = any number)
LayoutPlaces(name) {
    if Presets.Has(name)
        return Presets[name].Count
    if (name = "Swap")
        return 1 + SmallRegions.Length
    return 8
}

; Draw cells (relative to the layout area) into a preview box.
DrawPreview(box, rects, cells, labels) {
    LayoutArea(&L, &T, &W, &H)
    box.GetPos(&bx, &by, &bw, &bh)
    f := Min((bw - 2) / W, (bh - 2) / H)
    for n, r in rects {
        c := (n <= cells.Length) ? cells[n] : 0
        if !c {
            r.Visible := false
            continue
        }
        r.Move(bx + 1 + Round(c.x * f), by + 1 + Round(c.y * f), Max(8, Round(c.w * f) - 1), Max(8, Round(c.h * f) - 1))
        r.Text := (n <= labels.Length) ? labels[n] : n
        r.Visible := true
    }
}

SlotColours() => ["2E5A88", "2E7D32", "8E3B3B", "6A4C93", "B8860B", "00695C", "5D4037", "455A64"]

ShowLayouts(*) {
    global LW
    g := 0
    LBtn(opts, label, fn, tip) {
        btn := g.AddButton(opts, label)
        btn.OnEvent("Click", fn)
        AddTip(btn, tip)
        return btn
    }
    if !LW {
        g := Gui(, APP " - Layouts")
        g.SetFont("s10", "Segoe UI")
        LW := {gui: g, rects: []}
        Hint(g.AddText("xm w790", "Pick a layout to see where each of your slots goes. Use This Layout switches to it straight away (Ctrl+Alt+S steps to the next one)."))
        LW.list := g.AddListView("xm y+10 w240 r15 Section -Hdr -Multi", ["Layout"])
        LW.list.ModifyCol(1, 214)
        LVFill(LW.list, LayoutNames(), LayoutIndex(Layout))
        LW.list.OnEvent("ItemSelect", (lv, row, sel) => sel ? LayoutsShow() : 0)
        LW.list.OnEvent("DoubleClick", (*) => LayoutsUse())
        LW.box := Keep(g.AddText("x+14 ys w536 h300 Border Background101010"))
        g.SetFont("s11 w600")
        LW.name := g.AddText("xp y+10 w536", "")
        g.SetFont("s10 w400")
        LW.desc := g.AddText("xp y+4 w536 h66", "")
        LW.sizes := Hint(g.AddText("xp y+4 w536 h96", ""))
        for col in SlotColours()
            LW.rects.Push(Keep(g.AddText("xs ys w10 h10 Center 0x200 Border cFFFFFF Background" col, A_Index)))
        LW.use := LBtn("xs ys+516 w180 h32 Default", "Use This Layout", (*) => LayoutsUse(), TipText("Switch to the selected layout; running clients move straight away", "ToggleLayout", "^!s"))
        LBtn("x+8 yp w220 h32", "Save Current Positions...", (*) => LayoutsSave(), TipText("Save where your windows are right now as a new layout"))
        LW.del := LBtn("x+8 yp w150 h32", "Delete Layout", (*) => LayoutsDelete(), TipText("Delete the selected layout (only layouts you saved yourself)"))
        LBtn("x+8 yp w150 h32", "Close", (*) => g.Hide(), TipText("Close this window"))
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())
        ThemeGui(g)
    }
    LW.gui.Show()
    LayoutsRefresh(Layout)
}

; Fill a one-column list and select row sel.
LVFill(lv, items, sel := 1) {
    lv.Opt("-Redraw")
    lv.Delete()
    for x in items
        lv.Add(, x)
    if (sel >= 1 && sel <= items.Length)
        lv.Modify(sel, "Select Focus Vis")
    lv.Opt("+Redraw")
}

; text of a list's selected row ("" if none)
LVSelText(lv) {
    row := lv.GetNext(0)
    return row ? lv.GetText(row) : ""
}

; position of a layout in LayoutNames() (1 if it isn't there)
LayoutIndex(name) {
    for i, x in LayoutNames()
        if (x = name)
            return i
    return 1
}

LayoutsVisible() => (LW && DllCall("IsWindowVisible", "Ptr", LW.gui.Hwnd))

LayoutsRefresh(select := "") {
    if !LayoutsVisible()
        return
    if (select = "")
        select := LVSelText(LW.list) != "" ? LVSelText(LW.list) : Layout
    LVFill(LW.list, LayoutNames(), LayoutIndex(select))
    LayoutsShow()
}

LayoutsShow() {
    name := LVSelText(LW.list)
    if (name = "")
        return
    LayoutArea(&L, &T, &W, &H)
    cells := [], labels := [], sizes := "", missing := ""
    Loop MAX_SLOTS {
        n := A_Index
        c := CellIn(name, n)
        cells.Push(c ? {x: c.x - L, y: c.y - T, w: c.w, h: c.h} : 0)
        labels.Push(n (Chars[n] != "" ? " " Chars[n] : ""))
        if c
            sizes .= "Slot " n (Chars[n] != "" ? " (" Chars[n] ")" : "") ":  " c.w " x " c.h "`n"
        else
            missing .= (missing = "" ? "" : ", ") n
    }
    DrawPreview(LW.box, LW.rects, cells, labels)
    LW.name.Value := name (name = Layout ? "   (in use)" : "") "   -   room for " (LayoutPlaces(name) >= 8 ? "any number of" : LayoutPlaces(name)) " slot(s)"
    LW.desc.Value := LayoutDesc(name)
    LW.sizes.Value := sizes (missing != "" ? "No place for slot(s) " missing " - pick a layout with more spaces or use fewer slots." : "")
    LW.del.Enabled := !HasVal(BuiltinLayouts, name)
}

LayoutsUse() {
    name := LVSelText(LW.list)
    if (name != "")
        SetLayout(name)
    LayoutsRefresh(name)
}

LayoutsSave() {
    SaveLayout()
    LayoutsRefresh(Layout)
}

LayoutsDelete() {
    name := LVSelText(LW.list)
    if (name = "" || HasVal(BuiltinLayouts, name))
        return
    if (MsgBox("Delete the layout '" name "'?", APP, "YesNo Icon? Owner" LW.gui.Hwnd) != "Yes")
        return
    try IniDelete(CFG_FILE, "Layout." name)
    try Presets.Delete(name)
    for i, x in PresetOrder
        if (x = name) {
            PresetOrder.RemoveAt(i)
            break
        }
    if (Layout = name)
        SetLayout("Grid")
    LayoutsRefresh(Layout)
    Status("Deleted layout '" name "'")
}

ToggleLayout(*) {
    names := LayoutNames()
    i := 1
    for k, name in names
        if (name = Layout)
            i := k
    SetLayout(names[Mod(i, names.Length) + 1])
}

SetLayout(name) {
    global Layout
    if (name = Layout)
        return
    Layout := name
    IniWrite(name, CFG_FILE, "General", "Layout")
    Unmanaged.Clear()
    Fixes.Clear()
    Arrange()
    PrepFreeSlotIni()
    if LayoutDDL
        try LayoutDDL.Text := name
    LayoutsRefresh()
    msg := "Layout: " name
    if CountClients()
        msg .= "`nRestart running clients so they draw at the new sizes and the mouse lines up."
    Status(msg, 6000)
}

LayoutChanged(ctrl, *) => SetLayout(ctrl.Text)

; Built-in presets are fractions of the monitor, so they fit any screen.
; Custom presets come from [Layout.Name] sections (pixels from the monitor's
; top-left corner): 1=x,y,w,h
LoadPresets() {
    LayoutArea(&mL, &mT, &mW, &mH)
    W := mW, H := mH
    third := 1 / 3
    builtins := [
        ["Top + 2 Bottom",  [[0, 0, 1, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]],
        ["Top Center + 2 Bottom", [[0.25, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]],
        ["Top + 3 Bottom",  [[0, 0, 1, 0.5], [0, 0.5, third, 0.5], [third, 0.5, third, 0.5], [2 * third, 0.5, third, 0.5]]],
        ["Left + 2 Right",  [[0, 0, 0.5, 1], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]],
        ["Big + 3 Right",   [[0, 0, 0.75, 0.75], [0.75, 0, 0.25, 0.25], [0.75, 0.25, 0.25, 0.25], [0.75, 0.5, 0.25, 0.25]]],
        ["Side by Side",    [[0, 0, 0.5, 1], [0.5, 0, 0.5, 1]]],
        ["Top / Bottom",    [[0, 0, 1, 0.5], [0, 0.5, 1, 0.5]]],
        ["Big + 4 Bottom",  [[0, 0, 1, 0.75], [0, 0.75, 0.25, 0.25], [0.25, 0.75, 0.25, 0.25], [0.5, 0.75, 0.25, 0.25], [0.75, 0.75, 0.25, 0.25]]]
    ]
    for b in builtins {
        BuiltinLayouts.Push(b[1])
        P := Map()
        for n, f in b[2]
            P[n] := {x: Round(f[1] * W), y: Round(f[2] * H), w: Round(f[3] * W), h: Round(f[4] * H)}
        Presets[b[1]] := P
        PresetOrder.Push(b[1])
    }
    sections := ""
    try sections := IniRead(CFG_FILE)
    for sec in StrSplit(sections, "`n") {
        if (SubStr(sec, 1, 7) != "Layout.")
            continue
        name := SubStr(sec, 8)
        P := Map()
        for line in StrSplit(CfgSection(sec), "`n") {
            kv := StrSplit(line, "=", , 2)
            if (kv.Length = 2 && IsInteger(Trim(kv[1])))
                P[Integer(Trim(kv[1]))] := ParseRect(kv[2])
        }
        if (P.Count = 0)
            continue
        if !Presets.Has(name)
            PresetOrder.Push(name)
        Presets[name] := P
    }
}

; Save where the clients are right now as a new layout.
SaveLayout(*) {
    RefreshSlots()
    if (CountClients() = 0)
        return Status("Start your clients and place them first")
    ib := InputBox("Name for this layout (uses where each client is right now):", APP " - Save Layout", "w360 h130")
    if (ib.Result != "OK")
        return
    name := Trim(StrReplace(StrReplace(ib.Value, "[", ""), "]", ""))
    if (name = "" || name = "Grid" || name = "Swap")
        return Status("Pick a different name")
    LayoutArea(&mL, &mT, &mW, &mH)
    sec := "Layout." name
    try IniDelete(CFG_FILE, sec)
    P := Map()
    for n, id in Slots {
        if !id
            continue
        try WinGetClientPos(&x, &y, &w, &h, "ahk_id " id)
        catch
            continue
        P[n] := {x: x - mL, y: y - mT, w: w, h: h}
        IniWrite((x - mL) "," (y - mT) "," w "," h, CFG_FILE, sec, String(n))
    }
    if !Presets.Has(name)
        PresetOrder.Push(name)
    Presets[name] := P
    SetLayout(name)
    if LayoutDDL
        try LayoutDDL.Text := name
    LayoutsRefresh(name)
    Status("Saved layout '" name "'")
}

RestoreBorders(*) {
    for id in Slots
        if id {
            KeepFrame[id] := true
            try SetDwmFrame(id, 0)
            try DllCall("SetWindowRgn", "Ptr", id, "Ptr", 0, "Int", 1)
            ClipFor.Delete(id)
            try WinSetStyle("+0xC40000", "ahk_id " id)
        }
    Status("Window borders restored (until the next Arrange)")
}

CheckActive() {
    global MainSlot
    if (Layout != "Swap" || !SwapOnActivate || A_IsSuspended || Launching || Switching)
        return
    id := WinActive(EQ)
    if !id
        return
    n := SlotOf(id)
    if (n && n != MainSlot) {
        MainSlot := n
        ArrangeSwap()
        RefreshVFX()
        RefreshPanel()
    }
}

; ------------------------------ Switching -----------------------------
FocusSlot(n, *) {
    global MainSlot
    RefreshSlots()
    if !(n >= 1 && n <= MAX_SLOTS && Slots[n]) {
        Status("No client in slot " n)
        return
    }
    if (Layout = "Swap" && n != MainSlot) {
        MainSlot := n
        ArrangeSwap()
        RefreshVFX()
    }
    try WinActivate("ahk_id " Slots[n])
    RefreshPanel()
}

FocusNext(*) {
    RefreshSlots()
    cur := SlotOf(WinActive(EQ))
    Loop MAX_SLOTS {
        n := Mod(cur + A_Index - 1, MAX_SLOTS) + 1
        if Slots[n] {
            FocusSlot(n)
            return
        }
    }
}

AssignSlot(n, *) {
    global MainSlot
    RefreshSlots()
    id := WinActive(EQ)
    cur := SlotOf(id)
    if (!id || !cur || cur = n)
        return
    tmp := Slots[n]
    Slots[n] := id
    Slots[cur] := tmp
    if (MainSlot = cur)
        MainSlot := n
    UpdateTitles()
    Arrange()
    Status("This client is now slot " n)
}

; ------------------------------- Launcher -----------------------------
LaunchAll(*) {
    global Launching, IniStamp
    if (GameDef.launchers.Length) {
        ; started (and logged in) from the game's own launcher; MMORPG Boxer
        ; puts each client in the next free slot as its window opens
        if (exe := LauncherExe())
            Run('"' exe '"', EQPath)
        else
            MsgBox("Couldn't find the " GameDef.name " launcher in " EQPath ".`n`nSet the folder in the Setup Wizard (Ctrl+Alt+W), or start the launcher yourself.", APP, "Icon!")
        Status("Start each character from the " GameDef.name " launcher. MMORPG Boxer puts each window in the next free slot as it opens (Ctrl+Alt+F1-F" MAX_SLOTS " moves a client to another slot).", 12000)
        return
    }
    exe := EQPath "\" EQExe
    if !FileExist(exe) {
        MsgBox("Can't find " exe "`n`nSet EQPath in MMORPGBoxer.ini.", APP, "Icon!")
        return
    }
    RefreshSlots()
    Launching := true
    try {
        Loop MAX_SLOTS {
            n := A_Index
            if (Chars[n] = "" || Slots[n])
                continue
            before := WinGetList(EQ)
            if ProfilesOn
                LoadProfile(n, true)          ; this character's own eqclient.ini
            PrepareSlotIni(n, true)
            Status("Launching slot " n " (" Chars[n] ")...", 0)
            args := LaunchArgs
            if (Cfg("Login", "UseLoginArg", "1") = "1") {
                ; EverQuest's own /login: switch pre-fills the username box
                user := SlotUser(n)
                if (user != "")
                    args .= " /login:" user
            }
            WriteLog("launching slot " n " (" Chars[n] ")")
            Run('"' exe '" ' args, EQPath)
            id := WaitNewWindow(before, 90000, n)
            if id {
                Slots[n] := id
                NoteStart(id)
                UpdateTitles()
                ApplyCpu(n)
                ; wait until this client has finished starting (its window
                ; stopped changing) and has been arranged, before the next one
                start := A_TickCount
                while (!IsSettled(id) && A_TickCount - start < 60000)
                    Sleep(500)
                ArrangeCurrent()
            }
            Sleep(LaunchDelay)
        }
    } catch as e {
        MsgBox("Launch failed:`n" e.Message, APP, "Icon!")
    }
    Launching := false
    IniStamp := FileStamp(EqIni())     ; our own writes while launching aren't EverQuest's
    Arrange()
    Status("Launch complete - " CountClients() " client(s)")
}

WaitNewWindow(before, timeout, n := 0) {
    start := A_TickCount
    while (A_TickCount - start < timeout) {
        for id in WinGetList(EQ)
            if (!HasVal(before, id) && !SlotOf(id) && IsGameWindow(id))
                return id
        ; Other running clients can rewrite eqclient.ini at any moment, so keep
        ; this slot's position in it until the new client has read it.
        if n
            PrepareSlotIni(n)
        Sleep(250)
    }
    return 0
}

NoteStart(id) {
    if StartPos.Has(id)
        return
    try {
        WinGetPos(&x, &y, , , "ahk_id " id)
        StartPos[id] := {x: x, y: y}
    }
}

; True if the client opened somewhere other than its slot. EverQuest maps the
; mouse from where it opened, so such a client needs a restart.
OpenedOffSlot(n) {
    id := Slots[n]
    if (!id || !Settle.Has(id) || !Settle[id].ok)
        return false
    if (!Placed.Has(id) || (ArrangedAt.Has(id) && A_TickCount - ArrangedAt[id] < 10000))
        return false                      ; not arranged yet, or just being arranged
    c := CellFor(n)
    if !c
        return false
    try {
        if (HideBorders && BorderMode() = "Strip" && (WinGetStyle("ahk_id " id) & 0xC40000))
            return false                  ; not arranged yet
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " id)
    } catch
        return false
    return (Abs(x - c.x) > 6 || Abs(y - c.y) > 6 || Abs(w - c.w) > 6 || Abs(h - c.h) > 6)
}

CheckOffSlot() {
    for n, id in Slots {
        if (!id || OffSlotWarned.Has(id) || !OpenedOffSlot(n))
            continue
        OffSlotWarned[id] := true
        Status("Slot " n " isn't exactly in its slot - close it and start it again with MMORPG Boxer running.", 10000)
        return
    }
}

; ------------------------------- Key maps -----------------------------
LoadKeyMaps() {
    if !GameDef.together
        return                      ; key maps reach other clients: not for this game
    sections := ""
    try sections := IniRead(CFG_FILE)
    for sec in StrSplit(sections, "`n") {
        if (SubStr(sec, 1, 7) != "KeyMap.")
            continue
        hk := Cfg(sec, "Hotkey", "")
        if (hk = "")
            continue
        km := {Name: SubStr(sec, 8), Hotkey: hk, Steps: [], Idx: 1, Last: 0
             , Reset: ToInt(Cfg(sec, "ResetAfter", "0"), 0) * 1000}
        Loop 50 {
            s := Cfg(sec, "Step" A_Index, "")
            if (s = "")
                break
            actions := []
            for a in StrSplit(s, "&&", " `t")
                if (a != "")
                    actions.Push(a)
            km.Steps.Push(actions)
        }
        if (km.Steps.Length = 0)
            continue
        HotIfWinActive(EQ)
        ok := TryHotkey("$" hk, RunKeyMap.Bind(km))
        HotIfWinActive()
        if ok {
            KeyMaps.Push(km)
            KeyMapBaseKeys[RegExReplace(hk, "^[~*$!^+#<>]+")] := true
        }
    }
}

RunKeyMap(km, *) {
    now := A_TickCount
    if (km.Reset > 0 && km.Last && now - km.Last > km.Reset)
        km.Idx := 1
    km.Last := now
    step := km.Steps[km.Idx]
    km.Idx := Mod(km.Idx, km.Steps.Length) + 1
    for action in step
        DoAction(action)
}

DoAction(action) {
    parts := StrSplit(action, ":", , 2)
    if (parts.Length < 2)
        return
    target := Trim(parts[1])
    arg := Trim(parts[2])
    if (target = "Focus") {
        if IsInteger(arg)
            FocusSlot(Integer(arg))
        return
    }
    SendTo(ResolveTarget(target), arg)
}

ResolveTarget(t) {
    active := WinActive(EQ)
    out := []
    if (t = "All") {
        for id in Slots
            if id
                out.Push(id)
    } else if (t = "Others") {
        for id in Slots
            if (id && id != active)
                out.Push(id)
    } else if (t = "Active") {
        if active
            out.Push(active)
    } else if RegExMatch(t, "i)^(?:slot)?(\d+)$", &m) {
        n := Integer(m[1])
        if (n >= 1 && n <= MAX_SLOTS && Slots[n])
            out.Push(Slots[n])
    } else if Groups.Has(t) {
        for n in Groups[t]
            if (n >= 1 && n <= MAX_SLOTS && Slots[n])
                out.Push(Slots[n])
    }
    return out
}

SendTo(ids, keys) {
    active := WinActive("A")
    for id in ids {
        if (id = active)
            SendInput(keys)
        else
            try ControlSend(keys, , "ahk_id " id)
    }
}

; ------------------------------ Broadcast -----------------------------
AllKeys() {
    keys := []
    Loop 26
        keys.Push(Chr(96 + A_Index))
    Loop 10
        keys.Push(String(A_Index - 1))
    Loop 12
        keys.Push("F" A_Index)
    Loop 10
        keys.Push("Numpad" (A_Index - 1))
    for k in ["Space", "Tab", "Up", "Down", "Left", "Right", "Home", "End", "PgUp", "PgDn"
            , "Insert", "Delete", "Backspace", "Enter", "Escape", "NumpadAdd", "NumpadSub"
            , "NumpadMult", "NumpadDiv", "NumpadDot", "NumpadEnter"
            , "-", "=", "[", "]", ";", "'", ",", ".", "/", "\"]
        keys.Push(k)
    return keys
}

SetupBroadcast() {
    mode := Cfg("Broadcast", "Mode", "Whitelist")
    list := StrSplit(Cfg("Broadcast", "Keys", "1,2,3,4,5,6,7,8,9,0,-,="), ",", " `t")
    if (mode = "Blacklist") {
        black := Map()
        black.CaseSense := false
        for k in list
            black[k] := true
        keys := []
        for k in AllKeys()
            if !black.Has(k)
                keys.Push(k)
    } else {
        keys := list
    }
    ; Switch: the key is blocked, then pressed once in every client in turn.
    ; Send:   the key passes through to the active client and is copied to the
    ;         others in the background (EverQuest usually ignores these).
    downName := (BcMethod = "Switch") ? "$*" : "~*"
    upName   := (BcMethod = "Switch") ? "*"  : "~*"
    HotIfWinActive(EQ)
    for k in keys {
        if (k = "" || KeyMapBaseKeys.Has(k))
            continue
        try {
            Hotkey(downName k, BcDown.Bind(k), "Off")
            Hotkey(upName k " up", BcUp.Bind(k), "Off")
            BcKeys.Push(k)
            BcHotkeys.Push(downName k, upName k " up")
        }
    }
    HotIfWinActive()
}

ModState() {
    d := "", u := ""
    for m in ["Shift", "Ctrl", "Alt"] {
        if GetKeyState(m) {
            d .= "{" m " down}"
            u := "{" m " up}" u
        }
    }
    return {down: d, up: u}
}

BcDown(k, *) {
    if !Broadcasting
        return
    if (BcMethod = "Switch") {
        if BcHeld.Has(k)          ; holding the key: ignore auto-repeat
            return
        BcHeld[k] := true
        SwitchBroadcast(k)
        return
    }
    mods := ModState()
    active := WinActive("A")
    for id in Slots {
        if (id && id != active)
            try ControlSend(mods.down "{" k " down}" mods.up, , "ahk_id " id)
    }
}

BcUp(k, *) {
    if BcHeld.Has(k)
        BcHeld.Delete(k)
    if (!Broadcasting || BcMethod = "Switch")
        return
    active := WinActive("A")
    for id in Slots {
        if (id && id != active)
            try ControlSend("{" k " up}", , "ahk_id " id)
    }
}

ToggleBroadcast(*) {
    global Broadcasting
    if (!Broadcasting && NotForGame("Broadcasting"))
        return
    Broadcasting := !Broadcasting
    state := Broadcasting ? "On" : "Off"
    BcHeld.Clear()
    HotIfWinActive(EQ)
    for name in BcHotkeys
        try Hotkey(name, state)
    HotIfWinActive()
    UpdateIndicator()
    Status("Broadcast " (Broadcasting ? "ON" : "OFF"))
}

; One key press -> the same single key press in every client, one after another.
SwitchBroadcast(k) {
    global Switching
    prev := WinActive("A")
    keys := "{Blind}{" k "}"      ; {Blind} keeps Shift/Ctrl/Alt you are holding
    SendInput(keys)               ; the client you're playing in
    delay := ToInt(Cfg("Broadcast", "SwitchDelay", "20"), 20)
    Switching := true
    ; Stay in that client a moment before hopping away: EverQuest throws away
    ; a key it hasn't read yet when its window loses focus, so without this
    ; the client you pressed the key in could miss it (= Sit/Stand in slot 1).
    stay := ToInt(Cfg("Broadcast", "StayDelay", "50"), 50)
    if (stay > 0 && SlotOf(prev))
        Sleep(stay)
    sent := 1, missed := 0
    for id in Slots {
        if (!id || id = prev)
            continue
        try {
            WinActivate("ahk_id " id)
            if WinWaitActive("ahk_id " id, , 0.5) {
                Sleep(delay)      ; let the game notice it has focus
                SendInput(keys)
                Sleep(delay)
                sent++
            } else {
                missed++
            }
        }
    }
    if prev
        try WinActivate("ahk_id " prev)
    Switching := false
    if Cfg("Broadcast", "ShowFeedback", "1") = "1"
        Status("Broadcast " k " -> " sent " client(s)" (missed ? "  (" missed " could not be activated)" : "")
            . (A_IsAdmin ? "" : "  [not admin]"), 900)
}

; Mouse button 4: one mirrored left-click at the pointer, in every client.
MouseBroadcast(*) {
    if NotForGame("The mirrored click")
        return
    MouseGetPos(, , &win)
    if SlotOf(win)
        MirrorClickFrom(win, "Left", true)
}

; Mirror mode (Ctrl+Alt+M): after each left/right click in a client, the same
; click is made at the same spot (relative to window size) in every other one.
ToggleMirror(*) {
    global Mirroring
    if (!Mirroring && NotForGame("Mirror mode"))
        return
    Mirroring := !Mirroring
    state := Mirroring ? "On" : "Off"
    HotIfWinActive(EQ)
    try Hotkey("~LButton up", state)
    try Hotkey("~RButton up", state)
    HotIfWinActive()
    if Mirroring {
        SetTimer(UpdateMirrorDots, 30)
    } else {
        SetTimer(UpdateMirrorDots, 0)
        HideMirrorDots()
    }
    UpdateIndicator()
    RefreshPanel()
    Status("Mirror mode " (Mirroring ? "ON - clicks repeat in every client" : "OFF"))
}

MirrorUp(button, *) {
    if (!Mirroring || Switching)
        return
    MouseGetPos(, , &win)
    if SlotOf(win)
        MirrorClickFrom(win, button)
}

; Repeat a click made in client src at the same relative spot in the others.
; Each client is brought forward briefly, because EverQuest ignores clicks
; sent to windows in the background.
MirrorClickFrom(src, button, clickSource := false) {
    global Switching
    pt := CursorPos()
    try WinGetClientPos(&sx, &sy, &sw, &sh, "ahk_id " src)
    catch
        return
    if (sw <= 0 || sh <= 0 || pt.x < sx || pt.y < sy || pt.x >= sx + sw || pt.y >= sy + sh)
        return
    rx := (pt.x - sx) / sw, ry := (pt.y - sy) / sh
    Switching := true
    if clickSource {
        GameClick(pt.x, pt.y, button)    ; a click the game notices, then a short wait
    } else {
        ; your own click just happened here: let this client read it before
        ; another window takes focus (EverQuest drops input it hasn't read)
        stay := ToInt(Cfg("Mirror", "StayDelay", "50"), 50)
        if (stay > 0)
            Sleep(stay)
    }
    done := 0
    for id in Slots {
        if (!id || id = src)
            continue
        try {
            WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " id)
            WinActivate("ahk_id " id)
            if !WinWaitActive("ahk_id " id, , 0.5)
                continue
            GameClick(cx + Round(rx * cw), cy + Round(ry * ch), button)
            done++
        }
    }
    try WinActivate("ahk_id " src)
    CoordMode("Mouse", "Screen")
    MouseMove(pt.x, pt.y, 0)
    Switching := false
    if (Cfg("Mirror", "ShowFeedback", "1") = "1")
        Status("Mirrored " button " click to " done " client(s)", 900)
}

; Click at a screen position in the client that's in front, the way a game
; notices: real pointer movement (so the button under it lights up), a short
; wait for the game's next frame, then press and release separately.
GameClick(x, y, button := "Left") {
    CoordMode("Mouse", "Screen")
    wait := ToInt(Cfg("Mirror", "ClickDelay", "60"), 60)
    hold := ToInt(Cfg("Mirror", "HoldTime", "40"), 40)
    MouseMove(x + 2, y + 2, 0)
    Sleep(wait // 2)
    MouseMove(x, y, 0)
    Sleep(wait)
    Click(button " Down")
    Sleep(hold)
    Click(button " Up")
    Sleep(wait // 2)
}

; Small markers showing where a mirrored click will land in each other client.
UpdateMirrorDots() {
    if Switching
        return
    pt := CursorPos()
    src := 0
    for n, id in Slots {
        if !id
            continue
        try WinGetClientPos(&x, &y, &w, &h, "ahk_id " id)
        catch
            continue
        if (pt.x >= x && pt.y >= y && pt.x < x + w && pt.y < y + h) {
            src := id, rx := (pt.x - x) / w, ry := (pt.y - y) / h
            break
        }
    }
    sz := 10
    for n, id in Slots {
        if (!src || !id || id = src) {
            if MirrorDots.Has(n)
                try MirrorDots[n].Hide()
            continue
        }
        if !MirrorDots.Has(n) {
            g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")
            g.BackColor := Cfg("Mirror", "MarkerColor", "FFFF00")
            MirrorDots[n] := g
        }
        try {
            WinGetClientPos(&x, &y, &w, &h, "ahk_id " id)
            MirrorDots[n].Show("NA x" (x + Round(rx * w) - sz // 2) " y" (y + Round(ry * h) - sz // 2) " w" sz " h" sz)
            WinSetTransparent(200, MirrorDots[n])
        }
    }
}

HideMirrorDots() {
    for n, g in MirrorDots
        try g.Hide()
}

; ------------------------------ Video FX ------------------------------
LoadVFX() {
    global VFXOn
    for line in StrSplit(CfgSection("VFX"), "`n") {
        kv := StrSplit(line, "=", , 2)
        if (kv.Length < 2 || !InStr(kv[2], "|"))
            continue
        p := StrSplit(kv[2], "|", " `t")
        if (p.Length < 3 || !IsInteger(p[1]))
            continue
        VFX.Push({Name: Trim(kv[1]), Slot: Integer(p[1]), Src: ParseRect(p[2]), Dst: ParseRect(p[3])
                , Opacity: (p.Length >= 4 && IsInteger(p[4])) ? Integer(p[4]) : 255
                , Gui: 0, Thumb: 0})
    }
    VFXOn := GameDef.views && Cfg("VFX", "StartOn", "0") = "1"
}

DestroyVFX(v) {
    if v.Thumb
        DllCall("dwmapi\DwmUnregisterThumbnail", "Ptr", v.Thumb)
    if v.Gui {
        try VfxByHwnd.Delete(v.Gui.Hwnd)
        try v.Gui.Destroy()
    }
    v.Thumb := 0
    v.Gui := 0
}

RefreshVFX() {
    for v in VFX
        DestroyVFX(v)
    if (!VFXOn || VFX.Length = 0)
        return
    refW := ToInt(Cfg("VFX", "ReferenceWidth", "1920"), 1920)
    refH := ToInt(Cfg("VFX", "ReferenceHeight", "1080"), 1080)
    MonitorGet(MonitorNum, &mL, &mT)
    for v in VFX {
        src := (v.Slot >= 1 && v.Slot <= MAX_SLOTS) ? Slots[v.Slot] : 0
        if !src
            continue
        try WinGetClientPos(, , &cw, &ch, "ahk_id " src)
        catch
            continue
        sx := cw / refW, sy := ch / refH
        ; E0x08000000 = WS_EX_NOACTIVATE: clicking the view doesn't take focus
        ; away from the client you're playing in.
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
        g.BackColor := "000000"
        g.Show("NA x" (mL + v.Dst.x) " y" (mT + v.Dst.y) " w" v.Dst.w " h" v.Dst.h)
        thumb := 0
        if (DllCall("dwmapi\DwmRegisterThumbnail", "Ptr", g.Hwnd, "Ptr", src, "Ptr*", &thumb) != 0) {
            g.Destroy()
            continue
        }
        ; The selection is stored relative to the PICTURE (client area), but
        ; Windows' image of a window can start at the window's outer corner
        ; (title bar and border included), so shift it by where the picture
        ; sits in that image. Without this the view showed an area up and to
        ; the left of what was selected.
        off := VfxPictureOffset(thumb, src)
        ; DWM_THUMBNAIL_PROPERTIES (48 bytes)
        props := Buffer(48, 0)
        NumPut("UInt", 0x0F, props, 0)    ; RECTDESTINATION|RECTSOURCE|OPACITY|VISIBLE (whole-window coordinates)
        NumPut("Int", 0, "Int", 0, "Int", v.Dst.w, "Int", v.Dst.h, props, 4)
        NumPut("Int", off.x + Round(v.Src.x * sx), "Int", off.y + Round(v.Src.y * sy)
             , "Int", off.x + Round((v.Src.x + v.Src.w) * sx), "Int", off.y + Round((v.Src.y + v.Src.h) * sy), props, 20)
        NumPut("UChar", v.Opacity, props, 36)
        NumPut("Int", 1, props, 40)
        NumPut("Int", 0, props, 44)       ; fSourceClientAreaOnly = FALSE
        DllCall("dwmapi\DwmUpdateThumbnailProperties", "Ptr", thumb, "Ptr", props)
        v.Gui := g
        v.Thumb := thumb
        v.Off := off
        VfxByHwnd[g.Hwnd] := v
        WriteLog("view " v.Name " (slot " v.Slot "): Windows' image of the client is " off.how
            . " - picture starts at " off.x "," off.y " in it - " WinDesc(src))
    }
}

; Left/right button pressed on a view -> click the same spot in the source client.
; Where the picture (client area) starts inside Windows' (DWM's) image of a
; window. That image may be the whole window, the visible frame, or just the
; picture, depending on Windows' version and how the frame is drawn, so it's
; measured from the image's size rather than assumed.
VfxPictureOffset(thumb, src) {
    try {
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " src)
        WinGetClientPos(&px, &py, &pw, &ph, "ahk_id " src)
    } catch
        return {x: 0, y: 0, how: "unknown (window gone)"}
    sz := Buffer(8, 0)
    if (DllCall("dwmapi\DwmQueryThumbnailSourceSize", "Ptr", thumb, "Ptr", sz, "Int") != 0)
        return {x: px - ox, y: py - oy, how: "unknown (assumed the whole window)"}
    tw := NumGet(sz, 0, "Int"), th := NumGet(sz, 4, "Int")
    if (Abs(tw - ow) <= 1 && Abs(th - oh) <= 1)
        return {x: px - ox, y: py - oy, how: "the whole window " tw "x" th}
    if (Abs(tw - pw) <= 1 && Abs(th - ph) <= 1)
        return {x: 0, y: 0, how: "just the picture " tw "x" th}
    ; the visible frame (Windows 10/11 keep invisible borders outside it)
    rc := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", src, "UInt", 9, "Ptr", rc, "UInt", 16, "Int") = 0) {   ; DWMWA_EXTENDED_FRAME_BOUNDS
        el := NumGet(rc, 0, "Int"), et := NumGet(rc, 4, "Int")
        if (Abs(tw - (NumGet(rc, 8, "Int") - el)) <= 1 && Abs(th - (NumGet(rc, 12, "Int") - et)) <= 1)
            return {x: px - el, y: py - et, how: "the visible frame " tw "x" th}
    }
    ; the clip (MMORPG Boxer's window region)
    rk := RegionKey(src)
    if (rk != "") {
        r := StrSplit(rk, ",")
        if (Abs(tw - r[3]) <= 1 && Abs(th - r[4]) <= 1)
            return {x: px - ox - r[1], y: py - oy - r[2], how: "the clipped area " tw "x" th}
    }
    ; unknown size: assume it's anchored at the bottom-right of the window
    ; (the left/top parts are what usually differ)
    return {x: px - ox - (ow - tw), y: py - oy - (oh - th), how: "unrecognised " tw "x" th " (window " ow "x" oh ", picture " pw "x" ph ")"}
}

; Re-measure each view's source once a second; rebuild the views if a
; client's frame changed (e.g. its title bar was hidden after the view was made).
VfxCheck() {
    static lastRebuild := 0
    if (!VFXOn || A_TickCount - lastRebuild < 5000)
        return
    for v in VFX {
        if (!v.Thumb || !v.HasOwnProp("Off"))
            continue
        src := (v.Slot >= 1 && v.Slot <= MAX_SLOTS) ? Slots[v.Slot] : 0
        if !src
            continue
        now := VfxPictureOffset(v.Thumb, src)
        if (now.x != v.Off.x || now.y != v.Off.y) {
            lastRebuild := A_TickCount
            RefreshVFX()
            return
        }
    }
}

VfxMouse(wParam, lParam, msg, hwnd) {
    if !VfxByHwnd.Has(hwnd)
        return
    v := VfxByHwnd[hwnd]
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    SetTimer(VfxClickAt.Bind(v, x, y, msg = 0x204 ? "Right" : "Left"), -1)
    return 0
}

CursorPos() {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    return {x: NumGet(pt, 0, "Int"), y: NumGet(pt, 4, "Int")}
}

VfxClickAt(v, cx, cy, button) {
    src := (v.Slot >= 1 && v.Slot <= MAX_SLOTS) ? Slots[v.Slot] : 0
    if !src
        return
    mode := Cfg("VFX", "ClickMode", "Switch")
    if (mode = "Focus") {
        FocusSlot(v.Slot)
        return
    }
    refW := ToInt(Cfg("VFX", "ReferenceWidth", "1920"), 1920)
    refH := ToInt(Cfg("VFX", "ReferenceHeight", "1080"), 1080)
    try WinGetClientPos(&scx, &scy, &cw, &ch, "ahk_id " src)
    catch
        return
    ; position inside the view -> position inside the source client
    tx := Round((v.Src.x + cx * v.Src.w / v.Dst.w) * cw / refW)
    ty := Round((v.Src.y + cy * v.Src.h / v.Dst.h) * ch / refH)
    if (mode = "Send") {
        ; Background click without switching windows (EverQuest may ignore it).
        try ControlClick("x" tx " y" ty, "ahk_id " src, , button, 1, "NA")
        return
    }
    ; Switch mode: hop to the source client, click the real button, hop back.
    global Switching
    Switching := true
    prev := WinActive("A")
    home := CursorPos()
    try {
        WinActivate("ahk_id " src)
        if WinWaitActive("ahk_id " src, , 0.5)
            GameClick(scx + tx, scy + ty, button)
    }
    if (prev && prev != src)
        try WinActivate("ahk_id " prev)
    CoordMode("Mouse", "Screen")
    MouseMove(home.x, home.y, 0)
    Switching := false
}

ToggleVFX(*) {
    global VFXOn
    if (!VFXOn && NotForGame("Clickable views", GameDef.views))
        return
    if (VFX.Length = 0) {
        Status("No views yet - open Clickable Views (" NiceKey(Cfg("Hotkeys", "ViewManager", "^!e")) ") to make one")
        return
    }
    VFXOn := !VFXOn
    RefreshVFX()
    RefreshPanel()
    UpdateToolbar()
    VMRefresh()
    Status("Views " (VFXOn ? "ON" : "OFF"))
}

; ---------------------- Create / delete views by dragging ----------------------
; Dims the screen and lets you drag a rectangle. Returns screen rect or 0.
SelectRect(prompt) {
    MonitorGet(MonitorNum, &mL, &mT, &mR, &mB)
    dim := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    dim.BackColor := "000000"
    dim.Show("x" mL " y" mT " w" (mR - mL) " h" (mB - mT))
    WinSetTransparent(60, dim)
    box := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20")
    box.BackColor := "FF3030"
    ToolTip(prompt "`n(Esc cancels)", mL + 20, mT + 20, 3)
    result := 0
    Loop {
        if GetKeyState("Escape", "P")
            break
        if GetKeyState("LButton", "P") {
            p1 := CursorPos()
            while GetKeyState("LButton", "P") {
                p2 := CursorPos()
                x := Min(p1.x, p2.x), y := Min(p1.y, p2.y)
                w := Max(1, Abs(p2.x - p1.x)), h := Max(1, Abs(p2.y - p1.y))
                box.Show("NA x" x " y" y " w" w " h" h)
                WinSetTransparent(110, box)
                Sleep(10)
            }
            p2 := CursorPos()
            result := {x: Min(p1.x, p2.x), y: Min(p1.y, p2.y)
                     , w: Abs(p2.x - p1.x), h: Abs(p2.y - p1.y)}
            break
        }
        Sleep(10)
    }
    ToolTip(, , , 3)
    box.Destroy()
    dim.Destroy()
    KeyWait("Escape")
    return result
}

; Ask for an area of a client to copy. Returns {slot, src, w, h}, or 0.
PickViewSource(prompt) {
    RefreshSlots()
    if (CountClients() = 0) {
        Status("No clients running")
        return 0
    }
    r1 := SelectRect(prompt)
    if (!r1 || r1.w < 8 || r1.h < 8) {
        Status("View cancelled")
        return 0
    }
    cxm := r1.x + r1.w // 2, cym := r1.y + r1.h // 2
    srcSlot := 0
    for n, id in Slots {
        if !id
            continue
        try WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " id)
        catch
            continue
        if (cxm >= wx && cxm < wx + ww && cym >= wy && cym < wy + wh) {
            srcSlot := n
            break
        }
    }
    if !srcSlot {
        Status("That area isn't inside a game client", 4000)
        return 0
    }
    refW := ToInt(Cfg("VFX", "ReferenceWidth", "1920"), 1920)
    refH := ToInt(Cfg("VFX", "ReferenceHeight", "1080"), 1080)
    fx := refW / ww, fy := refH / wh
    src := {x: Round((r1.x - wx) * fx), y: Round((r1.y - wy) * fy)
          , w: Round(r1.w * fx), h: Round(r1.h * fy)}
    return {slot: srcSlot, src: src, w: r1.w, h: r1.h}
}

; Ask where a view goes (a plain click keeps the size w x h).
; Returns the spot relative to the monitor, or 0.
PickViewPlace(prompt, w, h) {
    r2 := SelectRect(prompt)
    if !r2 {
        Status("View cancelled")
        return 0
    }
    if (r2.w < 8 || r2.h < 8)
        r2 := {x: r2.x, y: r2.y, w: w, h: h}
    MonitorGet(MonitorNum, &mL, &mT)
    return {x: r2.x - mL, y: r2.y - mT, w: r2.w, h: r2.h}
}

SaveView(v) {
    IniWrite(v.Slot "|" v.Src.x "," v.Src.y "," v.Src.w "," v.Src.h "|" v.Dst.x "," v.Dst.y "," v.Dst.w "," v.Dst.h "|" v.Opacity
        , CFG_FILE, "VFX", v.Name)
}

CreateView(*) {
    global VFXOn
    if NotForGame("Clickable views", GameDef.views)
        return
    s := PickViewSource("Step 1 of 2: drag a box around the area to copy (e.g. slot 2's hotbar)")
    if !s
        return
    d := PickViewPlace("Step 2 of 2: drag a box where the copy should go (or just click to place it at the same size)", s.w, s.h)
    if !d
        return
    i := 1
    while HasViewName("View" i)
        i++
    v := {Name: "View" i, Slot: s.slot, Src: s.src, Dst: d, Opacity: 255, Gui: 0, Thumb: 0}
    SaveView(v)
    VFX.Push(v)
    VFXOn := true
    RefreshVFX()
    RefreshPanel()
    UpdateToolbar()
    VMRefresh(v.Name)
    Status("Created " v.Name " from slot " v.Slot ". Click it to use slot " v.Slot "'s buttons.", 5000)
}

HasViewName(name) {
    for v in VFX
        if (v.Name = name)
            return true
    return false
}

; Delete the view under the mouse pointer.
DeleteView(*) {
    MouseGetPos(, , &win)
    if !VfxByHwnd.Has(win)
        return Status("Point at a view, then press the delete hotkey")
    v := VfxByHwnd[win]
    DestroyVFX(v)
    try IniDelete(CFG_FILE, "VFX", v.Name)
    for i, x in VFX
        if (x = v) {
            VFX.RemoveAt(i)
            break
        }
    VMRefresh()
    Status("Deleted " v.Name)
}

; ------------------------- Clickable Views window -------------------------
ShowViews(*) {
    global VM
    if NotForGame("Clickable views", GameDef.views)
        return
    g := 0
    VBtn(opts, label, fn, tip) {
        btn := g.AddButton(opts, label)
        btn.OnEvent("Click", fn)
        AddTip(btn, tip)
    }
    if !VM {
        g := Gui(, APP " - Clickable Views")
        g.SetFont("s10", "Segoe UI")
        VM := {gui: g}
        Hint(g.AddText("xm w640 cGray", "A view is a live copy of part of one client - for example slot 2's hotbar - that you can put anywhere on screen. Clicking a button in the view clicks the real button in that client."))
        VM.list := g.AddListView("xm y+8 w640 r8 -Multi", ["View", "Copies from", "Area copied", "Shown at", "Opacity"])
        VM.list.OnEvent("ItemSelect", VMSelect)
        VM.list.OnEvent("DoubleClick", (*) => VMRename())
        bw := "w154 h32"
        VBtn("xm y+10 " bw " Section", "New View...", (*) => VMNew()
            , TipText("Drag a box around the area to copy, then where the copy should go", "CreateView", "^!c"))
        VBtn("x+8 yp " bw, "Change Area...", (*) => VMArea()
            , TipText("Pick a new area for the selected view to copy (from any client)"))
        VBtn("x+8 yp " bw, "Move / Resize...", (*) => VMPlace()
            , TipText("Drag a new box for where the selected view is shown.`nJust click to move it without changing its size."))
        VBtn("x+8 yp " bw, "Rename...", (*) => VMRename()
            , TipText("Rename the selected view (or double-click it in the list)"))
        VBtn("xs y+8 " bw, "Show Where", (*) => VMFlash()
            , TipText("Flash a red box where the selected view is"))
        VBtn("x+8 yp " bw, "Delete", (*) => VMDelete()
            , TipText("Delete the selected view.`nIn game, point at a view and press the shortcut to delete it.", "DeleteView", "^!d"))
        VBtn("x+8 yp " bw, "Delete All...", (*) => VMDeleteAll()
            , TipText("Delete every view"))
        VBtn("x+8 yp " bw, "Close", (*) => g.Hide(), TipText("Close this window (views stay as they are)"))
        g.AddGroupBox("xm y+14 w640 h96", "Selected view")
        g.AddText("xp+12 yp+28 w120 h28 0x200", "Copies from slot:")
        slotNames := []
        Loop MAX_SLOTS
            slotNames.Push(A_Index (Chars[A_Index] != "" ? " - " Chars[A_Index] : ""))
        VM.slot := g.AddDropDownList("x+4 yp w170", slotNames)
        VM.slot.OnEvent("Change", VMSlotChange)
        AddTip(VM.slot, TipText("Copy the same area from a different client (useful when every client has its hotbar in the same place)"))
        g.AddText("x+24 yp w64 h28 0x200", "Opacity:")
        VM.op := g.AddSlider("x+4 yp w170 Range20-100 TickInterval10 ToolTip", 100)
        VM.op.OnEvent("Change", VMOpacityChange)
        AddTip(VM.op, TipText("How see-through the selected view is"))
        VM.info := Hint(g.AddText("xm+12 y+10 w616 cGray", ""))
        VM.show := g.AddCheckbox("xm y+22 w300", "Show views")
        VM.show.OnEvent("Click", VMShowChange)
        AddTip(VM.show, TipText("Show or hide every view", "ToggleVFX", "^!v"))
        VM.start := g.AddCheckbox("x+8 yp w330", "Show views when MMORPG Boxer starts")
        VM.start.OnEvent("Click", (c, *) => IniWrite(c.Value ? 1 : 0, CFG_FILE, "VFX", "StartOn"))
        AddTip(VM.start, TipText("Turn views on automatically every time the app starts"))
        g.AddText("xm y+12 w160 h28 0x200", "Clicking a view:")
        VM.mode := g.AddDropDownList("x+4 yp w476", ["Switch - click the real button in that client (most reliable)"
            , "Send - click in the background (the game may ignore it)", "Focus - just switch to that client"])
        VM.mode.OnEvent("Change", (c, *) => IniWrite(StrSplit(c.Text, " ")[1], CFG_FILE, "VFX", "ClickMode"))
        AddTip(VM.mode, TipText("What happens when you click a view"))
        VM.status := Hint(g.AddText("xm y+12 w640 cGray", "Tip: views need the client they copy from to be running and not minimized."))
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())
        ThemeGui(g)
    }
    VM.gui.Show()
    VMRefresh()
}

VMVisible() => (VM && DllCall("IsWindowVisible", "Ptr", VM.gui.Hwnd))

; Fill the list; keep (or select) the view called keep.
VMRefresh(keep := "") {
    if !VMVisible()
        return
    if (keep = "") {
        v := VMSelected()
        keep := v ? v.Name : ""
    }
    VM.list.Opt("-Redraw")
    VM.list.Delete()
    sel := 0
    for i, v in VFX {
        slotTxt := v.Slot (v.Slot >= 1 && v.Slot <= MAX_SLOTS && Chars[v.Slot] != "" ? " - " Chars[v.Slot] : "")
            . ((v.Slot >= 1 && v.Slot <= MAX_SLOTS && Slots[v.Slot]) ? "" : " (not running)")
        VM.list.Add(, v.Name, slotTxt, v.Src.x "," v.Src.y "  " v.Src.w "x" v.Src.h
            , v.Dst.x "," v.Dst.y "  " v.Dst.w "x" v.Dst.h, Round(v.Opacity / 2.55) "%")
        if (v.Name = keep)
            sel := i
    }
    if (!sel && VFX.Length)
        sel := 1
    Loop 5
        VM.list.ModifyCol(A_Index, "AutoHdr")
    if sel
        VM.list.Modify(sel, "Select Focus Vis")
    VM.list.Opt("+Redraw")
    VM.show.Value := VFXOn
    VM.start.Value := Cfg("VFX", "StartOn", "0") = "1"
    mode := Cfg("VFX", "ClickMode", "Switch")
    VM.mode.Choose(mode = "Send" ? 2 : mode = "Focus" ? 3 : 1)
    VMLoad()
}

VMSelected() {
    if !VM
        return 0
    row := VM.list.GetNext(0)
    return (row >= 1 && row <= VFX.Length) ? VFX[row] : 0
}

VMSelect(*) => VMLoad()

; Show the selected view's settings.
VMLoad() {
    v := VMSelected()
    for c in [VM.slot, VM.op]
        c.Enabled := !!v
    if !v {
        VM.info.Text := VFX.Length ? "Select a view above." : "No views yet. Click New View... to make one."
        return
    }
    if (v.Slot >= 1 && v.Slot <= MAX_SLOTS)
        VM.slot.Choose(v.Slot)
    VM.op.Value := Max(20, Round(v.Opacity / 2.55))
    VM.info.Text := v.Name ": copies " v.Src.w "x" v.Src.h " from slot " v.Slot " (in 1920x1080 terms), shown "
        . v.Dst.w "x" v.Dst.h " at " v.Dst.x "," v.Dst.y " on screen."
}

; Run a screen-picking step with this window out of the way.
VMPick(fn) {
    VM.gui.Hide()
    try fn()
    VM.gui.Show()
    VMRefresh()
}

VMNew() => VMPick(CreateView)

VMNeedSel() {
    v := VMSelected()
    if !v
        MsgBox("Select a view in the list first.", APP, "Iconi Owner" VM.gui.Hwnd)
    return v
}

VMArea() {
    if !(v := VMNeedSel())
        return
    VMPick(DoArea)
    DoArea() {
        s := PickViewSource("Drag a box around the new area for " v.Name " to copy")
        if !s
            return
        v.Slot := s.slot, v.Src := s.src
        SaveView(v)
        RefreshVFX()
        Status(v.Name " now copies from slot " v.Slot)
    }
}

VMPlace() {
    if !(v := VMNeedSel())
        return
    VMPick(DoPlace)
    DoPlace() {
        d := PickViewPlace("Drag a box where " v.Name " should go (or just click to move it at the same size)", v.Dst.w, v.Dst.h)
        if !d
            return
        v.Dst := d
        SaveView(v)
        RefreshVFX()
        Status(v.Name " moved")
    }
}

VMRename() {
    if !(v := VMNeedSel())
        return
    ib := InputBox("New name for " v.Name ":", APP, "w320 h130", v.Name)
    if (ib.Result != "OK")
        return
    name := Trim(ib.Value)
    if (name = "" || RegExMatch(name, "[=|\[\];]")) {
        MsgBox("Use a name without = | [ ] or `;", APP, "Icon! Owner" VM.gui.Hwnd)
        return
    }
    if (name != v.Name && HasViewName(name)) {
        MsgBox("There's already a view called " name ".", APP, "Icon! Owner" VM.gui.Hwnd)
        return
    }
    try IniDelete(CFG_FILE, "VFX", v.Name)
    v.Name := name
    SaveView(v)
    VMRefresh(name)
}

VMDelete() {
    if !(v := VMNeedSel())
        return
    if (MsgBox("Delete " v.Name "?", APP, "YesNo Icon? Owner" VM.gui.Hwnd) != "Yes")
        return
    DestroyVFX(v)
    try IniDelete(CFG_FILE, "VFX", v.Name)
    for i, x in VFX
        if (x = v) {
            VFX.RemoveAt(i)
            break
        }
    VMRefresh()
    Status("Deleted " v.Name)
}

VMDeleteAll() {
    if !VFX.Length
        return
    if (MsgBox("Delete all " VFX.Length " view(s)?", APP, "YesNo Icon! Owner" VM.gui.Hwnd) != "Yes")
        return
    for v in VFX {
        DestroyVFX(v)
        try IniDelete(CFG_FILE, "VFX", v.Name)
    }
    VFX.Length := 0
    VMRefresh()
    UpdateToolbar()
    Status("Deleted all views")
}

; Flash a red box where the selected view is.
VMFlash() {
    if !(v := VMNeedSel())
        return
    MonitorGet(MonitorNum, &mL, &mT)
    box := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20")
    box.BackColor := "FF3030"
    box.Show("NA x" (mL + v.Dst.x) " y" (mT + v.Dst.y) " w" v.Dst.w " h" v.Dst.h)
    WinSetTransparent(120, box)
    SetTimer(() => box.Destroy(), -1200)
}

VMSlotChange(ctrl, *) {
    if !(v := VMSelected())
        return
    v.Slot := ctrl.Value
    SaveView(v)
    RefreshVFX()
    VMRefresh(v.Name)
}

VMOpacityChange(ctrl, *) {
    if !(v := VMSelected())
        return
    v.Opacity := Round(ctrl.Value * 2.55)
    SaveView(v)
    RefreshVFX()
    VMRefresh(v.Name)
}

VMShowChange(ctrl, *) {
    global VFXOn
    VFXOn := !!ctrl.Value
    RefreshVFX()
    RefreshPanel()
    UpdateToolbar()
    Status("Views " (VFXOn ? "ON" : "OFF"))
}

; ----------------------------- Appearance -----------------------------
; Light, Dark, or System (follows Windows: Settings > Personalization >
; Colors > "Choose your app mode"). Applies to the app's windows and menus;
; the toolbar keeps its own colours (Bar menu).
Hint(ctrl) {
    Hints[ctrl.Hwnd] := true
    return ctrl
}

Keep(ctrl) {
    NoTheme[ctrl.Hwnd] := true
    return ctrl
}

IsDark() {
    if (Appearance = "Dark")
        return true
    if (Appearance = "Light")
        return false
    try return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 0
    return false
}

Palette() {
    if IsDark()
        return {dark: true, bg: "202020", fg: "E6E6E6", hint: "9C9C9C", field: "2C2C2C"}
    return {dark: false, bg: "Default", fg: "Default", hint: "Gray", field: "Default"}
}

; app = theme name, "" = Windows' default, "none" = no visual styles
SetCtlTheme(hwnd, app) {
    if (app = "")
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Ptr", 0, "Ptr", 0)
    else if (app = "none")
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "", "Str", "")
    else
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", app, "Ptr", 0)
}

; Dark or light menus (tray menu, toolbar menus) for this program.
ApplyMenuTheme() {
    static setMode := 0, flush := 0
    if !setMode {
        h := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        if !h
            h := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
        setMode := DllCall("GetProcAddress", "Ptr", h, "Ptr", 135, "Ptr")   ; SetPreferredAppMode
        flush := DllCall("GetProcAddress", "Ptr", h, "Ptr", 136, "Ptr")     ; FlushMenuThemes
    }
    try {
        if setMode
            DllCall(setMode, "Int", Appearance = "Dark" ? 2 : Appearance = "Light" ? 3 : 1)
        if flush
            DllCall(flush)
    }
}

; Lets a window or control use Windows' dark theme parts (scroll bars,
; selection) - needed on some Windows versions for the DarkMode_ themes.
AllowDark(hwnd, on) {
    static fn := 0
    if !fn {
        h := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        fn := h ? DllCall("GetProcAddress", "Ptr", h, "Ptr", 133, "Ptr") : -1   ; AllowDarkModeForWindow
    }
    if (fn > 0)
        try DllCall(fn, "Ptr", hwnd, "Int", on ? 1 : 0)
}

; In dark mode, list rows are painted by us: the selected row in blue with
; white text, others dark (the theme's own highlight was light, leaving the
; light text unreadable).
LVDarkDraw(ctrl, lParam) {
    if !DarkNow
        return
    x64 := (A_PtrSize = 8)
    stage := NumGet(lParam, x64 ? 24 : 12, "UInt")
    if (stage = 1)                                   ; CDDS_PREPAINT
        return 0x20                                  ; CDRF_NOTIFYITEMDRAW
    if (stage != 0x10001)                            ; CDDS_ITEMPREPAINT
        return 0
    item := NumGet(lParam, x64 ? 56 : 36, "UPtr")
    stOff := x64 ? 64 : 40
    NumPut("UInt", NumGet(lParam, stOff, "UInt") & ~0x51, lParam, stOff)   ; theme: don't draw selected/focus/hot
    sel := SendMessage(0x102C, item, 0x2, ctrl) & 0x2                     ; LVM_GETITEMSTATE, LVIS_SELECTED
    NumPut("UInt", RGBtoBGR(sel ? "FFFFFF" : "E6E6E6"), lParam, x64 ? 80 : 48)   ; text
    NumPut("UInt", RGBtoBGR(sel ? "2F5A8C" : "2C2C2C"), lParam, x64 ? 84 : 52)   ; background
    return 0x2                                       ; CDRF_NEWFONT
}

; The column headers' text: the dark header theme leaves it dark grey, so
; light text is set while each header item is drawn. (The header tells the
; list, not the window, so the list is subclassed to hear it.)
LVSubclassProc(hwnd, msg, wParam, lParam, id, ref) {
    if (msg = 0x4E && DarkNow && NumGet(lParam, A_PtrSize * 2, "Int") = -12) {     ; WM_NOTIFY, NM_CUSTOMDRAW
        x64 := (A_PtrSize = 8)
        stage := NumGet(lParam, x64 ? 24 : 12, "UInt")
        if (stage = 1)                                       ; CDDS_PREPAINT
            return 0x20                                      ; CDRF_NOTIFYITEMDRAW
        if (stage = 0x10001) {                               ; CDDS_ITEMPREPAINT
            DllCall("gdi32\SetTextColor", "Ptr", NumGet(lParam, x64 ? 32 : 16, "Ptr"), "UInt", 0xE6E6E6)
            return 0
        }
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
}

RGBtoBGR(hex) {
    v := Integer("0x" hex)
    return ((v & 0xFF) << 16) | (v & 0xFF00) | ((v >> 16) & 0xFF)
}

ThemeCtrl(c, p) {
    if NoTheme.Has(c.Hwnd)
        return
    AllowDark(c.Hwnd, p.dark)
    fg := Hints.Has(c.Hwnd) ? p.hint : p.fg
    switch c.Type, false {
        case "Text", "Link":
            c.SetFont("c" fg)
            c.Opt("+Background" p.bg)
        case "Button":
            SetCtlTheme(c.Hwnd, p.dark ? "DarkMode_Explorer" : "")
        case "Checkbox", "Radio", "GroupBox":
            ; themed check boxes ignore the text colour, so plain style in dark
            SetCtlTheme(c.Hwnd, p.dark ? "none" : "")
            c.SetFont("c" fg)
            c.Opt("+Background" p.bg)
        case "Edit", "DDL", "ComboBox", "ListBox":
            SetCtlTheme(c.Hwnd, p.dark ? "DarkMode_CFD" : "")
            c.SetFont("c" fg)
            c.Opt("+Background" p.field)
        case "Slider", "UpDown":
            SetCtlTheme(c.Hwnd, p.dark ? "DarkMode_Explorer" : "")
            c.Opt("+Background" p.bg)
        case "ListView":
            SetCtlTheme(c.Hwnd, p.dark ? "DarkMode_Explorer" : "")
            hdr := SendMessage(0x101F, 0, 0, c)                          ; LVM_GETHEADER
            if hdr
                SetCtlTheme(hdr, p.dark ? "DarkMode_ItemsView" : "")
            bk := p.dark ? RGBtoBGR(p.field) : DllCall("GetSysColor", "Int", 5, "UInt")
            tx := p.dark ? RGBtoBGR(p.fg) : DllCall("GetSysColor", "Int", 8, "UInt")
            SendMessage(0x1001, 0, bk, c)                                 ; LVM_SETBKCOLOR
            SendMessage(0x1026, 0, bk, c)                                 ; LVM_SETTEXTBKCOLOR
            SendMessage(0x1024, 0, tx, c)                                 ; LVM_SETTEXTCOLOR
            if !LVDrawn.Has(c.Hwnd) {
                LVDrawn[c.Hwnd] := true
                c.OnNotify(-12, LVDarkDraw)                               ; NM_CUSTOMDRAW (rows)
                static subProc := CallbackCreate(LVSubclassProc, "F", 6)
                DllCall("comctl32\SetWindowSubclass", "Ptr", c.Hwnd, "Ptr", subProc, "UPtr", 1, "UPtr", 0)
            }
    }
}

; Style one window (and remember it, so it follows later changes).
ThemeGui(g) {
    global DarkNow
    if !HasVal(ThemedGuis, g)
        ThemedGuis.Push(g)
    p := Palette()
    DarkNow := p.dark
    AllowDark(g.Hwnd, p.dark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "UInt", 20, "Int*", p.dark ? 1 : 0, "UInt", 4)  ; dark title bar
    g.BackColor := p.bg
    for hwnd, c in g
        try ThemeCtrl(c, p)
    DllCall("RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0585)   ; INVALIDATE|ERASE|FRAME|ALLCHILDREN|UPDATENOW
}

ApplyAppearance() {
    ApplyMenuTheme()
    alive := []
    for g in ThemedGuis {
        try {
            if !WinExist("ahk_id " g.Hwnd)
                continue
            alive.Push(g)
            ThemeGui(g)
        }
    }
    ThemedGuis.Length := 0
    for g in alive
        ThemedGuis.Push(g)
}

SetAppearance(mode, *) {
    global Appearance
    Appearance := mode
    IniWrite(mode, CFG_FILE, "General", "Appearance")
    ApplyAppearance()
    Status("Appearance: " mode (mode = "System" ? " (" (IsDark() ? "dark" : "light") " right now)" : ""))
}

; Windows told us a setting changed: follow its light/dark app mode.
OnSettingChange(wParam, lParam, msg, hwnd) {
    if (Appearance != "System" || !lParam)
        return
    try if (StrGet(lParam) = "ImmersiveColorSet")
        SetTimer(ApplyAppearance, -300)
}

; ------------------------------ Tooltips ------------------------------
; Hovering a button shows what it does and its keyboard shortcut.
; [General] ShowTooltips=0 (or the control panel checkbox) turns them off.
AddTip(ctrl, text) {
    Tips[ctrl.Hwnd] := text
    return ctrl
}

; "what it does" + the shortcut currently set in [Hotkeys] for name
TipText(desc, name := "", def := "") {
    if (name = "")
        return desc
    k := Cfg("Hotkeys", name, def)
    return desc "`nShortcut: " (k != "" ? NiceKey(k) : "none")
}

TipMouseMove(wParam, lParam, msg, hwnd) {
    global TipHwnd
    if (!TipsOn || !Tips.Has(hwnd) || TipHwnd = hwnd)
        return
    TipHwnd := hwnd
    ToolTip(, , , 5)
    SetTimer(TipShow, -450)
    SetTimer(TipWatch, 100)
}

TipShow() {
    if (!TipsOn || !TipHwnd || !Tips.Has(TipHwnd))
        return
    MouseGetPos(, , , &c, 2)
    if (c = TipHwnd)
        ToolTip(Tips[TipHwnd], , , 5)
}

; Hide the tooltip once the pointer leaves the control.
TipWatch() {
    global TipHwnd
    MouseGetPos(, , , &c, 2)
    if (TipsOn && c = TipHwnd)
        return
    TipHwnd := 0
    ToolTip(, , , 5)
    SetTimer(TipWatch, 0)
}

SetTipsOn(ctrl, *) {
    global TipsOn
    TipsOn := !!ctrl.Value
    IniWrite(TipsOn ? 1 : 0, CFG_FILE, "General", "ShowTooltips")
    if !TipsOn
        ToolTip(, , , 5)
    Status("Tooltips " (TipsOn ? "on" : "off"))
}

; ----------------------- Active client highlight -----------------------
; A coloured frame drawn around the client you are playing in.
InitHighlight() {
    if (Cfg("Highlight", "Enabled", "1") != "1")
        return
    color := Cfg("Highlight", "Color", "FF0000")
    Loop 4 {
        ; click-through (E0x20 + layered), never takes focus (E0x08000000)
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")
        g.BackColor := color
        HL.Push(g)
    }
    SetTimer(UpdateHighlight, 50)
}

HideHighlight() {
    global HLLast
    for g in HL
        try g.Hide()
    HLLast := ""
}

UpdateHighlight() {
    global HLLast
    if Switching                  ; keep the frame on your client during hops
        return
    id := WinActive(EQ)
    if (!id || !SlotOf(id)) {
        if (HLLast != "")
            HideHighlight()
        return
    }
    try WinGetClientPos(&x, &y, &w, &h, "ahk_id " id)
    catch
        return
    key := x "," y "," w "," h
    if (key = HLLast)
        return
    HLLast := key
    t := Max(1, ToInt(Cfg("Highlight", "Thickness", "4"), 4))
    rects := [[x, y, w, t], [x, y + h - t, w, t], [x, y, t, h], [x + w - t, y, t, h]]
    for i, r in rects {
        HL[i].Show("NA x" r[1] " y" r[2] " w" r[3] " h" r[4])
        try WinSetTransparent(255, HL[i])
    }
}

; ------------------------------- Audio -------------------------------
; Mutes every EverQuest client except the one you're playing in, using the
; same per-program mute as the Windows Volume Mixer.
ToggleAudio(*) {
    global AudioFollow, AudioPid
    AudioFollow := !AudioFollow
    IniWrite(AudioFollow ? 1 : 0, CFG_FILE, "Audio", "FollowActive")
    AudioPid := 0
    if !AudioFollow
        SetEQAudio(0)
    UpdateToolbar()
    Status(AudioFollow ? "Sound: only the client you're playing in" : "Sound: all clients")
}

AudioTick() {
    static lastApply := 0
    global AudioPid
    if (!AudioFollow || Switching)
        return
    id := WinActive(EQ)
    if id {
        try pid := WinGetPID("ahk_id " id)
        catch
            return
        if (pid != AudioPid) {
            AudioPid := pid
            SetEQAudio(pid)
            lastApply := A_TickCount
            return
        }
    }
    ; re-apply now and then, so clients that just started get muted too
    if (AudioPid && A_TickCount - lastApply > 3000) {
        SetEQAudio(AudioPid)
        lastApply := A_TickCount
    }
}

; audiblePid = the EverQuest process that keeps its sound; 0 = unmute all.
SetEQAudio(audiblePid) {
    try {
        eqPids := Map()
        for w in WinGetList(EQ)
            try eqPids[WinGetPID("ahk_id " w)] := true
        if (eqPids.Count = 0)
            return
        ; IMMDeviceEnumerator -> default playback device
        enum := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        pDev := 0
        ComCall(4, enum, "UInt", 0, "UInt", 1, "Ptr*", &pDev)           ; GetDefaultAudioEndpoint(eRender, eMultimedia)
        dev := ComValue(13, pDev)
        pMgr := 0
        ComCall(3, dev, "Ptr", GuidBuf("{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"), "UInt", 23, "Ptr", 0, "Ptr*", &pMgr)  ; Activate IAudioSessionManager2
        mgr := ComValue(13, pMgr)
        pEnum := 0
        ComCall(5, mgr, "Ptr*", &pEnum)                                  ; GetSessionEnumerator
        senum := ComValue(13, pEnum)
        count := 0
        ComCall(3, senum, "Int*", &count)                                ; GetCount
        Loop count {
            pCtl := 0
            ComCall(4, senum, "Int", A_Index - 1, "Ptr*", &pCtl)         ; GetSession
            ctl := ComValue(13, pCtl)
            ctl2 := ComObjQuery(ctl, "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}")   ; IAudioSessionControl2
            pid := 0
            ComCall(14, ctl2, "UInt*", &pid)                             ; GetProcessId
            if !eqPids.Has(pid)
                continue
            vol := ComObjQuery(ctl, "{87CE5498-68D6-44E5-9215-6F5BA2B6E2C9}")    ; ISimpleAudioVolume
            ComCall(5, vol, "Int", (audiblePid && pid != audiblePid) ? 1 : 0, "Ptr", 0)   ; SetMute
        }
    }
}

GuidBuf(str) {
    b := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "Str", str, "Ptr", b)
    return b
}

; ---------------------------- Setup Wizard ----------------------------
; Six pages: EverQuest folder, number of slots, characters & accounts,
; layout (with preview), features, summary. Finish saves and restarts.
ShowWizard(*) {
    global Wiz
    if (Wiz && Wiz.g) {
        try Wiz.g.Show()
        return
    }
    g := Gui("+AlwaysOnTop", APP " - Setup Wizard")
    g.SetFont("s10", "Segoe UI")
    g.OnEvent("Close", WizCancel)
    Wiz := {g: g, page: 1, pages: [[], [], [], [], [], [], []], rows: [], rects: []}
    g.SetFont("s15 w600")
    Wiz.title := g.AddText("xm w620 h34", "")
    g.SetFont("s10 w400")
    Wiz.step := Hint(g.AddText("xm w620 cGray", ""))
    anchor := g.AddText("xm y+10 w1 h1 Section")
    P(i, ctrl) {
        Wiz.pages[i].Push(ctrl)
        return ctrl
    }

    ; ---- page 1: game and its folder ----
    P(1, g.AddText("xs ys w620", "This wizard sets up MMORPG Boxer in a few steps. You can run it again any time from the control panel, the tray menu, or Ctrl+Alt+W."))
    P(1, g.AddText("xs y+12 w60 h28 0x200", "Game:"))
    Wiz.game := P(1, g.AddDropDownList("x+4 yp w240", GameNames()))
    Wiz.game.Choose(GameIndex())
    Wiz.game.OnEvent("Change", (c, *) => (SetGame(c.Text) = false ? c.Choose(GameIndex()) : 0))
    P(1, Hint(g.AddText("x+10 yp w300 h28 0x200 cGray", "Each game keeps its own setup.")))
    if (GameDef.rules != "")
        P(1, g.AddText("xs y+8 w620 cB8860B", GameDef.rules))
    P(1, g.AddText("xs y+12 w620", GameDef.launchers.Length
        ? "Where is " GameDef.name " installed? (The folder with its launcher, for example " GameDef.folder ".)"
        : "Where is " GameDef.name " installed? (The folder that contains " GameDef.exe ".)"))
    Wiz.path := P(1, g.AddEdit("xs y+8 w500", EQPath))
    Wiz.path.OnEvent("Change", WizCheckPath)
    P(1, g.AddButton("x+8 yp-1 w110", "Browse...")).OnEvent("Click", WizBrowse)
    Wiz.pathInfo := P(1, g.AddText("xs y+6 w620", ""))
    Wiz.admin := P(1, g.AddCheckbox("xs y+16 w620", "Run MMORPG Boxer as administrator (recommended - games often run as administrator, and keys and clicks can only reach them if MMORPG Boxer does too)"))
    Wiz.admin.Value := Cfg("General", "RunAsAdmin", "1") = "1"

    ; ---- page 2: number of slots ----
    P(2, g.AddText("xs ys w620", "How many " GameDef.name " clients do you play at the same time?" (GameDef.maxSlots < 8 ? " (" GameDef.name " allows at most " GameDef.maxSlots ".)" : "") "`n`nEach client gets a numbered slot. Slot 1 is usually your main character (for example your tank)."))
    P(2, g.AddText("xs y+14 w130 h28 0x200", "Number of slots:"))
    counts := []
    Loop GameDef.maxSlots
        counts.Push(String(A_Index))
    Wiz.count := P(2, g.AddDropDownList("x+6 yp w70 Choose" MAX_SLOTS, counts))

    ; ---- page 3: characters & accounts ----
    P(3, g.AddText("xs ys w620", "For each slot: a label (shown in window titles and on the toolbar, for example Tank), the character's name in EverQuest (used by follow and assist), the account name (filled in at the login screen; no passwords are stored) and a resolution ('Fill slot' uses the slot's whole space)."))
    P(3, g.AddText("xs y+12 w40", "Slot"))
    P(3, g.AddText("x+4 yp w140", "Label"))
    P(3, g.AddText("x+6 yp w140", "In-game name"))
    P(3, g.AddText("x+6 yp w140", "Account name"))
    P(3, g.AddText("x+6 yp w140", "Resolution"))
    Loop 8 {
        n := A_Index
        lbl := g.AddText("xs y+6 w40 h26 0x200", n)
        nm := g.AddEdit("x+4 yp w140", Cfg("Characters", String(n), ""))
        ig := g.AddEdit("x+6 yp w140", InGameName(n))
        ac := g.AddEdit("x+6 yp w140", SlotUser(n))
        rs := g.AddDropDownList("x+6 yp w140", ResolutionChoices())
        SetResChoice(rs, SlotResText(n))
        rs.OnEvent("Change", WizResChange)
        if !GameDef.together
            ig.Enabled := false          ; in-game names are for team commands
        if !GameDef.loginArg
            ac.Enabled := false          ; this game logs in through its own launcher
        Wiz.rows.Push({lbl: lbl, name: nm, ign: ig, acct: ac, res: rs})
        for c in [lbl, nm, ig, ac, rs]
            P(3, c)
    }

    ; ---- page 4: layout ----
    P(4, g.AddText("xs ys w620", "How should the windows be arranged on your screen? Pick a layout to see where each slot goes."))
    Wiz.layout := P(4, g.AddListView("xs y+8 w220 r12 -Hdr -Multi", ["Layout"]))
    Wiz.layout.ModifyCol(1, 196)
    LVFill(Wiz.layout, LayoutNames(), LayoutIndex(Layout))
    Wiz.layout.OnEvent("ItemSelect", (lv, row, sel) => sel ? WizPreview() : 0)
    Wiz.box := P(4, Keep(g.AddText("x+12 yp w388 h218 Border Background101010")))
    Wiz.desc := P(4, g.AddText("xp yp+226 w388 h84", ""))
    for col in SlotColours()
        Wiz.rects.Push(P(4, Keep(g.AddText("xs ys w10 h10 Center 0x200 Border cFFFFFF Background" col, A_Index))))
    Wiz.work := P(4, g.AddCheckbox("xs ys+356 w620", "Keep windows above the taskbar"))
    Wiz.work.Value := UseWorkArea
    Wiz.borders := P(4, g.AddCheckbox("xs y+4 w620", "Remove window borders (clients sit edge to edge)"))
    Wiz.borders.Value := HideBorders
    P(4, Hint(g.AddText("xs y+4 w620 cGray", "Tip: after changing layout, close and relaunch your clients so they start at the new size.")))

    ; ---- page 5: team & performance ----
    P(5, g.AddText("xs ys w620", "How the clients work together and run. You can change all of this later under Team && Performance in the control panel."))
    Wiz.prof := P(5, g.AddCheckbox("xs y+12 w620", "Separate EverQuest settings file for each character (recommended). Each keeps its own graphics and window settings, and a client that logs out keeps its own resolution."))
    Wiz.prof.Value := ProfilesOn
    if !GameDef.eqIni
        Wiz.prof.Enabled := false
    P(5, g.AddText("xs y+14 w620", "CPU cores:"))
    Wiz.cpu := P(5, g.AddDropDownList("xs y+4 w620", ["Share every core between all clients (normal)"
        , "Give slot 1 cores of its own and higher priority (smoother main when the PC is busy)"
        , "Keep my current CPU settings"]))
    custom := false
    Loop 8
        if (SlotCores(A_Index) != "all" || SlotPriority(A_Index) != "Normal")
            custom := true
    Wiz.cpu.Choose(custom ? 3 : 1)
    P(5, g.AddText("xs y+16 w620", "Frame-rate caps (blank = keep EverQuest's own setting):"))
    f1 := SlotFps(1), f2 := SlotFps(2)
    P(5, g.AddText("xs y+6 w160 h26 0x200", "Slot 1 - active:"))
    Wiz.fg1 := P(5, g.AddEdit("x+4 yp w60 Number", f1.fg))
    P(5, g.AddText("x+16 yp w100 h26 0x200", "background:"))
    Wiz.bg1 := P(5, g.AddEdit("x+4 yp w60 Number", f1.bg))
    P(5, g.AddText("xs y+6 w160 h26 0x200", "Other slots - active:"))
    Wiz.fg2 := P(5, g.AddEdit("x+4 yp w60 Number", f2.fg))
    P(5, g.AddText("x+16 yp w100 h26 0x200", "background:"))
    Wiz.bg2 := P(5, g.AddEdit("x+4 yp w60 Number", f2.bg))
    P(5, Hint(g.AddText("xs y+6 w620 cGray", GameDef.eqIni
        ? "Lower background caps save power; keep them at 25 or more so /follow keeps up. Caps apply when a client starts."
        : "Set frame-rate limits in " GameDef.name "'s own options.")))
    if !GameDef.eqIni
        for c in [Wiz.fg1, Wiz.bg1, Wiz.fg2, Wiz.bg2]
            c.Enabled := false
    if GameDef.together {
        P(5, g.AddText("xs y+16 w620", "Team commands (they use the in-game names from step 3):"))
        P(5, Hint(g.AddText("xs y+4 w620 cGray", "Ctrl+Alt+F  everyone follows you      Ctrl+Alt+X  stop following      Ctrl+Alt+T  everyone assists you`nMore (follow in a line, attack, back off, sit, stand) on the toolbar's Team button.")))
    } else
        P(5, Hint(g.AddText("xs y+16 w620 cGray", "No team commands, broadcasting or mirror mode for " GameDef.name ": " GameDef.why ".")))

    ; ---- page 6: features ----
    P(6, g.AddText("xs ys w620", "Choose the features you want. You can change all of these later."))
    Wiz.sound := P(6, g.AddCheckbox("xs y+10 w620", "Sound only from the client you're playing in (others are muted)"))
    Wiz.sound.Value := Cfg("Audio", "FollowActive", "1") = "1"
    Wiz.frame := P(6, g.AddCheckbox("xs y+6 w620", "Coloured frame around the client you're playing in"))
    Wiz.frame.Value := Cfg("Highlight", "Enabled", "1") = "1"
    Wiz.toolbar := P(6, g.AddCheckbox("xs y+6 w620", "Show the on-screen button bar"))
    Wiz.toolbar.Value := Cfg("Toolbar", "Show", "1") = "1"
    Wiz.panel := P(6, g.AddCheckbox("xs y+6 w620", "Open the control panel when MMORPG Boxer starts"))
    Wiz.panel.Value := Cfg("General", "ShowPanelOnStart", "1") = "1"
    Wiz.loginArg := P(6, g.AddCheckbox("xs y+6 w620", "Fill in the account name at the login screen (Launch All)"))
    Wiz.loginArg.Value := GameDef.loginArg && Cfg("Login", "UseLoginArg", "1") = "1"
    if !GameDef.loginArg
        Wiz.loginArg.Enabled := false
    P(6, g.AddText("xs y+14 w620", "Keys copied to every client when broadcast is on (Ctrl+Alt+B), separated by commas:"))
    Wiz.keys := P(6, g.AddEdit("xs y+4 w620", Cfg("Broadcast", "Keys", "1,2,3,4,5,6,7,8,9,0,-,=")))
    if !GameDef.together
        Wiz.keys.Enabled := false
    P(6, Hint(g.AddText("xs y+4 w620 cGray", "Default: the 12 hotbar keys 1-0, - and =.")))
    Wiz.tips := P(6, g.AddCheckbox("xs y+12 w620", "Show tooltips with keyboard shortcuts on buttons"))
    Wiz.tips.Value := TipsOn
    Wiz.updates := P(6, g.AddCheckbox("xs y+6 w620", "Check for updates when MMORPG Boxer starts"))
    Wiz.updates.Value := Cfg("Update", "CheckOnStart", "1") = "1"
    P(6, g.AddText("xs y+10 w110 h28 0x200", "Appearance:"))
    Wiz.look := P(6, g.AddDropDownList("x+4 yp w200", ["System", "Light", "Dark"]))
    Wiz.look.Choose(Appearance = "Dark" ? 3 : Appearance = "Light" ? 2 : 1)
    P(6, Hint(g.AddText("x+10 yp w300 h28 0x200 cGray", "System follows Windows' light/dark mode")))

    ; ---- page 7: summary ----
    P(7, g.AddText("xs ys w620", "Ready to save. Check the summary below, then click Finish. MMORPG Boxer will restart with your settings.`n`nAfterwards: Launch All starts your clients, Layouts... shows every layout, and Clickable Views (Ctrl+Alt+E) lets you use one client's hotbar from another."))
    Wiz.summary := P(7, g.AddEdit("xs y+10 w620 r16 ReadOnly -Wrap"))

    ; ---- buttons (below the tallest page) ----
    anchor.GetPos(, &ay)
    Wiz.back := g.AddButton("xm y" (ay + 470) " w110 h32", "< Back")
    Wiz.back.OnEvent("Click", (*) => WizGo(-1))
    Wiz.next := g.AddButton("x+8 yp w110 h32 Default", "Next >")
    Wiz.next.OnEvent("Click", (*) => WizGo(1))
    g.AddButton("x+284 yp w110 h32", "Cancel").OnEvent("Click", WizCancel)
    WizCheckPath()
    WizShowPage(1)
    ThemeGui(g)
    g.Show()
}

WizShowPage(i) {
    Wiz.page := i
    titles := ["Welcome", "Number of slots", "Characters && accounts", "Layout", "Team && performance", "Features", "Finish"]
    Wiz.title.Value := titles[i]
    Wiz.step.Value := "Step " i " of " titles.Length
    for k, list in Wiz.pages
        for c in list
            c.Visible := (k = i)
    if (i = 3) {
        cnt := Integer(Wiz.count.Text)
        for n, r in Wiz.rows
            for c in [r.lbl, r.name, r.ign, r.acct, r.res]
                c.Visible := (n <= cnt)
    }
    if (i = 4)
        WizPreview()
    if (i = 7)
        Wiz.summary.Value := WizSummary()
    Wiz.back.Enabled := (i > 1)
    Wiz.next.Text := (i = 7) ? "Finish" : "Next >"
}

WizGo(d) {
    i := Wiz.page
    if (d > 0 && i = 1 && !GamePathOK(Wiz.path.Value)) {
        if (MsgBox(GameDef.name " wasn't found in that folder. Continue anyway?", APP, "YesNo Icon! Owner" Wiz.g.Hwnd) != "Yes")
            return
    }
    if (d > 0 && i = 7)
        return WizFinish()
    WizShowPage(Max(1, Min(7, i + d)))
}

WizResChange(ctrl, *) {
    if (ctrl.Text = "Custom...") {
        v := AskResolution()
        SetResChoice(ctrl, v ? v : "Fill slot")
    }
}

WizBrowse(*) {
    Wiz.g.Opt("-AlwaysOnTop")                 ; so the folder picker isn't hidden behind it
    dir := DirSelect("*" Trim(Wiz.path.Value), 0, "Choose the " GameDef.name " folder")
    Wiz.g.Opt("+AlwaysOnTop")
    if (dir != "") {
        Wiz.path.Value := dir
        WizCheckPath()
    }
}

WizCheckPath(*) {
    ok := GamePathOK(Wiz.path.Value)
    Wiz.pathInfo.Value := ok ? "Found " GameDef.name "." : GameDef.name " not found in this folder."
    Wiz.pathInfo.Opt(ok ? "c2E7D32" : "cB71C1C")
}

; Draw the chosen layout in the preview box, one coloured box per slot.
WizPreview() {
    if (!Wiz || Wiz.page != 4)
        return
    name := LVSelText(Wiz.layout)
    cnt := Integer(Wiz.count.Text)
    LayoutArea(&L, &T, &W, &H)
    cells := []
    if Presets.Has(name) {
        Pr := Presets[name]
        Loop cnt
            cells.Push(Pr.Has(A_Index) ? WizRes(A_Index, Pr[A_Index], W, H) : 0)
    } else if (name = "Swap") {
        Loop cnt
            cells.Push(A_Index = 1 ? MainRegion : (SmallRegions.Length ? SmallRegions[Min(A_Index - 1, SmallRegions.Length)] : 0))
    } else {
        rows := Ceil(cnt / GridCols)
        cw := Min(GridW, W // GridCols), ch := Min(GridH, H // Max(1, rows))
        Loop cnt {
            k := A_Index - 1
            cells.Push(WizRes(A_Index, {x: Mod(k, GridCols) * cw, y: (k // GridCols) * ch, w: cw, h: ch}, W, H))
        }
    }
    labels := [], missing := ""
    for n, r in Wiz.rows {
        labels.Push(n (r.name.Value != "" ? " " r.name.Value : ""))
        if (n <= cnt && !(n <= cells.Length && cells[n]))
            missing .= (missing = "" ? "" : ", ") n
    }
    DrawPreview(Wiz.box, Wiz.rects, cells, labels)
    Wiz.desc.Value := LayoutDesc(name)
        . (missing = "" ? "" : "`nNo place for slot(s) " missing " - pick a layout with more spaces, or use fewer slots.")
}

; preview cell for slot n using the resolution picked on the wizard's page 3
WizRes(n, c, areaW, areaH) {
    t := Wiz.rows[n].res.Text
    if !RegExMatch(t, "^(\d+)x(\d+)$", &m)
        return c
    w := Integer(m[1]), h := Integer(m[2])
    x := Max(0, Min(c.x + (c.w - w) // 2, areaW - w)), y := Max(0, Min(c.y + (c.h - h) // 2, areaH - h))
    return {x: x, y: y, w: w, h: h}
}

WizSummary() {
    cnt := Integer(Wiz.count.Text)
    t := GameDef.name " folder:  " Trim(Wiz.path.Value) "`r`n"
    t .= "Slots:  " cnt "`r`n"
    Loop cnt {
        r := Wiz.rows[A_Index]
        t .= "   Slot " A_Index ":  " (r.name.Value != "" ? r.name.Value : "(no name - Launch All skips it)")
            . (r.ign.Value != "" ? "   in game " r.ign.Value : "")
            . (r.acct.Value != "" ? "   account " r.acct.Value : "") "   " r.res.Text "`r`n"
    }
    t .= "Layout:  " LVSelText(Wiz.layout) (Wiz.work.Value ? ", above the taskbar" : ", full screen")
        . (Wiz.borders.Value ? ", no borders" : ", with borders") "`r`n"
    yn(v) => v ? "on" : "off"
    t .= "Separate settings per character:  " yn(Wiz.prof.Value) "`r`n"
    t .= "CPU:  " Wiz.cpu.Text "`r`n"
    fps(a, b) => (Trim(a.Value) = "" && Trim(b.Value) = "") ? "EverQuest's own" : (Trim(a.Value) = "" ? "-" : a.Value) " / " (Trim(b.Value) = "" ? "-" : b.Value)
    t .= "Max FPS slot 1:  " fps(Wiz.fg1, Wiz.bg1) "    other slots:  " fps(Wiz.fg2, Wiz.bg2) "`r`n"
    t .= "Sound from active client only:  " yn(Wiz.sound.Value) "`r`n"
    t .= "Frame around active client:  " yn(Wiz.frame.Value) "`r`n"
    t .= "Button bar:  " yn(Wiz.toolbar.Value) "`r`n"
    t .= "Control panel on start:  " yn(Wiz.panel.Value) "`r`n"
    t .= "Account name at login:  " yn(Wiz.loginArg.Value) "`r`n"
    t .= "Broadcast keys:  " Wiz.keys.Value "`r`n"
    t .= "Tooltips:  " yn(Wiz.tips.Value) "    Appearance:  " Wiz.look.Text "    Update check:  " yn(Wiz.updates.Value) "`r`n"
    t .= "Run as administrator:  " yn(Wiz.admin.Value)
    return t
}

WizFinish() {
    cnt := Integer(Wiz.count.Text)
    W(sec, key, val) => IniWrite(val, CFG_FILE, sec, key)
    W("General", "EQPath", Trim(Wiz.path.Value))
    W("General", "Slots", cnt)
    W("General", "Layout", LVSelText(Wiz.layout) != "" ? LVSelText(Wiz.layout) : Layout)
    W("General", "UseWorkArea", Wiz.work.Value ? 1 : 0)
    W("General", "HideBorders", Wiz.borders.Value ? 1 : 0)
    W("General", "ShowPanelOnStart", Wiz.panel.Value ? 1 : 0)
    W("General", "RunAsAdmin", Wiz.admin.Value ? 1 : 0)
    Loop cnt {
        r := Wiz.rows[A_Index]
        W("Characters", String(A_Index), Trim(StrReplace(r.name.Value, "|")))
        W("InGameNames", String(A_Index), Trim(r.ign.Value))
        W("Usernames", String(A_Index), Trim(StrReplace(r.acct.Value, " ")))
        W("Resolutions", String(A_Index), (r.res.Text = "Fill slot" || r.res.Text = "Custom...") ? "" : r.res.Text)
    }
    W("Audio", "FollowActive", Wiz.sound.Value ? 1 : 0)
    W("Highlight", "Enabled", Wiz.frame.Value ? 1 : 0)
    W("Toolbar", "Show", Wiz.toolbar.Value ? 1 : 0)
    W("Login", "UseLoginArg", Wiz.loginArg.Value ? 1 : 0)
    keys := RegExReplace(Trim(Wiz.keys.Value), "\s+", "")
    W("Broadcast", "Keys", keys != "" ? keys : "1,2,3,4,5,6,7,8,9,0,-,=")
    W("Profiles", "PerCharacter", Wiz.prof.Value ? 1 : 0)
    switch Wiz.cpu.Value {
        case 1:
            Loop cnt {
                W("CPU", "Slot" A_Index, "all")
                W("CPU", "Priority" A_Index, "Normal")
            }
        case 2: AutoCoresWrite(cnt)
    }
    caps(a, b) => (Trim(a.Value) = "" && Trim(b.Value) = "") ? "" : Trim(a.Value) "," Trim(b.Value)
    Loop cnt
        W("FPS", "Slot" A_Index, A_Index = 1 ? caps(Wiz.fg1, Wiz.bg1) : caps(Wiz.fg2, Wiz.bg2))
    W("General", "ShowTooltips", Wiz.tips.Value ? 1 : 0)
    W("General", "Appearance", Wiz.look.Text)
    W("Update", "CheckOnStart", Wiz.updates.Value ? 1 : 0)
    W("General", "WizardDone", 1)
    Reload()
}

WizCancel(*) {
    global Wiz
    IniWrite(1, CFG_FILE, "General", "WizardDone")    ; don't open it again by itself
    try Wiz.g.Destroy()
    Wiz := 0
}

; ------------------------------ Toolbar ------------------------------
; Always-on-top button bar. It never takes focus (WS_EX_NOACTIVATE), so the
; client you're playing in stays active when you click a button.
; Buttons are drawn as coloured text boxes so the bar can be fully recoloured.
;   Ctrl + mouse wheel over the bar   = bigger / smaller
;   Shift + mouse wheel over the bar  = more / less transparent
;   Right-click the bar (or "Bar")    = size, transparency, colours, layout
TBTheme() {
    c(k, d) {
        v := Cfg("Toolbar", k, d)
        return RegExMatch(v, "^[0-9A-Fa-f]{6}$") ? v : d
    }
    return {bar: c("Color", "1E1E1E"), btn: c("ButtonColor", "3A3A3A"), text: c("TextColor", "FFFFFF")
          , on: c("OnColor", "2E7D32"), press: c("PressColor", "6A6A6A")}
}

BuildToolbar() {
    global TB, TBVertical, TBPos
    TBVertical := Cfg("Toolbar", "Vertical", "0") = "1"
    th := TBTheme()
    fs := Max(7, Min(36, ToInt(Cfg("Toolbar", "FontSize", "12"), 12)))
    TB := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +Border -DPIScale", APP " Toolbar")
    TB.BackColor := th.bar
    TB.SetFont("s" fs " w600 c" th.text, "Segoe UI")
    k := (A_ScreenDPI / 96) * (fs / 12)          ; spacing grows with the text
    TBPos := {x: Round(4 * k), y: Round(4 * k), gap: Round(4 * k)
            , padX: Round(20 * k), padY: Round(12 * k), maxW: 0, k: k, th: th}
    ; The grip has no click event, so clicks on it reach the bar itself and
    ; start a drag (see ToolbarLButton).
    grip := TB.AddText("x" TBPos.x " y" TBPos.y " Center 0x200 BackgroundTrans", "::")
    if TBVertical
        TBPos.y += Round(22 * k)
    else
        TBPos.x += Round(22 * k)
    Loop MAX_SLOTS {
        n := A_Index
        label := n (Chars[n] != "" ? " " SubStr(Chars[n], 1, 12) : "")
        TBAdd("slot" n, label, FocusSlot.Bind(n), "> " label)
    }
    if GameDef.together {
        TBAdd("bc",      "Broadcast",  ToggleBroadcast, "Broadcast ON")
        TBAdd("mirror",  "Mirror",     ToggleMirror, "Mirror ON")
    }
    if GameDef.views
        TBAdd("vfx",     "Views",      ToggleVFX, "Views ON")
    TBAdd("audio",   "Sound: All", ToggleAudio, "Sound: Active")
    if GameDef.views
        TBAdd("views",   "Edit Views", ShowViews)
    if GameDef.together
        TBAdd("team",    "Team",       TeamMenu)
    TBAdd("arrange", "Arrange",    ManualArrange)
    TBAdd("layout",  "Layout",     ShowLayouts)
    TBAdd("launch",  "Launch All", LaunchAll)
    TBAdd("pause",   "Pause",      TogglePause, "Resume")
    TBAdd("panel",   "Panel",      TogglePanel)
    TBAdd("bar",     "Bar",        ToolbarMenu)
    TBAdd("help",    "?",          HotkeyHelp)
    TBAdd("hide",    "X",          ToggleToolbar)
    ; vertical: make every button as wide as the widest
    if TBVertical {
        for key, v in TBBtns {
            v.ctrl.GetPos(&bx, &by, , &bh)
            v.ctrl.Move(bx, by, TBPos.maxW, bh)
        }
    }
    ; grip spans the bar's height (or width when vertical)
    for key, v in TBBtns {
        v.ctrl.GetPos(, , , &bh)
        if TBVertical
            grip.Move(TBPos.x, Round(4 * k), TBPos.maxW, Round(18 * k))
        else
            grip.Move(Round(4 * k), TBPos.y, Round(18 * k), bh)
        break
    }
    ; tooltips: what each button does and its shortcut
    fm := Cfg("Hotkeys", "FocusSlotModifier", "^"), am := Cfg("Hotkeys", "AssignSlotModifier", "^!")
    Loop MAX_SLOTS
        if TBBtns.Has("slot" A_Index)
            AddTip(TBBtns["slot" A_Index].ctrl, "Switch to slot " A_Index (Chars[A_Index] != "" ? " (" Chars[A_Index] ")" : "")
                . "`nShortcut: " NiceKey(fm) "F" A_Index "`n" NiceKey(am) "F" A_Index " moves the client you're in to this slot")
    for row in [["bc", "Broadcast on/off: keys you press are pressed in every client", "ToggleBroadcast", "^!b"]
              , ["mirror", "Mirror on/off: clicks are repeated in every client", "ToggleMirror", "^!m"]
              , ["vfx", "Show or hide your clickable views", "ToggleVFX", "^!v"]
              , ["audio", "Sound from the client you're in only, or from all clients", "ToggleAudio", "^!o"]
              , ["views", "Open Clickable Views: make, move, change and delete views", "ViewManager", "^!e"]
              , ["team", "Team commands: follow me, stop following, assist me, attack, sit, stand.`nFollow me " NiceKey(Cfg("Hotkeys", "FollowMe", "^!f")) ", stop " NiceKey(Cfg("Hotkeys", "StopFollow", "^!x")) ", assist me " NiceKey(Cfg("Hotkeys", "AssistMe", "^!t")), "", ""]
              , ["arrange", "Put every client back in its slot and make it redraw at its size`n(fixes a stretched picture)", "Arrange", "^!g"]
              , ["layout", "Open Layouts: see every layout with a picture and pick one.`nNext layout without the window: " NiceKey(Cfg("Hotkeys", "ToggleLayout", "^!s")), "", ""]
              , ["launch", "Start every slot that has a character", "LaunchAll", "^!l"]
              , ["pause", "Pause or resume all MMORPG Boxer hotkeys", "Pause", "^!p"]
              , ["panel", "Show or hide the control panel", "ControlPanel", "^!h"]
              , ["hide", "Hide this toolbar", "ToggleToolbar", "^!k"]]
        if TBBtns.Has(row[1])
            AddTip(TBBtns[row[1]].ctrl, TipText(row[2], row[3], row[4]))
    if TBBtns.Has("bar")
        AddTip(TBBtns["bar"].ctrl, "Toolbar look: size, colours, transparency, layout`nOver the bar: Ctrl+Wheel = size, Shift+Wheel = transparency")
    if TBBtns.Has("help")
        AddTip(TBBtns["help"].ctrl, "List every keyboard shortcut")
    TB.OnEvent("ContextMenu", ToolbarMenu)
    UpdateToolbar()
    SetTimer(ToolbarMarkActive, 200)
}

; Add a button sized to fit its longest text (e.g. "Broadcast ON").
TBAdd(key, label, fn, longest := "") {
    global TBPos
    if (longest = "")
        longest := label
    th := TBPos.th
    b := TB.AddText("x" TBPos.x " y" TBPos.y " Center 0x200 Background" th.btn " c" th.text, longest)
    b.GetPos(, , &w, &h)
    h += TBPos.padY
    w := Max(w + TBPos.padX, h)                 ; at least square
    b.Move(TBPos.x, TBPos.y, w, h)
    b.Text := label
    b.OnEvent("Click", TBClick.Bind(key, fn))
    b.OnEvent("DoubleClick", TBClick.Bind(key, fn))   ; quick repeat clicks
    TBBtns[key] := {ctrl: b, label: label, on: false}
    TBPos.maxW := Max(TBPos.maxW, w)
    if TBVertical
        TBPos.y += h + TBPos.gap
    else
        TBPos.x += w + TBPos.gap
}

; Flash the button, then run its command.
TBClick(key, fn, *) {
    if TBBtns.Has(key) {
        TBPaint(key, TBTheme().press)
        SetTimer(TBPaint.Bind(key, ""), -150)
    }
    fn()
}

; Colour a button: explicit colour, or "" for its normal / ON colour.
TBPaint(key, color := "", *) {
    if !TBBtns.Has(key)
        return
    v := TBBtns[key]
    if (color = "") {
        th := TBTheme()
        color := v.on ? th.on : th.btn
    }
    try {
        v.ctrl.Opt("+Background" color)
        v.ctrl.Redraw()
    }
}

ShowToolbar() {
    if !TB
        return
    x := Cfg("Toolbar", "X", ""), y := Cfg("Toolbar", "Y", "")
    TB.Show("NA AutoSize Hide")
    TB.GetPos(, , &w, &h)
    MonitorGetWorkArea(MonitorNum, &L, &T, &R, &B)
    if !(IsInteger(x) && IsInteger(y)) {
        ; first time: bottom centre, just above the taskbar
        x := L + (R - L - w) // 2, y := B - h - 6
    }
    ; keep it on screen (it may have grown)
    x := Max(L, Min(Integer(x), R - w)), y := Max(T, Min(Integer(y), B - h))
    TB.Show("NA AutoSize x" x " y" y)
    ApplyToolbarOpacity()
}

ApplyToolbarOpacity() {
    if !TB
        return
    op := Max(20, Min(100, ToInt(Cfg("Toolbar", "Opacity", "100"), 100)))
    try WinSetTransparent(op >= 100 ? "Off" : Round(op * 2.55), TB)
}

ToggleToolbar(*) {
    if !TB
        return
    if DllCall("IsWindowVisible", "Ptr", TB.Hwnd) {
        TB.Hide()
        IniWrite(0, CFG_FILE, "Toolbar", "Show")
    } else {
        ShowToolbar()
        IniWrite(1, CFG_FILE, "Toolbar", "Show")
    }
}

; Rebuilding is done a moment later in its own thread (several quick
; requests, e.g. mouse-wheel ticks, become one rebuild). The new bar is built
; first; the old one is hidden and only destroyed seconds later, so a button
; that is still mid-click is never freed underneath it.
RebuildToolbar(*) {
    if TB
        SetTimer(DoRebuildToolbar, -40)
}

DoRebuildToolbar() {
    global TB, TBBtns
    old := TB, oldBtns := TBBtns
    vis := DllCall("IsWindowVisible", "Ptr", old.Hwnd)
    if vis {
        old.GetPos(&x, &y)
        IniWrite(x, CFG_FILE, "Toolbar", "X")
        IniWrite(y, CFG_FILE, "Toolbar", "Y")
    }
    SetTimer(ToolbarMarkActive, 0)
    TBBtns := Map()
    BuildToolbar()
    if vis
        ShowToolbar()
    try old.Hide()
    SetTimer(DestroyOldToolbar.Bind(old, oldBtns), -3000)
}

DestroyOldToolbar(old, oldBtns, *) {
    for key, v in oldBtns
        try Tips.Delete(v.ctrl.Hwnd)
    try old.Destroy()
}

; ---- look & feel ----
MouseOverToolbar(*) {
    if !TB
        return false
    MouseGetPos(, , &w)
    return (w = TB.Hwnd)
}

ToolbarResize(step, *) {
    fs := Max(7, Min(36, ToInt(Cfg("Toolbar", "FontSize", "12"), 12) + step))
    IniWrite(fs, CFG_FILE, "Toolbar", "FontSize")
    RebuildToolbar()
    Status("Toolbar size " fs, 1200)
}

ToolbarOpacity(step, *) {
    op := Max(20, Min(100, ToInt(Cfg("Toolbar", "Opacity", "100"), 100) + step))
    IniWrite(op, CFG_FILE, "Toolbar", "Opacity")
    ApplyToolbarOpacity()
    Status("Toolbar opacity " op "%", 1200)
}

SetToolbarSetting(key, value, *) {
    IniWrite(value, CFG_FILE, "Toolbar", key)
    if (key = "Opacity")
        ApplyToolbarOpacity()
    else
        RebuildToolbar()
}

ResetToolbarLook(*) {
    for key in ["Color", "ButtonColor", "TextColor", "OnColor", "PressColor", "Opacity", "FontSize", "Vertical"]
        try IniDelete(CFG_FILE, "Toolbar", key)
    RebuildToolbar()
    Status("Toolbar look reset", 1500)
}

ColourPresets() {
    return [["Dark grey", "1E1E1E"], ["Charcoal", "3A3A3A"], ["Black", "000000"]
        , ["Navy", "1A2A4A"], ["Blue", "1E5AA8"], ["Teal", "00695C"], ["Forest", "1F4D2B"]
        , ["Green", "2E7D32"], ["Maroon", "5A1A1A"], ["Red", "B71C1C"], ["Purple", "4A2A6A"]
        , ["Gold", "B8860B"], ["Yellow", "F9D71C"], ["Silver", "C0C0C0"], ["White", "FFFFFF"]]
}

ColourMenu(key) {
    m := Menu()
    cur := Cfg("Toolbar", key, "")
    for c in ColourPresets() {
        m.Add(c[1], SetToolbarSetting.Bind(key, c[2]))
        if (cur = c[2])
            m.Check(c[1])
    }
    m.Add()
    m.Add("Custom...", PickToolbarColour.Bind(key))
    return m
}

ToolbarMenu(*) {
    m := Menu()
    fs := ToInt(Cfg("Toolbar", "FontSize", "12"), 12)
    size := Menu()
    size.Add("Larger`tCtrl+Wheel up", ToolbarResize.Bind(1))
    size.Add("Smaller`tCtrl+Wheel down", ToolbarResize.Bind(-1))
    size.Add()
    for v in [9, 10, 11, 12, 14, 16, 18, 20, 24, 28] {
        size.Add(v " pt", SetToolbarSetting.Bind("FontSize", v))
        if (v = fs)
            size.Check(v " pt")
    }
    m.Add("Size", size)
    op := ToInt(Cfg("Toolbar", "Opacity", "100"), 100)
    tr := Menu()
    for v in [100, 90, 80, 70, 60, 50, 40, 30] {
        tr.Add(v "%" (v = 100 ? " (solid)" : ""), SetToolbarSetting.Bind("Opacity", v))
        if (v = op)
            tr.Check(v "%" (v = 100 ? " (solid)" : ""))
    }
    tr.Add()
    tr.Add("Tip: Shift+Wheel over the bar", (*) => 0)
    tr.Disable("Tip: Shift+Wheel over the bar")
    m.Add("Transparency", tr)
    m.Add()
    m.Add("Bar colour", ColourMenu("Color"))
    m.Add("Button colour", ColourMenu("ButtonColor"))
    m.Add("Text colour", ColourMenu("TextColor"))
    m.Add("ON / active colour", ColourMenu("OnColor"))
    m.Add()
    m.Add(TBVertical ? "Lay out horizontally" : "Lay out vertically", SetToolbarSetting.Bind("Vertical", TBVertical ? 0 : 1))
    m.Add("Reset look", ResetToolbarLook)
    m.Add("Hide bar`tCtrl+Alt+K", ToggleToolbar)
    ; a menu needs a foreground window to close properly; give focus back after
    prev := WinActive("A")
    DllCall("SetForegroundWindow", "Ptr", TB.Hwnd)
    m.Show()
    if (prev && WinExist("ahk_id " prev))
        try WinActivate("ahk_id " prev)
}

; Windows colour picker for one toolbar colour.
PickToolbarColour(key, *) {
    th := TBTheme()
    cur := (key = "Color") ? th.bar : (key = "ButtonColor") ? th.btn : (key = "TextColor") ? th.text : th.on
    if (A_PtrSize != 8) {
        ib := InputBox("Colour as RRGGBB hex (e.g. 1E5AA8):", APP, "w300 h120", cur)
        if (ib.Result = "OK" && RegExMatch(ib.Value, "^[0-9A-Fa-f]{6}$"))
            SetToolbarSetting(key, StrUpper(ib.Value))
        return
    }
    static custom := Buffer(64, 0)
    cc := Buffer(72, 0)                          ; CHOOSECOLORW (64-bit)
    NumPut("UInt", 72, cc, 0)
    rgb := Integer("0x" cur)
    NumPut("UInt", ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF), cc, 24)
    NumPut("Ptr", custom.Ptr, cc, 32)
    NumPut("UInt", 0x3, cc, 40)                  ; CC_RGBINIT | CC_FULLOPEN
    if DllCall("comdlg32\ChooseColorW", "Ptr", cc) {
        bgr := NumGet(cc, 24, "UInt")
        SetToolbarSetting(key, Format("{:02X}{:02X}{:02X}", bgr & 0xFF, (bgr >> 8) & 0xFF, (bgr >> 16) & 0xFF))
    }
}

; Drag the bar by its :: grip (or any gap between buttons).
ToolbarLButton(wParam, lParam, msg, hwnd) {
    if (TB && hwnd = TB.Hwnd) {
        PostMessage(0xA1, 2, 0, , "ahk_id " TB.Hwnd)     ; WM_NCLBUTTONDOWN, HTCAPTION
        return 0
    }
}

; Remember where the bar was dropped.
ToolbarMoved(wParam, lParam, msg, hwnd) {
    if (TB && hwnd = TB.Hwnd) {
        TB.GetPos(&x, &y)
        IniWrite(x, CFG_FILE, "Toolbar", "X")
        IniWrite(y, CFG_FILE, "Toolbar", "Y")
    }
}

; Show on/off state on the toggle buttons (text and ON colour).
UpdateToolbar() {
    if !TB
        return
    SetBtn("bc", Broadcasting ? "Broadcast ON" : "Broadcast", Broadcasting)
    SetBtn("mirror", Mirroring ? "Mirror ON" : "Mirror", Mirroring)
    SetBtn("vfx", VFXOn ? "Views ON" : "Views", VFXOn)
    SetBtn("pause", A_IsSuspended ? "Resume" : "Pause", A_IsSuspended)
    SetBtn("audio", AudioFollow ? "Sound: Active" : "Sound: All", AudioFollow)
}

SetBtn(key, text, on := "") {
    if !TBBtns.Has(key)
        return
    v := TBBtns[key]
    try v.ctrl.Text := text
    if (on != "" && !!on != v.on) {
        v.on := !!on
        TBPaint(key)
    }
}

; Mark the slot you're playing in: a > in front and the ON colour.
ToolbarMarkActive() {
    static last := -1
    if Switching
        return
    n := SlotOf(WinActive(EQ))
    if (n = last)
        return
    last := n
    Loop MAX_SLOTS {
        k := "slot" A_Index
        if TBBtns.Has(k)
            SetBtn(k, (A_Index = n ? "> " : "") TBBtns[k].label, A_Index = n)
    }
}

; "^!b" -> "Ctrl+Alt+b"
NiceKey(k) {
    out := ""
    while (k != "" && InStr("^!+#", SubStr(k, 1, 1))) {
        c := SubStr(k, 1, 1)
        k := SubStr(k, 2)
        out .= (c = "^") ? "Ctrl+" : (c = "!") ? "Alt+" : (c = "+") ? "Shift+" : "Win+"
    }
    return out k
}

HotkeyHelp(*) {
    H(name, def) => Cfg("Hotkeys", name, def)
    Nice(k) => NiceKey(k)
    fm := H("FocusSlotModifier", "^"), am := H("AssignSlotModifier", "^!")
    t := ""
    t .= Nice(fm) "F1-F" MAX_SLOTS "`tSwitch to slot`n"
    t .= Nice(am) "F1-F" MAX_SLOTS "`tMove active client to slot`n"
    for row in [["NextClient", "^!n", "Next client"], ["ToggleBroadcast", "^!b", "Broadcast on/off"]
              , ["ToggleMirror", "^!m", "Mirror mode on/off"], ["CreateView", "^!c", "New clickable view"]
              , ["DeleteView", "^!d", "Delete view under mouse"], ["ToggleVFX", "^!v", "Views on/off"]
              , ["ViewManager", "^!e", "Clickable Views window"]
              , ["LayoutsWindow", "", "Layouts window"]
              , ["FollowMe", "^!f", "Team: everyone follow me"], ["StopFollow", "^!x", "Team: stop following"]
              , ["AssistMe", "^!t", "Team: assist me"], ["FollowLine", "", "Team: follow in a line"]
              , ["AttackMyTarget", "", "Team: attack my target"], ["BackOff", "", "Team: back off"]
              , ["SitAll", "", "Team: everyone sit"], ["StandAll", "", "Team: everyone stand"]
              , ["Arrange", "^!g", "Arrange / re-sync"], ["ToggleLayout", "^!s", "Next layout"]
              , ["LaunchAll", "^!l", "Launch All"], ["Accounts", "^!a", "Slots (names & usernames)"]
              , ["RestoreBorders", "^!u", "Restore borders"], ["ControlPanel", "^!h", "Control panel"]
              , ["ToggleToolbar", "^!k", "Show/hide this toolbar"], ["Pause", "^!p", "Pause hotkeys"]
              , ["ToggleAudio", "^!o", "Sound: active client only / all"]
              , ["SetupWizard", "^!w", "Setup Wizard"]
              , ["ReloadConfig", "^!r", "Reload config"], ["Quit", "^!q", "Quit"]]
        if ((k := H(row[1], row[2])) != "")
            t .= Nice(k) "`t" row[3] "`n"
    t .= Nice(H("MouseBroadcast", "XButton1")) "`tOne mirrored click"
    if (MsgBox(t "`n`n" APP " " APP_VERSION "`n`nOpen the online guide?", APP " - Hotkeys", "YesNo Iconi") = "Yes")
        OpenGuide()
}

; The full guide, kept in step with README.md, is the repository's wiki.
OpenGuide(*) {
    try Run("https://github.com/" DEFAULT_UPDATE_REPO "/wiki")
    catch {
        guide := A_ScriptDir "\README.html"
        if FileExist(guide)
            try Run(guide)
    }
}

; --------------------------- Status / panel ---------------------------
Status(msg, ms := 2500) {
    try {
        MonitorGet(MonitorNum, &mL, &mT)
        ToolTip(msg, mL + 10, mT + 10, 1)
        if (ms > 0)
            SetTimer(() => ToolTip(, , , 1), -ms)
    }
    if SB
        try SB.Value := "  " msg
}

UpdateIndicator() {
    UpdateToolbar()
    MonitorGet(MonitorNum, &mL, &mT)
    t := (Broadcasting ? "BROADCAST ON" : "") (Broadcasting && Mirroring ? "  |  " : "") (Mirroring ? "MIRROR ON" : "")
    if (t != "")
        ToolTip(t, mL + 10, mT + 45, 2)
    else
        ToolTip(, , , 2)
}

TogglePause(*) {
    Suspend(-1)
    UpdateToolbar()
    Status(A_IsSuspended ? APP " PAUSED (hotkeys off)" : APP " active", A_IsSuspended ? 0 : 2500)
}

BuildPanel() {
    global Panel, LV, SB, LayoutDDL, PEName, PEUser, PESlot, PEInfo, PERes
    Panel := Gui(, APP)
    Panel.SetFont("s10", "Segoe UI")
    ; which game (each game keeps its own slots, layouts and settings)
    Panel.AddText("xm w52 h28 0x200", "Game:")
    gameDDL := Panel.AddDropDownList("x+4 yp w220", GameNames())
    gameDDL.Choose(GameIndex())
    gameDDL.OnEvent("Change", (c, *) => (SetGame(c.Text) = false ? c.Choose(GameIndex()) : 0))
    AddTip(gameDDL, "Each game keeps its own slots, layouts and settings. Switching restarts MMORPG Boxer.")
    Hint(Panel.AddText("x+12 yp w336 h28 0x200 cGray", GameDef.hint))
    ; 4 columns of buttons, each 150 wide with 8 between -> 624 wide
    LV := Panel.AddListView("xm y+8 w624 r8 -Multi", ["Slot", "Character", "Account", "Resolution", "Status", "Window"])
    LV.OnEvent("DoubleClick", PanelDoubleClick)
    LV.OnEvent("ItemSelect", PanelSelect)
    ; edit the selected slot's character name and account name right here
    PESlot := Panel.AddText("xm y+10 w56 h28 0x200", "Slot 1:")
    Panel.AddText("x+4 yp w74 h28 0x200", "Character")
    PEName := Panel.AddEdit("x+4 yp w150 h28")
    Panel.AddText("x+12 yp w100 h28 0x200", "Account name")
    PEUser := Panel.AddEdit("x+4 yp w150 h28")
    if !GameDef.loginArg
        PEUser.Enabled := false          ; this game logs in through its own launcher
    Panel.AddButton("x+10 yp w66 h28 Default", "Save").OnEvent("Click", PanelSave)
    Panel.AddText("xm+60 y+6 w74 h28 0x200", "Resolution")
    PERes := Panel.AddDropDownList("x+4 yp w150", ResolutionChoices())
    PERes.OnEvent("Change", PanelResChange)
    Hint(Panel.AddText("x+12 yp w300 h28 0x200 cGray", "game resolution / window size of this slot"))
    PEInfo := Hint(Panel.AddText("xm y+6 w624 cGray", GameDef.loginArg
        ? "Click a slot above, set its character, account name and resolution, then Save. Launch All pre-fills the account name at the EverQuest login screen."
        : "Click a slot above, set its character name and resolution, then Save. " GameDef.name " clients are started from its own launcher; each window goes into the next free slot."))
    ; buttons: fixed height so a long label can never wrap into the next row
    bw := "w150 h32"
    PB(opts, label, fn, tip) {
        b := Panel.AddButton(opts, label)
        b.OnEvent("Click", fn)
        AddTip(b, tip)
        return b
    }
    ; features this game's rules don't allow are greyed out
    PBx(opts, label, fn, tip, allowed := "") {
        if (allowed = "")
            allowed := GameDef.together
        b := PB(opts, label, fn, allowed ? tip : "Not available for " GameDef.name ": " GameDef.why ".")
        if !allowed
            b.Enabled := false
    }
    PB("xm y+12 " bw " Section", "Launch All", LaunchAll, TipText(GameDef.launchers.Length
        ? "Open the " GameDef.name " launcher; start each character from it and MMORPG Boxer puts the windows in their slots"
        : "Start every slot that has a character", "LaunchAll", "^!l"))
    PB("x+8 yp " bw, "Arrange", ManualArrange, TipText("Put every client back in its slot and make it redraw at its size (fixes a stretched picture)", "Arrange", "^!g"))
    PB("x+8 yp " bw, "Save Layout...", SaveLayout, TipText("Save where the clients are now as a new layout"))
    PBx("x+8 yp " bw, "Mirror On/Off", ToggleMirror, TipText("Clicks are repeated in every client", "ToggleMirror", "^!m"))
    PBx("xs y+8 " bw, "Broadcast On/Off", ToggleBroadcast, TipText("Keys you press are pressed in every client", "ToggleBroadcast", "^!b"))
    PBx("x+8 yp " bw, "Views On/Off", ToggleVFX, TipText("Show or hide your clickable views", "ToggleVFX", "^!v"), GameDef.views)
    PBx("x+8 yp " bw, "Clickable Views...", ShowViews, TipText("Make, move, change and delete clickable views", "ViewManager", "^!e"), GameDef.views)
    PB("x+8 yp " bw, "Characters...", ShowAccounts, TipText("Character and account names for each slot", "Accounts", "^!a"))
    PB("xs y+8 " bw, "Show/Hide Toolbar", ToggleToolbar, TipText("Show or hide the on-screen button bar", "ToggleToolbar", "^!k"))
    PB("x+8 yp " bw, "Setup Wizard...", ShowWizard, TipText("Set everything up step by step", "SetupWizard", "^!w"))
    PB("x+8 yp " bw, "Edit Config", EditConfig, TipText("Open MMORPGBoxer.ini in Notepad"))
    PB("x+8 yp " bw, "Reload Config", (*) => Reload(), TipText("Restart MMORPG Boxer to apply changes made in MMORPGBoxer.ini", "ReloadConfig", "^!r"))
    PB("xs y+8 " bw, "Team && Performance...", ShowPerf, TipText("In-game names, follow/assist, CPU cores, frame-rate caps and per-character EverQuest settings"))
    PBx("x+8 yp " bw, "Team Commands...", TeamMenu, TipText("Follow me, stop following, assist me, attack, sit, stand", "FollowMe", "^!f"))
    PB("x+8 yp " bw, "Diagnostics...", Diagnostics, TipText("Write a report of every window and the recent log (to send when something's wrong)"))
    PB("x+8 yp " bw, "Check for Updates", (*) => CheckForUpdates(false), TipText("Look for a newer version of MMORPG Boxer"))
    tipBox := Panel.AddCheckbox("xs y+8 w300 h28" (TipsOn ? " Checked" : ""), "Show tooltips with shortcuts")
    tipBox.OnEvent("Click", SetTipsOn)
    Panel.AddText("x+16 yp w96 h28 0x200", "Appearance:")
    look := Panel.AddDropDownList("x+4 yp w120", ["System", "Light", "Dark"])
    try look.Text := Appearance
    catch
        look.Choose(1)
    look.OnEvent("Change", (c, *) => SetAppearance(c.Text))
    AddTip(look, "System follows Windows' light or dark app mode (Settings > Personalization > Colors)")
    AddTip(tipBox, "Show what each button does and its keyboard shortcut when you point at it")
    ; layout and slot count on their own row
    Panel.AddText("xs y+14 w60 h32 0x200", "Layout:")
    LayoutDDL := Panel.AddText("x+4 yp w200 h32 0x200", Layout)       ; current layout's name
    PB("x+8 yp w130 h32", "Layouts...", ShowLayouts, TipText("See every layout with a picture and an explanation, and switch, save or delete layouts", "LayoutsWindow", ""))
    Panel.AddText("x+12 yp w120 h32 0x200", "Number of slots:")
    counts := []
    Loop GameDef.maxSlots
        counts.Push(String(A_Index))
    ddl := Panel.AddDropDownList("x+4 yp+2 w56 Choose" MAX_SLOTS, counts)
    ddl.OnEvent("Change", SetSlotCount)
    Hint(Panel.AddText("xs y+10 w624 h24 0x200 cGray", "Version " APP_VERSION ".  Double-click a slot to switch to it. Changing the number of slots saves and reloads."))
    Panel.AddText("xm y+6 w624 h1 0x10")                 ; separator line
    SB := Panel.AddText("xm y+4 w624 h22 0x200", "")      ; status line
    Panel.OnEvent("Close", (*) => Panel.Hide())
    ThemeGui(Panel)
}

SetSlotCount(ctrl, *) {
    IniWrite(ctrl.Text, CFG_FILE, "General", "Slots")
    Reload()
}

PanelSelect(lv, row, selected) {
    ; only load when you pick a different slot, so a background refresh never
    ; wipes what you're typing
    if (selected && row > 0 && Integer(lv.GetText(row, 1)) != PanelSel)
        PanelLoad(Integer(lv.GetText(row, 1)))
}

PanelLoad(n) {
    global PanelSel
    PanelSel := n
    PESlot.Value := "Slot " n ":"
    PEName.Value := Chars[n]
    PEUser.Value := SlotUser(n)
    SetResChoice(PERes, SlotResText(n))
}

; Select a resolution in a dropdown, adding it to the list if it's custom.
SetResChoice(ddl, text) {
    try {
        ddl.Text := text
        return
    }
    ddl.Add([text])
    ddl.Text := text
}

PanelResChange(ctrl, *) {
    if (ctrl.Text = "Custom...") {
        v := AskResolution(SlotRes(PanelSel) ? SlotResText(PanelSel) : "")
        SetResChoice(ctrl, v ? v : SlotResText(PanelSel))
    }
}

PanelSave(*) {
    n := PanelSel
    SaveSlotInfo(n, PEName.Value, PEUser.Value)
    if (PERes.Text != "Custom...")
        SaveSlotRes(n, PERes.Text)
    PEInfo.Value := "Saved slot " n ": " (Chars[n] != "" ? Chars[n] : "(no name)")
        . "  /  account " (SlotUser(n) != "" ? SlotUser(n) : "(none)")
        . "  /  " SlotResText(n)
}

; Save a slot's character name and account name, and update everything that shows them.
SaveSlotInfo(n, name, user) {
    name := Trim(StrReplace(name, "|"))
    user := Trim(StrReplace(user, " "))
    if (name != Chars[n]) {
        IniWrite(name, CFG_FILE, "Characters", String(n))
        Chars[n] := name
        UpdateTitles()
        RebuildToolbar()
    }
    IniWrite(user, CFG_FILE, "Usernames", String(n))
    RefreshPanel()
    if AccGui
        try AccFillSlots(n)
}

PanelDoubleClick(lv, row) {
    if (row > 0)
        FocusSlot(Integer(lv.GetText(row, 1)))
}

TogglePanel(*) {
    if !Panel
        return
    if DllCall("IsWindowVisible", "Ptr", Panel.Hwnd) {
        Panel.Hide()
    } else {
        Panel.Show()
        PanelLoad(PanelSel)
        RefreshPanel()
    }
}

RefreshPanel() {
    if (!Panel || !DllCall("IsWindowVisible", "Ptr", Panel.Hwnd))
        return
    LV.Opt("-Redraw")
    LV.Delete()
    Loop MAX_SLOTS {
        n := A_Index
        id := Slots[n]
        st := !id ? "not running" : (Layout = "Swap" && n = MainSlot) ? "running (main)" : "running"
        if (id && OpenedOffSlot(n))
            st .= " - not in its slot, restart it"
        LV.Add(, n, Chars[n], SlotUser(n), SlotResText(n), st, id ? Format("0x{:X}", id) : "")
    }
    LV.ModifyCol()
    LV.ModifyCol(1, "Integer 50")
    LV.ModifyCol(2, "AutoHdr")
    LV.ModifyCol(3, "AutoHdr")
    if (PanelSel >= 1 && PanelSel <= MAX_SLOTS)
        LV.Modify(PanelSel, "Select Focus")
    LV.Opt("+Redraw")
    SB.Value := (Format("  Layout: {}    Broadcast: {}    Mirror: {}    Views: {}    Clients: {}"
        , Layout, Broadcasting ? "ON" : "off", Mirroring ? "ON" : "off", VFXOn ? "ON" : "off", CountClients()))
}

Cleanup(*) {
    SetEQAudio(0)                 ; never leave clients muted after exiting
    HideHighlight()
    HideMirrorDots()
    for v in VFX
        DestroyVFX(v)
}

; --------------------------- Default config ---------------------------
WriteDefaultConfig() {
    text := "
(
; =====================================================================
;  MMORPG Boxer configuration
;  Edit this file, then press Ctrl+Alt+R (Reload Config).
;  Keep comments on their own lines - never after a value.
; =====================================================================

[General]
; Folder where EverQuest is installed
EQPath=C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest
EQExe=eqgame.exe
; patchme starts a client at the login screen. Patch with LaunchPad first.
LaunchArgs=patchme
; Milliseconds to wait between launches
LaunchDelay=12000
; Number of client slots to use (1-8)
Slots=4
; Show what each button does and its shortcut when you point at it (1/0)
ShowTooltips=1
; System (follow Windows' light/dark app mode), Light or Dark
Appearance=System
; Monitor to place the clients on
Monitor=1
; Grid, Swap, or a preset: Top + 2 Bottom, Top + 3 Bottom, Left + 2 Right,
; Big + 3 Right, Side by Side, Top / Bottom, Big + 4 Bottom, or your own
; [Layout.Name] section. Easiest: pick it in the control panel.
Layout=Grid
; Re-arrange automatically when a client opens or closes (1/0)
AutoArrange=1
; Hide title bars and borders so clients sit edge to edge (1/0)
HideBorders=1
; How: Clip = keep EverQuest's frame but show only its picture (reliable,
; default). Strip = remove the title bar (EverQuest sometimes puts it back)
BorderMode=Clip
; Swap layout: activating a small client moves it to the main region (1/0)
SwapOnActivate=1
; Milliseconds a new client must keep the same size before it is arranged
SettleTime=15000
; Fit layouts in the area above the taskbar (1) or the whole screen (0)
UseWorkArea=1
; Open the control panel when MMORPG Boxer starts (1/0)
ShowPanelOnStart=1
; 1 = clients fill their whole slot (they open slightly smaller if needed and
; are widened after start-up). 0 = keep a small margin on very wide slots
FillSlots=1
; Write the next free slot's position into eqclient.ini before each client
; starts, so EverQuest opens in its slot and the mouse lines up (1/0)
PrepareIni=1
; Run MMORPG Boxer as administrator (needed when EverQuest runs as admin) (1/0)
RunAsAdmin=1

[Characters]
; Slot=Name. Names are labels for window titles. Launch All starts one
; client for every slot that has a name.
1=Tank
2=Healer
3=DPS1
4=DPS2

[Profiles]
; 1 = each character keeps its own eqclient.ini (and eqlsPlayerData.ini) in
; the Profiles folder; the one you're playing is put in place automatically
PerCharacter=1

[InGameNames]
; slot=character name in EverQuest (used by follow / assist)

[CPU]
; Slot<n>=all, or logical core numbers like 0-3 or 4-11,14
; Priority<n>=Normal | Above normal | High | Below normal
; MainSlot = the slot "Auto-assign CPU Cores" gives cores of its own
MainSlot=1

[FPS]
; Slot<n>=<max FPS while active>,<max FPS in the background>
; (EverQuest's own MaxFPS / MaxBGFPS, set before each client starts)

[Team]
; key that walks backwards in EverQuest (breaks /follow)
StopFollowKey=Down

[Groups]
; Name=slot,slot,...  Use group names as key map targets.
Healers=2
DPS=3,4
Party=1,2,3,4

[Login]
; Launch All adds /login:<username> so EverQuest pre-fills the username box.
; Set usernames in the Slots window (Ctrl+Alt+A) or under [Usernames]. (1/0)
UseLoginArg=1

[Usernames]
; Slot=EverQuest username (no passwords are stored)

[Resolutions]
; Slot=WidthxHeight, e.g. 1=2560x1440. Empty = fill the slot's whole space.
; Set these in the control panel or the Setup Wizard.

[Audio]
; 1 = only the client you're playing in makes sound; the others are muted
; (Ctrl+Alt+O or the Sound button switches this)
FollowActive=1

[Toolbar]
; On-screen button bar (Ctrl+Alt+K shows/hides it). Drag it by the :: grip.
; Right-click it for size, transparency and colours.
; Ctrl+Wheel over it = bigger/smaller, Shift+Wheel = more/less transparent.
Show=1
; 1 = stack the buttons vertically
Vertical=0
; Text size 7-36 (buttons and spacing grow with it)
FontSize=12
; 20-100 (100 = solid)
Opacity=100
; Colours as RRGGBB hex: bar background, buttons, text, ON/active buttons
Color=1E1E1E
ButtonColor=3A3A3A
TextColor=FFFFFF
OnColor=2E7D32

[Mirror]
; Colour of the markers showing where mirrored clicks land (RRGGBB)
MarkerColor=FFFF00
; Milliseconds to let each client notice the pointer before clicking.
; Raise it (100-150) if clicks are missed. Raising MaxBGFPS in eqclient.ini
; lets you lower it.
ClickDelay=60
; Milliseconds the button is held down
HoldTime=40
; Milliseconds to stay in the client you clicked in before hopping to the others
StayDelay=50
; Show "Mirrored ... to N client(s)" after each mirrored click (1/0)
ShowFeedback=1

[Update]
; GitHub repository updates come from (owner/name). Leave empty for the
; built-in one (Rav8es/MMORPGBoxer)
Repo=
; Check for a newer version when MMORPG Boxer starts (1/0)
CheckOnStart=1

[Highlight]
; Coloured frame around the client you are playing in (1/0)
Enabled=1
; Colour as RRGGBB hex (FF0000 = red, 00FF00 = green, FFD700 = gold)
Color=FF0000
; Thickness in pixels
Thickness=4

[Grid]
; 2 x 2 grid of 1920x1080 fills a 3840x2160 (4K) monitor
Columns=2
Width=1920
Height=1080

; Custom layout example (pixels from the monitor's top-left: x,y,width,height).
; Or arrange clients by hand and click Save Layout... in the control panel.
[Layout.My Layout]
1=0,0,3840,1080
2=0,1080,1920,1080
3=1920,1080,1920,1080

[SwapLayout]
; x,y,width,height relative to the monitor's top-left corner.
; Default for 4K: main client 2880x1620, others 960x540 around it.
Main=0,0,2880,1620
Small1=2880,0,960,540
Small2=2880,540,960,540
Small3=2880,1080,960,540
Small4=0,1620,960,540
Small5=960,1620,960,540
Small6=1920,1620,960,540
Small7=2880,1620,960,540

[Broadcast]
; Whitelist = only the keys listed are broadcast
; Blacklist = every key EXCEPT those listed is broadcast (includes movement)
; Example blacklist: Keys=Enter,NumpadEnter,/,Escape,r
; Keys used by key maps are never broadcast.
Mode=Whitelist
; The 12 hotbar keys: 1-0, - and =
Keys=1,2,3,4,5,6,7,8,9,0,-,=
; Switch = hop to each client and press the key there (works with EverQuest;
;          keys are pressed once, so holding a key to move is not copied)
; Send   = copy key down/up to background clients (EverQuest often ignores it)
Method=Switch
; Milliseconds to wait in each client before/after the key (Switch method)
SwitchDelay=20
; Milliseconds to stay in the client you pressed the key in before hopping to
; the others. Raise it (80-120) if that client sometimes misses the key.
StayDelay=50
; Show a short message after each broadcast key (1/0)
ShowFeedback=1

[Hotkeys]
; ^ = Ctrl   ! = Alt   + = Shift   # = Win
; FocusSlotModifier + F1..F8 switches to that slot
FocusSlotModifier=^
; AssignSlotModifier + F1..F8 moves the active client into that slot
AssignSlotModifier=^!
NextClient=^!n
ToggleBroadcast=^!b
; Mirror mode: every left/right click is repeated in all clients
ToggleMirror=^!m
; Show/hide the on-screen toolbar
ToggleToolbar=^!k
; Sound from the active client only / from all clients
ToggleAudio=^!o
; Open the Setup Wizard
SetupWizard=^!w
Arrange=^!g
ToggleLayout=^!s
RestoreBorders=^!u
ControlPanel=^!h
ToggleVFX=^!v
; Drag-to-create a clickable view, and delete the view under the mouse
CreateView=^!c
DeleteView=^!d
ViewManager=^!e
; Layouts window (pictures and explanations of every layout); empty = no hotkey
LayoutsWindow=
; Team helpers (type EverQuest's /target, /follow, /assist ... into the others)
FollowMe=^!f
StopFollow=^!x
AssistMe=^!t
FollowLine=
AttackMyTarget=
BackOff=
SitAll=
StandAll=
LaunchAll=^!l
; Open the Slots window (character names and usernames)
Accounts=^!a
ReloadConfig=^!r
Pause=^!p
Quit=^!q
; Mouse button that clicks the same spot in every client
MouseBroadcast=XButton1

; ---------------------------------------------------------------------
;  KEY MAPS   [KeyMap.AnyName]
;    Hotkey=      key that triggers it (only while an EQ client is active)
;    Step1=...    what happens on a press. With several steps, each
;                 press runs the next step (round robin).
;    ResetAfter=  seconds idle before going back to Step1 (0 = never)
;  Action:  Target:Key   - join several actions with  &&
;    Target = All, Others, Active, a slot number, or a group name
;    Key    = one AutoHotkey key, e.g. {F1}  5  +2  {Numpad5}
;  Special: Focus:N switches to slot N
;  Rule: one key press = one action per client. No delays.
; ---------------------------------------------------------------------

[KeyMap.AssistAll]
; F11 = every other client presses its F11 (put an /assist hotkey there)
Hotkey=F11
Step1=Others:{F11}

[KeyMap.FollowMe]
; F12 = every other client presses its F12 (put a /follow hotkey there)
Hotkey=F12
Step1=Others:{F12}

[KeyMap.NukeRotation]
; Shift+F10 = each press makes the next DPS client press 6
Hotkey=+F10
Step1=3:6
Step2=4:6
ResetAfter=10

[KeyMap.HealAndBack]
; Shift+F9 = healer presses 5 (e.g. a heal on your target)
Hotkey=+F9
Step1=Healers:5

; ---------------------------------------------------------------------
;  VIDEO FX   live views of part of one client, shown anywhere on screen
;  Name=SourceSlot|srcX,srcY,srcW,srcH|destX,destY,destW,destH|opacity
;    Source coords assume a ReferenceWidth x ReferenceHeight client and
;    are scaled to the client's real size. Dest coords are relative to
;    the monitor's top-left corner. Click a view to switch to that client.
;  Example (remove the ; to enable):
;  HealerView=2|0,0,480,270|3360,1890,480,270|255
; ---------------------------------------------------------------------
[VFX]
StartOn=0
; Clicking a view:  Switch = hop to that client, click the real button, hop
; back (most reliable).  Send = background click only.  Focus = just switch.
ClickMode=Switch
; Milliseconds to wait after switching before/after the click (Switch mode).
; Lower = faster. Raise it if clicks are missed. Set EverQuest's background
; FPS (MaxBGFPS in eqclient.ini) to 30-60 so low values work.
SwitchDelay=20
ReferenceWidth=1920
ReferenceHeight=1080
)"
    FileAppend(text, CFG_FILE, "UTF-16")
}
