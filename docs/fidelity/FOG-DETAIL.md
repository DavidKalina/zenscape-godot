# Native fog sampling

This applies to the retained `--native-fog` comparison renderer. The default
now uses the display-space compositor documented in DISPLAY-FOG.md.

The default Godot fog buffer uses base size 64 and 64 depth slices. At the
saved distant camera, that blurred the source's thin summit cap into a rounded
glow. Captures at 128 and 256 showed the outline becoming flatter and more
defined. The project now uses base size 256 and 256 depth slices.

These are the documented
[volumetric fog detail settings](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-property-rendering-environment-volumetric-fog-volume-size).
They increase GPU rendering and memory cost. Frame-rate investigation remains
paused; no performance improvement is claimed.

The density field, source cap dimensions and light coefficients are unchanged.
`fog-detail-comparison.png` crops the same Autumn camera: finer sampling left,
previous default sampling right. It demonstrates the outline improvement, not
an exact source match. The source still has different cap brightness and
translucency: it composites its integrated fog in display space, while the
native volume integrates the adapted emission before tone mapping. Resolving
that requires a compositing change, not more sampling alone.

Storm and dawn-inversion native captures were inspected. The neutral thin-fog
GPU regression still passes: mean RGB (.116416, .116416, .116374), relative
channel imbalance .036%. The color-quantization correction remains necessary.
