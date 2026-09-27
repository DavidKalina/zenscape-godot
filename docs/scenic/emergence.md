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
- Emerged grass fades to bare ground between `BARE_SLOPE` (0.9–1.15) of the habitat's rock slope, so gentle hills stay green.
- **Sizes.** Trees draw their record scale from `TREE_SIZE` (0.65–1.0) and undergrowth from `SHRUB_SIZE` (0.5–0.9). `KIND_SIZE` then brings the models into proportion with each other and with the creatures (a deer stands about 1.2 m): the layered broadleaf ×0.55 (5.9 m tall at scale 1, so 2.1–3.2 m), the hero oak ×1.45 (1.9 m, so 1.8–2.8 m), the redwood ×0.6 and the fern ×0.6 (1.6 m across at scale 1). Spruces keep 1.6–4.5 m. Generated worlds are unchanged.
- **Ferns** take `FERN_WEIGHT` (0.3, it was 1.0) in emerged woodland undergrowth: from above they read as dark spiders. The fern mesh (`scripts/redwood_assets.gd`) now has nine fuller fronds in a fresher green, so the ones that come read as leafy rosettes.
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

## Growing in

Every arrival grows in with the regrow pop: it rises from the ground and overshoots into place, at its own birth. Nothing that stood before re-pops.

- **The clock.** `Emergence.time` is a static clock that `advance` moves every frame, busy or not, and publishes as the global `zs_emergence_time`. It is shared and never reset, so a birth can't land in a later world's future.
- **Objects.** An arrival's record gets `"born"`: its scheduled time plus one step, so it falls somewhere in the next 0.75 s. The arrivals of one step then rise one at a time instead of together. `GardenInstanceSamples` copies `born` into the instance source, with a rise time from `Emergence.rise_seconds`: trees take `TREE_RISE` (1.8 s) and everything else `SHRUB_RISE` (1.1 s). GardenView writes `(fire char, fire burn, born, rise)` into the MultiMesh custom data. `_write_fire` takes the birth from the source, so a fire update keeps it. It never reads the value back from the GPU.
- **Shaders.** `reference_surface`, `layered_tree_wood` and `layered_canopy_surface` gain `instance_birth_enabled`, which GardenView sets on its materials. `zs_birth_growth(born, rise)` in `reference_globals.gdshaderinc` gives the grow-in, and the shaders take the min of it and the global and wave grow-in (`zs_growth.y`, `zs_growth_wave_at`). An instance with no birth has rise 0 and reads 1, so generated and hand plants behave as before. The pop also applies to materials without `plant_growth`, such as the cactus. A birth more than 20 s in the future reads as grown.
- **Meadow tufts** (the blades cover). `data.cover_births[cell]` holds a birth for each of the cell's 8 tufts. When a step raises a cell's tuft count, the new tufts are born over the next step and rise over `TUFT_RISE` (0.8 s). Tufts that were already standing keep no birth.
- **Dense grass** (Ultra and Beauty). The blades are placed on the GPU from the terrain's green mask, so each cell also records `born` (the moment the front reached it, plus one step) and `prior` (the grass it had before). `dense_grass.gd` uploads them as a 56×56 `emergence_map`: r is born, g is prior over the current grass, a marks a birth. In the shader, tufts ranked below g stood before and stay grown. The rest start one by one, in keep order, across `COVER_CREEP` (3 s) after the cell's birth, and each rises over `COVER_RISE` (1.4 s). A tuft switches on as the mask greens, but it still rises from the ground instead of appearing at full height.
- **Not saved, not undone.** `to_document` strips `born`, `load_document` never reads it, and `cover_births` is not in the save or the undo state. A dropped birth reads as fully grown. Births that have finished growing are pruned each step.
- **Kept across rebuilds.** Births live in the records and in `cover_births`, so the full rebuild writes them again. The in-place lift (`_move_instances`, `lift_instances`) and the object preview only touch transforms and colours, which leaves custom data as it was.

## Pacing and cost

- `advance(delta)` runs in steps of 0.75 s. It returns true at most once per step, and the editor then calls `refresh(get_tree())` once. This is the yielding path a stroke's settle takes: instances are sampled on a worker and the rest is spread by the frame budget.
- **Measured** with `tools/profile_stroke.gd -- --mode=land --watch=40`, headless, on the cozy world. The profiler's land mode now prepares the brush and grows the stroke rect, as the pointer does; before that fix it never raised land, so it never started emergence. With the old synchronous `refresh()`, every step cost 15–27 ms on one frame. With the yielding refresh, the settle frames were median 8.3 ms, p95 9.1 ms, and 5 of 4800 over 16.7 ms: four at 16–19 ms in the content stage, and the one-time first plan (below) at 48 ms. The birth stamping adds 0.2–3.8 ms to a step's `advance`.
- **Planning.** A stroke's plan starts on the first step after release, never on release itself, and waits while the stroke's weathering is still on its worker. In the editor it runs on a worker over a detached copy of the ground (`_plan_async`, `plan_on_worker`): a planner Emergence builds or refreshes a copy of the live blend, pond flooding included, and plans every queued region. The main thread pays 0.4–1 ms to take the copy and about 0.1 ms to install the regions a few frames later. The worker takes 20–53 ms for a first plan. Probes that call `advance` in a tight loop plan synchronously, as before: about 10 ms on a warm blend and 25–54 ms for a first plan.
- **Step cost.** The steps themselves cost under 1 ms, not counting the refresh.
- **Pausing.** Emergence pauses while a stroke or selection edit is open, so emerged changes never fold into the player's undo step. Undo, load and new worlds clear pending work (`state_restored`).
- **Not saved.** Pending succession is not saved. Anything already grown is saved.

## Probe

`godot --headless --path . -s res://tools/probe_emergence.gd -- <seed>` raises a hill on a blank plain and on a generated world, prints cover and arrivals at 2–45 s, and checks four things: hand work stays intact, the salt determines the result, the save round trip works, and older saves still load.

## Open

- Hook `_stroke_ended` to `stroke_finished` from `feature/stroke-feel` once that branch lands.
- Dense grass only checks `prior` against the current grass, not the real keep mask. So when emergence thickens cover that was already partial, a few tufts that were standing may regrow.
- Should world time or season scale the pace?
- Water-first creep (grass from new ponds even without sculpting) needs pond fills to report their rect, which they do today only through the editor's pond click.
