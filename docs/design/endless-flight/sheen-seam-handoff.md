# Sheen seams: handoff

The wind sheen (`shaders/grass_sheen.gdshaderinc`, one field for the painted
ground and the far tufts) showed hard, straight, often vertical seams, sheened
grass on one side and trough grass on the other, from some bearings to the wind.

## Cause

Two things, both lattice noise (`zs_noise`, a square grid in the wind's frame):

1. `zs_sheen_crest` bent each band's phase by `(noise - 0.5) * 7.0` (up to
   +-3.5 rad) on a lattice about 22 m by 64 m. At 7 rad the band shifts nearly a
   wavelength across one cell, so the cell edges show as straight seams, aligned
   with the wind. Setting the 7.0 to 0 removed them, but left regular diagonal
   stripes, so the bending is wanted.
2. `zs_gust_band_at` (`reference_wind.gdshaderinc`) thresholds lattice noise
   (`smoothstep(0.42, 0.8, ...)`, 28 m by 18 m cells) and multiplies the whole
   swell strength. With the crest fixed, the seam that was left in the cruise
   view was this one (forcing the band to 1.0 removed it). Gust fronts were not
   a cause.

## Fix (sheen files only)

- `zs_sheen_crest`: the bend is three slow plane waves across the wind, at
  unrelated angles (36, -33, 17 degrees) and scales (3.2, 2.2 and 4.5 crest
  lengths), amplitudes 0.9, 0.7 and 0.5 rad (`ZS_SHEEN_BEND`), each train's
  `offset` shifting their phases. Sums of sines have no cells, so no straight
  seam; a band bends by at most about 35 degrees and never shifts more than
  about a quarter wavelength over a short distance.
- `zs_sheen_band` (new, replaces `zs_gust_band_at` inside `zs_sheen_field` only):
  the same 0.6..1.5 range and a similar size, from three plane waves rolling
  downwind with the air. `zs_gust_band_at` itself, `zs_noise` and the near tufts'
  sway are unchanged.
- Both the ground and the far tufts call `zs_sheen_field`, so they still read one
  field. Cost: about 15 sins per pixel against about 20 before (each `zs_noise`
  is four hash sins), so a little cheaper.

Tuning knobs: `ZS_SHEEN_BEND` (more wander), the wavelength factors in
`zs_sheen_crest` (0.31, 0.45, 0.22), the smoothstep in `zs_sheen_band`.

## Proof (rendered stills, 1440x900, `look_views.gd`, seed 1)

Views: cruise, wood, meadow_low, hills, high, sun_toward, sun_away, sun_side.
All in `scratch/sheen/` (git-ignored):

- before, `--sheen=3`: `scratch/sheen/before3/<view>.png`
- after, `--sheen=3`: `scratch/sheen/after3/<view>.png`
- before, default strength: `scratch/sheen/before_def/<view>.png`
- after, default strength: `scratch/sheen/after_def/<view>.png`
- sheen off: `scratch/sheen/off/<view>.png`
- difference against off (sheen field alone, before left, after right):
  `scratch/sheen/d1.png` (cruise, sun_side, wood), `scratch/sheen/d2.png`
  (meadow_low, high, sun_toward, sun_away)

The before cruise still has the sharp edge near x 460-500, y 560-700; the after
still does not, and no view shows a straight seam in the difference images.
Smoke: `python tools/smoke.py studies/endless_flight.tscn --frames 400` passes.

## Doubts

- Judged by eye on stills; the swells move, so a moving check in play is worth a
  look (the bands should roll downwind, wandering, with no popping).
- The sheen's gust band no longer matches `zs_gust_band_at` cell for cell (the
  near tufts' sway still uses the noise one); they are the same size and range,
  so the swell carries on from the tufts' sway in character, not in position.
- The bend now has a little less wander than before (up to 2.1 rad peak, against 7 peak to peak);
  raise `ZS_SHEEN_BEND` for more.
