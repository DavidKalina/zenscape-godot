# Spec: the railroad (loop `railroad`, trail prefix `ITER(railroad):`)

The wilderness is becoming a western in the mountains (decided 2026-11-05):
farmland, old western towns, and an old-school steam train circling the Peak,
alongside the pirate ships. The train is the headline: bob and weave along its
cars, fly through a car, smash a car, go through the tunnel with it, thread
between two trains.

This loop builds it **in greybox**: the line laid into seed 1's land along the
drafted route, a train of boxes that runs it, and a second train. No models,
no town buildings beyond blocks, no sound, no smoke. Those come in later
rounds once the user has flown this.

## Read first

- The route draft: `docs/design/endless-flight/railroad/`
  - `route-draft.png`: the loop on the seed 1 map, its seven places labelled.
  - `route-waypoints.json`: the stops and vias the draft was planned through.
  - `route-line.json`: the drafted line, a point every 10 m in world XZ (`pts`),
    its bed height (`bed`, world y) and each point's kind (`kinds`: grade,
    cut, fill, tunnel, trestle, bridge). It starts at the start station and runs
    north, then anticlockwise as the map shows it (x right, z down): station,
    north-east shore, farm plain, west tunnel, mine town, cattle plain, bay
    bridge, station.
  - `route_planner.py`: the throwaway planner that drew it (least-cost path over
    `tools/site_map.py`'s height JSON, Chaikin and moving-average easing,
    graded to 3.5%). It was planned on a 25 m height grid, so it misses
    small gorges and river cuts.
- `scripts/endless/pirate_ship.gd`: the closest thing in the game to a train.
  Its solid is records in LandArches `loose`, rewritten each frame, plus a
  StaticBody on layer 1 for the wing rays. It gets away with this because it
  moves about 0.15 m a frame, inside the pad its solids are grown by. Its
  break-a-plate, fly-the-length, reseal-behind-you loop (SurgeSmash) is the
  template for the smash car.
- `scripts/endless/near_miss.gd`: how near misses score. Speed counts as the
  plane's own speed over cruise.
- `scripts/endless/land_tunnels.gd`, `scripts/endless/tunnel_sites.gd`: the
  mountain tunnels' bores through the heightfield (portals, `ground`/`inside`).
- `scripts/endless/land_field.gd`: the land's height. It runs natively
  (`native/terrain_kernels/land_field.h`) and in GDScript, which must agree.
  See `native/terrain_kernels/README.md` for building the kernels.
- `scripts/world_scale.gd` (openings), `scripts/layout_overrides.gd` (handles),
  `scripts/world_clock.gd` (the clock), `scripts/endless/surge_smash.gd`.

## The route (drafted 2026-11-05, accepted by the user)

An 18.5 km loop round the Peak, about 10 minutes a lap at 30 m/s. In order:

| # | Place | Where (x, z) | What |
|---|---|---|---|
| 1 | Start station | (1350, 350) | just east of the start's meadows; the train is seen in the first minute |
| 2 | North-east shore | ~(1500, -500) to (600, -1700) | short trestles past the sea stacks |
| 3 | Farm town, farm plain | (-2500, -3300) | ~5 km of near-straight over the flat plain north of the Peak |
| 4 | West tunnel | ~(-4707, -857) | ~1.2 km through the Peak's west tail, ~180 m of rock over it |
| 5 | Mine town | (-4500, 700) | the line leaves the tunnel onto an ~800 m trestle ~55 m over the valley; the town below it |
| 6 | Cattle town, cattle plain | (-2500, 2300) | the second long run, south of the Peak |
| 7 | Bay bridge | ~(148, 836) | ~1 km across the bay, ~40 m up, in sight of the start |

Refine the draft at the land's real resolution: keep the same places in the same
order, and draw your own exact curve. Rails want at most about 3.5% grade and
curves of about 150 m radius or more; the draft's tightest curve is 143 m. Keep the
line off the start's meadows (first-cairn, east-room, meadow-dash).

Finds near the line stay where they are: bay-ring (under the bridge: keep it,
a ring to thread under the bridge), sea-arch-ring, stack-top, saddle-ring. If
the line truly hits one, say so in the commit; don't move a find silently.

## Decided with the user

- **Greybox first.** Cars are boxes, towns and stations are blocks, trestles and
  the bridge are plain beams and spans. All are flyable and collide.
- **Double track** the whole way, for two trains. The two tracks sit far enough
  apart that the plane can thread between two trains side by side: the gap
  between the trains' sides is an opening, sized with
  `WorldScale.opening(<toy width>)` (pick and name the toy width, AGENTS.md
  Sizes). **Settled 2026-11-05 (the lanes picked 3.5 and 5.0):** the gap is
  `WorldScale.opening(3.5)`, the game's usual thread (7 m at the defaults), so
  with 6 m cars the tracks sit 13 m apart, centre to centre. The rail path owns
  it (`rail_line.gd`, `TOY_BETWEEN := 3.5`, `track_gap()`); trains read their
  track's centre from `pose` and hold no spacing of their own. A knob,
  `--track-gap-toy=`, lets the user try it wider.
- **Speed.** The train runs a bit under cruise, default about 32 m/s (cruise is
  36.75). At cruise you creep up its length a car at a time, so the weave
  happens without braking; Boost runs you up to the engine. That keeps the
  escorts rule (things beside the plane hold at cruise; the user won't brake to
  stay with them). A knob: `--train-speed=`.
- **The cars.** Alternate tall cars (boxcars) and low ones (flatcars, open
  wagons), so flying the length is a rhythm: dip over a low car, pop over a
  tall one. One boxcar with both doors open to fly through, its doorway an
  opening by `WorldScale.opening`. One car to smash with a surge roll, in the
  pirate ship's manner. The train is oversized next to a real one; the
  openings set its size.
- **Two trains**, running opposite ways. Station stops time them so they always
  pass each other in two places: in the west tunnel (head-on in the dark) and on
  the bay bridge (thread between them).
- **The clock.** A train's place on the line is a pure function of the world
  clock (and its timetable), so it holds no state and is the same on every
  machine (co-op later). It is built only near the plane.
- **No people.** No figures anywhere: the towns are kept up with nobody about,
  and the cabs are empty.
- **Meadows and flats** (AGENTS.md): the line and towns sit on the two big
  plains; a landing flat must stay in reach everywhere along the line.

## Done (what the user plays and sees)

- `./run-endless-flight.command` (seed 1): the line is in the land. A double
  track on a graded bed, with cuts and banks, the west tunnel, trestles, the bay
  bridge, and block stations and towns at the five places. Rails, trestles,
  bridge and tunnel collide and score near misses like any arch or bore.
- Two box trains run the loop in opposite directions on the world clock and
  pass each other in the tunnel and on the bridge.
- Flying the train feels right at speed:
  - collisions hold, with no passing through a car, no jitter, and the plane
    is neither carried nor flung;
  - near misses score by the speed relative to the train;
  - the fly-through boxcar and the smash car work;
  - the camera doesn't clip into cars.
- Quick starts so the user can try things in seconds (each with `--no-title`):
  one beside a train with the train coming, one at the tunnel's mouth just
  before the two trains meet, one at the bridge. Name them in the handoff.
- Flags: `--no-railroad` (all of it off: seed 1's land hash, `tools/land_hash.py`,
  matches main), `--trains=0|1|2`, `--train-speed=`.
- Cost: a frame log of a driven run along the line, compared with main
  (`tools/frame_report.py`). Far trains and far line cost next to nothing.
- A flats scan along the line shows a landing flat still in reach.

## Lanes and trunk

The lanes don't need each other and run at once, each as its own short loop in
its own worktree, branched from `iter/railroad`. Keep new code in new files;
edits to shared files (the study's setup, flag lists, LandArches tables) stay
small and additive and are listed in each commit's **Notes for merge**. Lane
commits are `ITER(railroad): lane <name>: <task>`.

**The contract between them: a rail path.** The line lane owns the real path;
the train lane builds against a test path of the same shape. A path script
offers at least:
- `length() -> float` (m, one lap);
- `pose(s: float, track: int) -> Transform3D`: the centre of track 0 or 1 at
  distance `s` along the loop (wrapping), with the basis's -z along the travel
  direction for track 0 and y up off the bed;
- `kind(s) -> String`: grade, cut, fill, tunnel, trestle or bridge.

If a lane needs more, add it to both sides and say so in Notes for merge.

### Lane `line` (worktree `../zenscape-rail-line`, branch `lane/rail-line`)

Everything in the land, no train. Suggested order:
1. The route as data: refine the draft at full resolution into the rail path
   (above), with stable handles `rail/<piece>` for stations, towns, the tunnel,
   trestles and the bridge (AGENTS.md Handles). Draw it on a site map.
2. The bed in the land: cut and banked into the heightfield along the path,
   in both the native and the GDScript field, the kernels rebuilt. Lay plain
   rails on it. Fly it. `--no-railroad` leaves the land exactly as main.
3. The west tunnel: a double-track bore in the tunnels' manner.
4. Trestles and the bay bridge as greybox pieces (colliders on layer 1, near
   misses like arches).
5. Station and town blocks at the five places; the flats scan; stills.

### Lane `train` (worktree `../zenscape-rail-train`, branch `lane/rail-train`)

A box train on a test path, independent of the line: a flag-started test
loop on flat ground (e.g. `--train-test`) or a study. Suggested order:
1. A train on a test loop, with moving solids that hold up at speed: the
   pirate ship's pattern, plus whatever has to change once a body moves several
   times the pad each frame. The plane collides right.
2. Near misses relative to the train's motion.
3. The car rhythm, the fly-through boxcar and the smash car.
4. A speed knob and a feel pass, flown through the real play loop.
5. The train as a module: given any rail path and a clock, it runs; built only
   near the plane.

### The trunk (in `iter/railroad`, after both lanes merge)

1. Merge both lanes, join the shared lines, smoke check (done by the loop's
   runner, not an iteration).
2. The train on the line, on the world clock, built only near the plane.
3. The second train and the timetable: they pass in the tunnel and on the
   bridge.
4. The quick starts, frame log, flats scan and stills; the handoff.

## Checks

- Smoke: `studies/endless_flight.tscn`, and any study a lane adds.
- Through the real play loop (`tools/drive.py`): fly the line and fly the
  train, leaving the drivers uncommitted in `scratch/`.
- Stills (`tools/shot.py`) of what changed; open and look at them.
- `tools/land_hash.py` seed 1 with `--no-railroad` matches main.
- No new committed tests and no full suite (prototype, AGENTS.md).

## Working rules

- Never `git stash` or `git stash pop`: the stash list is shared by every
  worktree and holds the user's work. To compare with an older commit use
  `git show <rev>:<path>` or a throwaway `git worktree add`.
- Drivers and test runs never write the user's saves: pass
  `--pilot-file=/tmp/<name>.json` and keep layouts in /tmp.
- `tools/site_map.py` needs Pillow, which the Mac's `python3` lacks. Use
  `/Users/davidkalina/Documents/Projects/zenscape-godot/scratch/.venv/bin/python`.
- Cap and budget: the skill's default.
