# Wheat: a paintable crop

Branch `feature/wheat`, from `main`. Wheat is a new specimen in the tray. You paint it like the flowers. It comes up in dense, slightly rowed patches that read as a small farm field, not a scatter. The field sways with the wind as one mass, and it follows the year if the world clock runs.

Style rule: plants have a faceted shape and soft light. Wheat has golden straws, faceted ears and mass normals, so each ear shades as one spindle.

## How it plays

- **Tray.** "Wheat · Field" sits after the sunflower in the seed group (`scripts/materials_tray.gd`). It is also in the command palette.
- **Paint.** With wheat in hand, press and drag over the land. The brush is the flowers' brush (`scripts/flower_paint.gd`): passes, lingering and taps work the same way, and the pips size it. The ground still decides: no wheat on water, rock, snow, steep ground, under trees or on stones.
- **Shift** thins under the brush, as it does for flowers. Wheat counts as a flower to the thinning (`FlowerPaint.is_flower`), so a Shift pass with any flower or wheat in hand thins both.
- **Cmd+Z** undoes one stroke whole, because each stroke is one undo step.
- **Shift-press** plucks a single clump (`PLUCK_UNDERGROWTH`). The trash can sweeps wheat as small stuff, so Shift does not spare it.
- **Save and load.** Each clump is an ordinary object record (`"asset": "wheat"`), so a world saves and reopens with its wheat.

## Design

- **A slot, not a meadow type.** `FlowerSowing.SLOTS.wheat` composes on the sunflower type's drift. It overrides the flowers (wheat only, no companions), the sizes, and the rows (`drift` is merged over the type's). Wheat is not a New-world meadow, and it does not spread by pollen (`dandelion_seeds.gd` BLOOMS leaves it out, since wheat is wind-pollinated).
- **Rows.** `rows` is `{spacing 0.5, width 0.3, square, waver 0.06}`:
  - Rows are 0.5 m apart, and clumps stand on a 0.3 m band with a 0.2 m furrow between bands.
  - `square` turns the rows to run along the plate's x or z axis, picked per world. This needed a small hook in `FlowerSowing._init`.
  - `waver` (a new key in `MeadowTypes.on_row`, default 0.25 as before) bends the rows only 6 cm, so they look tidy but hand-sown.
  - Packing keeps every candidate in a row, because the head is narrow.
- **One record is one clump** (`MeadowFlowerMesh.wheat`):
  - Five straws from one root, each a three-sided stalk bowing out.
  - Each straw ends in a flattened four-sided ear. Its rings turn half a facet each, so the ear's outline zigzags kernel by kernel.
  - Three short awns sit at each tip, and two slim blades grow low down. The awns and blades are detail that the far field drops.
  - A clump is 277 triangles, in line with the other kinds (184–384), and stands about 1 m tall.
- **Instancing.** Wheat is a kit kind: the catalog part is `meadow-flower-wheat`, and GardenView gives it one MultiMesh batch per kind, as for every flower. The paint preview draws a stroke as you paint it, without a refresh. Distance thinning keeps 70% of clumps (`FAR_KEEP`), and detail drops from 15–20 m. Wheat casts no shadows, for cost (`SHADOW_KINDS`).
- **Wind.** Wheat uses the flower material's motion, with `flower_motion.x` set to 1. The straws take the whole of the grass's rolling breeze wave, so a field leans and rights itself as one mass. The ears lag 1 m upwind and nod about their necks.
- **Seasons** (the `flower_ripen` path in `shaders/reference_surface.gdshader`, read against the `zs_season` global):
  - Straw and ears keep the mesh's own gold, instead of the living green that other stems take.
  - The spring bloom (`zs_season.x`) greens the wheat.
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
- the rows
- Shift thinning and its undo
- one-step undo
- save and load
- the pluck and the trash can, each with its undo
- that every clump in a field-scale patch is one instance in the wheat batch

`tests/test_meadow_flowers.gd` covers the mesh and its registration. `tests/test_hand_flowers.gd` covers the tray order.

**Not verified headless:** how the field looks. That covers its colour in each season, the ripen and stubble shader path, the sway as a mass, the backlit glow, and the frame cost of a large field on a GPU. The dummy renderer only parses the shader (`tools/check_shaders.gd`).
