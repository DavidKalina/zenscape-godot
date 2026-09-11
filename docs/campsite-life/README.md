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

## Built over time

The bridge is not scenery that was always there. `SuspensionBridge` can be set
up unfinished -- `setup(a, b, {"laid": 0})` -- which stands the posts and
strings the ropes and lays no boards at all. The rope chain is the physics, so
an unbuilt crossing hangs, sways, takes the weather and can be walked out along
as far as it is planked; the missing boards are simply not drawn, their
MultiMesh slots folded to nothing exactly as the ones a cut takes. A bridge set
up without a `laid` option is the finished, weathered deck the module always
made, holes and all.

| Call | What |
| --- | --- |
| `lay_next_plank()` | nail the next board down, outward from the building end |
| `set_laid(n)` | jump the build to `n` boards (backwards allowed; for tests and scrubbing) |
| `laid_count()`, `plank_count()` | boards down, and slots there are to fill |
| `is_complete()` | every slot reached; the only state in which the bridge is a crossing |
| `built_extent()` | the frontier as `deck_point`'s `t`; moves away from the building end and never back |
| `drawn_plank_count()` | boards actually painted last repaint (lower on a weathered deck: a rotted slot is laid and still shows a hole) |

Crossability is gated on completion. `CrossingRoute.link()` takes an
`open_when` callable; while it says no, `plan()` returns nothing, which is what
every caller already handles -- the camper motive, Bigfoot's unattended-tent
visit and the study's `X` and `V` all refuse, with a printed reason. The link
itself still exists, because the built prefix is somewhere a builder walks:
`plan_to_deck(world, at, t)` and `plan_from_deck(t, world, at)` are ungated and
go no further than the `t` they are handed.

`scripts/bridge_construction.gd` is the pacing and nothing else. It turns the
world clock into planks at `rate` planks per world hour and lays them. When a
`builder` callable is set it is asked first: `campsite_life.take_plank()`
answers yes when a camper is free and the tent's wood pile is not empty, spends
one wood, and sends them out along the built extent with a board
(`_advance_builder`) to nail it on and walk home. When the answer is no -- no
camper, no wood, no route -- the driver lays the plank on the timer anyway, and
if a camper who took a board has not laid it within `grace` seconds the timer
lays it regardless. The pacing is the knob; the camper is the picture.

A board is a thing somebody holds. `claim()` takes one -- the driver's hook, a
study key and a test all go through the same door -- and whoever gets a true
owes a `lay()` or a `release()`; `grace` is what stops a lost claim from
stalling the deck forever.

Construction speaks up once at the first board, at each quarter, and on
completion, through `BridgeConstruction.on_event` -- the study prints it and
feeds it to `campsite_life`'s `events` list, and `readout()` is the progress
line in the study's status panel.

### Knobs

| Where | What |
| --- | --- |
| `bridge_construction.gd` `DEFAULT_RATE`, or `--build-rate=` | planks per world hour. **Placeholder.** At the 480 s world day that is a world hour every 20 real seconds, so the study's ~108-slot span takes about nine world hours, three real minutes |
| `bridge_construction.gd` `DEFAULT_GRACE` | seconds a hand-carried board may be in transit before the timer lays it anyway |
| `bridge_construction.gd` `MAX_STEP` | most world hours one `advance` may spend, so a skipped day is not a finished bridge in one frame |
| `suspension_bridge.gd` `setup` `build_from` | which anchor the planking starts from; `"b"`, the island, because that is where the campers live |
| `suspension_bridge.gd` `setup` `missing` | fraction of slots with no board. Defaults to zero the moment `laid` is named: a bridge being built now has not been rained on for thirty years yet |
| `campsite_life.gd` `PLANK_WOOD` | wood spent per board |
| `campsite_life.gd` `PLANK_WORK` | seconds a camper stands at the frontier nailing |
| `prototype_twin_chunks.gd` `--bridge=built\|unbuilt` | which end state the study opens in; `unbuilt` by default, and every still, film and older test that wants the finished deck calls `set_bridge_built(true)` |

### Deliberately not decided

- **Where the wood comes from.** One plank costs one wood off the tent pile,
  which is capped at eight and refilled by fetching fallen branches, of which
  there are three within reach on the island. So the pile is a trickle and the
  timer does most of the laying. Whether the campers should have to fell trees,
  whether a plank should cost more than one branch, whether the supply should
  gate the build at all: open. Nothing downstream assumes an answer -- if the
  pile runs dry, the bridge still finishes on time.
- **The rate.** Twelve planks a world hour is chosen so a study session shows
  the deck grow, not because a bridge takes nine hours to build. It is one
  number, on the command line, read once.
- **Whether it can be un-built.** `set_laid` goes backwards and `cut()` still
  works on a partial deck, but nothing wears boards out or takes them back.

### Watching it

In the study, `Q` lays one more plank and `E` finishes the bridge instantly;
the status panel carries a percentage and a plank count.
`tools/film_bridge_construction.gd --stills=<dir>` writes the same framing at
0, 25, 50 and 100 per cent, a still of a walker on the finished deck, and
numbered frames of the growth with its ffmpeg line. The build shots are side
on to the whole span rather than the study's `B` framing: `B` sights along the
deck, which foreshortens it and hides the end the planking starts from.

## Verification

- `test_campsite_life.gd`: placement/preview, wood collection and delivery,
  carried inventory across save/open, moving/deleting/undo, pause and visibility.
- `test_campsite_encounters.gd`: 150 simulated seconds; unattended inspection,
  food theft, sightings, hiding and repeated completed camper outings.
- `test_campsite_consequences.gd`: two independent residents, record validation,
  successful photo, occlusion at shutter time, exactly one stolen snack,
  player ownership, tent relocation, and persistent food/photo counts.
- `test_bridge_construction.gd`: an unbuilt rope hangs, settles and draws no
  planks; boards lay one at a time from the building end and the built extent
  only moves one way; a cut on a half-built deck parts it without crashing; the
  driver lays at its rate over simulated world hours and speaks at the quarters;
  and in the study the crossing refuses to exist until the last board is down,
  while a plank-layer can still walk out to the frontier. Run it alone.
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
