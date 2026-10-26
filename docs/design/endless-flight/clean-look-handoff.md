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
