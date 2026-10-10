#!/usr/bin/env python3
"""Download a real photo of each food into Images/photos.

Mac: double-click download_images.command.  Anything with Python: python3 download_images.py
(Windows: double-click download_images.bat instead.)

- Food list and photo sources: Images/photo-sources.json
  Each value is either a Wikimedia Commons file ("File:Something.jpg"), used as is,
  or a Wikipedia article name, whose main photo is used.
- Saves Images/photos/<food-id>.jpg (max 900 px) and Images/photos/thumbs/<food-id>.jpg (160 px)
- Writes photographer + license to Images/photos/credits.json and credits.js (shown under each photo)
- Photos already downloaded from the same source are skipped, so it's safe to run again.
  If you change a food's source, its photo is downloaded again. Your own photos are never replaced.
- If Wikimedia says "too many requests", it waits and tries again.

Uses only what comes with Python. Resizes with Pillow if installed, otherwise with the Mac's built-in `sips`.
"""
import html, json, os, re, shutil, ssl, subprocess, sys, tempfile, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, "Images")
OUT = os.path.join(IMG, "photos")
THUMBS = os.path.join(OUT, "thumbs")
UA = "GoutFoodGuide/2.0 (family food guide; one-time download of about 200 food photos; python)"
WIDTH = 960  # a standard Wikimedia thumbnail size, served faster and rate-limited less

try:
    from PIL import Image, ImageOps
except ImportError:
    Image = None


def fetch(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read()
    except urllib.error.HTTPError:
        raise
    except Exception as e:
        # Some Python installs on Mac have no certificates set up; fall back to the built-in curl.
        if isinstance(getattr(e, "reason", e), ssl.SSLError) and shutil.which("curl"):
            return subprocess.run(["curl", "-fsSL", "-A", UA, "--max-time", str(timeout), url],
                                  check=True, capture_output=True).stdout
        raise


def get_bytes(url, timeout=60):
    """Fetch a URL, waiting and retrying when Wikimedia is busy or rate-limiting."""
    for attempt in range(12):
        try:
            return fetch(url, timeout)
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == 11:
                raise
            wait = e.headers.get("Retry-After", "")
            wait = int(wait) if wait.isdigit() else 5 * 2 ** min(attempt, 4)
            if e.code == 429:
                print(f"    Wikimedia asked us to slow down. Waiting {min(wait, 120)} seconds...")
            time.sleep(min(wait, 120))


def get_json(url):
    try:
        return json.loads(get_bytes(url, 30).decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def strip_html(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    return html.unescape(re.sub(r"\s+", " ", s)).strip()[:120]


def same_file(a, b):
    """Compare two Commons file names, ignoring 'File:', spaces vs underscores and first-letter case."""
    def n(s):
        s = urllib.parse.unquote(s or "").replace("_", " ").strip()
        s = re.sub(r"^(File|Image):", "", s, flags=re.I).strip()
        return s[:1].upper() + s[1:]
    return n(a) == n(b)


def file_of(credit):
    url = (credit or {}).get("url") or ""
    return url.split("/wiki/", 1)[1] if "/wiki/" in url else ""


def article_file(title):
    """The Commons file name of a Wikipedia article's main photo, or None."""
    summ = get_json("https://en.wikipedia.org/api/rest_v1/page/summary/" + urllib.parse.quote(title.replace(" ", "_"), safe=""))
    src = summ and ((summ.get("originalimage") or {}).get("source") or (summ.get("thumbnail") or {}).get("source"))
    m = src and re.search(r"/wikipedia/commons/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?#]+)", src)
    return "File:" + urllib.parse.unquote(m.group(1)) if m else None


def commons_info(files):
    """Look up many Commons files at once (50 per request). Returns {file name: imageinfo}."""
    out = {}
    for i in range(0, len(files), 50):
        chunk = files[i:i + 50]
        d = get_json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
            "action": "query", "format": "json", "formatversion": "2", "prop": "imageinfo",
            "iiprop": "url|extmetadata", "iiextmetadatafilter": "Artist|LicenseShortName",
            "iiurlwidth": str(WIDTH), "titles": "|".join(chunk)})) or {}
        q = d.get("query", {})
        back = {n["to"]: n["from"] for n in q.get("normalized", [])}
        for page in q.get("pages", []):
            if page.get("imageinfo"):
                out[back.get(page["title"], page["title"])] = page["imageinfo"][0]
        time.sleep(1)
    return out


def convert(src_file, photo_path, thumb_path):
    """Make the 900 px photo (if photo_path) and a 160 px square thumbnail."""
    if Image:
        im = ImageOps.exif_transpose(Image.open(src_file))
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            bg = Image.new("RGB", im.size, (255, 255, 255))
            bg.paste(im, mask=im.split()[-1])
            im = bg
        im = im.convert("RGB")
        if photo_path:
            big = im.copy()
            big.thumbnail((900, 900), Image.LANCZOS)
            big.save(photo_path, "JPEG", quality=82, optimize=True, progressive=True)
        ImageOps.fit(im, (160, 160), Image.LANCZOS).save(thumb_path, "JPEG", quality=78, optimize=True)
        return
    if not shutil.which("sips"):
        raise RuntimeError("needs Pillow (pip install pillow) or a Mac")
    def sips(*args):
        return subprocess.run(["sips", *args], check=True, capture_output=True, text=True).stdout
    if photo_path:
        sips("-s", "format", "jpeg", "-s", "formatOptions", "82", "-Z", "900", src_file, "--out", photo_path)
    dims = sips("-g", "pixelWidth", "-g", "pixelHeight", src_file)
    w = int(re.search(r"pixelWidth: (\d+)", dims).group(1)); h = int(re.search(r"pixelHeight: (\d+)", dims).group(1))
    resize = ["--resampleWidth", "160"] if w < h else ["--resampleHeight", "160"]
    sips("-s", "format", "jpeg", "-s", "formatOptions", "78", *resize, src_file, "--out", thumb_path)
    sips("-c", "160", "160", thumb_path)


def main():
    os.makedirs(THUMBS, exist_ok=True)
    sources = json.load(open(os.path.join(IMG, "photo-sources.json"), encoding="utf-8"))
    cred_path = os.path.join(OUT, "credits.json")
    credits = json.load(open(cred_path, encoding="utf-8")) if os.path.exists(cred_path) else {}
    total = len(sources)
    ok, skipped, failed = 0, 0, []
    tmp = os.path.join(tempfile.gettempdir(), "gout-food-download.img")

    # 1. Work out which foods need a photo, and which Commons file each one uses
    todo = {}
    for fid, src in sources.items():
        photo = os.path.join(OUT, fid + ".jpg")
        have = os.path.exists(photo) and os.path.getsize(photo) > 0
        if have and not file_of(credits.get(fid)):
            skipped += 1          # your own photo: never replaced
            continue
        if have and src.startswith("File:") and same_file(file_of(credits.get(fid)), src):
            skipped += 1          # already downloaded from this source
            continue
        if have and not src.startswith("File:"):
            skipped += 1          # article source: keep what we have
            continue
        todo[fid] = src
    print(f"{total} foods, {skipped} already have a photo, {len(todo)} to download.\n")

    files = {}
    for fid, src in todo.items():
        if src.startswith("File:"):
            files[fid] = src
        else:
            try:
                files[fid] = article_file(src)
            except Exception as e:
                files[fid] = None
                print(f"    could not read the Wikipedia article for {fid}: {e}")
            time.sleep(0.5)
    print("Looking up photo details on Wikimedia Commons...")
    info = commons_info(sorted({f for f in files.values() if f}))

    # 2. Download each photo
    for i, (fid, src) in enumerate(todo.items(), 1):
        photo = os.path.join(OUT, fid + ".jpg")
        try:
            if not files.get(fid):
                raise RuntimeError("no free photo on the Wikipedia article")
            ii = info.get(files[fid])
            if not ii:
                raise RuntimeError("photo is not on Wikimedia Commons")
            with open(tmp, "wb") as f:
                f.write(get_bytes(ii.get("thumburl") or ii["url"]))
            convert(tmp, photo, os.path.join(THUMBS, fid + ".jpg"))
            meta = ii.get("extmetadata", {})
            credits[fid] = {
                "artist": strip_html(meta.get("Artist", {}).get("value", "")),
                "license": strip_html(meta.get("LicenseShortName", {}).get("value", "")),
                "url": ii.get("descriptionurl", ""),
            }
            ok += 1
            print(f"[{i}/{len(todo)}] {fid}")
        except Exception as e:
            failed.append(f"{fid}\t{src}\t{str(e)[:150]}")
            print(f"[{i}/{len(todo)}] no photo: {fid} ({str(e)[:80]})")
        time.sleep(2)  # Wikimedia limits how fast photos can be downloaded
    if os.path.exists(tmp):
        os.remove(tmp)

    # Photos you added yourself: list them and make their thumbnails
    for f in sorted(os.listdir(OUT)):
        if f.lower().endswith(".jpg"):
            fid = f[:-4]
            credits.setdefault(fid, {"artist": "", "license": "", "url": ""})
            tp = os.path.join(THUMBS, f)
            if not os.path.exists(tp):
                try:
                    convert(os.path.join(OUT, f), None, tp)
                except Exception:
                    print(f"Could not make a thumbnail for {f}")

    credits = {k: credits[k] for k in sorted(credits) if os.path.exists(os.path.join(OUT, k + ".jpg"))}
    text = json.dumps(credits, ensure_ascii=False, indent=1)
    open(cred_path, "w", encoding="utf-8").write(text)
    open(os.path.join(OUT, "credits.js"), "w", encoding="utf-8").write("window.PHOTO_CREDITS = " + text + ";\n")

    print(f"\nDownloaded {ok}, already had {skipped}, no photo for {len(failed)} of {total} foods.")
    fail_path = os.path.join(HERE, "failed-images.txt")
    if failed:
        open(fail_path, "w", encoding="utf-8").write("\n".join(failed) + "\n")
        print("Those foods keep their illustration. The list is in failed-images.txt.")
        print("Run this again to retry, or add your own photo as Images/photos/<food-id>.jpg")
    elif os.path.exists(fail_path):
        os.remove(fail_path)
    print("Open index.html to check the photos, then upload to GitHub.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
