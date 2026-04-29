set shell := ["bash", "-euo", "pipefail", "-c"]

# list the available recipes
default:
  @just --list

# runs swiftformat on the entire project
format:
  swiftformat .

# builds the project, optionally specify a build configuration and destination
build configuration="Debug" destination="":
  ./scripts/maru.py build "{{configuration}}" "{{destination}}"

# builds tests without running them, optionally specify a build configuration and destination
build-for-testing configuration="Debug" destination="":
  ./scripts/maru.py build-for-testing "{{configuration}}" "{{destination}}"

# runs all test plans, optionally specify a destination
test destination="":
  ./scripts/maru.py test "{{destination}}"

# prepares local prerequisites for clean debug/test runs
prepare:
  ./scripts/stage-debug-tokenizer-dictionary.sh

# runs a specific test plan, optionally specify a destination
test-plan plan destination="":
  ./scripts/maru.py test-plan "{{plan}}" "{{destination}}"

# runs the only_testing test/suite in the given plan, optionally specify destination
test-one only_testing plan="" destination="":
  ./scripts/maru.py test-one "{{only_testing}}" "{{plan}}" "{{destination}}"

# runs Rust crate tests; omit the crate to run all Rust crate tests
test-crate crate="":
  ./scripts/maru.py test-crate "{{crate}}"

# builds the initial database with Jitendex and Kanji Alive
starterdict:
  ./scripts/run-starterdict.sh

# regenerates committed UniFFI Swift bindings for MaruSudachiFFI
sudachi-bindings:
  ./scripts/generate-sudachi-uniffi-bindings.sh

# regenerates committed UniFFI Swift bindings for MaruAdblockFFI
adblock-bindings:
  ./scripts/generate-adblock-uniffi-bindings.sh

# syncs bundled third-party license documents and catalog
licenses:
  swift scripts/sync-third-party-licenses.swift

# refreshes upstream license snapshots, including Rust cargo-about output, before syncing bundled third-party licenses
licenses-refresh:
  swift scripts/sync-third-party-licenses.swift --refresh-snapshots

# shows the synced marketing version and build number for MaruReader and its release extensions
release-status:
  ./scripts/maru.py release-status

# sets the synced marketing version for MaruReader and its release extensions
set-version version:
  ./scripts/maru.py set-version "{{version}}"

# creates a prerelease archive by incrementing the build number, then commits and tags it
prerelease:
  ./scripts/maru.py prerelease

# creates a release archive by setting the marketing version, incrementing build, then commits and tags it
release version="":
  ./scripts/maru.py release {{version}}

# runs the UI screenshot test plan and extracts images to build/screenshots/
screenshots:
  ./scripts/run-screenshots.sh
