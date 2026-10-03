# Wind-driven leaf litter

Small folded leaves collect beneath broadleaf trees and shrubs. Calm air leaves
them settled; stronger wind slides them along the ground, and traveling gusts
lift them into a short flutter before they settle against the terrain slope.
They sample the existing atmospheric gusts and the wind playground's local field.

The fidelity scene and its inherited dioramas include the effect. In the visual
benchmark, press G to send a gust through the camera target and P to pause.
Population is capped at 96 leaves in one MultiMesh. Terrain/content revisions
reseed the cosmetic litter; leaves are not saved. Missing ground and pond basins
are excluded. Contact follows the ground surface, without object collisions.

## Evidence

`comparison.mp4` shows the gust on the left and calm air on the right. Both
start with the same leaves and camera. The gust begins at 0.5 seconds; the
seven-second clip was rendered at 24 FPS. The recording observed 454 airborne
leaf-frames with the gust and zero in the control, with 70 leaves in each.

Reproduce with Godot's native Forward+ renderer and
`--path . --script res://tools/film_leaf_litter.gd` (removed). Frames are written to
`/private/tmp/zs-leaf-gust` and `/private/tmp/zs-leaf-control`.

## Validation

Headless checks passed:

- `tests/test_wind_leaf_litter.gd`: calm rest, shared gust lift and downwind
  travel, pause, settling, slope alignment, missing ground, and population cap.
- `tests/test_weather_wind_trails.gd`: existing atmospheric wind regression.
- `tests/test_local_wind_field.gd`: local field behavior and CPU/GPU parity.

Native benchmark startup and the recorded close-up also exercised the scene
integration. The population cap bounds the work; this change has not been
separately profiled for GPU or CPU cost.
