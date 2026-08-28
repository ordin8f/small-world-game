#!/usr/bin/env bash
# Headless (re)import of the Godot project. Exits 0 on success.
set -euo pipefail
cd "$(dirname "$0")/.."
./tools/godot.sh --headless --path . --import
