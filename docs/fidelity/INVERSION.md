# Native dawn inversion

The source daynight.js inversion strength and lid altitude now drive a native
fog volume and surface treatment. It forms during a clear, calm late night and
early morning; wind above .9 starts breaking it, overcast prevents it, and sun
elevation .05–.24 burns it away. Dusk has no inversion. The source fixed patch
field lowers thin places first, with slow noise rippling the upper surface.
Terrain growth gates the volume. Ordinary mist and inversion are independent.

The default surface paint now runs after surface aerial haze and tone mapping,
then the separate air volume composites over it. The shared source lid/depth
helper includes the previously missing +0.2-band extension above the lid.
The native material tint is disabled while the post-tone tint is selected,
avoiding double application. --native-inversion-paint retains the HDR blend
for comparison (using the corrected source optical-depth rule).

Cloud/fog colors no longer receive an extra native night multiplier absent
from weather.js. The inversion's shared color uses the source fog tint, alpen
shadow line, sun intensity, ACES display mapping and white lift. Ground range
(.15–12.6268235) and source exposure (1.15) remain the captured scene's values.
Shroud suppresses the volume as in the source. General generated-world configuration remains pending.

Validation: capture_inversion.mjs reads the live original at the saved seed-7
camera, phase .26, cloud .06, mist .45 and wind .4. It saves source uniforms and
a rendered reference. Native test_inversion.gd matches strength, lid and three
color vectors to within 2e-5, checks sun/wind/cloud gates and independence from
ordinary mist. test_fidelity.gd passes after integration.

inversion-comparison.png: Godot LEFT, original Three.js RIGHT, matched camera
and environment dials. Both images were inspected. The native volume is softer
and tree silhouettes differ; this is not full volumetric pixel parity. Source
capture advances one second, native capture waits its real-time threshold, so
wind and wildlife are not frame matched. Moving burn-off and night-cloud
comparisons still need inspection. Separate water materials now share the surface-paint helper and native air
volume; their reflection/color blend is still a native HDR adaptation.

## Post-tone validation

test_inversion_surface.gd uses a depth-writing reference-material plane with a
known optical depth. Its final pixel matches the source display-space mix over
surface haze; a deliberately re-enabled HDR tint fails that expected result.
Sky pixels and surfaces above the lid band remain unchanged. The source color
and weather-gate state test also passes. The depth bridge now skips allocation
in headless tests, where no RenderingDevice exists.

inversion-display-comparison.mp4 shows the post-tone surface tint left and HDR
surface tint right, with the same display-space air volume, phase .26, mist .45,
haze .03 and three-second clock. --haze now allows pinning that source dial.
The new native frame at one second was also inspected beside inversion-source.png:
the broad dawn sea and plinth color agree closely, but tree silhouettes, shadows
and local air shape still differ. This is a rendering-order correction, not
full scene parity. Transparent particles and the depth-write-disabled lake still inherit underlying
opaque depth in the post pass; their separate-depth treatment remains incomplete.
