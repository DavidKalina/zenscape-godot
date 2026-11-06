# Handoff: wild-kit elk, lane elk-mind

The herd's behaviour (the ground escort kind) on its stand-in body, built in
lane `wk-elk-mind` of loop `wild-kit` to `spec-wild-kit-elk.md`. Branch
`lane/wk-elk-mind`; the trail is `git log --grep='lane elk-mind'`. The real
elk (lane elk-body) is built to the same contract and merged elsewhere.

## Fly it

```
cd /Users/davidkalina/Documents/Projects/zenscape-wk-elk-mind && python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/wild-kit-pilot.json --at=60,145 --heading=90 --alt=40
```

You start 600 m west of the herd at `wild/meadow_herd` (660, 145), flying
east down the meadow, 40 m up. The herd grazes near the meadow's south
treeline. Ways to fly it:

- **High or slow** (over 24 m, or under about 24 m/s): the near ones lift
  their heads and track you, then graze again.
- **Low and fast beside them** (under 24 m, cruise, 20-40 m north of them):
  they sprint alongside at your speed (up to cruise; Boost pulls away),
  now and then one leaps, then they peel off, halt and look back.
- **Low and fast straight through them**: they bolt and scatter both ways
  off your line, then break for the wood's edge, halt and look back.
- **Afterwards**: fly 300 m or more off and wait. They trot home to their
  spots and graze. If you fly past 900 m they are put back on their spots
  unseen.

`--elk=off` puts the site's marker post back.

## What's built

- `scripts/endless/kinds/ground_escort.gd`: the mind. Its knobs are in
  `KNOBS` at the top. The states are `graze`, `alert`, `settle`, `bolt`,
  `run`, `leap`, `peel`, `scatter`, `cover`, `halt` and `home`. The layout
  is seeded from the handle, so the same herd stands on every machine (8
  elk, 2 bulls). It reads the plane from the study (`study.plane`), the
  land from `field` and the trees from `study.trees`, and calls only the
  contract's API on its bodies.
- `scripts/endless/kinds/escort_standin.gd`: the stand-in body. It is built
  from primitives in the elk's size and has the seven sockets. Each clip is
  a set of procedural key poses timed to the contract's beats, with
  two-bone IK legs. It has the dust puffs and the bull/cow variants.
- One line in `scripts/endless/kinds/kinds.gd` and the herd's row in
  `scripts/endless/world/wilderness/placed.gd` (see Merge).

## Cost (work done, from driven passes)

These counts come from `w_*` counters in `ground_escort.gd`, which are
zeroed each frame (land heights, river asks, tree `top_at`, tree plan cells,
pair distances, bodies placed, and per-frame calls on a body). The
drivers were home.gd and home_beside.gd with a frame-count tally added
(`scratch/elk/cost.gd`, `cost_beside.gd`). Each run was one pass, the drift
home, a second pass, then the plane past the sleep distance and back. The
figures are mean per frame / most in one frame, for a herd of 8.

| Phase | Heights | River | top_at | Pairs | Placed | Body calls |
|---|---|---|---|---|---|---|
| Asleep (plane past 900 m) | 0 | 0 | 0 | 0 | 0 (8 once, the snap home) | 0 |
| Calm (all grazing) | 0.1 / 1 | 0 | 0 | 0 | 0 | 0 |
| Watching (heads up, none moving) | 1.0 / 2 | 0 | 0 | 0 | 0 | 3.9 / 7 |
| Run beside | 13.1 / 39 | 1.6 / 10 | 10.4 / 67 | 26.8 / 28 | 7.4 / 8 | 14.0 / 16 |
| Straight through (scatter, to the trees) | 12.3 / 486 | 1.6 / 121 | 6.6 / 327 | 23.6 / 28 | 5.2 / 8 | 11.8 / 16 |
| Drift home | 7-11 / 12 | 1 / 1 | 2 / 2 | 19-27 / 28 | 4-7 / 8 | 7-14 / 16 |

- While a body is awake, it poses one clip each frame: about 20 keyed
  channels, 4 two-bone IK solves and about 14 node transforms. Asleep, its
  `process_mode` is off and it costs nothing. The whole herd is 297 nodes.
- **Fixed this round:** the turn for the trees used to happen all in one
  frame: the wood's-edge sweep (24 ways) plus every animal's goal search.
  Its worst frame did 2412 heights, 608 river asks and 1786 `top_at`. Now
  the herd does one cover search a frame: either a slice of the sweep
  (`cover_slice`, 6 ways) or one animal's goal, and the rest scatter on for
  a frame. The worst frame is now 486 / 121 / 327.
- **In the frame log:** the herd runs in its own `_process`, outside the
  study's tick, so it logs through `FrameLog.add`, not a `mark`. Its
  columns are `herd` (the mind) and `herd_bodies` (the stand-in's posing),
  and `tools/frame_report.py` lists them with the other parts. On a driven
  headless run on this Mac, `herd` averaged 0.06-0.09 ms with a worst of
  3.6 ms (11.3 ms before the fix), and `herd_bodies` averaged 0.12 ms with
  a worst of 0.7 ms. Treat those times as noise; the counts above are the
  measure.
- The worst frame left is one animal's goal search when every ranked way
  fails (up to 24 ways of up to about 60 `top_at`). It comes up when a pass
  meets the herd strung along the wood's edge.

## How a run beside could join the line score

The run beside scores nothing yet. The surge smash already queues a move,
and the run beside could do the same: `game.near.moves.smash(game, what,
at, id)` in `scripts/endless/line_moves.gd`, called from
`scripts/endless/surge_smash.gd`.

1. A new held move, `herd run`, in `LineMoves`. It would get a `BASE` and
   `HELD_MIN` entry (about 2 s), its base in `line_tune.json` (`base`), and
   a glyph in `near_glyphs.gd`. A method `herd_run(game, held, least, at,
   id)` builds the move with `_held_move("herd run", held, HELD_MIN, k,
   least, at, "land", pace)` and passes it to `_finish`, the way `smash`
   does.
2. The herd calls it when its run ends (the last runner peels), through
   `_study.near.moves`, guarded by `has_method`. The arguments:
   - `held`: the seconds a runner held its station beside the plane. The
     herd already adds these up per pass (`stats.beside_s` counts runner
     seconds; this wants the herd's own seconds).
   - `least`: the closest a runner came to the plane's line.
   - `k`: 1 minus `least` over `side_max`, so a closer run scores more.
   - `at`: the herd's middle.
   - `id`: a hash of the handle, so `farm_same` cuts a second run with the
     same herd.
   LineScore then adds Fast (the plane's speed) and Low (its height). A
   leap seen beside could add a small bonus.
3. While the herd runs, the herd sets `LineMoves.holding`, so the chain
   doesn't bank during a long run beside.

The straight pass (the scatter) is better left unscored. It costs the
player nothing, and scoring it would reward flying through the herd.

## Known issues and open questions

- **Met in the wood's edge:** 1-2 of eight sometimes stay "tucked" (no way
  out holds, so they stand alert in the wood), and one sometimes finds no
  cover and peels in the open. It tries the trees again once the plane has
  passed.
- **Three straight passes in a row** (driver straight.gd) once failed its
  "scatter both ways" check on the second pass. The first pass had split
  the herd, 6 in the south wood and 2 in the north. The driver aims its
  line at the herd's middle, which ran 20 m north of the six, so all six
  were on one side. From a fresh herd, the same pass scatters 3 and 5. The
  behaviour is right; the driver's aim is off.
- **The drift home is a trot.** The contract has no walk clip; a walk
  would be a spec change.
- **Not saved:** a herd that wakes again starts calm on its spots.
- **For the merge** ("After both lanes" in the spec), the loop still has
  to:
  - swap the real body in through `BODIES` in `ground_escort.gd`. That is
    one line, `"elk": "res://scripts/endless/world/wilderness/elk_body.gd"`.
    No flag keeps the stand-in yet; `STANDIN` is the fallback for an
    unknown skin.
  - plant the feet on the real ground.
  - point the real head's look-at.
  - retune `KNOBS` to the real clips' feel. Today's timings are the
    stand-in's.

## Stills

All are in `scratch/elk/shots/` in this worktree (git-ignored), reshot this
round:

- High or slow: `senses_high.png`, `senses_slow_near.png`.
- Beside: `beside_beside_chase.png` (the game's camera, the herd
  sprinting beside), `beside_beside_leap_side.png`, `beside_beside_sprint.png`,
  `beside_beside_lookback.png`.
- Straight: `straight_straight_chase.png` (scattered both sides of the
  line), `straight_straight_treeline.png`, `straight_straight_lookback.png`
  (close, from 5 m up on the meadow side: a cow halted in the wood's edge
  grass, looking back over her shoulder).
- Drift home: `home_drift_trot.png`, `home_drift_back.png`.
- The stand-in's clips: `clips_sheet.png`.

The drivers that made them are in `scratch/elk/` (git-ignored, this
worktree only). Each pass has its own: `senses.gd` (high or slow),
`beside.gd`, `straight.gd`, `home.gd` and `home_beside.gd` (the drift
home), and `cost.gd` / `cost_beside.gd` (the counts above). Each runs as
`python3 tools/drive.py scratch/elk/<driver>.gd -- --scene-args --at=60,145
--heading=90 --alt=40`; add `--rendered ... --shots --no-title` for stills.
Run them one at a time: two run together have timed out.

## Merge

Lines in files this lane didn't create:

- `scripts/endless/kinds/kinds.gd`: one line in `KINDS` after `marker`:
  `"ground_escort": preload("res://scripts/endless/kinds/ground_escort.gd"),`
- `scripts/endless/world/wilderness/placed.gd`: the `wild/meadow_herd`
  row's kind and skin (`"marker",""` to `"ground_escort","elk"`) and the
  last line of its comment.
