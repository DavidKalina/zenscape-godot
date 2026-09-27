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

In progress. Items 2 to 7 are done. Item 1 and the Blender trees from item 3 are in PR #19. None of it has been seen on screen together yet.

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
5. **Curated palette families.** Done on `feature/palette-families`. Not yet seen on screen.
   - `scripts/palette_families.gd` holds twelve art-directed families. Each one sets the land (grass, foliage, rock, earth, water) and a daytime sky (sky, horizon, glow, sun). Ambient, bounce, rim and fog are derived as before.
     - From the landscape experiment: chalk & turquoise, copper & sage, slate & moss (lifted so its woods do not go to silhouette) and lavender & gold.
     - New for wet land: spring meadow, pine & granite, fern & cedar, frost & slate, and ember & plum for dusk.
     - Deserts: sandstone & sky, bone & sage (pale limestone) and rust & violet. Chalk, copper and lavender also dress deserts.
   - A world picks its family by weight: land (wet or desert), then the dominant habitat or the desert kind, the hour and the weather. For example, redwood leans to fern and moss, alpine to granite and chalk, salt basins and dunes to bone, buttes and monuments to sandstone, dusk to ember, lavender and rust, and snow almost always to frost.
   - Inside the family it draws four variations and keeps the most harmonious. Each variation has one small hue, saturation and value shift shared by the whole land, plus a little per colour. So no two worlds match, and the scheme holds together.
   - The hour reshapes the family's sky within the ranges the renderer was tuned for. Dawn gets a bluer-violet sky and a rose glow, dusk a violet sky and a deeper amber glow, and night the old moonlit ranges tinted by the family. Autumn warms the foliage toward amber and the grass toward straw.
   - Habitats in a blend stay distinct within one palette. Every family keeps its foliage darker than its grass, its rock at least 0.1 luminance from the grass, and its water darker than the bank.
   - Desert families can carry their own geology bases (bone has pale strata, rust has deep red bands). `geology_palette.gd` leans those toward the palette's rock and earth as before. Deserts without bases keep the old shader colours as the base.
   - The family and its variation come from their own random stream, seeded from the world seed. The old HSV draw still runs on the main stream, so every later draw keeps its value. Over seeds 0–399, every world is identical to `main` apart from its colours and desert geology: terrain, blend, hour, weather, wind, mist, clouds and fog.
   - Harmony over 400 seeds rises from a mean of 0.73 to 0.95. The worst world goes from 0.42 to 0.65, and worlds under 0.7 drop from 149 to 1. Pine & granite is the weakest family (mean 0.85), because grey rock against green woods spreads the saturation.
   - Saves are unchanged. Colours are stored encoded in the look, so old worlds reload with their old colours. The generated world also records its `palette` family. `tools/probe_world_beauty.gd` prints it per seed.
   - `--classic-palette` restores the old independent HSV draw for comparison.
   - Showcase families: 184, 303 and 278 chalk; 105 and 176 granite; 147 and 301 frost; 193, 328 and 198 lavender; 79, 102, 58 and 177 spring; 33 moss; 353 ember; 134 and 45 bone; 309 and 248 rust; 250 copper; 364 sandstone.
   - To check on screen: whether each family reads as its name, especially granite on 105 and 176, and whether frost on 147 (mist, not snow) is too cold. Also check lavender dusk on 328 and 193 against the renderer's own dusk grading, and bone and rust strata on 134 and 309 against `--classic-palette`.
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

Talked through with the user on 2026-09-26. Mapped the same day; slice 1 landed on `main` the same evening (see "Slice 1"). The later slices are still open.

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

### Decisions (2026-09-26)

- **Start canvas: both.** The game launches onto a quiet, misty blank plain. Regenerate still gives a finished world that you can paint over.
- **Pushback: gentle physics.** Intent is honoured where it makes sense: water painted on a hill runs downhill and pools, and forests thin out on steep rock.
- **First slice: one brush with the full feel.** The land brush alone, with tremor, fog reveal, grass creeping in and no hitches, before the other brushes.

### Open questions

- Is there a finished moment? Photo mode could be where you compose and then capture.
- Rare "and it was good" moments when a place becomes rich: a heron lands, a deer at dawn, a rainbow after rain. A glimpse of Bigfoot at the forest edge could be the rarest.

### What the survey found (2026-09-26)

- **A stroke rebuilds the world.** `NativeChunkEditor._process` runs about 30 dabs a second, and each dab calls `refresh()` synchronously with no frame tree (`scripts/native_chunk_editor.gd:598-628`, `:711-834`).
  - `brush()` loops over every vertex and duplicates the heights on each dab.
  - The whole `ArrayMesh` and the surface-map textures are uploaded again.
  - Fog and atmosphere bounds are updated.
  - `_notify_play_geometry` serialises heights and objects.
  - Navigation restarts.
  - Measured 30-dab sculpt: 67-94 ms worst frame (`docs/performance/threading-acceptance.md`).
- **Mask paint rebuilds every instance.** `GardenView`'s signatures include grass, blades and meadow (`scripts/garden_view.gd:452-455`), so each meadow or forest dab rebuilds every MultiMesh and the stream, waterfall and pond meshes.
- **Feedback pieces exist but have no stroke signal to hang on:**
  - tremor: `scripts/reference_tremor.gd`
  - fog-thinning gust puffs: `atmosphere.send_gust`, `studies/wind_puffs.gd`
  - local wind: `scripts/local_wind_field.gd`
  - wind strength globals in `studies/atmosphere.gd`
- **Grow-in is global.** It is driven by two uniforms, `zs_growth` and `zs_water_growth`, with a hash stagger per plant. It needs a spatial form (brush centre/radius/time, or per-instance birth time) to reveal locally.
- **Emergence gaps:**
  - The biome blend reads the recipe sampler, not live `data.heights` or added ponds.
  - Scatter is one whole-plate ordered seed stream (`inland_landscape.gd:form`).
  - There is no pinned or hand-placed flag, only `"landscape": true` on generated flora.
  - There is no succession timeline.
  - Nothing finds a basin's spill level.
  - Fauna use fixed reference positions.
  - The beauty score is whole-plate and terrain-only.

### Slice 1: the land brush, with the full feel (done 2026-09-26)

Four parallel branches, merged in this order:

1. **`feature/stroke-pipeline`: no hitches mid-stroke.**
   - Keep a dirty-rect accumulator; loop the brush and the masks over the brush bounding box only.
   - Split the mid-stroke refresh (mesh region and instance lift only) from the settle work run once at stroke end (surface maps, shoreline, play geometry, navigation, fog bounds).
   - Keep heights-only edits off the full instance rebuild.
   - Target: no frame over about 16 ms during a 30-dab land stroke on the Mac.
2. **`feature/stroke-feel`: the stroke reads as cause and effect.**
   - Add `stroke_started`, `stroke_moved` and `stroke_finished` signals on the chunk editor.
   - Tremor scales with how fast land rises.
   - Fog parts around the brush, starting from gust puffs, with a dedicated reveal hole if puffs are not enough.
   - Wind swells during the stroke and eases after it.
   - Local grow-in: a brush-centred growth wave in the terrain, foliage and grass shaders.
3. **`feature/emergence-core`: grass creeps in from the land you made.**
   - A provenance or pin layer (hand, painted or emerged) on cells and objects.
   - Biome rules re-read from live heights and water per dirty rect.
   - A position-hash regional scatter.
   - A succession clock: grass first, then shrubs and trees after a delay.
   - Emerged content never overwrites hand or pinned work.
4. **`feature/genesis-canvas`: launch into creation.**
   - A blank misty plain as the default start; regenerate still available.
   - A land brush that raises soft, natural forms and weathers them with a local native `erode` pass at stroke end.
   - Creation mode as the default tool state, with the craft rail tucked away.

**Also in slice 1:** grass. The user said the old grass read as stubble. Two passes built painterly tufts and a lush carpet (`feature/grass-look`, `feature/grass-lush`). After seeing them rendered, the user rejected standing grass entirely: it did not fit the art style and "feels like a chia pet", especially on mountains.
- **The look reference is the original Fidelity scene:** faceted low-poly ground painted green, with bare rock on the mountains.
- The plain and emergence write painted cover only, never blades.
- Generated worlds keep the original source tuft at its original density.
- The blade work is kept but opt-in: `--painterly-grass` for the tuft, `--beauty-grass` for dense grass.
- Dense grass rendered metres wide and lying flat on its first real render. It is off by default until that is fixed.

#### What landed (merged as `feature/genesis-slice1`)

- **Launch:**
  - The game opens on a misty blank plain with the land brush in hand (`scripts/genesis_canvas.gd`, `scripts/land_brush.gd`).
  - Drag raises land; Shift-drag or right-drag lowers it; `[ ]` sets size and Shift+`[ ]` sets strength.
  - Release weathers the stroke with a local native `erode`, and one undo removes both.
  - **Craft** opens the old tools; **Create** returns to the brush.
  - Flags:
    - `--generated`, `--seed N` or `--resume` for the old launch.
    - `--plain-seed N` for a repeatable plain.
    - `--classic-build` for the old Build/Enjoy toggle.
- **Stroke feel:**
  - `stroke_started`, `stroke_moved` and `stroke_finished` signals on the chunk editor drive tremor, a fog reveal hole (`zs_reveal`), a wind swell and a local grow-in wave (`scripts/stroke_feedback.gd`).
  - Tunables are in `docs/scenic/stroke-feel.md`.
- **No hitches mid-stroke:**
  - While painting, a light refresh rebuilds only the dirty region and lifts content in place; a yielding settle refresh runs at release.
  - Pond flooding moved to a worker (`docs/performance/stroke-pipeline.md`).
  - Headless, a raise stroke across a pond went from 68 ms p95 / 112 ms max to about 9 ms.
- **Emergence** (`scripts/emergence.gd`, `docs/scenic/emergence.md`):
  - Painted cover creeps out from raised land.
  - Shrubs arrive at about 9-21 s and trees at about 18-38 s, following live biome rules: nothing on water, steep rock or snow.
  - Provenance (generated / emerged / hand) keeps hand work safe and survives saves.
  - Each emerged plant grows in at its own birth time through `INSTANCE_CUSTOM` and `zs_emergence_time`, instead of popping.
- **Bigfoot's cave, lair and earthwork are not built in scenery mode.** `--bigfoot` restores them.
- **Tools:**
  - `tools/film_genesis.gd` records a Movie Maker film of a stroke and the world answering. The user asked for this visual capture.
  - `tools/profile_stroke.gd -- --mode=land --watch=40` times strokes and emergence headless.

**Measured after the merge** (headless CPU, `profile_stroke --mode=land --watch=40`):
- Stroke frames p95 10.2 ms. The first dab is 28 ms.
- Release is 15 ms.
- One 36 ms frame when emergence first plans a world, otherwise p95 8.6 ms over 40 s.
- Strokes that change water still spend about 40 ms in one release frame, in `_planar_water.sync`, `_update_leaf_litter` and streams.

**Follow-ups from slice 1:**
- The plain's ground reads greyer and more mauve than Fidelity's green. It picks a random palette family (for example Chalk & turquoise) under mist. Offered: default the plain to Fidelity's palette and a clearer sky.
- There is no "just look" mode while creating: the brush stays in hand even with the UI hidden (H). Slice 5 adds Look (Tab), and H now puts the brush away.
- `--verify-desktop-build` may fail, because it expects the tool rail to be visible at launch. Slice 5 rewrote it for the creation shell.
- The dense-grass render, the first-dab and first-plan hitches, and the water release frame are in the remaining slices below.
- A plain launch copies `places.json` to `places-previous.json` before it is overwritten.

### Where Phase 3 stands (2026-09-26, evening)

Slices 1-5 are on `main`. Slice 1 is 7978080. Slices 2-5 were built in parallel and merged as `feature/phase3-slices-2-5`, described under "Slices 2-5 integrated" below.
- **What you can do:** launch onto a plain in Fidelity's colours and paint with five brushes: land, water, meadow, forest and path.
- **How the world answers:** water settles into basins and streams, plants and forest emerge, and fish, frogspawn, frogs, birds, a heron, deer and, rarest, the ambient Bigfoot arrive from conditions.
- **The interface:** a glass creation palette, with Look, Craft and World behind it.

The user watched the slices 2-5 film (`captures/phase3-slices-2-5.mp4`) and said it looks "just like God creating something". Slices 6-8 are still open, along with the outstanding items below.

### Outstanding from the slices 2-5 film

Seen in the stills of the first rendered film. Each needs a fix and another look on screen.
- ~~**Land brush peaks.**~~ Fixed on `feature/genesis-look-fixes`: a dab caps at a dome over its rim (`land_brush.gd` `DOME`), the core is gentler, and emerged grass holds to 0.9 of the rock slope. The film's hill now rounds off green. Mountains still come from wider or repeated strokes and go rocky above about 4.75 m.
- ~~**Mist over ponds.**~~ Fixed on `feature/genesis-look-fixes`: the living fog, the display-space ground pool and the Beauty mist thin over open water (`zs_open_water`). The milky patch is gone. The water still reads grey-green from its own surface (reflections and tint), which belongs to the water work.
- ~~**Meadow barely shows.**~~ Fixed on `feature/genesis-look-fixes`: a lusher, warmer green at a higher weight, and flowers as warm one-colour drifts (no blues or whites). The drifts show as warm faces in the stills. Seen through the plain's mist they are still soft.
- **Path is plain.** Improved on `feature/genesis-look-fixes`: wandering, frayed edges, a darker worn centre, dusty shoulders with tufts of green, and per-cell earth variation. From the overview it reads as a trail. Up close under the ground mist it is still faint; it needs a look on screen.
- ~~**Ferns look like spiders.**~~ Fixed on `feature/genesis-look-fixes`: emerged woodland takes a third as many ferns at 0.6 scale, and the fern mesh has nine fuller, fresher fronds.
- ~~**Tree scale.**~~ Fixed on `feature/genesis-look-fixes`: emergence scales each kind (`KIND_SIZE`). Layered broadleaves are now 2.1–3.2 m (they were up to 6 m), hero oaks 1.8–2.8 m and spruces 1.6–4.5 m, against a 1.2 m deer.
- ~~**Tree in the pond.**~~ Fixed on `feature/phase3-round2`: when a pour lands, emergence withdraws the emerged plants whose base its new ponds or streams cover (`emergence.gd` `drown`, from the water plan's flooded cells), inside the pour's undo step. Until a plan that saw the new water replaces the blend's pond raster, arrivals read the fresh ponds too, so nothing is placed in them in between. Hand, pinned and generated objects stay.
- ~~**Look shows play hints.**~~ Fixed on `feature/phase3-round2`: in the creation shell, hovering a tree or rock no longer shows "Drag a tree to bend · Drag a rock or log to throw" (`diorama_world_play.gd`). Look keeps the palette's own calm line (`creation_palette.gd` `LOOK_HINT`). A bend or throw already under way still says how to finish it.
- **Frame spikes at release.** *Update (`feature/settle-hitches`):* the land stroke's release weathering, emergence's plan (live blend and pond flood included) and the encounter ground now run on workers. On the plain a land stroke's release frame went from 19–26 ms to about 1 ms, and its worst settle frame from 30–42 ms to 14–16 ms. On seed 184 the first plan's 54 ms frame is gone. *Water polish (`feature/water-polish`):* a pour's own settle frames are now at most 13–14 ms; the 35–47 ms first plan that followed a pour is the one the settle-hitches work moved to a worker. One 18–21 ms frame remains when a stroke crosses a pond on a recipe world: the planar reflection re-setup's first slice (12–15 ms, `planar_water.gd`). Numbers are in `docs/performance/stroke-pipeline.md` and `docs/scenic/water-brush.md`.
- **Reflections.** *Done on `feature/water-polish`.* Planar reflections cost 0.58 ms of CPU per frame while ponds exist, down from 4.79 ms. Materials now sync by change. Clip shaders compile ahead in idle frames after the scene grows, so a pour's first setup compiles none. The GPU pipeline cost of those shaders is unmeasured.
- ~~**Things not saved.**~~ Done on `feature/world-continuity`: the forest wish is saved in the terrain document (`intent_forest`, `docs/scenic/brushes.md`), and life in the scene state (`land_life`, `docs/scenic/life.md`). A loaded world resumes its life; saves without it still start settled. Moments are not saved. `tools/probe_world_continuity.gd` checks the round trip, an old save, the plain's day and the arrival puffs headless.
- **Water gaps.** *Done on `feature/water-polish`; the look is unverified.* New streams carve shallow beds. Ground a pour reshapes (a hollow, beds, a rim lip) moves into place over 0.7 s before the water fills, inside the pour's undo step. Pouring into a pond that brims at the plate's rim raises a soft lip there, so the pond rises by up to 0.5 m a pour.
- ~~**Deer need dawn.**~~ Done on `feature/world-continuity`. In creation mode the plain's day turns at 1200 s per 24 hours, and the night (phase 0.8 to 0.2) passes in a few seconds, eased like N. A full turning day would spend minutes in a night that hides the land, which the plain was chosen to avoid. A held day never brings dawn. Dawn and dusk are kept whole, so life's DAWN and DUSK windows each last about three minutes. From full day, dawn comes within six to eight minutes. Generated worlds still hold their hour. Still to judge on screen: whether the sun's pace reads as calm, and how the eased night looks. The same turning day gives Bigfoot his dawn, dusk and night windows on the plain.
- ~~**Forest wind.**~~ Done on `feature/world-continuity`: each batch of emerged trees gets a light local puff as it is born, which reaches the trees as they finish rising (`docs/scenic/stroke-feel.md`). Still to judge on screen.
- **Bigfoot sighting (`feature/bigfoot-sighting`):** the silhouette is replaced by the ambient model (`scripts/life_bigfoot.gd`). He steps out of a mature wood to watch or listen, or crosses along its edge in the Patterson stride, and leaves if the camera rushes him or the player paints near. He comes about once per 20-40 minutes of a rich, quiet world: a 10-minute settle, then chance 0.006 × light × weather per 2 s check, and a 20-minute cooldown. The rules and their reasoning are in `docs/scenic/life.md`, "Bigfoot". `--force-bigfoot[=watch|listen|stride]` brings him for filming; the probe is `tools/probe_bigfoot_sighting.gd`. Peeks wait for trunks thick enough (hero trees).
- **Tree variety (to discuss with the user first).** Emerged broadleaves are mostly the pale lavender blossom tree, which does not suit the plain. The user wants variety that is random but cohesive: a believable place with the odd surprise, with blossom allowed as an accent. Ideas: dominant, companion and rare mixes per stand; species that follow moisture, altitude and facing; neighbourhoods that drift across the land; the hero tree family (`scripts/hero_trees.gd`). Do not build this before talking it through.
- **Climate answers water (idea).** Ground far from water, or high and sun-facing, slowly dries (green, then ochre, then sand). Grass thins, and Joshua trees and scrub emerge. A river through it greens an oasis. This is how the plain could grow deserts without a desert brush. Generated worlds already have desert compositions (showcase seeds 134, 45, 250, 309, 248, 278 and 364).
- **Forest Shift feel.** One Shift pass over a young forest only brings its wish to about 0, above `CLEAR_BELOW` (−0.25), so nothing clears until a second pass. This is a feel question for the user.
- **Remaining frame.** On seed 184, a stroke across a pond has one 18–21 ms frame, from the first slice of the reflection-view rebuild in `planar_water.gd`. Recipe-world stream geometry still builds on the main thread (4.2 ms).
- **Not yet exercised:** Nobody has looked at the glass blur's frame cost, or at the palette on screen outside the film. Shift strokes are now profiled (`profile_stroke --then=shift`): forest clearing and path grow-back settle under 10 ms.
- **Film tool:** its layout depends on emergence timing and varies run to run. It forces the heron and deer with `--force-moments` and speeds up the life clock.
- **Tests:** `test_bigfoot_home`, `test_editor_coherence` and `test_diorama_flow` reference the old toolbar and menu. Update them when tests come back. The README's cozy-flow section now describes the creation shell.

### Remaining slices

2. **Water brush, and the plain in Fidelity's colours.**
   - Paint water and it settles: find the basin's spill level, fill it with the existing fill animation, and trace overflow downhill (`NativeWaterCourse.trace`) as a stream. Water painted on a hilltop runs down and pools.
   - Move the water flood and shoreline off the main thread, or into C++. That also removes the roughly 40 ms release frame when a stroke changes water.
   - Default the blank plain to Fidelity's palette and a clearer sky; other families stay for generated worlds.
   - Done when a film shows water filling a painted hollow and a stream finding its way down, with no visible hitch.
   - **What landed** (`feature/water-brush`, 2026-09-26; the film and a look on screen are still owed). Details and tunables are in `docs/scenic/water-brush.md`.
     - **The brush.**
       - Press `2` for the water brush (`scripts/water_brush.gd`) and `1` for land.
       - Poured water runs downhill and fills its basin up to the spill level. Overflow runs on as a stream to the next basin, and basins that spill into each other merge into one lake.
       - Water poured on a hill runs down to its pool as a stream.
       - Water that would run off the edge, or spread too thin, scoops a soft hollow and pools there.
       - Shift-drag drains. One undo removes the whole pour.
     - **Fill animation.**
       - Ponds rise from their beds and stream fronts run down their courses, on the emergence clock (per-vertex births in the water shader). Nothing appears at once.
       - Grass creeps out from the new shores.
     - **Brush list.**
       - `scripts/genesis_canvas.gd` keeps the ordered list `BRUSHES` (1 land, 2 water, then meadow, forest and path). Since the integration its entries are `brush_id`, `title`, `hint` and `script` (see "Slices 2-5 integrated" below).
       - The creation hint follows the brush in hand.
     - **Stroke feel.**
       - The land brush now emits `stroke_started` and is in the feedback's land modes. Slice 1 had left its tremor, fog reveal and swell unwired.
       - A pour parts the fog and swells the air softly, with no tremor.
     - **Off the main thread.**
       - The pour plans on a worker.
       - The plain's pond flood, shore fetch and stream geometry are built on a worker.
       - Reflection views re-set up over several frames, double-buffered, with the clip level as a uniform, and are capped at the two largest pond levels.
       - Rebuilds that leave the water inputs alone keep the water and its revision.
       - Headless, a pour's worst settle frame went from 54 ms to 18.5 ms (13.6 ms after the session's first reflection setup). The recurring 25 ms frames during emergence with ponds present are gone.
       - The first-dab hitch did not reproduce: the press path measured 3.4 ms.
     - **The plain in Fidelity's colours.** The plain now uses Fidelity's ground, foliage, rock, earth and water, a clear day sky, fair weather and thin ground mist. The badge reads "Fidelity green", and generated worlds still draw from the palette families.
     - **Still open.**
       - Emergence's first plan (about 36 ms) remains.
       - Stream beds are not carved. *Now carved (`feature/water-polish`).*
       - Planar reflections cost about 4.6 ms of CPU per frame while ponds exist. *Now 0.58 ms (`feature/water-polish`).*
3. **Life answers the land.**
   - Fish settle in new water.
   - Frogspawn appears in shallow edges.
   - Birds and herons come to shores.
   - Deer come to forest edges at dawn.
   - Birds, fireflies and frogs read the live world instead of fixed reference positions.
   - Arrivals follow conditions plus a delay, like plant emergence.
   - Add the rare "and it was good" moments: a heron landing, deer at dawn, a rainbow after rain, perhaps a glimpse of Bigfoot at the forest edge.
   - **What landed (`feature/life-answers`):**
     - `scripts/land_life.gd` re-reads the live world when the editor reports a change (settle, stroke end, undo, load). It reads heights, the drawn pond surface, stream beds and every plant, in 1.2 ms slices a frame (`scripts/life_survey.gd`), never per frame.
     - Fish, frogspawn, frogs (after spawn), gulls and fireflies arrive at their places after emergence-style delays keyed to position hashes, and leave when their water or cover goes.
     - Rare moments with chances and cooldowns (`scripts/life_moments.gd`): a heron lands to fish, deer step out at dawn, a rainbow follows rain over a rich place (`celestial.moment_bow`), and, in scenery mode only, the ambient Bigfoot model (first a silhouette; replaced on `feature/bigfoot-sighting`, see `docs/scenic/life.md`).
     - New faceted meshes: fish, frogspawn, heron and deer (`scripts/life_models.gd`).
     - Blank worlds only; the Fidelity world keeps its authored life. `--no-life` turns it off.
     - LandLife costs p95 0.1-0.2 ms a frame headless, with no stroke or settle change measured against `--no-life`.
     - Rules and tunables: `docs/scenic/life.md`. Probe: `tools/probe_land_life.gd`.
     - The look is unverified until the user launches it.
4. **Meadow, forest and path brushes.**
   - These write intent, and the world picks the details.
   - A forest brush plants a natural edge and thins on steep rock.
   - A path brush leaves worn ground with stony edges.
   - A meadow brush paints softer painted cover and flowers as ground colour, not blades.
   - All three respect provenance, so hand work always wins.
   - **What landed** (`feature/land-brushes`, 2026-09-26; `docs/scenic/brushes.md`):
     - **Scripts and keys.** Each brush is its own script: `scripts/meadow_brush.gd`, `scripts/forest_brush.gd` and `scripts/path_brush.gd`. They share `scripts/creation_brush.gd`. `genesis_canvas.gd` keeps the ordered brush list (`BRUSHES`). Keys are 1 land, 2 water, 3 meadow, 4 forest and 5 path. The editor's "land" tool paints with the brush in hand (`select_brush`, `brush_changed`).
     - **Forest.** The brush writes a forest wish, from -1 to 1, into a new intent layer (`scripts/land_intent.gd`). The wish is part of the undo step but is not saved. Emergence grows it over the succession clock: shrubs from about 9 s, trees from about 5 s, the core first. It gives a dense core, a frayed and lobed edge, and shrubs at the margin. Trees still thin on steep rock, and nothing grows on water or snow. Shift-drag clears ground and withdraws what emerged there.
     - **Meadow.** A lighter, warmer green is painted as ground tint, with flower-coloured faces in drifts. There are no blades.
     - **Path.** Worn earth with gravel margin faces. The tread sinks and smooths by up to 7 cm. At release the path lays small stones along its edges, and clears emerged plants and generated undergrowth from the tread.
     - **Provenance.** Meadow and path cells are marked hand. Hand-placed and pinned records are never touched.
     - **Feel.** Per-brush feel is set in `StrokeFeedback.BRUSH_FEEL`; the forest brush has the strongest wind swell. The land brush now emits `stroke_started`. On `main` it never did, so it had no tremor, fog reveal or grow-in wave.
     - **Pipeline.** `GardenView` no longer rebuilds every MultiMesh, and the water, for a cover-only change. The grass mask is out of the instance signature, and all cover masks are out of the water signature. This also removes the rebuild that emergence's cover steps paid.
     - **Carried polish, first-dab hitch.** On recipe worlds the per-face slope probes are now kept warm on a worker. The first sculpting dab there went from about 75 ms to 2 ms.
     - **Measured** headless on the plain (`profile_stroke --mode=land --brush=…`), 30-dab stroke, machine shared with other agents:

       | Brush | Stroke frames p95 / max | Dab median | Release | Frames over 16.7 ms |
       |---|---|---|---|---|
       | Land | 11.6 / 12.1 ms | 3.1 ms | 22 ms | 0 |
       | Meadow | 11.6 / 11.9 ms | 4.5 ms | 2.7 ms | 0 |
       | Forest | 11.5 / 12.0 ms | 4.0 ms | 2.2 ms | 0 |
       | Path | 11.3 / 11.7 ms | 4.4 ms | 3.9 ms | 0 |

       A 40 s forest watch grew 16 trees and 23 shrubs, with one 21 ms frame at the first plan. On generated seed 58 the stroke maximum is about 10 ms for every brush. The path's settle there has two frames of 17–27 ms, from the water rebuild when a stroke crosses a pond; that frame was already carried from slice 1.
     - **Unverified.** How the new ground colours read on each palette family, the stones, the forest's outline, and the feel. All of it needs a look on screen.
5. **The creation interface.** Landed on `feature/creation-shell` (2026-09-26); the look was first seen in the slices 2-5 film.
   - **Palette:** a glass strip at the bottom centre lists every brush in `Genesis.BRUSHES` (`scripts/genesis_canvas.gd`), in order, keys 1-9. It shows the size and strength of the brush in hand as two thin meters, and ends with **Look**. A one-line how-to sits beneath and fades after the first stroke (`scripts/creation_palette.gd`).
   - **Look (Tab):** puts the brush away. The camera roams, there is no brush ring and nothing paints. A brush button or its number picks it back up. **H** hides the chrome and puts the brush away with it; H again restores both.
   - **Top right:** only **Craft** (the old rail; it reads **Create** while open) and **World**: New open plain, Regenerate landscape, Return to previous place (swaps with `places-previous.json`), Save now, Colors & sky, Overview, Main menu. Alt+`[ ]` still steps the showcase seeds.
   - **Chrome:** the parked maker-editor glass (dark translucent tint over a blurred frame, transparent buttons with a thin selected outline) is reused in `scripts/glass_chrome.gd` and `shaders/editor_glass.gdshader`. Its pixel-stepped colour sprites stay parked; the shell uses thin line glyphs instead.
   - **World menu:** `diorama.gd` builds it from explicit actions (`add_world_action`) instead of pressing hidden toolbar buttons by index. The ids are unchanged. `_home_button` is gone; His spot greys itself out.
   - **`--verify-desktop-build`:** now walks the shell (plain, palette lists the registered brushes, first brush in hand, Look stops painting and a press orbits instead, Craft and Create, menu round trip). It passes headless from the source tree. The run uses a temporary places folder so it never touches the player's saves.
   - **Still open:** confirm the look on screen, the glass blur's frame cost, and the exit-time resource leak lines. Those lines appear before and after this change, and `tools/verify_desktop_export.py` fails on any `ERROR:`.

6. **Sound.**
   - Stroke sounds: rumble as land rises, water filling, wind swelling.
   - World beds that follow what exists (water, birds, forest).
   - None exist today; `tools/generate_nature_audio.py` can synthesise them.
7. **Inspect and photo mode.**
   - A composed camera, UI off, and capture.
   - This may be the "finished moment" that the open questions ask about.
   - **What landed** (`feature/photo-mode`, 2026-09-26; `scripts/photo_mode.gd`):
     - **Entering.** **P**, or **Photo** (a camera glyph beside Look in the palette), from the brush or from Look. The brush is put away, every CanvasLayer at layer 1 or above hides (the shell, notices, hints, the place badge), and the world keeps living. Layers at 0 and below are part of the picture (display fog, look grade, fall mist) and stay. **P** or **Esc** (or **Back**) returns to Look or the brush in hand, and the camera glides home over 0.7 s; a drag during the glide takes it over. A brush number leaves and picks that brush up.
     - **The camera.** It still places the scene's own orbit (target, yaw, polar, distance), so the fog, reflections and look pass read the camera they always do; photo mode runs before the scene each frame and writes an eased pose into it.
       - Drag orbits, right- or middle-drag (or Shift-drag) pans, scroll or pinch dollies. All of it glides to rest (exponential ease, 0.22 s), a little slower than the everyday orbit. Over the plate the orbit never dips under the ground.
       - **G, the ground eye:** the camera steps down 0.85 m above the ground a little ahead of where it was, facing the same way. Drag looks around, right-drag or the arrows walk, scroll steps. After 1.6 s without input the pitch settles gently toward the horizon. The horizon is always level: there is no roll. **G** again rises back to an orbit around a point ahead. The eye follows the terrain, not pond surfaces.
       - **`[ ]`** steps the lens through 16, 24, 29, 35, 50, 70 and 100 mm (the scene's 45° is about 29 mm), easing the field of view. **Shift+`[ ]`** sets exposure in quarter stops to ±1.5 (`CameraAttributesPractical.exposure_multiplier`).
       - **F** turns on depth of field (near and far blur around a focus distance), starting on what the centre of the frame rests on; a click refocuses there with an eased rack. Camera attributes go on only when exposure or focus is first used.
       - **H** hides the strip and hints for a clean view; **R** reframes where photo mode began.
     - **Chrome.** A glass strip (Ground/Rise, lens, Focus, exposure −/+, the shutter, Back) wakes on pointer movement and fades after 2.2 s still. A one-line hint fades after 6 s. All of it is on its own layer and never in a photo.
     - **Capture.** **Space** (or Enter, C, or the shutter) hides the strip for one frame, reads that frame back and writes an 8-bit RGB PNG on a `WorkerThreadPool` task, at the window's render resolution (no supersampling: the display fog is a canvas pass on the main viewport, so a 2× render would need a second composite). Photos go to **~/Pictures/ZenScape** (`user://photos` if Pictures is missing; `--photo-dir=PATH` for probes), named like `ZenScape - Open plain - Fidelity green - Day 2 dawn - 2026-09-26 14.03.22.png`. A quiet "Saved to Pictures/ZenScape" toast offers **Show in Finder**. A soft flash marks the shot.
     - **Inspect.** A click on a creature or plant shows a small glass label that fades after 4.5 s, e.g. "Grey heron · landed at dawn", "Frog · arrived at dusk", "Pine · took root in the morning", "Tree · part of the land". Creatures come from LandLife's present sites (fish, frogspawn, frogs, birds) and its moments (heron, deer, and Bigfoot as "Something tall"); plants and stones from the editor's object picker. The hour comes from arrivals photo mode heard this session (`LandLife.arrived`/`moment`, `Emergence.tree_arrived`); older ones read "settled here", "grew here on its own", "placed by hand" or "part of the land".
     - **Checks.** `--verify-desktop-build` enters photo mode from the palette, drags (turns, paints nothing), steps the lens, tries the ground eye, leaves with P back to the brush, then enters with P from Look and leaves with Esc back to Look. It passes headless from the source tree (enter 0.5 ms, leave 0.01 ms); its exit-time leak lines are the same six as on `main`. `tools/capture_photo_mode.gd` is the rendered check (seed 184, 1600×1000 window).
     - **Measured** rendered on the Mac, 1600×1000, seed 184 (frames about 15 ms at the 120 fps cap with the scene's load):
       - Entering: 1.7–2.8 ms on the main thread, no frame above 17.7 ms. The shell's first Look of a session costs one ~26 ms frame (parking the editor), whether Tab or P does it; photo mode skips Look's world-play preparation (props and collision, 21 ms on a fresh world) because it keeps every press for the camera.
       - Leaving: 0.4–0.6 ms, worst frame 17.5–19.8 ms, from picking the brush back up.
       - Capture: hiding 1.1 ms, readback 14–33 ms (the unavoidable GPU sync, once per shot), then nothing on the main thread; frames after it stay at 14–15.5 ms. The PNG (0.7–0.8 MB) is written on a worker.
       - Inspect: 12–15 ms on a click, mostly the object picker building triangle meshes the first time.
     - **Stills:** `/private/tmp/zs-photo/out/` (not committed): the orbit and ground-eye photos, `still-strip.png` (the strip and hint), `still-ground-label.png` (a label and the toast) and `still-after.png` (the shell back). The photos carry no UI.
     - **Still open:** the feel of the ease and the ground eye in the hand, the DoF look at other hours and in fog (the display-fog composite draws over the blurred frame), whether P should keep pausing anything (P used to pause motion in the shell; it now opens photo mode there, and still pauses in the studies), a photo gallery or share, and water-aware eye height.
8. **Quiet guidance.**
   - A regional beauty score that nudges water levels, edges and variant choice without the player seeing it.

### Slices 2-5 integrated (`feature/phase3-slices-2-5`, 2026-09-26)

Merged in order: water brush, land brushes, life answers, creation shell, then merged to `main` on 2026-09-26.

- **One brush list.** `Genesis.BRUSHES` holds land, water, meadow, forest and path (keys 1-5) as `brush_id`/`title`/`hint`/`script` entries. The editor instantiates one brush per entry, the shell's `_creation_key` is the only number-key handler, and the palette lists the same entries.
- **One paint path.** The editor's "land" tool paints with the brush in hand, water included. Water extends `creation_brush.gd` as a settling brush: dabs only record, and the pour plans on a worker after release. The shell picks brushes with `NativeChunkEditor.select_brush` rather than `select_tool(brush_id)`, because a `"meadow"` mode already means the craft Meadow tool. `[ ]` size the brush in hand; the palette's meters read `brush_setting`.
- **Feel.** Water is a `StrokeFeedback.BRUSH_FEEL` entry (fog reveal, soft swell, no rumble, puffs or wave).
- **Life.** LandLife also re-reads the world when a pour settles (`water_settled`) and waits for a settling pour before it surveys.
- **Checks.** `--verify-desktop-build` also picks every registered brush from its palette button. A Movie Maker film of all five brushes and the life that follows is `tools/film_genesis.gd` (rendered 2026-09-26 to `captures/phase3-slices-2-5.mp4`, not committed; with `--force-moments` it starts a deer or heron near the end if none came on its own).

**Carried polish, fold into whichever slice touches it:**
- The first-dab hitch no longer reproduces on the plain (3.4 ms), and on recipe worlds it dropped from about 75 ms to 2 ms. Emergence's first plan now runs on a worker (see "Frame spikes at release" above).
- Dense grass: fix its render or retire it. It is opt-in with `--beauty-grass`, and the user does not want blades by default.
- Craft mode's fine tools against the new provenance and pipeline: check that they still behave.
- Bring tests back only when the user asks.

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
