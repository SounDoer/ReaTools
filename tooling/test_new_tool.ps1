$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path $repoRoot 'dist/template-smoke'
$separator = [System.IO.Path]::DirectorySeparatorChar
$resolvedRepo = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd($separator) + $separator
$resolvedSandbox = [System.IO.Path]::GetFullPath($sandbox)
if (-not $resolvedSandbox.StartsWith($resolvedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe template sandbox: $resolvedSandbox"
}
if (Test-Path -LiteralPath $resolvedSandbox) {
  Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $sandbox 'tooling') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sandbox 'templates') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'new_tool.ps1') `
  -Destination (Join-Path $sandbox 'tooling/new_tool.ps1')
Copy-Item -LiteralPath (Join-Path $repoRoot 'templates/reaper-tool') `
  -Destination (Join-Path $sandbox 'templates/reaper-tool') -Recurse

& (Join-Path $sandbox 'tooling/new_tool.ps1') `
  -Name 'ReaTemplateSmoke' -Id 'reatemplatesmoke' `
  -Description 'Template validation tool.' | Out-Null

$toolRoot = Join-Path $sandbox 'tools/ReaTemplateSmoke'
$manifest = Get-Content -LiteralPath (Join-Path $toolRoot 'reatools-package.json') -Raw |
  ConvertFrom-Json
if ($manifest.id -ne 'reatemplatesmoke' -or $manifest.displayName -ne 'ReaTemplateSmoke') {
  throw 'Generated tool manifest has the wrong identity.'
}
foreach ($file in @('ReaTemplateSmoke.lua', 'README.md', 'CHANGELOG.md', 'reatools-package.json')) {
  $path = Join-Path $toolRoot $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing generated file: $file" }
  if ((Get-Content -LiteralPath $path -Raw).Contains('{{')) {
    throw "Unexpanded template placeholder in $file"
  }
}
Write-Output 'PASS future-tool scaffold'
