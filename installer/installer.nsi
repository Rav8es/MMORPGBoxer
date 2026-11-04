; =====================================================================
;  EQ Boxer Pro - Windows installer (NSIS, Modern UI 2)
;  Per-user install, no administrator rights needed to install.
; =====================================================================
Unicode true
!define APPNAME     "EQ Boxer Pro"
!ifndef APPVER
  !define APPVER    "0.0.0"
!endif
!ifndef OUTFILE
  !define OUTFILE   "EQBoxerPro-Setup.exe"
!endif
!define AHKVER      "2.0.31"
!define REGKEY      "Software\EQBoxerPro"
!define UNINSTKEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\EQBoxerPro"
!define RUNKEY      "Software\Microsoft\Windows\CurrentVersion\Run"
!define AHKEXE      "$INSTDIR\AutoHotkey\AutoHotkey64.exe"
!define SCRIPT      "$INSTDIR\EQBoxerPro.ahk"

Name "${APPNAME}"
Caption "${APPNAME} ${APPVER} Setup"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\EQ Boxer Pro"
InstallDirRegKey HKCU "${REGKEY}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${APPNAME} ${APPVER}"

VIProductVersion "${APPVER}.0"
VIAddVersionKey "ProductName"     "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion"     "${APPVER}"
VIAddVersionKey "ProductVersion"  "${APPVER}"
VIAddVersionKey "LegalCopyright"  "EQ Boxer Pro. Includes AutoHotkey ${AHKVER} (GPLv2)."

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"

; /UPDATE = started by EQ Boxer Pro's updater (together with /S): keep the
; user's choices, don't re-run AutoHotkey's installer, restart the app after
Var IsUpdate

!define MUI_ICON   "app\EQBoxerPro.ico"
!define MUI_UNICON "app\EQBoxerPro.ico"
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME} ${APPVER}"
!define MUI_WELCOMEPAGE_TEXT "EQ Boxer Pro helps you play several EverQuest clients at once: window layouts, slot switching, key and mouse broadcasting, clickable views and more.$\r$\n$\r$\nAutoHotkey v2 (${AHKVER}) is included, so nothing else needs to be installed.$\r$\n$\r$\nNo administrator rights are needed to install. When EQ Boxer Pro runs, Windows will ask for administrator permission, because EverQuest runs as administrator.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME

!define MUI_LICENSEPAGE_TEXT_TOP "Third-party software included with EQ Boxer Pro:"
!define MUI_LICENSEPAGE_BUTTON "&Next >"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "Click Next to continue."
!insertmacro MUI_PAGE_LICENSE "app\LICENSES.txt"

!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Start EQ Boxer Pro (opens the Setup Wizard)"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.html"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Open the EQ Boxer Pro guide"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------------
; EQ Boxer Pro must not be running while its files are replaced/removed.
; AutoHotkey's hidden main window is titled "<script path> - AutoHotkey v<ver>".
!macro WaitForAppClosed
  StrCpy $2 0
  ${Do}
    FindWindow $0 "AutoHotkey" "$INSTDIR\EQBoxerPro.ahk - AutoHotkey v${AHKVER}"
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
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "EQ Boxer Pro is running.$\r$\n$\r$\nPlease exit it first (right-click its tray icon, then Exit), then click Retry." IDRETRY +2
      Abort
    ${EndIf}
  ${Loop}
!macroend

Function LaunchApp
  Exec '"${AHKEXE}" "${SCRIPT}"'
FunctionEnd

; ---------------------------------------------------------------------
Section "EQ Boxer Pro (required)" SecApp
  SectionIn RO
  !insertmacro WaitForAppClosed
  SetOutPath "$INSTDIR"
  ; settings (EQBoxer.ini) and the log are created by the app and are kept
  File "app\EQBoxerPro.ahk"
  File "app\EQBoxerPro.ico"
  File "app\README.html"
  File "app\README.md"
  File "app\LICENSES.txt"
  SetOutPath "$INSTDIR\AutoHotkey"
  File /r "app\AutoHotkey\*.*"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "${AHKEXE}" '"${SCRIPT}"' "$INSTDIR\EQBoxerPro.ico" 0 SW_SHOWNORMAL "" "Multibox EverQuest"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME} Guide.lnk" "$INSTDIR\README.html"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME} Folder (settings and log).lnk" "$INSTDIR"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${REGKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${APPVER}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\EQBoxerPro.ico"
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
    DetailPrint "AutoHotkey's installer finished with code $0. EQ Boxer Pro still works with its own copy."
  ${Else}
    DetailPrint "AutoHotkey with AutoHotkey Dash installed."
  ${EndIf}
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "${AHKEXE}" '"${SCRIPT}"' "$INSTDIR\EQBoxerPro.ico" 0 SW_SHOWNORMAL "" "Multibox EverQuest"
SectionEnd

Section /o "Start EQ Boxer Pro when Windows starts" SecStartup
  WriteRegStr HKCU "${RUNKEY}" "${APPNAME}" '"${AHKEXE}" "${SCRIPT}"'
SectionEnd

Section "-Restart after update"
  ${If} $IsUpdate == 1
    Call LaunchApp
  ${EndIf}
SectionEnd

Function .onInit
  StrCpy $IsUpdate 0
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/UPDATE" $R1
  ${IfNot} ${Errors}
    StrCpy $IsUpdate 1
    !insertmacro UnselectSection ${SecAHK}
    ${IfNot} ${FileExists} "$DESKTOP\${APPNAME}.lnk"
      !insertmacro UnselectSection ${SecDesktop}
    ${EndIf}
  ${EndIf}
FunctionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "The app, its icon, the guide, and its own private copy of AutoHotkey v${AHKVER}."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAHK} "Also install AutoHotkey v${AHKVER} for your Windows user with AutoHotkey's own installer: adds AutoHotkey Dash and the AutoHotkey help to the Start Menu, and lets you run .ahk scripts. EQ Boxer Pro works without this."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Put an EQ Boxer Pro shortcut on the desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartup} "Start EQ Boxer Pro when you sign in to Windows. Windows will ask for administrator permission each time."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------------
Section "Uninstall"
  !insertmacro WaitForAppClosed
  StrCpy $1 "keep"
  MessageBox MB_YESNO|MB_ICONQUESTION "Also delete your EQ Boxer Pro settings (EQBoxer.ini) and log?$\r$\n$\r$\nChoose No to keep them for a later reinstall." IDNO +2
  StrCpy $1 "delete"

  Delete "$INSTDIR\EQBoxerPro.ahk"
  Delete "$INSTDIR\EQBoxerPro.ico"
  Delete "$INSTDIR\README.html"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\LICENSES.txt"
  RMDir /r "$INSTDIR\AutoHotkey"
  ${If} $1 == "delete"
    Delete "$INSTDIR\EQBoxer.ini"
    Delete "$INSTDIR\EQBoxer.log"
    Delete "$INSTDIR\EQBoxer-diagnostics.txt"
  ${EndIf}
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  RMDir /r "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegValue HKCU "${RUNKEY}" "${APPNAME}"
  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegKey HKCU "${REGKEY}"
SectionEnd
