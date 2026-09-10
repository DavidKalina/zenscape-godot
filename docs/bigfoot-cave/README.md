# Bigfoot's cave in Fidelity

The approved Blender cave is fitted to the southern hillside of the original
Fidelity diorama, beside the water. Run `run-bigfoot-cave.command` in this
worktree. **Find his cave** frames the entrance; **Visit the cave** invites a
normal approach, rest and departure. Ordinary scheduled sleeps also use it.

## Intended behavior

- Preserve the approved cave silhouette and irregular entrance in game.
- Walk from surface navigation through the black doorway, despawn from view during rest, then reappear
  behind the doorway and walk back out. The black surface follows the exact
  approved mouth outline; the resident is hidden only once fully behind it.
- Ordinary sleep lasts 45 seconds inside; rain shelter lasts at least 20 seconds
  and ends after six clear seconds. Snow/hibernation uses a 100-second stay.
- Pause freezes movement and rest. Sealing/editing an occupied cave cancels the
  activity and recovers Bigfoot to safe exterior ground; a held actor is not
  relocated. Sealed caves are unavailable until reopened.
- Save the prepared cave with the world and restore its model on opening it in
  the main diorama scene. Interior inspection and carrying items home are later.

## Implementation

`bigfoot_cave_site.gd` renders the approved GLB at a saved cave-tagged terrain
bore and creates matching mesh collisions. The bore clears intersecting hillside;
its rectangular entrance is covered by the authored rock shell. Surface navigation
excludes the cave mass; `bigfoot_cave.gd` temporarily owns the short threshold
route. Ordinary mines keep their existing terrain and navigation behavior.

The prepared study clears intersecting source props and loose stones once, as
saved editor state. Low reference foliage inside the entrance is masked on
private MultiMesh copies while the cave is present. No imported resources are
modified. The asset floor is raised 2.5 cm above the subtraction floor to avoid
coplanar rendering artifacts.

The floor, shell and pose are a fixed authored design: a saved cave marker
requires a bore at least 6.4 m wide, 4.8 m high and 7.2 m deep. This is a prepared
world, not a general cave-placement tool. Cave visit progress is transient;
saving does not freeze an action mid-animation. The normal save restores an
exterior resident position.

## Verification

`tests/test_bigfoot_cave.gd` exercises the real prepared scene. Native renderer
captures come from `tools/capture_bigfoot_cave.gd`, which explicitly requests a
visit then runs the real routine. They demonstrate the sequence, not autonomous
scheduling. The test separately exercises automatic weather retreat.

Native Metal verification: cave lifecycle, full main-game save/open, routine
pause, routine ownership and native tunnel tests pass. The older routine-world
fixture fails three sit/sleep assertions, and the older home fixture accesses
its editor before asynchronous startup finishes. Both failures reproduce using
HEAD scene/routine/habitat scripts without the cave changes. See
`verification.json`. This is not a claim of a clean repository-wide suite.

`Fidelity cave.json` is an openable prepared world for the main game. The study
launcher keeps experimentation isolated in this worktree. The black entrance
uses the exact Blender mouth outline, exported alongside the GLB.
