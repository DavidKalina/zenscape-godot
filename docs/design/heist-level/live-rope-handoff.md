# Handoff: the live rope and heavy climbs (prototype round)

Branch `iter/live-rope` (from main ca44ec57), not merged. Touches only
`scripts/rope/climb_rope.gd` and `scripts/carry/loot_bag.gd`. The swing
(rope over a beam) and the tool slot are unchanged.

## What changed

- **Live rope.** On a hooked rope down a face (hanging or climbing) and on
  a rappel, his grip is now a pendulum hung from the edge the rope goes
  over. The face stops it. The body is moved and tilted along the rope,
  and the drawn rope runs from the edge through his grip. Each pull
  throws him out and toward the pulling hand, with a lurch over the rise
  that settles as the other hand reaches. When he lets go, he keeps the
  swing's pace (a little more along it if rising), and the rope he left
  sways on and settles.
- **Rappel.** Stick across runs him along the face on the pendulum, out
  and back. The push-off hop (E) now crouches, then kicks out on the
  pendulum. The rope runs through the brake hand while he's off the wall
  (up to HOP_DROP), and he lands when he swings back into the wall.
  Pressing E again as he comes in chains straight into the next hop.
- **Weight slows climbs instead of blocking them.** The ledge bar moved
  from 9 kg to `CLIMB_STOP` 16 kg. Under that, ledge climbs (the motor's
  `climb_time`), rope pulls, hauls and hops take `1 + CLIMB_SLOW * k` as
  long (k eased from FREE_KG 2 to the stop). At 16 kg and over, stick up on
  a rope gives a strained heave and the line "Too heavy to climb (N kg):
  throw the bag up first". A heavier bag also swings slower and wider
  (less gravity and damping) and lurches less, with a sag after each pull.
  The egg plus the way-in loot (15 kg) climbs everything with the bag on.

## Knobs

`climb_rope.gd`: LIVE_G 18, LIVE_DAMP 0.18, LIVE_RUB 1.6, LIVE_MOST 1.05
rad, LIVE_PUMP 5, RUN_PUMP 9, KICK 2.6, HOP_KICK 3.2, KICK_KEEP 0.5,
WALL_BOUNCE 0.12, PULL_OUT 0.3, PULL_SIDE 0.3, LURCH 0.09, RELEASE 1.2,
HEAVY_G 0.4, HEAVY_DAMP 0.6, HEAVY_SAG 0.07, LIVE_FREE_DAMP 1.6,
HOP_FALL 2.2.
`loot_bag.gd`: CLIMB_STOP 16, CLIMB_SLOW 0.8 (1.74x at 15 kg), BARS now
wall 5, sail 13, ledge 16, rope 17.

## Try it (`./run-heist.command`, rope in hand)

- **Sway on a hooked rope.** Stick left/right (A/D), worked with the swing,
  pumps side to side. E (pad B) kicks off the wall. Press it again as you
  swing back in to swing further out. W / stick up climbs. Jump (Space /
  A) lets go with the swing's momentum.
- **Rappel** (post_01 or post_02). Stick left/right runs along the face in
  an arc. E pushes off, and E again as you come back chains hops. S /
  stick back lowers, Shift / crouch slides, Space / A lets go mid-swing.
- **Heavy bag.** Climb `wall_01` or the vault steps with up to 15 kg on.
  At 16 kg it says to throw the bag first.

## Proved (throwaway drivers, `scratch/live_rope.gd`, `scratch/heist_vault.gd`, `scratch/heist_wayin.gd`)

- Smoke: heist_level, rope_study, bag_study, crag_reach `--greed-run`.
  All had 0 errors.
- Real input on wall_01's rope:
  - nine pulls in 4 s swing him about 0.65 m;
  - stick across, timed to the swing, reaches a 1.7 m side sway, which
    settles under 0.2 m in 4 s;
  - four E kicks swing him 2.0 m out;
  - letting go on an outswing carries him 1.9 m off the face.
- Rappel at post_02:
  - stick across gives a 1.3-1.6 m arc that swings back past the plumb;
  - three hops go 1.2, 1.6 and 1.8 m out, each dropping 1.5 m and landing
    back on the wall;
  - a release mid-swing carries on along the swing's way.
- Heavy hook climb up wall_01 (11 m): 0 kg 11.7 s, 15 kg about 20 s, both
  up and over. At 16 kg he makes no headway and gets the line.
- Vault ledges (`heist_vault.gd --light --kg=15`): all three climbed with
  the bag on.
- `--light --kg=16`: thrown up each ledge, climbed after it, shouldered
  again.
- The way in from leg 3 (`heist_wayin.gd --from=3`): both hook climbs and
  the post_02 rappel pass.
- Rendered films (`scratch/shots/climb_*_sheet.png`,
  `rappel_*_sheet.png`). The rope tilts and the body hangs along it
  through the sways and kicks. The white streaks in them are the scene's
  breeze ribbons. The rappel "side" view sits inside the overhang, so
  that one is hard to read.

## Not checked or open

- Judge the feel in play. The pull-sway amount (PULL_*), the kick size and
  the side pump strength are first guesses.
- On the hanging rope the stick's forward/back still climbs and lowers.
  The fore/aft swing is on E (kicks), not the stick.
- A long sideways arc on a rappel can carry a release off the rim: one
  driver release at post_02 fell about 14 m.
- Stale driver checks, not regressions: `heist_vault.gd` with the egg at
  16+ kg loses him on the walk to the ramp, the same on main. Its greed
  marks check and `heist_wayin.gd`'s loot count also fail on main.
- Tests: none run (prototype). None in `tests/` read climb_rope or the
  bag's bars.

## The fall bug (not fixed; leads only)

- `_haul`: at the rope's top it releases him and drops the rope
  (`_off_rope`) before asking the motor's `_climb`. If that fails ("No
  room to stand up there"), he's left in a ledge hang off the rope. A
  failed hang there would read as holding the rope and then dropping.
- An untested crumbly hook gives partway up (`GIVE`). The heist's bare
  tops are "solid", so that only happens on tagged "poor" pieces.
- `_process` drops the climb whenever `motor.rider != self` (another
  rider or `toss` taking him, such as a brood shake or an Olmec knock).
  The rope then still looks held for a frame.
