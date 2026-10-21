# Endless flight: the grass rings' handoff (prototype round)

The problem: grass and flowers seemed to shrink as you flew toward them. The far ring's tufts were drawn 2x wide and 1.8x tall, then shrank to nothing between 30 and 16 m (3D) as the thin near tuft came in. The flower drifts' far tufts showed as big coloured clumps and shrank away, leaving small flowers. Because the distance was 3D, flying 15 to 30 m up put the ground right under you inside that band.

## What changed

- **One ring distance** (`shaders/endless_ring.gdshaderinc`, uniform `ring_lead`, and `EndlessGrass.ring_d()` on the CPU). It is measured along the ground. Past FLAT_UP m over the ground, the eye's height counts: `d = sqrt(R^2 + rise^2)`, with `rise = (over - FLAT_UP) * RISE`. The ring is also led ahead along the camera's level view direction, k = LEAD. A ring R m out stands R(1+k) ahead, R(1-k) behind and R*sqrt(1-k^2) to the side. That is a disc of radius R centred kR ahead, so it holds the same number of tufts as an unled ring. The lead follows the view (not the plane's nose), damped at LEAD_RATE, and fades out when looking steeply down. Five places read the same distance:
  - the near tufts' ring (`reference_surface`: `grass_ring`)
  - the flowers' thinning (`flower_far`)
  - the far tuft shader
  - the painted ground's `carpet_near`, `carpet_reach` and `bloom_fade`
  - cell streaming
- **reference_surface stays unchanged for the isles.** `ring_lead.w == 0` (the default) keeps the plain 3D distance.
- **The far tuft shader** (`shaders/endless_tuft_far.gdshader`):
  - Each far tuft comes up at its own distance in `grass_ring_in` (LOD.x-SOFT .. LOD.y-SOFT, over SOFT). That is the interval where a near tuft of the same rank shrinks away, so cover is handed over tuft by tuft rather than all tufts scaling together.
  - Where a far tuft comes up it is `grow_near` = FAR_NEAR (1.5 wide, 1.0 tall: the near tuft's height). It grows slowly to FAR_GROW (2.0, 1.8) by LOD.z (`grass_ring_grow` is now (LOD.y, LOD.z, FAR_GROW)). The old `grow_from` uniform is gone.
- **Flower-drift tufts** are now marked by their instance alpha, (kind+1)/16:
  - Their tint stays the grass tint. The shader puts the drift's colour (`wash_colours[8]`, endless_patch KINDS) on the upper blades (`wash_tip` 0.3..0.75).
  - They come up over `wash_in` (FLOWER_FADE) as the drawn flowers go, not in the grass band.
- **Flower detail.** The flowers' leaves and buds now shrink away over FLOWER_DETAIL (14..30 m ring distance, `flower_lod`).
- **Cell streaming** (`endless_grass.gd`):
  - The cells wanted and kept follow the led discs.
  - The queue and the standing order go by ring distance, so cells ahead grow first.
  - It replans when the lead turns.
  - The near layer stops once its grass ring is gone (rise >= LOD.y), so its flowers alone don't keep cells.
  - The batch visibility ranges are widened by (1+lead) plus FLAT_UP.
- **The study.** `studies/endless_flight.gd` passes the drawing camera's forward to `grass.step()` and `grass.prime()`.

## Knobs and flags (defaults)

| | default | flag |
|---|---|---|
| LEAD (k) | 0.45 | `--grass-lead=X` (0..0.85), `--no-grass-lead` |
| LEAD_RATE, LEAD_LEVEL | 3 /s, view level share 0.2..0.55 | |
| FLAT_UP | 20 m | `--grass-flat-up=M` |
| RISE | 1.6 (near grass gone from about 39 m over the ground; far ring from about 164 m) | |
| FAR_NEAR | (1.5, 1.0) | `--far-set=grow_near=W,H` |
| FLOWER_DETAIL | (14, 30) | |
| far `wash_tip` | (0.3, 0.75) | `--far-set=wash_tip=a,b` |
| round 5's rings for A/B (3D, no lead; the new tuft handoff stays) | | `--grass-ring=3d` |

Every existing flag still works (`--grass-lod=`, `--grass-range=`, `--grass-set=`, `--far-set=`, `--ground-set=`, `--no-grass`, G and the rest).

## Measured (headless, real time `--no-fixed-fps`, seed 1, `--at=1200,1150`, 15 to 25 s straight flight; scratch/grass_handoff/fly.gd)

The rows below are means. "Holes" counts frames with a near cell inside LOD.x wanted but not yet stood.

| run | speed | eye over ground | near cells / k inst | far cells / k inst | lag mean / max cells | holes | grow ms mean / slowest |
|---|---|---|---|---|---|---|---|
| cruise, alt 10, 3D (old rings) | 16.1 | 20 | 7.4 / 272 | 56.9 / 348 | 0.64 / 2 | 0 | 386 / 1939 |
| cruise, alt 10, new | 16.1 | 20 | 7.4 / 271 | 55.6 / 343 | 0.68 / 2 | 0 | 444 / 2026 |
| boost, alt 10, 3D | 25.0 | 21 | 6.8 / 251 | 56.9 / 347 | 1.18 / 2 | 0 | 417 / 1960 |
| boost, alt 10, new | 25.0 | 21 | 6.9 / 254 | 55.9 / 341 | 1.15 / 3 | 0 | 430 / 2022 |
| boost, alt 3, 3D | 24.9 | 13 | 6.9 / 253 | 55.5 / 338 | 1.27 / 3 | 12 frames | |
| boost, alt 3, new | 24.9 | 13 | 6.9 / 253 | 54.2 / 335 | 1.28 / 3 | 0 | 469 / 1936 |
| boost, alt 25, 3D | 24.9 | 35 | 1.2 / 44 | 56.5 / 344 | 0 | 0 | |
| boost, alt 25, new | 24.9 | 35 | 6.4 / 235 | 54.8 / 338 | 0.99 / 2 | 0 | |
| boost, alt 60, new | 24.9 | 70 | 0 / 0 | 50.9 / 315 | 0 | 0 | |
| boost, alt 120, 3D / new | 24.9 | 130 | 0 / 0 | 43.6 / 266 vs 30.0 / 185 | 0 | 0 | |

- Low down, the near tuft count is unchanged (the lead keeps the same area). Cells keep up at cruise and at top speed, with at most 3 cells ahead still growing.
- The cost moves in one band: with the eye 30 to 40 m over the ground, the near carpet is still drawn where the 3D rule had dropped it (235k against 44k instances at 35 m). At the start altitude (45 m, eye about 55 m) there is no near ring, as before. High up, the far ring is smaller than before.
- GPU frame time was not measured.

## Captures (scratch/grass_handoff/shots/, `before_*` = main, `after_*` = this round; scratch/grass_handoff/views.gd)

- `low`: 2.5 m up. The before shot shows a wall of tall far clumps behind the fine carpet. The after shot has none.
- `mid` (14 m) and `high` (28 m): before, the ground under the eye was coarse, fat far tufts. After, it is the fine carpet.
- `drift` and `drift_mid`: before, big yellow clumps came near and shrank. After, the drift's colour is on far-tuft tips past the flowers, with small flowers near.
- `bank`: the camera turned 110 degrees and banked 32 degrees, shot 0.5 s later. No hole.
- `approach_0..5` and `approach_sheet`: 6 m up at 33 m/s.
- Closer looks: `crop_before_low.png` against `crop_after1_low.png`; `t15_skim` against `t3d_skim` (no clouds, lead on against 3D rings); `lod_zoom` (6-degree view of the 60 to 70 m band); `nofl_skim` (no flowers: the grass handoff alone).

## Unverified, open

- The motion itself, live in a window: the shrink cue was judged from stills, and looked fine in stills.
- GPU frame time with the near carpet at 30 to 40 m eye height.
- A real-input bank or turn while measuring lag. Only the still-camera turn was checked.
- A few single-pixel teal glints from flowers at 50 to 80 m. These are flowers (`--no-flowers` removes them) and also show with `--no-grass-lead`. FLOWER_DETAIL cut them down but not to zero.
- Seen from 15 m, the drift reads softer than before. If it needs more colour, `wash_tip` and FAR_WASH are the knobs.

## Tests

- No test reads endless_grass, endless_tuft_far, FAR_GROW or `grow_from`.
- reference_surface gained a uniform (`ring_lead`). The uniform-list tests that passed are test_sky_peak_look, test_pilot_wake, test_look_light and test_ground_look.
- test_aqueduct_isle_look fails with the same 4 lines with and without this change (a plant budget and placement problem that was already there).
