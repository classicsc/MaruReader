# FAQ

## How do I learn Japanese?

It's too big a question to answer here, consult a [dedicated guide](https://learnjapanese.moe/guide/) on the topic. To get better at reading specifically, getting lots of practice with reading real books usually yields better results than studying individual kanji or textbook examples. MaruReader is meant to make this practice more efficient by putting a high quality learning dictionary system at your fingertips while reading, and automating the process of creating flashcards with the Anki integration.

## What dictionaries should I use?

These are the recommended dictionaries. You will get them automatically from the App Store:

- [Jitendex Japanese-English Dictionary](https://jitendex.org) by Stephen Kraus
- [BCCWJ Frequency Dictionary](https://github.com/Kuuuube/yomitan-dictionaries?tab=readme-ov-file#bccwj-suw-luw-combined) by National Institute for Japanese Language and Linguistics
- [Wadoku Pitch Accent Dictionary](https://github.com/classicsc/wadoku-pitch-dictionary-for-yomitan) by Wadoku Jiten
- [Kanji alive Audio](https://github.com/classicsc/kanji-alive-indexer) by Harumi Hibino Lory and Arno Bosse

A good add-on dictionary is [JMnedict](https://github.com/yomidevs/jmdict-yomitan?tab=readme-ov-file#jmnedict-for-yomitan), which provides proper nouns such as readings for Japanese names. Otherwise, the best dictionaries to use depend on your needs, which is why custom dictionaries are supported. Search the web for Yomitan dictionaries that align with your learning goals.

## What should I read?

You're more likely to stick with stuff that you're actually interested in reading. There are many guides, databases, and listicles online with books and manga organized by level.

## Can MaruReader open eBooks in non-epub formats like Aozora?

No, but most non-DRM ebook formats can be converted to epub with [Calibre](https://calibre-ebook.com). For aozora specifically, [AozoraEpub3](https://aozoraepub3-jdk21.github.io/AozoraEpub3-JDK21/en/usage.html) can generate EPUBs from the .txt files available from book card pages.

## Can MaruReader open manga in PDF or EPUB formats?

No, but it usually works to convert to ZIP with Calibre and import to MaruReader as manga.

## The text recognition got a character wrong in my manga, is it broken?

Text recognition can always produce errors. MaruReader uses on-device text recognition to provide convenience, privacy, and pretty good accuracy, but it won't be as accurate as cloud services.

All is not lost, however. If you know how to type the correct character, you can use the pen icon at the bottom of the dictionary sheet to edit the context before looking up the word again or creating an Anki note.

For the web browser specifically, accuracy can sometimes be improved by zooming in on the text you are trying to read. This will not help with the manga reader since the text recognition system always uses the full-resolution image for local manga.

## I have a particular EPUB where the layout looks off and tapping the text doesn't work

It might be a fixed-layout EPUB. Certain books, mostly older ones or PDF conversions, lack adjustable layout and might even contain pictures of each page instead of text. These are not supported since text is not available for dictionary lookups. If a newer digital edition of the same book is available, it might work better in MaruReader.

## Does MaruReader support Yomitan dictionaries with structured-content?

Yes.

## I have a dictionary that looks very different (worse) compared to Yomitan

- Some dictionaries use characters like the Unicode arrow `→` for purposes like indicating links, and on iOS some of these symbols are displayed as color emoji instead of the shape and color the dictionary's creator had in mind. This can be fixed in some cases by modifying the dictionary's stylesheet, but the better solution is for the dictionary to use images instead of Unicode characters for symbols that need to look the same on all platforms.
- MaruReader supports the `styles.css` at the dictionary root, but there's no equivalent to Yomitan's custom popup CSS settings. If you use custom styles on desktop, that could be the difference. A workaround is to add your custom styles to the dictionary's `styles.css` and re-import the dictionary.
- Otherwise, it may be a bug in MaruReader. Please open a discussion, specifying the dictionary and an entry with the problem, so it can be investigated.

## How do I use MaruReader with Anki?

The Anki integrations are designed to support mining, which is the process of reading and creating flashcards for unfamiliar words. See the [Anki guide](/doc/Anki.md) for full details.

MaruReader can work with many of the same mining setups as Yomitan, the main limitation being that MaruReader cannot use custom handlebars, only a set of values that roughly corresponds to Yomitan's default handlebars. If your workflow requires custom handlebars or some other feature that is missing, open a discussion thread so we can look at whether it can be supported.

## Formatting looks wrong on my Anki cards

Make sure you are using the latest version of Anki, as older versions have issues with styled content. Otherwise, see the [Anki guide](/doc/Anki.md) for more troubleshooting steps.

## Why is it called MaruReader?

Maru is the name of the correct answer mark in Japanese, and you'll see more of those if you add immersion to your studies. It's also the name of the round owl in the icon.

## I have a question or issue that isn't answered here, or a suggestion

Please open a discussion thread. For problems, include as many specifics as possible: the dictionary/book/website, a screenshot of the problem, steps to make it happen, etc.
