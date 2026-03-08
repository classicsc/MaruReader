set shell := ["bash", "-euo", "pipefail", "-c"]

# list the available recipes
default:
  @just --list

# runs swiftformat on the entire project
format:
  swiftformat .

# builds the project, optionally specify a build configuration and destination
build configuration="Debug" destination="":
  ./scripts/run-build.sh "{{configuration}}" "{{destination}}"

# runs all test plans, optionally specify a destination
test destination="":
  ./scripts/run-all-test-plans.sh "{{destination}}"

# runs a specific test plan, optionally specify a destination
test-plan plan destination="":
  ./scripts/run-test-plan.sh "{{plan}}" "{{destination}}"

# runs a specific test, optionally specify a test plan and destination
test-one only_testing plan="" destination="":
  ./scripts/run-test-only.sh "{{only_testing}}" "{{plan}}" "{{destination}}"

# builds the initial database with Jitendex and Kanji Alive
starterdict:
  ./scripts/run-starterdict.sh

# builds the uBOL content blocker extension
contentblocker:
  ./scripts/run-contentblocker.sh

# syncs bundled third-party license documents and catalog
licenses:
  swift scripts/sync-third-party-licenses.swift

# refreshes upstream license snapshots before syncing bundled third-party licenses
licenses-refresh:
  swift scripts/sync-third-party-licenses.swift --refresh-snapshots

# captures screenshots via fastlane snapshot to fastlane/screenshots/
screenshots:
  fastlane snapshot
