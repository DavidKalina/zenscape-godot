# Mountain variety and clouds

Run `./run-mountain-clouds.command` from this worktree. This disposable study keeps the small plot and fixed-size Bigfoot while varying mountain height independently.

- **1 / 2 / 3:** alpine massif, broken ridge, volcanic crown.
- **Short / Tall / Extreme:** peaks at 12 / 24 / 32 engine units. Bracket keys adjust in steps of four.
- **K:** cloud band on/off. **P:** freeze/resume cloud drift.
- **Cloud altitude slider:** move the band between 5 and 23 units.
- **C:** overview. **F:** focus Bigfoot. **Space:** orbit. Standard mouse camera controls remain available.

Start with Tall and move the clouds up the mountain, then compare Short with the same cloud altitude. The short mountain can sit beneath the clouds, while taller peaks emerge above them. The camera stays fixed when changing mountain settings so the comparison retains a scale reference.

## Accepted direction

The user likes these new mountains and the earlier mountain styles. Keep both in the available variety; this experiment is additive, not a replacement of the original mountains. Height and cloud treatment remain adjustable across that repertoire.

## Implementation and boundaries

Three procedural profiles replace the rear mountain, blending back into the familiar foreground. Trees are retained at the foothills. A height/slope material adds rock and snow; the experimental cloud band is a local native FogVolume using the existing cloud-noise functions. It is separate from the sky cloud layer, so it can intersect geometry. See Godot's [fog shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/fog_shader.html).

The silhouettes intentionally exaggerate verticality; Extreme is a boundary to explore rather than a proposed default. At this footprint the volcanic crown becomes a steep tower, and the summit needs more terrain resolution for a detailed crater. Snow coverage is conservative on steep faces. Clouds are still soft and need further art direction and performance evaluation before production use. No movement, saved-world, or production generation changes are included.

## Verification

Native Godot 4.7.2, Metal Forward+, 1600×1000. The capture script cycles all nine shape/height combinations, records peak height and camera transforms, and produces clouds-off and two cloud-time captures. No script or shader errors occurred in the final capture run. Godot still reports the six existing ObjectDB leaks at shutdown; this study does not resolve them. These are visual checks, not a real-time performance benchmark.

[Open the comparison gallery](index.html). Captures are local generated files excluded from Git; regenerate with:

```sh
~/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1600x1000 --rendering-method forward_plus --script res://tools/prototype_capture_mountain_clouds.gd -- --clean --balanced
```
