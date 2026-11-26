# Meadow tone

The lime came from the grass colour itself: the ramp/MEADOW greens, the warm drift (1.32,1.05,0.62) and the lime/straw regions all push it yellow, and the tufts carry the same. One pull now sits on the final grass colour in `zs_meadow_tone` (shaders/distance_read.gdshaderinc), called in three places: the ground's grass (before the flower drifts, endless_ground.gdshader), near tufts (reference_surface `grass_blades`) and far tufts (endless_tuft_far). Saturation x0.8 (0.68 in the study; the user chose 0.8), red -0.2 (blue +0.12), value x0.88 (constants MEADOW_* in scripts/endless/distance_read.gd, global `zs_meadow`).

Knob: `--meadow-tone=X` (0 the old look, 1 default). Fine: `--meadow-sat=`, `--meadow-yellow=`, `--meadow-value=`. Isles are unaffected (global defaults to 0).

Grass sat/hue/val (mean over grass-ish pixels, tone 0 -> 1): meadow_low .50/63.5/.53 -> .39/67.7/.49; cruise .43/63/.67 -> .32/70/.62; coast .61/68.6/.65 -> .44/74/.60; hilltop .49/58.6/.42 -> .38/65/.38.

Sheets (old left, new right; in scratch/, git-ignored): sheet_default.png (6 views), sheet_h125, sheet_h185, sheet_golden (6 views each), sheet_morn, sheet_rain (3 views).
Forest frame time 50.0 vs 49.7 ms (tone 0 vs 1), unchanged. Smoke passes.
Tests: none read these colours (test_ground_look and test_sky_peak_look only check reference_surface includes and varyings).
