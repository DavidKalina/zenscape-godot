# Spec: weather (loop `weather`)

Weather that moves through the endless flight on its own: mostly fair, now
and then a shower, rarely a thunderstorm, a rainbow after rain, an aurora on
some clear nights. The plane flies exactly as it does now.

Trail prefix: `ITER(weather):`. Branch: `claude/storm-weather-effects-9a0a8f`.
Cap and budget: the iterate skill's defaults. Model: Opus.

## Why this is a second try

A storm front was built before (branch `claude/wind-system-spectacle-e357d5`,
`docs/design/endless-flight/storm-front-handoff.md` there; 42 commits, 769
commits behind main, 11 files conflict, so it is **not** merged: read it and
lift pieces from it with `git show <branch>:<path>`). The user played it:
"not bad", sound effects great, but "overpowering in a way that was almost
comical, and not believable", and: **"felt more like I was entering an area
rather than being swallowed by the storm."**

So the old storm was a place: a 10 km wall with an edge you crossed, three
giant towers, a gust band, a dark room under it. This one is **weather that
happens to the whole sky, over time, around the plane.** The rules that
follow from that:

- **No edge to cross.** Nothing about a storm is a line, a wall or a zone
  boundary. Wherever the plane is, the sky builds over minutes: cloud cover
  thickens everywhere to the horizon, bases lower and darken, the light
  flattens, the wind in the grass and trees picks up, the first rain
  starts thin and thickens. It ends the same way, slowly.
- **Rain is uneven, with soft, wide edges.** Inside that weather, heavier
  rain falls in drifting cells (2 to 4 km across, feathered over a
  kilometre or more) that move with the wind. From far a cell reads as a
  grey rain shaft under darker cloud with lit land beyond it. Flying into
  one, the rain only gets heavier; there is no threshold.
- **Believable, restrained.** No giant towers, no deck dropping on the
  plane, no black gloom: the darkest storm keeps the land readable and
  flyable (think a heavy overcast afternoon, not night). Lightning is
  mostly a flicker inside distant cloud with thunder arriving late; a
  visible bolt is occasional and far; nothing is struck or broken; never a
  strike near the plane. No gust-front band.
- **Storm cloud is the field's own cloud.** The user rejected a flat dark
  deck ("a wool blanket"): storm cloud must be the same detailed volumetric
  cumulus as fair weather, grown, merged and darkened
  (`shaders/endless_cloud_march.glsl`, `scripts/endless/endless_clouds.gd`).
  The old branch's `shaders/storm_cloud.glslinc` "push on the field's
  cells" is the reference for that part only.
- **The plane is untouched.** With weather on or off the flight path is bit
  for bit the same (md5 of positions through the real play loop). No forces.
- **Cost.** Low-end hardware is a ship target. Fair weather must cost what
  it costs today. Note each piece's GPU ms in a rendered window; the whole
  storm should stay under about +1.5 ms on this PC.
- Judge every look by rendered stills from the chase camera
  (`tools/shot.py`, `-- --no-title`), looked at and iterated before
  committing. Stills go in `scratch/weather/`.

## What done looks like (what the user plays and sees)

`.\run-endless-flight.cmd` with no flags: a flight is mostly fair. Every so
often the weather turns by itself, over minutes, and turns back.

- `--weather=fair|shower|storm` holds one state from the start (built up,
  not ramping). `--weather=cycle` (the default) lets it drift.
  `--weather=off` builds nothing and is today's game exactly.
  `--weather-pace=X` speeds the cycle for judging (e.g. 10 = a whole
  fair, storm, clear turn in a couple of minutes). `--weather-debug` adds a
  HUD notes line (state, build 0..1, rain here, next change in s).
- **Shower:** cover thickens to broken grey cloud, soft rain cells drift
  through, light dims a little, sun still breaks through between cells.
- **Storm:** full dark overcast of heaped cloud, steady rain with heavier
  cells, wind up in grass, trees and water, distant lightning and thunder.
- **Clearing:** cloud breaks up, sun returns, the land stays wet a while.
- **Rainbow:** when the sun is out and lowish behind the camera and rain is
  falling ahead (the usual case: just after a shower passes), a rainbow
  fades in opposite the sun and fades out as the rain moves off. Rare
  double. `--rainbow` forces one.
- **Aurora:** on some clear nights (not every one), high in the sky, gone
  when cloud covers it. `--aurora` already forces it.

## The core contract (trunk step 1, before the lanes)

`scripts/endless/weather.gd` (class `Weather`), stepped from
`studies/endless_flight.gd`. Pure functions of time and position so CPU and
GPU agree.

- State over time: `fair -> building -> shower|storm -> clearing -> fair`,
  with eased scalars: `build()` 0..1 (how far the sky has turned),
  `severity()` 0 fair, about 0.5 shower, 1 storm, `cover()` (cloud cover
  lift), `wind()` (a multiplier on the look's wind), `clear_sky()` 0..1.
- Rain: `rain_at(p: Vector2) -> float` 0..1 = a base level from the state
  times drifting soft cells (noise or a few feathered blobs advected along
  `EndlessLook.wind_direction`); `rain_here()` at the eye;
  `rain_ahead(dir: Vector2) -> float` for the rainbow; `wet()` 0..1, the
  land's wetness, lagging rain and drying over minutes.
- The cycle: seeded, mostly fair (a turn every 6 to 12 minutes of flight,
  showers about three times as common as storms; tune), never starting a
  flight in rain.
- Flags as above. Shader globals declared in `project.godot` and published
  each frame: `zs_weather` (vec4: build, severity, rain here, wet),
  `zs_rain_field` (what the GPU needs to evaluate `rain_at`: drift offset,
  scale, base level), `zs_lightning` (vec4: latest flash xz, time since,
  strength; written by the lightning lane).
- The light: drive `celestial.storm` (`scripts/shared/celestial.gd:27`, read
  near `:445-573`; today nothing assigns it) from build and severity, with
  a cap that keeps a storm flyable. Stills of fair, shower and storm light
  at noon, at a low sun and at night.
- Proof: smoke with and without the flags; the md5 of positions.

## Lanes (in parallel after the core, one agent each)

Each lane runs in its own isolated worktree. Those are cut from main, so
its first act is `git merge --ff-only <the loop branch's tip>` then
`python tools/worktree.py setup .`. It keeps its code in its own new files,
its edits to shared files (`studies/endless_flight.gd`, `flight_sound.gd`,
`project.godot`, `endless_look.gd`) small and additive, and ends its commit
with **Notes for merge**: the shared lines it touched.

1. **`clouds`: the sky turning.** The cloud field under `cover()` and
   `severity()`: more and bigger cells, merged, lower darker bases, to the
   horizon, changing smoothly frame to frame (the old branch's
   `cloud_weather_blend.glsl` eased the weather map between slices); heavier
   and darker over rain cells. The clearing breaks it back up. No towers,
   no deck, no scud at plane height. Fair weather's march cost unchanged.
2. **`rain`: rain and wet.** Lift from the old branch: streaks round the eye
   (`storm_rain.gd`, `storm_rain*.gdshader`), far rain shafts under cells
   (`storm_curtain.gdshader`, softened: a shaft, not a wall), rain on the
   sea and lakes (`storm_rain_water.gdshaderinc`), the lens wet
   (`scripts/endless/screen_wet.gd`), wet land drying
   (`endless_ground.gdshader` soak), the rain bed in `flight_sound.gd`.
   All by `rain_at` and `wet()`.
3. **`lightning`: flicker and thunder.** In storms only. In-cloud flicker
   lighting the cloud from inside (old `storm_cloud_light.gdshaderinc`,
   `endless_cloud_composite.gdshader`), an occasional far bolt
   (`storm_bolt.gdshader`), thunder late by distance (the old
   `flight_sound.gd` thunder; `assets/audio/thunder-*.mp3` if on main, else
   lift them). No strikes on ruins, trees or near the plane: lift the small
   parts of the old 981-line `storm_lightning.gd`, not the targeting. At
   night a flash lifts the land briefly, never a white-out.
4. **`sky-lights`: rainbow and aurora.** Both shaders exist and compile into
   the dome (`shaders/reference_sky_common.gdshaderinc` `zsRainbow`,
   `zsAurora`; published at `scripts/shared/celestial.gd:591-597`). The
   rainbow has no writer: drive `weather_bow` (`celestial.gd:41-48`) from
   sun height, sun out at the eye, and `rain_ahead` opposite the sun,
   eased; a rare double; `--rainbow` floor like `--aurora`
   (`celestial.gd:40`). Check it draws against cloud and land correctly
   (a bow belongs in the rain, in front of far cloud). Aurora: the natural
   roll (`celestial.gd:306-326`, `:611-626`) seldom fires; make it some
   clear nights, faded by `cover()`. Stills of both; the aurora must not
   read as neon.

## Trunk (after the lanes merge, in order)

2. Whole: one flight with `--weather-pace` through fair, building, storm,
   clearing, rainbow. Fix the seams (timing, light, sound levels, the wind
   in grass, trees and sea rising with `wind()` through the existing wind
   globals). Stills at each stage, day and night.
3. Rhythm in normal play at pace 1: how often, how long, never at the
   start, landing in rain still works (through the play loop).
4. Cost: GPU ms fair, shower, storm vs `--weather=off`, noted; trims.
5. The handoff: `docs/design/endless-flight/weather-handoff.md`.

## Checks (every step)

- Smoke: `python tools/smoke.py` on `studies/endless_flight.tscn` with no
  flag, `--weather=storm` and `--weather=off`. PASS, no script errors.
- After any `.glsl`/`.glslinc` edit, reimport before a rendered run.
- Rendered stills of anything seen, looked at. GPU-only checks headless
  can't run are reported as unverified.
- Prototype rules: no committed tests, no full suite.

## Out of this slice

Forces on the plane, gusts that push, snow, fog banks, waterspouts, flying
above the cloud, lightning that breaks things, weather per region.
