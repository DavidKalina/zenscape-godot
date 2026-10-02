# Flowers: the meadow flower kit

Branch `worktree-agent-a439b45d63d62a49f`, from `beautification`. The user said the flowers "look really bad... you can't even tell that they're flowers". They asked for meadows of daisies, dandelions (yellow, and the white seed clock), cosmos, sunflowers and buttercups.

The style was settled with the user: shapes are faceted, light is soft. Petals are flat and clearly cut, stems are simple, and each plant has a few leaves. Shading follows the mass of the head, not each triangle. Petals glow when backlit.

## Why the old flowers did not read

- **Four abstract forms.** `button_flower`, `spike_flower`, `umbel_flower` and `daisy_flower` are the reference's geometry: a 0.2 m stem under a head 4 cm deep. The daisy head is 17 cm across but flat, so from the diorama camera (20–26 m, about 2.5 cm a pixel) it is a pale smear a pixel or two high.
- **Per-facet shading.** Their material has `flat_faces` on, so each head breaks into lit and dark shards.
- **One colour per head.** Petals and centre take a single instance tint, so a daisy has no yellow eye.

## What changed

- **Mesh** (`scripts/meadow_flower_mesh.gd`): one procedural plant per kind, built once and indexed. Each has a three- to five-sided stem, folded leaves (lance, broad, heart-shaped or palmate), and heads made of flat petals in rows, a domed disc with a green back, and bracts. Heads are drawn 1.2–1.5× the builders' sizes (`HEAD_SCALE`), so a daisy face is about 15 cm, six pixels at the diorama camera. The grass tufts are stylised the same way.
- **Vertex data**, read by the material:
  - COLOR is the part's own colour, linear.
  - UV.x is a stem or leaf shade. UV.y is the bend fraction (0 at the root, 1 at the tallest neck); every vertex of a head takes its neck's value.
  - UV2.x is the part: stem 0, leaf 1, disc 2, petal 3, puff 4. UV2.y is 1 where the vertex nods with its head, plus 0.25 (`DETAIL`) on the detail a far plant goes without (see Cost).
  - CUSTOM0.xyz is the offset from the head's neck, which is the nod pivot. CUSTOM0.w is the fraction out from the head's centre. On the seed clock it instead names each head vertex's part in the dandelion's round (docs/scenic/dandelions.md).
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

Catalog keys, heights at scale 1 (to the top of the tallest head) and triangle counts (`tools/probe_meadow_flowers.gd`; the first kit's in brackets):

| Key | Height | Tris | Reads as |
|---|---|---|---|
| `oxeye_daisy` | 0.57 m | 240 (324) | 14 white rays round a raised gold disc; two heads; toothed rosette |
| `buttercup` | 0.38 m | 267 (333) | three glossy five-petal gold cups (heads drawn 1.45×) on a forked stem; two fans of three-lobed leaves |
| `dandelion` | 0.26 m | 230 (365) | bright gold pompom of three rising floret rings (heads drawn 1.5×); long toothed rosette |
| `dandelion_clock` | 0.45 m | 286 (202) | soft core inside a halo of 42 seed parachutes; glows. Sheds on the air, stands bare, blooms gold and fluffs out again (docs/scenic/dandelions.md); the gold head is the added triangles, folded away while it stands whole |
| `cosmos` | 0.94 m | 322 (448) | 8 broad notched petals, pink, magenta, cream white or pale pink; wiry stem, thread leaves, a bud |
| `sunflower` | 1.84 m | 384 (430) | stem bends over so the 42 cm head faces up and out toward the sun side; a small brown disc in two long rings of bright gold petals, three heart leaves |
| `poppy` | 0.63 m | 184 (244) | four broad petals with dark basal blotch, red to orange; nodding bud |
| `lupine` | 0.85 m | 272 (507) | spike of 9 whorls of four pea florets, violet, purple, pink or white; three palmate leaves |

For scale, the painterly tuft's tallest blade is 0.44 m and the source tuft is 0.42 m. Buttercups and dandelions sit among the tufts, daisies and poppies top them, cosmos and lupines stand well clear, and sunflowers tower.

## Registration and saves

- The kinds are in `NativeAssetCatalog.PARTS` (one part each, `meadow-flower-<kind>`, made by `source_node`; the pose is identity so a plant stands on its root). They are also in `NativeTerrainData.ASSETS` (appended), `NativeDropReactions` (sprout), `FireField.FAST_ASSETS`, `HandReach.PLUCK_UNDERGROWTH`, `PathBrush.UNDERGROWTH`, `LifeSurvey.SHRUBS` and `FLOWERS` (butterflies visit), the build palette's `FOLIAGE`, and trail planting.
- `GardenView` needs no change: each kind gets its own MultiMesh batch on its own material. The part keys contain "flower", so winter takes them; the palette role is 0, so petals keep their hue.
- An instance tint multiplies petals and discs, never stems or leaves. For natural colours, place without a tint.
- **Old worlds are untouched.** `NativeFlora.FLOWER_KINDS` and emergence in worlds without a meadow type still place the four old forms, which draw exactly as before.
- **Painted by hand.** Since 2026-10-02 the materials bar's flower slots (Wildflower, Dandelion, Poppy, Cosmos, Sunflower) paint the kit's own kinds as drifts under a brush: they come up under it as it is dragged and grow in at once, passes and lingering pack them toward a full drift's core, a tap paints a small dab, Shift-drag thins (docs/scenic/handful.md "Flower seed", scripts/flower_paint.gd, composed by scripts/flower_sowing.gd). They used to scatter the old forms, and for a few hours were sown as a veil the wind carried, which the user found too much work to aim; that veil is kept for pollen from existing plants and pollinators later. Painted flowers draw the frame they are placed through GardenView's paint preview, so a stroke never waits on a rebuild.
- **Opt-in remap** (`--meadow-flowers`): only the drawing changes; records, saves and digests do not.
  - Old forms draw as kit kinds: daisy as oxeye daisy, button as buttercup, spike as lupine, umbel as dandelion clock.
  - The painted meadow's flowers bloom as drifts, one kind per 5×5 cells, at 0.8 scale, without sunflowers.

## Cost

The meadow types put 1,500–4,500 of these plants on a plate. Measured rendered (Forward+, Metal, macOS, 3024×1898 window) with `tools/film_breeze.gd --land=<meadow> --seconds=0 --probe`, which times 120 frames of the meadow view and then the same view with the flower batches hidden. Frame times swing by a third between runs on a busy machine, so the reliable figure is the flowers' own cost: the frame time less the same view without flowers, in one run.

| Land | Before: frame (primitives) | After: frame (primitives) | Flowers' own cost after |
|---|---|---|---|
| canyon (no meadow) | 12.4 ms (0.08 M) | 8.8 ms (0.09 M), same machine state as the row below | none |
| wildflowers | 40.2 ms (4.28 M) | 18.2 ms (2.07 M) | +6.5 ms over 11.7 ms without flowers |
| sunflowers | 15.9 ms (0.90 M) | 12.5 ms (1.13 M) | +3.7 ms |
| dandelions | 27.5 ms (2.63 M) | 14.5 ms (1.34 M) | +5.7 ms |
| cosmos | 24.0 ms (2.67 M) | 14.7 ms (2.35 M) | +5.8 ms |
| alpine meadow | 24.9 ms (2.05 M) | 23.6 ms (1.07 M), in a slower run | +3.9 ms over 19.7 ms without flowers |

The "before" column ran in the machine's slower state (canyon 12.4 ms), the "after" column in a faster one (canyon 8.8 ms), so compare within a column. Primitive counts now include dropped plants, which are drawn as one point each and cost almost nothing.

What the cost was. Probing one meadow showed the flowers' price was the material, not the triangles. The same meshes on a plain material cost +0.5 ms; on the flower material, +8.6 ms. About half of that was the breeze in the vertex stage, about half the rest of the uber-shader, run for every vertex in the depth pre-pass, the main pass and the shadow pass. So the levers are fewer vertices through that shader, not fewer triangles as such:

- **Distance thinning** (`flower_far` in `shaders/reference_surface.gdshader`). From `FAR_START` (14 m) to `FAR_END` (32 m) from the camera a kind keeps down to its `FAR_KEEP` share of its plants (0.6–0.7, sunflowers 0.8). A plant ranked out shrinks into the ground over a short band, so the camera's moves never pop it. The kept heads grow by keep^-`FAR_GROW` (0.5) about their necks, so a drift keeps its cover. The distance is from `zs_camera_position`, so the shadow and reflection passes thin the same plants.
- **A dropped vertex skips the vertex stage.** A shader's `vertex()` cannot return early, so the whole body sits under `if (!flower_gone)`. Before this, dropped plants still cost about two thirds of a drawn one.
- **Far detail** (`flower_lod`). Leaves, bracts, buds and the dandelion's middle floret ring carry `DETAIL` (0.25 added to UV2.y). They shrink away from `LOD_NEAR` (15 m) to `LOD_FAR` (20 m), so a far plant is stems and heads over the painted carpet. Sunflowers keep their leaves (`KEEP_DETAIL`): they are the field's mass.
- **Lighter meshes**, in looks that read the same at 3 m: small kinds' petals are kites (two rows and a tip, `kite_petals`) instead of three rows, thread and leaflet leaves are one row (`SLIM`), buttercup fans are two of three lobes (`LOBE`), buds are plain icosahedra, the daisy has 14 rays, the dandelion 18/13/8 florets, the lupine nine whorls of four florets and three palmate leaves of six. Vertices per plant went from 182–715 to 152–422.
- **Shadows** only from the kinds that stand clear of the grass (`SHADOW_KINDS`: sunflower, cosmos, lupine, poppy, oxeye daisy). Buttercups, dandelions and clocks cast none. **Pond reflections** copy only sunflowers (`REFLECT_KINDS`); copying cosmos and lupines into the wildflower meadow's pond view cost 2.7 ms.
- **The breeze is read once a vertex.** A flower's stem and its head's nod share one `zs_breeze_lean_at` (`zs_breeze_offset_lean` in `reference_wind`), instead of a head vertex reading it twice.

Still to do: the flower fragment stage is the full surface shader (cloud shade, haze, afterglow, inversion), and from the diorama camera thousands of 2–6 px petals pay for it in 2×2 quads. A cheaper far shading path, or per-region MultiMesh batches so far regions draw a real low-detail mesh, are the next levers.

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
