# Two-story Bigfoot diorama

Run `run-bigfoot-lair.command`. The forest and approved cave remain upstairs;
a full-width rocky lower story extends directly beneath the original chunk.
Four thick, closed walls make it read as ordinary ground until inspected. Their
outer faces continue the chunk's own skirt (a copy of its material, and its soil,
middle and low strata repeated down the wall); inside they are cave rock.
Resting the pointer on a wall for a moment glides the camera in to face it, then
dissolves that wall; moving off the cave glides back to the previous view. A
drag, zoom or camera preset during the glide keeps the viewer's camera instead.
The opening leaves about a metre of rock frame (a dithered cutout that
keeps depth, leaving a ragged rock frame), and only one wall opens at a time.
Pointing from above never opens it. Both stories share one camera. The interior has rolling terrain, a darker damp
rock palette, a puddle, droplets, and seeded stalactites and stalagmites.

**See both stories** frames the stack. **Look through lair windows** lowers the
viewing angle while retaining the forest above, and holds the facing wall open
until the camera moves. **Find Bigfoot** uses that view
when he is downstairs. **Visit the cave** invites the existing cave routine.
P pauses the resident and droplets.

**Generate another cave** changes a versioned companion cave genome without
changing the surface genome. A connected layout graph guides floor relief and
level routes; it does not add enclosed interior partitions. The seed also moves
the bed and pool and changes rock dressing. **Change cave palette** cycles mossy
shale, limestone, and blue slate. Moisture controls damp material patches.
**Another rock arrangement** changes dressing independently. Collected items
survive each of these changes.

**Gather a branch** requests an existing nearby tree interaction: Bigfoot shakes
the tree, carries a loose branch home, and adds it to a visible stockpile.
**Bring home a fish** searches the chunk for a reachable fishing spot. A successful
catch carries the actual fish identity home; cancellation releases it, while a
completed delivery removes it from the available population. The stockpile holds
24 items. Fruit gathering remains future work; no fruit-producing trees are
introduced by this pass.

The same resident transfers to the downstairs bed after crossing the black cave
mouth, then returns behind that mouth before walking outside. The hidden
connecting route is not yet walked. Normal visits sleep; deliveries briefly
settle downstairs. Cave genome, stash, and fish depletion save and reopen in the
main game. Saving during a visit retains a safe surface position; an unfinished
carry rolls back on reopening. Legacy worlds without a lower story still open.
The lower story is procedural geometry, not yet editable with terrain brushes.

## Verification

`tests/test_cave_genome.gd` checks deterministic generation across 100 seeds,
connectivity, palette independence, schemas, and unchanged surface generation.
`tests/test_cave_system_store.gd` checks actual main-game save/reopen, stash,
fish depletion, regeneration, and legacy surface restoration.
`tests/test_bigfoot_lair_foraging.gd` and `test_bigfoot_lair_fishing.gd` exercise
collection, carry, deposit, cancellation, capacity, and source ownership.
`tests/test_bigfoot_fish_invitation.gd` exercises the actual fishing button from
the untouched cave spawn through delivery. Run these scene checks with Metal
Forward+ rather than `--headless`: the dummy renderer produces a different
imported-world navigation layout and does not validate the visible game's route.
`tests/test_bigfoot_lair.gd` checks the cave lifecycle, shared visibility, geometry,
pause, redressing, and safe return. Existing cave and cave-store checks also pass.
`tools/capture_bigfoot_stack.gd` renders front, side, back, and lower views to
`/private/tmp/bigfoot-stack-*.png` for visual verification.

Godot 4.7.2 emits renderer light-unpair errors during scene teardown in some
native tests after assertions pass. This is not an error-free engine-log claim.
