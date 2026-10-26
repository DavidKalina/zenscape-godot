@echo off
rem The Godot editor on this project, with main pulled first: double-click, or
rem from PowerShell  .\open-godot.cmd
rem tools/play.py --editor pulls origin's main (fast-forward only; it says why
rem when it can't), warns when the native terrain kernels are out of date, then
rem opens the editor on this checkout and leaves it running.
cd /d "%~dp0"
python tools\play.py --editor %*
if errorlevel 1 pause
