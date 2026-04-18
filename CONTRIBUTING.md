# MaruReader Contributing Guide

Thanks for your interest in helping to improve MaruReader!

If you have a definite bug and know how to fix it, feel free to submit a PR directly. For larger features or if you're unsure about the best approach, please open an issue. For general feedback and bug reports, use the Discussions tab.

Before sending a PR, make sure it passes the unit tests, and if possible, include new test coverage.

## Development

For development, these tools are required:

- [Xcode 26+](https://developer.apple.com/xcode/)
- `cargo`, installed via [rustup](https://rustup.rs/)
- [swiftformat](https://github.com/nicklockwood/SwiftFormat)
- [just](https://github.com/casey/just)
- [xcbeautify](https://github.com/cpisciotta/xcbeautify)

For xcodebuild-backed `just` recipes, parsed output is shown in-terminal and raw/parsed logs are written under `build/logs/` with timestamped files plus `latest-*.log` aliases.

### Building

Builds and tests can also be run in Xcode GUI if you prefer.

#### Main App

`just build`

#### Formatting

`just format`

#### Tests

`just test` runs all the tests. Specify a simulator target like `just test 'iPhone 17 Pro'` (default) or `just test 'platform=iOS Simulator,id=<SIMULATOR_UDID>'`.

You can also run a specific test plan with `just test-plan MaruReaderCoreTests` or a single test with `just test-one 'MaruReaderCoreTests/SomeSuite/testExample()' MaruReaderCoreTests`.

Accepted device specifier formats:

- Simulator name: `'iPhone 17 Pro'`
- Simulator UDID: `76252478-5498-412D-9417-76009568896C`
- Raw xcodebuild destination: `'platform=iOS Simulator,id=76252478-5498-412D-9417-76009568896C'`

#### Content Blocker Extension

`just contentblocker`

This pulls the uBOL submodule and builds the extension with the latest filter lists. Extension persists for future builds unless you run `git submodule deinit`. Run again to build with updated filter lists.

#### Release build checklist

```bash
just contentblocker # Sync uBOL
just starterdict # Prepare the default jitendex and kanji-alive dictionaries
just licenses-refresh # Get acknowledgments for all dependencies
just screenshots # Generate new screenshots for App Store listing (writes to build/screenshots/)
```

### Agents

To save some frustration: If you want to work on MaruReader with a coding agent, I recommend getting a tool for docs searches, either the xcode one or [sosumi](https://sosumi.ai). Also make sure that xcodebuild-based `just` commands can be run outside any strict agent sandboxing, since they have to touch caches and such in your home folder. If you send a pull request you still have to review it manually first.

## Licensing Note

The GPLv3 license allows you to distribute copies or derivative works of MaruReader, provided you comply with all the terms. Distribition of derivative works without sharing the modified sources under the same license, or distribution of derivative works that bundle GPL-incompatible libraries, will not be tolerated.

If you have concerns about GPL compliance, please open a discussion.
