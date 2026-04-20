#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MaruReader.xcodeproj"
SCHEME_NAME="MaruReader"
TEST_PLAN_NAME="MaruReaderUITests"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData/Screenshots"
SCREENSHOT_ROOT="$ROOT_DIR/build/screenshots"
RESULTS_DIR="$SCREENSHOT_ROOT/xcresult"
SCREENSHOT_EXPORT_STEMS=(
  "01-BookDictionary"
  "02-MangaDictionary"
  "03-MangaDictionary-Regions"
  "04-WebDictionary"
  "05-AnkiSettings"
  "06-DictionarySettings"
)

# All simulators to capture screenshots on.
# Copy/paste device type names from Xcode's Devices and Simulators window
# or from `xcrun simctl list devicetypes`.
simulators=(
  "iPhone 17 Pro Max"
  "iPad Air 11-inch (M3)"
)

# All appearances to capture screenshots in.
# Supported values are "light" and "dark".
appearances=(
  "light"
)

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required but not found in PATH" >&2
    exit 1
  fi
}

require_screenshot_stem() {
  local filename="$1"
  local stem

  stem="$(
    printf '%s\n' "$filename" \
      | sed -nE 's/.* - [0-9]+-([0-9]{2}-[A-Za-z0-9-]+)_0_.*/\1/p'
  )"

  if [[ -n "$stem" ]]; then
    printf '%s\n' "$stem"
    return 0
  fi

  echo "Unable to determine screenshot stem from: $filename" >&2
  exit 1
}

normalize_locale_dir() {
  local locale_dir="$1"

  if [[ "$locale_dir" =~ ^([a-z]{2})\ \(([A-Z]{2})\)$ ]]; then
    printf '%s-%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  echo "Unsupported locale directory from xcparse output: $locale_dir" >&2
  exit 1
}

normalize_exported_screenshots() {
  local extracted_dir="$1"
  local output_dir="$2"
  local locale_output_dir
  local locale_dir
  local normalized_locale
  local screenshot_file
  local screenshot_stem
  local expected_stem
  local expected_path

  while IFS= read -r screenshot_file; do
    locale_dir="$(basename "$(dirname "$screenshot_file")")"
    normalized_locale="$(normalize_locale_dir "$locale_dir")"
    locale_output_dir="$output_dir/$normalized_locale"
    mkdir -p "$locale_output_dir"

    screenshot_stem="$(require_screenshot_stem "$(basename "$screenshot_file")")"
    cp "$screenshot_file" "$locale_output_dir/$screenshot_stem.png"
  done < <(find "$extracted_dir" -type f -name '*.png' | sort)

  for normalized_locale in "en-US" "ja-JP"; do
    locale_output_dir="$output_dir/$normalized_locale"
    if [[ ! -d "$locale_output_dir" ]]; then
      echo "Expected locale output was not created: $locale_output_dir" >&2
      exit 1
    fi

    for expected_stem in "${SCREENSHOT_EXPORT_STEMS[@]}"; do
      expected_path="$locale_output_dir/$expected_stem.png"
      if [[ ! -f "$expected_path" ]]; then
        echo "Missing normalized screenshot export: $expected_path" >&2
        exit 1
      fi
    done
  done
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

resolve_ios_runtime() {
  local runtime

  runtime="$(xcrun simctl list runtimes available iOS | awk -F ' - ' '/^iOS / { runtime = $NF } END { print runtime }')"

  if [[ -z "$runtime" ]]; then
    echo "No available iOS simulator runtime found." >&2
    exit 1
  fi

  printf '%s\n' "$runtime"
}

assert_device_type_exists() {
  local device_type="$1"

  if ! xcrun simctl list devicetypes | grep -Fq "$device_type ("; then
    echo "Simulator device type not found: $device_type" >&2
    exit 1
  fi
}

created_simulators=()

cleanup() {
  local simulator_udid

  for simulator_udid in "${created_simulators[@]}"; do
    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
  done
}

trap cleanup EXIT

require_command xcodebuild
require_command xcbeautify
require_command xcparse
require_command xcrun

runtime_id="$(resolve_ios_runtime)"

rm -rf "$SCREENSHOT_ROOT"
mkdir -p "$RESULTS_DIR" "$DERIVED_DATA_PATH"

for simulator in "${simulators[@]}"; do
  assert_device_type_exists "$simulator"

  simulator_slug="$(slugify "$simulator")"
  simulator_name="MaruReader Screenshots - ${simulator} - $$"
  simulator_udid="$(xcrun simctl create "$simulator_name" "$simulator" "$runtime_id")"
  created_simulators+=("$simulator_udid")

  for appearance in "${appearances[@]}"; do
    destination="platform=iOS Simulator,id=$simulator_udid"
    result_key="${simulator_slug}-${appearance}"
    result_bundle_path="$RESULTS_DIR/$result_key.xcresult"
    output_dir="$SCREENSHOT_ROOT/$simulator_slug/$appearance"
    extracted_dir="$SCREENSHOT_ROOT/.extracted/$result_key"

    echo "Running screenshots for $simulator ($appearance)"

    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$simulator_udid"
    xcrun simctl boot "$simulator_udid"
    xcrun simctl bootstatus "$simulator_udid" -b
    xcrun simctl spawn "$simulator_udid" defaults write \
      com.apple.keyboard.preferences \
      DidShowContinuousPathIntroduction \
      -bool true
    xcrun simctl ui "$simulator_udid" appearance "$appearance"
    xcrun simctl status_bar "$simulator_udid" override \
      --time 9:41 \
      --dataNetwork wifi \
      --wifiMode active \
      --wifiBars 3 \
      --batteryState charged \
      --batteryLevel 100

    rm -rf "$result_bundle_path" "$output_dir" "$extracted_dir"
    mkdir -p "$output_dir" "$extracted_dir"

    "$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "screenshots-${result_key}" \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME_NAME" \
      -destination "$destination" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -resultBundlePath "$result_bundle_path" \
      -testPlan "$TEST_PLAN_NAME" \
      test

    xcparse screenshots --language --region --test-plan-config "$result_bundle_path" "$extracted_dir"
    normalize_exported_screenshots "$extracted_dir" "$output_dir"
    rm -rf "$extracted_dir"
    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  done
done

echo "Screenshots exported to $SCREENSHOT_ROOT"
