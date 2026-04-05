# Agent instructions for MaruReader

## Project Overview

MaruReader is a Japanese language learning tool for iOS/iPadOS with an ebook reader, manga reader, and web browser that integrate with a dictionary system.

## Building

MaruReader uses synchronized filesystem groups. Routine addition and removal of source code files do not require editing the project file.

Build and test commands are provided by `just`. Use it instead of invoking the `xcodebuild` CLI directly for routine build and test runs, they provide logging conveniences and don't spam stdout (xcode function calls ok if available in your environment, xcode function calls are also the only way to trigger a localization string catalog sync). Run unsandboxed if your environment has sandboxing. Tests can take upwards of 3 minutes (sometimes over 5 minutes for a brand new simulator) so set timeouts/waits accordingly. Do not interrupt builds. Checking or tailing the build logs during an in-progress build is not recommended.

```bash
Available recipes:
    build configuration="Debug" destination=""   # builds the project, optionally specify a build configuration and destination
    contentblocker                               # builds the optional uBOL content blocker extension bundle
    default                                      # list the available recipes
    format                                       # runs swiftformat on the entire project
    licenses                                     # syncs bundled third-party license documents and catalog
    licenses-refresh                             # refreshes upstream license snapshots before syncing bundled third-party licenses
    screenshots                                  # runs the UI screenshot test plan and extracts images to build/screenshots/
    starterdict                                  # builds the asset package
    test destination=""                          # runs all test plans, optionally specify a destination
    test-one only_testing plan="" destination="" # runs the only_testing test/suite in the given plan, optionally specify destination
    test-plan plan destination=""                # runs a specific test plan, optionally specify a destination
```

Do not run `just` recipes (or xcodebuild commands) in parallel, each invocation needs a lock on the build folder. Bypassing this limitation by adding another DerivedData folder is not allowed as this could exhaust system RAM and lock up the build.

Example:

```bash
just build # Simple build of the MaruReader target
just test-plan MaruReaderCoreTests # Run when MaruReaderCore is involved in changes
just test-one MaruReaderTests/AnkiSettingsSnapshotTests MaruReaderTests # If avoiding other MaruReaderTests suites is required
```

`just test-plan` is nearly always the recipe to use for tests. `just test-one` is not a "lighter" recipe. It is for situations where you must avoid executing other tests in the plan, such as if they crash the simulator and you are fixing another test first. All methods of testing with xcodebuild will resolve the package graph, build MaruReader.app, and go through simulator workflows taking minutes before executing the test plan (under 5s).

