#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/MaruSudachiFFI"

PROJECT_TEMP_DIR="${PROJECT_TEMP_DIR:?PROJECT_TEMP_DIR must be set by Xcode}"
CURRENT_ARCH="${CURRENT_ARCH:-}"
ARCHS="${ARCHS:-}"
NATIVE_ARCH_ACTUAL="${NATIVE_ARCH_ACTUAL:-}"
PLATFORM_NAME="${PLATFORM_NAME:?PLATFORM_NAME must be set by Xcode}"
EFFECTIVE_PLATFORM_NAME="${EFFECTIVE_PLATFORM_NAME:-}"
LLVM_TARGET_TRIPLE_SUFFIX="${LLVM_TARGET_TRIPLE_SUFFIX:-}"
CONFIGURATION="${CONFIGURATION:-Debug}"

if [[ -z "$CURRENT_ARCH" || "$CURRENT_ARCH" == "undefined_arch" ]]; then
  if [[ -n "$NATIVE_ARCH_ACTUAL" && "$NATIVE_ARCH_ACTUAL" != "undefined_arch" ]]; then
    CURRENT_ARCH="$NATIVE_ARCH_ACTUAL"
  elif [[ -n "$ARCHS" ]]; then
    CURRENT_ARCH="${ARCHS%% *}"
  fi
fi

if [[ -z "$CURRENT_ARCH" || "$CURRENT_ARCH" == "undefined_arch" ]]; then
  echo "error: failed to resolve an active architecture from Xcode environment" >&2
  exit 1
fi

is_catalyst=false
if [[ "$EFFECTIVE_PLATFORM_NAME" == "-maccatalyst" || "$LLVM_TARGET_TRIPLE_SUFFIX" == "-macabi" ]]; then
  is_catalyst=true
fi

case "$PLATFORM_NAME:$CURRENT_ARCH:$is_catalyst" in
  iphoneos:arm64:false)
    rust_target="aarch64-apple-ios"
    ;;
  iphonesimulator:arm64:false)
    rust_target="aarch64-apple-ios-sim"
    ;;
  iphonesimulator:x86_64:false)
    rust_target="x86_64-apple-ios"
    ;;
  macosx:arm64:false)
    rust_target="aarch64-apple-darwin"
    ;;
  macosx:x86_64:false)
    rust_target="x86_64-apple-darwin"
    ;;
  macosx:arm64:true)
    rust_target="aarch64-apple-ios-macabi"
    ;;
  macosx:x86_64:true)
    rust_target="x86_64-apple-ios-macabi"
    ;;
  *)
    echo "error: unsupported Xcode build destination: PLATFORM_NAME=$PLATFORM_NAME CURRENT_ARCH=$CURRENT_ARCH EFFECTIVE_PLATFORM_NAME=$EFFECTIVE_PLATFORM_NAME LLVM_TARGET_TRIPLE_SUFFIX=$LLVM_TARGET_TRIPLE_SUFFIX" >&2
    exit 1
    ;;
esac

if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required to build MaruSudachiFFI for Apple targets" >&2
  exit 1
fi

rustup target add "$rust_target" >/dev/null

cargo_target_dir="$PROJECT_TEMP_DIR/cargo"
output_dir="$PROJECT_TEMP_DIR/RustStaticLibs"
mkdir -p "$output_dir"

build_args=(
  --manifest-path "$CRATE_DIR/Cargo.toml"
  --lib
  --target "$rust_target"
)
if [[ "$CONFIGURATION" != "Debug" ]]; then
  build_args+=(--release)
fi

CARGO_TARGET_DIR="$cargo_target_dir" cargo build "${build_args[@]}"

profile_dir="debug"
if [[ "$CONFIGURATION" != "Debug" ]]; then
  profile_dir="release"
fi

staticlib_path="$cargo_target_dir/$rust_target/$profile_dir/libmaru_sudachi_ffi.a"
if [[ ! -f "$staticlib_path" ]]; then
  echo "error: expected Rust static library at $staticlib_path" >&2
  exit 1
fi

cp "$staticlib_path" "$output_dir/libmaru_sudachi_ffi.a"
