# Rock throw polish

The playground uses a dedicated StoneHeave clip: crouch into the pickup,
bring the rock near the chest, load beside the shoulder with a bent elbow,
then turn the torso through release and let the arm follow through.
The same rigid body follows a continuous hand target before release and
flies under physics afterward. There is no release-position correction.

Editable source: `art/blender/bigfoot/zenscape-bigfoot-stone.blend`.
Regenerate using `tools/animate_bigfoot_stone.py` in Blender.
The earlier routine clips remain available for their existing callers.

`test_bigfoot_mischief.gd` checks stone hand contact, a shoulder windup,
continuous pickup/release, physical flight and the existing log/tree and
interruption behavior. This pass runs that focused regression; the full
suite results from the preceding log pass are in `../log-animation/`.

`tools/film_stone_animation.gd` records the real preset interaction, with
a closer front camera and explicit redraws for reliable offline capture.
