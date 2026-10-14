# Loading screen, round 1 (2026-10-13)

> On `perf/loading-screen` (from `roguelike`). Not merged.

Rendered play now holds behind a loading screen until the generator's layer
stands whole, then drops it. Nothing streams in round the player after.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
# today's streaming-in, no screen
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --no-loading-screen
# the screen without the material warm-up
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --no-shader-warmup
```

Windows (PowerShell, from the repo root, per AGENTS.md "Running on Windows"):

```powershell
$env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
```

Measure (rendered, windowed, vsync off, 1080p cap):

```sh
Godot --windowed --path . -s res://tools/bench_loading.gd -- --no-title --shape=sprawl --seed=2 --secs=30 [--no-loading-screen] [--no-shader-warmup] --out=/tmp/zs-load
```

`--loading-trace` prints, when the screen drops, the main-thread time each
isle stage cost and each isle's timings.

## What it does

- **Screen** (`scripts/roguelike/loading_screen.tscn`, `.gd`,
  `shaders/loading_sky.gdshader`): a calm sky gradient with two slow banks of
  painterly cloud, four floating-isle silhouettes bobbing, the ZENSCAPE title
  in the isle card's gilt Newsreader, "gathering the isles" in Spectral, a
  hairline that fills as the layer is built, and one small tracked line saying
  the real stage ("raising isles 5 / 8", "growing flora", "waking the ruins",
  "raising the viaduct", "laying the far region", "readying the light 12 / 31").
  The whole look is this one scene plus its exports (palette, title, tagline,
  sizes); nothing else knows how it looks.
- **Hold** (`scripts/roguelike/layer_loading.gd`, made by `studies/run_layer.gd`
  when rendered and unscripted): the screen is up and drawn before the base
  isle's long build; the pilot is not ticked, the run loop stands still, keys
  are dropped. Waits for: the plan; every motif isle `up` (built, parts stood,
  held collision shapes put back, turf, flora, life); the Broken Viaduct stood
  off its worker; the next region laid and stood (`NextRegionLoader`, now
  started at once with `eager`, not after the isles stand).
- **Budgets lifted**: `SkyCommits.lifted` = 45 ms a frame (was 4 ms), read by
  `SkyCommits.open()/budget()` and the motif sky's slices, so the main-thread
  stages go flat out and the screen still redraws at about 15-20 fps. (`work(-1)`
  was not used: one isle's flora in one call would freeze the screen for
  seconds.)
- **Warm-up** (`_sweep`): a hidden `Camera3D` (the pilot's fov, environment,
  attributes, cull mask) goes to 25-31 views, 2 frames each, then back: the
  pilot's own view first, then over each isle (from above, standing on it,
  and a third for big ones), the four ways from the start, the parked plane,
  the roost dragon (two views) and a headless body set on the base for the
  sweep and freed. It runs under the screen, in the real lights and shadows.
- **Layer change**: the gate and a void fall bring the screen up (0.45 s fade)
  at the request, over the warm veil; the new climb after a fall is laid behind
  the fall card as before, and the screen comes up at Space only if it is not
  yet whole (`run_loop._maybe_wake` -> `hold_for_layer`). The screen fades over
  1.0 s and the arrival veil is cleared under it (`run_loop.loading_done`).

## Next layer prebuilt: no (screen on layer change instead)

Building the next layer's real isles in the background would mean a second
sky of isles standing and simulating beside the first, a second stage, and a
swap, within the 4 ms slices (the isles' builds are 4-12 s each of worker time,
and the builds serialise: three at once took the same wall time as one, so the
bottleneck is not the one worker). Too big for this round. The next layer shows
the screen instead: a ring layer after a sprawl held play 29.5 s (laid 0.8 s,
plan was already near). The next region's silhouette (the far LOD, as before)
is already there to look at.

## Before / after

Apple M5 Pro, 1080p cap, windowed 1920x1080, vsync off. Load average 1.7-3.9
(other work idle; `uptime` before: 2.4, after: 1.7). One run each, so read
times as plus or minus 10 percent. "Before" is `--no-loading-screen`.
Frame trace is the first 30 s of play from playable, the camera turning once
round in it.

| | Sprawl 2 before | after | Ring 1 before | after |
|---|---|---|---|---|
| Launch to playable | 16.1 s | 48.8 s | 15.8 s | 39.6 s |
| Launch to stands whole | 71.9 s | 48.8 s | 49.5 s | 39.6 s |
| Frames, first 30 s | 1010 | 991 | 1330 | 1336 |
| p50 / p99 (ms) | 28.0 / 34.7 | 28.5 / 29.9 | 20.7 / 28.3 | 21.1 / 22.3 |
| Over 33 / 50 / 100 ms | 47 / 3 / 0 | 2 / 0 / 0 | 7 / 0 / 0 | 0 / 0 / 0 |
| Worst frame | 63 ms | 38 ms | 43 ms | 30 ms |
| Nodes at playable / +30 s | 9.8k / 54.8k | 76.6k / 76.6k | 9.5k / 61.9k | 62.0k / 62.0k |

Before, the pilot can move at 16 s but the layer builds round him for another
40-56 s (nodes grow 5-6x), the worst frames being the stand-ups. After, the
layer is whole at playable (the node count does not move afterwards), the 30 s
trace has no frame over 40 ms, and the time-to-whole is shorter than streaming
(sprawl 72 -> 49 s, ring 50 -> 40 s) because the budgets are lifted. The
cost is that the player waits 40-49 s, not 16, to move. Of that: the plan and
base isle 8-12 s, the isles 18-25 s (worker builds, 4-12 s each, plus 6 s of
main-thread stages), warm-up 1.7-4.9 s. The isle builds are the wall: more
concurrent builds did not shorten it (reverted).

Stills (`docs/design/roguelike/loading-screen-round1/`): the screen at 30 %
and 97 % (sprawl 2) and at 60 % (ring 1); the play view at +10 s before and
after: `sprawl-2-before-play-10s.png` (the far isles still growing in) and
`sprawl-2-after-play-10s.png`. Pop-in after the screen drops: none in the
node counts or the trace; the stills match except the flora's drift and light.

## What the warm-up gained

Measured by running with and without it (`--no-shader-warmup`): no
difference on this Mac in the 30 s turning trace (sprawl worst 38 vs 37 ms;
ring 30 vs 31 ms). Metal's ubershaders and shader cache plus the real camera's
render during the whole load already build what the spawn view needs, and no
hitch shows on the first turn of the view. So its measured gain here is zero
and its cost 1.7-4.9 s. It stays on by default, since a cold GPU driver (a
Windows machine with no shader cache) is the case it is for; `--no-shader-warmup`
turns it off. Unmeasured there.

## Knobs and flags

- `--no-loading-screen`: today's streaming in. Headless and scripted runs
  never show it (so tests do not hang).
- `--no-shader-warmup`, `--loading-trace`.
- `LayerLoading` constants: `LIFT_USEC` 45000, `WARM_FRAMES` 2, `FADE_IN` 0.45,
  `FADE_OUT` 1.0, `WARM_MOST` 90 s. The screen's exports: palette, title,
  tagline, sizes.

## Unverified / known

- Windows and any non-Metal driver: not run. The warm-up's value is
  unmeasured where a shader cache is cold.
- Not warmed: flight-only effects (the plane in the air: trails, boost), the
  headless body's climb and dust, the dragon's attack, the cannon's shots, water
  and rain not in the views. Only what is drawn standing is.
- A fall-card path where the layer is already whole at Space (no screen) and
  where it is not (screen) were not both run; the gate path was (a ring layer
  after a sprawl, 29.5 s, no errors).
- `studies/run_layer.gd`'s `layer_up_ms` can read set before the first layer
  (the sprawl, with the screen: an empty sky counts as "whole"). It is reset
  when the layer stands; the bench was written not to trust it.
- The screen is a first pass: the silhouettes are flat shapes, the far one reads
  grey. Only the first layer's stills are shown.

## Tests

Ran `test_run_layer` (pass), `test_layer_sprawl` (fails the same way on
`roguelike` without this change: seed 2 chain, seed 3 face, void), `test_motif_sky`
(known failure). Nothing it breaks. Headless import and `run_layer` sprawl 2
and ring 4 for 400 frames: no script errors.

## Files

New: `scripts/roguelike/loading_screen.{tscn,gd}`, `layer_loading.gd`,
`shaders/loading_sky.gdshader`, `tools/bench_loading.gd`. Changed:
`studies/run_layer.gd`, `scripts/roguelike/run_loop.gd`, `next_region_loader.gd`,
`scripts/sky_commits.gd`, `scripts/kit_isle/motif_sky.gd` (one line).
