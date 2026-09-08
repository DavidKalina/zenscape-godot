# Woodland Bigfoot model revision

This revision targets the current Godot diorama (`studies/diorama.tscn`).
Its resident inherits setup from `studies/fidelity_life.gd`; the build palette
uses the same new model for its portrait and fallback placement.

Editable source: `art/blender/bigfoot/zenscape-bigfoot-woodland.blend`.
Runtime asset: `assets/models/zenscape-bigfoot-woodland.glb`.
Earlier authored variants remain intact. `tools/restyle_bigfoot.py` records the
initial geometry pass and refuses to overwrite the resulting editable source.

The revision removes scattered tiny fur and leaf pieces, retains a few broad
coat locks, simplifies the head and limb planes, and combines the feet visually
into broad forefoot masses without separate toes. Flat per-face colours replace
small colour gradients. The coat palette, proportions and existing rig remain.
Polygon count changes from 4,316 to 1,795; all 32 skinned meshes remain.

All twelve exported animation clips match the original routine GLB exactly,
including each channel's sample times, values and interpolation. Source bones,
keyframes and handles are unchanged, and all vertices retain full skin weights.
Reports are alongside the Blender source (`woodland-validation.json` and
`woodland-clips-preserved.json`). Animation stiffness is outside this pass.

`original.png` and `redesigned.png` are matched static renders inside the current
product scene, using a disposable valley world and identical daylight/camera.
Reproduce with Godot Forward+ and `--script tools/capture_bigfoot_woodland.gd`.
The script uses a temporary library path, leaving the user's dioramas untouched.

Validation: Godot `tests/test_bigfoot_walk.gd` with
`-- --asset=res://assets/models/zenscape-bigfoot-woodland.glb` passes (31 bones,
32 skins, 3.6-second loop, zero loop seam). `tests/test_diorama_flow.gd` passes;
it emits an ObjectDB leak warning at shutdown. Native Metal/Forward+ capture
completed successfully.
