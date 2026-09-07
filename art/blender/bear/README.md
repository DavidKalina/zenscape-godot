# Bear: Blender redesign studies

## Current direction: woodland coat to match Wanderer

Open **`zenscape-bear-woodland.blend`**. This retains the approved square-faced
bear and walk, with Wanderer's muted umber/ochre palette, darker lower limbs,
reduced muzzle/paw contrast, restrained vertex-color variation and 33 short
faceted fur clumps around the shoulders, flanks and cheeks. There are 845 polygon
faces, 19 skinned meshes and the same 15 exported deformation bones.

Preview: `bear-woodland.png`. `woodland-pair.png` shows both approved character
variants together under identical studio lighting. Export:
`assets/models/zenscape-bear-woodland.glb`. The exported 1.6-second walk passes
the existing Godot skin, stance, swing and loop checks. The original geometry
and animation are preserved; clumps follow their existing body/head bones.

`tools/finish_bear_woodland.py` records the pass and protects existing outputs
unless explicitly given `--replace-generated`; do not use that option after
manual edits. `woodland-validation.json` records mesh and weight counts.
This is an authored asset revision, not a replacement of runtime bear behavior.

## Rig and first walk cycle

Open **`zenscape-bear-walk.blend`** and press **Space** to play the walk.
The playback range is frames 1–48 at 30 FPS; frame 49 repeats the first pose
for export. `bear-walk.mp4` shows four cycles. `bear-walk-comparison.mp4` shows
the walk on the left and the accepted rest shape on the right, with matched
camera and lighting. The moving shot tracks the bear over a tiled floor.

The source rig has 24 bones: 15 deformation bones and nine root/foot/knee controls.
Body, face, ears, tail and paws retain rigid weights; the legs have a few extra
transverse edges and blended weights around the knees. The accepted broad facets
remain flat-shaded. The original static Blender study remains unchanged.

In Pose Mode:

- Move `Foot_CTRL_Front_L` and the other three foot controls to place the paws.
- Move the corresponding `Knee_CTRL` to steer each leg's bend direction.
- `Body` controls weight shifts; `Head` controls the whole face; `Root` moves
  the complete animal, including its foot targets.
- Insert location/rotation keyframes after editing poses to keep those edits.

The `Walk` action is a 1.6-second in-place lateral amble with 72% stance time.
For forward travel, move the actor along its local **Godot +Z** axis at
**0.2604167 units/second** at animation speed 1. Scale movement and animation
speed together. Blender's corresponding forward axis is -Y.

The game export is `assets/models/zenscape-bear-walk.glb` relative to the project
root. It contains one skin, 19 skinned mesh objects, 15 baked deformation bones,
and `Walk`. Blender IK controls remain in the `.blend`; their evaluated motion
is baked into the export. When re-exporting, select the rig and its meshes,
enable animation sampling, export deformation bones, and enable **Set All glTF
Animation Starting at 0**. Export the closing key at frame 49. In Godot, set
`Walk` to linear looping in the import settings or on the Animation resource.

Validation: complete vertex weights; Blender IK/stance errors below 0.001 mm;
matching loop endpoints; Godot imported `Walk` at 1.6 seconds with 19 skinned
meshes and a 7 cm swing lift. Sampled Godot stance drift was about 0.12 mm after
export interpolation. `walk-validation.json` records the Blender measurements.
Run `tests/test_bear_walk.gd` with Godot after importing to repeat the native check.

This establishes the rig and flat-ground walk. Runtime terrain foot placement,
turning, idle/rearing clips and wildlife behavior integration remain separate work.
`tools/rig_bear.py` documents the initial construction and refuses to overwrite
the authored rig. `tools/film_bear_walk.py` renders the comparison without saving
changes into the `.blend`.

## Current direction: simple and square-faced

Open `zenscape-bear-blocky.blend` for the latest revision. It uses 518 polygon
faces across 19 editable parts: broad body planes, a square head, short blunt
muzzle, tiny flat eye markings and small ears. Individual claws and the dense
remeshed surface are removed. The previous detailed study and original Three.js
bear are preserved in hidden reference collections.

Preview: `bear-blocky.png`. Export: `assets/models/zenscape-bear-blocky.glb`
relative to the project root. Only the `EDIT - blocky bear` collection is exported.
This remains a static visual study, without a deformation rig or game integration.

## Earlier naturalistic study

Open `zenscape-bear-study.blend`. The active collection contains a heavier,
more naturalistic interpretation of the procedural Three.js bear: raised shoulder
mass, a continuous skull and muzzle, smaller ears, broader paws and five claws.
The torso, head and legs are blended into one faceted skin for further editing.

- `EDIT - imposing bear study`: editable model, with the skin selected on open.
- `REFERENCE - original Three.js bear`: original captured model, hidden by default.
- `STUDIO - not exported`: camera, ground and lighting used for `bear-study.png`.
  Studio helpers are hidden in the modeling viewport but enabled for rendering.

Toggle collection visibility in the Outliner to inspect the original. Avoid
showing both in the same position when comparing. The render uses studio lighting;
the appearance still needs to be evaluated under ZenScape's game lighting.

The exported asset lives at the project root's
`assets/models/zenscape-bear-study.glb`. Select only the EDIT collection's meshes
when exporting with Selected Objects enabled.

This is a static visual study, not a rigged or integrated replacement. The source
bear's gait, terrain IK, foraging and standing behavior remain in `bears.js`.
The unified skin needs a deformation rig and weights before those behaviors can
drive it. Remeshed topology is a sculpting starting point and needs deformation
review/retopology before production animation.

The source capture can be regenerated from the Godot project directory with:

```sh
node tools/export_bear.mjs ../zenscape
```

That command updates `original-bear.glb`; it does not overwrite the Blender study.
