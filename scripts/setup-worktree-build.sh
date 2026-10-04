#!/usr/bin/env bash
# Claude Code hook (SessionStart/CwdChanged): seeds a linked git worktree's
# build/ folder from the main checkout and runs `just prepare`, so tokenizer
# tests and the starter dictionary work without rebuilding. No-op elsewhere.
set -euo pipefail

input="$(cat || true)"
dir="$(jq -r '.new_cwd // .cwd // empty' <<<"$input" 2>/dev/null || true)"
dir="${dir:-$PWD}"

top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
main="$(dirname "$(git -C "$top" rev-parse --path-format=absolute --git-common-dir)")"
[[ "$top" == "$main" ]] && exit 0
[[ -f "$top/build/StarterDictionary/TokenizerDictionary/system_full.dic" ]] && exit 0
[[ -d "$main/build" ]] || exit 0

mkdir -p "$top/build"
for src in "$main"/build/*; do
  name="$(basename "$src")"
  [[ "$name" == logs || -e "$top/build/$name" ]] && continue
  # APFS clone: copy-on-write, no extra disk until modified.
  cp -cR "$src" "$top/build/$name"
done

(cd "$top" && just prepare) >&2
