#!/usr/bin/env bash
# Esporta la versione web in build/web (serve Godot 4.5.1 con i template di esportazione).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/web
"$GODOT" --headless --import
"$GODOT" --headless --export-release "Web" build/web/index.html
touch build/web/.nojekyll
