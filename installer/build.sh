#!/bin/bash
# Builds dist/EQBoxerPro-Setup.exe, dist/EQBoxerPro-Setup.exe.sha256 and
# dist/EQBoxerPro-Portable.zip from the files in this repository.
# Needs: makensis (NSIS 3; set MAKENSIS to its path if it isn't on PATH),
#        python3 with the "markdown" package, curl, unzip, zip.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AHKVER=2.0.31
MAKENSIS="${MAKENSIS:-makensis}"
STAGE="$ROOT/installer/app"
DIST="$ROOT/dist"
CACHE="$ROOT/installer/.cache"
VER=$(grep -oP 'global APP_VERSION := "\K[0-9.]+' "$ROOT/EQBoxerPro.ahk")

rm -rf "$STAGE" && mkdir -p "$STAGE" "$DIST" "$CACHE"
cp "$ROOT/EQBoxerPro.ahk" "$ROOT/README.md" "$ROOT/LICENSES.txt" "$STAGE/"
cp "$ROOT/installer/EQBoxerPro.ico" "$STAGE/"
python3 "$ROOT/installer/make_html.py" "$STAGE/README.md" "$STAGE/README.html"

# Unmodified official AutoHotkey v2 release (runtime + AutoHotkey Dash)
ZIP="$CACHE/AutoHotkey_$AHKVER.zip"
[ -f "$ZIP" ] || curl -fsSL -o "$ZIP" "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AHKVER/AutoHotkey_$AHKVER.zip"
mkdir -p "$STAGE/AutoHotkey" && unzip -q -o "$ZIP" -d "$STAGE/AutoHotkey"

(cd "$ROOT/installer" && "$MAKENSIS" -V2 -DAPPVER="$VER" -DOUTFILE="$DIST/EQBoxerPro-Setup.exe" installer.nsi)
(cd "$DIST" && sha256sum EQBoxerPro-Setup.exe > EQBoxerPro-Setup.exe.sha256)

rm -rf "$DIST/portable" "$DIST/EQBoxerPro-Portable.zip"
cp -r "$STAGE" "$DIST/portable"
printf '@echo off\r\nstart "" "%%~dp0AutoHotkey\\AutoHotkey64.exe" "%%~dp0EQBoxerPro.ahk"\r\n' > "$DIST/portable/Start EQ Boxer Pro.cmd"
(cd "$DIST/portable" && zip -q -r ../EQBoxerPro-Portable.zip .)
rm -rf "$DIST/portable" "$STAGE"
echo "Built EQ Boxer Pro $VER:"; cat "$DIST/EQBoxerPro-Setup.exe.sha256"
