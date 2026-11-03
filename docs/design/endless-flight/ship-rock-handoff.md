# Pirate ships ride the swell: handoff

Branch `iter/ship-rock`, off main a6b64912. Both ships heave, pitch and roll on
the sea under them, and lean a little out of the route's turns. The ride is the
ship node's own transform, so the plane flying through meets the wood where it is
drawn.

Play it:

```
cd /Users/davidkalina/Documents/Projects/zenscape-ship-rock && python3 tools/play.py -- --no-title --pilot-file=/tmp/ship-rock.json --ship-start --full-meter
```

`--ship-start` puts the plane 240 m off the first ship's beam, 16 m over the sea,
flying her way (checked headless with these flags). Add `--ship-rock=0` to compare
with the old fixed height and sway, or `--ship-rock=1.5` for more motion.

## What changed

- `scripts/endless/pirate_ship.gd`:
  - `sea_under()` reads `EndlessSea.height_at` at 14 points in her level frame:
    `ROCK_X` (±11 m across) by `ROCK_Z` (7 points, -60 to 60 m along). The body's
    long waves are 52 to 118 m and she is 130 m, so the 7 rows keep them apart.
    Then it fits a plane through them: the mean is the heave, the slopes are the
    pitch and roll.
  - `_ride_step()` puts each of the three through a damped spring (`ROCK_T`
    8 / 8.5 / 11 s natural period, `ROCK_DAMP` 0.7 / 0.5 / 0.32). It also adds
    a lean out of the turns, `ROCK_LEAN` 0.03 rad at the route's 200 m turn,
    from her yaw rate. Each ship reads the sea every `ROCK_EVERY` 2 frames, the
    two on alternate frames. A return reads it afresh and snaps (`_ride_fresh`).
  - `_pose()` puts `ride` on the node's transform (yaw, then pitch and roll,
    then heave). The sink's pose goes on top as before. The model's `SWAY` runs
    only at `--ship-rock=0`. While she rides, the model keeps only the sink
    shudder.
  - `_place()` gives her `loose` records her whole frame (`xf`, `inv`) while
    she rides. At 0 it drops them.
- `scripts/endless/land_arches.gd`: `stretches` and `record_at` read a loose
  record's `inv`/`xf` when it has them. `_tilted` takes the stretches at the
  point's own spot in her frame and maps their ends back to the world, as the
  wreck's `wreck_ground` does. It is exact at the point's height and off by
  a few centimetres at most for a face 5 m above or below it at 5° of roll. `plane_ground`,
  `_blocked`, the camera's `_solid`/`_sight`, `SurgeSmash._strike` and the near
  miss's probes all go through these two. Records without `inv` take the old
  path unchanged.
- Things that follow the node and needed no change: the model, guns and muzzles
  (`_fire` uses `transform`), plates and shards (in her frame), the StaticBody
  for the wing rays, `local()`/`in_corridor()`/`deck_way_off()`, and the sink's
  `wreck_*`, `_waterline` and `_under`. The relic (`finds.gd`) reads her
  `global_position` +8 m, so it heaves with her but doesn't tilt. At its spot
  amidships that is under 0.8 m at the largest roll, against a 9 m capture.
- The sea's aqua band and foam at the hull come from the depth buffer in the sea
  shader, so they follow any pose with nothing to update. The hull sits right in
  the rendered stills.

## The knob and flag

`rock` (`--ship-rock=K`, default 1):

- 0: today's fixed `SEA_Y` and the model's sway. Nothing reads the sea.
- K above 0: heave × min(K, 1), pitch and roll × `ROCK_GAIN` (3.0) × K, lean × K.

The heave is never exaggerated, so she stays in the water. The gain goes on the
angles, which read from the air.

## Numbers

**The sea on the routes**, headless (all 11 body components). The first route
was read from 4 starts over 120 s each. No surge reaches either route
(`surge_room` 0).

| | Each ship |
|---|---|
| Water at her middle | sd 0.34 to 0.55 m, most 1.7 m |
| Averaged over the hull | sd 0.10 to 0.17 m |
| Slope along her | sd 0.15 to 0.30°, most about 1° |
| Slope across her | sd 0.46 to 0.81°, most 2.6° |

In a rendered run the FFT is on, so the CPU swell uses the 5 long components.

**Her ride at `rock` 1**: 3 minutes through the real loop with `--ship-start`
(`scratch/rock_stats.gd`). The old sway was 0.8° of roll and 0.3° of pitch.

| | first ship | second ship |
|---|---|---|
| pitch, sd / most | 0.78° / 2.26° | 0.40° / 0.96° |
| roll, sd / most | 2.06° / 5.47° | 1.33° / 5.23° |
| heave, sd / most | 0.11 m / 0.41 m | 0.06 m / 0.22 m |

**The exits**: the middle of each gun deck mouth, her local (0, 8, ±56.5),
against where the flat ship would have it.

- First ship: at most 2.30 m off (2.29 up or down, 0.77 sideways), moving at
  most 1.35 m/s up or down.
- Second ship: at most 1.12 m off, at most 0.93 m/s.

A pass takes about 1.5 to 2 s, so an exit moves 2 m at most while you thread it.
The 2 to 2.8 m/s that `rock_fly.gd` prints per pass includes the sink's lurch as
the plane leaves. In the four passes the least room off a wall was 3.6 m (the
plane's half span is 1.4 m).

**In the water**: the hull's waterline points round her were sd 0.64 to 0.76 m
off the sea there, 2.6 m at worst (ends and sides in the swell). The keel was
never above the sea (highest 3.5 m under it). The gun deck's floor line was never
under the sea (lowest 0.4 m over it).

**Cost**: a read is 14 native samples at about 2.1 us each. With the GDScript
around them, `sea_under` measured 33 to 50 us a read (the machine was shared).
Each ship reads every other frame, so it costs about 17 to 25 us per ship per
frame. The springs cost next to nothing. `--gdscript-kernels` wasn't timed. No
frame time was taken: two other agents share the GPU.

## Proved (headless, real input, uncommitted drivers in `scratch/`)

- Smoke, 400 frames with 0 errors:
  - Plain: PASS.
  - `--ship-start --ship-blocks --gdscript-kernels`: PASS.
  - `--ship-start --full-meter` and `--ship-start --ship-rock=0`: 400 frames
    with 0 errors, then Godot hangs on quit (see Not mine).
- `rock_fly.gd --part=probe`, each ship while she rocked, at `rock` 1 and
  again at 4 (tilt up to 3.7°):
  - 38,148 points through her gun deck, hull and ends, inside and out. The
    flight's solid (`arches.inside`) agreed with her own boxes in her frame at
    every point. 0 were wrong, even within 0.25 m of a face.
  - Wing rays across the deck met her walls within 1 mm.
  - The glance pointed off the right wall, roof or floor at every probe.
- `rock_fly.gd --part=fly`: both ships, stern to bow and bow to stern, by real
  input (`fly_boost`, `fly_roll` on a full meter). In each pass both plates
  burst, there was no crash, no scrapes, and no scrape where she shows room.
  Tilt during passes reached 2.0° pitch and 2.6° roll.
- `ship_wall.gd` and `ship_wall.gd --second`: all five touches of walls, roof
  and floor glance with no crash on both ships.
- `ship_sink.gd --part=run`:
  - The ring run sinks her with no crash on her. She goes under, comes back
    out of sight, and the bare run pays 25,000 once.
  - `--part=through --t=3` and `--t=10` (flying at her in the sink): no crash,
    not stuck.
  - The same run at `--ship-rock=0` passes the same checks.
- Rendered (Mac, `scratch/rock_view.gd`): a film from her beam, low (50
  stills, 10 s), and a film from the air at 300 m, plus stills at 100 m, 300 m
  and from the chase camera low over the water, 170 m off her quarter. They are
  in `ship-rock-stills/`. Judged by eye: she sits in the water with the band and
  foam at the hull, and 2° of bow-down pitch reads side-on (07). From 300 m the
  motion is small in a still.

Driver changes: `scratch/ship.gd` and `scratch/ship_model.gd` now steer to the
tilted gun deck's height (`aim.y`) instead of the flat one. `scratch/ship_sink.gd`'s
"upright" check allows for her ride.

## Not proved

- Hand flying any of it. Whether the default amount reads in play or wants
  `--ship-rock=1.5` or 2 is for the user to judge. It was tuned from stills and
  films, not from play.
- Frame time, PC, the `--gdscript-kernels` cost.
- Rocking in heavier water: neither route meets the surge belt, so the largest
  sea she meets is the body swell.

## Not mine (found on the way)

- **Hang on quit:** with `--ship-start`, Godot sometimes hangs on quit after a
  clean run. The main thread waits on a condition variable with every worker
  idle. It happens at `--ship-rock=0` too, where this round's code does
  nothing. The `iter/ship-guns` worktree had a `hang.gd` run on the same flags
  stuck the same way.
- **Ring mark:** `ship_sink.gd`'s "ring mark up on the first ship" check fails
  at `--ship-rock=0` too.

## Tests

No test under `tests/` references `pirate_ship.gd`, `coast_sites.gd` or
LandArches' `loose`/`stretches`/`record_at`.

- `test_world_scale_guard.gd` scans every script: passes.
- `test_cloud_shade_steady.gd`, the one test that opens the scene, is
  `suite: gpu`. It was skipped headless, so it is unverified.

No known breaks.
