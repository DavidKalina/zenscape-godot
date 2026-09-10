# Two-story Bigfoot diorama

Run `run-bigfoot-lair.command`. The forest and approved cave remain upstairs;
a full-width rocky lower story extends directly beneath the original chunk.
The original pointed underside is replaced, and its edge band is shortened
to join the lower story. Eight large openings have thick stone reveals. Orbit the whole diorama to look
through them. Both stories always share the same camera and remain rendered.

**See both stories** frames the stack. **Look through lair windows** lowers the
viewing angle while retaining the forest above. **Find Bigfoot** uses that view
when he is sleeping downstairs. **Visit the cave** invites the existing cave
routine. P pauses the resident and the droplets.

The lower story uses Fidelity's terrain noise and rock palette, garden water,
waterfall droplets, and the existing sleep animation. The bed and puddle have
fixed footprints; **Another rock arrangement** reseeds stalactites and stalagmites.
The room is a procedural mesh study, not yet an extension of the terrain brushes.

The same resident transfers to the downstairs bed after crossing the black cave
mouth, then returns behind that mouth before walking outside. The hidden
connecting route is not yet walked. Saving during a visit retains a safe surface
position. The ordinary main-game cave remains supported; the new lower story is
part of this dedicated study, not a new main-game save format.

## Verification

`tests/test_bigfoot_lair.gd` checks the real cave lifecycle, sleep, pause, original
chunk/lower-story bounds, shared visibility across camera shortcuts, terrain
growth, redressing, exterior save position, surface return, and cancellation.
`tools/capture_bigfoot_stack.gd` renders front, side, back, and lower window views
to `/private/tmp/bigfoot-stack-*.png` for visual verification.

Native Metal lifecycle/geometry checks pass; see `verification.json` for the
requirement audit and the renderer cleanup errors observed at test teardown.
