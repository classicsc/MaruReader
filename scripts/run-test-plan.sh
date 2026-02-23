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

"$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "test-plan-${plan}" \
  -project "$ROOT_DIR/MaruReader.xcodeproj" \
  -scheme MaruReader \
  -destination "$destination" \
  -testPlan "$plan" \
  test
