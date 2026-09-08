# Luminous woodland — visual benchmark

Goal: make a small diorama extraordinary to spend time in, preserving crisp
faceted geometry and calm motion. The target is localized mist, readable shafts
of sunlight, reflective water, and consistent clarity while orbiting. No gameplay
expansion is part of this work.

## First study

Run `run-visual-benchmark.command`, or open `studies/visual_benchmark.tscn` in
Godot 4.7.2 with Forward+. F8 switches between the experimental treatment and
the original rendering on the same authored composition. Ordinary orbit, zoom,
and P-to-pause controls remain available.

The study builds the existing terraced-pools landscape with woodland planting
and the Golden meadow look. It is a separate entry point; it does not change the
main scene, production shaders, or project quality defaults.

- Native fog uses the existing terrain/water height textures to remain above
  the landscape. A slowly drifting noise field breaks it into patches, and an
  altitude falloff keeps the upper silhouettes clear. Real directional-light
  shadows modulate scattering. Bloom and full-scene temporal AA remain off.
- The experimental pond shader uses opaque depth colors and small moving
  facets, enabling native reflections. It uses a stylized specular response;
  its metallic value is an artistic control, not a physical claim about water.
- A local reflection probe captures surrounding geometry, excludes the water
  itself, and affects only the water layer. It supplies an off-screen fallback
  alongside screen-space reflections.

## Assessment and remaining work

This is a first rendering experiment, **not the completed visual target**.
Low fog and light/shadow separation are visible, while foreground facets remain
sharp. The first strong backlighting trial washed out the scene and was reduced.

Water is the outstanding visual problem. From the overview, its reflections
are still less legible than the desired mirror-like pond. The current opaque
material also gives up seeing the actual bed through water. Do not promote it
to production as a finished water replacement. Next investigate a planar pond
reflection with depth/transmission, compare against the current material, and
retain the calmer result. Multiple pool heights must be handled explicitly.

The probe currently captures a static scene once. It does not follow changing
geometry, foliage animation, or time-of-day changes. Source display-fog buffers
remain allocated in this comparison harness even when hidden, so timings are
for this study implementation, not an optimized native-fog production path.

## Reproduce evidence

Use the Godot executable from the launcher with `--path . --rendering-method
forward_plus --script` and one of:

- `res://tools/capture_visual_benchmark.gd`: same-camera stills plus pond view
  with/without scene reflections. Geometry and simulation are paused.
- `res://tools/film_visual_benchmark.gd`: two six-second orbits with the same
  fixed clocks and camera path; PNG sequences in `/private/tmp/zs-beauty-*`.
  Explicit `RenderingServer.force_draw(false)` keeps off-screen export running
  when the application window is covered. Enhanced is the left side of the
  assembled comparison.
- `res://tools/profile_visual_benchmark.gd`: control/enhanced/control intervals,
  two-second warmup and four-second sample per phase at 1440×900, 120 FPS cap.
  Writes `pacing.json`. These are process-frame wall intervals, not GPU timing,
  actual display presentation, or a hardware minimum specification.

## Initial timing result

Apple M5 Pro, Metal Forward+, 1440×900 render pixels, existing 4× MSAA and
120 FPS cap. Mean frame intervals were 8.33 ms / 8.42 ms / 8.33 ms for
control / enhanced / control. Enhanced p99 was 9.03 ms and maximum 9.61 ms.
No screenshot process ran during sampling. The cap limits what this can tell
us about spare GPU capacity. Runtime shader compilation succeeded; the inherited
atmosphere compositor reports texture RID leaks at application shutdown, which
still need separate cleanup before treating this as production code.
