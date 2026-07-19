# One-off manual utility. Composites a title/cover page image using the
# same page format, background texture and text styling as
# compose-print-image.ps1.
#
# Usage:
#   powershell -File scripts/compose-title-page.ps1

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
$muted = New-Object System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::FromArgb(179, 179, 179))

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Arial", 50, [System.Drawing.FontStyle]::Bold)
$lineFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 30, [System.Drawing.FontStyle]::Italic)
$lineFontUpright = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 30, [System.Drawing.FontStyle]::Regular)
$smallFont = New-Object System.Drawing.Font -ArgumentList @("Comic Sans MS", 20, [System.Drawing.FontStyle]::Regular)

$centerFormat = New-Object System.Drawing.StringFormat
$centerFormat.Alignment = [System.Drawing.StringAlignment]::Center

$textWidth = $canvasWidth - (2 * $sideMargin)
$x = $sideMargin

$titleHeight = $titleFont.GetHeight($g)
$lineHeight = $lineFont.GetHeight($g)
$smallHeight = $smallFont.GetHeight($g)
$titleGap = mm 24
$lineGap = mm 2
$smallGap = mm 24

$blockHeight = $titleHeight + $titleGap + $lineHeight + $lineGap + $lineHeight + $lineGap + $lineHeight + $smallGap + $smallHeight
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

$cropsDir = Join-Path $root "0_crops"
if (Test-Path $cropsDir) {
  $cropFiles = Get-ChildItem $cropsDir -Filter "*.png" | Get-Random -Count 100 | ForEach-Object { $_.FullName }
  $half = [Math]::Ceiling($cropFiles.Count / 2)
  $topCrops = $cropFiles[0..($half - 1)]
  $bottomCrops = if ($cropFiles.Count -gt $half) { $cropFiles[$half..($cropFiles.Count - 1)] } else { @() }
  DrawThumbRow $topCrops 0 $blockTop
  DrawThumbRow $bottomCrops $blockBottom ($canvasHeight - $blockBottom)
}

$titleRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $titleHeight)
$g.DrawString("Кино от Димы Конрадта", $titleFont, $white, $titleRect, $centerFormat)
$y += $titleHeight + $titleGap

$participRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $lineHeight)
$g.DrawString("при участии:", $lineFontUpright, $white, $participRect, $centerFormat)
$y += $lineHeight + $lineGap

$bartoRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $lineHeight)
$g.DrawString("Агнии Барто", $lineFont, $white, $bartoRect, $centerFormat)
$y += $lineHeight + $lineGap

$brodskyRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $lineHeight)
$g.DrawString("Иосифа Бродского", $lineFont, $white, $brodskyRect, $centerFormat)
$y += $lineHeight + $smallGap

$collectedRect = New-Object System.Drawing.RectangleF -ArgumentList @($x, $y, $textWidth, $smallHeight)
$g.DrawString("Нарезала Алла Лефондэ", $smallFont, $muted, $collectedRect, $centerFormat)

$outDir = Join-Path $root "all2"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath = Join-Path $outDir "0_0.jpg"

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
[System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
$ms.Dispose()

$g.Dispose()
$bmp.Dispose()
if ($bgImg) { $bgImg.Dispose() }

Write-Output "Saved: $outPath"
