# Thin fog color preservation

Storm's source haze value exposed green/olive fog above the peak. Disabling
ambient injection or temporal reprojection did not remove it. Constant sky
color did not remove it either. Constant neutral emission with the original
density field turned yellow; a dense, constant neutral volume remained gray.

Godot's [fog injection shader](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/shaders/environment/volumetric_fog.glsl)
multiplies emission by density, then truncates RGB into packed integer channels
using scales 511/511/255. Thin haze loses blue first; weak unequal RGB values
can retain only green. The sky background made this easier to see than the
terrain. It was not a sky shader or lighting-color defect.

`reference_fog_emission.gdshaderinc` stochastically rounds the density-weighted
channels before native packing. Its world-space hash and native volume
filtering/reprojection preserve average energy without a systematic color
bias. The fog shader applies the normal SDF boundary mask itself, before
rounding, so Godot does not rescale already rounded values at the volume edge.
Fog density, light colors, sky influence and ambient settings are retained.

Native Metal GPU regression `tests/test_fog_color.gd` renders a neutral volume
at density .015 and emission .2. The corrected mean display RGB was
(.115680, .115680, .115629), a .044% relative channel imbalance. With
`-- --control`, the same test reproduces (.087746, .087746, 0), a 100% imbalance,
and intentionally fails. This checks the actual renderer, not a CPU duplicate.

This helper depends on Godot's current fog packing scales; rerun the regression
when upgrading the engine. Fine stochastic texture remains a native rendering
adaptation, not exact source fog parity. The storm comparison uses identical
native weather, camera and three-second simulation clocks, corrected left and
uncorrected right. It validates removal of the tint, not source appearance parity.
