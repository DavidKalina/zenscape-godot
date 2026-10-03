# Ambient Bigfoot (scenic direction)

For the scenic diorama Bigfoot is an atmospheric prop, not an agent: a rare,
neutral woodland presence that is hard to read, never a monster and never a mascot.
`tools/blender_bigfoot/build_ambient_bigfoot.py` builds the model and rig into
`zenscape-bigfoot-ambient.blend`. The clips live in `ambient_clips.py`.

```sh
blender -b --python tools/blender_bigfoot/build_ambient_bigfoot.py -- [--no-render] [--no-anim]
blender -b --python tools/blender_bigfoot/check_ambient_bigfoot.py -- [--clip=PeekL] [--trace]
blender -b --python tools/blender_bigfoot/review_ambient_bigfoot.py -- --clip=PeekL --view=peek [--frames=0,100] [--video]
blender -b --python tools/blender_bigfoot/film_patterson.py -- [--still=194] [--scale=0.6]
```

`film_patterson.py` shoots the classic footage framing: a hand-held pan across a
clearing as he strides past, looks at the camera and walks on
(`/tmp/zs-bigfoot-previews/patterson.mp4`).

- **Look:** one continuous skinned mesh, a metaball body decimated into large facets,
  after the original woodland creature and the classic model (`bigfoot-classic.png`).
  The sculpt is already stooped: the head hangs forward of the chest and sits down
  in a mantle of shoulder, the shoulders slope, and the long arms leave the
  fingertips level with the knees. The torso is one barrel with no waist. With a
  waist and upright posture he read as a person in a suit.
  The head keeps the approved helmet dome, but with a thick, rounded brow: a thin
  brim read as a cap and, level with the eyes, as a frown. The face is recessed and
  shadowed, with a broad wedge nose, full cheeks and a square jaw. The eyes are
  small, round and dark amber-brown, smooth-shaded so the catchlight is a soft
  point. Faceted eyes threw white triangles that read as fangs. The coat is an even
  earthy brown, with ash-grey temples, a touch of moss and a few leaves.
  About 1,860 faces and 2.2 m tall, with one vertex-coloured coat material and one
  eye material. Only a few flat fur plates sit on the crown and mantle, because
  more plates, or raised ones, read as spikes.
- **Skinning:** only the lid meshes follow `Lid_L`/`Lid_R`, and the heat weights the
  lids would take from the brow go to `Head`. Breathing uses rotation only.
  The arms are their own metaball family, so they are separate islands of the one
  mesh. In the body's family the arms hanging by the flanks melted into them, and the
  stride's backswing stretched a web of flank skin behind each arm. Each arm starts in
  a ball centred on the shoulder joint, which turns in place inside the mantle.
  `arm_weights()` weights the arms by distance to their own bones, blending over the
  elbow and wrist. The torso keeps no arm weight: it goes to the shoulder cap, or to
  the chest down the flank.
- **Rig:** 27 deform bones, plus Root, foot IK and poles, and arm IK controls
  (`HandIK_*`, `ElbowPole_*`). The arm IK is off unless a hand holds something. All
  controls are baked into the exported bone motion. `FootIK_*` must share the foot bone's
  head, tail and roll: the foot copies its rotation, and a level control tipped his
  toes up. Walking feet roll over the ball or heel, not the ankle. Each arm swings
  against its own leg: back while its foot reaches forward.
- **Clips** (30 fps, seamless loops, in place):
  - `Idle` 16 s: weight wanders foot to foot, the free heel rolls up, and the gaze
    travels and holds (right, a pause to sniff the air, left).
  - `Watch` 14 s, the encounter beat: a glance, a slow full turn to face the
    viewer, and a long, still look with a curious tilt and a slow blink. His weight
    settles back onto his heels (wary, not hostile), then he loses interest and
    looks back the way he was.
  - `Listen` 12 s: he rises a little and finds the sound with small head
    adjustments. He holds his breath, sniffs, then lets it go with a sigh.
  - `PeekL` / `PeekR` 16 s: behind a trunk he takes hold of the bark, steps out
    and leans, slowly, head last. At the sight of you there is a small take and a
    long look, then the head ducks back first and the foot steps home. `L` leans
    out to his left.
  - `Forage` 15 s: he folds down with a hand on his knee and picks at a low plant
    (tug, tug, pull). He sniffs it, notices you over his hand, lets it fall and
    straightens.
  - `Walk` 3.33 s: a slow, heavy amble on soft knees, with the head kept level.
    Move the actor along local Godot +Z at `walk_speed_mps` (0.336 m/s, a rig
    extra) at playback speed 1.
  - `WalkGlance` 10 s: three walk cycles with the look back over his left shoulder,
    head first, then shoulders.
  - `Stride` 1.4 s: the classic 1967 film walk, made to be seen from the side. Long
    compliant steps on knees that never lock (about 21° at heel strike), so the hips
    glide low instead of bobbing. The heel peels up over the ball and the foot kicks up
    behind with its sole showing. The long arms swing wide, further back than forward,
    with the back arm nearly straight and the hand trailing the front one. Move the
    actor at `stride_speed_mps` (0.97 m/s, a rig extra).
  - `StrideLookL` / `StrideLookR` 7 s: five strides with the famous look. Without
    breaking step he turns to face the viewer, head and shoulders coming round together
    as one heavy mass, holds the look for a stride and a half and turns back. A blink
    rides each turn. `L` looks over his left shoulder, the side the film saw. Both begin
    on the same left heel strike as `Stride`, so the clips chain with no blend.
  Godot imports clips non-looping; set `loop_mode` when wiring.
- **Peek contract:** the peeks are authored against a trunk of radius 0.42 m whose
  axis is 0.92 m in front of him: Godot local (0, 0.92) on X/Z, stored as the rig
  extra `peek_trunk` in Blender coordinates `[x, y, radius]`. Palms rest on the bark
  and the near eye clears the trunk's silhouette by about 7 cm from straight ahead.
  For a wider trunk, move him back by the extra radius. The camera-facing head
  turn is baked forward; a runtime look-at can take over during the hold.
- **Motion polish** (see the `ambient_clips.py` docstring):
  - Travel-and-hold beats that overshoot and settle.
  - Gaze spread down the spine with per-joint delays; the head leads, then holds.
  - Arcs on head turns.
  - Spring follow-through on the arms, simulated over three loops. A holding hand
    steadies its arm. The stride clips stiffen the springs (`SPRING_STIFFNESS`), which
    would otherwise resonate with its 0.7 Hz arm swing.
  - Cyclic curves (feet, hip height) use `spline()`, which does not stop at its keys,
    and the swinging foot meets the ground already moving at ground speed.
  - Breath and drift in every hold.
- **Checks:** `check_ambient_bigfoot.py` reports, per clip, floor penetration, foot
  drift, the loop seam and the worst joint acceleration (to catch pops). For peeks
  it also reports bark penetration, eye clearance and palm gap. On the 2026-09-26
  pass every seam is 0, the feet stay within 6 mm of the floor (the toe pads' own
  depth), and the fingertips press at most 1.4 cm into the bark. The largest joint accelerations are about 13 m/s² in
  `Forage`, in its quick look-up, and under 7 m/s² in the other idles. The stride's
  pendulum arms reach about 11 m/s², and 18 to 23 m/s² as the look turns the trunk
  under them. That is a smooth rise over about 15 frames, not a pop.
- Export: `assets/models/zenscape-bigfoot-ambient.glb`. Review stills and videos go
  to `/tmp/zs-bigfoot-previews/review/`. The script regenerates the .blend, so make
  hand edits in a copy.

The sections below describe the earlier gameplay Bigfoot.

# Wanderer: Blender rig and walk

Current selected locomotion: **Heavy with loose arms**, authored in
`zenscape-bigfoot-heavy-walk.blend`, action `HeavyWalk`. It is a three-second,
four-step loop at 0.85 m/s. The game retargets its animation onto the existing
Bigfoot model. See `docs/bigfoot-heavy-walk.md` for calibration and checks.

Current idle source: `zenscape-bigfoot-breathing.blend`, exported as `assets/models/zenscape-bigfoot-breathing.glb`. See `docs/bigfoot-breathing/README.md` for breathing animation and mist validation. The woodland source below remains the base design.

## Current Godot diorama: woodland model revision

The diorama now uses `zenscape-bigfoot-woodland.blend` /
`assets/models/zenscape-bigfoot-woodland.glb`: simplified broad coat planes,
fewer small fur pieces, and solid forefeet. It preserves all twelve routine
clips and the existing skinned rig.
Earlier studies
below describe their historical passes.

## Native encounter lighting review

Run `studies/bigfoot_lighting.tscn` (removed) to inspect the classic model in the actual
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
`tools/refine_bigfoot_head.py` (removed) records the pass; its `--replace-generated` option
is for generated iterations only and must not overwrite subsequent manual edits.

## Previous pass: refined hands and feet

Open **`zenscape-bigfoot-hands-feet.blend` (removed)** for the hand/foot version. It retains
the unkempt coat below, with broader palms, angled thumbs, tapered faceted
finger segments and flatter, graduated toes connected to a shared forefoot.
Existing finger controls and the walk are preserved; thumbs follow palms and
toes follow feet. The asset has 4,064 polygon faces and 32 skinned objects.

Export: `assets/models/zenscape-bigfoot-hands-feet.glb` (removed). Full-body preview:
`bigfoot-hands-feet.png`; detail views: `bigfoot-refined-hands.png` and
`bigfoot-refined-feet.png`. `hands-feet-validation.json` records complete skin
weights and floor contact across the walk. `tools/refine_bigfoot_hands_feet.py` (removed)
reproduces this pass and refuses to overwrite the authored output.

## Previous pass: unkempt woodland coat

Open **`zenscape-bigfoot-unkempt.blend` (removed)**. This extends the finished material
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
Export: `assets/models/zenscape-bigfoot-unkempt.glb` (removed) relative to the project root.
`unkempt-validation.json` records geometry/weight checks; the existing Godot
walk test can target this asset with `--asset=res://assets/models/zenscape-bigfoot-unkempt.glb`.

`tools/roughen_bigfoot.py` (removed) records the procedural first pass. Its optional
`--replace-generated` flag deliberately replaces the generated study; do not
use it after making manual edits in that file. Earlier Blender variants remain
available for comparison.

## Current material study

Open **`zenscape-bigfoot-finished.blend` (removed)** for the coat/face pass, with the same
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
The corresponding game asset is `assets/models/zenscape-bigfoot-finished.glb` (removed).
The previous plain material study remains in `zenscape-bigfoot-walk.blend` (removed).

To check the finished export after Godot imports it:

```sh
# removed: godot --headless --path . --script tests/test_bigfoot_walk.gd -- --asset=res://assets/models/zenscape-bigfoot-finished.glb
```

## Original rig study

Open **`zenscape-bigfoot-walk.blend` (removed)**, then press **Space** to play the walk.
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

`assets/models/zenscape-bigfoot-walk.glb` (removed) (relative to the project root) contains
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
Run `tests/test_bigfoot_walk.gd` (removed) after Godot imports the asset to repeat the check.

`bigfoot-walk.mp4` shows the walk; `bigfoot-walk-comparison.mp4` shows the animated
rig on the left and the original rest pose on the right. Lighting and camera
match; the animated camera follows the character over a tiled floor. The videos
repeat one cycle twice. Studio helpers are excluded from the game export.

`tools/rig_bigfoot.py` (removed) records how the initial rig was built and refuses to
overwrite an existing authored rig. `tools/film_bigfoot_walk.py` (removed) regenerates
the preview frames without saving changes into the Blender file.
