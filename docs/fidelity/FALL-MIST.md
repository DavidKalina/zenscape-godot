# Source waterfall mist

Replaced the native 20-billboard approximation and additional 96 ballistic
spheres with the original scene's 37 point sprites. `export_fall_mist.mjs`
exports their origins, velocities, phases, sizes and rise coefficient from
waterfall.js. They follow its .16 phase rate, eased rise, outward drift, shared
wind/gust field, point-size projection, growth gate and night/freeze opacity.
Full freeze leaves 10% of the source mist opacity; it does not kill the cloud.

`fall_mist.gd` and `reference_mist_display.gdshader` project the particles and
composite them in display space before the air/UI layers. Opaque scene depth
clips each sprite at its center depth, as with the original GL point sprites.
The shared depth texture carries MSAA edge coverage. The default atmosphere
shares its depth pass; the native-fog debug path creates a depth-only compositor.
The mist is updated from the same paused motion clock as the other scene systems.

An initial spatial-material port was rejected visually: inverse-tonemapped
near-white particles blended in HDR made an excessive cyan glow. Keeping source
color and opacity in the display pass avoids this without arbitrary dimming.

Validation:
- `test_fall_mist.gd`: actual GPU alpha across 18 freeze/daylight/growth cases;
  projected center against source phase/velocity; an opaque plane alternately
  in front of and behind the mist proves depth clipping.
- `test_fidelity.gd`: source particle count, shared pause clock, scene checks;
  no renderer errors after correcting the depth texture's shutdown binding.
- `frozen-mist-comparison.mp4`: current left, previous right, 60 frames at 30fps;
  same full-freeze initialization and lake camera as ICE-LIGHTING.md. Frame 30
  inspected: solid bright droplets removed, native lake remains visible through
  the source mist. Compared with the source still `lake-ice-source.png`.

Remaining: matched open-water/gust motion footage, scene-wide transparent-depth
interaction and exact integration with atmospheric overlays. The sampled
source cloud is seed-specific; generation for arbitrary worlds remains separate.
