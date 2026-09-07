# Native surface weather checkpoint

Cold is now a live control, with snow weather setting its target to one and
clear/rain/storm resetting it to zero. Weather transitions preserve accumulated
ice and snow: clear cold weather holds snow, while warmth thaws it. Selecting
rain/cloud states does not instantly erase soaked ground.

surface_weather.gd ports the source cold response, precipitation phase,
snowpack integration, ice approach, groundWetAfter exact integration, suspended
drop persistence and waterfall flow-clock slowdown. Wet foliage darkens and
sags by its source tuning. Terrain and rock darken in fixed patches, with
mineral-dependent roughness; upward-facing surfaces receive the source
height/noise/slope snow mask. Sun and hemisphere illumination take source cold
tints.

The ice shader retains lake-ice.js's stationary fracture field, bubbles, clear
windows, wind-oriented snow, depth-dependent freezing and albedo/opacity.
export_ice.py regenerates that field. Water motion diminishes and the waterfall
clock stops at full freeze. Impact spray retires as the fall freezes. Detailed
cut/base ice coloring and exact source post-tone reflection remain unported;
current native HDR reflections are an adaptation.

Warm rain fills the suspended-drop state. When clouds clear in sunlight, this
drives an automatic rainbow. Hold rainbow supplies the manual floor; its reveal
now takes the source six seconds.

Validation: test_surface_weather.gd checks accumulation, dry-cold retention,
thaw/resume, pause, subdivision-invariant soaking, drying and suspended drops.
Native test_fidelity.gd covers weather transitions and automatic rainbow gating.
Native winter capture was inspected. winter-comparison.mp4 places frozen/snowy
native conditions on the left and warm native conditions on the right, same
camera, clock, wind and sun phase. It is a behavior comparison, not proof of
pixel parity with Three.js. Both recordings advance exactly six seconds; the
seven blank movie-writer startup frames are removed from the winter recording,
aligning its first rendered scene with the warm control. The published reel is
six seconds at 30 FPS.

Preset integration follow-up: selecting weather now sets the original rain,
cloud, storm, cold, wind, mist and haze targets together. Source presets are
extracted by export_weather_profiles.mjs. Existing Clear/Rain/Storm/Snow indices
are retained, with Fair/Overcast/Mist added. Wind reaches 2.5 in Storm and .8 in
Snow; the UI supports up to 3.0. Rain/cloud and air channels approach targets at
the source .55 rate. Manual wind/mist/haze values persist until another preset
is chosen. Haze has its own control; turning off valley mist leaves haze and
any dawn inversion intact.

The initial fidelity-study pose retains its existing custom wind/mist values
until a preset is selected. Autumn color and seasonal lighting are now implemented,
including Snow's autumn target. Canopy-bound leaf fall is implemented; see LEAVES.md. Profile
tests cover all eight presets, easing, pause and manual override behavior. See
AUTUMN.md for source comparison and the double-sided arch lighting correction.
