# Agent instructions for MaruReader

## Project Overview

MaruReader is a Japanese language learning tool for iOS/iPadOS with an ebook reader, manga reader, and web browser that integrate with a dictionary system.

## Building

MaruReader uses synchronized filesystem groups. Routine addition and removal of source code files do not require editing the project file.

Build and test commands are provided by `just`. Use it instead of invoking the `xcodebuild` CLI directly for routine build and test runs (xcode function calls ok if available in your environment). Run unsandboxed if your environment has sandboxing. Tests can take upwards of 3 minutes (sometimes over 5 minutes for a brand new simulator) so set timeouts/waits accordingly. Do not interrupt builds. Checking or tailing the build logs during an in-progress build is not recommended.

```bash
Available recipes:
    build configuration="Debug" destination=""   # builds the project, optionally specify a build configuration and destination
    contentblocker                               # builds the optional uBOL content blocker extension bundle
    default                                      # list the available recipes
    format                                       # runs swiftformat on the entire project
    licenses                                     # syncs bundled third-party license documents and catalog
    licenses-refresh                             # refreshes upstream license snapshots before syncing bundled third-party licenses
    screenshots                                  # runs the UI screenshot test plan and extracts images to build/screenshots/
    starterdict                                  # builds the initial database with Jitendex and Kanji Alive
    test destination=""                          # runs all test plans, optionally specify a destination
    test-one only_testing plan="" destination="" # runs the only_testing test/suite in the given plan, optionally specify destination
    test-plan plan destination=""                # runs a specific test plan, optionally specify a destination
```

Do not run `just` recipes (or xcodebuild commands) in parallel, each invocation needs a lock on the build folder. Bypassing this limitation by adding another DerivedData folder is not allowed as this could exhaust system RAM and lock up the build.

Example:

```bash
just build # Simple build of the MaruReader target
just test-plan MaruReaderCoreTests # Run when MaruReaderCore is involved in changes
just test-one MaruReaderTests/AnkiSettingsSnapshotTests MaruReaderTests # If running a single suite is needed
# Most time in tests is the build and simulator setup. Only `just test``, which cycles through all test plans, is usually slower than 7 minutes. `test-plan` and `test-one` take about the same amount of time (3-5 minutes).
```

## Idealized Workflow

This demonstrates the red/green TDD pattern and best practices for major changes. It is not a prescription or a replacement for common sense. You don't have to explain why you didn't follow this process to the letter unless asked, but you should generally complete as much of this as the environment allows and the nature of the task demands.

1. Keep track of what you're doing with your environment's todo system, and/or with notes in the `build/`  folder.
2. Plan the scope and structure of your patch.
3. Decide acceptance criteria and test strategy.
    - Most non-minor changes, and even minor changes that could use a regression test, need unit test coverage. Expectations of existing tests might also require updates.
    - For some changes, interactive validation in simulator may be requested. If available in your environment, the CLI tool `axe` can be used to launch a simulator, capture screenshots and recordings, read the accessibility hierarchy, and interact with the running app with various gestures to validate many types of UI changes.
4. If existing expectations are being updated, run tests first to verify current state.
5. Write tests and update expectations.
6. Run tests and validation to verify failing ("red") state.
7. Implement code changes.
8. Run a build, fix any compile errors or new warnings.
9. Run tests and validation, fix any failures to get to "green" state.
10. If your environment has a code review function or a suitable sub-agent, get a code review. If there are findings to address, run build, tests, and validation after patching.
11. Commit changes, run `just format`, verify build still works, and amend the commit. If formatting breaks build, reset the broken file(s) and use `swiftformat --lint` to identify the specific rule which needs to be disabled at the broken line.
