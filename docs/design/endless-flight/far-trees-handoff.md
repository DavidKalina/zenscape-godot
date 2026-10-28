# Far trees: weight, shade and shadows past 200 m

The complaint: distant trees looked flat and pale, pasted on, all alike.
Near and mid range were fine. `--far-trees=old` brings back the look before
this round (the sprites as they were, shadows to 430 m), to A/B.

## Causes found

Past FAR_CUT (200 m) every spruce is a camera-facing sprite from the baked
atlas (`scripts/endless/spruce_sprites.gd`, `shaders/endless_spruce_sprite.gdshader`).
Compared with the same trees as real crowns (`--spruce-far=700` puts crowns out
to 700 m; `--spruce-sprites=0` the old rings):

1. **Pale and low in contrast.** The atlas's mips average the crown's gaps,
   shaded boughs and tier undersides into one even tone. The 5th-percentile
   luminance of a wood strip at 200 to 700 m was 55 for sprites against 36 for
   crowns, and the sprites' hue sat mint where the crowns are dark blue-green.
   It is not the fog or the aerial term (about 1 % at 250 m) and not the
   lighting model: the sprite is lit as the crown is, but its light normal is a
   mip-averaged volume normal, so the shade side, the lower understorey and the
   dark pockets are gone.
2. **No shadows.** The sprites cast none (right, they are quads) and the near
   trees' shadow proxy (the `Shade` batch in `land_trees.gd`) was hidden past
   `NEAR_END` 430 m, though the sun's map reaches 900 m. From above the near
   trees cast long shadows and everything past 430 m cast none.
3. **All identical.** Every sprite had the plan's scale and one tone; the blue/green
   variety of `--spruce-look=b` is on by default but subtle.
4. **Nothing on the ground under the far woods** except what 1 gives.

## What changed

- `land_trees.gd`: the shade proxies' range is `SHADE_END` 860 m (was
  `NEAR_END` 430), under the map's 900 m reach (fade from 765). `--far-shadow=M`
  moves it. The proxy is the faceted crown, a tenth of the faces. The cost was
  not measurable (see below). The painted canopy (from 1250 m) takes the
  sprites' darker tone (`CANOPY_DARK` 0.78 over the atlas mean) so the sprites
  do not stand darker than the ground painted past them.
- `endless_spruce_sprite.gdshader`, under `far_look` (on unless
  `--far-trees=old`): a contrast stretch about the crowns' mean (`far_shape.w`
  0.35) then a value of 0.88 (`.x`); the lower 70 % of the tree darker, less
  from above (`.y` 0.32, a wood's understorey); the side away from the sun
  darker (`.z` 0.30, from the atlas light normal against `zs_key_direction`);
  per tree a size spread (`far_vary.x` 0.14, in over 120 to 300 m so the
  handover from the near crowns shows no pop) and a value (`.y` 0.2) and hue
  (olive to cool) spread from the foot's hash.
- `spruce_sprites.gd`: `far_look` and the two vectors, knobs
  `--far-trees-shape=value,under,shade,contrast` and
  `--far-trees-vary=size,tone`.

Not touched: `endless_ground.gdshader` (shadows come from the sun's map),
`grass_sheen.gdshaderinc`, `endless_motes.gd`, `grass_bit.gdshader`.

## Stills (1440x900, seed 1, rendered; before = `--far-trees=old`)

`scratch/ft/r_old/<view>.png` and `scratch/ft/r_new/<view>.png` for wood, cruise,
hills, forest, sun_toward, sun_away, high, and the extra views (in
`scratch/ft/ho.gd`) handover, hand2, low_far, far_wood, far_wood2, far_wood3.
Run `high` on its own: after another view it can show the land in an
unsettled bare state (sand), unrelated to this change. Side-by-side crops:
`scratch/ft/cmp3.png` (cruise, sprites against crowns), `cmp6.png` (handover),
`cmp8.png` (low view of the far woods), `cmp9.png` (the canopy hand-over),
`cmp10.png` (from above).

## Frame time (RTX 4070 SUPER, vsync off, `--time=240`, GPU ms median)

| view | old | new |
|---|---|---|
| wood | 7.60 / 7.58 | 7.49 / 7.45 |
| cruise | 7.90 / 7.68 | 7.77 / 7.77 |
| hills | 6.91 / 6.64 | 6.81 / 6.78 |
| forest | 8.58 / 8.42 | 8.49 / 8.44 |
| sun_toward | 7.63 / 7.34 | 7.52 / 7.57 |
| sun_away | 5.47 / 5.26 | 5.35 / 5.40 |
| high (solo) | 4.81 | 4.77 |

Two runs each; the difference is run-to-run noise (about 0.15 ms), so the
extra shadow range, a few more shadow-caster draws, costs under 0.1 ms.

## Open doubts

- The sprites are squatter than the real far crowns (the atlas mip's cover
  lift, `1 + 0.32 lod`, fattens the silhouette). Left alone: it keeps the mass
  and the alias down; a thinner lift would spike the silhouette more.
- Shadows stop at 860 m (the sun's map ends at 900); the painted canopy from
  1250 m has none. A ground contact blob under each sprite was considered and
  not built: the quad has no room under the foot.
- Looking toward the sun the far woods are now dark silhouettes (the old
  sprites glowed pale); that reads right to me, but it is the biggest change.
- The values (0.88, 0.32, 0.30, 0.35, 0.14, 0.2) were tuned by eye on seed 1 at the default hour; at --hour=17.5 the far woods go dark and take little of the low sun (scratch/ft/r_new/wood_h17.png), not tuned.
- Smoke check passes (`tools/smoke.py studies/endless_flight.tscn`, also with
  `--far-trees=old`). No tests were added or changed.
