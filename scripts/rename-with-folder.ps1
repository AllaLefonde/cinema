# One-off: renames all/<filmNumber>_<orderNumber>.jpg to
# all/<filmNumber>_<orderNumber>_<folderName>.jpg
$root = "C:\Users\ALLA\IdeaProjects\cinema"
$dataPath = Join-Path $root "films-data.js"
$raw = Get-Content $dataPath -Raw -Encoding UTF8
$json = $raw -replace '^\s*window\.FILMS\s*=\s*', '' -replace ';\s*$', ''
$data = $json | ConvertFrom-Json

$allDir = Join-Path $root "all"

$filmNum = 0
foreach ($group in $data.groups) {
  $filmNum++
  $orderNum = 0
  foreach ($f in $group.folders) {
    $orderNum++
    $oldName = "$filmNum`_$orderNum.jpg"
    $oldPath = Join-Path $allDir $oldName
    if (Test-Path $oldPath) {
      $newName = "$filmNum`_$orderNum`_$($f.folder).jpg"
      $newPath = Join-Path $allDir $newName
      Rename-Item -Path $oldPath -NewName $newName -Force
      Write-Output "$oldName -> $newName"
    } else {
      Write-Output "MISSING: $oldPath"
    }
  }
}
