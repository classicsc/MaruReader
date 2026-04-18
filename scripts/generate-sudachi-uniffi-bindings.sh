#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/MaruSudachiFFI"
RESOURCE_DIR="$ROOT_DIR/build/sudachi/v20260116-full"
OUTPUT_DIR="$ROOT_DIR/MaruTextAnalysis/Generated/UniFFI"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ ! -f "$RESOURCE_DIR/system_full.dic" ]]; then
  "$ROOT_DIR/scripts/fetch-sudachi-resources.sh" "$RESOURCE_DIR"
fi

cargo rustc \
  --manifest-path "$CRATE_DIR/Cargo.toml" \
  --lib \
  --crate-type cdylib

library_path="$(find "$CRATE_DIR/target/debug" -maxdepth 1 -type f \( -name 'libmaru_sudachi_ffi.dylib' -o -name 'libmaru_sudachi_ffi.so' -o -name 'maru_sudachi_ffi.dll' \) | head -n 1)"
if [[ -z "$library_path" ]]; then
  echo "error: failed to locate host cdylib for MaruSudachiFFI" >&2
  exit 1
fi

uniffi_version="$(
  awk -F'"' '
    /^[[:space:]]*uniffi[[:space:]]*=/ {
      value = $2
      sub(/^=/, "", value)
      print value
      exit
    }
  ' "$CRATE_DIR/Cargo.toml"
)"
if [[ -z "$uniffi_version" ]]; then
  echo "error: failed to resolve pinned uniffi version from Cargo.toml" >&2
  exit 1
fi

uniffi_manifest_path="$(find "$HOME/.cargo/registry/src" -path "*uniffi-$uniffi_version/Cargo.toml" | head -n 1)"
if [[ -z "$uniffi_manifest_path" ]]; then
  cargo fetch --manifest-path "$CRATE_DIR/Cargo.toml"
  uniffi_manifest_path="$(find "$HOME/.cargo/registry/src" -path "*uniffi-$uniffi_version/Cargo.toml" | head -n 1)"
fi
if [[ -z "$uniffi_manifest_path" ]]; then
  echo "error: failed to locate uniffi-$uniffi_version manifest in cargo registry" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

generate_swift_bindings() {
  cargo run \
    --manifest-path "$uniffi_manifest_path" \
    --features cli \
    --bin uniffi-bindgen-swift \
    -- "$@"
}

pushd "$CRATE_DIR" >/dev/null
generate_swift_bindings --swift-sources "$library_path" "$OUTPUT_DIR"
generate_swift_bindings --headers "$library_path" "$OUTPUT_DIR"
generate_swift_bindings \
  --modulemap \
  --module-name maru_sudachi_ffiFFI \
  --modulemap-filename module.modulemap \
  "$library_path" \
  "$OUTPUT_DIR"
popd >/dev/null

echo "Generated UniFFI Swift bindings at $OUTPUT_DIR"
