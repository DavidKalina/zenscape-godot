# Endless flight, look round 2: the clouds

The endless flight now has the isles' raymarched cloud volume over a field
of cumulus that never runs out. The clouds drift on the wind, cast shadows
on the land and the sea, and take the mood's light. The low ones can be
flown into: the view whites out round the plane.

## What changed

- `scripts/endless/endless_clouds.gd` (new) runs the clouds. It uses the
  isles' passes on the camera's compositor: weather map, ceiling, shade,
  then the march at half resolution, resolved over frames and laid in by a
  sheet in the see-through pass. `EndlessLook` makes it and steps it in
  `step()`, after the sea follows the eye.
  - **The field.** Two lattices of cells in the wind's drifting frame,
    each cell hashed (pcg3d) from the land seed:
    - Broad cumulus, 620 m cells. 30% are "low" (base 26 to 60 m over the
      sea, so you can fly into them). 12% are towers (base 115 to 160 m,
      1.2 to 1.9 times as tall as they are wide). The rest are "mid", with
      bases 128 to 190 m over the sea, at the flight's ceiling, so they
      form a roof.
    - Small puffs, 230 m cells, bases 22 to 115 m over the sea.
    - Each cloud is a cluster of four bubbles with a flat base.
    - A 5.2 km value noise makes clearer and cloudier regions.
    - The field is marched out to 7.8 km, so the horizon always has cloud.
  - **The CPU mirror.** `clouds_in(xz, reach)` and `cloud_depth(p)` /
    `in_cloud(p)` mirror the field on the CPU, for drivers and the HUD.
  - **Meadows.** A ground map (meadow, height; 160 texels over 20 km) is
    made on a worker. It is remade when the eye has moved 1.8 km. Over a
    meadow, the low cloud's base is lifted to at least `MEADOW_CLEAR` (70 m)
    over the turf, and the cloud is half as thick. No cloud base goes below
    the ground.
  - **Shade.** The shade map covers 6 km round the eye and is published
    through the isles' `zs_cloud_shadow*` globals.
- `scripts/endless/endless_cloud_effect.gd` (new) subclasses
  `cloud_volume_effect.gd` and compiles the new march in place of the
  isles' march. The bindings and the parameter block are the same.
- `shaders/endless_cloud_march.glsl` (new) is the march. It differs from
  the isles' in these ways:
  - The weather map holds two layers per texel (low top, low base, high
    top, high base), so a puff can hang under a cumulus. Where there is no
    cloud, a texel keeps the distance to the nearest rim (as base minus
    top). The march uses that to leap clear air safely.
  - The light's cone of taps lengthens far off, so far clouds still shade
    themselves.
  - Steps are refined just after the first hit.
  - The steps are jittered afresh after every leap, so the steps never show
    as contours on the cloud.
  - Lookups for the form and its normals use the map smoothed over two
    texels, so the texels never show as flutes down a tower's flank.
  - Inside a cloud the density comes in wisps. The cloud thins over the
    first ~18 m in front of the eye, so the plane stays readable.
- `shaders/endless_cloud_composite.gdshader` (new) colours the cloud:
  - Light comes from `cumulus_light.gdshaderinc` (`zs_cloud_sun`,
    `zs_cloud_sky`). That is the mood's sun and sky, so golden hour, dusk
    and moonlight read.
  - A whiteout glow shows in cloud.
  - The land's haze (`FOG_*`) is laid over the cloud, thinner for cloud
    standing high, toward the dome's colour behind each cloud.
  - Alpha is pushed to 1 once cover is 0.96, so the sun's disc never shows
    through a body of cloud.
- `shaders/endless_ground.gdshader`: under a cloud's shadow it loses 85%
  of the sun and 20% of the sky fill.
- `shaders/sky_ocean.gdshader` (shared, opt-in): a new uniform,
  `cloud_shade` (default 0, which reads no shade). The endless sea sets it
  to 1, which darkens the water under cloud and takes the glint off it.
  Other users are unchanged.
- `scripts/endless/endless_look.gd`:
  - Builds the clouds unless they are off.
  - Sets the sea's `render_priority` to -8, and the cloud sheet draws at -6
    over it.
  - Publishes `wind_direction`.
  - `step()` takes the camera.
- `studies/endless_flight.gd`:
  - C toggles the clouds.
  - The HUD (F1) shows "in cloud", "clouds off (C)" or "no clouds".
  - The hint line mentions C.

## Flags, keys, knobs

- `--no-clouds`: no clouds. They are also off under `--plain-look` and
  the Compatibility renderer, and headless (no RenderingDevice).
- `--cloud-cover=X`: how much sky they take (1; 0.5 sparse, 1.6 heavy).
- `--cloud-haze=X`: the share of the land's haze laid on them (0.6,
  `EndlessLook.CLOUD_HAZE`).
- `--cloud-steps=N` (110) sets the march's steps. `--cloud-full-res`
  marches every pixel.
- C turns the clouds off and on in flight.
- Knobs:
  - `endless_clouds.gd`: `REACH`, `TOP`, `WIND_SPEED`, `MEADOW_CLEAR`,
    `SMALL_COVER`, `LOW_SHARE`, `TOWER_SHARE`, `QUALITY`,
    `WEATHER_EVERY` / `SHADE_EVERY` (2), and `SHADE_SIDE`.
  - The field's shape constants are mirrored in the march. Change both, or
    `clouds_in` drifts from the drawn clouds.
  - In the march: `BIG*`/`LOW_*`/`MID_*`/`TOWER_*`/`SMALL_*`, `PROFILE`,
    `MAIN_R`, `LOBE`, `SIGMA`, `SIGMA_IN`, `SKY`, `FACE_SHADE`, `STEP*`,
    and `RIM_MARGIN`.
  - `endless_ground.gdshader`: `cloud_shade`.

## Verified (this Mac, M5 Pro, Forward+, 1440x900, Godot 4.7.2)

- Headless import: 0 errors. Smoke PASS, 0 errors, for:
  - `endless_flight.tscn` (headless runs it without clouds)
  - `endless_flight.tscn -- --no-clouds`
  - `endless_flight.tscn -- --plain-look`
  - `aqueduct_isle.tscn` (after the `sky_ocean` change)
- A rendered still of the aqueduct isle ran with 0 errors.
- Every rendered run and still had 0 errors.
- Frame time, measured as the mean of 300 real frames with `--uncapped`
  (`scratch/endless_perf.gd` via `scratch/endless-clouds/perf.sh`):

  | view | clouds off | clouds on |
  |---|---|---|
  | cruise at the start | 4.9 ms | 6.9 ms (p95 7.6) |
  | into a low sun, over the sea | 6.6 ms | 8.1 ms (p95 8.9) |
  | high over the coast | 5.6 ms | 7.6 ms (p95 8.3) |
  | inside a low cloud | | 7.5 ms (worst 8.8) |

  The clouds cost 1.5 to 2 ms a frame.
- Through the real play loop (throwaway drivers in `scratch/`):
  - `endless_cruise_long.gd`: a straight flight of 110 s with boost held,
    about 2.7 km.
    - There were 222 to 260 clouds within 3 km all the way.
    - The ground map moved once.
    - The worst frame was 17.7 ms, with 0 frames over 33 ms and 0 errors.
  - `endless_into_cloud.gd`: finds the nearest low cloud over the sea
    (seed 1) and flies into it through the stick, holding height.
    - It enters, whites out and comes out the other side, with 0 errors.
    - It passes repeatedly. One early run missed the cloud while the flight
      was real-time paced.
  - Meadows: stills over seed-1 meadows that had puffs placed over them
    show the cloud lifted well clear of the turf.
- Final stills are in `scratch/endless-clouds/` (git-ignored):
  - `final_cruise.png`: cruising with cumulus around.
  - `final_high.png`: high over the coast with a low cloud near.
  - `final_sun.png`: into a low sun.
  - `final_dusk.png`: rosewater dusk.
  - `final_rose.png`: rose dusk towers.
  - `final_shadows.png`: cloud shadows on land and sea.
  - `final_night.png`: moonlit.
  - `final_meadow.png`: a meadow approach under lifted puffs.
  - `final_into_1_near.png`, `final_into_2_inside.png` and
    `final_into_3_out.png`: into a cloud, the whiteout, and coming out.
  - Sheets: `final_sheet.png`, `final_sheet2.png` and
    `final_into_sheet.png`.
  - The view script is `scratch/endless-clouds/shoot.sh`.

## Not verified

- In motion, by eye:
  - Any shimmer or grain on the clouds at speed. A faint grain remains in
    still frames.
  - Ghosting of near clouds from the half-res resolve while turning.
  - The edges of near clouds are a little blocky from the half-res
    upsample.
- That nothing pops. By construction, clouds fade in at the reach (7 to
  7.8 km, deep in haze). Over a meadow far out, a low cloud may lift when
  the ground map moves, also at 6+ km. Not watched in a long flight.
- Moods other than alpine morning, golden meadow, rosewater dusk, rose dusk
  and moonlit stillness. The `--day` cycle as it runs.
- Windows and other GPUs. Retina or full-screen cost.
- An actual hand landing with clouds on. The meadow lift was only checked
  by stills.

## Existing tests this breaks

None known. No test covers the endless scripts or `sky_ocean.gdshader`.
The `sky_ocean` change is opt-in, with a default of 0. The full suite was
not run.

## Next cues

- **Shapes.**
  - Towers and puffs still read a little faceted (bubble domes). More
    bubbles, or a noise-warped radius per bubble, would round them.
  - The low layer's billows are mild. `LOBE` and `MID_SWELL` could be set
    per layer.
- **Fly-through feel.** Wisps streaming past the camera on entry and exit,
  a little buffet, and maybe a sound.
- **Weather.** `--cloud-cover` could follow a slow regional weather over
  time. The isles' storm and lightning hook into the same volume
  (`flash` slot 172 is free in the march).
- **Cost.** The weather map and shade are redrawn every 2 frames, and the
  march runs 110 steps at half resolution. A lighter tier could draw the
  shade every 4 frames and use 80 steps.
