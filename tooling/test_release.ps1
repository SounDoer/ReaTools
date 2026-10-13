param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'dist' }

& (Join-Path $PSScriptRoot 'build_release.ps1') -Tool All -OutputPath $OutputPath

foreach ($manifestPath in @(
  'tools\ReaProjectLink\reatools-package.json',
  'tools\ReaAssetFlow\reatools-package.json'
)) {
  $manifest = Get-Content -LiteralPath (Join-Path $repoRoot $manifestPath) -Raw | ConvertFrom-Json
  $releaseRoot = Join-Path $OutputPath "$($manifest.id)-$($manifest.version)"
  $inventoryPath = Join-Path $releaseRoot 'package-inventory.json'
  $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
  if ($inventory.id -ne $manifest.id -or $inventory.version -ne $manifest.version) {
    throw "Inventory identity mismatch: $inventoryPath"
  }
  foreach ($file in $inventory.files) {
    $path = Join-Path $releaseRoot $file.path
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $file.sha256) { throw "Inventory hash mismatch: $path" }
  }
  Write-Output "PASS $($manifest.displayName) release inventory ($($inventory.files.Count) files)"
}
