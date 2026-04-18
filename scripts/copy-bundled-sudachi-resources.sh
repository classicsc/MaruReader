#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/build/sudachi/v20260116-full"
DEST_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR must be set by Xcode}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH must be set by Xcode}/SudachiResources"

if [[ ! -f "$SOURCE_DIR/system_full.dic" ]]; then
  "$ROOT_DIR/scripts/fetch-sudachi-resources.sh" "$SOURCE_DIR"
fi

required_files=(
  "char.def"
  "rewrite.def"
  "sudachi.json"
  "system_full.dic"
  "unk.def"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$SOURCE_DIR/$required_file" ]]; then
    echo "error: Sudachi resource directory is missing $required_file at $SOURCE_DIR" >&2
    exit 1
  fi
done

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

for required_file in "${required_files[@]}"; do
  cp "$SOURCE_DIR/$required_file" "$DEST_DIR/$required_file"
done
