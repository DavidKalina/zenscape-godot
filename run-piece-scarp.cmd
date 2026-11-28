@echo off
cd /d "%~dp0"
python tools\play.py studies/piece_scarp.tscn -- %*
if errorlevel 1 pause
