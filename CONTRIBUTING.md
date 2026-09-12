# MaruReader Contributing Guide

Thanks for your interest in helping to improve MaruReader!

For general feedback, feature requests, and bug reports, use the Discussions
tab.

If you have a definite bug and know how to fix it, feel free to submit a PR
directly. For larger features or if you're unsure about the best approach,
please open an issue.

Before sending a PR, make sure it passes the unit tests, run `swiftformat`, and
if possible, include new test coverage.

## Development

For development, these tools are required:

- [Xcode 26+](https://developer.apple.com/xcode/)
- `cargo`, installed via [rustup](https://rustup.rs/)
- [swiftformat](https://github.com/nicklockwood/SwiftFormat)
- [just](https://github.com/casey/just)
- [xcbeautify](https://github.com/cpisciotta/xcbeautify)

For xcodebuild-backed `just` recipes, parsed output is shown in-terminal and
raw/parsed logs are written under `build/logs/` with timestamped files plus
`latest-*.log` aliases.

### Building

Builds and tests can also be run in Xcode GUI if you prefer.

#### Main App

`just build`

#### Formatting

`just format`

When editing docs, please run mdformat:

```bash
pipx install mdformat
pipx inject mdformat mdformat-gfm mdformat-frontmatter mdformat-footnote mdformat-gfm-alerts
mdformat .
```

#### Tests

Run a specific test plan with `just test-plan MaruReaderCoreTests`, or
`just test` to run all tests. Specify a simulator target like
`just test-plan MaruReaderCoreTests 'iPhone 17 Pro'` (default) or
`just test 'platform=iOS Simulator,id=<SIMULATOR_UDID>'`. Or a single test with
`just test-one 'MaruReaderCoreTests/SomeSuite/testExample()' MaruReaderCoreTests`.

Accepted device specifier formats:

- Simulator name: `'iPhone 17 Pro'`
- Simulator UDID: `76252478-5498-412D-9417-76009568896C`
- Raw xcodebuild destination:
  `'platform=iOS Simulator,id=76252478-5498-412D-9417-76009568896C'`

### Agents

If you have a Mac and are comfortable setting up the iOS development tools, a
free or inexpensive coding agent subscription makes it extremely easy to create
your own version of MaruReader customized however you like. Today's tools don't
even require configuration advice I used to list in this section. If you send a
pull request to merge your changes into my version, you still have to review the
code manually first.

### Release build checklist

For building an archive to run on your own devices, Archive the MaruReader
scheme in Xcode.

I use Xcode Cloud to simplify the process for builds destined for TestFlight and
the App Store. `just` commands to trigger this:

```bash
just prerelease 1.2.2  # Set marketing version; push v1.2.2-rc.1
just prerelease        # Keep version; push v1.2.2-rc.2
just release           # Keep version; push v1.2.2
# Or: just release 1.2.3
```

Only run this from a clean checkout of `main` where GH Actions checks are
passing. This will fetch tags from `origin`, synchronize the marketing version
across MaruReader, MaruShareExtension, and MaruAssetDownloader, create a commit
and an annotated tag, then push only that tag.

When releasing a new version for the App Store, prepare the supporting assets.

```bash
just starterdict # Prepare the default dictionaries. Upload the resulting build/starterdict.aar via Transporter
just screenshots # Generate new screenshots for App Store listing if needed (writes to build/screenshots/)
```

## Licensing Note

If you distribute a derivative work, note that the `just starterdict` output is
not under the same license due to the BCCWJ (CC-BY-NC) and Wadoku (incompatible
custom license). This project distributes the package as a separate App
Store-managed asset.
