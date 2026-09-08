# Coherent scene wind

Atmospheric wind now bends the existing swaying vegetation in world space.
Random asset yaw no longer turns the wind response sideways. Vertical instance
scale retains the authored relative bend, while roots remain anchored.

The shared water helpers now include traveling atmospheric parcels alongside
local gusts. Ponds, waterfall spray, and falls receive the passing gust without
needing a wind-playground emitter. The visual benchmark's planar pools use the
same ripple normals. Its low mist follows integrated air travel and thins gently
where a parcel passes. Existing loose leaves already sample these parcels.

This connects existing responses; it does not add sway to rigid tree assets.
The benchmark mist and planar reflections remain benchmark-specific.

## Comparison

`comparison.mp4`: current foliage/mist/planar water LEFT, their previous shaders
RIGHT. Same camera, wind strength 1.3, +X direction, and gust at 0.5 seconds.
Each reel lasts eight seconds at 24 FPS. Decorative wind trails are hidden in
both halves to remove their independently randomized motion. Leaves and shared
waterfall helpers use the current implementation in both halves.

The earlier three shader sources are retained in `control/` for reproduction
with `tools/film_scene_wind.gd`. The tool swaps shader source in memory; it does
not rewrite the working shaders. Native Forward+ is required for this footage.

## Validation

- `tests/test_scene_wind_direction.gd`: GPU render verifies atmospheric bending
  remains aligned across rotated and scaled instances.
- `tests/test_local_wind_water.gd`: GPU checks local gusts, atmospheric parcel
  drift and expiry, shoreline/impact anchoring, and ice suppression.
- `tests/test_wind.gd`: wind strength, travel, and pause regression.
- `tests/test_wind_leaf_litter.gd`: loose leaf behavior regression.

All passed on Godot 4.7.2 / Apple M5 Pro / Metal. Native comparison recording
also compiled and exercised the changed foliage, fog, and reflection shaders.
