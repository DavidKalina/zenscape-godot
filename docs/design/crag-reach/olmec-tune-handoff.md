# Handoff: the Olmec's chase tuned (prototype round `olmec-tune`)

Built on the routes round (`olmec-routes-handoff.md`, b07ada88).
**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
Each fix has its own knob. They are off by default and on in `OLMEC_KNOBS`
(studies/crag_reach.gd), so heist_level gets them too. To turn one off, pass
for example `--body-knob=run_soft=0`.

## Causes found (measured, `scratch/olmec_curve.gd`)

- **The run reset (feedback 1).** On a straight chase his heading jumped by
  0.1–0.5 rad every replan (about every 1.5 s while you run). The cause was
  `_pc_aim` stepping between the grid route's 1.5 m leg ends, at most 1 m off
  a corner. Every jump cost run speed in two ways:
  - `run_turn_cost` on any turn over 0.2 rad/s: 0.5–1.7 of his build lost
    per run.
  - `aligned²` slowing him while he faced off his way, with the build then
    held to his real speed (`_run_hold`): up to 0.5 more lost.
  - With the windowed check off, a gentle curve held his top for only
    0.6–1.6 s of the 7 s it could have.
  - A second cause showed in a rendered run, where the search takes more
    frames: his route ran out before the new one arrived. At its end he
    stopped and stared, which dropped the whole build.
- **The flip-flop in rubble (feedback 2).** At islet_12 he plows through a
  ruin. Each settle (and each re-settle of pieces his shove loosens) called
  `world_changed`. That forgot the graph and planned again **at once**: 35–60
  world changes per run, up to 233. Each new route could go another way.
  - Worst case measured: **19 route switches** (a new route turning him past
    0.6 rad) and 8 facing reversals in one 10 s window, standing in a pile.
  - Elsewhere (west_spire) a world change after his landing gave a route
    1.6 rad off the old one, then another, while he stood.
  - Found while fixing it: `_pc_pulls_from` said "I can suck you from here"
    when the worn head's pull didn't reach. He then stared ("none") for good.
- **The head (feedback 3).** The gaze is clamped at 125° (olmec_gaze.gd
  `MAX_YAW`). Standing with you round his side, his head went to 86–103°.

## What changed

- **`plan_smooth`** (headless_body.gd `_pc_smooth_aim`, `_pc_pass_legs`,
  `_pc_run_on`; olmec_route_graph.gd `walk_line`):
  - On walk legs he aims at the farthest point along the route within his
    look-ahead that he can walk straight to. The look-ahead is 9 m at a walk
    and grows to 14 m at his top run. The route is sampled every 0.75 m and
    the aim is found again every 0.1 s.
  - Straight-to means each column on the line is a place he fits, with its
    four neighbours fitting too, so the line keeps a column off rims. Without
    that, his look-ahead at speed met an edge and failed the leg.
  - Grid routes read as straight lines, and corners as gentle curves.
  - A leg counts as passed by where he is along it, not only at its end.
  - At a route's end, with you seen on his level and the ground straight to
    you walkable, he runs on at you while the new plan runs.
- **`run_soft`** = 0.6 rad (`_turn_real`):
  - A turn costs run speed only once his facing has swung about 0.5–0.8 rad
    (29–46°) over the last 1 s. Past that it costs in proportion.
  - 0.25 rad off his way no longer slows him (`RUN_FREE_OFF`).
  - Top speed and build time are unchanged.
- **`plan_keep`** = 0.2 (`_pc_keep_old`): a fresh route that would turn him
  past 0.6 rad replaces his current route only in these cases:
  - it is 20% cheaper (at least 3 m of walk),
  - his route is broken (a place he no longer fits, a rebuilt move gone, a
    ban),
  - his route is to where you were (your target moved 6 m or more),
  - he has spent more than 3 s on his current leg,
  - it gets to you when his route doesn't.

  Also, `_pc_pulls_from` now requires that the head's pull really reaches you
  (`worn_reaches`).
- **`plan_settle`** = 1.0 s (`_pc_settle`):
  - Rubble at rest plans again only if it lies by his route.
  - It waits until no more has settled for 1 s, and at most 4 s from the
    first settle.
  - The graph still forgets the area at once.
- **`plan_flips`** = 3 (`_pc_flip_watch`): 3 turns back (each over 0.3 rad)
  within 8 s, and he holds his route for 6 s. During the hold only a broken
  route or a failed leg replans.
- **`gaze_yaw`** = 65° (olmec_gaze.gd `_eased`, `past`; headless_body.gd
  `_gaze_follow`):
  - The head's yaw follows the look up to 60% of the limit, then eases with a
    tanh knee toward 65°. There is no hard stop.
  - Past 85% of the limit, for 0.25 s, his body turns after the look at his
    stood turn rate. This only happens while he stands in seek, land, spent,
    listen or alert. In the chase, stare and leaps the body keeps its own
    decisions and only the head is eased.

**Touched next to `_animate`:** one line in `think()` calls `_gaze_follow`
just before `_animate`. It sets `facing` and `_heading` only.
`_pc_flip_watch` is called after `_searching()`. Nothing in `_animate`, the
look and steps scripts or art/ changed.

## Knobs (default / OLMEC_KNOBS)

| knob | value | constants |
|---|---|---|
| `plan_smooth` | 0 / **1** | SMOOTH_AIM_TOP 14, SMOOTH_STEP 0.75, SMOOTH_EVERY 0.1; graph WALK_SIDE |
| `run_soft` | 0 / **0.6** rad | RUN_WINDOW 1.0 s, RUN_FREE_OFF 0.25 |
| `plan_keep` | 0 / **0.2** | PLAN_KEEP_WAY 0.6, PLAN_KEEP_MIN 3, PLAN_KEEP_LEGS 16, PLAN_KEEP_STUCK 3 s |
| `plan_settle` | 0 / **1.0** s | PLAN_SETTLE_MOST 4 |
| `plan_flips` | 0 / **3** | FLIP_MIN 0.3, FLIP_WINDOW 8, FLIP_HOLD 6 |
| `gaze_yaw` | 0 / **65**° | gaze KNEE 0.6, FOLLOW_AT 0.85; GAZE_FOLLOW, GAZE_FOLLOW_AFTER 0.25 |

Counters for drivers: `world_changes`, `plan_kept`, `plan_switches`,
`plan_flipped`, `plan_holds`, `keep_why`; `gaze.past`.

## Before / after (headless)

**Curve chase.** You run across main's crown through the stick with his
attacks off. The table shows seconds at top run, and in brackets the most he
could hold (from when he first reaches top to the end).

| path | before | after |
|---|---|---|
| straight | 2.5 (4.3) | 4.3–5.4 (all) |
| gentle curve 0.12 rad/s | 1.6 (6.9) | 6.3–7.0 (all) |
| curve the other way | 0.6 (2.9) | 7.1–7.3 (all) |
| zig-zag ±0.2 rad every 1.2 s | 3.9 (4.6) | 4.6 (all) |
| wiggle | 4.1 (4.3) | 4.4 (all) |

- Before, the build lost to turns was 0.2–1.7 per run. After, it is 0–0.05.
- After, there are no run resets across 7–10 replans.

**Rubble and flip-flops** (8 rubble-heavy places plus islet_12 ×3, 60 s;
`plan_keep`, `plan_settle` and `plan_flips` off vs on, the rest on):

| | off | on |
|---|---|---|
| route switches per 10 s | 0.72 | 0.26 |
| worst 10 s window, switches | 5 (19 in an earlier islet_12 run) | 2 |
| facing reversals per 10 s | 2.26 | 1.97 |
| worst 10 s window, reversals | 7 (8 earlier) | 6 |
| plans per 10 s | 4.25 | 3.55 |

- **islet_12, 6 runs with everything on:** reached 6/6 in 23.5–38.6 s, 0
  switches in 5 runs. Before: 30–57 s, and 1 of 4 not reached at 60 s.

**Reach table** (20 places, 60 s; `scratch/olmec_reach.gd`):

| | routes round | baseline this round | after |
|---|---|---|---|
| reached, seen | 15/20 | 15/20, mean 19.9 s | **19/20**, mean 22.5 s |
| reached, blind | 17/20 | 16/20, mean 22.8 s | **17/20**, mean 21.8 s |
| despawns, void falls | 0 | 0 | 0 |
| planted reversals per rim visit, seen / blind | — | 1.03 / 1.04 | 0.91 / 1.67 |

- **Newly reached, seen:** east_terrace_2, west, west_terrace_1 and
  west_spire.
- **Newly reached, blind:** east_terrace_2 and north_terrace_1.
- **Lost, blind:** west_spire (it was 50.9 s before; this varies run to run).
- Most places are faster, for example islet_12 seen went from 51.7 to 24.4 s.

**Head** (`scratch/olmec_head.gd`; he stands while you walk round him):

- Before: the head's yaw reached 86–103°.
- After: it peaks at 57–59°, the body turns after it, and the look holds
  about 55° off his body.

## Where to see it

- **The run:** stand on main's crown and run gentle curves or slight
  zig-zags. He holds the run and arcs instead of stepping.
  - Sheet: `scratch/shots/run_curve_after_sheet.png`. The camera turns with
    him, so the background swings as he arcs while he stays in the shoulder
    run.
- **The rubble:** stand on islet_12, about (42,9,52). He plows through the
  ruins east of main's south terrace and picks one way out.
- **The head:** let him stand (land, spent) while you circle him.
  - `scratch/shots/head_after_spent_sheet.png`: the head eased, body
    following.
  - `scratch/shots/head_before_spent_sheet.png`: the head about 100° round.

## Still off

- **Blind rim reversals went up** (1.04 to 1.67 planted per visit, worst
  visit 6). They are mostly at west and west_spire, where the aqueduct
  breaks under him. They come from stare/plan and stare/turn beats (turn to
  you, then onto the leg) and from the stood steps. The flip cap holds his
  route there but doesn't stop the beats.
- **What `plan_flips` counts:** facing reversals of any cause, including the
  stood steps' own swing. On landing he can swing about 0.5 rad off a 0.06 rad
  turn and back. That swing is in `look.steps`, the animation round's area.
- **Rubble lifts him:** wading a heap moves his feet up to 5 m, and the pile
  re-settles for as long as he shoves it.
- **The heist's Olmec** is only smoked (load); no heist chase was driven.
- **`gaze_yaw`'s body turn** works only in the standing states listed above.
  Running on a route with you behind him, the head just eases to the limit.
- **`_pc_smooth_aim`'s line test** reads graph columns. A column not read yet
  casts its rays then, which is rare on built ground.

## Proof

- Headless import. **Smoke PASS:**
  - crag_reach plain and `--olmec`
  - olmec_field, whole_body_chase
  - heist_level `--no-title --ledger=/tmp/...`
- **Throwaway drivers** (scratch/, uncommitted):
  - `olmec_curve.gd` (curve chase; `--path=`, `--film`)
  - `olmec_reach.gd`, now with oscillation counters, worst-window counts,
    `--fliplog` and multi-knob `--knob=a=1;b=2`
  - `olmec_head.gd` (head yaw; `--state=`, `--film`)
  - `osc.py`, `cmp3.py`, `crown_map.gd`, `table.sh`, `both.sh`, `sum.py`
- **Rendered captures** (one window each, watchdog), looked at:
  - the head sheets, before and after
  - the curving run sheet
- No committed tests, full suite not run. **No test refers to the changed
  code** (olmec_gaze, the route graph, `plan_chase`, `OLMEC_KNOBS`). Every
  knob is off by default, and `gaze.past` is new. I expect no breaks.

## Harness gaps

- `sweep.py` puts `--arg` after the driver's `--scene-args`, so knob sweeps
  went through a driver flag (`--knob=`, which now takes several, `;`
  separated).
- A driver row flattens nested dicts to `key.sub` columns. That is useful,
  but it isn't documented.
