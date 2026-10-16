# Look pass: cloud bounce and sky fill

Changed files:

- `shaders/look_fill.gdshaderinc` (new)
- `shaders/reference_surface.gdshader`
- `shaders/reference_direct_light.gdshaderinc`
- `shaders/folk_surface.gdshaderinc`
- `scripts/look_pass.gd`
- `project.godot` (two globals)

## What it does

Shaded rock and the isles' undersides went near black, because ambient light is off and the hemisphere fill alone is small on dark basalt. Two terms in `shaders/look_fill.gdshaderinc`, driven by the look pass:

- **Cloud bounce (`zs_look_bounce`, default 0.3).** The sunlit cloud sea lights faces that point down, in the cloud's own light (`zs_cloud_sun`, which turns to moonlight at night).
  - Weight by facing: 1 for faces pointing straight down, 0.25 for upright faces, 0 for faces pointing up.
  - Scaled by the cloud-sea strength, so it goes away with `--no-cloud-sea`.
- **Sky fill (`zs_look_fill`, default 0.8).** Adds more of the sky's hemisphere light, only in the sun's shade.
  - On land and rock (`reference_surface`): added in `light()` for the sun alone, gated by its real shadow (`ATTENUATION`), so it only lifts shade.
  - On the ruins' stone (`folk_surface` with `ZS_STONE_WEATHER`): that shader has no `light()`, so the fill is weighted by how far each face turns from the sun. It is off underground.

F6 (the look pass toggle) turns both off for a before/after. To try other strengths:

```
--look-bounce=N
--look-fill=N
```

## Proof

- Headless import is clean.
- Smoke check passed on `studies/aqueduct_isle.tscn` and `studies/zenscape.tscn` (400 frames, 0 errors).
- The rendered captures compiled the shaders with no errors.
- The six existing tests that read these shaders or globals:
  - `test_breeze`, `test_gust_fronts`, `test_meadow_flowers` and `test_sky_seasons` pass.
  - `test_lake_complete_lighting` and `test_lake_flash` skip headless (GPU), so they are unverified.
- No test breaks that I know of. The full suite was not run.

## Before/after stills

In `scratch/gfx/` (git-ignored), Ultra, 2560×1440, Alpine morning:

- `sheet-sw.png`: the south-west establishing view.
- `sheet-onfoot.png`: the on-foot view by the stair.

## Not done

- The plane, the airship and the folk don't take the bounce. They use `folk_surface` without `ZS_STONE_WEATHER`. Their bellies over the clouds would gain from it too.
- Night presets and other looks were not captured.
