# Rain on lake surfaces

The source water.js rain-ring normal block is now generated into
reference_rain_rings.gdshaderinc by tools/export_rain_rings.py. It changes the
lake's world-space normal before lighting, Fresnel, reflection and glint.
The source cell spacing, hashed phase/location, radial gradient, decay and .8
tilt are retained. These are fine reflective ripples, separate from the larger
existing splash-crown particles.

The existing liquid-rain channel zs_foliage_wet is exactly weather.js uWet:
rain times the non-snow fraction. The existing water clock advances the rings
and pause holds it. Source gates are retained: wet > .01 and ice < .5. Rings
apply to lake tops; streams and vertical cut faces are excluded. The comparison
flag --no-rain-rings disables only this normal contribution.

Native GPU test_rain_rings checks a distributed normal field, exact held-clock
identity, propagation, the rain threshold and the half-freeze cutoff. The shader
block is extracted from the actual source, rather than independently rewritten.

rain-rings-comparison.mp4: three seconds, Rain preset, camera
8,.55,1.9,6.2,.38,-3.4, fog disabled for inspection. Effect left, normal contribution
disabled right; rain and splash particles remain on both sides. This demonstrates
integration into the lake's reflections, not source-matched full water fidelity.

Still missing: wildlife-contact rings from rings.js and their fish/frog triggers,
underwater detail and full water
reflection/absorption parity. Rain rings are procedural source surface normals;
they are not a new simulation of individual particle impacts.

Source fetch-dependent wind chop and whitecaps are now present; see LAKE-WIND.md.
