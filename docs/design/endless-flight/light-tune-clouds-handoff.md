# Endless flight: light tune and living clouds (look round)

## What changed
**Light** (`shaders/endless_post.glsl`, `scripts/endless/endless_post.gd`)
- Shade sides: a sky fill and bounce added in the shade (`lift`, per mood), proportional to the surface's own colour plus a cool floor, scaled by the surface normal read from the depth buffer (up-facing gets more, sun-facing less). Shade tint is less navy. Rock keeps its form in shade.
- Sunlit faces: normal and curvature from depth (4 extra depth taps, near land only). Ridges catch light, creases keep shade (`relief`), the face most square to the sun goes warm to hot (`hot`).
- Fog: cutouts (dark tufts and trees behind thin fog) are floored at the fog's own colour by its opacity, so fog reads continuous. Not seen "patchy" in a repro; a sun-facing fog view (seed 4, hour 17.6) is the check.
- Shafts: the march now weights taps evenly (rays, not a glow round the sun), also runs over sky pixels, and gains up to 5.5x as the sun goes low (0.5x high). Visible in haze and fog fanning from ridges; with a sun fully behind a ridge (seed 5) they stay weak.
- Moods tuned: alpine_morning, ocean_light, meadow_morning, desert_afternoon, after_the_rain (lift, shade, light, rays, relief).
- Shade tint keyed on true shadow: not done. The pass sees only colour, depth and cloud opacity; the shadow map is not bound to it. Needs a new binding (sun shadow atlas) or a normal-roughness read.

**Clouds that live** (`shaders/endless_cloud_march.glsl`, `scripts/endless/endless_clouds.gd`)
- Each weather cell keeps a clock (cycle 110 s x 0.6 to 1.5, puffs x0.6): its cloud grows from a thin wisp over the first 40 %, stands briefly, thins away over the last 45 %. The next cycle is a fresh hash of the cell (another shape and place), so clouds form from nothing and fade to nothing. Done in the weather pass only: no extra march steps.
- A puff or wisp that sits under a bigger cloud (`yields`) now gives way smoothly (shrinks as the neighbour grows) instead of switching off.
- The low layer drifts at 0.8x the wind, the high layer at 2.0x: the weather pass runs the lattice twice (low clouds in one frame, high in the other). Cloud base and the meadow lift use the cloud's full size, so a low cloud's base never moves with its life, meadows stay clear, and low clouds you fly into keep their belly.
- The CPU mirror (`in_cloud`, `cloud_depth`) follows life and the layer drifts (approximate: yield pressure is binary there).
- Summit mist: not done.

## Flags
`--cloud-life=0` (rigid field as before), `--cloud-life=X` (cycle length x X), `--cloud-shear=X` (layer wind spread, 0 = one wind), `--cloud-clock=S` (start S s into life, for stills), `--lift=X`, `--relief=X` (0 off), plus the earlier `--rays=0`, `--post=0`. Constants: `LIFE_PERIOD`, `LIFE_COVER` (1.6, makes up for smaller average clouds), `LOW_WIND`, `HIGH_WIND` in `endless_clouds.gd`; the envelope is in `cell_life`.

## Cost (RTX 4070 Super, window, GPU median, frozen scene, with another agent running)
Clouds life +0.15 to 0.25 ms (11.57 vs 11.32/11.41). Post additions within noise (11.49 post off vs 11.79 with lift and relief off vs 11.4 on). Not measured at 2560x1440 with the sun in view.

## Proof
- `captures/shots/light_tune_sheet.png`: before left, after right: default, rosewater_dusk toward the sun, alpine toward the sun (seed 3), ocean_light, meadow_morning, desert_afternoon, after_the_rain. Singles in `captures/shots/lt/` (before_*, d_*).
- `captures/shots/cloud_life_strip.png`: same view at 0, 20, 40, 60 s (`--cloud-clock`): horizon clouds change, one forms over the lake bottom right.
- Smoke passes (headless; it has no renderer, so rendered runs of the stills ran with no script errors). Shared shaders untouched; the aqueduct isle is unaffected. No existing test breaks (none covers these files).

## Weak
- Rays are still modest with the sun behind a ridge or high; no real shadow-aware rays.
- Clouds still sample noise in world space (not advected with each layer), so lobes slide through a drifting cloud as before; layers moving apart makes it a touch more visible.
- Per-cycle new clouds can appear over a meadow edge as thin wisps first; fine, but the cover is a bit patchy in time (LIFE_COVER is a guess).
- Ocean mood mountains in shade are still deep blue; the sea-level cloud slab edge line at the horizon predates this round.
- Weather pass runs the cell loop twice (low and high frames); fine at 1024 texels here, watch on a slower GPU.

## Next
Summit mist (cap and banner on the highest peaks, drifting downwind, via the fog march); shadow map bound to the post pass for true-shadow shade tint; advect the noise per layer.
