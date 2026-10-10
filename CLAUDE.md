# Gout Food Guide

A color-coded gout food guide in English, Tiếng Việt and 廣東話 (Cantonese, `zh-HK`). It's written for family members, so it uses large text, big tap targets and plain wording. It's a static site for GitHub Pages: no build step and no dependencies apart from Google Fonts. `README.md` is the end-user guide for downloading the photos and deploying.

## Layout
- `index.html` holds the whole app: CSS, the UI text (`L`), the notes (`N`), the foods (`F`) and the plain ES5 JS in one IIFE.
- `Images/illustrations/` (and `small/`) holds the Fluent Emoji webp files used as the fallback picture for each food.
- `Images/photos/` is filled by `download_images.ps1` / `.py`, which also write `credits.js` (`window.PHOTO_CREDITS`). It is empty in the source zip, so the app shows illustrations until the photos are downloaded.
- `Images/photo-sources.json` maps each food id to an exact Commons file (`"File:…"`). Each one was checked by eye to show the food itself, not the plant or the live animal. A plain Wikipedia article name also works as a value; the downloader then uses that article's lead image. The downloader re-fetches a photo when its source changes, never replaces user photos (photos with no credit URL), and backs off on HTTP 429.

- Two photos come from Flickr, not Commons: `braised-pork-and-eggs` and `cantonese-slow-cooked-soup`. They were added by hand with their credits in `credits.json`. Their credit URLs aren't Commons `/wiki/` links, so the downloader treats them as user photos and never replaces them. `photo-sources.json` still lists a Commons fallback for each.
- Wikimedia's bot-traffic limiter sometimes blocks Windows PowerShell's image downloads (HTTP 429, "contact bot-traffic@wikimedia.org") while Python and curl still get through. If `download_images.bat` keeps stalling, `python download_images.py` does the same job.

## Gotchas
- A food's **id is `slug(English name)`**. Renaming a food in `F` changes its id. If you rename one, update its keys in `ILL` (the generated block between `/*ILL*/` and `/*/ILL*/`), in `photo-sources.json`, and in any downloaded `Images/photos/<id>.jpg` and thumbs.
- Every food needs all three languages. Notes in `N` are `[en, vi, zh]` arrays, in that order.
- The levels are 1 = Safe (<50 mg purine/100 g), 2 = Light (50–100), 3 = Medium (100–200), 4 = Avoid (>200, or a known trigger like beer or sugary drinks).
- Keep the folder name `Images` capitalized, because GitHub Pages is case-sensitive.
- Theme colors are tokens on `:root`, with dark mode under `prefers-color-scheme` and under `[data-theme="dark"]`. Keep the two dark blocks in sync.

## Run locally
The preview config is in `.claude/launch.json` (`python -m http.server 8417`). Open http://localhost:8417/. A missing `credits.js` returns a 404, which is expected.
