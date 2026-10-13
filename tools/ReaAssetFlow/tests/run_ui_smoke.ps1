param(
  [string]$ReaperPath = 'C:\Program Files\REAPER (x64)\reaper.exe',
  [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $toolRoot 'ReaAssetFlow.lua'
$result = Join-Path $PSScriptRoot '.validation-ui-smoke'
$dataRoot = Join-Path $PSScriptRoot '.storage-smoke'
$resolvedTests = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\'
$resolvedData = [System.IO.Path]::GetFullPath($dataRoot)
if (-not $resolvedData.StartsWith($resolvedTests, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe smoke data path: $resolvedData"
}
$process = $null

try {
  if (Test-Path -LiteralPath $result) { Remove-Item -LiteralPath $result -Force }
  $env:REAASSETFLOW_UI_SMOKE_RESULT = $result
  $env:REAASSETFLOW_DATA_ROOT = $resolvedData
  $process = Start-Process -FilePath $ReaperPath -WindowStyle Hidden -PassThru -ArgumentList @(
    '-newinst', '-new', '-nosplash', ('"' + $entry + '"')
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $result)) {
    Start-Sleep -Milliseconds 250
  }
  if (-not (Test-Path -LiteralPath $result)) { throw "Timed out waiting for ReaAssetFlow UI smoke" }
  $text = (Get-Content -LiteralPath $result -Raw).Trim()
  if (-not $text.StartsWith('PASS')) { throw "ReaAssetFlow UI smoke failed:`n$text" }
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    throw "ReaAssetFlow UI smoke REAPER process did not exit"
  }
  Write-Output $text
} finally {
  Remove-Item Env:REAASSETFLOW_UI_SMOKE_RESULT -ErrorAction SilentlyContinue
  Remove-Item Env:REAASSETFLOW_DATA_ROOT -ErrorAction SilentlyContinue
  if ($process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath $result) { Remove-Item -LiteralPath $result -Force }
  if (Test-Path -LiteralPath $resolvedData) {
    Remove-Item -LiteralPath $resolvedData -Recurse -Force
  }
}
