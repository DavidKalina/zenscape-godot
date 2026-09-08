# Live editing while Bigfoot roams

Measured in Open Meadow with Godot 4.7.2, headless, September 8, 2026.
These are CPU timings, not rendered/displayed frame-rate measurements.

Before: two object placements took 10–11 ms to refresh visuals and 58–206 ms
for synchronous navigation rebuilds. Two sculpt dabs took 9–15 ms to refresh
and 61–62 ms for navigation. Forming a foundation took 134 ms to compute,
96 ms to refresh, and 48 ms for navigation.

The live Fidelity/Open Meadow and Bigfoot Life controllers now scan navigation
in 2 ms slices. Water/obstacle preparation and final reconciliation are outside
that scan budget; this is not a hard cap on the entire scene frame. A new edit
restarts the scan, and no path is returned from an incomplete map. Walking waits
for completion while actor animation, fish, and existing thrown stones continue.
Previously every dab stopped the actor, rebuilt navigation, then resumed walking;
a sustained stroke could repeatedly restart the Walk clip near its first pose.

The Open Meadow integration test executes twelve consecutive brush refreshes
through the actual scene process callback. Its maximum measured callback was
6.8 ms after the change. It checks that the actor stays in place during rebuilding,
the idle animation progresses, the completed map exactly matches a synchronous
rebuild, and the final actor location is safe.

Validation:

- tests/test_navigation_budget.gd: pass (yielding, restart, partial-route rejection,
  exact map equality).
- tests/test_live_edit_navigation.gd: pass (Open Meadow edit/animation integration).
- tests/test_creature_navigation.gd: pass (obstacles, slopes, water, detours).
- tests/test_bigfoot_life_editor.gd: pass (physics boundary, carry, undo/redo,
  blocked habitat, recovery, deferred reset).

Terrain formation follow-up: the palette now runs recipe height/gradient sampling,
pond grid sampling, terrain face rebuilding, and ground-map rows with a cooperative
2 ms budget. The existing synchronous path remains available for loading, undo,
and offline tools. During live formation, other editor writes and route planning
wait; camera, world clock, actor animation, fish, and projectiles continue.

A second timing pass isolated 114 ms of recipe sampling, 21 ms of mesh work, and
56 ms of surface-map work. Mountain generation additionally exposed about 100 ms
of lazily sampled pond terrain, now prepared within the same frame budget.

`tests/test_formation_responsiveness.gd` exercises the palette action dispatcher
in Open Meadow for both foundation and mountain formation. The measured maximum
main-loop gaps were 10.1 ms and 11.0 ms respectively (headless CPU measurements,
not a claim about displayed FPS). Computation takes multiple frames to finish;
the budget targets responsiveness rather than less total computation.

The test checks that world and actor clocks advance, competing edits are blocked,
the mesh and both surface textures match a cold synchronous rebuild byte for byte,
and each formation remains one undoable operation with exact redo. Existing native
range, turf foundation, incremental refresh, live navigation, and Bigfoot Life
editor integration tests also pass. Palette tests now wait for formation completion
before inspecting generated terrain.
