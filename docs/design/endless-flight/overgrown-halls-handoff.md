# Overgrown: slot halls (handoff)

`--world=overgrown` now has Sundered halls in its ridges. A clean cut runs straight through a ridge from foot to foot, with a hall standing on its floor. The hall's walls stand against the cut's rock, and its roof spans wall to wall in places and lies open in others. You can fly the nave in one end and out the other. The cut is a layer over the land field, as the ponds are, so neither the recipe nor the native kernels changed. Wilderness hashes exactly as before. This is a prototype round: smoke checks plus throwaway checks, with no committed tests.

## Launch (seed 1, `--world=overgrown`)

400 m out on each hall's axis, heading in at its lower end, 20 m up:

- `--at=-3903,-3168 --heading=151 --alt=20`: 14 bays, through the deepest ridge (crest 148 m over the floor)
- `--at=-3114,-4807 --heading=-132 --alt=20`: 20 bays (crest +100 m)
- `--at=4833,3167 --heading=-36 --alt=20`: 18 bays (crest +134 m)
- `--at=-1618,-5065 --heading=150 --alt=20`: 23 bays, a lower ridge (+46 m)

F1's numbers now have a halls line.

## What changed

- **`scripts/endless/hall_sites.gd`** (new) finds the sites and cuts the land.
  - **Placement.** At most one hall per 1024 m square, from the seed and the square alone, and safe on a worker. A square rolls (0.7 times the density), then scans its middle on a 9 by 9 grid for crests (`mountain` 0.6 or more) and tries the best 8 spots:
    - It climbs the slope's gradient onto the crest.
    - It reads the crest's way off a 30 m ring and snaps across it.
    - It checks the crest is straight 50 m either side (the middle within 10 m of their line).
    - It walks out both ways to the feet, where the flank eases under 0.12 over 12 m and stands at least 30 m under the crest. It turns back at a river's water or the sea.
    - The hall runs foot to foot in whole bays (10 to 24). Its floor is at the lower foot, the crest must stand at least 30 m over it, and the whole cut stays inside the square, so a point asks only its own square.
    - On seed 1 that gives 9 halls over 100 km², at 1.3 ms a square (8 ms at worst).
  - **The cut.** Inside the slot's half width (the hall's walls' outer faces, 17.5 m) the land comes down to 0.4 m under the hall's floor. Past that the rock stands back up over 2 m to 30 m over the floor (the sheer walls), then leans back at 0.35 run over rise to the land. The lean opens the cut into a notch in the ridgeline that reads from 1 to 2 km. Past the hall's ends the floor runs flat for 16 m (the apse's ring stands there), then climbs at 0.25 till it meets the land.
  - **The layer.** `LandField` (`scripts/endless/land_field.gd`) applies the cut after the ponds:
    - in `sample`, `shape` and `height`;
    - as a post-pass in `build_chunk` (heights, normals, colours, the carve's channels and the skirt) and in `grid`. In `grid`, the slot's floor and walls read as a river's water (`river` -1), so no grass or flowers grow there.
    - New reads: `halls_in(box)`, `hall_info(key)` and `hall_at(x, z, margin)`.
  - **Determinism.** A site is found at full carve detail whatever chunk the asking field last built. `LandField.detail` is shared state that `build_chunk` sets, and without this the same land gave different halls depending on how the game started. The ponds' finder reads the field the same way and was left alone, so wilderness doesn't change (see Notes).
- **`scripts/endless/land_halls.gd`** (new) streams the halls round the eye, as the arches are streamed.
  - **Far detail.** A square's hall is planned and built on a worker within 3.2 km, committed within 1.5 ms a frame, and freed past 4.2 km.
  - **Sections.** A hall stands in 6-bay sections. Near detail (`SunderedBuild.near`, the kit's bays) is built one section at a time, nearest first, within 650 m. It is shown within 330 m, with its far detail hidden, and let go past 800 m. Its bodies stand one chunk a frame on the ruins' layer and layer 1 (the walker, the wheels).
  - **The flight's solid.** Each section gives its solid as a 1 m grid in the hall's frame, up to 3 stretches a cell, grown by the wingtip. Until its near detail is made the grid comes from the plan (walls, column lines, whole roofs); then it comes from the near build's own hulls. `ground(p, h)` answers SkyGlide as `LandArches.ground` does: a column or wall raises the land, so the glide turns along its face, and a roof or tie overhead is a `Vector2(top, underside)` the plane slides under. `inside(p)` serves the camera, the sight line and the rolling wheels.
- **`scripts/sundered_hall.gd`.** `slot_piece(seed, bays)` makes one straight piece whose bays run through the acts in turn (`SLOT_ACTS`: gate 3 to 4, nave the rest, shafts 2 to 4, cloister 0 to 3, apse 3 to 4). It has the gate's gabled mouth at the start and the apse's ring past the end, and no torn ends.
  - **Exits.** The walls back onto rock, so breaches don't count as a way out (`bay_exit`), and a run of more than `MAX_SHUT` shut bays opens its roof instead of a side arch.
  - **High ties.** Slot halls take high ties only, because the endless glide keeps 1 m under any underside and a low tie (underside 4.1 m) left a band only 0.9 to 3.1 m high (see Notes).
  - **No change to the sky halls.** `_plans` is split into `_roofs` and `_screens_and_breaches` with the RNG order unchanged; a fingerprint of six seeds' layouts is identical before and after.
- **`scripts/sundered_build.gd`.** `far` closes a piece's last bay line only when Hall.plan marks the bay `last`, so sections don't double the join's columns. Sky pieces are unchanged, since their last bay is always `last`.
- **Keep-outs.**
  - Trees (`tree_plan.gd _arches_near`, GDScript and native, through the arches' flat list): each cut is an arch whose span runs across the slot and whose approach runs along it. No tree grows in the cut, within 18 m of its rims, or within 110 m past its ends.
  - Arches (`arch_plan.gd`): none within 60 m of a cut (`HALL_CLEAR`).
- **`studies/endless_flight.gd`.**
  - `plane_ground` is `halls.ground(p, trees.ground(p, arches.ground(p, field.height(...))))`.
  - `_blocked`, `_solid`, `_sight` and the hop-out and spawn checks count `halls.inside`.
  - Halls are primed and stepped flying and on foot.
  - `LayoutOverrides.begin` moved ahead of the field's creation, so sites read the layout file before anything first looks at the land (the look's workers did before).
- **`scripts/endless/world/overgrown/look.gd`.** The `halls` layer is 1.0. Wilderness has no `halls` key, which reads as 0.

## Handles

- Each hall is named `overgrown/hall/<cx>_<cz>` (`<world>/hall/...`). Its site is placed through `LayoutOverrides.xform`: a move in the layout file moves both the hall and its cut (only its yaw and place are kept). It is dropped if the file lists it under `deleted`, and it is tracked by name while it stands.
- Checked: a hall moved in `--layout=` stands where the file put it, with its cut following and its node tracked.
- Keep a move inside its 1024 m square, because a point asks only its own square.
- The endless flight still has no world view (F4), so moves are made in the file.

## Flags and knobs

| Flag | What it does |
|---|---|
| `--halls=X` | Density: X times each square's roll (0.7, up to 0.95). Overgrown's default is 1. |
| `--no-halls` | No halls and no cuts. The land then hashes as it did before this round. |

The knobs are at the top of `hall_sites.gd` (`CELL`, `CHANCE`, `CREST_MIN`, `BEND`, `FOOT_SLOPE`, `TALL_MIN`, `BAYS`, `EDGE`, `SHEER`, `LEAN`, `APRON`, `GRADE`) and of `land_halls.gd` (`SECTION`, `NEAR_BUILD`, `NEAR_SHOW`, `NEAR_FORGET`, `NEAR_TASKS`). The acts are in `sundered_hall.gd` `SLOT_ACTS`.

## Verified (Windows, native kernels)

- **Fly-through on the stick** (`scratch/halls/fly.gd`). An autopilot works the `move_*` actions to hold the lane's line at `LINE_Y`; it records each frame inside the hall's footprint.
  - All 9 halls on seed 1, at cruise (29.4 m/s) and at boost (46.2 m/s), end to end: 0 frames brushing, riding, sliding under or inside a solid; at most 0.5 m off the line.
  - Real clock, 1.5 km out, nothing primed, cruise and boost, rendered and headless: every section's exact solid was in place on entry.
  - Headless with fixed steps runs faster than real time here (about 170 frames a second), so there the near detail lags behind the plane.
- **Misses.**
  - Aimed into the gate's column row: turned along its face, never inside the solid. The autopilot keeps steering into it, so it stays pinned there.
  - Aimed into the cut's rock 14 m off the mouth: turned along the face, then it rides up and over the ridge.
- **Frame time** (rendered, `--uncapped`, the line into `overgrown/hall/-4_-5` from 1.5 km, one run each):

  | | approach: mean / p95 / max ms | in the hall |
  |---|---|---|
  | cruise, halls | 13.45 / 16.22 / 37.0 | 9.78 / 12.27 / 13.5 |
  | cruise, `--no-halls` (same line, over the ridge) | 13.64 / 16.34 / 29.8 | 10.76 / 18.0 / 20.3 |
  | boost, halls | 13.86 / 16.76 / 49.8 | 10.06 / 12.66 / 13.6 |
  | boost, `--no-halls` | 13.69 / 16.44 / 50.9 | 10.76 / 17.8 / 19.5 |

- **Cost.**
  - A section's near build takes 1.9 to 2.2 s on its worker. A 6-bay section is about 75k triangles near; a hall's far detail is 4 to 6k.
  - Main-thread commit is 0.3 ms at worst.
  - A chunk by a hall costs 5 to 8 ms more on its worker. The first look at a square also pays for finding its site (up to 8 ms).
- **Land hashes** (`tools/land_hash.py`):
  - Wilderness is unchanged, native and GDScript: seed 1 `c515311f…`, seed 7 `cd244951…`.
  - Overgrown with halls: native and GDScript agree, `4c6f56f6…`.
  - Overgrown with `--no-halls`: `1629a047…`, the tuning round's hash.
- **Flats** (`scratch/overgrown/flats.gd`, 6 km square; seeds 1, 3, 7, 42): identical with and without halls. Blocks >400 m / >600 m and the worst block: 19/9 1205 m, 7/0 540 m, 8/3 818 m, 17/11 1168 m. The cuts run through ridges, not meadows.
- **Smoke**, headless, 0 errors each:
  - overgrown: flying, `--on-foot`, `--gdscript-kernels`, and `--on-foot` starting inside a hall;
  - the default world: flying, `--on-foot`, `--gdscript-kernels`.
- **Stills** (`captures/halls/`, git-ignored). `sheet_final.png` shows the deepest hall: from about 1.5 km (the cleft in the ridgeline), the approach, the gate, the nave, the exit and the slot from above. `fly_*_run*.png` are the chase camera mid-flight in the nave.

## Tests

Run headless: native_*, threaded_*, inland_recipe, lake_fill, plate_migration, forest_hold, world_scale_guard, landform_forest, aqueduct_isle_plane, isle_hall_chain, isle_loop_played, sundered_gorge_isle, flight_bench, airship_ferry and rune_serpent. 20 pass and 6 fail.

- Three failures are the known ones: test_threaded_recipe, test_landform_forest, test_aqueduct_isle_plane.
- Three fail the same way on an untouched checkout of this round's base (`ec1d8fab`), so they are not this round's:
  - test_isle_loop_played: "the next piece rises behind it";
  - test_rune_serpent: its way's tube is blocked at 186 m;
  - test_isle_hall_chain: the no-hitch budget (5.39 ms here, 8.15 ms on base).

No test breaks from this round. The full suite was not run.

## Not verified

- How flying a hall feels by hand.
- Landing in a hall or on its roof: `floor_at` (the wheels) reads only the land.
- Walking a hall: the bodies are on layer 1 and the `--on-foot` smoke inside one passes, but no walk was driven.
- On the Mac: the cut is GDScript only, so the Mac's GDScript field gets the same halls (native and GDScript hash the same here).

## Model budget (no new model: the kit's own hall pieces, in sections)

- **Import LODs** apply and are not done. A hall standing near shows 2 to 4 sections of about 75k triangles each within 330 m (up to about 300k). `RuinLod.add` on each section's merged mesh (as the arches' ruins get) might save 100 to 150k triangles at 150 to 330 m, perhaps 0.1 to 0.3 ms GPU. The frame times above show no measurable cost yet.
- **Silhouette geometry**: the kit's, unchanged.
- **Vertex-colour grime, sculpt high and bake low, parallax depth, rigid parts on bones**: do not apply (existing kit pieces, no new textures, no rig).

## Notes for later

- **Tunnel.** The roof over the slot is the hall's own. A rock roof is another stretch in the same grid (`Vector2(top, underside)` for the flight), and a mesh spanning the cut's walls. A true tunnel under an uncut mountain needs a hole in the ground mesh at the mouth: `apply_chunk` could drop the quads inside a mouth's outline the way the skirt is rebuilt. The site already has the frame for both.
- **Low ties.** A low tie is now refused in a slot hall, because SkyGlide treats every endless solid as stone (`plane.stone` is always true): touched from below within its 1 m clearance, the glide brushes the plane back instead of sliding it under. For low ties to return, the glide needs an under-slide for stone ceilings.
- **Ponds and `detail`.** `Ponds.cell_pond` samples the asking field at whatever `detail` its last chunk left. Ponds near a carved river could in principle differ with how the game started, though it hasn't shown. Fixing it as the halls do would change wilderness's hash.
- **`RuinKit.set_detail`** is global state. Near hall sections build one at a time for that reason. An arch's ruin built on a worker at the same moment could take the hall's detail (0.25), or the hall the arch's. That was not seen.
- **The approach.** A hall's gate faces its end from the seed. At the higher foot the floor climbs out on a trench (0.25), so coming in from that end means dropping into the trench.
- Aqueducts, the trees for this world, Olmec heads, overgrowth and the Mac dylib remain as the brief lists them.
