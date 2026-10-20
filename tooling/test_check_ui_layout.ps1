$ErrorActionPreference = 'Stop'
$scan = Join-Path $PSScriptRoot 'check_ui_layout.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures/ui_layout'
if (-not (Test-Path -LiteralPath $scan -PathType Leaf)) { throw 'Missing tooling/check_ui_layout.ps1' }

$clean = @(& $scan -Path (Join-Path $fixtures 'clean'))
$code = $LASTEXITCODE
if ($code -ne 0 -or ($clean -join "`n") -ne 'PASS ui layout (1 files)') {
  throw "Clean fixture failed with exit code ${code}:`n$($clean -join "`n")"
}

$dirty = @(& $scan -Path (Join-Path $fixtures 'dirty'))
$code = $LASTEXITCODE
if ($code -ne 1) { throw "Dirty fixture exited with $code instead of 1" }
$findings = @($dirty | Where-Object { $_ -match '^view\.lua:\d+: (raw-layout|layout-literal): ' })
if ($findings.Count -ne 4 -or $dirty.Count -ne 4) {
  throw "Dirty fixture expected exactly 4 findings:`n$($dirty -join "`n")"
}
$raw = @($findings | Where-Object { $_ -match ': raw-layout: ' })
if ($raw.Count -ne 2) { throw "Expected 2 raw-layout findings:`n$($dirty -join "`n")" }
foreach ($literal in @('8', '120')) {
  $hits = @($findings | Where-Object { $_ -match ": layout-literal: $literal in " })
  if ($hits.Count -ne 1) { throw "Expected one layout-literal finding for ${literal}:`n$($dirty -join "`n")" }
}

$null = & $scan -Path (Join-Path $fixtures 'dirty') -Report
if ($LASTEXITCODE -ne 0) { throw "-Report exited with $LASTEXITCODE instead of 0" }

Write-Output 'PASS ui layout scan'
