# Far lawn and a patchwork-free high paint: handoff

From high up the meadows showed hard-edged rectangles, straight stripes and
arcs. This round (1) ports the clean look's round 8 far lawn, and only that,
and (2) replaces the lattice noise behind the high-up paint with smooth fields.
The rest of the clean look (commit `1b734795`, reverted in `0abaadf6`) stays
reverted.

## A. The far lawn (ported from `1b734795`)

- `assets/textures/far_turf.png` (+ `.import`), `tools/bake_turf.gd`: as they
  were (the bake of the game's own soft tuft seen from above; not re-baked).
- `shaders/far_lawn.gdshaderinc`: as it was, with two changes: it no longer
  takes the clean look's `warm` tint (the function never used it) and `cool`
  is passed in. The ground passes `zs_cool(vec3(0.93, 0.90, 1.02), paint_follow)`,
  so the shade tint follows the light as the rest of the ground paint does.
  Nothing else of `clean_look.gdshaderinc` / `sheen_s` is brought back.
- `scripts/endless/grass_sheen.gd`: `LAWN`, `NAP`, `LAWN_RING` (140..230 m of
  ring distance), `LAWN_TILES`, `LAWN_TEXTURE`; `--lawn=X` (0 off), `--nap=X`.
- `shaders/endless_ground.gdshader`: `#include far_lawn`, and the hook inside
  the sheen block after the sheen's tone, fed by today's `zs_sheen_field` (the
  field is now computed once into `sheen_s`). The lawn is gated by `carpet_turf`
  and `(1 - 0.6 thin)`, not by the sheen's `(1 - 0.85 wc_up)`, so it reads from
  high up. 4 texture fetches per far grass pixel.
- From high up ring distance is at least the eye's height (`ring_lead.z`), so
  the lawn is at full from about 230 m up and over the whole high view; at
  cruise (45 m up) it comes in at 140..230 m of ring distance, past the tufts.

## B. The high-up paint

Two lattice-noise layers of the high paint (`high_up`, 20..75 m of height) made
the patchwork. Both rebuilt in `endless_ground.gdshader`:

- **Streaks**: five plane waves in the wind frame (long along, 6 to 21 m across,
  a little tilted so crests merge), their lines bent by two slow swings of up to
  +-11 m (slope under 0.2, no folds). Same amplitude (0.30 x std ~0.15).
- **Washes**: `f1` / `f2` from `zs_wave_fbm` (`shaders/smooth_wave_field.gdshaderinc`:
  five plane waves at golden-angle steps, two octaves, same mean and spread as the
  value-noise blend) under a gentle warp (`* 1.2` of a +-0.5 field, against 2.6
  and 0.9 of value noise, which folded the lattice by more than a cell). The wet
  edge's width is 0.09 (was 0.05), so the contour lines are soft ridges, not arcs.
  Thresholds, pigments, crown and pool are unchanged.
- **Silver undersides** (found while bisecting; the brief had ruled out the sheen,
  this is a different layer, `grass_silver`, on by default at 0.8): the paint's
  `zs_silver_drive` bends its crests by lattice noise up to 3.6 rad
  (`zs_wave_crest_at`) and thresholds lattice noise for the gust band
  (`zs_gust_band_at`), so its ribbons broke into small diagonal blocks. They
  were the small blocks left once the washes were smooth, visible with `--lawn=0`
  (the lawn's grain hides them). `zs_silver_drive_smooth` (same shape, same share,
  the plane-wave bend and `zs_sheen_band` from the sheen) replaces it on the
  paint, blended in by `wc_up`, so near the ground the paint still matches the
  tufts' silver and from high up it is smooth. The far tufts
  (`endless_tuft_far.gdshader`) still use the lattice drive; they are 3D tufts,
  not the patchwork.
- Untouched: `zs_noise`, `ep_noise`, the patches' `broad/wide/mid`, the sheen files.

## Flags (A/B)

- `--lawn=0`: no lawn. `--nap=0`: lawn without the nap and sheen.
- `--high-paint=old`: the old streaks, washes and silver drive (lattice noise).
  `--lawn=0 --high-paint=old` is pixel-identical to the base commit (`high`:
  mean abs diff 0.002 / 255 against the before still).
- Add `--no-grass-silver` to see the paint without any silver.

## Stills (git-ignored, `scratch/lawn/`)

Run each view as the only view of its run, `python tools/drive.py
tools/harness/look_views.gd --rendered -- --out=DIR --views=high --full-size
--scene-args --no-title [flags]`. Crops are (600,300)-(1100,620) of `high`,
contrast-boosted (`scratch/lawn/crop.py`).

- Before: `scratch/lawn/before/{high,cruise,wood,hills,meadow_low}.png`, `*_crop.png`
- After: `scratch/lawn/after/` (same names)
- Side by side, before left, after right: `scratch/lawn/cmp_<view>.png`,
  `cmp_<view>_crop.png`
- High, lawn off + new paint: `scratch/lawn/l0s2/high_crop.png`; lawn off + old
  paint: `scratch/lawn/old/`; lawn on + old paint: `scratch/lawn/a1/high.png`
- Dive 260 to 30 m (`scratch/lawn/dive.gd`): `scratch/lawn/dive/dive_<m>.png`,
  `sheet.png`; the same with `--lawn=0 --high-paint=old`: `dive_off/`;
  `dive_ab.png` (200, 150, 110 m, old left, new right).

What the stills show: `high` has no rectangles, straight stripes or arcs left,
the broad light and dark and the warm and cool drifts stay, and the far grass
reads as a fine grain with the wind's light bands; cruise, wood, hills and
meadow_low are close to unchanged (they are tuft territory). In the dive the
lawn and the paint hand over to the tufts with no new line; the edge of the
tuft ring against the paint (a lighter, more yellow ring from 150 to 110 m) was
there before and is unchanged. The old dive shows the mosaic of washes at 200 m.

## Frame time

`look_views.gd --time=240` (RTX 4070 SUPER class GPU, the harness's 0.75 3D
scale; median ms, GPU / wall), base commit shader first, repeated at the end:

| view | before | after (default) | lawn=0 | old paint, lawn=0 | before again |
| --- | --- | --- | --- | --- | --- |
| high | 4.74 / 4.79 | 4.71 / 4.76 | 4.77 / 4.83 | 4.74 / 4.79 | 4.73 / 4.78 |
| cruise | 7.62 / 7.68 | 7.62 / 7.73 | 7.67 / 7.73 | 7.88 / 7.94 | 7.89 / 7.96 |
| wood | 7.58 / 7.63 | 7.34 / 7.39 | 7.49 / 7.55 | 7.72 / 7.77 | 7.81 / 7.87 |

All inside run-to-run noise (cruise and wood move 0.3 ms between the two
"before" runs); no measurable cost. The smooth fields' sines are paid for by the
value noise they replace.

## Smoke

`python tools/smoke.py studies/endless_flight.tscn --frames 400`: PASS, 0 errors.
No tests were run or added (prototype round).

## Doubts

- The lawn and the smooth paint read a little deeper green and darker than
  before at `high` (luma 0.446 to 0.440 over the crop; the lawn's gaps and
  micro shadows). The clean look measured V -0.03 at high. Say if it should lift.
- The silver ribbons are now continuous: with `--lawn=0` they read as soft wavy
  pale bands from high up (the lawn mostly covers them). If they read as water,
  fade `zs_silver_drive_smooth` with height (`wc_up`) rather than blend it.
- The stripes are still soft diagonal bands by design ("combed"), now bending.
- `bloom` soft patches (`ep_bloom`, a lattice) still show an L-shaped orange
  patch in one spot of the `high` crop; not part of this ask.
- Not exercised: night and dusk looks, other worlds' profiles (`regions`,
  `test_dry` set `wc_paint` differently), the lawn's seams on very steep ground
  (it is gated by `carpet_turf`).
- Frame times are from one machine and the harness's own scale.
