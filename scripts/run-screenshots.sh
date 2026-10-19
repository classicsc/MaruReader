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
  "04-WebDictionary"
  "05-AnkiNoteEditor"
  "06-DictionarySettings"
)

# All simulators to capture screenshots on.
# Copy/paste device type names from Xcode's Devices and Simulators window
# or from `xcrun simctl list devicetypes`.
simulators=(
  "iPhone 17 Pro Max"
  "iPhone Duo"
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

# Copies the screenshot attachments in an xcresult bundle to <output>/<locale>/<stem>.png.
# Test plan configurations map to locales through the plan's language and region options.
normalize_exported_screenshots() {
  local result_bundle_path="$1"
  local output_dir="$2"
  local extracted_dir="$3"

  xcrun xcresulttool export attachments --path "$result_bundle_path" --output-path "$extracted_dir" >/dev/null

  python3 -I - "$ROOT_DIR/$TEST_PLAN_NAME.xctestplan" "$extracted_dir" "$output_dir" "${SCREENSHOT_EXPORT_STEMS[@]}" <<'PY'
import json, pathlib, re, shutil, sys

plan_path, extracted, output, *stems = sys.argv[1:]
plan = json.load(open(plan_path))
locales = {}
for configuration in plan["configurations"]:
    options = configuration.get("options", {})
    locales[configuration["name"]] = f"{options['language']}-{options['region']}"

exported = {}
for test in json.load(open(pathlib.Path(extracted) / "manifest.json")):
    for attachment in test.get("attachments", []):
        match = re.search(r"-(\d{2}-[A-Za-z0-9-]+)_0_", attachment.get("suggestedHumanReadableName", ""))
        if not match or not attachment["exportedFileName"].endswith(".png"):
            continue
        locale = locales[attachment["configurationName"]]
        destination = pathlib.Path(output) / locale / f"{match.group(1)}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(pathlib.Path(extracted) / attachment["exportedFileName"], destination)
        exported[(locale, match.group(1))] = destination

missing = [f"{locale}/{stem}.png" for locale in locales.values() for stem in stems if (locale, stem) not in exported]
if missing:
    sys.exit("Missing normalized screenshot exports: " + ", ".join(missing))
PY
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# The newest available iOS runtime that supports the device type; a beta runtime
# may support only new devices such as iPhone Duo.
resolve_ios_runtime() {
  local device_type="$1"
  local runtime

  runtime="$(
    xcrun simctl list runtimes available iOS -j \
      | python3 -I -c '
import json, sys
device_type = sys.argv[1]
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
runtimes.sort(key=lambda r: [int(part) for part in r["version"].split(".")])
supported = [r for r in runtimes if any(d["name"] == device_type for d in r.get("supportedDeviceTypes", []))]
print(supported[-1]["identifier"] if supported else "")
' "$device_type"
  )"

  if [[ -z "$runtime" ]]; then
    echo "No available iOS simulator runtime supports: $device_type" >&2
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

  for simulator_udid in ${created_simulators[@]+"${created_simulators[@]}"}; do
    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
  done
}

trap cleanup EXIT

require_command xcodebuild
require_command xcbeautify
require_command xcrun
require_command python3

rm -rf "$SCREENSHOT_ROOT"
mkdir -p "$RESULTS_DIR" "$DERIVED_DATA_PATH"

for simulator in "${simulators[@]}"; do
  assert_device_type_exists "$simulator"
  runtime_id="$(resolve_ios_runtime "$simulator")"

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

    normalize_exported_screenshots "$result_bundle_path" "$output_dir" "$extracted_dir"
    rm -rf "$extracted_dir"
    xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  done
done

echo "Screenshots exported to $SCREENSHOT_ROOT"
