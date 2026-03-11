# Agent instructions for MaruReader

## Project Overview

MaruReader is a Japanese language learning tool for iOS/iPadOS that combines a Yomitan-compatible dictionary with an ebook reader, manga reader, and web browser. It is licensed under GPLv3.

### Status + Guidelines

MaruReader is pre-release but nearly feature complete. Data models are not frozen. When replacing APIs, they should be removed instead of marking as deprecated.

New and substantially changed functionality requires unit test coverage. Red/green TDD is recommended.

Changes that touch the UI need to be verified interactively. If available in your environment, the `xcodebuildmcp` command line tool is recommended for launching the app in a simulator.

## Build Commands

Always verify your changes compile, even if a build is not specifically requested. When modifying tested logic or adding tests, verify the relevant test plan passes.

 Test plans pick up new tests from the associated target. Targets pick up new files via folder groups, so no need for project file editing for routine adding and removing of source code files.

In command environments subject to sandboxing, these commands are approved to run unsandboxed.

```bash
just format # Run code formatting
just build # Build the project
just test # Run all tests
just test-plan MaruReaderCoreTests # Run a specific test plan
just test-one 'MaruReaderCoreTests/SomeSuite/testExample()' MaruReaderCoreTests # Run a specific test
```

Avoid running these commands in parallel, it may cause build folder locking failures.

`just build`/`just test` accept an optional device specifier as the last argument. Usually the default (iPhone 17 Pro simulator) is all you need. Accepted formats:

- Simulator name: `'iPhone 17 Pro'`
- Simulator UDID: `76252478-5498-412D-9417-76009568896C`
- Raw xcodebuild destination: `'platform=iOS Simulator,id=76252478-5498-412D-9417-76009568896C'`

Xcodebuild-backed recipes also write raw and parsed logs to `build/logs/` (timestamped plus `latest-*.log` aliases). stdout receives the `xcbeautify`-parsed output.

If available in your environment, xcode's build/test functions are also valid options.

When running tests, runtime warnings like `Multiple NSEntityDescriptions claim the NSManagedObject subclass '...' so +entity is unable to disambiguate.` are expected and not harmful, since tests use an in-memory store which duplicates the entity descriptions from the sqlite store, so no need to report these.

## API Availibility

MaruReader targets iOS 26+, so newer APIs are available and do not require availability checks. `WebView`, `WebPage` and other WebKit things not prefixed with `WK` are from "WebKit for SwiftUI", introduced in iOS 26. `MaruVision` uses types like `RecognizedTextObservation`, part of the iOS 18 Vision API, which has a similar purpose but a different set of capabilities from the older `VN`-prefixed API.

Liquid Glass is the iOS 26 systemwide theme and design language, which emphasizes the use of transparency and UI elements that morph, split, and merge like drops of water.

Documentation search tools, if available in your environment, can help. In environments without dedicated Apple documentation functions, you can fetch documents in Markdown format by replacing the `developer.apple.com` in a URL with `sosumi.ai`.
