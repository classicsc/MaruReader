#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <only-testing-id> [test-plan] [simulator_name_udid_or_destination]" >&2
  exit 1
fi

only_testing="$1"
plan="${2:-}"
destination_input="${3:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$("$ROOT_DIR/scripts/resolve-xcode-destination.sh" test "$destination_input")"

xcodebuild_args=(
  -project "$ROOT_DIR/MaruReader.xcodeproj"
  -scheme MaruReader
  -destination "$destination"
)

if [[ -n "$plan" ]]; then
  xcodebuild_args+=(-testPlan "$plan")
fi

xcodebuild_args+=("-only-testing:$only_testing" test)

"$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "test-one-${only_testing}" "${xcodebuild_args[@]}"
