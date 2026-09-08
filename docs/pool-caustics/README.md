# One-pool caustics prototype

**Playable integration:** these effects now also run in the ordinary editor. See [playable visuals](../playable-visuals.md) for coverage and verification. The study description below records the original isolated prototype.

The lowest pool in the visual benchmark receives soft, slowly changing light
patches on its visible bed. Press C to toggle them; P freezes their animation.
The other two pools retain their existing water rendering.

The water shader reconstructs the submerged receiver from the opaque depth
buffer and evaluates a warped cellular pattern in world space. A second smooth
mask breaks up the continuous network. The result modulates the sampled bed
before absorption and reflection blending, retaining its facets and existing
lighting. Shorelines and deeper water fade the pattern; ice suppresses it.

This is an artistic screen-space approximation in the authored daylight study.
It does not trace refracted sunlight, explicitly sample shadow maps, or illuminate
transparent submerged objects. No extra render target or particle layer is added;
the shader cost has not been separately profiled.

## Evidence

`comparison.mp4`: caustics LEFT, identical water without caustics RIGHT. Eight
seconds at 24 FPS, fixed camera and clocks, normal prototype strength 0.45.
The first full-network attempt was softened and broken into patches after visual
inspection. Reproduce with native Forward+ and `tools/film_pool_caustics.gd`.

`tools/verify_visual_benchmark.gd` verifies exactly one enabled pool and the C-key
round trip, alongside pause/resume and the existing renderer comparison checks.
The native Metal recording compiled and exercised the depth reconstruction and
caustics shaders, and matched effect/control frames were inspected.
