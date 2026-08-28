#!/usr/bin/env bash
# Windowed run of the six-beat screenshot route (scripts/screenshot_route.gd)
# -- must NOT run under --headless, see that script's own doc comment for
# why (headless never renders a frame to capture). Copies the resulting
# PNGs out of user:// into build/shots/ so they land somewhere findable in
# the repo tree (build/ itself is gitignored, same as export.sh's
# build/web/ -- this just gives every run a stable, known local path).
# Usage: tools/shots.sh [--ui]   (--ui keeps the HUD/dialogue on screen;
# default hides it for clean world frames)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_ARGS=(--path . --script res://scripts/screenshot_route.gd --resolution 1280x720)
if [ "${1:-}" == "--ui" ]; then
  GODOT_ARGS+=(-- --ui)
fi

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

# set +e / set -e around just this line: pipefail would otherwise abort
# the script the instant godot exits non-zero, before the SHOTS_DIR-parsing
# and copy step below gets a chance to run -- and a broken/black-frame run
# is exactly the case where seeing what *was* produced matters most.
set +e
./tools/godot.sh "${GODOT_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
STATUS=${PIPESTATUS[0]}
set -e

# screenshot_route.gd prints "SHOTS_DIR: <globalized user:// path>" as its
# last line on both success and failure -- parsed out here rather than
# hardcoding user://'s real OS path, which differs by platform and depends
# on project.godot's application/config/name.
SHOTS_SRC="$(sed -n 's/^SHOTS_DIR: //p' "$LOG_FILE" | tail -1)"
if [ -z "$SHOTS_SRC" ]; then
  echo "shots.sh: could not find a SHOTS_DIR line in screenshot_route.gd's output -- nothing to copy." >&2
  exit 1
fi

DEST="build/shots"
mkdir -p "$DEST"
rm -f "$DEST"/*.png
cp "$SHOTS_SRC"/*.png "$DEST/" 2>/dev/null || {
  echo "shots.sh: no PNGs found in $SHOTS_SRC to copy." >&2
  exit 1
}

echo "shots.sh: copied shots to $(pwd)/$DEST"
ls -la "$DEST"

if [ "$STATUS" -ne 0 ]; then
  echo "shots.sh: screenshot_route.gd exited $STATUS -- see output above before trusting these frames." >&2
  exit "$STATUS"
fi
exit "$STATUS"
