# Bigfoot's own mischief

Launch `run-god-mode-playground.command` from this worktree. Bigfoot occasionally
chooses a stone, log or spring tree between his ordinary journeys. **Let him
play** cycles through available actions; **Show him the tree** invites a pull.

He walks to a checked stance, reaches for the same loose body the player can
pick up, lifts it, and throws. The log uses two palm targets and a heavier
lift-and-shove motion. At release the original rigid body resumes gravity,
contact, tumbling and its existing water behavior. His older daily-routine
projectiles are unchanged; these playground throws use the loose-object solver.

For the tree he draws the trunk toward himself and releases the existing spring.
Its crown can bat nearby loose bodies. He is protected from his own recoil;
a player takeover immediately restores the usual possibility of hitting him.

Picking him up, moving his target during approach, impact, switching tools,
calling him or losing focus interrupts the action. An interrupted grasp drops
that same object. Pause preserves an ongoing grip; reset restores the scene.
Unreachable or moving props are skipped, with a delay between route attempts.
This is playful world interaction, without other characters or damage systems.

## Implementation

`bigfoot_mischief.gd` owns the approach and performance lifecycle. It reuses the
existing StoneThrow and TreeShake clips and CreatureActor hand reach. The scene
coordinates player gestures and ordinary brain ownership. Prop flight remains
in `play_loose_body.gd`; spring contact remains in `play_spring_tree.gd`.

`request(kind, chosen)` accepts a particular existing prop when desired. It
validates target ownership, rest, dry access and navigation; it does not create
new props or implement targeting other characters. Invitations share that path
with autonomous choices.

## Validation

`tests/test_bigfoot_mischief.gd` exercises actual preset approaches, both palm
contacts, physical travel, complete actions, pause/resume, player tree takeover,
carrying, impact, focus loss, moved targets, tree-to-prop contact, reset and an
autonomous choice. The broader suite results are recorded in `suite.json`.

`tools/film_bigfoot_mischief.gd` requests each real action and waits for completion.
It repositions Bigfoot between demonstrations for framing, but does not script
the grasp or flight. The local `bigfoot-mischief.mp4` is generated and ignored by
Git. Capture frame-pacing results are recorded separately; capture speed is not
a measurement of foreground gameplay performance.
