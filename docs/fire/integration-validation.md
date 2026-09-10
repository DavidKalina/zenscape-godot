# Fire integration validation

Validated on 2026-09-09 against main `dcec8af` (native terrain performance and PR #4 Jolt/debris work). Godot 4.7.2, Forward+/Metal, Apple M5 Pro. One Godot process at a time.

## Behavior

Seventeen suites completed with zero failures and no script errors in their final runs:

- Fire: `test_fire_field`, `test_fire_integration`, `test_fire_look`, `test_fire_effects`, `test_fire_transactions`, `test_fire_visual_state`.
- Physics and workers: `test_native_explosives`, `test_debris_strikes`, `test_threaded_refresh`, `test_threaded_lifecycle`, `test_inherited_scene_lifecycle`.
- Resident: `test_bigfoot_fire`, `test_bigfoot_explosions`, `test_bigfoot_environment`, `test_bigfoot_tree_peek`, `test_bigfoot_tree_hug`, `test_diorama_environment`.

`test_fire_transactions` and `test_fire_visual_state` also passed with `--gdscript-kernels`. The final fallback fire timing run shut down without script errors.

New regressions cover first-fire Undo with empty history; loading a different garden; clearing queued cook-offs; terrain ownership during worker preparation and refresh; successive fires preserving earlier char/ash; back-to-back live cook-offs preserving the selected remote target; grouped Undo/Redo; Undo after rain extinguishes blast fire; failed ignition releasing stale history; char retained on physical props, debris and save/load; rain clearing ember heat; and replacement authored batches staying hidden for promoted props. The lifecycle suite also verifies that an abandoned finite async helper survives until its join and then releases itself.

## Frame timing

Balanced, verified 1440×900. Frame intervals are wall-clock measurements, not isolated CPU timings. Metal returned zero for its GPU timing monitor, so GPU timings are unavailable. Captures happen after sampling. Wrong-size startup runs were rejected.

`tools/profile_fire.gd` measures 240 idle frames and 600 active frames in a flat, densely planted meadow with four trees. It runs in real time, so native and fallback samples reach different fire populations; these are workload checks, not an isolated native-kernel speed comparison.

| Kernels | Phase | Median ms | p95 ms | Max ms | Peak burning cells |
|---|---|---:|---:|---:|---:|
| Native | idle | 10.78 | 11.23 | 11.62 | 0 |
| Native | active | 10.85 | 12.44 | 21.36 | 255 |
| GDScript fallback | idle | 11.47 | 13.17 | 26.33 | 0 |
| GDScript fallback | active | 11.57 | 13.51 | 21.69 | 301 |

The fixed-seed horn/alpine blast benchmark retains live worker preparation, staged debris publication and Jolt collisions, with fire enabled:

| Trial | Blast completion ms | Frame p95 ms | Longest frame ms |
|---|---:|---:|---:|
| 1 | 273.26 | 28.82 | 53.73 |
| 2 | 283.23 | 27.63 | 53.27 |
| 3 | 283.40 | 26.69 | 52.74 |

The small meadow stays below the 16.7 ms budget for at least 95% of sampled frames, with occasional longer refresh frames. The heavier blast still exceeds that budget: this is not a general 60 FPS claim. The earlier PR #4 baseline completed blasts in 281–308 ms with p95 frame times of 22.6–25.0 ms; this integrated run completes in 273–283 ms but has p95 frame times of 26.7–28.8 ms. Fire adds ongoing refresh work; do not treat these sequential runs as a controlled speedup comparison.

Reproduce with the local Godot binary:

```sh
Godot --windowed --resolution 1440x900 --path . --rendering-method forward_plus --script res://tools/profile_fire.gd
Godot --windowed --resolution 1440x900 --path . --rendering-method forward_plus --script res://tools/profile_fire.gd -- --gdscript-kernels
Godot --windowed --resolution 1440x900 --path . --rendering-method forward_plus --script res://tools/profile_explosions.gd -- --quality=balanced
```
