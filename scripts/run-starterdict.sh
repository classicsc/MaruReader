#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/build/logs"
DOWNLOAD_DIR="$ROOT_DIR/build/downloads"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData/DictionarySeeder"
STARTER_OUTPUT_DIR="$ROOT_DIR/build/StarterDictionary"
MANIFEST_PATH="$ROOT_DIR/starterdict-manifest.json"
ASSET_OUTPUT_PATH="$ROOT_DIR/build/starterdict.aar"

JITENDEX_URL="https://github.com/stephenmk/stephenmk.github.io/releases/latest/download/jitendex-yomitan.zip"
KANJI_ALIVE_URL="https://github.com/classicsc/kanji-alive-indexer/releases/latest/download/kanji-alive-mp3-indexed.zip"
BCCWJ_URL="https://github.com/Kuuuube/yomitan-dictionaries/releases/download/yomitan-permalink/BCCWJ_SUW_LUW_combined.zip"
WADOKU_URL="https://github.com/classicsc/wadoku-pitch-dictionary-for-yomitan/releases/latest/download/wadoku-pitch.zip"
JITENDEX_ZIP_PATH="$DOWNLOAD_DIR/jitendex-yomitan.zip"
KANJI_ALIVE_ZIP_PATH="$DOWNLOAD_DIR/kanji-alive-mp3-indexed.zip"
BCCWJ_ZIP_PATH="$DOWNLOAD_DIR/BCCWJ_SUW_LUW_combined.zip"
WADOKU_ZIP_PATH="$DOWNLOAD_DIR/wadoku-pitch.zip"
SEEDER_BINARY_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/DictionarySeeder"

mkdir -p "$LOG_DIR" "$DOWNLOAD_DIR"

echo "Downloading starter dictionary archives..."
curl --fail --location --output "$JITENDEX_ZIP_PATH" "$JITENDEX_URL"
curl --fail --location --output "$KANJI_ALIVE_ZIP_PATH" "$KANJI_ALIVE_URL"
curl --fail --location --output "$BCCWJ_ZIP_PATH" "$BCCWJ_URL"
curl --fail --location --output "$WADOKU_ZIP_PATH" "$WADOKU_URL"

echo "Building DictionarySeeder..."
"$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "build-dictionaryseeder-debug" \
  -project "$ROOT_DIR/MaruReader.xcodeproj" \
  -scheme DictionarySeeder \
  -destination generic/platform=macOS \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -x "$SEEDER_BINARY_PATH" ]]; then
  echo "DictionarySeeder binary not found at $SEEDER_BINARY_PATH" >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
seed_log_path="$LOG_DIR/${timestamp}-starterdict-seed.log"
latest_seed_log_path="$LOG_DIR/latest-starterdict-seed.log"

echo "Seeding starter dictionary output to $STARTER_OUTPUT_DIR..."
rm -rf "$STARTER_OUTPUT_DIR"
set +e
"$SEEDER_BINARY_PATH" "$STARTER_OUTPUT_DIR" "$JITENDEX_ZIP_PATH" "$BCCWJ_ZIP_PATH" "$WADOKU_ZIP_PATH" --audio "$KANJI_ALIVE_ZIP_PATH" 2>&1 | tee "$seed_log_path"
seed_exit_code=${PIPESTATUS[0]}
set -e

cp "$seed_log_path" "$latest_seed_log_path"

echo "Seeder log: $seed_log_path"
echo "Latest seeder log: $latest_seed_log_path"

ba_package_log_path="$LOG_DIR/${timestamp}-starterdict-archive.log"
latest_ba_package_log_path="$LOG_DIR/latest-starterdict-archive.log"

echo "Creating background asset archive..."
rm -f "$ASSET_OUTPUT_PATH"
xcrun ba-package "$MANIFEST_PATH" -o "$ASSET_OUTPUT_PATH" 2>&1 | tee "$ba_package_log_path"

echo "ba-package log: $ba_package_log_path"
echo "Latest ba-package log: $latest_ba_package_log_path"

exit "$seed_exit_code"
