# Opal cloud sea: ocean and mountain peeks (unfinished)

## State
No shader change is made yet. `shaders/sky_cloud_sea_opal.gdshaderinc` is untouched.
The only code change is `tools/capture_backdrop.gd`: new `--hours=10,17.67` and
`--yaws=1.57,3.14` options (extra overviews turned by those radians, named
`yawN-HHMM.png`; `--only=yaws` shoots just those).

Only one baseline still exists: `/private/tmp/zs-opal-peeks/r0/yaw0-1000.png`
(overview turned 1.57 rad, 10:00). The run was stopped before the rest. No
iteration rounds were rendered.

## Plan worked out (not yet tried)
Ocean, in `zs_opal_sea_land`: add a broad mask, `m = noise(at*0.28) + 0.25*noise(g*0.5)`,
`ocean = smoothstep(0.5, 0.54, m)` (about half the world is sea; cells about 3.5 depths).
Water is deep hazed blue times `level`, with a lighter shallow band near the threshold for a
soft coast. Add a sun glint: `pow(0.5+0.5*az, 6)` times a fine ripple noise, passed in from
the caller. At night use `zs_moon_direction` (`zs_sun_direction` is the sun, not the moon).
Keep the existing `mix(land, air, ...)` veil so it never competes with the plate.
Check the ocean shows in the default overview at 10:00; if not, bias the mask.

Peaks, in `zs_cloud_sea_opal` before the haze mix. Work in `room` space.
- The eye is 1 unit above the sea plane, and `at = room.xz/down`.
- Ray height above sea at horizontal distance s is `1 - s/far`, with `u = normalize(room.xz)`.
- Keep 3 hardcoded analytic peaks: a snow-capped cone (Fuji) and a rocky pair.
- Per peak, reject early: `s0 = dot(P,u)`, perpendicular distance greater than R, or `s0 <= 0`.
- Otherwise march about 14 steps across the chord, clamped to s < far, to the first crossing
  where peak height exceeds ray height. Refine linearly.
- Peak height `H*pow(1-r/R, ~1.15)` plus faceted relief from linearly interpolated (unsmoothed)
  value noise, so it reads as planes. Take the normal from 2 extra samples.
- Lighting: Lambert from `zsRoomDir(zs_sun_direction)` (moon direction at night). Snow above a
  height line, blue-grey rock below. Mix to `air` by distance haze, with extra haze on the shade side.
- Fade the foot into the cloud with `smoothstep(0, 0.25 + noise, height_above_sea)`.
- Placement constraint: the veil is `smoothstep(-0.02,-0.16,dir.y)`, so a peak top must sit
  below about dir.y -0.12 or it half-vanishes. Try distance 3.5 to 6, R about 0.8, H about 0.4 to 0.5.
  Check which bearings the overview camera sees: place the main peak where the default overview
  sees it, and the rest so they show at some turns only.
- Cost estimate: peaks are rejected by the chord test for most pixels. Ocean is a few noise
  evaluations, only inside open rifts.
- Optional: round the rifts less (add warp to `zs_opal_sea_rift`), and break the quilted puff
  lattice with a slight per-cell rotation.

## Next steps
1. Implement the above, run `/tmp/zs-render.sh ... --only=overview --hours=10` for r1.
2. Tune placement, then check 17.67 (golden), 23 (night) and an overcast still.
3. Run `tests/test_cloud_styles.gd` headless.
