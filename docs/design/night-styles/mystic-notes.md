# Mystic night: status notes

Branch: worktree-agent-a43dbcd8e11087381 (based on 1f34b2e5).

## Where it stands
Finished first-to-fifth pass, seen in rendered stills (runs r1 to r5, in /private/tmp/zs-night/mystic). Best: r5/sky-b1-up.png (Milky Way), r5/sky-b2-low.png (teal veils), r5/planet.png, r3/sky-b3-up.png (violet veil shaft). `tests/test_night_styles.gd` passes headless.

Round notes: r1 showed a near-black dome, grey veils and a lumpy Milky Way (pebbles from strong lanes and wisps). Fixes: brighter violet-teal dome, saturated veil colours, softer lanes and wisps, wider patches, hue split so teal shows as well as violet. The planet is lavender, silver and teal bands, antialiased limb, rings with fine lanes; it is deliberately last priority.

## What was written
- Dome: violet overhead easing to teal at the horizon, with a thin teal air line.
- Veils (`zs_mystic_veil`, two curtains): foot height wanders slowly. Soft vertical rays come from noise sampled on a circle about the vertical (`zs_mystic_ring`), so there is no azimuth seam. Patches leave some sky clear. Teal and violet hue drift. Intensity is about 0.07 to 0.09, and rays fade by `pixel`.
- Milky Way: the old band structure, recoloured silvery-violet and made softer, plus ridged nebula wisps in teal and violet, drifting slowly. About 11 noise calls inside the band, with an early-out outside it.
- Stars: field cooled toward lavender-silver. A rare 7 percent (by seed) take a slow teal-to-violet colour breath. No twinkle.
- Planet body: lavender, silver and teal bands bent by slow noise, a luminous floor so the dark side stays dim lavender, a rim, and a one-pixel antialiased limb (`ndv^2 / fwidth(ndv^2)`).
- Rings: lanes from 1D noise at three scales, faded by `fw`, a wide gap and a thin gap, and colour graded lavender to teal. Faint inner glow, soft shadow.
- Glow: thin atmosphere rim and a faint halo.

## Change outside the file
None. The scaffold's soft ring penumbra replaced my earlier edit.

## Next steps
1. The 23:00 overview (capture_backdrop) was never rendered. Check the sky there. Also:
   - whether the veils are too faint or too strong (the multipliers 0.09 and 0.07 in `zs_mystic_light`);
   - whether the Milky Way has boxy artefacts;
   - whether the rays read as soft.
2. Crop the planet close-up (room direction (-0.73, -0.21, 0.65)). Check the limb antialiasing, whether the bands read, and whether the ring shadow penumbra looks right.
3. Check that `zs_mystic_veil`'s `v` coordinate gives tall enough rays. The ray noise uses `v * 0.9` as its height input.
4. Tune the dome, which may be too dark or too saturated.
5. Check the per-pixel cost, and that the veils' `room.y` range suits the ground-eye pitch.
