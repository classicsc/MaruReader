# Mokuro Guide

MaruReader can use OCR text from a [mokuro](https://github.com/kha-white/mokuro) file instead of running on-device text recognition. This guide covers generating a mokuro file, attaching it to a manga, and troubleshooting.

## Mokuro Usage

After attaching a mokuro file (see below), open the manga and read normally. Tap text to look it up exactly as you would otherwise.

The bounding box colors tell you which text recognition is active:

| Box color | Text recognition | Text direction |
| ----------- | ------------------ | ---------------- |
| **Red** | Mokuro | Vertical (tategaki) |
| **Purple** | Mokuro | Horizontal |
| **Blue** | On-device | Vertical (tategaki) |
| **Green** | On-device | Horizontal |

Warm colors mean mokuro, cool colors mean on-device recognition. Vertical text is also drawn with a dashed outline and horizontal with a solid one, so the direction is readable without relying on color.

If you attached a mokuro file but still see blue and green boxes, the file isn't being matched to your pages. See [Troubleshooting](#troubleshooting).

## What is mokuro?

Mokuro is a desktop tool that runs OCR over a manga volume ahead of time and saves the results to a `.mokuro` file. It uses [manga-ocr](https://github.com/kha-white/manga-ocr), a model trained specifically on manga text, and groups the text it finds into speech bubbles.

On-device recognition handles most manga well and needs no preparation at all, so mokuro is entirely optional. It's worth considering when you'd like a second opinion on a particular volume — the work happens in advance on a computer, so it isn't bound by what's practical to run on a phone while you read. Some readers prefer it for heavily stylized lettering or unusually dense pages.

Because mokuro files are plain JSON, you can also correct the text by hand before you read, which isn't possible with recognition done on the fly.

> **Note:** MaruReader can't generate mokuro files. Mokuro needs Python and a machine learning pipeline that isn't available on iOS. You run it on a computer and transfer the result to your device.

---

## Generating a mokuro file

**Run mokuro directly on the CBZ file you're going to read.** This is the single most important thing for getting mokuro working in MaruReader.

```bash
pip install mokuro
mokuro "my_manga.cbz" --unzip
```

Mokuro accepts `.cbz` and `.zip` archives directly and writes a `.mokuro` file next to the archive.

### Why running it on the CBZ matters

MaruReader pairs mokuro pages to manga pages by **image filename**. Mokuro records the name of each page image it processed, and MaruReader looks for a page in your archive with that same name.

When you run mokuro on the CBZ itself, the names it records are the archive's own page names, so every page pairs correctly and the order of the pages can't cause problems.

When you run mokuro on a *separately extracted* folder of images, the names it records are that folder's names, which frequently don't match the archive at all:

| Your CBZ contains | Your extracted folder contained |
| ------------------- | --------------------------------- |
| `001.jpg` | `cover.jpg` |
| `002.jpg` | `i-white.jpg` |
| `003.jpg` | `i-001.jpg` |

With no names in common, nothing pairs, and every page quietly falls back to on-device recognition. The symptom is easy to miss: reading works normally, you're just not seeing the mokuro text you prepared.

> **Tip:** If you already have a mokuro file that was generated from an extracted folder, the simplest fix is to re-run mokuro on the CBZ. Renaming files to match also works, but re-running is faster and less error-prone.

### Downloaded mokuro files

Mokuro files shared by other people were generated from *their* copy of the volume. If their page names don't match yours, the file won't pair with your archive. Re-running mokuro on your own CBZ is the reliable path.

---

## Attaching a mokuro file

### Packaged inside the CBZ

If the `.mokuro` file is inside the archive itself, MaruReader attaches it automatically when you import the manga — there's nothing else to do. Add the `.mokuro` file to your CBZ alongside the page images before transferring it to your device:

```bash
mokuro "my_manga.cbz" --unzip
zip -j "my_manga.cbz" "my_manga.mokuro"
```

It can sit at the top level or in a subfolder; the name doesn't matter. If the archive somehow contains more than one `.mokuro` file, the first by name is used. A file that can't be read as mokuro data is skipped and the manga imports normally with on-device recognition — importing never fails because of a mokuro file.

Attaching a file by hand afterwards replaces the packaged one.

### Attaching by hand

1. Transfer the `.mokuro` file to your device (AirDrop, Files, iCloud Drive, etc.)
2. In the **Manga** library, long-press the manga you want to use it with
3. Tap **Attach Mokuro File...**
4. Select the `.mokuro` file in the file picker

The file is copied into the app, so you can delete the original afterwards. Attaching a new file to the same manga replaces the previous one.

### Removing a mokuro file

Long-press the manga and tap **Remove Mokuro File**. This option only appears when a file is attached, including one attached automatically from inside the archive. The manga reverts to on-device text recognition.

Deleting a manga also deletes its attached mokuro file.

---

## How pages are matched

MaruReader pairs pages **by image filename**, and only by image filename. A mokuro page is used for the archive page whose image has the same name. Page order doesn't matter, so this works even when the two are ordered differently.

Pages that can't be paired fall back to on-device recognition individually, so a mokuro file covering only part of a volume still works for the pages it does cover.

> **Note:** MaruReader deliberately won't guess. If none of the names line up, it uses on-device recognition for the whole volume rather than pairing pages by their position in the file. Position looks tempting when both have the same number of pages, but it isn't reliable — mokuro lists its pages in alphabetical order, which often isn't the order they appear in your archive. A single blank or bonus page sorting differently shifts everything after it, and the result is confident, correctly-placed boxes containing the wrong text, with nothing to signal the problem. Generating the mokuro file from the CBZ makes the names line up and avoids the question entirely.

---

## Troubleshooting

### Attached a mokuro file, but the boxes are still blue and green (on-device)

The file isn't pairing with your pages. Almost always this means the mokuro file was generated from a differently-named set of images.

- Re-run mokuro on the CBZ itself (see [Generating a mokuro file](#generating-a-mokuro-file))
- Confirm you attached the file to the manga you're actually reading

### Mokuro boxes appear, but the text belongs to a different page

Pages are paired by filename, so this means two pages in your archive carry the names mokuro recorded for *different* pages — usually a mokuro file built from a different edition or a re-ordered extraction of the same volume.

- Re-run mokuro on the CBZ itself, so every name comes from the archive you're reading
- Or remove the mokuro file to go back to on-device recognition

### Mokuro boxes appear, but the text is from a different volume

Mokuro page names are often generic (`001.jpg`, `002.jpg`), so a file from volume 3 can pair with volume 1 and show confident but entirely wrong text.

- Check that you attached the right volume's file
- Re-attach the correct one; attaching replaces the previous file

### The file picker won't let me select my mokuro file

- Confirm the file actually ends in `.mokuro`
- If it came from iCloud Drive, open it in the Files app once so it downloads locally first

### "The selected file is not a valid mokuro file"

The file couldn't be read as mokuro data.

- Confirm it's a `.mokuro` file and not the `.html` file mokuro generates alongside it
- Re-run mokuro if the file may have been truncated during transfer

### Some pages have no boxes at all

Pages with no text produce no boxes, which is expected. If a page clearly has text and shows nothing, that page may be missing from the mokuro file — check that mokuro processed the whole volume without errors.

### Mokuro's text is wrong

MaruReader displays what the mokuro file contains and doesn't correct it. Since `.mokuro` files are JSON, you can edit the text by hand, or re-run mokuro with different settings. See the [mokuro documentation](https://github.com/kha-white/mokuro) for options.
