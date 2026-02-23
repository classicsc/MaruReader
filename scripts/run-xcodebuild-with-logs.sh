#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <log-key> <xcodebuild-args...>" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required but not found in PATH" >&2
  exit 1
fi

if ! command -v xcbeautify >/dev/null 2>&1; then
  echo "xcbeautify is required but not found in PATH" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/build/logs"
mkdir -p "$LOG_DIR"

log_key="${1//[^A-Za-z0-9._-]/-}"
shift

timestamp="$(date +%Y%m%d-%H%M%S)"
raw_log_path="$LOG_DIR/${timestamp}-${log_key}.raw.log"
parsed_log_path="$LOG_DIR/${timestamp}-${log_key}.parsed.log"
latest_raw_path="$LOG_DIR/latest-${log_key}.raw.log"
latest_parsed_path="$LOG_DIR/latest-${log_key}.parsed.log"

echo "Running xcodebuild ($log_key)"
echo "Raw log: $raw_log_path"
echo "Parsed log: $parsed_log_path"

set +e
xcodebuild "$@" 2>&1 | tee "$raw_log_path" | xcbeautify -q | tee "$parsed_log_path"
xcodebuild_exit_code=${PIPESTATUS[0]}
set -e

cp "$raw_log_path" "$latest_raw_path"
cp "$parsed_log_path" "$latest_parsed_path"

echo "Latest raw log: $latest_raw_path"
echo "Latest parsed log: $latest_parsed_path"

exit "$xcodebuild_exit_code"
