# Endless flight: silvery undersides the wind flips (prototype round)

Grass blades now have a pale silvery-sage underside, and the breeze's waves and gusts turn it into view. Soft silver swells roll downwind across the meadows. They show on the near tufts, the far tuft ring and the painted ground past them, all reading one field, so no ring shows where one tier hands over to the next. At rest little shows. Colour regions, flowers and drifts are unchanged.

## What changed

- **`shaders/grass_silver.gdshaderinc` (new)** holds the field and the paint:
  - `zs_silver_drive(p, fp)`: three wave trains of crests rolling downwind on the air's travel (`zs_wave_crest_at`): the tufts' 9 m ones and the ground's 22 m and 60 m ones. The slow gust bands (`zs_gust_band_at`) and the breeze strength swell or calm them, and gust fronts lift them. Each train fades to its mean once a pixel (`fp` m) outgrows it, so from cruise height the long swells roll and nothing shimmers.
  - `zs_silver_tuft`: the same, plus anything that bows a tuft past the usual (`grass_bow`), so the other lane's wash and parting should flip it too.
  - `zs_silver_paint`: the underside colour, which keeps some of the blade's own hue (`grass_silver_keep`).
  - `zs_silver_side`: a two-sided look from screen derivatives (the blade face turned downwind reads as its back).
  - All of it is opt-in. `grass_silver.x == 0`, the default, adds no cost and changes nothing, so the isles and motifs build as before.
- **Hooks**, one guarded line each plus the include:
  - `reference_surface.gdshader` (tufts): after the root paint, before the wet/gust tint.
  - `endless_tuft_far.gdshader` (far tufts): per vertex at the root, with one new varying; the shader also now includes `reference_wind`.
  - `endless_ground.gdshader` (paint): before the flower drifts.
  - None of the existing sheen lines were edited.
- **No doubling.** With silver on, `endless_grass.gd` cuts the old bow paling through uniforms only: the tufts' `grass_wave_sheen` goes from 0.55 to 0.2 and the paint's `wind_sheen` from 1 to 0.45.
- **No twist in the mesh.** The tuft mesh carries no blade frame, and reference_surface is at Metal's 31-varying limit. The "twist" is therefore shading only.

## Flags and knobs (`scripts/endless/endless_grass.gd`)

- `--grass-silver=X`: strength, default 0.8.
- `--no-grass-silver`: off, for A/B. It matches main exactly.
- Other constants:
  - SILVER_BOW (0.25, 1.25): the drive over which the underside comes into view.
  - SILVER_LIFT (near 1.9, far 1.5, paint 1.25): how much brighter the underside reads.
  - SILVER_KEEP (0.45, 0.55, 0.7): how much of the tier's own colour it keeps.
- By hand: `--grass-set=` / `--far-set=` / `--ground-set=` with `grass_silver_colour`, `grass_silver_keep`, `grass_silver_waves` and `grass_silver_share`. `EndlessGrass.set_silver(s)` toggles it live, for A/B in one run.
- Launch: `./run-endless-flight.command` (silver on by default); A/B with `./run-endless-flight.command --no-grass-silver`.

## Cost

- At native resolution the frame stays under the display's ~145 Hz cap (6.9 ms) both on and off, so there is no measurable difference.
- At 2x render scale, so the GPU is the limit, it adds 4 to 5.5 ms on a ~102 ms frame (+4 to 5 %), at about the same share from on foot to 14 m up (scratch driver, alternated 3x).
- Most of it is likely the per-pixel field on the near tufts (4 noises and 3 crests). If it matters, a cheaper path is fewer trains on the tufts.

## Captures (captures/grass-silver/, git-ignored)

- `pair_<view>.png`: on (top) against off (bottom), same frame. Views:
  - `foot`: 1.7 m
  - `low`: 4 m
  - `mid`: 14 m
  - `down`: 70 m, looking down 50 degrees
  - `cruise`: 70 m, looking down 24 degrees
- `silver_low.gif`, `silver_down.gif` and `strip_*_sheet.png`: 16 frames, 8 apart, showing the swells travelling.

## Left / unverified

- Live play in a window. The motion was judged from strips only.
- Seen top-down from cruise, the swells can read a little like pale frost. Raise the paint's SILVER_KEEP or lower its lift if the user finds that.
- The field is soft swells rather than crisp bands. More weight on the 9 m train (`grass_silver_share`) gives crisper near bands.
- Tests: test_breeze, test_ground_look, test_pilot_wake and test_sky_peak_look pass. None were found reading these lines. test_aqueduct_isle_look was failing before this round.
