#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/External/uBlock/dist/build/uBOLite.safari"
ZIP_PATH="$ROOT_DIR/External/uBlock/dist/build/uBOLite.safari.zip"

cd "$ROOT_DIR"
echo "Initializing/updating submodules..."
git submodule update --init --recursive

echo "Building content blocker extension..."
"$ROOT_DIR/scripts/prepare-ubol.sh"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Expected uBOLite.safari output was not found" >&2
  exit 1
fi

echo "Creating ZIP archive..."
rm -f "$ZIP_PATH"
(
  cd "$SOURCE_DIR"
  /usr/bin/zip -q -r -X "$ZIP_PATH" .
)

echo "Content blocker output:"
echo "  Directory: $SOURCE_DIR"
echo "  ZIP: $ZIP_PATH"
