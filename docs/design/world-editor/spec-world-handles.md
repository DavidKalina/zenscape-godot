# World handles: everything the AI builds can be moved by hand

> 2026-10-17. Loop `world-handles`, branch `iter/world-handles` (from
> `iter/world-editor`; read `world-editor-handoff.md` first).

## The pipeline

Agents build the structure: motifs, routes, procedural pieces like the
stair to the clouds. The user tunes it by hand in the world view (F4):
moving, adding, grouping and adjusting knobs. Whatever is too
complex to tune by hand goes back to an agent. So every piece an agent
builds comes out with **handles**: a stable name, a movable transform, and
for procedural builds their knobs.

## What done looks like

The user plays the aqueduct isle, presses F4 and:

1. **Moves anything placed.** Every piece placed through the shared
   placers can be selected and dragged: the foot route's balustrades,
   ropes, beams, ferry and perch, the stair to the clouds' pieces, kit
   caches, coins, the route's standing stones, and the recipe pieces from
   the island view (anchored to their island). Register the placers
   (`scripts/interactables/foot_pieces.gd` host methods,
   `Art.floating_stones`, and the placers the stair and caches use) so
   new code that goes through them is named automatically.
2. **Groups.** Shift-click, or drag a box, to select several pieces. They
   move, turn and delete as one. A selection can be **saved as a chunk**
   (a named file of pieces relative to an anchor), and a chunk can be
   **stamped** from a list where the user looks, as free pieces or on the
   island under it. Chunks are recipes: they rebuild from current code.
3. **Islets.** A free piece kind: add a small islet from the list (the
   isle's `Art.island` blob), drag it, and set its size and seed knobs.
   It carries turf, so he can stand on it. Islets saved in the layout file.
4. **Knobs.** A selected procedural build shows a small panel of its
   knobs, starting with the stair to the clouds
   (`scripts/interactables/stair_clouds_foot_route.gd`): step count, rise,
   spacing, curve, or whatever it really takes. A changed knob rebuilds
   that build on release. Per-piece moves on top are kept where the build
   still has that piece. The same panel shows a slab's pumps, a ring's
   boost and the ferry's pace.
5. **Undo** (Cmd/Ctrl+Z) for every world-view action this loop adds and
   the ones before it.

## Rules

- The spec of `iter/world-editor` still holds: performance (a drag changes
  only transforms, rebuilds happen on release and only for what changed,
  nothing new per frame in play), the landing-strip warning, stable names, and
  the motif editor contract.
- Keep names readable and stable (`stair_clouds/step_7`,
  `foot_route/rope_2`, `chunk/<name>`); saved files key on them.
- Pieces that already have names keep them.

## Checks

Every iteration:
- Smoke `studies/zenscape.tscn` and `studies/aqueduct_isle.tscn` (with
  `-- --no-title`), and `studies/motif_editor.tscn` when the editor is touched.
- Run a throwaway driver through real input in `scratch/world_handles/`,
  with `--layout=/tmp/...` so it never writes the repo's layout file.
- Look at rendered stills of what changed. Use a throwaway ledger for play runs.

Prototype rules: no committed tests, no full suite. Cap and budget: the
iterate skill's defaults.
