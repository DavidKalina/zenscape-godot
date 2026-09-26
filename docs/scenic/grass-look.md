# Grass look: painterly meadow

Phase 3, branch `feature/grass-look`. The user said the grass "looks like stubble… it doesn't look artistic enough". The direction is a painterly meadow in the spirit of Ghibli and Tiny Glade. It keeps the existing look and palette families, so this is an upgrade, not a restyle.

Scope: the dense GPU grass drawn on Ultra (`scripts/dense_grass.gd`, `shaders/dense_grass.gdshader`). The dressed `grass_tuft` and `bank_grass` meshes from `native_flora.gd`, which every tier draws, are unchanged. So are the grass masks in `NativeTerrainData` and the mask bake.

## Why it read as stubble

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
- **Wind:** long waves roll downwind (`wave_length`, `wave_speed`, `wave_strength`). They ride `zs_gust_distance`, so they travel with the air and stay frame-rate independent. A noise bends the crests so they wander, and the gust field and puffs still scale them. Bowed blades read paler (`wave_sheen`). Only a small per-blade `flutter` is left.
- **Accents:**
  - Flowers come in drifts of one kind: white daisy, buttercup, violet and clover. Their colours lean toward the palette's earth (`flower_palette_pull`).
  - Spring adds more flowers (`spring_flowers`) and winter takes them.
  - Seed heads stand where the grass is drier (`seed_amount`).
- **Per-world variety:** `world_offset` comes from the recipe seed, so each world has its own tussocks, dry patches and drifts.
- **Level of detail:** past `fade_start` the tufts drop to `far_blades` blades, as well as thinning and widening as before.

The season response (`zs_season_grass`, the winter shortening), autumn paint, snow, wet droop, the tread wake, cloud shade and the grow-in line are all kept. The grow-in line (`zs_growth.y`) and the lines either side of it are byte-for-byte unchanged, so the local growth wave from `feature/stroke-feel` merges cleanly.

## Tunables

All tunables are shader uniforms on `DenseGrass.material` unless noted. Each group lists its defaults.

- **Size:** `blade_height` 0.34 (was 0.26) and `blade_width` 1.0. The mesh constants in `dense_grass.gd` are `BLADES`, `BLADE_HALF_WIDTH`, `ROOT_SPREAD`, `LEAN` and `BLADE_SHARE`.
- **Clumping:** `tuft_scale` 1.3, `tuft_contrast` 0.7, `tuft_lift` 0.75 and `water_lush` 0.35.
- **Shape:** `tuft_spread` 1.0, `blade_lean` 1.0 and `blade_curve` 1.8.
- **Colour:** `root_shade` (0.46, 0.53, 0.46), `tip_lift` (1.30, 1.28, 0.84), `tip_curve` 0.8, `dry_amount` 0.45, `dry_scale` 0.16, `straw_tint` and `tuft_variation` 0.12.
- **Light:** `mass_shading` 0.9, `tuft_round` 0.55 and `tip_translucency` 0.55.
- **Wind:** `wave_length` 6.5 m, `wave_speed` 1.0, `wave_strength` 0.6, `wave_sheen` 0.22 and `flutter` 0.06.
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
