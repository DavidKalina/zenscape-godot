# Log animation — first pass

Bigfoot now steps into his facing before reaching. He grips the existing log
without snapping its transform, heaves it into a cradle, and lifts it above his head, turns it, and lowers it onto his
right shoulder. He takes a short checked walk with the load, then swings it
forward into a physical toss. If there is no clear short route, he tosses from
where he stands.

The original walk is retained for his legs. Dedicated Blender clips add a
crouch, staggered lift, upper-body counterbalance, grip and recovery. The log
tracks the animated shoulder during the carry. Its orientation and hand
assignment account for which side he approaches from, avoiding crossed grips
and an unnecessary half-turn of the prop.

This pass focuses on the log. Stone and tree approaches also benefit from the
stepping turn, but their existing performances have not received an equivalent
animation redesign yet.

## Files

- `tools/animate_bigfoot_log.py` generates the new source copy and GLB.
- `art/blender/bigfoot/zenscape-bigfoot-log.blend` is the editable animation source.
- `assets/models/zenscape-bigfoot-log.glb` contains the imported performances.
- `scripts/bigfoot_mischief.gd` coordinates approach, lift, carry and toss.
- `scripts/creature_actor.gd` supports the stepping turn and loaded walk clip.
- `tools/film_log_animation.gd` captures the real interaction at fixed timing.

The old interaction and daily-routine Blender files are preserved. Regeneration
only replaces the generated log source and export. The capture uses the real
preset navigation and live rigid body; it changes the camera for readability.

## Validation

`test_log_animation.gd` checks gradual facing, prop continuity, actual loaded
travel, pause/resume, interruption by picking up Bigfoot, and a moved boulder
blocking the carry path. `test_bigfoot_mischief.gd` covers the other actions and
ownership regressions. The full headless suite is recorded separately and is
not expected to be clean: this repository includes rendering-dependent tests
and previously recorded legacy failures.

This is a reviewable first iteration. The local `log-animation.mp4` is the
artifact for judging the timing, weight and silhouette in the next feedback
round, not evidence that the whole animation library is finished.

## Arm correction iteration

The follow-up addresses elbow reversal, crossed support and hand penetration.
Log grips now provide a stable elbow pole and explicit palm orientation. Palm
positions intersect the cached visible log triangles, rather than using its
centerline or its oversized collision capsule. The supporting hand fades out
during shoulder transfer. Other interactions retain the original two-pass hand
solve; the new oriented grips use a third wrist correction pass.

Tests additionally measure log angular continuity, continuous carry grip error,
elbow bend side, and interruption during the pre-release toss. A numeric pass
is not a substitute for judging the motion; the final movie is retained for
further visual feedback.

Capture-only metadata prevents app focus changes from aborting the automated
performance. Normal gameplay still cancels on focus loss.

## Overhead transfer

The log rises in front of him before its long axis rotates across the head.
It stays at 3.65 m during the turn, then lowers onto the animated shoulder.
The supporting hand stays engaged through the rise and releases during the turn.
The focused test checks this overhead interval in addition to continuity,
elbows, carry contact and interruption behavior.

The full suite recorded 99/147 passes under fixed timing. The only difference
from the previous 100/147 baseline was the wall-clock performance-trace test;
it passes when rerun without fixed FPS. The other 47 existing failures remain.

The overhead iteration capture contains 1,214 frames with zero consecutive duplicates.
The capture harness explicitly draws each frame to avoid stale desktop frames.

## Shoulder catch and lengthwise toss

LogLift now lasts 4.7 seconds. The shoulder descent takes 0.95 seconds, with
a 13 cm pelvis dip and a small torso response as the load arrives. The elbow
pole rises during the catch and returns to the carry position. The toss keeps
the carried basis until release and pushes the log forward along its length,
without regripping it crosswise. Its flight remains a rigid-body simulation.
A focused regression checks that the held toss never changes the log heading.

Latest preview: `log-catch.mp4` (1,244 frames, no consecutive duplicates).
