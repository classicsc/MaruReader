#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SRCROOT}/External/uBlock/dist/build/uBOLite.safari"
DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/uBOLite.safari"

rm -rf "$DEST_DIR"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Skipping optional uBOLite.safari copy; source bundle not found at $SOURCE_DIR"
  exit 0
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
cp -R "$SOURCE_DIR" "$DEST_DIR"
echo "Copied optional uBOLite.safari to $DEST_DIR"
