# Deliberate pond — throwaway visual prototype

Update: the [canopy second pass](canopy/README.md) now starts by default. Press K to return to the previous tree; 1/2/3 still compare material treatments. The original captures below retain the previous tree.

Question: can localized material response and an intentional light/color relationship make a simple ZenScape pond feel more tactile while preserving the faceted geometry?

Run `./run-deliberate-pond.command` (removed) from this worktree. Press 1/2/3 or click the bottom arrows to compare, drag to orbit, scroll to zoom, Space for automatic orbit, P to pause, C to return to the study camera. The fixture is assembled in memory from editable terrain and existing assets. It does not load or save a user garden.

## Treatments

1. Original material response, Mountain palette, afternoon sun at phase 0.60.
2. Same palette and sun, with a prototype shader: localized shoreline darkening and roughness, broad stone moss, cooler lower foliage, thin foliage transmission, and hemisphere fill routed through IRRADIANCE so SSAO can affect it. No fine normal texture.
3. Treatment 2 with ambient energy 0.72, cooler ambient fill, adjusted bounce and sunlight color, restrained greens and cooler stone. Same sun direction and geometry.

This is a bundled art-direction comparison, not an isolated benchmark of each shader term. The separate shader and scene are disposable; production defaults are untouched. The native fixture uses one broadleaf tree, three boulders, sparse ferns/reeds, and the existing planar pond renderer. This pass does not add GI, depth of field, extra fog, or new grass geometry.

## Evidence and limits

Open `index.html` for the original/treatment wipe and side-by-side orbit. The native captures are 1600×1000 pixels. `captures.json` records camera transforms and viewport dimensions. The four-second, 120-frame film replays the exact original transforms in the afternoon variant. It freezes scene animation to make the material comparison readable; it is not real-time performance evidence.

`pacing.json` is a separate original / afternoon / original sequence with live animation and automatic orbit: three seconds of settling, five seconds of frame intervals per phase, VSync enabled, no application FPS cap. The final timing run is inconclusive: the repeated original control changed from 6.9 ms median to 34.5 ms, while the treatment measured 23.9 ms. That control drift prevents attribution to the treatment. An earlier short run was steadier (~14.6 / 15.1 / 14.6 ms), but its apparent small difference should not be treated as established cost. These wall intervals do not measure GPU cost, presentation latency, or a production garden. No general 120 FPS claim is made.

First visual reading: the shoreline feels darker and cooler, and the slate color separates stones from the bank. The change remains restrained. The sparse tree is still visibly a simple asset; this has not demonstrated the richer canopy volume described in the brief. User verdict is pending. Decide whether to develop the materials, change the composition/assets, or discard this study before production adoption.

Native Godot 4.7.2 / Metal Forward+ on Apple M5 Pro rendered the study without script or shader errors. The process reports six ObjectDB instances leaked on exit, also documented by the earlier lighting study; this prototype does not resolve that existing shutdown warning.

## Reproduce

```sh
# removed: "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --windowed --resolution 1600x1000 --rendering-method forward_plus --script res://tools/prototype_capture_pond.gd -- --clean --balanced --study-film --study-profile
ffmpeg -y -framerate 30 -i /tmp/pond-film-0/%04d.jpg -framerate 30 -i /tmp/pond-film-2/%04d.jpg -filter_complex '[0:v]scale=800:500[l];[1:v]scale=800:500[r];[l][r]hstack=inputs=2[v]' -map '[v]' -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart docs/fidelity/deliberate-pond/comparison.mp4
```

Capture images and video follow the repository's existing ignore policy and remain local. Retain the measurements and notes if the prototype is removed.
