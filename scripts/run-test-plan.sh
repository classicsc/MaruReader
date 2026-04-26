#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <test-plan> [simulator_name_udid_or_destination]" >&2
  exit 1
fi

plan="$1"
destination_input="${2:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$("$ROOT_DIR/scripts/resolve-xcode-destination.sh" test "$destination_input")"
latest_raw_log_path="$ROOT_DIR/build/logs/latest-test-plan-${plan}.raw.log"

xcodebuild_args=(
  -project "$ROOT_DIR/MaruReader.xcodeproj"
  -scheme MaruReader
  -destination "$destination"
  -testPlan "$plan"
  test
)

for attempt in 1 2; do
  if "$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "test-plan-${plan}" "${xcodebuild_args[@]}"; then
    exit 0
  fi

  if [[ "$attempt" -eq 2 ]]; then
    exit 1
  fi

  if [[ -f "$latest_raw_log_path" ]] && grep -Fq 'is installing or uninstalling, and cannot be launched' "$latest_raw_log_path"; then
    echo "Retrying test plan $plan after simulator launch race..."
    sleep 15
    continue
  fi

  exit 1
done
