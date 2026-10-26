# Clean look (experiment, branch `look-clean`)

An alternate look to judge by playing: calmer, bigger flatter shapes. Land,
generation, collision and placement are untouched; looks only. Off by default
(the main look is unchanged when off).

## Launch and flip

    python tools/play.py -- --look=clean --edges=1 --ledger=/tmp/look_clean_ledger.json

- `--look=clean` starts in the clean look; `--edges=1` starts with the edge line.
- **K** (or F6) flips the look live (eased over 0.35 s), **J** (or F7) the edge
  line. A note ("Look: clean / as it was", "Edges: on/off") shows where the
  weight note does. Keys: `studies/endless_flight.gd` `_clean_key`.
- One global shader uniform `zs_clean` (0..1, project.godot `[shader_globals]`,
  declared in `shaders/reference_globals.gdshaderinc`) is mixed in by every
  shader; `scripts/endless/clean_look.gd` owns it, eases it, and moves the
  Environment's haze and glow. `zs_edges` is published too (the pass reads
  `CleanPost.edge_strength`).

## What each item changed (knobs)

1. Ground paint (`shaders/endless_ground.gdshader` "Clean look" block in the
   carpet section): 5.5 m and 1.4 m noise cut to 10 %, 19 m to 40 %, 8 m clumps
   to 0.18, 34 m clumps crisp (`ep_patch_edge`, `shaders/endless_patch.gdshaderinc`)
   at 1.5x, then the blend is stepped in soft thirds (0.92). Far tufts
   (`endless_tuft_far.gdshader`) pull their own tint 30 % toward neutral. Grain,
   speckle and sheen damped. The near tufts (reference_surface) keep their
   own variation, and the tufts' baked tint cannot follow a live flip, so tufts
   and ground agree only roughly in the clean look.
2. Cool shadows and warm sun: `shaders/clean_look.gdshaderinc` (`ZS_CLEAN_WARM`,
   `ZS_CLEAN_COOL`), used in ground, tufts, `reference_surface`, the spruce
   sprite/ring/forest floor shaders and far trees.
3. One light model: ground and far tufts scale their albedo by banded / lambert
   (`zs_clean_sun_ratio`, no `light()` so the off look is bit for bit); the
   surface shader's `light()` swaps n.l for `zs_clean_steps` (the rock's three
   soft steps, 0.86 of the sun at most).
4. Clouds: `cumulus_light.gdshaderinc` palette (white sun side, lilac-grey
   shade) and `endless_cloud_composite.gdshader` (crisper lit/shade split).
5. Snags: `reference_surface.gdshader` "dead wood" lift (target grey-brown
   0.36, 0.305, 0.26). Snags use palette role 0 there; the spruce sprite bake
   opts out (`clean_lift`, `scripts/endless/spruce_sprites.gd`) or the atlas
   bakes tan.
6. Distance: ground colour planes by camera distance (`lay`, 240 to 900 m
   blue-green, 1100 to 3600 m pale blue) and Environment haze
   (`clean_look.gd` `CLEAN_FOG_BEGIN/CURVE/AERIAL`; clear to 260 m).
7. Water: sea and river/lake depth in log bands, ripple normals down 70 to
   75 %, one crisp shore line, wider and brighter glints
   (`endless_sea.gdshader`, the `wet` block of the ground shader).
8. Grade: AgX was tried and turned greens khaki and spruce tan (the palette is
   built against ACES), so it is **off**; `--clean-agx` puts it back. The grade
   is the post pass (`shaders/clean_post.glsl`): warm highlights, cool shadows,
   `CleanPost.TINT_WARM/TINT_COOL`. The sun and sky are not re-derived.
9. Edges: same pass; a depth jump (18 % to 60 % of the nearer depth) to sky or
   far land, from 140 to 500 m, drawn in the haze's colour at 0.55
   (`clean_look.gd` `EDGE_STRENGTH`, `_edge_colour`).

## Stills

`/tmp/look_now/` (main), `/tmp/look_clean/` (clean), `/tmp/look_clean_edges/`
(clean and edges), `/tmp/look_h12.5/`, `/tmp/look_h18.5/` (hour 18.5 is a night
mood here), `/tmp/look_toggle/` (the live K / J flip through the key path).

## Unverified and limits

- Headless only imports; every look check was rendered, one machine (Mac, Forward+).
- The edge pass and grade need a RenderingDevice (not Compatibility).
- Not checked: other moods, winter, regions worlds, the plane and ruin kit
  under the surface-shader changes, performance.
- Near tufts do not calm (their colour is baked per tuft).
- Out of scope, seen: white triangle sprites on the sandy patch in `high`
  (main look), hazy near grass in `coast`, jagged grass lip on the sand cliff.
- Tests likely to break: any golden-image or shader-parameter tests of
  `reference_surface`, `endless_ground`, `endless_sea`, and tests that count
  `[shader_globals]` or check `project.godot`; none run.

## Round 2: one switch per item, grass kept, clouds in three

Launch (from the worktree):

    python3 tools/play.py -- --look=clean --edges=1 --ledger=/tmp/look_clean_ledger.json
    python3 tools/play.py -- --clean=paint,shadows,water --clouds=cream --ledger=/tmp/look_clean_ledger.json

Flags: `--look=clean` all items on (clouds white); `--clean=a,b,...` only those
(paint, shadows, light, clouds, snags, distance, water, grade, edges);
`--clouds=beige|cream|white` (beige is as it was; cream or white also turns the
clouds item on); `--edges=1` as before. No flags: every item off, which is main's
look.

Keys (`studies/endless_flight.gd`, `scripts/endless/clean_look.gd`): **K** (F6)
master (all on; all off when all are on); **O** (F8) the panel listing each item
and its state; **1..9** one item each (1 paint, 2 shadows, 3 light, 4 clouds
cycling as it was / cream / white, 5 snags, 6 distance, 7 water, 8 grade,
9 edges); **J** edges. Each flip eases over 0.35 s. The globals are now
`zs_cl_paint, zs_cl_shadow, zs_cl_light, zs_cl_cloud (0/1/2), zs_cl_snag,
zs_cl_dist, zs_cl_water` (`zs_clean` is gone); grade and edges are the post pass.

Where each switch acts: paint = ground paint block + far tuft tint pull (now
12 %, was 30 %); shadows = cool fill, warm sun tint, spruce and far tree tints;
light = banded sun on ground, tufts and the surface shader; clouds =
`cumulus_light.gdshaderinc` (`zs_cumulus_palette_plain` is the old palette) and
`endless_cloud_composite.gdshader`; snags = dead-wood lift; distance = ground
colour planes plus Environment haze; water = sea and river shader changes;
grade = `clean_post.glsl`.

What made the grass pale and why now fixed:
- The big one was the clouds item: the valley fog is drawn by the cloud
  composite, and white cloud light made it a haze over the near grass (coast).
  Valley fog now keeps its old colours; only cloud goes cream or white.
- The banded sun was brighter than Lambert on flat ground (about +18 %). It is
  now levelled to Lambert on flat ground (`zs_clean_banded`), steps move light
  around the mean.
- The crisp clumps pushed the paint toward SUNLIT (paler, less saturated):
  `sunny_bias` -0.10 takes it back. Far tuft neutral pull 30 % -> 12 %.
- The grade cost saturation; it gives 3 % back (`clean_post.glsl`).
- Far sea beige band: the shore line foam (water item) used a pixel footprint
  wider than the shore, so the whole far sea foamed. Faded out by footprint
  0.6..2.5 m.
- Cloud undersides: a soft floor of sky light (0.62 of the shade) keeps them light;
  white shade lilac grey, cream shade warm grey.

Grass median V / S (`tools/look_measure.py`), main stills `/tmp/look_now/` vs all on
`/tmp/look_clean2/`:

| view | main V/S | clean V/S | blotch8 main -> clean |
|---|---|---|---|
| cruise | 0.608 / 0.605 | 0.608 / 0.616 | 0.063 -> 0.062 |
| coast | 0.655 / 0.456 | 0.659 / 0.460 | 0.056 -> 0.048 |
| hills | 0.506 / 0.503 | 0.506 / 0.494 | 0.138 -> 0.131 |
| meadow_low | 0.490 / 0.548 | 0.498 / 0.550 | 0.0725 -> 0.0745 (slightly above) |
| high | 0.510 / 0.540 | 0.522 / 0.542 | 0.093 -> 0.0905 |

Single items (coast, cruise, hills), V/S, against the same build with all off
(0.659/0.451, 0.627/0.597, 0.522/0.489): paint .659/.441, .627/.579, .529/.472;
shadows .659/.449, .627/.601, .518/.503; light .667/.453, .631/.596, .522/.486;
clouds .659/.451, .627/.597, .522/.489; snags, distance, water within 0.005;
grade .655/.463, .627/.621, .522/.477. None moves V more than 0.01 or S more
than 0.02 (the off build itself differs from the main stills by up to 0.02).

Stills: `/tmp/look_clean2/` (all on: meadow_low hills rock coast cruise high),
`clouds_beige|cream|white/` (coast, cruise), `single_<item>/` (coast, cruise,
hills), `panel.png` (the panel through the key path).

Proof: smoke (headless) passes with no flags, `--look=clean --edges=1`, and
`--clean=paint,water --clouds=cream`. A scratch driver sent real key events
(O, 1, 4 x3, 9, J, K, K): 13 of 13 checks. Note headless does not compile
shaders; shader errors only show in rendered runs (all rendered runs clean).

Unverified: the compute shader needs `python3 tools/godot.py --import` after an
edit (it is a resource); other moods, winter, performance, the flip under a
long flight; the K/number keys were not tried with a pad. The panel text is
small at 4K. Fine paint noise: meadow_low blotch8 is a hair above main's.
Tests likely broken: any that read the `zs_clean` global.

## Round 3: tints follow the light, clouds as they were, the light audit

Audit: `docs/design/endless-flight/light-audit.md`.

What changed
- `--look=clean` and K no longer include the clouds item: clouds stay as they
  were (beige) until `--clouds=cream|white` or key 4 (cycles as it was /
  cream / white). K's "all off" still turns them off.
- Clouds as it was equals main: in `endless_cloud_composite.gdshader` every
  clean-look change (crisper split, valley-fog copy, soft floor, sun scatter) is
  now inside `if (ZS_CL_CLOUD_ON > 0.0)`, so with the item off the old maths
  run unchanged. The cream and white options now read the sun's hue and the
  shade's hue (`cumulus_light.gdshaderinc`).
- Tints from the light: four new globals (`zs_cl_warm`, `zs_cl_cool`,
  `zs_cl_haze_mid`, `zs_cl_haze_far`, vec3, defaults in project.godot are
  round 2's constants), set every frame by `clean_look.gd` `_tints` from
  `celestial.state`: warm = 1 lerped to the key colour's hue (luma-normalised)
  by 0.12, rising to 0.30 as the sun drops under elevation 0.45 (full at 0.1);
  cool = 1 lerped to `zs_hemi_sky`'s hue by 0.66, trimmed `(1,0.885,1)`; distance
  planes from `fog_light_color` (mid 0.12 x 0.95, far 0.22 x 0.84); the grade's
  warm and cool (`CleanPost.tint_warm/tint_cool`, were consts) from the sun and
  sky by 0.15 to 0.28 and 0.22. The spruce, forest floor and far tree shaders,
  which had the constants inline, read the globals. Knobs are those numbers.
- `--look=clean` turns on: paint, shadows, light, snags, distance, water, grade
  (edges by `--edges=1`, clouds by key 4 or `--clouds=`).

Numbers (default lighting, grass median V / S, `tools/look_measure.py`):

| view | round 2 clean | round 3 off | round 3 clean |
|---|---|---|---|
| cruise | 0.608 / 0.616 | 0.620 / 0.594 | 0.616 / 0.606 |
| coast | 0.659 / 0.460 | 0.659 / 0.446 | 0.663 / 0.448 |
| hills | 0.506 / 0.494 | 0.522 / 0.489 | 0.522 / 0.481 |

Within 0.03 of round 2 (largest: hills V +0.016, coast S -0.012). (The
off column differs from main's by shot-to-shot spawn variation, as in round 2.)

Stills: `/tmp/look_clean3/<default|golden_meadow|rosewater_dusk>_<off|on>/`
(cruise, coast, hills). At dusk the clean look's grass, sand and water go
with the mood and the clouds are the old gold ones.

Unverified: the three moods and views only (no winter, regions, other hours);
golden_meadow's sun is high (0.48) so it hardly tests a low sun; the rock, the
sunset glints and the old post keep fixed colours (audit); `grade` was rendered
but its dusk warm/cool is a few percent only; headless smoke passed with no
flags and with `--look=clean --edges=1` (shaders only compile in rendered
runs, which were clean). The audit's sun : fill numbers do not match the
measured 1.4 lit/shade; cause not found.
