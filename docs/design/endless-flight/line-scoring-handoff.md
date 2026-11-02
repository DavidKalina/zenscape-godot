# Line scoring by degree of difficulty: handoff (2026-11-01)

A line now scores degree of difficulty and its shape. Each moment pays base x band
x its factors. Runs of one kind and surface pay a length bonus. A flourish steps up
the line's multiplier. There's no separate chain multiplier any more. The old
formula is still there with `--line-score=old`.

## What was built

- `scripts/endless/line_score.gd` (`LineScore`): the formula, with
  `LineScore.Line` holding a line under way. Every number is in
  `scripts/endless/line_tune.json`, which the game and the re-scorer both read
  (it is added to the export presets' include filter).
  - Moment = `base[kind]` x `band[band]` x Close x Fast x Knife x Low x Under
    (x hold for a held move, x `farm_same` when it's the same tree or patch again).
    Close: k^1.5 up to 1.5. Fast: from `plane.cruise()` to `plane.boost_speed()`
    (level Boost, the top held speed), up to 1.5. Knife: 30 to 90 degrees of bank,
    up to 1.4. Low: 10 m to 3 m over the land, up to 1.3. Under: 1.3.
  - Run: moments of one kind and surface, each within `run_gap` 2 s of the last.
    One closer than `run_echo` 0.05 s is the same pass seen twice (trunk and crown):
    it is paid but not counted. From 2 moments a run pays
    `run_scale` x n^`run_pow` (0.05 x n^2) x the run's average Fast.
  - Flourish: a moment of another kind or surface than the line's last run of 2 or
    more, whose factor product is over 1.6x that run's average. It adds +0.6 to the
    line's multiplier (cap 4), applied to the whole line. One flourish per run.
    Moments in between (a stray pull-out) don't stop it.
  - Line total = (moments + run bonuses) x multiplier. Game points = units x 100.
- `scripts/endless/near_miss.gd`: `_line_moment` scores every moment this way and
  writes its log row, under either formula. Under the new one, `_chain_line`
  replaces the old chain. `multiplier()` returns the line's multiplier. `top()` is
  the cap (the HUD heat uses it). `bank_after()` is the bank timer. `meter_full()`
  is the meter's fill. `run_label()` returns "TREES ×7". Skimming holds the bank
  but adds nothing. The old FARM_EACH cut is gone; only the same-spot cut stays. The
  slalom held move is skipped (`skip`), because its trees are already a run of grazes.
  - Fix: a passage under an arch (`_pass`, `_gate`) now records its roll. Before,
    a knife-edge pass under a span was never seen as knife edge.
- `scripts/endless/line_log.gd` (`LineLog`): `--line-log=FILE`. It writes one row per
  moment and one row per line end (banked, lost or reset), and is wired beside
  `FrameLog.begin`.
- `tools/line_report.py`: re-scores a log from its raw columns, prints line cards,
  prints two logs side by side, and takes `--set key=value` (`base.thread=1.1`).
  `--check` compares each row's points, multiplier and running total with the log.
- HUD (ring): the newest pass's top two factors show as tags (CLOSE, FAST, KNIFE,
  LOW, UNDER, when over 1.15) after its points. The live run (TREES ×3) shows after
  the multiplier. The ring's arc and heat use `bank_after()` and `top()`.

## Flourish pass after the first hand flight (2026-11-01)

The first flight (68 lines) got one flourish, because Fast is the same on
everything flat out and pull-outs filled whole lines. This supersedes the
Flourish bullet above; `line_score.gd`'s header has the rules.

- The flourish test leaves Fast out, `flourish_margin` is 1.25, and
  `flourish_min_run` is 1.
- Switch: another kind or surface that isn't a flourish adds `switch_step` 0.2,
  once a run. The ring's tags show FLOURISH or SWITCH.
- Filler: a near pull-out or skip is paid and keeps the line alive, but makes no
  run, doesn't break one, and never steps the multiplier. Close and razor ones
  (`filler_shows`) count as ordinary moments.
- Logs from before this pass fail `--check`, because they hold the old tuning.

## Ring HUD pass (2026-11-01)

`near_miss_hud_ring.gd` now reads the line as `LineScore` scores it. This
supersedes the HUD (ring) bullet above; the file's header has the details.

- A feed of the line's last three runs, newest on top, replaces the pass row and
  the medallion trail. Multiplier steps fly into the multiplier and ring a bell
  (`flight_sound.gd`, the burrower's bells).
- Filler moments only tick the total. The newest row shows one tag, never FAST.
- The last pass's clearance sits under the ring, for every pass.
- A banked line's banner shows its runs in order, the sum and the money, then its
  closest pass, average speed and time. Prizes and `--line-score=old` lines keep
  the seals.
- Stills came from a stand-in over a plain backdrop (`scratch/hud_lab.gd`), so the
  feed hasn't been judged over the real land. The next pass cuts the banner short.

## Tuning changes outside the brief (all in line_tune.json)

- `bank_after` is 4.5 s (was BANK_AFTER 3). Trees are cleared 110 m in front of an
  arch's opening (`tree_plan.gd` ARCH_APPROACH). At cruise (36.8 m/s) the gap from
  the last tree to the arch is about 3.8 s, so with 3 s the easy reference line
  always banked before the arch.
- `low_from` is 10 m (the brief said 15). Weaving trees is always low, and at 15 m
  Low added about 1.2 to every easy tree. That lifted the easy line to 6 or more.
- Meter: `meter_full` is 10 units. Under the old formula, the easy flight's 3 trees
  filled 0.29 of the meter and the hard flight filled it in 3 moments (the
  multiplier grew fast). Under the new one, 3 easy trees fill about 0.3 and a hard
  run fills it in about 6 moments. The meter still banks a line early when it would
  fill. That cut the hard line short when `meter_full` was 8.

## Play with the log on

    cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-ab356abf24c417c1e
    python3 tools/play.py -- --pilot-file=/tmp/line_play.json --line-log=res://scratch/line1.csv
    python3 tools/line_report.py scratch/line1.csv
    python3 tools/line_report.py scratch/line1.csv --check
    python3 tools/line_report.py scratch/easy.csv scratch/hard.csv --set run_scale=0.07
    # A/B: the old formula (the log still holds the new score, shadowed, and the old points)
    python3 tools/play.py -- --pilot-file=/tmp/line_play.json --line-score=old --line-log=res://scratch/old1.csv

## What the driver flew (scratch/line_fly.gd, real input path, seed 1)

The autopilot used the stick, Boost and lean actions. It flew straight approaches
along trees to an arch that `scratch/line_survey.gd` picked.

- Easy: gate `endless/arch/6_-1/0` at cruise. It flew 3 trees, then through the
  arch's middle, then a pull-out after. Run TREES x3 (2.67 + bonus 0.45), thread
  1.30 (UNDER), pull-out 0.71: **5.13** (4.42 without the trailing pull-out).
- Hard as flown: rock arch `endless/arch/4_-11/0` on Boost. It flew TREES x3,
  a pull-out, then a knife-edge pass (bank 90) 1.1 m off the leg, which scored as a
  flourish (FAST 1.50, KNIFE 1.40): **15.57** (x1.6). That is 3.0x the easy line.
  The driver can't find 10 trees in a row near an arch: arches clear their approach,
  and the survey's best straight approach had 7 trees in a chain. Two tree lines
  before it were lost to wingtip scrapes.
- Hard, extrapolated: the flown hard moments with the tree run repeated to 10
  (`scratch/hard_synth10.csv`, synthetic) give **43.2**, which is **8.4x** the easy line.
- `--check` passes on every log flown.
- The drivers and logs are uncommitted, in this worktree's `scratch/`:
  `line_survey.gd`, `line_fly.gd` (`--arch= --yaw= --dir= --u= --back= --agl=
  --fast --knife --pillar= --open_share= --trace --shot=`), `easy6.csv`,
  `hard5.csv`, `hard_synth10.csv` (built by `synth.py`), and the old-formula
  flights `easy_old.csv` and `hard_old.csv`.

## Not proved

- A hand-flown 10-tree weave and knife-edge arch. The user should fly both lines
  and run the report.
- The driver flies along trees rather than weaving between them, and its
  approaches are straight.
- Money: `PilotBook.line_pay` now gets points about 1/5 to 1/10 of the old ones
  and a smaller multiplier. Pay per line is lower and hasn't been retuned.
  `LineMoves.name_for` names lines by the old multiplier (3 to 9.5), so with a cap
  of 4 the names rarely show.
- The rendered still (`scratch/badge2_1.png` in this worktree, shows "221 ×1.0 TREES ×2 / GRAZE 1.8 m +116 FAST CLOSE") checks the ring style only. The other HUD styles
  (glyph, handoff, plain) don't show the tags.

## Tests

There are no near-miss tests in `tests/`, so none break. The full suite wasn't run.
