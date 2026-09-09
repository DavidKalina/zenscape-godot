# Layered canopy — pond prototype, second pass

The pond experiment now starts with a broader, layered tree. Press **K** or click **Canopy** to compare it with the previous two-mass broadleaf. The 1/2/3 material treatments remain independent. Both tree variants retain the same tree location, scene lighting, pond, and camera. The new tree includes branchwork and a root flare, so this is a whole-tree art-direction experiment rather than a lighting-only comparison.

The new crown has eight unequal, irregular faceted clusters (80 triangles each), 120 small folded leaves (four triangles each), and tapered branches. Crown and leaves share a tree-local wind field. The closed crown masses receive less transmission than the thin edge leaves. Interior hemisphere fill is cooled and attenuated with a broad crown-depth term; a small sky contribution retains underside readability. This is an artistic approximation, not simulated global illumination.

The capture script renders the pond framing, a close view, and the opposite/backlit view at 1600×1000. The four-second orbit uses 120 exact replayed camera transforms, verified from `captures.json`. World animation is paused for this comparison; the interactive launcher retains wind. Planar reflections copy the new meshes and follow the canopy visibility toggle using the existing reflection bindings.

The native captures were inspected from both sides and during the camera sweep. The crown has clearer volume and more readable supporting structure. It still uses deliberately solid stylized masses, and the small peripheral leaves are a first silhouette treatment. User preference is pending; keep this isolated from the asset catalog until reviewed.

No performance claim is made for this pass: other Godot work was running on the machine. Native Metal Forward+ compilation and captures completed without script or shader errors. The existing six-instance ObjectDB shutdown warning remains.

Run from the worktree:

```sh
./run-deliberate-pond.command
```

Regenerate comparison frames:

```sh
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --windowed --resolution 1600x1000 --rendering-method forward_plus --script res://tools/prototype_capture_canopy.gd -- --clean --balanced --study-film
ffmpeg -y -framerate 30 -i /tmp/canopy-film-original/%04d.jpg -framerate 30 -i /tmp/canopy-film-layered/%04d.jpg -filter_complex '[0:v]scale=800:500[l];[1:v]scale=800:500[r];[l][r]hstack=inputs=2[v]' -map '[v]' -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart docs/fidelity/deliberate-pond/canopy/comparison.mp4
```
