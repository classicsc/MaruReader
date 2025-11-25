# Maru

Tools to help you understand Japanese on iOS and iPadOS. Integrates a powerful Yomitan-compatible dictionary with an ebook reader. Send text or images from any app or a screenshot and look up any unfamiliar words in the dictionary. Even more features coming soon!

## Features

- **Powerful Dictionary Features**
  - Import any dictionary made for Yomichan or Yomitan, including dictionaries with advanced formatting like [Jitendex](https://jitendex.org/).
  - Choose the display order for dictionaries, great for multi dictionary users and grammar dictionaries.
  - Search text from any app: just highlight, and choose **Share -> Maru** from the context menu.
  - Can't highlight? Use the instant OCR feature. Take a screenshot and share it, then tap the text you want to read.
  - Deinflects and normalizes text with logic based on Yomitan's, much more advanced than the iOS system "Look Up" dictionary.
  - Add a frequency dictionary for even smarter result sorting.
- **Built In Ebook Reader**
  - Add any ePub file (convert other ebook formats with [Calibre](https://calibre-ebook.com/)).
  - Great Japanese support, including tategaki.
  - Tap any word to see the definitions in a compact popup. Tap inside the popup to open the full search page.

## Roadmap

Maru is still in the early stages. Before moving to publish it on the App Store for everyone, I plan to complete these features:

- **Ebook Reader Improvements**
  - **Support scrolling view**: in tategaki we shouldn't need to scroll up and down, so this will need some customization as the standard readium way doesn't work well. Will need UI toggles too.
  - **Font Customization**: Choose your favorite system font or add your own.
- **Dictionary Improvements**
  - **Customize the font** and font size for the dictionary search and popup.
  - Support getting **audio** from the network with settings for a Yomitan-compatible URL for definitions. (Anki prerequisite)
  - Support the display of **pitch-accent** and **IPA** phonetic data from dictionaries. (Anki prerequisite)
  - Support tapping **kanji** in definition headers to view data from kanji dictionaries and a stroke order diagram.
  - Add a toggle in the UI for whether to activate **links** on tap or just scan the text (the current behavior).
  - Polish the rough edges of the **styles** for dictionary content.
- **Furigana support**
  - Prerequiste for Anki, we need to run segmentation on sentences and retrieve the likely furigana which can be passed to the Anki field when needed. When provided in an epub, use the book's furigana.
- **Anki Support**
  - **AnkiConnect**: Configure an AnkiConnect URL to create cards with rich formatting and support for popular sentence mining card templates.
  - **AnkiMobile**: Send cards straight to the Anki iOS app, subject to URL limitations.
- **Improved image OCR views**
  - Support pan+zoom for large images.
  - Merge neighboring rects to keep sentence context together. Needs a heuristic to determine the probable text direction and exclude mismatches (signs in manga, shouldn't combine with neighboring speech, etc)
  - Try to guess tap location based on character level bounding.
  - Add a camera interface to capture directly.

While the above features are essential, I have some further ideas in mind that I may choose to complete before or after wide release:

- **OCR**
  - Build task-oriented interfaces like a manga reader.
  - Integrate with epub reading views to assist with embedded images.
- **Further Reader Customization**
  - Users would likely appreciate more themes, controls for font weight, and (better) control for page margins.
- **macOS**
  - While Mac users have better access to tools like Yomitan, the OCR functions would be helpful for games and videos. Specialized game interfaces for static text locations would be possible.
- **Deeper Anki Integration**
  - Maru should help unify card formatting and fix issues like missing furigana.

## Development

Guidelines:

- Adding extenal dependencies requires a good reason.
- Maru is built with Swift 6 strict concurrency checks.
- Test with Core Data concurrency checks as well (these are on by default in the Run destination and all test plans).
- Substantive changes to dictionary import and search pipelines require before/after profiling results. Stress test it with multiple large dictionaries and metadata dictionaries.
- While not essential for private methods, use DocC comments.
- Use `swiftformat` for style normalization.
- If you're adding logic, you should add test coverage at the same time. Maru uses the Swift Testing framework. UI is more fluid at this phase so there are no automated tests yet, but you must verify that your UI changes work.

### Building

For debugging:

```bash
xcodebuild -project MaruReader.xcodeproj -scheme MaruReader -destination generic/platform=iOS -configuration Debug build
```

For release:

```bash
xcodebuild -project MaruReader.xcodeproj -scheme MaruReader -destination generic/platform=iOS -configuration Release build
```

### Testing

Prefer running tests on a recent simulator to avoid xcode bugs. Currently I use the iPhone 17 Pro simulator.

Currently there are separate test plans for the dictionary functionality (MaruReaderCore) and the book reader (MaruReader).

```bash
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderTests
xcodebuild test -scheme MaruReaderCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderCoreTests
```
