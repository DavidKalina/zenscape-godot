# Wheat: a paintable crop

Branch `feature/wheat`, from `main`; rows and plants reworked on `fix/wheat-rows`. Wheat is a new specimen in the tray. You paint it like the flowers. It comes up in tidy drilled rows with open furrows between them, so a patch reads as a small cultivated field, not a scatter. The field sways with the wind as one mass, and it follows the year if the world clock runs.

Style rule: plants have a faceted shape and soft light. Wheat has golden straws, faceted ears and mass normals, so each ear shades as one spindle.

## How it plays

- **Tray.** "Wheat · Field" sits after the sunflower in the seed group (`scripts/materials_tray.gd`). It is also in the command palette.
- **Paint.** With wheat in hand, press and drag over the land. The brush is the flowers' brush (`scripts/flower_paint.gd`): passes, lingering and taps work the same way, and the pips size it. The ground still decides: no wheat on water, rock, snow, steep ground, under trees or on stones.
- **Shift** thins under the brush, as it does for flowers. Wheat counts as a flower to the thinning (`FlowerPaint.is_flower`), so a Shift pass with any flower or wheat in hand thins both.
- **Cmd+Z** undoes one stroke whole, because each stroke is one undo step.
- **Shift-press** plucks a single clump (`PLUCK_UNDERGROWTH`). The trash can sweeps wheat as small stuff, so Shift does not spare it.
- **Save and load.** Each clump is an ordinary object record (`"asset": "wheat"`), so a world saves and reopens with its wheat.

## Design

- **A slot, not a meadow type.** `FlowerSowing.SLOTS.wheat` composes on the sunflower type's drift. It overrides the flowers (wheat only, no companions), the sizes, and the rows (`drift` is merged over the type's). Wheat is not a New-world meadow, and it does not spread by pollen (`dandelion_seeds.gd` BLOOMS leaves it out, since wheat is wind-pollinated). Everything below is keyed to wheat's own `rows`; sunflowers and the other slots place exactly what they did (the probe holds digests of their records).
- **Rows.** `rows` is `{spacing 0.32, band 0.1, along 0.2, room 0.05, align, square, waver 0.06}`:
  - Rows are 0.32 m apart. `band` (metres, the on-row band's whole width; `MeadowTypes.on_row`) keeps every clump within 5 cm of its row's middle, so a furrow at least 0.22 m wide stays open between rows. In practice the clumps' feet sit within 2 cm of the middle (`BAND_JITTER`), and the clump itself is about 7 cm across.
  - **The row lattice** (`FlowerSowing.cells`, `spot`, `key_of`, `middle`). Wheat's candidates are not the meadow's 0.2 m square lattice filtered by the rows. They stand on the rows themselves, `along` 0.2 m apart down each row (straying a quarter of that either way), following the row's waver. Each candidate is still judged once a stroke against the brush's coat, so one pass comes up as gappy rows and more passes fill them. Other slots keep the square lattice, unchanged.
  - `room` lets clumps stand 5 cm from each other (flowers keep 12 cm), so a second stroke over a first can fill the gaps down a row.
  - `align` turns each clump's long side down its row, within about ±15°, so a row reads as one drilled line (`MeadowTypes.flower`).
  - `square` turns the rows to run along the plate's x or z axis, picked per world (`FlowerSowing._init`).
  - `waver` bends the rows only 6 cm, so they look tidy but hand-sown.
- **One record is one clump** (`MeadowFlowerMesh.wheat`):
  - Six straws in a short line along the clump's x (the row), each a three-sided stalk in two segments, 7.5 mm in radius.
  - Each straw ends in a plump, flattened four-sided ear (`WHEAT_EAR_RADIUS` 2.5 cm, drawn 1.3× as the heads are). Its three rings turn half a facet each, so the ear's outline zigzags kernel by kernel. One short awn sits at each tip, and two slim blades grow low down along the row. The awns and blades are detail that the far field drops.
  - A clump is 234 triangles and about 0.27 m along its row by 0.07 m across. It stands 0.68 m at size 1; the slot's sizes (0.82–0.95) put a field at 0.56–0.64 m, knee-high to a fence: under its posts' tops (0.62 m) on the whole, above its top rail (0.48 m).
  - **Contrast.** Ripe, the ears are pale golden-cream (`e2c27c` at the foot to `f5e4b0` at the tip) over darker warm ochre straw (`a97d3e`, blades `9c7438`). After the material's shading the ears are about 3× the straw's luminance (it was about 1.35× before).
- **Field cost.** The probe's 10 × 8 m stroke is 2,157 clumps, 505k triangles before distance thinning (it was 1,716 clumps and 475k). Painting stays within a frame.
- **Instancing.** Wheat is a kit kind: the catalog part is `meadow-flower-wheat`, and GardenView gives it one MultiMesh batch per kind, as for every flower. The paint preview draws a stroke as you paint it, without a refresh. Distance thinning keeps 70% of clumps (`FAR_KEEP`), and detail drops from 15–20 m. Wheat casts no shadows, for cost (`SHADOW_KINDS`).
- **Wind.** Wheat uses the flower material's motion, with `flower_motion.x` set to 1. The straws take the whole of the grass's rolling breeze wave, so a field leans and rights itself as one mass. The ears lag 1 m upwind and nod about their necks.
- **Seasons** (the `flower_ripen` path in `shaders/reference_surface.gdshader`, read against the `zs_season` global):
  - Straw and ears keep the mesh's own colours, instead of the living green that other stems take.
  - The spring bloom (`zs_season.x`) greens the wheat: the ears a lighter yellow-green (`flower_ripen_green_ear`), the straw a deeper green (`flower_ripen_green_straw`, MeadowFlowerMesh `RIPEN_GREEN_*`). Each is scaled by the vertex's own luminance, so the ears stay about 4× the straw's luminance in spring.
  - Autumn (`.w`) deepens it toward amber.
  - Through the winter dormancy (`.z`), the ears fold onto their necks and the straws are held under 14 cm (`STUBBLE`) as pale straw stubble. The bend is clamped too, so the stubble doesn't wave.
  - As the dormancy eases, the stubble comes back up green.
  - `SceneLook.leaf_season` gives wheat no autumn paint and no die-back.
- **Ground.** A painted patch warms the grass under it slightly toward stubble gold (`FLOWER_KEYS.wheat.wash`), as flower drifts do.

## Known gaps

- **Late-winter flash.** The world clock has no late-winter signal: `zs_season` is all zeros both in summer and in the short stretch between the end of dormancy and the spring bloom (year 0.99–0.02). The wheat therefore turns back to gold briefly before the bloom greens it. The change is gradual, not a pop. With no clock running, `zs_season` is zero and the wheat shows ripe gold.
- **Butterflies.** Wheat is in `life_survey.SHRUBS` but not in `FLOWERS`, so it draws no butterflies.

## Checks

```sh
godot --headless --path . -s res://tools/probe_wheat.gd            # unit and scene
godot --headless --path . -s res://tools/probe_wheat.gd -- --only=unit
```

The probe paints on a flat plate and in the cozy scene through real input. It checks:

- painting
- the rows: every clump on its row's band and none in the furrows, the furrow width, the rows spaced as configured, clumps a metre of row, each clump turned along its row, in both row directions
- the plant: its height band under a fence's posts, the ears' and straws' widths, and the ears' luminance against the straw when ripe, green and in autumn, through a mirror of the shader's `flower_ripen` path that the probe holds to the shader's source
- a field's clump and triangle budget
- that sunflower and wildflower strokes and a sunflower sowing place exactly the records they did before
- Shift thinning and its undo
- one-step undo
- save and load
- the pluck and the trash can, each with its undo
- that every clump in a field-scale patch is one instance in the wheat batch

`tests/test_meadow_flowers.gd` covers the mesh and its registration. `tests/test_hand_flowers.gd` covers the tray order.

**Not verified headless:** how the field looks. That covers whether the rows and furrows read at the diorama camera, its colour in each season as lit, the ripen and stubble shader path as drawn, the sway as a mass, the backlit glow on the ears, and the frame cost of a large field on a GPU. The contrast check is arithmetic on the mesh's colours: lighting, mood and glow multiply ear and straw alike, but the backlit glow adds more to the ears. The dummy renderer only parses the shader (`tools/check_shaders.gd`).
