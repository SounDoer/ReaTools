param(
  [Parameter(Mandatory = $true)][string]$Path,
  [switch]$Report
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$rawLayout = [regex]'ImGui\.(SameLine|Separator|NewLine|Dummy|Indent|SetCursorPos\w*|PushStyleVar|PushStyleColor)\s*\('
$call = [regex]'\b(c|ImGui)\.\w+\(([^()]*)\)'
$number = [regex]'(?<![\w.])\d+(\.\d+)?(?![\w.])'
$culture = [System.Globalization.CultureInfo]::InvariantCulture

$files = @(Get-ChildItem -LiteralPath $root -Filter '*.lua' -File | Sort-Object Name)
$findings = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
  $relative = $file.Name
  $lines = [System.IO.File]::ReadAllLines($file.FullName)
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $text = $lines[$index].Trim()
    if ($text.StartsWith('--')) { continue }
    $prefix = "${relative}:$($index + 1)"
    if ($rawLayout.IsMatch($text)) { $findings.Add("${prefix}: raw-layout: $text") }
    foreach ($match in $call.Matches($text)) {
      foreach ($literal in $number.Matches($match.Groups[2].Value)) {
        $value = [double]::Parse($literal.Value, $culture)
        if ($value -ne 0 -and $value -ne 1) {
          $findings.Add("${prefix}: layout-literal: $($literal.Value) in $text")
        }
      }
    }
  }
}

if ($findings.Count -eq 0) {
  Write-Output "PASS ui layout ($($files.Count) files)"
  exit 0
}
$findings | ForEach-Object { Write-Output $_ }
if ($Report) { exit 0 }
exit 1
