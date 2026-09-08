# Redwood Grove

Choose **Landscapes → Redwood Grove** in the game toolbar. The existing variation action generates another arrangement; the **Redwood forest** biome can also dress other landscape shapes.

The preset generates gently rolling native faceted terrain, tall redwoods, ferns, grass, rocks, mushrooms and fallen logs. A loose clearing through the trees leaves room to build. Trees and undergrowth remain normal selectable objects: move, resize, delete, undo, and save them. Individual **Redwood** and **Fern** pieces are available in the Build palette.

Forest-floor volumetric mist follows the sculpted terrain and local redwood cover. Removing trees changes its coverage. The existing fog and ray controls adjust it, and its animation follows the scene clock. Native mist requires Forward+ rendering. Switching out of the redwood biome restores the ordinary atmosphere.

Selecting Redwood Grove applies the demonstrated Golden Meadow lighting, clear weather, 0.45 mist and full ray strength. Other world presets also apply their authored moods. The camera and graphics quality remain under player control. One Undo restores terrain and atmosphere together; changing only the biome, water treatment or variation preserves a customized mood. The grove uses the current single-biome landscape workflow; regional biome painting and blending are outside this addition.

![Generated grove](overview.png)
![Inside the grove](inside.png)

## Validation

- `tests/test_redwood_grove.gd`: native Forward+ run passed; generation, selectable palette assets, moving/scaling, undo/redo, tree removal and mist coverage, sculpted height-map binding, disk save/load, fog control, biome exit and variation.
- `tests/test_landscape_presets.gd`: all eight landscape presets, biome combinations, history, document loading and gallery previews passed.
- `tests/test_native_play_collisions.gd`: existing collision regression suite passed.
- `tests/test_conifer_wind.gd`: native GPU checks passed for rooted trunks, crown deformation, world direction, calm and frozen clocks.
- `tools/capture_redwood_grove.gd`: renders the actual game scene and generates the gallery thumbnail. Seed 37 contains 51 redwoods; native mist was active during capture.

Headless runs emitted sandbox log/certificate warnings and shutdown object-leak warnings. The native grove and GPU wind checks completed without script or renderer errors.
