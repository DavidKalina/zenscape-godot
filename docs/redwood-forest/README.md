# Redwood morning

A standalone art study with 113 tall faceted redwoods, a high canopy, ferns,
fallen wood, and a narrow natural opening toward warm morning light.

Run `run-redwood-forest.command` with native Forward+. Drag to orbit, scroll to
move closer, P to pause, M to compare the stronger floor mist with the original,
F8 to compare without atmosphere, and Esc to exit.
This is a separate composition; it does not replace the editable diorama.

The god rays are directional sunlight scattering through native volumetric fog,
with tree geometry casting shadows into it. A low ground layer uses upward
noise advection and altitude-dependent fading: patches rise, thin, and dissolve
instead of lifting a flat fog sheet. A lighter haze above the ground lets the
shafts remain visible through the trunks. This suggests evaporation visually;
it is not a moisture or temperature simulation.

The floor-mist pass concentrates irregular pockets beside the winding path.
Most density fades within two world units of the ground, with rising wisps
dissolving by 2.7. The path retains 22% of the pocket density, leaving breaks in
the mist. Upper haze and the light settings remain unchanged.

`floor-mist.mp4` shows the updated forest; `floor-mist-comparison.mp4` shows new
floor mist LEFT and the previous mist RIGHT, with god rays enabled on both sides.
The eight-second, 24 FPS reels use a fixed 1440×900 offscreen viewport, identical
camera motion and clocks. Reproduce with `tools/film_redwood_floor_mist.gd`.

`hero.png` shows the finished view. `comparison.mp4` shows atmosphere LEFT and
the same forest without it RIGHT. Both reels use the same gentle camera move,
eight seconds at 24 FPS. `morning.mp4` is the full-width atmosphere reel.
Reproduce with `tools/film_redwood_forest.gd`.

`tests/test_redwood_forest.gd` verifies scene construction, upward-facing ground,
shadow-casting light, pause/resume, camera validity, and the atmosphere toggle.
The native Metal film also exercises shader compilation and volumetric rendering.
Tree and fern meshes are deliberately simple study assets, not final botanical
models. This dense study has not yet been performance-tuned.
