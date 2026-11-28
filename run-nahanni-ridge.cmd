@echo off
rem The Nahanni map, started in the air short of the fin ridge's south end,
rem pointed down its length (the ridge: scripts/endless/world/profiles/nahanni.gd
rem `pieces`). Double-click, or from PowerShell
rem   .\run-nahanni-ridge.cmd
rem Extra arguments are the game's launch flags (a later --at= / --alt= /
rem --heading= wins). Runs tools/play.py like run-endless-flight.cmd.
cd /d "%~dp0"
python tools\play.py -- --world=nahanni --at=-170,1000 --alt=60 --heading=0 %*
if errorlevel 1 pause
