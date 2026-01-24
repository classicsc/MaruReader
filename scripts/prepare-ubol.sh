#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UBLOCK_DIR="$ROOT_DIR/External/uBlock"
RULESETS_PATH="$UBLOCK_DIR/platform/mv3/rulesets.json"
REPLACEMENT_RULESETS_PATH="$ROOT_DIR/External/ublock-rulesets.json"

if [[ ! -d "$UBLOCK_DIR" ]]; then
  echo "uBlock submodule not found at $UBLOCK_DIR" >&2
  exit 1
fi

if [[ ! -f "$RULESETS_PATH" ]]; then
  echo "rulesets.json not found at $RULESETS_PATH" >&2
  exit 1
fi

if [[ ! -f "$REPLACEMENT_RULESETS_PATH" ]]; then
  echo "ublock-rulesets.json not found at $REPLACEMENT_RULESETS_PATH" >&2
  exit 1
fi

cp "$REPLACEMENT_RULESETS_PATH" "$RULESETS_PATH"

cd "$UBLOCK_DIR"
make mv3-safari
