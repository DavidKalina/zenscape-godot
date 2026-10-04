# Nocturne night sky: notes

Status: finished for now. Rendered 4 rounds (r0 draft baseline to r3).
Stills: /private/tmp/zs-night/nocturne/r0 (baseline draft) and r3 (final);
sky-b1-up.png shows the Milky Way, planet.png the close-up.

## What it is
- Dome: teal-navy lifting toward the horizon.
- Milky Way: smooth dusty-rose river, noise stretched 4x along the band so it
  reads as filaments; soft dust lanes from a low-frequency stretched fbm plus a
  thin spine rift; warm toward the core. About 8 noise calls, band pixels only.
- Planet: banded gas giant (three band scales, streaked turbulence), limb
  darkening, thin rim; a fixed night key light from upper left (the real sun can
  leave it dark); fine ring lanes with a Cassini-like gap and an outer gap.
- Stars: a few faintly warm or cool tints.

## What we learned
- r0: Milky Way was grey-lavender with big dark blobs; planet dark (night sun).
- Ridge-noise lanes made a cracked vein network: replaced by soft fbm lanes.
- Haze and rose must be warm-biased or the display grade turns rose to mauve.

## Weaknesses / next
- Dark lanes are subtle; the band could use one or two bolder long lanes.
- Stars are sparse and tiny in the band; the star hook only tints them.
- Ring edges show faint ghost lanes at the outer rim.
- Planet deprioritised: the user finds it distracting and may remove it.
