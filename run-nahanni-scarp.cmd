@echo off
rem The Nahanni map, started in the air on the low side of the scarp in the west
rem valley, 600 m short of its face and pointed up the valley at it (the scarp:
rem scripts/endless/world/profiles/nahanni.gd `pieces`). Double-click, or from
rem PowerShell
rem   .\run-nahanni-scarp.cmd
rem Extra arguments are the game's launch flags (a later --at= / --alt= /
rem --heading= wins). Runs tools/play.py like run-endless-flight.cmd.
cd /d "%~dp0"
python tools\play.py -- --world=nahanni --at=-2068,-2848 --alt=50 --heading=125 %*
if errorlevel 1 pause
