#!/bin/bash
# Builds dist/MMORPGBoxer-Setup.exe, dist/MMORPGBoxer-Setup.exe.sha256 and
# dist/MMORPGBoxer-Portable.zip from the files in this repository.
# Needs: makensis (NSIS 3; set MAKENSIS to its path if it isn't on PATH),
#        python3 with the "markdown" package, curl, unzip, zip.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AHKVER=2.0.31
MAKENSIS="${MAKENSIS:-makensis}"
STAGE="$ROOT/installer/app"
DIST="$ROOT/dist"
CACHE="$ROOT/installer/.cache"
VER=$(grep -oP 'global APP_VERSION := "\K[0-9.]+' "$ROOT/MMORPGBoxer.ahk")

rm -rf "$STAGE" && mkdir -p "$STAGE" "$DIST" "$CACHE"
cp "$ROOT/MMORPGBoxer.ahk" "$ROOT/README.md" "$ROOT/LICENSES.txt" "$STAGE/"
cp "$ROOT/installer/MMORPGBoxer.ico" "$STAGE/"
python3 "$ROOT/installer/lint_ahk.py" "$ROOT/MMORPGBoxer.ahk"
python3 "$ROOT/installer/make_html.py" "$STAGE/README.md" "$STAGE/README.html"

# Unmodified official AutoHotkey v2 release (runtime + AutoHotkey Dash)
ZIP="$CACHE/AutoHotkey_$AHKVER.zip"
[ -f "$ZIP" ] || curl -fsSL -o "$ZIP" "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AHKVER/AutoHotkey_$AHKVER.zip"
mkdir -p "$STAGE/AutoHotkey" && unzip -q -o "$ZIP" -d "$STAGE/AutoHotkey"

(cd "$ROOT/installer" && "$MAKENSIS" -V2 -DAPPVER="$VER" -DOUTFILE="$DIST/MMORPGBoxer-Setup.exe" installer.nsi)
(cd "$DIST" && sha256sum MMORPGBoxer-Setup.exe > MMORPGBoxer-Setup.exe.sha256)
# Same installer under the old name, so copies from before the rename
# (EQ Boxer Pro 1.2.2 and older) can still update themselves.
(cd "$DIST" && cp MMORPGBoxer-Setup.exe EQBoxerPro-Setup.exe && sha256sum EQBoxerPro-Setup.exe > EQBoxerPro-Setup.exe.sha256)

rm -rf "$DIST/portable" "$DIST/MMORPGBoxer-Portable.zip"
cp -r "$STAGE" "$DIST/portable"
printf '@echo off\r\nstart "" "%%~dp0AutoHotkey\\AutoHotkey64.exe" "%%~dp0MMORPGBoxer.ahk"\r\n' > "$DIST/portable/Start MMORPG Boxer.cmd"
(cd "$DIST/portable" && zip -q -r ../MMORPGBoxer-Portable.zip .)
rm -rf "$DIST/portable" "$STAGE"
echo "Built MMORPG Boxer $VER:"; cat "$DIST/MMORPGBoxer-Setup.exe.sha256"
