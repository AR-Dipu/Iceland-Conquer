param([string]$Label = 'after', [int]$Seconds = 30, [string]$Version = '0.1.11')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$adb = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk\platform-tools\adb.exe'
$layers = (& $adb shell dumpsys SurfaceFlinger --list) -join "`n"
$match = [regex]::Match($layers, 'SurfaceView\[[^\]]*com\.islandconquer[^\]]*\]\(BLAST\)#\d+')
if (!$match.Success) { throw 'Game SurfaceView is not running.' }
$layer = $match.Value
& $adb shell 'dumpsys SurfaceFlinger --latency-clear' | Out-Null
$times = [Collections.Generic.HashSet[long]]::new()
$watch = [Diagnostics.Stopwatch]::StartNew()
while ($watch.Elapsed.TotalSeconds -lt $Seconds) {
    $lines = & $adb shell "dumpsys SurfaceFlinger --latency '$layer'"
    foreach ($line in $lines) {
        $columns = $line.Trim() -split '\s+'
        if ($columns.Count -eq 3) {
            $value = 0L
            if ([long]::TryParse($columns[1],[ref]$value) -and $value -gt 0 -and $value -lt [long]::MaxValue) { [void]$times.Add($value) }
        }
    }
    Start-Sleep -Milliseconds 500
}
$ordered = @($times | Sort-Object)
$intervals = @()
for ($i = 1; $i -lt $ordered.Count; $i++) { $intervals += ($ordered[$i]-$ordered[$i-1])/1000000.0 }
if ($intervals.Count -lt 10) { throw 'Not enough presentation timestamps; do not infer frame pacing.' }
$sorted = @($intervals | Sort-Object)
$report = [ordered]@{
    source = 'SurfaceFlinger actual presentation timestamps; emulator compositor, not phone GPU timing'
    label = $Label
    layer = $layer
    seconds = $watch.Elapsed.TotalSeconds
    samples = $intervals.Count
    median_ms = $sorted[[int][math]::Floor($sorted.Count*0.5)]
    p95_ms = $sorted[[math]::Min($sorted.Count-1,[int][math]::Floor($sorted.Count*0.95))]
    worst_ms = $sorted[-1]
    over_33ms = @($intervals | Where-Object { $_ -gt 33.4 }).Count
    timestamps_ns = $ordered
}
$path = Join-Path $root ('docs/frame-pacing-'+$Version+'-'+$Label+'.json')
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path
$report.Remove('timestamps_ns')
$report | ConvertTo-Json
