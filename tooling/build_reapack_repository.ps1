param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'dist\reapack' }
$outputRoot = [System.IO.Path]::GetFullPath($OutputPath)
$releaseRoot = Join-Path $repoRoot 'dist\release-source'

if (Test-Path -LiteralPath $outputRoot) {
  Remove-Item -LiteralPath $outputRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

& (Join-Path $PSScriptRoot 'build_release.ps1') -Tool All -OutputPath $releaseRoot

foreach ($manifestFile in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') `
    -Filter 'reatools-package.json' -Recurse -File | Sort-Object FullName) {
  $manifestPath = $manifestFile.FullName
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $source = Join-Path $releaseRoot "$($manifest.id)-$($manifest.version)"
  $target = Join-Path $outputRoot "ReaTools\$($manifest.displayName)"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Get-ChildItem -LiteralPath $source -Force |
    Where-Object Name -ne 'package-inventory.json' |
    Copy-Item -Destination $target -Recurse -Force
}

$config = [System.Collections.Generic.List[string]]::new()
$config.Add('--name ReaTools')
$config.Add('--about README.md')
foreach ($productDir in Get-ChildItem -LiteralPath (Join-Path $outputRoot 'ReaTools') -Directory) {
  foreach ($relative in @('lib', 'scripts', 'requirements.txt')) {
    $candidate = Join-Path $productDir.FullName $relative
    if (Test-Path -LiteralPath $candidate) {
      $config.Add("--ignore ReaTools/$($productDir.Name)/$relative")
    }
  }
}
$config.Add('--commit-template "index: $changelog')
$config.Add('')
$config.Add('[ci skip]"')
$config | Set-Content -LiteralPath (Join-Path $outputRoot '.reapack-index.conf') -Encoding utf8

@'
# ReaTools

ReaPack repository for ReaProjectLink, ReaAssetFlow, and future ReaTools.

Packages are independently versioned and self-contained. ReaAssetFlow requires
an explicit one-time Python dependency setup after its ReaPack files are
installed; optional LLM features also require Ollama.
'@ | Set-Content -LiteralPath (Join-Path $outputRoot 'README.md') -Encoding utf8

Write-Output "Built ReaPack repository source: $outputRoot"
