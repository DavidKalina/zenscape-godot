# Endless flight, arches round

The ask: "more arches to fly through on land", both natural rock arches and ruined built ones.

## Launch

- Mac: `./run-endless-flight.command [--seed=1]`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`
- Places on seed 1, each one a short glide from the start:
  - a rock arch: `--at=-372,-3376 --heading=-60 --alt=30`
  - a double rock arch: `--at=872,-3514 --heading=-171 --alt=30`
  - a big rock span over a valley: `--at=-3410,-2024 --heading=29 --alt=40`
  - a ruined aqueduct: `--at=-3520,-3413 --heading=-24 --alt=20`
- F1's numbers now have an arches line.

## What changed

- `scripts/endless/arch_plan.gd` decides where the arches go. It is a pure function of the seed and a 480 m world cell: 6 tries per cell, at most 2 arches per cell, at least 200 m apart. Each spot reads the land through the new `LandField.shape()`. The kinds:
  - **rock**: on range flanks and crests (`mountain` 0.22 to 0.95, away from valleys). The span runs along the slope's contour, so both legs stand on ground of about the same height. There are four forms:
    - single: opening from toy width 8 to 13
    - tall and narrow (the tight one on purpose): toy width 5 to 6.5, about 11 m
    - wide and low: toy width 14 to 22
    - double: two spans sharing a leg
  - **narrows**: a rock span across a valley where it runs narrow through a range. Its legs stand up the valley's sides, and you fly it down the valley. These are big (150 to 270 m wide, 70 to 90 m clear) and rare (1 to 3 per 60 km²).
  - **aqueduct**: a RuinKit `Aqueduct.run` across a valley floor in the hills. It has up to 6 arches, sometimes a head and sometimes a broken span. The spans are grown from toy widths 4.7, 6.5 or 8, and on wide floors they grow up to 2.4x, so openings run from 8.5 m (tight) to about 20 m.
  - **gate**: at a lowland meadow's edge (meadow 0.06 to 0.7, so not on the flat itself). It is either a `RuinKit.arch` (toy width 4.2, 6 or 7) or a short broken aqueduct run.
  - Every opening is sized with `WorldScale.opening`. Density is about 2 arches per km², roughly 2 to 3 in view a minute at cruise. Seed 1 over 59 km²: 42 single, 19 tall, 22 wide and 11 double rock arches, 1 narrows, 24 aqueducts and 8 gates.
- `scripts/endless/arch_build.gd` builds the arches on a worker.
  - **Rock**: a procedural mesh. A tube is swept along the arch's line, with a squared section that flares into the ground at the legs. The rock is lumped, grained and banded into ledges by world noise sized to the rock's thickness. The feet are sunk and the ends capped. It uses the land's own ground material, so the faces read as the land's rock and flat tops grow its turf. Its collider is a trimesh on layer 1.
  - **Ruins**: the kit piece grown to size, with its piers built down to the land (the kit's `ground` callable). It gets the kit's LODs (`RuinLod.add`). Its colliders are about 120 boxes merged from its columns, not the kit's 1,400 hulls; adding those took 36 to 50 ms a commit.
  - **Columns**: every arch also gives its solid as columns, for the flight. Along its own x, each 1 m column holds up to 3 solid stretches. Its depth is kept per 3 m height band, and it is widened by half the plane's span (the wingtip).
- `scripts/endless/land_arches.gd` streams the arches like the land.
  - Cells within 2.6 km are built by WorkerThreadPool tasks (2 at once). They are committed on the main thread within 1.5 ms a frame (at least one arch a frame) and freed past 3.1 km. `prime` builds those within 500 m at the start.
  - `ground(p, h)` answers SkyGlide's `ground`:
    - a leg or pier raises the land's height (a cliff: the glide turns aside along its face);
    - a span over the plane is `Vector2(top, underside)` once the plane is nearer the span than the ground, so it slides under it and can ride its top;
    - under that, it gets the land.
  - `inside(p)` is for the camera, its sight line and the rolling wheels.
- `studies/endless_flight.gd`:
  - `plane_ground` goes through `arches.ground`, and `_solid`/`_sight` count the arches.
  - The hand landing gets `blocked = arches.inside`, so a rolling plane is stopped by a pier.
  - It calls `LayoutOverrides.begin("endless_flight")`.
  - The HUD has an arches line.
- `scripts/endless/land_field.gd` has a new `shape(x,z)`: height, meadow, mountain, inland, valley distance, half, side and the way across the valley. These are values `sample` already worked out, kept in `last_*` vars. The land itself is unchanged. Round one's land (`--old-land`) reports no ranges or valleys, so it gets no arches.

## Handles

- Each arch is named `endless/arch/<cx>_<cz>/<i>`.
- At commit it is placed through `LayoutOverrides.xform`, then `track`, and dropped if the layout file lists it under `deleted`. Only the yaw and the place of a move are kept, and the flight's columns follow them. Its name leaves `entries` when its cell is freed.
- The endless flight has no world view (F4), so nobody can move one by hand yet. A layout file at `res://layouts/endless_flight.json` would be read.

## Flags

| Flag | What it does |
|---|---|
| `--arches=X` | How many: X times the tries a cell. Default 1; 0 gives none. |
| `--no-arches` | No arches. |
| `--rock-arches=X` | X times the chance a fitting spot takes a rock arch (rock and narrows). Default 1; 0 gives none. |
| `--ruin-arches=X` | The same for the ruins (aqueducts and gates). |
| `--no-arch-lod` | The ruins without their LODs, to compare. |

The knobs are at the top of `arch_plan.gd`: `CELL`, `TRIES`, `MOST`, `APART`, `TAKE`, the `TOY_*` widths, `RUN_MOST` and `RUIN_GROW`. The rock's look is at the top of `arch_build.gd`: `RING`, `RING_EVERY`, `SQUARE`, `LUMPS`, `GRAIN` and `LEDGES`.

## Verified (M5 Pro Mac)

- Headless import: 0 errors.
- Smoke: these all PASS with 0 errors:
  - `endless_flight.tscn` as is
  - with `--no-arches`
  - with `--old-land --seed=7`
  - with `--arches=2 --rock-arches=0 --at=-3600,-3650` (start by an aqueduct)
  - with `--plain-look` by the narrows
  - `aqueduct_isle.tscn`

  RuinKit itself is untouched, so the motif yard was not smoked.
- Play-loop check (`scratch/arches/fly.gd`, run by `scratch/arches/runs.py`). It flies the plane at an arch through the real input path: the stick's `move_*` actions, an autopilot driving them. Seed 1:
  - Through the opening, clean, with no brush within 40 m of the arch: rock single, tall (the tight 11 m one), wide, double, narrows, aqueduct and gate.
  - Into a rock leg: it is turned aside along the face (brushing, the heading swung 1.2 rad), and it never got nearer than 11 m to the leg's middle line.
  - Into an aqueduct pier: it is turned aside (1.2 rad) at 4.4 m from the pier's middle (the pier is about 1.9 m deep, plus the wingtip).
- Flats check (`scratch/arches/flats.gd`, the terrain round's check, with each arch's ground footprint plus 16 m counted as no flat). Seeds 1, 3, 7 and 42, an 8 km square, 160 to 180 arches each:

  | | blocks >400 m from a 192 m strip | blocks >600 m |
  |---|---|---|
  | without arches | 30, 35, 30, 22 | 8, 6, 14, 3 |
  | with arches | 30, 37, 33, 22 | 8, 6, 16, 3 |

  That is 0 to 3 more blocks out of about 600. Seed 7's worst block went from 1032 m to 1092 m. Maps with the strips marked are in `scratch/arches/flats_<seed>.png`.
- Stream (`scratch/arches/stream.gd`, 60 s real time, boosting):
  - 58 arches standing, 107 cells.
  - Slowest commit 2.9 ms. A rock arch commits in about 1 to 2.5 ms (its mesh and trimesh), a ruin in 0.1 ms.
  - Worker builds: rock 1 to 2 ms, gate about 30 ms, aqueduct 0.5 to 3.5 s (the kit's own build).
  - The start is 0.5 s slower, more by an aqueduct (`prime` builds within 500 m).
- Rendered stills (Forward+, from the plane's approach), judged by eye:
  - `scratch/arches/rock_150.png`, `rock_25.png`: a single rock arch on a range's foot.
  - `scratch/arches/rock_double_150.png`: a double.
  - `scratch/arches/narrows_150.png`: the big span.
  - `scratch/arches/aqueduct_70.png`: a ruined aqueduct across a valley floor.

## Not verified

- How the flying feels by hand.
- GPU frame time. An aqueduct run is 100 to 330k triangles at LOD0, and about 135k rock triangles stand round the eye.
- Landing on top of an arch. The glide can ride a span's top, but `floor_at` (the wheels) reads only the land.
- Walking: the layer-1 colliders exist, but there is no walking yet.
- Building kit pieces on a worker under the headless dummy renderer has a known Godot race (godot#124183, noted in `scripts/ruin_lod.gd`). It did not show in about 15 headless runs.

## Model budget (rock arches, a new model)

- Rock arches are 1.6k to 4k triangles; the big narrows spans are 9k to 18k.
- **Silhouette geometry**: applies, and is what is used. The lumps and ledges are real geometry on the outline, and the faces get their detail from the ground shader's world noise. Nothing to save.
- **Import LODs**: applies, but is not done. At about 40 rock arches standing (about 135k triangles), a far level at 25% beyond 600 m would save about 80 to 100k triangles, perhaps 0.1 to 0.3 ms GPU. `RuinLod.leveled_mesh`'s simplifier could be reused.
- **Vertex-colour grime**: partly. The vertex colour carries a noise shade. Darkening the crevices (where the push is negative) would cost no triangles, a look gain only.
- **Sculpt high, bake low**, **parallax depth**, **rigid parts on bones**: do not apply (procedural, no textures, no rig).
- The ruins use the kit's pieces and its existing LODs (`RuinLod`), with nothing new.

## Tests this breaks

None known. The full suite was not run.
