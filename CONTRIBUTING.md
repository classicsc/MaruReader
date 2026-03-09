# MaruReader Contributing Guide

Thanks for your interest in helping to improve MaruReader!

If you have a definite bug and know how to fix it, feel free to submit a PR directly. For larger features or if you're unsure about the best approach, please open an issue for discussion.

All PRs need to pass the unit tests, and within the bounds of common sense, need to include new unit tests proving that the changes work.

## Development

For development, these tools are required:

- [Xcode 26+](https://developer.apple.com/xcode/)
- [swiftformat](https://github.com/nicklockwood/SwiftFormat)
- [just](https://github.com/casey/just)
- [xcbeautify](https://github.com/cpisciotta/xcbeautify)

For xcodebuild-backed `just` recipes, parsed output is shown in-terminal and raw/parsed logs are written under `build/logs/` with timestamped files plus `latest-*.log` aliases.

### Building

#### Content Blocker Extension

`just contentblocker`

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

#### Release build checklist

```bash
just contentblocker # Sync the latest uBOL code and filter lists
just starterdict # Prepare the default jitendex and kanji-alive dictionaries
just licenses-refresh
just licenses # Get acknowledgments for all dependencies
just screenshots # Generate new screenshots for App Store listing (requires fastlane installed)
```

### Agents

The repo includes a basic AGENTS.md/CLAUDE.md file that attempts to get coding agents on the right track with build commands and API availibility. It intentionally doesn't include any kind of structural overview, because that burdens the context window and is better learned through targeted exploration.

You're welcome to use coding agents to help with PRs, but you are still responsible for ensuring that the code is sensible, passes tests, etc. Recommended development style is "AI-assisted", not "vibe coded".

## GPLv3 Note

It is the author's opinion that app store distribution of GPLv3 software is in accordance with the spirit of the license, provided the rights granted by GPLv3 are not unfairly limited. For example, MaruReader publishes its source code, build instructions, and release artifacts on GitHub; these are not subject to Apple or third-party app store EULAs.

By contributing, you acknowledge that MaruReader and any forks can be distributed on app stores, provided they comply with the license terms. If you have concerns about GPL compliance, please open an issue to discuss.
