param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [Parameter(Mandatory = $true)]
  [string]$Description,
  [string]$Id
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Name -notmatch '^Rea[A-Za-z0-9]+$') {
  throw 'Name must start with Rea and contain only ASCII letters or digits.'
}
if (-not $Id) { $Id = $Name.ToLowerInvariant() }
if ($Id -notmatch '^rea[a-z0-9]+$') {
  throw 'Id must start with rea and contain only lowercase ASCII letters or digits.'
}

$target = Join-Path $repoRoot "tools\$Name"
if (Test-Path -LiteralPath $target) { throw "Tool already exists: $target" }
$templateRoot = Join-Path $repoRoot 'templates\reaper-tool'
New-Item -ItemType Directory -Path $target | Out-Null

function Expand-Template([string]$TemplateName, [string]$TargetName) {
  $content = Get-Content -LiteralPath (Join-Path $templateRoot $TemplateName) -Raw
  $content = $content.Replace('{{DISPLAY_NAME}}', $Name)
  $content = $content.Replace('{{DESCRIPTION}}', $Description)
  $content = $content.Replace('{{ID}}', $Id)
  Set-Content -LiteralPath (Join-Path $target $TargetName) -Value $content -Encoding utf8
}

Expand-Template 'ToolName.lua.template' "$Name.lua"
Expand-Template 'README.md.template' 'README.md'
Expand-Template 'CHANGELOG.md.template' 'CHANGELOG.md'
Expand-Template 'reatools-package.json.template' 'reatools-package.json'

Write-Output "Created $Name at $target"
Write-Output 'Next: record Product decisions, add tests, and add the tool to repository validation.'
