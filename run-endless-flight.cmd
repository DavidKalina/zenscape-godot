@echo off
rem Endless flight on Windows: double-click, or from PowerShell
rem   .\run-endless-flight.cmd
rem   .\run-endless-flight.cmd --weight=heavy
rem Extra arguments are the game's launch flags. tools/play.py finds Godot.
cd /d "%~dp0"
python tools\play.py -- %*
if errorlevel 1 pause
