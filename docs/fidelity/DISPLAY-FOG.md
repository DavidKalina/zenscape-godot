# Display-space fog compositor

The display-space compositor is now the default in Forward+.
Use `./run-fidelity.command -- --native-fog` for the previous FogVolume
comparison. `--display-fog` remains an explicit alias for the default path.

The original weather renderer accumulates premultiplied fog color and opacity,
then composites over the already tone-mapped scene. Native FogVolume emission
is integrated before tone mapping. Inverse-transforming the emission color
does not make those operations equivalent for partially transparent fog.

The new path renders the shared atmosphere field into a half-resolution,
transparent SubViewport, then blends its premultiplied RGB over the 3D scene
in a CanvasLayer below the UI. The ray march uses the terrain/water height map
for occlusion, source plot bounds and source extinction. Sixty-four samples and
spatial filtering currently replace the source's shorter temporal march.
Native volumetric fog is disabled while this compositor is in use, avoiding
double fog. `--no-fog` hides the compositor as well.

Autumn cap and dawn inversion captures are substantially closer to the source:
the cap is muted rather than orange, and trees fade into the inversion with
the original display-space blend. The field includes the source altitude
afterglow contribution. Shroud and loosening are present. Temporal reconstruction and exact
source growth occlusion parity remain. Camera round trips and terrain
collapse/restore are covered by native GPU checks; an eight-second orbit
during formation was inspected. The
current height map, not arbitrary mesh depth, stops the march; this is also
how the original air renderer works, with consequences for protruding objects.

`tests/test_display_fog.gd` runs on the native GPU. It checks
empty-air scene-color identity, nonempty fog alpha, exact paused buffer state,
half-resolution dimensions, UI layering and removal of native double fog.
The display-space path does not use the native fog emission quantization workaround.

`display-fog-comparison.mp4` shows display-space fog left and the existing native
volume right, Autumn at the saved camera with identical three-second clocks.
It demonstrates the compositing difference, not complete source parity.

Storm was also inspected: the cap and lee spill remain terrain-occluded,
with rain visible through the composed atmosphere. Sampling grain remains
on steep fog boundaries; temporal reconstruction is still needed there.

Promotion checks: the integrated fidelity suite passes with the compositor
selected by default. Looking away yields an empty fog buffer; returning to
the original camera yields an identical buffer. Collapsing the terrain changes
the buffer, and restoring it restores the original bytes. The new compositor
does not repeatedly enable the native fog renderer during weather updates.

Shallow wind-torn bank controls are now available; see [SHROUD.md](SHROUD.md).

## Surface haze pipeline finding

The installed source Three.js meshphysical shader runs tone mapping, then color
space conversion, then fog_fragment (node_modules/three/src/renderers/shaders/
ShaderLib/meshphysical.glsl.js, lines 222–224). aerial.js replaces that final fog
chunk. weather.js adds inversion paint after it. This authoritative execution
order contradicts weather.js commentary claiming surface fog precedes ACES.
Do not implement surface haze as native pre-tone emission interpolation and
claim equivalence. A future surface pass must preserve the actual post-tone
blend, view-depth exponential falloff, height-integrated density, and directional
color. The compositor now includes a separate depth-driven surface haze pass before
the air volume; see [SURFACE-HAZE.md](SURFACE-HAZE.md). Inversion surface paint now follows that haze in display space; see
[INVERSION.md](INVERSION.md). Per-particle transparency and matched whole-scene
appearance still need work.
