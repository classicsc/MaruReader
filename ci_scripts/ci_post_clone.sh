#!/bin/bash
set -euo pipefail

# Xcode build phases also add this path; exports here do not persist into them.
export PATH="$HOME/.cargo/bin:$PATH"

# Match development CI's stable Rust toolchain, with the device target for archives.
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 --fail --show-error --silent --location \
  https://sh.rustup.rs -o "$installer"
sh "$installer" -y --profile minimal --default-toolchain stable --no-modify-path \
  --target aarch64-apple-ios

cd "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud must provide the repository path}"
for crate in MaruMarkFFI MaruAdblockFFI MaruSudachiFFI; do
  cargo fetch --locked --manifest-path "$crate/Cargo.toml" --target aarch64-apple-ios
done
