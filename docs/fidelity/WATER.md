# Native water checkpoint

The water slider scrubs the source growth channel. Refill water replays it
without regrowing foliage, and Y includes water between terrain and plants.
P freezes the shared animation.

export_water_growth.mjs builds the source water in a temporary browser module
that exposes its procedural strand arrays. It leaves source files unchanged,
checks stream/lake geometry against the imported snapshot, and records a source
strand sample at time 1.25, travel front .47, no wind. water-growth.json retains
centers, travel times, ring frames and dimensions, aeration, steepness, facet
bands, stream centers/arrival coordinates and the lake bed/level.

The native strand shader uses the source advancing nose, ring swell, inward
chop, aeration palette and squared-drop wind bend. Stream rings collapse to
their centerline until reached. The source fill curves drive the falling front,
stream arrival, lake bed-to-level rise and late glint. Existing stream ripple
and lake shading approximations remain; this is not complete water parity.

Rain/fog sample terrain separately from water. The lake follows its current
waterline; stream height is gated by a second map carrying arrival time,
normalized cross-stream width and centerline height. These 128-square nearest-sampled maps do not
replace exact deformed-mesh collision. Spray starts when the fall reaches the
impact, clearing old hidden particles when refilled.

Validation: test_water_growth.gd verifies lake visibility/height/depth, imported
stream attributes, water-only replay, arrival-map coverage and imported strand
parameters against 648 original source vertices (maximum error 4.81e-7).
That numerical check validates the parameters/equations on CPU; native captures
also compile and exercise their shader implementation. Existing fidelity and
growth checks pass.

Remaining: individual foam ledge gates and bobbing, exact post-tone reflections,
source stream speed/ripple detail, lake absorption/reflection parity, lake rays,
submerged detail, ice cut/base detail, algae, reactive ripples and sound. Core ice
fractures, snow cover and freeze/thaw now work; see SURFACE-WEATHER.md. Captured foam/rings are
currently gated together at water .5.

water-growth-comparison.mp4: native refill left, native empty-water control
right, matched detail camera, seed/time/weather; six seconds at 30 FPS. This
shows the added behavior, not a source pixel-parity comparison.

The current reel advances the scene once per recorded frame, even when the
window is occluded. Both reels report exactly 6.0 seconds of scene motion and
identical final cloud drift. Start, early front, fill, middle and end frames
were visually inspected.

Water lighting follow-up: lake and fall now share the terrain's Lambert/GGX
direct-light gate, alpenglow, hemisphere light and inversion paint helpers.
The fall uses original scattering emissive (including ice/night response) and
sky reflection weighted by aGlass=1-aeration, source Fresnel and the squared
smooth-glass mask. Native blends occur in HDR; source blends happen after
color conversion, so this is not full pixel parity. Day/dusk native captures
were inspected; the water-growth and scene fidelity checks still apply.
