# Endless spruces: the plastic look, two approaches

The ask (2026-10-26): the spruces look plasticky and a little blue next to
the rest of the land. The woods' motion and the far sprites are already done
on this branch (`docs/design/endless-flight/tree-alive-handoff.md`). This
doc lays out two ways to tackle the plastic look, for the user to choose
between:

- **A, realistic needles:** needle detail, light through the needles,
  self-shadowing.
- **B, painterly with depth and light:** large value shapes, a warm/cool
  light split, a glowing rim.

Both share some groundwork (below). Neither is started.

## What reads as plastic now

From stills and the code (default look: `--spruce=sprays`, texture b):

1. **Little value inside a crown.**
   - The bake's dark-at-the-trunk to light-at-the-tips is pulled toward its
     mean by `flat` 1.6 (`SPRUCE_B` in `scripts/hero_trees.gd`, applied in
     `zs_spruce_paint`, `shaders/spruce_paint.gdshaderinc`).
   - The light normal bends 70 % toward a smooth volume (`round` 0.7), and
     the sun's steps are soft (`steps` 0.25).
   - So each tier reads as one smooth moulded shape.
2. **Smooth at mid range.** Texture b's micro-facets fade out from 40 to
   110 m (`reference_surface.gdshader` around lines 895 and 1022), and the
   bake and blue ease to the mean over 40 to 160 m (`away` in
   `zs_spruce_paint`). Past about 100 m a crown is an even, clean colour.
3. **No light through the needles.**
   - `foliage_transmission` is declared in `reference_surface` (line 120)
     but nothing reads it.
   - The crowns get a wrapped "glow" (`glow` 0.35) and the backlight
     include's silhouette rim (`ZS_BACKLIGHT_SPRUCE` 3.0).
   - Nothing makes the boughs themselves light up against the sun.
4. **One colour everywhere.**
   - Every tree takes the glaucous blue (`blue` 1.0, `SPRUCE_GLAUCOUS`,
     0.62x to 1.12x per tree).
   - The shade is olive and the lit side blue-green (round 4): the light is
     cool and the shade warm, the reverse of the land's light.
5. **Milky mid-distance.** Trees at 100 to 300 m wash toward the haze, so
   they lose value against the meadow.

## History to respect

These came from the user, in `docs/design/endless-flight/spruce-sprays-handoff.md`
and memory:

- **Round 2 asked for "bluer".** The glaucous tint is wanted. Keep blue
  spruces; vary how many and how blue.
- **Round 3 said "too much contrast, a little too dark".** That is where
  `flat`, `fill` and `floor` come from. Bring depth back without lowering
  the crown's mean value: dark the gaps and undersides, lift the lit tips.
  Check V p50 and the darkest tenth against round 4's table (V p50 about
  0.48 close, 0.45 dense).
- **The clean look lost an A/B (memory, 2026-10-26).** "Before had way
  more depth." Keep detail that shrinks with distance rather than smoothing
  it away, and A/B before merging.
- **The user judges by playing.** Every change goes behind one flag, with
  the current look one flag away.

## Shared groundwork (either approach)

- **One flag.** `--spruce-look=a` or `=b`; the current look is the
  default until the user picks. Use `SPRUCE_PAINT`-style knob sets in
  `scripts/hero_trees.gd` (`spruce_paint_knobs()` already merges named
  sets, as `--spruce-look=r3` does).
- **The sprites must follow.**
  - `scripts/endless/spruce_sprites.gd` bakes the crown's albedo through
    its own material (unshaded) and a light normal (its own bake shader).
  - `shaders/endless_spruce_sprite.gdshader` re-lights them with a copy of
    the crown's light (`sun`, `tone`, backlight).
  - Anything changed in the crown's light (transmission, the warm/cool
    split, the rim) must be mirrored in the sprite's `light()`, or the
    200 m hand-over shows a seam. Albedo changes come through the bake on
    their own.
  - So does `shaders/endless_forest_floor.gdshader`'s painted canopy past
    1.44 km (its `canopy_colour` is the sprites' mean).
- **Variety per tree and per grove.**
  - Most trees green, a share blue, hashed from the foot as `rank` is
    (`zs_spruce_tree_rank`), with groves sharing a lean.
  - Within a crown, older inner needles darker and olive, fresh tips
    lighter.
- **Haze on the trees.** Ease the trees' haze at 100 to 300 m (a share of
  the fog on the crowns and sprites, or a value lift against it) so a wood
  keeps its silhouette against the meadow.
- **Views** (`tools/harness/look_views.gd`, which now steps the trees):
  - `spruce_near`, a lone meadow spruce about 25 m off;
  - `wood`, a wood 150 to 600 m off from 60 m up;
  - `forest`, `cruise`, and `sun_toward_low` / `sun_away_low` for the
    backlight.
  - `python tools/drive.py tools/harness/look_views.gd --rendered -- --views=spruce_near,wood,sun_toward_low --out=DIR --tag=_a --time=240 --scene-args --no-title --spruce-look=a`
- **Measure.** `python tools/look_measure.py before.png after.png --crop ...`
  gives V p50, the darkest tenth, the lit/shaded ratio, blotch and shade
  hue. Compare them with the round 4 table.

## Approach A: realistic needles

The goal is a crown that reads as many needles, with real self-shadowing
and light coming through.

1. **Self-shadowing (ambient occlusion by depth into the crown).** Darken
   each point by:
   - how far in it is from the tier's outer cone (`length(vertex.xz)` over
     the tier's reach at its height);
   - how far under the tier above it (the bake's 0.42 core is a start).

   Undersides and the core go dark, the outer tips stay lit. Lower `flat`
   toward 1.0 or below, and lift the tips (`spruce_value`) so the mean
   holds.
2. **Needle detail that lasts.**
   - A tiling needle texture (albedo grain and a normal of needle rows) in
     the sprays glb's bough-space UVs (`UV`/`UV2`, round 5).
   - Its mips fade to their own mean, so it shrinks with distance instead
     of being cut at 110 m.
   - The texture is authored in Blender or procedurally and baked once.
3. **Translucency.**
   - Put `foliage_transmission` to work in the crown's `light()`
     (`reference_direct_light.gdshaderinc`): light from behind, through
     thin needle edges (the bake's light tips, the sawtooth teeth), tinted
     warm yellow-green.
   - Strongest where the bough is thin and toward the sun.
   - Mirror it in the sprite's `light()`.
4. **A faint waxy sheen** on the blue trees only. The glaucous bloom is a
   wax, so add a broad, low specular (roughness about 0.6, small F0) on the
   lit side. Risk: specular is the most "plastic" thing there is. Keep it
   off by default and A/B it on its own.
5. **Geometry (optional, a model change).**
   - An alpha-tested needle fringe card along each near bough's edge, so
     the outline breaks into needles within 80 m.
   - Assess `docs/art/model-budget.md` first and list which tricks apply;
     the full crown is about 4,100 triangles a tree, and about 11k near
     trees draw.

**Cost (estimate).** Steps 1 to 3 add +0.5 to 1.5 ms at cruise: texture
reads on every near and far crown pixel, plus the transmission term. Step 5
is more and needs its own measurement. The near crowns are about 11k
trees, so measure in the `forest` and `wood` views.

**Risk.** Detailed needles next to the painted land may stand out as the
one realistic thing in a painted world. Judge it in `cruise` and `wood`,
not only up close.

## Approach B: painterly with depth and light

The goal is a crown that reads as a few big painted shapes: a lit top on
each tier, a dark band under its skirt, a warm glowing edge against the
sun.

1. **Tier value shapes.**
   - Light on each tier's upper sunward slope and a dark band under each
     tier's skirt (the underside, `spruce_under`, and the tier's lower
     edge).
   - Edges a little crisp, as the land's painted light is (the carved
     rock's three-step ramp), but steps across the tier, not down the
     tree (round 4's vertical split came from steps over the round normal).
   - Hold the mean value: darker bands, lighter tops.
2. **Warm light, cool shade.**
   - Try the land's split: the lit side warm (yellow-green), the shade
     cool (blue-green, where the glaucous blue lives).
   - That reverses round 4's olive shade, so put it behind its own knob and
     A/B it against round 4. The user picked olive there to match the
     world's shadow hue (66 to 100), so check the shade hue measure.
3. **A glowing rim against the sun.**
   - Strengthen the backlight on the crown's silhouette and the tips
     (`ZS_BACKLIGHT_SPRUCE`, the backlight include), warm and saturated
     rather than white.
   - Mirror it in the sprites' `BACKLIGHT_GAIN` and `edge`.
4. **Dabs that shrink with distance.**
   - Keep a painted break-up in place of texture b's facets past 110 m: a
     world-space dab anchored to the tree whose size grows with distance,
     so a dab stays a few pixels wide.
   - The ground's `ep_patch` / `ep_fade` (`shaders/endless_patch.gdshaderinc`)
     already does this for the land.
5. **Variety from the shared groundwork,** with the blue spruces as an
   accent: a share of trees, or whole groves.

**Cost (estimate).** +0.2 to 0.6 ms at cruise. It is light maths only, no
new textures; the tier bands come from the vertex height and the bake.

**Risk.** Painterly can go flat again if the bands are too soft. Hold the
lit/shaded ratio near round 4's (about 1.8 close, 2.2 dense) or above, not
below.

## How a round proves it

- Stills before and after from the views above, in a sheet, judged by eye
  first, then `look_measure.py` against the round 4 table.
- Frame time from `look_views.gd --time=240` in `forest`, `wood` and
  `cruise`, the current look against the new one, run twice.
- The smoke check passes, and there are no shader errors in a rendered run.
- The 200 m hand-over: the `wood` view with `--spruce-far=` moved, so no
  seam shows between crown and sprite.
- A short note added to this file, with the flag and the knobs.

## Picking

- **Approach A** costs more frame time and maybe a model change, and risks
  standing out from the painted land.
- **Approach B** is cheaper and stays in the land's language, but leans on
  tuning.

Both can share the groundwork: variety, haze, translucency or the rim. One
way to start is with the groundwork alone; it may take a good share of the
plastic out before either approach.
