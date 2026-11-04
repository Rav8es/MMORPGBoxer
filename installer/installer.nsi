; =====================================================================
;  MMORPG Boxer - Windows installer (NSIS, Modern UI 2)
;  Per-user install, no administrator rights needed to install.
; =====================================================================
Unicode true
!define APPNAME     "MMORPG Boxer"
!ifndef APPVER
  !define APPVER    "0.0.0"
!endif
!ifndef OUTFILE
  !define OUTFILE   "MMORPGBoxer-Setup.exe"
!endif
!define AHKVER      "2.0.31"
!define REGKEY      "Software\MMORPGBoxer"
!define UNINSTKEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\MMORPGBoxer"
; the same app before it was renamed (EQ Boxer Pro 1.2.2 and older)
!define OLDNAME     "EQ Boxer Pro"
!define OLDREGKEY   "Software\EQBoxerPro"
!define OLDUNINST   "Software\Microsoft\Windows\CurrentVersion\Uninstall\EQBoxerPro"
!define RUNKEY      "Software\Microsoft\Windows\CurrentVersion\Run"
!define AHKEXE      "$INSTDIR\AutoHotkey\AutoHotkey64.exe"
!define SCRIPT      "$INSTDIR\MMORPGBoxer.ahk"

Name "${APPNAME}"
Caption "${APPNAME} ${APPVER} Setup"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\MMORPG Boxer"
InstallDirRegKey HKCU "${REGKEY}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${APPNAME} ${APPVER}"

VIProductVersion "${APPVER}.0"
VIAddVersionKey "ProductName"     "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion"     "${APPVER}"
VIAddVersionKey "ProductVersion"  "${APPVER}"
VIAddVersionKey "LegalCopyright"  "MMORPG Boxer. Includes AutoHotkey ${AHKVER} (GPLv2)."

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"

; /UPDATE = started by MMORPG Boxer's updater (together with /S): keep the
; user's choices, don't re-run AutoHotkey's installer, restart the app after
Var IsUpdate
Var OldDir      ; folder of an EQ Boxer Pro install to move over ("" = none)

!define MUI_ICON   "app\MMORPGBoxer.ico"
!define MUI_UNICON "app\MMORPGBoxer.ico"
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME} ${APPVER}"
!define MUI_WELCOMEPAGE_TEXT "MMORPG Boxer helps you play several EverQuest clients at once: window layouts, slot switching, key and mouse broadcasting, clickable views and more.$\r$\n$\r$\nAutoHotkey v2 (${AHKVER}) is included, so nothing else needs to be installed.$\r$\n$\r$\nNo administrator rights are needed to install. When MMORPG Boxer runs, Windows will ask for administrator permission, because EverQuest runs as administrator.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME

!define MUI_LICENSEPAGE_TEXT_TOP "Third-party software included with MMORPG Boxer:"
!define MUI_LICENSEPAGE_BUTTON "&Next >"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "Click Next to continue."
!insertmacro MUI_PAGE_LICENSE "app\LICENSES.txt"

!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Start MMORPG Boxer (opens the Setup Wizard)"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.html"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Open the MMORPG Boxer guide"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------------
; MMORPG Boxer must not be running while its files are replaced/removed.
; AutoHotkey's hidden main window is titled "<script path> - AutoHotkey v<ver>".
!macro WaitForAppClosed
  StrCpy $2 0
  ${Do}
    FindWindow $0 "AutoHotkey" "$INSTDIR\MMORPGBoxer.ahk - AutoHotkey v${AHKVER}"
    ${If} $0 = 0
      ${Break}
    ${EndIf}
    ${If} ${Silent}
      ; the updater closes the app itself - give it up to 30 seconds
      IntOp $2 $2 + 1
      ${If} $2 > 60
        Abort
      ${EndIf}
      Sleep 500
    ${Else}
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "MMORPG Boxer is running.$\r$\n$\r$\nPlease exit it first (right-click its tray icon, then Exit), then click Retry." IDRETRY +2
      Abort
    ${EndIf}
  ${Loop}
!macroend

; The old EQ Boxer Pro must be closed too before its folder is tidied up.
!macro WaitForOldAppClosed
  StrCpy $2 0
  ${Do}
    FindWindow $0 "AutoHotkey" "$OldDir\EQBoxerPro.ahk - AutoHotkey v${AHKVER}"
    ${If} $0 = 0
      ${Break}
    ${EndIf}
    ${If} ${Silent}
      IntOp $2 $2 + 1
      ${If} $2 > 60
        Abort
      ${EndIf}
      Sleep 500
    ${Else}
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${OLDNAME} (the old name of ${APPNAME}) is running.$\r$\n$\r$\nPlease exit it first (right-click its tray icon, then Exit), then click Retry." IDRETRY +2
      Abort
    ${EndIf}
  ${Loop}
!macroend

Function LaunchApp
  Exec '"${AHKEXE}" "${SCRIPT}"'
FunctionEnd

; ---------------------------------------------------------------------
; Move an EQ Boxer Pro install over: its settings come along, the old
; files, shortcuts and uninstall entry are removed.
Section "-Move settings from EQ Boxer Pro" SecMigrate
  ${If} $OldDir == ""
    Return
  ${EndIf}
  !insertmacro WaitForOldAppClosed
  DetailPrint "Moving settings from ${OLDNAME} ($OldDir)..."
  CreateDirectory "$INSTDIR"
  ${IfNot} ${FileExists} "$INSTDIR\MMORPGBoxer.ini"
    CopyFiles /SILENT "$OldDir\EQBoxer.ini" "$INSTDIR\MMORPGBoxer.ini"
  ${EndIf}
  ${IfNot} ${FileExists} "$INSTDIR\MMORPGBoxer.log"
    CopyFiles /SILENT "$OldDir\EQBoxer.log" "$INSTDIR\MMORPGBoxer.log"
  ${EndIf}
  ${If} $OldDir != $INSTDIR
    Delete "$OldDir\EQBoxerPro.ahk"
    Delete "$OldDir\EQBoxerPro.ico"
    Delete "$OldDir\README.html"
    Delete "$OldDir\README.md"
    Delete "$OldDir\LICENSES.txt"
    Delete "$OldDir\EQBoxer.ini"
    Delete "$OldDir\EQBoxer.log"
    Delete "$OldDir\EQBoxer-diagnostics.txt"
    Delete "$OldDir\Uninstall.exe"
    RMDir /r "$OldDir\AutoHotkey"
    RMDir "$OldDir"
  ${Else}
    Delete "$OldDir\EQBoxerPro.ahk"
    Delete "$OldDir\EQBoxerPro.ico"
  ${EndIf}
  RMDir /r "$SMPROGRAMS\${OLDNAME}"
  Delete "$DESKTOP\${OLDNAME}.lnk"
  DeleteRegValue HKCU "${RUNKEY}" "${OLDNAME}"
  DeleteRegKey HKCU "${OLDUNINST}"
  DeleteRegKey HKCU "${OLDREGKEY}"
SectionEnd

Section "MMORPG Boxer (required)" SecApp
  SectionIn RO
  !insertmacro WaitForAppClosed
  SetOutPath "$INSTDIR"
  ; settings (MMORPGBoxer.ini) and the log are created by the app and are kept
  File "app\MMORPGBoxer.ahk"
  File "app\MMORPGBoxer.ico"
  File "app\README.html"
  File "app\README.md"
  File "app\LICENSES.txt"
  SetOutPath "$INSTDIR\AutoHotkey"
  File /r "app\AutoHotkey\*.*"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "${AHKEXE}" '"${SCRIPT}"' "$INSTDIR\MMORPGBoxer.ico" 0 SW_SHOWNORMAL "" "Multibox EverQuest"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME} Guide.lnk" "$INSTDIR\README.html"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME} Folder (settings and log).lnk" "$INSTDIR"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${REGKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${APPVER}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\MMORPGBoxer.ico"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "EstimatedSize" 5000
SectionEnd

Section "AutoHotkey v2 with AutoHotkey Dash" SecAHK
  ; Uses AutoHotkey's own installer (silent, for this Windows user):
  ; adds AutoHotkey Dash and the help to the Start Menu and .ahk file support.
  DetailPrint "Installing AutoHotkey v${AHKVER} with AutoHotkey Dash for this Windows user..."
  ExecWait '"${AHKEXE}" "$INSTDIR\AutoHotkey\UX\install.ahk" /silent /user' $0
  ${If} $0 <> 0
    DetailPrint "AutoHotkey's installer finished with code $0. MMORPG Boxer still works with its own copy."
  ${Else}
    DetailPrint "AutoHotkey with AutoHotkey Dash installed."
  ${EndIf}
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "${AHKEXE}" '"${SCRIPT}"' "$INSTDIR\MMORPGBoxer.ico" 0 SW_SHOWNORMAL "" "Multibox EverQuest"
SectionEnd

Section /o "Start MMORPG Boxer when Windows starts" SecStartup
  WriteRegStr HKCU "${RUNKEY}" "${APPNAME}" '"${AHKEXE}" "${SCRIPT}"'
SectionEnd

Section "-Restart after update"
  ${If} $IsUpdate == 1
    Call LaunchApp
  ${EndIf}
SectionEnd

Function .onInit
  StrCpy $IsUpdate 0
  ; an EQ Boxer Pro install to move over?
  ReadRegStr $OldDir HKCU "${OLDREGKEY}" "InstallDir"
  ${If} $OldDir == ""
    StrCpy $OldDir "$LOCALAPPDATA\Programs\${OLDNAME}"
  ${EndIf}
  ${IfNot} ${FileExists} "$OldDir\EQBoxerPro.ahk"
    StrCpy $OldDir ""
  ${EndIf}
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/UPDATE" $R1
  ${IfNot} ${Errors}
    StrCpy $IsUpdate 1
    !insertmacro UnselectSection ${SecAHK}
    ${IfNot} ${FileExists} "$DESKTOP\${APPNAME}.lnk"
    ${AndIfNot} ${FileExists} "$DESKTOP\${OLDNAME}.lnk"
      !insertmacro UnselectSection ${SecDesktop}
    ${EndIf}
  ${EndIf}
  ; keep "start with Windows" if the old install had it
  ${If} $OldDir != ""
    ReadRegStr $R2 HKCU "${RUNKEY}" "${OLDNAME}"
    ${If} $R2 != ""
      !insertmacro SelectSection ${SecStartup}
    ${EndIf}
  ${EndIf}
FunctionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "The app, its icon, the guide, and its own private copy of AutoHotkey v${AHKVER}."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAHK} "Also install AutoHotkey v${AHKVER} for your Windows user with AutoHotkey's own installer: adds AutoHotkey Dash and the AutoHotkey help to the Start Menu, and lets you run .ahk scripts. MMORPG Boxer works without this."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Put an MMORPG Boxer shortcut on the desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartup} "Start MMORPG Boxer when you sign in to Windows. Windows will ask for administrator permission each time."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------------
Section "Uninstall"
  !insertmacro WaitForAppClosed
  StrCpy $1 "keep"
  MessageBox MB_YESNO|MB_ICONQUESTION "Also delete your MMORPG Boxer settings (MMORPGBoxer.ini) and log?$\r$\n$\r$\nChoose No to keep them for a later reinstall." IDNO +2
  StrCpy $1 "delete"

  Delete "$INSTDIR\MMORPGBoxer.ahk"
  Delete "$INSTDIR\MMORPGBoxer.ico"
  Delete "$INSTDIR\README.html"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\LICENSES.txt"
  RMDir /r "$INSTDIR\AutoHotkey"
  ${If} $1 == "delete"
    Delete "$INSTDIR\MMORPGBoxer.ini"
    Delete "$INSTDIR\MMORPGBoxer.log"
    Delete "$INSTDIR\MMORPGBoxer-diagnostics.txt"
  ${EndIf}
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  RMDir /r "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegValue HKCU "${RUNKEY}" "${APPNAME}"
  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegKey HKCU "${REGKEY}"
SectionEnd
