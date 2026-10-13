param(
  [string]$Tool = 'All',
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'dist' }
$outputRoot = [System.IO.Path]::GetFullPath($OutputPath)
$toolNames = if ($Tool -eq 'All') {
  @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'reatools-package.json') } |
    Sort-Object Name |
    Select-Object -ExpandProperty Name)
} else { @($Tool) }
$uiRoot = Join-Path $repoRoot 'packages/ReaToolUI'
$uiManifest = Get-Content -LiteralPath (Join-Path $uiRoot 'reatools-package.json') -Raw |
  ConvertFrom-Json
$trackedSet = [System.Collections.Generic.HashSet[string]]::new(
  [System.StringComparer]::OrdinalIgnoreCase)
foreach ($tracked in (& git -C $repoRoot ls-files)) {
  [void]$trackedSet.Add($tracked.Replace('\', '/'))
}
if ($LASTEXITCODE -ne 0) { throw 'Could not read the Git release inventory.' }

function Assert-RelativePath([string]$Path, [string]$Label) {
  if ([System.IO.Path]::IsPathRooted($Path) -or $Path -split '[\\/]' -contains '..') {
    throw "$Label must stay inside its declared root: $Path"
  }
}

function Copy-DeclaredItem([string]$ToolRoot, [string]$ReleaseRoot, $Item) {
  Assert-RelativePath $Item.source 'Source path'
  Assert-RelativePath $Item.target 'Target path'
  $source = Join-Path $ToolRoot $Item.source
  if (-not (Test-Path -LiteralPath $source)) { throw "Missing release source: $source" }
  $sources = if (Test-Path -LiteralPath $source -PathType Container) {
    @(Get-ChildItem -LiteralPath $source -Recurse -File)
  } else {
    @((Get-Item -LiteralPath $source))
  }
  $copied = 0
  foreach ($sourceFile in $sources) {
    $repoRelative = [System.IO.Path]::GetRelativePath($repoRoot, $sourceFile.FullName).Replace('\', '/')
    if (-not $trackedSet.Contains($repoRelative)) { continue }
    $suffix = if (Test-Path -LiteralPath $source -PathType Container) {
      [System.IO.Path]::GetRelativePath($source, $sourceFile.FullName)
    } else { '' }
    $target = Join-Path $ReleaseRoot $Item.target
    if ($suffix) { $target = Join-Path $target $suffix }
    $targetParent = Split-Path -Parent $target
    if ($targetParent) { New-Item -ItemType Directory -Force -Path $targetParent | Out-Null }
    Copy-Item -LiteralPath $sourceFile.FullName -Destination $target -Force
    $copied++
  }
  if ($copied -eq 0) { throw "Release declaration contains no tracked files: $source" }
}

function Write-Inventory([string]$ReleaseRoot, $Manifest) {
  $files = Get-ChildItem -LiteralPath $ReleaseRoot -Recurse -File |
    Where-Object Name -ne 'package-inventory.json' |
    Sort-Object FullName |
    ForEach-Object {
      [ordered]@{
        path = [System.IO.Path]::GetRelativePath($ReleaseRoot, $_.FullName).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = $_.Length
      }
    }
  $inventory = [ordered]@{
    schemaVersion = 1
    id = $Manifest.id
    displayName = $Manifest.displayName
    version = $Manifest.version
    uiContract = $Manifest.uiContract
    files = @($files)
  }
  $inventory | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath `
    (Join-Path $ReleaseRoot 'package-inventory.json') -Encoding utf8
}

foreach ($toolName in $toolNames) {
  $toolRoot = Join-Path $repoRoot "tools/$toolName"
  $manifestPath = Join-Path $toolRoot 'reatools-package.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1) { throw "Unsupported manifest schema: $manifestPath" }
  if ($manifest.kind -ne 'reaper-tool') { throw "Not a REAPER tool manifest: $manifestPath" }
  if ($manifest.uiContract.package -ne $uiManifest.id -or
      $manifest.uiContract.version -ne $uiManifest.version) {
    throw "Unsupported ReaToolUI contract in $manifestPath"
  }
  if ($manifest.uiContract.usage -notin @('planned', 'validation-only', 'runtime')) {
    throw "Unsupported uiContract.usage in $manifestPath"
  }

  $releaseRoot = Join-Path $outputRoot "$($manifest.id)-$($manifest.version)"
  if (Test-Path -LiteralPath $releaseRoot) { Remove-Item -LiteralPath $releaseRoot -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
  foreach ($item in $manifest.release.files) {
    Copy-DeclaredItem $toolRoot $releaseRoot $item
  }
  if ($manifest.uiContract.usage -eq 'runtime') {
    if (-not $manifest.uiContract.vendorTarget) {
      throw "runtime uiContract requires vendorTarget in $manifestPath"
    }
    Copy-DeclaredItem $uiRoot $releaseRoot ([pscustomobject]@{
      source = 'lib'
      target = $manifest.uiContract.vendorTarget
    })
  }
  if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot $manifest.entry) -PathType Leaf)) {
    throw "Release entry is missing: $($manifest.entry)"
  }
  $entryContent = Get-Content -LiteralPath (Join-Path $releaseRoot $manifest.entry) -Raw
  $entryVersion = [regex]::Match($entryContent, '(?m)^\s*--\s*@version\s+(\S+)')
  if (-not $entryVersion.Success -or $entryVersion.Groups[1].Value -ne $manifest.version) {
    throw "Entry @version does not match $($manifest.version): $($manifest.entry)"
  }
  Write-Inventory $releaseRoot $manifest
  Write-Output "Built $($manifest.displayName) $($manifest.version): $releaseRoot"
}
