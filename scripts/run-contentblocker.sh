#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
echo "Initializing/updating submodules..."
git submodule update --init --recursive

echo "Building content blocker extension..."
"$ROOT_DIR/scripts/prepare-ubol.sh"

if [[ ! -d "$ROOT_DIR/External/uBlock/dist/build/uBOLite.safari" ]]; then
  echo "Expected uBOLite.safari output was not found" >&2
  exit 1
fi

echo "Content blocker output: $ROOT_DIR/External/uBlock/dist/build/uBOLite.safari"
