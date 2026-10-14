# The wind horn blows (2026-10-13)

## Round 2: it fires the ball (the user's notes)

The user played round 1 (`studies/wind_horn_study.tscn -- --blow`) and
missed the projectile. In the viaduct crossing, the gust arrows' ball
"looked way better". They also listed what the arrows got wrong: a wind-up
that fizzled with no shot, and a horn that ignored him on the other side or
"a little bit too high". So the horn now fires that ball, without those limits.

- **`shot` knob: "ball" (the default) or "gust".** "gust" is round 1's
  instant knock, unchanged.
- **The ball is the gust arrows' own.** The Rig makes a `DragonAirBlast`
  configured as `gust_arrows.gd add_launcher` does, using its constants:
  speed 30, fuse 0.3, glow, tint, gather, trail and `FLY`. It differs in
  three ways:
  - **No homing.** It leads instead (`lead` 1, his flat pace only).
  - **A harder throw.** The burst throws him as hard as the gust at its
    heart (14.4 m out, 1.2 m up; 0.45 of that at the rim). The throw goes
    out from the burst, and the horn piece is the source.
  - **Its own collision is ignored.** The horn's hulls are `see_through`, so
    the ball doesn't pop on the horn's own staves.
- **The tell is `ball_tell`, 0.8 s, the arrows' wind-up.** The blast's own
  wind-up (the ball gathering in the mouth) runs held through it. The horn
  fires, not the blast. The swell, the motes and the inhale are as before.
- **No dead charge. I chose the shot.** A drawn breath always ends in a
  ball. If it still sees him, the ball goes where he will be. If he broke its
  line mid-tell, it goes where he was heading: last seen, carried on at his
  last pace for the time since, then led. The only other ending is a
  knock-out (P or a slam), which slumps visibly. That case is counted in
  `knocked_out_tells`.
- **It is aware of him from more places.**
  - **It turns all round.** `yaw_arc` defaults to PI. Set it only where a
    horn is set into a wall.
  - **It pitches deeper.** A watching horn pitches down to
    `PITCH_DOWN_WARD`, 0.55 rad. Dressing horns keep 0.3, so the viaduct is
    unchanged. I checked the model:
    - The pedestal's top never meets the barrel. The barrel's underside
      stays over it past 1 rad.
    - The real limit is the bell's lip. At 0.55 rad, 3 m out, it about
      meets the ground at the pedestal's own foot.
  - **The ball can leave off the barrel.** Where the head can't point, it
    leaves up to `off_barrel` (0.35 rad) off the barrel. So the horn wakes
    and shoots from 0.9 rad under level to straight up. Only nearer under
    its lip than that is safe.
  - **It holds the breath to turn.** If the barrel is still more than
    `off_barrel` off him when the tell ends, it holds the full breath while
    it turns, up to `turn_max`, then fires as near his way as it can.
- **Slam:** the Rig joins `slam.gd`'s group. A slam on the pedestal top or
  the cap knocks it out for the arrows' `DISABLE_TIME`, 8 s. P in the study
  still works.

### Proved (headless, real play loop, `--fixed-fps 60`, input actions)

Horn station: a real RuinKitHorn beside the trap yard, plus a second one on a
6 m tower. 10 runs a case, start jittered +-0.5 m, timing 0-0.4 s.

| case | ball | gust |
|---|---|---|
| hop in front, 7-11 m | 10/10 hit | 10/10 |
| run past at 9 m | 10/10 hit | 10/10 |
| juke at ~20 m: run, reverse 0-0.16 s after the shot leaves | 10/10 first ball dodged | 0/10 |
| on a ledge 6 m up, ~8 m out | 10/10 hit | 1/10 |
| 6 m below (horn on a tower), 10 m out | 10/10 hit | 7/10 |
| behind it (all-round arc) | 10/10 hit | 10/10 |
| break line: seen running, gets behind a stone mid-tell | 19/20 popped on the stone (start 1.5 m from the shadow); 11/20 from 2.5 m, where the rest are caught by the fuse at the shadow's edge | n/a |
| every tell ends in a shot (the full ball pass, the break-line runs included) | 99 tells, 99 shots, 0 dead | |

Vigil copy (local, untracked, deleted after). Seeds 11 and 7, 20 runs a
chain, both modes at the new pitch:

| chain | ball | gust | gust, round 1 (pitch 0.3) |
|---|---|---|---|
| 1 splash | 7/20 under a roof | 20/20 under a roof | 12/20 |
| 2 apron hop into the shaft | 20/20 | 20/20 | 20/20 |
| 3 seesaw, hit mid-air | 0/20 hit | 20/20 hit, 16/20 NE | 19/20 |
| 4 out the NE corner | 20/20 | 20/20 | 20/20 |
| creep unnoticed | 20/20 | 20/20 | 20/20 |

- **Chain 1 changed hands.** With the deeper pitch, the tower horn now
  reaches the pool and wins the bellows. It throws him south into the west
  bays (the gust makes it every time, the ball 7/20). The layout's "under its
  lip" relied on 0.3 rad, so the turf pass should re-place the tower horn or
  set `pitch_down` there.
- **Chain 3 is lost with the ball.** A body thrown by the seesaw is
  ballistic. The ball leads only flat pace, and gravity bends him off the
  lead, so it misses (fair, but the chain is gone). To bring it back, lead
  the full 3D velocity, or add gravity, when he is airborne.
- **Smoke:** run_layer sprawl 1, 2, 3 and ring 1, 4; the Vigil copy; the
  horn study with and without `--blow`. No SCRIPT ERROR.
- **Tests:**
  - Pass: test_trap_wind, test_wind_horn, test_stun_yard, test_ruin_kit.
  - test_crossing_viaduct_arrows and _perches fail only on the same
    pre-existing exit-leak engine error as round 1. Their checks pass.
- **Not judged:** the look and sound of the ball from the horn. The inhale
  sample is 0.5 s against the 0.8 s tell. The slam-to-disable was not
  exercised.

## Round 1

Prototype round, uncommitted. Branch `wind-horn-blows` off `roguelike`. The
spec is the Vigil of the Bellows greybox's "Engine changes still needed"
(docs/design/roguelike/brainstorm/round1/motif-m3-the-vigil-of-the-bellows.md).

The wind horn (scripts/ruin_kit_horn.gd + its Rig, scripts/wind_horn.gd) was
dressing only. Now it can be a ward that notices the pilot, draws breath and
gusts him with the wind blaster's own knock, naming itself as the source.

## What changed

- **One gust, shared** (`scripts/traps/gust.gd`, new). It holds the knock
  lifted out of `trap_wind.gd` `_blast`:
  `Gust.knock(motor, way, out, up, source)` =
  `motor.knock(motor.knock_velocity(flat way, out, up), source)`. It also
  holds the blow's knob defaults (`Gust.defaults(pilot)`: blast_out run x 3,
  blast_up run x 0.25, delay 0.5, blast_time 0.3, rearm 2.0) and who it can
  take (`can_take`: anyone but a rider). The wind trap's `defaults()` merges
  those knobs, and its `_blast` calls `Gust.knock`.
- **The blaster no longer skips a swimmer.** A gust lifts him out of the
  water (`knock` already ends the swim). The vent's breeze still skips
  swimmers: it is a breeze, not a gust.
- **The horn's blow** (wind_horn.gd). It is off by default, so every
  existing horn (the viaduct perches, the gallery, the study) is unchanged.
  `rig.watch(motor, {knob overrides})` turns it on. It runs a four-state ward:
  - **watch:** it sweeps its arc, level. It wakes on **air** (a body in the
    air, not on a ledge, anywhere in its arc), a **splash** (swimming, or
    wading at more than 0.2 m/s) or **seen** (on the ground faster than
    `notice_pace`, walk / 3 = 0.8 m/s, within `view` 0.6 rad of where it
    looks). A body that is already tumbling is not news. Waking also needs
    `can_reach`: within `reach` (blast_out x 2.2 = 31.7 m), inside its arc,
    inside its real pitch (PITCH_DOWN 0.3 + cone x 0.8 below level, so under
    its lip is safe), and a clear line of sight (mask: solids + turf; its
    own hulls excluded).
  - **tell (`delay` 0.5 s):** it turns on him. The bellows draw: the chest
    swells up to 12 % wide and 4 % tall, eased in. Dust and leaves are drawn
    into the mouth and the bell shudders (both existing). A procedural rising
    inhale plays.
  - **blow (`blast_time` 0.3 s):** it blows once it is **settled** on him:
    the barrel within cone x 0.6 and the head's yaw within `settle`
    (0.08 rad) of his bearing. If it never settles, it blows anyway
    `turn_max` (1.5 s) past the tell. The chest empties (a squash 8 % under
    rest, sprung back), the head kicks (existing), and fast puffs and a rush
    of air leave the mouth. On the first frame his chest is within `cone`
    (0.25 rad) of its facing and can be reached: `Gust.knock` along the
    barrel's flat facing, `blast_out` / `blast_up`, source = the horn piece.
    Once per blow.
  - **rest (`rearm` 2 s),** then back to watch.
  - `disabled()` drops it back to watch. `may_draw` (a Callable) is asked
    before it draws breath, which is how a shared bellows is wired. `auto`
    (on) steps it from its own `_process`. A host can turn that off and call
    `step(delta)`. Signals `woke(why)` and `blew(hit)`. Counters `blows`,
    `hits`, `last_knock`.
- **`yaw_arc`** on the Rig (rad either side of the piece's front; PI, the
  default, means all round). `aim_at` turns inside it, never round the back,
  and clamps there.
- The "settle" rule is new, beyond the card. Without it the gust went along
  a swing still closing on him (up to 0.15 rad off), so where he landed
  depended on which side the sweep came from.

Knobs (`rig.knobs`, from wind_horn.gd's static `blow_defaults()`): blast_out 14.4,
blast_up 1.2, delay 0.5, blast_time 0.3, rearm 2.0, reach 31.7, cone 0.25,
settle 0.08, notice_pace 0.8, view 0.6, sweep 0.45 rad/s, sweep_share 0.85,
turn_max 1.5.

## Proved (headless, through the real play loop)

All runs use the study's own `_process`, input actions and `--fixed-fps 60`.
The probe scripts were throwaway and were not kept.

- **The blaster is unchanged.** The trap yard's wind stations were run before
  and after: the blaster stood on its plate (10 jittered spots), the blaster
  run through (5), and the vent burst (5). All 20 lines are identical. For
  example, the knock is at 0.517 s, v (13.789, 7.466, 0) one frame after
  (flat 13.79 = the 14.4 m throw), landing 19.0-20.5 m across on the floor
  6 m down, 1 shove. Running through: 172 frames and 0 shoves.
- **Horn station** (a plain floor beside the trap yard, a real RuinKitHorn,
  yaw arc 60 deg, `watch(motor)`). Each case is 10 runs, start jittered
  +-0.5 m, timing 0-0.4 s:
  - hop in front (7-11 m): **10/10**, woken "air", gusted once, stunned,
    source = the horn, thrown 14.15 m.
  - run across its front: **10/10**, woken "seen", gusted, 12.3-14.2 m.
  - creep across (25 % stick, about 0.57 m/s): **10/10** unnoticed.
  - hop beside it, outside the arc: **10/10** unnoticed.
- **The Vigil greybox.** A local copy, untracked and deleted after. Its
  stand-in gust was swapped for the real Rig: `yaw_arc` from its table,
  `watch(motor, {reach})`, `may_draw` = the shared bellows. Seeds 11 and 7,
  10 runs each, same jitter. The stand-in was re-run through the same harness
  for comparison:

  | chain | real horn | stand-in |
  |---|---|---|
  | 1 splash in the pool, gate horn, into a NW bay | 12/20 | 11/20 |
  | 2 hop on the apron, gate horn, into the kick shaft | 20/20 | 20/20 |
  | 3 seesaw launch, gate horn mid-air, NE | 19/20 | 20/20 |
  | 4 hop, out the fallen NE corner | 20/20 | 20/20 |
  | creep across the apron, unnoticed | 20/20 | 20/20 |

  - **Chain 1** is a layout knife-edge, not the horn: real and stand-in
    behave alike. The gust line from the gate horn meets the north wall
    right at the pier between NW bays 1 and 2 (x about -16.5). About half
    the runs stop against that pier, in the open gap at x -15.9. The other
    half slide on into bay 1 at x -18.2. The splash wakes it every time.
    For the turf pass: move the splash spot about 0.5 m west, or widen the
    bay.
  - **Chain 3:** the seesaw's own plate would not hold the pilot in this
    harness (he slid off the tipping far end before its 1 s fuse). So the
    harness stood him on the far arm and released the block itself (jitter
    0-0.4 s). The miss lands on the east wall top (y 3.7, z +1.4).
  - Chain 2's climb up the shaft (the wall kicks) was not re-run. It is the
    motor's alone and is unchanged.
- **Smoke:** `studies/run_layer.tscn` sprawl seeds 1, 2, 3 and ring seeds
  1, 4 (400 frames each), plus the Vigil copy and the wind horn study: no
  SCRIPT ERROR. The headless import showed no script errors. Its only
  message is a Windows editor `HRESULT` error.

## Tests (existing, none added)

Run: test_trap_* (wind, voussoirs, seesaw, sluice, sluice_aqueduct,
roll_flip, giants), test_wind_horn, test_wind, test_stun_yard,
test_pilot_stun, test_dragon_grip_stun, test_ruin_kit, and
test_crossing_viaduct (plain, arrows, heights, perches).

- **Pass:** test_trap_wind, test_wind_horn, test_stun_yard (includes the
  blaster station), test_pilot_stun, test_dragon_grip_stun, test_wind,
  test_ruin_kit, test_trap_voussoirs, test_trap_sluice,
  test_trap_sluice_aqueduct, test_trap_roll_flip. Some pass only with a
  known engine error: an exit leak.
- **Fail, the same with this change reverted** (checked on this Windows PC,
  so none of them is caused by this round):
  - test_crossing_viaduct, _arrows, _perches: an unclassified engine
    "Pages in use exist at exit in PagedAllocator" at exit. Their checks pass.
    Perches showed 3 FAILs once under 8-way load; run 3-way, it passes its
    checks.
  - test_crossing_viaduct_heights: sail and updraft checks. These are flaky
    and differ run to run.
  - test_trap_seesaw: "comes down on the high ledge".
  - test_trap_giants: the rider lurch checks.

## Not done / the user's call

- No motif places a watching horn yet. The Vigil's turf pass would call
  `watch`, set `yaw_arc` and wire its bellows through `may_draw`.
- Look and sound were not judged: the swell size, the empty squash, the
  inhale and rush sounds, the gust puffs. Headless only.
- The horn is not a trap (no `ports()`, cost or TrapField hookup). It is a
  kit piece with a brain.
- The bell-style knock-out from below (to call `disabled`) is still the
  Vigil's stand-in key.
