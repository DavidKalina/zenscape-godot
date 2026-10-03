# Native motion and water pass

This document records the initial motion pass. See [PARITY.md](PARITY.md) for
the current environment/creature work and full remaining scope.

This pass targets animation and visual polish in the imported seed-7 scene.
It does not change the original Three.js checkout or make the import editable.

## What changed

- The importer retains `aDepth` and `aCut` in UV2. The lake now uses its source
  depth palette and depth-dependent transparency, with waves pinned at the shore.
- The stream was previously imported as a static opaque surface. It now uses
  a water material, deformed facet normals, and highlights moving downstream.
  New exports retain `aS`/`aU`; the existing version-1 snapshot reconstructs those
  coordinates from its five-point ribbon sections without resampling the terrain.
- The waterfall has small traveling silhouette deformation with its endpoints
  pinned, plus moving aerated highlights. This is a native approximation of the
  source animation, not a port of its full hydrology and cross-section model.
- Birds alternate flapping and gliding, with gentle vertical flight variation.
- Water, vegetation, birds, and spray share a pausable animation clock. A global
  shader parameter updates that clock once per frame, rather than updating every
  material separately. The wind
  slider adjusts vegetation sway and water deformation. The subsequent atmosphere pass connects mist and ballistic droplets to
  the same moving wind field.
- Middle-drag pans. Beauty enables the existing SSAO/glow; Balanced disables
  those two effects while retaining geometry, shadows, and motion. The selector
  is disabled under Compatibility, where these effects are unavailable.
- Camera/light settings are embedded in the native scene, avoiding parsing the
  full 5 MB geometry JSON at runtime. The source JSON remains an import fixture.

## See and reproduce

Run `run-fidelity.command`. P pauses/resumes motion; the existing Tab source-image
comparison, R reset, Space camera drift, and H hide-controls shortcuts remain.

`motion-comparison.mp4` shows **updated Godot left / previous Godot right** for six
seconds at 30 FPS, 1280 × 854 per side. Both use the same close camera, source
snapshot, and lighting. Wind phases are not guaranteed to match: the previous
shader used engine TIME; the new scene uses its own clock.

Record the current scene using the native Godot binary:

```sh
godot --path . --rendering-method forward_plus \
  --write-movie /tmp/motion.avi --fixed-fps 30 \
  res://studies/fidelity.tscn -- --clean --detail --film-frames=180
```

Trim to 180 frames when encoding; Godot may record a final frame after quit.
The fixed-rate movie is visual evidence, not a real-time performance measurement.

## Performance work is paused

The user explicitly removed frame rate from the current priorities. Retained
benchmark reports measure forced offscreen draw throughput, not gameplay FPS or
GPU timestamp queries, and do not establish a speedup over Three.js. They are
not an acceptance gate for the shader, lighting, physics and atmosphere work.

## Validation and next work

The native import check verifies all 5,366 instance positions. The fidelity test
checks every water vertex's imported depth, stream coordinates, shared pause and
resume behavior, quality switching, and camera panning/release behavior.

```sh
godot --path . --rendering-method forward_plus --script tools/check_import.gd
godot --path . --rendering-method forward_plus --script tests/test_fidelity.gd
godot --headless --path . --script tests/test_camera_feedback.gd
godot --headless --path . --script tests/test_landscape.gd
# removed: godot --path . --rendering-method forward_plus --script tests/test_scene.gd
```

The 17 landscape checks and native scene integration checks pass. The existing
sandbox camera-picking test fails under this machine's headless dummy viewport;
the same test passes with a real rendering viewport. The sculpting code is unchanged.

Current remaining work is tracked in [PARITY.md](PARITY.md). The source celestial
shader/lighting rig, shared wind, native valley fog, original Bigfoot peek rig,
camera tremor and precipitation controls have since been added. Full cloud,
weather, water-detail, growth and wildlife behavior are still incomplete.

## 2026-09-07: camera damping and frame pacing

The source camera is stock OrbitControls with damping: pointer deltas pool and
5 % of the pool is applied per frame, so the view glides and settles. The
fidelity scene now pools orbit and pan deltas (`_orbit_delta`, `_pan_delta`) and
eases them in `_ease_camera` by the same 5 % per displayed frame as the source's
`OrbitControls.update()` call. This removes elapsed-time modulation of the
fraction consumed per frame; it also makes settling time depend on frame rate,
as in the source. The replay test establishes that response contract, not
input-to-photon smoothness. F7 in the comparison launcher toggles the prior
time-based response so the user can judge the change directly.
Rotation is `TAU` per viewport height and pan follows the source's
`2 * distance * tan(fov / 2) / height` per pixel. Wheel zoom uses the source's
0.95 per 100 px (Godot's precise factor is 0.03 per px), trackpad momentum
arrives as `InputEventPanGesture` and pinch as `InputEventMagnifyGesture`, the
idle spin cancels on the first press, and drag motion is read in `_input` so a
drag crossing the control panel keeps moving the camera. Metal vsync produced a
~1 s stall once per session and a 60 Hz cadence at the 120 Hz budget, so vsync
is disabled and `application/run/max_fps` paces the loop at 120.
