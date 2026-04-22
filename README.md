# MaruReader

<p align="center">
<img width="128" height="128" alt="marureader-icon" src="https://github.com/user-attachments/assets/9166af5d-f3c9-484a-99a3-155234aa83a1" />
</p>

MaruReader is a free, open source dictionary and reading application for learning Japanese, which runs on iOS and iPadOS. You can use MaruReader to look up unfamiliar words across multiple dictionaries while reading eBooks, manga, and websites, or even from photos and screenshots. When you want to commit a new term to memory, instantly create an Anki note with rich formatting and full context.

## Key Features

### 1. Fast, customizable dictionary

The dictionary works across the book reader, manga reader, web browser, and photo scanner, or direct one-off searches.

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/bb6edb30-8fdf-41d8-a29c-5f52f77c7b95" width="80%" controls></video>
</p>

The MaruReader dictionary system automatically converts verbs to dictionary form, converts between hiragana, katakana, and romaji, and performs other normalizations to make searching faster.

### 2. Read manga with text recognition

Text in manga is OCR'd on your device as you read so you can look up words with no pre-processing or online services required.

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/937cf72d-e93a-4dfc-8527-2026996e6c24" width="80%" controls></video>
</p>

Text recognition is designed to be easy to use. Instead of trying to highlight text from imprecise character bounds on an image, just tap on the area of the image you're interested in and choose a word from the Context area.

### 3. All the ways to use the dictionary on the web

#### Select text in the MaruReader Browser

The MaruReader browser is great for reading Japanese websites and web novels with a dictionary at your fingertips. Ad blocker included to reduce distractions. Just select some text and choose "Dictionary" to look it up.

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/82f4659a-e4eb-464f-b33a-0970ce9c1b10" width="80%" controls></video>
</p>

#### OCR in the MaruReader Browser

To look up any text on screen, use the tap icon in the toolbar and tap the text you want to look up. Great for manga.

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/aba81026-b9fe-40d9-b53c-12c9393e7aa7" width="80%" controls></video>
</p>

#### Text and OCR from the Share Menu

Share text or images from any other app for a quick lookup. Great for text in Japanese apps and games, just take a screenshot and share it to MaruReader.

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/0572a207-dc9b-49fc-8ba6-13dcbd45534e" width="80%" controls></video>
</p>

### 4. Anki Integration

Stop forgetting new words, add them to Anki's smart flashcard system. MaruReader has tons of options for populating notes for information-rich cards, including a configuration for the popular Lapis note.

## All Features

### Dictionary System

- **Deinflection** Inflected forms are automatically converted to dictionary form to make searching more convenient. Just enter text as you found it.
- **Sentence Furigana** To aid with reading sentences, the dictionary displays auto-generated readings. While this isn't 100% accurate, it can he a helpful reference.
- **Yomitan Dictionary Format Support**
  - MaruReader uses the same dictionary format as [Yomitan](https://yomitan.wiki/). Term, frequency, and pitch accent dictionaries are supported.
  - Add as many custom dictionaries as you like, search is fast even with many large dictionaries.
  - Learn more in the [Dictionary Guide](doc/Dictionaries.md)
- **Search Within Definitions** Tap on words in dictionary definitions to search in a compact popup, and tap in the popup to open those results in the full dictionary search page. This is a must-have feature for learners using monolingual (Japanese-Japanese) dictionaries.

### Manga Reader

- **On-device text recognition (OCR)** MaruReader uses your device's built-in text recognition capabilities to read text on manga pages with no need for pre-processing or specialized file formats, just add any ZIP/CBZ and start reading. Tap on the text you want to look up, and it will open alongside the page. Auto-generated furigana can also be displayed on the lookup page.
- **Smart Metadata** On devices with Apple Intelligence supported and enabled, the title and author displayed in the manga library can be extracted from filenames with no specific naming scheme or special metadata file needed.

### Book Reader

- **Optimized for Japanese eBooks** MaruReader displays books with vertical text (tategaki) and fonts designed for Japanese text.
- **Compact dictionary popup search** In the book reader, tapping on text opens a compact popup for the specific word you tapped, keeping you closer to the book.

### Web Browser

- **Text recognition for web-based content** You can use MaruReader even without offline books and manga. Open what you want to read online in the built-in web browser. Activate OCR mode and tap on text to look it up using the same text recognition system used by the manga reader, or search text in the dictionary by highlighting it.
- **Content blocker** The web browser has a content blocker with general and Japan-specific filters, so you can read with fewer distracting ads and trackers.

### Photo Scanner

- **Text Recognition for Everything Else** Whether you need to look up a word from a sign in Japan, a screenshot of an app or game, or anything else, the photo scanner has your back. Snap or import a photo from the Scan tab, or share from another app.

### Anki Integration

- **AnkiMobile Integration** MaruReader can add notes to the AnkiMobile app by tapping the "+" button in any dictionary lookup context. Includes built-in configuration for Lapis, and the ability to configure your own note fields for other note types.
- **Anki-Connect Integration** Advanced users also have Anki-Connect as an option. This has some benefits including customizable duplicate note detection.
- Learn more in the [Anki Guide](doc/Anki.md)

## Questions?

See the [FAQ](doc/FAQ.md), or open a thread in the Discussions tab.

## Acknowledgements

The MaruReader dictionary system is based on [Yomitan](https://yomitan.wiki/). Third-party libraries are listed in the About section of the app.

If you download MaruReader from the App Store, you'll also get a package of the best freely licensed dictionaries and audio available, listed below:

- [Jitendex Japanese-English Dictionary](https://jitendex.org) by Stephen Kraus
- [BCCWJ Frequency Dictionary](https://github.com/Kuuuube/yomitan-dictionaries?tab=readme-ov-file#bccwj-suw-luw-combined) by National Institute for Japanese Language and Linguistics
- [Wadoku Pitch Accent Dictionary](https://github.com/classicsc/wadoku-pitch-dictionary-for-yomitan) by Wadoku.de
- [Kanji alive Audio](https://github.com/classicsc/kanji-alive-indexer) by Harumi Hibino Lory and Arno Bosse

The manga shown in the screenshots is used under the terms listed on [the author's website](https://densho810.com/free/).

**Title**: Give My Regards to Black Jack

**Author**: SHUHO SATO
