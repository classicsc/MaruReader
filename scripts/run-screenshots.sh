#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MaruReader.xcodeproj"
SCHEME_NAME="MaruReader"
TEST_PLAN_NAME="MaruReaderUITests"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData/Screenshots"
SCREENSHOT_ROOT="$ROOT_DIR/build/screenshots"
RESULTS_DIR="$SCREENSHOT_ROOT/xcresult"

# All simulators to capture screenshots on.
# Copy/paste device type names from Xcode's Devices and Simulators window
# or from `xcrun simctl list devicetypes`.
simulators=(
  "iPhone 17 Pro Max"
  "iPhone 17"
  "iPad Air 13-inch (M3)"
  "iPad Air 11-inch (M3)"
)

# All appearances to capture screenshots in.
# Supported values are "light" and "dark".
appearances=(
  "light"
  "dark"
)

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required but not found in PATH" >&2
    exit 1
  fi
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

    rm -rf "$result_bundle_path" "$output_dir"
    mkdir -p "$output_dir"

    "$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "screenshots-${result_key}" \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME_NAME" \
      -destination "$destination" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -resultBundlePath "$result_bundle_path" \
      -testPlan "$TEST_PLAN_NAME" \
      test

    xcparse screenshots "$result_bundle_path" "$output_dir"
    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  done
done

echo "Screenshots exported to $SCREENSHOT_ROOT"
