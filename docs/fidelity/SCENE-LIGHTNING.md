# Whole-scene lightning calibration

The native bolt light now uses energy `flash * 900 / PI`, corresponding to the
source weather.js `PointLight.intensity = flash * 900` under the imported native
Lambert/GGX convention. It retains source color d8e8ff, range 160 and decay 1.6.
Source boltLight does not cast shadows, so the native extra shadow pass is off.
The lake's separately collected point contribution already uses these values.

`--legacy-flash-light` restores the old energy 12 for brightness diagnosis (it
does not restore the erroneous point shadows). `test_lightning.gd` checks full
pulse irradiance, shadow setting, range, decay and the strike/pause lifecycle.
All pass natively. The prior lake point-light GPU comparison establishes the
energy convention at four distances and three pulse strengths.

`scene-lightning-calibration.mp4` shows current left and previous right, both
storm/no-fog/manual strike, camera `8,.55,1.9,6.2,.38,-3.4`, 60 fixed frames at
30 fps. Both end at clock 2 and cloud drift `(-.804167,.008,-.281459)`. The right
reel predates both whole-scene intensity and shadow changes. Frame 2 inspected.

`tools/capture_storm_flash.mjs` captures the original at the same nominal camera,
weather dials and strike location (4,-2), three 1/30-second steps after triggering.
`storm-flash-source.png` shows the strong pale cliff/foliage illumination now
also present natively. Camera drift, vegetation phases and later repeated pulses
are not synchronized; this is not pixel parity or matched full-motion footage.
Water compositing and rainfall differences remain visible.

Short forced-exit lightning captures still report two ObjectDB instances leaked;
the standalone lifecycle test passes. The capture cleanup issue remains open.
