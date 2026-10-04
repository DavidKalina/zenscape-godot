# Opal cloud sea: ocean and mountain peeks

Built in `shaders/sky_cloud_sea_opal.gdshaderinc`; `tools/capture_backdrop.gd` gains `--yaws=A,B` (extra overviews turned by those radians, `yawN-HHMM.png`).

## What it does
- Ocean: inside the rifts, a broad mask (`SEA_OCEAN`: scale 0.3 per depth, threshold 0.5) turns the land to sea: pale shore, deep hazed blue farther out, a soft coast, and a glint toward the sun (moon at night), veiled like the land.
- Peaks: five analytic cones (`zs_opal_sea_peak`), found per ray with a chord test then a 16-step march and a linear refine. Heights carry unsmoothed value noise so they read as flat facets. Snow caps on the two tall ones, bare blue-grey rock on the rest, Lambert from the sun (moon at night), distance haze with extra on the shade side, and a cloud-lost foot.
- Night: peaks are composited outside the night's pulled-down veil and lifted (level x 2.4), so they read as dim silver.
- Distance: the user asked for them further out; they sit at 1.7 to 2.3 depths with radii about 0.2 to 0.27 and heights 0.37 to 0.52.

## Stills (all /private/tmp/zs-opal-peeks)
- r0: baseline. r8/yaw0-1000.png: default overview 10:00, ocean at right, peak at top right.
- r3/yaw3-1000.png: ocean patches and a rocky peak (peaks were nearer, before pushing out).
- r4/yaw0-1740.png: golden hour, peaks at the bottom corners.
- r6/yaw1-2300.png: night, dim silver peak at left. r6/overview-1000-overcast.png: overcast.

## Weaknesses
- In the steep default overview a peak sits at the screen edge at only some turns; in low views peaks nearly leave the screen (a peak's top must be below dir.y about -0.12 to survive the veil, and steep views only see dir.y below about -0.3).
- Silhouette edges are marched, not antialiased; haze hides it.
- Positions are fixed in room space, not seeded.
- Rift roundness and quilted puffs were not touched.
- Cost: peaks are rejected by the chord test for most pixels (at most about 5 cheap tests, 16-step march only inside a peak's chord). Ocean adds about 6 noise taps inside open rifts only. At night the sea shading now also runs in the band the veil used to skip.
