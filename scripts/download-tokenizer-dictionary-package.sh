#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/build/downloads/sudachi-tokenizer-dictionary.zip}"
TOKENIZER_REPO="${TOKENIZER_REPO:-classicsc/sudachidict-for-marureader}"
TOKENIZER_ASSET_NAME="${TOKENIZER_ASSET_NAME:-sudachi-tokenizer-dictionary.zip}"
TOKENIZER_DOWNLOAD_URL="${TOKENIZER_DOWNLOAD_URL:-https://github.com/${TOKENIZER_REPO}/releases/latest/download/${TOKENIZER_ASSET_NAME}}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

if [[ -f "$OUTPUT_PATH" ]]; then
  echo "Using cached tokenizer dictionary package at $OUTPUT_PATH"
  exit 0
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && gh repo view "$TOKENIZER_REPO" >/dev/null 2>&1; then
  echo "Downloading tokenizer dictionary package from $TOKENIZER_REPO via gh..."
  gh release download --repo "$TOKENIZER_REPO" --pattern "$TOKENIZER_ASSET_NAME" --output "$OUTPUT_PATH" --clobber
else
  echo "Downloading tokenizer dictionary package from latest release..."
  curl --fail --location --output "$OUTPUT_PATH" "$TOKENIZER_DOWNLOAD_URL"
fi

if [[ ! -f "$OUTPUT_PATH" ]]; then
  echo "error: tokenizer dictionary package was not downloaded to $OUTPUT_PATH" >&2
  exit 1
fi
