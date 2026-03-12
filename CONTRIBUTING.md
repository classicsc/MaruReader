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

This pulls the uBOL submodule and builds the extension with the latest filter lists. Extension persists for future builds unless you run `git submodule deinit`. Run again to build with updated source and filter lists.

#### Release build checklist

```bash
just contentblocker # Sync the latest uBOL code and filter lists
just starterdict # Prepare the default jitendex and kanji-alive dictionaries
just licenses-refresh
just licenses # Get acknowledgments for all dependencies
just screenshots # Generate new screenshots for App Store listing (requires fastlane installed)
```

### Agents

Much of MaruReader was made using coding agents! Specifically, the initial translation to Swift of deinflection and test code from Yomitan, dictionary HTML generation, the WebKit parts of MaruWeb, most of the MaruAnki framework, and most of the JP localization were made using agents, albeit with strict steering and review. I'm not against anyone sending AI-assisted pull requests if they're good, but manually ensuring that the patch is sensible, self-contained and not massive, passes tests, actually works in practice, etc, is just good manners. Development style is "AI-assisted", not "vibe coded".

If you want to work on MaruReader with a coding agent, I recommend getting the [sosumi docs search MCP](https://sosumi.ai) and the [xcodebuildmcp UI automation CLI](https://github.com/getsentry/XcodeBuildMCP) (confusingly, the best way to use it is with the CLI, not an actual MCP daemon). Also make sure that xcodebuild-based `just` commands and `xcodebuildmcp` (if you're using it) can be run outside any strict agent sandboxing, since they have to touch caches and such in your home folder.

## Licensing Note

I've seen a lot of developers of OSS apps for iOS complain about their apps getting ripped off, so I will say some things up front to hopefully discourage anyone from making a noncompliant version of MaruReader.

- MaruReader is licensed under GPLv3. This is not a permisssive type license like MIT, it carries obligations you have to follow or lose it
- If you distribute a derivative work, incorporate all or part of MaruReader into your app, or put something that is derived from or includes MaruReader on the Apple App Store or a third-party app store, you must comply with the GPLv3 terms
  - It's not very long, reading the whole thing is a good idea
- See sections 5 and 6 of the license for some specific obligations. MaruReader follows these by:
  - Licensing under GPLv3 (5c)
  - Carrying all the proper notices in the About section of the GUI (5a, 5b, 5d)
  - Source code corresponding to each release can be accessed from a designated place (GitHub Releases), linked from the App Store page and the GUI (6d), and I'll ensure this stays available at least as long as the app is offered on the App Store or somewhere else
  - MaruReader does not use any libraries or assets with incompatible licenses, aside from system libraries

If you have concerns about GPL compliance, please open an issue to discuss.
