# Emergence

Phase 3, first slice (`feature/emergence-core`). Life arrives on land you made. You do not place it.

## What happens

When a sculpt stroke finishes (raise, lower, smooth, flatten, a mountain, or a filled pond), the chunk editor passes the stroke's bounding rect to `emergence.on_region_changed(rect)` (`scripts/emergence.gd`). The region then runs a succession:

| Stage | Starts | Done by | How |
|---|---|---|---|
| Grass and standing blades | 1.5 s | about 10–15 s | A front creeps out from the region's wettest ground at 1.4 m/s. Each cell then fills toward its target over 2.5 s. |
| Shrubs, ferns, flowers | 9 s | 21 s | Candidates on a jittered 0.9 m lattice. Ones nearer the wettest ground arrive first. |
| Trees | 18 s | 38 s | Candidates on a jittered 1.3 m lattice, ordered the same way. |

These constants sit at the top of `emergence.gd`.

A candidate's jitter, kind, size, angle and chance all come from `seeded_variety.gd` hashes of (salt, layer, lattice cell). The salt comes from the world's planting seed, or from a per-session draw on a blank plain. So the same strokes on the same world give the same result, and a different seed gives a different one. The conditions are checked when the candidate arrives, not when the stroke finishes, so a later stroke changes what arrives.

## The rules a candidate follows

These are the same rules the generator uses: the habitat and its cover come from the biome blend, `BIOMES` supplies `rock_slope`, snowline, treeline and tree counts, and trees are chosen per habitat as in `inland_landscape.form`.

- Nothing grows on water, on bare rock (slope above the habitat's `rock_slope`), or within 1.8 m of the snowline.
- Trees stop at the treeline (the genome's treeline in alpine ground, 10 m elsewhere). They thin out as the slope climbs from 0.45 to `rock_slope`, so forests on steep ground are sparse.
- Shrubs need a slope under 0.6.
- Crowding: tree to tree 1.1 m, tree to anything else 0.6 m, shrub to shrub 0.45 m. Existing objects of every source count.
- Cover target: grass follows the blend's `cover(p)`, fading to nothing on rock and near snow. Blades follow grass, are thickest toward water, and are absent on steep ground.

## Live biome

`BiomeBlend.live(data)` builds the blend from the edited terrain: the live heights, the pond surfaces rasterised on a 0.25 m lattice, and the stream beds. Worlds without an inland recipe read as a single woodland habitat. `refresh_rect(rect)` re-samples only the cells under the rect. The derived fields are then rebuilt across the whole 28×28 grid, which keeps the chamfer distance exact.

The recipe path is unchanged. `probe_biome_dressing.gd` gives identical digests before and after the refactor for seeds 33, 58, 176, 184 and 79.

## Provenance: hand edits win

- **Cover cells.** `NativeTerrainData.provenance` is a 56×56 byte grid aligned with the masks: 0 generated, 1 emerged, 2 hand. The editor's paint and erase brushes call `mark_hand` for every dab. Blasts, fire and the generators write masks without claiming cells. Emergence never touches a hand cell, and it only thickens generated cover (it never thins it). Emerged cover follows its target in both directions. Erasing a patch claims it too, so cleared ground stays clear.
- **Objects.** `"source": "hand"` or `"emerged"`, plus an optional `"pinned": true`. A record without a source reads as generated; this covers the generator's objects and everything saved before provenance existed. `NativeTerrainData.object_source(item)` resolves the source, and pinned counts as hand. The editor tags every object minted during a placement stroke as hand (`mark_objects_hand`). `update_object` also makes the edited object hand, the same way it drops `landscape`.
- **Emergence only adds.** The one exception: when a new stroke covers them, emerged objects whose ground has turned to water, rock or snow are withdrawn.
- **Saving.** The save stays at version 10, with `provenance` as an optional hex string. Older saves load with every cell generated. Undo history carries the grid.

## Pacing and cost

- `advance(delta)` runs in steps of 0.75 s. It returns true at most once per step, and the editor then calls `refresh()` once.
- **Batching is chunky on purpose.** Today `refresh()` rebuilds the whole mesh and view. `feature/stroke-pipeline` is making those rebuilds regional, and once it lands `STEP` can drop for a smoother creep.
- **Planning.** A stroke's plan runs on the first step after release, never on release itself. It costs about 10 ms on a warm blend. The first plan on a world also builds the live blend, about 35 ms, most of it pond flooding.
- **Step cost.** The steps themselves cost under 1 ms, not counting the refresh.
- **Pausing.** Emergence pauses while a stroke or selection edit is open, so emerged changes never fold into the player's undo step. Undo, load and new worlds clear pending work (`state_restored`).
- **Not saved.** Pending succession is not saved. Anything already grown is saved.

## Probe

`godot --headless --path . -s res://tools/probe_emergence.gd -- <seed>` raises a hill on a blank plain and on a generated world, prints cover and arrivals at 2–45 s, and checks four things: hand work stays intact, the salt determines the result, the save round trip works, and older saves still load.

## Open

- Hook `_stroke_ended` to `stroke_finished` from `feature/stroke-feel` once that branch lands.
- Arrivals should use the regrow grow-in animation rather than popping in.
- Should world time or season scale the pace?
- Water-first creep (grass from new ponds even without sculpting) needs pond fills to report their rect, which they do today only through the editor's pond click.
