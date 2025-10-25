# Maru

Tools to help you understand Japanese on iOS and iPadOS. Integrates a powerful Yomitan-compatible dictionary with an ebook reader. Share text from any app and look up any unfamiliar words in the dictionary. Even more features coming soon!

## Features

- **Powerful Dictionary Features**
  - Import any dictionary made for Yomichan or Yomitan, including dictionaries with advanced formatting like [Jitendex](https://jitendex.org/).
  - Choose the display order for dictionaries, great for multi dictionary users and grammar dictionaries.
  - Search text from any app: just highlight, and choose **Share -> Maru** from the context menu.
  - Deinflects and normalizes text with logic based on Yomitan's, much more advanced than the iOS system "Look Up" dictionary.
  - Add a frequency dictionary for even smarter result sorting.
- **Built In Ebook Reader**
  - Add any ePub file (convert other ebook formats with [Calibre](https://calibre-ebook.com/)).
  - Great Japanese support, including tategaki.
  - Tap any word to see the definitions in a compact popup. Tap inside the popup to open the full search page.

## Roadmap

Maru is still in the early stages. Before moving to publish it on the App Store for everyone, I plan to complete these features:

- **Optimized dictionary search UI** for searching full sentences: search a sentence (or more!) and see it in larger text with furigana. Tap a word to see the search results.
- **Ebook Reader Improvements**
  - **Optimize the scrolling view**: in tategaki we shouldn't need to scroll up and down.
  - Add custom support for **paged view with vertical text**.
  - **Font Customization**: Choose your favorite system font or add your own.
- **Dictionary Improvements**
  - **Customize the font** and font size for the dictionary search and popup.
  - Support getting **audio** from the network with settings for a Yomitan-compatible URL for definitions.
  - Support the display of **pitch-accent** and **IPA** phonetic data from dictionaries, as well as **frequency information**.
  - Support tapping **kanji** in definition headers to view data from kanji dictionaries and a stroke order diagram.
  - Add a toggle in the UI for whether to activate **links** on tap or just scan the text (the current behavior).
  - Polish the rough edges of the **styles** for dictionary content.
- **Anki Support**
  - **AnkiConnect**: Configure an AnkiConnect URL to create cards with rich formatting and support for popular sentence mining card templates.
  - **AnkiMobile**: Send basic cards straight to the Anki iOS app.

While the above features are essential, I have some further ideas in mind that I may choose to complete before or after wide release:

- **OCR**
  - iOS has pretty good built in vision APIs, there needs to be a more learning-oriented interface around them.
  - For a proof of concept, build an interface for looking at a single image and test with screenshots of webpages and photos of book/manga pages with both horizontal and vertical text.
  - If this succeeds, build task-oriented interfaces like a new view for the share extension, a manga reader, and a camera view.
- **Further Reader Customization**
  - Users would likely appreciate more themes, controls for font weight, and (better) control for page margins.
- **macOS**
  - While Mac users have better access to tools like Yomitan, if the OCR implementation succeeds it would be useful on macOS.
- **Deeper Anki Integration**
  - Maru should help unify card formatting and fix issues like missing furigana.

## Development

Contributions are welcome. Key guidelines:

- Adding extenal dependencies requires a good reason.
- Maru is built with Swift 6 strict concurrency checks.
- Make sure to enable Core Data concurrency checks as well in your testing (these are on by default in the Run destination and all test plans).
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
