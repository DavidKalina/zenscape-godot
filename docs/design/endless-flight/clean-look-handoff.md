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

## Round 4: the look is the game's look, calmer near tufts

The sections above describe the experiment; the switches, panel, keys and
flags they name are gone (below).

Baked in (new path only): paint, shadows, light, snags, distance, water,
grade, with round 3's light-following tints. The tint globals stay
(`zs_cl_warm`, `zs_cl_cool`, `zs_cl_haze_mid`, `zs_cl_haze_far`, set per frame
by `scripts/endless/clean_look.gd` `_tints`; defaults in project.godot).

Removed
- Switch globals `zs_cl_paint/shadow/light/cloud/snag/dist/water`, `zs_edges`
  (project.godot `[shader_globals]`, `shaders/reference_globals.gdshaderinc`,
  and every `mix(old, new, zs_cl_x)` in the shaders).
- Clouds: `cumulus_light.gdshaderinc` and `endless_cloud_composite.gdshader`
  restored to main's bytes (cream/white code deleted).
- Edges: the depth read, edge colour and strength from `clean_post.gd` and
  `clean_post.glsl` (the pass is now the grade only; it no longer reads depth).
- Panel, K/J/O/1-9/F6-F8 keys and their code in `studies/endless_flight.gd`,
  flags `--look`, `--clean`, `--clouds`, `--edges`, `--clean-agx` (AgX code).
- `clean_look.gd` is now ~80 lines: the tints each frame, and the Environment's
  haze (`FOG_BEGIN/CURVE/AERIAL`, `GLOW`) set once. Built in
  `studies/endless_flight.gd` right after `EndlessLook`, which the title/menu
  world shares (same scene, same camera), so the title gets the look too
  (checked: `/tmp/look_clean4/title_clean.png`).
- Grade without a RenderingDevice: `CleanPost.available()` is false there
  (Compatibility), the pass is not made, the game runs without it. Compat also
  never builds `EndlessLook`, so the plain look is unchanged. Headless
  `--rendering-method gl_compatibility`: no errors (only the existing FSR1
  warning).

Near tufts calmed
- `scripts/endless/endless_patch.gd` `sunny_of` (and `patch_edge`, `PAINT_BIAS`,
  `PAINT_STEPS`): the tufts' baked tint now follows the ground's calmed paint:
  34 m clumps crisp at 1.5, 8 m clumps 0.18, wide 1.8, mid 0.36, bias -0.10,
  soft thirds at 0.92; no 5.5 m or 1.4 m scales (the tufts never carried them,
  the old mirror's soft 8 m clumps at 0.5 and mid 0.9 were the fine part).
  Root-dark to tip-light gradient and the 2 m tint grid are untouched.
- Ground under the tufts (`shaders/endless_ground.gdshader`, the `coarse`
  block, ~line 840): the same `sunny_c`, and its grain (`carpet_near_grain`)
  at 0.25, so tufts and ground agree where they meet.
- Placement, counts, seeds untouched.
- **Native kernels:** the tint is also computed in C++ (`native/terrain_kernels/
  grass_cell.h` `Patch::grass`). I edited it to match but have no scons or
  godot-cpp here, so it is NOT compiled or run. Until rebuilt,
  `endless_grass.gd` `SCRIPT_TINT := true` tells the native pass to carry no
  tint and lays it on in script (worker threads, per tuft). After a rebuild
  (`tools/build_native_kernels.py`) set it false. Per-cell cost of the script
  pass not measured; the frame time below includes it. A rendered check of the
  C++ version is still owed.

Numbers (grass median V / S, `tools/look_measure.py`, main `/tmp/look_now/`
vs `/tmp/look_clean4/`): cruise .608/.605 -> .604/.615; coast .655/.456 ->
.655/.462; hills .506/.503 -> .502/.508; meadow_low .490/.548 -> .518/.548
(+0.028, round 2 was .498: the tufts are a little brighter than main's);
high .510/.540 -> .518/.542. meadow_low std at 1-4 px: -4 % against round 2.
Stills match round 2/3 apart from the tufts. Dusk (`cruise_dusk.png`,
`--mood=rosewater_dusk`) follows the mood.

Frame time (`--print-fps --disable-vsync`, Forward+ 1440x900, title scene,
1500 frames, two runs each): main 22.2-23.8 ms mid-run, branch 22.2-24.4;
the same within noise.

Stills: `/tmp/look_clean4/` (meadow_low, hills, rock, coast, cruise, high,
cruise_dusk, title_main, title_clean). Title: the branch's grass is calmer
and a little hazier/cooler; the plane and menu read the same.

Existing tests this may break (none run; grep found no test reading the
removed globals, flags, `clean_look`/`clean_post`, edges or `EndlessPatch`):
`tests/test_ground_look.gd` and `tests/test_sky_peak_look.gd` read
`reference_surface.gdshader` as text (varying count, includes), which round 1
added an include and a uniform to; they are the ones to check. Nothing
compares shader output. Nothing tests the tuft tint colours; any colour test
of grass tufts on seed 1 would change.

Not done / limits: C++ edit uncompiled (above); other moods besides default and
dusk, winter and regions not re-checked; stills of the 6 views were taken with
the script tint path.

## Round 5: far grass as blades, calm far water, calmer blade lighting

Launch: `cd /Users/davidkalina/Documents/Projects/zenscape-look-clean && python3 tools/play.py -- --ledger=/tmp/look_clean_ledger.json`.
Stills: `/tmp/look_clean5/` (meadow_low, hills, coast, cruise, high; `far120.png`
120 m over open meadow looking out; `*_dusk.png` at `--mood=rosewater_dusk`;
`title.png`; `seq/high_0..3.png` the same high view 4 s apart). Compare with
`/tmp/look_clean4/`.

### 1. Far grass: a blade read on the sheen (`shaders/grass_sheen.gdshaderinc`, ground shader hook)
- Builds on the existing sheen (`grass_sheen`, same ring fade 28 to 85 m, same
  wave field `zs_sheen_field`, same wind globals), not a second sheen.
- `zs_blade_paint` (grass_sheen.gdshaderinc:116): three layers of streaks long
  along the wind (6x their width, each leaning a little off the wind so no grid),
  widths 1.3, 3.2 and 8 m (`BLADE_WIDTHS`, `scripts/endless/grass_sheen.gd:24`;
  uniform `grass_far_blades`, :95). Each fades to its mean when a pixel across
  the streak is wider than 0.3 of its width (full under 0.12): so none draws
  under about 3 px and none shimmers (`zs_blade_layer`, :98). The pixel width
  comes from `dFdx/dFdy` projected across the wind (`endless_ground.gdshader`
  ~line 881), not the paint's mixed footprint, so low views keep them.
- Light: lit streaks go toward a luma-keyed silver in the key light's tint
  (`zs_key_irradiance`, so dusk is warm) and `zs_cl_warm`; dark ones toward
  `zs_cl_cool`. Which face the eye gets is the sheen's `turn` (wind lean against
  sun and eye), so a field brightens and darkens as you fly over it. The sheen's
  crests (`s`) set how much the streaks show (`roll`, :132), so the waves roll
  through them with the wind; streaks stay put, the light moves.
- From high up the old sheen was 85 % off (`wc_up`, the watercolour paint). Now
  the swell tone keeps 40 % there (`endless_ground.gdshader` ~line 877) and the
  blades keep all of it.
- Knobs: `--blades=X` (0 off, default 1, `grass_sheen.gd:25`), the weights
  0.4/0.4/0.2 and the contrast 2.5 in `zs_blade_paint`, dark 0.14, lit 0.4,
  cool 0.3.
- Check: `seq/high_0..3.png`: the bright band moves with the wind, no flicker.
  A frame-diff or film was not made.

### 2. Far water
- Rivers and lakes (`endless_ground.gdshader`, `wet` block): from `WATER_FAR_BEGIN`
  90 m to `WATER_FAR_END` 300 m (:36) the ripple slope goes down 90 %, the
  streak lines, slicks and flecks fade, and a soft broad glint (`WATER_FAR_GLINT`
  exponent 28, strength 0.28; the sun's path off a calm level) comes in. Depth
  bands, banks and the shore line are as they were. Near water unchanged.
- Sea (`endless_sea.gdshader`, :37 `SEA_FAR_*`, same 90 to 300 m): chop detail
  down 90 %, swell slope down 50 %, foam lace x0.12 (was 0.4), the bed seen
  blurred (`SEA_FAR_BLUR`), the same broad glint; the wake keeps its own.
- Not fixed: the milky mottle over the shallows at the left of `high.png`
  (the sea shader's shallows over the sea-floor paint) is unchanged: with foam
  off and the bed blurred it stayed, so it is something else (the floor paint
  seen through thin water, or the ground's watercolour paint under it). Not found.

### 3. Calmer blades (`reference_surface.gdshader`, `reference_direct_light.gdshaderinc`)
- One uniform `grass_calm` (:132, default 1, blades only; `ZS_GRASS_CALM` is 0
  for everything else): blade normals lean 50 % toward up (:868), each tuft's
  own shade swings 60 % less (:972), the sun is pulled 75 % toward the mean a
  blade tilted 0.45 gets round the compass (`ZS_GRASS_PULL/TILT`, :1180) and the
  little shadows between blades soften 40 % (`ZS_GRASS_SOFT`). Root-to-tip
  gradient, translucency, specular and the sun side untouched.
- What I found, measured by taking terms out one at a time (meadow_low): the
  blades' colour (`own`) is nearly uniform across blades, the sun's banded
  diffuse is already on its plateau for almost every blade, and neighbours'
  shadows are not on the tufts. So there is little blade-to-blade lighting to
  take out and the user's "noisy grass" is mostly the blades' own shapes,
  overlaps and root-to-tip gradient. Removing the specular term made it worse
  (V -0.05, S +0.09). Tried and dropped: a sky-fill lift with the sun giving it
  back (V -0.024, std up), flattening `own` (kills the gradient).
- Result: small. meadow_low `local4` 0.028 -> 0.025 (-11 %), std at 1 px 0.0965
  -> 0.0965, at 4 px 0.080 -> 0.082; hills std1 0.1695 -> 0.163, std4 0.145 ->
  0.1375; cruise std1 0.095 -> 0.091; coast 0.058 -> 0.055. The title can't be
  A/B'd (its camera differs between runs): `title.png` looks calmer, std1 0.0955.
  If the user wants it much calmer, the next lever is the blades' shape and
  overlap (fewer, wider blades near, or a softer gradient), not lighting.

### Numbers
Grass median V / S (`tools/look_measure.py`), `/tmp/look_clean4/` -> `/tmp/look_clean5/`:
meadow_low .518/.548 -> .518/.528; hills .502/.508 -> .510/.500; coast .655/.462
-> .659/.444; cruise .604/.615 -> .604/.621; high .518/.542 -> .506/.538. All
within 0.03 (coast S -0.018, meadow_low S -0.020).
Frame time (`--print-fps --disable-vsync`, 1440x900 Forward+, title scene,
1500 frames, mid-run): before 21.7-26.3 ms (noisy, shader compile in the first
run), after 20.0-22.7 ms: same within noise. Not measured from the high view,
where the ground shader's new far work actually runs (about 3 x 2 noise reads
plus the sheen's, per grass pixel past 28 m).

### Unverified
- Dusk and one more mood only checked by eye (`*_dusk.png`); no winter, regions.
- The motion proof is four stills; the waves are soft from 260 m.
- The sea's new glint was not seen (the views have the sun off the water's path).
- Native kernels still uncompiled; `SCRIPT_TINT := true` left as is.
- Tests likely to break: those reading `reference_surface.gdshader`,
  `endless_ground.gdshader`, `endless_sea.gdshader` as text (`test_ground_look`,
  `test_sky_peak_look`); none run. New uniforms `grass_far_blades` (ground) and
  `grass_calm` (surface).

## Round 6: near grass as one mass, clean far shallows (far grass dropped)

Launch: `cd /Users/davidkalina/Documents/Projects/zenscape-look-clean && python3 tools/play.py -- --ledger=/tmp/look_clean_ledger.json`.
Stills: `/tmp/look_clean6/` (meadow_low, hills, coast, cruise, high, far120,
`*_dusk.png` at `--mood=rosewater_dusk`, `seq/far120_0..3.png` 0.75 s apart,
`title.png` with `title_main.png` and `title_r5.png` taken from the same
pinned camera). Trials are in `x/`.

### Title camera pinned
The title's spot is the same every run (seed 1: (108.8, 26.7), heading
-1.963), but the orbit's angle runs on from when the stage begins, so stills
differed. `scratch/title6.gd` (a throwaway driver, uncommitted) holds
`stage.angle` at heading + ORBIT_FROM and `stage.elapsed` at 4.5 s for the
whole hold: `python3 tools/drive.py scratch/title6.gd --rendered -- --out=F
--scene-args --title`. Main's title came from a `git archive` of main's HEAD
in `/tmp/main_ro` (the main checkout was only read), set up with
`tools/worktree.py`. The harness has no title-orbit flag; a `--menu-orbit=`
in `menu_stage.gd` would be the committed version.

### 1. Near grass: calm and deep
- What made it flat: round 5's blades were calm already (flicker at 1 to 4 px
  was about half of main's on the title) but the field had no lower mass. Each
  blade's lower 60 % takes the ground paint's colour (`grass_root_paint`, so
  no dark rings), and the turf under the tufts is that same light paint. So
  the field's floor, seen between blades, was as light as the blades
  (`title_r5.png`: light yellow-green under the plane and in every gap), and
  the clean look's soft banded sun gives the blades little light and shade of
  their own. It read as hazy. Main's depth came from blade-by-blade light and
  dark, which is the flicker.
- Fix (`shaders/reference_surface.gdshader`):
  - `grass_tone` (:821): the root-to-tip tone follows the height in the
    field (model-space height over `grass_mass_top`) rather than each blade's
    own length (`grass_mass`, :138). Blades side by side at one height take
    one tone. A short blade's tip is no longer as light as a tall one's. Used
    for the paint gradient, the root blend, the root paint and the contact
    term (:989, :992, :1018, :1146).
  - The mass shade (:1020): after the root paint, the tint goes from
    `grass_mass_shade` x a share of `zs_cl_cool` at the root up to
    `grass_mass_lift` at the field's top (smoothstep), so the lower field is
    darker and cooler as one mass and the tops stay light.
  - The turf under the near carpet takes the root's shade
    (`shaders/endless_ground.gdshader` `carpet_near_mass` :95, applied :872),
    so the gaps between blades show the field's dark floor, not light paint.
    It fades with `carpet_near` (16 to 30 m) and is off from high up (`wc_up`).
- Knobs: `scripts/endless/endless_grass.gd:261` `MASS` (follow 1.0, top 0.35 x
  tall = 1.4 m, shade 0.66, lift 1.1, cool 0.5), set in `_calm` (:1157) and on
  the ground (:766). By hand: `--grass-set=grass_mass_shade=0.75`,
  `--ground-set=carpet_near_mass=0.75,0.5`. The shader defaults are neutral,
  so every other user of `reference_surface` is unchanged.
- Tried and dropped: per-blade tone along the field's height alone (no
  visible change: the root paint covers the base); per-tuft brightness hash
  off (`grass_variation=0`, no change); fewer, wider blades (9 x 0.8 width, 2
  per satellite: flicker -6 %, but the near tufts read as reeds or leaves);
  `grass_calm=0` and the tip glow off (both minor). The mesh is unchanged, so
  there is no model-budget assessment to do.
- Not changed: the very dark olive tufts on the steep river bank in
  `meadow_low` (the land's thin-turf tint on steep ground, there on main too).
  They are now the strongest dark slivers in that view.

### 2. Far grass: dropped on purpose
Dropped mid-round at the user's request: the streaks read "a little streaky",
and round 7 will try fake depth with clumps and layered parallax blades
instead. A trial (sheen kept from high up, far boost 0.6, stronger and wider
streaks) was reverted. The far grass is exactly as round 5 left it.

### 3. Milky mottle over far shallows
- Reproduced in `high`; isolated with the sea's own uniforms
  (`--sea-set=bed_fade:0.001` hides the bed: clean bands;
  `--sea-set=bed_fade:100000.0;absorb:Vector3(0,0,0)` shows only the bed).
  `--no-clouds` changed nothing. Stills: `x/hi_base`, `x/hi_nobed`,
  `x/hi_bedonly`, `x/hi_fix1`.
- Cause: the bed seen through the sea (`seen * bed`). The seabed's lit relief
  (rills and streaks down the shelf) and its paint, seen through thin water at
  a share that follows each bump's depth, read from afar as a milky, cloudy
  mottle. Round 5's blur (`SEA_FAR_BLUR`, mip 4) is narrower than those
  streaks, so it stayed.
- Fix: `shaders/endless_sea.gdshader:47` `SEA_FAR_BED` 0.7, applied at :1067:
  over the far-water ramp (90 to 300 m) 70 % of the bed is taken away, and the
  column's banded colour shows instead. Near shallows (coast's lagoon) are
  unchanged. Inland lakes are the ground shader's water and were not changed
  (no mottle seen there).

### Numbers
Near grass (`scratch/grass_metric.gd`, run headless: flick = luma std at 1 to
4 px, mid = std at about 5 to 25 px, mass = p85 - p15 of the 6 px-blurred
luma; the title cropped below the logo, meadow_low below the horizon):

| still | luma | flick | mid | mass |
|---|---|---|---|---|
| title main | 0.466 | 0.0446 | 0.0465 | 0.226 |
| title r5 | 0.493 | 0.0248 | 0.0278 | 0.226 |
| title r6 | 0.442 | 0.0259 | 0.0281 | 0.210 |
| meadow_low main | 0.459 | 0.0529 | 0.0492 | 0.200 |
| meadow_low r5 | 0.488 | 0.0343 | 0.0375 | 0.172 |
| meadow_low r6 | 0.458 | 0.0327 | 0.0347 | 0.197 |

Flicker stays about 42 % (title) and 38 % (meadow_low) under main's. The
depth shows more by eye than in these numbers: the lower field is darker
than its tops, and nothing light shows through it.

Grass median V / S (`tools/look_measure.py`), r5 -> r6: meadow_low
.518/.528 -> .482/.521 (V -0.036, on purpose: main is .490); title (pinned)
.549/.577 -> .498/.590 (V -0.051, on purpose: main's is .502); hills
.510/.500 and cruise .604/.621 unchanged; coast .659/.444 -> .655/.444; high
.506/.538 -> .510/.538.

Frame time (`scratch/perf6.gd`, Forward+ 1440x900, vsync and the fps cap off,
the median of 400 frames after a 330-frame hold, wall clock; the Metal GPU
timer reads 0): `high` r5 11.3 to 11.8 ms, r6 11.3 to 11.8 ms; `far120` r5
18.0, r6 18.1; title r5 12.9 to 13.0, r6 12.5 to 13.3. All the same within
noise.

### Unverified
- One machine (Mac, Forward+). Headless smoke passes; the shaders only
  compile in rendered runs, which were clean.
- Moods: default and rosewater dusk only (`*_dusk.png`). No winter or
  regions. The isles' tufts are untouched (neutral defaults), but not
  rendered.
- The near ring's tufts against the far ring at 16 to 30 m: no ring seen in
  meadow_low or the title, but not checked in flight.
- `native/terrain_kernels/grass_cell.h` was not touched (nothing it computes
  changed); `SCRIPT_TINT := true` stays.
- Tests likely to break (none run): those reading `reference_surface.gdshader`,
  `endless_ground.gdshader` or `endless_sea.gdshader` as text
  (`test_ground_look`, `test_sky_peak_look`). New uniforms: `grass_mass`,
  `grass_mass_top`, `grass_mass_shade`, `grass_mass_lift`, `grass_mass_cool`
  (surface); `carpet_near_mass` (ground).

## Round 7: far grass as clumps with depth

Launch: `cd /Users/davidkalina/Documents/Projects/zenscape-look-clean && python3 tools/play.py -- --ledger=/tmp/look_clean_ledger.json`.
Stills: `/tmp/look_clean7/` (high, cruise, hills, meadow_low, coast, far120,
`high_dusk` / `far120_dusk` at `--mood=rosewater_dusk`; `dive/dive_0..8_H.png`
260, 200, 160, 130, 105, 80, 58, 38, 22 m over open meadow, `dive/sheetA.png`
and `sheetB.png` are crops; `seq/far120_0..4.png` and `seq/high_0..4.png`
40 frames (0.67 s) apart, `seq/sheet_*.png` crops). Compare `/tmp/look_clean6/`.
Throwaway drivers `scratch/dive7.gd` (dive) and `scratch/look5.gd --seq=5 --gap=40`.

### What it is (ground shader only, no geometry)
- `shaders/far_clumps.gdshaderinc` (new, included after `grass_sheen`),
  hooked in `endless_ground.gdshader` right after the sheen block (~line 893),
  gated like the sheen (`carpet_turf`, minus 60 % of `thin`).
- **Clumps:** three scales of jittered cells (`grass_far_clump_sizes`, default
  1.2 / 3.0 / 9 m; `grass_sheen.gd` `CLUMP_SIZES`). Each scale fades to its
  mean when a pixel nears a third of it (full under 0.15 x size, gone at
  0.36 x), so nothing under ~3 px; its weight (0.9 / 0.8 / 0.45, `zs_far_clumps`)
  is varied slowly over the meadow (`patch_k`, x0.6..1.4) so it is not even
  bubble wrap. Each clump: lit on its sun side (dome normal against
  `zs_sun_direction`), dark cool gaps (`zs_cl_cool`), a soft shadow on a
  clump's sun-facing edge (the neighbour toward the sun throws it), ragged
  blade tips on the height (finer noise, gone with the pixel).
- **Parallax:** `ZS_CLUMP_LAYERS` 6 layers marched under the surface along the
  view ray (`ZS_CLUMP_DEPTH` 0.9 m tall field; layer k reads the same clump's
  dome shifted by `(view.xz/vert + lean) * depth`, no new hashes), front to back,
  so tips cover the dark floor and hide each other at grazing angles. Lower
  layers darker and cooler (round 6's mass). The 9 m scale has no layers.
  `--clump-depth=X` scales the shift (0: sides and gaps only).
- **View angle:** `look` (0 along the ground, 1 straight down): floor 0.70 -> 0.60,
  lower layers cooler, a 1.2 -> 1.12 gain, and along the ground a +35 % saturation
  lift. Climbing and diving changes the read.
- **Wind:** `lean = wind_dir * (0.14 + 0.22 * s)` m per m of height, `s` the
  sheen's own wave field (`zs_sheen_field`, the near tufts' crests, gust
  bands and fronts), so direction and timing agree with the tufts. It moves
  the clump tops (`q` is taken at `p - lean * depth`), shifts the layers, and
  tilts the lit side. Texture only: flat meadows stay flat.
- **Light:** `zs_sun_direction`, `zs_key_irradiance` tint, `zs_cl_warm/cool`;
  dusk checked (`*_dusk.png`).
- **Handoff to the tufts:** the clumps come in over ring distance 150..240 m
  (`grass_far_clumps.zw`, `CLUMP_RING`), as the far ring's tufts thin out
  (LOD.z 150 to LOD.w 230, not the 100 m mesh morph, which is not where tufts
  end). The ring distance counts height, so from 200 m up it is on over all of
  the ground the tufts thin on. Tops are lifted and yellowed (+12 % at
  the top layers) toward the tufts' light.
- Round 5's streaks stay in code, off by default: `BLADES := 0.0`
  (`--blades=1` brings them back, `--clumps=0` removes the clumps).
- Knobs: `--clumps=X` strength, `--clump-depth=X`, uniforms
  `grass_far_clumps` (x strength, y depth, zw ring), `grass_far_clump_sizes`.

### Numbers
Grass median V / S (`scratch/gm.py` = `look_measure.py`), `/tmp/look_clean6/`
-> `/tmp/look_clean7/`: high .510/.538 -> .514/.563; far120 .549/.604 ->
.553/.599; cruise .604/.621 -> .616/.608; hills .510/.500 -> .510/.500;
meadow_low .482/.521 -> .471/.537; coast .655/.444 -> .651/.461. All within
0.03; high's S +0.025. (Before the lift tuning high was .455: the first version
read as moss; the deliberate darker-from-above is now mostly in the gaps, not the median.)
Frame time (uncapped wall ms per frame, median of 400, `scratch/perf6.gd`):
high 11.74 -> 14.28; far120 18.15 -> 19.86. About +2.5 ms from 260 m, where
the whole ground is far grass; the cost is 3 Voronoi + 6 layers per far grass pixel.
Cheap saves if wanted: 4 layers, drop the 9 m scale.

### Seen
- high: the meadow now reads as tufted grass with gaps, not a wash (it can
  still read a little like a rounded canopy from straight above; the sizes
  1.2/3/9 are what keeps it fine).
- Dive: smooth change from clumps (260, 200) to real tufts (160 and nearer),
  no line. At 200 m the clump zone is a touch darker and rounder than the
  tufts' spiky yellow-green; the 150..240 ramp softens it but it is still the
  one place two characters meet.
- Motion (far120 and high, 0.67 s apart): no flicker or shimmer; the bow is
  subtle (top shift 0.1..0.3 m on 3 m clumps).

### Unverified / not done
- Only default and rosewater_dusk moods; no winter, regions.
- Wind bow checked by stills only (no film); with a strong gust front the
  top shift is larger (s clamps at 1) and was not seen.
- `--blades=1` together with clumps was not looked at.
- Tests likely to break: those reading `endless_ground.gdshader` /
  `grass_sheen.gd` as text (`test_ground_look`, `test_sky_peak_look`); none run.

## Round 8: far grass as a fine lawn (replaces the clumps)

Launch: `cd /Users/davidkalina/Documents/Projects/zenscape-look-clean && python3 tools/play.py -- --ledger=/tmp/look_clean_ledger.json`.
Compare: `-- --lawn=0` (no grain), `-- --lawn=0 --clumps=1` (round 7), `-- --nap=0` (grain without nap and sheen).
Stills: `/tmp/look_clean8/` (high, cruise, hills, meadow_low, coast, far120,
`high_dusk` / `far120_dusk`; `crop_grain_260.png`, `crop_grain_120.png`;
`tile_far_turf.png` the baked tile, `tile_shade_crop.png` / `tile_height_crop.png` its R and G (512 crop);
`dive/dive_0..8_H.png` + `sheetA/B.png`; `seq/` 40-frame sets). `/tmp/look_clean8_off/` = same views with `--lawn=0`.

### The bake
- `tools/bake_turf.gd` (run: `python tools/godot.py --rendered --timeout 150 -s res://tools/bake_turf.gd [-- --preview=/tmp]`; a window for ~1 s).
  Lays 48 x 48 jittered cells (+2 duplicated border cells each side, drawn from the
  wrapped cell's own random draw so the tile is seamless) of the game's real soft tuft
  (`GrassTuftMesh.build`, scaled 5x, random yaw / size / shade) and draws them from
  straight above with an orthographic camera (MSAA 8x), unlit, in two passes:
  shade + height, then the blade's lean direction.
- `assets/textures/far_turf.png` (1024 px RGBA8, 2.2 MB, lossless, mipmaps on,
  `fix_alpha_border` off): R shade (mean 0.5; blade colour from the tuft's own root to tip,
  gaps dark), G height of the blade surface (mean 0.5), B / A the blade's lean on the ground
  (0.5 + 0.5 v; mips average it to "no lean" so far off the wind decides).
- Sampled `filter_linear_mipmap_anisotropic, repeat_enable`. The project does not set
  anisotropic level, so it is Godot's default (4x); left alone.

### Shading (`shaders/far_lawn.gdshaderinc`, hook `endless_ground.gdshader:899-904`, after the clumps)
- Gated as the sheen is (`carpet_turf`, minus 60 % of `thin`): grass only. Ring distance
  fade `smoothstep(140, 230)` (`grass_lawn.yz`, `LAWN_RING`), a little before the
  tufts thin out (150..230); full by 230 m.
- Scales: tiles of 64 m and 39 m (`LAWN_TILES`, `grass_lawn_tiles`; second turned 0.83 rad
  and offset). A blade is ~6 texels: 0.37 m / 0.23 m, about 1.5-2 px at 120 m. The two grains
  are summed (spread rescaled by 0.707) so no repeat shows, over the paint's own broad variation.
- Micro shadows: second sample 2..5.5 texels toward the sun (`reach`, line 43, longer at
  a low sun), `shadow = clamp((h_sun - h) * 3.5)`, darkens up to 30 % and cools; off at night
  (`day`). Gaps (low height) darker and cooler (`cool`), tips lighter and warmer (key tint).
  At mip level the offset samples agree, so shadows fade out without shimmer.
- Nap: lean = `zs_wind_direction` turned by `s * 0.9` rad, `s` = the sheen's `zs_sheen_field`
  x 1.7 (so gust bands, waves and fronts turn and lay it); per blade the texture's own
  lean is added. Shade `1 + 0.3 * nap * nap_k`, `nap` = dot(lean, view's flat direction):
  lighter looking along, darker against, along-side only 0.45 as strong (keeps a meadow from
  brightening as a whole downwind); `nap_k` grows with the laid-down amount (line 96).
  Soft sheen: Kajiya-Kay along the lean with the sun's half-vector, x 0.12 (line 105).
- Lift: x1.17 while the grain is seen (`seen_grain`, fp 0.15..1.3 m, line 88) because gaps
  and shadows take more than tips give; far off the mips are the mean.
- Knobs: `scripts/endless/grass_sheen.gd` `LAWN`, `NAP`, `LAWN_RING`, `LAWN_TILES`,
  `--lawn=X`, `--nap=X`, `--sheen-set=grass_lawn=...`. Clumps default `CLUMPS := 0.0`
  (`--clumps=1`; parallax code kept in `far_clumps.gdshaderinc`, unused by default, no cost).
  Round 5's streaks stay off (`--blades=1`).

### Numbers
Grass median V / S in the same view list (`scratch/l6.sh`), lawn off -> on: high .514/.554 ->
.482/.547; far120 .541/.589 -> .525/.587; cruise .624/.608 -> .620/.608; hills and
meadow_low and coast unchanged (.553/.431, .467/.538, .659/.447). Against `/tmp/look_clean6/`:
high -.028, far120 -.024, cruise +.016, meadow_low -.015 (all inside 0.03). Hills
reads .553/.431 against round 6's .510/.500, but that is with the lawn off too (round 7's
clumps had pulled it down; the lawn does not touch that view), so it is a round 7 baseline shift, not this round.
Frame time (uncapped wall ms, median of 400, `scratch/perf6.gd`, same run): high round 7
12.39 -> round 8 10.88 (round 6 was 11.74); far120 17.95 -> 17.87. 4 texture fetches
per far grass pixel instead of 3 Voronoi + 6 layers.

### Seen
- high: fine even grain of tiny blades, lawn-like, no cells or moss; no tiling visible at 260 m.
- Dive 260 -> 22 m: lawn into real tufts with no line or pop; at 260/200 the lawn is a
  slightly darker, cooler green than the yellower tufts at 160 (the one place the characters differ).
- Seq (0.67 s and 2.5 s apart): no flicker or shimmer. Nap bands are visible but gentle at
  high, clearer at 120 m; the long swell is slow.
- Dusk (rosewater_dusk) follows the light.

### Unverified / not done
- Judged by stills, no film; bands rolling in motion are inferred from sets 0.7 s and 2.5 s apart.
- Only default and rosewater_dusk moods; no winter or regions.
- Grazing-angle crispness depends on the default 4x anisotropy.
- Tests likely to break: those reading `endless_ground.gdshader` / `grass_sheen.gd` as text
  (`test_ground_look`, `test_sky_peak_look`); none run.
- Models budget: no model made; a texture only.
