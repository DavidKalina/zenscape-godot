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
| Every helper a driver has, with its doc | `python tools/drive.py --api [route\|watch\|ray\|...]` (read from drive.gd, chain.gd, stations.gd; no Godot run) |
| The same over seeds and knobs | `python tools/sweep.py scratch/x.gd --seed 1..8 --knob gulf=40,60` |
| The same over the driver's own args | `python tools/sweep.py scratch/x.gd --arg pilot=stand,flee,dodge` (the driver gets `--pilot=...`) |
| One motif alone on the real stage (the yard) | `python tools/smoke.py studies/motif_yard.tscn -- --motif=plumb_well [--grey] [--bodies=0] [--rims]` |
| A motif's chain, 10 jittered trials | write `scratch/x_chain.gd` extending `tools/harness/chain.gd`, then `python tools/drive.py scratch/x_chain.gd -- --trials=10 --scene-args --motif=x [--grey]` |
| Walk points through real input (lips, walls, falls, stuns) | in a driver: `await route([start, p1, {"to": p2, "jump": "long"}])`; a motif's paths: `walk_paths(owner, offset)` / chain.gd `walk_motif_paths()` (drive.gd, Routes) |
| Log an enemy over time while he stands, flees, dodges or walks | in a driver: `await watch(enemy, {"pilot": "flee", "frames": 600})`; `--pilot-at=`, `--enemy-at=`; `"row": true` or `--watch-row` for a sweep table (drive.gd, Watching an enemy) |
| Who's at a point, what a ray hits | in a driver: `say(hit_text(ray(a, b)))`, `pierce(a, b)`, `what_is_at(p, r)`, `what_is_in(box)`, `colliders(node)` (drive.gd, Collider probes) |
| What a run layer lays (isles, crossings, problems), without building it | `python tools/godot.py -s tools/layer_dump.gd -- --shape=ring --seed=2 [--isles] [--out=scratch/plan.json]`; over seeds: `python tools/sweep.py tools/layer_dump.gd --seed 1..20 --shape sprawl,ring` |
| Parse-check a script without running it | `python tools/godot.py --check-only -s res://scratch/x.gd` (one script; exit 1 with the parse error) |
| Check a land outline (bowtie, wrong winding) | `KitLand.outline_problems(outline, winding)`; `KitLand.island` warns on its own |
| Rendered stills to look at | `python tools/shot.py studies/x.tscn --frame Trap --view three,top --sheet` |
| A still of a moment in a driven run (him mid-jump, a piece by its AABB) | in a driver: `await shot_at("side", motor, {"when": cond})`, then `route()`/`watch()`; run with `drive.py --rendered` (drive.gd, Shots) |
| A short film and contact sheet while a route or watch plays | in a driver: `var f := film(enemy, {"view": "shoulder", "every": 6, "seconds": 3})`, `await watch(enemy)`, `await film_end(f)` (drive.gd, Shots) |
| Run a Blender script (Mac, Windows, the Store build) | `python tools/blender.py run art/blender/x/x_build.py [--blend F] [--timeout S] -- args`; `--where`; `--expr "..."` |
| Anything that runs over ~8 min | `python tools/bg.py start NAME -- <command>`, then `python tools/bg.py wait NAME` |
| The test suite | `python tools/run_tests.py [--tests 'test_x*.gd'] [--quick]` |
| A brainstorm round's cards as one page of maps | `python tools/motif_cards_html.py docs/design/motifs/brainstorm/<round> [--open]` |
| A new RuinKit piece: scaffold, sizes, recipe, yard, check | `python tools/kit_piece.py new\|numbers\|recipe\|yard\|check` |
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
  by name, class or script path. `shot(path)` takes a still of the window,
  `shot_at(view, target)` and `film(target)` place a camera of their own
  (`--api shot`); all three only in a rendered run, and print SKIP headless.
- **The full list.** `python tools/drive.py --api` prints every helper's
  signature and doc, read from the scripts; `--api WORD` adds the
  section's notes (a route's opts, what `watch` returns). drive.gd's
  header index comes from the same parse: after changing a helper, run
  `python tools/drive.py --api --update`. `--api` exits 1 while the index
  or chain.gd's header misses a helper.
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
`--set name=a,b` gives `--name=a`. `--arg name=a,b` gives the driver
`--name=a` instead (before `--scene-args`), so the scene never sees it:
`python tools/sweep.py scratch/watch_enemy.gd --arg pilot=stand,flee,dodge -- --watch-row`. Ranges are written `1..5` or `0..20..5`.
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

## kit_piece.py: a new RuinKit piece

```
python tools/kit_piece.py new <id> --family <family> [--name "Display name"]
python tools/kit_piece.py numbers                  # GRAB_TOP, CHAIN_TOP, SET_OFF, STAND, HEAD, SLIDE_AUTO, opening(TOY_THREAD)...
python tools/kit_piece.py recipe                   # tools/kit_piece_recipe.md
python tools/kit_piece.py yard <id> [--seed 3 --weathered 0.4]
python tools/kit_piece.py check <id> [--shots]
```

- `new` writes `scripts/ruin_kit_<id>.gd` from a stub (one worn block on a
  clean walk box) and registers it in `scripts/ruin_kit.gd` (a
  `<ID>_PIECES` const, FAMILIES, ALL_PIECES, NAMES, the `piece` line) and a
  connector arm in `scripts/ruin_kit_fit.gd`. It never overwrites a file
  and skips edits already made; the piece is in the editor palette and
  passes tests/test_ruin_kit.gd straight away.
- `numbers` prints the sizing constants read live from the code (a
  headless `tools/kit_piece_numbers.gd`), each with its file and name.
  Carries are ballistic estimates: prove a gap with a drive.
- `recipe` is the Build helpers, collision, ledges, meta, ropes, live
  rigs, connectors and LOD by symbol name.
- `yard` prints the shot.py and drive.py lines for
  `studies/kit_piece_yard.tscn` (`--piece=<id> --seed= --weathered=
  --turn=`; the piece is node "Piece" at the origin, its ropes hung live).
  The drive skeleton is `tools/harness/examples/kit_piece_drive.gd`.
- `check` prints one PASS/FAIL line each: the editor round trip
  (`tools/harness/kit_piece_editor.gd`: palette, place, turn, save,
  reload rebuilds the same after a dress, ropes, temp save deleted),
  tests/test_ruin_kit.gd, smokes of the motif editor, motif_yard
  editor_aqueduct_gorge and bell_spires, and the yard; `--shots` adds a
  still sheet. Exits 1 on any failure (about 40 s). Run one `check` at a
  time: the editor round trip uses one temp slug.
- Tool and study scripts get the editor's FootPieces with
  `load("res://scripts/roguelike/layer_greybox.gd").FootPieces` at run
  time; a const preload of it leaks the script graph at exit.

## blender.py: Blender scripts

```
python tools/blender.py --where
python tools/blender.py run art/blender/guacharo/guacharo_build.py -- --out=scratch/g --render=scratch/g
python tools/blender.py run --blend art/blender/plane/plane.blend art/blender/plane/plane_render.py -- scratch/r
python tools/blender.py --expr "import bpy; print(bpy.app.version_string)"
```

It finds Blender from `$BLENDER`, a Program Files install, the Microsoft
Store build's launcher (`%LOCALAPPDATA%\Microsoft\WindowsAppslender-launcher.exe`;
the Store's `blender.exe` gives Access denied), the Mac app or
`/opt/homebrew/bin/blender`. The script runs `-b` inside a bootstrap that
logs its output and writes its exit code, so the detaching launcher still
gives both back: the run prints the output as it comes and exits 0, the
script's `sys.exit` code, or 1 on an exception (Blender alone exits 0
then). `--timeout S` (default 1800) kills it with exit 124. The script sees
its args after `--` as usual, runs from the repo root, and has its own
folder and `art/blender/` on `sys.path` (the shared helpers,
`art/blender/blendkit/`). Don't write a scratch wrapper.

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
