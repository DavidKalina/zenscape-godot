@echo off
rem Endless flight on Windows: double-click, or from PowerShell
rem   .\run-endless-flight.cmd
rem   .\run-endless-flight.cmd --weight=heavy
rem Extra arguments are the game's launch flags. tools/play.py pulls main
rem first (fast-forward only; it says why when it can't), warns when the
rem native terrain kernels are out of date, finds Godot, imports and keeps a
rem launch log.
cd /d "%~dp0"
python tools\play.py -- %*
if errorlevel 1 pause
