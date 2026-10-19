# The motif editor

> 2026-10-14. Design for an in-game editor where the user authors motifs
> by hand: the land, the kit pieces, the markers. Started after the
> Rootbound Cut (brainstorm/round2/): an agent built a place in an hour,
> and the weak parts (the tree, a floating henge, a rope in mid air) were
> taste calls the user would have fixed in seconds with a mouse.

## Why

Places put beauty
first, and beauty is the user's taste. Agents are good at what has an
answer (distances, routes, plans, flora, budgets) and slow at what doesn't.
So the user authors the place; agents do the grunt work after (route walks,
plan sweeps, sizes, dressing, the move into the pool). The old chunk editor
(NativeChunkEditor and the god-hand brushes, scripts/god_hand.gd) shaped one
heightfield plate; this one builds floating isles with kit stone on them.

**The bar is the old tools' ease, not the god hand.** What the user
wants back from the early game is how quick it was: pick a brush, shape
some terrain, drop a tree, done. The hand itself is not the point. Every
tool here should be that direct: one click or one stroke, seen at once.
Round 2 starts by surveying those tools (scripts/god_hand.gd, its brushes
such as Mountain and Ravine, NativeChunkEditor's native shaping,
stroke_feedback.gd) for what carries over to KitLand isles.

## What it is

An **in-game** editor scene, `studies/motif_editor.tscn`, on the motif
yard's base (studies/kit_isle.gd: the real look, sky, light, pilot, motor
and camera), so the place is judged in the look it ships in. It authors one
motif at a time and saves it to one text file.

Three tool groups:

1. **Land: generate fast, then update.** A landform **preset** (first: the
   whale-back hill; later the mesa, split gorge, crater bowl, spire
   cluster) shaped by **sliders** (size, relief, cliff step, outline
   jaggedness, cuts and slots, cave-in). A preset is a recipe for a
   `KitLand.island` spec (outline + ground function + cliffs + keel), so the
   kit's grabbable cliffs, keels and turf come free. **Re-roll** gives a new
   seed with the same sliders. Dragging a slider rebuilds the bare terrain
   (target well under a second); releasing it adds flora and life. Hand
   nudges on top: drag outline points; **stamps** that raise, lower or
   flatten a disc, or cut a slot along a stroke. Stamps are stored as data
   applied over the preset, never a baked mesh.
2. **Kit: stitch the pieces.** A palette of what can be placed: RuinKit
   pieces (`RuinKit.piece(id, seed, weathered)`, scripts/ruin_kit.gd
   FAMILIES), the cloister and belfry sets, rope bridges, stones, trees
   and other plants (the flora the isles already grow). Pieces
   **snap to the ground** (seated, sunk a little: nothing floats) and to
   each other's ends (arch to pier, wall to wall) and to cliff lips. Move,
   turn, tilt and sink handles for breaking and burying.
3. **Markers.** The spawn (where he stands in the yard), the rims in and out
   and the arena / cover / perch spots (the motif contract's sockets,
   scripts/kit_isle/kit_motif.gd), traps and enemies from a list, an
   enemy's patrol path as points.

**Play from here:** one key drops the pilot where the camera looks, live;
the same key returns to editing, the place unchanged. **Pilot-scale guides**
while editing: a jump-reach ring, ledge-height ticks, opening widths from
WorldScale, so a gap is judged before it is jumped.

## What it saves

One diffable file per motif under `motifs/authored/<slug>.json` (or
`.tres` if Godot resources prove simpler): the preset and its sliders and
seed, the stamps and outline nudges, the placed pieces (id, seed,
transform, weathered), the markers. Stored as recipes, not meshes, so kit
fixes carry through. One generic script, `scripts/kit_isle/
motif_authored.gd`, reads a file and answers the motif contract (footprint,
height span, occupancy, sockets, `build`), so an authored motif goes into
`scripts/kit_isle/greybox/registry.gd` like any other and the yard shows it
with `--motif=<slug>`.

## Variation

An authored motif is fixed per seed at first. Later: mark pieces and
stamps as optional or ranged, so knobs can vary it.

## Round 1 (the first slice)

Enough to rebuild the Rootbound Cut by hand and compare:

- the whale-back hill preset, 5-6 sliders, live terrain rebuild, re-roll;
- placing RuinKit pieces from a palette, snapped to the ground, move/turn;
- the spawn and two rims;
- play from here and back;
- save and load the file; `motif_authored.gd` reads it and the yard stands
  it (`--motif=<slug>`).

### What the user put first (2026-10-14, after round 1 was briefed)

1. **Terrain above all.** Slopes, hills, mountains, ravines and bodies of
   water, made really easily, and changing the landform's shape and
   silhouette. This is round 2: brushes in the old tools' spirit (raise,
   lower, smooth, flatten, carve a ravine along a stroke, pour water) over
   KitLand isles, plus dragging the outline for the silhouette, alongside
   more presets (mesa, mountain, gorge, crater).
2. **Kit pieces that know how to fit.** Attach an aqueduct and it fits and
   connects: each piece declares its connectors (an aqueduct span's two
   ends, an arch's springers, a wall's ends, a rope bridge's anchors) and
   the editor snaps a new piece onto a free connector, follows the ground,
   and fills a run between two points with spans.
3. **Load a motif, copy it, edit it.** The kit motifs and greybox motifs
   saved as editor files (their land as a recipe, their pieces as placed
   pieces), so any motif opens in the editor, duplicates and changes.

### Round 3: the old game's UI (2026-10-14, the user's ask)

"I want to be able to build the levels sort of like a game... we've
already built so much of it." The early game's build UI comes back on the
editor: the searchable palette with thumbnails rendered from the real
meshes and drag-in ghosts (scripts/native_build_palette.gd), its tool
roll and styling (hud_icons.gd, hud_linen.gd), the clay tools
(scripts/clay_tools/: mountain, hills, crater, bowl, island, chisel, drawn
line, can...) re-pointed from the old chunk heightfield to the editor's
recipe data, so a ravine is drawn, a lake circled and filled, a landform
stamped; and their feel (stroke_feedback.gd, clay_sound.gd,
clay_tremor.gd). The landform generator stays as a panel of sliders in the
top left, in the same styling. Pieces that know how to fit move to round 4,
load/copy/edit to round 5.

Later rounds: more presets, stamps and outline nudges, piece-to-piece
snapping, rope bridges, traps and enemies with patrol paths, undo, the
pilot-scale guides, optional pieces.
