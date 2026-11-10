@echo off
"%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --script res://tests/run_suite.gd --quit-after 1200
pause
