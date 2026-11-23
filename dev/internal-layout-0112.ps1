param([int]$Height=1280,[string[]]$Modes=@('selection','playing','paused','defeated','demo_ad','round_over','editing'))
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$adb='D:\irinfo\Wanderide App Automation\.tools\android-sdk\platform-tools\adb.exe'
& $adb wait-for-device
& $adb shell wm size "720x$Height"
foreach($mode in $Modes){
    & $adb shell am force-stop com.islandconquer.prototype
    $fixture=@{mode=$(if($mode -eq 'editing'){'selection'}else{$mode});country='bgd';difficulty=2;editing=($mode -eq 'editing');insufficient=($mode -eq 'defeated')}
    $fixture|ConvertTo-Json -Compress|& $adb shell "run-as com.islandconquer.prototype sh -c 'cat > files/internal_preview.json'"
    & $adb shell monkey -p com.islandconquer.prototype 1 2>&1|Out-Null
    Start-Sleep -Seconds 5
    & $adb shell screencap -p /sdcard/layout-0112.png
    $path=Join-Path $root "docs/country-0.1.12-$mode-720x$Height.png"
    & $adb pull /sdcard/layout-0112.png $path 2>&1|Out-Null
    Write-Output "CAPTURED $mode 720x$Height"
}
