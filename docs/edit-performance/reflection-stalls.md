# Flower placement and camera stalls after the graphical upgrade

The September 8 follow-up reported volcano flower placements freezing the app,
and occasional large Redwood camera stutters without Bigfoot. The earlier
mist/refresh fixes did not cover the subsequently added planar reflection system.

## Confirmed reflection causes

Every object revision cleared the reflection viewports, generated clipping
shaders and reflected materials. Four real flower placements on the `cone`
preset caused 40 on-demand **Draw** pipeline compilations on native Metal.
Placement frames peaked at 41.075 ms. Disabling reflections as an A/B control
reduced the peak to 12.765 ms.

Object-only updates now preserve viewports, pond surfaces, shaders and reusable
materials, while replacing bindings to changed geometry. Unused material
bindings are removed. Changes to water still rebuild the reflected water views.

Reflection viewports also used 2× MSAA against the main viewport's 4× MSAA.
Preserving resources alone left one Draw compilation per placement. Matching
the scene's MSAA removed these: the final four placements produced **zero Draw
compilations**, with a 14.393 ms maximum frame interval. Godot explicitly
documents mixed viewport MSAA as a precompilation limitation:
[pipeline precompilation features](https://docs.godotengine.org/en/latest/tutorials/performance/pipeline_compilations.html#pipeline-precompilation-features).
Specialization and Surface counters each rose by four in the final run; the
fix does not eliminate all compilation work.

These are Apple M5 Pro / Godot 4.7.2 / Forward+ Metal measurements, not Windows
validation. The benchmark uses the editor's `place_at` path with actual flowers
and their sprout reactions, then sends camera mouse-motion events. Earlier
before/control runs rotated by directly updating yaw; the placement path is
the same. The benchmark checks how many objects were added and records
frame-by-frame pipeline counters. No world files are saved.

## Camera report remains open

A 30-second camera-input run on Redwood without Bigfoot or edits stayed below
11 ms during orbit. A separate run with Bigfoot produced occasional larger
intervals, but that is not the clarified user scenario. The random Windows
inspection hitch has **not** been reproduced or explained locally.

Do not infer a cause solely because a Specialization counter changes near a
slow frame: Godot describes those compilations as background work. GPU timing
can be unavailable (the local captures returned zero), and the engine's process
monitor is not an exact per-frame timer.

## Capture on Windows

The normal exported app now includes an opt-in capture:

1. Press **F9** before inspecting or editing.
2. Reproduce the hitch, then press **F9** again.
3. File Explorer reveals the saved `zenscape-performance-*.json`; return that file.

Recording also stops after 60 seconds or 15,000 samples. Frames are buffered in
memory and written only when recording stops. Reports contain GPU/backend/CPU,
initial display settings, frame intervals, prior scene callback duration,
pipeline counters, camera values and revision/count metadata. They omit authored
world content. Files live in the app's `user://performance` directory. Writing
the report and opening its folder occur after the measured capture has stopped.

## Source benchmarks and tests

```sh
godot --path . --script tools/profile_interaction_stalls.gd -- --out=/tmp/cone.json
godot --path . --script tools/profile_interaction_stalls.gd -- --no-reflections --out=/tmp/cone-control.json
godot --path . --script tools/profile_interaction_stalls.gd -- --preset=redwood_grove --orbit-only --orbit-seconds=30 --out=/tmp/redwood.json
```

`test_playable_visuals.gd` gained initially failing checks for retained
viewports/shaders/materials and matching MSAA. `test_performance_trace.gd`
exercises F9 start/stop, real frame sampling, GPU/backend and pipeline metadata,
saved JSON, stopped-recording behavior, and automatic completion.
