$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$adb = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk\platform-tools\adb.exe'
$package = 'com.islandconquer.prototype'
$measurements = @()
foreach ($version in @('0.1.11','0.1.12','0.1.13')) {
    & $adb -s emulator-5554 install -r -d "builds/android/country-conquer-v$version.apk"
    if ($LASTEXITCODE -ne 0) { throw "Could not install $version" }
    & $adb -s emulator-5554 shell wm size '720x1600'
    foreach ($sample in 1..3) {
        & $adb -s emulator-5554 shell am force-stop $package
        if ($version -ne '0.1.11') {
            '{"mode":"playing","country":"bgd","difficulty":2}' | & $adb -s emulator-5554 shell "run-as $package sh -c 'cat > files/internal_preview.json'"
        }
        & $adb -s emulator-5554 shell monkey -p $package 1 2>&1 | Out-Null
        Start-Sleep -Seconds 7
        if ($version -eq '0.1.11') {
            & $adb -s emulator-5554 shell input tap 590 1277
            & $adb -s emulator-5554 shell input tap 360 1357
            Start-Sleep -Seconds 2
        }
        $raw = & "$PSScriptRoot\measure-frame-pacing.ps1" -Version $version -Label "0113-comparison-$sample" -Seconds 30
        $report = ($raw -join "`n") | ConvertFrom-Json
        $measurements += [ordered]@{version=$version; sample=$sample; p95_ms=$report.p95_ms; median_ms=$report.median_ms; samples=$report.samples}
        $measurements | ConvertTo-Json | Set-Content docs/frame-comparison-0.1.13.json
        $measurements[-1] | ConvertTo-Json -Compress
    }
}
& $adb -s emulator-5554 shell am force-stop $package
