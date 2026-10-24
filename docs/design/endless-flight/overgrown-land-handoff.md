# Overgrown's land forms (handoff)

`--world=overgrown` now has its own land: long, low, straight ridges with sharp crests and clean notches, terraced hills, and tiered mesas with sheer walls. Wilderness's valleys, rivers, coast and sea are unchanged. All of it comes from new recipe keys in `LandField` (`scripts/endless/land_field.gd`, GDField) and the native field (`native/terrain_kernels/land_field.h`, `land_field_bind.h`), and they match bit for bit. Every new key defaults to off, so wilderness and test_dry hash exactly as before.

## New recipe keys (default → overgrown's value)

| Key | Default | Overgrown | What it does |
|---|---|---|---|
| `ridge_crisp` | 0 | 0.85 | Blends the ranges' round massif toward a gable: straight flanks up to a sharp crest, with the ridged noise only a ripple on top. |
| `notch` | 0 | 0.8 | How deep the notches cut, as a share of the range's height. A notch sits where a noise's zero line crosses a crest; where that line runs along a crest, it cuts nothing. |
| `notch_scale`, `notch_width` | 1300, (0.025, 0.07) | 2600, (0.05, 0.10) | How far apart the notch lines are; the notch floor and its lip, in \|noise\|. |
| `terrace` | 0 | 1.0 | Terraces on the hills and on a range's lower flanks. |
| `terrace_step`, `terrace_flat` | 5, 0.65 | 4, 0.65 | A tread every N m of height; the share of each step that is tread (the rest is riser). |
| `terrace_scale`, `terrace_band` | 1500, (-0.15, 0.2) | the same | The mask that decides where terraces appear. |
| `mesa` | 0 | 1.0 | Mesas: flat tops standing above the lowland. Valleys cut through them as canyons, their walls are carved like rock, and their tops are meadow. |
| `mesa_tall`, `mesa_keep` | 50, 0.12 | the same | The top's height over the lowland; the share of the hills the top keeps. |
| `mesa_scale`, `mesa_level`, `mesa_edge` | 800, 0.3, 0.035 | 1400, 0.05, 0.025 | Mesa size, how much land they cover, and wall width (in noise units; at 0.025 the walls are sheer). |
| `mesa_steps`, `mesa_gap` | 2, 0.12 | 2, 0.06 | Tiers, with a ledge between them. |
| `mesa_mask_scale`, `mesa_band` | 3800, (-0.1, 0.2) | the same | The broad regions mesas stand in. Outside a region they shrink away rather than sink, and they stay off the ranges. |

Existing keys that overgrown changes: `range_scale` 3400, `range_width` 0.12, `warp_move` 140, `range_band` (-0.7, -0.3), `peak_tall` (70, 150), `ridge_scale` 1500, `snow` 320 (no snow). It keeps wilderness's `hill_tall` of 16, because 20 cost flats.

Native noise salts 19 to 22 are new. **`ZenScapeLandField` is now version 3.** `LandField._need` asks for v3 only when a recipe uses the new keys. A v2 or v1 library still grows wilderness and test_dry natively; overgrown falls back to GDScript on it, with a warning.

## Where halls and aqueducts would sit best

- **Hall cuts:** through the long ridges, either at the notches or along straight stretches. In `shape()`, a ridge is where `mountain` > 0.7. Ridges run across the gradient of the range noise; they are about 150 to 250 m wide and 70 to 150 m tall, with crests 2 to 4 km long between valley crossings. A notch already gives a flat floor 40 to 90 m wide to fly through; a hall would dress it.
- **Aqueducts:** along the valley floors (`valley` < `half`; floors stay flat, with the river hugging one side), and spanning the gaps where a valley cuts through a ridge or a mesa (the canyon walls stand on both sides).
- Neither the notches nor the mesas are exposed yet. `scratch/overgrown/finder.gd` finds them by diffing the field against the recipe with one form turned off. A dressing round would add `last_notch` and `last_mesa` reads to the field.

## Proof

- **Hashes** (`tools/land_hash.py`, 78,628 spots plus 6 chunks):
  - Wilderness is unchanged in both native and GDScript: seed 1 `c515311f…`, seed 7 `cd244951…`.
  - test_dry is unchanged: `c3bfe25e…`.
  - Overgrown matches native against GDScript on seeds 1, 3, 7 and 42: `3a84f4a1…`, `81577e7f…`, `13842a02…`, `df8fe123…`.
- **In-process parity** (`scratch/overgrown/parity.gd`, native against GDField, 140k samples at five carve details on mesa walls, notches and random points): heights and meadows match exactly. A few carve-shade bytes (0 to 15 per 180k) flip on ulp rounding, at the same rate in wilderness, so this predates this round.
- **Chunk build cost**, native, 64 cells, steps 1 to 16 m: wilderness 4.08 to 4.14 ms (before this round 4.06 to 4.27), overgrown 3.83 to 3.97 ms (less range to carve).
- **Real play loop**, rendered, `--uncapped`, 30 s at cruise:
  - Overgrown: mean 11.98 ms, p95 14.6 ms, max 22.8 ms, 6.6 ms per chunk on a worker.
  - Wilderness: mean 11.96 ms, p95 15.9 ms, max 44 ms.
- **Flats check** (`scratch/overgrown/flats.gd`, 6 km square; land blocks more than 400 m / more than 600 m from a 192 m strip, and the worst block):

  | seed | wilderness | overgrown |
  |---|---|---|
  | 1 | 42 / 11, worst 1735 m | 13 / 9, worst 1186 m |
  | 3 | 36 / 19, worst 1195 m | 4 / 0, worst 484 m |
  | 7 | 18 / 4, worst 729 m | 6 / 1, worst 744 m |
  | 42 | 10 / 3, worst 1082 m | 14 / 5, worst 1168 m |

  Strips cover 19 to 25% of the land, against 13 to 19% in wilderness.
- **Landing** (`scratch/overgrown/land_on.gd`, through stick, flaps and brake, then stop, F to get out): greasers on an overgrown meadow 458 m from the start, on a mesa top 43 m above its foot (strip at -192,-1120), and on wilderness.
- **Smoke**, headless, 0 errors each: overgrown flying, `--on-foot` and `--gdscript-kernels`; the default world flying, `--on-foot` and `--gdscript-kernels`.
- **Stills:** `captures/overgrown/` (git-ignored). `pair_*.png` puts overgrown on the left and wilderness on the right at the same spots. Also `approach.png` and `landed.png`.

## Tests

The run covered native_*, threaded_*, inland_recipe, lake_fill, plate_migration, forest_hold, world_scale_guard, landform_forest and aqueduct_isle_plane: 17 pass, 3 fail. The 3 failures are the known ones (test_threaded_recipe, test_landform_forest, test_aqueduct_isle_plane). No existing test breaks. The full suite was not run, and no test is committed (still a prototype).

## Mac

Rebuild the dylib for both targets (the commands are in world-profiles-handoff.md). Until then overgrown grows in GDScript, with the same land but slower. Afterwards, `python3 tools/land_hash.py -- --world=overgrown` with and without `--land-native=0` must print the same `exact` line.

## Notes

- The windows' look in the stills (orange mood) is the parallel look round's work, not this one.
- In the landing driver, the walk after getting out moved only 0.5 m in 180 frames of stick. The driver's walk check may be wrong, so on-foot walking after a landing is unverified here. Getting out and the `--on-foot` smoke both work.

## Tuning

After a flight the ridges read, from a distance, like a lattice of spaced posts (the crest cut into separate teeth by notches, thin crests sampled intermittently by far LOD chunks), becoming clear only when close. Values only, in `scripts/endless/world/overgrown/land.gd`:

| Key | Before | After |
|---|---|---|
| `range_width` | 0.12 | 0.16 |
| `ridge_crisp` | 0.85 | 0.7 |
| `notch` | 0.8 | 0.5 |
| `notch_scale` | 2600 | 5000 |
| `notch_width` | (0.05, 0.10) | (0.04, 0.09) |

Notches are now rare, shallower saddles, and crests are broader, so a ridge reads as one ridgeline from 1 to 3 km and is still crisp up close. Grass: `grass_tall` 1.35 to 1.5 in `overgrown/look.gd`.

Checks: native and GDScript agree (`land_hash.py` seed 1 overgrown `1629a047...`, both; parity.gd: heights and meadows differ 0). Flats (blocks >400 m / >600 m, worst) for seeds 1, 3, 7, 42: 19/9 1205 m, 7/0 540 m, 8/3 818 m, 17/11 1168 m. This is slightly worse than before this tuning (13/9, 4/0, 6/1, 14/5; seed 42 gets 6 more far blocks) and still better than wilderness on most seeds. Stills: `captures/tune/` (git-ignored; `*_before` and `*_v1`, e.g. `nsE_*`).
