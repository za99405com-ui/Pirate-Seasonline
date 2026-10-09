#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.3"
GODOT_RELEASE="4.3-stable"
GODOT_BIN="./Godot_v${GODOT_RELEASE}_linux.x86_64"

curl -L --fail --silent --show-error -o "Godot_v${GODOT_RELEASE}_linux.x86_64.zip" "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
unzip -q "Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
chmod +x "$GODOT_BIN"

curl -L --fail --silent --show-error -o "Godot_v${GODOT_RELEASE}_export_templates.tpz" "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"
mkdir -p "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
unzip -q "Godot_v${GODOT_RELEASE}_export_templates.tpz"
mv templates/* "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/"

sed -i 's/renderer\/rendering_method="mobile"/renderer\/rendering_method="gl_compatibility"/' project.godot

"$GODOT_BIN" --headless --path . --editor --quit
mkdir -p build/web
"$GODOT_BIN" --headless --path . --export-release "Web Preview" build/web/index.html
python3 tools/cache_bust_web.py build/web "${VERCEL_GIT_COMMIT_SHA:-vercel}"
touch build/web/.nojekyll
