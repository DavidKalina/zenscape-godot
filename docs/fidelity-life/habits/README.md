# Bigfoot makes a resting place

In Fidelity Life, an uninterrupted first rest establishes a favorite spot. Rest
selection favors reachable, smooth ground with less low foliage. Later sit,
sleep and hibernation visits return to that spot. As he sits down, his hands
sweep inward and his leaf bed develops through three sizes. The bed remains
when he explores, and growth stops at a modest finished arrangement.

Use **Find his resting spot** in the upper-left life controls. Continue using
`run-fidelity-life.command` to play this scene. No special input, progression
currency, new Blender asset or connected-world system is needed.

## Player ownership

The bed is a normal `leaf_bed` garden record with a selectable mesh. Select,
move, resize, delete, erase, duplicate, undo and save use the existing editor.
Each autonomous improvement is an undoable stroke; it never joins an active
player stroke. Changing or deleting his bed relinquishes the remembered place
and excludes its immediate area from future adoption. Undo can restore the
prop without restoring Bigfoot's claim on it. This exclusion is saved.

His bed presses down nearby **original** reeds and soft bank cover, following
the same sloping ground plane. This is derived rendering on private MultiMesh
copies. Imported source transforms and player-placed plants are untouched.
Deleting or moving the bed restores the old area's source cover. Significant
terrain changes or blocked resting clearance make him abandon the memory;
the editable bed remains part of the player's garden.

The current scope is one favorite resting place and one growing bed. Forgotten
beds can remain as ordinary props. Clearing many places can leave him without
a suitable rest site until the player makes space. Habits retain at most 16
excluded places. Bed development adds local leaves; it does not consume a
finite stock of leaf entities or model individual leaf physics.

## Persistence

Fidelity Life adds optional versioned `bigfoot_habits` state to the normal
scene-state save: favorite position, visits, stage, expected bed identity and
excluded areas. Validation occurs before opening mutates terrain. Load compares
record fields across JSON's float IDs and the garden's integer IDs, then checks
that the remembered surface still fits. Legacy saves start with fresh memory.
The base Fidelity editor can render/edit the bed; only Fidelity Life captures
and restores Bigfoot's habit memory. Actor poses and active actions are not
part of this new persistent state.

## Verification

Passed with Metal / Forward+:

- `tests/test_bigfoot_habits.gd`: 310 seconds of ordinary, unprompted play;
  stages 1/2/3 around 74/132/163 seconds at 60 simulation steps per second;
  repeated visits to `(5.6, 0.544, -7.7)`; one bed; no routine cancellation;
  safe sampled positions; actual selection geometry; paused state; garden
  save/open; invalid-state rejection without mutation; delete/undo; moving
  the bed; lowered terrain; legacy load; immutable source foliage and its
  restoration when the bed is removed.
- `tests/test_native_chunk_editor.gd`: existing garden editing and saving tests.
- Headless actor, authored routine actor, and hand-reach checks also passed.

`tests/test_native_drop_reactions.gd` has one existing failure: “A paused
reaction stays live” (line 146). Its flower reaction count is zero. The same
failure was reproduced with the new leaf asset, renderer registration and
reaction classification removed, then those files were restored. Its asset
classification checks pass with the leaf bed included. This unrelated pause
fixture was not changed.

## Footage

`lived-in.mp4` is a 32-second highlight reel from autonomous play. Four chapters
show later visits and the persistent arrangement. Between chapters the script
simulates ordinary play without rendering: there are cuts, not a claim that
the whole habit develops in 32 seconds. No action requests, teleports or timer
changes drive the reel. Daylight and camera framing are fixed for visibility.

`comparison.mp4` shows the visible bed and pressed cover on the left; the same
routine with those two visual treatments hidden is on the right. The control
retains the same behavioral memory so the framing and action beats match.

Reproduce using `tools/film_bigfoot_habits.gd`, Godot Movie Maker, fixed 30 FPS,
960×640 window, and `-- --control` for the control. The driver advances from the fixed Movie Maker process clock with the viewport
forced to update. It does not depend on redraw notifications, which can stop
when a still pose leaves the renderer with no new frame to draw.
