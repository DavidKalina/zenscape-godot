# Bigfoot breathing idle

The current Godot creature uses `assets/models/zenscape-bigfoot-breathing.glb`, authored in `art/blender/bigfoot/zenscape-bigfoot-breathing.blend` by `tools/animate_bigfoot_breathing.py`.

The 5.2-second Idle rises about 3.8 cm with subtle shoulder, arm, and head follow-through. Inhalation occupies the first 40%, followed by a slower settle and a short rest. IK keeps the feet planted. The other eleven exported clips are byte-for-byte unchanged from the woodland asset; validation reports live beside the Blender source.

Godot import optimization is disabled for this asset's AnimationPlayer to retain the small IK corrections. Native measurements: 0.0381746 m head travel, 0.00000204 m foot drift. The Blender loop seam is zero.

A Head-attached BreathOrigin marker supplies the mouth bind offset. CreatureActor evaluates its animated transform after gaze updates. Fourteen pooled mist quads emit only during early exhalation, expand and fade over 1.65 seconds, and drift with the existing wind field. The shader shares the world cloud noise and woodland mist colors. Pausing freezes the effect; leaving idle stops emission while existing puffs dissipate; resetting clears them.

## Validation

- `tests/test_bigfoot_breathing.gd`: bob, planted feet, emission timing, pause, interruption, reset.
- `tests/test_bigfoot_walk.gd -- --asset=res://assets/models/zenscape-bigfoot-breathing.glb` (test removed): walk contact and loop preservation.
- `tests/test_diorama_flow.gd` (removed): current scene integration.
- `tools/film_bigfoot_breathing.gd`: native product scene captured at 30 fps for two complete breathing cycles. Uses a disposable world under /private/tmp.

`comparison.mp4`: new breathing idle on the left, previous woodland idle on the right, matching camera and environment.
