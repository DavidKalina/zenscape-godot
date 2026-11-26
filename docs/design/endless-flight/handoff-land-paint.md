# Land paint: noise from textures, skipped work

The ground's fragment shader (shaders/endless_ground.gdshader, endless_rock.gdshaderinc) is GPU-bound on value noise. This round swaps the paint's noise to baked lattices and skips work proven to give nothing.

**What changed**
- `er_tnoise` (rock include): er_vnoise from a 128^3 8-bit 3D texture, one filtered read at the smoothstepped point in place of eight hashes. Used by 15 rock-paint calls (drift, relief mixer, strokes, gullies, colour zones, stains, lichen, moss) and the bank/sand grit and bank clods.
- `zs_tnoise` (ground): zs_noise from a 256^2 texture, in `zs_fade`, `zs_patch`, the carpet specks/streaks, bloom dots, old-rock beds, bank stones, alpine stones, ice streaks and river water marks; in place of ep_noise for the river water only (grain, slicks, riffles, bars, fringe).
- Kept on the hashes on purpose: what the CPU or the tufts mirror (rock ragged edge, `endless_patch.gd` patches/regions/blooms, bank width, wind, silver, sheen), the edges (rock, sand, snow, river), and terms that magnify the noise into lines or offsets, where the filter's 8-bit weights could step (bed warp, plane warp, fissures).
- Gates, exact: the Peak tarn's water only where `peak_tarn_in` > 0; the Peak snow mask only above `pk_line - 120` (its edge reaches 98 m under, its band 20 m more), and the old snow edge noise only when psnow is off; summit caps' noise only where the land is proud and the noise's whole swing could lift it to the snow (`sm_snow`, `sm_far` still set as before); `peak_paint`'s rag only where ice or the gorge reads it; the fine cells' seam (strength 0) dropped.
- Tried, no gain (left out): Voronoi hashes from a texture (+0.2 ms), pruned 27-cell search, rnd hashed after the search, relief taps skipped by weight. The cells cost only ~0.2 ms in all.

**Old path**: `--land-paint=old` compiles the same file with `#define ZS_LAND_OLD` (EndlessLook.land_shader), the shader exactly as before; the new path carries no branch for it.

**Textures**: `python tools/bake_land_noise.py` writes assets/textures/land_noise_3d.png (16x8 slices, imported as Texture3D, lossless, no mipmaps) and land_noise_2d.png (lossless, no mipmaps, detect_3d off), fixed seed; then a headless import. endless_look.gd sets `er_noise_tex` and `zs_noise_tex`. 2 MB + 64 KB.

**GPU time** (frozen frame, old and new interleaved in one run, 3 reps each, whole frame ms):

| stop | 1920x1080 old -> new | 2560x1440 old -> new |
|---|---|---|
| canyon walls | 12.73 -> 11.69 (-1.04) | 16.79 -> 15.12 (-1.67) |
| meadow, wide river | 13.03 -> 11.69 (-1.34) | 16.64 -> 15.20 (-1.44) |
| meadow, creek | 12.48 -> 11.79 (-0.69) | 15.25 -> 14.48 (-0.76) |
| 300 m up (1080p) | 16.50 -> 14.98 (-1.52) | |
| Peak (1080p) | 12.50 -> 11.41 (-1.10) | |
| hour 16.5 (1080p) | 12.71 -> 11.75 (-0.97) | |

**Looks**: stills in scratch/ab/ (`*_pair.png` old left, new right; `*_diff.png`): line_s0/s1/s2, rockL_close_s0 (7 m off a lit wall), rock_close_s0 (shaded wall), high_s0, peak_s0, lowsun_s0. Same tones and scale of detail; the rock's blotches, moss patches, strokes and stains and the grass's specks sit in other places (a new lattice), so 15-40 % of pixels differ by more than 2/255, mean brightness within 0.3. Snow, ice and the Peak are unchanged (gates exact). No banding or tiling seen up close or from 300 m.

**Tests**: none read this shader's noise or parameters. test_sky_peak_look passes; test_ground_look fails on `reference_surface adds no varyings` (16 declarations), a file this round does not touch.

**Not done**: the mirrored ep_noise calls (~0.5 ms) would need endless_patch.gd and the C++ grass kernel to read the same lattice; the wind/silver/sheen zs_noise is shared with the tufts. Not flown by the user yet.
