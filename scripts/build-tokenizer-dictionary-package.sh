#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/build/downloads/sudachi-tokenizer-dictionary.zip}"
TOKENIZER_NAME="${TOKENIZER_NAME:-SudachiDict Full}"
TOKENIZER_VERSION="${TOKENIZER_VERSION:-20260116}"
TOKENIZER_ATTRIBUTION="${TOKENIZER_ATTRIBUTION:-SudachiDict by Works Applications Co., Ltd. is licensed under the [Apache License, Version2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

   Copyright (c) 2017-2023 Works Applications Co., Ltd.

   Licensed under the Apache License, Version 2.0 (the \"License\");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an \"AS IS\" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

This project includes UniDic and a part of NEologd.
- http://unidic.ninjal.ac.jp/
- https://github.com/neologd/mecab-ipadic-neologd}"
TOKENIZER_INDEX_URL="${TOKENIZER_INDEX_URL:-}"
TOKENIZER_DOWNLOAD_URL="${TOKENIZER_DOWNLOAD_URL:-}"

TEMP_DIR="$(mktemp -d)"
PACKAGE_DIR="$TEMP_DIR/package"

json_string() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT_PATH")" "$PACKAGE_DIR"
"$ROOT_DIR/scripts/fetch-sudachi-resources.sh" "$PACKAGE_DIR"

name_json="$(json_string "$TOKENIZER_NAME")"
version_json="$(json_string "$TOKENIZER_VERSION")"
attribution_json="$(json_string "$TOKENIZER_ATTRIBUTION")"

if [[ -n "$TOKENIZER_INDEX_URL" && -n "$TOKENIZER_DOWNLOAD_URL" ]]; then
  is_updatable=true
  index_url_json="$(json_string "$TOKENIZER_INDEX_URL")"
  download_url_json="$(json_string "$TOKENIZER_DOWNLOAD_URL")"
else
  is_updatable=false
  index_url_json="null"
  download_url_json="null"
fi

cat >"$PACKAGE_DIR/index.json" <<EOF
{
  "type": "tokenizer-dictionary",
  "format": 1,
  "name": $name_json,
  "version": $version_json,
  "isUpdatable": $is_updatable,
  "attribution": $attribution_json,
  "indexUrl": $index_url_json,
  "downloadUrl": $download_url_json
}
EOF

rm -f "$OUTPUT_PATH"
(
  cd "$PACKAGE_DIR"
  zip -qr "$OUTPUT_PATH" index.json char.def rewrite.def sudachi.json system_full.dic unk.def
)
