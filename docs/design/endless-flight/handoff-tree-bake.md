# Handoff: a light bake for the sprays spruces (2026-11-25)

Prototype round. No committed tests.

## What was baked and how

`tools/blender_trees/spruce_sprays.py` now ray-casts a light bake per vertex
(`light_bake`, about 12 s for the whole family in bpy, mathutils BVH):

- **Sky occlusion.** 64 directions over the whole sphere (the sheets take light
  on both sides), weighted toward the sky (straight down weighs 0.25 of
  straight up). A ray counts as open when nothing in the tree's crown or trunk
  lies within `REACH` 1.4 model units.
- **Thickness.** Along the same rays, how many sheets lie between the vertex
  and the open air (up to 4). `thin` is 1 on a lone bough tip with air past it
  and goes toward 0 deep in the crown.
- The near and faceted ("b") crowns are cast against themselves. The far, mid
  and low crowns are cast against the near crown, the tree they stand in for.
- `baked_value` turns these into the grey:
  `light = 0.7 * sky/0.75 + 0.3 * thin`, then `0.34 + 0.76 * light^0.8`. That
  is mixed 0.8 over the old hand-set ramp, which keeps the tiers getting lighter
  up the crown and each bough's own value.
- Each crown is then shifted so its openness-weighted mean (a stand-in for what
  the eye sees) equals the ramp's. Tone and the LOD hand-overs stay; the bake
  moves light from the hidden depths out to the open tips.
- The knobs are in `BAKE` at the top of the script. `-- --dump FILE` writes the
  raw per-vertex values as JSON and exits without exporting.

Vertex counts are unchanged (checked in the GLB accessors), and so is the
format: COLOR_0 VEC4 u16.

## Channel contract

- **COLOR.rgb**: the grey bake, the same meaning as before. Shaders read it as
  `luma(COLOR) / luma(instance tint)`: about 0.35–0.45 in the dense core,
  about 0.55 at a bough's root, 1.0 at the open tips (export clamps at 1).
  Unchanged readers: `spruce_paint.gdshaderinc`, `spruce_variety` and
  `spruce_tiers` zones, `endless_spruce_ring`, the sprite bake and the sprite
  shader.
- **COLOR.a (new)**: thinness, 0..1. It was 1.0 before and no spruce path read
  it. `reference_surface.gdshader` sets the existing `spruce_tip` varying from
  it, as `smoothstep(0.35, 0.85, COLOR.a)`, for every sprays look. Before, it
  was the grey's tip share and was set only under look g/b. That varying feeds
  the rim's tip share, as before, and now also the glow through the crown in
  `reference_direct_light.gdshaderinc`, which is multiplied by `(0.6 + 0.8 * tip)`.
  No new varying, uniform, texture sample or pass.
- **Not changed**: the ring shader (rings are off with the default sprites)
  and the sprites, which still read only the grey. `endless_tree_far.gdshader`
  draws FarTrees' faceted family crown (`spruce.py`), which I did not bake.
- **One knob changed**: `SPRUCE_G.flat` went from 1.0 to 0.5 in
  `scripts/hero_trees.gd`. The shader's flattening of the bake within 40 m was
  cancelling most of the new dark depths. `--spruce-flat=1.0` brings the old
  value back.

## Stills (in this worktree's scratch/, git-ignored)

Side-by-side sheets, before on the left and after on the right, clock fixed:
- `scratch/bake_compare/h11_*.png` (hour 11: forest, spruce_near, wood,
  spruce_close, spruce_rim)
- `scratch/bake_compare/h175_*.png` (hour 17.5, a low sun: forest,
  spruce_close, spruce_rim)
- `scratch/bake_compare/distance_side.png`: the lone spruce from 40, 100, 190
  and 230 m, lens narrowed, pairs old and new, across the crown-to-sprite
  hand-over.
- The raw stills are in `scratch/final_before/` and `scratch/final_after/`.

What I saw:
- Close up, the crown is now dark between the tiers and under the boughs, and
  the bough tips are light.
- Backlit (spruce_rim), the body is darker and the thin tips glow; it is dark
  green, not black.
- At 100–300 m the change is small. I saw no new seam at 80 m or at the 200 m
  sprite hand-over. That hand-over already had a value step before this
  change, and it is unchanged.
- From high above, the far crowns' open tops read a touch lighter than before.

## Frame time at `forest` (median ms, 1440x900, rendered)

| run | old | new |
|---|---|---|
| 1 | 49.18 | 49.15 |
| 2 | 49.33 | 49.92 |
| 3 | 49.05 | 49.33 |

The difference is within noise. At spruce_close: old 32.46–32.56 ms, new
32.62–32.74 ms.

## Checks

- Smoke check passed: `tools/smoke.py studies/endless_flight.tscn`, 0 errors.
- Existing tests: none reads the spruce bake. Only `test_landform_forest` and
  `test_sky_swap` mention spruces, and neither touches vertex colours or these
  shaders. I did not run the full suite.

## Next

- Bake the faceted family crown (`spruce.py`) the same way. It is still used
  for the near trees' shadow casters and under `--spruce-sprites=0`.
- If the rings come back, give them the thinness too (they would need a
  varying).
- The sprites' atlas is drawn at 400 m, where the shader eases the bake to its
  mean, so the dark depths don't reach the sprites. Baking the atlas nearer, or
  without that easing, would carry the depth past 200 m.
- Noted, not done (out of scope): per-tree colour variation, darker ground
  under the trees.
