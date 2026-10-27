# Spec: the storm front (loop `storm-front`)

A storm front that sweeps across the endless land, as spectacle. The plane
flies exactly as it does now: no forces on it in this slice.

Trail prefix: `ITER(storm-front):`. Branch: `claude/wind-system-spectacle-e357d5`.
Cap and budget: the iterate skill's defaults. Model: Opus.

## What done looks like (what the user plays and sees)

`.\run-endless-flight.cmd --storm-start` (PowerShell) puts a storm front on
the horizon ahead of the start, moving toward the plane. Flying at it, it
reaches the plane in about a minute or two.

- **From far:** a long, dark shelf of low cloud across the horizon, a wall
  kilometres long, with grey curtains of rain hanging under its base and
  lightning flickering inside it. It visibly moves with the wind.
- **The gust front, ahead of it:** a band of hard wind rolling over the land
  a few hundred metres ahead of the cloud: grass flattened in waves, trees
  bending hard, the sea and lakes roughening into whitecaps with spray off
  the crests, and a rising roar.
- **Under it:** the light drops to a grey-green gloom; rain streaks past the
  plane and beads on the lens (the existing screen-wet); rain pocks the
  water; a rain bed in the sound. Lightning bolts strike the land near the
  plane: sometimes a ruin piece, which cracks and drops stones through the
  existing breaks; sometimes a tree; otherwise a hilltop. Each strike
  flashes light over the land and the cloud base, and its thunder arrives
  late by its distance (343 m/s).
- **Behind it:** the cloud breaks up, the light comes back, the land is
  clear.
- **At night** (the day cycle's night hour; find the flag in
  `scripts/endless/endless_look.gd`): the flashes light up the whole land
  for an instant and drop it back to dark.

Hard rules:

- **The plane is untouched.** With the storm on, the flight path is bit for
  bit the same as with it off (prove with an md5 of positions through the
  real play loop, as `shelved/thermals` did). Strikes never hit the plane.
- **Off by default.** No storm unless `--storm` or `--storm-start[=m]` is
  given. `--storm=0` is the same as no flag. When off, nothing in the game
  changes and nothing extra is built.
- **Weather, not a drawn zone.** It must read as real weather. The last wind
  feature was rejected because it looked like a glass tube. Judge every look
  by rendered stills from the chase camera, at a few distances, and iterate
  before committing.
- **Low-end hardware is a ship target.** Note the cost of each piece; keep
  near-camera effects cheap and fade far ones by distance.
- Meadows and flats (AGENTS.md) are untouched; the storm changes no land.

## The core contract (built first, then read by every lane)

`scripts/endless/storm_front.gd` (class `StormFront`), stepped from
`studies/endless_flight.gd`. One front at a time. It is a function of time
and position only, so every lane and the CPU and GPU agree.

- The front is a straight line, `LENGTH` long (about 8 to 12 km), moving
  along the wind's heading (`EndlessLook.wind_direction`) at `SPEED`
  (about 12 to 20 m/s; tune). Across the line it has bands, by signed
  distance `d` from the leading edge (positive = ahead, not yet arrived):
  - `gust` band: ahead, about 0 to 800 m. Wind rising to its peak at the
    edge.
  - `shelf`: the cloud's leading shelf, about -200 to 400 m.
  - `core`: under it, rain and lightning, about -300 to -3000 m.
  - `clearing`: the trailing edge, cloud thinning out over about 1 km.
  - The line's ends taper off over about 1 km, so it has ends you could fly
    around.
- Query API, all cheap, all pure:
  - `amount_at(p: Vector2) -> float` 0..1, how deep in the storm (cloud and gloom).
  - `rain_at(p: Vector2) -> float` 0..1.
  - `gust_at(p: Vector2) -> float` 0..1, the gust front's wind.
  - `edge_distance(p: Vector2) -> float` the signed `d` above.
  - `heading() -> Vector2`, `on() -> bool`.
- Flags: `--storm`, `--storm=0`, `--storm-start[=m]` (default about 3500 m:
  the leading edge this far ahead of the start, its middle on the start's
  line, coming toward the plane), `--storm-speed=X`, `--storm-length=X`.
- Shader globals, declared in `project.godot` by the core and published each
  frame by `StormFront`:
  - `zs_storm_line` (vec4): a point on the leading edge (xz) and the heading (xy).
  - `zs_storm_shape` (vec4): length, the core's depth, the gust band's depth, on (0/1).
  - `zs_storm_here` (float): `amount_at` at the eye, for screen and light grade.
  - `zs_lightning` (vec4): the latest strike's xz, the time since it, its
    strength. Written by the lightning lane; declared by the core.
- The light grade under the storm: drive `celestial.storm` (it greys the
  sky and deepens overcast; `scripts/shared/celestial.gd:27`, read near
  `:445-573`) from `zs_storm_here`, so the gloom works from the core on.
- A debug line in the flight's HUD notes (`--storm-debug`): `d`, amount,
  rain, gust at the plane.

## Lanes (built in parallel after the core, one agent each)

Each lane works in its own worktree on branch `lane/<part>`, cut from this
branch after the core lands. It keeps its code in its own new files and its
edits to shared files (`studies/endless_flight.gd`, `flight_sound.gd`,
`project.godot`) small and additive, and ends its commit with **Notes for
merge**: the shared lines it touched.

1. **`clouds`: the cloud wall and the light.** The shelf and core as thick,
   dark, low cloud in the raymarched field (`shaders/endless_cloud_march.glsl`
   `region_cover` ~:226 / `weather_texel` ~:736, mirrored in
   `scripts/endless/endless_clouds.gd` `_region` ~:586), darker in the
   composite (`shaders/endless_cloud_composite.gdshader` ~:68-92), with a
   ragged clearing behind. The composite also lights the cloud from inside
   by `zs_lightning`. The sky and sun grade via `celestial.storm`.
2. **`rain`: rain and wet.** Rain streaks around the eye under `rain_at`
   (cheap GPU particles moving with the eye); distant grey rain curtains
   hanging under the cloud base, readable from kilometres; rain pocking the
   sea and lakes; the lens wetting (`scripts/endless/screen_wet.gd:94`
   `wet`); `assets/audio/rain-bed.wav` as a bed in `flight_sound.gd` (`_bed`
   ~:359).
3. **`lightning`: bolts, flash, thunder, strikes.** Branching bolt visuals
   from the cloud base to the ground; a flash of light over the land; picks
   targets near the plane's view, preferring a ruin piece
   (`scripts/breaks/breakables.gd:121` `hit`, `kit_breaks.gd:203`
   `_nearest`), then a tree (`scripts/endless/land_trees.gd:1259`
   `tree_in`, `scripts/endless/tree_knock.gd:136` `at_hit`), then a
   hilltop. Thunder from `assets/audio/thunder-1..3.mp3`, delayed by
   distance (`flight_sound.gd` `shot` ~:405). Writes `zs_lightning`. Rhythm:
   flickers in the cloud often; ground strikes every several seconds under
   the core, with at least one reliably within view early on with
   `--storm-start`.
4. **`gust`: the gust front on the land and water.** Feed the band to the
   grass and trees through the existing front hook (`scripts/shared/gust_fronts.gd`
   `publish` ~:191 sets `zs_front_N`, read by `zs_front_at`,
   `shaders/reference_wind.gdshaderinc` ~:392, today only used by the ruin
   kit gallery); roughen the sea and lakes in and behind the band
   (`shaders/endless_sea.gdshader` `zs_sea_air` ~:736, `zs_wind_strength`
   ~:289/:596; the FFT takes one wind at build, `endless_sea.gd:168`, so
   scale in the shader rather than rebuild each frame) with whitecaps and
   spray off crests; a gust roar (`assets/audio/kit/wind-slam-1/2.wav`,
   `wind-bed.wav`) by `gust_at` at the eye; flocks scatter if cheap.

## Trunk (after the lanes merge, in order)

The lanes are merged (`ITER(storm-front): merge lane …`). Each was judged
alone, against a blue sky; these seams were seen in their stills and come
first in step 1:

- **The deck reads as a flat lid.** From under it the base is a hard,
  straight line with a bright strip of horizon below it
  (`storm-lane-clouds` stills `sc_v9_sheet.png`). Make the base ragged and
  lumpy, hang the rain curtains into it so they join, and let the distance
  under the deck go grey with rain, so no clean strip of sky shows.
- **The sea stays bright cyan under the core.** Dim and grey the sea and
  lakes by `zs_storm_here` / the storm amount at the water.
- **The flash tints the trees icy blue-white.** Tone it to a bright,
  neutral flash that doesn't recolour the land.
- **A struck arch keeps its old flight solid**, so the plane can hit the
  part that fell; rubble is never freed.
- **Not yet shot:** a far bolt seen from outside the storm, the flash
  lighting the cloud from inside (`zs_lightning` in the composite), the
  view from behind the storm, night, the clouds lane's last tweak (sun
  share by height), and a no-flag still against the loop's tip.
- **Determinism low over the sea:** with `--water-near-start` the plane's
  path hash already varied run to run at the tip; with the storm on it
  never repeats even with `--water-contact=0`. Find out whether the storm
  reaches the plane there (it must not).
- **Sound by ear is unverified** for the rain bed, thunder and gust roar;
  balance their levels against each other by numbers at least.

**The user played the merged build (2026-10-26).** "A great start"; the
sound effects are great. The storm cloud is the problem: next to the
normal clouds' rich, textured, volumetric shapes it reads as "a wool
blanket pulled over the top", flat. The direction, agreed with the user:
the storm is the field's own cumulus turned menacing, not a separate deck.
So step 1 now starts with these, in order, before the other seams:

- **1a. The field's own clouds become the storm.** In and ahead of the
  front, the normal cells get bigger and taller, merge, their bases sink,
  and they go darker and fuller, keeping all of the field's texture and
  detail. The push is one storm-intensity input per place, from the front's
  distance. Replace the lanes' separate deck if it is in the way. Judge
  against no-flag stills of the normal clouds at the same distances: the
  storm must have at least their shape and detail, with menacing depth from
  light and shadow on real shapes, not tint.
- **1b. They grow over time.** The intensity ramps with time as well as
  distance, so the player watches the cumulus ahead fill up, expand and
  darken over a minute or two as the front builds, and boil (faster detail
  motion inside storm cells).
- **1b+. Detail up close, before the towers.** The orchestrator's read of
  1b's stills (`grow_sheet.png`, `g2_sheet.png`): the build-up reads well
  from afar, but close to and under the storm the grown cells go to huge,
  smooth, pale faces and a smudged ceiling, losing exactly the texture the
  user asked for, plus a pale V blotch on a shaded tower face. Fix the
  detail at 200 m to 1 km (finer lumps that scale with the grown size, the
  light taps seeing the carve) until a near storm face holds at least the
  normal clouds' texture at the same range.
- **1c. Cumulonimbus towers.** A few giant towers along the front, far
  taller than the flight ceiling, visible from 10 km: bring the baked tower
  back from `scripts/sky_tower.gd` / `scripts/sky_towers.gd` (a heap of
  lobes baked to a coarse 3D distance texture, rebaked in stages as it
  rises turret by turret, cauliflower noise on top) into the endless cloud
  march, scaled up, darkened at the base, rising as the front builds.
- **1d. Enveloped.** Flying in, the base drops toward the plane, ragged scud
  whips past at plane height, the distance closes in and it goes dark
  (`in_cloud` and the screen, sound and light follow).

1. Make it whole: one pass from far, through the gust front, under the
   core, out the back; fix seams between the lanes (timing, light, sound
   levels). Stills at 5 km, 2 km, the gust band, under the core, behind.
2. Night: the flashes lighting the land; tune.
3. Behind the storm: wet land glinting, cloud breaking up, if cheap.
4. Cost: frame time with the storm on vs off on this PC, noted.
5. The handoff.

## Checks (every step)

- Smoke: `python tools/smoke.py` on `studies/endless_flight.tscn`, with
  `--storm-start` and with no flag. Must PASS with no script errors.
- The plane untouched: md5 of positions through the real play loop with and
  without `--storm-start` (several headings), identical.
- Rendered stills of anything seen (`tools/shot.py`, `-- --no-title`), looked
  at and iterated on. GPU-only checks headless can't run are reported as
  unverified.
- Prototype rules: no committed tests, no full suite.

## Out of this slice

Forces on the plane, gusts that push, storm rhythm in normal play (when and
how often storms come), rainbows, waterspouts, breaking through above the
cloud (the ceiling is about 175 m over the sea).
