# Garden sandbox implementation and validation

The requested loop is implemented in `scenes/sandbox.tscn`: start flat, sculpt a
hill and hollow, paint a meadow, place a tree/rock/individual flower, fill a pond,
change weather, save, and reopen the garden.

## Evidence (2026-09-07)

- `tests/test_landscape.gd`: the original 17 terrain checks pass.
- `tests/test_garden.gd`: flat initialization, complete undo/redo, rooted objects,
  full-precision JSON persistence, invalid-document rejection, old-save migration,
  and creation/load capacity boundary round trips pass.
- `tests/test_garden_scene.gd`, run with Metal/Forward+: constructs the requested
  garden through tool handlers, checks actual rendered instance anchors, fills
  only connected terrain, prevents duplicate water on refilling, changes weather,
  writes a temporary save, destroys the scene, and loads a fresh scene. The world
  document, camera framing, shoreline vertices, and rendered tree anchor match.
- All 49 `tests/test_*.gd` scripts passed in a sequential graphics-backed run.
  After the review's capacity and duplicate-pond fix, the garden model and rendered
  integration tests passed again.
- Clear, mist, rain, snow, and reopened screenshots were captured and the clear,
  rain, and snow renders were visually inspected. Captures are in this directory.

Run model checks headlessly. Run scene checks with graphics: Godot's dummy
renderer does not return actual MultiMesh transforms and its camera projection
results differ from the real window. Those tests must exercise the real renderer.

## Review

The Standards and Spec reviewers both identified the same durability defect:
creation had no cap, while loading capped objects and ponds. Creation now enforces
shared limits and shows a refusal message. Refilling a connected pond replaces its
water record instead of stacking surfaces. Boundary round trips are covered.
A nonblocking maintenance suggestion remains: consolidate weather parameters if
more profiles are added.

## Remaining verification

The automated scene test calls tool handlers; it does not replace an end-to-end
mouse playtest. Desktop control successfully selected tools and sculpted in an
isolated temporary save, then repeatedly lost its actionable window connection
(`noWindowsAvailable` / concurrent-change errors). A complete mouse-driven loop
and reopen remains pending. The overall goal should remain active until this
interaction gap is resolved.

## Current scope

The 24-unit plot uses a 48-cell heightfield and remains bounded to −0.65 through
8 units vertically. Meadow seeds are stable per cell, and individually placed
objects use persistent IDs and ground-relative positions. Plants use original
ZenScape meshes; the stone is a small procedural mesh. Pond surfaces are clipped
to connected terrain triangles; open basins that spill off the plot are refused.
Weather is a compact garden implementation, not the fidelity scene's full weather
simulation. Animation phases restart, while authored garden state and camera
framing persist. Object selection/movement, rivers, custom assets, and Workshop
are future work beyond this requested garden loop.
