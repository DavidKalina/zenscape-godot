# Lake reflection and glints

The normal lake path now collects directional Lambert/GGX lighting, hemisphere
light and afterglow before applying sky reflection and source sun/moon glints in
display RGB. `reference_lake_lighting.gdshaderinc` evaluates the unshadowed lake
key/rim contribution from current celestial colors, directions and irradiance.
The native light processor suppresses those directional contributions to avoid
double lighting. Stream lighting remains on the native shadow-receiving path.

`reference_tonemap.gdshaderinc` converts the complete directional/ambient result
to display RGB, applies reflection then glints, and converts back to native HDR.
This avoids the broad orange sheen seen in the rejected inverse-color HDR mix;
that experimental integration has been removed. `--legacy-lake-lighting` restores
the prior native path. `--no-lake-glints` disables the source glint weight, and
`--lake-lighting-probe` exposes the collected light without reflection.

## Validation

- `test_lake_complete_lighting.gd`: actual native Lambert/GGX and collected light
  match within RGB vector error .015 at roughness .22, .5 and .86.
- `test_lake_display_composite.gd`: nine actual ACES output cases pass and reject
  the earlier HDR blend. `test_lake_glints.gd` covers sun/moon weights, color,
  cloud suppression, broad lobe and freeze cutoff.
- Native `test_fidelity.gd` passes with the integrated path enabled.
- `lake-display-reflection-comparison.mp4`: corrected left, legacy right. Both
  90-frame/30-fps reels use clear weather, no fog and camera
  `3,1.108864,-0.982801,6.2,0.38,-3.4`, ending at clock 3 and identical cloud drift.
  Frame 29 inspected in both against `lake-glints-source.png`: native source
  glints are restrained pale highlights rather than the rejected orange sheen.

## Remaining fidelity work

The source lightning point contribution is now included before the display
blend; see `LAKE-LIGHTNING.md` for GPU comparison and storm response evidence. Native HDR transparency blending, fog depth on transparent
water, exact ice reflection/cut ordering and source wave poses also remain.
Thus this is integrated directional/ambient reflection progress, not complete
water parity. The helper assumes the fidelity environment's ACES white point 16.

Source captures can use `ZS_LAKE_CAMERA=radius,polar,yaw,x,y,z` with
`tools/capture_lake_material.mjs`. Radius 8 at this reflected-sun angle is blocked
by the cliff; radius 3 provides the visible lake comparison.
