# ZenScape in Godot: first fidelity study

Question: how quickly can the existing game's scenery reach a comparable visual
quality in Godot? This first pass transfers a real source scene, then adapts its
rendering. It does not replace the sculpting sandbox or port the generator.

## See it

Double-click `run-fidelity.command` in the project root. It opens the study using
Forward+ on the native graphics device. The sculpting prototype retains its
Compatibility renderer and normal F5 entry point.

- Drag to orbit; scroll to zoom.
- Tab switches between the live Godot scene and the captured Three.js reference.
  It resets the camera so the comparison uses the same pose.
- R resets the view; Space starts a gentle camera drift; H hides the controls.
- Escape returns to the sculpting sandbox in the current process.

`comparison.mp4` and `comparison.png`: **Godot on the left, Three.js on the right**.
Both reels are 1440 × 900 per side, six seconds, 30 FPS, the same seed, camera,
daytime phase, and source weather settings. Bird and wind phases are not synchronized.

## What transferred

- Seed 7's actual terrain, vertex palette, natural arch, and layered earth base.
- 42 mesh groups with 5,366 placed instances: trees, ground plants, flowers,
  deadwood, mushrooms, and the captured wildlife meshes.
- The source's camera, sun/rim light directions, light colors, and hemisphere
  bounce settings.
- The source sky gradient, compensated for the different display pipelines.
- Source foliage sway parameters, adapted to Godot shaders.

`geometry.scn` contains native MeshInstance3D and MultiMeshInstance3D resources.
The scene does not run Three.js or embed the reference screenshot as its 3D view.
The screenshot is shown only while explicitly comparing with Tab.

## Fidelity still to address

The [native motion pass](MOTION.md) now preserves water depth, animates the stream
and waterfall, and adds wind/pause controls. Its new before/after film is
`motion-comparison.mp4`; the original `comparison.mp4` remains the Three.js comparison.


- Shadows and indirect shading differ: Godot's first pass is softer and some
  vegetation is cooler/lighter than the source.
- Lake reflection, water depth, flow, foam, and the waterfall's changing geometry
  are approximations. The source water system has considerably more detail.
- Bird flight is a simple native orbit with wing motion. Its original thermal
  behavior is not ported; the other captured animals are static.
- The full volumetric weather, cloud shadows, lake mist, atmospheric perspective,
  day/night transitions, and sound are not ported. Waterfall spray is a small
  native approximation.
- The imported ground is a reference mesh. Sculpting it while keeping plants,
  water, and landmarks coherent is the next architectural step.

## Reproduce

Serve the source ZenScape checkout, then run:

```sh
ZS_URL=http://127.0.0.1:8148/ node tools/export_reference.mjs ../zenscape
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script tools/import_reference.gd
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script tools/check_import.gd
./run-fidelity.command
```

The exporter was adapted from ZenScape's GPU probe harness. Geometry is returned
in small batches because sending the complete scene over the capture connection
stalled. Import with a real renderer: Godot's headless dummy renderer discarded
MultiMesh transforms when the first version was saved.

Once the bridge was ready, native conversion and saving took well under a second
in the measured run. The six-second source and Godot films each rendered in a few
seconds on this M5 Pro. These are offline capture observations, not a gameplay
performance benchmark. Most of this session's work was building the bridge and
matching color/light conventions.

Conclusion: the existing geometry and art direction carry over very well.
Achieving closer parity is primarily shader, lighting, and motion work. Recreating
editable terrain and environmental behavior remains a separate task.
