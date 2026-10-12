# Wanderer look, round 2: slender, a bigger hat, the cockpit pilot

The user's note on round 1: "the wanderer reads a bit chunky compared to the
sheet, where he's a bit more slender." This round stays inside round 1's
envelope: the hat's top is still at 1.192 m and the widest point is still
±0.303 m. Collision, `PilotMotor.set_size`, `world_scale.gd`, the legs, the
hips, the gait and the ledge numbers are unchanged. The look is still
smooth and painterly, about 83k triangles.

## What changed

- `art/blender/pilot/pilot_build.py` → `assets/models/pilot.glb`:
  - **Body:**
    - The jacket is narrower and tapered, with sloping shoulders that round
      into the arms. It is 0.29 m across the chest (was 0.40).
    - It is split into a body over the belt and a skirt under it that flares
      a little over the hips and falls lower. Six thin folds replace nine
      thick ones, which had read as a fringe.
    - The trousers' seat is narrower.
  - **Limbs:**
    - Thinner sleeves (0.022 build units at the shoulder, was 0.024) and
      thinner legs (0.035 at the thigh, was 0.043).
    - Smaller mitts (`MITT` 1.2 → 1.08) and boots (`BOOTS` 1.12 → 1.03).
    - The shoulders came in (`SHOULDER.x` 0.08 → 0.064) and the arms hang a
      little further out (`ARM_OUT` 0.2 → 0.26), so they clear the jacket.
  - **Head:** slightly smaller (`HR` x 0.075 → 0.0635, 0.38 → 0.32 m wide),
    so the brim can be about twice its width. It is raised on its bone
    (`HEAD_C`). No bone moved.
  - **Hat:**
    - Lower, softer crown: 0.165 m over the brim's root, was 0.213.
    - It sits higher on the head (`HAT_BASE` 0.012 → 0.036), so the eyes
      show under the brim.
    - The brim is wider relative to the head (1.9×, was 1.6×) and floppier:
      more droop, more even all round, and two ripples.
  - **Scarf:** thinner rolls, lower, so the head shows over them.
  - **Fleece cuffs:** now ride the shin. On the boot they slid behind the
    leg whenever the knees bent, which was visible in round 1's standing
    shots.
  - **Cape:** hangs on his back between the arms (wrap 84° → 64°, narrower)
    and rolls sideways less (top strip ±30° → ±12°). This stops it clipping
    the arms on the back swing.
  - **Satchel:** moved to the left hip.
  - **Trousers:** greyer, darker denim, `323847` (was `2c3b62`).
  - The build also prints `PILOT_HEAD` (the head's middle and radius) for
    the cockpit pilot.
- `shaders/pilot_paint.gdshader`: `eye_at`, `eye_apart` and `eye_half` set
  to the new `PILOT_EYES`.
- `scripts/pocket_sail_figure.gd`: `ON_HEAD` is now 1.002 (from
  `PILOT_HAT`). The surface lift moved to `PilotPaint.lift()` and is shared
  with the cockpit. Motion and the API are untouched.
- `scripts/pilot_figure.gd`:
  - The cap float pose replaces the sail-bar hold. The arms are out from
    his sides (`SAIL_ARMS`, 1.0 rad), drooping at the elbows. The left
    reaches forward and the right swings back (`SAIL_REACH`). The left knee
    is up and the right leg trails (`SAIL_LEGS`), all paddling slowly
    (`SAIL_PADDLE`).
  - The sky dive's under-sail pose follows it.
  - `CAPE_SWING_MOST` 0.35 → 0.2.
  - `scripts/pocket_sail.gd` is untouched.
- `scripts/plane_pilot.gd`: the wanderer in the cockpit now wears the
  walker's own head and hat, lifted from `pilot.glb` in the walker's paint.
  - His painted eyes blink through the shader's `blink`.
  - He is drawn smaller and lower in the seat: head radius 0.116 → 0.1
    pilot units, brim reach 0.232 → 0.188, hat top about 0.06 lower.
  - The coat and mitts use the walker's colours (`JACKET` 4a403c, `MITT`
    7a4e38) in the plane paint.
  - His rig scale (0.92 * `WorldScale.pilot_size`) is unchanged, and so are
    livery pilots.
- `scripts/plane_figure.gd`:
  - The wanderer's scarf tail is navy (`_tail_navy`). The folk ribbon
    shader reads the vertex colour as linear, which is why the sRGB navy
    drew pale sky blue.
  - The cream is warmed a touch: `e9dfcb` → `ecdcc0`.
- `tools/capture_wanderer_sheet.gd` (new) writes:
  - the turnaround, and the sheet's turnaround over ours (`vs_sheet.png`)
  - the cap float
  - a 40° chase-height view

## Sizes (rest pose, metres; standing is 0.029 lower)

| | round 1 | round 2 |
|---|---|---|
| top (hat) | 1.192 | 1.192 |
| width overall | 0.614 (mitts ±0.307, brim ±0.301) | 0.606 (brim ±0.303, mitts ±0.284) |
| head ball width | 0.380 | 0.321 |
| brim : head width | 1.6 | 1.9 |
| jacket with sleeves | ±0.277 | ±0.252 |
| jacket body at chest | ±0.21 | ±0.145 |
| trousers | ±0.222 | ±0.205 |
| boots | ±0.221, 0.34 long | ±0.213, 0.31 long |
| scarf | ±0.167, 0.665–0.871 | ±0.150, 0.682–0.842 |
| head ball | 0.733–1.146 (with neck) | 0.768–1.107 (ball alone; neck from 0.733) |
| crown over brim root | 0.213 | 0.165 |

Head : torso : legs, as shares of the height (round 1's measures):

| | round 1 | round 2 |
|---|---|---|
| head ball | 0.40 m, 34% | 0.34 m, 28% |
| hat above the head | 0.046 m | 0.085 m |
| neck base to crotch | 0.36 m, 30% | 0.36 m, 30% |
| legs | 0.39 m, 33% | 0.39 m, 33% (unchanged) |

The head plus hat is 0.42 m tall (35%) and is still the biggest mass. On the
sheet the head is about 26% of the height wide; ours is 27%.

Arm IK reach (under 1 reaches): hang 0.867, shimmy 0.911, climb 0.851,
wall slide 0.963 (round 1: 0.862, 0.898, 0.846, 0.902). The legs and the
water's numbers are unchanged.

## Checks

- **Import and studies, headless:** headless import is clean. Loading
  `studies/character_study.tscn`, `pocket_sail_study`, `plane_parts_gallery`
  and `zenscape` (`--quit-after 300`) printed no errors.
- **Tests, headless:** all pass except one:
  - Pass: `test_pilot_*` (8 of 9), `test_pocket_sail*`, `test_sky_plane`,
    `test_sky_traffic`, `test_plane_*` (3), `test_world_scale_guard`,
    `test_world_scale_fit`, `test_glide_camera`, `test_sky_dive`.
  - Fails: `test_pilot_tricks`, "Twirling low, Jump pressed again neither
    opens the sail nor flies". It fails the same way on the untouched
    branch head (checked in a clean worktree), so it is pre-existing and a
    motor matter. Not added to known_failures.
- **Captures** (rendered, `captures/look-round2/`, gitignored):
  - `vs_sheet.png`, `turnaround.png`, `cap_float.png`, `chase.png`
  - `before_after_turnaround.png`, `before_after_plane_rear_chase.png`
  - `plane/` (rear-chase, front-quarter, side, pilot-close, above)
  - `before/` (the same, from round 1's build)

## Still differs from the sheet

- **Head and hat scale:** the sheet's brim is about 0.73 of his height wide
  (0.87 m at our height), and its head is the width of the jacket. Inside
  the 0.61 m envelope the brim is 1.9× the head, not the sheet's 2.5–2.8×.
  The head is the width of the torso, not wider.
- **Brim:** thinner and flatter than the sheet's thick, soft felt. From the
  chase camera's 40° it still covers his head and shoulders, as before (its
  reach is unchanged).
- **Legs:** longer than the sheet's. The belt is at 0.53 m against the
  sheet's 0.46 m, because the hips are fixed. The skirt now falls a little
  lower to help.
- **Skirt in a run:** the longer skirt rides the chest bone, so a thigh
  swung far forward (run, long jump) can poke through its front.
  Unverified in motion in the game; seen only in Blender stills.
- **Float pose:** reads as loose arms out with the knees up. The sheet's is
  more of a running stride, and on the sheet he keeps a hat on his head
  under the big one.
- **Colour:** the scarf swatch (2e4fa3) still renders brighter than the
  sheet's navy under the toon fill.
- **Cockpit pilot:**
  - The hat reads lighter and pinker than the plane's terracotta, because
    the walker's paint is drawn under the plane paint's light.
  - The coat has no strap, belt or bracelets.
  - The scarf tail is a flat ribbon; the sheet's is knit.
- **Cream:** still reads cool in `tools/view_plane.gd`'s pale sky. It was
  warmed only slightly and not judged in the game's light.
- Round 1's other open points stand: no collar, no scarf tail on foot, eye
  look-at, cape folds.
