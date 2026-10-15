# Grass look: painterly meadow

> **Retired unless requested (2026-09-27, `feature/phase3-polish`).** The dense GPU grass draws only with `--beauty-grass`, on Beauty and Ultra alike, and builds nothing until first wanted. Its first render drew tufts metres wide and lying flat, and the user does not want blades by default, so the render is not fixed. The sections below describe it as it stood before; `--no-beauty-grass` and `--classic-grass` still force it off.

Phase 3, branch `feature/grass-look`. The user said the grass "looks like stubble… it doesn't look artistic enough". The direction is a painterly meadow in the spirit of Ghibli and Tiny Glade. It keeps the existing look and palette families, so this is an upgrade, not a restyle.

Scope: every tier's grass.

- The dense GPU grass, drawn on Ultra and at reduced density on Beauty (`scripts/dense_grass.gd`, `shaders/dense_grass.gdshader`). Beauty drew it only with `--beauty-grass` at first; since round two it is on by default.
- The dressed grass tufts every tier draws: the `grass_tuft` catalog part and the painted blades, both the source's `mesh-10` (`scripts/grass_tuft_mesh.gd`, and `reference_surface.gdshader` with `grass_blades`).
- Both share `shaders/grass_look.gdshaderinc`: the wind wave, straw patches, mass normal, tip glow, and the per-world noise offset `zs_grass_offset`.

`bank_grass`, the grass masks in `NativeTerrainData` and the mask bake are unchanged.

## Why the default tier's tufts read as stubble

- A world has about 1,650 tufts spread across it. Each tuft is six flat single triangles with no curve.
- `flat_faces` shaded every triangle as its own facet, so each tuft was a cluster of lit and dark shards.
- The root-to-tip colour (#38663a to #93c05f) was there, but faceting broke it up.
- The wind was the generic plant sway, so nothing rolled across the field.

## Why the dense grass read as stubble

Measured from the code on `main` at 8ac595c:

- **Short, thin, straight sticks.** Each clump had 3 blades, 2.2 cm wide at the root, bunched inside 5 cm and about 0.26 m tall. The blades stood straight up. Only an optional lean with one sign bent them, so from the diorama camera they read as a bristle of vertical dashes. The source tuft (`foliage.js` `grassTuftGeometry`) had 6 blades, 8 cm wide at the root, fanned out and leaning 7–20 cm.
- **Even spacing, uniform height.** There was one clump per cell of an 11 cm jittered grid. Thinning was per-clump salt and pepper, so there were no tussocks and no gaps. Height noise was low-frequency and gentle, so the field was a flat nap.
- **Flat colour.** Each blade was the ground's own colour times 0.62 at the root and about 1.12 at the tip, with no hue shift. Against the same-coloured ground, only the dark roots showed, which read as dark speckle. The source ran from #38663a at the root to #93c05f at the tip, which is much lighter and yellower.
- **Per-blade lighting noise and no translucency.** The normal was 30% the clump's random facing, so each clump shaded differently. The sheet backscatter term needs a back-facing normal. With 70% ground-up normals it never fired, so backlit grass never glowed.
- **Wind as jitter.** The wave was `sin(time·1.9 + phase)` on a fixed diagonal, plus a 3.4 Hz second harmonic per blade, at a few centimetres of amplitude. Nothing travelled across the field, and nothing changed brightness as the grass bowed.
- **Flowers only in spring,** painted onto the top 22% of a blade, never as a shape.

## What changed

- **Tuft mesh** (`_clump_mesh`): 6 blades fanned round the root, with 4 rows and a pointed tip. Each blade is 3.4 cm wide at the root and 55–100% of the tuft's height, tallest first. Each blade arcs outward, 0.18–0.5 of its own height, and lies over toward the tip (`blade_curve`). Each tuft also carries one accent stem with a 5-petal flower face and a crossed seed spike. The shader shows the accent on a few tufts only. The mesh is indexed: 76 vertices and 57 triangles per tuft, up from 45 and 15.
- **Tussocks:** a noise at `tuft_scale` gathers tufts into clumps with bare gaps between them (`tuft_contrast`). The heart of a tussock stands taller (`tuft_lift`), and grass within about 0.75 m of water grows lusher (`water_lush`).
- **Colour:** runs from `root_shade` to `tip_lift` over the palette-tinted ground colour, with a per-tuft brightness jitter. World-noise dry patches go toward straw (`dry_amount`, `dry_scale`, `straw_tint`), but not beside water.
- **Mass shading:** the normal is the ground's, domed outward over each tuft toward the tips (`tuft_round`) and tipped downwind as the blades bow. Only `1 - mass_shading` of the blade's own facing is left.
- **Translucency:** the tips glow when you look toward the sun (`tip_translucency`). This is a new `ZS_GRASS_TRANSLUCENCY` block in `reference_direct_light.gdshaderinc`, shadowed like direct light. The grass no longer defines `ZS_FOLIAGE_TRANSMISSION`.
- **Wind:** long waves roll downwind (`wave_length`, `wave_speed`, `wave_strength`). They ride `zs_gust_distance`, so they travel with the air and stay frame-rate independent. A noise bends the crests so they wander, and the gust field and puffs still scale them. Bowed blades read paler (`wave_sheen`). Only a small per-blade `flutter` is left. Since the breeze pass this wave is the shared breeze's (`zs_wave_crest_at`, `zs_breeze_lean_wave`); see [the breeze](breeze.md).
- **Accents:**
  - Flowers come in drifts of one kind: white daisy, buttercup, violet and clover. Their colours lean toward the palette's earth (`flower_palette_pull`).
  - Spring adds more flowers (`spring_flowers`) and winter takes them.
  - Seed heads stand where the grass is drier (`seed_amount`).
- **Per-world variety:** the global `zs_grass_offset` comes from the recipe seed, so each world has its own tussocks, dry patches and drifts.
- **Level of detail:** past `fade_start` the tufts drop to `far_blades` blades, as well as thinning and widening as before.

The season response (`zs_season_grass`, the winter shortening), autumn paint, snow, wet droop, the tread wake, cloud shade and the grow-in line are all kept. The grow-in line (`zs_growth.y`) and the lines either side of it are byte-for-byte unchanged, so the local growth wave from `feature/stroke-feel` merges cleanly.

## Default tiers: the dressed tufts

- **Mesh** (`scripts/grass_tuft_mesh.gd`): 7 blades per tuft (10 since round two, below), fanned out using the source's root ring, heights and lean. Each blade is a tapered strip that arcs outward (`LEAN_CURVE`) and has a pointed tip. The mesh copies its root and tip colours from `mesh-10`, so it keeps the source gradient. It has 49 vertices and 35 triangles, where the source had 18 and 6. `--classic-grass` keeps the source tuft.
- **Material** (`GardenView`): `grass_blades` is on and `flat_faces` is off. The shader:
  - lights the tuft with the height-map ground normal, domed outward (`grass_round`);
  - adds the shared rolling wave and its paling, on top of the source sway;
  - adds straw patches (`grass_dry`) in the same places as the dense grass;
  - makes the tips glow when backlit (`grass_tip_glow`).
- **Cost:** about 1,650 tufts per world, so roughly 58k triangles, up from 10k. Each vertex adds three height-map taps and a noise. This is well under 0.1 ms on any tier.

## Dense grass on Beauty

Beauty shows the dense grass by default at reduced cover (`DenseGrass.REDUCED`, set on `feature/grass-lush`):

- density 0.7 (was 0.55 behind the old opt-in);
- 2 blades per far tuft;
- the fade starts at 18 m.

`--no-beauty-grass` turns it off, and so does `--classic-grass`, so that A/B shows the old default look. `--beauty-grass` is still accepted and forces it on. Balanced never draws it; Ultra draws full cover. The choice and its cost are in "Round two" below.

## Round two: a lush default (`feature/grass-lush`)

After watching a Movie Maker film of the Genesis plain (default Beauty tier, Chalk & turquoise, summer, mist), the user could not tell whether the new grass was on. It was: the painterly tuft was drawn. The ground still read as sparse, dry straw spikes over grey, for these reasons.

### Diagnosis

- **Almost no tufts.** `genesis_canvas.gd` set `blades` to `smoothstep(0.38, 0.7, noise) * 0.4`. The noise rarely passes 0.4, and `GardenInstanceSamples` truncated `blades * 8` to whole tufts, so a blank plain had about 80 tufts in total (76–94 over three seeds). Emergence raised dry ground to 0.14, which truncated to one tuft per 0.25 m² cell.
- **The palette turned the tufts to straw.** Palette families tint grass by a ratio to the source green #5d9e53. For Chalk & turquoise (#929c72) that ratio is about (2.6, 1.0, 1.9) in linear. It turned the tuft's #93c05f tip into a tan straw (about #e3bd82) and its #38663a root into a grey olive. The dense grass, tinted through the ground palette, would have gone grey the same way.
- **Straw patches and a dark base.** `grass_dry` 0.45 took a noticeable share of the ground to straw. The tuft's root shade (from the source, about 4.3× darker than its tip) was darkened again by the contact-occlusion term over its whole height, since it stands under 0.85 m.
- **Too thin at the camera distance.** At 20–26 m a pixel spans about 2.5 cm. The 7-blade tuft, with blades 5.6 cm wide at the root and tapering to a point, drew as a few one-pixel spikes.
- **No dense grass on Beauty.** Beauty is the default tier, and the dense GPU meadow was opt-in there.
- **Not grass.** Mist and display fog still soften the whole plain; the twiggy dark shapes in the film are dead wood and shrubs, not grass. Neither was changed here.

### What changed

- **Coverage.** The Genesis plain lays a carpet of `blades` 0.22 everywhere, rising by up to 0.3 in tussocks (`GENESIS_BLADES`), with small flower drifts in `meadow` (`GENESIS_FLOWERS` 0.13, one flower a cell inside a drift). Emergence grows dry ground to 0.22 and damp ground to 0.48. The instance sampler now dithers the fraction per cell with a golden-ratio sequence instead of truncating it. A blank plain has about 7,500 tufts and 130–230 flowers, up from about 80 and none.
- **A fuller tuft.** `grass_tuft_mesh.gd` has 10 blades, 8.4 cm wide at the root. Inner blades stand tallest (up to 0.44 m) and outer ones lean furthest (up to 0.26 m), so each tuft is a rounded mound about 0.55 m across. It has 70 vertices and 50 triangles, up from 49 and 35.
- **Living colour tied to the family.** `zs_grass_living` in `grass_look.gdshaderinc` takes the family's grass colour and leans it 40% toward living green at the same luminance, then saturates it slightly (1.12). For Chalk & turquoise this gives a soft sage green (about #83a666) where the tufts were tan. The tufts then run from the shared `ZS_GRASS_ROOT_SHADE` to `ZS_GRASS_TIP_LIFT`, as the dense grass does, and jitter ±12% per tuft. Their vertex colour, divided by the mesh's own root and tip colours (`grass_source_root`, `grass_source_tip`, set by `GrassTuft.dress`), only carries each blade's tip jitter and any instance tint. The dense grass leans its ground colour to living green the same way (`living_pull`, `living_saturation`).
- **Straw as an accent.** `grass_dry` on the tufts and `dry_amount` on the dense grass both drop from 0.45 to 0.25.
- **Softer base.** The tufts keep 40% of the contact darkening (`grass_contact`).
- **Shadows.** The painted meadow tufts (the `grass` batch) no longer cast shadows, like the dense grass. At about 5× the count, the shadow pass would have doubled their vertex cost, and tuft shadows do not resolve at diorama distance. The `grass_tuft` catalog props still cast them.
- **Dense grass on Beauty by default,** as described above.
- **A log line.** `look_pass.gd` prints one line at startup, and again only when the tier changes. For example: `Grass: tier Beauty, dense meadow reduced cover (--no-beauty-grass to turn off), tufts painterly tuft (10 blades, scripts/grass_tuft_mesh.gd)`.

### Cost

This is an estimate; nothing has been measured.

- **Tufts:** a blank plain draws about 7,500 tufts, or 375k triangles and 525k vertices, with no shadow pass. That is about 0.3–0.6 ms on the 4070 Super. On an Apple-silicon Mac on Balanced, expect 0.5–1.5 ms. Generated worlds grow about 10–40% more tufts than before, from the dithering.
- **Dense grass on Beauty:** 65,536 tufts are vertex-shaded wherever a tile is in view, and 70% of them are drawn. That is about 0.6–1.4 ms on the 4070 Super at 1440p, the earlier estimate. On the Mac it is probably 2–4 ms. Mac players who need the frames should use Balanced (`--balanced`) or `--no-beauty-grass`.
- **CPU:** every garden rebuild samples and fills about 7,500 more multimesh instances. This runs on the worker, and the main-thread fill runs under the frame budget, but a stroke refresh on the Genesis plain now carries about 5× the grass instances.

## Round three: a calm field (`beautification`, 2026-10-01)

The user said the grass was "too noisy, too angular". The ground had become the grass since the blades were dropped (d367f2a), and it read as a mosaic of light and dark triangles. The tufts left on the plain (the `grass_tuft` part, which emergence, the inland places and the meadow brush still plant) read as dark shards beside the new soft flowers. The aim: faceted shapes, soft light, and the field reading as one calm mass.

### What made the ground noisy

- **Three greens, picked per face by a hard threshold.** `NativeTerrainPalette.grass_at_coordinates` gives each face one of #5d9e53, #7fb069 or #4a8548 (after the seed-7 cover shift: linear luminance 0.29, 0.37 and 0.21), switching where an fbm at 0.4 per metre (about 2.5 m features) crosses 0.42 and 0.55. Neighbouring faces 1.7× apart in brightness sat side by side wherever the noise hovered near a threshold.
- **A random shimmer on top.** Every face adds ±0.035 linear to all three channels from a hash, about ±12% of the middle green's luminance, so even a single class flickered face to face.
- **Faceted light.** Each face is lit by its own normal (the mesh writes one normal per face), so rolling ground added a second light/dark pattern at the same scale.
- **Muted families made it worse.** Palette families multiply by their ratio to #5d9e53. Under Chalk & turquoise (2.6, 1.0, 1.9) the light class went tan and the dark one olive-grey, so the plain read as a grey and mauve patchwork.

The same colours are the source scene's (tests/test_native_palette.gd holds the palette to them), and the meadow brush and Paddle paint them into the tint layer, so the fix is in the shader rather than the palette.

### What changed: the ground

All in `shaders/ground_look.gdshaderinc`, used by `reference_surface.gdshader` on the ground only (`zs_is_ground`: `terrain_growth`, `palette_role` 1, not the earth sides).

- **Grass faces go most of the way to one field.** `zs_ground_grassness` tells grass faces by chromaticity: the three greens and their shimmer lie within 0.06 of the middle green, while bare earth, rock, sand, gravel, snow, a face half earth and half grass, and painted colours lie 0.2 or more away. A grass face moves `ground_calm` 0.8 of the way to the field colour, so 20% of its own colour is left as a hint of facet.
- **The field (`zs_ground_field`)** is the middle green leant toward the sunlit or deep green by two broad noises (about 16 m and 6 m), up to 0.65 of the way. Dry patches lean to a lighter, warmer green (`ground_dry` 0.45), in the same places as the tufts' straw (`zs_grass_dry` with `zs_grass_offset`). Within about 0.9 m of water (half by 1.8 m, none more than a metre above it) the green deepens (`ground_lush` 0.6).
- **Muted families stay green.** After the palette, grass faces lean 0.3 toward living green at the same luminance (`ground_living`, the tufts' `zs_grass_living` with no extra saturation). Chalk & turquoise now reads as a soft sage, not grey and mauve.
- **Softer light on grass.** The vertex stage takes a smoothed normal from the height map (`zs_water_map` green, central differences over 0.6 m), and grass faces are lit `ground_soft` 0.7 of the way to it, with 30% of the facet left. Rock and snow faces keep their facets. Geology, snow and wetness still read the face's own normal. Where the map does not match the vertex (mid-growth, mid-sculpt before the map catches up, a neighbouring chunk, off the plate), the face normal is used.
- **No new varyings.** The smoothed normal rides `world_normal` (the fragment takes the facet from derivatives), and the water nearness rides `earth_side.x`, which the ground never used. reference_surface still has 14 varying declarations (Metal's 31-component limit, 4b6508e).

Measured on the diorama stills (mean |luma − local 9×9 mean| over a patch of open plain): default palette 1.6% before, 0.3% after; Chalk & turquoise 1.2% before, 0.3% after. Mean brightness of the patch rose about 6%.

**The hook for later tints.** `zs_ground_color` in `ground_look.gdshaderinc` is the one place the ground's colour is made, and it ends in `zs_ground_meadow_tint(ground, world point)`, which returns the colour unchanged for now. A meadow tint under flower drifts goes there. The tufts' root and body colour call `zs_ground_color` too, so a tint there reaches them as well.

### What changed: the tufts

- **The soft tuft is the default.** `scripts/grass_tuft_mesh.gd` now replaces `mesh-10` without a flag; `--classic-grass` draws the source tuft. Each blade is still three flat facets and a point. It is fuller and lower than round two's: half width 4 cm (was 4.2), tip taper 0.55 (was 0.5), heights 0.20–0.36 m (was 0.24–0.44) and lean 0.09–0.22 m (was 0.08–0.26). A tuft is about 0.5 m across and 0.34 m tall, against the source's 0.42 m. It has 10 blades and 50 triangles; the source had 6.
- **Soft light by mass,** as the round-one painterly tuft had: the ground normal domed over the tuft (`grass_round`), tips glowing when backlit, no `flat_faces`, so neither side of a blade goes black.
- **Roots grow out of the ground.** The root takes the ground's own colour under it (`zs_ground_color` at the root), times 0.92, and gives way to the tuft's green by 0.6 of the way up (`grass_root_blend`). Contact darkening now only applies up the blade, so there is no dark ring at the base.
- **The tuft sits in the field.** Its living green leans 0.4 toward the ground colour under it (`grass_ground_pull`). Under Chalk & turquoise the tufts are a pale sage-green, not straw.

Placement is unchanged: no cover, digest or save format changed, and existing worlds load as before. Cost: the default tuft is 50 triangles where the source's was 6. A world with about 1,650 tufts draws about 82k triangles for them, up from 10k. Each ground vertex adds 40 height-map fetches (normal and water nearness); a plate has about 13k ground vertices. Each ground fragment adds three value noises.

### Loose grass chaff

`scripts/wind_grass_chaff.gd` is the leaf litter (`wind_leaf_litter.gd`) with grass blades: 36 at most, one per anchor, laid on open grass (`ground_coverage` over 0.4, picked by an R2 sequence so the same ground gives the same places). Each is a thin bent sliver 10–16 cm long in a soft straw-green. They weigh 0.5–0.75 against the leaves' 0.8–1.4, so the same air moves them sooner: the ordinary breeze rocks them, a swell or puff drags them, and a gust lifts and tumbles them downwind. Under one wind-tool gust in the test, a blade travels 2.6 m where leaves travel 1.7 m. They are cosmetic and not saved. Fidelity (and so every world) seeds them with the leaves and hides them while the world grows in; the wind playground hands them its local wind.

### Checks and stills

- `tests/test_ground_look.gd` (headless) checks that the shader's greens are the palette's, that every palette grass face (with its shimmer) counts as grass while rock, sand, gravel, snow, bare earth, a half-earth face and a painted rose do not, the hook and the single call site, the varying count, and the default tuft's size, triangle count and dressing.
- `tools/still_grass.gd` takes the stills: a flattened patch with 90 tufts, a hill and a small pond, in Alpine daylight, at close, mid, diorama and pond distances. `--chalk` uses Chalk & turquoise and `--set=ground_calm:0` sets a ground uniform for A/B. Run it windowed with `--no-title`.
- `tests/test_wind_grass_chaff.gd` (headless) checks the anchors, calm air leaving the chaff still, a gust lifting it further than leaves, settling and pause.
- Stills in `captures/grass/`: `before-*` and `before-chalk-*` are the base; `a2-*`, `a2-chalk-*`, `after-*` and `after-chalk-*` are the result. Each run grows a different random plate, so trees and rocks differ between stills.

### Unverified and left alone

- The pond's edge still shows a stair-stepped dark band. It comes from the water's edge and the damp-bank darkening (`zs_look_shore`, which reads the 0.25 m water map texel by texel), not from this pass.
- Inland worlds use `prototype_inland_surface.gdshader` and are not changed. Dense grass (opt-in) still reads its own ground colour.
- The tuft's wind, the soft normal under the wind tool and the chaff in flight were only seen in stills, not in motion.

## Round four: somewhere in between (`beautification`, 2026-10-02)

The user liked the calm field but found it "a little bit flat", and asked for somewhere between the old mosaic and the calm. The target was broad, soft patches of light and shade over tens of metres, a little warmer on sunny slopes and deeper in hollows, a gentle hint of facets, and no harsh per-triangle contrast.

- **More of each face's own colour.** `ground_calm` 0.6 (was 0.8), so 40% of a grass face's own green is left where 20% was. `ground_soft` 0.6 (was 0.7), so a little more of the facet's light shows.
- **A stronger broad field.** `zs_ground_field` now reads its two noises at 2.8 and 0.9 (were 1.8 and 0.7). The new `ground_patch` 1.3 (fixed at 0.65 before) is how far it leans to the sunlit and deep greens, a little past them at the extremes. At the same noise the field now leans about three times as far as in round three. In the stills, though, the spread between 33-pixel blocks of the plain rose only a little (2.1% to 2.2–2.4%): the mist, the facet light and each run's random plate weigh as much at that scale. The patches show, but gently.
- **Warmer sunny slopes, deeper shaded ones.** `zs_ground_sun_warm` takes the smoothed ground normal (already on `world_normal`) and the sun's direction. Grass on a slope turned to the sun goes up to 10% warmer and lighter (×1.10, 1.05, 0.88), and grass on a slope turned away goes up to 10% deeper (×0.90, 0.95, 1.0), scaled by `ground_warm` 0.5. Flat ground and rock are left alone, it adds no varyings, and it runs after the palette, so muted families shift the same way. Lusher low ground still comes from water only (`ground_lush`). There is no height-based hollow term: the plate has no reference level to measure a hollow against.
- **Tufts as small clumps.** The soft tuft now has two satellite clumps of three blades each, at 0.24–0.27 m from the centre and 0.55–0.62 of its size (`SATELLITES` in `grass_tuft_mesh.gd`). The clump is 0.71 × 0.46 m and has 16 blades and 80 triangles (was 50). Placement is unchanged, so no digest moved. A world with about 1,650 tufts draws about 132k triangles for them (was 82k). Real clustering of placements (emergence's shrub lattice) was left alone, because it would move the placement digests.

**Measured.** `tools/still_noise.gd` (new, headless) gives the mean |luma − its 9×9 local mean| over a fixed patch of open plain in the diorama still (x 80–440, y 470–650 at 1280×720). It reads the grass agent's own stills as 0.77% before and 0.15% calm (`captures/grass/before-diorama.png` and `a2-diorama.png` in its worktree). That is about half the 1.6% and 0.3% quoted in round three, which used a different patch, so compare the ratios rather than the absolute numbers. On this branch:

| Still | Noise | Mean luma |
| --- | --- | --- |
| Before round three (mosaic) | 0.77% | 0.49 |
| Round three (calm) | 0.15–0.19% | 0.50–0.52 |
| Round four, default palette | 0.35% | 0.49 |
| Round four, Chalk & turquoise | 0.37% | 0.54 |

That is roughly 45% of the way from calm to mosaic, or about 0.7% on round three's scale. Each run of `still_grass.gd` grows a different random plate, so expect ±0.05% between runs.

Stills are in `captures/final/` in the main checkout: `plain-diorama-final.png`, `plain-close-final.png` and the `plain-chalk-*` pair, with `plain-*-merge.png` as the calm field for comparison.

## Round five: the land's own colour (`look/ground-variation`, 2026-10-03)

After a play session the ground still read as flat, uniform green: the largest surface on screen with the least in it. Nothing darkened under trees, nothing told a hollow from a crest, and grass brushed onto a steep face stayed a bright slab. This round keeps the facets, adds no texture and no pattern, and lets colour follow what the land is doing. It builds on the unmerged `look/ground-form` (2052373, 2026-09-30), which carried the wet/dry/scree idea in the same varying slot but swapped the palette greens for a different blend; that branch was never adopted, so here the round-four field stays as it is and the new terms sit on top.

All in `shaders/ground_look.gdshaderinc` (`zs_ground_form`, called once from `reference_surface.gdshader` after `zs_ground_sun_warm`), plus the trees' shade field (`scripts/ground_shade.gd`).

- **Hue drift.** The field's broad light/deep patches now drift in hue as well, over about 9 m: sun-warmed patches yellower, deep ones cooler and bluer (`ground_hue` 1.15, `ZS_GROUND_WARM_DRIFT`/`ZS_GROUND_COOL_DRIFT`). Hue more than light, so it reads as meadow rather than noise. It is in the field, so the tufts' roots follow it.
- **Hollows and crests.** The vertex stage reads the height map on two rings (1.5 m and 3.5 m, 16 taps) and keeps how far the ground round about stands above (a hollow) or below (a crest, a convex edge, a crater's lip) the vertex. Hollows go lusher and cooler (`ground_hollow` 0.7), crests and high ground drier and paler (`ground_crest` 0.55); ground near water never reads dry.
- **Steep grass thins.** Grass on slopes past about 50 degrees (the smoothed normal) leans toward a dry olive of the same lightness (`ground_steep` 0.6), so grass brushed onto a cliff no longer stands out as a bright slab.
- **The floor under trees.** `GroundShade` bakes the trees' records into a 64x64 field over the plate (0.5 m texels): a soft pool per crown, flat under it and easing out to 1.7 radii plus 0.8 m, overlapping toward 1 in a grove. The ground darkens toward a cool, mossy green there (`ground_shade` 0.9, `ZS_GROUND_SHADE`); bare earth, rock and painted ground only darken a little. The tufts under trees take the same shade, and snow lies thinner there (`ZS_GROUND_SNOW_SHELTER` 0.45). Crown radii per kind are the catalog meshes' bounds (`GroundShade.CROWN`); desert plants cast none.
- **Autumn keeps its glow.** The first pass cooled the grass that the autumn paint keys its turn on, so autumn ground went muddier. Now the hue drift, hollow, crest and steep terms fade out as autumn (or the dry season) paints the ground (`zs_ground_season_hold`), and the trees' shade is laid after the season's paint, darkening warm (`ZS_GROUND_SHADE_WARM`) rather than grey.
- **Painted ground, seasons and looks.** Every term but the shade is scaled by the face's grassness, so painted tints (wheat's warm ground, Paddle's earth, rock and sand) keep their colour. The multipliers work after the palette, so they shift every family the same way, and autumn, the season's grass, wetness, snow and cloud shade still come after. Desert ground is not grass, so it is untouched.

**No new varyings.** The bowl and the shade ride `earth_side.y` and `.z` beside the water nearness in `.x`. `zs_ground_shade` is a new project shader global; its green channel is held at 0 so an unset texture (Godot's white) reads as no shade.

**Cost.** Per ground vertex: 16 more height-map taps and 4 shade taps (a plate has about 13k ground vertices, and the shadow pass runs the vertex stage too), well under 0.1 ms. Per tuft fragment: 4 shade taps. On the CPU the field is read only when `objects_revision` or the record count moves, at most every 0.2 s: a walk of the records (about 1.3 ms for 3,000). It is baked only when the trees among them changed, on the worker pool, never on the frame: about 0.3 ms for 13 trees, 1 ms for 80 and 55 ms for 1,500 off-thread. Painting flowers never bakes.

**Checks and stills.** `tests/test_ground_shade.gd` (headless) checks the pool's shape, that flowers, rocks and desert plants cast none, and on real terrain data that placing, removing, undo and redo a tree follow it while painting flowers does not bake. `tests/test_ground_look.gd` checks the hooks and that the varying count holds. `tools/capture_ground.gd` takes the stills (overview, low, a grove, a shore, golden hour, a mood, autumn and winter) of a saved world (`--resume --places=`), a seed, or `--diorama`, a fixed test scene with a hill, a lake and a grove; `--classic-form` turns the round-five terms off for a before/after on the same run.

## Tunables

All tunables are shader uniforms on `DenseGrass.material` unless noted. Each group lists its defaults.

- **Ground (reference_surface, every tier):** `ground_calm` 0.6, `ground_soft` 0.6, `ground_patch` 1.3, `ground_warm` 0.5, `ground_dry` 0.45, `ground_lush` 0.6 and `ground_living` 0.3; round five's `ground_hue` 1.15, `ground_hollow` 0.7, `ground_crest` 0.55, `ground_steep` 0.6 and `ground_shade` 0.9 (`shaders/ground_look.gdshaderinc`). The shade field's crowns, reach and depth are constants in `scripts/ground_shade.gd`.
- **Tufts (reference_surface, every tier):** `grass_dry` 0.25, `grass_living` 0.4, `grass_variation` 0.12, `grass_contact` 0.4, `grass_round` 0.55, `grass_tip_glow` 0.55, `grass_root_blend` (0.92, 0.6) and `grass_ground_pull` 0.4. The mesh constants are `BLADES`, `HALF_WIDTH`, `ROOT_RING`, `HEIGHT` and `LEAN` in `grass_tuft_mesh.gd`. Cover on the plain is `GENESIS_BLADES` and `GENESIS_FLOWERS` in `genesis_canvas.gd`; emerged cover is `_cover_target` in `emergence.gd`.
- **Living colour (dense grass):** `living_pull` 0.4 and `living_saturation` 1.12.

- **Size:** `blade_height` 0.34 (was 0.26) and `blade_width` 1.0. The mesh constants in `dense_grass.gd` are `BLADES`, `BLADE_HALF_WIDTH`, `ROOT_SPREAD`, `LEAN` and `BLADE_SHARE`.
- **Clumping:** `tuft_scale` 1.3, `tuft_contrast` 0.7, `tuft_lift` 0.75 and `water_lush` 0.35.
- **Shape:** `tuft_spread` 1.0, `blade_lean` 1.0 and `blade_curve` 1.8.
- **Colour:** `root_shade` (0.46, 0.53, 0.46), `tip_lift` (1.30, 1.28, 0.84), `tip_curve` 0.8, `dry_amount` 0.25, `dry_scale` 0.16, `straw_tint` and `tuft_variation` 0.12.
- **Light:** `mass_shading` 0.9, `tuft_round` 0.55 and `tip_translucency` 0.55.
- **Wind:** `wave_length` 9 m (was 6.5), `wave_speed` 1.0, `wave_strength` 0.42 (now a lean per unit of `zs_breeze`, was 0.6 per unit of the raw dial), `wave_sheen` 0.34 (was 0.22) and `flutter` 0.06. The tufts use the same values from `ZS_BREEZE_*` in `reference_wind`. See [the breeze](breeze.md).
- **Accents:** `flower_amount` 0.035, `spring_flowers` 0.08, `seed_amount` 0.04, `flower_size` 0.026 m, `seed_head_size` (0.008, 0.075) and `flower_palette_pull` 0.3.
- **Level of detail:** `fade_start` 22, `fade_end` 58 and `far_blades` 3.

## Cost

This is an estimate; nothing has been measured. There are 65,536 tufts at most, the same as before:

- Vertices: about 1.7× as many shaded, each with about five more noise taps and four more ground-map taps.
- Triangles: about 3.8× as many at most, for about 3.7 M in total. Hidden tufts and dropped blades collapse to degenerate triangles, which the GPU discards before raster.
- Past 22 m, half the blades drop out as well as the thinning.

Expect roughly 1–2.5 ms on the RTX 4070 Super at 1440p Ultra. If it costs more, the first levers are `BLADES` 6→5, `far_blades` and `fade_start`.

## Unverified

Headless runs do not compile shaders, so none of this has been seen on screen. The checklist to go through on first launch is in the branch's report.

Round two is also unverified on screen. The shader changes in `grass_look.gdshaderinc`, `reference_surface.gdshader` and `dense_grass.gdshader` have not been compiled. The GDScript parses headless. A headless probe built the tuft (70 vertices, 50 triangles) and sampled three Genesis plains (7,518–7,662 tufts). To check on the next film:

- the plain reads green and grassy rather than as spikes;
- the Chalk & turquoise tufts are sage green, not tan;
- straw patches are occasional;
- flower drifts are visible but sparse;
- the startup log names the grass that is on;
- `--classic-grass` shows the source tuft with no dense grass on Beauty.
