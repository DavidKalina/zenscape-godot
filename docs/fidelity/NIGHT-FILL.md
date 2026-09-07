# Readable night lighting

The native landscape now receives a cool hemispherical fill after dark. At the
normal camera distance, the arch, forest layers and waterfall remain readable
under the aurora instead of merging into a nearly black silhouette.

**Night fill · landscape visibility** controls the strength from 0 to 1.5, with
1 as the default. Zero restores the previous source-derived surface ambient.
The adjustment follows the existing night envelope, fades out by daylight,
and is reduced during storms. It changes shared surface hemisphere colors and
energy, preserving the sky, cloud, fog and directional-light color calculations.
Explicit slider changes work while paused.

This is an intentional native art-direction adjustment, not physical moonlight
calibration or an exact source match. It introduces no extra lights or shadows.

`tests/test_night_fill.gd` checks unchanged daytime and sky/directional state,
additional night surface fill, and changes while paused. The three-second
`night-fill-comparison.mp4` places the new fill on the left and zero fill on the
right at the same normal landscape camera, aurora mood and animation times.

Capture with `tools/film_night_fill.gd`, normal scene flags `--clean --mood=2`,
`--fixed-fps 30`, `--film-frames=90`, and a unique `--film-dir`. Add `--control`
for the zero-fill reel.
