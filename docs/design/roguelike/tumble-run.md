# The Tumble Run

> "Can we also extend the scene with the tumbling block? I want a few of them arranged in a line. Not a perfectly straight line. But like a platforming section, where they are spaced horizontally and vertically from one another in an arrangement from point A to B."

A new trap-yard lane, `tumble_run` (the single `tumble` lane is unchanged): five
Tumbling Blocks (`scripts/traps/trap_tumble.gd`, one instance each, set only by
its knobs, nothing forked) over open void between the start deck (A) and the
far deck (B). `scripts/traps/trap_tumble_run.gd` is the composite trap: it lays
the blocks from a data list, steps them, and is stepped by the field once.

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=tumble_run

## Layout

The route is the data list `BLOCKS` in the trap script, in the pilot's units
(his heights, small jumps, a share of a running small hop's reach); `plan()`
turns it into metres from `Trap.pilot()`. Measured at the wanderer's size
(height 1.12 m, small jump 0.8 m, running reach 1.9 to 2.4 m):

| # | side (from last) | size | rise over last top | hop in (gap) | rhythm delay | notes |
|---|---|---|---|---|---|---|
| 1 | left of the axis, hopped to from A | 6.0 h | +0.40 m | 0.94 m, 50% of a run hop | 1.0 rests | |
| 2 | right | 5.2 h | 0.00 m | 0.87 m, 40% (easy) | 3.0 | quicker (tempo 1.2), no prize |
| 3 | left | 7.0 h | +1.36 m (a climb: jump for the lip and hang) | 0.42 m | 2.6 | the big one, holds the prize |
| 4 | right | 5.6 h | -0.80 m (a drop) | 2.05 m, 80% (wants the run) | 5.4 | turns the other way (`dir` -1), slower (0.9) |
| 5 | left | 6.4 h | +0.32 m | 1.36 m, 70% | 6.4 | quicker (1.1) |
| B | far deck | | -1.28 m (a drop) | 1.52 m, 55% | | |

About 30.6 m of route, 9 m across x, 1.4 m up and down. Each hop is sideways and
on: the neighbour lies off to one side with its x range apart from the last, so
the gap is across x and the cubes' swinging corners can't meet; the block after
it is a body-length further on (a cube swings 0.707 of its side from its middle).
`clear_of()` checks it. The rider walks to the far side of his block, level
with the strip the two share in z (about 1.2 m wide), runs at the next and jumps
at the edge.

## Knobs

- Per entry of `BLOCKS`: `size`, `side`, `x` (first only), `ahead`, `gap`,
  `rise`, `phase`, `tempo`, `prize`, and `knobs` (any Tumbling Block knob, e.g.
  `dir`, `yaw`, `ramp_top`, `pocket`). A rest and tip are scaled to the block's
  size (the single cube's, per metre of side) and divided by `tempo`.
- `phase` is a delay in rests before the block's first tip: a wave from block to
  block so they don't lurch together. Reset (a fall, R) re-applies it.
- The trap knob `blocks` replaces the whole list (`--knob` can't set a list; a
  generator would `configure({"blocks": [...]})`).
- Constants: `HOP_UP` (a rise over this share of a small jump is a climb),
  `EXIT_GAP`.

## Riding with several blocks

Each block's `riding()` is about that block's own outside, so only the one he
stands on (or hangs from) carries him, counts his time, throws or slides him; he
lands on the next and it carries him from then. `riding_block()` names it. The
field needed no change: it steps the composite, which steps its blocks (and sets
their `motor`). Their sounds are relayed to the composite's `sounded`/`heard`.

## Verified

`tests/test_tumble_run.gd` (headless, real yard loop with input actions):

- Layout: five blocks, every gap within 80% of a running small hop's reach at
  its rise, hops up at most 75% of a small jump, the climb under the lip a jump
  catches, no two blocks swinging into each other, first/last over the decks'
  width, the route length matches the yard's far deck, sizes/rhythm delays differ,
  one block turns the other way, each laid where the plan puts it.
- A scripted rider hops from the start deck onto block 1, stands carried by
  it, hops block 1 to block 2 (stepping up over the sweeper's bar on the way) and
  is carried by 2 as it tips; each of the five blocks, set under him as it tips,
  carries him alone and no other counts him.
- A fall into the void puts him back at the start deck with the blocks as built.
- `tests/test_trap_giants.gd` (the single cube) was run alongside.

## Unverified

- The hops 3 to 5, the climb up to block 3 (a lip hang and climb on a block
  that may be tipping), and a full A-to-B run were not scripted; they are held
  to the layout arithmetic only.
- Feel and timing: how the delay wave sits for a human pace, whether the
  1.2 m shared strip makes the sideways hops too fiddly (widen `ahead` apart or
  shrink sizes to ease), the look (interpenetration of the corners at the
  closest approach was checked by the clearance rule, not by eye).
- Whole suite not run.
