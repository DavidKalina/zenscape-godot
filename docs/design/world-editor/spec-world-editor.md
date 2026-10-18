# World editor: islands as units, edited alone

> 2026-10-17. Loop `world-editor`, branch `iter/world-editor` (from the
> layout edit branch: `docs/design/layout-edit/layout-edit-handoff.md`).

## What done looks like

The user plays the aqueduct isle (`run-zenscape.command --no-title`), presses
F4 and gets the **world view** (the layout edit mode, `scripts/layout_edit.gd`):

1. **Islands are units.** Clicking an island's ground selects the island.
   Dragging or turning it moves everything on it as one: its ruins, turf,
   grass, standing stones, caches, balustrades, ropes, coins and markers.
   A key steps out of a piece to the island it stands on.
2. **Free pieces (choice C).** Air rings and bob slabs, and anything else
   floating in the air between islands, belong to no island. They are
   placed and moved in the world view, as now.
3. **Links (choice B).** Aqueducts and rope bridges that span two islands
   are links. When either island moves, the link refits on release (an
   aqueduct refit is ~0.8 s; a hitch on release is fine, a hitch on drag is not).
4. **Island view.** With an island selected, one key opens it alone in the
   motif editor (`studies/motif_editor.tscn`). There the user changes its
   size and shape and puts things on it with the editor's existing tools.
   Saving it and going back returns to the world view with that island
   rebuilt from its saved recipe at its world spot, the rest of the world as
   it was.
5. **The palette lane's mechanics** can be placed on an island in the island view:
   air rings, bob slabs (and the ring-stair slab), ropes, the drift (ferry)
   slab and kit caches.
6. Everything the user changes is saved in files the game reads on load
   (the layout file `layouts/aqueduct_isle.json`, plus one recipe per
   edited island), so it survives code changes and a restart.

## Rules

- **Performance:** a drag only changes transforms. Turf, grass, lips,
  links and refits are redone on release, and only for what moved. With
  edit mode off, nothing new runs per frame. Report fps while dragging an
  island against plain play, the way round 1 did.
- **Landing strip:** every isle the plane can reach keeps turf long enough
  to land on (AGENTS.md). The world view warns, on screen, when a move,
  delete or island-view edit takes that away. It doesn't block.
- **Anchoring without rewiring every call:** prefer giving each
  placement its island automatically at build time (for example, the
  island whose outline it stands over), over editing every placer by hand.
  Floating pieces with no island under them are free pieces.
- **Two land systems.** The isle's islands are built by
  `studies/aqueduct_isle_art.gd` (`Art.island`), while the motif editor builds
  KitLand. Teach the editor to open the isle's island type first, so
  nothing looks different until the user changes it. Converting islands to
  KitLand isn't part of this loop.
- **Motif editor contract** (AGENTS.md): keep piece ids stable and changes
  additive, so `motifs/authored/*.json` build as before. Smoke a kit motif
  and an `editor_*` motif in the motif yard after touching the editor.
- **Stable names:** islands, links and pieces keep readable names
  (`island/east_islet`, `link/aqueduct_main`, `ring_route/ring_a`). Saved
  files key on them.

## Lanes and trunk

- **Lane `palette`** (its own worktree, `lane/palette`, branched from
  `iter/world-editor`): goal 5. It adds the mechanics to the motif
  editor's palette and to `scripts/kit_isle/motif_authored.gd`'s build, so a
  saved motif holding them plays. It keeps its code in new files where it
  can, and keeps its edits to `studies/motif_editor.gd` small and additive.
  The trunk doesn't do goal 5. It's merged before the trunk's island view step.
- **Trunk** (this loop): goals 1 to 4 and 6, in order: island registry and
  anchoring, island drag with refresh on release, links, island view open
  and return. The first iteration writes the Plan.

## Checks

Every iteration:
- Smoke `studies/zenscape.tscn` and `studies/aqueduct_isle.tscn` (with
  `-- --no-title`), and `studies/motif_editor.tscn` when the editor is touched.
- Run a throwaway driver through real input in `scratch/world_editor/`.
- Look at rendered stills of what changed. Use a throwaway ledger
  (`--ledger=/tmp/...`) for any play run.

Prototype rules: no committed tests, no full suite. Cap and budget: the
iterate skill's defaults.
