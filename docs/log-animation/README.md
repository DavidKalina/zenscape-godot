# Log animation — first pass

Bigfoot now steps into his facing before reaching. He grips the existing log
without snapping its transform, heaves it into a cradle, and rolls it onto his
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
