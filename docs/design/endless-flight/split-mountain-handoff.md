# Split mountains (handoff)

The wilderness now has split mountains. Each is a narrow slot canyon cut straight through a range, from the foot on one side to the foot on the other. You fly in at one mouth and out the other with sheer rock close on both sides. This is a prototype round: a smoke check, throwaway drivers and stills. No tests were committed.

## Play it

```
./run-endless-flight.command --split-near-start
python3 tools/play.py -- --split-near-start           # same, any OS
.\run-endless-flight.cmd --split-near-start           # Windows
```

`--split-near-start` finds the split nearest the start and moves the start 520 m out from its lower mouth. You start 28 m over the land, heading straight in; `--alt=` overrides the height. The console prints the split's length and where its mouth and exit are. Add `--seed=N` for other land. These were flown on the stick:

| seed | length | crest over floor | bend |
|---|---|---|---|
| 1 | 288 m | 85 m | 9 m S |
| 2 | 328 m | 112 m | straight |
| 3 | 240 m | 94 m | slight |
| 4 | 188 m | 94 m | slight |
| 7 | 680 m | 87 m | 24 m S (the best one to try first) |

## What was built

- **`scripts/endless/split_sites.gd`** (new) finds the sites and cuts the land.
  - It is a layer over the land field, like the slot halls' cuts and the ponds. `LandField` cuts it in last, after the native or GDScript field has worked. That keeps both paths in step, so nothing native changed and nothing needed rebuilding.
  - **Placement.** It follows `hall_sites.gd`:
    - There is at most one split per 1536 m square (`CELL`), chosen from the seed and the square alone.
    - A square rolls `CHANCE` times the density. If it passes, the square's middle is scanned for crests (`mountain` 0.5 or more).
    - From a crest it walks across the range to both feet. A foot is where the flank eases, or wherever the flank is 110 m under the crest (`FOOT_DEEP`). The foot also stops 40 m short of a river.
    - The crest must stand at least 75 m over both feet (`TALL_MIN`). The slot is 180 to 860 m long.
  - **What is kept clear.** A site is rejected unless all of these hold:
    - No river water within about 40 m of the floor, and no water where the ramps cut.
    - No pond nearby, and no sea.
    - The whole cut sits inside its square.
    - The way out of each mouth is open for 400 m: no hill rising faster than 0.15 straight ahead (`OPEN*`).
    - Each mouth has a flat to land on: 160 m within 4 m, within 1100 m of the mouth (`FLAT_*`, the meadows rule).
    - In the regions world, the whole cut lies inside one region whose profile grows splits, clear of the border band (`LandBlend.site_ok`).
  - **Shape of the cut.**
    - **Floor.** It is `WorldScale.opening(TOY_SLOT)` wide at its narrowest (`TOY_SLOT := 9.0`, so 18 m: 7.6 m past each wingtip). Each wall stands back by its own flutes (`ROUGH`), and the slot swells wider in places (`WIDEN`), so it is about 18 to 30 m wide. The floor runs from the lower foot to the higher at a slope of 0.07 at most. It keeps its grass and meadow paint.
    - **Walls.** Each wall rises in two sheer tiers with a bench between them (`TIER`, `BENCH`, `TIER_UP`). Above that it leans back at 0.24 (`LEAN`), so the ridgeline shows a notch from afar.
    - **Path.** It bends in a gentle S of up to 30 m, no tighter than a 220 m turn (`BEND_MOST`, `TURN_MIN`). Only the longer slots bend noticeably.
    - **Mouths.** Over the last 80 m at each end the slot opens out (`FLARE*`). The floor gets up to 1.8 times as wide, the tiers drop to a fifth of their height and soften into slopes, and the lean opens to 1.1. The range opens around the entrance instead of ending as a trench in a wall.
    - **Ends.** Past each end the floor climbs at 0.25 to meet the land (`GRADE`), and the cut's edges ease back into the land over 12 m (`EASE`), so no seam shows.
    - **Look.** The walls use the existing stylised rock (the ground shader's steep rock). The flutes also write the carve's groove and buttress channels, so the rock reads grooved. No new textures.
  - **Determinism.** A site is found at full detail whatever chunk the field last built, with the same cache scheme as the halls.
- **`LandField`** (`land_field.gd`):
  - Hooks the cut into `sample`, `shape`, `height`, `build_chunk` and `grid`.
  - New reads: `splits_in(box)`, `split_at(x, z, margin, along)` and `split_near(at)`.
  - A split is dropped where a hall's cut or a tunnel's box meets it (for when `--halls=` or `--tunnels=` is forced on in wilderness).
- **`hall_sites.gd`**: the chunk pass's normals/colour/skirt half is now `refresh(...)`, shared with the splits. It takes optional carve marks and a keep-meadow mask. Halls behave exactly as before.
- **Keep-outs.**
  - Trees (`tree_plan.gd _arches_near`, so the GDScript and native trees both get it): none in the cut. A 140 m lane through the woods continues out of each mouth, plus the trees' usual 110 m approach (`tree_keepouts`). The cut is split into stretches of up to 240 m, because a keep-out is only read within 400 m of its centre.
  - Arches (`arch_plan.gd`): none within 60 m of a cut, or within 260 m past its ends (`SPLIT_LANE`). A rock arch was standing in one approach line.
  - Grass and flowers: none on the walls; the floor keeps its tufts.
- **World profiles.**
  - Wilderness's `layers` has `"splits": 1.0`.
  - Overgrown has none, and its land hash is unchanged.
  - The regions world runs the layer at the densest region's value, then gates each site to the regions that grow it. On seed 1 regions, all 20 splits in a 24 km square are in wilderness.
- **`studies/endless_flight.gd`**: `--split-near-start`, plus the flags in its header.

## Knobs and flags

| Knob / flag | What it does |
|---|---|
| world layer `splits` (wilderness 1.0) | Density. Another region gets splits by setting this in its profile's `layers`. |
| `CHANCE` (0.9), `CELL` (1536 m) | How often. On seeds 1 to 4 (12 km squares) there is one split every 4.6 to 9.6 km². At brisk cruise (about 35 m/s) a two-minute line, with about 1 km of view either side, passes one or two. |
| `--splits=X` / `--no-splits` | Density times X / none. `--no-splits` restores the wilderness land hash from before this round. |
| `--split-slot=X` | The slot's toy width (9, giving 18 m), to try other widths. |
| `--split-near-start` | Start at the nearest split's lower mouth (above). |
| `TOY_SLOT`, `ROUGH`, `WIDEN`, `TIER*`, `BENCH*`, `LEAN`, `FLARE*`, `BEND_MOST`, `TURN_MIN`, `TALL_MIN`, `LENGTH`, `OPEN*`, `FLAT_*` | The shape and placement knobs, documented at the top of `split_sites.gd`. |

**Handles.** Each split is named `<world>/split/<cx>_<cz>` (for example `wilderness/split/-1_1`) and placed through `LayoutOverrides.xform`. A move in `layouts/endless_flight.json` moves the cut; the frame's origin is the floor's middle and only yaw and position are kept. Listing the name under `deleted` drops it. Keep a move inside its 1536 m square.

## How limited the heightmap is

- **Mesh spacing.**
  - Terrain chunks are 64 by 64 quads. The finest level is 64 m, so vertices are 1 m apart. Each level up doubles both the size and the spacing.
  - A chunk splits while the eye is nearer than 1.3 times its size (`land_stream.gd` `SPLIT`). So at distance r the drawn spacing is roughly r/83 to r/42 m: 1 m within about 80 m, 2 m to about 170 m, 4 m to about 330 m, 8 m to about 670 m, and 16 m out to about 1.3 km.
  - The walking collider is a 1 m `HeightMapShape3D` within 70 m.
- **Flight reads the exact cut.** The flight's ground and contact (`plane_ground`, `FlightContact`) read the field's height directly, not the mesh. A slot of any width is exact to fly; the limit is only in what is drawn.
- **Narrowest clean slot.**
  - With `--split-slot=3` (a 6 m floor, 1.6 m past each wingtip) the autopilot flew the seed-1 slot end to end with 2.1 m of clearance and no contact, and the walls drew clean close up.
  - From 300 m or more (4 m spacing) a floor under about 8 m draws as a closed V, and only opens as you close in.
  - For the slot to read open from about 650 m the floor needs about 16 m. Hence the 18 m default.
  - A sheer tier (2.5 m across) is a single quad from about 170 m out. The tiers and bench smear into one slope in the distance, but the notch in the ridgeline still reads from 1 km and more because of the lean.
- **What it can't do.**
  - No overhangs or undercuts: one height per point.
  - No lip leaning over the slot.
  - No faces truly vertical: the steepest face is one mesh step across.
  - No closed roof.
  - The field's own carve (blocks, ledges, gullies) is not applied to the cut's faces. The walls get the flutes, tiers and carve marks instead, which reads well enough close up.

## Proof

- **Smoke** (`tools/smoke.py`), headless, 0 errors in each:
  - endless flight with no flags;
  - `--split-near-start`;
  - `--gdscript-kernels --split-near-start`;
  - `--world=regions`;
  - `--world=regions --split-near-start`;
  - `--world=regions --gdscript-kernels`;
  - `--world=overgrown`;
  - `studies/flight_study.tscn`.
- **Fly-through on the stick** (`scratch/split/fly.gd`, uncommitted; `python3 tools/drive.py scratch/split/fly.gd -- --scene-args --split-near-start --seed=N`).
  - An autopilot works the `move_*` actions along the slot's centre line at about 9 m over the floor, at the default weight (medium) and pace (brisk). It approaches at 45 m to clear the woods.
  - Each frame it measures the wingtip clearance to each wall at the plane's height, and it counts the study's scrapes and crashes.

  | seed | time in the slot | least wingtip clearance (L / R) | contact |
  |---|---|---|---|
  | 1 | 8.4 s | 9.3 / 9.6 m | none |
  | 2 | 9.4 s | 10.6 / 10.3 m | none |
  | 3 | 7.0 s | 9.3 / 7.8 m | none |
  | 4 | 5.6 s | 9.6 / 9.3 m | none |
  | 7 | 19.8 s | 9.3 / 9.3 m | none |

  - Earlier versions hit two things, now fixed:
    - a rock arch standing in an approach (now kept 260 m clear);
    - on seed 2, a hill 100 m past an exit (now rejected by the open-way check).
  - One rendered seed-7 run had a crash 21 m past the exit, just after a still was taken. It did not happen again headless or in a rendered rerun. It is probably the driver holding a pull-up while the still was taken, but this is unverified.
- **Same canyon with and without the native kernels** (`tools/land_hash.py`, macOS arm64). The GDScript field and the native field give identical hashes.

  | land | native = GDScript `exact` |
  |---|---|
  | wilderness seed 1 | `24157d33…` |
  | wilderness seed 7 | `b722e55c…` |
  | regions seed 1 | `dc4be20f…` |
  | overgrown seed 1 | `28f79dfa…` (unchanged by `--no-splits`, so overgrown has none) |
  | wilderness seed 1 with `--no-splits` | `c515311f…`, the hash from before this round |

  - The native library this worktree copied from the main checkout reports itself as version 1 (an older warning: "rebuild it"). The stock wilderness recipe still runs natively on it. The cut does not depend on it.
- **Cost of finding sites.** Native: 2.2 to 3.4 ms per square on average. GDScript: 15 ms. The cost falls mostly on the chunk workers (a shared cache) and is paid once per square. `--split-near-start` adds about 4 s to the start (8.5 s against 4.4 s ready).
- **Stills** (`captures/split/`, git-ignored; chase camera, rendered, `--no-title`):
  - `final_seed1/sheet.png` (from about 1 km, approach, mouth, inside twice, exit) and `final_seed7/sheet.png` (approach, mouth, inside, exit). Both read as a mountain split in two.
  - `aerial2.png` is the seed-1 split from above along its axis (taken before the mouths were softened): a massif cleft from a thin spur.
  - `narrow3/sheet.png` shows the 6 m slot.

## Tests

These were run headless: `test_world_scale_guard`, `test_native_*`, `test_threaded_*`, `test_inland_recipe`, `test_forest_hold`, `test_landform_*`, `test_landscape` and `test_tree_degrowth`.

- 22 pass and 1 GPU test is skipped.
- `test_landform_forest` fails ("trees draw at most 1200000 triangles near (7773402)"). It fails identically on an untouched checkout of this round's base (`8e9d33ab`), so this round did not cause it.
- No committed test reaches the endless land, so no test covers this change directly.
- No test breaks. The full suite was not run.

## Not verified

- How flying one feels by hand, especially the 18 m pinch at boost, and in the heavy weight.
- Landing on a slot's floor. It is flat grass at least 18 m wide, but the wheels were not driven there.
- On Windows or another machine: the hashes above are from one Mac, so co-op agreement across machines is unchecked.
- How it looks across more seeds. One intermediate seed-1 site on a broad plateau read more like a canyon through a tableland than a peak split in two; others may too.

## Next round could add

- **Overhanging gorge lips** (mesh pieces). The heightfield can't overhang, so lips would be streamed rock pieces along the rims. They can be laid from the site's own path and wall heights (`Splits.point`, `path`, `_rise`). The glide would need them as solids, the way the arches and halls answer `ground` / `inside`, ideally with a soft guard like the tunnels' `guide` / `keep`. An archway or a fallen block spanning the slot would fit the same seam.
- **A rival race against the traffic planes.** `Splits.point(s, u)` gives the centre line at any `u` (floor height included). A race can line up a traffic plane at one mouth and give both the same line; `split_near` finds the next split.
- **Smaller additions:**
  - an F1 numbers line (the nearest split, and clearance while inside);
  - a pinch variant (one stretch at the opening's floor);
  - tighter S-bends on long slots;
  - perched birds or a few trees on the benches;
  - letting `--split-near-start` prefer a mountain over a tableland (score sites by crest over floor).
