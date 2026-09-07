# Wanderer: Blender rig and walk

## Native encounter lighting review

Run `studies/bigfoot_lighting.tscn` to inspect the classic model in the actual
seed-7 landscape beside the source encounter tree. Keys **1 / 2 / 3** select
daylight / mist / night; normal mouse orbit and zoom controls remain available.
Launch with `-- --paused --phase=0.0 --fog=0.35` for the captured nighttime setup.

The camera starts 10 meters from the focus point. All three captures use the
same watching pose, placement and camera. `encounter-day.png`,
`encounter-mist.png` and `encounter-night.png` are full viewport captures;
`encounter-lighting-comparison.png` combines identical crops, day/mist/night
from left to right. Day and mist use phase 0.5, with fog 0.05 and 0.8;
night uses phase 0.0 and fog 0.35.

The review uses the existing reference coat lighting with the authored vertex
colors and binds both eye meshes to `reference_bigfoot_eyes.gdshader`, restoring
the source darkness fade and normal depth occlusion. It asserts that both eyes
are found. This is a static lighting study; it does not replace the gameplay
encounter or implement the new rig's tree gripping and peeking behavior.

## Current direction: classic Bigfoot head

Open **`zenscape-bigfoot-classic.blend`** for the latest variant. The head has a
heavier integrated brow, broader nasal wings, squarer lower jaw, slightly raised
crown and 36 additional faceted cheek, hairline and chin tufts. The hands, feet,
body, controls and walk from the previous pass are retained. The result has
4,316 polygon faces, 32 skinned meshes and the same 31 exported bones.

Export: `assets/models/zenscape-bigfoot-classic.glb`. Previews:
`bigfoot-classic.png` and `bigfoot-classic-face.png`. Skin checks are recorded in
`classic-head-validation.json`; the exported asset passes the Godot walk check.
`tools/refine_bigfoot_head.py` records the pass; its `--replace-generated` option
is for generated iterations only and must not overwrite subsequent manual edits.

## Previous pass: refined hands and feet

Open **`zenscape-bigfoot-hands-feet.blend`** for the hand/foot version. It retains
the unkempt coat below, with broader palms, angled thumbs, tapered faceted
finger segments and flatter, graduated toes connected to a shared forefoot.
Existing finger controls and the walk are preserved; thumbs follow palms and
toes follow feet. The asset has 4,064 polygon faces and 32 skinned objects.

Export: `assets/models/zenscape-bigfoot-hands-feet.glb`. Full-body preview:
`bigfoot-hands-feet.png`; detail views: `bigfoot-refined-hands.png` and
`bigfoot-refined-feet.png`. `hands-feet-validation.json` records complete skin
weights and floor contact across the walk. `tools/refine_bigfoot_hands_feet.py`
reproduces this pass and refuses to overwrite the authored output.

## Previous pass: unkempt woodland coat

Open **`zenscape-bigfoot-unkempt.blend`**. This extends the finished material
study with uneven faceted fur wisps around the shoulders, outer arms, temples,
crown and lower legs; six muted green/dry leaves; one small forked twig; and
subtle coherent vertex-color mottling on the coat. The face stays clear.

The original mesh coordinates and silhouette masses are preserved. The added
66 tapered tufts, six leaves and two twig segments add 520 polygon faces
(5,368 → 5,888), using the existing 32 skinned objects and 31 deformation bones.
No textures or bones are added. Each detail follows its existing body-part bone;
independent fur/leaf wind motion is not implemented.

`bigfoot-unkempt.png` is the matched studio view; `bigfoot-unkempt-face.png` is
the head detail; `bigfoot-unkempt-stride.png` checks a raised-foot pose.
`bigfoot-unkempt-comparison.png` shows the new version left, previous finish right.
Export: `assets/models/zenscape-bigfoot-unkempt.glb` relative to the project root.
`unkempt-validation.json` records geometry/weight checks; the existing Godot
walk test can target this asset with `--asset=res://assets/models/zenscape-bigfoot-unkempt.glb`.

`tools/roughen_bigfoot.py` records the procedural first pass. Its optional
`--replace-generated` flag deliberately replaces the generated study; do not
use it after making manual edits in that file. Earlier Blender variants remain
available for comparison.

## Current material study

Open **`zenscape-bigfoot-finished.blend`** for the coat/face pass, with the same
rig and walk. Shoulders have warm, faded fur; forearms, legs, hands and feet are
darker; temple patches are grayer. The exposed face, nose, mouth and recessed
eye band have more contrast. Existing eye meshes now use dark amber shading
and an ordinary reflective material, with no emission. These eyes are visible
in daylight; the original game's daylight-fade behavior is not connected here.

The changes use vertex colors and glTF-compatible materials, with no added
textures or polygons. `material-validation.json` confirms identical hashes for
mesh positions/topology, skin weights, rest bones and animation keys before and
after. Studio lighting and the full-body camera match the previous study.

Preview: `bigfoot-finished.png`; face detail: `bigfoot-finished-face.png`;
comparison: `bigfoot-material-comparison.png` (new materials left, previous right).
The corresponding game asset is `assets/models/zenscape-bigfoot-finished.glb`.
The previous plain material study remains in `zenscape-bigfoot-walk.blend`.

To check the finished export after Godot imports it:

```sh
godot --headless --path . --script tests/test_bigfoot_walk.gd -- --asset=res://assets/models/zenscape-bigfoot-finished.glb
```

## Original rig study

Open **`zenscape-bigfoot-walk.blend`**, then press **Space** to play the walk.
The existing shaggy Wanderer model is preserved: 5,368 polygon faces, the same
proportions, face, fur locks, fingers and feet. Skin weights and an armature are
added; the geometry is not simplified or replaced.

`bigfoot-source.blend` is the original `assets/bigfoot/wanderer.glb` imported into
Blender. A hidden `REFERENCE - original Wanderer` collection also remains inside
the rig file. The editable collection is `EDIT - rigged Wanderer`.

## Motion and controls

- The `Walk` action is a slow 3.6-second alternating gait, with restrained arm
  swing, pelvis weight transfer and shoulder counter-rotation.
- Playback uses frames 1–108 at 30 FPS. Frame 109 repeats the first pose for export.
- Move `Foot_CTRL_R` / `Foot_CTRL_L` in Pose Mode to position the feet. The two
  `Knee_CTRL` bones determine the knees' bend direction.
- `Root` moves the whole character. `Pelvis`, `Spine` and `Head` control posture.
- `UpperArm`, `Forearm` and `Hand` bones control the arms. Four two-joint finger
  chains per hand remain available for gestures. Thumbs move with the palms.
- Insert transform keyframes after editing a pose to preserve your changes.

The source rig has 36 bones: 31 deformation bones and five root/foot/knee controls.
The original segmented meshes are rigidly weighted to their matching bones,
preserving their faceted surfaces and the source's overlapping joint coverage.

## Godot export

`assets/models/zenscape-bigfoot-walk.glb` (relative to the project root) contains
one skin, 32 skinned mesh objects, 31 bones and the baked `Walk` action. Select
the rig and its meshes for re-export; enable animation sampling, deformation
bones and **Set All glTF Animation Starting at 0**. Include the closing key at
frame 109. Blender IK controls are baked into the exported bone motion.

The clip is in place. Move the actor along local **Godot +Z** at
**0.2419355 units/second** at animation speed 1; scale both rates together.
Blender forward is -Y. Set `Walk` to linear looping in Godot's animation import
settings or on the Animation resource.

The game encounter and `scripts/reference_bigfoot.gd` remain unchanged. This
asset does not yet replace runtime terrain adaptation, tree gripping, peeking,
gaze behavior or the game's custom daylight-dependent eye shader.

## Verification and footage

`walk-validation.json` records complete weight coverage, Blender foot IK/contact
errors below 0.006 mm, soles remaining above the floor within floating-point
tolerance, and matching loop endpoints. The imported Godot animation has a
3.6-second duration, 31 bones and 32 skinned meshes. A sampled stance interval
drifts about 0.54 mm after export interpolation; the swing lifts the foot 11 cm.
Run `tests/test_bigfoot_walk.gd` after Godot imports the asset to repeat the check.

`bigfoot-walk.mp4` shows the walk; `bigfoot-walk-comparison.mp4` shows the animated
rig on the left and the original rest pose on the right. Lighting and camera
match; the animated camera follows the character over a tiled floor. The videos
repeat one cycle twice. Studio helpers are excluded from the game export.

`tools/rig_bigfoot.py` records how the initial rig was built and refuses to
overwrite an existing authored rig. `tools/film_bigfoot_walk.py` regenerates
the preview frames without saving changes into the Blender file.
