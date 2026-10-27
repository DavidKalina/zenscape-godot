# Terrain horizon shadows: demo

`--terrain-shadows=1` turns it on; **K** turns it off and on in flight for an A/B.

The sun's shadow map reaches 900 m, and only land chunks of level 2 or below cast
into it (about 650 m round the eye). Past that, the land had no shadows: a range
never shaded the valley behind it. This demo adds them.

- `scripts/endless/land_horizon.gd`: a square of the field's heights round the
  eye (16 km x the draw distance, 1024 texels; 192 without the native field),
  made on a worker (0.9 to 1.1 s on this PC), made again after the eye has moved
  1/8 of the square.
- `shaders/land_horizon_bake.gdshader`: a SubViewport pass marches it toward the
  key light (sun, the moon by night; 48 steps, out to a few km), and in 8 ways
  for the sky each spot sees. It runs again when the light has turned 0.2°.
- `shaders/land_horizon.gdshaderinc`: the ground reads the shade
  (`zs_horizon`, `zs_horizon_at`). It takes the sun's share off ALBEDO, the way
  cloud shade does, and the sky term off the hemisphere fill. Inside 600 to 860 m
  of the eye, only occluders more than 220 m off count, so near hills are left to
  the sun's own sharp map.

Seen at 17:30, from 500 m and 1500 m up: long shadows across the lowland from the
peaks. At noon it's almost the same as off, with no acne. Stills:
`captures/shots/terrain_shadows_ab.png` (high_down off/on, alt_side off/on).

Not done:
- Only the ground takes it. Trees, grass tufts, the sea, rivers' water, rocks and
  arches stay sunlit inside a far shadow.
- GPU cost not measured. The bake is about 150 texture reads per texel over 1M
  texels, roughly once a second while the day runs. The sky term could bake only
  when the square moves.
- The sky term is subtle; strength not tuned.
- Smoke check passes with the flag on. No committed tests (a prototype).
