@echo off
cd /d "%~dp0"
python tools\play.py studies/temple_kit_gallery.tscn -- %*
if errorlevel 1 pause
