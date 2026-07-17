# One-off manual utility. Composites a folder's poster + second photo plus
# title/director/quote text into a single image that looks like the site's
# film page, without a real browser. Uses .NET System.Drawing (built into
# Windows), no external tools required.
#
# Usage:
#   powershell -File scripts/compose-page-image.ps1 -Folder 1

param(
  [Parameter(Mandatory=$true)][string]$Folder,
  [string]$OutName
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
$change = $false
if (Test-Path $textPath) {
  $lines = Get-Content $textPath -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^order:\s*(.*)$') { $order = $matches[1].Trim() }
    elseif ($line -match '^Иосиф Бродский:\s*(.*)$') { $brodsky = $matches[1].Trim() }
    elseif ($line -match '^Агния Барто:\s*(.*)$') { $barto = $matches[1].Trim() }
    elseif ($line -match '^change:\s*true\s*$') { $change = $true }
  }
}

# Normally Brodsky is shown above the second photo and Barto below the
# poster, matching the site's default "both" layout. change:true swaps
# which quote/author goes in which position.
if ($change) {
  $topQuote = $barto; $topAuthor = "Барто"
  $bottomQuote = $brodsky; $bottomAuthor = "Бродский"
} else {
  $topQuote = $brodsky; $topAuthor = "Бродский"
  $bottomQuote = $barto; $bottomAuthor = "Барто"
}

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
$topTextHeight = 160
$bottomTextHeight = 160

$imgPoster = [System.Drawing.Image]::FromFile($poster.FullName)
$imgSecond = [System.Drawing.Image]::FromFile($second.FullName)

$scale1 = $targetHeight / $imgPoster.Height
$scale2 = $targetHeight / $imgSecond.Height
$w1 = [int]($imgPoster.Width * $scale1)
$w2 = [int]($imgSecond.Width * $scale2)

$x1 = $sideMargin
$x2 = $sideMargin + $w1 + $gap
$canvasWidth = $w1 + $gap + $w2 + (2 * $sideMargin)
$canvasHeight = $targetHeight + $topTextHeight + $bottomTextHeight

$bmp = New-Object System.Drawing.Bitmap -ArgumentList @($canvasWidth, $canvasHeight)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Black)

$borderPen = New-Object System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::FromArgb(217, 217, 217), 2)

$g.DrawImage($imgPoster, $x1, $topTextHeight, $w1, $targetHeight)
$g.DrawImage($imgSecond, $x2, $topTextHeight, $w2, $targetHeight)
$g.DrawRectangle($borderPen, 0, 0, ($canvasWidth - 1), ($canvasHeight - 1))

$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::FromArgb(179, 179, 179))

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 26, [System.Drawing.FontStyle]::Bold)
$dirFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 21)
$quoteFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 28, [System.Drawing.FontStyle]::Italic)

$leftFormat = New-Object System.Drawing.StringFormat
$leftFormat.Alignment = [System.Drawing.StringAlignment]::Near

$rightFormat = New-Object System.Drawing.StringFormat
$rightFormat.Alignment = [System.Drawing.StringAlignment]::Far
$rightFormat.LineAlignment = [System.Drawing.StringAlignment]::Far

$titleRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, 15, $w1, 40)
$g.DrawString($filmName, $titleFont, $white, $titleRect, $leftFormat)
if ($director) {
  $dirRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, 60, $w1, 30)
  $g.DrawString("Режиссёр: $director", $dirFont, $muted, $dirRect, $leftFormat)
}

if ($topQuote) {
  $topText = '"' + $topQuote + '" ' + [char]0x2014 + ' ' + $topAuthor
  $font = $quoteFont
  while ($g.MeasureString($topText, $font).Width -gt ($canvasWidth - (2 * $sideMargin)) -and $font.Size -gt 10) {
    $font = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", ($font.Size - 1), [System.Drawing.FontStyle]::Italic)
  }
  $topRect = New-Object System.Drawing.RectangleF -ArgumentList @(0, 10, ($x2 + $w2), ($topTextHeight - 15))
  $g.DrawString($topText, $font, $white, $topRect, $rightFormat)
}

if ($bottomQuote) {
  $bottomText = '"' + $bottomQuote + '" ' + [char]0x2014 + ' ' + $bottomAuthor
  $font = $quoteFont
  while ($g.MeasureString($bottomText, $font).Width -gt ($canvasWidth - (2 * $sideMargin)) -and $font.Size -gt 10) {
    $font = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", ($font.Size - 1), [System.Drawing.FontStyle]::Italic)
  }
  $bottomRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, ($topTextHeight + $targetHeight + 10), ($canvasWidth - $x1), ($bottomTextHeight - 20))
  $g.DrawString($bottomText, $font, $white, $bottomRect, $leftFormat)
}

$ext = $poster.Extension
$outName = if ($OutName) { $OutName } elseif ($order) { "$base`_$order$ext" } else { "$base`_$Folder$ext" }
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
