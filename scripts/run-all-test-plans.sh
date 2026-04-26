#!/usr/bin/env bash
set -euo pipefail

destination_input="${1:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plans=(
  MaruReaderTests
  MaruReaderCoreTests
  MaruDictionaryManagementTests
  MaruMangaTests
  MaruAnkiTests
  MaruWebTests
  MaruMarkTests
  MaruTextAnalysisTests
)

for plan in "${plans[@]}"; do
  "$ROOT_DIR/scripts/run-test-plan.sh" "$plan" "$destination_input"
done
