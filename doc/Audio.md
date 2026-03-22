# Pronunciation Audio Guide

MaruReader supports pronunciation audio so that you can hear a native speaker pronounce a word. The built-in "Kanji alive" audio source contains about 10,000 clips. This guide describes how to work with additional sources.

## How to use multiple audio clips

If you have multiple audio sources, or a source that provides multiple clips for each lookup, press and hold the speaker icon to see all the available clips.

## Audio Formats

MaruReader can play any audio file type that plays in iOS webviews, which includes most popular ones like `mp3`, `aac`, `ogg`, and `opus`.

AnkiMobile users should use `mp3` audio sources, with others you can't add audio to your notes.

If you don't care about AnkiMobile compatibility, `opus` (which often uses the `ogg` file extension) is the most efficient.

## Audio Servers

Like Yomitan, MaruReader supports URL patterns to connect to audio servers like the Local Audio Server for Yomitan. SSL connection is required.

### URL Pattern Setup

1. Open MaruReader **Settings → Pronunciation Audio**
2. Tap **+ → Add URL Pattern**
3. Give your source a **Name**
4. Enter the URL Pattern, using the replacement values `{term}`, `{language}`, and `{reading}`
5. If your audio server's instructions say to use the "Custom URL (JSON)" option in Yomitan, toggle JSON on
6. Save the source

### Pitch Accent Details

If you have a pitch accent dictionary added, MaruReader will try to match results with bracketed downstep positions from the `name` field in audio JSON responses. For example, if `name` is `日本語 [0]`, then this clip would receive a higher display priority for a result group where the top pitch accent result is heiban. This also works for compound forms written like `向き不向き [1-1]`.

## Audio ZIPs

If you'd rather not depend on a network connection for audio, you can use an indexed ZIP.

### Indexed ZIP Setup

1. Open MaruReader **Settings → Pronunciation Audio**
2. Tap **+ → Add Indexed ZIP**
3. Select the file on your device

### Indexed ZIP Format

It's the same format as the AJT Japanese plugin for Anki. At minimum you need an `index.json` file at the root of the ZIP structured as follows:

```json
{
    "meta": {
        "name": "My audio source",
        "year": 2023,
        "version": 2,
        "media_dir": "media"
    },
    "headwords": {
        "私": ["file1.ogg", "file2.ogg"],
        "僕": ["file3.ogg", "file4.ogg"]
    },
    "files": {
        "file1.ogg": {
            "kana_reading": "わたし",
            "pitch_pattern": "わたし━",
            "pitch_number": "0"
        },
        "file2.ogg": {
            "kana_reading": "わたくし",
            "pitch_pattern": "わたくし━",
            "pitch_number": "0"
        }
     }
}
```

The `pitch_pattern` and `pitch_number` fields are optional, they are used to match files to search results if the fields are present and a pitch accent dictionary is added.

* **Local Audio**: Place files in the `media` subdirectory
* **Online Audio**: You can also use a `media_dir_abs` field in the `meta` section. Set it to a base web URL (SSL required), creating an audio source where the files are stored online but the index is on your device, removing the need for specialized server software.

## About TTS

Text-to-speech (TTS) software is generally not suitable for language learning. Some modern AI-powered TTS systems are getting pretty good, but either require proprietary cloud services or are experimental setups that only run on desktop computers. If the situation changes, and a reliable, accurate TTS solution with human-level pronunciation that can run on-device or self-hosted emerges, MaruReader might update to support it.
