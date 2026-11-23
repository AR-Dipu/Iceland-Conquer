$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Set-Location $root
$suites=@('arcade_0115_suite','last_survivor_0114_suite','collection_0113_suite','premium_0112_suite','spatial_faces_0112_suite','hunter_0112_suite','capture_017_suite','connections_0110_suite','smooth_0111_suite','win_ai_019_suite','minimap_017_suite','shore_suite','corner_suite','economy_suite','revive_suite','name_map_suite','newcomer_017_suite','demo_duration_suite','world_campaign_suite','flag_refill_suite')
$log=Join-Path $root 'docs/tests-0.1.17.log'
Set-Content $log ''
foreach($suite in $suites){
 Add-Content $log "SUITE $suite"
 $arguments=@('--headless','--path','.','--script',"res://tests/$suite.gd",'--quit-after','1000')
 if($suite -eq 'world_campaign_suite'){ $arguments+=@('--','--quick') }
 $out=& .\tools\godot\Godot_v4.7.2-stable_win64_console.exe @arguments 2>&1
 $out|Add-Content $log
 if($LASTEXITCODE -ne 0 -or ($out -join "`n") -match 'SCRIPT ERROR|ERROR:|Assertion failed|Parse Error'){ $out|Write-Output; throw "FAILED $suite" }
 if(($out -join "`n") -notmatch 'RESULT'){ throw "Missing result: $suite" }
 $out|Select-String 'RESULT'
}




