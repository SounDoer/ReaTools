param(
  [string]$ReaperPath = 'C:\Program Files\REAPER (x64)\reaper.exe',
  [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = 'Stop'
$coreScript = Join-Path $PSScriptRoot 'run_in_reaper.lua'
$uiScript = Join-Path $PSScriptRoot 'run_ui_smoke.lua'
$results = [System.Collections.Generic.List[string]]::new()
$temporaryFiles = [System.Collections.Generic.List[string]]::new()
$validationProcesses = [System.Collections.Generic.List[object]]::new()

function Wait-ValidationResult([string]$Path) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $Path) {
      $text = (Get-Content -LiteralPath $Path -Raw).Trim()
      if ($text) { return $text }
    }
    Start-Sleep -Milliseconds 250
  }
  throw "Timed out waiting for $Path"
}

function Start-ReaperValidation([string]$ScriptPath) {
  $process = Start-Process -FilePath $ReaperPath -WindowStyle Hidden -PassThru -ArgumentList @(
    '-newinst', '-new', '-nosplash', ('"' + $ScriptPath + '"')
  )
  $validationProcesses.Add($process)
  return $process
}

function Wait-ReaperExit([System.Diagnostics.Process]$Process, [string]$Name) {
  if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
    throw "$Name REAPER process did not exit within $TimeoutSeconds seconds"
  }
}

function Assert-Pass([string]$Name, [string]$Text) {
  if (-not $Text.StartsWith('PASS')) { throw "$Name failed:`n$Text" }
  $results.Add("$Name`: $Text")
}

try {
  $coreResult = Join-Path $PSScriptRoot '.last-result'
  $temporaryFiles.Add($coreResult)
  if (Test-Path -LiteralPath $coreResult) { Remove-Item -LiteralPath $coreResult -Force }
  $coreProcess = Start-ReaperValidation $coreScript
  $coreText = Wait-ValidationResult $coreResult
  Wait-ReaperExit $coreProcess 'Core'
  Assert-Pass 'Core' $coreText

  $uiResult = Join-Path $PSScriptRoot '.validation-ui-smoke'
  $temporaryFiles.Add($uiResult)
  if (Test-Path -LiteralPath $uiResult) { Remove-Item -LiteralPath $uiResult -Force }
  $env:REAPROJECTLINK_UI_SMOKE_RESULT = $uiResult
  $uiProcess = Start-ReaperValidation $uiScript
  $uiText = Wait-ValidationResult $uiResult
  Wait-ReaperExit $uiProcess 'Product UI'
  Assert-Pass 'Product UI' $uiText

  $results | ForEach-Object { Write-Output $_ }
} finally {
  Remove-Item Env:REAPROJECTLINK_UI_SMOKE_RESULT -ErrorAction SilentlyContinue
  foreach ($process in $validationProcesses) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
  }
  foreach ($path in $temporaryFiles) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
  $runnerProject = Join-Path $PSScriptRoot '.runner-project.rpp'
  if (Test-Path -LiteralPath $runnerProject) { Remove-Item -LiteralPath $runnerProject -Force }
}
