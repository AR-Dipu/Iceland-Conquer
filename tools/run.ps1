param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path -LiteralPath $enginePath)) { throw 'Install Godot 4.7.2 or open project.godot with that editor.' }
if ($Editor) { & $enginePath --path $projectRoot --editor } else { & $enginePath --path $projectRoot }
