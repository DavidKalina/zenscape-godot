# River shape: less regular (2026-10-26)

The rivers read like highway roads: one smooth sweep along the valley, an
even width and a matching tan kerb down both banks. This round breaks up
all three. Flown and approved by the user.

## What changed

- **Course** (`land_field.gd` `_wind`, `RIVER_WIND*`): the river's line
  winds on top of the floor's sway, in bends of about 260 m and kinks of
  about 80 m on them (30 m and 7 m each way, times 0.6 to 1.3 by the
  river's width). The signed distance takes the winding's slope into
  account (`wg` less the winding's gradient), so the width holds through the
  bends. The `far` reach grows by the most it can wind.
- **Width** (`RIVER_PINCH`, `RIVER_PINCH_SIZE`, now Vector2s): the
  swell-and-pinch is 0.34 over 150 m plus 0.16 over 48 m (was 0.28 over
  150 m).
- **Bank slope** (`_bank_swing`, `RIVER_BANK_SWING`, `RIVER_BANK_SIZE`):
  the bank's run from water to floor is 0.35 to 1.9 times `RIVER_BANK`,
  swinging over 90 m, each side its own noise. Kept through the carve as
  `_river_bank` (C++ `river_bank`), used by `_river` and the floor's `near`.
- **Tan band** (`endless_ground.gdshader` `bank_w`, mirrored in
  `EndlessPatch.river_bank` and `grass_cell.h` `Patch::river_bank`):
  0 to 1.8 times 3.5 m (was 0.2 to 1.6), over 55 m and 19 m (was 70 m and
  17 m), so grass reaches the water in stretches and the two sides seldom
  match.

All field changes are mirrored in `native/terrain_kernels/land_field.h`
(a `V2::operator-` was added for the gradient).

## Checks

- Native and GDScript fields match exactly: `tools/land_hash.py --seed 1`
  with `--land-libm` against `--land-native=0`, 0 of 78,627 spots differ.
- Valley floors keep their flats: the share of floor more than 8 m from a
  river's water is unchanged (seed 1 0.727 to 0.734, seed 7 0.759 to 0.767;
  16 m grid over 8 km).
- Smoke passes: default, `--land-native=0`, `--world=regions`.
- No test mentions rivers; the suite was not run.
- Captures (uncommitted, `scratch/rv/`): held views of the seed-1 river at
  (-1325, 2786) by `scratch/river_views.gd` (extends
  `tools/harness/look_views.gd`); top-down maps by `scratch/river_map.gd`.

## Notes

- The native kernels must be rebuilt for the new rivers
  (`tools/build_native_kernels.py`; on this PC godot-cpp is at
  `builds/godot-cpp` and SCons is the Python 3.11 package's `scons.exe`).
  A stale library grows the old rivers; the launcher warns it is stale.
  Only the debug library was rebuilt here.
- Pre-existing, not from this round: with `--land-native=0`, a zigzag strip
  of water is drawn across a meadow near (-1500, 2720) on seed 1; the
  native field doesn't draw it.
