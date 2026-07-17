# One-off batch runner: composites a page image for every folder, in the
# same order the site presents them (grouped by film, ordered within each
# group), named <filmNumber>_<orderNumber>.jpg.
$root = "C:\Users\ALLA\IdeaProjects\cinema"
$dataPath = Join-Path $root "films-data.js"
$raw = Get-Content $dataPath -Raw -Encoding UTF8
$json = $raw -replace '^\s*window\.FILMS\s*=\s*', '' -replace ';\s*$', ''
$data = $json | ConvertFrom-Json

$filmNum = 0
foreach ($group in $data.groups) {
  $filmNum++
  $orderNum = 0
  foreach ($f in $group.folders) {
    $orderNum++
    $outName = "$filmNum`_$orderNum`_$($f.folder).jpg"
    Write-Output "Folder $($f.folder) -> $outName"
    powershell -File (Join-Path $root "scripts\compose-page-image.ps1") -Folder $f.folder -OutName $outName
  }
}
