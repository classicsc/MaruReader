#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_PATH="$ROOT_DIR/build/downloads/sudachi-tokenizer-dictionary.zip"
STARTER_DIR="$ROOT_DIR/build/StarterDictionary"
TOKENIZER_DIR="$STARTER_DIR/TokenizerDictionary"

"$ROOT_DIR/scripts/download-tokenizer-dictionary-package.sh" "$DOWNLOAD_PATH"

rm -rf "$TOKENIZER_DIR"
mkdir -p "$TOKENIZER_DIR"
unzip -q -o "$DOWNLOAD_PATH" -d "$TOKENIZER_DIR"

required_files=(
  "index.json"
  "char.def"
  "rewrite.def"
  "sudachi.json"
  "system_full.dic"
  "unk.def"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$TOKENIZER_DIR/$required_file" ]]; then
    echo "error: staged tokenizer dictionary is missing $required_file" >&2
    exit 1
  fi
done

echo "Staged tokenizer dictionary at $TOKENIZER_DIR"
