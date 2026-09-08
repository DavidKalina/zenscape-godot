# A little life

Launch `run-bigfoot-life.command` (Godot 4.7.2, Forward+), or run
`studies/bigfoot_life.tscn`. This reproducible garden extends the wind playground
without changing its original behavior or replacing an existing garden save.

Bigfoot chooses short walks, notices nearby scenery, approaches, inspects, and
rests. Curious approaches use **?** and 0.5 m/s; excited discoveries or calls use
**!** and 1.5 m/s. Ordinary wandering uses 0.85 m/s. The existing Blender Walk
clip runs at a cadence matched to its authored stride. It stays continuous at
path corners, and each step samples the actual terrain height.

## Try it

- Watch him choose scenery, or click **Something interesting?** for curiosity.
- **Call him** prompts an excited approach toward your side of the garden.
- Grab his head, use **Pick up**, or switch the gust tool on and blow him over.
  He yields to carrying and physical reactions, then resumes exploring.
- **Build while he explores** opens the existing native editor. Place or move a
  rock ahead of his route, sculpt a ridge, undo/redo, or remove a target he is
  inspecting. He reconsiders changed routes and targets.
- Right drag orbits, the wheel zooms, P pauses, R resets, and Esc leaves Build.
  Build/Inspect does not stop him. Normal native garden save/open remains available.

If an edit removes his supporting ground, the scene moves him to a safe nearby
spot with a reaction. If no dry, usable ground remains, he waits in his held pose
until you make a clearing; you can still carry him. A held character is never
teleported by a terrain edit. Drops and recovery share navigation's habitat rules.

## Implementation

`CreatureActor` owns locomotion/animation and physical interruption states.
`CreatureBrain` owns notice, approach, inspection, blocked and resting phases.
`CreatureNavigation` owns a bounded 0.7 m grid, terrain/water/prop clearance and
A* routes. Returned segments are checked at at most 0.2 m intervals; actual steps
are grounded again. Lazy edge validation preserves safety without rebuilding
every edge after an edit.

The native editor emits a geometry-change signal for terrain, water and object
changes, including selected-object previews. Painting and tint changes do not
invalidate navigation. Colliders and navigation rebuild on successive physics
boundaries, and walking waits during reconciliation. Moved/deleted interests are
updated or cancelled by ID, with cooldowns surviving undo/redo.

## Verification and performance

The reproducible reel `roaming-and-building.mp4` shows a slow curious approach,
inspection, a quicker excited approach, and a rock placed ahead of the route.
Bigfoot stops with **?**, then notices and inspects the new obstruction.
Reproduce with `tools/film_bigfoot_life.gd` and `--write-movie` at fixed 60 FPS.

Targeted tests cover slope/water/edge/prop avoidance, subcell obstructions,
continuous gait, terrain-following feet, relative approach speeds, moved/deleted
targets, cooldowns, live edits, undo/redo, total habitat loss/restoration, queued
reset, repeated physical gusts, pickup/drop, pause and autonomous resumption.

`tools/profile_bigfoot_life.gd` records normal roaming near the 120 FPS cap.
The initial continuous-sculpt reproduction exposed a separate severe editor hitch:
waterfall rebuilding repeatedly flooded the same pond, then rebuilt scenery and
maps unnecessarily. The fixes reuse exact pond results, unchanged waterfall
geometry/spray, meadow instances and local water-map pixels. Shared pond vertices
reuse shoreline samples. Standalone creature scenes skip the unused original
encounter-ground index. Clearance checks reuse their capsule/query object and
avoid duplicate height reads. Reconciliation still runs on the existing physics
boundaries, without throttling it until the gesture ends.

`tools/profile_sculpt.gd` reproduces 30 raise/lower dabs at a requested 30 Hz in
the same live garden, including collision/navigation and rendering. Apple M5 Pro,
Metal Forward+, 1440×900, 120 FPS cap:

| Measurement | Before | After |
| --- | ---: | ---: |
| Median brush refresh | 277.5 ms | 19.2 ms |
| Worst brush refresh | 344.8 ms | 35.5 ms |
| Sculpt frame p95 | 353.2 ms | 30.4 ms |
| Worst sculpt frame | 379.6 ms | 48.3 ms |

The quarter-second stalls are removed in this reproduction; occasional spikes
remain and sculpting is not locked to 120 FPS. Timings are process-frame intervals,
not display-presentation measurements or guarantees for arbitrary gardens/hardware.
`sculpt-before.json` and `sculpt-after.json` retain the evidence; intermediate
reports show the isolated optimizations. Clearance-only A/B measurements preserve
all 1,280 safe nodes while reducing median rebuild from 8.93 to 5.36 ms.

Regression checks compare incremental terrain, water, instances and texture bytes
to forced rebuilds, including moved/deleted water and undo/redo. Additional tests
check cache invalidation and exact per-vertex pond attributes. `test-results.json`
records all **98 tests passing** in the final Metal / Forward+ suite.

## Current limits

This is a small repertoire, not a needs/social simulation. Interest is proximity
and reachability based; Bigfoot does not yet identify objects through true visual
perception. He looks and pauses rather than touching or using each object.
Climbing, swimming, articulated ragdolls and a separate running animation remain
future work. Excitement currently uses the same Walk clip at a faster cadence.

Narrow passages smaller than the navigation grid/capsule clearance can be
unreachable even if a visual gap exists. Terrain edits can require a short safe
relocation; there is no physical digging-out or climbing recovery. His current
behavior and position are transient; native saves contain the garden.

The underlying fidelity scene can report six ObjectDB instances at shutdown,
as it did before this work. This feature's tests verify body and behavior state
cleanup; the pre-existing shutdown leak is not repaired here.
