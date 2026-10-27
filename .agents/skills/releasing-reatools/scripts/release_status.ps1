param(
  [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run this script inside the ReaTools repository.' }

if (-not $NoFetch) {
  & git -C $repoRoot fetch --quiet origin main reapack
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch origin/main and origin/reapack.' }
}

$indexText = (& git -C $repoRoot show origin/reapack:index.xml) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Could not read index.xml from origin/reapack.' }
$index = [xml]$indexText

function Get-VersionKey([string]$Name) {
  $parsed = $null
  if ([version]::TryParse($Name, [ref]$parsed)) { return $parsed }
  return [version]'0.0'
}

$toolDirs = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') -Directory |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'reatools-package.json') } |
  Sort-Object Name

foreach ($toolDir in $toolDirs) {
  $manifest = Get-Content -LiteralPath (Join-Path $toolDir.FullName 'reatools-package.json') -Raw |
    ConvertFrom-Json
  $paths = @($manifest.release.files | ForEach-Object { "tools/$($toolDir.Name)/$($_.source)" })
  if ($manifest.uiContract.usage -eq 'runtime') { $paths += 'packages/ReaToolUI/lib' }

  $category = "ReaTools/$($manifest.displayName)"
  $package = $index.SelectSingleNode(
    "//category[@name='$category']/reapack[@name='$($manifest.entry)']")
  $indexed = $null
  $base = $null
  if ($package) {
    $indexed = @($package.SelectNodes('version')) |
      Sort-Object { Get-VersionKey $_.name } |
      Select-Object -Last 1
    $mainSource = @($indexed.SelectNodes('source')) |
      Where-Object { $_.GetAttribute('main') } |
      Select-Object -First 1
    $reapackSha = [regex]::Match($mainSource.InnerText, '/raw/([0-9a-f]{40})/').Groups[1].Value
    $subject = (& git -C $repoRoot log -1 --format=%s $reapackSha)
    $base = [regex]::Match($subject, 'sync packages from ([0-9a-f]{40})').Groups[1].Value
    if (-not $base) { throw "Cannot find the source commit of $category $($indexed.name)." }
  }

  $changed = @()
  if ($base) {
    $changed = @(& git -C $repoRoot diff --name-only $base -- @paths)
    if ($LASTEXITCODE -ne 0) { throw "Could not diff $($manifest.displayName) against $base." }
  }

  $status = if (-not $package) {
    'never published'
  } elseif ($manifest.version -ne $indexed.name) {
    'version bumped, not yet published'
  } elseif ($changed.Count -gt 0) {
    'NEEDS VERSION BUMP'
  } else {
    'up to date'
  }

  Write-Output "== $($manifest.displayName) ($($toolDir.Name)) =="
  Write-Output "  declared version : $($manifest.version)"
  Write-Output "  indexed version  : $(if ($indexed) { $indexed.name } else { '-' })"
  Write-Output "  released from    : $(if ($base) { $base.Substring(0, 7) } else { '-' })"
  Write-Output "  status           : $status"
  Write-Output "  changed release files since release ($($changed.Count)):"
  foreach ($file in $changed) { Write-Output "    $file" }
  Write-Output ''
}
