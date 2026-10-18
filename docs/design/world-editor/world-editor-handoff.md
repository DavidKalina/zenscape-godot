# World editor: handoff

> 2026-10-17. Loop `world-editor`, branch `iter/world-editor`. Spec:
> `spec-world-editor.md`. Trail: `git log --grep='^ITER(world-editor)'`.

## Play it

`./run-aqueduct-isle.command` (or `run-zenscape.command --no-title`). Press
F4 on foot to open the **world view**.

| Key | Does |
|---|---|
| F4 | world view on/off; back in play he drops where you look |
| LMB | select a piece, or an island by its ground; drag to move |
| wheel / PgUp PgDn, Z X, T G | lift, turn, tip (islands don't tip) |
| U | from a piece to the island it stands on |
| C, Del, 1 2 3 | duplicate, delete, add a ring, bob slab or ring-stair slab |
| O | open the selected island alone in the motif editor (**island view**) |
| Cmd/Ctrl+S | save |

In the island view, F4 saves the island's recipe and goes back to the world.

## What's built

- **Named pieces** (`scripts/layout_overrides.gd`): the ring route and the
  foot route's bob slabs and rings, moved, added and deleted through
  `layouts/aqueduct_isle.json`.
- **Islands as units** (`scripts/world_islands.gd`): `island/near`, `far`,
  `west_islet` and `east_islet`. Everything standing over an island's
  outline is anchored to it on the first F4, and grass rides along. A
  release refreshes turf, pools and path dirt (about 1 ms). Island moves are saved
  under `"islands"` and applied at load. The parked plane follows its island.
- **Free pieces:** rings and slabs belong to no island.
- **Links:** the aqueduct splits at its fallen span and each half follows
  its island. The stumps spread out between the islands. The gap stretches,
  and a red LINK line shows when a jump changes.
- **Landing-strip warning:** a red line when an island's longest clear
  turf run drops.
- **Island view** (`scripts/kit_isle/isle_island_motif.gd`,
  `scripts/kit_isle/isle_recipes.gd`): the isle's own island in the motif
  editor. Pieces, traps, mechanics and the spawn marker placed there save
  to `motifs/authored/isle_<name>.json` and are laid over the island in game,
  moving with it.
- **Mechanics pocket** in the motif editor (lane palette): air ring, bob
  slab, ring-stair slab, swing rope, drift (ferry) slab, kit cache.

Performance: dragging costs only transforms. Fps while dragging matched the
idle world view from the same camera (about 14 ms a frame, rendered,
uncapped). With edit mode off, nothing new runs.

## Open

- The island view's land and the isle's own ruins are read-only, so the
  island can't be reshaped and the stone circle can't be moved.
- The island view lacks the foot route's pieces and Life. It opens at the
  island's coded spot, and it uses the editor's light, so the turf reads greener.
- Pieces added from a recipe aren't anchored for world-view boxes or
  picking. Breakable recipe pieces don't break by slam in the isle.
- Still unregistered: the foot route's balustrades, ropes and ferry, the
  stair to the clouds, caches and coins, and the far motif isles.
- Songbirds keep their old trees after a move. Headless runs anchor fewer
  pieces (no cached visuals). Turning an island swings its link a long way.
- `scratch/world_editor/save_drive.gd`'s strip case (10/11) predates the links
  riding along; its scenario needs a new setup.
- Follow-up loop: `spec-world-handles.md`.
