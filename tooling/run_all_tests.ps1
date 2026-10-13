param(
  [string]$ReaperPath = 'C:\Program Files\REAPER (x64)\reaper.exe',
  [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$reatoolui = Join-Path $root 'packages\ReaToolUI'
$reaprojectlink = Join-Path $root 'tools\ReaProjectLink'
$reaassetflow = Join-Path $root 'tools\ReaAssetFlow'
$results = [System.Collections.Generic.List[string]]::new()

function Invoke-Step([string]$Name, [scriptblock]$Action) {
  Write-Output "==> $Name"
  & $Action
  if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
  $results.Add("PASS $Name")
}

Invoke-Step 'ReaToolUI' {
  & (Join-Path $reatoolui 'tests\run_validation.ps1') `
    -ReaperPath $ReaperPath -TimeoutSeconds $TimeoutSeconds
}

Invoke-Step 'ReaProjectLink' {
  & (Join-Path $reaprojectlink 'tests\run_validation.ps1') `
    -ReaperPath $ReaperPath -TimeoutSeconds $TimeoutSeconds
}

Invoke-Step 'ReaAssetFlow' {
  Push-Location $reaassetflow
  try {
    python -m pytest
    if ($LASTEXITCODE -ne 0) { return }
    python -m py_compile scripts\wwise_import.py scripts\llm_assist.py
  } finally {
    Pop-Location
  }
}

Write-Output '==> Summary'
$results | ForEach-Object { Write-Output $_ }
