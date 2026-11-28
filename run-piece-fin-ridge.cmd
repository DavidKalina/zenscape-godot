@echo off
cd /d "%~dp0"
python tools\play.py studies/piece_fin_ridge.tscn -- %*
if errorlevel 1 pause
