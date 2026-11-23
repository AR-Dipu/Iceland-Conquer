$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$adb = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk\platform-tools\adb.exe'
$serial = 'emulator-5554'
$package = 'com.islandconquer.prototype'
if (!(Get-Process 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)) {
    throw 'The existing no-window emulator is required.'
}
$previous = (& $adb -s $serial shell wm size | Select-String 'Override size: (\S+)').Matches.Groups[1].Value
try {
    foreach ($height in @(1280,1600)) {
        & $adb -s $serial shell wm size "720x$height"
        foreach ($country in @('bgd','ind','jpn','isl','chl')) {
            & $adb -s $serial shell am force-stop $package
            & $adb -s $serial logcat -c
            $fixture = @{mode='playing';country=$country;difficulty=2;name='Captain';pacing_fixture=$true;seed=117} | ConvertTo-Json -Compress
            $fixture | & $adb -s $serial shell "run-as $package sh -c 'cat > files/internal_preview.json'"
            & $adb -s $serial shell monkey -p $package 1 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            $log = & $adb -s $serial logcat -d -s godot:*
            if (($log -join "`n") -match 'SCRIPT ERROR|Failed to load resource') { throw "Runtime error in $country at 720x$height" }
            & $adb -s $serial shell screencap -p /sdcard/cc-terrain.png
            & $adb -s $serial pull /sdcard/cc-terrain.png "docs/flag-$country-720x$height.png"
        }
    }
} finally {
    & $adb -s $serial shell am force-stop $package
    if ($previous) { & $adb -s $serial shell wm size $previous }
    else { & $adb -s $serial shell wm size reset }
}
