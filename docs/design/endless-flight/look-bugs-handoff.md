# Look bugs: handoff (2026-10-25)

Three bugs from the look driver's stills of seed 1
(`tools/harness/look_views.gd`, views `high` and `coast`). Branch `look-bugs`.
Stills are in `/tmp/look_bugs/`: `before/`, `after/` (high, coast, cruise),
`repro/` (main, all seven views in the driver's default order).

## 1. White triangles in a sandy haze (`high`): fixed

- **What they are.** The sandy haze is a low cumulus growing below the
  camera (it only shows after about 35 s of cloud clock, which is why
  `--views=high` alone at 300 frames doesn't show it; `--cloud-clock=30`
  shows it straight away). The triangles are the wood's spruce sprites seen
  through that cloud.
- **Cause.** The forest floor (`shaders/endless_forest_floor.gdshader`) is
  see-through (`blend_mix`) with render priority 0, so it drew *after* the
  clouds' screen sheet (priority -6, `scripts/endless/endless_clouds.gd`
  `RENDER_PRIORITY`). It painted itself over the cloud wherever no crown
  stood in front of it, and the tree shadows it receives came through as
  well. That left the cloud looking thin and dark over the wood, and the
  sprite pixels (where the floor was depth-tested away) as pure cloud: pale
  triangles. How I proved it: `--no-forest-floor` and a debug composite
  showing the cloud's cover both took the triangles away. `--cloud-full-res`
  and `--no-valley-fog` changed nothing.
- **Fix.** `scripts/endless/land_trees.gd:107` `FLOOR_PRIORITY := -7`, set
  on both floor materials in `_floor_shader` (`:378`). The floor now draws
  between the sea (-8) and the clouds' sheet (-6).
- **Stills.** `before/high_clk30.png` vs `after/high_clk30.png`.

## 2. Hazy near grass (`coast`): deliberate, not changed

- **What it is.** Valley fog drawn by the cloud march
  (`shaders/endless_cloud_march.glsl` `fog_at`). The camera stands 25 m
  over the river valley's floor at the start spot (0, 40). There the fog
  map (`EndlessClouds.fog_image`) gives the valley about 0.6 fog (inland
  0.55, mountain 0.48). The layer is about 35 m deep, so the eye is inside
  the bank. The default soft look (`fog_look.x` = 0.8, the floor share)
  keeps the fog almost as thick at the ground as above it, so the near
  grass is seen through it. Depth fog starts at 120 m and plays no part.
  `--no-clouds` gives crisp grass, and the debug composite showed the cover
  as entirely the fog's share.
- **What would change it.** `endless_clouds.gd:223` `fog_look.x`, which
  thins the fog near the ground (`--fog-look=0.12,0.35,0.6`: see
  `coast_floorshare012.png`, clearer but still a little hazy because the
  eye is in the layer). Also `--valley-fog-depth=M` (`FOG_DEPTH` 40), the
  march's near ramp `sstep(1.0, 12.0, tf)`, or the fog map's `amount`.

## 3. Jagged grass lip on the sand bank (`coast`): fixed

- **Cause.** Not the turf lips (`scripts/shared/turf_lips.gd` is used only
  by the islet, not by the endless land) and not the tufts (`--no-grass`
  keeps it). It is the ground shader's paint. On steep ground, the noise
  is sampled at `gxz = p.xz + shear * p.y * k`, where `shear` ramps with the
  interpolated normal. Where the slope turns (a bank's lip), `shear`
  changes across a triangle, and the sample point moves by that change
  times the world y. At y -37 that is about 0.3 m per 1% of shear. The
  noise raced past in stripes that follow the normal's contours, which
  zigzag along the triangles. A variant with no shear made the lip clean;
  a footprint-only fix (fading the noise by gxz's own derivatives) left
  big zigzags.
- **Fix.** `shaders/endless_ground.gdshader:586-592`: shear by the height
  over the sea (`p.y - sea_y`), not the world's y. The shear's slant on a
  wall stays the same. Only its pivot moves, so the warp term is small on
  low land by the sea.
- **Stills.** `before/coast.png` vs `after/coast.png`.

## Unverified / left

- Fix 3 scales the warp with height over the sea, so a sharp grass crease
  high inland (100 m or more over the sea) could still stripe. I didn't see
  it in the `hills` or `rock` stills. A full fix would blend two samples
  (flat and sheared) rather than one blended coordinate, which costs every
  paint noise twice. The paint on sheared slopes is shifted by up to
  40 m x 0.8 compared with before. It has the same character, but the
  spots are in new places.
- Other see-through things that hug the land (stream water, ponds) may
  draw over a low cloud the same way; not checked.
- Untouched: a dark stair-stepped line along the far edge of the same
  sand bar against the sea, in the `coast` view, which was there before.
- GPU-only: all three need a rendered run. Headless smoke passed.

## Files touched

- `scripts/endless/land_trees.gd` (fix 1)
- `shaders/endless_ground.gdshader` (fix 3; the `look-clean` branch also
  edits this file: the change is the few lines at the `gxz` shear)

No existing test references the changed lines; none known to break. Full
suite not run.
