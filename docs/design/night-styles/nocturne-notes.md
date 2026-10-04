# Nocturne night sky: notes (WIP, unrendered)

Status: `shaders/night_nocturne.gdshaderinc` has a first-draft rewrite that has
**never been seen rendered**. The coordinator stopped all windowed runs. The
baseline capture (r0) also produced no stills (the first runs were killed when
the render lock was introduced, and the rerun wrote nothing). There are no
stills yet. `tests/test_night_styles.gd` prints PASS headless, which does not
prove the shaders compile under Metal.

## What the draft does
- Dome: slightly richer teal-navy, lifted toward the horizon.
- Milky Way: noise stretched along the band (across-band part scaled 2.6x) so
  structure runs as filaments; a slow spine wander; 3-octave glow, 3-octave
  ridge for wisps and dust lanes, plus one broken dark rift on the spine.
  8 noise calls on band pixels only, early outs elsewhere. Dusty rose to warm
  toward the core, with a cool haze.
- Planet body: latitude bands at three scales with streaked turbulence, grey
  poles, limb darkening, thin pale rim. Fine bands fade by fwidth(p.y).
- Rings: faint inner ring, bright broad B ring, Cassini-like gap at r 1.99,
  outer ring with a thin gap at 2.2; three lane scales fading by fw. Shadow
  edge antialiased by one pixel only (shade is binary from the caller).
- Glow: soft, warm-neutral, small, nothing over the disc but a faint rim.
- Stars: a few slightly warm or cool tints.

## Not done
- Clean antialiased planet limb. At night `sky_planet_body.gdshader` uses
  `ALPHA = presence * mix(face.a, 1.0, zs_night)`, so the style cannot fade the
  edge. Minimal fix outside my file: multiply ALPHA by
  `clamp((1.0 - s) / max(fwidth(s), 1e-4), 0.0, 1.0)` with
  `s = length(cross(radial, view))`. Not applied.
- Ring shadow on the body and a truly soft planet shadow on the rings: the style
  gets neither the sun nor the ring plane in the planet frame.
- The body is lit by the real sun, which at night may leave it a crescent or
  dark; judge on a render and consider a fixed key light.

## Next steps
1. Capture r0 (compare against commit 1f34b2e5) and r1:
   `/tmp/zs-render.sh --path . --windowed --script res://tools/capture_night_sky.gd -- --no-title --seed 184 --night-style=nocturne --sky-dir=/private/tmp/zs-night/nocturne/rN`
   Planet sits at room direction (-0.73, -0.21, 0.65); crop with sips.
2. Check the Milky Way for blocks or grain, band brightness (compare the 0.34
   glow gain with the old 0.38) and lane coherence; tune stretch, widths.
3. Check planet brightness, band contrast, ring visibility at ~60 px radius.
4. Apply the limb AA edit if the edge looks jagged.
