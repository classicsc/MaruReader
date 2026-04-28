# Anki Guide

MaruReader integrates with Anki to help you create flashcards from vocabulary you encounter while reading. This guide covers setup and configuration.

## Anki Usage

After Anki setup (see below), tap the **+** button in any lookup. The button will change to a checkmark for words that were already added, but you can still use it to try adding again. Your duplicate detection settings determine whether this succeeds.

## What is Anki?

[Anki](https://apps.ankiweb.net/) is a flashcard app that uses a spaced repetition algorithm to schedule reviews for just before you're likely to forget a card. When you encounter a word in MaruReader that you want to memorize, you can create an Anki note with a single tap and get back to reading. The note is a collection of information like the word, reading, definitions, and the context sentence.

A "note type" refers to the instructions Anki uses to transform the note into one or more flashcards. MaruReader is mainly designed to work with mining-oriented note types.

### Mining Basics

Mining is a strategy for building vocabulary and reading comprehension skills through immersion:

1. **Read or watch native material** (books, manga, web articles, television)
2. **Look up unfamiliar words** in a dictionary
3. **Save interesting words to Anki** with the sentence you found them in
4. **Review your cards** using spaced repetition

Cards created through mining include a real context that you'll remember encountering, which might help them stick better than textbook examples.

> **Tip:** Don't try to create a note for every unknown word. Focus on words you've seen multiple times but forgot the meaning, or words you find interesting. Create notes from "one-target sentences", where you understand everything except the target word or grammar structure.

## Recommended Note Type: Lapis

If you're just getting started with mining, the [**Lapis note type**](https://github.com/donkuri/lapis) is recommended. MaruReader includes a field mapping template configurator for it. The template may also work with Lapis forks like [**lapis-simplified**](https://github.com/friedrich-de/lapis-simplified) that use the same fields if you prefer a different appearance.

Please set up your note type in Anki according to its documentation before configuring MaruReader's Anki integration.

> **Note:** You can use almost any note type, provided it doesn't require custom Yomitan handlebars, but you'll need to customize the field mapping. See the section on Custom Field Mappings below.

---

## Connection Methods

MaruReader supports two ways to connect to Anki:

| Method | Platform | Merits |
| -------- | ---------- | ---------- |
| **AnkiMobile** | iOS | Simple setup, offline use |
| **Anki-Connect** | Desktop Anki | Advanced deduplication, more audio formats, faster note add |

### AnkiMobile

AnkiMobile is the official iOS app from the Anki developers. This is the easiest option if you do reviews on your iPad or iPhone. It also works completely offline. When you press the button to create a note, AnkiMobile will open for a moment to save the note and then send you back to MaruReader.

**Requirements:**

- [AnkiMobile](https://apps.apple.com/app/ankimobile-flashcards/id373493387) installed on the same device

**Limitations:**

- Can't add notes directly when working with text or images shared from other apps, they go to Pending Notes to add later
- Duplicate detection is limited to allowing or blocking all duplicates
- `mp3` audio only

### Anki-Connect

Anki-Connect is a desktop Anki add-on for integrating with external apps. This gives you more control over duplicate detection, which is useful if you have a large collection spread across multiple decks. Adding notes through Anki-Connect can be faster under good network conditions since there's no switching apps. It also supports ogg/opus audio, which can be helpful if you're worried about your AnkiWeb storage limit.

**Requirements:**

- [Anki desktop](https://apps.ankiweb.net/) running on your computer
- [Anki-Connect add-on](https://ankiweb.net/shared/info/2055492159) installed
- A reachable network connection to your computer, using HTTPS or a supported plain HTTP local/private-network host (iOS will block plain HTTP except for private addresses. Even on the local network, HTTPS is recommended for privacy.)

> **Note:** Anki-Connect is marked as an advanced option because it requires extra network setup compared with AnkiMobile.

---

## Setup Walkthrough

### AnkiMobile Setup

1. Open MaruReader **Settings → Anki**
2. Tap **Configure Anki Integration**
3. Select **AnkiMobile**
4. Tap **Fetch profiles, decks, and note types**
   - This opens AnkiMobile. Authorize the request and you will be sent back to MaruReader

5. Tap **Continue** and select your:
   - **Profile**
   - **Deck** where new cards will go
   - **Note Type** (e.g., "Lapis")
6. Choose a **Field Mapping** (select "Lapis" template if using Lapis note type)
7. Configure **Duplicate Detection**

### Anki-Connect Setup

1. Ensure Anki is running with Anki-Connect installed
2. Open MaruReader **Settings → Anki**
3. Tap **Configure Anki Integration**
4. Select **Anki-Connect (Advanced)**
5. Enter your connection details:
   - **Host**: Your computer's hostname (e.g., `mycomputer.local`) or IP address
   - **Port**: Usually `8765` or `443`
   - **Use HTTPS**: Turn this on when your Anki-Connect endpoint is using TLS. Turn it off for supported plain HTTP local/private-network setups.
   - **API Key**: Optional, if you've configured one in Anki-Connect
6. Tap **Test Connection**. If successful, continue to select profile, deck, note type, and field mapping as above

---

## Duplicate Detection

Duplicate detection prevents creating multiple notes for words you've already added.

### AnkiMobile Options

- **Allow Duplicates**: Creates new notes even if a note for the same word exists
- **Block Duplicates**: Skips words that already have notes

### Anki-Connect Options

Anki-Connect provides more granular control:

- **Scope**: Check the target deck only, a specific deck (with or without child decks), or your entire collection
- **Note Types**: Check only the same note type, or all note types

---

## Field Mappings

Field mappings determine what information goes into each Anki field. MaruReader provides:

- **Built-in templates** for popular note types (Lapis)
- **Custom field mappings** for any note type

### Using the Lapis Configurator

If you're using the Lapis note type:

1. Select "Lapis" when choosing a field mapping
2. Choose your **Main Definition Dictionary**
3. Select your preferred **Card Type**:
   - **Click Card**: Word on front, click to reveal sentence. **Recommended** if you don't know what to pick, this type is ideal for speeding through reviews as words get easier while having the sentence available for the learning stage
   - **Vocabulary Card**: Word on front, definition on back
   - **Word + Sentence Card**: Word and sentence on front
   - **Sentence Card**: Sentence only
   - **Audio Card**: Audio-based review

### Custom Field Mappings

To create a custom mapping for other note types:

1. In the configuration flow, tap **Create New Mapping**
2. Or later: **Settings → Anki → Manage Field Mappings**

For each field in your note type, you can add one or more **template values** that MaruReader will populate. See the next section for all available values.

---

## Template Values Reference

Template values are the building blocks for populating Anki fields. When you create a note, MaruReader replaces each template value with data from your lookup and context.

### Text & Expression

| Value | Description |
| ------- | ------------- |
| **Expression** | The word as written (e.g., 食べる) |
| **Character** | Single kanji character (for kanji cards) |
| **Furigana** | Word with reading in ruby text format (e.g., `食[た]べる`) |
| **Reading** | Phonetic reading in kana (e.g., たべる) |
| **Conjugation** | Conjugation/inflection information if looked up in conjugated form |
| **Part of Speech** | Grammatical category (verb, noun, etc.) if your dictionary provides it |
| **Tags** | Dictionary tags for the entry |

### Glossary & Definitions

| Value | Description |
| ------- | ------------- |
| **Multi-Dictionary Glossary** | Combined definitions from all enabled dictionaries |
| **Glossary (No Dictionary Title)** | Plain text definition without dictionary styling |
| **Single Dictionary Glossary** | Definition from a specific dictionary you select |

### Context & Sentence

| Value | Description |
| ------- | ------------- |
| **Sentence** | The full sentence where you found the word |
| **Sentence (Furigana)** | Sentence with furigana readings generated by the internal text analysis engine |
| **Selection Text** | Plain text selected in dictionary results when you tap the add note button |
| **Cloze Prefix** | Text before the target word |
| **Cloze Body** | The target word itself |
| **Cloze Suffix** | Text after the target word |
| **Cloze Furigana Prefix/Body/Suffix** | Same as above, with furigana |
| **Document Title** | Title of the book/manga you're reading |
| **Document URL** | URL for web content |

> **Tip:** Combine cloze values with custom HTML to style the target word in a sentence:  
> `Cloze Prefix` + `Custom HTML: <b>` + `Cloze Body` + `Custom HTML: </b>` + `Cloze Suffix`

### Images

| Value | Description |
| ------- | ------------- |
| **Context Image** | Image selected based on source (see [Context Image Settings](#context-image-settings)) |

### Pitch Accent

| Value | Description |
| ------- | ------------- |
| **Pitch Accent List** | All pitch accent patterns for the word |
| **Single Pitch Accent** | First/primary pitch pattern |
| **Pitch Disambiguation** | Pitch pattern that helps distinguish homophones |
| **Pitch Accent Categories** | Pitch pattern classifications (平板, 頭高, etc.) |
| **Pronunciation Audio** | Audio file for pronunciation |

### Frequency

| Value | Description |
| ------- | ------------- |
| **Frequency List** | Frequency data from all dictionaries |
| **Single Frequency** | Frequency from highest-priority dictionary |
| **Frequency (Dictionary)** | Frequency from a specific dictionary |
| **Frequency Sort (Rank HM)** | Harmonic mean of rank frequencies (for sorting in Anki) |
| **Frequency Sort (Occ HM)** | Harmonic mean of occurrence frequencies |
| **Frequency Sort (Rank)** | Rank frequency from a specific dictionary |
| **Frequency Sort (Occurrence)** | Occurrence frequency from a specific dictionary |

> **Note on frequency sorting:** The "Frequency Sort" values output a numeric value which can be used for Anki's custom sort order, which you can configure to focus on common words first. For this to work correctly, dictionaries need to be using the correct frequency mode, and you need to configure the same dictionary or dictionaries everywhere you create notes. In rank-based dictionaries, a smaller number is a more common word; occurrence-based is the opposite. MaruReader assumes dictionaries that do not declare a frequency mode are rank-based.
>
> The worst that can happen from getting this wrong is getting new cards in a different order, so if it seems confusing I wouldn't worry about it.

### Custom HTML

You can insert arbitrary HTML between other values. Useful for:

- Adding `<br>` line breaks
- Wrapping text in `<b>`, `<i>`, or `<span>` tags
- Adding other separators or formatting

---

## Context Image Settings

The **Context Image** template value automatically selects an appropriate image based on where you're reading:

| Source | Default Image |
| -------- | --------------- |
| Book reader | Cover image |
| Manga reader | Page screenshot |
| Web browser | Screenshot |
| Dictionary | Screenshot |

You can customize this behavior in **Settings → Anki → Context Image Settings**.

---

## Pending Notes

When you add a note from share screens, AnkiMobile can't be opened directly, so notes go to Pending notes.

View pending notes and send to Anki in **Settings → Anki → Pending Notes**.

---

## Troubleshooting

### AnkiMobile doesn't open

- Ensure AnkiMobile is installed and has a profile set up

### Anki-Connect connection fails

- Verify Anki is running with Anki-Connect add-on
- Check the hostname and port
- Ensure you're using HTTPS
- Test the connection from another device on the same network

### Notes not created in Anki

- Check Pending Notes
- Check duplicate detection settings

### Added an audio field, but can't hear audio during reviews

- AnkiMobile can only add and play audio from `mp3` sources, make sure your source matches
- Make sure you mapped Pronunciation Audio to the right field if using a custom mapping
- When using an online audio source, it's possible to add an Anki note before it responds. If the audio button is still greyed out when adding the note, it will be created without audio

### Card formatting looks bad

- If the problem is on desktop, make sure you are running the latest version of Anki. Older versions have limitations on rendering styled content from Jitendex etc
- Make sure you have the latest version of your note type. Some newer dictionaries with customized stylesheets are incompatible with Lapis and other note types that add their own formatting, but Lapis in particular has updated to support more dictionaries which could fix your issues
- If neither of the above worked, it might be a bug in MaruReader. Open an issue and provide your template or field mapping, note type and version, Anki version, and a screenshot of what looks off

### Images aren't appearing

- Ensure Context Image Settings match your expectations
- For Anki-Connect, check for errors writing to the media folder
