# Hall line tufts

Branch `look/hall-line-tufts` (from `look/hall-line-grass`). Not merged.

## What changed

The hall line islands' turf now carries KitFlora grass tufts and meadow
flowers, grown by the same `KitFlora.Grow` the aqueduct isle uses (same drifts,
flower meadow type, catalog meshes and plant materials).

- `scripts/hall_line_build.gd` `_flora` (worker, in `build`): runs `Grow` with a
  site that has no physics space. Its `probe` reads the island's own ground
  (`on_land`, `ground_at`, slope under the palette's rock slope on all four sides,
  not `blocked`, off the water). It refuses points in the flown lane's strip
  along the whole piece and points on or beside the hall's hulls (paving,
  columns, walls: their AABBs, grid-filed). The result is plain batches in
  `made.flora`, with `made.flora_usec` timing it.
- `stand_island` (main thread) turns the batches into `MultiMeshInstance3D`s
  under an `Island/Tufts` node, which frees with the piece.
- `scripts/kit_isle/kit_flora.gd`, additive and opt-in on `Site`: `probe`
  (a callable in place of the ray prober), `tuft_size`, `plain` (Draw gives
  `parts` data, no nodes or materials, worker-safe). `KitFlora.batch_node` is
  Draw's old batch construction, moved out so both use it. Defaults
  unchanged, so the isle and the editor's motifs build as before.

## Knobs

`hall_line_build.gd`: `TUFTS` 3.0 (a square metre of box at a drift's thickest;
the isle's is 4.6), `TUFT_SIZE` (1.1-1.9, bigger than the isle's 0.85-1.45 to
read from the air), `LANE_MARGIN` 0.8 m, `HULL_NEAR` 0.45 m, `FLORA_HEIGHT` 1.2.
`-- --hall-tufts=0` turns it off, `--hall-tufts=2` scales the density.

The lane's corridor floor is 1.0 m over the hall floor (`Hall.LANE_Y.x`); tufts
reach about 0.7 m and flowers about 1 m, and none stand in the lane's strip.
Collision, shape and sizes are untouched.

## Cost (per piece, measured in the autopilot flight)

- Worker: 280-470 ms of flora on a 3.3-9.4 s build (about 5%).
- Main thread: `stand_island` took 1.1-2.3 ms with the tufts.
- Draws: 43-59 multimesh batches a piece (24 m tiles, one a tile and part),
  1,600-2,500 instances. Visible only inside GRASS_RANGE 95 m / FLOWER_RANGE
  65 m, fading as the isle's do.

## See it

```
& $env:GODOT --path . --rendering-method forward_plus --windowed studies/aqueduct_isle.tscn -- --no-title --near-ring --autopilot
```

Captures (not committed, `captures/hall/`): `tufts_09.png`, `tufts_12.png`,
`tufts_17.png` beside last round's `after_09/12/17.png`, and `main_isle.png`.
The islands are mostly hall, so the turf in view is the gaps between the
paving and the flanks; the lane's own strip stays bare turf on purpose. Throwaway
driver: `scratch/hall_shots.gd` (`python tools/drive.py scratch/hall_shots.gd --rendered -- --n=18 --tag=tufts`).

## Proof

Smokes pass with no errors: `studies/aqueduct_isle.tscn -- --near-ring --autopilot`,
`studies/motif_yard.tscn -- --motif=bell_spires`, `-- --motif=editor_hill`.

## Existing tests that might break

None expected. `tests/test_isle_hall_chain.gd`, `tests/test_isle_loop_played.gd`
and the KitFlora tests (`test_kit_flora*`) were not run (no full suite).

## Not done

Gaps between the paving get tufts only where wide enough past
the hull margin.
