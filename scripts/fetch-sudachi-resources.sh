#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/build/sudachi/v20260116-full}"

DICT_VERSION="20260116"
DICT_TAG="v20260116"
DICT_ARCHIVE_NAME="sudachi-dictionary-${DICT_VERSION}-full.zip"
DICT_DOWNLOAD_URL="https://github.com/WorksApplications/SudachiDict/releases/download/${DICT_TAG}/${DICT_ARCHIVE_NAME}"
SUDACHI_RS_REVISION="4ff4bbc3b410f88ce93a3582cd94eb168f855007"
SUPPORT_FILE_BASE_URL="https://raw.githubusercontent.com/WorksApplications/sudachi.rs/${SUDACHI_RS_REVISION}/resources"
DOWNLOAD_DIR="$ROOT_DIR/build/downloads"
ARCHIVE_PATH="$DOWNLOAD_DIR/$DICT_ARCHIVE_NAME"
TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$DOWNLOAD_DIR" "$OUTPUT_DIR"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Downloading pinned SudachiDict Full archive..."
  curl --fail --location --output "$ARCHIVE_PATH" "$DICT_DOWNLOAD_URL"
else
  echo "Using cached SudachiDict archive at $ARCHIVE_PATH"
fi

rm -rf "$TEMP_DIR/extracted"
mkdir -p "$TEMP_DIR/extracted"
unzip -j "$ARCHIVE_PATH" -d "$TEMP_DIR/extracted" >/dev/null

cp "$TEMP_DIR/extracted/system_full.dic" "$OUTPUT_DIR/system_full.dic"

for support_file in char.def rewrite.def sudachi.json unk.def; do
  curl --fail --location --output "$OUTPUT_DIR/$support_file" "$SUPPORT_FILE_BASE_URL/$support_file"
done

required_files=(
  "char.def"
  "rewrite.def"
  "sudachi.json"
  "system_full.dic"
  "unk.def"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$OUTPUT_DIR/$required_file" ]]; then
    echo "error: staged Sudachi resource directory is missing $required_file" >&2
    exit 1
  fi
done

echo "Sudachi resources staged at $OUTPUT_DIR"
