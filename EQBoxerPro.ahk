#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
; =====================================================================
;  EQ Boxer Pro - an ISBoxer-style multiboxing tool for EverQuest Live
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
;  Everything is configured in EQBoxer.ini (created on first run).
;  Design rule: one key press = one action per client. No delays, no
;  timed sequences, nothing runs without you pressing a key.
; =====================================================================

SetWinDelay(0)
SetControlDelay(-1)
SetKeyDelay(-1, -1)
CoordMode("Mouse", "Client")
CoordMode("ToolTip", "Screen")
CoordMode("Pixel", "Screen")

global APP := "EQ Boxer Pro"
global APP_VERSION := "1.1.0"
; GitHub repository ("owner/name") that updates are published to
global DEFAULT_UPDATE_REPO := "Rav8es/BoxerPro"
; installed copies ship an icon next to the script
if FileExist(A_ScriptDir "\EQBoxerPro.ico")
    TraySetIcon(A_ScriptDir "\EQBoxerPro.ico")
global CFG_FILE := A_ScriptDir "\EQBoxer.ini"
global LOG_FILE := A_ScriptDir "\EQBoxer.log"     ; window placement log (Diagnostics)
if !FileExist(CFG_FILE)
    WriteDefaultConfig()

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
global MAX_SLOTS := Max(1, Min(8, ToInt(Cfg("General", "Slots", "4"), 4)))

; ------------------------------ Settings ------------------------------
global EQPath         := Cfg("General", "EQPath", "C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest")
global EQExe          := Cfg("General", "EQExe", "eqgame.exe")
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
global PrepareIni     := Cfg("General", "PrepareIni", "1") = "1"
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
if (mouseKey != "") {
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
OnMessage(0x232, ToolbarMoved)     ; WM_EXITSIZEMOVE: save toolbar position

; ------------------------------ Tray menu -----------------------------
A_IconTip := APP " " APP_VERSION
A_TrayMenu.Delete()
A_TrayMenu.Add("Control Panel", TogglePanel)
A_TrayMenu.Add("Show/Hide Toolbar", ToggleToolbar)
A_TrayMenu.Add("Launch All", LaunchAll)
A_TrayMenu.Add("Characters && Accounts...", ShowAccounts)
A_TrayMenu.Add("Setup Wizard...", ShowWizard)
A_TrayMenu.Add("Diagnostics...", Diagnostics)
A_TrayMenu.Add("Check for Updates...", (*) => CheckForUpdates(false))
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
    for n, id in Slots {
        if !id
            continue
        want := "EQ" n (Chars[n] != "" ? " - " Chars[n] : "")
        try {
            if (WinGetTitle("ahk_id " id) != want)
                WinSetTitle(want, "ahk_id " id)
        }
    }
}

WatchClients() {
    global Enforcing
    changed := RefreshSlots()
    UpdateTitles()
    if !Launching
        PrepareSlotIni(FirstFreeSlot())
    CheckOffSlot()
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
            MsgBox("Windows is scaling the EverQuest clients (display scale "
                . Round(A_ScreenDPI / 96 * 100) "%).`n`n"
                . "This makes the mouse line up only in the top-left window.`n`n"
                . "Fix: right-click eqgame.exe > Properties > Compatibility >`n"
                . "Change high DPI settings > check 'Override high DPI scaling`n"
                . "behavior' and choose 'Application'. Then restart the clients."
                , APP, "Icon! T60")
            return
        }
    }
}

; ------------------------------ Diagnostics ------------------------------
; Window events are written to EQBoxer.log so placement problems can be seen
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
        return Format("window {},{} {}x{} | picture {},{} {}x{} | {}", x, y, w, h, cx, cy, cw, ch
            , (st & 0xC00000) ? "title bar" : "no title bar")
    }
    return "(window gone)"
}

; Writes a report (settings, every slot's window vs its slot, recent log)
; to EQBoxer-diagnostics.txt, copies it to the clipboard and opens it.
Diagnostics(*) {
    t := APP " diagnostics  " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
    t .= "Admin: " (A_IsAdmin ? "yes" : "no") "   Screen DPI: " A_ScreenDPI "   Layout: " Layout "   Slots: " MAX_SLOTS "`r`n"
    MonitorGet(MonitorNum, &mL, &mT, &mR, &mB)
    MonitorGetWorkArea(MonitorNum, &wL, &wT, &wR, &wB)
    t .= Format("Monitor {}: {},{} - {},{}   work area: {},{} - {},{}", MonitorNum, mL, mT, mR, mB, wL, wT, wR, wB) "`r`n"
    bs := BorderSize()
    t .= "Border size (w x h added): " bs.w " x " bs.h "   UseWorkArea=" UseWorkArea "  HideBorders=" HideBorders "`r`n"
    ini := EQPath "\eqclient.ini"
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
    out := A_ScriptDir "\EQBoxer-diagnostics.txt"
    try FileDelete(out)
    FileAppend(t, out, "UTF-8")
    A_Clipboard := t
    Run('notepad.exe "' out '"')
    Status("Diagnostics saved to EQBoxer-diagnostics.txt and copied to the clipboard", 6000)
}

; ------------------------------- Updates -------------------------------
; New versions are published as GitHub releases. Each release has the
; installer (EQBoxerPro-Setup.exe) and its SHA-256 checksum
; (EQBoxerPro-Setup.exe.sha256). The download is only run if the checksums
; match. The installer runs silently (/S /UPDATE), keeps the settings and
; restarts EQ Boxer Pro.
UpdateRepo() => Trim(Cfg("Update", "Repo", DEFAULT_UPDATE_REPO))

HttpGet(url) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "EQBoxerPro-Updater/" APP_VERSION)
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
        json := HttpGet("https://api.github.com/repos/" repo "/releases/latest")
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
    ShowUpdatePrompt(latest, JsonStr(json, "body")
        , FindAsset(json, "EQBoxerPro-Setup.exe"), FindAsset(json, "EQBoxerPro-Setup.exe.sha256"))
}

ShowUpdatePrompt(ver, notes, exeUrl, shaUrl) {
    g := Gui("+AlwaysOnTop", APP " - Update available")
    g.SetFont("s10", "Segoe UI")
    g.SetFont("s12 w600")
    g.AddText("w560", APP " " ver " is available")
    g.SetFont("s10 w400")
    g.AddText("w560 cGray", "You have version " APP_VERSION ". Updating closes EQ Boxer Pro, installs the new version and starts it again. Your settings are kept.")
    g.AddText("w560 y+12", "What's new:")
    g.AddEdit("w560 r12 ReadOnly", notes != "" ? notes : "(no notes)")
    g.AddButton("w180 h32 Default", "Update now").OnEvent("Click", (*) => (g.Destroy(), InstallUpdate(ver, exeUrl, shaUrl)))
    g.AddButton("x+10 yp w180 h32", "Later").OnEvent("Click", (*) => g.Destroy())
    g.AddButton("x+10 yp w180 h32", "Skip this version").OnEvent("Click"
        , (*) => (IniWrite(ver, CFG_FILE, "Update", "SkipVersion"), g.Destroy()))
    g.Show()
}

InstallUpdate(ver, exeUrl, shaUrl) {
    if (exeUrl = "" || shaUrl = "") {
        MsgBox("This release doesn't include the installer and its checksum, so it can't be installed automatically.", APP, "Icon!")
        return
    }
    tmp := A_Temp "\EQBoxerPro-Setup-" ver ".exe"
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
; Usernames live in [Usernames] in EQBoxer.ini. No passwords are stored.
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
        AccInfo := AccGui.AddText("xm w320 cGray", "")
        AccGui.AddButton("xm w100 Default", "Save").OnEvent("Click", (*) => AccSave())
        AccGui.AddButton("x+10 w100", "Close").OnEvent("Click", (*) => AccGui.Hide())
        AccGui.AddText("xm w320 cGray y+12"
            , "Launch All starts each client with its username already in the login box. You type the password. An empty name means Launch All skips that slot.")
        AccGui.OnEvent("Close", (*) => AccGui.Hide())
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
; Manager. Move the username into EQBoxer.ini and delete the stored password.
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
CellFor(n, forStart := false) {
    LayoutArea(&mL, &mT, &mW, &mH)
    if Presets.Has(Layout) {
        P := Presets[Layout]
        if !P.Has(n)
            return 0                    ; this layout has no place for slot n
        r := P[n]
        return SlotSize(ApplyRes(n, {x: mL + r.x, y: mT + r.y, w: r.w, h: r.h}), forStart)
    }
    if (Layout = "Swap") {
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
    PrepareSlotIni(FirstFreeSlot(), true)
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
; it straight back and squashes its picture (EQBoxer.log). So by default the
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

ClipToPicture(id) {
    try {
        key := ClipKey(id)
        p := StrSplit(key, ",")
        rgn := DllCall("CreateRectRgn", "Int", p[1], "Int", p[2], "Int", p[1] + p[3], "Int", p[2] + p[4], "Ptr")
        DllCall("SetWindowRgn", "Ptr", id, "Ptr", rgn, "Int", 1)     ; Windows owns rgn now
        ClipFor[id] := key
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
    clipOK := (ClipFor.Has(id) && ClipFor[id] = ClipKey(id))
    Placed[id] := true
    if (sizeOK && posOK && clipOK)
        return false
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
    if !WinExist("ahk_id " id)
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
        clipOK := (ClipFor.Has(id) && ClipFor[id] = ClipKey(id))
        if (sizeOK && posOK && clipOK) {
            WriteLog("slot " n ": in place - " desc " | clipped to picture")
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

; EverQuest's behaviour (seen in EQBoxer.log): whenever its picture area
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
    ; window while it is still doing that gets undone (EQBoxer.log showed it
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
    if (HideBorders && BorderMode() = "Clip")
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
    ForceResync := true
    try Arrange()
    ForceResync := false
    Status("Arranged " CountClients() " client(s). If one looks stretched, close it and start it again.", 6000)
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
    PrepareSlotIni(FirstFreeSlot(), true)
    if LayoutDDL
        try LayoutDDL.Text := name
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
    if LayoutDDL {
        LayoutDDL.Delete()
        LayoutDDL.Add(LayoutNames())
    }
    SetLayout(name)
    if LayoutDDL
        try LayoutDDL.Text := name
    Status("Saved layout '" name "'")
}

RestoreBorders(*) {
    for id in Slots
        if id {
            try DllCall("SetWindowRgn", "Ptr", id, "Ptr", 0, "Int", 1)
            ClipFor.Delete(id)
            try WinSetStyle("+0xC40000", "ahk_id " id)
        }
    Status("Window borders restored")
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
    global Launching
    exe := EQPath "\" EQExe
    if !FileExist(exe) {
        MsgBox("Can't find " exe "`n`nSet EQPath in EQBoxer.ini.", APP, "Icon!")
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
        Status("Slot " n " isn't exactly in its slot - close it and start it again with EQ Boxer running.", 10000)
        return
    }
}

; ------------------------------- Key maps -----------------------------
LoadKeyMaps() {
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
    MouseGetPos(, , &win)
    if SlotOf(win)
        MirrorClickFrom(win, "Left", true)
}

; Mirror mode (Ctrl+Alt+M): after each left/right click in a client, the same
; click is made at the same spot (relative to window size) in every other one.
ToggleMirror(*) {
    global Mirroring
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
    if clickSource
        Click(button)
    Switching := true
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
    VFXOn := Cfg("VFX", "StartOn", "0") = "1"
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
        ; DWM_THUMBNAIL_PROPERTIES (48 bytes)
        props := Buffer(48, 0)
        NumPut("UInt", 0x1F, props, 0)    ; RECTDESTINATION|RECTSOURCE|OPACITY|VISIBLE|SOURCECLIENTAREAONLY
        NumPut("Int", 0, "Int", 0, "Int", v.Dst.w, "Int", v.Dst.h, props, 4)
        NumPut("Int", Round(v.Src.x * sx), "Int", Round(v.Src.y * sy)
             , "Int", Round((v.Src.x + v.Src.w) * sx), "Int", Round((v.Src.y + v.Src.h) * sy), props, 20)
        NumPut("UChar", v.Opacity, props, 36)
        NumPut("Int", 1, props, 40)
        NumPut("Int", 1, props, 44)
        DllCall("dwmapi\DwmUpdateThumbnailProperties", "Ptr", thumb, "Ptr", props)
        v.Gui := g
        v.Thumb := thumb
        VfxByHwnd[g.Hwnd] := v
    }
}

; Left/right button pressed on a view -> click the same spot in the source client.
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
    if (VFX.Length = 0) {
        Status("No views yet - press Ctrl+Alt+C to create one")
        return
    }
    VFXOn := !VFXOn
    RefreshVFX()
    RefreshPanel()
    UpdateToolbar()
    Status("Video FX " (VFXOn ? "ON" : "OFF"))
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

CreateView(*) {
    global VFXOn
    RefreshSlots()
    if (CountClients() = 0) {
        Status("No clients running")
        return
    }
    ; 1) the area to copy
    r1 := SelectRect("Step 1 of 2: drag a box around the area to copy (e.g. slot 2's hotbar)")
    if (!r1 || r1.w < 8 || r1.h < 8)
        return Status("View cancelled")
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
    if !srcSlot
        return Status("That area isn't inside an EverQuest client", 4000)
    refW := ToInt(Cfg("VFX", "ReferenceWidth", "1920"), 1920)
    refH := ToInt(Cfg("VFX", "ReferenceHeight", "1080"), 1080)
    fx := refW / ww, fy := refH / wh
    src := {x: Round((r1.x - wx) * fx), y: Round((r1.y - wy) * fy)
          , w: Round(r1.w * fx), h: Round(r1.h * fy)}
    ; 2) where to show it (a plain click = same size at that spot)
    r2 := SelectRect("Step 2 of 2: drag a box where the copy should go (or just click to place it at the same size)")
    if !r2
        return Status("View cancelled")
    if (r2.w < 8 || r2.h < 8)
        r2 := {x: r2.x, y: r2.y, w: r1.w, h: r1.h}
    MonitorGet(MonitorNum, &mL, &mT)
    ; unique name
    i := 1
    while HasViewName("View" i)
        i++
    name := "View" i
    value := srcSlot "|" src.x "," src.y "," src.w "," src.h "|" (r2.x - mL) "," (r2.y - mT) "," r2.w "," r2.h "|255"
    IniWrite(value, CFG_FILE, "VFX", name)
    VFX.Push({Name: name, Slot: srcSlot, Src: src
            , Dst: {x: r2.x - mL, y: r2.y - mT, w: r2.w, h: r2.h}
            , Opacity: 255, Gui: 0, Thumb: 0})
    VFXOn := true
    RefreshVFX()
    RefreshPanel()
    Status("Created " name " from slot " srcSlot ". Click it to use slot " srcSlot "'s buttons.", 5000)
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
    Status("Deleted " v.Name)
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
    Wiz := {g: g, page: 1, pages: [[], [], [], [], [], []], rows: [], rects: []}
    g.SetFont("s15 w600")
    Wiz.title := g.AddText("xm w620 h34", "")
    g.SetFont("s10 w400")
    Wiz.step := g.AddText("xm w620 cGray", "")
    anchor := g.AddText("xm y+10 w1 h1 Section")
    P(i, ctrl) {
        Wiz.pages[i].Push(ctrl)
        return ctrl
    }

    ; ---- page 1: EverQuest folder ----
    P(1, g.AddText("xs ys w620", "This wizard sets up EQ Boxer in a few steps. You can run it again any time from the control panel, the tray menu, or Ctrl+Alt+W.`n`nFirst, where is EverQuest installed? (The folder that contains eqgame.exe.)"))
    Wiz.path := P(1, g.AddEdit("xs y+12 w500", EQPath))
    Wiz.path.OnEvent("Change", WizCheckPath)
    P(1, g.AddButton("x+8 yp-1 w110", "Browse...")).OnEvent("Click", WizBrowse)
    Wiz.pathInfo := P(1, g.AddText("xs y+6 w620", ""))
    Wiz.admin := P(1, g.AddCheckbox("xs y+16 w620", "Run EQ Boxer as administrator (recommended - EverQuest usually runs as administrator, and keys can only reach it if EQ Boxer does too)"))
    Wiz.admin.Value := Cfg("General", "RunAsAdmin", "1") = "1"

    ; ---- page 2: number of slots ----
    P(2, g.AddText("xs ys w620", "How many EverQuest clients do you play at the same time?`n`nEach client gets a numbered slot. Slot 1 is usually your main character (for example your tank)."))
    P(2, g.AddText("xs y+14 w130 h28 0x200", "Number of slots:"))
    Wiz.count := P(2, g.AddDropDownList("x+6 yp w70 Choose" MAX_SLOTS, ["1", "2", "3", "4", "5", "6", "7", "8"]))

    ; ---- page 3: characters & accounts ----
    P(3, g.AddText("xs ys w620", "Give each slot a character name (shown in window titles and on the toolbar), an account name (filled in for you at the EverQuest login screen) and a resolution. 'Fill slot' uses the slot's whole space in the layout. No passwords are stored."))
    P(3, g.AddText("xs y+12 w44", "Slot"))
    P(3, g.AddText("x+6 yp w200", "Character name"))
    P(3, g.AddText("x+8 yp w200", "Account name"))
    P(3, g.AddText("x+8 yp w150", "Resolution"))
    Loop 8 {
        n := A_Index
        lbl := g.AddText("xs y+6 w44 h26 0x200", n)
        nm := g.AddEdit("x+6 yp w200", Cfg("Characters", String(n), ""))
        ac := g.AddEdit("x+8 yp w200", SlotUser(n))
        rs := g.AddDropDownList("x+8 yp w150", ResolutionChoices())
        SetResChoice(rs, SlotResText(n))
        rs.OnEvent("Change", WizResChange)
        Wiz.rows.Push({lbl: lbl, name: nm, acct: ac, res: rs})
        for c in [lbl, nm, ac, rs]
            P(3, c)
    }

    ; ---- page 4: layout ----
    P(4, g.AddText("xs ys w620", "How should the windows be arranged on your screen?"))
    Wiz.layout := P(4, g.AddDropDownList("xs y+8 w300", LayoutNames()))
    try Wiz.layout.Text := Layout
    Wiz.layout.OnEvent("Change", (*) => WizPreview())
    Wiz.box := P(4, g.AddText("xs y+10 w384 h216 Border Background101010"))
    colours := ["2E5A88", "2E7D32", "8E3B3B", "6A4C93", "B8860B", "00695C", "5D4037", "455A64"]
    Loop 8
        Wiz.rects.Push(P(4, g.AddText("xs ys w10 h10 Center 0x200 Border cFFFFFF Background" colours[A_Index], A_Index)))
    Wiz.note := P(4, g.AddText("x+0 yp w10 cGray", ""))
    Wiz.work := P(4, g.AddCheckbox("xs w620", "Keep windows above the taskbar"))
    Wiz.work.Value := UseWorkArea
    Wiz.borders := P(4, g.AddCheckbox("xs y+4 w620", "Remove window borders (clients sit edge to edge)"))
    Wiz.borders.Value := HideBorders
    P(4, g.AddText("xs y+4 w620 cGray", "Tip: after changing layout, close and relaunch your clients so they start at the new size."))

    ; ---- page 5: features ----
    P(5, g.AddText("xs ys w620", "Choose the features you want. You can change all of these later."))
    Wiz.sound := P(5, g.AddCheckbox("xs y+10 w620", "Sound only from the client you're playing in (others are muted)"))
    Wiz.sound.Value := Cfg("Audio", "FollowActive", "1") = "1"
    Wiz.frame := P(5, g.AddCheckbox("xs y+6 w620", "Coloured frame around the client you're playing in"))
    Wiz.frame.Value := Cfg("Highlight", "Enabled", "1") = "1"
    Wiz.toolbar := P(5, g.AddCheckbox("xs y+6 w620", "Show the on-screen button bar"))
    Wiz.toolbar.Value := Cfg("Toolbar", "Show", "1") = "1"
    Wiz.panel := P(5, g.AddCheckbox("xs y+6 w620", "Open the control panel when EQ Boxer starts"))
    Wiz.panel.Value := Cfg("General", "ShowPanelOnStart", "1") = "1"
    Wiz.loginArg := P(5, g.AddCheckbox("xs y+6 w620", "Fill in the account name at the login screen (Launch All)"))
    Wiz.loginArg.Value := Cfg("Login", "UseLoginArg", "1") = "1"
    P(5, g.AddText("xs y+14 w620", "Keys copied to every client when broadcast is on (Ctrl+Alt+B), separated by commas:"))
    Wiz.keys := P(5, g.AddEdit("xs y+4 w620", Cfg("Broadcast", "Keys", "1,2,3,4,5,6,7,8,9,0,-,=")))
    P(5, g.AddText("xs y+4 w620 cGray", "Default: the 12 hotbar keys 1-0, - and =."))

    ; ---- page 6: summary ----
    P(6, g.AddText("xs ys w620", "Ready to save. Check the summary below, then click Finish. EQ Boxer will restart with your settings."))
    Wiz.summary := P(6, g.AddEdit("xs y+10 w620 r12 ReadOnly -Wrap"))

    ; ---- buttons (below the tallest page) ----
    anchor.GetPos(, &ay)
    Wiz.back := g.AddButton("xm y" (ay + 470) " w110 h32", "< Back")
    Wiz.back.OnEvent("Click", (*) => WizGo(-1))
    Wiz.next := g.AddButton("x+8 yp w110 h32 Default", "Next >")
    Wiz.next.OnEvent("Click", (*) => WizGo(1))
    g.AddButton("x+284 yp w110 h32", "Cancel").OnEvent("Click", WizCancel)
    WizCheckPath()
    WizShowPage(1)
    g.Show()
}

WizShowPage(i) {
    Wiz.page := i
    titles := ["Welcome", "Number of slots", "Characters && accounts", "Layout", "Features", "Finish"]
    Wiz.title.Value := titles[i]
    Wiz.step.Value := "Step " i " of 6"
    for k, list in Wiz.pages
        for c in list
            c.Visible := (k = i)
    if (i = 3) {
        cnt := Integer(Wiz.count.Text)
        for n, r in Wiz.rows
            for c in [r.lbl, r.name, r.acct, r.res]
                c.Visible := (n <= cnt)
    }
    if (i = 4)
        WizPreview()
    if (i = 6)
        Wiz.summary.Value := WizSummary()
    Wiz.back.Enabled := (i > 1)
    Wiz.next.Text := (i = 6) ? "Finish" : "Next >"
}

WizGo(d) {
    i := Wiz.page
    if (d > 0 && i = 1 && !FileExist(Trim(Wiz.path.Value) "\" EQExe)) {
        if (MsgBox("eqgame.exe wasn't found in that folder. Continue anyway?", APP, "YesNo Icon! Owner" Wiz.g.Hwnd) != "Yes")
            return
    }
    if (d > 0 && i = 6)
        return WizFinish()
    WizShowPage(Max(1, Min(6, i + d)))
}

WizResChange(ctrl, *) {
    if (ctrl.Text = "Custom...") {
        v := AskResolution()
        SetResChoice(ctrl, v ? v : "Fill slot")
    }
}

WizBrowse(*) {
    Wiz.g.Opt("-AlwaysOnTop")                 ; so the folder picker isn't hidden behind it
    dir := DirSelect("*" Trim(Wiz.path.Value), 0, "Choose the EverQuest folder (it contains eqgame.exe)")
    Wiz.g.Opt("+AlwaysOnTop")
    if (dir != "") {
        Wiz.path.Value := dir
        WizCheckPath()
    }
}

WizCheckPath(*) {
    ok := FileExist(Trim(Wiz.path.Value) "\" EQExe)
    Wiz.pathInfo.Value := ok ? "Found " EQExe "." : "eqgame.exe not found in this folder."
    Wiz.pathInfo.Opt(ok ? "c2E7D32" : "cB71C1C")
}

; Draw the chosen layout in the preview box, one coloured box per slot.
WizPreview() {
    if (!Wiz || Wiz.page != 4)
        return
    name := Wiz.layout.Text
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
    Wiz.box.GetPos(&bx, &by, &bw, &bh)
    f := Min((bw - 2) / W, (bh - 2) / H)
    missing := ""
    for n, r in Wiz.rects {
        c := (n <= cells.Length) ? cells[n] : 0
        if !c {
            r.Visible := false
            if (n <= cnt)
                missing .= (missing = "" ? "" : ", ") n
            continue
        }
        r.Move(bx + 1 + Round(c.x * f), by + 1 + Round(c.y * f), Max(8, Round(c.w * f) - 1), Max(8, Round(c.h * f) - 1))
        nm := Wiz.rows[n].name.Value
        r.Text := n (nm != "" ? " " nm : "")
        r.Visible := true
    }
    Wiz.note.Move(bx + bw + 10, by, 220, 120)
    Wiz.note.Value := (missing = "") ? "" : "This layout has no place for slot(s) " missing ". Pick a layout with more spaces, or use fewer slots."
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
    t := "EverQuest folder:  " Trim(Wiz.path.Value) "`r`n"
    t .= "Slots:  " cnt "`r`n"
    Loop cnt {
        r := Wiz.rows[A_Index]
        t .= "   Slot " A_Index ":  " (r.name.Value != "" ? r.name.Value : "(no name - Launch All skips it)")
            . (r.acct.Value != "" ? "   account " r.acct.Value : "") "   " r.res.Text "`r`n"
    }
    t .= "Layout:  " Wiz.layout.Text (Wiz.work.Value ? ", above the taskbar" : ", full screen")
        . (Wiz.borders.Value ? ", no borders" : ", with borders") "`r`n"
    yn(v) => v ? "on" : "off"
    t .= "Sound from active client only:  " yn(Wiz.sound.Value) "`r`n"
    t .= "Frame around active client:  " yn(Wiz.frame.Value) "`r`n"
    t .= "Button bar:  " yn(Wiz.toolbar.Value) "`r`n"
    t .= "Control panel on start:  " yn(Wiz.panel.Value) "`r`n"
    t .= "Account name at login:  " yn(Wiz.loginArg.Value) "`r`n"
    t .= "Broadcast keys:  " Wiz.keys.Value "`r`n"
    t .= "Run as administrator:  " yn(Wiz.admin.Value)
    return t
}

WizFinish() {
    cnt := Integer(Wiz.count.Text)
    W(sec, key, val) => IniWrite(val, CFG_FILE, sec, key)
    W("General", "EQPath", Trim(Wiz.path.Value))
    W("General", "Slots", cnt)
    W("General", "Layout", Wiz.layout.Text)
    W("General", "UseWorkArea", Wiz.work.Value ? 1 : 0)
    W("General", "HideBorders", Wiz.borders.Value ? 1 : 0)
    W("General", "ShowPanelOnStart", Wiz.panel.Value ? 1 : 0)
    W("General", "RunAsAdmin", Wiz.admin.Value ? 1 : 0)
    Loop cnt {
        r := Wiz.rows[A_Index]
        W("Characters", String(A_Index), Trim(StrReplace(r.name.Value, "|")))
        W("Usernames", String(A_Index), Trim(StrReplace(r.acct.Value, " ")))
        W("Resolutions", String(A_Index), (r.res.Text = "Fill slot" || r.res.Text = "Custom...") ? "" : r.res.Text)
    }
    W("Audio", "FollowActive", Wiz.sound.Value ? 1 : 0)
    W("Highlight", "Enabled", Wiz.frame.Value ? 1 : 0)
    W("Toolbar", "Show", Wiz.toolbar.Value ? 1 : 0)
    W("Login", "UseLoginArg", Wiz.loginArg.Value ? 1 : 0)
    keys := RegExReplace(Trim(Wiz.keys.Value), "\s+", "")
    W("Broadcast", "Keys", keys != "" ? keys : "1,2,3,4,5,6,7,8,9,0,-,=")
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
    TBAdd("bc",      "Broadcast",  ToggleBroadcast, "Broadcast ON")
    TBAdd("mirror",  "Mirror",     ToggleMirror, "Mirror ON")
    TBAdd("vfx",     "Views",      ToggleVFX, "Views ON")
    TBAdd("audio",   "Sound: All", ToggleAudio, "Sound: Active")
    TBAdd("newview", "New View",   CreateView)
    TBAdd("arrange", "Arrange",    ManualArrange)
    TBAdd("layout",  "Layout",     ToggleLayout)
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
              , ["Arrange", "^!g", "Arrange / re-sync"], ["ToggleLayout", "^!s", "Next layout"]
              , ["LaunchAll", "^!l", "Launch All"], ["Accounts", "^!a", "Slots (names & usernames)"]
              , ["RestoreBorders", "^!u", "Restore borders"], ["ControlPanel", "^!h", "Control panel"]
              , ["ToggleToolbar", "^!k", "Show/hide this toolbar"], ["Pause", "^!p", "Pause hotkeys"]
              , ["ToggleAudio", "^!o", "Sound: active client only / all"]
              , ["SetupWizard", "^!w", "Setup Wizard"]
              , ["ReloadConfig", "^!r", "Reload config"], ["Quit", "^!q", "Quit"]]
        t .= Nice(H(row[1], row[2])) "`t" row[3] "`n"
    t .= Nice(H("MouseBroadcast", "XButton1")) "`tOne mirrored click"
    MsgBox(t "`n`n" APP " " APP_VERSION, APP " - Hotkeys", "Iconi")
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
        try SB.SetText("  " msg)
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
    ; 4 columns of buttons, each 150 wide with 8 between -> 624 wide
    LV := Panel.AddListView("xm w624 r8 -Multi", ["Slot", "Character", "Account", "Resolution", "Status", "Window"])
    LV.OnEvent("DoubleClick", PanelDoubleClick)
    LV.OnEvent("ItemSelect", PanelSelect)
    ; edit the selected slot's character name and account name right here
    PESlot := Panel.AddText("xm y+10 w56 h28 0x200", "Slot 1:")
    Panel.AddText("x+4 yp w74 h28 0x200", "Character")
    PEName := Panel.AddEdit("x+4 yp w150 h28")
    Panel.AddText("x+12 yp w100 h28 0x200", "Account name")
    PEUser := Panel.AddEdit("x+4 yp w150 h28")
    Panel.AddButton("x+10 yp w66 h28 Default", "Save").OnEvent("Click", PanelSave)
    Panel.AddText("xm+60 y+6 w74 h28 0x200", "Resolution")
    PERes := Panel.AddDropDownList("x+4 yp w150", ResolutionChoices())
    PERes.OnEvent("Change", PanelResChange)
    Panel.AddText("x+12 yp w300 h28 0x200 cGray", "game resolution / window size of this slot")
    PEInfo := Panel.AddText("xm y+6 w624 cGray", "Click a slot above, set its character, account name and resolution, then Save. Launch All pre-fills the account name at the EverQuest login screen.")
    ; buttons: fixed height so a long label can never wrap into the next row
    bw := "w150 h32"
    Panel.AddButton("xm y+12 " bw " Section", "Launch All").OnEvent("Click", LaunchAll)
    Panel.AddButton("x+8 yp " bw, "Arrange").OnEvent("Click", ManualArrange)
    Panel.AddButton("x+8 yp " bw, "Save Layout...").OnEvent("Click", SaveLayout)
    Panel.AddButton("x+8 yp " bw, "Mirror On/Off").OnEvent("Click", ToggleMirror)
    Panel.AddButton("xs y+8 " bw, "Broadcast On/Off").OnEvent("Click", ToggleBroadcast)
    Panel.AddButton("x+8 yp " bw, "Video FX On/Off").OnEvent("Click", ToggleVFX)
    Panel.AddButton("x+8 yp " bw, "Edit Config").OnEvent("Click", EditConfig)
    Panel.AddButton("x+8 yp " bw, "Reload Config").OnEvent("Click", (*) => Reload())
    Panel.AddButton("xs y+8 " bw, "Show/Hide Toolbar").OnEvent("Click", ToggleToolbar)
    Panel.AddButton("x+8 yp w150 h32", "Characters...").OnEvent("Click", ShowAccounts)
    Panel.AddButton("x+8 yp w150 h32", "Setup Wizard...").OnEvent("Click", ShowWizard)
    Panel.AddButton("x+8 yp w150 h32", "Diagnostics...").OnEvent("Click", Diagnostics)
    ; layout and slot count on their own row
    Panel.AddText("xs y+14 w60 h28 0x200", "Layout:")
    LayoutDDL := Panel.AddDropDownList("x+4 yp w250", LayoutNames())
    try LayoutDDL.Text := Layout
    LayoutDDL.OnEvent("Change", LayoutChanged)
    Panel.AddText("x+20 yp w120 h28 0x200", "Number of slots:")
    ddl := Panel.AddDropDownList("x+4 yp w56 Choose" MAX_SLOTS, ["1", "2", "3", "4", "5", "6", "7", "8"])
    ddl.OnEvent("Change", SetSlotCount)
    Panel.AddButton("xs y+10 w150 h32", "Check for Updates").OnEvent("Click", (*) => CheckForUpdates(false))
    Panel.AddText("x+10 yp w464 h32 0x200 cGray", "Version " APP_VERSION ".  Double-click a slot to switch to it. Changing the number of slots saves and reloads.")
    SB := Panel.AddStatusBar()
    Panel.OnEvent("Close", (*) => Panel.Hide())
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
    SB.SetText(Format("  Layout: {}    Broadcast: {}    Mirror: {}    Video FX: {}    Clients: {}"
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
;  EQ Boxer Pro configuration
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
; Open the control panel when EQ Boxer starts (1/0)
ShowPanelOnStart=1
; 1 = clients fill their whole slot (they open slightly smaller if needed and
; are widened after start-up). 0 = keep a small margin on very wide slots
FillSlots=1
; Write the next free slot's position into eqclient.ini before each client
; starts, so EverQuest opens in its slot and the mouse lines up (1/0)
PrepareIni=1
; Run EQ Boxer as administrator (needed when EverQuest runs as admin) (1/0)
RunAsAdmin=1

[Characters]
; Slot=Name. Names are labels for window titles. Launch All starts one
; client for every slot that has a name.
1=Tank
2=Healer
3=DPS1
4=DPS2

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
; Show "Mirrored ... to N client(s)" after each mirrored click (1/0)
ShowFeedback=1

[Update]
; GitHub repository updates come from (owner/name). Empty = built-in default
Repo=
; Check for a newer version when EQ Boxer Pro starts (1/0)
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
