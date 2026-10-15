# City real fire, round 1: the real flame on everything that burns

Branch `look/city-real-fire` (from `roguelike` 6a8373a1). A look round: the visuals and the visible light changed, the gameplay did not.

Ask: PR #27 added `scripts/flame.gd` (a raymarched flame volume with sparks, smoke and a light; `docs/design/fire/round1.md`). Nothing used it. This round swaps it in for the fire visuals the game already has, sized and lit per piece, and keeps the cost down.

## What was swapped where

| Where | Before | Now |
|---|---|---|
| The wanderer's torch (`scripts/underground/underground.gd`) | a glowing egg (unshaded sphere) | `Flame` kind `torch`, scale 0.72, sparks, no smoke, no light of its own. `flame` is still a `Node3D` at the stick's tip, so `Fires.torch_point` / `torch_lit` / `set_torch` / `relight_torch` read it as before. The torch's own shadowed light (`torch_light`) and its flicker are untouched. The old sphere squash is dropped; the volume flickers itself. |
| City fires (`scripts/city_fire.gd`, used by every cresset, tower crown, wick spire, the tipped-bowl spill and the oil runnel's front) | flame cards on the campfire's toon shader, a spark pool, coals, halo, light | one `Flame` child per fire: kind `brazier` in a bowl (great cresset, cresset, crown, spire crown), `bonfire` for the tipped bowl's spill, `torch` for the runnel's running front. Sized by `flame` m x `FLAME_FIT` 1.4. `CityFire`'s API is unchanged (`light()`, `burn()`, `douse()`, `lit`, `heat`, `flame`, `bed`, `halo`, the light's range, energy and shadows, `lightings`), and its `heat` (flare and ease) now drives `Flame.burn`. The coals bed stays, at half strength; the halo stays as the far glow; the fire's own OmniLight3D stays. The old spark pool (`sparks`, `_embers`) is gone: the Flame's GPU sparks replace it, so the lighting burst of embers is now only the flare (flame taller and brighter for 0.9 s). |
| The oil runnel | its strip shader plus a card flame at the front | the strip shader is kept as is (a volume does not fit a line); only the front flame is a `torch` volume. |
| Niche lamps, hush-gallery lamp, mouse run (`scripts/city_kit_refuges.gd` `_lamp`) | a glowing sphere | a `candle` volume (scale 1.25) in the bowl. Past 26 m the old glowing bead stands in (a 5 cm flame is a pixel there). Their drawn light, `SightLight` and relight reach are untouched. |
| The roguelike's way lanterns and the start lantern (`scripts/roguelike/way_lights.gd`, `start_spot.gd`) | a glowing bead in the fire box | a `candle` volume in the box (`Flame.in_lantern`), burn tied to the day/night glow (0.55 by day, 1 at night); the bead stands in past 28 m. In `way_lights` the volume is child 1 and the bead is added after the light, so `get_child(3)` is still the light. |
| The kit isles' night lanterns (`scripts/kit_isle/kit_night_lights.gd`, the aqueduct study) | a batched glowing core | a `candle` volume per lantern, burn = the night glow (nothing drawn by day); the core batch is hidden, the halo batch is what reads from far. |

Not touched: the old toon campfire (`campfire_flame.gdshader`, `scripts/campfire*.gd`, the garden's fire), which the fire round left as card art on purpose, and the garden's stone lamps (a different game mode). Dragon eye-halos are not fires.

## Changes to `Flame` / the shader (shared)

- Shared unit mesh and material for all volumes (was one mesh and material per fire).
- New knobs: `with_light`, `with_sparks`, `with_smoke`, `vis_end`, and `burn` (0 out and hidden, 1 as the kind, over 1 flaring). A piece that eases its fire sets `burn` each frame; `Flame` only touches shader parameters when they change.
- `Flame.in_lantern(parent, at, far)`: the lantern candle used by the three lantern files.
- Lights: `distance_fade` (60 m begin, 24 m long, more at scale) on the Flame's light; `CityFire`'s light fades from 2.4 ranges out.
- Visibility ranges: the volumes draw to `110 m x scale_by` (24 to 420 m); sparks and smoke to 55 m x scale (min 1). Past that a fire is its halo, which `CityFire` already had in the same orange (`stone_lamp_halo`). Far beacon towers (200 to 300 m in haze) still show the volume because their flames scale up with `beam`.
- Shader: fewer ray steps (22 to 18 near), dropping to 6 by 24 box-heights away (the step count is cut by distance in box heights, so a big far flame and a small near one are cut alike); brightness is normalised per step, so the cut is not visible as a dimming.
- Shadowed fire lights: unchanged from the earlier city round (the great cresset's light was already shadowed; no other fire light is). I did not add any, and did not prove that one is cheap.

## Cost

The bench (`scratch/fire_bench.gd`, uncommitted) opens the fires yard rendered (960x540, vsync off, a full read-back each frame so the GPU is counted), lights the great cresset, terrace cresset, tower crown, spire crown, the 6 far towers and the torch (12 fires), and for each camera alternates five rounds of 20 frames with every fire shown and every fire hidden, taking medians. "Fires" cost = on minus off. The machine was shared with other agents' renders (load average about 10), so the frame itself swung 55 to 125 ms and each reading is good to about plus or minus 3 ms. Read them as "about the same", not as exact.

| View | Fire cost before (ms) | Fire cost after (ms) |
|---|---|---|
| great cresset, close | 2.4 | 3.4 |
| yard wide (4 lit + 6 far) | 2.4 | 4.3 |
| 6 far towers | 3.4 | 3.7 |
| torch, close | 2.1 | 3.8 |
| 24 extra lit bowls, wide | 5.5 | 2.8 |
| 24 extra lit bowls, near, 70 deg | 4.1 | not readable (a 125 ms off-frame spike); an earlier pass read 7.5 to 10.5 before the last step cut and the particle cut |

So: roughly +1 to +2 ms in a 60 ms frame for a handful of fires, and the 24-bowl stress is no worse than the card flames and spark pools it replaces (the old multimesh pools and a camera-facing glow per fire are not free either). One caution: the stress runs cost 3 to 10 ms for 24 fires with their lights on this card at 960x540; at 1440x900 and near a bowl the volume fills more pixels. If a layer ever stands dozens of lit bowls in sight, lower `Flame.VIS_PER_SCALE` or `PARTICLE_REACH`, or `steps` in the shader (all one-line knobs). I did not benchmark a whole run layer with many lanterns lit, only smoke-checked it.

## Stills (before left, after right)

Not committed (images are ignored by the repo). They are in the round's worktree: `captures/shots/fire_before_*` and `fire_after_*` (34 PNGs) and three sheets:
- `fire_sheet_cresset.png`: the fires yard lit, the great cresset close, the beacon tower's crown.
- `fire_sheet_torch_haze.png`: the wanderer's torch close and from the play camera, then the far beacon towers in haze.
- `fire_sheet_lamp_runnel_spill.png`: a niche lamp, the runnel's front, the tipped bowl's spill from above.

Judged by eye: the flames read as fire with real licks and a pale heart over the basalt; the warm light on stone is the same dim orange as before (the lights' colours and energies were not changed). The torch is now a flame on a stick instead of an egg. The lamps read as a wick flame.

## Limits and notes

- The lanterns of `way_lights` / `start_spot` do not show in the sprawl seed 1 run's start (not found in the scene), and the kit-isle night lantern's still came out inside a rail; those three changes are proven by the smoke runs only, not by a still. Please eyeball one.
- A flame is a vertical teardrop: a runnel's front on a wall is a small upright flame, partly hidden by the wall's depth (the volume stops at scene depth). It reads as a bright head on the strip.
- The spill's flame is a bonfire at the old spill height; from a low camera behind the fallen bowl it is hidden by the bowl.
- Smoke is off for the runnel front and the spill, on for bowls (faint grey; faint by day as the fire round noted).
- The torch's light is still shadowed and unchanged; I did not touch it (earlier finding: shadowed lights under the torch fog stalled rendering, but it was already this way).
- The yard was proven on its own look only (torch preset; haze for the far towers). `--day` was not shot.

## Proof

- Smoke (headless, 0 errors): `fire_study`, `city_fires_yard`, `city_refuges_yard`, `city_breaks_yard`, `city_kit_gallery`, `aqueduct_isle`, `run_layer` sprawl (seed 1) and ring (seed 2, `--underground=torch`).
- Through the real play loop (`scratch/fire_play.gd`, not committed): stood a cresset, walked him to it with the stick, jumped onto its plinth with the jump input, his torch touched the bowl and lit it (`torch_lightings` 1, flame drawn), a headless Olmec in reach took the beacon (`beacon_turns` 1), `douse()` and `light()` work, and the torch can be doused (T). The same run on the old code gives the same lines. Note: a whole Olmec that is already hunting him does not turn to it, as before.
- Tests: no test references these scripts. `test_night_fill` and `test_night_styles` pass. No test broken; the full suite was not run (prototyping).

## Open questions

- FLAME_FIT 1.4 makes the cresset flames taller than the old cards (a teardrop's tip is thin). Taller or shorter?
- Should the great cresset's shadowed light stay? Nothing changed, but now that the volume reads real, an unshadowed light might do.
- The torch's flame scale (0.72 of the kit's torch): it is large next to his hat in the play view; smaller would read more "held".
