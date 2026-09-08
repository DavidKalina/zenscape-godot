# Shadow edges and camera response

The user identified two remaining deficits during a direct interactive
comparison: patterned, stair-stepped Godot shadows and jittery camera response.

## Shadow correction

The fixed close-up reproduces the reported fringe at directional shadow filter
quality 1 (very low), blur 0.2. Independent captures established:

- Quality 3 alone removes the conspicuous sample pattern but retains stair steps.
- Blur 1 alone broadens the noisy fringe.
- Quality 3 with blur 1 smooths the edge but is softer than needed.
- Quality 3 with blur 0.5 retains a tight silhouette and removes the obvious
  patterned fringe. These are the new defaults.

The atlas remains 8192 and the orthogonal shadow distance remains 130. Bias,
normal bias, light direction, geometry, MSAA and atmosphere were not changed.
This fixes the demonstrated filtering defect; it does not establish perfect
shadow stability at every camera distance.

Godot's [Light3D documentation](https://docs.godotengine.org/en/4.7/classes/class_light3d.html#class-light3d-property-shadow-blur)
describes the radius as an edge filter for hiding shadow pixel artifacts and
notes that excessive values can introduce grain. The chosen values were judged
in actual native captures rather than inferred solely from the documentation.

`before.png` and `after.png` show the same fixed camera. The film shows revised
shadows LEFT and prior shadows RIGHT, with a four-second camera sweep at 30 FPS.
The world is paused; the camera follows a prescribed path. This is offline
visual evidence, not a frame-rate benchmark.
All 120 recorded camera transforms and viewport sizes match between reels;
`camera-path.json` retains that path. Matching frames were visually inspected.

## Camera response

Source OrbitControls consumes 5% of accumulated motion per rendered frame. The
native implementation instead used a delta-time-scaled fraction referenced to
60 Hz. It now uses the source's fixed fraction, with a comparison switch retaining
the previous response. This changes settling at high refresh rates and removes
frame-delta modulation of the consumed fraction. Settling duration consequently
depends on frame rate, as in the source.

`tests/test_camera_feedback.gd` failed before the change and passes afterward:
it replays uneven frame durations and multiple input events between frames.
That verifies the input response contract. It does **not** prove the user's
perceived jitter is solved or establish input-to-photon latency. Hands-on
comparison remains necessary.
The native fidelity integration checks also pass. Its settling check now
replays sixty frames instead of treating one artificial one-second frame as
equivalent to a second of rendering.

## Real-time timing

`pacing.json` records an old / revised / old comparison at 2400×1500 physical
pixels, VSync off, cap 120, close camera, no fog. Median intervals stayed around
8.33 ms in all three phases. p99 was 8.70 / 9.01 / 10.40 ms respectively.
The revised phase also contained a 1026.81 ms stall. Its cause is unestablished;
similar one-off stalls were seen before these changes. The data supports normal
120 FPS throughput but **not** a claim that hitching is solved or the new filter
has no cost. The earlier run was excluded because viewport sizing changed and
the repeated control drifted substantially.

## Try it

Run `run-godot-comparison.command`. The window title identifies active modes:

- F6: reset the common camera pose.
- F7: toggle revised / previous camera response.
- F8: toggle filtered / previous shadows.
- F9: toggle display-synchronized presentation / independent 120 FPS timer.
- F10: cycle atmosphere normal / no temporal history / hidden. This isolates
  the reported after-trail from continued camera motion. History-free air may
  look noisier. Hidden mode hides the compositor contribution while retaining
  its running viewport workload; it is not a performance optimization.

Use Fn with the function keys if required by macOS keyboard settings. The
comparison starts with the revised camera and filtered shadows. The normal
saved garden is not loaded or overwritten by this launcher.

## Short follow-up: display synchronization

The comparison launcher now starts with VSync enabled and Engine.max_fps = 0,
so the display sets the cadence without a second limiter. F9 restores the
previous VSync-off / max_fps 120 combination. Production project settings are
unchanged by this experiment.

At 2400×1500 on the reported 120 Hz display, a timer / sync / timer run measured
median intervals of 8.34 / 8.39 / 8.34 ms. The synchronized phase sustained
120 FPS (p99 9.19 ms), with no intervals over 16.67 ms during its eight-second
sample. The final timer phase caught a 1029.94 ms stall. This does not establish
the stall's cause, display presentation intervals, or perceived input latency.
It does show that VSync without the separate cap need not halve throughput on
this machine. `presentation-pacing.json` retains the summaries.

The source schedules its frame callback with Three's `setAnimationLoop` and
applies a display-aware cap in `main.js`; the native timer mode is not equivalent
despite both reporting 120 FPS. See Godot's
[VSync documentation](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html#enum-displayserver-vsyncmode).
The remaining acceptance check is a short manual F9 comparison; no further
damping or input changes were made during this time-boxed follow-up.
