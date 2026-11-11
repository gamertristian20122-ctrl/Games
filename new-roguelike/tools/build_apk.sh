#!/usr/bin/env bash
# build_apk.sh: makes the signed Android APK in build/.
#   ./tools/build_apk.sh
# Needs: godot 4.7.2 + Android export templates, the Android SDK, JDK 17, and the signing key.
# The signing key is NOT in this repo (the repo is PRIVATE, but a signing key still never goes in git). It is read from these environment
# variables, or from /root/keys/game.keystore with the values below when they are not set:
#   KEYSTORE=/path/to/game.keystore   KEY_ALIAS=game   KEY_PASS=...
# Every build must be signed with the SAME key, or phones refuse to install it over the old one.
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
KEYSTORE="${KEYSTORE:-/root/keys/game.keystore}"
KEY_ALIAS="${KEY_ALIAS:-game}"
KEY_PASS="${KEY_PASS:-}"
if [ ! -f "$KEYSTORE" ] || [ -z "$KEY_PASS" ]; then
	echo "No signing key. Set KEYSTORE, KEY_ALIAS and KEY_PASS (see the comment at the top of this file)." >&2
	exit 1
fi
VERSION="$(grep -E '^config/version=' project.godot | cut -d'"' -f2)"
NAME="$(grep -E '^package/name=' export_presets.cfg | cut -d'"' -f2 | tr -cd 'A-Za-z0-9')"
mkdir -p build
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEY_PASS"
OUT="build/${NAME}_v${VERSION}.apk"
"$GODOT" --headless --path . --export-release "Android" "$OUT" 2>&1 | grep -vE "JAVA_TOOL_OPTIONS|^$|ADDING:|cannot connect to daemon" | tail -n 8
ls -la "$OUT"
