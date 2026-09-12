# Regrowth frame-time pass

The transition is now degrow with tremor (3.4 seconds), rebuild, and grow with
tremor (5 seconds). It adds no fog blanket. Normal landscape mist and weather
continue moving. Releasing Bigfoot during any stage still queues a safe landing.

## Measured change

September 12, 2026, Apple M5 Pro, Godot 4.7.2, Forward+ / Metal, native window
at 3024×1898. Seeds 110 (redwood plateau) and 4 (desert monuments), same order,
with two seconds of warmup. These are short local desktop captures, not an
isolated GPU benchmark. Background desktop load can affect individual frames.
The GPU timer returned zero, so only observed frame intervals are reported.

| World | Before: worst frame | After: worst frame | Before: p95 | After: p95 |
| --- | ---: | ---: | ---: | ---: |
| Redwood plateau | 87.9 ms | 45.6 ms | 41.2 ms | 34.5 ms |
| Desert monuments | 72.2 ms | 46.8 ms | 49.5 ms | 40.8 ms |

Percentiles cover the transition, excluding idle frames. The longer animation
changes the distribution of phases; these figures describe the player-facing
sequence, rather than equal-duration render microbenchmarks. Total transitions
were roughly 8.8–9.1 seconds after the change, versus 6.4 seconds before.

The matching headless runs isolate main-thread responsiveness from rendering:
worst intervals fell from 78.5 to 34.5 ms for the forest and 28.2 to 11.0 ms for
the desert. Both passed the 50 ms stall threshold. Dense cloud scenes still
exceed a 16.7 ms frame budget in the native window; this is not a 60 fps claim.

## Changes and evidence

The cozy controller previously called the synchronous habitat rebuild after
terrain publication. It now uses the existing navigation worker path with two
partitions, then validates/publishes within the native 2 ms budget. Bigfoot stays
held until the complete replacement navigation map is available. Terrain and
instance generation already used workers; adding more terrain jobs was unnecessary.

Terrain publication, atmosphere, camera framing, and navigation start on separate
frames. Framing also yields through the existing cooperative work budget.

The cloud field skips fine noise and erosion only when the remaining noise
amplitude cannot cross the density threshold. The cloud march uses 16 samples
instead of the 26-sample ceiling, preserving the field and three-tap shadows.
The GPU cloud comparison measured mean summed RGB error of 0.00113 against
26 steps in the fixed above-deck test. Actual native-window frame tails improved
further after reducing the march budget.

## Reproduction

Run `tools/profile_cozy_regrowth.gd` with Godot, supplying
`-- --label=capture`. Native Forward+ runs measure window frame intervals.
Headless runs can add `--max-frame-ms=50` to fail on main-thread stalls.
Per-frame rows, refresh timings, navigation submission times, worker count,
and physical viewport size are written to `/private/tmp/cozy-capture-110.json`
and `/private/tmp/cozy-capture-4.json`.

`tests/test_cozy_worlds.gd` passes 30 checks covering actual carry input,
degrowth tremor, growth tremor, worker navigation, queued landing, absence of
transition fog, Undo/Redo, and save/reopen. `tests/test_cloud_view_from_above.gd`
checks both cloud visibility and the optimized image against the source budget.
