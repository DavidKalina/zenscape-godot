# Grass tall (endless flight)

Blades are 4x taller by default (2x first; the user flew 3 and 5 and chose 4); `--grass-tall=X` (1.0 = the old grass, clamped 0.25..6).
Only scripts/endless/endless_grass.gd changed (no shared flora/shader code): `TALL`/`tall`
scales the FINE tuft mesh's vertex Y (width unchanged), the far ring's `grow_near` and
`grass_ring_grow` tall sizes (so the near/far handoff stays matched), and the near
material's `sway_shape.y` (sway arm; taller blades bend proportionally). Shading along
the blade, silver and reactive bend read blade-relative values and followed with no change.
Not scaled: `--grass-fine=0` (isle tuft) near ring; flowers (partly hidden in the grass
at meadow height; from cruise they read as before); the painted ground (no retune needed).
Stills: captures/grass-tall/{low,alt14,alt70}_t{1,2}.png, `--seed=1 --at=1640,580 --heading=0`.
Smoke passes at 2 and 1. No frame-time change measured (same triangle count).
