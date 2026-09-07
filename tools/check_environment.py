"""Run the current scene's integration checks and retain their actual output."""
import subprocess, json, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT='/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot'
TESTS=['test_fidelity.gd','test_wind.gd','test_display_fog.gd','test_water_growth.gd','test_lake_complete_lighting.gd','test_ice_highlight.gd','test_surface_weather.gd','test_growth.gd','test_bigfoot_lifecycle.gd','test_thunder_audio.gd','test_ambient_audio.gd','test_paused_lighting.gd','test_rainbow_weather.gd']
results=[]
for test in TESTS:
    started=time.monotonic()
    p=subprocess.run([GODOT,'--path',str(ROOT),'--rendering-method','forward_plus','--script','tests/'+test],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    passed=p.returncode==0 and 'SCRIPT ERROR:' not in p.stdout and '\nERROR:' not in p.stdout
    results.append(dict(test=test,passed=passed,exit_code=p.returncode,seconds=round(time.monotonic()-started,2),output=p.stdout))
    (ROOT/'docs/fidelity/environment-checks.json').write_text(json.dumps(results,indent=2))
    print(('PASS' if passed else 'FAIL'),test,flush=True)
    if not passed:
        print(p.stdout,flush=True)
        raise SystemExit(1)
print('PASS: all',len(results),'environment integration checks',flush=True)
