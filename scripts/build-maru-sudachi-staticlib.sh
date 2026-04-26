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

is_catalyst=false
if [[ "$EFFECTIVE_PLATFORM_NAME" == "-maccatalyst" || "$LLVM_TARGET_TRIPLE_SUFFIX" == "-macabi" ]]; then
  is_catalyst=true
fi

rust_target_for_arch() {
  local arch="$1"

  case "$PLATFORM_NAME:$arch:$is_catalyst" in
    iphoneos:arm64:false)
      echo "aarch64-apple-ios"
      ;;
    iphonesimulator:arm64:false)
      echo "aarch64-apple-ios-sim"
      ;;
    iphonesimulator:x86_64:false)
      echo "x86_64-apple-ios"
      ;;
    macosx:arm64:false)
      echo "aarch64-apple-darwin"
      ;;
    macosx:x86_64:false)
      echo "x86_64-apple-darwin"
      ;;
    macosx:arm64:true)
      echo "aarch64-apple-ios-macabi"
      ;;
    macosx:x86_64:true)
      echo "x86_64-apple-ios-macabi"
      ;;
    *)
      echo "error: unsupported Xcode build destination: PLATFORM_NAME=$PLATFORM_NAME CURRENT_ARCH=$arch EFFECTIVE_PLATFORM_NAME=$EFFECTIVE_PLATFORM_NAME LLVM_TARGET_TRIPLE_SUFFIX=$LLVM_TARGET_TRIPLE_SUFFIX" >&2
      return 1
      ;;
  esac
}

resolved_archs=()
if [[ -n "$CURRENT_ARCH" && "$CURRENT_ARCH" != "undefined_arch" ]]; then
  resolved_archs+=("$CURRENT_ARCH")
elif [[ -n "$ARCHS" ]]; then
  read -r -a resolved_archs <<<"$ARCHS"
elif [[ -n "$NATIVE_ARCH_ACTUAL" && "$NATIVE_ARCH_ACTUAL" != "undefined_arch" ]]; then
  resolved_archs+=("$NATIVE_ARCH_ACTUAL")
fi

if [[ ${#resolved_archs[@]} -eq 0 ]]; then
  echo "error: failed to resolve active architectures from Xcode environment" >&2
  exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required to build MaruSudachiFFI for Apple targets" >&2
  exit 1
fi

cargo_target_dir="$PROJECT_TEMP_DIR/cargo"
output_dir="$PROJECT_TEMP_DIR/RustStaticLibs"
mkdir -p "$output_dir"

profile_dir="debug"
if [[ "$CONFIGURATION" != "Debug" ]]; then
  profile_dir="release"
fi

staticlib_paths=()
for arch in "${resolved_archs[@]}"; do
  rust_target="$(rust_target_for_arch "$arch")"
  rustup target add "$rust_target" >/dev/null

  build_args=(
    --manifest-path "$CRATE_DIR/Cargo.toml"
    --lib
    --target "$rust_target"
  )
  if [[ "$CONFIGURATION" != "Debug" ]]; then
    build_args+=(--release)
  fi

  CARGO_TARGET_DIR="$cargo_target_dir" cargo build "${build_args[@]}"

  staticlib_path="$cargo_target_dir/$rust_target/$profile_dir/libmaru_sudachi_ffi.a"
  if [[ ! -f "$staticlib_path" ]]; then
    echo "error: expected Rust static library at $staticlib_path" >&2
    exit 1
  fi
  staticlib_paths+=("$staticlib_path")
done

if [[ ${#staticlib_paths[@]} -eq 1 ]]; then
  cp "${staticlib_paths[0]}" "$output_dir/libmaru_sudachi_ffi.a"
else
  xcrun lipo -create "${staticlib_paths[@]}" -output "$output_dir/libmaru_sudachi_ffi.a"
fi
