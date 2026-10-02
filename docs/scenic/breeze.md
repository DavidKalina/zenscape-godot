# The breeze: ambient foliage wind

The user didn't notice the foliage swaying. The wind was there, but at the diorama camera's distance it moved things by about a pixel.

## Why nobody noticed

**Default air.** A generated world draws its wind dial from 0.15 to 0.65 (0.4 on average). A Genesis plain draws it from 0.15 to 0.35. Living weather keeps it within 0.12 to 1.4. The shaders got `zs_wind_strength`, which is the dial times `gust_at(t)`. That factor averages 0.68 and swings 0.16 to 1.2 every few seconds, with the whole land in step. So with the dial at 0.4, `zs_wind_strength` averaged **0.27** (0.09 to 0.44). The plain filmed below published 0.19.

**Response.** Plant lean went with the *square* of that strength, times source sway constants of 0.012 to 0.07. At 0.27 the square is 0.07, so the lean all but vanished. What motion was left came from small fixed-frequency flaps.

**Tip movement at a dial of 0.4,** modelled from the shader formulas over 600 s and 3,000 roots. "Swing" is how far the tip travels within 6 s (peak to peak):

| Plant | Tip offset, mean (p90) | Swing in 6 s, mean (p90) |
| --- | --- | --- |
| Grass tuft, 0.35 m | 1.4 cm (3.3) | 4.3 cm (6.5) |
| Flower | 0.5 cm (0.9) | 1.5 cm (2.2) |
| Broadleaf crown, 2.4 m | 0.9 cm (1.6) | 2.8 cm (4.2) |
| Layered tree, 6 m | 1.8 cm (3.1) | 4.2 cm (6.1) |
| Conifer top | 4.2 cm (7.0) | 4.0 cm (6.3) |

At 23 m with the 45° lens, one pixel of a 1080-line view is about 1.8 cm. Flowers and crowns moved less than two pixels.

## What changed

**One breeze for plants: `zs_breeze`.** This is a new shader global, published by `studies/atmosphere.gd` as `breeze()`. Water, fog, pollen and clouds still read `zs_wind_strength`, so the water look is unchanged.

- **Floor.** `breeze_air(air) = sqrt(air² + 0.35²)` (`BREEZE_FLOOR`). A dial of 0 gives 0.35, calm (0.15) gives 0.38, the default 0.4 gives **0.53**, brisk (0.8) gives 0.87, a gale (1.3) gives 1.35 and a storm (2.5) gives 2.52. The order of the dial is kept, and strong air passes through almost unchanged.
- **Slow breathing.** `breeze_swell(t)` replaces `gust_at`'s quick, in-step pulse. It is three sines of 53 s, 23 s and 9.7 s (shares 0.2, 0.13 and 0.07), averaging 1 and ranging 0.6 to 1.4. It changes by at most about 10 % a second; `gust_at` changes by up to 88 %. Local variety comes from the travelling fields below, not from the whole land pulsing.
- **Published value.** It runs on the atmosphere's wind clock (`_wind_time`), so it holds while paused and is the same at any frame rate. The stroke feedback's `swell` still stirs it.
- **Default.** With the dial at 0.4 the breeze is **0.53** (0.33 to 0.75). Before, the shaders saw 0.27. The plain in the capture shows 0.48 at a dial of 0.23.

**Shared lean: `zs_breeze_lean_wave` / `zs_breeze_lean_at` (`shaders/reference_wind.gdshaderinc`).** This is a lean in `zs_blow_at`'s units, where 1 lays a small plant over by about 45°.

- The formula is `breeze × (0.10 + 0.5·g² + 0.42·crest·wave) × band`, then eased off toward 0.9 (`ZS_BREEZE_MAX`).
- `g` is the existing gust field (`zs_breeze_field_at`, which includes the resident's puffs).
- `band` is new: `zs_gust_band_at`, 0.6 to 1.5. These are slow gust bands about 30 m along the wind and 18 m across, rolling with the air. The strong ones are rare.
- `crest` is the meadow wave, `zs_wave_crest_at`. It now has 9 m crests (was 6.5) and a second, longer train 24° across the first. Wander noise is bent harder, and the edges are soft (smoothstep) instead of a narrow squared crest. Crests swell and wander instead of marching in stripes.
- `wave` is how much of the meadow wave a plant rides: 1 up to 0.7 m tall, 0 from 1.8 m. Grass and flowers roll with the waves; trees take only the gusts and bands.
- `bow` (0..1) is how far a plant is bowed. Grass pales by it.

**Hierarchical bend: `zs_breeze_offset` / `zs_breeze_bend`.** These have the same arguments as `zs_blow_bend`, plus `flex`, `flutter_share` and the out values `gust` and `bow`.

- **Stiff at the root.** The bend follows (h/span)². Big plants give less: `zs_blow_give^1.5`, which is 1 up to 0.5 m and about 0.16 from 3 m. Trunks barely move and crowns sway.
- **Lag.** Each vertex reads the air from `0.3 s × span m × k` ago, where k is its share of the way up. A crown top trails its trunk by about 0.6 s and a 7 m spruce top by about 2 s.
- **Sway at the plant's own pace.** The pace is `2.6/sqrt(span)` rad/s: 0.7 Hz for a tuft, 0.3 Hz for a crown and 0.16 Hz for a spruce. The swing is ±40 % of the lean, with the tip a beat behind (phase −0.9·k), so it bends like a whip, not a pendulum. Phase also varies by root, and there is a slow wander across the wind at 22 % of the lean.
- **Flutter.** A quick 11 rad/s tremble works on the outer 45 % of the plant (`flutter_share`). It is about 1 to 2 cm on a tree, depends on position only (so faceted meshes don't crack), and grows with `gust`.
- **Species.** `zs_breeze_flex(sway_shape.z)`: stiff shrubs and reeds (0.012 to 0.018) take about half the lean. `zs_breeze_flutter` scales their flutter.

**Where it is wired:**

- `reference_surface` sway: tufts, flowers, shrubs, reeds, bank grass, fern and broadleaf crowns.
- `reference_surface` and `layered_tree_wood` trunks (`blow_enabled`): they now take their crown's breeze over the crown's `blow_shape`, so trunk and crown never part.
- `layered_canopy_surface`.
- `conifer_wind.gdshaderinc`: trunk and crown together, with rim flutter.
- `dense_grass`: its `wave_*` uniforms are now the shared wave.

`sway_frequency` is no longer read by these shaders.

**Sheen.** `ZS_GRASS_WAVE_SHEEN` and dense `wave_sheen` went from 0.22 to 0.34, driven by `bow`, so bowed blades pale by up to a third. Before, it worked out to about 4 % at the default air. Classic tufts (the default tier) have no blade sheen, so the swaying plants' `foliage_gust` now takes `bow`, and the shared plant tint lift is 0.16 (was 0.10).

**The wind tool is unchanged.** `zs_blow_bend` still adds on top. A full gust leans a tuft about 45°, roughly five times the breeze's typical lean, so it still reads strongly.

## After

These are the same model and roots as the table above. They come from the shader formulas, not from GPU readback.

| Plant | Air 0.4: tip mean (p90) / 6 s swing | Calm 0.15 swing | Storm 1.4 swing |
| --- | --- | --- | --- |
| Grass tuft, 0.35 m | 6.8 cm (12.8) / 11.0 cm | 8.0 cm | 23.9 cm |
| Flower, 0.3 m | 5.8 cm (11.0) / 9.5 cm | 6.9 cm | 20.5 cm |
| Stiff shrub, 0.3 m | 3.1 cm (5.8) / 5.0 cm | 3.6 cm | 10.9 cm |
| Broadleaf crown, 2.4 m | 9.7 cm (17.3) / 9.8 cm | 6.7 cm | 27.5 cm |
| Layered tree, 6 m | 10.8 cm (19.4) / 9.8 cm | 6.6 cm | 28.1 cm |
| Conifer, 7 m | 13.7 cm (24.6) / 12.2 cm | 8.2 cm | 35.4 cm |
| Conifer, 4.3 m | 8.5 cm (15.2) / 7.9 cm | 5.3 cm | 22.3 cm |

At the default air that is 2 to 3 times the old swing, about 5 to 7 px at 23 m. A strong band can briefly push a crown top to 0.5 m. A storm moves about 2.5 times as much as the default.

## For new plants (flowers)

Include `reference_wind` (and `grass_look` after it if you want the grass look). Then:

```glsl
float gust; float bow;
VERTEX += zs_breeze_bend(VERTEX, MODEL_MATRIX, stem_base, stem_top, 1.0, 1.0, gust, bow);
VERTEX += zs_blow_bend(VERTEX, MODEL_MATRIX, stem_base, stem_top, shiver);
```

Then add the head nod and petal flutter from `gust` (0..1, how hard the air is on it) and `bow`. Plants under 0.7 m ride the meadow waves on the same crests as the grass, through `zs_grass_offset`, which is now declared in `reference_globals`. All the older names are unchanged: `zs_breeze_field`, `zs_gust_pulse_at`, `zs_gust_push_at`, `zs_grass_crest`, `zs_blow_bend` and `zs_blow_give`. `zs_grass_crest` keeps its signature but now returns the softer, wider shared crest.

## Checks

- `tests/test_breeze.gd` (headless) covers:
  - the floor and the default 0.53, and that `zs_breeze` is registered in `project.godot` at that value;
  - the dial order, storms at more than 2.5 times calm, and calm below 75 % of light;
  - swells within 0.6 to 1.4, averaging 1, changing under 12 % a second, and lulling or swelling by over a third within 20 s;
  - the same breeze and air travel at 60 fps and 1 fps, and pause holding;
  - the shared function names, every foliage shader reading the breeze rather than `zs_wind_strength`, and no new varyings in `reference_surface` (Metal's limit, 4b6508e).
- The GPU tests now set `zs_breeze` where they set `zs_wind_strength`: `test_conifer_wind`, `test_scene_wind_direction`, `test_local_wind_foliage`, `test_foliage_tread` and `test_tree_degrowth`. `test_scene_wind_direction` now draws one stem at one root, plain and then turned, because the breeze differs from root to root. These need a GPU and were not run.
- `tools/film_breeze.gd` films a grown Genesis plain at 30 fps.

## Unverified

- One rendered capture compiled the changed shaders on Metal without errors: `captures/breeze/breeze-plain-seed7.mp4`, 8 s, seed 7, air 0.23, breeze 0.48. Frames 1.5 s apart differ (PSNR 29 dB).
- The plate grew mostly trees, so grass waves and sheen are barely in shot. The meadow look needs a grassier world.
- The `foliage_gust` / 0.16 tint change was made after that capture and has not been compiled.
- Dense grass is retired from the default tier, so its changes were not drawn.
