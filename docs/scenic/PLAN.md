# Scenic diorama plan

Started 2026-09-26. This replaces the Bigfoot and cryptid game direction.

## The product

- **A beautiful, interactable, inspectable diorama.** Physics, wind, fog, weather, lighting and shadows.
- **Regenerate for a new piece.** There should be a great deal of variety, and every result should look good.
- **Craft your own world, in the spirit of Tiny Glade.** Simple and hand-held, with the tools steering towards good results, but still with a skill to it.
- **Keep the current stylised look and make it better.** This is not a restyle.
- **Target good PCs.** The reference machine is an RTX 4070 Super, aiming for high frame rates. The Mac is secondary.
- **Keep some ambient life:** birds, fireflies, fish and weather. Bigfoot and the gameplay are hidden, not deleted.

### Engine decision

Stay on Godot 4.7 Forward+.

- Godot has no built-in hardware ray tracing and no built-in DLSS.
- The look is stylised. PC headroom goes to density, fog resolution and frame rate.
- Avoid temporal upscalers and TAA for now. They fight the display fog's own temporal resolve and smear swaying foliage.
- The display-fog compositor needs Forward+.

## Phase 0: scenery mode and motion feel

The code items are done and merged to `main`. The settings items are waiting on the 4070 Super.

**Done:**
- Scenery mode is on by default in the product scene (`studies/diorama.gd`).
  - Bigfoot is still built but never enabled; `--bigfoot` restores him.
  - The World menu, build palette and tool rail no longer offer anything Bigfoot-related.
  - Saves record no resident.
- Regrow folds and replays the land with no carry, and skips rebuilding Bigfoot's navigation (`scripts/cozy_regrowth.gd`).
- Fish and falling wood keep living without the resident (`studies/fidelity_life.gd`).
- Camera damping is time-based, so the glide is the same at any refresh rate (`studies/fidelity.gd`). F7 in `tools/compare_live.gd` restores the per-frame response.
- `world_visuals` no longer re-serialises the recipe settings every frame.
- The headless Python test runners and `AGENTS.md` are in place.

**Still to do. Each needs eyes on screen and numbers from the 4070 Super:**
- Vsync. It is currently off with a 120 fps cap (`project.godot`).
- The volumetric fog grid is 256×256, which is 64× Godot's default. Try 128 or lower, and compare captures.
- Pond planar reflections redraw the scene every frame, which doubles frame time in the pacing benchmark (`scripts/planar_water.gd`). Try half-rate updates or fewer copies.
- Physics interpolation. Turning it on project-wide also interpolates the camera and anything moved in `_process`, so those nodes have to opt out.
- The tread wake has no source now that Bigfoot is gone. Drive it from the camera or cursor, or from wind.
- Remaining per-frame work: the study sliders are set every frame, and the redwood mist toggles volumetric fog on and off.

## Phase 1: better look, same look

Done and merged to `main` on 2026-09-26. The user has seen it on the Mac and is happy with it. The strengths and the grass settings still need tuning on the 4070 Super.

**Done, in `scripts/look_pass.gd`. F6 toggles the whole pass; `--no-look-pass` starts with it off:**
- **Contact ambient occlusion in the material.**
  - Ambient light is written as `EMISSION`, which Godot's SSAO never touches. That is why the old Beauty SSAO changed nothing.
  - Objects darken toward their own base (`shaders/reference_surface.gdshader`).
- **Silhouette rim light:** a sky sheen, stronger when backlit. Flat ground is excluded.
- **Per-hour grade and a light vignette** in `shaders/reference_air_blend.gdshader`. Highlights lean toward the hour's sun colour and shadows toward its sky colour.
- **God rays:** a 24-tap screen-space gather of open sky toward the sun. They fade as the sun sinks or cloud covers it.
- **Glow:** the threshold drops from 1.8 to 1.0, intensity rises to 0.3, and it uses glow levels 3–5.
- **Quality presets:**
  - Balanced: occlusion, rim, grade and vignette.
  - Beauty: adds glow and god rays.
  - Ultra: adds 4× MSAA, fog at 0.75 scale, SSAO and 768 px pond reflections.
- **Round two:**
  - Beauty is the default quality. Saves from before the look pass stored Balanced as a default rather than a choice, so they reopen on Beauty. New saves record that the quality was chosen.
  - Biomes that use native volumetric fog, such as the redwood and woodland mist, get the grade and vignette from a standalone pass (`shaders/look_grade.gdshader`). Their god rays come from the native fog itself.
  - Three hazed ridge layers ring the horizon in `shaders/reference_sky.gdshader`. The terrain seed shapes the skyline and the relief sets its height. The sun and moon set behind them.
  - Sky radiance updates incrementally instead of every frame (`--realtime-sky` restores it). Only the wet sheen reads it.
  - A broken, lapping foam line where still water meets the bank, and darker damp ground just above ponds and streams. The ground reads water height through the `zs_water_map` global.
  - Dense GPU grass on Ultra (`scripts/dense_grass.gd`, `shaders/dense_grass.gdshader`).
    - One MultiMesh of three-blade clumps is shared by an 8×8 grid of tiles, 1,024 clumps per tile, about 11 cm apart, so up to 196,000 blades.
    - The shader places every clump. Height comes from the ground map, and colour and density come from a 128² mask baked from the terrain mesh on a worker. The bake takes 8–14 ms.
    - Blades grow only where the ground passes the palette's green test, so there is none on deserts, rock, snow, sand or under water. It also thins on steep slopes.
    - Blades sway with the scene's wind and gusts, part for the tread field, droop when wet, shrink under snow, turn with autumn and grow in with the foliage.
    - Past 22 m, clumps thin and widen to keep the cover. The blades cast no shadows.
- **Seed controls:**
  - The badge shows the seed.
  - `]` and `[` step through the showcase seeds.
  - `--seed N` regrows to a seed at launch.
  - A seed now always reproduces the same world, whichever landscape you start from.

**Left for later. None of it blocks Phase 2:**
1. Tune the strengths against the showcase seeds. The defaults are occlusion 0.8, rim 0.35, grade 0.55, saturation 1.06, vignette 0.16, rays 0.22, ridges 0.85 and shore 1.0, all in `scripts/look_pass.gd`.
2. Tune the grass on the 4070 Super: density, blade height 0.26 m, and whether shadows are worth casting. Do it together with the Phase 0 settings items.
3. Desert families might suit flat-topped mesa ridges better than peaks. This fits Phase 2's per-biome work.

**Dropped:** contact-hardening soft shadows. They cost the most and pay off the least.

## Phase 2: variety where every result looks good

In progress. Items 2, 3, 4, 6 and 7 are done. Item 1 and the Blender trees from item 3 are in PR #19. None of it has been seen on screen together yet.

1. **Replace the generator's "usable, connected ground" gate with a beauty score.** Done in PR #19 (`feature/beauty-score`). Not yet seen on screen.
   - `scripts/world_beauty.gd` scores a candidate from the overview camera: drama (rise over the plate's far edge, land hidden behind nearer ridges, skyline movement, peaks), relief, a focal summit or water, water share, and composition (summit near a third, balanced weight, walls not hiding the land).
   - The generator keeps the family it draws, builds six candidates and keeps the best. It also draws four palettes and keeps the most harmonious. A world takes about 124 ms on the worker.
   - Genome version 6 keeps the three clearings for dressing but no longer flattens them. Saved version 5 worlds keep their terraces. The meadow fallback is gone.
   - Over 150 seeds the mean score rises from 0.64 to 0.71 and every family's worst world improves. Palettes scoring under 0.6 drop from 79 to 12.
   - Known gaps: the score is blind to what makes a chasm or a marsh good, so those families only compare among themselves. Scores are not comparable across families. `inland_places.quality` is now only used by the deferred tests, and `test_inland_places.gd` will fail its usable-ground floor.
   - Tune the weights (`WEIGHTS` in `world_beauty.gd`) against captures. `tools/probe_world_beauty.gd` sweeps scores and timings headless; `tools/capture_seed_stills.gd` renders stills or orbit frames per seed.
2. **Erosion plus ridged, domain-warped noise** in the native C++ terrain kernels (`native/terrain_kernels`). Done on `feature/terrain-erosion`. Not yet seen on screen.
   - Genome version 7 adds a height delta from `scripts/terrain_erosion.gd` to the inland field before water is carved. It uses a 41×41 grid of 0.7 m cells, about the mesh spacing.
   - Ridged, domain-warped noise (three octaves) is laid on slopes only, so flats, mesa tops and the plate rim keep their shape.
   - Then 20 passes of stream-power erosion down a drainage tree. Only cells draining more than four cells cut, and jittered flow directions let gullies branch instead of following the grid. Sediment settles where the flow slackens, without burying the cells upstream or mounding pits.
   - The kernel's `erode` takes under 1 ms per world. `erode_reference` in GDScript mirrors it exactly, so a seed grows the same world without the library, in about 70 ms. Both use only `+ - * / sqrt floor`, so no platform's maths library can change a seed. `tools/probe_terrain_erosion.gd -- 400 --reference 400` must report 0 mismatches.
   - Per-family strengths are in `FAMILIES`. Dunes, marsh and salt basins are not eroded, since wind shapes dunes and the pools sit on exact levels. Chasms, meadows, buttes and tablelands get only a light touch. Mountains and massifs get cuts of about 1 m, and valleys and desert mountains about 0.8 m.
   - Saved worlds from versions 3 to 6 build exactly their old terrain.
   - The generator scores its six candidates uneroded and only the kept world is eroded, so a world still takes the same time to draw (128 ms in both runs on the day). Over 368 eroded worlds, the uneroded pick is also the best eroded candidate 322 times. The mean loss is 0.0015 and the worst is 0.058.
   - Building the terrain costs more: recipe sampling on one thread rises from 180 to 203 ms per world. It is split across four workers.
   - Beauty scores barely move: the mean over 400 seeds goes from 0.700 to 0.701. Family minimums shift by 0.04 at most. Valley drops from 0.90 to 0.86, and tablelands rises from 0.58 to 0.61.
   - Every showcase seed keeps its family. Seed 147 (volcanic crown) drops from 0.85 to 0.82 and 193 (sawtooth) from 0.86 to 0.84. The rest change by 0.01 or less.
   - `--hillshade DIR` on the probe writes uneroded, eroded and change maps per seed. Headless runs cannot check the shaded look. Launch `./run-cozy-flow.command` and judge whether the gullies read at the overview distance or need more strength.
3. **Seeded tree and rock variants.** Done on `feature/seeded-variants`, apart from the Blender trees in PR #19. Not yet seen on screen.
   - **Blender trees, committed as `a2eec16` and in PR #19.** Scripts in `tools/blender_trees/` (plus `tools/build_hero_oak.py`) build faceted trees in Blender and export them to `assets/models/`. Run one with `blender -b --factory-startup --python <script>`.
   - `scripts/hero_trees.gd` swaps the geometry behind the existing catalog parts and keeps each part's material, wind and tint. The oak replaces the broadleaf and the redwood replaces the redwood.
   - Pines grow as a six-variant spruce family. `garden_instance_samples.gd` picks the variant per tree with a stable weighted hash.
   - Arid worlds plant Joshua trees (a new `joshua` asset) for about half of their cactus slots.
   - `--classic-trees` restores the source meshes for comparison. Not yet checked on screen.
   - **Rocks.** `scripts/rock_variants.gd` builds eight faceted stones in Godot from fixed seeds: rounded, lumpy, blocky, tabular, slab, flag, shard and column. Each is an 80-face icosphere with lumps, sliced by random planes into big facets, tapered and given a flat base. Weathering is baked as greyscale light and shade: bleached tops, a damp stain near the ground, and a value per facet. The family builds in about 1 ms at startup.
   - `rock` and `boulder_1..4` both draw from the family, one MultiMesh batch per shape on the boulders' material. `rock` instances carry their old grey over that base, and user tints are converted, so colours and the palette role are unchanged. Records are unchanged too: the shape is picked at render time, like the spruce family.
   - Per world, `scripts/seeded_variety.gd` picks a rock character from the recipe seed: granite, slate, basalt or sandstone (deserts draw sandstone, basalt or granite). The character weights the shapes, with a fifth of the weight spread evenly. Per stone, a stable integer hash of the world and the record id picks the shape, proportions (±18% across, ±22% in height), a tilt of up to 8° and a value shift of −10% to +8%. Each kind keeps its old footprint (rock 1.2 m, boulders 1.45–1.9 m), so collisions and Bigfoot's cover still fit.
   - `--classic-rocks` restores the sphere and icosahedra for comparison.
   - **Layered trees.** `layered_tree.gd` has a `tree_seed`. Seed 0 is the original tree, unchanged. Other seeds grow a sibling: taller or broader, leaning, with the leaf masses moved and resized, and sometimes one low side mass dropped. Forms 0, 5 and 12 are in `VARIANT_SEEDS`. Each world favours one form (weight 3 against 1), and each tree gets ±8% width and −10% to +12% height, shared by trunk and crown. The trunk and crown keys keep their material, wind, tread and tint rules. `--classic-trees` also turns this off.
   - **Props.** Generated worlds now carry `"variety": 1` in the terrain recipe. With it, `inland_landscape.gd` drops its fixed cycles:
     - Meadow flowers follow a low-frequency drift, so each species gathers into patches. Each world leans its own mix of daisy, button, spike and a few umbel flowers, and its own share of grass tufts.
     - Woodland and redwood logs, stumps, snags, ferns and mushrooms keep their old average rates, but each world leans each rate by ×0.5 to ×1.6, and a position hash picks, not `i%29`-style counters.
     - Alpine cover gets some rocks (5–16%). Arid cover gets rocks and tufts among the shrubs.
     - Clearing palettes are weighted picks, leaned per world, instead of cycling. A focal boulder gets one to three small stones beside it.
     - None of it draws from the planting stream, so trees and prop positions stay where they were. Only the kinds change, plus the added stones.
   - Saves: recipes without `variety` dress byte-for-byte as before (object, grass and meadow digests match `main` for eight showcase seeds). Rock and layered-tree shapes change for every world, old saves included, because they are chosen at render time. The recipe codec and `valid` accept `variety` (only the value 1).
   - Cost: dressing time is unchanged within noise. A world draws up to eight stone batches (it was up to five: rock plus four boulders) and up to six layered-tree batches (it was two). A meadow with umbels adds two small flower batches. The two extra layered forms cost about 7 ms once at startup.
   - Probe: `tools/probe_seeded_variants.gd -- [old] [view] [meshes] seeds` prints each world's rock character, stones per shape, layered forms, kinds, a save round trip, and with `view` the real batches. `old` prints the digest without `variety`, to compare with `tools/probe_biome_dressing.gd` on `main`.
   - To check on screen: rocks on 105 (slate, 43 stones), 134 and 364 (sandstone), 45 (basalt), 184 (granite); layered forms on 33, 177 and 102; meadow drifts on 177, 58 and 198. Headless runs do not compile shaders, so the facets and weathering are unverified. Judge whether the shard and flag shapes read as stones or need taming.
4. **Blend two or three biomes per world** from moisture, altitude and slope direction, instead of one habitat string. Done on `feature/biome-blend`. Not yet seen on screen.
   - `scripts/biome_blend.gd`. The recipe's `biome` stays the dominant habitat. Generated worlds add an optional `blend` of one or two more habitats, and each one claims ground by a single rule: moist (near water and low ground), high, low, or facing a direction. Edges are soft smoothsteps broken up by noise.
   - The generator draws the blend from the terrain seed on its own random stream, so every other draw, and the showcase seeds' terrain and mood, are unchanged. Thresholds are quantiles of the world's own land, so each habitat gets its intended share.
   - Mixes by dominant habitat: alpine gets woodland on low ground and sometimes a wet meadow; woodland gets a meadow floor plus alpine tops above about 8 m, or a wet corner; redwood gets woodland on one aspect and a meadow; meadow gets woodland on one aspect or high ground, and wetland by water; marsh gets meadow and woodland on its rises. Deserts keep one habitat.
   - Over 200 seeds every non-desert world gets two or three habitats. The plan costs about 7 ms, so a world takes about 130 ms on the worker. Dressing a world costs up to 35 ms more, on the main thread with the existing frame budget. There is no per-frame work.
   - Placement: trees, low cover and clearing props follow the habitat at each point. Each habitat plants its own density on its share of the land. Thinning uses a position hash, so the planting stream is not disturbed.
   - Ground: the grass cover grid follows the habitats, so the mesh colour and the dense grass mask grade between them. Alpine ground thins toward the summit. An alpine layer brings the alpine snowline, so woodland valleys get snow and rock tops. Woodland stays below 5.5 m under alpine ground.
   - The badge names the mix, for example "Woodland, meadow and alpine · Valley".
   - Saves: recipes without `blend` dress byte-for-byte as before (object, grass and meadow digests match `main` for five seeds). A blend is stored as integers, so it survives JSON exactly.
   - Fixed on the way: JSON reads the recipe's `version` as a float, and `NativeTerrainRecipe.decode` rejected it, so saved inland worlds failed to reload. Decode now restores integer fields before validating.
   - **Geology colours come from the palette.** `scripts/geology_palette.gd` holds the old shader colours as defaults. Generated deserts lean each one toward the palette's rock or earth hue (strata 40%, sand 35%, salt 15%) with small saturation and value jitter, and save them in `world_visuals.geology`. Worlds without their own geology get the old colours exactly. The uniforms are set only when the world changes.
   - Probes: `tools/probe_biome_blend.gd -- showcase` (mix, shares and save round trip per seed) and `tools/probe_biome_dressing.gd -- [single] seeds` (what each habitat plants, reload check).
   - To check on screen: the treeline and meadow edges on 79 and 105; the alpine valley tops of 79 and 301; redwood on one side and woodland on the other of 328; the wet corner of 58; desert strata on 134, 309 and 364 against the old colours. The desert ground has no blend because the desert shader paints over the vertex colours.
5. **Curated palette families.** Start from the landscape experiment's chalk, copper, moss and lavender (on branch `wip/parked-2026-09-26`).
6. **Weather and seasons that change while you watch.** Done on `feature/living-weather`. Not yet seen on screen, and the shader changes are not compiled until the user launches.
   - **Live weather** is on in the product scene (`scripts/living_weather.gd`, set up in `studies/diorama.gd`). `--still-weather` keeps each world on its own weather.
     - The drift starts from the world's generated weather and runs `WeatherScheduler` in a new climate mode. Its draw weights are solved so the time spent in each sky matches `WET_WEATHER` and `DRY_WEATHER`. Over 20,000 simulated hours a wet world spends clear 30%, fair 34%, mist 14%, rain 9%, overcast 7% and snow 6%, so overcast, rain and snow are 22%. Dry worlds get clear 45%, fair 45% and overcast 10%, and never rain or snow.
     - Wet worlds trade snow for rain in summer and rain for snow in winter, so the grey and wet share stays at 22%.
     - The scheduler keeps its own clock, 20 s per hour, because generated worlds hold their hour of day. Bright skies hold three to five minutes, overcast and rain about two to three, and mist about two. A change comes every three minutes on average. `tools/probe_living_weather.gd` prints a timeline, the shares and the dwell times.
     - Each change eases in over about 35 s instead of 5: cloud, rain, wind, fog and haze at 0.08/s, and gold, cold, ice and snow cover at 0.3× their old rates. Rain and storm wait for the cloud to build and stop as it thins.
     - The drift keeps the world's own air. The mood's cloud override becomes the start of the ease, so neither the light nor the god rays step. Wind, cloud, mist and haze move from the world's own values by the difference between weathers (half the preset difference for wind and haze, the generator's mean mist for mist). The saved fog bank and peak clouds scale by the generator's ratio between weathers, for example 4.2× into mist, 1.9× into rain or snow.
     - What follows without extra work: god rays fade with the cloud, the wet sheen soaks and dries on its own curve, rainbows can appear as rain clears, dense grass droops while rain falls and shrinks under snow, and snow cover builds while it snows. A long cold spell now frosts the ground only to 0.5 cover, and snowfall above that settles back slowly.
     - **W** starts easing to the next sky now, **Shift+W** holds or releases the drift, and the badge shows the season and sky.
   - **Seasons drive plants** through a new `zs_season` global (bloom, leaf fall, dormancy), set only when it changes (`shaders/reference_season.gdshaderinc`).
     - Spring: deciduous leaves turn fresher and lighter, 45% of broadleaves and 30% of shrubs blossom in pink or white, dense grass is fresher with scattered white, yellow and violet wildflowers, and flowers stand 10% taller.
     - Autumn is the existing gold, as before.
     - Winter: deciduous crowns drop their leaves in clumps until only the branches stand (shrubs keep about half), each tree a little before or after its neighbours. Grass and green ground go to straw, dense grass shortens by 30%, and flowers and ferns die back. Deep winter also brings the existing cold lift, frost and snowfall.
     - A per-part `leaf_season` material uniform decides who follows (`leaf_season` in `scripts/scene_look.gd`). Spruce, redwood, Joshua trees, cactus and the source pine stay green and no longer take the autumn gold. New tree variants follow as long as they reuse the part keys.
   - **Decision: the season is fixed per world, with E to move it.** The generator draws the palette, weather and gold for one season, so a turning year would put blossom on an autumn palette and leave a snowy world's colours wrong within minutes. A real year at this pace, about 3.7 hours, is too slow to watch anyway. The weather supplies the change you watch. The season is part of the piece's identity, and E lets you see the same world in another season.
     - Snow worlds open in deep winter and autumn worlds at the exact point of the year that gives their drawn gold. Deserts open in summer. Other worlds open in spring 45% of the time and summer otherwise, from their own random stream, so no generator draw moves. Over seeds 0–119: summer 65, spring 31, autumn 17, winter 7.
     - **E** glides forward to the middle of the next season at a quarter per 30 s, so you watch the leaves turn and fall or the blossom open. `--seasons-turn` lets a pinned season creep forward on its own, a quarter per 10 minutes.
     - The pin lives in `world_clock.season_override`. Worlds whose clock still runs, such as a new blank diorama, follow the calendar as before.
   - **Saves:** the scheduler's capture is now version 2. It records whether drift was chosen, plus the world's origin weather and air. Older saves stored drift as off by default, so they open drifting. Saves without an origin take it from the sky they show. Saves with a held clock and no pinned season take one from the ground: cold is winter, gold is autumn, anything else is summer. `tools/probe_living_scene.gd` runs the product scene headless through a drift, the four E presses, a save round trip and a pre-living save.
   - **Cost:** no per-instance CPU work. Per frame, living weather does a few dictionary reads and lerps. `zs_season` is set only when the season moves. On the GPU, deciduous crowns add one discard test with a two-sample noise, blossom adds another on blossoming trees in spring, and dense grass adds a colour branch.
   - **To check on screen:** whether blossom flecks read at the overview distance, whether bare crowns look like branches or holes (the classic `--classic-trees` broadleaf has almost no branches), the straw tint strength, and whether mist's fog bank at 4× is too thick on tall worlds. Evergreens on autumn palettes still take the palette's orange foliage multiplier. That belongs to the palette work in item 5.
7. **Rebalance the weather odds.** Done on 2026-09-26. Regrows used to pick weather uniformly, which made overcast 24% of 400 seeds and grey or wet skies 49%. `WET_WEATHER` and `DRY_WEATHER` in `scripts/cozy_world_generator.gd` now weight it: clear 30, fair 34, mist 14, rain 9, overcast 7, snow 6 (dry: clear 45, fair 45, overcast 10). Over seeds 0–399, overcast is 10% and grey or wet is 22%. Terrain and scores are unchanged, but most seeds roll different weather, so the showcase seeds were re-checked.
8. **Later: horizons beyond one 28 m plate.** Stitched multi-chunk terrain exists on `feature/stitched-terrain`.

## Phase 3: creation, in the spirit of Genesis

Talked through with the user on 2026-09-26. Not started.

### The idea

- **The default experience is creation, not construction.** You feel like you are painting a world into being. You create the conditions and the world answers in its own time. You do not control the outcome.
- **Life is breathed in after the land.** Water finds the low ground, grass creeps out from it, then shrubs and trees. Fish, frogspawn, birds and wildlife arrive because of what you made. The sun, the moon and the weather carry on without you.
- **Low floor, high ceiling.** Dragging the mouse across the plain always reveals something legible, attractive and unique. A careful, artistic player gets higher highs by understanding the world: learning what frogs or herons need and composing for it.
- **Variety comes from the systems.** Two players painting the same strokes on different land get different worlds and different life.

### The feel is the product

Painting has to feel so smooth and satisfying that it is almost mind-blowing: a premium, polished, seamless experience. A stroke should set off a visible chain of cause and effect:

- The ground tremors as land rises.
- The fog and volumetric fog drift aside to reveal what you made.
- Water fills a basin; it does not appear in it.
- The wind picks up, and the trees you just grew start to sway.
- Sound effects for every stage. None exist yet.

Nothing may hitch while you paint. Frame pacing during a stroke matters more than anywhere else in the game (see Phase 0 and Phase 4).

### Two layers over one world

1. **Creation mode, the default and what the game launches into.** Broad brushes (land, water, meadow, forest, path) write intent; the world chooses the details.
   - Brushes that decorate for you: a path gets grassy, stony edges; a forest gets a natural edge; water settles in the low ground.
   - The reveal can reuse the regrow grow-in animation locally under the brush.
2. **Craft mode, later and opt-in.** Very fine-grained control for players who want it: spawn a mountain and sculpt it, paint the rock face, choose where grass blades grow, rotate individual trees. The current Sculpt, Paint and Place rail (`scripts/native_tool_rail.gd`) is roughly this layer already.

**Rules that keep the layers from fighting:**
- Both layers edit the same data: heights, material and grass masks, and instance transforms. Craft mode then only adds controls; it is not a second editor.
- Hand edits win. Emergence and later strokes leave pinned or hand-placed work alone.
- Life arrives from conditions plus a delay and is never placed directly. It answers careful craft-mode work the same way it answers broad strokes.

### Building blocks that already exist

- The biome blend's wet, high, low and facing rules (`scripts/biome_blend.gd`) are "the land brings forth plants".
- Native erosion (`erode` in `native/terrain_kernels`, under 1 ms per world) can become a brush that weathers what you raise.
- The regrow grow-in animation, the ambient birds, fireflies and fish, and the living weather and seasons from Phase 2 item 6.
- The beauty score can stay invisible and quietly guide variant choice, water settling and edges.

### Open questions

- Does creation start from a blank plain, a generated world, or both?
- How much does the world push back? For example, does water painted on a hilltop run downhill?
- Is there a finished moment? Photo mode could be where you compose and then capture.
- Rare "and it was good" moments when a place becomes rich: a heron lands, a deer at dawn, a rainbow after rain. A glimpse of Bigfoot at the forest edge could be the rarest.

### Also in this phase

- **Rebuild the UI around creation:**
  - Replace the top toolbar, which hides buttons by moving them into the World menu by position (`diorama.gd`).
  - Check the maker-editor look on screen. It is parked on `wip/parked-2026-09-26` and has never been seen.
- **Add an inspect and photo mode.**

## Phase 4: presentation

- A shader warm-up pass, plus the shader baker in export presets.
- Visibility ranges with fade on props, trees and MultiMesh batches. There are none today.
- HDR output, new in Godot 4.7.
- Movie Maker mode (`--write-movie`) for trailer footage.
- Threaded resource loading for places.

## Showcase seeds

These are `SHOWCASE` in `scripts/cozy_regrowth.gd`. They were picked on 2026-09-26 as the top scorers per family in seeds 0–399 of `tools/probe_world_beauty.gd`, then re-checked after the weather rebalance the same day. Five seeds that had turned overcast were swapped for the next-best seed in their family: 276→303, 240→328, 363→301 (kept as the snow showcase), 126→309 and 28→278.

| Family | Seeds |
|---|---|
| Mountain | 184 (fair), 105 (tall massif, clear), 147 (volcanic crown, mist) |
| Massif | 193 (sawtooth, fair), 303 (tall massif, fair) |
| Valley | 79 (glacial, mist), 328 (buttressed canyon, clear), 301 (glacial, snow) |
| Basin | 176 (fair) |
| Plateau | 33 (fair), 102 (clear) |
| Chasm | 353 (fair) |
| Foothills | 58 (rolling uplands, fair) |
| Meadow | 177 (rain) |
| Marsh | 198 (fair) |
| Desert | 134 (fair) |
| Desert mountains | 45 (clear) |
| Buttes | 309 (clear) |
| Tablelands | 248 (fair) |
| Dunes | 250 (fair) |
| Salt basin | 278 (fair) |
| Monuments | 364 (fair) |

## Working agreements

- Run tests only when the user brings them back. Until then, check scripts with `--check-only` and have the user look at the result.
- `tests/test_scenery_mode.gd` is drafted and has never been run. Existing Bigfoot tests are expected to fail against the product scene.
- Use `--rendered` Godot runs only when the user asks. Headless Godot does not compile shaders, so shader changes are unverified until the user launches.
- Launch with `./run-cozy-flow.command`. `godot` is not on PATH; the binary is `~/Applications/Godot.app/Contents/MacOS/Godot`.
- The uncommitted work from before the pivot is parked on `wip/parked-2026-09-26`. It holds the beach ball, perching bird, maker editor and the landscape experiment.
