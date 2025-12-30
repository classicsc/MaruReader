# Maru

Tools to help you understand Japanese on iOS and iPadOS. Integrates a powerful Yomitan-compatible dictionary with an ebook reader. Send text or images from any app or a screenshot and look up any unfamiliar words in the dictionary. Instantly create Anki notes with rich context so you won't forget.

## Features

- **Powerful Dictionary Features**
  - Import any dictionary made for Yomichan or Yomitan, including dictionaries with advanced formatting like [Jitendex](https://jitendex.org/).
  - Choose the display order for dictionaries, great for multi dictionary users and grammar dictionaries.
  - Search text from any app: just highlight a word or sentence, and choose **Share -> Maru** from the context menu.
  - Can't highlight? Use the instant OCR feature. Take a screenshot and share it, then tap the text you want to read.
  - Deinflects and normalizes text with logic based on Yomitan's, generally this is more reliable than the iOS system "Look Up" dictionary.
  - Add a frequency dictionary for even smarter result sorting.
  - Add audio sources (compatible with Yomitan-style network URLs and AJT-style ZIPs) to hear pronunciation.
- **Built In Ebook Reader**
  - Add any ePub file (convert other ebook formats with [Calibre](https://calibre-ebook.com/)).
  - Great Japanese support, including tategaki.
  - Tap any word to see the definitions in a compact popup. Tap inside the popup to open the full search page.
- **Supports Anki Sentence Mining Workflows**
  - Use Anki-Connect (needs to be proxied with HTTPS) on your PC to add notes direct to your mining deck. Customize field mapping to work with your favorite note type.
  - Sentence furigana generated using MeCab for accuracy.

## Roadmap

Maru is still in the early stages. Before moving to publish it on the App Store for everyone, I plan to complete these features:

- **Ebook Reader Improvements**
  - **Support scrolling view**: in tategaki we shouldn't need to scroll up and down, so this will need some customization as the standard readium way doesn't work well. Will need UI toggles too.
  - **Font Customization**: Choose your favorite system font or add your own.
- **Dictionary Improvements**
  - Support tapping **kanji** in definition headers to view data from kanji dictionaries and a stroke order diagram.
  - Add a toggle in the UI for whether to activate **links** on tap or just scan the text (the current behavior).
  - Polish the rough edges of the **styles** for dictionary content, including support for dictionary stylesheets.
- **Anki Support**
  - **AnkiMobile**: Send cards straight to the Anki iOS app, subject to URL limitations.
  - **APKG**: Look into queueing and exporting notes to a file for more flexibility.
- **Improved image OCR views**
  - Merge neighboring rects to keep sentence context together. Needs a heuristic to determine the probable text direction and exclude mismatches (signs in manga, shouldn't combine with neighboring speech, etc)
  - Try to guess tap location based on character level bounding.
  - Add a camera interface to capture directly.

While the above features are essential, I have some further ideas in mind that I may choose to complete before or after wide release:

- **OCR**
  - Build task-oriented interfaces like a manga reader.
  - Integrate with epub reading views to assist with embedded images.
- **Further Reader Customization**
  - Would be nice to have more themes, controls for font weight, and (better) control for page margins.
- **macOS**
  - While Mac users have better access to tools like Yomitan, the OCR functions would be helpful for games and videos. Specialized game interfaces for static text locations would be possible.
- **Deeper Anki Integration**
  - Maru should be able to help unify card formatting and fix issues like missing audio and furigana when using Anki-Connect.

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

Currently there are separate test plans for the dictionary functionality (MaruReaderCore), the book reader (MaruReader), and Anki functionality (MaruAnki).

```bash
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderTests
xcodebuild test -scheme MaruReaderCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderCoreTests
```
