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

## Pass 2: faceting and the shadow side

- **Planes.** `er_planes()` snaps the surface normal's azimuth (9 steps) and elevation (6) after a slow noise warp, so big forms break into flat planes that follow the form with wandering edges; each plane gets a random tone and warm/cool lean (by its step ids). On top, a 70 m cell tilts each plane (`rock_bump`), the 38 m cells tilt more than pass 1 did, and the 7.5 m facets tilt 3x more. Cell seams are thin violet cracks. All in the fragment shader from world position; no geometry, heights or collision changed. Planes fade as pixels widen (`er_keep`), snapped edges widen with footprint.
- **Shadow side.** Shadow tone is a slate-violet, not near-black; strata, lips (cool glint) and cracks (violet, not black) are kept in shade. `er_rock` has a new `out vec3 glow`: bounce light added to EMISSION (ground shader, times `rocky`), cool sky blue weighted by upward-facing and warm reflected light from below that is stronger low in the valleys (p.y + 40 under about 170 m), strongest on faces turned from the sun.
- **API change.** `er_rock(p, n, fp, sun, mossy, bumped, glow)`; a mesh that includes it adds `EMISSION += glow`. The ground shader does. Rock arches use the ground material, so they pick it up (checked in stills).
- **Flags and knobs.** `--rock-pass1` gives pass 1's look (uniform `rock_pass1`); `--old-rock` still gives the original. New uniforms `rock_facets` (1, 0 off) and `rock_bounce` (1, 0 off) beside `rock_bump`, `rock_paint`, `rock_moss`, `rock_size`.
- **Stills** (git-ignored, in the worktree `scratch/rock2/`): before is `p1_*.png` (pass 1) and after is `a6_*.png`, for `valley`, `range`, `wall`, `far`, `arch`, `shade` (the `span` shot is also there).
- **Verified:** headless smoke of `endless_flight.tscn` with no flag, `--old-rock` and `--rock-pass1` PASS; rendered stills judged by eye over six iterations.
- **Unverified:** GPU cost (one more 27-tap cell search at 70 m plus about 4 value noises on rock pixels; not measured); shimmer in motion (plane edges are contour lines of the interpolated normal, softened by footprint, not checked in motion); other seeds, night. The wall seen close still has a slightly ghostly look where lit tan and shaded slate planes overlap softly, and faint horizontal moire from the 2 m beds at grazing angles (also in pass 1).
- No tests added or run.

## Rock decision and ruin stone

Pass 2 stays the rock look. Later tries (pass 3's hard planes, a
Poly Haven textured material, and a stylised version of it) live
unmerged on branches `endless-rock-planes` and `endless-rock-material`
(handoff sections there) for reference.

The ruin arches take an endless-only copy of the kit's stone material,
lifted and warmed so they read as sunlit stone instead of near-black
(`_sunlit()` in `scripts/endless/land_arches.gd`). The kit's shared
material, the isle and the motif editor are untouched.
`--old-ruin-stone` keeps the dark kit stone.
