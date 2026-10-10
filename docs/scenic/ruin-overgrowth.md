# Ruin overgrowth: handoff

Branch `look/ruin-overgrowth` (from main 79398f2e). Not merged to main.

The ask: overgrowth on the ruin kit, like vines, that animates and reacts to the wind. The user's verdict on the first pass: it "looks absolutely fantastic right now". Keep going in the same direction.

## What was built

- **Growth on its own surface.** Everything the kit grows (ivy strands, leaf mats, ground spreads, tufts, moss cushions and the new vines) is drawn as a second surface of each ruin mesh in `shaders/ruin_growth.gdshader`. The stone stays surface 0 in `ruin_stone.gdshader`, unchanged. `RuinKit.merge` carries the growth into the merged mesh as one second surface, so a hall or a run is still one mesh: two surfaces, two draw calls (plus their shadow passes) instead of one.
- **A wind shader in the grass's air.** `ruin_growth.gdshader` includes `reference_wind`, `grass_look` and `foliage_tread`. It reads the same breeze (`zs_breeze_lean_at`: the gust field, gust bands, gust fronts and the ribbons' wake), the wind tool (`zs_blow_at`), the local gusts and the pilot's tread wake as the grass does.
  - Motion is weighted by distance from the anchor. A strand bends as `(reach / length)^1.5`: the root is pinned to the stone and the tip swings most. The tip lags the air at the anchor (`ZS_BREEZE_LAG` per metre) and swings at a hanging rope's pace (`zs_breeze_pace(length)`), a whip rather than a pendulum. It rises as it swings, so it keeps its length.
  - Strands pressed to a face slide along it and peel off it, never into it, and give `pressed_give` (0.45) of a free strand's motion.
  - Leaf clumps flutter on top, each with its own phase, harder in a gust. Mats on tops only flutter a little. Moss cushions never move.
  - In a gust the leaves turn paler (their backs), as bowed grass does.
- **Light.** Faceted shapes, soft light. Each leaf keeps its cut silhouette but lights from its strand's facing (`soft` 0.6), not its facets. The hemisphere fill and the halls' shelter bounce are as the stone's. There is a root-to-tip gradient (`root_shade`, `tip_lift`), and grass_look's tip translucency glows when backlit. Nothing glows otherwise.
- **Vine curtains** (`scripts/ruin_growth.gd`, new). Every free strand a piece asks for with `Build.hang` is now a curtain: a row of up to 11 strands (5 on lean stone) under the underside over it. The row runs the way the underside runs (the soffit, beam or deck, found by probing for stone overhead), each strand finding its own underside. Strands are longest in the row's middle, with ragged tips, and hang 1.8 × the asked length + 0.6 m (at most 6 m and never into the floor). That covers the arches, lancet windows, rose, vault, aqueduct arches and decks, and hall bays (beams and roof).
  - Each strand is a thin three-sided stem strung with small folded leaves (two triangles each) at nodes every 8.5 cm, alternating sides. They are dense at the root and thin to a bare **tendril** (its last 20 %) with a few small leaves and a curl at the tip. Leaf greens are a little fresher than the ivy's, lighter toward the tip.
- **Wall-head fringes.** A few rows (up to 6, or 2 on lean stone, by the high tops' area and the weathering) of 4–9 strands are draped from wall heads whose face falls away under them. They hug the face, pushed out round what stands proud, and hang free where it overhangs, 1.6–5 m long.
- **The plane and the pilot push curtains** (`scripts/ruin_growth_push.gd`, new). Whoever moves near ruins calls `RuinGrowthPush.stir(id, world_position, delta)` once a frame. It keeps a short trail and writes the strongest four points to the growth's one shared material (`pusher_at` and `pusher_way`, 4 × vec4 each).
  - Where the pusher is now shoves strands along its way and out from its path. Where it has just been swings back past rest and settles (the wind tool's damped swing), so a curtain flown through billows and falls back.
  - There is no per-strand CPU work: it is 8 vectors a frame.
  - It is wired into the game in `scripts/wanderer_eye.gd` (two lines: the plane after `RopeBridge.flown_by`, the pilot in `_tread`) and into the gallery's fly mode.
  - The pilot on foot also already parts low growth through the existing tread wake (`zs_tread_*`), which the shader reads.
- **set_detail and lean.** Curtains are thinned by `Build.detail` (by index, so the seed's draw is kept) and fringes by count. Detail 0 grows nothing. Lean stone gets fewer strands, one leaf per node, and leaves and steps 1.6× bigger.
- **Collision is unchanged.** Growth is never collided. All growth is built in `finish`, after every stone block, so hulls are identical with or without the vines (tested).

## Edits to the kit (kept surgical)

`scripts/ruin_kit.gd` only, in about 70 lines:

- `Build.grow` (the attrs of the growth being built) and `Build.growth_face`.
- `solid` tags its pending face with `grow`, and `_draw` routes tagged faces to `Build.growth` via `RuinGrowth.emit`.
- `finish` calls `RuinGrowth.fringes` and adds the growth surface.
- `_ivy`'s free-strand loop is replaced by `RuinGrowth.curtains`.
- `_strand`, mats, spreads, `tuft` and `_cushions` set their `grow`.
- `merge` and `forget_arrays` carry the growth.
- `materials()` gains `growth`.

`ruin_kit_aqueduct.gd` and `ruin_kit_hall.gd` are untouched. The new geometry lives in `scripts/ruin_growth.gd`.

Per-vertex data (see the shader's header): UV = (reach from the anchor in m, negative for an upright tuft; the strand's length), UV2 = (the clump's phase; flutter), CUSTOM0 (RGBA float) = (the face it lies on x, z; how free; colour share root→tip). Vertex alpha is still the shelter amount.

## Flags and keys (gallery)

```
./run-ruin-kit.command [--still] [--no-vines] [--gust=s] [--breeze=x]
godot --path . res://studies/ruin_kit_gallery.tscn -- --no-title --capture=out.png --frames=60 --frame-step=0.1 [--gust=2]
```

- **V**: the growth in the wind or held still (compare). **B**: send a strong gust front across the view now. Both also work in fly mode (G). The label shows "growth in the wind / still".
- `--still` starts held still. `--no-vines` builds without curtains and fringes (the old ivy and moss only).
- `--gust=<s>` sends a strong front at that many seconds. `--breeze=<x>` sets `zs_breeze` (default 0.53, the game's default air).
- `--frames=<n>` with `--capture`: n half-size frames, each exactly `--frame-step` s of scene time apart, saved as `<capture>_000.png` and on. Turn them into a GIF with ffmpeg.
- The gallery now runs the game's air as `studies/atmosphere.gd` does: the air's travel (`zs_gust_distance`), gust fronts every 12–30 s (`studies/gust_fronts.gd`) and the breeze's lull before a front. Fly mode pushes curtains as the game does.

## Cost

Triangles, from `tests/test_ruin_growth.gd` and a one-off measure against main's `ruin_kit.gd`:

| Build | main | now | change |
|---|---|---|---|
| 12-bay hall, seed 12, weathered 0.6, in-world detail 0.25 | 88,524 | 90,532 (stone 79,938 + growth 10,594) | +2.0k (+2.3 %) |
| 12-bay hall, seed 12, weathered 0, in-world | 78,382 | 78,356 | ~0 |
| Aqueduct span, seed 1, weathered 0.55, detail 1 | 32,402 | 38,290 | +5.9k |
| Aqueduct span, seed 1, weathered 1, detail 1 | 44,287 | 50,784 | +6.5k |
| Gallery run (head + 4 spans), in-world detail | 67,325 | 73,333 | +6.0k |
| Gallery run, detail 1 | 140,420 | 160,888 | +20.5k |

- The hall stays under `Hall.BUDGET` (100k) at in-world detail (the kit's `_budget` check).
- **Draw calls:** each ruin mesh (a piece, a merged hall or run) draws 2 surfaces instead of 1, so it costs +1 draw call and +1 shadow-caster draw per mesh. A merged 12-bay hall goes from 1 to 2, and so does a merged aqueduct run.
- The growth material is one shared ShaderMaterial, so it batches with nothing new. The vertex shader evaluates the breeze per vertex, as the grass does.
- Frame times were not measured meaningfully: this machine was shared with several other Claude sessions during the work, so any frame-time numbers would be noise. Triangle and draw-call counts are exact.

## Checks

- `tests/test_ruin_growth.gd` passes headless. It checks:
  - Two surfaces (stone, then growth in its material) with per-vertex wind data.
  - No vertex reaches past its strand, roots are pinned, and curtains hang free over a metre.
  - Moss is still.
  - set_detail thins the growth and 0 grows none.
  - Collision and stone are identical with or without the vines.
  - A merged run keeps one growth surface.
  - Prints the costs above.
- `tests/test_ruin_kit.gd`: its "nothing glowing" check now allows the growth surface as the second surface.
- `tests/test_ruin_kit.gd` and `tests/test_sundered_hall.gd` pass headless. The import check is clean.
- Rendered captures (gallery, `--no-title`): stills and a 60-frame sway sequence with a forced gust (see the report).

## Open issues

- **Only the gallery's fly mode exercises the plane push.** It is wired in the game (`wanderer_eye.gd`) but not flown by hand there. The pilot's push in the game runs through `_tread`, so it is only live where the tread runs (the plate and perches).
- **The push clock** advances with every `stir`. With a plane and a pilot both stirring in one frame (never today) it would run double. A pusher that stops stirring fades only while someone else stirs or `settle` runs. In the game, if nothing stirs any more, its last push holds (in practice the last push is near zero, as it is speed-based).
- **Free curtains light from one facing** (across their row), so the back of a curtain lights as its front. That is fine at play distance but flat up close in raking light.
- **The pilot's tread** (`zs_tread_push`) is 2D, so it parts growth at any height over his path, including curtains well above him. It is weak at curtain heights (radius ~0.5 m), but it is not height-aware.
- **The halls at in-world detail** get few curtains (detail 0.25 keeps about a quarter of the hangs). The flown lane may want more. They would cost about 1–1.5k triangles per curtain.
- **Growth shares one material**, so V (wind off) holds every ruin's growth still, by design for the gallery.
- **Vines don't yet trail along the ground** or climb columns as spirals. Columns get the ivy's strands only.
- **Far LOD:** none for the growth yet. A far hall would use detail 0 (no growth).

## Next steps

1. Fly the long hall by hand (G) and through the aqueduct arches, and tune `pusher` reach and strength (`KINDS` in ruin_growth_push.gd) by eye.
2. Tune the motion by eye at play distance (`sway_gain` 1.25, `swing_share`, `calm_sway`, `flutter_gain` on the material). It was set strong first, per the user's preference.
3. More curtains in in-world halls (a floor on the curtain count independent of detail, under the budget).
4. Height-aware pilot push: the pilot's 3D pusher already exists, so the tread term could be dropped for strands far above the ground.
