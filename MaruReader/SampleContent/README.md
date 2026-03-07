# Sample Content

Place screenshot-only EPUB and CBZ fixtures in this folder alongside a `manifest.json`.

- The app only looks for `SampleContent/manifest.json`.
- Debug builds copy this folder into the app bundle.
- Release builds exclude it entirely.

Expected layout:

```text
SampleContent/
  manifest.json
  Books/
    Example.epub
  Manga/
    Example.cbz
```
