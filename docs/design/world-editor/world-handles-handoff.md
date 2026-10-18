# World handles: handoff

> 2026-10-18. Loop `world-handles`, branch `iter/world-handles` (on top of
> `iter/world-editor`, `world-editor-handoff.md`). Spec:
> `spec-world-handles.md`. Trail: `git log --grep='^ITER(world-handles)'`.

## Play it

`./run-aqueduct-isle.command` (add `--foot-at=stair` or `--foot-at=stair_slabs`
for the stair), then F4 on foot.

| Key | Does |
|---|---|
| LMB / drag | select / move; on an island's ground, the island |
| Shift+LMB, drag a box on sky (Shift+drag over ground) | add to / drop from a group; box-select |
| wheel or PgUp/PgDn, Z X, T G | lift, turn, tip (a group about its middle) |
| `[` / `]` (Shift finer) | size rings and slabs |
| C, Del | duplicate, delete (whole group too) |
| 1 2 3 4 | add an air ring, bob slab, ring-stair slab, islet |
| K, J | save the selection as a chunk; list chunks and stamp one (Shift: free pieces) |
| U, O | from a piece to its island; open the island in the island view |
| Cmd/Ctrl+Z | undo, any world-view action |
| Cmd/Ctrl+S | save |

The bottom-right panel shows the selected piece's sliders: a ring's boost, a
slab's pumps, the ferry's pace, an islet's size and seed, and the stair slab
cut's count, rise, spacing, out and curve.

## What's built

- **Everything placed is named and movable:**
  - the foot route's balustrades, ropes, beams, ferry and perch
  - the stair to the clouds' flights, shrines, gate, turret, lancets and summit slabs, plus its rails and slabs
  - kit caches, tokens and the ring route's standing stones
  - the pieces placed in the island view (`isle_<island>/<id>_<n>`)
- **Size** for rings (the hole, trigger and bounce disc all scale) and for
  slabs (the footprint scales; thickness stays).
- **Rings throw along their tilt**, on the side away from the ground. An
  upright ring throws out the side he leaves through, with a 3 m lift
  floor. A cyan arrow shows the throw. `ring_a`'s line still lands.
- **Nothing is left behind when an island moves:** lanterns and their
  light, birds' perches, fireflies, undergrowth, leaves and laid plane parts.
- **Undo** for everything. **Groups** turn, tip, size, copy and delete
  as one. **Chunks** (`layouts/chunks/<name>.json`) are recipes holding
  rings and slabs.
- **Knobs** on the stair's slab cut, and **tunes** on single pieces.
  **Islets** are free pieces with turf and grass.
- The layout file gained the `sizes`, `knobs` and `tunes` blocks; added
  islets live under `added`. Drivers that pass `--layout=<file>` keep
  chunks and island recipes beside that file.

Checks: every step smoked zenscape, aqueduct_isle and motif_editor clean
and passed its real-input driver (headless and rendered where it applied).
The final smoke with a /tmp layout passed 3/3. The drivers live in
`scratch/world_handles/` and are uncommitted.

## Open

- The stone stair's step count and rise aren't knobs; they're baked into
  the mesa. Only the slab cut rebuilds.
- Chunks hold only rings and slabs. `[ / ]` doesn't size islets (use the
  slider). The LINK and landing-strip warnings don't see islets.
- Not named: the mesa, the pinnacle and the stair's rope bridge; the
  buried token and runes that drop later; sink slabs have no tunes. A
  moved stair flight keeps its baked shade.
- Island view: a piece moved in the world view still shows at its recipe
  spot there; a rope-carrying piece leaves its ropes; deleting a piece
  there renumbers later ones of its kind.
- Clicking into an arch's opening picks the island behind it; a token
  can win a click meant for the island under it. The status line keeps
  its last message.
- Panel drivers need `--rendered` (the headless window is too small).
