# Handoff: grass colour areas (visual polish round, colour lane)

The ask: grass that looks different in different areas, with the Amberlands' grass as one of them.

## What changed

The wilderness's meadows are now split into **grass areas**, each one to a few
kilometres across. Inside an area the whole meadow is one grass. The borders
are soft (about 400-700 m) and wander, because they are warped by the old
regions' own 300-380 m noise. There are four areas:

| area | colour at the grass's light (luma = brightness) | mix |
|---|---|---|
| lush deep green | (0.29, 1.02, 0.41) | 0.60 |
| cool sage | (0.70, 1.045, 0.76) | 0.55 |
| amber straw (Amberlands' `carpet_hue` 0.72,0.62,0.30, normalised) | (1.21, 1.04, 0.50) | 0.55 |
| today's lime | none | 0 |

- **Split:** two value noises (2600 m and 2100 m, the second rotated) with a
  smoothstep from 0.40 to 0.60. Low/low gives lush, low/high sage, high/low
  amber, high/high lime. On seed 1 the spawn is in lime. The nearest amber is
  around (750, 1050), sage around (1350, -150) and lush around (1950, 600).
- **Applied:** `grass = grass*(1-w) + luma(grass)*colour`, right after the old
  region multiplier and before the vertex hue, dry, tundra and steep olive.
  It is a hue swap at the grass's own light, so the light and shade of the
  patches (depth) is kept. High ground still turns to tundra and steep turf
  to olive, and sand, rock and water are untouched.
- **Old regions:** the round-5 blotches (ep_region) are scaled to 0.6 inside
  an area, by its weight (`EP_REGION_UNDER`), so they stay as a lighter
  variation there. In lime they are unchanged.
- **Cost:** 2 extra `ep_noise` taps per grass pixel or tuft. The warp reuses
  the regions' a and b noises.

## Flag

`--grass-areas=X` sets the strength: 1 by default, capped at 1.6.
`--grass-areas=0` or `--no-grass-areas` gives exactly the look from before
(the A/B).

Where the areas apply:
- `--world=amberlands`: none.
- The doors world: they fade out over x from offset/2 - 6 km to offset/2 - 3 km.
  That is the Amberlands' side, 25 km out, never seen from home.
- `--world=regions` (the patchwork): areas everywhere. There, Amberlands'
  `carpet_hue` repaints most of the hue.

## The twins

All three twins are touched and kept in step:
- `shaders/endless_patch.gdshaderinc` (`ep_area`, `ep_region` now takes
  areas/edge and an `out vec4 area`)
- `shaders/endless_ground.gdshader` (uniforms `area_amount`, `area_edge`)
- `scripts/endless/endless_patch.gd` (`area`, `_ab`, `_region`, `area_at`,
  statics `area_amount`, `area_edge`)
- `native/terrain_kernels/grass_cell.h` (`Patch::area`, config `area_amount`,
  `area_edge`; ZenScapeGrass version 3 -> 4)
- `scripts/endless/endless_grass.gd` (flag, `_set_areas`, `NATIVE_VERSION` 4,
  plumbing)

**The native kernels were rebuilt on this Windows PC (debug and release).**
The binaries are git-ignored, so:
- **The Mac needs its own rebuild.**
- **Main's checkout needs this build copied in or rebuilt.**

A library older than version 4 makes `_set_areas` turn the areas off
everywhere (ground and tufts together) with a push_warning. You get the old
look, not a mismatch.

## Proof

- Smoke: `python tools/smoke.py studies/endless_flight.tscn`. PASS, 0 errors.
- Stills, before (`--grass-areas=0`) and after, same build:
  - `scratch/colour/before/*.png` and `scratch/colour/after/*.png`
  - Side-by-side sheets: `scratch/colour/pair_low.png` (inside each area, 6 m
    up), `pair_cruise.png` (45 m), `pair_stock.png`, `pair_wide.png` (480 m)
  - The custom views are in `scratch/colour_views.gd`.
- What the stills show:
  - Amber reads as a golden straw meadow and replaces the old garish yellow
    blotch.
  - Sage is a cooler grey-green.
  - Lush is a little deeper.
  - Lime and the hills view are unchanged.
  - The tufts fade into the paint with no hue seam in each area.
  - Sand and water are unchanged.
- Map: `scratch/colour/area_key.png` is a key of the areas over 24 km of
  seed 1, red = spawn, bar = 1 km. `scratch/colour/area_map.png` and
  `area_map_off.png` show the painted grass with areas on and off. The script
  is `scratch/area_map.gd`.
- Native vs GDScript tints: I tried a numeric check, but it proved nothing.
  `scratch/area_parity.gd` grows a far cell in each area both ways. The
  counts match, but the buffers' colour slots read 0 in this static call, so
  no tint was actually compared. The rendered runs use the native library
  (version 4), and its tufts visibly take each area's hue and meet the paint.
  The C++ is a line-for-line copy of the GDScript.

## Frame time

Unchanged within noise. Measured with look_views `--time=240`, two runs
each, median wall / GPU ms:

| view | areas off | areas on |
|---|---|---|
| meadow_low | 7.72 / 7.68, 7.68 / 7.63 | 7.66 / 7.60, 7.68 / 7.62 |
| cruise | 8.13 / 8.07, 8.04 / 7.98 | 8.10 / 8.06, 8.09 / 8.03 |

## Tests

No committed test reads the region or patch code (grepped `tests/`), so none
are known to break. The full suite was not run.

## Not verified

- The Mac build.
- The Amberlands and doors gating was not rendered (it is code-checked only).
- A hand-flown look. From 480 m in the haze the areas are subtle: the
  kilometre change shows most from cruise height and below.
- The `border_la` view is blocked by a mountain, so it shows nothing useful.
