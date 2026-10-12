# Wanderer look, round 3: the big hat, and holding on to it

The user's note on round 2: he read lanky. The head had shrunk to 28% of his
height, and the hat and head together came to about a third of it. On the
sheet they are about half. The user chose option A, a look-only change:

- The visual envelope is lifted for the hat and head, so they may stand
  taller and wider than the old helmet's outline.
- Gameplay sizes stay as they were. That covers collision,
  `PilotMotor.set_size`, `world_scale.gd`, the hip and leg bones, the gait,
  the ledge numbers and the water numbers.

A later direction replaced the spinning cap float: he now holds on to his
hat and hangs from it.

## What changed

### `art/blender/pilot/pilot_build.py` → `assets/models/pilot.glb`

About 93k triangles (round 2: 83k).

- **Head:**
  - Big again: 0.454 m wide and 0.40 m tall (round 2: 0.32 by 0.34).
  - It is a soft "mochi" rather than a ball. It is full and wide down to the
    cheeks, which is the part that shows under the brim, and rounds off
    under the chin and over the top (`HEAD_RINGS`).
  - Its middle sits lower on the head bone (`HEAD_C` 0.0516 → 0.0575 head
    units), so the chin sinks into the scarf's top roll, as on the sheet.
  - The eyes are bigger and placed in step (`EYE_X`, `EYE_Y`, `EYE_H`).
- **Hat:**
  - The brim is 1.0 m across, about 2.2 times the head's width (round 2:
    0.61 m, 1.9 times).
  - The felt is thicker, with a fat rolled edge.
  - The brim flops down at the sides (about 0.10 m) and the back more than
    at the front, and it ripples gently.
  - The crown is soft and low: 0.47 m wide and about 0.19 m over the brim's
    root.
  - The band is 0.05 m deep, with a bigger buckle loop.
  - The whole hat is tipped a hair back (`HAT_TILT` +0.03, was -0.06).
  - The brim's root sits 0.12 m over the head's middle, so the eyes show
    under it.
- **Scarf:** three chunky rolls (±0.187 m), a little lower, with the chin
  sunk into the top one.
- **Body:** a soft pear rather than a stick.
  - The jacket is fullest at the belt (±0.165 m, was ±0.14) and tapers
    gently to the sloping shoulders.
  - The skirt is longer (its hem 0.04 m lower, at 0.359 m in rest) and
    flares over the hips.
- **Arms:** hang close down the sides of the fuller body.
  - The shoulder bones sit 0.013 m wider (`SHOULDER.x` 0.064 → 0.07 build
    units). This is a visual bone, not a gameplay one.
  - The arms hang a little further out (`ARM_OUT` 0.26 → 0.3), so the
    mitts sit beside the skirt rather than in it.
- **Legs:**
  - The trousers are fuller (thigh 0.035 → 0.038 build units).
  - The boots are bigger (`BOOTS` 1.03 → 1.15).
  - The fleece cuffs are fatter, taller and higher.
  - The mitts are bigger (`MITT` 1.08 → 1.15).
  - The hips, legs, ankle and every clip number are unchanged.
- **Cape:** it sits a touch wider so it clears the fuller jacket.
- **Satchel:** moved further round to the left hip.

### Other files

- `shaders/pilot_paint.gdshader`: `eye_at`, `eye_apart` and `eye_half`
  are set to the new `PILOT_EYES`.
- `scripts/pilot_figure.gd`:
  - `SPARK_AT` moved up and out, over the bigger hat.
  - The cap float pose was rewritten (see below).
- `scripts/plane_pilot.gd`:
  - `WALKER_HEAD` and `WALKER_HEAD_RADIUS` are set to the new `PILOT_HEAD`.
  - `HEAD_RADIUS` stays at 0.1, and the rig scale stays at
    0.92 * `WorldScale.pilot_size`.
- `tools/capture_wanderer_sheet.gd`: `cap_float.png` now shows front,
  three-quarters, side, the chase camera's height, and a view tipped into a
  turn.

## The cap float: holding on to the hat (the direction that replaced target 6)

`scripts/pocket_sail_figure.gd` (figure only; `scripts/pocket_sail.gd` is
untouched):

- When the sail opens, the hat lifts `HOLD` (0.1 m) off his head into his
  hands. It is held crown up and does not spin.
- It tips into a turn on a spring (`LEAN` 0.3 rad, `LEAN_SPRING`) and rocks
  and bobs a little.
- It exposes `swing`, the same tip a beat behind on a slower spring, which
  the body follows.
- `grips()` returns the two grip points on the brim's underside, `GRIP`
  (0.39 m) out at each side. Their height is read off the mesh.
- The stacked rotor rings are gone. A thin cyan tube now glows just under
  the rolled edge and follows its droop (`edge_glow()`). It brightens in
  rising air.
- When the sail folds, the hat goes back on his head (`OPEN_TIME` and
  `FOLD_TIME` unchanged).

`scripts/pilot_figure.gd` `_hold_hat` (on foot through `_holding_sail`,
and in `dive()` for the sky dive's under-sail pose, so the two match):

- The body swings about the grips' middle by the sail's `swing`.
- The shoulders lift `SAIL_SHRUG` (0.03 m out, 0.11 m up) and the arms grow
  10% (`SAIL_ARM_GROW`).
- Two-bone IK reaches each wrist to `SAIL_WRIST` (0.1 m) short of its grip,
  with the mitt aimed at the grip. The mitts meet the brim; their tips
  close over the edge like a grip.
- The legs dangle loose and a little behind (`SAIL_LEGS`), swinging slowly.
- Probe, headless: with the sail out, the wrists stand 0.1 m from the grips
  as aimed.

The honest limit: his arms are short for a head this big. Even with the
shrug and the 10% stretch, the hat can only be held about 0.1 m above where
it sits on his head. It reads as "hat raised overhead in both hands", not
as a parasol held high.

## Sizes (rest pose, metres; standing is 0.029 lower)

| | round 2 | round 3 |
|---|---|---|
| total height (hat top) | 1.192 | **1.264** |
| total width (brim) | 0.606 | **0.998** |
| head ball | 0.768–1.107 (0.34), 0.32 wide | 0.758–1.155 (0.40), 0.454 wide |
| brim : head width | 1.9 | 2.2 |
| crown over brim root | 0.165 | 0.19 |
| jacket with sleeves | ±0.252 | ±0.276 |
| jacket at belt | ±0.14 | ±0.165 |
| skirt hem | 0.385 | 0.359 |
| trousers | ±0.205 | ±0.211 |
| boots | ±0.213, 0.31 long | ±0.223, 0.35 long |
| fleece cuffs | 0.136–0.189 | 0.148–0.213 |
| scarf | ±0.150, 0.682–0.842 | ±0.187, 0.657–0.838 |
| mitts | ±0.284 | ±0.315 |

The table below gives head : hat over head : torso : legs as shares of the
total height. The head is the ball, and the head sinks into the scarf, so
the shares overlap. The sheet's column is measured off its front
turnaround, scaled so its legs are ours.

| | round 2 | round 3 | sheet |
|---|---|---|---|
| head ball (height) | 0.34, 28% | 0.40, 31% (34% of the height to the head's top) | about 27–30% |
| head width | 27% | 36% | 34% |
| hat over the head | 0.085, 7% | 0.11, 9% | about 10% |
| hat + head (head bottom to hat top) | 0.42, 35% | 0.51, 40% | about 36% from the chin; about 44% with the scarf |
| neck base to crotch | 0.36, 30% | 0.36, 28% | about 24% |
| legs to crotch | 0.39, 33% | 0.39, 31% | about 33% |
| brim width / height | 0.51 | 0.79 | 0.71 |

- Hat and head come to 40%, not half. The sheet itself measures about 36%
  from the chin to the crown, or about 44% counting the scarf. Reaching 50%
  would take a taller crown than the sheet's soft, low one.
- The brim is a little wider than the sheet's: 2.2 times the head, against
  the sheet's 2.1 and the user's "about 2.5".

Arm IK reach (under 1 reaches): hang 0.863, shimmy 0.876/0.891, climb 0.847,
wall slide 0.939 (round 2: 0.867, 0.894/0.911, 0.851, 0.963). The legs' and
the water's numbers are unchanged (`PILOT_AFLOAT` +0.043/+0.078 m).

## Camera (`scripts/wanderer_eye.gd`; no camera numbers changed)

The chase view was captured on the aqueduct isle (`captures/look-round3/
chase/`): on the ground, beside the stair walls, and side on to them.

- At the normal distance (7 m, about 40 degrees down) the hat is small on
  screen and hides none of the world. It does not crowd the walls.
- It does hide him. From behind and above he reads as a big terracotta
  disc with his boots and the cape's hem under it. In round 2 his shoulders,
  arms and back showed. This is the trade-off option A accepted, and it is
  not broken, so the camera is unchanged. If it is not wanted, a lower
  `CAM_POLAR` or a brim that flops less at the back would show more of him.
- **Under a ledge: unverified.** I found no overhang spot on the aqueduct
  isle to stand him under.

## Clipping

Checked on the build's own stills (pilot_preview.py, same mesh and clips:
`captures/look-round3/clipping_hang_climb_pump_wallslide.png`). In-game
motion was not checked.

- **Wall slide: bad.** The brim passes about 0.25 m into the wall behind
  him: his head is about 0.25 m from the wall and the brim reaches 0.5 m.
  There is no cheap pose fix, because the hat rides the head bone. The
  options are a hat bone that tips the brim up off the wall, or squashing
  the brim's back while he is on a wall. Left as is.
- **Pump:** the raised fist touches or crosses the brim's edge for a few
  frames. Minor; not fixed.
- **Hang and climb:** the brim rides over the lip's top and does not cut
  into the wall face. In the climb's three-quarter frame the brim edge
  grazes the block's top.
- **Cape vs brim:** no contact in these clips. The cape's lift is capped at
  92 degrees and stays under the brim, which sits about 0.9 m up and over.
  The jump, twirl and flip were not checked in motion.

## Cockpit pilot (`scripts/plane_pilot.gd`)

He wears the new head and hat at the same head radius (0.1 pilot units)
and the same rig scale.

- The brim now reaches 0.22 pilot units (round 2: 0.19), and the hat's top
  is a little lower.
- **Front quarter:** the eyes show under the brim; it reads as the sheet's
  chibi.
- **Rear chase:** he hides about the same part of the plane as in round 2,
  slightly more at the brim's sides. The brim covers the cockpit, his
  shoulders and the fuselage's top just behind it. The wings, tail and
  nose stay clear.
- **Windscreen:** the brim's front edge comes down to about the windscreen
  frame's top. Close up, they touch rather than cross.
- I did not lower him in the seat.

## Checks

- **Import and studies, headless:**
  - The headless import is clean.
  - `studies/character_study`, `pocket_sail_study`, `aqueduct_isle` and
    `plane_parts_gallery` load with `--quit-after 300` and print no
    errors.
- **Tests, headless:** `test_pilot_*`, `test_pocket_sail*`,
  `test_sky_plane`, `test_sky_traffic`, `test_plane_*`,
  `test_world_scale_*` and `test_glide_camera` all pass except one.
  - `test_plane_flight` passes with the known `exit_leak`.
  - `test_pilot_tricks` fails with "Twirling low...", as it does on main.
  - `test_sky_dive` (it builds the sail figure) also passes.
  - The full suite was not run.
- **Captures** (rendered, `captures/look-round3/`, gitignored):
  - `vs_sheet.png`, `turnaround.png`
  - `before_after_turnaround.png` (round 2 over round 3)
  - `cap_float.png`: the held hat, front, three-quarters, side, chase
    height, and tipped into a turn
  - `chase.png`: the stage's 40-degree view
  - `chase/ground.png`, `chase/wall.png`, `chase/wall_side.png`,
    `chase/walls_pair.png`
  - `plane/`: rear-chase, front-quarter, side, pilot-close, above
  - `before_after_plane_rear-chase.png`,
    `before_after_plane_front-quarter.png`
  - `clipping_hang_climb_pump_wallslide.png`
  - `iter1`–`iter5`: working passes

## Still differs from the sheet

- **Hat:** a little wider than the sheet's brim relative to his height. It
  is more evenly floppy, where the sheet's is tipped back more. The sheet's
  crown has a softer, dented top.
- **Head:** a touch taller than the sheet's squashed mochi. Seen from the
  capture's low camera, the eyes sit a little high under the brim.
- **Proportions:** hat and head are 40% of him, not half. The legs are
  still a third of him, because the hips are fixed.
- **Skirt front:** under the toon fill it reads as a separate flap below
  the belt; the sheet's jacket reads as one piece.
- **Float:**
  - The hat is held only about 0.1 m over his head, because his arms are
    short.
  - The shoulders shrug up into the scarf to reach it, and the arms grow
    10% while holding.
  - The mitts' tips show over the brim's edge.
  - The sheet's float has him running under a hovering hat with a second
    hat on his head; this direction replaces that.
- Round 2's other open points stand: the scarf reads bright, there is no
  collar and no scarf tail on foot, and the cockpit pilot's coat has no
  strap or bracelets.
