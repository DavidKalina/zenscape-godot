# First combined atmosphere tuning

The broad white wind strokes competed with the canopy motion and small water
details. Ambient strokes now use 45% of their former opacity, 65% of their
width, and 1.6 times the interval between births. This changes the visual cue,
not the wind forces. Existing trail lifetimes and pause behavior are retained.

The visual benchmark's low mist density is reduced from 0.17 to 0.145 to retain
more terrain definition. Its lighting and drifting patches remain intact.
Leaves, conifer motion, drips, and reflections retain their established settings.

## Comparison

`comparison.mp4`: tuned LEFT, previous atmosphere RIGHT. Eight seconds at 24 FPS,
same camera, fixed animation clocks, wind strength 1.3, and a gust at 0.5 seconds.
The random trail sequence is reset between reels. Fewer births intentionally
change which trails are present at each time. All other effects run in both.
Reproduce with native Forward+ and `tools/film_atmosphere_tuning.gd`.

## Frame pacing

Godot 4.7.2 / Metal / Apple M5 Pro, 1440×900, 120 FPS cap. Two-second warmup,
six-second sample, all current effects enabled at the benchmark's default
weather. These are process-frame wall intervals, not GPU or presentation timing.
Recording was run separately. Raw samples are summarized in before/after.json.

| Measurement | Before | Tuned |
| --- | ---: | ---: |
| Mean frame interval | 16.263 ms | 16.297 ms |
| p95 | 16.493 ms | 16.549 ms |
| p99 | 16.590 ms | 16.652 ms |
| Maximum | 17.206 ms | 16.941 ms |

Pacing is effectively unchanged at roughly 61 FPS; this is an aesthetic tuning
pass, with no measured speedup. These short measurements do not establish
performance on other hardware or larger scenes.

`tests/test_weather_wind_trails.gd` passed: spawning, pause, anchored curves,
population cap, calm cleanup, and missing-terrain behavior. The native film also
exercises the tuned mist and combined visual effects.
