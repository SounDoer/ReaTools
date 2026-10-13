param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'dist/reapack' }

$sourceIndexes = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') `
  -Filter 'index.xml' -Recurse -File
if ($sourceIndexes) {
  $paths = $sourceIndexes.FullName -join ', '
  throw "Generated ReaPack indexes must live only on the reapack branch: $paths"
}

& (Join-Path $PSScriptRoot 'build_reapack_repository.ps1') -OutputPath $OutputPath

$entries = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') `
  -Filter 'reatools-package.json' -Recurse -File | Sort-Object FullName | ForEach-Object {
    $manifest = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    "ReaTools/$($manifest.displayName)/$($manifest.entry)"
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

$reaprojectlinkRoot = Join-Path $OutputPath 'ReaTools/ReaProjectLink'
$reaprojectlinkReadme = Get-Content -LiteralPath `
  (Join-Path $reaprojectlinkRoot 'README.md') -Raw
$reaprojectlinkEntry = Get-Content -LiteralPath `
  (Join-Path $reaprojectlinkRoot 'ReaProjectLink.lua') -Raw
$canonicalRepository = 'https://github.com/SounDoer/ReaTools'
$canonicalIndex = 'https://raw.githubusercontent.com/SounDoer/ReaTools/reapack/index.xml'
if (-not $reaprojectlinkReadme.Contains($canonicalIndex)) {
  throw 'ReaProjectLink README does not name the unified ReaPack index.'
}
if (-not $reaprojectlinkEntry.Contains($canonicalRepository)) {
  throw 'ReaProjectLink package metadata does not name the canonical repository.'
}
foreach ($legacyOrigin in @(
    'github.com/SounDoer/ReaProjectLink',
    'github.com/SounDoer/ReaperToWwise')) {
  if ($reaprojectlinkReadme.Contains($legacyOrigin) -or
      $reaprojectlinkEntry.Contains($legacyOrigin)) {
    throw "Legacy repository origin entered the ReaProjectLink package: $legacyOrigin"
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
    # The output lives below the source worktree. Passing an explicit path is
    # required so Git creates a nested validation repository instead of finding
    # and reinitializing the source repository above it.
    & git init --quiet .
    & git remote add origin 'https://github.com/SounDoer/ReaTools.git'
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
