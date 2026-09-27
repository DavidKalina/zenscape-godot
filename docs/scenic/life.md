# Life answers the land

Phase 3, slice 3 (`feature/life-answers`). Fish, frogspawn, frogs, birds and fireflies find their places in the world as it stands now, and arrive in their own time. Herons, deer, a grass snake, a rainbow and, very rarely, a glimpse of Bigfoot come when a place has become rich. Nothing is placed by the player.

- `scripts/land_life.gd`: the scheduler and the everyday creatures.
- `scripts/life_survey.gd`: what the land offers, read from the live world.
- `scripts/life_moments.gd`: the rare moments.
- `scripts/life_models.gd`: low-poly procedural meshes for the fish, frogspawn, heron, deer and the Bigfoot silhouette.
- `scripts/life_snakes.gd`: the grass snake, built and moved in code.
- `tools/probe_land_life.gd`: the headless probe.
- `tools/probe_snake.gd` and `tools/render_snake_probe.py`: the snake's headless probe and a Blender renderer for what it dumps.

`studies/fidelity_life.gd` builds `LandLife` after the fish and dead wood. It runs only on blank worlds: the Genesis plain and generated worlds. The Fidelity reference world keeps its authored birds, frogs and fireflies. `--no-life` turns the whole system off, for A/B timing.

## When the world is read

The editor reports change and LandLife re-reads the world. Nothing scans the world every frame.

- **Signals:** `play_geometry_changed` (every settle refresh, including emergence steps), `stroke_finished`, and `state_restored` (undo, load, new world).
- **Timing:** a survey starts once the editor is idle (not painting, no refresh pending, not forming) and has been quiet for `SURVEY_QUIET` (0.6 s). A finished stroke, an undo or a new world is urgent. Plain geometry changes, such as emergence stepping every 0.75 s, re-read at most every `SURVEY_GAP` (4 s).
- **Slicing:** a survey runs in slices of `SURVEY_BUDGET_USEC` (1.2 ms) a frame. The stages are: object buckets, heights row by row, pond triangles 64 at a time, stream beds one route at a time, slopes row by row, water bodies, water distance, then places row by row. A survey that is running finishes before the next one starts.
- **Planning:** a finished survey is planned one creature kind per frame.

### What a survey sees

The grid is 56×56 at 0.5 m, aligned with the terrain's cover cells.

- **Ground:** live heights (`data.ground_height`).
- **Still water:** the pond triangles the view drew (`GardenView.pond_vertices`). Each triangle's water stands at its vertices' height. This is free, and it matches what is on screen. Water from the water brush lands there as long as that branch draws its water through the pond mesh.
- **Flowing water:** stream beds from `data.streams`, marked as water 6 cm deep.
- **Plants:** trees and shrubs from `data.objects`, of every provenance, bucketed on a 1 m grid.

From these it derives:

| Place | Rule |
|---|---|
| Water body | 4-connected still water; at least `MIN_BODY_AREA` (1.5 m²) to count as a pond |
| Deep | inner cells of a body at least `DEEP` (0.22 m) deep |
| Shallow edge | body cells beside land, 0.02-0.2 m deep |
| Wading | body cells 0.05-0.32 m deep |
| Bank | dry cells beside a body, slope under 0.9 |
| Forest edge | open ground with grass cover ≥ 0.2, slope under 0.4, no tree in its own metre, a tree in the next metre, and at least 3 trees within 3 m, mostly to one side. `into` points into the trees. |
| Damp | dry ground within 3 m of water with grass ≥ 0.35, a shrub or trees near |
| Richness | water area /12 (≤1.5) + stream cells /30 (≤0.6) + trees /12 (≤1.5) + shrubs /30 (≤0.8) |

## Arrivals: conditions plus a delay

Each kind keeps sites keyed by survey cell. This works like emergence's candidates:

- **Choosing sites:** up to a capacity per water body. Sites that already stand keep their place while they still qualify. New ones are taken in position-hash order (`salt` is emergence's world salt) with a minimum gap. The same strokes on the same world bring the same life.
- **Arrival:** a site is born when its conditions first hold. Its creature arrives after `delay + spread × hash` seconds of the life clock.
- **Departure:** a site whose conditions go away sends its creature off. Fish sink and fade, frogspawn shrinks, frogs hop away up the bank, birds fly off into the distance, and fireflies dim. A site that has not arrived yet simply closes.
- **Settled worlds:** a new, regrown or loaded world starts settled. Its first sites start `SETTLED_HEAD` (85%) of the way through their delay, so a generated world comes alive within a few seconds. An undo keeps whatever still fits, and new sites wait their full delay.
- **The clock:** the life clock is real seconds and stops while the scene is paused or the world is regrowing. `pace` multiplies it for probes.

| Kind | Needs | Delay + spread (s) | How many |
|---|---|---|---|
| Fish | deep cells of a pond | 10 + 16 | one per 2 m², at most 7 a pond and 24 in all |
| Frogspawn | shallow still edges, not in winter (`SPAWN_SEASON` 1, 0.7, 0.3, 0) | 22 + 26 | 1 + area/10, at most 3 a pond and 9 in all |
| Frogs | a bank of water that already holds frogspawn | 16 + 22, counted from the spawn's arrival | 2 a pond, 6 in all |
| Birds | shores and woods | 6 + 24 | one per 14 bank cells + one per 10 trees + one for a stream, at most 8 |
| Fireflies | damp undergrowth | 12 + 22 | up to 64, 0.7 m apart |

What each creature looks like and does:

- **Fish:** low-poly koi (orange, gold, silver, cream) circle their home and never swim out of wet cells. Now and then one rises and leaves a ring, more often in low light.
- **Frogspawn:** clumps of pale beads with dark eggs, floating flat at the water level and following the level if it changes.
- **Frogs:** the Fidelity frog mesh and its pond loop. They sit on the bank, leap into the nearest water, paddle and hop back.
- **Birds:** the Fidelity gulls with their thermal flight model (`studies/bird_flight.gd`). They fly in from beyond the plate over three thermals, which rise above the two biggest waters and the highest ground.
- **Fireflies:** the scene's own 90 fireflies. On a blank world every one starts absent. `INSTANCE_CUSTOM.w` in `reference_fireflies.gdshader` is now absence, and each firefly fades in at its place. They glow at dusk as before. Leaving a blank world restores the Fidelity positions.

## Moments

Checked every `CHECK` (2 s) of life time. Each moment has its conditions, a delay after those first hold, a chance per check and a cooldown, so it stays rare. Every moment is logged in `moments.history` and emitted as `LandLife.moment(kind, position)`, which is ready for sound (slice 6).

| Moment | Conditions | Chance per check | Cooldown (s) |
|---|---|---|---|
| Heron lands | a pond with ≥ 2 fish settled for 30 s and wading water; daylight > 0.25; rain < 0.3 | 0.06 | 240 |
| Deer at dawn | ≥ 6 trees; a forest edge that has stood 25 s; celestial phase 0.2-0.36; rain < 0.3 | 0.25 | 300 |
| Rainbow after rain | ≥ 8 s of rain above 0.25 that then stops (< 0.06); richness ≥ 1.2; daylight > 0.35 | 0.6 once per rain | none |
| Bigfoot glimpse | scenery mode and Bigfoot not resident; ≥ 14 trees; richness ≥ 2; dawn (phase 0.2-0.36) or dusk (phase 0.64-0.8); an edge with ≥ 8 trees near, at least 18 m from the camera, seen from the open side | 0.006 | 1200 |

What each moment looks like:

- **Heron:** glides in from off the plate along a curve over 7 s with slow wingbeats, legs trailing, then brakes and lands with a ring. It stands in the shallows 45-90 s, and its neck strikes at the water every 7-14 s. It flies off early if rain comes or the water goes.
- **Deer:** a doe, and half the time a fawn, step out of the trees to the edge at 0.42 m/s. They graze, head down for 5-11 s and up for 2-4 s, for 25-45 s, and leave when their time is up or the sun climbs. They walk back into the wood and fade inside the trees.
- **Rainbow:** `celestial.moment_bow`, a new term in `studies/celestial.gd` next to `rainbow_strength` and `weather_bow`, rises to 0.85 over 6 s, holds 30 s and fades over 10 s. It is never saved.
- **Bigfoot:** a dark procedural silhouette about 2.1 m tall stands just inside the trees for 5 s, turns and walks back into the wood, and is gone about 9 s after it appeared. It uses no model or rig, only faceted spindles in one colour. The resident Bigfoot is untouched.

`moments.force(kind)` starts one now for probes. It skips the delay, chance and hour, but not the place it needs.

## The grass snake

`scripts/life_snakes.gd`, owned and advanced by LandLife like the moments. `LandLife.force("snake")` (or `snakes.force(options)`) summons one for probes.

### When

Checked every `CHECK` (2 s) of life time, at most one snake at a time.

| Needs | Delay | Chance per check | Cooldown (s) |
|---|---|---|---|
| a pond of ≥ `POND_AREA` (3 m²) with ≥ 8 bank cells and fish, frogspawn or frogs in it; celestial phase 0.24-0.52 (`MORNING`); daylight ≥ 0.5; rain < 0.1 | the pond has qualified for 40 s | 0.1 | 420 |

Rain above 0.4 or the pond draining sends it off early, swimming to the nearest bank first if it is in the water.

### A visit

1. **Out of cover.** It picks a flat spot 0.5-1.5 m up the bank with open ground all round to coil. For cover it takes the best spot 1.5-5 m away that it can reach in a straight line: trees or shrubs in the survey's coarse grid, else thick grass, else open ground away from the water. Its body starts laid out inside the cover with its head and neck out (`PEEK`, 25 cm). It pauses there with its head up, then comes to the bank in bursts.
2. **Coil and bask.** It spirals in to a loose coil, 1.6 turns from 0.2 m to 0.08 m radius, on the side away from the water. Failing that it tries the other side, then a slightly tighter coil, before it gives up and basks as it lies. It basks 16-28 s (`BASK`) with its head resting in the middle. Once or twice it wakes: the head comes up, looks about, tastes the air and settles again. Then it rouses, lifts its head and crawls out over its own coils.
3. **Hunt.** 3-5 stops (`HUNT`) round the pond in one direction, each 0.6-1.8 m ahead of it on the bank. At each it holds 1.8-3.4 s with its head up and turned toward the water.
4. **Swim, half the time** (`SWIM_CHANCE`). From the nearest bank cell it looks at the water, slides in and swims to the far water's edge, crossing at least 1.2 pond radii of open water. Its head is held up and steady while the body undulates on the surface. A ring spreads from its head every 0.42 s, and it pauses once midway, floating with its head up. It hauls out and pauses.
5. **Leave.** It goes to cover in bursts and slips in. Rings shrink to nothing as they pass the cover's edge, head first, so it vanishes into the cover the way the deer melt back into the trees. It never slips away on open water: from the water it makes for the bank first.

A visit takes 95-125 s with an 8 s bask. With the usual 16-28 s bask it is about two minutes.

### Body and motion

- **Mesh.** A faceted hexagonal tube with a flat belly: 26 rings, a head and a forked tongue, 28 bones, 354 triangles. Every vertex belongs to one bone, so rings stay rigid and the faces between them stretch; skinning runs on the GPU. It is drawn with the frogs' `reference_surface` material and per-face vertex colours: an olive back, darker bars and spots on half-faces, a pale belly, the yellow collar patches with a black crescent behind them, and small dark eyes. It is 1.2 m long and 5.6 cm across (`LENGTH`, `RADIUS`): a big female, slightly larger than the usual metre so it reads from further off.
- **The path.** The head follows a way worked out ahead of time, with points `STEP` (2 cm) apart measured along the ground rather than across it, so the body keeps its length on slopes. Every ring sits on that path at its own distance behind the snout, so the serpentine comes from the head weaving (`WEAVE`, `WAVE`) and nothing slides sideways. The way turns toward its goal at `TURN` rad/m and is smoothed. It looks ahead, never past the goal, to steer round water and ground steeper than `SLOPE_MAX`.
  - **Near a goal:** ahead of it, it steers harder and stops weaving, so it arrives. A goal behind it is swung round to wide, never in a hairpin.
  - **No progress:** a way that stops getting closer ends where it was closest.
  - **Water's edge:** on land it may turn through the shallows in its first half metre. Swims may slide over the steep band at the water's level. Leaving from the water, it may use the water for its first 1.5 m.
  - **Cost:** each way is worked out a slice at a time (`PLAN_BUDGET_USEC`, 0.4 ms a frame) during the hold before the move.
- **Contact.** Each path point reads the live ground height once, plus the level of any pond in or beside its cell. A ring's centre stands `BELLY` × radius above the ground (divided by the slope's cosine), or floats at the water's level, whichever is higher. It rolls with the sideways slope. After a new survey the points are re-read 12 a frame. Where the way crosses the body (leaving the coil), the upper part rides a smooth bump over whatever of the lower part is still underneath, and settles as the tail slides out from under it.
- **Travel and hold.** On land it moves in bursts of 0.35-0.9 m at up to 0.24 m/s (`CRUISE`), easing off over the last few centimetres, then holds for 0.9-2.2 s. In a hold the head rises 4.5-7 cm with a small overshoot. The neck bends up in an S whose rings keep their spacing. The head turns to look first, and the neck follows on a critically damped spring. Each look dips a little on the way (an arc, not a swivel) and then holds still while breath and drift continue. The rear third settles deeper into its curves with a small overshoot, and the tail's tip drifts.
- **Anticipation.** Before each move (the last 0.45 s of a hold), the head dips to the ground and turns home, the body draws back 12 mm along its path, and the rear straightens. As it sets off the draw-back springs out.
- **Tongue.** A 0.44 s flick with a fast flutter at stops and every 2-4.5 s on the move.
- **Swimming.** The head is held up (`SWIM_LIFT`) and its heading is smoothed, so the weave passes under a steady head.

### Measured

`tools/probe_snake.gd -- --visits=6`, headless, stepping each visit at exactly 30 fps, on 2026-09-26. There were six visits, all with the full programme (coil, bask, hunt, swim, leave): 10.1 minutes of snake time.

- **Cost per step:** median 27 µs, p95 38 µs, p99 43 µs, worst 0.87 ms (a slice of planning). Arriving costs 0.8-1.5 ms once. While no snake is out, only the condition check runs, every 2 s.
- **Contact:**
  - A flat belly sits a median 0.2 mm from the ground (p95 1.0 mm, p99 2.4 mm).
  - The belly's edges stand 1.3 mm off at p95 and sink at most 4 mm.
  - Floating rings sit at the water's level to within 0.1 mm.
  - Over its own coils, the upper body rests within 8 mm of the lower.
- **Spacing:** along the body, rings stay at 0.87-1.14 of their spacing (p99 1.06). On the lifted neck the p99 is 1.07.
- **Motion:**
  - The head travels at a median 0.23 m/s, p99 0.35 m/s.
  - Sideways slip of the body rings is p99 2 cm/s.
  - Body acceleration is p99 1.2 m/s², at most 4.1 m/s².
  - The head peaks higher, 6-9.6 m/s², on its quick rises and dips at the start and end of each hold.
- **LandLife with the snake hooked in** (`probe_land_life.gd -- --pace=6 --watch=15`): median 0.08 ms, p95 0.15 ms per frame. Every other creature and moment still comes.

## Models

`life_models.gd` builds everything from faceted spindles (a bipyramid over a 4-7 sided ring) and flat fans, with vertex colours and a slight per-face shade. It uses the Fidelity frog's own `reference_surface` material (flat faces, scene palette), so the models sit in the painted look and share a pipeline that is already compiled.

| Model | Triangles |
|---|---|
| Fish | 12 + 2 fins |
| Frogspawn clump | 22 icosahedra |
| Heron | 5 parts, the wings shown only in flight |
| Deer | 7 parts: body, neck and head, 4 legs |
| Glimpse | 1 mesh |

Fish, frogspawn, frogs and rings are MultiMeshes with fixed slots. The heron, the two deer and the glimpse are built once at setup and hidden.

## Cost

Measured headless, CPU only, on 2026-09-26:

- **`tools/probe_land_life.gd -- --pace=6 --watch=20`:** a plain with a dug pond and 14 trees.
  - LandLife per frame: median 0.07 ms, p95 0.11 ms, max 1.7 ms (a survey slice).
  - A survey is about 21 ms of work in total, spread over about 20 frames. The worst single step is 1.5 ms.
  - The only frame over 16.7 ms is the editor's own synchronous undo refresh (about 50 ms, LandLife 0.1 ms in it).
- **Generated worlds** (`--world-seed=198` marsh, `--world-seed=79` glacial valley):
  - LandLife p95 0.22 ms per frame.
  - A survey is 17-25 ms in total, worst step 1.7-2.9 ms.
  - All frames under 12 ms.
  - Everything settled arrives within about 5-11 s of the world appearing.
- **`tools/profile_stroke.gd -- --mode=land --watch=60`, with and without `--no-life`:** the same shape.
  - Stroke frames p95 10.3 / 10.8 ms, settle p95 9.0 / 9.4 ms.
  - The one slow settle frame is emergence's first plan (22-31 ms) either way.

## Probe

```
godot --headless --path . -s res://tools/probe_land_life.gd -- --pace=6 --watch=20
godot --headless --path . -s res://tools/probe_land_life.gd -- --pace=1 --watch=12 --world-seed=198
godot --headless --path . -s res://tools/probe_snake.gd -- --dump=/tmp/zs-snake-previews/frames
blender -b --python tools/render_snake_probe.py -- --view=close --video --every=2 --name=visit
```

The first command digs a pond on the plain and stands a small wood beside it. It prints a per-second timeline of what is present, the survey, arrivals and moments, then forces each moment. Last, it drains the pond (the water life leaves) and undoes the drain (it comes back after its delays). The second regrows a generated world and watches it come alive.

The snake probe digs the same pond, with shrubs on its west bank, and waits for fish. It then summons a snake and steps it at exactly 30 fps through a whole visit. It prints the timeline, the cost per step, ground and water contact, ring spacing, head speed, sideways slip, per-frame acceleration and the planning journal. Last it runs the life clock fast and waits for a snake to come by itself. `--dump` writes the mesh, the ground, the pond, the plants and every frame's bone poses and ripples. The Blender script poses the same mesh on the CPU from those and renders it as contact sheets or video, following the snake (`close`), from the game's default camera 43 m off at the game's pixel density (`far`, add `--mirror` for the other side), or from above (`top`).

## Tunables

All of these are constants at the top of `land_life.gd`, `life_moments.gd` and `life_snakes.gd`:

- `DELAYS`, `SETTLED_HEAD` and the per-kind caps and gaps.
- `SURVEY_BUDGET_USEC`, `SURVEY_QUIET` and `SURVEY_GAP`.
- Each moment's `*_DELAY`, `*_CHANCE`, `*_COOLDOWN` and `*_STAY`, and the `DAWN` and `DUSK` phase windows.
- The snake's `SNAKE_*`, `MORNING`, `BASK`, `HUNT` and `SWIM_CHANCE`; its size (`LENGTH`, `RADIUS`); and its motion (`CRUISE`, `SWIM`, `WEAVE`, `WAVE`, `LIFT`, `RECOIL`, `ANTICIPATION`).

The survey's thresholds are at the top of `life_survey.gd`: `DEEP`, `SHALLOW_*`, `WADE_MAX`, `MIN_BODY_AREA`, `FOREST_*` and `DAMP_REACH`.

## Open

- Everything visual is unverified: the models, the palette they take, and how the heron's and deer's motion read on screen. Headless runs do not draw. The snake has been seen only in Blender renders of the probe's dump, not through the game's shader and palette.
- At the default overview (43 m) the snake is a line one or two pixels wide. Only its motion and wake show from there; it is for looking at up close.
- The snake's cover is where it vanishes, not something it hides under: a painted-grass world has no blades for it to slip between.
- Fish live in ponds only, not streams.
- Life is not saved. A loaded world starts settled instead.
- Deer need the dawn window. The plain's clock is frozen at its launch hour, so a plain launched at full day never sees deer until the day turns.
- Sound hooks: `LandLife.arrived` and `LandLife.moment` are emitted but nothing listens yet.
- `fidelity_fish.gd`, Bigfoot's catchable fish, still seeds from the Fidelity water once at startup. It is separate from these ambient fish and only matters with `--bigfoot`.
