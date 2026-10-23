# Endless flight: the wind's sheen across far grass (look round)

From altitude the meadow past the tufts was a static painted carpet. Now soft light and dark swells roll downwind across it, like wind over wheat. Shading only: no terrain, collision or motion change.

## What changed

- `shaders/grass_sheen.gdshaderinc` (new): `zs_sheen_field(p, fp)` is a -1..1 lean from four wave trains (14, 30, 70 and 170 m between crests) on the same air travel (`zs_gust_distance`), wave speed, `zs_grass_offset`, gust bands, breeze strength and gust fronts the near tufts sway to, so near and far swells run on one clock. Each train fades to its mean once a pixel outgrows it, so nothing shimmers from 100 to 600 m. `zs_sheen_tone` turns the lean into a colour multiplier: crests lighter, troughs deeper, and a blade leant toward the sun / away from the eye shows its lit face. Leaning ones get a glint tinted by the key light (`zs_key_irradiance`), so dusk reads warm. The trains are long-crested bands (own `zs_sheen_crest`), not `zs_wave_crest_at`, whose skewed second train made a diamond lattice from far off.
- Hooks: `endless_ground.gdshader` (include plus one block before the flower drifts) and `endless_tuft_far.gdshader` (tone per tuft at its root, applied in full so a tuft and the paint under it match). Both fade it in over ring distance 28 to 85 m, past the near tufts. `endless_grass.gd`: two `GrassSheen.apply` lines.
- `scripts/endless/grass_sheen.gd` (new): the consts and flags.
- Near tufts are untouched. Flowers, regions, bare patches, silver undersides, grass_react and the moods are unchanged.

## Flags

- `--sheen=X` strength (0.8 default; 0 off, matches main). `--sheen-far=X`: extra strength at 400 m (0.25).
- `--sheen-tier=ground|tufts`: only that tier, for A/B.
- `--sheen-set=name=v[,v,v]`: any `grass_sheen*` uniform (`grass_sheen_waves`, `_share`, `_long`) on both materials.
- Consts: `STRENGTH`, `IN`, `FAR` in grass_sheen.gd.

## Cost

GPU, `viewport_get_measured_render_time_gpu`, 2560x1440 window, uncapped, 150 m over a meadow (seed 1, `--at=1640,580`), alternated 2 times: off 11.8 ms, on 12.25 ms, so +0.43 ms. CPU unchanged. Not measured on foot or at 400 m.

## Captures (`captures/grass-sheen/`, git-ignored)

- `sheet_150_and_low.png`: off / on at 150 m (top), and off / on 25 m up looking along the meadow (bottom, the near/far blend).
- `strip_150_time.png`: the same 150 m view at four wind times (settle 200, 600, 1000, 1400 frames, plane crawling at `--plane-speed=0.1`): the swells move.
- `sheet_400_golden_meadow.png`, `sheet_400_rosewater_dusk.png`: 400 m up, off | on (top: north, bottom: south).
- Also earlier iterations (`t_150_*`, `dbg_*`, `n_*`) and rough films (`film_*`, `play_*`: those cameras are not the real one, so ignore their tile edges).

## Weak spots

- Swells are soft. The strength is one knob if the user wants more punch; far off it rises with distance, cap by `--sheen-far`.
- A real motion film was not made: the stills at four wind times are the proof. Wave speed is the breeze's, so the roll is slow.
- Looking down from 400 m, the one-triangle far LOD tufts show as faint dashes with or without sheen (existing).
- On foot (low) the sheen is only past 28 to 85 m; near tufts keep their own sway.
- Tuft tone is per tuft (root), the paint's per pixel. They match at the swells' scale; not checked at the horizon in all moods.

## Tests

None added or run (prototype round). Smoke passes. No test is known to break.
