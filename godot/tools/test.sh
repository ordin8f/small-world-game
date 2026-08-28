#!/usr/bin/env bash
# Runs the gdUnit4 test suite headlessly (unit + play tests under godot/tests/).
set -euo pipefail
cd "$(dirname "$0")/.."
./tools/godot.sh --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
