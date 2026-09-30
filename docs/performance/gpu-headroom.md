# GPU headroom: where the main pass goes

September 30, 2026; Godot 4.7.2, Apple M5 Pro, Metal, a 3024×1668 window on
the Retina display with MSAA 2×. Follows [stutter.md](stutter.md): once the
compiles were gone, a rendered frame still cost 14–19 ms, right on the 60 fps
line, and the main thread was only 1–2 ms of it.

## Pricing the main pass

`tools/profile_play_session.gd --gpu-slopes` (after the grown world) or
`--gpu-slopes-early` (after two pinches) prices the main 3D pass by
multiplication: it adds one, then three, full-size views of the same world
from the same camera, so one pass costs `(t(3) - t(1)) / 2` whatever the
frame cap and the fixed costs. Each variant is applied everywhere and set
beside a fresh baseline, and the saving is the median of the paired rounds.

    godot --windowed --resolution 1440x900 --path . -s res://tools/profile_play_session.gd -- --modeless --no-title --gpu-slopes --slope-rounds=2 --slopes=sky_off,half_res

What makes the readings trustworthy:

- The scene tree is paused while pricing. Water, land life and growth
  otherwise change the work between readings, by 5–10 ms.
- Variants are re-applied every frame, since the scene republishes some of
  them.
- A reading at the 120 fps cap means the window was hidden and nothing
  drew. The tool waits and retakes it. Keep the window uncovered.

## What one main pass costs

Grown world, pass about 15.5 ms. Savings per pass, two paired rounds each:

| Turned off | Saves |
|---|---|
| Half-resolution 3D | 5.4 ms |
| Sky | 3.8–4.1 ms |
| of which the cloud march | 3.0–3.7 ms |
| Plants | 1.3 ms |
| Shadows | 0.55–0.7 ms |
| MSAA | 0.4 ms |
| Glow | 0.3–0.4 ms |
| Terrain | 0.1 ms |
| Soft shadow filter, medium to low | 0.1 ms |
| SSAO | ≈ 0 |

The sky was a quarter of the pass, and nearly all of that was the cloud
deck's ray march. It runs 16 steps of value noise along every sky pixel,
including every ray looking down past the plate, even in clear weather.
Shadows, the terrain shader and the shadow filter each cost well under a
millisecond, so they are not worth trading look for.

## What changed

- **Half-resolution cloud march** (`shaders/reference_sky.gdshader`). The
  march runs in Godot's half-resolution sky pass (`render_mode
  use_half_res_pass`, `AT_HALF_RES_PASS`), and the full pass composites
  `HALF_RES_COLOR` under the sun, moon, stars and hills, which stay at full
  resolution. The radiance map still marches at its own resolution. Without
  the render mode Godot never runs the pass and `HALF_RES_COLOR` reads as
  white.
- **Fog.** Godot applies fog to the half-resolution pass as well, so the
  clouds take it twice. The local fog volumes around the plate barely reach
  the sky, so `LandscapeLighting` keeps the half-resolution march for them.
  It falls back to the full-resolution march only under depth fog or a
  global volumetric density.

## Results

Look, from `--sky-capture` (bare world) and `--sky-capture-grown`: half
against full resolution, from the play view and from low down looking up
into the deck, in light and heavy cover, with and without the fog volumes,
and in mist. The mean difference is under 0.4/255 everywhere. Almost all the
rest sits under 1/255; the largest, up to 40/255, are rare pixels at the far
horizon streaks. A crop of the horizon band reads the same by eye.

Main pass, bare world: 12.5 ms before, 8.9 ms after. The full-resolution
march now costs 4.1 ms more than the half-resolution one.

Played session, rendered, warm cache, runs alternated. A is main at 7750365,
B is the half-resolution march. Times in ms over the played phases:

| Run | p50 | p95 | p99 | max | >25 ms per min | growing, median | growing, p95 |
|---|---|---|---|---|---|---|---|
| A1 | 18.8 | 27.8 | 30.7 | 45.1 | 366 | 25.2 | 29.6 |
| A2 | 15.8 | 27.2 | 33.3 | 46.0 | 298 | 18.5 | 26.2 |
| B1 | 12.9 | 16.2 | 23.0 | 31.7 | 32 | 14.9 | 16.5 |
| B2 | 12.6 | 18.1 | 24.0 | 46.3 | 38 | 15.0 | 16.3 |

Every phase is faster in both B runs, and they agree with each other. The
frame now sits at about 12–15 ms, under the 60 fps line with some room to
spare.

## Frame caps and tiers per platform

- **Mac:** capped at 60 fps (`run/max_fps.macos` in `project.godot`). A
  frame costs about 13 ms, so 120 is out of reach, and uncapped frames
  alternate between the 120 Hz and 60 Hz ticks. The cap gives a steady 60.
  Vsync stays off: on Metal it stalled a frame for a second now and then.
- **Windows:** uncapped (`run/max_fps.windows=0`), and it starts on the Ultra
  tier (`studies/fidelity.gd`): 4× MSAA, ambient occlusion, the finer fog
  buffer, full grass, and the cloud deck marched at full resolution.
- **Elsewhere:** 120 fps and Beauty, as before. Choosing Ultra anywhere
  brings the full-resolution clouds.

`tools/profile_play_session.gd` measures at 120 fps whatever the platform
ships, so runs stay comparable; `--keep-fps-cap` measures the shipped cap.
