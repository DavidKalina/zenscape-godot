# Handoff: the bag throw on the move (prototype round)

Branch `iter/bag-throw` (from `iter/heist-round2` b8f04e08), not merged.
The user's ask: "Similarly with the bag. Needs to be throwable while moving."

## What changed

- **Aim on the move** (`scripts/carry/loot_bag.gd`):
  - He keeps walking or running under the stick while he holds the throw. He
    swings the sack up over his head and pumps it there (`AIM_PUMP`, deeper
    on the move).
  - Standing, he turns to the reticle. On the move he keeps his own heading.
  - A ledge, a rider or water puts the aim away (as the rope's whirl).
  - The hosts' `_want` no longer stop him: `crag_reach.gd`, `bag_study.gd`,
    `wreck_cluster.gd`. `aim_steer` is kept as a no-op.
- **The camera picks the spot** (`look_spot`). Along the camera's look line:
  1. A ledge: the first top that is a step up (`AIM_UP`) from the sample
     before it. A ramp or slope doesn't count.
  2. Else a gap: the first top past a drop that is no more than
     `AIM_FAR_DROP` under him.
  3. Each lands `AIM_IN` past the lip. Else the spot is `AIM_START` of the
     reach on.

  The spot is kept within the reach. The lobs, the red reticle and the
  blocked check are unchanged.
- **Camera speed:** while aiming, the camera turns as fast as during the
  rope's whirl. The mouse turns `AIM_MOUSE` times as fast; the right stick
  adds `AIM_STICK`.
- **Camera ease** (out, wider, levelled):
  - On a host with the rope, the rope's `_cam_step` now eases for the bag too
    (`bag.cam_wanted()`: aiming, throwing, the bag in flight). That is one
    ease for both, so a hand-over doesn't jolt it.
  - Without a rope, the bag eases with the same values (`AIM_FAR`, `AIM_WIDE`,
    `AIM_EASE`, `AIM_POLAR`). `bag_study`'s own swung aim camera is removed.
- **Throw on the move:**
  - He keeps going through the snap at `THROW_PACE` (it used to be 0.15).
  - The arc is solved from where the sack leaves his hands, so it lands on
    the reticle.
  - At a run it reaches further (`RUN_REACH`) and flies flatter (`RUN_FLAT`).
- **Hand-over** (`studies/crag_reach_greed.gd`):
  - Both aims follow the camera. `rope_ahead` is now the rope's own camera
    pick (`_pick`). It counts when the rope wants it: any swing point, a post,
    or a lip on a face too tall to climb.
  - Going from the bag (or a fresh press) to the hook needs a swing point or
    post within `HANDOVER_CONE` (0.6) of the rope's snap cone. Going back
    needs the look off the whole cone. Each switch waits `HANDOVER_HOLD`.
  - A bag too heavy to throw always gets the hook.
  - Driver `aim_point`s carry across a hand-over. The old stick-based
    `aim_toward` hand-over and `HANDOVER_ON`/`OFF`/`LIP_AHEAD` are gone.
    `climb_rope.gd` gained `look_k`.
- **Hints:**
  - Context line: "hold LMB/T aim a throw of the bag where you look". While
    whirling: "let go: throw the hook (look off it: the bag)".
  - The heist foot hint and the bag study hint are updated.

## Knobs (loot_bag.gd unless noted)

| Knob | Value | What it does |
|---|---|---|
| `AIM_PUMP`, `AIM_PUMP_RATE` | 0.05 of THROW_TIME, 1.7 /s | The overhead pump while aiming |
| `THROW_PACE` | 0.85 | His paces through the throw |
| `RUN_REACH` | 0.3 | Extra reach at a full run |
| `RUN_FLAT` | 0.5 | The arc's rise at a full run, times |
| `AIM_UP` / `AIM_DROP` / `AIM_FAR_DROP` / `AIM_IN` / `AIM_STEP` | 0.6 / 1.5 / 3.0 / 0.8 / 0.4 m | How the look line finds a ledge or a gap's far side |
| `AIM_START` | 0.6 | The spot when there's no ledge or gap |
| `AIM_MOUSE`, `AIM_STICK` | 1.6, 2.4 rad/s | Camera turn while aiming (as the rope's) |
| `AIM_FAR`, `AIM_WIDE`, `AIM_EASE`, `AIM_POLAR` | 1.4, 7 deg, 3 /s, PI/2-0.3 | Camera ease, hosts without a rope |
| `HANDOVER_CONE` (greed) | 0.6 | How far into the rope's cone the look must be to hand the bag's aim to the hook |

## Controls

| Action | Keyboard / mouse | Pad |
|---|---|---|
| Aim (bag or hook, by what you look at), keep moving | hold LMB / T, WASD | hold RT, left stick |
| Sweep the target | mouse | right stick |
| Throw | let go | let go |

Reticle colours: gold lands, red won't (nowhere to land, blocked).

## Proof

All headless unless marked rendered. The throwaway drivers are in the
worktree's `scratch/`, with ledgers in `/tmp/bt`.

- **Smoke** (0 errors each): heist_level, bag_study, crag_reach
  `--greed-run`, wreck_cluster `--loot-bag`.
- **`bag_throw.gd`** (real key events, the stick, the camera yaw turned as
  the mouse would):
  - `--case=ledge`, 15 kg, up the vault ramp:
    - he moved 9.4 m while aiming and let go at 3.2 m/s, running on at
      3.2 m/s;
    - the bag landed on ledge 1's top, 0.57 m from the reticle.
  - `--case=gap`, 10 kg:
    - he let go at 4.0 m/s;
    - the bag landed on gap_far (x 102.6), 0.3 m from the reticle.
  - `--case=handover`, at gap_near in one held press:
    - the hook first (the lintel), then the bag, the hook and the bag again:
      3 hand-overs;
    - `cam_far` held at 1.31-1.40 throughout;
    - let go, the bag went across; the camera eased back to 1.0.
  - `--case=corner`, 4 kg on vault_s's crown: bag, then onto swing_02's arm
    the hook, then back off it the bag.
- **`heist_vault.gd --light --kg=15`:** all three ledges thrown up, climbed
  and shouldered again. Its two FAILs are the known stale checks (marks, and
  the old 9 kg ledge bar).
- **`heist_route.gd` (now presses the throw as a key event):**
  - `--part=out` (15 kg) passes 20/20 standing and 16/16 `--run`;
  - `--part=in` passes 26/26;
  - `--part=in --run` fails swing_01's landing at the default lead 3.5 and
    at 4.0, and passes at 3.0 and 4.5. That is swing_01's known timing
    sensitivity (heist-tidy handoff).
- **Rendered** (`scratch/shots/bag_windup_run_sheet.png`,
  `bag_throw_run_sheet.png`, `bag_cam_sheet.png`):
  - the sack held over his head while he runs reads;
  - the play camera eases out and level, with the reticle on ledge 1's top
    and the arc up to it;
  - the bag lands on the ledge.

## Open

- **The pump is subtle in the captures.** Raise `AIM_PUMP` if it doesn't read
  in play. Nothing new was authored in Blender: it is the old procedural
  wind-up pose, pumped.
- **gap_far's landing lies under the lintel (swing_03).**
  - Looking straight across is the hook.
  - To throw the bag across, look past the lintel's south end (about 25-40
    degrees left of straight from the lip).
- **The gap at 10 kg from about 2 m back:** the reticle is clamped by the
  reach to just inside gap_far's edge. At a run the reach grows.
- **Pitch isn't used.** The spot picks itself along the yaw line. To throw
  short of a ledge or gap, look off it.
- **A bag throwable in the heist (up to 16 kg) means a far swing point
  starts as a bag aim.** It hands to the hook once within the rope's reach.
- **Tests:** none in `tests/` read the bag or the hand-over, so none are
  known to break. Full suite not run.
