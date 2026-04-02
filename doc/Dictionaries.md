# Dictionaries Guide

MaruReader uses the Yomitan dictionary format. For schemas and tools for making custom dictionaries, see [Making Yomitan Dictionaries](https://github.com/yomidevs/yomitan/blob/master/docs/making-yomitan-dictionaries.md) from upstream.

## Adding Dictionaries

1. Open MaruReader **Settings → Dictionaries**
2. Tap **+**
3. Select the file on your device

> Adding dictionaries directly from third-party cloud drive apps and network drives is unreliable because of the large file size. If you're having trouble with the file picker not responding when you select a file, copy the file to an On My iPhone/On My iPad folder first, and try importing from there.


## Dictionary Order

To adjust the display order of dictionaries in search results:

1. Open MaruReader **Settings → Dictionaries**
2. Tap **... → Priorities**
3. Drag dictionaries around in each category to reorder

### Frequency Dictionaries

For frequency, you can also select the ranking dictionary. This is used in the search result ranking algorithm, so you should set it to a high quality comprehensive dictionary like BCCWJ or JPDB.

## Dictionary Updates

Some dictionaries provide updates. For example, Jitendex typically updates monthly. To update your dictionaries:

1. Open MaruReader **Settings → Dictionaries**
2. Tap **... → Check Updates**
3. Tap the download icon to update them all, or the **Update** button on a dictionary to update it individually.

This will download the updated dictionary, import it, and replace the old version.

## Deleting Dictionaries

If you want to get rid of a dictionary:

1. Open MaruReader **Settings → Dictionaries**
2. Swipe left on the dictionary you want to delete.

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
