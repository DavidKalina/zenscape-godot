# Flowers: the meadow flower kit

Branch `worktree-agent-a439b45d63d62a49f`, from `beautification`. The user said the flowers "look really bad... you can't even tell that they're flowers". They asked for meadows of daisies, dandelions (yellow, and the white seed clock), cosmos, sunflowers and buttercups.

The style was settled with the user: shapes are faceted, light is soft. Petals are flat and clearly cut, stems are simple, and each plant has a few leaves. Shading follows the mass of the head, not each triangle. Petals glow when backlit.

## Why the old flowers did not read

- **Four abstract forms.** `button_flower`, `spike_flower`, `umbel_flower` and `daisy_flower` are the reference's geometry: a 0.2 m stem under a head 4 cm deep. The daisy head is 17 cm across but flat, so from the diorama camera (20–26 m, about 2.5 cm a pixel) it is a pale smear a pixel or two high.
- **Per-facet shading.** Their material has `flat_faces` on, so each head breaks into lit and dark shards.
- **One colour per head.** Petals and centre take a single instance tint, so a daisy has no yellow eye.

## What changed

- **Mesh** (`scripts/meadow_flower_mesh.gd`): one procedural plant per kind, built once and indexed. Each has a three- to five-sided stem, folded leaves (lance, broad, heart-shaped or palmate), and heads made of flat petals in rows, a domed disc with a green back, and bracts. Heads are drawn 1.2–1.35× the builders' sizes (`HEAD_SCALE`), so a daisy face is about 15 cm, six pixels at the diorama camera. The grass tufts are stylised the same way.
- **Vertex data**, read by the material:
  - COLOR is the part's own colour, linear.
  - UV.x is a stem or leaf shade. UV.y is the bend fraction (0 at the root, 1 at the tallest neck); every vertex of a head takes its neck's value.
  - UV2.x is the part: stem 0, leaf 1, disc 2, petal 3, puff 4. UV2.y is 1 where the vertex nods with its head.
  - CUSTOM0.xyz is the offset from the head's neck, which is the nod pivot. CUSTOM0.w is the fraction out from the head's centre.
- **Mass normals are baked in.** Each head vertex's normal points out from a dome centre set 0.7–1.2 head radii behind the face. A spike's normals point out from its axis. Stems and leaves face up and out. The material does not flip normals on back faces, so a petal seen from below shades as part of the head.
- **Shader** (`flower_heads` in `shaders/reference_surface.gdshader`, helpers in `shaders/meadow_flower.gdshaderinc`):
  - Stems and leaves take the family's living green (`zs_grass_living`, as the tufts do) times `flower_stem_shade` 0.8. A muted family cannot turn them to straw.
  - Petals keep their own colour, pulled only 12% toward the family's grass ratio (`flower_palette_pull`), clamped, at unit luminance.
  - Kinds with variants pick a petal colour per plant from `flower_variants` (up to four), by a hash of the root.
  - Backlit glow (`zs_flower_translucency`, a new `ZS_FLOWER_TRANSLUCENCY` block in `reference_direct_light.gdshaderinc`) is the petal's own colour, warmed slightly. It is strongest when looking toward the sun and when the light is behind the head's mass. Parts take shares of it: petals 0.9, the seed puff 1, leaves 0.45, discs 0.3, stems 0.12.
  - The seed clock also gets a soft sky glow of its own (`ZS_FLOWER_PUFF_LIGHT` 0.45).
  - Buttercup petals are glossy (`flower_roughness` 0.34).
  - Flowers keep half the contact darkening (`flower_contact`).
- **Motion** (on top of the shared breeze, `docs/scenic/breeze.md`; one `if (flower_heads)` block inside the sway section; no global wind or wave constant is touched):
  - Stems bend on `zs_breeze_offset` (stiff root, lagging and swaying tip, the meadow's crests for plants under about 1.8 m), taking `mix(0.5, 1, flower_motion.x)` of it. Every head vertex is evaluated at its neck (`VERTEX - CUSTOM0.xyz`), so the head rides the stem whole.
  - The shader's other bend weight (tread, wet droop, local wind, paling) is `UV.y ^ flower_bend` (1.6), so stems give most toward the head.
  - Heads lag: each nods by the breeze's lean read `flower_motion.y` metres of air travel behind its root (`zs_breeze_lean_at`), downwind about its neck, `flower_motion.z` radians per 0.6 lean, plus a slow bob scaled by `zs_breeze`.
  - Petal tips flutter by `flower_motion.w` metres, harder in the breeze's `gust`.
  - Gusts, the wind tool, tread, wet droop and local wind still act through the shared code.
- **Varyings:** none added. The surface shader stays at 14 declared varyings, under Metal's limit (see 4b6508e). Flowers reuse `grass_along` for their glow share, and rewrite COLOR and NORMAL in `vertex()`.

## Kinds

Catalog keys, heights at scale 1 (to the top of the tallest head) and triangle counts:

| Key | Height | Tris | Reads as |
|---|---|---|---|
| `oxeye_daisy` | 0.57 m | 324 | 15 white rays round a raised gold disc; two heads; toothed rosette |
| `buttercup` | 0.38 m | 333 | three glossy five-petal gold cups on a forked stem; three-lobed leaves |
| `dandelion` | 0.26 m | 365 | gold pompom of three rising floret rings; long toothed rosette |
| `dandelion_clock` | 0.45 m | 202 | soft core inside a halo of 42 seed parachutes; glows |
| `cosmos` | 0.94 m | 448 | 8 broad notched petals, pink, magenta, white or pale pink; wiry stem, thread leaves, a bud |
| `sunflower` | 1.83 m | 430 | stem hooks over so the 34 cm head droops; dark disc, two petal rings, broad heart leaves |
| `poppy` | 0.63 m | 244 | four broad petals with dark basal blotch, red to orange; nodding bud |
| `lupine` | 0.85 m | 507 | spike of 11 whorls of pea florets, violet, purple, pink or white; palmate leaves |

For scale, the painterly tuft's tallest blade is 0.44 m and the source tuft is 0.42 m. Buttercups and dandelions sit among the tufts, daisies and poppies top them, cosmos and lupines stand well clear, and sunflowers tower.

## Registration and saves

- The kinds are in `NativeAssetCatalog.PARTS` (one part each, `meadow-flower-<kind>`, made by `source_node`; the pose is identity so a plant stands on its root). They are also in `NativeTerrainData.ASSETS` (appended), `NativeDropReactions` (sprout), `FireField.FAST_ASSETS`, `HandReach.PLUCK_UNDERGROWTH`, `PathBrush.UNDERGROWTH`, `LifeSurvey.SHRUBS` and `FLOWERS` (butterflies visit), the build palette's `FOLIAGE`, and trail planting.
- `GardenView` needs no change: each kind gets its own MultiMesh batch on its own material. The part keys contain "flower", so winter takes them; the palette role is 0, so petals keep their hue.
- An instance tint multiplies petals and discs, never stems or leaves. For natural colours, place without a tint.
- **Old worlds are untouched.** `NativeFlora.FLOWER_KINDS`, emergence and the hand materials still place the four old forms, which draw exactly as before.
- **Opt-in remap** (`--meadow-flowers`): only the drawing changes; records, saves and digests do not.
  - Old forms draw as kit kinds: daisy as oxeye daisy, button as buttercup, spike as lupine, umbel as dandelion clock.
  - The painted meadow's flowers bloom as drifts, one kind per 5×5 cells, at 0.8 scale, without sunflowers.

## Cost

This is an estimate; nothing has been measured. Plants are 200–510 triangles, against 150 for the old flower, which is two batches. A meadow of 1,000 kit flowers is about 0.35 M triangles in about eight batches, with shadows on. If that costs too much, the first levers are the dandelion's three floret rings, the lupine's whorls (11) and the daisy's two heads.

## Checks

- `tests/test_meadow_flowers.gd` (headless) checks:
  - mesh validity: indexed, indices in range, all vertex arrays present, unit normals;
  - per-kind height bands and the order against the tuft;
  - parts present, a nodding head on a still root;
  - variants and gloss;
  - registration in every table;
  - place, save, reopen and draw on its own batch;
  - the old forms drawing as before without the flag, and as kit kinds with it;
  - drift coherence;
  - the shader keeping its varying count.
- `tools/probe_meadow_flowers.gd` prints each kind's size and triangle count.
- `tools/still_meadow_flowers.gd` (rendered) places a drift of each kind among grass tufts. It takes close, backlit, sunflower, mid and diorama stills into `captures/flowers/`. `--wind=1.4` holds a strong breeze, and `--chalk` applies the Chalk & turquoise grass ratio.

## Seen on screen, and not

Rendered stills (Forward+, macOS) showed the shader compiling and every kind reading as itself at 3 m and 9 m:

- cosmos come in mixed pinks;
- buttercups catch a highlight;
- sunflower heads droop and face the camera;
- under Chalk & turquoise, petals keep their hue and stems stay green while the classic tufts go to straw;
- under `--wind=1.4`, heads tilt downwind and stay on their stems.

At 23 m a small test patch reads as specks of pink, white, gold and red. A full meadow's drift has not been seen.

Not verified:

- the motion over time (only stills were taken);
- the backlit glow looking straight into the sun;
- cost;
- the `--meadow-flowers` remap on a real generated world.
