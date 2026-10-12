# Wanderer look, round 4: the hat hold in the game, the chase view, the wall slide

The user played round 3 and said: "He doesn't hold the hat tho. Or, at least
I didn't see that." This round finds out why, fixes it in the game itself,
shows more of him from the chase camera, and gives the hat its own bone.

## 1. Why the hold did not show in the game

**Cause: the hold never ran in any real host.** It was a wiring bug, not
the pose.

- `PilotFigure._hold_hat` looked for the sail's figure only as its own
  child: `get_node_or_null("PocketSail")`.
- The staged capture (`tools/capture_wanderer_sheet.gd`) put the
  `PocketSailFigure` under the `PilotFigure`, so round 3's stills showed
  the hold.
- Every game host puts the sail's figure beside the body, under the
  walker's node, not inside it:
  - `studies/character_study.gd` `_build_pilot`, which the kit isles
    (aqueduct isle included) and the pocket sail study inherit;
  - `scripts/wanderer_eye.gd` `_build_figure`, used for the walker and the
    sky dive;
  - `studies/landing_study.gd`.
- So in play `_hold_hat` found nothing and returned. The hat still lifted
  0.1 m (the sail's figure draws it) and the head's hat was hidden.
  - The arms stayed in the falling and idle pose, down at his sides.
  - The legs still dangled.
- Seen from the chase camera, a hat 0.1 m over its usual spot still sits
  on the top of his head: the head's top is 1.155 m and the lifted brim
  root was 1.146 m. It looked like he was falling with his hat on.

**Reproduced in the real aqueduct isle.** I ran the game's own frame loop
and input (not scripted), placed him over the isle and pressed Space
through `Input`. The arms stayed at his sides in every frame
(`captures/look-round4/hold-before-fix/`). Headless, the new test measured
the mitts 0.68 m from their grips and 0.40 m *under* the head bone.

**Fix:** `PilotFigure.sail_figure()` finds the `PocketSail` as his child or
as his sibling. `_hold_hat` and the sky dive's `dive()` both use it.
Guarded by the new `tests/test_pocket_sail_hold.gd`. It runs the pocket
sail study, where the sail's figure is the body's sibling as in the kit
isles, and checks four things:
- the mitts at their grips;
- the wrists over his head;
- still holding while turning;
- the arms coming down after the fold.

## What changed to make the hold read in play

`scripts/pocket_sail_figure.gd` (figure only; `scripts/pocket_sail.gd`'s
motion and numbers untouched):

- **`HOLD` 0.1 → 0.26 m.** The brim's root is now about 0.13 m over the
  top of his head, with a clear gap of air under the crown.
- **The grips moved.** They are now on the brim's underside 0.44 m out
  from the crown (`GRIP`, was 0.39), swept 0.6 rad round towards the back
  (`GRIP_BACK`, new). The mitts sit at the brim's back edge, which is where
  the chase camera can see them.
- **`HOLD_PITCH` 0.12 rad (new).** Held, the hat tips forward a little:
  the back of the brim goes up and the front down.
- **`OPEN_TIME` 0.22 → 0.18 s.** The hat comes off his head into his hands
  in 0.18 s. The arms go up in `SAIL_ARMS_TIME` (0.12 s, unchanged). The
  fold puts it back on in `FOLD_TIME` (0.12 s, unchanged).

`scripts/pilot_figure.gd`:

- **`sail_figure()`** (the fix above).
- **The arms stretch along their length while holding**
  (`SAIL_ARM_GROW` 1.1 → 1.3).
  - The upper arm is scaled along its bone only, `(1, grow, 1)`.
  - The forearm rides the stretch.
  - The mitt is scaled back by `1/grow`.
  - So the sleeves keep their girth and the mitts their size. Round 3
    scaled the whole arm, mitt included.
  - The wrist stops `SAIL_WRIST` short of the grip. It is no longer grown
    with the arm.
- **`SAIL_SHRUG` (0.03, 0.11) → (0.03, 0.13).**
- Unchanged: the body's swing under the hat into turns, the legs' dangle,
  and the IK.

Measured headless (`test_pocket_sail_hold`):
- Holding, the wrists stand 0.30 m over the head bone. In round 3's
  staged pose that figure was about 0.16 m, and in play it was −0.40 m.
- Each wrist is 0.12 m from its grip, where `SAIL_WRIST` aims it at
  0.1 m. Turning, it is 0.16 m.

In the aqueduct isle's chase view (`captures/look-round4/hold/`):
- **Opening:** the hat rises off his head and the arms come up under it.
- **Holding:** the hat is clearly up, with both mitts at its back edge,
  the arms up, and the scarf, jacket and dangling legs under it.
- **Turning:** he swings under it.
- **Folding:** the hat comes back down onto his head.
- **Side view:** the arm runs straight up to the brim, with the head
  clear under the crown.

## 2. The chase view

**Hat: the back of the brim droops less.** In `pilot_build.py`,
`BACK_LIFT` = 0.3 takes the droop at the very back from 0.71 to 0.41 of
`BRIM_DROOP`. The sides and front are as they were, so the eyes show as
before.

**Camera: one number changed, by a small amount.**
- `CAM_POLAR` went from `PI*0.5-0.7` to `PI*0.5-0.62`.
- So the camera looks down 35.5 degrees instead of 40.1.
- It is changed in both copies that are kept the same:
  `scripts/wanderer_eye.gd` and `studies/character_study.gd`.
- The distance (7 m), the height (0.8 m) and the range (`POLAR`) are
  unchanged.

**Captures** are in `captures/look-round4/chase/`, taken from the same
spots with `tools/capture_chase.gd`:
- `before/` is the round 3 model and camera.
- `hat/` is the new brim with the old camera.
- `after/` is the new brim and the new camera.
- `compare-ledge.png` and `compare-ramp.png` show the three side by side.

With the brim alone, the scarf, bracelets and jacket show under the back
of the brim at the ledge. With the camera change, a little more of his
back and arms shows. He still reads mostly as a hat from 7 m and 35
degrees; that is the big-hat look.

## 3. The hat's own bone, and the wall slide

`art/blender/pilot/pilot_build.py` → `assets/models/pilot.glb`:

- **New bone `hat`, a child of `head`.**
  - Its root is at the brim's root (`HAT_AT`, asserted equal to the old
    `PILOT_HAT` point), so it pivots there.
  - It is added last, so no other bone's index moves.
  - No bone or clip is renamed or removed.
  - The crown, brim, rolled edge, band and buckle ride it. In a clip that
    leaves it alone it follows the head exactly, as before.
  - `HAT_BASE` moved up beside `HEAD_C`; its value is the same.
- **Wall slide:** the hat is turned (`WALL_HAT` = pitch −30, roll −12
  degrees over the head's) so the brim folds up flat along the wall rather
  than into it.
  - The build prints `PILOT_HAT_WALL`. The brim's front reached **0.224 m**
    into the wall; it now reaches **0.039 m**.
  - It rocks a little with his judder.
- **Pump:** the punched right fist knocks the brim up on that side
  (`PUMP_HAT` roll −16, pitch 6).
  - The build prints `PILOT_HAT_PUMP`. The fist's clearance from the brim
    went from 0.012 m to 0.076 m (the mitt taken as a 0.06 m ball).
- Unchanged: the legs' reach, the arms' reach, the afloat numbers and the
  triangle count (93,232).
- `scripts/pilot_figure.gd` does not drive the hat bone yet. It is there
  for the figure to tip or tuck the hat later.
- The cockpit pilot (`scripts/plane_pilot.gd`) lifts the hat by its paint,
  not by bone, so it is unaffected. The `test_plane_*` tests pass.

Captures (`captures/look-round4/wall/`, the build's own stills via
`pilot_preview.py`): `before-after-wallslide.png` (left two before) and
`before-after-pump.png`. All stills are in `build-before/` and
`build-after/`.

## Tools added

- `tools/capture_sail_hold.gd`: the hold in the aqueduct isle from the
  game's own loop and input. It captures opening, holding, turning left
  and right, a side view, and folding. The opening and fold are slowed
  with `Engine.time_scale` so they span several stills.
- `tools/capture_chase.gd`: the walker's chase view at fixed aqueduct isle
  spots.
- `tests/test_pocket_sail_hold.gd`: the regression test for the hold.

## Checks

- **Import and studies, headless:**
  - The headless import is clean.
  - `character_study`, `pocket_sail_study` and `plane_parts_gallery` load
    with `--quit-after 300` and print no errors.
  - `aqueduct_isle` sometimes prints an exit-time "ObjectDB instances
    leaked" or "1 resources still in use" line. It varies run to run, and
    the round 3 checkout prints the same warning.
- **Tests, headless:** 19 of 20 pass across `test_pilot_*`,
  `test_pocket_sail*` (including the new hold test), `test_sky_dive`,
  `test_sky_plane`, `test_plane_*`, `test_world_scale_*` and
  `test_glide_camera`.
  - `test_pilot_tricks` fails with "Twirling low...", as it does on main.
- **Camera tests:** I also ran the tests that read `CAM_POLAR`.
  `test_aqueduct_isle_plane`, `test_walker_step_smooth` and
  `test_aqueduct_isle_sail` pass.
- The full suite was not run.

## Unverified

- **Sky dive under the sail:** not captured rendered. It goes through the
  same `sail_figure()` lookup, and `test_sky_dive` passes headless.
- **Wall slide and pump in the game:** checked on the build's stills
  only. In motion and against real walls they are not checked.
- **Cockpit pilot:** not re-captured with the lifted back brim. The
  change is small, but it is not looked at.
- **Arm stretch:** the 1.3 stretch is along the arm. It skews a little
  where the elbow bends. Seen from the side and the chase this reads fine,
  but it is not checked close up.
- **Reaching in a hard turn:** the mitts fall up to 0.16 m short of the
  brim on the high side.

## How to see it in the game

Run `./run-aqueduct-isle.command` and do one of these:
- jump off any edge, then press **Space** (pad **A**) while falling;
- or jump with **Space**, then press **Space** again near the top of the
  jump.

He takes the hat off and holds it up overhead. Steer with **WASD** and he
swings under it into the turns. **Shift**/**C** floats. **Space** again
folds it back onto his head.
