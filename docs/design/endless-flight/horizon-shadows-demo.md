# Terrain horizon shadows: demo

`--terrain-shadows=1` turns it on; **K** turns it off and on in flight for an A/B.

The sun's shadow map reaches 900 m, and only land chunks of level 2 or below cast
into it (about 650 m round the eye). Past that, the land had no shadows: a range
never shaded the valley behind it. This demo adds them.

- `scripts/endless/land_horizon.gd`: a square of the field's heights round the
  eye (16 km x the draw distance, 1024 texels; 192 without the native field),
  made on a worker (0.9 to 1.1 s on this PC), made again after the eye has moved
  1/8 of the square.
- `shaders/land_horizon_bake.gdshader`: a SubViewport pass (half float) marches
  it for the land's horizon toward the key light's bearing (sun, the moon by
  night; 48 steps, out to a few km), and in 8 ways for the sky each spot sees.
  It runs again when the bearing has turned 0.25°.
- `shaders/land_horizon.gdshaderinc`: the ground compares that horizon with the
  light's height each frame (`zs_horizon_key`), so shadows slide as the sun
  sinks. It takes the sun's share off ALBEDO, the way cloud shade does, and the
  sky term off the hemisphere fill. Inside 600 to 860 m of the eye, only
  occluders more than 220 m off count, so near hills are left to the sun's own
  sharp map.
- Two viewports: each march goes into the one not shown and fades in over the
  last for 1 s (`zs_horizon_was`), so neither a recentred square nor a re-march
  pops.

Pop fix (round 2). Played, whole shadows jumped. Two causes: the first version
baked lit or unlit for one sun height and re-marched every 0.2°, which at low sun
moves a 1000 m peak's shadow tip hundreds of metres at once; and a recentred
square shades at once land whose occluders were past the old square's edge.
Probe (`scratch/horizon_flicker.gd`, a still camera at dusk with the day running,
counting pixels whose luma jumps 0.02 in a frame): before, 0.46 % of pixels
jumped every 74 frames, and 0.35 % on a recentre; after, at most 0.05 % and
0.03 %, the same as with the shadows off. The GPU's horizon matches a CPU march
at six texels, so the HDR viewport doesn't colour-convert it.

Seen at 17:30, from 500 m and 1500 m up: long shadows across the lowland from the
peaks. At noon it's almost the same as off, with no acne. Stills:
`captures/shots/terrain_shadows_ab.png` (high_down off/on, alt_side off/on).

Not done:
- Only the ground takes it. Trees, grass tufts, the sea, rivers' water, rocks and
  arches stay sunlit inside a far shadow.
- GPU cost not measured. The bake is about 150 texture reads per texel over 1M
  texels, about once a second while the day runs; the ground reads two textures.
  The sky term could bake only when the square moves.
- Between marches the shadow's bearing lags the sun's by up to 0.25°, a few tens
  of metres sideways at a 10 km shadow's tip.
- The sky term is subtle; strength not tuned.
- Smoke check passes with the flag on. No committed tests (a prototype).
