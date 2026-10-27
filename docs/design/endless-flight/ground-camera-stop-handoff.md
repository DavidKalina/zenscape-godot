# Ground camera and the stop: handoff (2026-10-26)

A prototype round on the camera after landing and on stopping on the wheels.
The bug that came in: after landing beside the rival the camera went under
the world and kept resetting, and holding Shift to stop sent the plane
backwards.

## How to try it

`.\run-endless-flight.cmd`, land anywhere, hold Shift through the stop and
keep holding it: the plane stays stopped. Let go and press Shift again to
back up. Space rolls off. For the rival race:
`.\run-endless-flight.cmd --race-near-start`, Tab to challenge, land in the
gold marks.

## Causes found

1. **The way flipped when backing up.** On the wheels the chase took its way
   as half the nose and half the path. Backing up, the path is the nose's
   opposite, so the sum was close to nothing and the way flipped back and
   forth. The eye swung round through the plane, up to 178 degrees in one
   frame, and dropped into the ground on the way. It swung back each time the
   plane stopped. That was the "resetting over and over".
2. **The tail dropped the eye.** Stopped, the way was the nose alone, and the
   nose sits tipped up on the tail wheel. "Behind and up" along a tipped-up
   way put the eye lower each second it stood still, down to the land.
3. **Shift held through the stop backed it up.** `_stopped` counted brake-held
   time from the stop itself, so holding Shift to stop flowed into reverse
   after 0.4 s.
4. **The sight and the floor.** The study's `_sight` ignored the sea, rivers
   and the 0.3 m margin `_solid` uses. `_keep_clear` never draws in nearer
   than `near`, and nothing lifted the eye when the land was nearer than that.

## What changed

- `scripts/glide_camera.gd`
  - `ground` (set by the study while on the wheels): the way follows the
    nose, kept level. The path's share comes in only when rolling forwards,
    from 2 to 6 m/s along the nose (`GROUND_PATH`). Stopped, slow or backing
    up, the view holds still.
  - `floor_at` (the study's new `eye_floor`: land, river water, sea swell, a
    bore's floor): the framed eye is kept `FLOOR_KEEP` (1.5 m) over what is
    under it. It lifts at once and comes back down over `EASE_FLOOR`
    (0.5 s). This is off when `tight` (near a tunnel's bore, whose own
    sight handles it).
  - The air path is unchanged: the old blend runs whenever `ground` is false.
- `studies/endless_flight.gd`: `eye_floor()` is shared by `_solid` and
  `_sight`. `_sight` now counts the water and EYE_CLEAR's half, as `_solid`
  does. It sets `chase.ground` and `chase.floor_at`.
- `scripts/manual_landing.gd`: `_brake_fresh`. Once stopped, only a press of
  Brake made after letting go backs it up (`REVERSE_DELAY` unchanged). Held
  on from the roll, it stays stopped for as long as it is held. Reverse,
  pivoting and the run-up on the brakes are otherwise unchanged.
- HUD: a small gold line over the hint. Stopped, it reads "stopped · Space
  boost to roll · Shift again to back up". Backing up, it reads "backing up ·
  let go of Shift to stop". It is hidden in the menu and while a race counts
  down, where the race's tag says "hold still". The hint line drops the dead
  "F flaps (stopped: get out)", which now reads "F flaps".

## Proof (throwaway drivers in scratch/, uncommitted)

`scratch/ground_cam.gd` finds a spot of each kind near the start (flat; a
cross-slope of 0.12-0.3; a river 5-17 m aside). It launches low behind the
spot and lands by stick and brake through the real input path. It then
holds Shift through the stop and 4 s past it, lets go, and runs the free
look (down, up, left; skipped with `--no_look`). Next it presses Shift
again to reverse for 2.5 s, lets go, and boosts and pulls to take off.
Every frame it logs the eye's height over the land or sea under it and the
camera's yaw change.

`scratch/race_cam.gd` runs the previous round's `race_course.gd` line-up
(`--race-near-start`: land beside the rival, brake into the marks, the
count, GO) with the same log, and ends 8 s after GO.

Seeds 1-6, before/after. Each cell is the range over seeds, with the
flat, slope and bank spots pooled:

| | before | after (no free look) | after (with free look) |
|---|---|---|---|
| eye over land/sea, least | -0.69 to -2.19 m | 3.4 to 4.6 m | 1.5 m (the floor) |
| frames with the eye under | 28-77 per run | 0 | 0 |
| yaw change per frame, backing up | 146-178 deg | 0.04-0.05 deg | 2.1 deg (the free look easing back) |
| yaw change per frame, stopped | 145-171 deg | 0.07-0.12 deg | 1.9-2.6 deg (look keys held) |
| yaw travelled while stopped/reversing | 821-881 deg (1279-1339 with look) | 6-9 deg (37 on seed 4's slope, the hit below) | 286-330 deg |
| reversed while Shift held from the stop | yes, every run | no | no |
| roll / takeoff yaw per frame | 0.47 / 0.58 | 0.47 / 0.58 | same |

Rival race, seeds 1-6:

| | before | after |
|---|---|---|
| backed out of the marks with Shift held | yes, all 6 | no |
| yaw per frame on the wheels | 147-160 deg | 0.47 deg |
| eye over land, least | -0.76 to -0.93 m | 3.85 to 4.32 m |
| lined up, counted and went | 6/6 | 6/6 |
| eye to the rival, least | 11-16 m | 17-29 m |

The race's line-up test (`in your marks and under 1.5 m/s`, `STILL`) is
untouched. Its tag words ("roll into the gold marks", "stop in the marks",
"hold still") read right: holding Shift now stops and stays stopped.

Stills (rendered, seed 1, flat, under `captures/ground_cam/`, git-ignored):
- `before/sheet.png`: the touch, then the eye in the grass, then the eye
  under the ground (the land's underside) while backing up.
- `after/sheet.png`: the same run. The eye stays in the side view, over the
  land. The reverse frames are still turned by the driver's free look.
- `after_nolook/sheet.png`: stopped and backing up without the free look.
  It is the same calm side view, with the cue over the hint.

Smoke: `endless_flight.tscn` default, `--race-near-start` and `--title`
(the menu), and `flight_study.tscn`: all PASS, 0 errors.
Tests (headless): `test_glide_camera`, `test_ground_look` and
`test_sky_plane` pass. No test exercises manual_landing directly, and none
broke. The full suite was not run.

## Judge by hand

- The touchdown swing into the side view (unchanged, EASE_CINE 0.9 s,
  peak about 28 deg/s) is one smooth move in the numbers. Feel it.
- Whether a fresh press of Shift to back up is easy to find. The cue says
  so.
- The eye floor is 1.5 m. A hard free look down on the wheels now stops
  there; some tall tufts still reach the lens.
- The cue's wording and colour (a warm gold, the hint's outline).

## Known issues

- A hit into a tree or rock while rolling still turns the view in one frame
  (2-3.5 deg, seed 4's slope). The plane stops dead, and the driver's
  plane got stuck there, so that run's takeoff failed both before and
  after.
- The eye floor is a vertical lift. On a very steep bank, land can still
  stand between the lifted eye and the plane for a moment until a dodge
  swings round. No run showed it.
- `_sight` now counts the sea and the margin in flight too. Low over water,
  the chase dodges up a little earlier than before. Not judged by eye.
