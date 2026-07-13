# One-off manual utility. Composites a folder's poster + second photo plus
# title/director/quote text into a single image that looks like the site's
# film page, without a real browser. Uses .NET System.Drawing (built into
# Windows), no external tools required.
#
# Usage:
#   powershell -File scripts/compose-page-image.ps1 -Folder 1

param(
  [Parameter(Mandatory=$true)][string]$Folder
)

Add-Type -AssemblyName System.Drawing

$root = (Get-Location).Path
$dir = Join-Path $root $Folder
if (-not (Test-Path $dir)) { throw "Folder not found: $dir" }

$files = Get-ChildItem $dir -File | Where-Object { $_.Extension -match '\.(jpe?g|png|gif|webp)$' }
$poster = $files | Where-Object { $_.Name -match '^\d_' } | Select-Object -First 1
if (-not $poster) { throw "No poster (N_...) file found in $dir" }
$second = $files | Where-Object { $_.Name -ne $poster.Name } | Select-Object -First 1
if (-not $second) { throw "No second image found in $dir" }

$textPath = Join-Path $dir "text.txt"
$order = ""
$brodsky = ""
$barto = ""
if (Test-Path $textPath) {
  $lines = Get-Content $textPath -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^order:\s*(.*)$') { $order = $matches[1].Trim() }
    elseif ($line -match '^Иосиф Бродский:\s*(.*)$') { $brodsky = $matches[1].Trim() }
    elseif ($line -match '^Агния Барто:\s*(.*)$') { $barto = $matches[1].Trim() }
  }
}
$quote = if ($brodsky) { $brodsky } else { $barto }

# Film name from poster filename, same rule as build-manifest.mjs
$base = [System.IO.Path]::GetFileNameWithoutExtension($poster.Name)
$filmName = ($base -replace '^\d_', '') -replace '_', ' '

# Director lookup from film-meta.mjs (best-effort text scan, not a full JS parse)
$director = ""
$metaPath = Join-Path $root "scripts\film-meta.mjs"
if (Test-Path $metaPath) {
  $metaText = Get-Content $metaPath -Raw -Encoding UTF8
  $escaped = [regex]::Escape($filmName)
  if ($metaText -match "(?s)`"$escaped`":\s*\{.*?director:\s*\{\s*ru:\s*`"([^`"]*)`"") {
    $director = $matches[1]
  }
}

$targetHeight = 900
$gap = 40
$sideMargin = 50
$topTextHeight = 115
$bottomMargin = 50

$imgPoster = [System.Drawing.Image]::FromFile($poster.FullName)
$imgSecond = [System.Drawing.Image]::FromFile($second.FullName)

$scale1 = $targetHeight / $imgPoster.Height
$scale2 = $targetHeight / $imgSecond.Height
$w1 = [int]($imgPoster.Width * $scale1)
$w2 = [int]($imgSecond.Width * $scale2)

$x1 = $sideMargin
$x2 = $sideMargin + $w1 + $gap
$canvasWidth = $w1 + $gap + $w2 + (2 * $sideMargin)
$canvasHeight = $targetHeight + $topTextHeight + $bottomMargin

$bmp = New-Object System.Drawing.Bitmap -ArgumentList @($canvasWidth, $canvasHeight)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Black)

$g.DrawImage($imgPoster, $x1, $topTextHeight, $w1, $targetHeight)
$g.DrawImage($imgSecond, $x2, $topTextHeight, $w2, $targetHeight)

$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::FromArgb(179, 179, 179))

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 26, [System.Drawing.FontStyle]::Bold)
$dirFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 21)
$quoteFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 28, [System.Drawing.FontStyle]::Italic)

$leftFormat = New-Object System.Drawing.StringFormat
$leftFormat.Alignment = [System.Drawing.StringAlignment]::Near

$rightFormat = New-Object System.Drawing.StringFormat
$rightFormat.Alignment = [System.Drawing.StringAlignment]::Far

$titleRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, 15, $w1, 40)
$g.DrawString($filmName, $titleFont, $white, $titleRect, $leftFormat)
if ($director) {
  $dirRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, 60, $w1, 30)
  $g.DrawString("Режиссёр: $director", $dirFont, $muted, $dirRect, $leftFormat)
}

if ($quote) {
  $quoteRect = New-Object System.Drawing.RectangleF -ArgumentList @($x2, 20, $w2, ($topTextHeight - 30))
  $quoteText = '"' + $quote + '"'
  $g.DrawString($quoteText, $quoteFont, $white, $quoteRect, $rightFormat)
}

$ext = $poster.Extension
$outName = if ($order) { "$base`_$order$ext" } else { "$base`_$Folder$ext" }
$outDir = Join-Path $root "all"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath = Join-Path $outDir $outName

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
[System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
$ms.Dispose()

$g.Dispose()
$bmp.Dispose()
$imgPoster.Dispose()
$imgSecond.Dispose()

Write-Output "Saved: $outPath"
