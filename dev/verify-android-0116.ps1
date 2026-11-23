$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sdk = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$package = 'com.islandconquer.prototype'
$apk = 'builds/android/country-conquer-v0.1.16.apk'
if (!(Get-Process 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)) { throw 'The existing no-window emulator is required.' }
& $adb -s emulator-5554 wait-for-device
$signature = & "$sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs $apk
if ($LASTEXITCODE -ne 0 -or ($signature -join ' ') -notmatch '44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb') { throw 'Signing certificate mismatch.' }

function Read-Profile {
    $data = @{}
    foreach ($file in @('practice_wallet.json','campaign.cfg','equipped_character.txt')) {
        $data[$file] = (& $adb -s emulator-5554 shell "run-as $package sh -c 'if test -f files/$file; then cat files/$file; else echo MISSING; fi'") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Could not read $file" }
    }
    return $data
}
& $adb -s emulator-5554 shell am force-stop $package
$oldVersion = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
$before = Read-Profile
& $adb -s emulator-5554 install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Upgrade failed.' }
$after = Read-Profile
$version = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
if ($version -notmatch 'versionCode=17\b' -or $version -notmatch 'versionName=0\.1\.16\b') { throw 'Version mismatch.' }
foreach ($key in $before.Keys) { if ($before[$key] -ne $after[$key]) { throw "Saved data changed: $key" } }
@{
    package=$package;version='0.1.16';code=17
    from=([regex]::Match($oldVersion,'versionName=([^\s]+)').Groups[1].Value)
    balance=($after['practice_wallet.json'] | ConvertFrom-Json).balance
    campaign_preserved=$true;wallet_preserved=$true;equipment_file_preserved=$true
    sha256=(Get-FileHash $apk).Hash
} | ConvertTo-Json | Set-Content docs/upgrade-0.1.16.json

& $adb -s emulator-5554 shell wm size '720x1600'
$records = @()
Set-Content docs/performance-phases-0.1.16.log ''
foreach ($seed in @(116,117,118)) {
    & $adb -s emulator-5554 wait-for-device
    & $adb -s emulator-5554 shell am force-stop $package
    & $adb -s emulator-5554 logcat -c
    $fixture = @{mode='playing';country='bgd';difficulty=2;metrics=$true;pacing_fixture=$true;seed=$seed} | ConvertTo-Json -Compress
    $fixture | & $adb -s emulator-5554 shell "run-as $package sh -c 'cat > files/internal_preview.json'"
    & $adb -s emulator-5554 shell monkey -p $package 1 2>&1 | Out-Null
    Start-Sleep -Seconds 6
    $raw = & "$PSScriptRoot\measure-frame-pacing.ps1" -Version '0.1.16' -Label "hard-$seed" -Seconds 30
    $frame = ($raw -join "`n") | ConvertFrom-Json
    for ($attempt=0; $attempt -lt 15; $attempt++) {
        $log = & $adb -s emulator-5554 logcat -d -s godot:*
        if (($log -join "`n") -match 'INTERNAL_CAPTURE_VISIBILITY') { break }
        Start-Sleep -Seconds 1
    }
    $log | Select-String 'INTERNAL_PERFORMANCE|INTERNAL_CAPTURE_VISIBILITY|SCRIPT ERROR' | Add-Content docs/performance-phases-0.1.16.log
    if (($log -join "`n") -match 'SCRIPT ERROR') { throw 'Godot reported a runtime script error.' }
    $summary = $log | Select-String 'INTERNAL_CAPTURE_VISIBILITY (\{.*\})' | Select-Object -Last 1
    if (!$summary) { throw 'Missing gameplay interval marker.' }
    $state = $summary.Matches[0].Groups[1].Value | ConvertFrom-Json
    if ($state.state -ne 2 -or $state.active_seconds -lt 30.0) { throw "Sample $seed did not remain in an active match." }
    & $adb -s emulator-5554 shell screencap -p /sdcard/cc-0116.png
    & $adb -s emulator-5554 pull /sdcard/cc-0116.png "docs/country-0.1.16-hard-$seed.png" 2>&1 | Out-Null
    $records += @{seed=$seed;p95_ms=$frame.p95_ms;median_ms=$frame.median_ms;worst_ms=$frame.worst_ms;frames=$frame.samples;active_seconds=$state.active_seconds;fixture_revives=$state.fixture_revives;capture_frames=$state.visible_delays}
    $records | ConvertTo-Json -Depth 6 | Set-Content docs/frame-comparison-0.1.16.json
    $records[-1] | ConvertTo-Json -Compress
}
& $adb -s emulator-5554 shell am force-stop $package
