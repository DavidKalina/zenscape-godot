# Dragon spine, round 1: the body takes part in flight

The complaint: "locked in a semi-relaxed, semi-stiff pose, and the wings are
what move." Branch `feature/dragon-spine` (from `roguelike`).

## What changed

- New `scripts/dragon_spine.gd` (RefCounted): a chain of damped springs on
  chest, spine.2, neck.0-3 and hips (pitch and yaw). Each bone chases the one
  before it plus its own goal, slower down the chain, so a push on the chest
  reaches the neck's end and the hips late (follow-through). The legs are
  springs too. All tuning constants live in this file.
- `scripts/sky_dragon.gd` `_pose` steps it every flying frame (roaming, the
  grab, the let-go, `wake_fly`, `wake_pose`) and lays its turns on top of the
  old pose:
  - **beat**: the downstroke pitches the chest nose-down and swells it, then it
    recovers on the upstroke. The hips lag by about 0.2 of a beat and the
    neck's end by about 0.5. The old keyed chest/hips/neck beat sines are gone.
  - **turns**: the chest, spine.2 and neck bend into the turn. The hips bend
    the other way, so the back half curves in too, and the tail's rest line
    curls on into it. The bend eases in and out (TURN_EASE).
  - **climb**: the chest lifts, the neck reaches, the beats get 25% bigger
    and the head levels less. **dive**: the neck's S straightens and the neck
    stretches forward, the head lines up with it, the legs draw up, the wings
    fold and sweep back further. **level-out**: the pull-up rate sets a flare
    (the chest up, the tail dropping, the wings cupped forward, the legs
    forward).
  - **glide**: breathing, a slow spine sway, chest pitch against the air's
    pitch, and the hips ruddering against its roll.
  - **head**: it cancels 80% of the chain's carried sway and of the body's nod
    and the air's pitch. neck.0 dips as the bob lifts the body
    (BOB_STEADY), so the head rides steadier than the neck under it.
  - **legs**: they swing late with the beat's heave, swing out of turns, tuck
    in dives, and the knee chases the upper leg.
- **tail**: `_tail` now takes the rope's rest line and the tail bones' turns
  from the hips as posed, not from the body. Before, any hips turn put a
  hinge at tail.0. This also applies on the rim (the cling hips' 0.1 rad).
- Unchanged: the cling and grab poses, roost and wake blending, sight
  tracking (`_look`), and the roar and cyclone draw-back (`_rear`, jaw).
  These add on top as before.

## Tuning constants (scripts/dragon_spine.gd)

CHAIN (each bone's Hz and damping: chest 0.5, neck 0.7 down to 0.55, hips
0.32), HIPS_FOLLOW, BEAT_CHEST 0.09, BEAT_RECOVER, BEAT_SWELL, CLIMB_BEAT,
TURN_CHEST/SPINE/NECK/HIPS/TAIL (0.12/0.1/0.07/0.22/0.08 rad at full turn),
TURN_EASE, CLIMB_*, TUCK_* (incl. TUCK_NECK per bone), FLARE_*, SIGNAL_EASE,
AIR_CHEST, AIR_RUDDER, GLIDE_SWAY(_HZ), BREATH(_HZ), HEAD_STEADY, BOB_STEADY,
NECK_LENGTH, LEG_*, KNEE_SPRING, STALE (a gap after which it restarts from
rest, e.g. after a cling).

## Run

```sh
godot --path . res://studies/dragon_vision_study.tscn -- --no-title --vision-low --no-sight-overlay
godot --path . res://studies/zenscape.tscn -- --no-title --dragon --dragon-downwash-test        # =glide too
godot --path . res://studies/zenscape.tscn -- --no-title --dragon --dragon-hold --dragon-pose=dive
python3 tools/run_tests.py --tests 'test_dragon_*.gd'
```
V cycles the dragon camera. `--dragon-watch=orbit --dragon-orbit=105` gives a
side view a little behind the shoulder. In front of him, within 260 m, his
head turns to the camera.

## Verified vs judged

- Verified headless: the new `tests/test_dragon_spine.gd` (beat heave, hips and
  neck lag, head steadier than the neck, turn bend with hips and tail on the
  inside, weighty ease, dive tuck, climb gain, level-out flare, glide
  shifting, reset after a gap, bounds). The existing dragon tests still pass:
  wake (no bone jumps, back to the coil exactly), downwash, sight, cyclone.
- Judged by eye in windowed captures (before/after under /tmp/dragon_spine/):
  beating side view, chase through a turn, top view of the cloverleaf, glide,
  held dive, the vision greybox (sight tracking and cyclone wind-up still
  read), and a rim cling.

## Open points

- The turn's bend is modest at the cloverleaf's turn rate (about half
  MAX_TURN). Raise TURN_* if it still reads stiff.
- No roll twist along the spine yet (the bank is still rigid in roll).
- The climb's look wasn't captured: no test scene holds a climb.
- The neck's beat wave is fairly large at neck.3 (about 0.2 rad local)
  while the head stays steady. Watch it at close range.
- The flare is driven by the pull-up rate, so a shallow pull-up flares only a
  little.
