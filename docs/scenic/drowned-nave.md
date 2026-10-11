# The Drowned Nave (motif isle, handoff)

Branch `look/motif-drowned-nave` from main. Not merged, not pushed.

## What it is

A larger ruin motif isle (about 62 m radius, 348k static triangles, water 17k). A shallow basin of still water (the shared KitWater pond, 0.5 m cells, tea 0.5) fills the middle. A long gothic nave stands half drowned in it: two rows of 11 piers and pointed arches (`Cloister.range_run`, 5.4 m bays, wall-walks on top), the south row fallen in a run (snapped stubs) and the north row in another. A raised flagged floor (0.4 m under the water: wading) runs down the nave with moat either side (2.4 m: swimming). At the far (east) end is a rocky apse in three tiers with a kit grand stair up its axis to a plateau, the rose gable on it, buttresses behind it, a tomb chest, and the lodestone's block. Vault springers stand at the chancel corners with their ribs broken off over the nave. A lancet window and snapped piers, walls and arches stand on the grass shore; the west is a long beach. The basin spills down a channel on the north side over the lip as a curtain fall.

Files: `studies/drowned_nave_isle_art.gd` (terrain, nave, apse, water, fall), `scripts/kit_isle/motif_drowned_nave.gd` (the motif, plane tokens), `studies/drowned_nave_isle{,_life}.gd` + `.tscn`, `run-drowned-nave.command`, scene catalog entry `drowned_nave`, `tests/test_drowned_nave_isle.gd`.

Card: "The Drowned Nave", "Where the roof went, the sky came in".

## Play

- Standalone: `./run-drowned-nave.command` (starts on the beach looking east).
- In the sky: `godot --path . res://studies/aqueduct_isle.tscn -- --no-title --fly`; it is the south-west isle, middle near world (-230, 350), 473 m from home.
- Plane tokens (source `nave`): skim along the nave's axis, thread the south row's gap, thread a standing north bay, pull up past the chancel's springers, dive down the fall, keel. 5 foot tokens: causeway, lookout, arcade walk, snapped pier, spill bank.
- On foot: a causeway of 20 stones down the nave (wade + hop), the grand stair up the apse.
- The water uses the existing WATER_LAYER (1 << 12) the cloister tarn uses, so `studies/aqueduct_isle.gd` needed no change.

## Placement (`motif_sky.gd`)

Appended `PLACES` offset (-310, 0, 350), `REACH` 64, `MIDDLES` (80, 0). The requested (-330, 380) failed `test_aqueduct_isle_sky` (578 m from home, limit 500), so it was nudged to about (-230, 350): 290 m to the cloister tarn, 279 m to the Sundered gorge (edge gaps 172 and 159 m), 357 m clear of the (-100, 750) tower's keep. Other agents' motifs may need to avoid this spot.

## Tests (headless)

- Import clean.
- `test_drowned_nave_isle.gd` PASS: budget, dry start, no hole in ground, water skimmed (basin and spill), the nave axis / gap / bay / pull-up lines clear of stone by the wing-wide bump body (and a pier is hit as a control), causeway 20/20 hopped, grand stair walked to the plateau, moat swum, stones true, tokens.
- `test_motif_sky.gd`, `test_aqueduct_isle_sky.gd`, `test_kit_clouds.gd`, `test_isle_lock.gd`, `test_kit_water.gd`, `test_scene_picker_entries.gd` PASS.
- Edited tests (appended): motif id lists and the "nave" source in `test_aqueduct_isle_sky.gd`; `places().size() == 5` in `test_kit_clouds.gd`; `test_motif_sky.gd` checks the nave's water too.

## Looks

Two rendered captures judged (overview, and from the nave looking east): the water reads glassy teal with the pond's low-poly chop, stone dark. Not verified: the plane skim by hand, the fall's look, night/other presets, frame time (about 40 ms in the windowed standalone capture on this Mac with the whole scene).

## Open issues

- The basin is ~40% of the top, not "most"; the grass shore is wide.
- Foot tokens other than the causeway are not walked by the test; the arcade walk (buttress) and stub routes are unproven.
- The "broken vault" is only the chancel springers; no roof over the nave.
- Triangle count (348k) is above the other motifs' ~250k.
