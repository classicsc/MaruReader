# MaruReader

MaruReader is a free, open source dictionary and reading application for learning Japanese, which runs on iOS and iPadOS. You can use MaruReader to look up unfamiliar words across multiple dictionaries while reading eBooks, manga, and websites, or even from photos and screenshots. When you want to commit a new term to memory, instantly create an Anki note with rich formatting and full context.

## Key Features

### Dictionary System

- **Built-in Japanese-English dictionary** The included Jitendex dictionary features clear definitions, examples, and variant form tables.
- **Pronunciation Audio** Over 10,000 audio clips included. See the Pronunciation Audio guide for instructions on adding additional audio or network sources.
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
- **Content blocker** The web browser has a content blocker with general and Japan-specific filters, so you can read with fewer distracting ads and trackers.

### Photo Scanner

- **Text Recognition for Everything Else** Whether you need to look up a word from a sign or menu in Japan, a screenshot of an app or game, or anything else, the photo scanner has your back. Snap or import a photo from the Scan tab, or share from another app.

### Anki Integration

- **AnkiMobile Integration** MaruReader can add notes to the AnkiMobile app by tapping the "+" button in any dictionary lookup context. Includes built-in configuration for Lapis, and the ability to configure your own note fields for other note types.
- **Anki-Connect Integration** Advanced users also have Anki-Connect as an option. This has some benefits including customizable duplicate note detection.

## FAQ

### How do I learn Japanese?

It's too big a question to answer here, but generally language ability is a muscle you have to use. To get better at reading, getting lots of practice with reading real books usually yields better results than studying individual kanji or textbook examples. Through the sentence mining technique, you create flashcards to help with memorizing new vocabulary and grammar from real contexts. MaruReader is meant to make this practice more efficient by putting a high quality learning dictionary system at your fingertips while reading, and automating the process of creating flashcards with the Anki integration.

### What should I read?

MaruReader intentionally does not come with any starter reading materials, because it's better to read what you're actually interested in reading. There are many guides, databases, and listicles online with books and manga organized by level.

### Can MaruReader open eBooks in non-epub formats like Aozora?

No, but most non-DRM ebook formats can be converted to epub with [Calibre](https://calibre-ebook.com). For aozora specifically, [AozoraEpub3](https://aozoraepub3-jdk21.github.io/AozoraEpub3-JDK21/en/usage.html) works well.

### Can MaruReader open manga in PDF or EPUB formats?

No, but you can use Calibre to convert to CBZ.

### The text recognition got a character wrong in my manga!

Text recognition can always produce errors. MaruReader uses on-device text recognition to provide convenience, privacy, and pretty good accuracy, but it won't be as accurate as cloud services.

All is not lost, however. If you know how to type the correct character, you can use the pen icon at the bottom of the dictionary sheet to edit the context before looking up the word again or creating an Anki note.

For the web browser specifically, accuracy can be improved by zooming in on the text you are trying to read. This will not help with the manga reader.

### I have a particular EPUB where the layout looks off and tapping the text doesn't work

It might be a fixed-layout EPUB. Certain books, mostly older ones or PDF conversions, lack adjustable layout and might even contain pictures of each page instead of text. If a newer digital edition of the same book is available, it might work better in MaruReader.

### Does MaruReader support Yomitan dictionaries with structured-content?

Yes.

### I have a dictionary that looks very different (worse) compared to Yomitan

- Some dictionaries use dingbat characters like `→` for purposes like indicating links, and on iOS some of these symbols are displayed as color emoji instead of the shape and color the dictionary's creator intended. This can be fixed in some cases by modifying the dictionary's stylesheet, but the better solution is for the dictionary to use images instead of Unicode characters for symbols that need to look the same on all platforms.
- MaruReader supports the `styles.css` at the dictionary root, but there's no equivalent to Yomitan's custom popup CSS settings. If you use custom styles on desktop, that could be the difference. A workaround is to add your custom styles to the dictionary's `styles.css` and re-import the dictionary.
- Otherwise, it may be a bug in MaruReader. Please open an issue, specifying the dictionary and an entry with the problem, so it can be investigated.

### How do I use MaruReader with Anki?

The Anki integrations are designed to support mining, which is the process of reading and creating flashcards for unfamiliar words. See the Anki guide for full details.

MaruReader can work with many of the same mining setups as Yomitan, the main limitation being that MaruReader cannot use custom handlebars, only a set of values that roughly corresponds to Yomitan's default handlebars. If your workflow requires custom handlebars or some other feature that is missing, open an issue so we can look at whether it can be supported.

### Formatting looks wrong on my Anki cards

Make sure you are using the latest version of Anki, as older versions have issues with styled content. Otherwise, see the Anki Guide for more troubleshooting steps.

### Is iOS 26+ really required?

Yes, MaruReader relies on certain iOS 26 APIs for displaying dictionary content and the user interface.

### Why is it called MaruReader?

It was mostly chosen at random, one reason is that Maru a good name for a mascot.

### I have a question or issue that isn't answered here, or a suggestion

Please open an issue. For problems, include as many specifics as possible: the dictionary/book/website, a screenshot of the problem, steps to make it happen, etc.

## Development

For development, these tools are required:

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

`just test`. Specify a simulator target like `just test 'iPhone 17 Pro'` (default) or `just test 'platform=iOS Simulator,id=<SIMULATOR_UDID>'`.

You can also run a specific test plan with `just test-plan MaruReaderCoreTests` or a single test with `just test-one 'MaruReaderCoreTests/SomeSuite/testExample()' 'iPhone 17 Pro' MaruReaderCoreTests`

#### Bundled license sync

When preparing a new release version, you should update the third-party license list:

```bash
swift scripts/sync-third-party-licenses.swift
```

To refresh snapshot files from their configured upstream sources before generating:

```bash
swift scripts/sync-third-party-licenses.swift --refresh-snapshots
```

#### Starter Dictionaries

This is only needed if you want to distribute the app with preloaded dictionaries, for regular dev builds it's usually unnecessary and makes the build a bit slower.

`just starterdict`
