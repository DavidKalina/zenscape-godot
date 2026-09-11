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
across the bridge from Bigfoot. `tests/test_twin_campers.gd` holds it, and
`tools/probe_island_camp.gd` maps where on a grown island a tent could stand.

## Across the bridge

Each ground owns one navigation grid clamped to its own document, and nothing
joins two of them. A bridge does. `CrossingRoute` (`scripts/crossing_route.gd`)
is that link: two `CampsiteWorld`s, the two bridgeheads `bridge_anchors()`
chose, and a callable that answers where the live, physics-driven deck is at
`t`. `plan(from_world, from_at, to_world, to_at)` returns one flat array of
world-space steps -- grid path to the near bridgehead, the boards, grid path
from the far one -- and `CrossingWalk` (`scripts/crossing_walk.gd`) is the
cursor a walker holds into it. It answers the two questions a bridge that moves
forces every frame: where the next board is *now*, and what counts as ground
*here*. Bigfoot reads `target()` and `probe()` and uses his own legs
(`walk_step`); a camper, which is a model whose position is assigned, hands its
position to `carry()` and takes back the next one.

Everything in a plan is world space. The two shores disagree about what local
means -- the far island is turned 180 degrees and carried across the chasm --
and the deck belongs to neither. `CampsiteWorld` gained `to_world`/`to_local`,
a world-space `ground_probe()` and `resident_point()` for exactly this: the
controller used to read `creature.position` directly, which is only the right
frame when Bigfoot lives on the ground doing the asking.

What the crossing is *for* is the camp's own motive, unchanged:

- **Bigfoot.** A camp with no resident of its own but a link to one fetches him
  the same way it would walk him over from the next clearing: an unattended
  tent is worth a look (`_consider_crossing`). He walks the deck, steps off, and
  from then on the island's `CampsiteWorld.resident` is him -- which is all
  `resident_active()` needs, so sightlines, the photograph and the scare work
  with no further change. He raids the tent and walks back. One difference: a
  visitor does not give up because the camper came home. A hundred metres of
  rope deck is too far to come to be put off by somebody sitting outside, and
  the encounter is the interesting half of the crossing.
- **Campers.** Once the wood pile is full there is nothing left to fetch, so an
  outing becomes a look at the other island (`_outing`). A visitor walks, looks
  and comes back; there is no wood of theirs over there and no tent of theirs
  to keep. The model keeps its parent -- and so its frame -- the whole way
  across and only its world position moves; landing is where that stops being
  enough, and the shore it has arrived on is asked, in its own frame, for the
  nearest foothold (`_land_camper`).

### Knobs

| Where | What |
| --- | --- |
| `campsite_life.gd` `CROSS_SPEED`, `BIGFOOT_CROSS_SPEED` | how fast the deck is walked, m/s |
| `campsite_life.gd` `CAMPER_STAY`, `BIGFOOT_STAY` | seconds a visitor stays on the far shore |
| `campsite_life.gd` `CROSS_COOLDOWN` | seconds before anyone sets out again |
| `campsite_life.gd` `CROSS_STALL` | seconds of no progress before the crossing is given up |
| `crossing_route.gd` `DECK_STRIDE` | metres between deck waypoints |
| `crossing_route.gd` `DECK_LANE` | how far off the centreline still counts as boards; wider than the deck on purpose, because the deck bows downwind and a walker refused ground there is stopped for good |
| `crossing_route.gd` `APPROACH_REACH` | how far the last stride onto the boards may be walked off the grid |
| `prototype_twin_chunks.gd` `TRAIL_WIDTH`, `TRAIL_DONE` | how much scenery is folded away to open a way to the bridgehead |

### Two things that bit

The bridgehead sits on the rim, past where `creature_navigation.gd` stops
calling ground safe, and on a wooded island the pocket it stands in can be cut
off from the grid entirely. The study's anchor search already folds away
whatever stands on a bridgehead, but `fidelity_habitat.gd` reads that geometry
and the grid does not know until it is read again -- so `_clear_trail()` opens a
corridor from the ground the walkers can already reach and re-reads the habitat,
and the last few metres onto the boards are walked off the grid on the
heightfield alone.

`deck_t_at` cannot project onto the straight chord. `t` is spread over the
rope's segment points, not over its length, and the last interval runs from a
segment's centre out to the anchor; probe and waypoint then name different
places on the same deck and a walker stops a third of a metre above the boards
forever. It samples the real curve instead.

### Watching it

In the study, `X` sends Bigfoot across now and `V` sends a camper.
`tools/probe_crossing.gd` says why a crossing does or does not exist, leg by
leg, and maps the ground each shore refuses.
`tools/film_bridge_crossing.gd --frames=<dir>` follows him over the deck and
writes `crossing.png` plus the clip and its ffmpeg line.

## Verification

- `test_campsite_life.gd`: placement/preview, wood collection and delivery,
  carried inventory across save/open, moving/deleting/undo, pause and visibility.
- `test_campsite_encounters.gd`: 150 simulated seconds; unattended inspection,
  food theft, sightings, hiding and repeated completed camper outings.
- `test_campsite_consequences.gd`: two independent residents, record validation,
  successful photo, occlusion at shutter time, exactly one stolen snack,
  player ownership, tent relocation, and persistent food/photo counts.
- `test_bridge_crossing.gd`: the twin-chunk study; the route stays on the boards
  and passes within a metre of both bridgeheads, a camper crosses to chunk one
  and stands on its ground, and Bigfoot crosses the other way, is a resident of
  the island while he is there, raids the tent and walks home. Physics-timed and
  long (two crossings at about a metre a second); run it alone.
- `test_diorama_flow.gd`: current product startup, editor and save/open flow.
- Rendered `test_native_build_palette.gd` and `test_bigfoot_routine_ownership.gd`:
  editor and Bigfoot regression checks. Use real rendering for these; main also
  fails their thumbnail/layout/instance-readback assertions in headless mode.

Godot still emits pre-existing renderer cleanup/null-material diagnostics in
some suites. `events.json` records the automated encounter run. `first-camp.png`
is an actual in-game capture, generated with the launcher's `-- --capture` option.

![Current campsite](/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/camper-models/docs/campsite-life/first-camp.png)
