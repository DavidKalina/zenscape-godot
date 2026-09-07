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

## Mouse playtest

A separate macOS app identity resolved the desktop-control targeting failure.
The visible controls were used to start flat, raise a hill, lower a hollow, paint
308 meadow cells, place a tree, rock and three individual flowers, fill one pond,
select Rain, and save. The app was closed normally and reopened. A second save
was byte-identical to the first:

`44f625b5c7a09cd02b40fa46401c67c34d788a3fa06c4d1dade092ed68e8aef7`

The authored world is preserved as `manual-garden.json`. The new input check
reproduced and fixed a missed first click when leaving the toolbar; picking now
uses the mouse event position, and the rendered integration test uses real camera
rays. Loading also restores vector coordinate precision, including near-zero
ray-picked positions.

## Clarified target: Build mode in the beautiful port

The user clarified that an editor with approximately similar visuals is not the
target. Build tools must operate in the original inspectable, rotatable fidelity
scene, on that chunk, with its camera, lighting, textures and shaders. Switching
from Inspect to Build should add editing tools without changing the landscape's
appearance or swapping to the old square sandbox.

The separate garden loop is functional and verified, but does not satisfy this
clarified integration requirement. Keep the goal active. Next work is to attach
editing to `studies/fidelity.tscn`, preserving the imported terrain topology and
material payloads, then connect blank initialization, planting, water authoring,
complete world saves, and the existing environmental controls there.

Rendering groundwork in this iteration:

- The port and garden use the same `LandscapeLighting` setup.
- Garden surfaces and water use the real source shaders and foliage materials.
- `GardenSurfaceMap` updates the port's surface texture channels after edits.
- The port's atmosphere compositor supports the garden's orthographic camera;
  its original perspective path remains intact.
- All 50 rendered test scripts passed, including live ground/water-map checks.
  Review then found that overlapping ponds could overwrite a higher water level
  with a lower one in the atmosphere map. The map now retains the highest surface;
  both insertion orders pass the added rendered regression. Atmosphere alone owns
  wind/gust shader globals.

This is shared rendering infrastructure, not a claim of native Build mode or
visual parity. Native Build mode must be verified against the unchanged port
before editing, and with representative authored landscapes after editing.

## Current scope

The 24-unit plot uses a 48-cell heightfield and remains bounded to −0.65 through
8 units vertically. Meadow seeds are stable per cell, and individually placed
objects use persistent IDs and ground-relative positions. Plants use original
ZenScape meshes; the stone is a small procedural mesh. Pond surfaces are clipped
to connected terrain triangles; open basins that spill off the plot are refused.
Precipitation remains the compact garden implementation; materials, lighting,
water and atmospheric compositing now use the port's rendering systems. Animation phases restart, while authored garden state and camera
framing persist. Object selection/movement, rivers, custom assets, and Workshop
are future work beyond this requested garden loop.
