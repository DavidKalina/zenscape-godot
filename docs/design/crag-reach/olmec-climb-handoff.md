# Handoff: the Olmec climbs up to you, or pulls you down (prototype round `olmec-climb`)

Built on the ledge round (`olmec-ledge-handoff.md`, commit f8cf8159).
**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
The old behaviour comes back with `--body-knob=climb_to=0 --body-knob=suck_up=0`.
The round was stopped early, by request, before the rendered capture.

## The cause

- **The geometry.** main_terrace_3 (y 6–7) lies under main's south
  overhang. Main's crown at y 30 leans out over the terrace's whole north
  side: its underside runs from about y 12 at z 29 to y 29 at z 40. No face
  between the terrace and the crown can be climbed. The shelves inside the
  overhang have roofs, and nowhere does a wall come straight down to the
  terrace floor. `scratch/climb_probe.gd` checked 77 terrace points × 32
  ways and found no climbable face.
- **The stuck loop.** The chase walks him under the overhang toward your
  xz. The old `_climbable` returns INF (an underside, too tall), so he
  skirts or gets pinned there. The `climb_after` route (body_routes A*) also
  stalls under the overhang. After 7 s the never-stuck watch walks him to a
  rim to stare. The stare's plan only had leaps, drops, faces across, cliffs
  at or under his feet, and rim stands on his own level. It took the rim
  stands for 1.5 m gains, and the next walk took him to another rim. That
  is the user's log.
- **He never sees you.** From under the overhang the lip hides you, so
  `suck_in`, which needs his sight, never fired. Even when he is in view,
  the head's `_pull` drops a wanderer above it (the "stood on the head"
  check). The suck's full brace (the windup crouch) also ducks his mouth
  below the lip line.
- **Not caused by the ledge round.** With the ledge knobs off (`--old`:
  ledge_stare=0, cliff_leap=0, dive=1, which is main 3e66870c's behaviour),
  he is just as stuck. He leaps at the underside and falls back for the
  whole 60 s, and never climbs. The ledge round only changed the stuck
  look: rim to rim instead of leap and fall.

## Repro driver (scratch/, git-ignored)

`scratch/climb_case.gd`. He spawns as in play (`--olmec`) and hauls over.
The driver then sets him at `--him` and you at `--me`, and you stand still.
He plays through the real loop.

```
python3 tools/drive.py scratch/climb_case.gd -- --log --secs=50 --me=4,30,40.6            # the user's case
python3 tools/drive.py scratch/climb_case.gd -- --log --secs=50 --me=4,30,40.6 "--knob=climb_to=0;suck_up=0"   # before
python3 tools/drive.py scratch/climb_case.gd -- --log --secs=40 --him=-40,16,-12 --me=-26,30,-14   # a climbable face (main_terrace_2)
```

- `--him` defaults to (9,6,42) on main_terrace_3. `--me=4,30,40.6` is the
  crown's tip, 0.3 m in from the lip, which is where the user's log
  distances put them.
- Flags: `--old`, `--knob=k=v;k=v`, `--go-on --after=N` (runs on to the
  gulp), `--pull` (the pull's diagnostics), `--every/--from/--to` (log
  rate and window).
- It prints a ROW: reached, how, climb_ups, pulls, pulled (when your feet
  dropped 6 m), and the stare log.
- Short wrappers: `scratch/case.sh OUT [args]` (one run, summarised) and
  `scratch/cases.sh` (16 starts).
- Probes: `climb_probe.gd` (`_climb_find` from points: why each way fails),
  `map.gd`, `section.gd` (height maps and sections), `lip_probe.gd` (which
  terrace stands see you at each point of the south lip).

## What changed (headless_body.gd, a few lines in inhaler_head.gd and crag_reach.gd)

**`climb_to`.** Applies when you are over him: up past his stair and
within `climb_look` Hh off flat.

- The stare's plan looks along the foot of the face. `_climb_find` sends a
  chest ray each of 32 ways, out to `climb_look` Hh, from his stand and from
  6 stands round him. A face counts when:
  - it meets his floor (no undercut),
  - its foot is walkable straight,
  - its lip is within climb_max plus his mantle (a shelf short of it counts
    as the lip),
  - his hung bulk is clear all the way up (`_climb_column`: no overhang, the
    face stays in reach),
  - there is no roof over the lip and there is room past it,
  - the lip is about your level or under it, and 3 m nearer you.
- He walks to a stand his shoulders' breadth off the foot, turns to the
  face, walks in, and his existing feel, climb and mantle take him up.
- When you are over him, rim stands on his level drop out of the plan.
- A wall he can't climb in the chase, and his old `_after_try`, now start
  the stare first. The planner's route is the fallback.

**`suck_up` (8 Hh in OLMEC_KNOBS).** This runs only when the plan finds no
climb.

- He goes to the nearest stand where his mouth has a clear line to your
  chest (`_sight_find`), or uses the one he is on.
- He plants with the jaw tell and pulls. The brace is SUCK_UP_BRACE 0.3, so
  his mouth stays up.
- His mouth's line keeps the suck going.
- The head's "stood on the head" check is skipped while `_suck_up_now` is
  set.
- With no climb and no pull, the never-stuck watch no longer walks him from
  rim to rim. He waits.

Both knobs are off by default and on in OLMEC_KNOBS. olmec_field and
whole_body_chase are unchanged.

## Numbers (headless)

- **The user's case** (you at the lip (4,30,40.6), him at (9,6,42)):
  - Before: nothing in 50 s, 3 ledge walks.
  - After: he plants at 10.7 s, you are pulled off at 14.7 s and gulped.
  - Across 12 starts and lip spots (`cases.sh`): 11 pulled down, 3–43 s.
  - One run, him at (9,6,42) with you at (10,30,37.6), never got a stand
    with a line to you.
- **main_terrace_2 → crown** (a climbable stretch beside an overhang):
  - Before: stare, no way, then wanders.
  - After: he climbs and pounces at 15–16 s. 7 of 8 starts climbed or
    reached you.
  - From (-44,16,-12): reached at 17 s, but **2 void falls** were counted.
    Not looked at.
- **Reach table, 20 places, 60 s:**
  - Seen: 15/20, the ledge round's 15.
  - Blind: 13/20, the ledge round's 13, the same places at about the same
    times.
  - 0 despawns, 0 void falls.
  - The table never puts you over him within 27 m, so it doesn't use the
    new paths.

## Where to stand to see it

- **The pull:** stand on main's south tip at the very edge, about (4,30,40.6),
  with him on main_terrace_3 below. Step back 0.6 m from the lip and he
  can't see you, so he waits under you.
- **The climb:** stand on main's crown at about (-26,30,-14), with him on
  main_terrace_2. He climbs the clean stretch at about (-34,·,-5).

## Still off / not done

- No rendered capture was taken (the round was stopped). The feel slides him
  about 2 m to the face. The stare turns, the turn onto his way and the turn
  to the face add up to about 3 rad in the pull case.
- Back from the lip, you are out of his line, and he waits deep under the
  overhang (the route took him there).
- The 2 void falls from (-44,16,-12).

## For the `chase_routes` round (the A* in body_routes.gd)

Evidence from these runs only:

- With `climb_after`, his existing route-after (`_after_try`, the same
  planner) was tried in both cases and stalled each time. On terrace_2 it
  sent him to (-35.5,16.5,-11.5), under the overhanging part of the face,
  and he stood there about 7 s "routed" with no progress. On terrace_3 it
  led him to (13,6,30), deep under the overhang.
- So the planner's climb legs don't see overhangs or bulk room at the
  Olmec's size (hh 3.36, a bulk 6.7 m across, climb_max 22 m).
- A route round needs checks like `_climb_column` and the room-past-lip
  check on climb legs. Without them it will pick climb legs his body can't
  make.

## Proof

- Headless import. Smoke PASS: crag_reach plain and `--olmec`, olmec_field,
  whole_body_chase.
- No committed tests. Full suite not run.
- No existing test should break: no test refers to the changed code, and
  the knobs are off by default.
