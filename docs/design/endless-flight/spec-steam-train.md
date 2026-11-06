# Spec: the steam train (loop `steam-train`, trail prefix `ITER(steam-train):`)

The railroad's greybox trains (loop `railroad`, `railroad-handoff.md`) become
classic steam trains. The user flew the greybox ("a great start") and asked
(2026-11-06) for:
- real Blender models that look like a classic train and fit the world;
- coal smoke puffing from the stack;
- longer trains with more cars, and more cars to fly through, kept realistic;
- landing on a car and riding it, sitting there taking in the sights as it
  goes.

This branch, `iter/steam-train`, sits on `iter/railroad` (PR #46, not merged).

## Read first

- `docs/design/endless-flight/railroad-handoff.md` and `spec-railroad.md`:
  what's built, the flags, the quick starts, the rail path contract.
- `scripts/endless/rail_train.gd`: the cars (`CARS`: kind, length, height),
  their solids and dress (`_blocks`), the doors car's doorway (`door_wide`,
  `door_high`), the smash car's corridor and plates, the keep-out.
- `scripts/endless/rail_trains.gd`: the trains as one module, the timetable,
  building near the plane (look within 4 km, solid within 600 m), the quick
  starts. `rail_timetable.gd`: stops, dwells, the meetings.
- `scripts/endless/rail_bore_shape.gd`: the bores are sized on the tallest car
  (`CAR_TALL` 9 m) with an opening over it.
- `art/blender/ship/ship_build.py` and the pirate ship's "Contract for the
  model" (`pirate-ship-handoff.md`): how a model is built here. It has numbers
  in one block, painted textures, vertex-colour grime, a glb into
  `assets/models/`, and the openings read back from the glb and proved clear.
  `tools/blender.py` runs Blender. After a build, run
  `python3 tools/godot.py --import`: smoke and drive don't reimport a glb and
  silently use the old one.
- `docs/art/model-budget.md`: the tricks every model round assesses.
- The plane's landing: `scripts/plane_landing.gd`, `scripts/manual_landing.gd`.

## Decided with the user

- **The look: a classic western train, stylised to fit the world.** It is
  chunky, painted and a bit toy-like, not photo-real (the user rejected a
  too-realistic rock look before).
  - **The engine:** a 4-4-0 with a funnel stack, cowcatcher, big headlamp,
    bell, sand and steam domes, and a tall wooden cab. It is black, with a red
    cab and brass trim.
  - **The tender:** carries a coal heap.
  - **The cars:** barn-red boxcars in painted timber, like the towns. The
    coaches are a deep green with a gold line, and the caboose is red with a
    cupola.
  - **Size:** oversized against a real train, as now; the openings set the
    size. No figures: the cab and coaches are empty.
- **Smoke.** Coal puffs chuff from the stack:
  - **Rhythm:** in time with the train's speed and readable, a few puffs a
    second at speed, slow heavy chuffs pulling out of a station.
  - **Colour:** dark at the stack, growing and paling to grey.
  - **Trail:** drifting back over the cars, so flying the train's length goes
    through them.
  - **Steam:** white from the cylinders at stops.
  - **From far off:** the smoke is seen farther than the train's look (4 km),
    so the user can find a train from across the land.
  - **Solid:** no; the plane flies through smoke.
- **Longer, mixed train.** About 24 cars, about 550 m. A mixed train: freight,
  then two passenger coaches and the caboose.
- **More cars to fly through, kept realistic:** open-door boxcars, stock cars,
  log flats, a bridge truss on a flat, a wrecking crane, and the gap between
  the two coaches, as in the table. The smash car becomes a boxcar whose end
  walls burst into planks.
- **Riding.** The plane can land on a car (a flatcar's deck, a roof) and ride
  it:
  - **Sitting:** it sits there through curves, grades, station stops, the
    tunnel and the bridge, and the user looks round as when landed on the
    ground.
  - **Taking off:** throttle up and lift off with the train's speed.
- **Unchanged:** the line, the timetable's meetings (mid west tunnel and mid
  bay bridge, every lap), the 7 m gap between the trains, the 32 m/s speed,
  the flags and the quick starts.

## The cars (the contract between the lanes)

All numbers are at the default sizes (`--plane-scale=1`). Every car is 6 m
wide (`WIDE`), its floor 1.4 m over the bed (`FLOOR`), and 1.6 m from the next
(`GAP`), except where a row says otherwise. Nothing stands more than 9 m over
the bed: the bores are sized on that (`rail_bore_shape.gd`, `CAR_TALL`).
Openings are by `WorldScale.opening(toy)`, the toy widths named in the file
that owns them: `TOY_DOOR` 5 gives 10 m, `TOY_DOOR_HIGH` 3 gives 6 m and the
thread 3.5 gives 7 m.

| # | Kind (id) | Length | Top over bed | What it is | Flown |
|---|---|---|---|---|---|
| 1 | `engine` | 22 | 8.5 (stack) | the 4-4-0 | weave round; land on? no |
| 2 | `tender` | 12 | 6.0 | coal heap | dip over |
| 3 | `box` | 24 | 9.0 | boxcar, doors shut | pop over, land on the roof |
| 4 | `logs` | 20 | 6.5 | logs chained in two bundles | the gap between bundles: 7 m along the car, open above, to slot across |
| 5 | `doors` | 24 | 9.0 | boxcar, both side doors open | the doorway 10 x 6, across (as now) |
| 6 | `open` | 20 | 4.2 (+0.8 heap) | coal gondola | dip into |
| 7 | `stock` | 24 | 9.0 | slatted cattle car, side doors open | the doorway 10 x 6, across, the slats flicking by (not flyable between slats) |
| 8 | `flat` | 20 | 2.6 | flatcar, bare | dip, land on |
| 9 | `box` | 24 | 9.0 | | |
| 10 | `truss` | 24 | 8.5 | a bridge truss section on a flat | one web panel either side an opening 10 x 6, across |
| 11 | `flat` | 20 | 2.6 | | |
| 12 | `doors` | 24 | 9.0 | | |
| 13 | `crane` | 20 | 9.0 | wrecking crane, its boom slung forward over the next car | |
| 14 | `flat` | 20 | 2.6 | the crane's idler, under the boom | under the boom, over the deck: at least 6 m clear, across |
| 15 | `stock` | 24 | 9.0 | | |
| 16 | `logs` | 20 | 6.5 | | |
| 17 | `box` | 24 | 9.0 | | |
| 18 | `flat` | 20 | 2.6 | | a pair of lows, a dip that works on Boost |
| 19 | `flat` | 20 | 2.6 | | |
| 20 | `smash` | 24 | 9.0 | boxcar, end walls burst into planks | surge roll in over the flat behind, out over the two ahead (as now) |
| 21 | `flat` | 20 | 2.6 | | |
| 22 | `coach` | 24 | 8.5 | passenger coach, open end platforms | land on the roof |
| 23 | `coach` | 24 | 8.5 | | the gap between the two coaches: between their end walls, over the railings, under the roof hoods, an opening 10 x 6, across |
| 24 | `van` | 14 | 7.5 | caboose with cupola | land on the roof |

- **The contract is the kinds, sizes and openings.** The order is the cars
  lane's to tune for the rhythm, keeping each special car reachable and the
  smash car's lows. A size or opening that must change is a spec change, made
  in both lanes (tell the runner in your Notes).
- **Each model's frame** is the car's frame in `rail_train.gd`: origin at the
  car's middle on the bed, forward -Z in Godot (Blender +Y), up +Y, 1 unit =
  1 m.
- **Moving parts are their own nodes,** so code can drive them: the engine's
  drivers, leading wheels, side and main rods; every car's bogies and wheels;
  the doors (open); the smash car's two end walls, each a plug of plank shards
  in the pirate ship's manner; the stack's mouth as an empty node, where the
  smoke starts; the cylinders' steam points.
- **Openings at other plane scales.** Models are built at the defaults. At
  another `--plane-scale` the colliders follow `WorldScale` but the models
  don't. That's accepted for the prototype; say it in the handoff.

## Done (what the user plays and sees)

- `./run-endless-flight.command` (seed 1): two classic steam trains run the
  line, 24 cars each, as models. Their drivers turn and their rods work, and
  coal smoke puffs from the stack. Every collider matches its model, so what
  you see is what you hit.
- **Flying them:** the user flies the length and through each fly-through car
  (doors, stock, logs, truss, crane, the coaches' gap, the smash car's
  planks). Each opening scores near misses and collides like the doors car now.
- **Meetings:** at both meetings the two 550 m trains pass in the 7 m gap.
- **Riding:** the plane lands on a car and rides it the whole way round
  (stops, curves, grades, the tunnel, the bridge) with no slide, jitter or
  knock-off. It clears every bore and span while riding the tallest roof, and
  the user can look round while sitting. Throttle lifts it off at the train's
  speed.
- **Quick starts** (each with `--no-title`): the existing three still work,
  plus `--rail-start=ride`, sitting on a flatcar leaving a station.
- **Smoke from afar:** smoke is seen from across the land.
- **Cost:** a headless frame log along the line through a meeting, compared
  with the 12-car greybox. A frame log of a flight the user flies is offered at
  the end (GPU).
- **The handoff** lists the model-budget tricks that apply, with estimated
  triangle and frame savings.

## Lanes and trunk

The lanes don't need each other and run at once, each as its own short loop in
its own worktree, branched from `iter/steam-train`. Keep new code in new files.
Edits to shared files (`rail_train.gd`, `rail_trains.gd`,
`studies/endless_flight.gd`, the plane's landing) stay small and additive and
are listed in each commit's **Notes for merge**. Lane commits are
`ITER(steam-train): lane <name>: <task>`. A lane is done when its list below is
done: end with `<promise>COMPLETE</promise>`.

### Lane `model` (worktree `../zenscape-train-model`, branch `lane/train-model`)

The models in Blender, by script, in `art/blender/train/`, into
`assets/models/train/`. No game code beyond what shows them for stills.
1. **The engine and the tender first, rough,** with stills in the game's own
   light (a small yard study the lane adds, e.g. `studies/train_yard.tscn`,
   the models on a straight track) and a Blender render. Keep this one task
   short: the user judges the look before the rest is built.
2. The boxcar, doors car, stock car, flat, gondola and caboose: one shared set
   of trucks and wheels, one shared set of materials.
3. The special cars: logs, truss, crane, coaches, the smash car's plank walls.
   The build script reads each glb back and proves every opening in the table
   clear (exit 1 if not).
4. LODs, visibility ranges, the moving parts as nodes, and the model-budget
   assessment. Stills of the whole train in the yard.

### Lane `cars` (worktree `../zenscape-train-cars`, branch `lane/train-cars`)

The longer train and the new cars in greybox, flown. No models.
1. **The 24-car table** in `rail_train.gd` (`CARS`), the new kinds' solids and
   openings sized as the table says (toy widths named), near misses and the
   keep-out on each. Fly every opening through the real play loop.
2. **The meetings and quick starts at the new length.** The two trains still
   pass mid west tunnel and mid bay bridge, and the quick starts still land
   the plane where they say. Platforms are made as long as the train where the
   ground allows (`rail_stops.gd` `PLATFORM_HALF`, the tool's `PLATFORM`);
   where a stop can't take it, say so.
3. **Cost:** a headless frame-log A/B along the line through a meeting, 24 cars
   against the 12-car greybox. If near-miss scoring or the keep-out spikes
   worse, make it cheaper (only the cars near the plane asked) before moving
   on.

### Lane `ride` (worktree `../zenscape-train-ride`, branch `lane/train-ride`)

Landing on a car and riding it, built on the current 12-car greybox, so it
works for any car with a top. Keep the code in a new file (e.g.
`scripts/endless/rail_ride.gd`), with small hooks in the plane's landing and
the trains.
1. **Landing on a moving car:**
   - The touchdown is judged by the speed relative to the car.
   - Once down, the plane is carried in the car's frame: it turns with it on
     curves and holds through grades and the stops' slowing and pulling out,
     with no slide and no jitter.
   - Landing elsewhere is unchanged.
   - Prove it on the test oval (`--train-test`) through the real play loop.
2. **Sitting and looking round:** the camera rides with the car, and the user
   looks round as when landed on the ground. Takeoff: throttle lifts off with
   the car's speed.
3. **On the line:**
   - Ride a whole lap's worth of the hard parts (the tunnel meeting, the
     trestle, the bridge meeting, a station stop) on the tallest roof and on a
     flat.
   - It clears every bore and span; where something doesn't clear, raise it
     and say so.
   - No near-miss scoring while sitting.
   - The quick start `--rail-start=ride`.

### The trunk (in `iter/steam-train`, after the lanes merge)

1. Merge the lanes, join the shared lines, smoke check (done by the loop's
   runner, not an iteration).
2. **The models on the 24-car trains,** in place of the greybox looks. The
   drivers turn and the rods work with the train's speed. The smash car's
   plank walls burst and reseal. Colliders still match the models.
3. **The smoke:** stack puffs, cylinder steam at stops, the far plume, and the
   rhythm with speed and leaving stations. Stills and a short rendered clip.
4. **The whole thing flown:** both meetings, every fly-through car and a ride.
   Then the cost log against the greybox, the stills and the handoff.

## Checks

- **Smoke:** `studies/endless_flight.tscn` plain, with `--train-test`, with
  `--no-railroad` and with each quick start, plus any study a lane adds.
- **Through the real play loop** (`tools/drive.py`): every played thing (the
  openings, the meetings, landing and riding). Leave the drivers uncommitted
  in `scratch/`.
- **Stills** (`tools/shot.py`, with `-- --no-title`) of everything seen. Open
  them and look; fix what reads wrong and shoot again.
- **Land hash:** `tools/land_hash.py` seed 1 with `--no-railroad` still matches
  main (`9ceaddb3…fcb3c4e8`).
- **Tests:** no new committed tests and no full suite (prototype, AGENTS.md).

## Working rules

- Never `git stash` or `git stash pop`: the stash list is shared by every
  worktree and holds the user's work. To compare with an older commit use
  `git show <rev>:<path>` or a throwaway `git worktree add`.
- Drivers and test runs never write the user's saves: pass
  `--pilot-file=/tmp/<name>.json` and keep layouts in /tmp.
- Python with Pillow and numpy (the Mac's `python3` lacks them):
  `/Users/davidkalina/Documents/Projects/zenscape-godot/scratch/.venv/bin/python`.
- Frame times taken while other lanes run share the machine and are noise.
  Repeat an A/B before believing it, and say it was taken in parallel.
- Cap and budget: the skill's default.
