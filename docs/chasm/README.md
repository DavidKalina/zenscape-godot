# Chasm terrain

Open **World → New chasm glade** in either the main cozy game or the diorama. Move the supplied long log across the middle of the gap with the ordinary selection tool. Bigfoot notices the opposite bank, waits for support, and balances across. The main cozy game saves an Open-able backup of the preceding world before creating the glade.

**Wild landscapes → Composition → Chasm** generates a seeded variation. Chasms also participate in ordinary cozy-world generation. Genome version 5 adds independently sampled width, bend, phase and angle. Existing version 3/4 recipe shapes and random draws are retained; older versions cannot request the new composition.

## Behavior

- The gap contains no terrain or collision floor. Both banks have exposed sides and independent bottoms; the old continuous skirt is hidden.
- Rendering, terrain picking, collision and worker navigation snapshots agree on the removed triangles. Custom terrain-growth attributes remain intact.
- Bigfoot avoids unsupported gaps. A low log resting on both banks can supply a checked walking surface above missing terrain. A hovering log cannot.
- Pushing him over the edge, releasing him over the gap, or removing his bridge starts an animated gravity fall. Pause freezes it. He then lands on the nearest currently safe bank, with no penalty. A log above his feet is not support.
- Both the diorama carry controller and the main cozy portrait carry resolve a deliberate void drop. Log pointer dragging continues across empty space.
- Saved worlds, restart and undo/redo preserve the topology. Plants and rest clearings stay on the banks. A pond that would drain into the gap cannot become a floating water surface.

Sculpting edits the banks but does not fill the missing triangles. Changing the landscape recipe replaces the gap layout. Flowing rivers, rafts and lily pads remain future work.

## Verification

`tests/test_chasm_terrain.gd` checks missing ground, through-gap picking and collision rays, bridge navigation, rejected unsupported crossings, recipe compatibility, custom mesh channels, snapshots, save/load, undo/redo and planting.

`tests/test_creature_void_fall.gd` checks gravity, paused simulation, recovery revalidation, landing events and rescue without GPU dependencies.

`tests/test_bigfoot_chasm.gd` exercises the main menu, pointer log placement, autonomous crossing, bridge removal, falling and pause, both carry paths, below-deck release, physical pushing and fresh main-game restart.

Run focused headless checks with:

```sh
python3 tools/check_bigfoot_living_regressions.py --tests test_chasm_terrain.gd --tests test_creature_void_fall.gd --output /private/tmp/chasm-focused
```

The full headless suite is attempted through the same tool without `--tests`. Headless cannot verify GPU readback or MultiMesh rendering; those checks remain unverified where the dummy renderer prevents them. Detailed results, earlier completed native checks, and the interrupted graphical-suite comparison are recorded in `validation.json`.

Only when a graphical capture is explicitly requested, run `tests/test_bigfoot_chasm.gd` with native rendering and `-- --capture`; it writes `/private/tmp/chasm-crossing.png`, `/private/tmp/chasm-fall.png` and `/private/tmp/chasm-glade.png`. Captures are deliberately not versioned.
