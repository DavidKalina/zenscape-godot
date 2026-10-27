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
| `bshare` | 0.5 (was 0.3) | share of blue spruces over the land |
| `bgrove` | 160 | grove scale (m); a world-space noise, so a patch shares a lean |
| `blean` | 0.5 | how far a grove moves the share (0 none; 1 about a whole grove one colour) |
| `bgreen` | 0.8 (was 0.1) | the blue a green tree keeps (times the `blue` knob) |
| `inner` | 0.9 | older inner needles darker and olive (from the bake's grey) |
| `fresh` | 0.9 | fresh outer tips lighter, yellow-green |
| `flat` | 1.0 | the bake's flattening (the default look's 1.6 cancelled `inner` and `fresh`) |
| `haze` | 0.0 (was 0.6) | a wood keeps its outline: saturation up (to +27 %), 4 % darker, 80 to 300 m, easing past 900 m |
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

## Round 2: painterly (`--spruce-look=b`)

Built 2026-10-26. `b` is `g` plus approach B's steps 1 to 4. With no flag
nothing changes (every new uniform is 0 and every branch is gated on it);
`g` is unchanged.

**Knobs** (`HeroTrees.SPRUCE_BL` over `SPRUCE_G`; each `--spruce-<knob>=X`,
only with look b; 0 turns that part off):

| knob | default | what |
|---|---|---|
| `tilt` | 1.8 | the light normal tipped by its place on the tier (up on the sheet's lit slope, down in the shade under a skirt and at the skirt's edge); the painted steps then break across each tier |
| `band` | 1.0 | a cool dark band in the albedo under each skirt (and the tip zone where the face looks down) |
| `top` | 1.0 | a warm lit top on the sheet's slope, in the albedo |
| `coolshade` | 0.25 | the shade's hue from round 4's olive (0) to a cool blue-green (1) |
| `warmlit` | 0.8 | the lit side's warm yellow-green |
| `fardab` | 2.0 | gain of the distance dabs (below) |
| `dabpx` | 5 | a dab's width in pixels, whatever the distance |
| `dabfrom` | 110 | m: the dabs come in from 0.55x to 1.15x of it; eased off past 1.5 km |
| `steps`, `soft` | 0.7, 0.15 | the sun's three painted steps made crisp (the default look's 0.25 and 0.5) |
| `texgain` | 0.55 | texture b's facets, so tier shapes lead up close (1.0 by default) |
| `inner`, `fresh` | 0.6, 0.7 | g's needle terms toned down, since the band and top now carry the bake's value |

**How it is built**
- `shaders/spruce_tiers.gdshaderinc` (new): `zs_st_zones` cuts the generator's
  grey bake into `dark` (under 0.8: the core cone and the inner sheet, the
  shade under the tier above's skirt), `top` (0.8 to 0.93: the lit slope) and
  `skirt` (over 0.93: the tips), the edges short so a step is a step. The
  visible bake is only 0.7 to 1.0, not 0.55 to 1.02 (measured with a threshold
  debug), and carries the tree's own tone (0.86 to 1.04), so the edges move a
  little tree to tree. `far` (0 near, 1 from 200 m) narrows `dark` to the core:
  a distance crown is one skirt from the apex, whose inner half is its lit
  top, not a shade (without it the wood read 0.04 darker in V).
  Also `zs_st_normal` (tilt), `zs_st_paint` (band, top), `zs_st_shade` (olive
  to cool) and `zs_st_dabs`.
- Three copies of the light, kept in step: `reference_direct_light`'s spruce
  block (lit hue toward `ZS_ST_WARM` by `warmlit * t`, and the fill's shade
  colour), `endless_spruce_sprite` and `endless_spruce_ring` `light()`. The
  shade colour also goes through `zs_st_shade` in the surface's emission and
  both `fragment()`s.
- Normals: the surface applies `zs_st_normal` to the volume normal before
  texture b's facets; the ring on its own volume normal; the sprites in the
  atlas (`endless_spruce_sprite_bake` takes `tilt` and `bake_luma` and reads
  `COLOR`). Albedo bands reach the sprites through the atlas on their own (it
  bakes the near material). The ring takes the facing for `under` from the
  mesh's own normal.
- Dabs: a pattern in the tree's own frame (foot-relative, height folded in, a
  per-tree offset), noise at `dabpx` pixels wide, stepped by octaves with the
  two nearest cross-faded so nothing swims. The pixel size comes from the
  projection and the viewport. They are in the near and mid crowns (past
  `dabfrom`), the rings and the sprites; the atlas bake is told to leave them
  out (`spruce_g.w >= 0`) and the sprite paints its own at its own distance,
  on the quad's plane in the tree's frame.
- Uniforms `spruce_tier` (tilt, band, top, coolshade) and `spruce_tier2`
  (warmlit, fardab, dabpx, dabfrom) on the surface, ring and sprite shaders,
  from `HeroTrees.spruce_g_uniforms`.

**Findings**
- Texture b's facets swamp tier shapes up close: tilt and bands alone read as
  a slight darkening until `texgain` came down to 0.55. `flat` 1.0 and g's
  needle terms also fight B (the bake is dark inside and bright at the tips; a
  painted tier wants a lit top and a dark skirt), hence `inner` and `fresh`.
- Dabs at gain 1 were barely visible at 250 to 600 m; at 2 they mottle the
  sprites' crowns without reading as noise; at 3 they are plain. Past about
  1 km they are subpixel.
- The 200 m hand-over (`wood` with `--spruce-far=` 150 and 250): no seam from
  the b look. At 250 a few shadowed crowns read darker than the sprites; the
  same trees do it under `g` (the crown's own shadow, not this round).
- The dusk views fire the scene's white glow blobs (the default look has them
  too). The rim, checked on a backlit `spruce_rim` view at `--hour=17.5`
  against `g` and the default: g's rim (5.0, warm 0.7) holds with B's bands,
  the golden fringe following each tier's skirt over the cool-shaded body.
  Left at g's values.

**Measures** (the same crops as round 1, `--time=240`, same view order; the
last block is `spruce_close`, crop 0.4,0.25,0.6,0.7):

| crop | measure | default | g | b |
|---|---|---|---|---|
| close (`spruce_near`) | V p50 | 0.435 | 0.439 | 0.459 |
| | darkest tenth V | 0.274 | 0.255 | 0.206 |
| | lit/shaded | 2.46 | 2.79 | 3.45 |
| | S p50 | 0.372 | 0.532 | 0.522 |
| | shade hue | 102 | 95 | 105 |
| dense (`forest`) | V p50 | 0.404 | 0.396 | 0.416 |
| | darkest tenth V | 0.206 | 0.200 | 0.161 |
| | lit/shaded | 3.54 | 3.68 | 4.66 |
| wood (`wood`) | V p50 | 0.510 | 0.518 | 0.510 |
| | darkest tenth V | 0.249 | 0.251 | 0.252 |
| | lit/shaded | 3.05 | 3.14 | 3.13 |
| | S p50 | 0.492 | 0.603 | 0.590 |
| `spruce_close` tree | V p50 | 0.475 | 0.482 | 0.510 |
| | darkest tenth V | 0.269 | 0.255 | 0.221 |
| | lit/shaded | 2.73 | 3.01 | 3.51 |
| | shade hue | 104 | 97 | 105 |

The mean value is held (close and dense up 0.02, wood level) and lit/shaded
is well up where the crowns are near. The price is the darkest tenth, 0.05 to
0.04 lower close and dense: the bands are darker by design (round 3 said "too
dark" about the whole crown; the band is only its skirts, but watch it).
`coolshade` 0.25 keeps the shade hue at about g's; 0.4 gave 117 to 123, off the
world's 66 to 100. Wood's lit/shaded is level with g (3.13 against 3.14): out
there the sprites and rings dominate and a band is a few pixels.

**Frame time** (`look_views.gd --time=240`, GPU ms, two runs each):

| view | default | b |
|---|---|---|
| forest | 8.48, 8.49 | 8.59, 8.52 |
| wood | 7.32, 7.55 | 7.53, 7.35 |
| cruise | 7.61, 7.85 | 7.85, 7.64 |

Inside the noise (at most +0.1 ms). The atlas bake is the same size.

**Files:** `shaders/spruce_tiers.gdshaderinc` (+ `.uid`, new),
`spruce_paint.gdshaderinc`, `reference_surface.gdshader`,
`reference_direct_light.gdshaderinc`, `endless_spruce_ring.gdshader`,
`endless_spruce_sprite.gdshader`, `endless_spruce_sprite_bake.gdshader`,
`scripts/hero_trees.gd` (SPRUCE_BL, uniforms), `scripts/endless/spruce_sprites.gd`
(tilt and bake luma to the normal bake), `tools/harness/look_views.gd`
(`spruce_close`: the meadow spruce 7.5 m off, sun across; `spruce_rim`: the
same against the sun).

**Stills:** `scratch/spruce-look/b/*_b.png`, `close/` (default, g, b), `dusk/`
(default and b), `seam/`, and the sheet `scratch/spruce-look/sheet.png` (rows
the six views and a dusk `spruce_close`; columns default, g, b).

**Tests:** none of the committed tests read the changed code. The smoke check
passes for `--spruce-look=b` and for the default; no shader errors in the
rendered runs. The full suite was not run.

**Left rough**
- Tier shapes are cut from the bake, not from true tier geometry, so they
  follow the generator's value ramps and the edges differ a little tree to
  tree. A per-vertex tier phase in the glb (a model change) would give exact
  tops and skirts.
- The facets still dominate at 10 m and under; `texgain` 0.55 is a compromise
  with the "detail that shrinks with distance" ask.
- The sprites bake with `far` = 1 zones and tilt (the atlas is baked at 400 m
  and more), so a crown at 80 to 200 m eases between the two; no seam seen, but
  the crown/sprite pair is only checked at 150 and 250.
- The sprite's dabs live on the billboard plane, so they slide a little as the
  eye circles a tree (a dab is a few pixels at those distances).
- The darkest tenth is lower than `g`'s; `band` 0.6 gives it back at some cost
  to the painted look.
- The dusk set's white blobs (scene-level) cover part of the frame, so the dusk
  look is judged mainly on the backlit view.

## After the first play (2026-10-26)

- The user flew `b`: in the distance the trees looked "way more green". At
  `bshare` 0.3, `bgreen` 0.1 and `haze` 0.6 the far woods turned a saturated
  toy green next to the default's dusty blue-green. `g` and `b` now default to
  `bshare` 0.5, `bgreen` 0.8 and `haze` 0 (`scripts/hero_trees.gd` SPRUCE_G).
  The far woods match the default's hue and read a little deeper. Stills:
  `scratch/spruce-look/r3/` (`--hour=13`), `scratch/spruce-look/far2/` (the
  knob variants).
- The dusk white blobs are the grass, not the trees: they go with `--no-grass`
  and stay with `--no-grass-silver`, `--no-flowers`, `--no-pollen`, `--no-motes`.
  Each is one black pixel in a white halo (an inf/NaN in the blades' shading).
- The dusk blobs are fixed (ef81941d, the grass backlight's `pow` of a value
  a hair below 0 under MSAA).

## Painterly is the default (2026-10-26)

The user played `b` at native 2560x1440 and picked it. `b` is now the look
with no flag (`HeroTrees.SPRUCE_LOOK`); `--spruce-look=old` is the look
before it, and `g`, `r2`, `r3` still pick the others. The knobs
(`--spruce-<knob>=X`) work on the default now, no flag needed. The user saw
a blurry quality with `--taa=1 --screen-aa=smaa` over 8x MSAA; whether TAA
was the cause is not yet confirmed.
