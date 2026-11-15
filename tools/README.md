# Tools

Start here before writing a tool. The harness below covers what agents
used to rewrite every round: finding Godot, the import, the smoke check,
driving a study, seed and knob sweeps, rendered stills, and runs past the 10-minute tool limit. Everything is
Python or GDScript, so it runs the same on the Mac and on Windows. Call it
with `python` on Windows (there is no `py` there) and `python3` on the Mac.

| Need | Command |
|---|---|
| A fresh worktree made runnable (kernels, caches, import) | `python tools/worktree.py setup <path> [--cache toad_tex] [--from DIR]`; `check <path>` |
| Run any Godot command | `python tools/godot.py <godot args>` |
| Play the game or a study in a window (for the user; no timeout) | `python tools/play.py [studies/x.tscn] [-- flags]`; the launchers `run-endless-flight.command` (Mac) and `.cmd` (Windows) wrap it; it pulls main first (a checkout on main only; `--no-pull`), warns on stale native kernels, and imports every launch; `--editor` (`open-godot.command` / `.cmd`) opens the editor instead |
| Whether the native kernels were built from the C++ here | `python tools/native_stamp.py` (`--mark` records a build known current); tools/build_native_kernels.py stamps what it builds |
| Smoke a scene (400 frames, no errors) | `python tools/smoke.py studies/x.tscn [-- scene flags]` |
| A check through the real play loop | write `scratch/x.gd` extending `tools/harness/drive.gd`, then `python tools/drive.py scratch/x.gd` |
| Every helper a driver has, with its doc | `python tools/drive.py --api [ray\|shot\|film\|...]` (read from drive.gd; no Godot run) |
| The same over seeds and knobs | `python tools/sweep.py scratch/x.gd --seed 1..8 --knob gulf=40,60` |
| The same over the driver's own args | `python tools/sweep.py scratch/x.gd --arg pilot=stand,flee,dodge` (the driver gets `--pilot=...`) |
| Who's at a point, what a ray hits | in a driver: `say(hit_text(ray(a, b)))`, `pierce(a, b)`, `what_is_at(p, r)`, `what_is_in(box)`, `colliders(node)` (drive.gd, Collider probes) |
| Parse-check a script without running it | `python tools/godot.py --check-only -s res://scratch/x.gd` (one script; exit 1 with the parse error) |
| Check a land outline (bowtie, wrong winding) | `KitLand.outline_problems(outline, winding)`; `KitLand.island` warns on its own |
| A flight taped and filmed again from any camera (trailer shots: no HUD, no dropped frames, any size) | fly with `python tools/play.py -- --record`, then `python tools/movie.py last --from 12 --to 20 --cam flyby` (`--list`, `--preview`; movie.py, below) |
| Rendered stills to look at | `python tools/shot.py studies/x.tscn --frame Trap --view three,top --sheet` |
| A still of a moment in a driven run (the plane touching down, a piece by its AABB) | in a driver: `await shot_at("side", node, {"when": cond})`, then step frames; run with `drive.py --rendered` (drive.gd, Shots) |
| A plane skin's sheet: the hero plane wearing it from a few angles, by day and (when it glows) by night, in one image | `python tools/skin_sheet.py paint/moonstone` (`captures/skins/<id>.png`; several ids stack into `--out`; `sheen:gloss[@id]` a finish alone; skin_sheet.py, below) |
| A short film and contact sheet of something moving | in a driver: `var f := film(node, {"view": "shoulder", "every": 6, "seconds": 3})`, step frames, `await film_end(f)` (drive.gd, Shots) |
| Run a Blender script (Mac, Windows, the Store build) | `python tools/blender.py run art/blender/x/x_build.py [--blend F] [--timeout S] -- args`; `--where`; `--expr "..."` |
| Anything that runs over ~8 min | `python tools/bg.py start NAME -- <command>`, then `python tools/bg.py wait NAME` |
| Where the land could carry a lake-fed waterfall and a tunnel behind it | `python tools/fall_sites.py [--r 10000] [--step 20] [--grid DUMP] [--near x,z]` (dumps the natural land with `tools/harness/land_dump.gd`, then lists hollows whose way out drops steeply, with a bore from each foot; a coarse lead list, refine before placing) |
| The test suite | `python tools/run_tests.py [--tests 'test_x*.gd'] [--quick]` |
| Measure a still's look (palette, shadows, blotch scale, edges, aerial) against the world's ranges, or two stills | `python tools/look_measure.py a.png [b.png] [--crop x0,y0,x1,y1] [--no-classes]` (stills: `tools/harness/look_views.gd`; `docs/art/look-breakdown.md`) |
| Where the light on screen comes from (sun, sky fill, rim, haze per class, sunlit and shade), and a pixel-matched before/after of two runs | `python tools/drive.py tools/harness/light_split.gd --rendered --log L.txt -- --out=DIR --views=hills,sun_toward --save-mask --scene-args --no-title --hour=17.5`, then `python tools/light_split.py shares L.txt` or `match BEFORE_DIR AFTER_DIR` (views: `tools/harness/look_views.gd` SPOTS and SUN, the ones facing toward and away from the sun) |
| Frame time at the look views | `python tools/drive.py tools/harness/look_views.gd --rendered --log L.txt -- --views=high,cruise --time=240 --scene-args --no-title` (a ROW per view: median ms from frame to frame, vsync off) |
| Why a flight stutters: every frame of a real flight, by hand or driven (parts of the tick, engine, place), then the spikes and their causes | `python tools/play.py -- --frame-log=res://scratch/f.csv`, then `python tools/frame_report.py scratch/f.csv [before.csv]`; `scripts/frame_log.gd`. Measure low and fast: the cost lives near the ground |
| How a line scored: every near-miss moment of a flight (kind, factors, run, flourish, the line's total), re-scored from the raw columns as line cards; a tuning tried on a flight already flown | `python tools/play.py -- --line-log=res://scratch/line1.csv`, then `python tools/line_report.py scratch/line1.csv [other.csv] [--set key=value] [--check]`; `scripts/endless/line_log.gd`, `line_score.gd`, `line_tune.json` |
| The native ground layers (broad phase, tree solid) against their GDScript, bit for bit | `python tools/ground_parity.py [--only ground\|trees] [--break]` (~9 min; `tools/harness/ground_parity.gd`); exit 1 on any mismatch, `--break` must fail |
| The endless land's hash for a seed, to compare machines (co-op) | `python tools/land_hash.py --seed 1 [-- --land-native=0]`; `--compare a.txt b.txt` |
| What a scene or folder reaches (scripts, scenes, shaders, assets), or why a file is reached, before cutting or moving files | `python tools/reach.py studies/x.tscn scripts/endless [--out F]`; in Python `reach.why(starts, file)`. It reads res:// strings, class_name words, uid:// ids and #includes; a compressed binary scene's dependencies come from Godot (`ResourceLoader.get_dependencies`) |
| A top-down map of a box of the land, every site and find named | `python tools/site_map.py --box=x0,z0,x1,z1 --out scratch/m.png` (also `m.sites.json`; `--kinds arch,find`; `--from-json` redraws) |
| The flight glyphs' polygon data, from the design's json to the script the game loads | `python tools/glyph_data.py` (`docs/design/ui/mock/glyphs.json` to `scripts/endless/near_glyph_data.gd`; `--check` exits 1 when the script is stale) |
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
python tools/smoke.py studies/endless_flight.tscn studies/flight_study.tscn -j 2
python tools/smoke.py studies/endless_flight.tscn -- --world=regions
```

Each scene is opened the way the game opens it (`change_scene`), then runs
400 frames at `--fixed-fps 60`. It prints one PASS/FAIL line per scene,
with how long the scene took to be walkable and any errors with their
`at:` lines. Endless flight takes about 10 s (15 s with `--world=regions`).

## drive.gd + drive.py: checks through the real play loop

```gdscript
extends "res://tools/harness/drive.gd"

func drive() -> void:
	await open("studies/endless_flight.tscn")      # flying, or a FAIL line
	var plane: RefCounted = study.plane
	hold(&"fly_brake")                              # the real input actions
	var down := await until(func() -> bool: return not study.hand_landing.flying(), 3000)
	check(down >= 0, "touched down", "speed %.1f" % float(plane.speed))
	result("touch_frames", down)
	row({"seed": arg("seed"), "speed": plane.speed})
```

`python tools/drive.py scratch/land.gd -- --seed=2 --scene-args --at=720,760 --alt=14`

- **Args.** Args after `--` belong to the driver: `arg`, `arg_int`,
  `arg_float`, `arg_vec3`, `flag`. Args after `--scene-args` are the
  scene's launch flags. `open` hands those to the scene, with
  `--no-title`, through `scripts/launch_args.gd`; `--title` among them
  keeps the scene's title instead (endless flight's main menu).
- **Time.** `frames(n)` and `until(cond, max)` step the real loop: the
  study's own `_process`, with input read as actions.
- **Input.** `stick(v)` (Godot's convention: (0, -1) is forward),
  `press(action, n)`, `hold(action, on)` and `let_go()`. `press` only
  sets an action's state: a key a study reads as an event needs
  `tap(KEY_SPACE)` or `tap(&"walk_jump")`, a real key event through
  `Input.parse_input_event`.
- **The window.** In a rendered run `open` sets the window to `--win=WxH`
  (else the driver's `--size=`, else 1440x900) after the scene opens, and
  notes the window, viewport and 3D scale: the project starts full screen,
  and on a Mac that could win over `--windowed --resolution`, so a run drew
  at the screen's size with its 3D scaled down. `--win=keep` skips it;
  `fit_window(size)` does it again.
- **Looking around.** `find(pattern)` and `first(pattern)` look up nodes
  by name, class or script path. `shot(path)` takes a still of the window,
  `shot_at(view, target)` and `film(target)` place a camera of their own
  (`--api shot`); all three only in a rendered run, and print SKIP headless.
- **The full list.** `python tools/drive.py --api` prints every helper's
  signature and doc, read from the scripts; `--api WORD` adds the
  section's notes (a shot's opts, what `film_end` returns). drive.gd's
  header index comes from the same parse: after changing a helper, run
  `python tools/drive.py --api --update`. `--api` exits 1 while the index
  misses a helper.
- **Reporting.** `check(ok, label, detail)` prints `OK`/`FAIL`.
  `result(k, v)` adds to the closing `RESULT {json}` line. `row(dict)`
  prints `ROW {json}`, which a sweep turns into table rows. `say(text)`
  and `note(text)` print lines drive.py shows. The run exits 0, or 1 if a
  check failed, or 2 on `--timeout=` (wall clock, default 240 s).
- **Throwaway drivers** go in `scratch/`, which git ignores and Godot
  doesn't scan.
- **Typing.** The project treats an untyped `:=` from a Variant as a
  parse error. Write `var d: Dictionary = x.get("k")`, not
  `var d := x.get("k")`. drive.py points this out when it happens. A
  script that doesn't parse fails in about a second.

## sweep.py: a table over seeds and knobs

```
python tools/sweep.py scratch/gap.gd --seed 1..6 --knob gulf=40,60,80 --csv scratch/gap.csv -j 8
```

Each axis becomes a scene flag: `--seed=N`, `--shape=S`, `--knob=k=v`, and
`--set name=a,b` gives `--name=a`. `--arg name=a,b` gives the driver
`--name=a` instead (before `--scene-args`), so the scene never sees it:
`python tools/sweep.py scratch/x.gd --arg line=low,high`. Ranges are written `1..5` or `0..20..5`.
The columns are the driver's RESULT values, or one row per ROW line it
printed, plus `ok` and seconds. To try a value, pass it as a flag. Don't
`sed` it into the source.

## shot.py: rendered stills

```
python tools/shot.py studies/ruin_kit_gallery.tscn                         # its own camera
python tools/shot.py studies/flight_study.tscn --frame all --view three,front,top,close --sheet
python tools/shot.py studies/endless_flight.tscn --at 0,30,60 --look 0,0,0
python tools/shot.py --sheet-of a.png b.png --out scratch/sheet.png        # headless
```

Each run opens one Forward+ window. A lock keeps it to one window across
agents, and a watchdog closes it. `--frame PATTERN` frames the meshes
under the matching nodes. `walker` frames the study's figure (if it has one) and `all` frames the scene.
The views are three, front, back, left, right, top and close. The HUD is
hidden unless you pass `--hud`. Files go to `captures/shots/<scene>_<view>.png`
unless `--out` says otherwise. Read the PNGs and judge them yourself.
Headless runs can't take stills.

## skin_sheet.py: a plane skin's sheet

```
python tools/skin_sheet.py paint/moonstone                     # captures/skins/paint_moonstone.png
python tools/skin_sheet.py paint/harbour paint/night --night   # a night row though they don't glow
python tools/skin_sheet.py sheen:satin sheen:gloss sheen:matte sheen:metal --no-night --out captures/skins/sheens.png
python tools/skin_sheet.py sheen:metal@paint/ochre --views port,starboard,tail,chase
```

A skin is a ShopStock id from any batch (`scripts/endless/skins/`), or
`sheen:NAME[@id]`: that skin's livery (Harbour's by default) in the sheen
alone, or `glow:HEX[*POWER][@id]` (quote it in the shell): that livery with
its body and trim glowing HEX at POWER (1), to tune a glow. The plane is frozen in flight over the endless land
(`tools/harness/skin_sheet.gd`), painted through `ShopStock._paint`, the
shop's own path. A skin's sheet is a row of views at `--day-hour` (11), and
a second at `--night-hour` (1) when its finish has a glow (`--night` for
all, `--no-night` for none): two windows, one after the other, under
shot.py's window lock. Views, in the plane's own frame: port, starboard,
quarter (ahead, above), top, tail, and chase, where the play camera sits at
a cruise (GlideCamera's BACK, UP and FOV): flying distance. Default
port,quarter,top,chase. Several skins stack, rows in the order given, into
`--out` (default `captures/skins/sheet.png`). The stills are kept in
`captures/skins/raw/`. Exit non-zero when a skin is unknown or a still is
missing. About 20 s a window.

## movie.py: a taped flight, filmed

```
python tools/play.py -- --record                    # fly; writes scratch/flights/<date>.flight
python tools/movie.py --list                        # the tapes, their takes and lengths
python tools/movie.py last --preview --cam orbit    # watch it in a window, nothing written
python tools/movie.py last --from 12 --to 20 --cam flyby,dist=12 --size 2560x1440
python tools/movie.py last --from 30 --to 33 --speed 0.5 -- --hour=17.5 --no-clouds
```

`--record[=FILE]` tapes the flight proper, a row a frame: the camera, the
hour, the input and every number the plane and the landing hold
(`scripts/endless/flight_tape.gd`). `--replay=FILE` draws it again
(`scripts/endless/flight_replay.gd`): the plane and the landing are set from
the tape, mixed between its rows, and the rest of the tick runs as in play,
with the HUD hidden and no book kept. movie.py launches that under Godot's
Movie Maker on the tape's seed, world, weight and flags, the Full preset and
the 3D at the window's own resolution, then cuts off the frames before the
take starts. A film is `captures/movie/<name>/frame000001.jpg` on and
`sound.wav` (an editor opens them as one clip), and an `.mp4` when ffmpeg
is on the PATH. JPEG frames take about 0.06 s each at 1080p and 0.18 s at
4K; `--lossless` writes PNGs at about 0.3 to 0.5 s each. A launch takes
about 45 s before the first frame.

- **Cameras** (`--cam NAME,knob=value`): `flown` (the eye as it was), `chase`
  (the game's chase camera afresh), `orbit`, `side`, `front`, `top`, `flyby`
  (stood where the plane will pass, a long lens following it). The knobs
  and their defaults are `CAMS` in flight_replay.gd.
- **Takes.** The scene standing again (a door, a restart) starts a new take
  in the same tape: `--take N`.
- **Size.** Movie Maker films at the project's window size and scales every
  frame to it, so movie.py writes the size to `override.cfg` for the launch
  and deletes it once the first frame is out. The window is borderless, so
  it can pass the screen's size.
- **Flags after `--`** go to the game: a look to A/B, `--hour=`, `--frame-log=`.
- Only the plane, the landing, the camera and the hour come from the tape.
  The clouds and the wildlife run on their own clocks from the launch, so
  expect them elsewhere than in the flight (not compared).

## blender.py: Blender scripts

```
python tools/blender.py --where
python tools/blender.py run art/blender/guacharo/guacharo_build.py -- --out=scratch/g --render=scratch/g
python tools/blender.py run --blend art/blender/plane/plane.blend art/blender/plane/plane_render.py -- scratch/r
python tools/blender.py --expr "import bpy; print(bpy.app.version_string)"
```

It finds Blender from `$BLENDER`, a Program Files install, the Microsoft
Store build's launcher (`%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe`;
the Store's `blender.exe` gives Access denied), the Mac app or
`/opt/homebrew/bin/blender`. The script runs `-b` inside a bootstrap that
logs its output and writes its exit code, so the detaching launcher still
gives both back: the run prints the output as it comes and exits 0, the
script's `sys.exit` code, or 1 on an exception (Blender alone exits 0
then). `--timeout S` (default 1800) kills it with exit 124. The script sees
its args after `--` as usual, runs from the repo root, and has its own
folder on `sys.path`. Don't give it an arg starting `--cycles`: Blender's
Cycles add-on reads `sys.argv` and exits on one. Don't write a scratch wrapper.

## worktree.py: a fresh worktree

```
python tools/worktree.py setup ../my-lane                     # kernels + import
python tools/worktree.py setup . --cache toad_tex --from ../lane-toad-body
python tools/worktree.py check ../my-lane --cache all
```

Copies the git-ignored native kernels (`native/terrain_kernels/bin/`,
`zenscape_kernels.gdextension` and its `.uid`) from the main checkout, or
`--from`, and each `--cache NAME` (`scratch/cache/NAME`, else
`scratch/NAME`; `all` for every stage), then runs the headless import
there. Unchanged files are skipped. `check` lists what's missing and
changes nothing.

## bg.py: runs past the tool limit

```
python tools/bg.py start suite -- python tools/run_tests.py
python tools/bg.py wait suite          # blocks up to 540 s, prints the tail; exit 3 = still running
```

Logs and state go to `scratch/bg/`. Use this rather than `sleep` and
`until` polling loops.

## The other tools

These are one-off probes, captures, films, benches and dumps from earlier
rounds (the ones for the cut scenes went with them on 2026-10-24:
docs/archive.md). Most say what they do and how to run them in their header.
`python tools/index.py <word>` lists them with that line. Reuse one, or
copy its idea into a driver, before writing another.
