# Handoff: the climbing rope (greybox study)

Spec: `docs/design/rope/spec-rope.md`. Branch `iter/rope`, trail
`git log --grep='^ITER(rope)'`.

## Where to play it

`./run-rope-study.command` (`studies/rope_study.tscn`). A grey room:

| Key | Spot |
| --- | --- |
| 1 | start floor |
| 2 | the wall, 5 m, solid lip |
| 3 | the face, 8 m, anchor post on top (smooth top: the post is the only catch) |
| 4 | the crumbly lip (tan) beside a solid one (orange), 5 m |
| 5 | the drop top: tower with an anchor post at its edge, 9 m down |
| 6 | the lower floor under the drop |

R back to start, F1 numbers, F4 world view (pieces are named
`rope_study/<piece>`), Esc frees the mouse. Loot sits up top and below;
walk into it to take it.

## Controls

| Action | Keys | Pad |
| --- | --- | --- |
| Aim the hook (hold), throw (let go) | LMB / T | RT |
| Steer the reticle while aiming | WASD | left stick |
| Tug a caught hook; by a post up top, fix the rope | E | B |
| Take hold of a hooked rope | Space by it | A |
| Climb up / down | W / S | stick up / back |
| Slide down | Shift / C | crouch |
| Let go | Space | A |
| Over the edge to rappel (by a fixed rope, facing out) | Space | A |
| Rappel: lower (faster the longer held), stop on release | S | stick back |
| Rappel: push off in a hop | E | B |
| Reel in: flick free from below, pull a fixed rope down, pull it up from a top | F | d-pad down |
| Reduced / full moveset | M | d-pad left |

On the rope the stick's own up and back climb and lower, whatever way the
camera looks. The reduced moveset (default) is walk, run, jump and slide:
the motor's `wall_on`, `ledge_on`, `sail_on`, `rope_on` off, no updraft.

## What's built

All in `scripts/rope/climb_rope.gd` (one Node3D the study adds), with
`studies/rope_study.gd` and two additive actions in `scripts/pad.gd`
(`walk_tug`, `walk_reel`, `walk_moveset`).

- **Throw:** the bag's aim borrowed: reticle snaps to a top's lip over him or
  a post; gold catches, red won't (smooth top, floor, blocked, out of reach).
  The hook whirls while aiming, flies a kinematic arc (under `HOOK_G` 1.8x
  gravity for a snappy flight), lands past the lip and is dragged back
  (`caught`), or slides off / bounces down and is reeled in.
- **Tug:** reach, yank, hold. Posts and solid lips seat (click, taut). A
  crumbly lip is bad half the time (`POOR_BAD`): tugged, it slips with grit;
  untested, it gives 40-70% of the way up the climb.
- **Climb:** the rope is the motor's rider (`PilotMotor.mount/ride/toss`, no
  motor changes). Hand over hand, a pull of 0.4 m each 0.42 s (~1 m/s; the
  5 m wall in 4.8 s), stop and hang on release, down hand under hand, slide,
  let go. Hands IK'd onto the rope a reach over the hang grip, feet IK'd to
  the wall (one higher). At the top the motor's own ledge hang and climb
  haul him over (sped to 0.6 s).
- **Rappel:** E by an anchor post up top ties the rope and throws it over the
  drop past the post. Space at the edge facing out: the motor's catch and
  lower to a hang, then onto the rope leaned back 44 deg, feet on the wall.
  Stick back lowers him continuously, 1.1 m/s rising to 3.4 m/s over 1.4 s
  held, feet walking the wall and skimming at speed; let
  go and he stops in 0.2 s. E pushes off in a 1.5 m hop. Stick up climbs;
  the stance eases out over 0.3 s. At the bottom the rope stays fixed: climb
  it back, or F pulls it down. F on top pulls it up.

## The knobs

Constants at the top of `climb_rope.gd`, each with its comment. The ones
play tunes most: `AIM_SPEED`, `AIM_START`, `AIM_RISE`, `HOOK_G`,
`WHIRL_RATE` (throw); `PULL`, `PULL_T`, `DOWN_SPEED`, `SLIDE_SPEED`,
`HAUL_TIME` (climb); `RAP_SPEED`, `RAP_RAMP`, `RAP_STOP`, `RAP_STRIDE`,
`RAP_LIFT`, `LEAN`, `HOP_*` (rappel); `POOR_BAD`, `GIVE` (bad holds).

## Stood in (greybox)

- Every rope pose is procedural on the existing clips: bone turns for the
  whirl, the tug and the pull-up; two-bone IK for hands on the rope and feet
  on the wall. No authored clips yet. The big hat hides much of the arm work
  from behind.
- The rope is 28 cylinder segments: a parabola sag when slack, polylines
  when hanging. No physics.
- The room is grey boxes; holds are tagged per piece (`holds`: solid, poor,
  anchor), not read from geometry.

## Open

- **The bag on the rope** (kept in mind, not built): `climb_pace` (1.0)
  scales every climb and rappel time; a load sets it. Hauling a heavy bag up
  after him would hang it off the rope's hanging end.
- Going from rappel to climb, the hands jump to the climb grip (the body
  blends, the hands don't).
- The pull-up's arms are bone turns, not IK on the rope.
- Throwing at the tower post from the upper floor wasn't re-checked.
- The rope works only in this study; the isle has no anchors or tagged holds.
