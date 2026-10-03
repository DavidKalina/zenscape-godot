# Redwood foliage fidelity — first slice

The playable Redwood Grove now uses irregular, faceted crown rims, small lateral tier offsets and four broad missing bough sectors per crown. Tree placement, trunk geometry and the shared conifer wind response are unchanged by this slice. Crown geometry drops from 54 to 50 triangles per tree and remains in the existing instanced batch.

Redwood crown materials opt into restrained thin-sheet light transmission (0.42). The shared surface shader defaults to zero transmission for other assets. The contribution uses the existing direct-light attenuation, cloud-colored albedo and atmosphere gates; it adds no emission or independent light source. This is a low-cost surface approximation, not volumetric scattering through needles. Overlapping opaque tiers still block light, so transmission is modest in the dense grove. Silhouette variation is the larger visible improvement.

## Comparison

**Improved LEFT; original RIGHT.** Both render the actual `studies/diorama.tscn` grove, seed 37, 51 trees, Golden Meadow look, fog 0.45, existing wind strength 0.4, fixed cameras, 1440×900 SubViewport with 8× MSAA. No density increase. The baseline mesh is preserved from commit `d5eb629` in `tools/fixtures/redwood_assets_control.gd`; both use the current shared shader, with transmission disabled in the control.

![Overview comparison](overview-comparison.png)

[Six-second wind comparison](comparison.mp4), 24 fps, improved left / original right. Motion and gust-distance clocks match frame by frame; camera, celestial time and mist clock are frozen in both reels. This demonstrates gentle crown motion rather than an added gust event. The interior camera intentionally exposes crown undersides; the scene remains quite dark there.

`overview-shape-only.png` and `canopy-shape-only.png` disable transmission on the improved geometry to isolate the lighting term. The canopy effect/shape-only pair changes about 4.3% of pixels by more than 3 channel values out of 255; effect/control changes about 27%. These raw differences include temporal fog noise and are supporting diagnostics, not perceptual quality scores. See `pixel-comparison.json`.

Reproduce from the Godot project root:

```sh
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script tools/compare_foliage_fidelity.gd -- --film --profile
ffmpeg -y -framerate 24 -i /private/tmp/zs-foliage-effect/%04d.png -framerate 24 -i /private/tmp/zs-foliage-control/%04d.png -filter_complex '[0:v][1:v]hstack=inputs=2,scale=1920:-2' -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart docs/foliage-fidelity/comparison.mp4
```

The tool replaces only the live crown batch mesh/material parameters in its temporary scene. It does not write a saved diorama or gallery thumbnail. Omit `--film` and `--profile` to capture stills only.

## Validation and limits

Native Godot 4.7.2 / Forward+ / Metal / Apple M5 Pro:

- `tests/test_redwood_grove.gd` (removed): 0 failures; editing, undo/redo, removal, mist binding, save/load, biome exit and variation.
- `tests/test_conifer_wind.gd`: passed; crown movement, root anchoring, rotated/scaled instances, calm and frozen clocks.
- Capture and recording logs contain no script or shader errors.
- Four alternating unrecorded frozen-scene samples, 180 intervals each: control median 8.325 / 8.335 ms, improved 8.312 / 8.343 ms; p95 8.90–9.17 ms. No PNG readback or forced draw during measurement. Results in `performance.json`.

These are process-frame intervals for a continuously rendered frozen SubViewport, not GPU timings or a full gameplay benchmark. Other tasks were active on the machine. There is no demonstrated material regression in this limited sample, and no claim of sustained gameplay at 120 fps or HDR output.

Concurrent Bigfoot and world-preset mood edits were present in the checkout and were left intact. The comparison explicitly reapplies its look after generation, so both sides share the same mood regardless of that separate work. No production lighting preset or generator change belongs to this slice.
