# Wanderer look, round 1

The on-foot wanderer rebuilt after the character sheet (`wanderer-proto.png`):
a terracotta felt hat, no face (only two glowing cyan eyes on a dark head),
navy scarf rolls, a charcoal-brown jacket with a strap, belt and satchel, gold
bracelets with a glowing stripe, big mitts, denim, chunky boots with fleece
cuffs, a torn charcoal cape. The pocket sail is now the sheet's "float with
cap".

## What changed

- `art/blender/pilot/pilot_build.py` builds the new body, outfit, hat and
  cape. It exports `assets/models/pilot.glb` (about 84.5k triangles, up from
  16k: dense, smooth-shaded forms for the painterly look). The rig, bone
  names, clips and timings are unchanged.
  - Cape: one sheet skinned with blended weights to the old scarf-tail bones
    (`tail.L.0-2`, `tail.R.0-2`), whose rest positions now run down the cape.
    It is the only part that bends; everything else still rides one bone.
    The clips' old tail keys go through `cape_turn()`. It never swings
    forward into the legs, never lifts past about 92 degrees (so it can't go
    over the hat), and the lower strips curl less.
  - The hat brim is a thick slab with a rolled edge, drooping softly and
    slightly wavy. The band has a buckle loop.
  - New `slab()` helper (a sheet with thickness, optionally skinned).
    `add()` accepts per-vertex weights.
- `scripts/pilot_paint.gd` and `shaders/pilot_paint.gdshader` hold the new
  surface set. The shader gains:
  - `eyes`: procedural pill eyes in the rest position, morphed by `blink`,
    `happy`, `surprise` and `squint`
  - `glow`: self-lit surfaces
  - `gone`: discards the hat while it flies
- `scripts/pilot_figure.gd`:
  - expressions and blinks
  - the surprise spark (three glowing strokes over the hat)
  - the cape's own spring: lifts back when falling, swings out of turns
  - hides the head's hat under the sail
- `scripts/pocket_sail_figure.gd` is redrawn as the cap float. The hat's
  surfaces are lifted from `pilot.glb`; the hat rises off his head, spins
  overhead with three additive cyan rings under the brim, leans into turns,
  and spins faster and glows brighter in a thermal. It drops back onto his
  head when folded. `scripts/pocket_sail.gd` (motion, controls, numbers) is
  untouched, as are the figure's `update`/`reset`/`out` API and its
  OPEN_TIME/FOLD_TIME.
- `tools/capture_pilot_look.gd` also captures the three expressions and
  tries the cap float.

## Surfaces and palette

| Surface | Hex | What |
|---|---|---|
| `pilot_face` | 3b2a22 | head and neck, with the eyes painted on (`eyes` 1) |
| `pilot_hat` | **c9644a** | crown, brim, rolled edge |
| `pilot_hat_band` | 4a2f24 | band, buckle loop |
| `pilot_scarf` | **2e4fa3** | three rolls |
| `pilot_jacket` | 4a403c | jacket, sleeves, folds |
| `pilot_strap` | **5a3a2c** | shoulder strap, belt, satchel |
| `pilot_gold` | d9a441 | bracelets, belt/strap buckles, satchel clasp |
| `pilot_glow` | **5fe6e6** | bracelet stripes (`glow` 2.2) |
| `pilot_mitt` | 7a4e38 | mitts |
| `pilot_trousers` | 2c3b62 | denim |
| `pilot_boots` | 7a4a32 | boots |
| `pilot_fleece` | **d9bc9c** | boot cuffs |
| `pilot_cape` | **4a4848** | cape |

Bold hexes are the sheet's swatches (shared with the plane's restyle); the
rest are shades between them. Eye, ring and spark glow is
`PilotPaint.GLOW` = 5fe6e6. `PilotPaint.HAT` lists the hat's surfaces.

## Expressions (`PilotFigure.express(mood, seconds)`)

- **Blink**: every 2.2 to 5.5 s (sometimes double), 0.14 s long. No blinks
  while happy.
- **Happy (^ ^)**: when a pump, a side flip or a twirl starts, and on landing
  after at least 0.9 s in the air.
- **Surprise**: wider eyes plus the spark, while knocked (`tumble`) and
  0.8 s after.
- **Squint**: angled lids while skidding or sliding down a wall.
- Each expression eases in and out over 0.08 s. Any caller can use
  `express()`.

The eye placement constants in the shader (`eye_at`, `eye_apart`,
`eye_half`) and `pocket_sail_figure.gd ON_HEAD` are copies of the build's
printed `PILOT_EYES` and `PILOT_HAT`. Update them if the head moves.

## Proportions and envelope

Bounding boxes from the exported glbs, in rest pose (standing is 0.029 m
lower):

| | old (helmet pilot) | new (wanderer) |
|---|---|---|
| top | 1.189 m (helmet) | 1.192 m (hat crown) |
| width | 0.600 m (mitts ±0.300) | 0.614 m (mitts ±0.307; brim ±0.30) |
| head ball | 0.33 m (28%) | 0.40 m (34%), top at 1.146 m; the hat adds 0.046 m above it |
| neck base to crotch | 0.41 m (34%) | 0.36 m (30%) |
| legs to crotch | 0.39 m (33%) | 0.39 m (33%), unchanged |
| arm (shoulder to wrist) | 0.24 m | 0.29 m |

Ratios are head : torso : legs as a share of height.

- `world_scale.gd`, `PilotMotor.set_size` and every motor number are
  untouched.
- The legs, hips (`HIPS_BUILD`, `pilot_figure.gd HIPS`) and ankle are the
  old ones, so the gait, the ledge's `HANG_DROP`/`HANG_OUT` and the swim
  draft stand. The sheet's legs are about a third of his height too. The
  "short legs" read comes from the jacket skirt, the fleece cuffs and the
  boots (12% longer and wider).
- The shorter torso (`NECK` 0.13 to 0.106) gave its height to the head
  (`HEAD_SIZE` 0.9 to 1.15) and the hat. The arms grew so the shoulders'
  drop costs no reach, and they hang slightly narrower (`ARM_OUT` 0.268 to
  0.2) to keep his width. Mitts are 1.2x.
- IK reach from the build (under 1 means it reaches):

  | clip | old | new |
  |---|---|---|
  | hang (arms) | 0.948 | 0.862 |
  | shimmy (arms) | 0.995 | 0.898 |
  | climb (arms) | 0.924 | 0.846 |
  | wall slide (arms) | 0.948 | 0.902 |
  | run (legs) | 0.971 | 0.971, unchanged |

## Checks

- **Tests, headless:** all pass. `test_pilot_*` (11 files),
  `test_pocket_sail`, `test_pocket_sail_study`, `test_sky_dive` and
  `test_aqueduct_isle_sail`.
- **Studies, headless:** `studies/character_study.tscn` and
  `studies/pocket_sail_study.tscn` load with no errors (`--quit-after 300`).
- **`test_skydive.gd` (slow, serial):** flaky. It fails "The plane comes in
  to land near the pilot / And parks" and sometimes "Down in the pond", in
  2 of 3 runs on the unchanged baseline too (HEAD~0 files swapped in). On
  the final build it passed 3 times, then failed in 3 later runs.
  Pre-existing; not added to known_failures.
- **Captures:** rendered and judged against the sheet. They are in
  `captures/wanderer-look/` (gitignored):
  - `vs_sheet.png`: the sheet's turnaround beside ours
  - `turnaround.png`
  - `expressions.png`: neutral, happy, surprise, squint
  - `cap_float.png`: flying, then folded back on his head
  - `in_game.png`: test island, standing, running, close shots

## Still differs from the sheet

- **Hat:** the brim is narrower relative to the head (about 1.6x head width;
  the sheet's is over 2x). The width envelope caps it at ±0.30 m. A wider
  brim also hides more of him from the chase camera, which is 40 degrees
  above and behind. The crown is a little tall and dome-like.
- **Trousers:** the denim still reads brighter than the sheet's under the
  toon fill.
- **Jacket:** no collar or lapels.
- **Scarf:** no tail.
- **Mitts:** no cuff detail.
- **Cape:** clips into the arms when they swing back. The sheet's cape is
  softer, with more folds.
- **Float pose:** he still holds his arms up overhead (the old sail-bar
  pose, `SAIL_ARMS`); the sheet has them out and loose.
- **Swimming:** the shoulders now sit +0.04 m over the water swimming and
  +0.08 m treading (were +0.08 / +0.13).
- **Sky dive:** `SkyDive.HIPS` still places the diver by the old hips,
  which haven't changed.
- **Spark:** the surprise spark is three strokes, not the sheet's exact
  flick marks.
- **Eyes:** no "look" direction.

## Next steps

- A wider, floppier brim if the envelope can give, checked against the chase
  camera (`scripts/wanderer_eye.gd` CAM_*).
- A sail pose: arms out, legs paddling, instead of arms up (pilot_figure
  `_holding_sail`).
- Cape: collisions with the arms, or a few spring-driven bones; a back fold
  or two.
- Eye look-at (where the camera or the stick points), and more moments
  (sleepy idle, a wink on a perfect landing).
- The cockpit pilot (another agent) can reuse `PilotPaint.GLOW`, the hat's
  surfaces via `PocketSailFigure.hat_mesh()`, and the palette above.
