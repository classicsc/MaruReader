# MaruReader Contributing Guide

Thanks for your interest in helping to improve MaruReader!

For general feedback, feature requests, and bug reports, use the Discussions tab.

If you have a definite bug and know how to fix it, feel free to submit a PR directly. For larger features or if you're unsure about the best approach, please open an issue.

Before sending a PR, make sure it passes the unit tests, run `swiftformat`, and if possible, include new test coverage.

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

Run a specific test plan with `just test-plan MaruReaderCoreTests`, or `just test` to run all tests. Specify a simulator target like `just test-plan MaruReaderCoreTests 'iPhone 17 Pro'` (default) or `just test 'platform=iOS Simulator,id=<SIMULATOR_UDID>'`. Or a single test with `just test-one 'MaruReaderCoreTests/SomeSuite/testExample()' MaruReaderCoreTests`.

Accepted device specifier formats:

- Simulator name: `'iPhone 17 Pro'`
- Simulator UDID: `76252478-5498-412D-9417-76009568896C`
- Raw xcodebuild destination: `'platform=iOS Simulator,id=76252478-5498-412D-9417-76009568896C'`

#### Content Blocker Extension

`just contentblocker`

This pulls the uBOL submodule and builds the extension with the latest filter lists. Extension persists for future builds unless you run `git submodule deinit`. Run again to build with updated filter lists.

#### Release build checklist

```bash
just starterdict # Prepare the default jitendex and kanji-alive dictionaries. Upload the resulting build/starterdict.aar via Transporter
# one of:
# just prerelease: creates a prerelease archive by incrementing the build number, then commits and tags it
# just release <version>: creates a release archive by setting the marketing version, resetting build to 1, then commits and tags it
just screenshots # Generate new screenshots for App Store listing if needed (writes to build/screenshots/)
```

### Agents

To save some frustration: If you want to work on MaruReader with a coding agent, I recommend getting a tool for docs searches, either the xcode one or [sosumi](https://sosumi.ai). Also make sure that xcodebuild-based `just` commands can be run outside any strict agent sandboxing, since they have to touch caches and such in your home folder. If you send a pull request you still have to review it manually first.

## Licensing Note

If you distribute a derivative work, note that the `just starterdict` output is not GPL3 due to the BCCWJ (CC-BY-NC) and Wadoku (incompatible custom license). This project distributes the package as a separate App Store-managed asset.

If you have questions or concerns about GPL compliance, please open a discussion.
