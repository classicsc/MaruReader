#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <raw-xcodebuild-log>" >&2
  exit 1
fi

log_path="$1"

if [[ ! -f "$log_path" ]]; then
  echo "Log file not found: $log_path" >&2
  exit 1
fi

if summary="$(
  awk '
    /^[[:space:]]*([✔✘][[:space:]]+)?Test run with [0-9]+ tests in [0-9]+ suites? (passed|failed) after / {
      swift_testing_summary = $0
    }
    /^[[:space:]]*Executed [1-9][0-9]* tests, with / {
      xctest_summary = $0
    }
    END {
      if (swift_testing_summary != "") {
        sub(/^[[:space:]]+/, "", swift_testing_summary)
        print swift_testing_summary
        exit 0
      }
      if (xctest_summary != "") {
        sub(/^[[:space:]]+/, "", xctest_summary)
        print xctest_summary
        exit 0
      }
      exit 1
    }
  ' "$log_path"
)"; then
  printf '%s\n' "$summary"
  exit 0
fi

exit 1
