# Campsite interactions — current-main port

Run `run-campsite.command` from the `codex/camper-models` worktree. This launches
an editable woodland with the v01 Blender tent and photographer, fallen branches,
and the current Bigfoot model. Camp restores the overview; Day / night switches
between daylight sightings and the camper's flashlight. Build pauses campers.
Search for Campsite or Fallen branch to place more. Normal Bigfoot carrying,
wind, object play and terrain editing remain available.

The launcher makes a fresh demonstration in `user://campsite-demo`; ordinary
Save and Open preserve edited worlds. It starts from main at `b93160a` and ports
only the campsite integration from the old experiment, preserving that worktree.

## What happens

Campers leave to gather reachable loose branches, carry them home, and build a
pile of up to eight. Once supplies run out, they explore. Each tent owns one
resident and inventory. The default is the photographer; a saved campsite record
can specify `camper: "backpacker"` for the second model. The backpacker gathers
and reacts but does not take photographs.

Bigfoot sometimes approaches an unattended tent, looks at it for three seconds,
and takes one of three snacks. The visible food pile diminishes. A returning
camper can interrupt the visit. Sightings build suspicion; campers investigate
the last seen location while Bigfoot seeks reachable cover. A close encounter
can startle a camper into running home. These opportunities depend on routes,
cover and timing, rather than a forced story sequence.

The photographer raises the camera after a sustained view. The shutter checks
sight again: intervening cover cancels the shot. A successful shot flashes and
increments that campsite's photo count. Food, photos, carried wood and delivered
wood survive Save/Open. Photo counts are records, not saved screenshot images.

Moving or deleting a tent cancels its encounter. Undo restores its resident.
Terrain edits rebuild routes and visibility. Player ownership of Bigfoot takes
priority over campsite movement. Pausing/building stops the simulation. The
campsite does not override the world's weather or fog settings.

## Art and motion

The v01 Blender meshes are used directly; simple rigid part poses provide walking,
collecting, carrying, startled running and camera raising. These are prototype
performances, not finished animation rigs. Food theft currently reads through
Bigfoot's approach/look, the missing snack and the event caption; a hand-to-food
animation is still to come. Campers do not yet have player pickup or ragdoll
physics, tent cloth simulation, or an actual photo gallery. Visibility uses
static authored triangles and terrain samples; moving foliage is approximate.

## Any ground at all

The controller reaches its ground only through `CampsiteWorld`
(`scripts/campsite_world.gd`): the terrain document the records live in, a
navigation grid, the planted content and landmarks for sightlines, and, where
he lives, the resident Bigfoot. `CampsiteWorld.for_scene` is the playable
chunk; `CampsiteWorld.for_island` binds the same controller to a generated
island (`scripts/island_builder.gd`), building a navigation grid over the
island's own document with the tent as a solid. Camper positions are in the
document's frame, so the controller node is parented under the island.

The twin-chunk study (`studies/prototype_twin_chunks.gd`, `_settle_camp`) uses
that to put a tent, its resident and a few fallen branches on the far island,
across the bridge from Bigfoot. He cannot cross yet, so on that island there is
nobody to glimpse: the campers gather wood, stack it and explore.
`tests/test_twin_campers.gd` holds it, and `tools/probe_island_camp.gd` maps
where on a grown island a tent could stand.

## Verification

- `test_campsite_life.gd`: placement/preview, wood collection and delivery,
  carried inventory across save/open, moving/deleting/undo, pause and visibility.
- `test_campsite_encounters.gd`: 150 simulated seconds; unattended inspection,
  food theft, sightings, hiding and repeated completed camper outings.
- `test_campsite_consequences.gd`: two independent residents, record validation,
  successful photo, occlusion at shutter time, exactly one stolen snack,
  player ownership, tent relocation, and persistent food/photo counts.
- `test_diorama_flow.gd`: current product startup, editor and save/open flow.
- Rendered `test_native_build_palette.gd` and `test_bigfoot_routine_ownership.gd`:
  editor and Bigfoot regression checks. Use real rendering for these; main also
  fails their thumbnail/layout/instance-readback assertions in headless mode.

Godot still emits pre-existing renderer cleanup/null-material diagnostics in
some suites. `events.json` records the automated encounter run. `first-camp.png`
is an actual in-game capture, generated with the launcher's `-- --capture` option.

![Current campsite](/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/camper-models/docs/campsite-life/first-camp.png)
