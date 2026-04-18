# Dictionaries Guide

MaruReader uses the Yomitan dictionary format. For schemas and tools for making custom dictionaries, see [Making Yomitan Dictionaries](https://github.com/yomidevs/yomitan/blob/master/docs/making-yomitan-dictionaries.md) from upstream.

## Adding Dictionaries

1. Open MaruReader **Settings → Dictionaries**
2. Tap **+ → Import Zip Archive**
3. Select the file on your device

> Adding dictionaries directly from third-party cloud drive apps and network drives is unreliable because of the large file size. If you're having trouble with the file picker not responding when you select a file, copy the file to an On My iPhone/On My iPad folder first, and try importing from there.

## Dictionary Order

To adjust the display order of dictionaries in search results:

1. Open MaruReader **Settings → Dictionaries**
2. Drag dictionaries around in each category to reorder

### Frequency Dictionaries

For frequency, you can also select the ranking dictionary. This is used in the search result ranking algorithm, so you should set it to a high quality comprehensive dictionary like BCCWJ or JPDB.

## Dictionary Updates

Some dictionaries provide updates. For example, Jitendex typically updates monthly. To update your dictionaries:

1. Open MaruReader **Settings → Dictionaries**
2. Tap **... → Check for Updates**
3. Tap **Update All**, or the **Update** button on a dictionary to update it individually.

This will download the updated dictionary, import it, and replace the old version.

## Deleting Dictionaries

If you want to get rid of a dictionary:

1. Open MaruReader **Settings → Dictionaries**
2. Long press on the dictionary you want to delete and choose **Delete**.

## Supported Data Types

Yomitan dictionaries can contain several types of data. MaruReader uses:

* **Terms**: Regular dictionary definitions
* **Pitch Accent**: Pronunciation data for Japanese
* **Term Frequency**: The relative commonality of terms

You can import dictionaries containing the rest of the data types, but the data is not used anywhere in the MaruReader app:

* **Kanji**
* **Kanji Frequency**
* **IPA Pronunciation**

## Dictionary Stylesheets

Like Yomitan, MaruReader will import a `styles.css` from the root of the dictionary ZIP and load it into the dictionary viewer scoped to the dictionary's term glossary display sections. Dictionary creators and end users familiar with CSS can use this to customize how definitions look. Most styles for Yomitan work for MaruReader (class names and such are matched).

## Tokenizer Dictionaries (Advanced)

MaruReader uses a tokenizer system to split sentences into lexeme units (e.g. words) and add furigana for context display and certain Anki fields. The tokenizer uses its own dictionary, [SudachiDict](https://github.com/WorksApplications/SudachiDict), which you can update or replace if needed. Most SudachiDict updates are very minor and only add some new words that you won't encounter in most reading, but over time it can make a difference particularly with text that contains proper nouns.

For example, using a tokenizer dictionary that is old or does not contain proper nouns on a sentence containing 「蓮ノ空女学院」 (the setting of a recent anime) would split the noun into more than two units and you'd get an incorrect transcription such as 「はちすのそらじょがくいん」. But a recent enough SudachiDict contains 「蓮ノ空」 as a known proper noun and produces the correct transcription 「はすのそらじょがくいん」.

Currently only the system dictionary is supported. Support for Sudachi user dictionaries could be added in the future if there is interest.

If you build a new tokenizer dictionary, put it in a ZIP with the required files: `char.def`, `rewrite.def`, `sudachi.json`, `system_full.dic`, `unk.def`.

The ZIP must also contain `index.json` which is similar to a Yomitan index. Example:

```json
{
  "type": "tokenizer-dictionary",
  "format": 1,
  "name": "SudachiDict Full",
  "version": "20260116",
  "isUpdatable": false,
  "attribution": "SudachiDict by Works Applications Co., Ltd. is licensed under the [Apache License, Version2.0](http://www.apache.org/licenses/LICENSE-2.0.html)\n\n   Copyright (c) 2017-2023 Works Applications Co., Ltd.\n\n   Licensed under the Apache License, Version 2.0 (the \"License\");\n   you may not use this file except in compliance with the License.\n   You may obtain a copy of the License at\n\n       http://www.apache.org/licenses/LICENSE-2.0\n\n   Unless required by applicable law or agreed to in writing, software\n   distributed under the License is distributed on an \"AS IS\" BASIS,\n   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n   See the License for the specific language governing permissions and\n   limitations under the License.\n\nThis project includes UniDic and a part of NEologd.\n- http://unidic.ninjal.ac.jp/\n- https://github.com/neologd/mecab-ipadic-neologd",
  "indexUrl": null,
  "downloadUrl": null
}
```

If you make the dictionary updatable, `indexUrl` should point to the latest `index.json` and `downloadUrl` to the latest ZIP.
