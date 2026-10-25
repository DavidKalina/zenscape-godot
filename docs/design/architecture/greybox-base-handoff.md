# Greybox base: the turf skeleton lifted into MotifGreybox (handoff)

This round is a refactor that should not change behaviour. Every motif
builds the same tree as before, in both grey and turf modes. The
fingerprints below confirm it.

## What moved where

- **`KitLand.island` spec keys** (`scripts/shared/kit_land.gd`). These
  are opt-in, so every existing caller and saved motif builds as before.
  - `"collide_sides": true` collides the hanging sides as drawn. It adds a
    "Sides" StaticBody3D as the island's last child.
    `"sides_backface"` defaults to true. gb_face passes false to keep its
    one-sided `create_trimesh_shape` behaviour.
  - `"sides": false` draws no ring sides. The Stair to the Clouds' mesa
    uses it instead of deleting the "Mesh" child afterwards.
  - New `static func collide_sides(node, drawn, backface)`.
- **`KitMotif.warm_look()`** (`scripts/kit_isle/kit_motif.gd`) is the
  `palette / ground_material / rock_material / rock_tone` block. It
  replaces the copy in 16 files.
- **MotifGreybox turf hooks** (`scripts/kit_isle/motif_greybox.gd`). All
  are optional:
  - `grey_flag()` names the launch flag. `grey()` is now an instance
    method, and `static flagged(flag)` is for static callers.
  - `turf_seed()` returns -1 when the motif has no turf pass. Island k
    gets seed `turf_seed()+k` and flora gets `+9`.
  - `turf_islands()` returns KitLand specs plus `name`. Default values:
    flat `ground` at `top`, `hang`, `tone` and `collide_sides`. `keel:false`
    leaves an island out of the occupancy.
  - The other hooks are `turf_paths()`, `turf_tone()`, `turf_cost()`,
    `warm_turf()` (default: warm_look, RuinKit materials, GiantStone) and
    `dress(root)`.
  - The base now answers `build` (turf, or `build_grey`), `warm`,
    `life_script`, `build_cost`, `flora_site`, `flora_seed`, and `_solids`
    (`_part_solids` plus the islands' keels at `TURF_KEEL_REACH` 1.4).
  - `has_turf()` is true when the motif has a turf pass and is not grey.
  - The turf root is named `slug().to_pascal_case()`.

## Files

- **Converted to the hooks, with no `build`, `warm`, `life_script` or
  `build_cost` override left:** gb_plumb_well, gb_sunken_giant,
  gb_wardens_well, gb_lidstack, gb_noon_weir and gb_vigil_bellows. Their
  `_collide_sides`, `grey()`, `KEEL_REACH` and keel loops are deleted.
  - Plumb keeps a `flora_site` (it calls super and adds the ray) and a
    `warm_turf` (it never warmed RuinKit).
  - The giant keeps `_solids` for its forearm beam.
  - Noon weir keeps `_part_solids` (the channels) and `_solids` (the
    piers).
  - Wardens and vigil keep `turf_tone` (their wet turf).
- **Kept their own `build`**, because their land diverges: per-island
  seeds from LAYOUT, metas, `pieces`, islets left uncollided, colossus
  caps and similar. These now pass `"collide_sides"` to KitLand and call
  `warm_look()`:
  - gb_haulway also moves to `grey_flag()`. Its static ground functions
    use `flagged(GREY_FLAG)`.
  - gb_rootbound_cut, gb_serpent_crossing, gb_procession, gb_weir_stair
    and gb_face.
- **Only `warm_look()` changed:** gb_coliseum_pit, gb_lamplighters_stair,
  gb_stacked_court and gb_felled_colonnade. gb_city_landing is untouched.
- **motif_authored.gd** uses `"collide_sides"` instead of
  `Rootbound._collide_sides`, and its Rootbound preload is gone.
- **.claude/skills/motif-turf/SKILL.md** now points to the hooks.
- **Totals:** 360 lines added and 627 deleted. All 12 `_collide_sides`
  copies and all 7 `static func grey()` copies are gone.
- **Unchanged:** piece ids, motif ids, connectors and the launch flags.
  The motif yard's and `tools/harness/chain.gd`'s `GREY_FLAGS` tables are
  still hand-kept. They could ask `grey_flag()` instead. Doing that would
  give haulway `--grey` in the yard, which is a behaviour change, so this
  round leaves the tables alone.

## Proof

- The headless import is clean.
- **Fingerprint.** `scratch/fp_greybox.gd` (throwaway) covers every
  registry motif: the 17 `gb_` motifs and the 4 `editor_*` motifs. Each is
  built off-tree after `warm`. Per motif it hashes:
  - every node's class, transform and metas (with object ids stripped)
  - every mesh's vertex count and AABB
  - every collision shape, including the concave faces' bytes and backface
    flag
  - the contract: footprint, span, occupancy, sockets, flora seed and
    site, life script, cost and `lands`

  It also covers the stair-clouds mesa. Runs on the base files and on
  this branch match exactly in turf mode, and in grey mode (all 7 grey
  flags). Nothing differed.
- **Smoke:** 40 of 40 passed.
  - Motif yard: each of the 17 motifs with and without `--grey`, plus
    `--haul-grey`.
  - `bell_spires` (kit), `editor_hill`, `editor_aqueduct_gorge`,
    `studies/aqueduct_isle.tscn` and `studies/stair_clouds_isle.tscn`.
- **`tools/smoke.py --greybox`:** 9 of 10 passed.
  `studies/greybox/sunken_giant.tscn` fails on exit-time leak errors
  (PagedAllocator, DummyMaterial RIDs). It fails the same way on the base
  files. The study does not use the motif code.
- **Nearest tests** (`test_motif*`, `test_*isle*`, cluster, ravine,
  ground_look, character_study, ledger, scene_picker): 24 passed and 6
  failed. All 6 also fail on the base files, with the same lines and
  hashes. None are in known_failures.txt. **This round breaks no
  existing test.**
  - test_aqueduct_isle: the wall run
  - test_aqueduct_isle_life: tokens
  - test_aqueduct_isle_look: the plant shader, 25 plants off turf
  - test_broken_ring_isle: the spiral
  - test_motif_families: the colonnade_spine and broken_ring hashes
  - test_motif_sky: dragon_roost life is null

## Harness notes

- `tools/godot.py` options (`--log`, `--timeout`) must come before the
  Godot args. When they come after, they are passed to Godot and ignored.
- There is no ready tool for a before/after fingerprint of every motif, so
  this round wrote `scratch/fp_greybox.gd`. `tests/motif_fingerprint.gd`
  covers less: no metas, no backface flag, no contract. When a
  fingerprint hashes metas through `str()`, object ids leak in and change
  whenever the preload graph changes, so strip `#<id>` first.
