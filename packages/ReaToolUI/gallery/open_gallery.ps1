param(
  [ValidateSet('Foundations', 'Components', 'Patterns', 'Cross-product Scenarios', 'Diagnostics')]
  [string]$Section = 'Components',
  [ValidateSet('light', 'dark')]
  [string]$Theme = 'light',
  [ValidateSet('compact', 'standard', 'wide')]
  [string]$Preview = 'wide',
  [string]$ReaperPath = 'C:\Program Files\REAPER (x64)\reaper.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ReaperPath -PathType Leaf)) {
  throw "REAPER executable not found: $ReaperPath"
}

$galleryScript = Join-Path $PSScriptRoot 'ReaToolUI_DesignSystemGallery.lua'
$env:REATOOLUI_GALLERY_SECTION = $Section
$env:REATOOLUI_GALLERY_THEME = $Theme
$env:REATOOLUI_GALLERY_PREVIEW = $Preview

try {
  Start-Process -FilePath $ReaperPath -WindowStyle Normal -ArgumentList @(
    '-newinst', '-new', '-nosplash', ('"' + $galleryScript + '"')
  ) | Out-Null
  Write-Output "Opened Gallery: section=$Section theme=$Theme preview=$Preview"
} finally {
  Remove-Item Env:REATOOLUI_GALLERY_SECTION -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_THEME -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_PREVIEW -ErrorAction SilentlyContinue
}
