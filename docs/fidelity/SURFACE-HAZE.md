# Surface aerial perspective

The default display compositor now applies source aerial.js surface haze before
compositing the separate air volume. --no-surface-haze provides a comparison.
Its extinction uses camera-axis depth, exponential height-profile integration
across the ray, a .4–2.2 density multiplier, elevation color and sunward warmth.
Weather supplies the source mist/haze/shroud density and squared shroud gate.
The sky is excluded by empty reverse-Z depth.

A CompositorEffect copies native depth and MSAA silhouette coverage into an
RG32F Texture2DRD. The CanvasLayer reads that texture after tone mapping, so the
haze does not receive a second tone curve. Allocation occurs before rendering,
not inside the compositor callback. Both single-sample and multisample inputs
are supported, along with logical viewport resizing. The scene deliberately
uses a fixed 1440x900 logical canvas when only its physical window changes.

Source evidence: the installed Three.js meshphysical shader runs tone mapping,
color-space conversion, then fog_fragment. WebGLMaterials.refreshFogUniforms
converts fogColor to the renderer's unlit uniform color space (sRGB when drawing
to the screen); the custom aerial sun uniform is supplied directly. These are
preserved as separate values, rather than using the volume's ACES fog display
color for both. Matched source appearance still requires validation.

Native GPU test_surface_haze verifies a plane exactly ten units from the eye,
its analytically expected post-tone exponential color blend, untouched sky,
partial MSAA coverage, logical resize, and the no-MSAA path. test_display_fog
passed with the first depth/haze integration; its atmosphere-only checks remain
separate from these surface checks.

Limitations: the surface pass sees the nearest depth-writing material. Blended
particles and the depth-write-disabled lake inherit the opaque surface behind
them, rather than receiving haze at their own depth. Water can therefore use
the lake bed depth; per-surface transparent treatment remains incomplete. MSAA coverage handles sky silhouettes, not separate haze at every mixed
geometry sample. Inversion paint now follows surface haze in this display pass; the retained
HDR comparison path is optional. The blend/order and source optical depth have
a separate native GPU regression (INVERSION.md). This pass does not
claim complete fog or water fidelity.

Implementation references:
- https://docs.godotengine.org/en/4.7/tutorials/rendering/compositor.html
- https://docs.godotengine.org/en/4.7/classes/class_renderscenebuffersrd.html

The native Autumn lighting/palette/arch regression also passes with surface haze
enabled. surface-haze-comparison.mp4 shows three seconds of the Mist preset:
new surface haze left, --no-surface-haze right, identical camera and motion clock.
Frame 45 was inspected on both sides. An earlier resolved-depth-only prototype
produced bright silhouette outlines; the published version uses MSAA coverage.
