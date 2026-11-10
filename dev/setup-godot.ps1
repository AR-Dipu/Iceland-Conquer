$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot 'tools'
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
$release = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable'
$sumsPath = Join-Path $toolRoot 'SHA512-SUMS.txt'
Invoke-WebRequest "$release/SHA512-SUMS.txt" -OutFile $sumsPath
function Download-Verified([string]$Name, [string]$Destination) {
    Invoke-WebRequest "$release/$Name" -OutFile $Destination
    $record = Get-Content -LiteralPath $sumsPath | Where-Object { $_ -match ('\s+' + [regex]::Escape($Name) + '$') } | Select-Object -First 1
    if (!$record) { throw "No official checksum for $Name" }
    $expected = ($record -split '\s+')[0]
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA512).Hash
    if ($expected -ne $actual) { throw "Checksum mismatch: $Name" }
}
$editorZip = Join-Path $toolRoot 'godot.zip'
Download-Verified 'Godot_v4.7.2-stable_win64.exe.zip' $editorZip
Expand-Archive -LiteralPath $editorZip -DestinationPath (Join-Path $toolRoot 'godot') -Force
$templates = Join-Path $toolRoot 'export_templates.tpz'
Download-Verified 'Godot_v4.7.2-stable_export_templates.tpz' $templates
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($templates)
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.Name -in @('android_debug.apk','android_release.apk')) {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $toolRoot $entry.Name),$true)
        }
    }
} finally { $archive.Dispose() }
New-Item -ItemType File -Force -Path (Join-Path $toolRoot '.gdignore'),(Join-Path $toolRoot 'godot/_sc_') | Out-Null
Write-Host 'Godot 4.7.2 and matching Android templates are ready.'
