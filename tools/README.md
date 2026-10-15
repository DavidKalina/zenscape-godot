# Tools

Start here before writing a tool. The harness below covers what agents
used to rewrite every round: finding Godot, the import, the smoke check,
driving a study, seed and knob sweeps, rendered stills, and runs past the 10-minute tool limit. Everything is
Python or GDScript, so it runs the same on the Mac and on Windows. Call it
with `python` on Windows (there is no `py` there) and `python3` on the Mac.

| Need | Command |
|---|---|
| Run any Godot command | `python tools/godot.py <godot args>` |
| Smoke a scene (400 frames, no errors) | `python tools/smoke.py studies/x.tscn [-- scene flags]` |
| A check through the real play loop | write `scratch/x.gd` extending `tools/harness/drive.gd`, then `python tools/drive.py scratch/x.gd` |
| The same over seeds and knobs | `python tools/sweep.py scratch/x.gd --seed 1..8 --knob gulf=40,60` |
| One motif alone on the real stage (the yard) | `python tools/smoke.py studies/motif_yard.tscn -- --motif=plumb_well [--grey] [--bodies=0] [--rims]` |
| A motif's chain, 10 jittered trials | write `scratch/x_chain.gd` extending `tools/harness/chain.gd`, then `python tools/drive.py scratch/x_chain.gd -- --trials=10 --scene-args --motif=x [--grey]` |
| Rendered stills to look at | `python tools/shot.py studies/x.tscn --frame Trap --view three,top --sheet` |
| Anything that runs over ~8 min | `python tools/bg.py start NAME -- <command>`, then `python tools/bg.py wait NAME` |
| The test suite | `python tools/run_tests.py [--tests 'test_x*.gd'] [--quick]` |
| Find an existing tool | `python tools/index.py <word>` |

## godot.py: the base

It finds Godot from `$GODOT`, then the WinGet install, then `C:\Tools\Godot`,
then the Mac app (`python tools/godot.py --where`). Runs are headless
unless you pass `--rendered`, and `--path` is added for you. Before each
run it checks the import, which is needed when no import has run yet or
when a `class_name` script is newer than the class cache. If it is needed,
it runs `--import` under a lock, so agents never import at the same time.
A missing import is what causes the phantom
`Could not find type "NativeTerrainData"` parse errors in fresh worktrees.
The exit-time leak noise is dropped and the output ends in one summary
line. `--only` prints just the check lines, errors and that summary.
`--log FILE` keeps the full log. `--timeout S` kills the run, which then
exits 124.

## smoke.py: the smoke check

```
python tools/smoke.py studies/greybox/lidstack.tscn studies/trap_yard.tscn -j 4
python tools/smoke.py --greybox
```

Each scene is opened the way the game opens it (`change_scene`), then runs
400 frames at `--fixed-fps 60`. It prints one PASS/FAIL line per scene,
with how long the scene took to be walkable and any errors with their
`at:` lines. A trap yard takes about 8 s.

## drive.gd + drive.py: checks through the real play loop

```gdscript
extends "res://tools/harness/drive.gd"

func drive() -> void:
	await open("studies/trap_yard.tscn")           # walkable, or a FAIL line
	await place(Vector3(0, 0, 3.6), Vector2(0, -1))
	var got := await walk_to(Vector3(0, 0, -4), 600, 0.6, 0.5)   # jump halfway
	check(got, "crossed the gap", "feet %s" % motor.feet)
	var landed := await until(func() -> bool: return motor.grounded, 120)
	result("airtime_frames", landed)
	row({"seed": arg("seed"), "feet": motor.feet})
```

`python tools/drive.py scratch/gap.gd -- --seed=2 --scene-args --motif=sundered_gorge`

- **Args.** Args after `--` belong to the driver: `arg`, `arg_int`,
  `arg_float`, `arg_vec3`, `flag`. Args after `--scene-args` are the
  scene's launch flags. `open` hands those to the scene, with
  `--no-title`, through `scripts/launch_args.gd`.
- **Time.** `frames(n)` and `until(cond, max)` step the real loop: the
  study's own `_process`, with input read as actions.
- **Input.** `stick(v)` (Godot's convention: (0, -1) is forward),
  `stick_toward(point)`, `walk_to(point, max, near, jump_at)`,
  `jump(n)`, `press(action, n)`, `hold(action, on)` and `let_go()`.
  `yaw_follows_facing = true` holds the camera behind him.
- **Scripted ticks.** `scripted_ticks(n, want, jump)` uses the study's
  scripted ticks (`script_want`, `tick`). It is faster, but it skips the
  input path. Use it for setup, and prove the result with real input
  (AGENTS.md).
- **Looking around.** `find(pattern)` and `first(pattern)` look up nodes
  by name, class or script path. `shot(path)` takes a still, and only in a
  rendered run.
- **Reporting.** `check(ok, label, detail)` prints `OK`/`FAIL`.
  `result(k, v)` adds to the closing `RESULT {json}` line. `row(dict)`
  prints `ROW {json}`, which a sweep turns into table rows. `say(text)`
  and `note(text)` print lines drive.py shows. The run exits 0, or 1 if a
  check failed, or 2 on `--timeout=` (wall clock, default 240 s).
- **Stations.** `tools/harness/stations.gd` is a ready driver: he stands
  at every station of `--scene=`.
- **Throwaway drivers** go in `scratch/`, which git ignores and Godot
  doesn't scan.
- **Typing.** The project treats an untyped `:=` from a Variant as a
  parse error. Write `var d: Dictionary = x.get("k")`, not
  `var d := x.get("k")`. drive.py points this out when it happens. A
  script that doesn't parse fails in about a second.

## The motif yard and chain.gd

`studies/motif_yard.tscn` stands one motif and nothing else, on the study
base, with the pilot, motor, input and camera; its live parts (traps,
ropes, cannons, heads and their bodies) are set up as they are anywhere
else. It stands in about 2 s, and 10 trials
of the Plumb Well column take about 10 s.

```
python tools/smoke.py studies/motif_yard.tscn -- --motif=lidstack [--grey] [--bodies=0] [--rims] [--at=x,y,z] [--sky]
python tools/drive.py tools/harness/examples/plumb_well_chain.gd -- --trials=10 --scene-args --motif=plumb_well --bodies=0 [--grey]
python tools/shot.py studies/motif_yard.tscn --frame Motif_gb_vigil_bellows --view three -- --motif=vigil_bellows [--sky]
```

- `--motif=` takes a greybox slug (`scripts/kit_isle/greybox/registry.gd`)
  or a kit pool id (`bell_spires`: stood, no heads). `--grey` sets the
  motif's own grey flag (`--well-grey` and so on). `--bodies=0` turns the
  headless bodies off, `--rims` adds a pad a route stride off each rim,
  `--at=` moves the motif, and `--sky` adds the clouds and life for stills
  (a drifting puff can hide a low motif; shoot it without `--sky` then).
  R in the yard resets the stage and sets him at the start.
- **The trial helper.** `tools/harness/chain.gd` extends drive.gd.
  `open_motif(slug)` opens the yard. `motif_point(p)` moves a point of the
  motif's own table into the world. `motif_isle`, `motif_host` (its traps,
  ropes) and `motif_heads` find its parts. `reset_all()` puts the stage
  back as built. `trials(n, fn, jitter, delay)` runs `fn` n times from a
  jittered start, after a jittered delay with the traps and heads running,
  and prints a `ROW` per trial and `RESULT {passed, trials, rate}`.
  `rest(region)` waits until he comes to rest. The header has the rest.
- **Examples.** `tools/harness/examples/plumb_well_chain.gd` (the column,
  and `--chain=cannon`) and `wardens_well_chain.gd` (the head relay, and
  `--chain=cannon`, the missed relay). Copy one into `scratch/`.
- **What the yard leaves out.** Neighbouring isles (`--rims` stands in a
  pad off each rim), and the load of anything else on the frame.

## sweep.py: a table over seeds and knobs

```
python tools/sweep.py scratch/gap.gd --seed 1..6 --knob gulf=40,60,80 --csv scratch/gap.csv -j 8
```

Each axis becomes a scene flag: `--seed=N`, `--shape=S`, `--knob=k=v`, and
`--set name=a,b` gives `--name=a`. Ranges are written `1..5` or `0..20..5`.
The columns are the driver's RESULT values, or one row per ROW line it
printed, plus `ok` and seconds. To try a value, pass it as a flag. Don't
`sed` it into the source.

## shot.py: rendered stills

```
python tools/shot.py studies/trap_yard.tscn                                # its own camera
python tools/shot.py studies/trap_yard.tscn --frame walker --view three,front,top,close --sheet
python tools/shot.py studies/kit_isle.tscn --at 0,30,60 --look 0,0,0
python tools/shot.py --sheet-of a.png b.png --out scratch/sheet.png        # headless
```

Each run opens one Forward+ window. A lock keeps it to one window across
agents, and a watchdog closes it. `--frame PATTERN` frames the meshes
under the matching nodes. `walker` frames him and `all` frames the scene.
The views are three, front, back, left, right, top and close. The HUD is
hidden unless you pass `--hud`. Files go to `captures/shots/<scene>_<view>.png`
unless `--out` says otherwise. Read the PNGs and judge them yourself.
Headless runs can't take stills.

## bg.py: runs past the tool limit

```
python tools/bg.py start suite -- python tools/run_tests.py
python tools/bg.py wait suite          # blocks up to 540 s, prints the tail; exit 3 = still running
```

Logs and state go to `scratch/bg/`. Use this rather than `sleep` and
`until` polling loops.

## The other ~330 tools

These are one-off probes, captures, films, benches and dumps from earlier
rounds. Most say what they do and how to run them in their header.
`python tools/index.py <word>` lists them with that line. Reuse one, or
copy its idea into a driver, before writing another.
