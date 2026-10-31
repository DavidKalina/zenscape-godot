@echo off
cd /d "%~dp0"
python tools\play.py studies/burrower_study.tscn -- %*
if errorlevel 1 pause
