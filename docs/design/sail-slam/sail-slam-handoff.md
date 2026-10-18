# Slam from the sail: handoff (prototype round)

The complaint was a lag between pressing crouch in the sail and the slam
starting, so he overshot. There were three causes, all in `scripts/slam.gd`:

1. The slam fired only when crouch was **released** (`SAIL_TAP`, 0.2 s). A
   held press braked the sail and never slammed.
2. The 3-frame catch at the top (`HANG`) came on top of that.
3. The drive kept 94% of his flat pace (`SLAM_KEEP`). From the sail that
   is 5.5 m/s or more, so he carried on past the target.

`LOW` (1.8 m) wasn't the cause; it is unchanged.

The fix: in the sail, a fresh crouch press with `LOW` of air under him
folds the sail and starts the drive on that same frame. There is no
catch, and his flat pace is cut to `SAIL_KEEP` (0.1). Below `LOW`, crouch
in the sail is still the brake. Above `LOW`, crouch no longer brakes, and
that's the one change to the sail. A slam from a plain fall is
unchanged: 3 frames of catch at 60% flat pace, then the drive at 94%.

These numbers come from `scratch/sail_slam.gd` (git-ignored), real input
on the ring route. The sail is opened at the top of slab 2's launch and
crouch is pressed right over slab 3.

| | press to plunge | drift by the slab's height | result |
|---|---|---|---|
| before, 2-frame tap | 6 frames | 1.69 m | missed, fell 51 m |
| before, 6-frame tap | 10 frames | 2.07 m | missed |
| before, held | never (brakes) | n/a | no slam |
| after, any press | 1 frame | 0.15 m | lands on slab 3 (launched) |
| plain fall (same both times) | 4 frames | 1.34 m to the touch | lands |

Checks:
- `scratch/ring_route/route.gd`: 18/18 passed.
- Smoke on `zenscape.tscn`: passed.
- `test_slam` has one new failure, "Under the sail, crouch held brakes",
  which this change breaks on purpose.
- `test_pilot_motor` and the `test_pocket_sail*` / `test_aqueduct_isle_sail`
  tests pass.
