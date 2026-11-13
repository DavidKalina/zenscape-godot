# Weather (handoff)

Weather moves through the endless flight on its own: mostly fair, now and
then a shower, rarely a thunderstorm, a rainbow after rain, an aurora on some
clear nights. It applies no forces: the plane reads nothing from it. This is
a prototype: smoke checks, throwaway drivers and stills, no committed tests.
Spec: `spec-weather.md`; trail: `git log --grep='^ITER(weather)'`. It replaces
the unmerged storm front (branch `claude/wind-system-spectacle-e357d5`), which
the user found "overpowering" and "more like entering an area than being
swallowed by the storm".

## Play it

```
.\run-endless-flight.cmd                                   # weather comes by itself
.\run-endless-flight.cmd --weather=storm --weather-debug   # a storm held from the start
.\run-endless-flight.cmd --weather=storm --weather-build-from=0 --weather-pace=10 --weather-debug
.\run-endless-flight.cmd --weather=shower --rainbow --hour=17 --heading=away
.\run-endless-flight.cmd --aurora --hour=0
```

## What you see

- **No edge.** A storm builds over the whole sky in 2.5 to 4 minutes: the
  field's own cumulus grows, merges and greys to the horizon, the light
  flattens, the wind in the grass, trees and sea picks up, rain starts thin.
  It clears the same way. The sky eases frame to frame while it changes.
- **Shower:** broken grey cumulus with sun between; **storm:** a heavy grey
  overcast of heaped cloud, the land at about 40% of fair noon brightness.
- **Rain** falls in soft drifting cells (about 2.6 km): streaks round the
  plane, a grey that thickens with distance, rings on water near the eye,
  matte water farther off, wet land and grass that dry over minutes, a few
  drops on the lens, a rain bed in the sound.
- **Lightning** in full storms only: a flicker in cloud 1.5 to 9 km off, one
  in five a thin far bolt, thunder late by distance. Nothing is struck.
- **Rainbow** when the sun is low and out and rain falls opposite it; it also
  draws over far land, sea and cloud. A double on a quarter of spells.
- **Aurora** on about 30% of nights, hidden by cloud and rain.
- **Rhythm** (200 seeds x 3 h): weather 30% of flight time, 1.85 spells an
  hour, showers 2.9 : 1 over storms, first weather 6 to 15 minutes in, rain
  never before 7.6 minutes.

## Flags

`--weather=cycle|fair|shower|storm|off` (off builds nothing),
`--weather-pace=X`, `--weather-seed=N`, `--weather-debug`,
`--weather-build=F` (hold a part-built sky), `--weather-build-from=F` (start
there and keep building), `--weather-wet=F`, `--rainbow[=X]`,
`--rainbow-double`, `--aurora[=X]`, `--heading=away`, `--lightning-at=F`,
`--lightning-kind=cloud|bolt`, `--lightning-range`, `--lightning-bearing`,
`--lightning-hold`, `--lightning-log`, `--rain-air=0`, `--rain-slant=F`,
`--rain-fibres=F`, `--cloud-ease=0` (the sky's easing off, for A/B).

## Where it lives

- `scripts/endless/weather.gd` (`Weather`): the cycle, the eased scalars, the
  rain field (`rain_at`, `wet`), the flags, the globals `zs_weather`,
  `zs_weather_sky`, `zs_rain_field`, `zs_lightning`; its contract is at the
  top. GPU copy: `shaders/weather.gdshaderinc`. The light goes through
  `scripts/shared/celestial.gd` (`weather_grey`, `weather_dim`, `weather_fill`).
- Clouds: `shaders/weather_cloud.glslinc` in `shaders/endless_cloud_march.glsl`
  (editing the include alone does not rebuild the march: bump its "Include
  edit" comment and run `python tools/godot.py --import`),
  `shaders/cloud_weather_blend.glsl`, `scripts/cloud_volume_effect.gd`,
  `scripts/endless/endless_clouds.gd`.
- Rain: `scripts/endless/weather_rain.gd`, `shaders/weather_rain.gdshader`,
  `weather_rain_air.gdshader`, `weather_rain_water.gdshaderinc`; the soak in
  `endless_ground.gdshader` and the grass shaders; the wind in
  `endless_look.gd` `_publish`.
- Lightning: `scripts/endless/weather_lightning.gd`,
  `shaders/weather_bolt.gdshader`, `weather_lightning.gdshaderinc`.
- Rainbow and aurora: `scripts/endless/weather_sky_lights.gd`,
  `shaders/weather_bow.gdshaderinc`, `reference_sky_common.gdshaderinc`.

## Cost (this PC, GPU ms of the cloud passes over `--weather=off`)

Three interleaved rounds, no other Godot running, spread 0.02 ms or less.

| | Chase | Looking up |
|---|---|---|
| Fair | +0.00 | +0.00 |
| Shower | +0.51 | +0.94 |
| Storm | +0.71 | +1.04 |

The target was +1 ms; a storm looking up misses it by 0.04. What is left
there is the march (0.42 ms off, 1.08 storm). The rain, water and wet grass
were not measured.

## Stood in, left rough or unverified

- **The Peak is set aside** (the user's call): a storm leaves part of an open
  patch to the right of it (`WX_UNLIFT` 0.3; closing it at 0.6 cost about
  3.5 ms, cause not found), and its spiral ribbon clouds stay white.
- Sound is set by numbers; nobody has heard the rain bed or the thunder.
- The plane's path with weather on and off could not be compared: the
  flight is not repeatable run to run even with weather off.
- A held storm steps very faintly every 8 frames (1.24x at pace 10).
- From low altitude a far rain shaft is a thin band: cloud bases sit 115 to
  190 m over the ground.
- The shower's dark patch is fixed for showers only; the same edge may show
  on big fair cumulus (not checked) and a storm keeps its dark heaps.
- In rain the speed streaks fade, so Boost in rain gives less sense of speed.
- Close-up rain rings are faint under the dim overcast; the storm sea reads
  slate-navy.
- The second rainbow now shows only on a double, in a shared sky shader, so
  the isles lose their faint second bow too.
- One `--weather=off` smoke failure was seen once and never again; its text
  was lost.
- No existing test was run.

Also on this branch: the amber cloud door (the wall of standing cloud to the
amberlands, `shaders/door_cloud.gdshader`, `--door=cloud`) is deleted;
`region_doors.gd` keeps only what the ruin hall door shares. The hall door
loads under `--world=doors --doors=1` but was not flown through.
