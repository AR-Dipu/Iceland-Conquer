param(
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$JavaSdkPath = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path -LiteralPath $enginePath)) { throw 'Run dev/setup-godot.ps1 first.' }
if (!$AndroidSdkPath) { $AndroidSdkPath = 'D:\irinfo\Wanderide App Automation\.tools\android-sdk' }
if (!$JavaSdkPath) { $JavaSdkPath = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot' }
if (!(Test-Path -LiteralPath (Join-Path $AndroidSdkPath 'platform-tools/adb.exe'))) { throw 'Set ANDROID_HOME or pass -AndroidSdkPath.' }
$keytool = Join-Path $JavaSdkPath 'bin/keytool.exe'
if (!(Test-Path -LiteralPath $keytool)) { throw 'Set JAVA_HOME to JDK 17 or pass -JavaSdkPath.' }
$portableRoot = Join-Path $projectRoot 'tools/godot/editor_data'
New-Item -ItemType Directory -Force -Path $portableRoot | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $projectRoot 'tools/godot/_sc_') | Out-Null
$keystorePath = Join-Path $projectRoot 'tools/debug.keystore'
if (!(Test-Path -LiteralPath $keystorePath)) {
    & $keytool -genkeypair -keystore $keystorePath -storepass android -alias androiddebugkey -keypass android -dname 'CN=Island Conquer Debug,O=Prototype,C=BD' -keyalg RSA -keysize 2048 -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Debug signing key generation failed.' }
}
$settingsPath = Join-Path $portableRoot 'editor_settings-4.7.tres'
$newline = [Environment]::NewLine
if (Test-Path -LiteralPath $settingsPath) { $settings = Get-Content -LiteralPath $settingsPath -Raw }
else { $settings = '[gd_resource type="EditorSettings" format=3]' + $newline + $newline + '[resource]' + $newline }
$values = @{
    'export/android/java_sdk_path' = $JavaSdkPath.Replace('\','/')
    'export/android/android_sdk_path' = $AndroidSdkPath.Replace('\','/')
    'export/android/debug_keystore' = $keystorePath.Replace('\','/')
    'export/android/debug_keystore_user' = 'androiddebugkey'
    'export/android/debug_keystore_pass' = 'android'
}
foreach ($name in $values.Keys) {
    $line = $name + ' = "' + $values[$name] + '"'
    $pattern = '(?m)^' + [regex]::Escape($name) + ' = .*\r?$'
    if ($settings -match $pattern) { $settings = [regex]::Replace($settings,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line }) }
    else { $settings += $newline + $line }
}
Set-Content -LiteralPath $settingsPath -Value $settings -Encoding utf8
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'builds/android') | Out-Null
& $enginePath --headless --path $projectRoot --export-debug Android (Join-Path $projectRoot 'builds/android/island-conquer-debug.apk')
if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
Write-Host 'APK: builds/android/island-conquer-debug.apk'
