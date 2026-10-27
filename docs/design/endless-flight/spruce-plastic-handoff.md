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

## Round 1: groundwork (`--spruce-look=g`)

Built 2026-10-26. The shared groundwork only (variety, haze, rim); neither
approach A nor B is started. With no flag the game is unchanged: every new
uniform is 0 and every new branch is gated on it.

**Flag and knobs** (`HeroTrees.SPRUCE_G`; each is also `--spruce-<knob>=X`,
only with look g; 0 turns that part off):

| knob | default | what |
|---|---|---|
| `bshare` | 0.3 | share of blue spruces over the land |
| `bgrove` | 160 | grove scale (m); a world-space noise, so a patch shares a lean |
| `blean` | 0.5 | how far a grove moves the share (0 none; 1 about a whole grove one colour) |
| `bgreen` | 0.1 | the blue a green tree keeps (times the `blue` knob) |
| `inner` | 0.9 | older inner needles darker and olive (from the bake's grey) |
| `fresh` | 0.9 | fresh outer tips lighter, yellow-green |
| `flat` | 1.0 | the bake's flattening (the default look's 1.6 cancelled `inner` and `fresh`) |
| `haze` | 0.6 | a wood keeps its outline: saturation up (to +27 %), 4 % darker, 80 to 300 m, easing past 900 m |
| `rim` | 5.0 | silhouette glow gain (the default look's is 3.0) |
| `rimwarm` | 0.7 | share of its hue that is saturated yellow-green (else the sun's) |
| `rimday` | 0.3 | floor for the glow by day (`zs_backlight` is 0 above sun height 0.42) |
| `rimtip` | 0.5 | the fresh tips' share of the glow |

**How it is built**
- `shaders/spruce_variety.gdshaderinc` (new, no dependencies): the foot hash,
  the grove noise, `zs_sv_blue_k` (a green tree's own little blue, a blue
  tree's 0.62 to 1.12 by rank), `zs_sv_needles` (inner and fresh),
  `zs_sv_keep` (the haze term). The near and far crowns (`zs_spruce_paint`,
  new args `gv` and `gt`), the rings and the sprites all include it, so all
  agree on which trees are blue.
- Uniforms `spruce_var`, `spruce_g`, `spruce_rim` (vec4s) in
  `reference_surface`, the ring and the sprite shaders;
  `HeroTrees.spruce_g_uniforms(knobs)` fills them.
- Sprites: the atlas is baked at one mid blue strength (`G_BAKE_BLUE` 0.5,
  forced through `spruce_g.w`) with `inner` and `fresh` baked in; the sprite
  shader shifts each tree to its own blueness by the ratio of the two
  glaucous mixes, then applies `haze` and the warm rim (`spruce_rim`; the
  fresh-tip share is read from the atlas albedo against `mean_luma`).
- Rim: `backlight.gdshaderinc` gets `zs_backlight_amount_floor` and
  `zs_backlight_tint_warm`; `reference_direct_light.gdshaderinc`'s spruce
  block takes the g path when `spruce_rim.x > 0`; `ZS_BACKLIGHT_SPRUCE` is now
  `spruce_rim.x` or 3.0; the tip share reaches `light()` through
  `varying spruce_tip`.

**Findings**
- **The engine's fog is not the milky look.** Depth fog is `begin` 120 m,
  `end` 7.6 km (15.2 km on a high-end GPU) over a 0.75 curve; toggling
  `environment.fog_enabled` on the `wood` view moved the trees by a few
  levels at most. It is under 1 % at 100 to 300 m. The grey-blue at mid range
  is the crowns' own colour (blue mix, bake eased to the mean, facets gone).
  So `haze` is a colour term (`zs_sv_keep`), not a share of the fog. A true
  fog share needs `fog_disabled` and the fog's colour as a global (the
  `fog()` function can, as far as I know, only add fog). The land's and the
  sky's fog are untouched.
- **`sprites.mean` was never measured**: the 1 x 1 `resize` of the atlas row
  returns an empty pixel, so `canopy_colour` stays at the `mean` fallback
  (0.08, 0.12, 0.09). Under g it is measured by a strided sum, (0.060, 0.121,
  0.068), luma 0.104 against 0.109, so the painted canopy past 1.44 km stays
  matched in value and is a little greener. The default look keeps the
  fallback unchanged.
- **The seam check.** `wood` with `--spruce-far=` 60, 150, 250 and 400 for g
  (and 60, 400 for the default) shows no visible seam; the mid band's mean
  colour agrees to within 2 levels between sprites and crowns (g:
  112/132/57 against 112/130/56).

**Measures** (the same crop before and after; the stills run on a running
day cycle, so compare only runs with the same view order and `--time`):

| crop (of the still) | measure | before | g |
|---|---|---|---|
| close (`spruce_near` 0.44,0.5,0.52,0.6) | V p50 | 0.435 | 0.439 |
| | darkest tenth V | 0.274 | 0.255 |
| | lit/shaded | 2.46 | 2.79 |
| | S p50 | 0.372 | 0.532 |
| | shade hue | 102 | 95 |
| dense (`forest` 0.82,0.62,0.97,0.98) | V p50 | 0.404 | 0.396 |
| | darkest tenth V | 0.206 | 0.200 |
| | lit/shaded | 3.54 | 3.68 |
| wood (`wood` 0.2,0.44,0.5,0.56, with meadow) | V p50 | 0.510 | 0.518 |
| | darkest tenth V | 0.249 | 0.251 |
| | lit/shaded | 3.05 | 3.14 |
| | S p50 | 0.492 | 0.603 |

V p50 is held, the darkest tenth about held, lit/shaded up a little (round 4
asked for at least 1.8 close and 2.2 dense). Saturation is the big move: the
greens are greener and the blues fewer.

**Frame time** (`look_views.gd --time=240`, GPU ms, two runs each, default
then g):

| view | default | g |
|---|---|---|
| forest | 8.57, 8.48 | 8.53, 8.58 |
| wood | 7.56, 7.47 | 7.71, 7.59 |
| cruise | 7.92, 7.90 | 7.86, 7.97 |

Inside the noise (up to +0.1 ms on `wood`). The sprite atlas bake is the same
size.

**Files:** `scripts/hero_trees.gd` (SPRUCE_G, a two-pass flag parse,
`spruce_g_uniforms`), `scripts/endless/land_trees.gd` (rings),
`scripts/endless/spruce_sprites.gd` (bake at a fixed blue, mean, uniforms),
`shaders/spruce_variety.gdshaderinc` (new), `spruce_paint.gdshaderinc`,
`reference_surface.gdshader`, `reference_direct_light.gdshaderinc`,
`backlight.gdshaderinc`, `endless_spruce_ring.gdshader`,
`endless_spruce_sprite.gdshader`.

**Stills:** `scratch/spruce-look/before/*_before.png` (the baseline for this
round and the next; keep it) and `scratch/spruce-look/g/*_g.png`; views
`spruce_near, wood, sun_toward_low, sun_away_low, cruise, forest`.

**Tests:** none of the committed tests read the changed code.
`test_landform_forest.gd` fails on a triangle budget ("trees draw at most
1,200,000 triangles near (7,773,402)"), which is geometry this round does not
touch. `test_sky_swap.gd` passes.

**Left rough**
- Near trees are still smooth-ish up close: `inner` and `fresh` add
  tier-scale depth, not needle-scale detail (approach A) or crisp tier bands
  (B).
- A wood of one grove can show no blue at all (that is `blean`). Blue
  strength still eases at range as before (x0.55 past 160 m), so far blue
  trees are paler.
- I judged the rim on `sun_toward_low`, where the sun is high, so it shows
  through `rimday`; check it at dusk with `--hour=17.5`.
- The sprite's per-tree blue is a ratio from the crown tint's hue (the
  instance tint, not the palette-resolved colour), so it is approximate.
- The user's earlier "bluer" ask is the `bshare` knob (try 0.5).

**Notes for approach B**
- With `flat` 1.0 the bake's raw grey is visible, so tier value shapes can key
  off `bake_raw` and `spruce_under` in `zs_spruce_paint`. Anything on the
  light side goes in `reference_direct_light.gdshaderinc`'s spruce block and
  its two copies (`endless_spruce_sprite.gdshader` and
  `endless_spruce_ring.gdshader`, both `light()`).
- The sprites' atlas bakes albedo only; a tier band that lives in the crown's
  light has to be re-derived in the sprite from the atlas's light normal.
- The rim's warm hue is `ZS_BACKLIGHT_WARM` in `backlight.gdshaderinc`; B's
  warm/cool split could follow `rimwarm`'s pattern.
- The day cycle runs by default: pass `--hour=` (or `--day=0`) after
  `--scene-args` when two runs must match at any view order.
