#!/usr/bin/env bash
set -euo pipefail

# Xcode shell phases often run with a reduced PATH that excludes Homebrew.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/build/logs"
DOWNLOAD_DIR="$ROOT_DIR/build/downloads"
PINNED_COMMIT="2fd29256c6d5e1b10211cac838069ee9ede8c77a"
ARCHIVE_URL="https://github.com/taku910/mecab/archive/$PINNED_COMMIT.tar.gz"
ARCHIVE_PATH="$DOWNLOAD_DIR/mecab-$PINNED_COMMIT.tar.gz"

DERIVED_FILE_DIR="${DERIVED_FILE_DIR:?DERIVED_FILE_DIR must be set by Xcode}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR must be set by Xcode}"
UNLOCALIZED_RESOURCES_FOLDER_PATH="${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH must be set by Xcode}"

WORK_DIR="$DERIVED_FILE_DIR/bundled-ipadic"
SOURCE_DIR="$WORK_DIR/source"
OUTPUT_DIR="$WORK_DIR/output"
TARGET_DICT_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ipadic dictionary"
EXTRACTED_ROOT="$SOURCE_DIR/mecab-$PINNED_COMMIT"
IPADIC_SOURCE_DIR="$EXTRACTED_ROOT/mecab-ipadic"

timestamp="$(date +%Y%m%d-%H%M%S)"
build_log_path="$LOG_DIR/${timestamp}-bundled-ipadic-build.log"
latest_build_log_path="$LOG_DIR/latest-bundled-ipadic-build.log"

mkdir -p "$LOG_DIR" "$DOWNLOAD_DIR" "$WORK_DIR"

find_mecab_dict_index() {
  if command -v mecab-dict-index >/dev/null 2>&1; then
    command -v mecab-dict-index
    return 0
  fi

  local candidate
  local candidates=(
    "/opt/homebrew/bin/mecab-dict-index"
    "/usr/local/bin/mecab-dict-index"
    "/opt/homebrew/libexec/mecab/mecab-dict-index"
    "/usr/local/libexec/mecab/mecab-dict-index"
    "/opt/homebrew/opt/mecab/libexec/mecab/mecab-dict-index"
    "/usr/local/opt/mecab/libexec/mecab/mecab-dict-index"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  local brew_bin
  local brew_bins=(
    "$(command -v brew 2>/dev/null || true)"
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
  )

  for brew_bin in "${brew_bins[@]}"; do
    [[ -n "$brew_bin" && -x "$brew_bin" ]] || continue

    local brew_prefix
    brew_prefix="$("$brew_bin" --prefix mecab 2>/dev/null || true)"
    if [[ -n "$brew_prefix" && -x "$brew_prefix/libexec/mecab/mecab-dict-index" ]]; then
      printf '%s\n' "$brew_prefix/libexec/mecab/mecab-dict-index"
      return 0
    fi
  done

  return 1
}

MECAB_DICT_INDEX="$(find_mecab_dict_index || true)"
if [[ -z "$MECAB_DICT_INDEX" ]]; then
  echo "error: mecab-dict-index not found. Install mecab and ensure it is in PATH or available under Homebrew's libexec/mecab path." >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Downloading pinned MeCab source archive..."
  curl --fail --location --output "$ARCHIVE_PATH" "$ARCHIVE_URL"
else
  echo "Using cached MeCab source archive at $ARCHIVE_PATH"
fi

rm -rf "$SOURCE_DIR" "$OUTPUT_DIR"
mkdir -p "$SOURCE_DIR" "$OUTPUT_DIR"

echo "Extracting source archive..."
tar -xzf "$ARCHIVE_PATH" -C "$SOURCE_DIR"

if [[ ! -d "$IPADIC_SOURCE_DIR" ]]; then
  echo "error: extracted archive is missing mecab-ipadic sources at $IPADIC_SOURCE_DIR" >&2
  exit 1
fi

STAGED_DICT_DIR="$OUTPUT_DIR/ipadic dictionary"
mkdir -p "$STAGED_DICT_DIR"

echo "Building compiled IPADic dictionary..."
set +e
"$MECAB_DICT_INDEX" \
  -d "$IPADIC_SOURCE_DIR" \
  -o "$STAGED_DICT_DIR" \
  -f euc-jp \
  -t utf-8 \
  -p 2>&1 | tee "$build_log_path"
build_exit_code=${PIPESTATUS[0]}
set -e

cp "$build_log_path" "$latest_build_log_path"

if [[ $build_exit_code -ne 0 ]]; then
  echo "error: mecab-dict-index failed. See $build_log_path" >&2
  exit "$build_exit_code"
fi

static_files=(
  "dicrc"
  "left-id.def"
  "pos-id.def"
  "rewrite.def"
  "right-id.def"
)

for static_file in "${static_files[@]}"; do
  cp "$IPADIC_SOURCE_DIR/$static_file" "$STAGED_DICT_DIR/$static_file"
done

required_files=(
  "char.bin"
  "dicrc"
  "left-id.def"
  "matrix.bin"
  "pos-id.def"
  "rewrite.def"
  "right-id.def"
  "sys.dic"
  "unk.dic"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$STAGED_DICT_DIR/$required_file" ]]; then
    echo "error: compiled dictionary is missing required file: $required_file" >&2
    exit 1
  fi
done

echo "Copying bundled dictionary into $TARGET_DICT_DIR"
rm -rf "$TARGET_DICT_DIR"
mkdir -p "$TARGET_DICT_DIR"

for required_file in "${required_files[@]}"; do
  cp "$STAGED_DICT_DIR/$required_file" "$TARGET_DICT_DIR/$required_file"
done

echo "Bundled IPADic build log: $build_log_path"
echo "Latest bundled IPADic build log: $latest_build_log_path"
