# Canopy leaf fall

`tools/export_leaves.mjs` captures the original weather geometry: 520 particles,
their canopy positions, ground heights, speeds, phases, sizes and display colors.
The source currently supplies 57 broadleaf/thicket spots. The exporter verifies
the live broadleaf instance matrices against the saved imported scene before
writing the data; it does not invent release positions or shed from pines.

The native shader retains weather.js's mod-loop cycle, gust-dependent release,
sideways rocking, wind drift, lift, ground rest and fading. Release samples the
shared wind field at the cycle's birth distance. `zs_gust_field_at` permits that
historical lookup while the existing wind readers keep their current-distance
wrapper. The gust speed uses the mean wind dial, independently of its oscillating
strength envelope, as in the source.

Native quads retain the original circular point mask and 1–14 pixel projected
size. Their display colors use the native HDR conversion. The projection scale
must use the absolute vertical projection entry: Metal's flipped entry otherwise
clamped every leaf to a single pixel. The original fixed canopy-ground height is
retained, including its limitations when wind carries leaves onto different
terrain; this is not a new collision simulation.

Autumn above .02 enables the population, with individual release determined in
the shader. Clear weather disables it, and the shared paused motion/air clocks
hold falling and gust release. `--no-leaves` is the comparison control. The new
generic `--cam=distance,polar,yaw,targetX,targetY,targetZ` uses the source pose
format so native comparisons can target real objects without hardcoded views.

Validation: native `tests/test_leaves.gd` checks all 520 imported positions and
cycle attributes, seasonal gating, pause and the control. An isolated GPU draw
checks that the projected particles have visible area (11,745 colored pixels
in the tested close view). Existing puff tests cover the shared gust lifecycle.

`leaves-comparison.mp4` is four seconds, native leaves left and disabled right.
Both use Autumn, wind 1.15, identical air clocks and the first broadleaf canopy
at (11.64, 2.94, -3.34). It establishes visible motion against a control; exact
source GPU trajectory comparison and reveal-stage behavior remain to verify.

A matched source close-up confirms that the first canopy is intentionally
blossom-pink; its pale color is not an import defect. The source camera clamps
the requested distance 4, so that image is wider than the native close-up.
The native size regression reproduces 97 colored pixels with the old signed
projection scale and 11,745 with the correction.
