# Directional shadow filtering

The source renderer selects `THREE.PCFSoftShadowMap` in `main.js` and uses a
4096-square sun shadow map. The native fidelity scene had additionally enabled
Godot distance-dependent PCSS penumbrae with `light_angular_distance = 0.6`.
This produced broad, noisy shadow boundaries on the cliff and lake that were
absent in the source close-camera capture.

The native sun now uses angular distance zero, preserving Godot edge filtering
while removing the added distance-dependent softness. The old setting is
available through `--legacy-soft-shadows` for comparison. No other sun, bias,
map or material settings changed in this pass.

Godot documents the angular-distance switch in its
[lights and shadows guide](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).

## Visual evidence

`shadow-filter-comparison.mp4` shows corrected filtering on the left and the
previous setting on the right. Both reels use clear weather, no fog, camera
`8,0.55,1.9,6.2,0.38,-3.4`, and 90 frames at 30 fps. Both finish at water/motion
time 3.0 and cloud drift `(-0.458715, 0.012, -0.16055)`. Representative frame 29
was inspected in both reels against `lake-material-source.png`.

The corrected render recovers sharply defined conifer silhouettes and removes
the broad noisy penumbra. This is a filtering improvement, not proof of exact
shadow parity: native cascade projection, bias, edge sampling and vegetation
poses still differ from the source. The lake's blue color mismatch remains.

Follow-up: `LAKE-SHADOWS.md` identifies and corrects the missing source lake
shadow-receiving flag, substantially improving the shadowed-water color reported
in this earlier pass. Reflection and compositing order remain separate gaps.

## 2026-09-07: source-fitted map, tight filter, no reflection glaze

A same-camera daylight pair against the Electron build showed Godot shadow
edges as blurred stair-steps and shadow interiors near black. The source fits one
4096 map to the whole island (about 35 texels per metre) with a 3x3 PCF and a
slightly negative bias, and has no environment map. The sun now uses one
orthogonal map over the diorama (`directional_shadow_max_distance` 130, fade at
1.0) on an 8192 atlas (`rendering/lights_and_shadows/directional_shadow/size`),
soft filter quality "very low" with `shadow_blur` 0.2, bias 0.08 and normal bias
0.8 (lower values showed depth acne on canopy tiers). The surface shader sets
`SPECULAR = 0.0` so the realtime sky radiance no longer lifts and desaturates
shaded facets, and the direct GGX term no longer scales by the light's specular
amount, which had halved the sun sheen and rim glint. The larger atlas measured
about 0.13 ms per 3D pass with `tools/profile_frame_phases.gd`. The native
Bigfoot encounter tree, absent from the source seed, is now shown only while
Bigfoot is out; it had sat in front of the reference camera in every capture.
