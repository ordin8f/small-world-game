#!/usr/bin/env bash
# The one command that must be green before any commit: import -> test -> export.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== import =="
./tools/import.sh
echo "== test =="
./tools/test.sh
echo "== export =="
./tools/export.sh
echo "verify.sh: all green."
