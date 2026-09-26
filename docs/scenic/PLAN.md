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

In progress. Item 1 and the Blender trees from item 3 are in PR #19. Neither has been seen on screen together yet.

1. **Replace the generator's "usable, connected ground" gate with a beauty score.** Done in PR #19 (`feature/beauty-score`). Not yet seen on screen.
   - `scripts/world_beauty.gd` scores a candidate from the overview camera: drama (rise over the plate's far edge, land hidden behind nearer ridges, skyline movement, peaks), relief, a focal summit or water, water share, and composition (summit near a third, balanced weight, walls not hiding the land).
   - The generator keeps the family it draws, builds six candidates and keeps the best. It also draws four palettes and keeps the most harmonious. A world takes about 124 ms on the worker.
   - Genome version 6 keeps the three clearings for dressing but no longer flattens them. Saved version 5 worlds keep their terraces. The meadow fallback is gone.
   - Over 150 seeds the mean score rises from 0.64 to 0.71 and every family's worst world improves. Palettes scoring under 0.6 drop from 79 to 12.
   - Known gaps: the score is blind to what makes a chasm or a marsh good, so those families only compare among themselves. Scores are not comparable across families. `inland_places.quality` is now only used by the deferred tests, and `test_inland_places.gd` will fail its usable-ground floor.
   - Tune the weights (`WEIGHTS` in `world_beauty.gd`) against captures. `tools/probe_world_beauty.gd` sweeps scores and timings headless; `tools/capture_seed_stills.gd` renders stills or orbit frames per seed.
2. **Erosion plus ridged, domain-warped noise** in the native C++ terrain kernels (`native/terrain_kernels`). Today there is one noise octave and no erosion.
3. **Seeded tree and rock variants.** `layered_tree.gd` has no seed, the catalog has 22 fixed assets, and each habitat cycles its props with `i%4`.
   - **Blender trees, committed as `a2eec16` and in PR #19.** Scripts in `tools/blender_trees/` (plus `tools/build_hero_oak.py`) build faceted trees in Blender and export them to `assets/models/`. Run one with `blender -b --factory-startup --python <script>`.
   - `scripts/hero_trees.gd` swaps the geometry behind the existing catalog parts and keeps each part's material, wind and tint. The oak replaces the broadleaf and the redwood replaces the redwood.
   - Pines grow as a six-variant spruce family. `garden_instance_samples.gd` picks the variant per tree with a stable weighted hash.
   - Arid worlds plant Joshua trees (a new `joshua` asset) for about half of their cactus slots.
   - `--classic-trees` restores the source meshes for comparison. Not yet checked on screen.
   - Still to do: seeded rocks, a seed for `layered_tree.gd`, and replacing the per-habitat `i%4` prop cycle.
4. **Blend two or three biomes per world** from moisture, altitude and slope direction, instead of one habitat string. Geology colours should come from the palette. The desert band colours are hard-coded in the shader today.
5. **Curated palette families.** Start from the landscape experiment's chalk, copper, moss and lavender (on branch `wip/parked-2026-09-26`).
6. **Weather and seasons that change while you watch.**
   - The weather scheduler is off by default.
   - Seasons do not yet drive plants: no spring bloom, no bare winter trees.
7. **Rebalance the weather odds.** Across 300 seeds, overcast is the most common weather at 24%, and rain and snow add another 27%. That makes half of random regrows grey or wet, and overcast turns off god rays.
8. **Later: horizons beyond one 28 m plate.** Stitched multi-chunk terrain exists on `feature/stitched-terrain`.

## Phase 3: crafting in the spirit of Tiny Glade

- **Brushes that decorate for you:**
  - Painting a path gives it grassy, stony edges.
  - Painting a forest gives it a natural edge.
  - Water settles in the low ground.
- **The skill is composing,** not placing every tree by hand.
- **Rebuild the UI around this:**
  - Replace the top toolbar that hides buttons by moving them into the World menu by position (`diorama.gd`).
  - Check the maker-editor look on screen. It was parked, never seen.
  - Add an inspect and photo mode.

## Phase 4: presentation

- A shader warm-up pass, plus the shader baker in export presets.
- Visibility ranges with fade on props, trees and MultiMesh batches. There are none today.
- HDR output, new in Godot 4.7.
- Movie Maker mode (`--write-movie`) for trailer footage.
- Threaded resource loading for places.

## Showcase seeds

These are `SHOWCASE` in `scripts/cozy_regrowth.gd`, re-picked on 2026-09-26 after the beauty score. They are the top scorers per family in seeds 0–399 of `tools/probe_world_beauty.gd`. They have not been looked at on screen yet.

| Family | Seeds |
|---|---|
| Mountain | 184 (clear), 105 (tall massif, fair), 147 (volcanic crown, rain) |
| Massif | 193 (sawtooth, clear), 276 (tall massif, snow) |
| Valley | 79 (glacial, fair), 240 (mist), 363 (buttressed canyon, fair) |
| Basin | 176 (clear) |
| Plateau | 33 (fair), 102 (mist) |
| Chasm | 353 (clear) |
| Foothills | 58 (rolling uplands, fair) |
| Meadow | 177 (fair) |
| Marsh | 198 (clear) |
| Desert | 134 (fair) |
| Desert mountains | 45 (fair) |
| Buttes | 126 (clear) |
| Tablelands | 248 (fair) |
| Dunes | 250 (clear) |
| Salt basin | 28 (fair) |
| Monuments | 364 (fair) |

## Working agreements

- Run tests only when the user brings them back. Until then, check scripts with `--check-only` and have the user look at the result.
- `tests/test_scenery_mode.gd` is drafted and has never been run. Existing Bigfoot tests are expected to fail against the product scene.
- Use `--rendered` Godot runs only when the user asks. Headless Godot does not compile shaders, so shader changes are unverified until the user launches.
- Launch with `./run-cozy-flow.command`. `godot` is not on PATH; the binary is `~/Applications/Godot.app/Contents/MacOS/Godot`.
- The uncommitted work from before the pivot is parked on `wip/parked-2026-09-26`. It holds the beach ball, perching bird, maker editor and the landscape experiment.
