# Endless flight, look round 1: sky, light, ground, sea

The endless flight now wears the isles' own sky and light, a painted grass
carpet, and the plane-height sea. There are no clouds yet; they come next
round. The land's shape is untouched.

## What changed

- `scripts/endless/endless_look.gd` (new) builds the look and steps it each
  frame:
  - Sky and light: `LandscapeLighting` (the reference sky, ACES, glow,
    SSAO, the sun and rim lights), driven by `studies/celestial.gd` with
    one of the isles' look presets (`scripts/scene_look_presets.gd`) as
    the mood.
  - The sky's own cloud deck is off (`zs_cloud.x = 0`), and the ringed
    planet is hidden.
  - The sun casts shadows in 4 splits out to 900 m.
  - Haze: depth fog whose colour is the dome's own horizon colour toward
    where the camera faces (`horizon()`, `zsSkyBase` at y 0 brought to
    scene light as the dome does). 35% of it is Godot's aerial
    perspective, which turns the middle distance bluer. Far land melts
    into the sky with no line, and distant ranges go blue. The camera's
    far plane is now just past the fog's end (7.9 km), where it is all
    sky.
  - Wind globals (`zs_wind_*`, `zs_gust_distance`) and the clocks
    (`zs_motion_time`, `zs_flow_time`, `zs_camera_position`), published
    by the look. No Atmosphere node is used.
- `shaders/endless_ground.gdshader` (new) is the chunk material.
  - It paints per pixel from the world height over the sea, the normal's
    slope, and the meadow, which now rides in the vertex colour's alpha.
  - The grass uses the isles' calm-field greens. Patches run from 900 m
    down to 0.3 m, some with defined edges (clover and lush clumps), with
    warm and cool drift and dry patches (`zs_grass_dry`). High ground
    turns to tundra, and steep turf thins to olive.
  - Wind-wave crests (`zs_grass_crest`, two trains) roll over the grass,
    with a velvet sheen at grazing angles.
  - Ragged-edged rock on slopes, with beds by height. A beach strip at the
    water, wet sand, and a seabed that darkens with depth. Snow above
    `SNOW` on gentler slopes.
  - Every scale fades to its mean once a pixel is too coarse for it, so
    no chunk level and no distance pops. There are no blades.
  - It is lit like the isles' surfaces: the sun through Godot, plus the
    `zs_hemi_*` fill as emission. Ambient is off under
    LandscapeLighting. At night it takes celestial's `night_grade`.
- Sea: `shaders/sky_ocean.gdshader` (the lower world's plane-height sea)
  with `below_sky = 0`, so it mirrors the open sky.
  - It has swell, chop, cat's paws, the sun's glint path, a sky mirror,
    and a screen-space mirror of the land (the mountains show in it).
  - It has turquoise shallows over the bed, read from the depth buffer,
    and shore foam and a bright lip.
  - It is drawn on `SkyBelow._sheet()` (ringed LOD), which follows the
    eye.
- `scripts/endless/land_stream.gd`: `setup(seed, ground = null)` takes the
  look's material. Without one it keeps round one's vertex colours. The
  vertex colour's alpha is now the meadow (StandardMaterial ignores it).
- `studies/endless_flight.gd` builds the look unless the plain look is
  asked for. The new flags, keys and HUD numbers are listed below.

No shared file was edited. The look only uses shared scripts and shaders,
so the aqueduct isle and the motif editor are unchanged.

## Flags, keys, knobs

- `--mood=ID` picks the mood, one of `EndlessLook.MOODS`. The default is
  `alpine_morning`, at 07:36. The others are golden_meadow, ocean_light,
  meadow_morning, after_the_rain, desert_afternoon, rosewater_dusk,
  rose_dusk and moonlit_stillness. There is no winter mood.
- `--hour=H` sets the sun's hour.
- `--day` lets the hour run (a day in about 8 min).
- `--plain-look` gives round one's look. It is also used automatically
  under the Compatibility renderer.
- `--heading=sun` faces the sun.
- `--numbers` opens with the F1 numbers shown.
- `--uncapped` turns off vsync and the fps cap, so the HUD's fps is the
  frame's real cost.
- Keys: T eases to the next quarter of the day, and L goes to the next
  mood. The HUD now shows the frame time, and the mood and hour.
- Knobs:
  - `endless_look.gd`: `FOG_BEGIN/END/CURVE`, `AERIAL`, `SUN_SCATTER`,
    `SHADOW_REACH`, `WIND`, `AIR_SPEED`, `TINT_*` (the sea by depth),
    `HOUR`, `MOOD`.
  - `endless_ground.gdshader` uniforms: `rock_up`, `thin_up`,
    `patch_strength`, `velvet`, `wind_sheen`, `wave_lengths`,
    `vertex_hue`.

## Verified (this Mac, M5 Pro, Forward+, Godot 4.7.2)

- Headless import: 0 errors.
- Smoke PASS, 0 errors, for `endless_flight.tscn`, for
  `endless_flight.tscn -- --plain-look`, and for `aqueduct_isle.tscn`.
- Every rendered still ran with 0 errors.
- Frame time at 1440x900, uncapped, measured from the HUD's fps:
  - Low over meadows: about 5.3 ms (187 fps).
  - Over the sea toward the coast: 7.1 ms (141 fps).
  - High over the coast: 6.5 ms (155 fps).
  - The driver reports no GPU time on Metal (`gpu` reads 0, so the HUD
    hides it). These are whole-frame times. With the 60 fps cap there
    is plenty of headroom.
- Final stills are in `scratch/endless-look/` (git-ignored):
  - `final_meadow.png`, `final_coast.png`, `final_high.png`,
    `final_sun.png`, `final_low_meadow.png`, `final_night.png` and
    `final_plain.png`.
  - Contact sheets: `final_sheet.png` and `final_sheet2.png`.
  - Perf HUD stills: `perf_*.png`.
  - The view script is `scratch/endless-look/shoot.sh`.

## Not verified

- Not checked in motion: how the grass sheen and sea read while flying,
  any shimmer at speed, and the `--day` cycle as it runs.
- The view of sunrise and night was not judged in depth. Only one
  moonlit still was taken.
- Windows and other GPUs.
- Retina or full-screen resolution cost.
- Moods other than alpine_morning, golden_meadow, meadow_morning,
  rosewater_dusk and moonlit_stillness were not looked at.
- The low flats under about 1.5 m over the sea read as sand bars.
  Meadows (3 m and up) stay turf.

## Existing tests this breaks

None known. No test covers the endless scripts, and no shared file
changed. The full suite was not run.

## Cue for the clouds round

- Hook `scripts/cloud_volume.gd` onto the scene's camera
  (`endless_flight.gd` `camera`). It attaches to `camera.compositor`,
  which is unset here, and calls `update(view, near_sea, host, sky, time)`
  each frame. Do this in `EndlessLook.step` after the sea follows the eye.
  - `sky` is `look.celestial`.
  - `near_sea` and `host` need an endless SkySea and towers (or a laid-sky
    host, `scripts/cloud_host.gd`) sized for the flight band, sea -40 to
    ceiling 95.
- The cloud composite sheet draws in the transparent pass. Give the sea
  (`look.sea`, transparent, depth_draw_always) a render priority that
  keeps the clouds in front of it.
- The sky's own cheap deck can come back for far cover by raising
  `zs_cloud.x` in `EndlessLook.setup`. Then also set `celestial.cloud`,
  which dims the light.
- The camera's far plane is 7.9 km. Clouds marched beyond it need the
  far plane or the march's own reach widened, and the haze
  (`environment.fog_*`) applied to them.
