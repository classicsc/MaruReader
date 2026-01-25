# Maru

Maru is a dictionary and reading application for people learning Japanese, which runs on iOS and iPadOS. You can look up unfamiliar words across multiple dictionaries (Yomitan format) with just a tap while reading eBooks, manga, and websites. You can even snap a photo of text or take a screenshot of another app and look it up. When you want to commit a new term to memory, instantly create an Anki note with rich formatting and full context.

## Key Features

### Dictionary System

- **Yomitan Dictionary Format Support**
  - Maru uses the same powerful dictionary format as [Yomitan](https://yomitan.wiki/).
  - Frequency and pitch accent dictionaries for Yomitan can also be used.
  - Add as many custom dictionaries as you like, search is fast even with many large dictionaries.
- **Search Within Definitions** Tap on words in dictionary definitions to search in a compact popup, and tap in the popup to open those results in the full dictionary search page. This is a must-have feature for learners using monolingual (Japanese-Japanese) dictionaries.
- **Pronunciation Audio** Configure an audio server (Yomitan custom URL format), or go offline with an audio ZIP (AJT Japanese format).

### Manga Reader

- **On-device text recognition (OCR)** Maru uses your device's built-in text recognition capabilities to read text on manga pages with no need for pre-processing or specialized file formats, just add any ZIP/CBZ and start reading. Tap on the text you want to look up, and it will open alongside the page. Auto-generated furigana can also be displayed on the lookup page.
- **Smart Metadata** On devices with Apple Intelligence supported and enabled, the title and author displayed in the manga library can be extracted from filenames with no specific naming scheme or special metadata file needed.

### Book Reader

- **Optimized for Japanese eBooks** Maru displays books with vertical text (tategaki) and and a nice mincho/serif font with great legibility on phone screens. Can be customized with light/dark mode following system, font size, and page margin adjustment.
- **Compact dictionary popup search** In the book reader, tapping on text opens a compact popup for the specific word you tapped, keeping you closer to the book.

### Web Browser

- **Text recognition for web-based content** You can use Maru even without offline books and manga. Open what you want to read online in the built-in web browser. Activate reading mode and tap on text to look it up using the same text recognition system used by the manga reader.
- **Reading Mode Controls** Reading mode disables links when active, but you can turn pages on most eBook and manga sites by swiping to simulate a key press. For articles or scrolling readers, switch to scroll mode and swipe to scroll by a fixed amount.
- **Built-in content blocker** The web browser has a built-in content blocker, so you can read with fewer distracting ads and trackers.

### Photo Scanner

- **Text Recognition for Anything** Whether you need to look up a word from a sign or menu in Japan, a screenshot of an app or game, or anything else, the photo scanner has your back. Snap or import a photo from the Scan tab, or share from another app. Just like the manga reader, tap on text to look up.

### Anki Integration

- **AnkiMobile Integration** Maru can add notes to the AnkiMobile app by tapping the "+" button in any dictionary lookup context. Includes a built-in configuration for the highly recommended [Lapis](https://github.com/donkuri/lapis) notetype, and fully customizable note fields.
- **Anki-Connect Integration** Advanced users also have Anki-Connect as an option. This has some benefits including customizable duplicate note detection and the ability to add notes faster and directly from the share menu, but requires some more involved setup.

## Development

### Building

First, clone this repository. Before building the app, you need to build the web viewer's content blocker extension:

```bash
git submodule update --init --recursive
./scripts/prepare-ubol.sh
```

If the build went well, you should see a `uBOLite.safari` folder under `External/uBlock/dist/build`. Then build the app in XCode.

For command line builds:

```bash
xcodebuild -project MaruReader.xcodeproj -scheme MaruReader -destination generic/platform=iOS -configuration Debug build
```

### Testing and formatting

If you plan to send a pull request, please run [swiftformat](https://github.com/nicklockwood/SwiftFormat) on the files you added or changed for consistency.

You must also ensure your changes pass the unit tests, or update the tests if you're changing the expected behavior. Tests are generally written with Swift Testing and run with XCode test plans, organized according to the framework structure. For example, to run all the tests from the command line, you could run:

```bash
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderTests
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderCoreTests
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruMangaTests
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruAnkiTests
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruWebTests
```

## License and Acknowledgements

Maru is free software licensed to you under the GNU General Public License, version 3. I'd like to particularly thank the following projects:

| Project name | Author | Source Code |
| ----------- | ----------- | ----------- |
| Jitendex | Stephen Kraus | [Project Homepage](https://jitendex.org/) |
| Yomitan | Yomitan Authors | [GitHub](https://github.com/yomidevs/yomitan). Maru files derived from Yomitan are clearly marked in the header. |
| Mecab-Swift | telethon k.k. | [GitHub](https://github.com/shinjukunian/Mecab-Swift) |
| mecab-ipadic | Taku Kudo, Masayuki Asahara, Yuji Matsumoto | [GitHub](https://github.com/taku910/mecab/tree/master/mecab-ipadic) |
| Readium Swift Toolkit | Readium Foundation | [GitHub](https://github.com/readium/swift-toolkit) |
| json-stream | Topolyte Limited | [GitHub](https://github.com/Topolyte/json-stream) |
| swift-async-algorithms | Apple Inc. and the Swift project authors | [GitHub](https://github.com/apple/swift-async-algorithms) |
| ZIP Foundation | Thomas Zoechling | [GitHub](https://github.com/readium/ZIPFoundation) |
| uBlock Origin Lite | Raymond Hill | [GitHub](https://github.com/gorhill/uBlock). Maru uses a modified ruleset configuration from the `External` directory of this repository. |
| uBlock filters | Raymond Hill | [GitHub](https://github.com/uBlockOrigin/uAssets) |
| EasyList + EasyPrivacy | [The EasyList authors](https://easylist.to/index.html) | [GitHub](https://github.com/uBlockOrigin/uAssets) |
| AdGuard Mobile + AdGuard Japanese | AdGuard | [GitHub](https://github.com/AdguardTeam/AdguardFilters) |

Full acknowledgements and software licenses can be reviewed in the About section of the Settings tab in the app.
