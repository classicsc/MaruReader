#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SRCROOT}/External/uBlock/dist/build/uBOLite.safari"
SOURCE_ZIP="${SRCROOT}/External/uBlock/dist/build/uBOLite.safari.zip"
DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/uBOLite.safari"
DEST_ZIP="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/uBOLite.safari.zip"

rm -rf "$DEST_DIR"
rm -f "$DEST_ZIP"

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

if [[ -f "$SOURCE_ZIP" ]]; then
  cp "$SOURCE_ZIP" "$DEST_ZIP"
  echo "Copied optional uBOLite.safari.zip to $DEST_ZIP"
  exit 0
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Skipping optional uBOLite.safari ZIP copy; source bundle not found at $SOURCE_DIR"
  exit 0
fi

(
  cd "$SOURCE_DIR"
  /usr/bin/zip -q -r -X "$DEST_ZIP" .
)
echo "Created optional uBOLite.safari.zip at $DEST_ZIP from $SOURCE_DIR"
