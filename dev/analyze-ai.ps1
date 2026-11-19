$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Get-Median([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    if (!$sorted.Count) { throw 'Missing samples.' }
    $middle = [int][math]::Floor($sorted.Count/2)
    if ($sorted.Count%2) { return $sorted[$middle] }
    return ($sorted[$middle-1]+$sorted[$middle])/2
}
$rows = Get-Content (Join-Path $root 'docs/contested-0.1.11.json') -Raw | ConvertFrom-Json
if ($rows.Count -ne 30) { throw 'Expected exactly 30 simulation rows.' }
$old = @($rows | Where-Object { $_.baseline })
$new = @($rows | Where-Object { !$_.baseline })
$countries = @()
foreach ($id in @('bgd','ind','lka','jpn','isl')) {
    $before = Get-Median @($old | Where-Object { $_.country -eq $id } | ForEach-Object { $_.net_land })
    $after = Get-Median @($new | Where-Object { $_.country -eq $id } | ForEach-Object { $_.net_land })
    $countries += [ordered]@{country=$id; baseline_net_median=$before; new_net_median=$after; improvement_percent=100*($after/$before-1); no_regression=($after -ge $before)}
}
$before = Get-Median @($old | ForEach-Object { $_.net_land })
$after = Get-Median @($new | ForEach-Object { $_.net_land })
$reverseOld = Get-Median @($old | ForEach-Object { $_.normal_reverse_units })
$reverseNew = Get-Median @($new | ForEach-Object { $_.normal_reverse_units })
$reverseTotalOld = ($old | Measure-Object normal_reverse_units -Sum).Sum
$reverseTotalNew = ($new | Measure-Object normal_reverse_units -Sum).Sum
$cpuOld = Get-Content (Join-Path $root 'docs/performance-0.1.11-baseline.json') -Raw | ConvertFrom-Json
$cpuNew = Get-Content (Join-Path $root 'docs/performance-0.1.11-after.json') -Raw | ConvertFrom-Json
$report = [ordered]@{
    simulations=$rows.Count
    baseline_net_median=$before
    new_net_median=$after
    net_gain_improvement_percent=100*($after/$before-1)
    baseline_reverse_median=$reverseOld
    new_reverse_median=$reverseNew
    reverse_reduction_percent=100*(1-$reverseNew/$reverseOld)
    summed_reverse_reduction_percent=100*(1-$reverseTotalNew/$reverseTotalOld)
    land_gain_gate=($after -ge $before*1.25)
    reverse_gate=($reverseNew -le $reverseOld*0.7)
    country_gate=(@($countries | Where-Object {!$_.no_regression}).Count -eq 0)
    cpu_p95_reduction_percent=100*(1-$cpuNew.p95_cpu_ms/$cpuOld.p95_cpu_ms)
    cpu_gate=($cpuNew.p95_cpu_ms -le $cpuOld.p95_cpu_ms*0.7)
    natural_bot_wins_before=@($old | Where-Object {$_.winner -gt 0}).Count
    natural_bot_wins_after=@($new | Where-Object {$_.winner -gt 0}).Count
    countries=$countries
}
$report | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'docs/gates-0.1.11.json')
$report | ConvertTo-Json -Depth 8
