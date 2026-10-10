# Hall eruption: handoff

Branch `study/hall-eruption`, from main (d4e68e82). Not merged, not pushed. Greybox study only. The game, the moments world and the aqueduct isle are untouched.

The ask: the Sundered hall should erupt out of the cloud sea in pieces, one by one, instead of appearing all at once. In the game loop it rises where a lodestone is seated and then stays. This round covers only the eruption, so you can judge how it feels to watch from the plane and from an orbit or hover camera.

## How to run it

```
./run-hall-eruption.command                      # orbit camera, it plays at once
./run-hall-eruption.command --watch=plane        # in the plane, 260 m out on the hall's way in
./run-hall-eruption.command --erupt-speed=1.3    # quicker
./run-hall-eruption.command --build-upfront=3.5 --build-cost=3.5   # a kit-slow build under it
```

It is also in the scene picker: Scenes, then Ruins, then "Hall eruption".

### Keys

| Key | Does |
|---|---|
| R | play it again (Shift+R builds it again too, so you can watch a fresh worker build) |
| Enter | every piece in place at once |
| C | camera: orbit, then free, then the plane |
| F | into the plane, or out of it (back to orbit) |
| [ / ] | slower / quicker (0.25x to 2x); \ back to 1x |
| O | orbit turns by itself, or holds still (a hover) |
| M | the moments (gold balls) and the line (white dots) on or off. They show once the hall has settled. |
| Orbit | drag with the left mouse; the wheel zooms |
| Free | hold the right mouse to look; W A S D, Q E down and up, Shift quick |
| Plane | the game's plane controls (shown on screen) |
| Esc | frees the mouse |

### Flags

| Flag | Does |
|---|---|
| `--watch=orbit\|free\|plane` | the camera to start in |
| `--wait` | don't play until R |
| `--loop=<s>` | play again this long after each settle |
| `--hall-y=<m>` | the entry's height over home (20; the moments world uses 8–30) |
| `--erupt-speed=<x>` | everything quicker (or slower under 1) |
| `--erupt-gaps=<x>` | scales only the gaps between pieces (0 sends each category up together) |
| `--erupt-path=arc\|straight` | arc (default): pieces rise beside the hall and come in over it. straight: everything comes straight up through the floor. |
| `--no-keels`, `--no-stones` | leave out the two additions (see below) |
| `--build-upfront=<s>`, `--build-cost=<s>` | slow the worker build down on purpose: a wait before the first piece, plus extra time spread over the pieces by weight |
| `--capture=<dir>` `[--capture-at=t,t,…] [--hover] [--orbit-yaw/dist/pitch=…]` | stills at those eruption times, then quit (opens a window) |

Headless:

```
godot --headless --path . -s tools/hall_eruption_list.gd [-- <eruption flags>]   # every piece and its timing
python3 tools/run_tests.py --tests 'test_hall_eruption.gd'
```

## What's built

- **`scripts/hall_eruption_plan.gd`** is plain data and safe on a worker. It plans the pieces and their timing.
  - **The hall** is the moments set piece the sky world stands, `moments_hall`: sundered_flow's greybox, two halves with the gap between them. Its solids are taken exactly as SkyMoments stands them (`Plan.local_solids(0)`, all 178), and each goes into exactly one piece.
  - **Classifying.** The bays are laid again (`FlightCourse._bay`, same order) only to tell, for each solid, its bay, its bay line and what it is.
  - **92 pieces**, rising in this order:

    | Category | Pieces | What |
    |---|---|---|
    | base | 2 | each half's floor plus a greybox rock keel |
    | piers | 41 | every column on its own |
    | walls | 10 | runs of 3 bays a side, arches and breaches included |
    | spans | 12 | per bay line: beam, tie and slit screen (the arches across the nave) |
    | roofs | 18 | per roofed bay, strips and architraves, left and right fragments |
    | stones | 9 | floating stones |

    Within a category the pieces go gate to apse.
  - **Timing.** `TIMING` holds per-category gap, rise, slot, settle, overshoot, dip, tilt, lift and margin. `CHURN_LEAD` and `CATEGORY_PAUSE` set the lead-in and the pauses.
  - **Supports.** A piece never lands before what it stands on: piers and walls wait for their half's base, spans for their piers and walls, roofs for their spans and walls. The plan delays a start rather than letting a piece arrive early.
- **`scripts/hall_eruption.gd`** is the node.
  - **Building.** It builds the pieces on a WorkerThreadPool task, one at a time, in the order they rise. It hands each over as soon as it is made, then plays and advances them.
  - **Motion** (`pose_at`, static and tested):
    - A piece starts with its top 6 m under the cloud top. It bursts up with an ease-out (power 2.6), so it is fastest as it breaks through.
    - The base and the stones rise straight to their place plus an overshoot (1.8 m base, 1.2 m stones), then ring out on a damped spring.
    - The rest rise beside the hall. Each is clear of the hall's side by its `margin`, at its `lift` over its place plus the overshoot. It then swings in over the hall and drops into its slot, sinking 0.2–0.25 m past it, then springs back.
    - Pieces inside the rows (inner columns, ties, screens) come in over the wall tops.
    - Each comes up tipped by a few degrees (stones 25°), and the tip eases out over the rise.
    - From the end on, the pose is exactly the piece's place.
  - **Collision.**
    - While a piece moves, its body has no layer.
    - Once it is still, it goes on the ruins' layer (`RuinBump.LAYER`), where the plane's bump reads it.
    - If the plane is inside the piece's box (grown 0.6 m) at that moment, the piece stays "pending" until the plane is out. The plane is never shut inside stone.
    - Shapes are the hall's own boxes and cylinders, and the keels are convex hulls.
  - **Cloud and dust** (greybox):
    - soft white puff balls in one MultiMesh (shaders/hall_eruption_puff.gdshader, with feathered rims);
    - a churn over the hall's footprint from t = 0;
    - a burst round each piece's foot where it breaks the cloud top, with more and bigger puffs for bigger pieces;
    - wisps trailing a piece's foot for its first 30 m;
    - small grey stones shed off a rising piece and falling back (a second MultiMesh).
  - **Grid shader.** Stone uses shaders/hall_eruption_grid.gdshader, the greybox grid with an `offset` instance uniform. A moving piece's grid rides with it. Once settled, the grid is the in-world hall's world-metre grid.
- **`studies/hall_eruption.gd` / `.tscn`** is the study.
  - **Setting.** A greybox cloud sea (shaders/hall_eruption_sea.gdshader): an opaque floor of drifting heaps at the game's height (SEA_Y −105) that follows the eye. A procedural sky and sun.
  - **Placement.** The hall stands at turn 0, its entry 20 m over home, as the moments world stands it. The plane flies 125 m over the cloud sea.
  - **Cameras.** Orbit, hover (orbit held), free, and the game's plane: SkyPlane, PlaneFigure, the chase camera, and `RuinBump` off the settled stone, skimming the cloud top.
  - **HUD.** Time, pieces risen and still, the current category, the build, any hold for the build, and the camera.
- **`tests/test_hall_eruption.gd`** passes headless, with no engine errors under the runner. It checks:
  - every hall solid is in exactly one piece;
  - base first and bigger than any other piece, categories in order, starts in order;
  - nothing lands before its supports;
  - the length is 8–16 s;
  - the straight and no-additions variants;
  - every piece is hidden until it begins, and begins in order within a frame of its planned time, well under its place;
  - nothing collides while it moves;
  - every piece breaks through the cloud, and puffs and dust are up;
  - every piece ends exactly in its place, on the ruins' layer, each shape where the in-world hall has it (worst 0.00000 m);
  - a ray hits the stone;
  - the line keeps 0.9 m of room all the way;
  - keels and stones keep 3 m off the line, its way in and out, and every moment;
  - a piece settling round the plane waits, then goes solid once the plane is out;
  - a slow build churns cloud before the first piece, holds the schedule, keeps the order and settles;
  - the plane flies 25 s into the settled hall without sticking.
- `tools/hall_eruption_list.gd` prints the schedule. `scripts/scene_catalog.gd` has the new entry, and `run-hall-eruption.command` launches the study.

### The two additions

The settled hall's own stone is identical to the in-world hall's. Two things are added round it, and both are on by default:
- **Keels.** A faceted rock keel hangs under each half's floor. It is deepest mid-half (about 16 m), shallow at the ends, and drawn in at the torn ends so the gap stays open sky. It collides.
  - This is the "island/rock base" the brief asked for. The greybox hall has none.
  - The kit hall on `look/moments-hall-kit` stands on real sky islands instead.
- **Floating stones.** 9 turned boxes beside the walls and two deep in the gap. Each keeps 7 m past its own size from the line, the way in (starter and leads), the way out and every moment. They collide.

`--no-keels --no-stones` gives the bare hall.

## Timing (defaults, measured headless)

| What | When (s) |
|---|---|
| Cloud churn starts | 0 |
| Base A starts / lands / still | 1.0 / 4.0 / 5.4 |
| Base B starts / lands | 1.7 / 4.7 |
| Piers (41, 0.06 s apart) start | 2.65–5.05 |
| Walls start | 5.4–6.7 |
| Spans start | 7.1–8.2 |
| Roofs start | 8.6–10.1 |
| Floating stones start | 10.4–11.4 |
| Last roof still | 13.7 |
| All still | **14.8** |

`--erupt-speed=1.25` brings it to 11.8 s, and `--erupt-gaps=0.6` to 10.6 s.

The planner takes about 7 ms.

## A worker-thread build under the eruption

**This study.** The greybox builds all 92 pieces on a worker in about 7 ms. The first piece is ready after about 6 ms, long before the 1 s churn lead. Each piece's hand-over on the main thread (its mesh made, put in the tree) costs at most 0.19 ms headless. GPU upload is unverified, because the headless renderer is a dummy.

Meshes are made on the main thread at hand-over. The worker makes only arrays, shapes and nodes. Making ArrayMeshes on the worker while the main thread made its own raced the dummy renderer's mesh store (engine errors in the runner).

**How it hides a slow build:**
- Playing never waits for the whole build.
- The cloud churns from t = 0, whether or not anything is built.
- Pieces are built in rise order and each can rise as soon as it is made.
- If a piece is due before it is made, the schedule's clock holds and the clock of the pieces already in the air runs on, so nothing freezes mid-air. The hold is reported (`stall`, shown on the HUD).

| Simulated build | Held (s) |
|---|---|
| `--build-upfront=1.5 --build-cost=1` (test) | about 0.2–0.45 |
| `--build-upfront=3.5 --build-cost=3.5` (the kit's ~3.5 s solve, then the rest spread out; built in 7.6 s) | 2.1, nearly all of it at the base (the heaviest piece); all still at 16.9 s instead of 14.8 |

An upfront cost over the 1 s churn lead becomes a longer churn. That reads fine for 2–3 s; for longer it looks stuck.

**What's feasible for the real (kit) hall.** Not built this round. From docs/scenic/moments-hall-kit.md and sundered-hall.md:
- The kit's near build is 0.53 s (A) + 0.30 s (B) on a worker. Each half is built as one kit hall and merged into one mesh, with about 3.1k hulls.
- The islands are authored on their own worker. Standing one costs 3.5–11 ms on the main thread.
- The big sky Sundered hall's whole cluster solve is 3.5–7 s. That is the number in the brief, but that hall is the 1 km one, not this set piece.

To erupt the kit hall in pieces:
1. **Split the stone by piece.** Build the kit's stone per piece rather than per half. Either tag each kit block with its role and bay as `Hall.bay` lays it and merge per piece, or build each bay alone. Merging per piece multiplies draw calls: about 92 pieces × 2 surfaces is too many, so group to 20–30 pieces (a bay's columns together, a wall run, a bay's roof).
2. **Build the base first.** The islands and podium are the base. They are slow but needed first, so start them at seating, under the churn, and let the base rise as soon as its island is made. Build the rest in rise order behind it. At 0.3–0.5 s per half, the kit's stone is well inside the eruption's length.
3. **Spread the collision.** The body's 3.1k hulls today stand 120 a frame (2.6 ms each). Per piece, each body goes solid only when its piece settles, so the hull cost is spread across the eruption.

## What works

- Base first, then a wave of columns down the nave, then walls and arches swinging in, roof fragments dropping on, and stones last. Each piece gets a burst where it breaks the cloud and a trail of grit. From the orbit camera this reads as a building assembling itself out of the sea (captures/hall-eruption/try2).
- From the plane on the way in at cruise, you watch it come together ahead and arrive as it settles. 260 m at 14 m/s is about 18 s, against 14.8 s (captures/hall-eruption/plane1).
- Timing and order are all in `TIMING` or flags, `--erupt-speed` and `--erupt-gaps` change the feel quickly, and `tools/hall_eruption_list.gd` prints the result.
- Collision is correct once settled (tested), and the plane is never shut in.

## What's weak

- **Greybox clipping on the way in.** The greybox solids interpenetrate: the beam runs into the walls, the ties into the columns, the roof edge strips into the parapets. So the last metre of some slots passes through settled stone (spans and ties most). `--erupt-path=straight` has every non-base piece come up through the floor instead.
- **Pieces don't push the plane.** A rising piece passes through the plane (no collision while moving). No shove or dodge.
- **The puffs read as balls** close up, and white-on-white against the sea from far. The cloud sea is a flat greybox, not the game's volumetric sea, so the real breakthrough look is unknown.
- **The rise is long (about 125 m) and fast.** The base bursts at about 80 m/s. From the plane at the hall's height, the breakthrough is far below and easy to miss; the orbit sees it best.
- **No sound and no camera shake**, which would carry much of the weight.
- **The keels and stones are additions** that the in-world hall doesn't have, though both keep clear of the line and moments.
- **Not checked by hand:** flying through it while it rises, the feel at 1x against 1.3x, and the frame cost with about 1000 puffs on a GPU (the MultiMesh is updated on the CPU each frame, about 1k transforms).
- **No lodestone hookup.** The optional flag on the aqueduct isle was not added: the 150 m hall needs a clear spot by the shard, and that touches the isle's tests.

## Open questions for you

1. Arc (beside, then in) or straight up through the floor, or both by category? (`--erupt-path`)
2. Is 14.8 s right, or quicker (`--erupt-speed=1.3`, about 11 s)?
3. Keep the rock keels and floating stones as part of the hall's arrival (and in the world), or bare?
4. Order: per category (now) or a single wave gate to apse with everything at once per bay?
5. Should the rise be shorter (the hall starts nearer the sea and rises less), so the breakthrough is closer to where you watch from?

## Files

- New:
  - `scripts/hall_eruption_plan.gd`, `scripts/hall_eruption.gd`
  - `studies/hall_eruption.gd`, `studies/hall_eruption.tscn`, `run-hall-eruption.command`
  - `shaders/hall_eruption_grid.gdshader`, `shaders/hall_eruption_puff.gdshader`, `shaders/hall_eruption_sea.gdshader`
  - `tests/test_hall_eruption.gd`, `tools/hall_eruption_list.gd`
  - this doc
- Changed: `scripts/scene_catalog.gd` (one entry).
- Checks run: the headless import (clean), `test_hall_eruption` (pass) and `test_scene_picker` (pass). The full suite was not run.
