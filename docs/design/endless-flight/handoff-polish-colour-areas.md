# Handoff: grass colour areas (visual polish round, colour lane)

The ask: grass that looks different in different areas, with the Amberlands' grass as one of them.

## What changed

Two rounds: the first commit (4555e35a), then a retune after the user's
first look ("Did we lose some of the color though? I'd still like to keep
that more bright green as well. Not everywhere ofc.").

The wilderness's meadows are now split into **grass areas**, one to a few
kilometres across. Inside an area the whole meadow is one grass. The
borders are soft (a few hundred metres) and wander, because they are warped
by the old regions' own 300-380 m noise.

Shares over seed 1's grass (`scratch/area_stats.gd`: land 2-60 m over the
sea, a 24 km square on a 60 m grid; each point counted by its weights):

| area | colour at the grass's light (luma = brightness) | mix | share |
|---|---|---|---|
| today's bright lime | none | 0 | 45.2% |
| vivid emerald lush | (0.24, 1.36, 0.39) | 0.60 | 14.3% |
| cool sage green | (0.50, 1.18, 0.62) | 0.45 | 22.4% |
| amber straw (Amberlands' `carpet_hue`, normalised; unchanged) | (1.21, 1.04, 0.50) | 0.55 | 18.1% |

- **Split (retuned):**
  - A 2600 m noise keeps lime past a soft cut (smoothstep 0.47 to 0.65).
  - Under that, a 2100 m noise falls into three bands: lush below
    0.36-0.44, amber above 0.58-0.66, sage between.
  - Lush and amber never touch: a sage band of a few hundred metres runs
    between them.
  - The first round (two noises, lime only where both were high) left lime
    on about 28% of the land.
- **Where they sit on seed 1:**
  - The spawn is in lime.
  - Flat spots deep in each area: lime (450, -1050), lush (1800, 450), sage
    (1350, 0), amber (-1950, 2100) and (1050, -1200).
- **Applied:** `grass = grass*(1-w) + luma(grass)*colour`, right after the old
  region multiplier and before the vertex hue, dry, tundra and steep olive.
  It is a hue swap at the grass's own light, so the light and shade of the
  patches (depth) is kept.
  - Lush's colour is brighter than the grass (luma 1.05), a fuller emerald
    that is vivid next to the lime.
  - Sage has less blue than before, so it reads as a cool green, not grey.
  - High ground still turns to tundra and steep turf to olive. Sand, rock
    and water are untouched.
- **Old regions:** the round-5 blotches are kept at 0.8 inside an area (it
  was 0.6), by its weight (`EP_REGION_UNDER`). At 0.6 they pulled the
  bright lime blotches out of the quieter areas and added to the muting.
  In lime they are unchanged.
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
  `area_edge`, a `tint_check` binding for parity; ZenScapeGrass version
  3 -> 4 -> 5 with the retune)
- `scripts/endless/endless_grass.gd` (flag, `_set_areas`, `NATIVE_VERSION` 5,
  plumbing)

**The native kernels were rebuilt on this Windows PC (debug and release).**
The binaries are git-ignored, so:
- **The Mac needs its own rebuild.**
- **Main's checkout needs this build copied in or rebuilt.**

A library older than version 5 makes `_set_areas` turn the areas off
everywhere (ground and tufts together) with a push_warning. You get the old
look, not a mismatch.

## Proof

- Smoke: `python tools/smoke.py studies/endless_flight.tscn`. PASS, 0 errors.
  It also passed with `--world=amberlands` in round 1.
- Stills, before (`--grass-areas=0`) and after, same build:
  - Retune: `scratch/colour/before2/` and `scratch/colour/after2/`.
  - Side-by-side sheets:
    - `scratch/colour/pair2_low.png`: 6 m up, inside lime, lush, sage and
      amber.
    - `scratch/colour/pair2_cruise.png`: the same at 45 m.
    - `scratch/colour/pair2_stock.png`: the stock meadow_low and cruise, a
      lush/sage border, the second amber spot.
  - Round 1's sheets are `scratch/colour/pair_*.png`.
  - The views are in `scratch/colour_views.gd`.
- What the stills show:
  - Lime is pixel-for-pixel today's look.
  - Lush turns a vivid even emerald. Before, the same ground had olive and
    yellow blotches.
  - Sage is a calm cool green, close to before and a little cooler.
  - Amber is a golden straw meadow.
  - The tufts fade into the paint with no hue seam.
  - In `lush_low` the far arches differ between the two runs. That is the
    streaming state at capture, not the colour.
- Map: `scratch/colour/area_key2.png` is the retuned key over 24 km of seed 1
  (red = spawn, bar = 1 km); round 1's key is `area_key.png`. The script is
  `scratch/area_map.gd` (`--mode=key`).
- Native vs GDScript tints, a real comparison now:
  - `scratch/area_parity.gd` runs in the game scene and calls the new
    ZenScapeGrass `tint_check` (the configured patch's `tint`) against
    `EndlessPatch.tint`.
  - It covers 3721 points crossing all four areas and their borders, with
    varied meadow, height, slope and vertex hue.
  - Result on the final build: worst channel difference 0.000001. PASS.
  - Round 1's buffer comparison compared nothing and is dropped.

## Frame time

Unchanged within noise. Measured with look_views `--time=240`, two runs
each, median wall / GPU ms.

Retune (final build):

| view | areas off | areas on |
|---|---|---|
| meadow_low | 7.84 / 7.77, 7.70 / 7.65 | 7.77 / 7.72, 7.77 / 7.69 |
| cruise | 8.11 / 8.06, 8.17 / 8.13 | 8.27 / 8.22, 8.09 / 8.04 |

Round 1:

| view | areas off | areas on |
|---|---|---|
| meadow_low | 7.72, 7.68 | 7.66, 7.68 |
| cruise | 8.13, 8.04 | 8.10, 8.09 |

## Tests

No committed test reads the region or patch code (grepped `tests/`), so none
are known to break. The full suite was not run.

## Not verified

- The Mac build.
- The Amberlands and doors gating was not rendered (it is code-checked only).
- A hand-flown look. From 480 m in the haze the areas are subtle: the
  kilometre change shows most from cruise height and below.
- Sage is still the quietest area by design. Its exact greenness is a
  judgement call for the user.
- Round 1's `border_la` view is blocked by a mountain, so it shows nothing
  useful.
