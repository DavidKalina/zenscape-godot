# Luminous woodland — visual benchmark

**Playable integration:** these effects now also run in the ordinary editor. See [playable visuals](../playable-visuals.md) for coverage and verification. The study description below records the original isolated prototype.

A runnable benchmark for crisp faceted dioramas with low drifting mist, shafts
of sunlight, reflective pools, and calm motion. It builds the existing wooded
terraces and applies a cool woodland palette under warm light.

## View it

Run `run-visual-benchmark.command`, or open `studies/visual_benchmark.tscn` with
Godot 4.7.2 and Forward+. Drag to orbit, scroll/pinch to zoom, P to pause, F8 to
compare the original renderer on the same composition, G to send a gust through
the camera target, C to toggle caustics in the lowest pool, and Esc to close.
The study consumes other keyboard shortcuts so source editor actions cannot
invalidate its reflected geometry.

This is an isolated visual benchmark. The main scene, production shaders,
project quality defaults, terrain editing, and resident behavior are unchanged.

## Rendering choices

- The existing terrain/water height maps locate native fog above the ground.
  Drifting noise creates patches; altitude falloff keeps upper silhouettes
  clear. Directional light and tree shadows produce actual volumetric shafts.
- Each of the three pool heights has its own mirrored camera and clipped scene.
  Geometry below that pool's surface is discarded from its reflected view.
  This prevents underground terrain from appearing as a false reflection.
- Reflections update every frame. Small, slow distortion softens the reflection;
  angle-dependent blending makes water more reflective at grazing angles.
  The screen color behind the surface supplies the visible bed, with depth-
  dependent absorption and a soft shallow-water boundary.
- Reflection views use 512 pixels of width, matching the main camera aspect,
  and 2× MSAA. They omit their own shadow-map passes. The main view retains
  its existing full-resolution faceted geometry, shadows, and 4× MSAA.
- Full-scene TAA and bloom remain off. Source display-fog targets are retained
  for the F8 control, but hidden in the enhanced mode.

The first native-reflection experiment exposed opposite face winding inherited
from Three.js. The original double-sided material concealed it. The study's
pool meshes preserve vertex attributes and correct their front-face indices.
A standard mirror probe confirmed native reflections after the correction;
per-pool planar views then replaced that experiment to make reflection placement
coherent across different water heights.

## Evidence

- `comparison.mp4`: six seconds, enhanced LEFT / original renderer RIGHT;
  identical geometry, authored palette, camera path, and fixed animation clocks.
- `enhanced.png`, `control.png`: matched overview captures.
- `pond.png`, `pond-no-reflections.png`: same pond view with just the planar
  reflection contribution toggled, retaining transmission and atmosphere.
- `hero.png`: a lower viewing angle for checking light shafts and silhouettes.
- `pacing.json`: control / enhanced / control wall-frame measurements.

Use the executable from the launcher with `--path . --rendering-method
forward_plus --script` and one of:

- `res://tools/capture_visual_benchmark.gd` for the stills.
- `res://tools/film_visual_benchmark.gd` for the two six-second sequences in
  `/private/tmp/zs-beauty-*`. The tool explicitly draws frames so export continues
  when the native window is covered.
- `res://tools/profile_visual_benchmark.gd` for two-second warmups and four-second
  samples at 1440×900, with the existing 120 FPS cap. Run measurements separately
  from recording.

## Scope and limitations

The reflected geometry is copied from this fixed composition at setup, so this
is not yet a drop-in renderer for live terrain editing. It includes the scene's
compatible surface shaders, including the trees, terrain, rocks, and falls;
water does not recursively reflect other water. Vegetation's shader motion
continues through the shared wind clocks. Reflected directional lights use the
initial authored light settings, and omit cast shadows to avoid three additional
large shadow-map passes.

Transmission samples screen color rather than physically refracting the scene.
Its bed sample already includes atmospheric fog; the water pass avoids fogging
that sample twice. This also means the reflected image does not receive the full
native fog integral. These are deliberate image/performance compromises in this
stylized benchmark, not claims of physically exact water.

The inherited scene can report seven texture RIDs at application shutdown. This
was also present before the planar renderer; production compositor lifecycle
cleanup remains separate work. Frame intervals measure this benchmark as a
whole, including the retained comparison infrastructure, and do not establish
GPU timings, display presentation latency, or hardware minimum specifications.

## Final validation

`tools/verify_visual_benchmark.gd` sends actual P/F8 key events through Godot's
input dispatch, checks pause/resume and the comparison round trip, confirms the
source water mesh remains unchanged, and verifies three nonempty front-facing
horizontal pool meshes. `reflection-difference.png` amplifies the difference
between the pond captures five times; it isolates the changed contribution to
the water surfaces.

Apple M5 Pro / Metal / Forward+, 1440×900, 120 FPS cap: final mean frame intervals
were 8.30 ms / 16.51 ms / 8.33 ms for control / enhanced / control. Enhanced p99
was 17.35 ms and maximum 19.43 ms. This is roughly 60.6 FPS on average for the
richer treatment, versus the control reaching its cap. An earlier version with
720-pixel reflection views and additional shadow maps averaged 18.51 ms. The
final recording uses the measured 512-pixel reflection configuration.
