#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SRCROOT}/build/StarterDictionary"
DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/StarterDictionary"

rm -rf "$DEST_DIR"

if [[ "${CONFIGURATION}" != "Debug" ]]; then
  exit 0
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  exit 0
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
cp -R "$SOURCE_DIR" "$DEST_DIR"
