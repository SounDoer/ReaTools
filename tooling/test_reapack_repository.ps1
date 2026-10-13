param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'dist\reapack' }

& (Join-Path $PSScriptRoot 'build_reapack_repository.ps1') -OutputPath $OutputPath

$entries = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') `
  -Filter 'reatools-package.json' -Recurse -File | Sort-Object FullName | ForEach-Object {
    $manifest = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    "ReaTools\$($manifest.displayName)\$($manifest.entry)"
  }
foreach ($relative in $entries) {
  $path = Join-Path $OutputPath $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing ReaPack entry: $relative"
  }
  $header = Get-Content -LiteralPath $path -Raw
  foreach ($tag in @('@description', '@version', '@author', '@provides')) {
    if (-not $header.Contains($tag)) { throw "$relative is missing $tag" }
  }
}

$forbidden = Get-ChildItem -LiteralPath $OutputPath -Recurse -Force |
  Where-Object { $_.FullName -match '(__pycache__|\.pytest_cache|[\\/]_state[\\/]|[\\/]_staging[\\/])' }
if ($forbidden) { throw "Generated or user-state files entered the ReaPack tree." }

$indexer = Get-Command reapack-index -ErrorAction SilentlyContinue
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if ($indexer -and $pandoc) {
  Push-Location $OutputPath
  try {
    & git init --quiet
    & git add .
    & git -c user.name=ReaTools -c user.email=release@invalid.local commit `
      --quiet -m 'ReaPack validation snapshot'
    & $indexer.Source --check
    if ($LASTEXITCODE -ne 0) { throw "reapack-index --check failed" }
  } finally {
    Pop-Location
  }
  Write-Output 'PASS ReaPack metadata and reapack-index validation'
} else {
  $missing = @()
  if (-not $indexer) { $missing += 'reapack-index' }
  if (-not $pandoc) { $missing += 'pandoc' }
  Write-Output "PASS ReaPack metadata and layout validation (full index check needs: $($missing -join ', '))"
}
