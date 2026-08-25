#!/usr/bin/env bash
# Headless web export. Output lands in godot/build/web/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
./tools/godot.sh --headless --path . --export-release "Web" build/web/index.html

for f in index.html index.js index.wasm index.pck index.png; do
  if [ ! -s "build/web/$f" ]; then
    echo "export.sh: expected output build/web/$f is missing or empty" >&2
    exit 1
  fi
done
echo "export.sh: all expected output files present."
