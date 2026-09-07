# Native growth checkpoint

Y replays formation. Terrain and foliage sliders scrub each channel; manual
scrubbing stops replay, and P pauses the shared animation. The sandbox replay
raises terrain first, fills water, then grows plants, using conductor.js's exponential response
rate 1.4. This sequence is a sandbox control, not a port of journal thresholds.

The supplemental growth.json contains the original terrain and landmark
attributes: aDelay, aHold, aTo, aDirt and aBaseColor. export_growth.mjs verifies
all source positions against the imported seed-7 snapshot before writing it.
import_reference.gd preserves these across winding conversion in UV, UV2 and
CUSTOM0. At full growth, every imported height is retained.

The terrain uses the source .3-wide delayed smoothstep, seam hold and
bare-earth → meadow → feature color transitions. Foliage uses the source
position hash, .72 delay range, .28 growth band and easeOutBack overshoot,
applied after wind so small plants have appropriately small motion. Native
shadow passes run the same vertex deformation. Flat face normals are derived
from the deformed surface, so a flattened mountain does not retain its final
lighting silhouette.

Formation feeds the source conductor's positive-rise trauma calculation into
the native tremor. Scrubbing is immediate and does not generate trauma.
Fog and precipitation use weather.js's mean terrain-delay approximation for
the drawn ground; summit caps gate on terrain growth. This is not exact
triangle collision sampling during formation.

The water stage now uses source path/fill data; see WATER.md. Remaining:
boulders and wildlife currently appear when terrain reaches .995. Their
original emergence and spawn sequences are not yet ported. Bigfoot and waterfall spray are hidden until their supporting
landscape is ready. Sound feedback is not yet implemented.

Validation: tests/test_growth.gd checks every supplemental attribute, exact
finished heights, conductor response, pause, replay completion, scrub
cancellation and formation trauma. tests/test_fidelity.gd still passes.
Bare, partial, full and snow-on-partial native captures were inspected.

growth-comparison.mp4 shows native replay on the left and the same native
scene held at bare growth on the right: seed 7, matched camera/weather/clock,
12 seconds at 30 FPS. Frames at 0, 1.5, 4, 5.5 and the endpoint were inspected.
It demonstrates the new motion; it is not a Three.js parity reel.
