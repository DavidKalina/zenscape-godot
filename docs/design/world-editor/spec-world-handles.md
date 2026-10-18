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
1b. **Size.** (Spec change 2026-10-17, to do right after goal 1's
   current task.) A selected air ring or slab (bob, ring-stair, drift,
   foot slab) grows or shrinks with `[` / `]` (Shift: finer), so the
   user can say "this slab is hard to land on, bigger" or "this ring
   smaller, for precise platforming". It's a gameplay size, not only a
   look: a ring's hole, its trigger and its top's bounce disc scale with it;
   a slab's footprint and collision scale with it, and its thickness stays.
   It shows the size in metres in the status line, is saved per name in the
   layout file like a move, and rebuilds only that piece on release. Rings
   and slabs added in the world view and from the island view's Mechanics
   pocket take it too.
1c. **Rings throw along their angle.** (Spec change 2026-10-17, right
   after 1b.) Today a ring taken in flight launches him straight up in
   world space whatever its tilt (`_take_ring` in
   `scripts/interactables/foot_pieces.gd`: only velocity.y is set). Make
   the boost go along the ring's axis, on its side away from the ground
   (the axis's upward half; for a ring standing upright with its axis
   level, the side he leaves through), at the same POP strength. A flat ring
   throws straight up as now; a ring tipped 45° throws him 45° out; the
   user aims a ring by turning and tipping it in the world view.
   Keep enough rise that an upright ring still carries him (judge it in
   play, say how). Check the ring route and foot route still play their
   lines; a ring placed tipped on purpose (`ring_a`) may now throw
   differently: retune its tip so its line still lands, and say so. A ring
   shows its throw direction as a short arrow in the world view.
1d. **Nothing left behind.** (Spec change 2026-10-17, right after the
   current task.) The user dragged an island and the lamps (the stone
   lanterns by the paths) stayed put, and "some of the other stuff". The
   isle's anchoring only walks `world_roots()` in `studies/aqueduct_isle.gd`,
   so anything built under another root is missed. Sweep for it: in a
   rendered run, record every visible node (and every collider) whose
   world bounds lie over an island, drag the island, and list each one
   that didn't move. Anchor all of them, unless they're meant to stay (sky,
   clouds, weather). Lamps, their lights, props, decals, particles,
   wildlife homes (the songbirds' trees) and audio emitters should all go
   with their island. Commit the driver's before/after list in the commit
   Notes. Then drag each of the four islands and show a before/after still.
2. **Groups.** Shift-click, or drag a box, to select several pieces. They
   move, turn and delete as one. (Spec change 2026-10-17: the user's
   example is a run of rings.) Turning (Z/X) and tipping (T/G) a group
   swing it about the group's middle, each piece keeping its place in the
   group; `[ / ]` sizes every ring and slab in it; C duplicates the whole
   group. Shift-click again drops a piece from the selection. The selection
   boxes and throw arrows show on every selected piece. A selection can be **saved as a chunk**
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
   Also: the red LINK and LANDING STRIP warnings run into the key list at
   the top left when they're long; give them their own space (wrap at a
   width, or stack under the status line).
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
