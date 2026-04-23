#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/MaruReader.xcodeproj/project.pbxproj"
TARGETS=(MaruReader MaruShareExtension MaruAssetDownloader)
TARGETS_JSON="$(printf '%s\n' "${TARGETS[@]}" | jq -R . | jq -s -c .)"

die() {
  echo "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required but was not found in PATH"
}

project_json() {
  plutil -convert json -o - "$PROJECT_FILE"
}

target_config_ids_json() {
  local json="$1"

  jq -c --argjson targets "$TARGETS_JSON" '
    .objects as $objects
    | [
        $objects
        | to_entries[]
        | . as $entry
        | select($entry.value.isa == "PBXNativeTarget" and (($targets | index($entry.value.name)) != null))
        | $entry.value.buildConfigurationList
        | $objects[.]
        | .buildConfigurations[]
      ]
    | unique
  ' <<<"$json"
}

unique_setting_value() {
  local json="$1"
  local config_ids_json="$2"
  local key="$3"
  local values_json

  values_json="$(
    jq -c --arg key "$key" --argjson config_ids "$config_ids_json" '
      .objects as $objects
      | [
          $config_ids[]
          | $objects[.]
          | .buildSettings[$key]
        ]
      | unique
    ' <<<"$json"
  )"

  local value_count
  value_count="$(jq 'length' <<<"$values_json")"
  if [[ "$value_count" -ne 1 ]]; then
    die "Expected a single synced value for $key across ${TARGETS[*]}, found: $(jq -r 'join(", ")' <<<"$values_json")"
  fi

  jq -r '.[0]' <<<"$values_json"
}

current_marketing_version() {
  local json="$1"
  local config_ids_json="$2"
  unique_setting_value "$json" "$config_ids_json" MARKETING_VERSION
}

current_build_number() {
  local json="$1"
  local config_ids_json="$2"
  unique_setting_value "$json" "$config_ids_json" CURRENT_PROJECT_VERSION
}

update_setting_for_config() {
  local config_id="$1"
  local key="$2"
  local value="$3"

  CONFIG_ID="$config_id" BUILD_SETTING_KEY="$key" BUILD_SETTING_VALUE="$value" perl -0pi -e '
    my $config_id = $ENV{CONFIG_ID};
    my $key = $ENV{BUILD_SETTING_KEY};
    my $value = $ENV{BUILD_SETTING_VALUE};
    my $count = s{
      (\Q$config_id\E\s*/\*.*?\*/\s*=\s*\{
       .*?
       buildSettings\s*=\s*\{
       .*?
       \b\Q$key\E\s*=\s*)
      [^;]+
      (;)
    }{$1$value$2}gsx;
    die "Failed to update $key for $config_id\n" if $count != 1;
  ' "$PROJECT_FILE"
}

set_synced_versions() {
  local marketing_version="$1"
  local build_number="$2"
  local json
  local config_ids_json
  local config_id

  json="$(project_json)"
  config_ids_json="$(target_config_ids_json "$json")"

  while IFS= read -r config_id; do
    update_setting_for_config "$config_id" MARKETING_VERSION "$marketing_version"
    update_setting_for_config "$config_id" CURRENT_PROJECT_VERSION "$build_number"
  done < <(jq -r '.[]' <<<"$config_ids_json")
}

ensure_clean_worktree() {
  if [[ -n "$(git -C "$ROOT_DIR" status --short)" ]]; then
    git -C "$ROOT_DIR" status --short
    die "Working tree must be clean before starting the release workflow."
  fi
}

ensure_tag_absent() {
  local tag_name="$1"
  if git -C "$ROOT_DIR" rev-parse --verify --quiet "refs/tags/$tag_name" >/dev/null; then
    die "Git tag $tag_name already exists."
  fi
}

normalize_tag_version() {
  local version="$1"

  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$version"
    return
  fi

  if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "${version}.0"
    return
  fi

  die "Version $version cannot be converted to a semver tag. Use Xcode Version values like 1.2.3."
}

validate_release_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Release version must use semver major.minor.patch."
}

run_release_prep() {
  "$ROOT_DIR/scripts/run-contentblocker.sh"
  swift "$ROOT_DIR/scripts/sync-third-party-licenses.swift" --refresh-snapshots
}

archive_for_tag() {
  local tag_name="$1"
  local destination
  local archive_dir="$ROOT_DIR/build/archives"
  local archive_path="$archive_dir/$tag_name.xcarchive"

  mkdir -p "$archive_dir"
  rm -rf "$archive_path"

  destination="$("$ROOT_DIR/scripts/resolve-xcode-destination.sh" build)"

  "$ROOT_DIR/scripts/run-xcodebuild-with-logs.sh" "archive-${tag_name}" \
    -project "$ROOT_DIR/MaruReader.xcodeproj" \
    -scheme MaruReader \
    -configuration Release \
    -destination "$destination" \
    -archivePath "$archive_path" \
    archive

  echo "$archive_path"
}

commit_and_tag() {
  local commit_message="$1"
  local tag_name="$2"

  git -C "$ROOT_DIR" add -A

  if git -C "$ROOT_DIR" diff --cached --quiet; then
    die "Release workflow produced no changes to commit."
  fi

  git -C "$ROOT_DIR" commit -m "$commit_message"
  git -C "$ROOT_DIR" tag -a "$tag_name" -m "$tag_name"
}

show_status() {
  local json
  local config_ids_json
  local marketing_version
  local build_number
  local prerelease_tag

  json="$(project_json)"
  config_ids_json="$(target_config_ids_json "$json")"
  marketing_version="$(current_marketing_version "$json" "$config_ids_json")"
  build_number="$(current_build_number "$json" "$config_ids_json")"
  prerelease_tag="v$(normalize_tag_version "$marketing_version")-build.$build_number"

  cat <<EOF
Marketing version: $marketing_version
Build number: $build_number
Targets: ${TARGETS[*]}
Current prerelease tag shape: $prerelease_tag
EOF
}

run_prerelease() {
  local json
  local config_ids_json
  local marketing_version
  local current_build_number_value
  local next_build_number
  local tag_name
  local archive_path

  ensure_clean_worktree

  json="$(project_json)"
  config_ids_json="$(target_config_ids_json "$json")"
  marketing_version="$(current_marketing_version "$json" "$config_ids_json")"
  current_build_number_value="$(current_build_number "$json" "$config_ids_json")"

  [[ "$current_build_number_value" =~ ^[0-9]+$ ]] || die "Current build number must be numeric."
  next_build_number=$((current_build_number_value + 1))
  tag_name="v$(normalize_tag_version "$marketing_version")-build.$next_build_number"

  ensure_tag_absent "$tag_name"
  run_release_prep
  set_synced_versions "$marketing_version" "$next_build_number"
  archive_path="$(archive_for_tag "$tag_name")"
  commit_and_tag "Prerelease $tag_name" "$tag_name"

  cat <<EOF
Created prerelease $tag_name
Archived at $archive_path
EOF
}

run_release() {
  local release_version="$1"
  local tag_name="v$release_version"
  local archive_path

  [[ "$current_build_number_value" =~ ^[0-9]+$ ]] || die "Current build number must be numeric."
  next_build_number=$((current_build_number_value + 1))

  validate_release_version "$release_version"
  ensure_clean_worktree
  ensure_tag_absent "$tag_name"
  run_release_prep
  set_synced_versions "$release_version" "$next_build_number"
  archive_path="$(archive_for_tag "$tag_name")"
  commit_and_tag "Release $tag_name" "$tag_name"

  cat <<EOF
Created release $tag_name
Archived at $archive_path
EOF
}

main() {
  require_command git
  require_command jq
  require_command perl
  require_command plutil
  require_command swift

  local command="${1:-}"
  case "$command" in
    show)
      show_status
      ;;
    prerelease)
      run_prerelease
      ;;
    release)
      [[ $# -eq 2 ]] || die "Usage: $0 release <version>"
      run_release "$2"
      ;;
    *)
      die "Usage: $0 <show|prerelease|release>"
      ;;
  esac
}

main "$@"
