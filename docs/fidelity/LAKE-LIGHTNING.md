# Lightning on the lake

The collected lake lighting now includes the original weather.js point light
before tone mapping, sky reflection and glints. Its source parameters are color
`d8e8ff`, intensity `900 * flash`, cutoff 160 and decay 1.6. The attenuation comes
from the installed Three `lights_pars_begin` physical point-light function.
`zs_flash` supplies the existing strike position and pulse amplitude, so pause,
repeated pulses and decay follow the scene's lightning clock.

The lake's native light processor now suppresses all native light contributions
when collected lighting is active, preventing a second flash after reflections.
Streams and other surfaces retain their existing native light path.

## Evidence

- Native `test_lake_flash.gd` compares the collected source contribution against
  an actual unshadowed OmniLight3D with equivalent irradiance at distances 8,
  30, 80 and 160, and amplitudes 0, .3 and 1. All twelve cases pass with RGB
  vector error below .015, including the distance cutoff.
- Native `test_lightning.gd` passes pulses, pause, downburst, thunder and storm
  scheduling.
- `lake-lightning-response.mp4`: storm preset, manual strike, no fog,
  camera `8,.55,1.9,6.2,.38,-3.4`, 60 fixed frames at 30 fps. Frames 2 and 59
  inspected: the lake brightens under the pulse and settles as it decays. This
  is a response demonstration, not a matched source/control fidelity reel.
- The short filmed run reported two ObjectDB instances leaked on exit; the
  separate lifecycle test completed successfully. Capture-exit cleanup remains
  to investigate if it recurs.

## Remaining scope

Whole-scene native illumination now uses source 900 irradiance and no bolt
shadows; see `SCENE-LIGHTNING.md`. Full matched source storm footage remains. This pass corrects the lake contribution
and its reflection ordering; transparency, fog depth and ice detail remain open.
