# Motif editor, round 1 (handoff)

> 2026-10-14. Round 1 of docs/design/roguelike/level-editor.md. Nothing committed.

## Run it

```
godot --path . res://studies/motif_editor.tscn -- --no-title [--load=editor_hill]
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=editor_hill    # the generator form, in the yard
```

## Controls

| Editing | |
|---|---|
| hold right mouse + move | look round |
| W A S D, Q E, Shift, wheel | fly, down/up, fast, fly speed |
| left click a piece or marker | select it; drag to move it along the ground |
| palette item, then left click the ground | place it (Shift+click keeps placing; Esc stops) |
| Z / X (Shift: fine) | turn the selected piece 15 deg (5 deg) |
| Delete / Backspace | delete the selected piece |
| G or "Dress" | dress again (turf, flora, life) |
| Ctrl+S (or Cmd+S) / Load list | save / load `motifs/authored/<slug>.json` (the slug is the panel's field) |
| P / Shift+P | play from the spawn / from the ground under the camera's middle; P again goes back to editing |

When you play, the pilot uses the real study base (motor, input, camera). The net 60 m under the keel puts him back at the spawn.

## What works

- **The scene.** `studies/motif_editor.tscn` and `.gd` extend `studies/kit_isle.gd` with the yard's sky (`studies/motif_yard_sky.gd`). The motif stands as a `MotifIsle` in a `MotifSky`, the same way the yard and the generator stand theirs, so the look matches what ships.
- **The land.** The whale-back preset has length, width, relief, cliff step (it defaults to `RuinKit.SET_OFF` so the terraces can be climbed), jaggedness and a seed. Moving a slider rebuilds the bare land and pieces as you drag. Letting go dresses the motif again with turf, flora and life. Re-roll draws a new seed and keeps the sliders. Markers the land shrinks away from move back inside the outline.
- **Kit pieces.** The palette holds every RuinKit piece plus three trees: the game's hero oak, birch and willow glbs (`scripts/hero_trees.gd` `_build`), each with a trunk collider. A piece is seated on the lowest ground under its footprint and sunk 0.15 m. A selected piece gets a yellow ring. A piece's y is worked out again from the ground on every build, so a re-rolled hill never leaves one floating.
- **Markers.** The spawn, rim in and rim out are draggable poles. Each rim's arrow faces out from the hill's middle.
- **Save and load** work, along with `--load=`.
- **The generator form.** `scripts/kit_isle/motif_authored.gd` reads the file and answers the contract (see below). `scripts/kit_isle/greybox/au_editor_hill.gd` is the two-line subclass the registry uses. One registry line was added: `editor_hill`.
  - The contract: footprint, height span and occupancy (a keel sampled every 4 m plus each piece's box), rim sockets (lip to the outline, run-up kept clear of the pieces), start, summit, flora site and life.

## Proof

- `python3 tools/smoke.py studies/motif_editor.tscn` PASS.
- `python3 tools/smoke.py studies/motif_yard.tscn -- --motif=editor_hill` PASS. `rootbound_cut` still PASSes.
- The driver `scratch/editor_drive.gd` passed 32/32 checks, all through real mouse and key events:
  - dragging the Length slider by mouse (9 live rebuilds);
  - placing a pier, an arch, an oak and a fallen pier from the palette, each seated with every corner at or under the turf;
  - clicking, dragging and turning a piece with X, then deleting one;
  - dragging the spawn marker;
  - Ctrl+S, then reloading and getting identical data;
  - P, walking 5.3 m, and P back with the camera and data unchanged.
- Rendered stills: `scratch/shots/editor.png`, `editor_close.png`, `editor_play.png`.

## Timings (headless, this Mac)

| Land | Bare rebuild | Dress |
|---|---|---|
| default 64 x 40 | ~100 ms | 130-230 ms (flora ~150 ms and life ~40 ms follow over frames) |
| 120 x 70, relief 12 | ~450 ms | |

All of these are under the 1 s target. If the last bare rebuild took over 250 ms, the next one while dragging is coarse (no crisp cliffs, `fast` spec, ~16 ms). Rebuilds are also spaced by a debounce. On a rendered run the dressed isle is built on the main thread on purpose: waiting on a worker build from the main thread deadlocks.

## File format

`motifs/authored/<slug>.json` stores recipes, not meshes. Keys are written in a fixed order and numbers are snapped to 1 mm, so the files diff cleanly.

```json
{
	"format": 1, "slug": "editor_hill", "name": "Editor Hill", "preset": "whale_back",
	"sliders": {"length": 41.0, "width": 40.0, "relief": 9.0, "step": 1.6, "jag": 0.4},
	"seed": 1,
	"pieces": [{"id": "pier", "seed": 1823, "weathered": 0.3, "at": [4.566, 8.019, 1.968], "turn": 15.0, "sink": 0.15},
	           {"id": "tree_oak", "seed": 7609, "weathered": 0.3, "at": [6.164, 8.073, -1.303], "turn": 0.0, "sink": 0.15}],
	"markers": {"spawn": [x, y, z], "rim_in": [x, y, z], "rim_out": [x, y, z]}
}
```

A piece's "transform" is its position plus its yaw (`turn`, degrees). Each piece's `y` and each marker's `y` record where the editor seated it. Both are re-grounded on every build.

## Stood in or missing

- **Trees look faceted.** They use a plain vertex-colour material, not the flora's wind and tint shader, so they read low-poly against the painterly look. They also don't sway.
- **Pieces only sit on the land.** There is no stacking on other pieces and no snapping to piece ends or cliff lips. There are no tilt or sink handles yet (`sink` is in the file).
- **Piece edits don't regrow the plants.** Adding or moving a piece doesn't regrow the flora, so grass can poke through a newly placed piece until you press G.
- **Clicking a piece** ray-tests its colliders first. If that misses, it takes the piece whose drawn middle is nearest the click on screen. This is how a sunk piece or a tree crown gets picked.
- **Missing features:** undo, stamps and outline nudges, more presets, the arena/cover/perch markers, the pilot-scale guides, Windows-tested paths.
- **The JSON won't ship in exports** unless the export filter includes `motifs/*.json`.
- **The turf reads orange.** This is the live sky's autumn, the same look as the other isles.
- **`motif_authored.gd` was already committed.** An early version of it was swept into the user's commit b74fcfd5 ("feat: skills and stuff") while this round was running, so its later edits show as a modification.

## Round 2, first

1. Add **undo**: snapshot `data` per action. The file is small, so this is cheap.
2. Add **raise, lower and flatten stamps** and **outline point drags**, stored as data over the preset.
3. Add **snapping**: piece to piece (arch to pier), piece to cliff lip, and pieces stacked on pieces (seat on the highest collider under the footprint).
4. Give the trees the flora's material (the TINT/OWN path through the catalog's reference material) so they match the painterly look and sway.
