# Wind-torn fog bank

The default Forward+ display compositor now implements the source weather.js
shallow shroud bank: noised lid, windward erosion, gust-shaped retained patches,
fluidity-dependent travel and thinning, and puff/downburst holes. Coverage and
fluidity are independent sliders. CLI: `--shroud=0.7 --loosen=1`.
Both default to zero, preserving the existing unshrouded scene.

The bank converges toward the source ACES/sRGB fog display color from the current
celestial/weather palette. Shroud suppresses the compositor’s inversion and
orographic cap as in the source. Existing wind consumers retain their original
field wrapper; the fog can additionally read the puff/downburst contribution.

Validation: native Metal test_display_fog checks coverage, fluidity, wind, empty
color identity, pause, camera return, growth occlusion and layering. The existing
puff lifecycle/field test passes. shroud-comparison.mp4 is three seconds, effect
left (coverage .7, fluidity 1), control right (coverage 0, fluidity 1), with matching
camera and simulation clock. Frames 45 and 80 were inspected: the shallow bank
veils trees while the mountain peaks remain exposed.

The bank now drives source sun dimming (up to 14%), atmospheric sun color,
orographic strength and automatic rainbow suppression. It leaves the dome,
hemisphere tint and explicit rainbow floor intact. test_shroud_weather passes
headless and native Metal for coverage .25, .5 and 1, including clearing back
to the original daylight.

Surface distance haze and the squared aerial gain are now connected in the
post-tone surface pass (SURFACE-HAZE.md). Still incomplete: automatic reveal choreography; matched source motion and
color validation. The retained --native-fog comparison path does not implement
shroud, so its bank controls are disabled. This is not full fog parity.
