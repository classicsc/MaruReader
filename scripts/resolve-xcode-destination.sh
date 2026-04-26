#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <build|test> [destination_or_simulator]" >&2
  exit 1
fi

mode="$1"
destination_input="${2:-}"

if [[ "$mode" != "build" && "$mode" != "test" ]]; then
  echo "Mode must be 'build' or 'test'" >&2
  exit 1
fi

if [[ -z "$destination_input" ]]; then
  if [[ "$mode" == "build" ]]; then
    echo "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1"
  else
    echo "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1"
  fi
  exit 0
fi

if [[ "$destination_input" == generic/* ]]; then
  echo "$destination_input"
  exit 0
fi

if [[ "$destination_input" == *"platform="* || "$destination_input" == *","* ]]; then
  echo "$destination_input"
  exit 0
fi

if [[ "$destination_input" =~ ^[0-9A-Fa-f-]{8,}$ ]]; then
  echo "platform=iOS Simulator,id=$destination_input"
  exit 0
fi

echo "platform=iOS Simulator,name=$destination_input"
