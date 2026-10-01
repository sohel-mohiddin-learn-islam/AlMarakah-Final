#!/usr/bin/env bash
# Linux / GitHub Codespaces. Android users can use the Godot Android editor instead.
set -euo pipefail
VERSION=4.4.1
case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo 'Unsupported Linux CPU architecture'; exit 1 ;;
esac
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BASE="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
curl -fL --retry 3 "$BASE/Godot_v${VERSION}-stable_linux.${ARCH}.zip" -o "$TMP/godot.zip"
unzip -q "$TMP/godot.zip" -d "$TMP"
install -m 755 "$TMP/Godot_v${VERSION}-stable_linux.${ARCH}" "$BIN/godot"
if [[ "${1:-}" == '--templates' ]]; then
  curl -fL --retry 3 "$BASE/Godot_v${VERSION}-stable_export_templates.tpz" -o "$TMP/templates.zip"
  # Only Android and single-threaded Web are needed, not other large platforms.
  unzip -q "$TMP/templates.zip" 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/web_nothreads_debug.zip' 'templates/web_nothreads_release.zip' 'templates/version.txt' -d "$TMP"
  DEST="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  mkdir -p "$DEST"
  cp "$TMP"/templates/* "$DEST/"
fi
printf '\nGodot installed: %s/godot\n' "$BIN"
"$BIN/godot" --headless --version
