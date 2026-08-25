#!/usr/bin/env bash
# Resolves the Godot 4.7 binary: $GODOT_BIN if set, else `godot4`/`godot` on PATH.
set -euo pipefail

if [ -n "${GODOT_BIN:-}" ] && [ -x "${GODOT_BIN}" ]; then
  exec "${GODOT_BIN}" "$@"
fi

for candidate in godot4 godot; do
  if command -v "$candidate" >/dev/null 2>&1; then
    exec "$candidate" "$@"
  fi
done

echo "godot.sh: no Godot 4.7 binary found. Set GODOT_BIN=/path/to/godot or add godot/godot4 to PATH." >&2
exit 1
