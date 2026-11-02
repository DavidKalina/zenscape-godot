# Sunk caves: the mouths

Spec item 8 (`spec-sunk-caves.md`). Both bugs are fixed at all 8 openings on
the native path, and the land path this Mac runs by default was flown through
one cave.

## The ghost

It was the forest floor, with its trees on it. The floor sheet is a
see-through mesh that follows the land. ZenScapeTrees builds it and places the
trees on the native field (`tree_cell.h` `height`, `shape`), which knows nothing
of the sinkholes: LandField cuts those in afterwards, in GDScript. So over each
hollow the sheet hung at the old ground's height, up to 105 m over the carved
land, with trees standing on it up to 61 m up. The split canyons had the same
fault (`bcb3e8a7`); `_floor_off_cuts` only knew the splits.

It shows wherever a hollow is cut through woods: trees floated at 6 of the 8
openings. (4640, 4384) end B and (-6880, 5408) end B stand in open meadow, with
no floating trees and only a few floor vertices over the land, so `8cc12233`'s
"all 8" overstates those two.

Proved on one flown line into (4640, 4384): native shows the veil and the
trees; native with `--no-forest-floor` loses the veil and keeps the trees;
GDScript shows neither.

Why earlier checks missed it: the wilderness's coast keys need kernels of
version 4 (`land_field.gd` `_need`). This Mac's are version 3, so region 0
falls back to GDScript, where `height` has the sinkholes in and nothing floats.
`--no-coast` brings the native path back on the Mac. Reading `field._native`
doesn't tell you: the world is a blend, so it's always false. Use
`native_impl_in`.

Fix: `tree_keepouts` gains the sinkholes as columns (`_bowl_columns`), which
reach both tree builders through `arches_flat`, so no kernel rebuild is needed.
`_floor_off_cuts` drops floor over a sinkhole (`on_bowl`). Native and GDScript
now agree here.

## The textures

Three faults: smooth walls with their carve marks zeroed; a sawtooth rim,
because any moved vertex lost its whole meadow; and bare sand floors, because
the ground shader paints per pixel from height over the sea and these floors
lie under it. Plus the mouth rock's facets, which were undersampled ledges.

- `_bowl_cut`: gullies and patchy benches in the carve, with groove and crest
  marks in CUSTOM0. The mesh, `height` and the collider agree.
- Turf thins over `BOWL_TURF` m of cut. Flat floors keep a meadow's paint.
- `dry_low` in `endless_ground.gdshader`, marked by `DRY_LOW_RIVER`. It must
  stay clear of SEA_Y-100, every riverless vertex's level, or real sea bed and
  beaches paint as land.
- `LIP_SPOKES` 180, `LIP_RINGS` 60.

## Proof

- Census at all 8 on the native path: floating trees 0, floor verts over land
  0. Floor triangles left 3+ m over land stand the same over the uncarved land
  and no nearer than e 1.40: the coarse lattice over relief, not the ghost.
- All 8 flown from 1 km on Boost, native path, full preset, 0 hits:
  `scratch/sheet_before.png`, `scratch/sheet_after.png`. (-6880, 5408) end A
  needs a 80 m line; at 28 m the autopilot hit something 530 m out, and what it
  hit wasn't looked into.
- Cave (4640, 4384) from 1 km through and out the far end, headless, both land
  paths: 0 hits, low speed 55.2, floor clearance 5.6.
- Smoke PASS. Coast compared before and after on one flown line: unchanged.

Drivers in `scratch/`: `mouth_fly.gd`, `mouth_all.py`, `mouth_census2.gd`,
`cave_through.gd`, `label_sheet.gd`.

## Not done, or to watch

- Which path the PC ran isn't known from here. Seeing the ghost suggests
  native. Have the user look on the PC; that is the real test.
- Only one cave was flown end to end, on a clean line, not off centre.
- Stills are the full preset at 1440x900, scale 0.8, on the M5 Pro. Performance
  wasn't captured, and neither was the final code on the GDScript path. The
  ghost depends on the land path, not the preset.
- Seen straight above, the gullies read as a fairly regular radial fan on some
  bowls, e.g. (4896, -1504) end A. Fine from the flying line. `GULLY_SCALE` is
  the knob.
- The lowest wall beside the mouth stays smooth tan: `WALL_E` starts the rock
  at 0.35 of the way out. The new floor paint has no grass tufts on it.
- `shot_at` stills show cloud bands and pale mint blocks among far trees, before
  and after. Play camera stills don't. Not looked into.
- `sunk_cut` adds noise reads per bowl vertex and the mouth has 4x the verts;
  build time wasn't remeasured.
- The Windows dll here is old; `tree_cell.h` is unchanged, so none is needed.

## Model budget (mouth rock: 21.6k tris a mouth, was 5.8k; about 32k more a
cave, against about 1.4M, +2.3%)

- Sculpt high, bake low: applies in principle, not done. Baking the face onto a
  5-8k mesh would save about 14k tris a mouth, under 0.1 ms; it would cost a
  bake per mouth for each site, so not worth it yet.
- Import LODs: applies. The mouth has no LOD or visibility range. A LOD past
  about 300 m would save about 16k tris a mouth and under 0.1 ms; only one or
  two mouths are ever in view.
- Silhouette geometry: already used. The ragged inner edge is real geometry.
- Rigid parts on bones: no, nothing moves.
- Parallax depth: no. It costs per pixel, and the rock is seen at speed.
- Vertex-colour grime: in use, through RockShape and the lumps. No saving.

## Tests

No test reads the tunnel scripts. Of the two nearest, both fail and both failed
before this work, unrelated to it, and neither is in `known_failures.txt`:

- `test_ground_look.gd`: `reference_surface` has 16 varyings, limit 14. That
  file isn't touched here and had 16 at the round's start.
- `test_landform_forest.gd`: 7773402 near tree triangles, limit 1200000. The
  same number at the round's start.

The full suite wasn't run. `tools/land_hash.py`'s value for seed 1 changes, by
design, at the sinkholes.
