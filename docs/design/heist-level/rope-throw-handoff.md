# Handoff: the rope throw on the move (prototype round)

Branch `iter/rope-throw` (from `iter/live-rope` 91ac39f6), not merged.
Most of the change is in `scripts/rope/climb_rope.gd`. Outside it:

- the hosts' `_want` in `studies/crag_reach.gd` and `studies/rope_study.gd`
  (one line each: whirling no longer stops him);
- hint text in `studies/rope_study.gd` and `studies/swing_study.gd`.

It doesn't touch the tool slot, loot or Olmec code. The greed hint in
`crag_reach_greed.gd` still says "E tug". iter/heist-tidy rewrites that hint.

## What changed

- **Whirl on the move.** Holding the throw, he keeps walking or running
  under the stick, and through jumps and off edges. The hook circles at his
  side and his arm circles with it. A ledge, a rope or water puts it away.
- **The camera picks the target.** The stick no longer moves the reticle.
  - A swing point or anchor post near the camera's look line snaps the
    reticle (within `AIM_CONE`).
  - Otherwise it goes on the first lip above him along that line.
  - Otherwise it's red on the ground ahead.
  - While whirling, the camera turns faster: the right stick adds
    `AIM_STICK` (4.6 rad/s in all, against 2.2 before) and the mouse turns
    `AIM_MOUSE` times as fast.
  - Standing still, he turns to face the target. On the move he keeps his
    own heading.
- **Throw on the move.** The arc is solved from his moving hand. At a run
  it flies flatter (`RUN_FLAT`), and every flight is quicker (`FLY_PACE`):
  about 0.9 s to a high swing point, down from 1.5 s. He keeps going as the
  rope pays out. If he gets past `ROPE_LEN` from the hook in flight, the
  rope runs out and the hook drops. A red "out of reach" throw used to
  catch anyway; that was a bug.
- **No tug.** A hook that lands on a hold is set at once (`seated`, holds
  his weight). The hidden "bad hook gives partway up the climb" is gone.
  A crumbly lip shows amber at the aim, and at the catch it may skitter off
  in grit and fall (`POOR_BAD` 0.5). So the risk always shows at the throw.
  The heist's tops are all solid.
- **Swing points.** Set over a swing point, the rope is in his hand at
  once (`swing_hold`). Run off the edge (or press Space) into the swing. If
  the hook sets while he's already in the air, he swings at once, lower.
- **Rethrow.** Holding the throw with the hook out snatches it back to his
  hand through the air, then whirls again if still held. That works after
  a miss, on a lip, or on a swing point. It doesn't work on a tied rappel
  rope or from up top over a hooked lip. F still reels in as before.
- **Camera.** While whirling and during the flight, the camera eases out
  to `WHIRL_FAR` and widens a little. It also tilts up toward
  `WHIRL_POLAR`, as an offset on the player's own look, so the face and the
  gap are in view. It eases back after. The rope study keeps its own pull
  (`_cam_pull`).
- E at an anchor post up top still ties the rappel rope (the "tug" state
  is now only that tie's yank). On a rope, E still kicks or hops.

## Knobs (climb_rope.gd)

| Knob | Value | What it does |
|---|---|---|
| `AIM_CONE` | 16 deg | Snap cone for swing points and posts |
| `AIM_NEAR` | 1.2 m | Snap distance across the look line, near him |
| `AIM_PREFER` | 0.6 | A swing point or post wins over a lip inside this share of the cone |
| `AIM_STEP` | 0.4 m | Step when walking the look line for a lip |
| `AIM_MOUSE` | 1.6 | Mouse turn, times its own, while whirling |
| `AIM_STICK` | 2.4 rad/s | Right-stick turn added while whirling |
| `RUN_FLAT` | 0.45 | The arc's rise at a full run, times |
| `FLY_PACE` | 1.9 | How much faster the flight is (same arc) |
| `WHIRL_FAR` | 1.4 | Camera reach while whirling, times |
| `WHIRL_WIDE` | 7 deg | Camera widening while whirling |
| `WHIRL_EASE` | 3 /s | How fast the camera eases out and back |
| `WHIRL_POLAR` | PI/2 - 0.3 | The camera's tilt while whirling |
| `WHIRL_R` | 0.55 | Whirl radius |
| `YANK_TURN` | 8 /s | How fast the snatched hook turns toward his hand |
| `POOR_BAD` | 0.5 | Chance a crumbly lip skitters |

Unchanged: `AIM_REACH` 10 m flat, `ROPE_LEN` 14.

## Controls

| Action | Keyboard / mouse | Pad |
|---|---|---|
| Whirl the hook, move as usual | hold LMB / T, WASD | hold RT, left stick |
| Sweep the target | mouse | right stick |
| Throw | let go of LMB / T | let go of RT |
| Throw again (snatches a miss back) | LMB / T | RT |
| Take hold of a set rope | Space by it | A |
| Climb, down, slide | W, S, Shift | stick up, back, crouch |
| Swing point | run off the edge or Space | run off the edge or A |
| Reel in | F | D-pad down |
| Tie at a post up top, kick / hop on a rope | E | B |

Reticle colours: gold catches, amber is a crumbly lip that may skitter,
red won't catch.

## Proved (headless, throwaway drivers in the worktree's `scratch/`)

- **Smoke** (0 errors each): heist_level, rope_study, swing_study,
  bag_study, and crag_reach `--greed-run`.
- **`rope_throw.gd --case=run`:**
  - he moves 2.4 m in 0.5 s while whirling;
  - he releases at 4.8 m/s and runs about 5 m during the 1.1 s flight;
  - the hook sets on the gate lip with 0 tugs;
  - Jump, climb, up and over, nothing gave.
- **`--case=runoff`:** he whirls at a run on ford's rim and throws at
  swing_05 at 4.8 m/s. It sets about 0.9 s later and he runs off into the
  swing and lands on stack_1. This works releasing anywhere from 72 to
  76.5 m along.
- **`--case=miss`:**
  - a red throw at bare ground comes down (a miss);
  - throwing again snatches it back and whirls in about 0.4 to 0.95 s;
  - the next throw at the lip sets, 2.4 s after the miss.
- **`--case=sweep`:** the right stick turns the reticle 4.6 rad/s (the old
  reticle was about 1.8). A full turn takes 1.4 s and passes swing_05 and
  lips.
- **`rope_crumble.gd` (rope study, skitter forced):**
  - amber on the crumbly lip;
  - it skitters at the catch and falls;
  - a rethrow on the solid lip sets, climbs up and over.
- **`heist_route.gd`:**
  - `--part=in`: rappel post_01, swing_01, hook climbs on the gate face and
    vault_n, rappel post_02. 26/26 checks; `--run` passes too.
  - `--part=out` (15 kg bag): swing_02, swing_03, swing_05 and swing_06,
    each landed, standing and `--run`. 16/16 checks.
- **`live_rope.gd`** (the last round's): sway, pump, kicks, let-go swing,
  rappel traverse and hops, 15 kg climb, and the 16 kg refusal all pass.
- **Rendered** (`scratch/shots/whirl_run_sheet.png`,
  `throw_cam_sheet.png`):
  - the hook circling at his side while he runs reads clearly;
  - the camera levels and pulls out with the face and arc in view, then
    eases back after the catch.

## Open

- Judge the feel: `AIM_STICK`, `AIM_MOUSE`, `FLY_PACE`, `WHIRL_*` and the
  snap cone are first guesses.
- The whirling hand stays put (no IK on the hook). Only the arm swings.
- A lip much higher than him and out of reach shows red, and the reticle
  sits on the lip out of frame top. The arc up the face shows the way.
- Releasing at the rim, so the hook sets with him in the air, gives a
  deeper swing. Throw a few metres before the edge.
- The snatch back after a miss takes up to about 1 s from far.
- Tests: none in `tests/` read the rope, so none are known to break. The
  full suite was not run (prototype).
