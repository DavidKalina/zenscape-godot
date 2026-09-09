# Living fog atmosphere experiment

Run `./run-living-fog.command`. The inland visual lab has a persistent native Godot FogVolume with **on/off, density, bank height, and wind** controls.

The fog drifts, billows, expands and breaks into patches under the shared world wind. It uses the same moving gust field as foliage and water. Integrated wind travel keeps the pattern continuous when wind speed changes. Terrain, habitats and all nine moods remain available.

This is an atmosphere effect only. There are no text inputs, typing signals, journal mechanics, or writing-driven reveal modes.

The effect takes inspiration from the Electron fogbank's gust-shaped openings and drifting remnants. It does not port the original chunk-presence lifecycle. This remains a disposable visual experiment requiring Godot Forward+.

`tools/prototype_capture_living_fog.gd` captures calm/windy fog and verifies that the terrain snapshot remains unchanged. Inspect movement in the running lab; still images cannot demonstrate the timing.

Wind startup regression: the inherited mountain study paused the shared world clock, so the original demo did not advect fog or respond to the wind slider. Living fog now explicitly starts the clock. The native capture checks nonzero air travel at startup and increased travel speed under stronger wind, alongside the unchanged terrain snapshot.

Motion refinement: the full density envelope now travels with integrated wind, including separated banks and clear gaps. The original broad, nearly saturated noise mask kept a stationary silhouette even while its detail moved. Default wind now follows the valley axis at strength 1.2; the direction knob can redirect it. The native capture also records eight seconds at ten frames per second in `motion/`, used for `wind-through-valley.gif`. Three sampled frames confirm distinct banks entering, traversing and leaving the valley. The native startup/acceleration checks still pass.
