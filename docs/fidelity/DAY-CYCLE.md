# Day/night transition review

`tools/film_day_cycle.gd` captures one complete day over twelve seconds, starting
at phase 0.2. It advances the hour exactly once per recorded frame; camera,
weather and geometry remain fixed. This is an accelerated visual review, not
the speed of the normal eight-minute day/night cycle.

The first capture revealed a white band around the exposed island sides at
dawn. Inversion air already faded over the outer quarter of the island, but its
surface-color treatment did not. Both now use the same spatial fade. Interior
mist, height/depth behavior and display-space blending are retained.

`tests/test_inversion_surface.gd` checks the interior blend, no double tint,
sky and summit isolation, below-ground exclusion and positive-height island
edge exclusion through actual rendered pixels. The edge test uses a surface at
world z=14, where the mist volume has already faded out.

Capture with `--script tools/film_day_cycle.gd --fixed-fps 30 -- --clean
--film-frames=360 --film-dir=/private/tmp/native-day-cycle-final` using the native
Forward+ renderer. `day-cycle-comparison.mp4` shows the corrected scene on the
left and the prior scene on the right, including the dawn boundary artifact.
