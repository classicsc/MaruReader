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

# runs a specific test, optionally specify a destination
test-one only_testing destination="" plan="":
  ./scripts/run-test-only.sh "{{only_testing}}" "{{destination}}" "{{plan}}"

# builds the initial database with Jitendex and Kanji Alive
starterdict:
  ./scripts/run-starterdict.sh

# builds the uBOL content blocker extension
contentblocker:
  ./scripts/run-contentblocker.sh
