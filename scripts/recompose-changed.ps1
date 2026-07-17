# One-off: recomposes page images for folders whose text.txt has
# "change: true" (quotes swapped top/bottom), reusing each folder's
# existing output filename in all/.
$root = "C:\Users\ALLA\IdeaProjects\cinema"
$allDir = Join-Path $root "all"

$folders = Get-ChildItem $root -Directory | Where-Object {
  $tp = Join-Path $_.FullName "text.txt"
  (Test-Path $tp) -and (Select-String -Path $tp -Pattern '^change:\s*true\s*$' -Quiet)
} | ForEach-Object { $_.Name }

foreach ($folder in $folders) {
  $existing = Get-ChildItem $allDir -Filter "*_$folder.jpg" | Select-Object -First 1
  if (-not $existing) {
    Write-Output "SKIP (no existing output found): folder $folder"
    continue
  }
  Write-Output "Folder $folder -> $($existing.Name)"
  powershell -File (Join-Path $root "scripts\compose-page-image.ps1") -Folder $folder -OutName $existing.Name
}
