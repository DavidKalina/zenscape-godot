# Endless flight, spruce look: bough sprays

One of three takes on more needle texture for the spruce (the others are
alpha needle cards and spiky tufts). This one is real geometry with no
alpha. Each crown tier is a set of drooping boughs. Each bough is a thin
tented spray whose edges are a sawtooth fringe, so the outline breaks into
many needle tips. The shape, sizes and six variants are the family's.

## Launch

- Mac: `./run-endless-flight.command --spruce=sprays`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title --spruce=sprays`
- Places on seed 1, as in the forests round:
  - a lone tree to walk up to: `--at=-1130,-3600 --heading=180 --alt=40`
    (the tree stands at -1144, -3640);
  - low into the dense wood: `--at=-704,-2700 --heading=0 --alt=8`;
  - cruise over woods by a river: `--at=-700,-1900 --heading=0 --alt=45`.
- Without `--spruce=sprays` the game is unchanged.

## Flags

| Flag | What it does |
|---|---|
| `--spruce=sprays` | Use the sprays glb for every spruce (the endless land, the islets, the garden). |
| `--spruce-detail=M` | How far out a tree keeps its full crown (default 150 m). `all` gives every near tree its full crown (the cost is in Numbers). |
| `--spruce-far=M` | Where the far sprays crown hands over to the faceted family's crown (default 200 m). |

## What was built

- **`tools/blender_trees/spruce_sprays.py`** (uses `kit.py`) writes
  `assets/models/zenscape-spruce-sprays.glb` and
  `art/blender/trees/zenscape-spruce-sprays.blend`. The old glb stays.
  - It has the same table of variants as `spruce.py`. It also has the same
    node names (`<variant> canopy`, `<variant> trunk`), height, reach and
    tier layout, so the glb drops in. It adds one node per variant,
    `<variant> canopy far`, a coarser version of the same tree.
  - **A tier** has four whorls of boughs: reaches 1.08, 0.8, 0.5 and 0.28
    of the tier's reach. Each whorl's tips land on the tier's cone, so the
    tier keeps the family's silhouette. The top tier adds a small whorl
    angled up round the leader.
  - **Inside each tier** a small dark bicone (0.45 of the reach) stops the
    eye between boughs.
  - **A bough** is one tented sheet:
    - the spine is on top and the edges hang (`ARCH`);
    - it is narrow at the trunk, widest a little inside the middle, and
      ends in a point;
    - it droops along its length;
    - the outer 70 % has sawtooth needle teeth, one every 0.07 model
      units, swept out and forward;
    - the inner 30 % is bare (it sits under the boughs above).
    The sheets are single-sided; the canopy material draws both sides
    (`cull_disabled`).
  - **The bake** is greyscale per vertex, and the game tints it as before:
    - dark at the trunk (0.55) and light at the tips (1.02);
    - teeth tips a little lighter, notches a little darker;
    - the core 0.42;
    - upper tiers a touch lighter.
    Vertices are shared (smooth in Blender). The game's canopy shader
    shades each face flat from its own derivatives (`flat_faces`), so this
    looks the same as a flat export with a third of the vertices.
  - **Variety:** the windswept lee, the sparse gaps and the dead top work
    as in `spruce.py`. Each variant is seeded by its name, so the near and
    far crowns share a trunk.
  - Run: `python3 tools/blender.py run tools/blender_trees/spruce_sprays.py [-- --no-render] [-- --out DIR]`.
    The preview renders (lineup, close, above, `pair` beside the old
    mature, `lods` the far crowns) go to `/tmp/zs-tree-previews/spruce-sprays/`.
- **`scripts/hero_trees.gd`:**
  - `--spruce=<look>` picks the glb (`SPRUCE_LOOKS`, `spruce_glb()`);
  - `spruce_has_far()` and `spruce_far_mesh()` give the far crown;
  - `spruce_family_crown()` gives the old crown whatever look is picked.
- **`shaders/reference_surface.gdshader`:** `lod_band_on` / `lod_band`, off
  by default. An instance draws only while its foot is
  `lod_band.x..lod_band.y` m from the eye; outside that band it collapses
  to its foot, so its faces cull.
- **`scripts/endless/land_trees.gd`** (only with a look that has a far
  crown): three levels of detail per tree.
  - **Full crown within `DETAIL` (150 m).** The full crowns stand in 64 m
    squares (`DETAIL_TILE`), made only for squares within DETAIL and freed
    32 m past it, so the rest of the near ring never draws them.
  - **Far sprays crown from 150 to `FAR_CUT` (200 m).** These stand in
    128 m squares (`FAR_TILE`), made only within FAR_CUT.
  - **The family's faceted crown from 200 to 430 m.** One batch per
    block, as before. The mid ring's crowns already stand inside the near
    trees from 190 m.
  - Every tree switches at its own distance. The full-to-far swap at
    150 m is between two versions of the same tree, so it reads as a
    softening. The swap to the family crown at 200 m is a visible change
    of shape when you look for it.
  - Each band is that crown's material with its `lod_band`. Trunks,
    shadows (the proxies), the mid and far rings and the solid are
    unchanged.

## Triangles per tree

| variant | full crown | far crown | family crown (before) |
|---|---|---|---|
| mature | 4140 | 960 | 192 |
| young | 2532 | 612 | |
| windswept | 4086 | 972 | |
| dead-top | 3528 | 828 | |
| sparse | 3006 | 732 | |
| spire | 4818 | 1248 | |

Trunks are unchanged (25 to 49 faces in Blender, 45 triangles in the
game).

## Numbers (this Mac)

**How it was measured.** These are frame times, not F1's own figure.

- A throwaway driver (`scratch/spruce-sprays/views.gd`) holds a fixed eye
  in endless flight and streams the land, trees, grass and look round it.
- Each run is rendered, `--uncapped` and not fixed-fps. It settles for
  300 frames, then times 600.
- The figure is the median frame in ms, with A/B pairs run back to back.
- The Mac was shared with the other two spruce agents and another Godot,
  so the baseline is inflated (25 to 38 ms) and drifts. Some runs of
  either look came back at a flat 6.9 ms whatever was on screen; those
  were dropped.
- Treat the differences as ±1 ms.

The three eyes (seed 1):

- dense: 8 m over -704,-2700, looking north;
- cruise: 45 m over -700,-1900, looking north and down;
- high: 160 m over -1500,-2900, looking down over woods.

| setup | dense | cruise | high |
|---|---|---|---|
| current spruce | 35.4 / 38.1 | 25.1 / 26.0 | 24.8 / 25.0 |
| sprays, as shipped (full 150 m, far sprays to 200 m, family past) | 36.4 / 39.1 (+1.0) | 28.2 / 28.4 (+2.7) | 25.8 (+0.9) |
| sprays, far sprays to 260 m | +5 | +2 to +5 | +4.5 to +5 |
| sprays, full 150 m and far sprays to 430 m (no family crown) | +4.4 | +11 | +6.6 |
| sprays, `--spruce-detail=all` (every near tree full) | +19 | +32 | +13 |

The near ring draws about 11k trees in this part of the land, so it
needs the levels of detail.

Smoke: `python3 tools/smoke.py studies/endless_flight.tscn -- --spruce=sprays --at=-704,-2700 --heading=0 --alt=8`
passes (400 frames, 0 errors), and so does the default look.

## Model budget (`docs/art/model-budget.md`)

- **Sculpt high, bake low:** does not apply. There are no textures; the
  needles are the geometry and the shade is in vertex colour. No saving.
- **Import LODs:** applies; done by hand (three levels, above).
  - Godot's generated LODs don't survive `HeroTrees._build`, which rebuilds
    the arrays.
  - A MultiMesh picks its LOD for the whole batch, not per tree.
  - Saving: a tree past 150 m draws 960 triangles (mature), past 200 m
    192, instead of 4140.
  - Frame time: from +13 to +32 ms (all full crowns) down to +1 to +3 ms.
- **Silhouette geometry:** this is the whole approach. The needle teeth
  are real outline breaks.
  - The inner 30 % of each bough has no teeth, because the boughs above
    hide it. That saves about a fifth of the triangles (roughly 1000 a
    mature tree).
  - **Shared vertices:** the flat-faces shader shades flat from
    derivatives, so the canopy exports smooth: 3.7k vertices instead of
    12k for the mature. Before the levels of detail, this took the dense
    view from about 80 to 42 ms.
- **Rigid parts on bones:** does not apply (no rig).
- **Parallax depth:** does not apply (flat faces, no textures).
- **Vertex-colour grime:** applies and is used.
  - Dark at the trunk, light at the tips, dark inside the core; that is
    the depth between boughs.
  - No extra cost over the old bake.
  - A further step would be a per-vertex occlusion bake (rays against the
    other boughs) instead of the radial ramp. It would cost no
    triangles.

## Tests

Run headless, the tests that touch the changed files:

- `test_breeze`, `test_ground_look`, `test_landform_forest`,
  `test_pilot_wake`, `test_sky_peak_look` and `test_sky_swap` pass.
- `test_aqueduct_isle_look` fails four checks (plant triangle budget,
  tufts, path middle, plants on turf). It fails the same four with this
  round's changes stashed, so spruce-base had them already.
- The full suite was not run.
- No committed tests (prototype round).

The default look is unchanged:

- the flag is off by default;
- the shader's `lod_band_on` is false by default;
- `land_trees.gd`'s new paths run only with a far-crown look.

## Stills

In this worktree's `scratch/spruce-sprays/` (git-ignored):

- `spruce_sprays_sheet.png` has the current spruce on the left and the
  sprays on the right. The rows, top to bottom:
  - the lone tree from the meadow at walking eye height;
  - the same tree close;
  - low at the dense-wood start, with one tree near the eye;
  - cruise height over woods (45 m over -1500,-2900).
- The single stills: `lone_*.png`, `lonenear_*.png`, `dense_*.png`,
  `cruise_*.png`.
- Blender previews: `blender/lineup.png` (six variants), `pair.png` (the
  old mature beside the new), `lods.png` (the far crowns), `above.png`,
  `close.png`.

What to look at:

- **Close up,** each bough reads as a fringed spray. Tiers break into
  many tips, with dark between the boughs and lighter tips.
- **Against the sky** (backlit, dense row), the silhouette is the clearer
  win: the old one is a smooth stack of star cones.
- **From cruise height** the two are close. The family crown and the mid
  ring take over at 200 m.

Open questions for the user:

- A more ragged far crown?
- A higher `--spruce-detail`, if the 150 m change is noticed in flight?
- A lighter bake (`V_ROOT`, `V_CORE` at the top of the generator), if the
  interiors read too dark under the game's tint?

## Round 2: painted crown (less flat, bluer, painterly)

Shading only; the sprays shape and glb are unchanged. All of it is on
under `--spruce=sprays` and off otherwise (every new uniform is 0 by default).

- **Less flat.** The light normal bends out from the trunk and up
  (`spruce_round` 0.7), so light rolls round the crown instead of each
  bough sheet taking its own flat shade. The sun goes through the carved
  rock's three-step painted ramp over a wrapped term. The crown's own
  shadow (the proxy cone's) takes only half the sun, so a backlit crown
  has no hard black half. A soft glow comes through a crown seen against
  the sun, and the sky's fill is 1.6x the plain hemisphere term.
- **Bluer.** The colour is kept at its own luminance and moved to a glaucous
  blue-green (sRGB about 0.39, 0.55, 0.63). Each tree gets between 0.62x
  and 1.12x of the blue, hashed from its foot. The tips (bake over 0.8)
  are frostier. The far rings' `FAR_ALBEDO` gets the same blue, so trees
  don't turn green with distance.
- **Painterly.** This uses the endless ground's patch language (`ep_fade`
  / `ep_patch` from `endless_patch.gdshaderinc`, with the ground's
  sun/deep mix and warm/cool drift multipliers). It has a 70 m drift
  across a wood, a 4.5 m light and deep half, 1.5 m clumps, and dabs
  with an edge at 0.45 and 1.4 m. All of them fade to the mean with the
  pixel footprint. Undersides and the core go cooler, not darker.
- **Files:**
  - `shaders/spruce_paint.gdshaderinc` (new) holds the functions and
    constants.
  - `shaders/reference_surface.gdshader` has the uniforms, the volume
    normal, the paint call and the fill.
  - `shaders/reference_direct_light.gdshaderinc` has an
    `#ifdef ZS_SPRUCE_LIGHT` branch. Only `reference_surface` defines it.
  - `scripts/hero_trees.gd` has `SPRUCE_PAINT`, `spruce_paint()` and
    `spruce_far_albedo()`.
  - `scripts/sky_islets.gd` calls `spruce_paint` on the crown material.
  - `scripts/endless/land_trees.gd` sets the far albedo.
- **Knobs:**
  - `--spruce-round=`: volume, default 0.7.
  - `--spruce-blue=`: blue, default 0.85.
  - `--spruce-dabs=`: painted patches, default 1.0.
  - `--spruce-wrap=`: ramp wrap, default 0.6.
  - `--spruce-glow=`: backlit glow, default 0.35.
  - `--spruce-paint=off`: the round-1 look, to compare.
- **Cost:** no new varyings (the shader sits at Metal's 31). Per crown
  pixel it adds about 4 value-noise lookups and a small branch in
  `light()`. Frame time was not measured.
- **Stills:** `scratch/spruce-sprays/painterly/painterly_sheet.png` puts
  before on the left and after on the right. The rows are the lone tree
  close, the dense wood start (backlit) and cruise over -1500,-2900. The
  views are in `scratch/spruce-sprays/painterly/stills.sh <label> [args]`.
- **Smoke:** endless flight passes with `--spruce=sprays` and with the
  default look (400 frames, 0 errors).
- **Not done yet:**
  - The mid and far rings (`_far_shader`) only got the hue. At cruise
    they still read dark; their light could take the same fill.
  - The dabs are subtle at walking distance. `--spruce-dabs=1.5..2`
    makes them stronger.
  - The ramp's steps barely show on the bent normal. More steps, or less
    `round`, would bring the stepped look up.

## Round 3: contrast (flatter, lighter, warmer shade)

Shading only. User: too much contrast, a little too dark, still clearly
different from the grass.

- **Default spruce is now sprays.** `HeroTrees.spruce_glb()` returns the
  sprays glb unless `--spruce=family` (the old faceted family). This is
  global (every scene that builds spruce through HeroTrees), not only
  endless flight.
- **New defaults** (`SPRUCE_PAINT` in `scripts/hero_trees.gd`):
  - `wrap` 0.6 -> 1.0: the shade side keeps more of the stepped sun.
  - `fill` 2.2 (was a constant 0.6): the sky's fill on the crown.
  - `warm` 1.0: the fill takes an olive (`SPRUCE_SHADE_OLIVE`) in place of the blue tint, so the shade moves warm; the lit side keeps the blue.
  - `flat` 1.0: the bake's light/dark is pulled toward a lighter mean
    (`pow(bake/0.85, -0.6*flat)`), lifting the core and trimming the tips.
  - `fine` 3.0: gain on the 0.45 m and 1.4 m dabs (was 1.8x1).
  - `farlift` 1.45: the mid and far rings' albedo, so a wood is not
    darker with distance.
  - The sun's cool/warm ramp in `reference_direct_light.gdshaderinc` is
    nearly neutral (0.96,0.99,1.04 to 1.04,1.02,0.94).
  - New uniform `spruce_tone` (vec4: fill, warm, flat, fine) on `reference_surface`.
- **Round 2 back:** `--spruce-look=r2` (the sun ramp's tint change stays).
  Each dial is also `--spruce-fill=`, `-warm=`, `-flat=`, `-fine=`, `-farlift=`.
- **Measures** (crown crops, `look_measure.py --no-classes`; close = crop
  0.40,0.35,0.60,0.65 of the lone tree, dense = 0.36,0.55,0.52,0.95 of the
  near tree's lower half; the close crop has no sky, the dense one a few
  gaps):

  | | before | after | world |
  |---|---|---|---|
  | close V p50 | 0.416 | 0.471 | 0.54-0.78 |
  | close darkest tenth V | 0.207 | 0.279 | 0.36-0.67 |
  | close lit/shaded | 3.2 | 2.4 | 1.2-2.1 |
  | close blotch8 | 0.845 | 0.838 | 0.53-0.83 |
  | close darkest-tenth hue | 174 | 163 | 66-100 |
  | dense V p50 | 0.267 | 0.337 | |
  | dense darkest tenth V | 0.117 | 0.215 | |
  | dense lit/shaded | 6.2 | 3.2 | |
  | dense blotch8 | 0.917 | 0.916 | |

- **Not reached:** the targets for darkest tenth (0.30), p50 (0.45-0.55) in
  a dense wood, lit/shaded 2.5 in the shaded lower crown, blotch8, and the shade
  hue (still teal-ish, 160s). The olive fill barely moves it because the
  shade's hue also comes from the look pass's sky fill (`zs_look_fill`) and
  bounce, not from `spruce_tone`. Next: gate those for the crown, then raise `fill` or `flat`.
  `--spruce-blue=0` alone drops the shade hue to about 120.
- **Stills:** `scratch/spruce-sprays/contrast/contrast_sheet.png` (rows:
  close, dense, cruise; left round 2, right round 3), singles `v6_*.png`.
  The distant trees at cruise are only slightly lighter.
- **Smoke:** endless flight, default, `--spruce=family`, `--spruce=sprays`: 400 frames, 0 errors.

## Round 4: split, shade hue, speckle, lift

Shading only. `--spruce-look=r3` brings round 3 back (`SPRUCE_R3` in `scripts/hero_trees.gd`).

- **The hard vertical split.** The cause was the painted sun's three tiers
  (`zs_spruce_painted_light`, 70 % stepped, edge width 0.18) read over the bent
  "round" normal: across the crown the normal sweeps from the sun side to the far
  side, and where the sweep crosses a tier edge the tone jumps along a straight
  line down the tree. Fix: the step share is 0.25 with a fully soft edge
  (`steps`, `soft`), so the tiers read as a gradient. No cone or per-half bake is
  involved.
- **Shade hue.** The crown's share of the look pass's sky fill and bounce is
  cancelled off the blue albedo and put back olive (`olive`, in
  `reference_direct_light.gdshaderinc` and the emission), the plain hemisphere term leans
  olive (`hemiolive`), the deep patches and the dark depths take an olive tint
  instead of a blue one. The lit side keeps the blue (`blue` 1.0).
- **Fine variation.** Edged dabs at 0.16, 0.33 and 0.075 m (`ep_patch`, the
  ground's model), gain `speck` (new uniform `spruce_tone2.x`).
- **Dark.** `fill` 2.6, `flat` 1.25, the crown's own-shadow floor `floor` 0.85
  (was 0.5), and at range the bake and blue ease to the mean (`away`, 40..160 m).
- **Distant.** Far rings: `farlift` 2.0, `farblue` 0.6 (less blue), `farbaked` 0.4
  (less baked dark) via `HeroTrees.spruce_far_baked`. The faceted family crown past 200 m takes none of the sprays paint.
  Backlit trees at 150 to 300 m still read dark at cruise heading north (the old family is darker); not a sprays fault.
- Dials: `--spruce-steps= -soft= -speck= -floor= -olive= -hemiolive= -farblue= -farbaked=`.
- Stills: `scratch/spruce-sprays/round4/round4_sheet.png` (left r3, right r4; rows
  close, dense, cruise). Smoke: endless flight default, `--spruce=family`, `--spruce-look=r3`.

| crop | measure | r3 | r4 | world |
|---|---|---|---|---|
| close | V p50 | 0.471 | 0.482 | 0.54-0.78 |
| close | darkest tenth V | 0.279 | 0.381 | 0.36-0.67 |
| close | lit/shaded | 2.42 | 1.77 | 1.2-2.1 |
| close | blotch8 | 0.838 | 0.821 | 0.53-0.83 |
| close | shade hue | 163 | 108 | 66-100 |
| dense | V p50 | 0.337 | 0.451 | |
| dense | darkest tenth V | 0.215 | 0.308 | |
| dense | lit/shaded | 3.15 | 2.18 | |
| dense | blotch8 | 0.916 | 0.877 | |
| dense | shade hue | 159 | 107 | |

## Texture variants (round 5, rough)

User after round 4: good, but the crown is a little too smooth next to the
grass; not the cards' fur or the tufts' stripes. Three rough ways to add
texture, each a flag; without the flag the crown is round 4.

**Why the grass reads textured.** Measured on one still (crown crop vs a
grass crop, `look_measure.py`, which now also prints `std1/2/4` and
`local4/8`, the mean luma spread inside 4 and 8 px windows). The crown has
as much contrast as the grass (std at 1 px 0.066 vs 0.069), but it sits in
a few hard facet edges: its median pixel gradient is 0.0035 against the
grass's 0.025, and the spread in a 4 px window 0.016 against 0.035. The
grass has a gradient everywhere: thin blades (0.08 to 0.14 m), each ramped
root to tip about 2.2 to 2.8x, each tuft +-12 %, dark gaps between; the
grass shaders add no pixel noise. The crown's facets are near-uniform, and
round 3's `flat` pulled the bake's per-bough ramp nearly flat.

**The variants** (`--spruce-texture=a|b|c`, `--spruce-texgain=` scales any of them, default 1):

- **a: per-bough gradient and tone.** Each bough dark where it leaves the
  tier and light at its tip (0.86 to 1.20), each tooth lighter to its tip,
  each bough its own value (+-11 %) and a slight olive-to-blue hue.
  Reads as boughs told apart, each a little shaded; the fine grain barely moves.
- **b: micro-facets.** The glb's `<variant> canopy b`: each sheet cell is
  split by a jittered row between spine and notches, each tooth into three
  facets round a jittered centre (`FACETS`, `FACET_JIT` 0.35 in the
  generator). The shader adds each facet's tilt off the smooth sheet back
  over the volume normal (x1.6), fading out 40 to 110 m. Reads as a crinkled,
  faceted shimmer, low-poly. **Cost:** near crown 4140 -> 9564 triangles
  (mature; young 5844, windswept 9438, dead-top 8152, sparse 6934, spire
  11114), about 2.3x, within the 150 m detail band only. Frame time not measured.
- **c: dabs along the boughs.** Soft value dabs in bough space (along in
  0.05 model units, across about two a side), warped value noise of two
  sizes, each bough offset by its own hash so they never line up; lights
  warm, darks olive; fade by footprint and 40 to 120 m. Reads as brushy
  streaks along each bough.

**Bough space.** The generator now writes UV = (along 0..1, bough hash) and
UV2 = (across: 0 spine, +-0.4 notch, +-1 tooth tip; bough length) on every
crown (near, far, b). The near crown's positions are unchanged (same
vertices; the new hash uses its own rng). The default look ignores them.
Shader: `spruce_texture` / `spruce_texture_gain` on `reference_surface`,
`zs_spruce_texture` in `spruce_paint.gdshaderinc`; no new varyings (UV and UV2
were already in the shader). The family crown past 200 m gets `spruce_texture` 0.

**Measures** (crown crops; close = 0.40,0.30,0.62,0.70 of the lone tree at
about 5 m, wood = 0.56,0.36,0.70,0.62 of the nearest tree in the wood view at about 20 m):

| crop | measure | round 4 | a | b | c | grass |
|---|---|---|---|---|---|---|
| close | edge p50 | 0.0035 | 0.004 | 0.008 | 0.010 | 0.025 near, 0.0165 mid |
| close | local4 | 0.016 | 0.018 | 0.021 | 0.023 | 0.035 near, 0.022 mid |
| close | V p50 | 0.455 | 0.439 | 0.447 | 0.459 | |
| close | lit/shaded | 1.67 | 1.85 | 1.86 | 1.90 | 1.65 |
| close | blotch8 | 0.826 | 0.843 | 0.818 | 0.822 | 0.72 |
| wood | edge p50 | 0.0175 | 0.0235 | 0.024 | 0.0275 | 0.0245 |
| wood | local4 | 0.0325 | 0.044 | 0.040 | 0.0435 | 0.040 |
| wood | V p50 | 0.506 | 0.510 | 0.506 | 0.498 | |

At wood range the crowns already carry about the grass's grain; up close
all three still sit under it (c closest), so `--spruce-texgain=1.5..2` is the
next thing to try on the one the user picks.

**Stills:** `scratch/spruce-sprays/texture/` (`stills.sh <label> [args]`,
`measure.sh <labels>`): `sheet_close.png`, `sheet_close_zoom.png`,
`sheet_wood.png`, each a 2x2 grid: round 4 top left, a top right, b bottom
left, c bottom right. Copies in `/tmp/spruce-texture/` (`0 ROUND4 - close.png`,
`1 A - ...`, `2 B - ...`, `3 C - ...`, each close, close zoom and wood).
The wood view: eye 3.4 m over -700,-2540 looking at -714,-2505.

**Launch:** `./run-endless-flight.command --spruce-texture=a --at=-704,-2700 --heading=0 --alt=8` (b, c likewise).
**Smoke:** endless flight plain and with a, b, c: 400 frames, 0 errors.

## Round 5: B default, matching distance crowns

User after the texture variants: B looks solid, a little darker maybe; the
distance versions stick out like a sore thumb.

**B is the default.** `HeroTrees.spruce_texture()` returns b unless
`--spruce-texture=off|a|c` (off is round 4). With b the crown takes
`SPRUCE_B` over `SPRUCE_PAINT`: `value` 0.85 (new uniform `spruce_value.x`,
the crown's albedo times it at every level), `flat` 1.6 and `floor` 0.95 (they
lift the darks so the lit/shaded ratio does not rise), `bfar` 0.985 (b's
micro-facets' mean tone, measured -1.8 % on the close crop, kept where the
facets fade out, 40 to 110 m, and on every distance crown). Off, a and c keep
value 1. Dials: `--spruce-value= -bfar= -midlift= -ringlift=`.

| close crop (lone tree) | B as flag, before | after | world |
|---|---|---|---|
| V p50 | 0.447 | 0.427 | 0.54-0.78 |
| darkest tenth V | 0.322 | 0.305 | 0.36-0.67 |
| lit/shaded | 1.86 | 1.85 | 1.2-2.1 |
| darkest tenth hue | 121 | 124 | 66-100 |
| blotch8 | 0.818 | 0.794 | 0.53-0.83 |

(value 0.9 alone gave p50 0.416 but lit/shaded 1.93; a higher `fill` did not move it.)

**Distance crowns from the same generator** (`tools/blender_trees/spruce_sprays.py`
LODS `mid` and `low`, glb nodes `<variant> canopy mid` / `<variant> canopy low`,
`HeroTrees.spruce_mid_mesh` / `spruce_low_mesh`). The same tiers, droop, lean,
gaps and seed as the near tree; each tier one skirt from the tier's top on the
trunk down to drooping bough tips at the rim, notched in and up between them
(`skirt()`; mid 6 tips a tier, low 4). The bake is the near crown's logic
(root dark, tips `V_TIP`). Thin tents of the near boughs (still in the code as
`bough_low`, LOD key `tent`) were tried first: at range they read
see-through and dark.

**Levels** (`scripts/endless/land_trees.gd`, sprays look):

| level | distance | mesh | triangles (mature; range over variants) before -> after |
|---|---|---|---|
| near | 0-150 m | full crown, b | 4140 (round 4 default) / 9564 (b flag) -> 9564 (5844-11114) |
| lighter | 150-200 m | `canopy far` | 960 -> 960 (612-1248) |
| mid crown | 200-400 m (was 200-430) | `canopy mid` per variant (was the faceted family) | 192 -> 72 (48-96) |
| mid ring | 400-1440 m (was 190-1500, standing inside the near trees) | `mature canopy low`, fitted per variant (was FarTrees' proxy) | 20 -> 48 |
| far ring | 1440-5750 m, fade to 6200 | the same | 20 -> 48 |

- The near, lighter and mid crowns draw in the near crown's own material
  (reference_surface with the spruce paint, the volume light, the olive
  shade). The rings first did too, but on ~30k trees that cost about 12 ms
  at cruise (52.3 ms with the old rings, 64.4 with them; neither the paint
  noise nor the sway was the cost). So the rings have their own small
  shader, `shaders/endless_spruce_ring.gdshader`: the same blue (eased as at
  range), value, volume normal, wrapped soft-stepped sun with the porous
  own shadow and backlit glow, olive hemisphere, fill and look fill, the
  same dither; its knobs are read off the crown material
  (`land_trees.gd _ring_shader`). `RING_GAIN` (1.11, 1.08, 0.98) matches it
  to the reference on a view of forced rings (crop V p50 0.427 vs 0.435,
  hue 103 vs 100; `sheet_rings.png`, reference over cheap).
  `--spruce-rings=ref` draws the rings in the full material,
  `--spruce-rings=old` brings back FarTrees' crown in `endless_tree_far`
  (still what `--spruce=family` uses).
- `midlift` / `ringlift` 0.965 match the distance crowns' value to the
  full crown's at 150 to 400 m (crop V p50: full 0.431, far 0.435, mid and
  low skirts 0.447 before the lift).
- **Fades.** `reference_surface` `lod_fade` (x at the band's start, y at its
  end, m): a dither in screen space (interleaved gradient noise), the
  outgoing level drawing where the noise is under its fade and the incoming
  one where it is over, so the two never both draw a pixel. Widths: 12 m at
  150, 15 m at 200, 30 m at 400, 60 m at 1440, 450 m at the far end.
  The fade's distance is the foot across (`plant_root`) and the pixel's own
  height, the same for both levels; the vertex keeps an instance
  `LOD_SLACK` 25 m past its band. The detail tiles stand out to their fade
  plus slack. The mid crown batches draw to a block middle of
  `MID_CROWN_END` 670 m (was the trunks' 430 with Godot's block-wise fade)
  and the rings start at 400 m with no overlap, so the old double draw of
  the mid ring inside the near trees from 190 m is gone.
- Flags: `--spruce-mid=M` moves the mid crown to ring hand-over (400).
  Forcing one level on a whole view: `scratch/spruce-sprays/lod/levels.sh`.
- `reference_surface` `flat_faces`: a face smaller than a pixel can have no
  derivatives; it keeps the mesh normal then (it showed as stray blue-purple
  pixels on the far crowns).
- Shadows are still cast by FarTrees' 20-triangle proxy (unchanged).
- **Backlit distant trees.** At cruise heading north (into the sun) the
  rings and the 200-430 m crowns read navy before: the faceted family crown
  took none of the sprays paint and the rings were lit by Godot's own light
  and ambient in `endless_tree_far`. Both now go through the sprays light and
  read grey-green like the near crowns (sheet `cruise_zoom`).

**Stills** (`scratch/spruce-sprays/lod/`, `stills.sh <label> [args]`):
`sheet_close.png`, `sheet_mid.png`, `sheet_cruise.png` (before left, after
right), `sheet_mid_zoom.png` and `sheet_cruise_zoom.png` (before over after),
`sheet_levels.png` (the mid view with every tree forced to full, lighter,
mid, ring crown, top to bottom; shape check, rendered before the final value).
Copies in `/tmp/spruce-lod/` (`0 BEFORE - mid.png`, `1 AFTER - mid.png`, ...).
Views: close as round 4; mid eye 16 m over -712,-2372 looking at -712,-2700
(trees at 30 to 1000 m); cruise eye 60 m over -704,-2380 looking at
-704,-2900 (into the sun).

**Launch:** `./run-endless-flight.command --at=-700,-1900 --heading=0 --alt=45`
(no flags: b and the new crowns). `--spruce-texture=off` for round 4.

**Smoke:** endless flight plain, `--spruce=family`, `--spruce-texture=off`
(400 frames, 0 errors), and `studies/aqueduct_isle.tscn -- --no-title`
(passes). B as the default also puts b's near crown (2.3x the triangles) on
the islets and the aqueduct isle, which have no levels of detail;
`test_aqueduct_isle_look`'s plant triangle budget already failed before.

**Frame time** (this Mac; `scratch/spruce-sprays/lod/perf.sh`, `iso.sh`):
rendered, `--uncapped`, not fixed-fps, 1500 frames to settle, the median
of 600; one Godot at a time (the script waits while any other Godot runs,
bar the user's idle editor, PID 82102; other agents' Godots came and went,
and one run that overlapped one, off/dense 87.9 ms, is dropped). Main is the
plain checkout at 374e19d4 (round 3, which now also has the native land
field). Dense: 8 m over -704,-2700 looking north; cruise: 45 m over
-704,-2380 looking at -704,15,-2900 (north, into the sun, woods out to the
far rings).

| build | dense | cruise |
|---|---|---|
| main (round 3) | 35.4 / 35.4 | 40.2 / 40.4 |
| this round, `--spruce-texture=off` (round 4 near crown, new distance crowns) | 34.1 / 33.9 | 39.7 / 39.6 |
| this round, default (b) | 35.1 / 34.9 (-0.4) | 53.0 / 53.0 (+12.7) |
| default, rings in the full material (`--spruce-rings=ref`, first try) | 46.1 / 45.8 | 64.0 / 64.4 |
| default, `--spruce-rings=old` | | 52.3 |
| default, `--spruce-detail=100` | 34.6 | 46.4 (+6.1) |
| default, `--spruce-detail=60` | | 37.5 (-2.8) |

- In the dense wood the new default is within noise of main.
- At cruise b's near crown costs about +13 ms: from 45 m over a wood many
  trees are inside the 150 m detail distance, and b's crown is 2.3x the
  triangles. `--spruce-detail=80` should land about +2 to +3 (between the
  two measured); 60 brings it under main. The default is left at 150.

**Model budget** (`docs/art/model-budget.md`) for the mid and low crowns:
- Import LODs / visibility ranges: this is the round. Per tree past 200 m:
  72 instead of 192 triangles (mid, about -60 %); in the rings 48 instead of
  20 (+28 a tree, about +0.5 M triangles over ~10k mid and ~20k far trees;
  the frame's primitives went from 15.0 M to 15.4 M in the dense view).
- Silhouette geometry: applies, cheaply: the notched, drooping skirt rims
  are the outline breaks; no teeth past 200 m.
- Vertex-colour grime: applies, used (root dark, tips light); at range the
  shader eases the bake to its mean, so the tone is set per level
  (`midlift`, `ringlift`).
- Sculpt high/bake low, rigid parts on bones, parallax depth: do not apply
  (no textures, no rig).
