# Lake shadow receiving

The original lake has `receiveShadow = false`; its stream explicitly enables
shadow receiving in `waterfall.js`. The original export preserved `castShadow`
but omitted `receiveShadow`. Consequently the native lake incorrectly received
tree shadows in addition to showing the shadowed lakebed through transmission.
This was the main cause identified for the dark blue appearance in shadowed water.

`tools/export_lake_wind.mjs` now preserves the live lake flag after matching all
996 vertex positions and colors. `tools/export_reference.mjs` also includes the
flag in future full exports. The native importer selects
`lake_reference_water.gdshader`, with `shadows_disabled`, for the lake whose flag
is false. Streams retain their shadow-receiving shader. Both shader entry points
include `reference_water_body.gdshaderinc`; water motion, ice, algae and lighting
remain shared. Growth classification recognizes the new lake entry point.

`--legacy-water-shadows` restores the previous receiver for comparison.
`--opaque-water-probe` removes native transmission for diagnosis;
`ZS_OPAQUE_LAKE=1 node tools/capture_lake_material.mjs` captures the source with
final shader alpha forced to one. This source probe must retain normal blending:
turning blending off leaves fractional canvas alpha and corrupts PNG comparison.

## Evidence

- Live source flag: false, saved in `assets/zen_reference/lake-wind.json`.
- Opaque source/native inspection isolated the brighter source water surface
  from lakebed transmission. The native surface incorrectly carried tree shadows.
- `lake-shadow-receiving-comparison.mp4`: corrected left, previous receiver right.
  Both clear/no-fog reels use camera `8,0.55,1.9,6.2,0.38,-3.4`, 90 frames at 30 fps,
  final clock 3.0, cloud drift `(-0.458715,0.012,-0.16055)`. The control is the
  preceding shadow-filter pass with identical filtering and algae settings.
- Frame 29 inspected against `lake-material-source.png`: removing received
  surface shadows brings shaded water much closer to the original green-blue.
- Native `test_fidelity.gd` passes, including stream/lake material classification,
  water depths, growth-related scene behavior, weather, pause and navigation.
- Native `test_lake_fetch.gd` passes 7,968 fetch values and all imported instance
  transform checks after rebuilding geometry.

This does not establish exact lake parity. Reflection/tone ordering, transparent
compositing, wave poses, glints, submerged detail and source shadow projection
remain to be matched. Other imported material receiver flags have not yet been
audited; the full exporter now records them for that follow-up.
