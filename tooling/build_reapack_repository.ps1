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

foreach ($toolName in @('ReaProjectLink', 'ReaAssetFlow')) {
  $manifestPath = Join-Path $repoRoot "tools\$toolName\reatools-package.json"
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $source = Join-Path $releaseRoot "$($manifest.id)-$($manifest.version)"
  $target = Join-Path $outputRoot "ReaTools\$($manifest.displayName)"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Get-ChildItem -LiteralPath $source -Force |
    Where-Object Name -ne 'package-inventory.json' |
    Copy-Item -Destination $target -Recurse -Force
}

@'
--name ReaTools
--about README.md
--ignore ReaTools/ReaProjectLink/lib
--ignore ReaTools/ReaAssetFlow/scripts
--ignore ReaTools/ReaAssetFlow/requirements.txt
--commit-template "index: $changelog

[ci skip]"
'@ | Set-Content -LiteralPath (Join-Path $outputRoot '.reapack-index.conf') -Encoding utf8

@'
# ReaTools

ReaPack repository for ReaProjectLink, ReaAssetFlow, and future ReaTools.

Packages are independently versioned and self-contained. ReaAssetFlow requires
an explicit one-time Python dependency setup after its ReaPack files are
installed; optional LLM features also require Ollama.
'@ | Set-Content -LiteralPath (Join-Path $outputRoot 'README.md') -Encoding utf8

Write-Output "Built ReaPack repository source: $outputRoot"
