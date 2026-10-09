# Gout Food Guide

A simple, color-coded guide to which foods are safe to eat with gout, in English, Tiếng Việt and 廣東話. It includes everyday Vietnamese and Cantonese foods and dishes.

- 🟢 **Safe**: eat freely (under 50 mg purine per 100 g)
- 🟡 **Light**: OK most days (50–100 mg)
- 🟠 **Medium**: small portions, not every day (100–200 mg)
- 🔴 **High – Avoid**: over 200 mg, or a known trigger like beer or sugary drinks

It's a single `index.html` page plus an `Images` folder. It needs no build step and no server code, and it works on phones and computers.

## Put it on GitHub Pages

1. Create a new **public** repository on GitHub, for example `gout-food-guide`.
2. Unzip the download. Click **Add file → Upload files** and drag in **everything inside** the `gout-food-guide` folder: `index.html`, `manifest.webmanifest`, the three `.png` icons, this README, and the `Images`, `tools` and `.github` folders. Click **Commit changes**.
   - **On a Mac:** Finder hides the `.github` folder because its name starts with a dot. Press **Command + Shift + .** (period) in the Finder window to show it, then drag it in with the rest.
   - If `.github` still doesn't upload, see [Turning on the photo step by hand](#turning-on-the-photo-step-by-hand) below.
3. Go to **Settings → Pages**. Under **Build and deployment**, set **Source** to *Deploy from a branch*, choose **main** and **/ (root)**, then click **Save**.
4. After a minute or two the page will be live at
   `https://YOUR-USERNAME.github.io/gout-food-guide/`

## Food photos

Every food has a small picture next to its name. Tap it to show a bigger picture, and tap again to close it.

- Right after you upload, the pictures are **illustrations**. They're stored in `Images/illustrations`.
- A one-time step called **Download food photos** runs on GitHub by itself after you upload. It downloads a real photo of each food from Wikipedia / Wikimedia Commons into `Images/photos` and saves it to the repository. It takes about 2–3 minutes. Then the site updates within a few minutes and shows the photos instead.
- Each photo shows the photographer and its license underneath, as the free license requires.
- A few foods have no suitable free photo, such as lotus root and sea snails. Those keep their illustration.

**Check that it worked:** open the **Actions** tab of the repository. You should see **Download food photos** with a green check ✓.

- If Actions asks you to enable workflows, click the green button to enable them. Then click **Download food photos → Run workflow**.
- If it fails with a permissions error, go to **Settings → Actions → General → Workflow permissions**, choose **Read and write permissions**, click **Save**, and run it again.
- If the photos don't show on the site 10 minutes after the green check, open **Actions → pages build and deployment** and click **Re-run all jobs**.

**Use your own photo for a food:** upload it to `Images/photos` named after the food's id, for example `beef-pho.jpg`. The ids are listed in `Images/photo-sources.json`. Then run **Download food photos** again from the Actions tab. It never replaces photos that are already there, so yours stay. It just adds the small preview picture and the list entry.

**Choose a different photo:** in `Images/photo-sources.json`, change the Wikipedia article name for that food. Then delete the old photo from `Images/photos`, and the step downloads the new one automatically.

### Turning on the photo step by hand

If the `.github` folder didn't upload, you can create the file on GitHub directly:

1. In the repository, click **Add file → Create new file**.
2. Type the name `.github/workflows/download-photos.yml`. The slashes create the folders.
3. Paste in the contents of that file from the zip, then click **Commit changes**.

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
- Photos: Wikimedia Commons contributors. The author and license for each photo are listed in `Images/photos/credits.json` and shown under the photo in the app.

---

Purine levels are approximate and based on published food purine tables. This is general information, not medical advice. Always follow the doctor's guidance.
