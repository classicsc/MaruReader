# MaruReader

MaruReader is a free, open source dictionary and reading application for learning Japanese, which runs on iOS and iPadOS. You can use MaruReader to look up unfamiliar words across multiple dictionaries while reading eBooks, manga, and websites, or even from photos and screenshots. When you want to commit a new term to memory, instantly create an Anki note with rich formatting and full context.

## Key Features

### Dictionary System

- **Built-in Japanese-English dictionary** The included Jitendex dictionary features clear definitions, examples, and variant form tables.
- **Pronunciation Audio** Over 10,000 audio clips included thanks to the Kanji alive project. If you need more, connect to an audio server (Yomitan custom URL compatible), or go offline with an audio ZIP (AJT Japanese plugin compatible). See the Pronunciation Audio guide for details.
- **Yomitan Dictionary Format Support**
  - MaruReader uses the same dictionary format as [Yomitan](https://yomitan.wiki/). Check out its website or search the web for more dictionaries.
  - Frequency and pitch accent dictionaries for Yomitan can also be used.
  - Add as many custom dictionaries as you like, search is fast even with many large dictionaries.
- **Search Within Definitions** Tap on words in dictionary definitions to search in a compact popup, and tap in the popup to open those results in the full dictionary search page. This is a must-have feature for learners using monolingual (Japanese-Japanese) dictionaries.

### Manga Reader

- **On-device text recognition (OCR)** MaruReader uses your device's built-in text recognition capabilities to read text on manga pages with no need for pre-processing or specialized file formats, just add any ZIP/CBZ and start reading. Tap on the text you want to look up, and it will open alongside the page. Auto-generated furigana can also be displayed on the lookup page.
- **Smart Metadata** On devices with Apple Intelligence supported and enabled, the title and author displayed in the manga library can be extracted from filenames with no specific naming scheme or special metadata file needed.

### Book Reader

- **Optimized for Japanese eBooks** MaruReader displays books with vertical text (tategaki) and and a nice mincho/serif font with great legibility on phone screens. Light/dark mode follows system.
- **Compact dictionary popup search** In the book reader, tapping on text opens a compact popup for the specific word you tapped, keeping you closer to the book.

### Web Browser

- **Text recognition for web-based content** You can use MaruReader even without offline books and manga. Open what you want to read online in the built-in web browser. Activate reading mode and tap on text to look it up using the same text recognition system used by the manga reader.
- **Reading Mode Controls** Reading mode disables links when active, but you can turn pages on most eBook and manga sites by swiping to simulate a key press. For articles or scrolling readers, switch to scroll mode and swipe to scroll by a fixed amount.
- **Content blocker** The web browser has a content blocker with general and Japan-specific filters, so you can read with fewer distracting ads and trackers.

### Photo Scanner

- **Text Recognition for Everything Else** Whether you need to look up a word from a sign or menu in Japan, a screenshot of an app or game, or anything else, the photo scanner has your back. Snap or import a photo from the Scan tab, or share from another app.

### Anki Integration

- **AnkiMobile Integration** MaruReader can add notes to the AnkiMobile app by tapping the "+" button in any dictionary lookup context. Includes built-in configuration for some popular note types, and the ability to configure your own note fields.
- **Anki-Connect Integration** Advanced users also have Anki-Connect as an option. This has some benefits including customizable duplicate note detection.

## FAQ

### How do I learn Japanese?

There are many different answers, but many people find they make the fastest progress on reading comprehension when constantly immersed in native reading material, as opposed to studying kanji or learning from textbooks. The point of MaruReader is to put a powerful dictionary at your fingertips to reduce the tedium of looking up unfamiliar words while reading, which can be a challenge for beginners to Japanese. For more comprehensive advice, it may help to refer to immersion-focused guides like AJATT, but it's more important to simply read more books rather than take anything in these guides as gospel.

### What should I read?

MaruReader intentionally does not come with any starter reading materials, because it's better to read what you're actually interested in reading. However, it can be helpful to look through materials arranged by level to find something interesting that is just above your current skill level. There are many guides and databases online for this purpose.

### Can MaruReader read eBooks in non-epub formats like Aozora?

Not directly, but most non-DRM ebook formats can be converted to epub with [Calibre](https://calibre-ebook.com). For aozora specifically, [AozoraEpub3](https://aozoraepub3-jdk21.github.io/AozoraEpub3-JDK21/en/usage.html) works well.

### Can MaruReader open manga in PDF or EPUB formats?

Not yet, but you can use Calibre to convert to CBZ.

### The text recognition got a character wrong in my manga!

Text recognition can always produce errors. MaruReader uses on-device text recognition to provide convenience, privacy, and pretty good accuracy, but it won't be as accurate as cloud services.

All is not lost, however. If you know how to type the correct character, you can use the pen icon at the bottom of the dictionary sheet to edit the context before looking up the word again or creating an Anki note.

### I have a particular EPUB where the layout looks off and tapping the text doesn't work

Certain epubs, mostly older ones or PDF conversions, lack adjustable layout and might even contain pictures of each page instead of text. These are mostly untested and unlikely to display correctly. This may be improved in the future, for now try to find a newer version of the same book.

### Does MaruReader support Yomitan dictionaries with structured-content?

Yes.

### I have a dictionary that looks very different (worse) compared to Yomitan

- Some dictionaries use styled dingbat characters like `→` for purposes like indicating links, and on iOS these are displayed using the emoji font which can look wrong. There is no real fix for this. Dictionaries should use .svg files when it's important for a symbol to always look the same across different browsers and operating systems.
- MaruReader supports the `styles.css` at the dictionary root, but there's no equivalent to Yomitan's custom popup CSS settings. If you use custom styles, that could be the difference. A workaround is to append your custom styles to `styles.css` and re-import the dictionary.
- Otherwise, there are probably still display bugs in MaruReader and you may have found one. Please open an issue, specifying the dictionary and an entry with the problem, so it can be investigated.

### How do I use MaruReader with Anki?

The Anki integrations are designed to support mining, which is the process of reading and creating flashcards for unfamiliar words. See the Anki guide for full details.

MaruReader can work with many of the same mining setups as Yomitan, the main limitation being that MaruReader cannot use custom handlebars, only a set of values that roughly corresponds to Yomitan's default handlebars. If your workflow requires custom handlebars or some other feature that is missing, open an issue so we can look at whether it can be supported.

### Formatting looks wrong on my Anki cards

Make sure you are using the latest version of Anki, as older versions have issues with styled content. Otherwise, see the Anki Guide for more troubleshooting steps.

### Is iOS 26+ really required?

Yes, MaruReader relies on certain iOS 26 APIs for displaying HTML content and the user interface.

### Why is it called MaruReader?

It was mostly chosen at random, one reason is that Maru a good name for a mascot.

### I have a question or issue that isn't answered here, or a suggestion

Please open an issue. For problems, include as many specifics as possible: the dictionary/book/website, a screenshot of the problem, steps to make it happen, etc.

## Development

### Building

#### Content Blocker Extension

```bash
git submodule update --init --recursive

./scripts/prepare-ubol.sh
```

If the build went well, you should see a `uBOLite.safari` folder under `External/uBlock/dist/build`.

#### Starter Dictionaries (optional)

This is only needed if you want to distribute the app with preloaded dictionaries.

Build the dictionary seeder tool and run it with an output folder and one or more valid yomitan dictionaries. Audio ZIPs are given with `--audio`.

```bash
xcodebuild -project MaruReader.xcodeproj -scheme DictionarySeeder -destination generic/platform=macOS -configuration Debug build

./DerivedData/MaruReader/Build/Products/Debug/DictionarySeeder MaruReader/StarterDictionary /path/to/jitendex-yomitan.zip --audio /path/to/kanji-alive.zip
```

The app checks for `MaruDictionary.sqlite` and the `AudioMedia` and `Media` directories in `MaruReader/StarterDictionary` whenever there is no existing database.

#### Main App

```bash
xcodebuild -project MaruReader.xcodeproj -scheme MaruReader -destination generic/platform=iOS -configuration Debug build
```

### Testing and formatting

If you plan to send a pull request, please run [swiftformat](https://github.com/nicklockwood/SwiftFormat) on the files you added or changed for consistency.

Tests are generally written with Swift Testing and organized with XCode test plans according to the framework structure. For example, to run all the tests from the command line, you could run:

```bash
xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderTests

xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruReaderCoreTests

xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruMangaTests

xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruAnkiTests

xcodebuild test -scheme MaruReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan MaruWebTests
```

## Third-party credits

MaruReader is made with the content and libraries listed below. Thank you!

| Project name | Author | Source Code |
| ----------- | ----------- | ----------- |
| Jitendex | Stephen Kraus | [Project Homepage](https://jitendex.org/) |
| Kanji alive | Harumi Hibino Lory & Arno Bosse | [GitHub](https://github.com/kanjialive/kanji-data-media?tab=readme-ov-file) |
| Yomitan | Yomitan Authors | [GitHub](https://github.com/yomidevs/yomitan). MaruReader files derived from Yomitan are marked in the header. |
| Mecab-Swift | telethon k.k. | [GitHub](https://github.com/shinjukunian/Mecab-Swift) |
| mecab-ipadic | Taku Kudo, Masayuki Asahara, Yuji Matsumoto | [GitHub](https://github.com/taku910/mecab/tree/master/mecab-ipadic) |
| Readium Swift Toolkit | Readium Foundation | [GitHub](https://github.com/readium/swift-toolkit) |
| json-stream | Topolyte Limited | [GitHub](https://github.com/Topolyte/json-stream) |
| swift-async-algorithms | Apple Inc. and the Swift project authors | [GitHub](https://github.com/apple/swift-async-algorithms) |
| ZIP Foundation | Thomas Zoechling | [GitHub](https://github.com/readium/ZIPFoundation) |
| uBlock Origin Lite | Raymond Hill | [GitHub](https://github.com/gorhill/uBlock). MaruReader uses a modified ruleset configuration from the `External` directory of this repository. |
| uBlock filters | Raymond Hill | [GitHub](https://github.com/uBlockOrigin/uAssets) |
| EasyList + EasyPrivacy | [The EasyList authors](https://easylist.to/index.html) | [GitHub](https://github.com/uBlockOrigin/uAssets) |
| AdGuard Mobile + AdGuard Japanese | AdGuard | [GitHub](https://github.com/AdguardTeam/AdguardFilters) |
