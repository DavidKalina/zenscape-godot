# Grass look: painterly meadow

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
- **Wind:** long waves roll downwind (`wave_length`, `wave_speed`, `wave_strength`). They ride `zs_gust_distance`, so they travel with the air and stay frame-rate independent. A noise bends the crests so they wander, and the gust field and puffs still scale them. Bowed blades read paler (`wave_sheen`). Only a small per-blade `flutter` is left.
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

## Tunables

All tunables are shader uniforms on `DenseGrass.material` unless noted. Each group lists its defaults.

- **Tufts (reference_surface, every tier):** `grass_dry` 0.25, `grass_living` 0.4, `grass_variation` 0.12, `grass_contact` 0.4, `grass_round` 0.55 and `grass_tip_glow` 0.55. The mesh constants are `BLADES`, `HALF_WIDTH`, `ROOT_RING`, `HEIGHT` and `LEAN` in `grass_tuft_mesh.gd`. Cover on the plain is `GENESIS_BLADES` and `GENESIS_FLOWERS` in `genesis_canvas.gd`; emerged cover is `_cover_target` in `emergence.gd`.
- **Living colour (dense grass):** `living_pull` 0.4 and `living_saturation` 1.12.

- **Size:** `blade_height` 0.34 (was 0.26) and `blade_width` 1.0. The mesh constants in `dense_grass.gd` are `BLADES`, `BLADE_HALF_WIDTH`, `ROOT_SPREAD`, `LEAN` and `BLADE_SHARE`.
- **Clumping:** `tuft_scale` 1.3, `tuft_contrast` 0.7, `tuft_lift` 0.75 and `water_lush` 0.35.
- **Shape:** `tuft_spread` 1.0, `blade_lean` 1.0 and `blade_curve` 1.8.
- **Colour:** `root_shade` (0.46, 0.53, 0.46), `tip_lift` (1.30, 1.28, 0.84), `tip_curve` 0.8, `dry_amount` 0.25, `dry_scale` 0.16, `straw_tint` and `tuft_variation` 0.12.
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

Round two is also unverified on screen. The shader changes in `grass_look.gdshaderinc`, `reference_surface.gdshader` and `dense_grass.gdshader` have not been compiled. The GDScript parses headless. A headless probe built the tuft (70 vertices, 50 triangles) and sampled three Genesis plains (7,518–7,662 tufts). To check on the next film:

- the plain reads green and grassy rather than as spikes;
- the Chalk & turquoise tufts are sage green, not tan;
- straw patches are occasional;
- flower drifts are visible but sparse;
- the startup log names the grass that is on;
- `--classic-grass` shows the source tuft with no dense grass on Beauty.
