# Endless flight: the cloud weather map drawn in slices

Measured on the Windows PC (RTX 4070 SUPER, 2560 x 1440, the saved max
settings: native 3D, MSAA 4x, SMAA, full shadows, vsync off).

## Where the frame went

GPU time 13 to 17 ms at the five spots of `frame-rate-handoff.md` (range
13.1, coast 14.5, woods 15.3, meadow 16.4, worst 17.0). The CPU is not the
limit: at a 25% render scale the frame drops to about 8 ms, with the GPU
still the slower side.

GPU ms saved by hiding each part (meadow / woods / worst):

| Part | ms |
|---|---|
| Clouds | 4.0 / 4.6 / 4.6 |
| Grass | 3.7 / 1.8 / 1.2 |
| MSAA 4x | 2.6 / 2.6 / 3.3 |
| Shadows | 1.4 / 1.2 / 1.3 |
| Land | 1.0 / 0.8 / 2.1 |
| Trees | 0.6 / 1.1 / 1.5 |
| Sea, SMAA, glow, fog, birds | 0.4 or less each |

Upscaling (meadow / worst GPU ms): native 16.4 / 17.0, FSR1 75% 13.8 / 15.0,
FSR1 67% 13.3 / 14.3, FSR1 75% without MSAA 11.9 / 12.4 (the grass and tree
line go jagged), FSR2 75% (MSAA and SMAA off) 14.4 / 13.9, softer and
smearing behind the plane. `--render-upscale=fsr2` as it stands leaves MSAA
4x on: 17.1 in the meadow, slower than native. Switching to FSR2 while the
game runs makes the engine print `Parameter "uniform_set" is null` every
frame after; starting with it is clean.

The cloud passes' own timestamps (`Cloud weather done`, `Cloud shade done`,
`Cloud march done`, `Cloud resolve done`, added in
`scripts/cloud_volume_effect.gd`), frozen at the meadow: weather map and
ceiling 1.28 ms a frame (2.5 ms every other frame), march 1.0, resolve 0.47.
The rest of the clouds' 4 ms is outside these passes (the composite in the
see-through pass, the shade read by the land and sea). The march already
takes one pixel of each 2x2 block a frame; the weather map was the cheap
win.

## What changed

The weather map (1024 texels a side, about 31 m each) is drawn 1/8 of its
rows a frame into a second map, round the square the eye asked for when the
cycle began, and the two swap (and the ceiling is redrawn) when the second
is whole. Every slice of a cycle is drawn at the drift and life clock the
cycle began with, so each map is one moment; the march reads each layer
shifted by how far that layer has drifted since (`weather_map` in
`shaders/endless_cloud_march.glsl`, the drift in `spare[22]`, the slice's
square in `spare[23]`). The map is at most two cycles old (16 frames).

- `scripts/cloud_volume_effect.gd`: `weather_slices` (0 by default, so the
  isles' clouds run as before), the second map, the cycle, the timestamps.
- `scripts/endless/endless_clouds.gd`: `WEATHER_SLICES := 8`,
  `--cloud-weather-slices=N` (0: the whole map every other frame, as
  before; 16 is a little cheaper).
- `shaders/endless_cloud_march.glsl`: the sliced weather pass and the
  shifted look-ups.

## Numbers

| | Weather (ms) | March (ms) | GPU frame (ms) |
|---|---|---|---|
| Frozen, before | 1.28 | 1.02 | 15.50 |
| Frozen, 8 slices | 0.39 | 1.01 | 14.35 |
| Frozen, 16 slices | 0.24 | 1.02 | 14.42 |
| Flying, before | 1.26 | 1.17 | 16.03 |
| Flying, 8 slices | 0.40 | 1.40 | 15.68 |
| Flying, 16 slices | 0.23 | 1.34 | 15.01 |

Flying, the march pays about 0.2 ms for the high layer's second look-up
(it drifts at its own speed), so the saving in flight is about 0.7 to
0.9 ms. The flying frame totals differ by where the plane got to.

## Checked

- Camera held, clouds stepped at 8x speed, `--cloud-life=0`: without the
  shift each swap is a jump (frame-to-frame sky change 0.5 to 0.6 against
  0.05); with it 0.14 to 0.22. What stays is what a shift can't model: the
  meadow lift and the far fade are fixed to the ground and the eye, not the
  wind, and the clouds' growth.
- At normal speed, 96 frames each of before, 8 and 16 slices: every
  frame-to-frame change 0.032 to 0.038, no pulse at the swaps.
- Stills: the same clouds before and after.
- Smoke: `endless_flight` and `aqueduct_isle` pass headless.

## Not checked

- The isles' clouds rendered (headless runs no compute; their path is the
  old one, `weather_slices` 0).
- Long play, and a cloud flown through up close.
- The Mac.

## Tests this breaks

None known; no test reads the cloud effect.

## Then: FSR1 at 75% and MSAA 2x as the defaults

- `studies/endless_flight.gd` `NATIVE_3D := 0.75`: while endless flight
  runs, a Native draw (the player's render resolution, and the default on a
  discrete GPU) takes 75% upscaled by FSR1 (`scripts/render_resolution.gd`
  `native_scale`, put back on exit). The capped choices (1080p and so on)
  and the Mac's 720 lines are as before. `--render-scale=1` draws at the
  window's own; F2 still cycles 100 / 85 / 75 / 67%.
- `scripts/endless/endless_look.gd` `MSAA_3D`: MSAA 2x everywhere (the Mac
  had it already); `--msaa=4` brings 4x back.

GPU ms, both with the weather slices, frozen: meadow 14.5 to 11.3, worst
15.3 to 11.6 (about 87 fps). Against the session's start (16.4 / 17.0) the
three changes save about 5 ms. Stills: a touch crisper (FSR1's sharpening)
and the grass a little grainier; the tree line holds. Not judged in play.
`test_render_resolution` and `test_game_settings` pass; smoke passes.

## Next

- A wider march spread (one pixel of each 4x4 block a frame): at most
  about 0.7 ms, softer clouds and more reliance on history in turns.
- The clouds' cost outside these passes (about 1.5 ms): the composite and
  the shade reads.
- MSAA 2x on this PC (the Mac already trades it): about 1.3 to 1.7 ms.

Drivers (git-ignored): `scratch/perf/perf.gd` (parts, upscalers),
`scratch/perf/ts.gd` (the cloud passes' timestamps), `scratch/perf/film.gd`
(camera held, clouds stepped).
