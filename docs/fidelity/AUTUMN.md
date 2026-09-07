# Autumn turn and seasonal lighting

`tools/export_autumn.py` extracts the original weather.js AUTUMN_FRAG into
`reference_autumn.gdshaderinc`. Green dominance and the red/green ratio select
the pixels that turn; fixed world noise staggers their progression through gold
and rust. Luminance preserves baked shading. The paint runs before snow cover,
so winter settles onto turned vegetation. Non-green stone, bark and flowers
retain their own palettes.

Autumn is the eighth native weather option (existing indices remain stable).
All eight profiles now carry their original autumn target, including Snow.
A separate slider allows intermediate seasons; another preset restores its
season. The state eases at the source .55 rate and holds on pause. The source
sun, hemisphere and inversion fog tints apply autumn warmth before cold tint.

`tools/capture_autumn.mjs` captures the live source using explicit URL dials,
seed 7, time .35, and the saved camera. `tests/test_autumn.gd` compares native
sun/sky lighting against those captured values within 2e-5, and checks
transition, pause, snow's turned foliage and cold-after-autumn ordering.
`test_weather_profiles.gd` checks all eight preset channels.

The comparison exposed an older arch shading defect: flat double-sided faces
were forced to their authored normal even when the camera saw the back face.
The surface shader now orients its derivative normal toward the viewer, as
the original double-sided material does. The native regression samples the
actual arch patch: it must retain warm illumination rather than blue-black.
The source patch averages RGB (115.6, 98.4, 75.1); the corrected native patch
(138.7, 118.8, 95.0), versus approximately (36, 36, 36) before correction.
Intensity and fog still differ; this is not a claim of pixel parity.

`autumn-comparison.png`: native left, original right, matched camera and weather.
The native summit cap is softer and larger, and shadows differ. Canopy-bound leaf fall has since been added; see LEAVES.md.

`autumn-motion.mp4`: native autumn left, autumn amount zero right; otherwise
identical weather, camera and three-second simulation clocks. It shows the
seasonal paint/lighting on moving vegetation, not matched source animation.
