$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sdk = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$package = 'com.islandconquer.prototype'
$apk = 'builds/android/country-conquer-v0.1.14.apk'
if (!(Get-Process 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)) {
    throw 'The existing no-window emulator is required.'
}
& $adb -s emulator-5554 wait-for-device
if ((& $adb -s emulator-5554 shell getprop sys.boot_completed).Trim() -ne '1') { throw 'Emulator has not finished booting.' }
$cert = & "$sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs $apk
if ($LASTEXITCODE -ne 0 -or ($cert -join ' ') -notmatch '44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb') {
    throw 'APK signing verification failed.'
}
function Read-Profile {
    $saved = @{}
    foreach ($file in @('practice_wallet.json','campaign.cfg','equipped_character.txt')) {
        $value = & $adb -s emulator-5554 shell "run-as $package sh -c 'if test -f files/$file; then cat files/$file; else echo MISSING; fi'"
        if ($LASTEXITCODE -ne 0) { throw "Could not read $file" }
        $saved[$file] = ($value -join "`n")
    }
    return $saved
}
& $adb -s emulator-5554 shell am force-stop $package
$oldPackage = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
if ($oldPackage -notmatch 'versionName=0\.1\.13\b') { throw 'Expected the installed 0.1.13 build for the upgrade test.' }
$before = Read-Profile
& $adb -s emulator-5554 install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Upgrade install failed.' }
$after = Read-Profile
$newPackage = (& $adb -s emulator-5554 shell dumpsys package $package) -join "`n"
if ($newPackage -notmatch 'versionCode=15\b' -or $newPackage -notmatch 'versionName=0\.1\.14\b') { throw 'Installed version mismatch.' }
$upgrade = [ordered]@{
    from = '0.1.13'; to = '0.1.14'; code = 15; package = $package
    apk_sha256 = (Get-FileHash $apk).Hash
    wallet_preserved = ($before['practice_wallet.json'] -eq $after['practice_wallet.json'] -and $before['practice_wallet.json'] -ne 'MISSING')
    campaign_preserved = ($before['campaign.cfg'] -eq $after['campaign.cfg'] -and $before['campaign.cfg'] -ne 'MISSING')
    equipment_file_preserved = ($before['equipped_character.txt'] -eq $after['equipped_character.txt'])
    explicit_equipment_present = ($before['equipped_character.txt'] -ne 'MISSING')
    balance = ($after['practice_wallet.json'] | ConvertFrom-Json).balance
}
$upgrade | ConvertTo-Json | Set-Content docs/upgrade-0.1.14.json
$upgrade | ConvertTo-Json
if (!$upgrade.wallet_preserved -or !$upgrade.campaign_preserved -or !$upgrade.equipment_file_preserved) { throw 'Upgrade changed saved data.' }
& $adb -s emulator-5554 shell wm size '720x1600'
$measurements = @()
foreach ($sample in 1..3) {
    & $adb -s emulator-5554 shell am force-stop $package
    '{"mode":"playing","country":"bgd","difficulty":2}' | & $adb -s emulator-5554 shell "run-as $package sh -c 'cat > files/internal_preview.json'"
    & $adb -s emulator-5554 shell monkey -p $package 1 2>&1 | Out-Null
    Start-Sleep -Seconds 7
    $raw = & "$PSScriptRoot\measure-frame-pacing.ps1" -Version '0.1.14' -Label "hard-$sample" -Seconds 30
    $report = ($raw -join "`n") | ConvertFrom-Json
    & $adb -s emulator-5554 shell screencap -p /sdcard/cc-0114-frame.png
    & $adb -s emulator-5554 pull /sdcard/cc-0114-frame.png "docs/country-0.1.14-hard-$sample.png" | Out-Null
    $measurements += [ordered]@{sample=$sample; p95_ms=$report.p95_ms; median_ms=$report.median_ms; samples=$report.samples}
    $measurements | ConvertTo-Json | Set-Content docs/frame-comparison-0.1.14.json
    $measurements[-1] | ConvertTo-Json -Compress
}
& $adb -s emulator-5554 shell am force-stop $package
