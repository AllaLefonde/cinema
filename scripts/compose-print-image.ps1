# One-off manual utility. Composites a folder's poster + second photo plus
# title/director/quote text into a single page-sized image for physical
# printing (one page = both photos + both quotes), at a fixed print
# format and DPI so fonts and margins scale correctly on paper.
#
# Usage:
#   powershell -File scripts/compose-print-image.ps1 -Folder 1 -OutName 1.jpg

param(
  [Parameter(Mandatory=$true)][string]$Folder,
  [string]$OutName,
  [int]$PageNumber
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

# Physical page: 29 x 22 cm, rendered at 300 DPI.
$dpi = 300
function mm($v) { return [int]($v / 25.4 * $dpi) }
function cm($v) { return mm ($v * 10) }

$canvasWidth = cm 29
$canvasHeight = cm 22
$sideMargin = mm 18
$gap = mm (12 * 0.7)

# Canvas size is fixed (page format), independent of the photos, so we can
# create the bitmap/graphics now and use it to measure text before doing
# any layout math that depends on how many lines the quotes wrap to.
$bmp = New-Object System.Drawing.Bitmap -ArgumentList @($canvasWidth, $canvasHeight)
$bmp.SetResolution($dpi, $dpi)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Black)

$bgPath = Join-Path $root "background_sample.jpg"
if (Test-Path $bgPath) {
  $bgImg = [System.Drawing.Image]::FromFile($bgPath)
  # Stretch a single copy to cover the whole page instead of tiling many
  # small repeats of the (much lower-res) source texture.
  $g.DrawImage($bgImg, 0, 0, $canvasWidth, $canvasHeight)
}

$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::FromArgb(179, 179, 179))

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 39, [System.Drawing.FontStyle]::Bold)
$dirFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 24)
$quotesFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 18, [System.Drawing.FontStyle]::Italic)

$leftFormat = New-Object System.Drawing.StringFormat
$leftFormat.Alignment = [System.Drawing.StringAlignment]::Near

$rightFormat = New-Object System.Drawing.StringFormat
$rightFormat.Alignment = [System.Drawing.StringAlignment]::Far
$rightFormat.LineAlignment = [System.Drawing.StringAlignment]::Far

# Fixed font size on every page (no per-page shrinking). If a quote is too
# wide to fit on one line, split it at the space closest to the middle -
# recursively, in case one split still isn't enough - rather than letting
# it get clipped by the drawing rect.
function WrapToFit($text, $maxWidth) {
  if ($g.MeasureString($text, $quotesFont).Width -le $maxWidth) { return $text }
  $spacePositions = @()
  for ($i = 0; $i -lt $text.Length; $i++) {
    if ($text[$i] -eq ' ') { $spacePositions += $i }
  }
  if ($spacePositions.Count -eq 0) { return $text }
  $mid = $text.Length / 2
  $best = $spacePositions | Sort-Object { [Math]::Abs($_ - $mid) } | Select-Object -First 1
  $left = WrapToFit ($text.Substring(0, $best)) $maxWidth
  $right = WrapToFit ($text.Substring($best + 1)) $maxWidth
  return "$left`n$right"
}

$topText = if ($topQuote) { '"' + $topQuote + '" ' + [char]0x2014 + ' ' + $topAuthor } else { "" }
$bottomText = if ($bottomQuote) { '"' + $bottomQuote + '" ' + [char]0x2014 + ' ' + $bottomAuthor } else { "" }

# Split a quote onto two lines once it exceeds 60% of the page width.
$wrapWidth = $canvasWidth * 0.6
if ($topText) { $topText = WrapToFit $topText $wrapWidth }
if ($bottomText) { $bottomText = WrapToFit $bottomText $wrapWidth }

$lineHeight = $quotesFont.GetHeight($g)
$quoteGap = mm 4
$topLines = if ($topQuote) { ($topText -split "`n").Count } else { 0 }
$bottomLines = if ($bottomQuote) { ($bottomText -split "`n").Count } else { 0 }
$topBlockHeight = $lineHeight * $topLines
$bottomBlockHeight = $lineHeight * $bottomLines

# Reserve exactly the space each zone needs: title+director+quote up top,
# quote alone at the bottom - so a long, multi-line quote can never
# overlap the title/director text above it.
$topTextHeight = (mm 30) + $topBlockHeight + $quoteGap
$bottomTextHeight = $bottomBlockHeight + (mm 8)

$availableHeight = $canvasHeight - $topTextHeight - $bottomTextHeight

# Budget for solving image scale (w1+w2 only, gap added back in separately).
$imageWidthBudget = $canvasWidth - (2 * $sideMargin) - $gap
# Total space the content block (w1+gap+w2) centers within - NOT the same
# as $imageWidthBudget above, which already had the gap subtracted once;
# reusing that value here would double-subtract the gap and push the
# whole block left, leaving a bigger right margin than left.
$totalContentSpace = $canvasWidth - (2 * $sideMargin)

$imgPoster = [System.Drawing.Image]::FromFile($poster.FullName)
$imgSecond = [System.Drawing.Image]::FromFile($second.FullName)

$aspect1 = $imgPoster.Width / $imgPoster.Height
$aspect2 = $imgSecond.Width / $imgSecond.Height

$targetHeightByWidth = $imageWidthBudget / ($aspect1 + $aspect2)
$targetHeight = [Math]::Min($targetHeightByWidth, $availableHeight)

$w1 = [int]($targetHeight * $aspect1)
$w2 = [int]($targetHeight * $aspect2)
$targetHeight = [int]$targetHeight

$contentWidth = $w1 + $gap + $w2
$xOffset = $sideMargin + [int](($totalContentSpace - $contentWidth) / 2)
$yOffset = $topTextHeight + [int](($availableHeight - $targetHeight) / 2)

$x1 = $xOffset
$x2 = $xOffset + $w1 + $gap

$borderPen = New-Object System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::FromArgb(217, 217, 217), (mm 0.5))

$g.DrawImage($imgPoster, $x1, $yOffset, $w1, $targetHeight)
$g.DrawImage($imgSecond, $x2, $yOffset, $w2, $targetHeight)
$g.DrawRectangle($borderPen, 0, 0, ($canvasWidth - 1), ($canvasHeight - 1))

$titleRect = New-Object System.Drawing.RectangleF -ArgumentList @($sideMargin, (mm 4), ($canvasWidth - 2 * $sideMargin), (mm 16))
$g.DrawString($filmName, $titleFont, $white, $titleRect, $leftFormat)
if ($director) {
  $dirRect = New-Object System.Drawing.RectangleF -ArgumentList @($sideMargin, (mm 20), ($canvasWidth - 2 * $sideMargin), (mm 10))
  $g.DrawString("Режиссёр: $director", $dirFont, $muted, $dirRect, $leftFormat)
}

if ($topQuote) {
  $topRect = New-Object System.Drawing.RectangleF -ArgumentList @(0, ($yOffset - $quoteGap - $topBlockHeight), ($x2 + $w2), $topBlockHeight)
  $g.DrawString($topText, $quotesFont, $white, $topRect, $rightFormat)
}

if ($bottomQuote) {
  $bottomRect = New-Object System.Drawing.RectangleF -ArgumentList @($x1, ($yOffset + $targetHeight + $quoteGap), ($canvasWidth - $sideMargin - $x1), $bottomBlockHeight)
  $g.DrawString($bottomText, $quotesFont, $white, $bottomRect, $leftFormat)
}

if ($PageNumber -gt 0) {
  $pageNumFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 16)
  $pageNumRect = New-Object System.Drawing.RectangleF -ArgumentList @(0, ($canvasHeight - (mm 14)), ($canvasWidth - (mm 10)), (mm 10))
  $g.DrawString("$PageNumber", $pageNumFont, $muted, $pageNumRect, $rightFormat)
}

$ext = $poster.Extension
$outName = if ($OutName) { $OutName } elseif ($order) { "$base`_$order$ext" } else { "$base`_$Folder$ext" }
$outDir = Join-Path $root "all2"
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
if ($bgImg) { $bgImg.Dispose() }

Write-Output "Saved: $outPath"
