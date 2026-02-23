#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-Debug}"
destination_input="${2:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$("$ROOT_DIR/scripts/resolve-xcode-destination.sh" build "$destination_input")"
log_key="build-$(echo "$configuration" | tr '[:upper:]' '[:lower:]')"

"$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "$log_key" \
  -project "$ROOT_DIR/MaruReader.xcodeproj" \
  -scheme MaruReader \
  -destination "$destination" \
  -configuration "$configuration" \
  build
