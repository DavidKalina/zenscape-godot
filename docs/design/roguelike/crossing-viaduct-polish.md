# Broken Viaduct: polish round (horns that point, routes in view, kit pillars, slam cancel)

Branch `feature/viaduct-polish`, cut from `feature/viaduct-perches` (3454c5dd). Not merged.
Run it as before: `./run-crossing-yard.command --beat=2`.

## Per flaw

1. **The blast left the bell sideways.** The horn now fires where it points.
   - The head turns fast: it closes `TURN_GAIN` 10/s of its error, capped at `TURN_RATE`
     2.4 rad/s (was a flat 0.9 rad/s). It settles heavily onto him and keeps up with a
     running or gliding pilot.
   - A horn starts its wind-up only within `START_CONE` 0.6 rad of him. It finishes the
     wind-up only within `AIM_CONE` 0.1 rad (about 6°); until then the wind-up holds at
     full. The ball leaves the Mouth along the barrel's facing, and the gentle homing does
     the rest.
   - New in `DragonAirBlast`: `hold` and `face`. Both default off, so the dragon is
     unchanged.
   - The horns' bodies are out of the balls' see-through list. The ball leaves in front of
     the lip, so the workaround isn't needed. The route stones are still see-through.
2. **Aim up (and down).** The horn is split in two:
   - `Head`: the chest and cap. It only yaws, so its cap stays flat to stand and slam on.
   - `Head/Barrel`: the horn's rings on a trunnion at the chest's face (`PIVOT_Z` 0.85,
     `AXIS` up). It pitches from `PITCH_UP` 1.22 rad (70°) up to `PITCH_DOWN` 0.3 rad (17°)
     down.
   - The bell clips the pedestal past about 15° down (measured: 0.10 m at 20°, 0.6 m at
     30°), so downward pitch is limited. **Under a horn's lip is a blind spot.**
   - The Mouth moved to `Head/Barrel/Mouth`. `tests/test_wind_horn.gd` was updated for the
     new path.
3. **Stones hid the horn.** `_route` now puts the stones `ROUTE_ASIDE` 4.8 m off the
   sightline from the departure to the horn: left of it for the left route (`LEFT_SIDE`),
   right of it for the far route (`FAR_SIDE`).
   - The sail gap runs out on a slant to the first stone. The sinking stone sits beside the
     first one. The last stone steps in beside the perch's top (`PERCH_STEP` off its side,
     `slam_over` above it), level with the top's middle.
   - The challenge is unchanged: the 7.38 m sail gap, the bob stone, the sink stone and the
     drop-slam.
   - `on_route` now follows the stones' polyline.
4. **Kit pillars.** The new `RuinKitAqueduct.pillar(seed, weathered, height, size)` replaces
   the dark columns for every perch, routed and low.
   - It is a coursed aqueduct pier (`_pier`) under its impost, with a flat true-hull top at
     `height`.
   - Its foot is broken off over the void: a ragged half course hangs under it, with ivy
     strands trailing.
5. **Slam cancel.** See the rule below.

## The slam-cancel rule (shared: scripts/pilot_motor.gd, scripts/slam.gd)

A fresh Jump during the slam cancels it into the pocket sail, everywhere in the game:

- **When:** in the catch (`hang`) or the drive, as long as the sail could open
  (`PocketSail.can_open`). That means room under him of `CLEAR` plus his fall speed ×
  `CLEAR_AHEAD`.
- **Near the ground:** a press just before the touch is still the old buffered jump out of
  the landing. The slam still lands.
- **What happens:** the motor's move `slam` ends, the fall is capped at his normal
  `terminal`, and the sail opens. The step reports `slam_cancel`. `slam.gd` ends with no
  touch: no ring, and no group push.
- **Sail tap:** after a slam made by a tap out of the sail, the sail's `REOPEN` of 0.25 s
  still applies before a cancel.

`tests/test_slam.gd`, `test_pocket_sail.gd`, `test_pocket_sail_hold.gd` and
`test_pocket_sail_study.gd` all pass.

## Knobs

| Where | Knobs |
|---|---|
| scripts/wind_horn.gd | `TURN_RATE`, `TURN_GAIN`, `PITCH_RATE`, `PITCH_GAIN`, `PITCH_UP`, `PITCH_DOWN` |
| scripts/ruin_kit_horn.gd | `PIVOT_Z` |
| studies/crossings/gust_arrows.gd | `START_CONE`, `AIM_CONE` |
| studies/crossings/crossing_viaduct.gd | `ROUTE_ASIDE`, `LEFT_SIDE`, `FAR_SIDE` |

## Verified

**Headless:**

- Import is clean.
- The yard loads for 300 frames with no script errors (only the known exit-time leak report).
- Throwaway play-loop checks, uncommitted, in `captures/viaduct_polish/checks.gd`. All pass:
  - **A:** the left horn, turned 145° away from a pilot on pier 2, starts its wind-up only
    once within 0.58 rad. It fires 0.1–0.4° off his middle, and the ball leaves exactly
    from the Mouth along the barrel (0.00° off).
  - **B:** with him on the route's last stone over the perch, the barrel pitches up to
    -0.60 rad (the old limit was 0.22) and the ball leaves upward.
  - **C:** Jump in the slam's catch and in its drive (at -34 m/s) opens the sail. There is
    no touch and the fall is eased. A Jump just before the touch still lands the slam and
    jumps out.
  - **D:** from each route's departure lip, rays from the eye and from a camera behind hit
    no stone before the horn.
- `tests/test_crossing_viaduct_perches.gd` passes when run alone, including the full new-route
  traverse, the sink stone, the drop-slam and the 8 s silence.
- `test_crossing_viaduct_arrows.gd` passes when run alone, after the gain was raised. With
  the first gain of 5 the horn lagged a pumping pilot by more than the cone and never fired.

**In the window** (forward_plus, `-- --no-title`): `captures/viaduct_polish/drive.gd`
(throwaway). Captures are in `captures/viaduct_polish/`:

- `1_route_left_from_start.png`, `2_route_far_from_start.png`: the stones are off to the
  side and the horn on its pillar stands clear.
- `3_horn_fires_at_pier2.png`: the bell faces the camera and pilot, with the ball in its
  mouth.
- `4_horn_fires_up_from_last_stone.png`: the bell is pitched up at him.
- `5_low_perch_fires_up_at_glider.png`: a low perch's bell is tipped up, its ball streaking
  toward the glider. The free camera picked up cloud-sheet artefacts.
- `6_pillar_left_perch.png`, `7_pillar_far_perch.png`, `8_pillar_low_perch.png`: the kit
  pillars, ivied, with the low one's broken foot.
- `3_..._side.png` and `4_..._side.png` are spoiled: the camera was inside the blast puff.

## Not verified

- Feel at human timing. Is a 2.4 rad/s horn too sharp or too forgiving? Is the held full
  wind-up readable?
- The far route is only checked by sightline rays and a capture; nobody has walked it.
- How the blind spot under a horn plays.
- Whether the steep-up bell clips its own chest at full pitch. It was only checked against
  the pedestal.

## Tests this breaks

- **`test_crossing_viaduct_heights.gd`: 3 failures.** The left perch moved (its top is now
  about 3 m nearer the pier) and its mouth's height changed. Its throw now lands him on a
  pier, so "Space after the beat opens the sail" sees a jump, and the updraft ride that
  follows fails.
- **`test_crossing_viaduct_perches.gd`:** the low-perch hit failed under the parallel runner
  (8 jobs) but passes alone. The facing gate makes it timing-sensitive under load.
- **`test_crossing_viaduct.gd` and others:** flagged only for the exit-time leak report.
  That was already there before this round.
- Not fixed this round, as asked.
