param(
  [string]$ReaperPath = 'C:\Program Files\REAPER (x64)\reaper.exe',
  [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$galleryScript = Join-Path $packageRoot 'gallery\ReaToolUI_DesignSystemGallery.lua'
$coreScript = Join-Path $PSScriptRoot 'run_in_reaper.lua'
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

function Assert-ExactPass([string]$Name, [string]$Text, [string]$Expected) {
  if ($Text -ne $Expected) {
    throw "$Name did not cover the expected matrix:`nExpected: $Expected`nActual: $Text"
  }
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

  $galleryResult = Join-Path $PSScriptRoot '.validation-gallery-matrix'
  $temporaryFiles.Add($galleryResult)
  if (Test-Path -LiteralPath $galleryResult) { Remove-Item -LiteralPath $galleryResult -Force }
  $env:REATOOLUI_GALLERY_SMOKE_BATCH = '1'
  $env:REATOOLUI_GALLERY_SMOKE_RESULT = $galleryResult
  $galleryProcess = Start-ReaperValidation $galleryScript
  $galleryText = Wait-ValidationResult $galleryResult
  Wait-ReaperExit $galleryProcess 'Gallery'
  Assert-ExactPass 'Gallery' $galleryText `
    'PASS Design System Gallery matrix (30 scenarios)'

  $results | ForEach-Object { Write-Output $_ }
} finally {
  Remove-Item Env:REATOOLUI_GALLERY_SECTION -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_THEME -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_PREVIEW -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_SMOKE_BATCH -ErrorAction SilentlyContinue
  Remove-Item Env:REATOOLUI_GALLERY_SMOKE_RESULT -ErrorAction SilentlyContinue
  foreach ($process in $validationProcesses) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
  }
  foreach ($path in $temporaryFiles) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
}
