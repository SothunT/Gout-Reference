# Gout Food Guide

A simple, color-coded guide to which foods are safe to eat with gout, in English, Tiếng Việt and 廣東話. It includes everyday Vietnamese and Cantonese foods and dishes.

- 🟢 **Safe**: eat freely (under 50 mg purine per 100 g)
- 🟡 **Light**: OK most days (50–100 mg)
- 🟠 **Medium**: small portions, not every day (100–200 mg)
- 🔴 **High – Avoid**: over 200 mg, or a known trigger like beer or sugary drinks

It's a single `index.html` page plus an `Images` folder. It needs no build step and no server code, and it works on phones and computers.

## What's in this folder

| File | What it is |
| --- | --- |
| `index.html` | The whole app. |
| `Images/illustrations/` | Food illustrations. They show until the photos are downloaded, and for any food without a photo. |
| `Images/photos/` | Where the real food photos go. Empty until you run the downloader. |
| `Images/photo-sources.json` | Each food's id and the Wikimedia Commons photo it uses. |
| `download_images.bat` | **Windows:** double-click to download all the photos into `Images/photos`. |
| `download_images.command` | **Mac:** double-click to do the same. |
| `download_images.ps1` / `.py` | The scripts the two launchers run. |
| `manifest.webmanifest`, `*.png` | App icon for adding the page to a phone's home screen. |

## Step 1 — download the photos (once)

- **Windows:** double-click `download_images.bat`.
- **Mac:** double-click `download_images.command`. If macOS blocks it, right-click it → **Open** → **Open**. If it asks to install developer tools, accept, then run it again.
- **Anything with Python:** open a terminal in this folder and run `python3 download_images.py`.

A window shows progress for all 203 foods. It takes about 10–15 minutes. If Wikimedia asks it to slow down, it says so, waits and carries on by itself. Then:

- Each food gets a photo from Wikimedia Commons in `Images/photos`, plus a small preview in `Images/photos/thumbs`. Every food has a photo chosen to show the food itself, not the plant or the live animal.
- The photographer and license are saved in `Images/photos/credits.js`. The app shows them under each photo, as the free license requires.
- If any photo can't be downloaded, that food keeps its illustration and is listed in `failed-images.txt`. Run the downloader again to retry. It only fetches what's missing.

Open `index.html` in a browser and tap a few pictures to check the photos before uploading. To swap one, see [Changing a photo](#changing-a-photo).

## Step 2 — put it on GitHub Pages

1. Create a new **public** repository on GitHub, for example `gout-food-guide`.
2. Click **Add file → Upload files**. Drag in `index.html`, `README.md`, `manifest.webmanifest`, the three `.png` icons, and the whole **`Images` folder** (drag the folder itself, not just what's inside it). Click **Commit changes**. You don't need to upload the download scripts.
3. Go to **Settings → Pages**. Under **Build and deployment**, set **Source** to **Deploy from a branch**, pick `main` and `/ (root)`, then click **Save**.
4. After a minute or two the page will be live at
   `https://YOUR-USERNAME.github.io/gout-food-guide/`

Keep the folder named exactly `Images` with a capital I, because GitHub Pages is case-sensitive.

If you run the downloader again later, upload the `Images/photos` folder again so the new photos and the updated `credits.js` go up together.

## Changing a photo

- **Use your own photo:** save it as `Images/photos/<food-id>.jpg`, for example `Images/photos/beef-pho.jpg`. The ids are listed in `Images/photo-sources.json`. Delete that food's small preview in `Images/photos/thumbs` and its entry in `Images/photos/credits.json`, then run the downloader again. It makes the new preview and adds your photo to the list, and it never replaces your own photos.
- **Pick a different Wikimedia photo:** find a photo on [Wikimedia Commons](https://commons.wikimedia.org) and copy its file name from the page title, for example `File:Pho bo.jpg`. In `Images/photo-sources.json`, put that name next to the food's id, then run the downloader again. It notices that the source changed and downloads the new photo. You can also put a Wikipedia article name there instead of a `File:` name, and the article's main photo is used.

## Open it straight in a language

Add one of these to the end of the link:

| Link ending | Opens in |
|---|---|
| `#en` | English |
| `#vi` | Tiếng Việt |
| `#yue` or `#zh` | 廣東話 |

Example: `https://YOUR-USERNAME.github.io/gout-food-guide/#yue`

The page also remembers the last language and text size chosen on that phone.

## Add it to the phone's home screen

- **iPhone (Safari):** tap the Share button, then **Add to Home Screen**.
- **Android (Chrome):** tap the ⋮ menu, then **Add to Home screen**.

It will then open like an app, with its own icon.

## Editing foods

All foods are in `index.html` in the list that starts with `var F = [`. Each line looks like:

```js
["seafood",3,"Shrimp & prawns","Tôm","蝦"],
```

That is: category (`veg`, `meat`, `seafood`, `fruit`, `drink`, `dish`, `other`), level (1 = Safe, 2 = Light, 3 = Medium, 4 = Avoid), then the English, Vietnamese and Cantonese names. An optional sixth value adds a note from the `N` list just above it.

## Picture credits

- Illustrations: [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji), MIT License. See `Images/illustrations/LICENSE.txt`.
- Photos: Wikimedia Commons contributors, plus two Flickr photos (braised pork & eggs, Cantonese slow-cooked soup). The author and license for each photo are listed in `Images/photos/credits.json` and shown under the photo in the app. The downloader treats the two Flickr photos like your own photos and never replaces them.

---

Purine levels are approximate and based on published food purine tables. This is general information, not medical advice. Always follow the doctor's guidance.
