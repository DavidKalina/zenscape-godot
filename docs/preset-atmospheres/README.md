# Authored world atmospheres

Selecting a landscape applies its own lighting, weather, fog, rays and surface state. Player camera and quality settings are preserved. Biome-only edits, water changes and another variation keep the player's customized mood. Undo/redo restores terrain and atmosphere together.

| World | Direction | Mist | Haze | Rays | Wind |
|---|---|---:|---:|---:|---:|
| Redwood Grove | Existing golden forest treatment | .45 | .16 | 1.00 | .40 |
| Riverfold valley | Fresh, warm morning with cool shadows | .22 | .10 | .25 | .28 |
| Skywater plateau | Clear mountain light and pale blue air | .18 | .13 | .40 | .48 |
| Sleeping volcano | Rose dusk with lavender shadows | .08 | .12 | .15 | .22 |
| Emerald ridgeback | Cool greens, brighter shadow detail, breaking cloud | .40 | .13 | 1.00 | .30 |
| Silverhorn tarn | Cold dawn, peach sunlight and nearly still air | .14 | .07 | .30 | .12 |
| Sunstone canyon | Late-afternoon sandstone, dry air | .03 | .17 | .12 | .35 |
| Jade terraces | Clearing after rain, damp stone and gentle air | .30 | .12 | .65 | .22 |

Values are existing editor control units, not physical units. See `scripts/native_landscape_presets.gd` for complete authored recipes. World overrides extend `scripts/scene_look_presets.gd` without mutating the standalone Looks gallery recipes. Jade terraces starts with damp surfaces and no permanent rainbow; no new weather event scheduler was added.

This pass tunes existing atmosphere rendering. It does not add new localized fog volumes or ray-tracing passes; Redwood retains its existing terrain-following native volume. Fog and rays depend on light direction, camera angle and available occlusion and remain subtle from the overview camera.

## Native previews

The seven PNGs here and corresponding `assets/landscapes` thumbnails were rendered using `tools/capture_preset_atmospheres.gd` through the actual diorama scene, normal game viewport, Forward+ and Beauty quality. The player selection path applies the mood; the capture tool does not supply separate lighting overrides. The original previews in `docs/landscapes` remain historical evidence.

## Validation

- `tests/test_landscape_presets.gd`: all eight presets pass generation, specialized colors/time/clouds/mist/rays, saved atmosphere restoration, terrain history, world mood undo/redo, variation and biome preservation, and gallery checks.
- `tests/test_curated_looks.gd` (removed): standalone Looks gallery, undo/redo and saved look restoration pass.
- All seven native captures completed without script or rendering errors and were visually inspected.

Headless runs emit sandbox log/certificate warnings and shutdown object-leak warnings; both suites reported zero failures.
