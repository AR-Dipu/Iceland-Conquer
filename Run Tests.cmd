@echo off
for %%S in (run_suite revive_suite economy_suite self_trail_suite world_campaign_suite corner_suite demo_duration_suite shore_suite name_map_suite expansion_suite capture_017_suite newcomer_017_suite minimap_017_suite win_ai_019_suite) do (
  "%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --script res://tests/%%S.gd --quit-after 10000
  if errorlevel 1 exit /b 1
)
pause
