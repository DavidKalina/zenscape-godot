# The steam train: handoff (loop `steam-train`, 2026-11-06)

Spec: `spec-steam-train.md`. Trail: `git log --grep='^ITER(steam-train)'` on
`iter/steam-train`, which sits on `iter/railroad` (PR #46, not merged). Three
lanes ran at once and were merged: `lane/train-cars` (the 24-car train in
greybox), `lane/train-ride` (landing on a car and riding it) and
`lane/train-model` (the Blender models). The trunk put the models on the
trains, then added the smoke.

## What's built

- **Two 24-car mixed trains (549 m)** run the railroad's line at 32 m/s. Each
  is the engine and tender, then freight: boxcars, logs, doors, a gondola,
  stock cars, flats, a truss, a crane and its idler, and the smash car. Then
  two coaches and the caboose. Car order is `RailTrain.CARS`
  (`scripts/endless/rail_train.gd`). They still pass mid west tunnel and mid
  bay bridge every lap (1038 s), 7 m apart.
- **The models.** A 4-4-0 engine (black, red cab, brass), a tender with a coal
  heap, barn-red boxcars, green coaches with a gold line, and a red caboose
  with a cupola. All 13 kinds are built by one script,
  `art/blender/train/train_build.py`, into `assets/models/train/<kind>.glb`.
  They share eight materials, with paint and grime in the vertex colours. The
  build reads each glb back and proves every opening clear (exit 1 if not).
  - **Far looks.** Each glb has a hand-made Far version, shown at rest from
    150 m (the tender from 200 m, the engine from 250 m). An import script,
    `assets/models/train/train_import.gd`, sets the ranges.
  - **On the trains.** `scripts/endless/rail_train_look.gd` puts each car's
    glb on its car. The drivers, wheels and rods follow the train's odometer
    and the trucks swivel on curves, but only within a car's Far range.
  - **The smash car.** Its two end walls burst into planks the pirate ship's
    way: thrown in the car's frame, some left lying in the corridor and on
    the flats either side, some fallen away. They reseal 150 m off.
  - **Colliders.** What you see is what you hit. The engine's solid is 22
    boxes that follow its model (`ENGINE` in `rail_train.gd`). Every other
    kind's solid already matched.
- **Openings to fly through**, each scoring near misses: doors and stock
  doorways (10 x 6), the log gap (7 m, open above), the truss's middle panel
  (10 x 6), under the crane's boom over the idler (6 m clear), the gap
  between the two coaches (10 x 6, over the railings) and the smash car's
  corridor.
- **The smoke** (`scripts/endless/rail_smoke.gd`,
  `assets/models/train/train_smoke.gdshader`). It is look only, and the plane
  flies through it.
  - **The stack.** Four chuffs a turn of the drivers, every other one weaker:
    0.8 a second pulling out, 4.3 a second at 32 m/s. The smoke is dark at the
    stack and goes grey over 6 s. Each puff lasts about 19 s, so the trail
    lies back over the train.
  - **Steam.** White steam from the cylinders at stops and pulling out.
  - **The far plume** shows from 300 m out. A train too far off to be built
    (past 4 km) still has its plume, posed from its timetable, so a train can
    be found from anywhere on the land. The plume is a white streak at
    1–1.5 km, grey at 3 km and a thin line at 6 km.
  - **In a bore** the puffs stay under the vault.
- **Riding** (`scripts/endless/rail_ride.gd`, with small hooks in
  `manual_landing.gd`, `glide_camera.gd`, `plane_ground_scale.gd` and
  `studies/endless_flight.gd`).
  - **Landing.** Land on a flat's deck or any roof except the engine's. The
    touchdown is graded on the speed relative to the car.
  - **Sitting.** The plane rides through curves, grades, stops, the bores and
    the spans. The camera looks round as when you're stopped on the ground,
    and nothing scores while you sit.
  - **Lifting off.** Boost and pull lift off at the train's speed.
- **Platforms** at the start and farm stops are as long as the train. Mine and
  cattle can't take it: the standing train's ends hang onto the trestles and
  creek bridges either side (see Open).
- **A yard study** (`studies/train_yard.tscn`): the models on a straight
  track in the game's light.

## Play it

From `/Users/davidkalina/Documents/Projects/zenscape-steam-train` (or main once
merged). Every command takes `--pilot-file=/tmp/rail.json` so your saves stay
untouched.

- **Fresh start:** `python3 tools/play.py --no-pull -- --pilot-file=/tmp/rail.json`.
  The trains meet on the bay bridge about 35 s after takeoff, behind you to
  the left.
- **Quick starts:** `python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/rail.json --rail-start=<name>`.
  The first three put you in the gap 30 m behind train 0's caboose.
  - `beside`: the farm plain at full speed, about 65 s up the train to the
    engine. The farm town stop is about a minute on: steam, and the pull-out's
    heavy chuffs.
  - `tunnel`: 16 s before the meeting in the west tunnel.
  - `bridge`: the meeting on the bay deck.
  - `ride`: sat on a flatcar at the start station, 3 s before it pulls out.
    Right stick to look round, Boost and pull to lift off.
    - `--ride-car=box`: the tallest roof instead.
    - `--ride-at=S`: S seconds further on: 418 for 12 s before the tunnel
      meeting, 470 for the mine trestle, 940 for the bay bridge meeting.
- **The test oval on the sea:** `-- --no-title --train-test --trains=1`. Add
  `--full-meter` to surge through the smash car.
- **The yard:** `python3 tools/play.py --no-pull studies/train_yard.tscn -- --no-title --line=24`.
  Drag to look round and use the wheel to zoom. `--lod=near|far` forces the
  near or far look, `--train --solids` draws the colliders, and
  `--car=N --view=close|three|side|back` frames one car.
- **Rebuilding the models:** `python3 tools/blender.py run art/blender/train/train_build.py`
  (`-- --only=engine,tender --render` for some kinds and Blender renders).
  Then run `python3 tools/godot.py --import`; smoke and drive don't reimport
  a glb.

## Flags (new this loop)

| Flag | What it does |
|---|---|
| `--rail-start=ride` | the ride quick start |
| `--ride-car=<kind>` | ride another kind with a top (`box`: the 9 m roof) |
| `--ride-at=S` | the ride start S seconds later in the lap |
| `--train-greybox` | the old greybox blocks instead of the models (A/B) |
| `--no-train-smoke` | no smoke (A/B) |

The railroad's flags are unchanged: `--no-railroad`, `--trains=`,
`--train-speed=`, `--track-gap-toy=`, `--rail-clock=`,
`--rail-start=beside|tunnel|bridge`, `--train-test` and `--train-keep=0`.

## Flown (through the real play loop, headless)

The drivers are in `scratch/`, uncommitted.

- **Both meetings** (`rail_quick.gd`), held in the gap between the tracks:
  - **West tunnel:** 2.8 s between both trains, train 1's caboose past at
    23 s. 0 crashes, 0 scrapes, the camera never inside a car.
  - **Bay bridge:** 6.7 s between them. 0 crashes, 0 scrapes, 15 near misses.
- **Every opening** on the test oval (`cars_fly.gd`, `--trains=1`): the logs
  twice, doors twice, stock twice, the truss, under the crane's boom and the
  coaches' gap.
  - **A paced slide, holding the hole's height:** 9 of 9 clean, each
    scoring a near miss.
  - **Square across on Boost:** the 10 m openings, 7 of 7 clean.
    - The second log car (#15) crashed: the driver came in 2.3 m behind the
      gap's middle and a wing caught the front bundle.
    - The first log car (#3) was clean.
  - **Paced, hands off:** log car #15 sinks 0.6 m and scrapes its deck. This
    happens on the cars lane's own branch too, so the models didn't cause it.
- **The smash car** (`look_check.gd`):
  - A surge roll bursts both walls, throwing 82 planks.
  - The planks end in the corridor (7-10), on the flats (21-31) and fallen
    away (44-51).
  - The reseal puts every plank home.
  - 0 crashes with one train on the oval. With two, the driver's plane,
    parked over the other track, met train 1.
- **A ride:**
  - **The whole lap on the boxcar roof** (`ride_line.gd`, `--ride-car=box`,
    1045 s): 4 stops, 4 bores, 24 spans, the tunnel meeting (423 s) and the
    bridge meeting (942-949 s, train 1 10 m off).
    - 0 frames off the car; slide 0.001 m, jitter 0.0015 m a frame.
    - Body and eye never in stone, nothing scored.
    - The least room is 6.9 m over the plane's top, in a bore.
  - **A flat through the tunnel meeting** (150 s): the same, with 13.4 m of
    room in the bore.
- **Landing and lift-off** on the oval (`ride_land.gd`) on a flat and on a
  coach roof:
  - A firm touchdown at 2.5 m/s relative to the car, then 20 s carried:
    0 off, 0 slide, 0 jitter.
  - Lifted off after 28 frames at 34.8 m/s, with the train at 32.
  - The checks for a stop and a curve failed only because a 20 s ride met
    neither. The lap covers both.

## What it costs (headless CPU only)

The cost route (`cars_cost_ab.gd`, the cars lane's) runs from the tunnel
start, low in the gap, through the tunnel meeting, over the mine trestle and
past the mine stop, about 115 s. Three sides, run twice each, alternating,
with nothing else running on the machine:
- **new:** the models with smoke;
- **no smoke:** the models with `--no-train-smoke`;
- **old:** the railroad's 12-car greybox (the detached worktree
  `../zenscape-train-cars-ab`).

| | new | no smoke | old |
|---|---|---|---|
| frame median (ms) | 3.83 / 3.97 | 3.90 / 4.01 | 3.67 / 3.76 |
| frame p95 | 6.55 / 6.77 | 6.65 / 7.24 | 6.38 / 6.49 |
| frame p99 | 12.0 / 12.7 | 11.8 / 13.1 | 12.5 / 13.5 |
| frames over 16.7 ms (of ~6800) | 25 / 29 | 33 / 37 | 22 / 28 |
| trains, mean | 0.55 / 0.58 | 0.55 / 0.58 | 0.27 / 0.28 |
| trains, p99 | 1.79 / 1.80 | 1.76 / 2.07 | 1.08 / 1.05 |
| trains, max | 4.3 / 4.6 | 4.2 / 4.2 | 2.8 / 2.6 |
| near-miss scoring, mean | 0.52 / 0.54 | 0.53 / 0.56 | 0.53 / 0.54 |

- **The trains** cost about 0.3 ms a frame more than the 12-car greybox, and
  0.7 ms in the bore with both trains near (against 0.35).
  - The cars lane measured the 24-car greybox alone at about +0.2 ms, so
    the models add about 0.1 ms.
  - The cost is steady: frames where the trains took over 2 ms went from
    6-8 to about 57. Long frames overall are about the same.
- **The smoke** is in the noise on the CPU (about 22 µs a frame for both
  trains).
- **Near-miss scoring and landing** are unchanged.
- **GPU: unverified.** Headless draws nothing: the draws, the puffs' fill
  flying through the trail, the Far switch and the glbs' first upload. The
  yard's rendered numbers are under Model budget.
- **The next step:** a frame log of a flight you fly (below).

Logs: `scratch/ab_{new,nos,old}{1,2}.csv`. Read them with
`python3 scratch/cars_ab_sum.py <csvs>`, or `scratch/cars_ab_segs.py` for
each stretch of the line.

## Stills (rendered, in `scratch/shots/`)

- `flown/sheet_play1.png`, `sheet_play2.png`: the chase camera through the
  log gap, the doors and stock doorways, the truss, under the crane's boom
  and the coaches' gap.
- `flown/sheet_ride.png`: sat on a boxcar roof on the bay bridge, train 1
  passing.
- `look/sheet1.png`, `sheet2.png`: the train on the line, the engine, the
  smash car's planks flying.
- `smoke/sheet_run.png`, `sheet_stand.png`, `far3/far_sheet.png`: the trail
  over the cars, steam at a stop, the plume from 0.8 to 6 km.
- The yard's stills are in `../zenscape-train-model/captures/shots/`
  (`train24_low.png` first).

## Model budget (`docs/art/model-budget.md`)

- **Import LODs, visibility ranges: applied.** Godot's generated LODs barely
  touch these meshes, because every face has its own vertices. So each car
  has a hand-made Far look, and every part hangs on it (Godot's HLOD), so a
  car switches whole. Measured in the yard (rendered, Mac):
  - **Triangles:** a 24-car train is 137k with every part and 70k as Far
    (-49%).
  - **The whole train from 631 m:** draw calls 257 -> 67, render CPU about
    0.7 -> 0.5 ms.
  - **Down the train from 70 m ahead:** draw calls 407 -> 211.
  - **In all:** about 0.2 ms of render CPU and about 190 draws saved for each
    train in view. GPU time is unmeasured (this Mac gives no timestamps).
- **Vertex-colour grime: applied.** Paint and grime are in the vertex colours,
  so eight shared materials serve every kind. Repeated kinds share one mesh:
  7 flats and 3 boxcars on each train. That saves draw state, not triangles.
- **Rigid parts on bones: applies in kind.** Every moving part is its own
  node, with no skinning. Nothing more to save.
- **Silhouette geometry: applies.** The outline detail is real geometry:
  running boards, brake wheels, ladders, the shards. The board seams are in
  the textures. Nothing to take.
- **Sculpt high, bake low, and parallax depth: don't apply.** The cars are
  hard-surface painted timber and iron, and the seams are in normal maps.
- **Also applied:** mipmaps and VRAM compression on the textures (boards
  speckled at range without them).
- **Not done, if the GPU log says triangles cost:** a third level past about
  600 m, the greybox blocks in one MultiMesh. That would take a train from
  about 70k triangles and 50 draws to a few hundred triangles and a handful
  of draws.

## Stood in

- The models are built at the default sizes. At another `--plane-scale` the
  colliders follow `WorldScale` but the models don't.
- The cab and coaches are empty. There is no sound: no chuff, whistle, bell
  or wheels.
- The Far looks don't animate: past 150 m (the engine 250 m) the wheels and
  rods stand still. A smash car seen bursting from past 150 m shows sealed.
- The coach's trucks sit 6.25 m off its middle on the model, while the car is
  posed on bogies 3 m in from its ends: a few cm off the rail on curves.
- Puffs in a train's smoke aren't sorted by depth. No fault showed in the
  stills. If one shows in play, sort them by distance.
- The HUD still calls a car graze "STONE GRAZE".

## Open: for the user

- **The engine's look** (your notes on the first engine, for a later round):
  - a lower, narrower cab, so the boiler and stack lead;
  - a bigger funnel stack;
  - a big lantern headlamp;
  - red or black drivers. They're red now; the spec said black, and the
    model lane made them red.
- **The smoke's thickness.** The near trail reads thinner from 150 m than up
  close. Say if it should be thicker. Tuning is in `RailSmoke`'s consts and
  the shader's uniforms.
- **The log gap** is a paced or angled slot. Square across on Boost, the
  train's drift over 6 m (3.4 m) plus the wingspan leaves little room in 7 m.
  Square across at cruise it doesn't fit at all.
- **Mine and cattle stops** can't take a 549 m train between their trestles
  and creek bridges. The nearest long-enough plain bed is 550 m off at mine
  and 620 m off at cattle. Using it means re-laying the stations with
  `tools/rail_line.py` (`PLATFORM` 561) and moving their towns.
- **A GPU frame log of a flight you fly** low along the train and through a
  meeting (AGENTS.md, Stutter). The headless numbers above can't see the
  draws, the smoke's fill or the Far switch.

## Open: for a later round

- The engine's look changes above.
- Sound: chuffs in time with the smoke's beat, the whistle, the bell and
  rail noise.
- If the GPU log asks for it:
  - the third, far level;
  - taking far cars' bodies out of the physics space;
  - posing far trains' cars from one pose each instead of two bogies.
- The models at other plane scales, if `--plane-scale` stays a choice.
- Re-laying the mine and cattle stations for the long train.
- The railroad's own leftovers (`railroad-handoff.md`, Open) still stand.

## Tests

Prototype: no tests were added and the full suite wasn't run. Smoke checks
pass for `studies/endless_flight.tscn`: plain, `--train-test`,
`--no-railroad`, `--train-greybox`, `--no-train-smoke`, and each quick
start. They pass for `studies/train_yard.tscn` with `--train --solids` too.
Seed 1's land hash with `--no-railroad` matches main (`9ceaddb3…fcb3c4e8`).
No test references the train.
- `tests/test_glide_camera.gd` covers `glide_camera.gd`, which the ride
  changed (an `under` velocity, zero by default). It passes, as does
  `test_world_scale_guard.gd` (run on the merged branch).

## Files

- **New:**
  - `scripts/endless/rail_train_look.gd`, `rail_smoke.gd`, `rail_ride.gd`;
  - `assets/models/train/`: the 13 glbs, `train_import.gd`,
    `train_surface.gdshader`, `train_smoke.gdshader`, the materials and the
    textures;
  - `art/blender/train/train_build.py`;
  - `studies/train_yard.tscn` and `.gd`.
- **Shared lines:**
  - `scripts/endless/rail_train.gd`: the 24-car table, the kinds, `ENGINE`,
    the look's hooks;
  - `rail_trains.gd`: the smoke, the ride, the ride start;
  - `rail_stops.gd` and `rail_bed.gd`: the platforms;
  - `scripts/manual_landing.gd`, `glide_camera.gd`,
    `plane_ground_scale.gd` and `studies/endless_flight.gd`: the ride's
    hooks.
