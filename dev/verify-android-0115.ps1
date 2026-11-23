param([switch]$ReuseBaseline,[switch]$SkipLayouts)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sdk = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$package = 'com.islandconquer.prototype'
$apk = 'builds/android/country-conquer-v0.1.15.apk'
if (!(Get-Process 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)) { throw 'The existing no-window emulator is required.' }
& $adb -s emulator-5554 wait-for-device
$cert = & "$sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs $apk
if ($LASTEXITCODE -ne 0 -or ($cert -join ' ') -notmatch '44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb') { throw 'APK signature mismatch.' }
function Read-Profile {
    $saved = @{}
    foreach ($file in @('practice_wallet.json','campaign.cfg','equipped_character.txt')) {
        $saved[$file] = (& $adb -s emulator-5554 shell "run-as $package sh -c 'if test -f files/$file; then cat files/$file; else echo MISSING; fi'") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Could not read $file" }
    }
    return $saved
}
function Start-Fixture($fixture) {
    & $adb -s emulator-5554 wait-for-device
    & $adb -s emulator-5554 shell am force-stop $package
    $fixture | & $adb -s emulator-5554 shell "run-as $package sh -c 'cat > files/internal_preview.json'"
    & $adb -s emulator-5554 shell monkey -p $package 1 2>&1 | Out-Null
    Start-Sleep -Seconds 5
}
function Save-Screen($target) {
    & $adb -s emulator-5554 shell screencap -p /sdcard/cc-0115-screen.png
    & $adb -s emulator-5554 pull /sdcard/cc-0115-screen.png $target 2>&1 | Out-Null
}
function Measure-Gameplay($version, $sample, $seconds) {
    Start-Fixture '{"mode":"playing","country":"bgd","difficulty":2,"metrics":true}'
    $raw = & "$PSScriptRoot\measure-frame-pacing.ps1" -Version $version -Label "0115-comparison-$sample" -Seconds $seconds
    $report = ($raw -join "`n") | ConvertFrom-Json
    Save-Screen "docs/country-$version-0115-comparison-$sample.png"
    if ($version -eq '0.1.15') {
        Start-Sleep -Seconds 3
        & $adb -s emulator-5554 logcat -d -s godot:* | Select-String 'INTERNAL_PERFORMANCE|INTERNAL_CAPTURE_VISIBILITY|SCRIPT ERROR' | Add-Content docs/performance-phases-0.1.15.log
        & $adb -s emulator-5554 logcat -c
    }
    [pscustomobject]@{version=$version;sample=$sample;seconds=$seconds;p95_ms=$report.p95_ms;samples=$report.samples} | ConvertTo-Json -Compress
}
$oldPackage = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
if ($ReuseBaseline -and $oldPackage -match 'versionName=0\.1\.15\b') {
    & $adb -s emulator-5554 shell am force-stop $package
    & $adb -s emulator-5554 install -r -d builds/android/country-conquer-v0.1.14.apk | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage the previous signed APK.' }
    $oldPackage = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
}
if ($oldPackage -notmatch 'versionName=0\.1\.14\b') { throw 'Expected installed 0.1.14 for the upgrade test.' }
& $adb -s emulator-5554 shell wm size '720x1600'
if (!$ReuseBaseline) {
    foreach ($sample in 1..3) { Measure-Gameplay '0.1.14' "active-$sample" 7 }
    Measure-Gameplay '0.1.14' 'long' 30
}
& $adb -s emulator-5554 shell am force-stop $package
$before = Read-Profile
& $adb -s emulator-5554 install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Upgrade failed.' }
$after = Read-Profile
$version = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
if ($version -notmatch 'versionCode=16\b' -or $version -notmatch 'versionName=0\.1\.15\b') { throw 'Version mismatch.' }
foreach ($file in $before.Keys) { if ($before[$file] -ne $after[$file]) { throw "$file changed during upgrade." } }
@{package=$package;version='0.1.15';code=16;wallet_preserved=$true;campaign_preserved=$true;equipment_preserved=$true;explicit_equipment_present=($before['equipped_character.txt'] -ne 'MISSING');balance=($after['practice_wallet.json'] | ConvertFrom-Json).balance;sha256=(Get-FileHash $apk).Hash} | ConvertTo-Json | Set-Content docs/upgrade-0.1.15.json
Set-Content docs/performance-phases-0.1.15.log ''
foreach ($sample in 1..3) { Measure-Gameplay '0.1.15' "active-$sample" 7 }
Measure-Gameplay '0.1.15' 'long' 30
foreach ($height in @(1280,1600) | Where-Object { !$SkipLayouts }) {
    & $adb -s emulator-5554 shell wm size "720x$height"
    foreach ($mode in @('selection','shop','playing','defeated','round_over')) {
        Start-Fixture ('{"mode":"' + $mode + '","country":"bgd","difficulty":2}')
        Save-Screen "docs/country-0.1.15-$mode-720x$height.png"
        if ($mode -eq 'shop') {
            $ys = [int]($height*0.72)
            $ye = [int]($height*0.28)
            & $adb -s emulator-5554 shell input swipe 370 $ys 370 $ye 500
            Start-Sleep -Milliseconds 450
            Save-Screen "docs/country-0.1.15-shop-premium-720x$height.png"
        }
    }
}
& $adb -s emulator-5554 shell am force-stop $package
