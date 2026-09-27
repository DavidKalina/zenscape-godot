# Genesis canvas and the land brush

Phase 3, first slice (branch `feature/genesis-canvas`, 2026-09-26).

## What changed

- **Launch onto a blank plain.** The product scene (`studies/cozy_worlds.tscn`) now opens onto a quiet, misty, gently undulating plain (`scripts/genesis_canvas.gd`).
  - The swells are about a metre tall, the ground is fully grassed, and a few patches of standing blades are scattered over it.
  - There are no trees, water or objects.
  - The sky and land colours come from a curated palette family (a meadow draw at dawn or full day), with mist weather and thin ground fog. Living weather drifts from there.
  - *Since slice 2:* the plain uses Fidelity's own ground, foliage, rock, earth and water colours under a clear day sky, in fair weather with a thin ground mist (`Genesis.FIDELITY`). The badge reads "Fidelity green".
  - The badge reads "Open plain · <family>".
- **Regrow is unchanged.** It still folds the plain away and grows a full generated world, and Undo restores the plain.
- **World → New open plain** folds any world back into a fresh plain, with the same animation and the same Undo.
- **Creation is the default tool state.**
  - The land brush is in hand at launch and the build palette stays hidden.
  - **Craft** in the toolbar opens the old palette and tool rail, with the last fine tool in hand. **Create** returns to the land brush.
  - A one-line hint along the bottom of the screen lists the brush controls.
- **The land brush** is the `land` mode in `scripts/native_chunk_editor.gd`, backed by `scripts/land_brush.gd`.
  - Each dab has a broad, smooth quartic shoulder and a quicker Gaussian core, so land rises fastest under the pointer.
  - A world-seeded, domain-warped ridged noise field (`land_seed`, which is the world seed) scales each vertex's rise between 0.4× and 1.6×. Repeated strokes therefore grow crests and spurs rather than round blobs. Lowering follows the noise troughs instead.
  - Rising slows over the top 40% below the ceiling (`land_ceiling`, 10 m) and stops at it. Land that already stands above the ceiling is left alone. Lowering eases out towards −1.2 m.
  - Only vertices in the 2 m buckets under the brush are visited. A dab costs about 35 µs in GDScript.
  - When the stroke ends, the native erosion kernel (`TerrainErosion.erode`) runs once on the 41×41 grid. Every cell outside the stroke's bounds (plus 1.4 m) is locked through `fixed`, so the rest of the world does not move.
    - The erosion adds no detail noise, so repeated passes do not stack a pattern.
    - One pass takes about 9 ms, most of which is sampling the grid.
    - The pass runs inside the stroke's transaction, so one Undo removes the stroke and its gullies together.
    - `land_weathered(bounds)` is emitted when it lands.
  - Steep faces (slope above 0.93) paint as rock and land above about 6.5 m takes snow. This comes from the existing blank-world shading, not new code.

## Try it

Run `./run-cozy-flow.command` and try the following:

1. Wait for the misty plain to appear.
2. Drag slowly across the middle. A soft ridge should rise under the pointer.
3. Drag back over the same line. It should grow crests and shoulders, not a bigger dome.
4. Release the mouse. After a short beat, gullies should settle into the slopes. Check whether they read at the overview distance.
5. Hold Shift and drag, or right-drag, to press a hollow.
6. Press `[` and `]` to change the brush size, and Shift+`[` / `]` to change its strength.
7. Stroke the same spot for a long time. The peak should flatten out at about 10 m, with rock on its steep faces and snow on top.
8. Drag from the sky, or Alt-drag, to orbit. Middle-drag pans.
9. Press Cmd+Z to undo the last stroke, including its gullies.
10. Press **Craft** to open the fine tools, then **Create** to go back to the land brush.
11. Press **Regrow landscape** for a generated world, and paint over it too. Then use World → New open plain to get a fresh plain.
12. Press Esc to open the menu.

## Flags

Pass these after `--`, for example `./run-cozy-flow.command -- --generated`.

- `--generated`: the old launch. It opens the saved place, or the valley when there is none.
- `--seed N`: implies `--generated`, then regrows seed N, as before.
- `--resume`: opens the last saved place, which may be a plain.
- `--plain-seed N`: a reproducible plain.
- `--classic-build`: the old Build/Enjoy toggle, with no creation mode.

Launching onto a plain means the next save overwrites `user://cozy-worlds/places.json`. The launch first copies it to `places-previous.json`.

`[` and `]` size the brush while creating. Alt+`[` / `]` still step through the showcase seeds, as do plain `[` / `]` in Craft.

## Unverified

The checks were headless only: parse checks and a launch probe covering the plain's heights and grass, the tool state, dab cost, the ceiling and floor, erosion locality, the craft round trip, and regrowing to seed 184 and back. The following have not been seen on screen:

- Whether the plain reads as misty rather than grey, and whether the fog (0.30–0.44) hides the land too much under the Balanced preset.
- Whether the gullies are strong enough to read (the largest change is about 0.24 m on a 3 m ridge). If not, `WEATHER.k` and `max_cut` in `scripts/land_brush.gd` are the knobs.
- Whether the brush circle shows at the 4.5 m size.
- Whether the one-line hint sits clear of the notice text.
- How the drag feels at speed. Every dab batch still runs a full `refresh()`, and `feature/stroke-pipeline` makes that regional.

## Later

- The creation UI rebuild, with no Enjoy toggle. At present, H hides the UI but the brush stays in hand.
- Feed stroke provenance into emergence (`feature/emergence-core`).
- Animate the settle instead of applying the erosion as a single step.
