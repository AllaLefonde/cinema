# One-off manual utility. Composites a closing/credits page image using the
# same page format, background texture and text styling as
# compose-title-page.ps1 - lists every director as a wrapped block of text,
# with a face-crop collage (from 0_crop_last/) in the empty top/bottom bands.
#
# Usage:
#   powershell -File scripts/compose-last-page.ps1

Add-Type -AssemblyName System.Drawing

$root = (Get-Location).Path

$dpi = 300
function mm($v) { return [int]($v / 25.4 * $dpi) }
function cm($v) { return mm ($v * 10) }

$canvasWidth = cm 29
$canvasHeight = cm 22
$sideMargin = mm 18

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
  $g.DrawImage($bgImg, 0, 0, $canvasWidth, $canvasHeight)
}

$borderPen = New-Object System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::FromArgb(217, 217, 217), (mm 0.5))
$g.DrawRectangle($borderPen, 0, 0, ($canvasWidth - 1), ($canvasHeight - 1))

$white = [System.Drawing.Brushes]::White

$headingFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 30, [System.Drawing.FontStyle]::Regular)
$namesFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 26, [System.Drawing.FontStyle]::Regular)

$centerFormat = New-Object System.Drawing.StringFormat
$centerFormat.Alignment = [System.Drawing.StringAlignment]::Center

# Collect the unique directors from films-data.js, in the same order their
# films appear in the site/viewer (films-data.js groups order - the same
# sequence the 127 combined pages in all2/ are numbered in), not alphabetical.
$dataPath = Join-Path $root "films-data.js"
$raw = Get-Content $dataPath -Raw -Encoding UTF8
$json = $raw -replace '^\s*window\.FILMS\s*=\s*', '' -replace ';\s*$', ''
$data = $json | ConvertFrom-Json
$directors = $data.groups | Where-Object { $_.director } | ForEach-Object { $_.director.ru } | Select-Object -Unique
$namesText = $directors -join ", "

$textWidth = $canvasWidth - (2 * $sideMargin)
$x = $sideMargin

$headingHeight = $headingFont.GetHeight($g)
$headingGap = mm 12

# Wrap the names into a block roughly as tall as it is wide, rather than
# one long line - measure at a candidate width, then pick the narrowest
# width whose wrapped block height doesn't exceed its width.
$blockWidth = $textWidth
$namesRectMeasure = New-Object System.Drawing.RectangleF -ArgumentList @(0, 0, $blockWidth, 5000)
for ($w = [int]($textWidth * 0.4); $w -le $textWidth; $w += [int]($textWidth * 0.05)) {
  $namesRectMeasure = New-Object System.Drawing.RectangleF -ArgumentList @(0, 0, $w, 5000)
  $measured = $g.MeasureString($namesText, $namesFont, [System.Drawing.SizeF]::new($w, 5000))
  if ($measured.Height -le $w) { $blockWidth = $w; break }
}
$namesSize = $g.MeasureString($namesText, $namesFont, [System.Drawing.SizeF]::new($blockWidth, 5000))
$namesHeight = $namesSize.Height

$blockHeight = $headingHeight + $headingGap + $namesHeight
$y = ($canvasHeight - $blockHeight) / 2
$blockTop = $y
$blockBottom = $y + $blockHeight

function DrawThumbRow($files, $bandTop, $bandHeight) {
  if ($files.Count -eq 0) { return }
  $vPad = mm 10
  $gapPx = mm 6
  $availH = $bandHeight - (2 * $vPad)
  if ($availH -le (mm 10)) { return }

  $aspects = @()
  foreach ($f in $files) {
    $img = [System.Drawing.Image]::FromFile($f)
    $aspects += ($img.Width / $img.Height)
    $img.Dispose()
  }
  $sumAspect = ($aspects | Measure-Object -Sum).Sum
  $maxWidth = $canvasWidth - (2 * $sideMargin)
  $gapsTotal = $gapPx * [Math]::Max($files.Count - 1, 0)
  $hByWidth = ($maxWidth - $gapsTotal) / $sumAspect
  $thumbH = [int]([Math]::Min($availH, $hByWidth))
  $totalW = [int]($thumbH * $sumAspect) + $gapsTotal

  $curX = [int](($canvasWidth - $totalW) / 2)
  $rowY = [int]($bandTop + $vPad + ($availH - $thumbH) / 2)
  $overlay = New-Object System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::FromArgb(140, 0, 0, 0))
  $thumbBorderPen = New-Object System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::FromArgb(217, 217, 217), (mm 0.5))

  foreach ($f in $files) {
    $img = [System.Drawing.Image]::FromFile($f)
    $w = [int]($thumbH * ($img.Width / $img.Height))
    $g.DrawImage($img, $curX, $rowY, $w, $thumbH)
    $g.FillRectangle($overlay, $curX, $rowY, $w, $thumbH)
    $g.DrawRectangle($thumbBorderPen, $curX, $rowY, $w, $thumbH)
    $img.Dispose()
    $curX += $w + $gapPx
  }
}

$cropsDir = Join-Path $root "0_crops_last"
if (Test-Path $cropsDir) {
  $cropFiles = Get-ChildItem $cropsDir -Filter "*.png" | Get-Random -Count 100 | ForEach-Object { $_.FullName }
  if ($cropFiles.Count -gt 0) {
    $half = [Math]::Ceiling($cropFiles.Count / 2)
    $topCrops = $cropFiles[0..($half - 1)]
    $bottomCrops = if ($cropFiles.Count -gt $half) { $cropFiles[$half..($cropFiles.Count - 1)] } else { @() }
    DrawThumbRow $topCrops 0 $blockTop
    DrawThumbRow $bottomCrops $blockBottom ($canvasHeight - $blockBottom)
  }
}

$headingRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $headingHeight)
$g.DrawString("Режиссеры:", $headingFont, $white, $headingRect, $centerFormat)
$y += $headingHeight + $headingGap

$namesX = ($canvasWidth - $blockWidth) / 2
$namesRect = New-Object System.Drawing.RectangleF -ArgumentList @($namesX, $y, $blockWidth, $namesHeight)
$g.DrawString($namesText, $namesFont, $white, $namesRect, $centerFormat)

$outDir = Join-Path $root "all2"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath = Join-Path $outDir "0_last.jpg"

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
[System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
$ms.Dispose()

$g.Dispose()
$bmp.Dispose()
if ($bgImg) { $bgImg.Dispose() }

Write-Output "Saved: $outPath"
