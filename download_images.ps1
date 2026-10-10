# Download a real photo of each food into Images\photos (Windows).
# Double-click download_images.bat, or run:
#   powershell -ExecutionPolicy Bypass -File download_images.ps1
#
# - Food list and photo sources: Images\photo-sources.json
#   Each value is either a Wikimedia Commons file ("File:Something.jpg"), used as is,
#   or a Wikipedia article name, whose main photo is used.
# - Saves Images\photos\<food-id>.jpg (max 900 px) and Images\photos\thumbs\<food-id>.jpg (160 px)
# - Writes photographer + license to Images\photos\credits.json and credits.js (shown under each photo)
# - Photos already downloaded from the same source are skipped, so it's safe to run again.
#   If you change a food's source, its photo is downloaded again. Your own photos are never replaced.
# - If Wikimedia says "too many requests", it waits and tries again.

$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Add-Type -AssemblyName System.Drawing

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$img    = Join-Path $here "Images"
$out    = Join-Path $img "photos"
$thumbs = Join-Path $out "thumbs"
New-Item -ItemType Directory -Force -Path $thumbs | Out-Null
$ua    = "GoutFoodGuide/2.0 (family food guide; one-time download of about 200 food photos; Windows PowerShell)"
$width = 960   # a standard Wikimedia thumbnail size, served faster and rate-limited less
$utf8  = New-Object System.Text.UTF8Encoding $false

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }

# Fetch a URL (JSON, or to a file with -OutFile), waiting and retrying when Wikimedia is busy or rate-limiting
function Invoke-Wiki([string]$uri, [string]$outFile) {
    for ($a = 0; $a -lt 12; $a++) {
        try {
            if ($outFile) { Invoke-WebRequest -Uri $uri -OutFile $outFile -UserAgent $ua -UseBasicParsing -TimeoutSec 60; return }
            return Invoke-RestMethod -Uri $uri -UserAgent $ua -TimeoutSec 30
        } catch [System.Net.WebException] {
            $resp = $_.Exception.Response
            $code = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ((@(429, 500, 502, 503, 504) -notcontains $code) -or $a -eq 11) { throw }
            $wait = 0
            if (-not [int]::TryParse([string]$resp.Headers["Retry-After"], [ref]$wait) -or $wait -le 0) { $wait = 5 * [Math]::Pow(2, [Math]::Min($a, 4)) }
            $wait = [Math]::Min($wait, 120)
            if ($code -eq 429) { Write-Host "    Wikimedia asked us to slow down. Waiting $wait seconds..." -ForegroundColor DarkGray }
            Start-Sleep -Seconds $wait
        }
    }
}

# Compare Commons file names, ignoring "File:", spaces vs underscores and first-letter case
function Normalize-File([string]$s) {
    if (-not $s) { return "" }
    $s = ([Uri]::UnescapeDataString($s)).Replace("_", " ").Trim() -replace "^(?i)(File|Image):", ""
    $s = $s.Trim()
    if ($s.Length -eq 0) { return "" }
    return $s.Substring(0, 1).ToUpper() + $s.Substring(1)
}
function File-Of($credit) {
    if (-not $credit) { return "" }
    $u = [string]$credit.url
    $k = $u.IndexOf("/wiki/")
    if ($k -lt 0) { return "" }
    return $u.Substring($k + 6)
}

function Save-Jpeg($bmp, [string]$path, [long]$quality) {
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), $quality
    $bmp.Save($path, $jpegCodec, $ep)
}

function Draw-Image($src, [int]$w, [int]$h, $srcRect) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $bmp
}

# Make the 900 px photo (optional) and the 160 px square thumbnail from an image file
function Convert-Photo([string]$file, [string]$photoPath, [string]$thumbPath) {
    $ms  = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($file))
    $src = [System.Drawing.Image]::FromStream($ms)
    try {
        if ($photoPath) {
            $scale = [Math]::Min(1.0, 900.0 / [Math]::Max($src.Width, $src.Height))
            $w = [int][Math]::Round($src.Width * $scale); $h = [int][Math]::Round($src.Height * $scale)
            $full = Draw-Image $src $w $h (New-Object System.Drawing.Rectangle 0, 0, $src.Width, $src.Height)
            Save-Jpeg $full $photoPath 82; $full.Dispose()
        }
        $side = [Math]::Min($src.Width, $src.Height)
        $sx = [int](($src.Width - $side) / 2); $sy = [int](($src.Height - $side) / 2)
        $t = Draw-Image $src 160 160 (New-Object System.Drawing.Rectangle $sx, $sy, $side, $side)
        Save-Jpeg $t $thumbPath 78; $t.Dispose()
    } finally { $src.Dispose(); $ms.Dispose() }
}

function Strip-Html([string]$s) {
    if (-not $s) { return "" }
    $s = $s -replace "<[^>]+>", "" -replace "\s+", " "
    $s = [System.Net.WebUtility]::HtmlDecode($s).Trim()
    if ($s.Length -gt 120) { $s = $s.Substring(0, 120) }
    return $s
}

$sources = [System.IO.File]::ReadAllText((Join-Path $img "photo-sources.json"), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$credPath = Join-Path $out "credits.json"
$credits = @{}
if (Test-Path $credPath) {
    $old = [System.IO.File]::ReadAllText($credPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($p in $old.PSObject.Properties) { $credits[$p.Name] = $p.Value }
}

$items = @($sources.PSObject.Properties)
$total = $items.Count
$ok = 0; $skipped = 0; $failed = @()
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gout-food-" + [guid]::NewGuid().ToString() + ".img")

# 1. Work out which foods need a photo, and which Commons file each one uses
$todo = New-Object System.Collections.Specialized.OrderedDictionary
foreach ($item in $items) {
    $id = $item.Name; $src = [string]$item.Value
    $photo = Join-Path $out ($id + ".jpg")
    $have = (Test-Path $photo) -and ((Get-Item $photo).Length -gt 0)
    $from = File-Of $credits[$id]
    if ($have -and -not $from) { $skipped++; continue }                       # your own photo: never replaced
    if ($have -and $src.StartsWith("File:") -and ((Normalize-File $from) -eq (Normalize-File $src))) { $skipped++; continue }  # same source
    if ($have -and -not $src.StartsWith("File:")) { $skipped++; continue }    # article source: keep what we have
    $todo[$id] = $src
}
Write-Host "$total foods, $skipped already have a photo, $($todo.Count) to download."
Write-Host ""

$files = @{}
foreach ($id in @($todo.Keys)) {
    $src = [string]$todo[$id]
    if ($src.StartsWith("File:")) { $files[$id] = $src; continue }
    try {
        $sum = Invoke-Wiki ("https://en.wikipedia.org/api/rest_v1/page/summary/" + [Uri]::EscapeDataString($src.Replace(" ", "_")))
        $srcUrl = $null
        if ($sum.originalimage) { $srcUrl = $sum.originalimage.source } elseif ($sum.thumbnail) { $srcUrl = $sum.thumbnail.source }
        if ($srcUrl -and $srcUrl -match "/wikipedia/commons/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?#]+)") {
            $files[$id] = "File:" + [Uri]::UnescapeDataString($Matches[1])
        }
    } catch { Write-Host "    could not read the Wikipedia article for ${id}: $($_.Exception.Message)" -ForegroundColor Yellow }
    Start-Sleep -Milliseconds 500
}

# Look up photo details 50 files at a time
Write-Host "Looking up photo details on Wikimedia Commons..."
$info = @{}
$names = @($files.Values | Where-Object { $_ } | Sort-Object -Unique)
for ($k = 0; $k -lt $names.Count; $k += 50) {
    $chunk = $names[$k..([Math]::Min($k + 49, $names.Count - 1))]
    $q = "https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&prop=imageinfo&iiprop=url%7Cextmetadata" +
         "&iiextmetadatafilter=Artist%7CLicenseShortName&iiurlwidth=$width&titles=" + [Uri]::EscapeDataString(($chunk -join "|"))
    $d = Invoke-Wiki $q
    $back = @{}
    foreach ($n in @($d.query.normalized)) { if ($n) { $back[$n.to] = $n.from } }
    foreach ($page in @($d.query.pages)) {
        if ($page.imageinfo) {
            $name = if ($back.ContainsKey($page.title)) { $back[$page.title] } else { $page.title }
            $info[$name] = $page.imageinfo[0]
        }
    }
    Start-Sleep -Seconds 1
}

# 2. Download each photo
$i = 0
foreach ($id in @($todo.Keys)) {
    $i++
    $src = [string]$todo[$id]
    $photo = Join-Path $out ($id + ".jpg")
    try {
        if (-not $files[$id]) { throw "no free photo on the Wikipedia article" }
        $ii = $info[$files[$id]]
        if (-not $ii) { throw "photo is not on Wikimedia Commons" }
        $dl = if ($ii.thumburl) { $ii.thumburl } else { $ii.url }

        Invoke-Wiki $dl $tmp
        Convert-Photo $tmp $photo (Join-Path $thumbs ($id + ".jpg"))

        $credits[$id] = [ordered]@{
            artist  = Strip-Html $ii.extmetadata.Artist.value
            license = Strip-Html $ii.extmetadata.LicenseShortName.value
            url     = [string]$ii.descriptionurl
        }
        $ok++
        Write-Host "[$i/$($todo.Count)] $id"
    } catch {
        $failed += "$id`t$src`t$($_.Exception.Message)"
        Write-Host "[$i/$($todo.Count)] no photo: $id ($($_.Exception.Message))" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2   # Wikimedia limits how fast photos can be downloaded
}
if (Test-Path $tmp) { Remove-Item $tmp -Force }

# Photos you added yourself: list them and make their thumbnails
foreach ($f in (Get-ChildItem -Path $out -Filter *.jpg -File)) {
    $id = $f.BaseName
    if (-not $credits.ContainsKey($id)) { $credits[$id] = [ordered]@{ artist = ""; license = ""; url = "" } }
    $tp = Join-Path $thumbs $f.Name
    if (-not (Test-Path $tp)) { try { Convert-Photo $f.FullName $null $tp } catch { Write-Host "Could not make a thumbnail for $($f.Name)" -ForegroundColor Yellow } }
}

# Keep only entries that have a photo file, sorted by id
$sorted = [ordered]@{}
foreach ($k in ($credits.Keys | Sort-Object)) {
    if (Test-Path (Join-Path $out ($k + ".jpg"))) { $sorted[$k] = $credits[$k] }
}
$json = if ($sorted.Count -gt 0) { $sorted | ConvertTo-Json -Depth 4 } else { "{}" }
[System.IO.File]::WriteAllText($credPath, $json, $utf8)
[System.IO.File]::WriteAllText((Join-Path $out "credits.js"), "window.PHOTO_CREDITS = " + $json + ";`n", $utf8)

Write-Host ""
Write-Host "Downloaded $ok, already had $skipped, no photo for $($failed.Count) of $total foods."
$failPath = Join-Path $here "failed-images.txt"
if ($failed.Count -gt 0) {
    [System.IO.File]::WriteAllText($failPath, (($failed -join "`n") + "`n"), $utf8)
    Write-Host "Those foods keep their illustration. The list is in failed-images.txt."
    Write-Host "Run this again to retry, or add your own photo as Images\photos\<food-id>.jpg"
} elseif (Test-Path $failPath) { Remove-Item $failPath -Force }
Write-Host "Open index.html to check the photos, then upload to GitHub."
