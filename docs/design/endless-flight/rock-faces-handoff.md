# Endless flight, rock faces round

The ask: the mountains' and valley walls' rock was "super blurry and ugly"; make it beautiful, relatively detailed, painterly.

## Launch

- `godot --path . res://studies/endless_flight.tscn -- --no-title --seed=1 --at=400,-1065 --heading=22 --alt=35` (a valley wall); `--at=-700,-300 --heading=66 --alt=90` (a range); `--at=-760,-420 --heading=40 --alt=45` (a wall up close).
- `--old-rock` gives back the earlier rock for comparison.
- Stills (before is `--old-rock`): `scratch/rock/before_{valley,range,far,wall}.png` and `scratch/rock/a_*.png` (git-ignored, in the worktree).

## What changed

- **Cause of the blur.** The rock's beds and grain, and the grass patches on steep ground, were noise on world x,z, so on a wall they stretched down it into smears; the beds were smooth value noise (no edges); the rock-to-turf fade ran long across a wall's curved foot.
- `shaders/endless_rock.gdshaderinc` (new): `er_rock(...)`, all world-space 3D (no projection, so no stretch at any slope). Warped, tilted strata at 18, 6.4 and 2.2 m, each bed with its own tone and warm/cool hue, a dark seam at its foot and a pale lip on its top; dry-brush strokes along the beds; broad soft down-face streaks; vertical joints between blocks (steep faces only); 38 m and 7.5 m cells that tilt the lit normal a little (planes catching the sun); light painted in steps from a cool shadow tone to a warm lit one; turf and moss settling where the face lies back. Every scale fades to its mean where a pixel is wider than it (`er_keep`), so far rock is the near rock's average and nothing shimmers.
- `shaders/endless_ground.gdshader`: calls `er_rock` where `rocky`; the rock edge is crisp and ragged (3D noise tongues) rather than a long fade; on steep turf the grass patches sample a height-sheared point (`gxz`, 0 on ground flatter than n.y 0.93, so the tufts' tint still matches) and a pixel's size is its 3D one; the lit normal carries the facets. Snow, beach, carpet and flowers are untouched. Uniform `old_rock` (set by `--old-rock` in `endless_look.gd`) restores the old paths.
- Land shape, collision and the field are unchanged.

## Knobs

`rock_bump` (facet tilt, 0.55), `rock_paint` (painted light share, 0.75), `rock_moss` (1), `rock_size` (pattern scale, 1) on the ground material (`look.ground.set_shader_parameter`). Palette consts `ER_*` at the top of the include.

## Reuse for rock meshes (arches)

```
#include "res://shaders/endless_rock.gdshaderinc"
// vertex: pass world_position and world_normal as varyings
// fragment, top level (derivatives):
float fp = er_footprint(world_position);
vec3 lit_n = n;
ALBEDO = er_rock(world_position, n, fp, zs_sun_direction, MOSS_COLOUR, lit_n);
NORMAL = normalize((VIEW_MATRIX * vec4(lit_n, 0.0)).xyz);
```
It needs only `zs_sun_direction` (global) and no other uniforms of the ground shader (its own `rock_*` uniforms have defaults). A mesh at the same place gets the same strata (they key on world y), so an arch standing in a wall matches it. Roughness/specular as the ground: ~0.85 / 0.3.

## Verified

- Headless import 0 errors; smoke of `endless_flight.tscn` with and without `--old-rock` PASS.
- Rendered stills (valley, range, far, wall, a 12 m skim) judged by eye, several iterations.
- Unverified: GPU cost (not measured; the include runs two 27-tap 3D cell searches and about 12 value noises only on rock pixels, and the fine cell pass drops out past ~35 m); no shimmer check in motion; other seeds and moods (night) not looked at.
- No tests added or run. Known weakness: the mesh's smooth normals mean walls' big shading stays soft; the near wall foot's fillet still reads soft in places.
