#!/usr/bin/env bash
# Serves the exported web build locally so it can be played in a real browser.
# Usage: tools/serve.sh [port]   (default 8081)
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${1:-8081}"
if [ ! -f "build/web/index.html" ]; then
  echo "serve.sh: build/web/index.html not found — run tools/export.sh first." >&2
  exit 1
fi
echo "Serving godot/build/web on http://localhost:${PORT}/ (Ctrl+C to stop)"
python3 -m http.server "${PORT}" --directory build/web
