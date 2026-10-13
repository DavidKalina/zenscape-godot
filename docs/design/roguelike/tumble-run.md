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

## Round 2: alive and aggressive

> "Not too bad. Felt a little too easy though. Like they didn't feel alive or aggressive enough."

### What changed

Every block is now meaner than the single cube: a steeper tip (still under the
throw angle), a quicker lurch, a harder throw, a faster ramp. Each one also has
its own personality, and the run builds from A to B:

| # | personality | what it does |
|---|---|---|
| 1 | the waker | breathes (bobs a quarter of a small jump), wakes when he lands: a startled shudder, "wake", and its rest is cut to 1.5 tells, so it tips soon after |
| 2 | the jitter | tempo 1.6, startles awake (1 tell), a fake-out shudder mid-rest (0.6 tells, no tip), a nervous 4 degree yaw sway |
| 3 | the slammer | big and heavy (tempo 0.85), steepest tip (0.75 of the way to SLIDE_AUTO), lurch 1.6x quicker, a DOUBLE lurch (after the slam it rests `chain_rest`, tips over one tell, all shudder, and goes again), the slam drops it half a small jump and it heaves back, throw 1.4, jolt 0.6, twice the shake |
| 4 | the drifter | turns the other way, drifts 0.35 of his height along its axis so both its gaps open and close, wakes on landing |
| 5 | the finale | tempo 1.3, wakes, feints, bobs, ramps 3x to x2.0, throw 1.3 |

The tells are louder: the faces glow (`glow`) as well as warm, the slammer's
slam throws dust, and the wake and the feint have their own shudder. The tip is
still the honest read: a feint never tips, and every lurch comes out of a tip
whose last `tell` seconds shudder (a chained lurch's whole tip is shudder).

The gaps are authored at their WORST now: a row's `gap` is the hop at the
motion's widest and the rise at its highest (the source at its low, the target
at its high), and `plan()` lays the middles closer by what the blocks move. So
a moving gap is never past its share of his reach, and `narrow` (its closest)
is checked to stay open. `clear_of` counts the motion too. Block 3 and block 5
sit a little further on (`ahead` 5.3, 5.5) for the bob and dip; the route is
31.5 m.

### New knobs

On `trap_tumble.gd`, all off by default (the single `tumble` lane is
unchanged; `tests/test_trap_giants.gd` passes as before):
`wake` (s), `wake_off` (s off it before he can wake it again; a hop doesn't),
`feint` (s), `double` (chained quarter turns), `chain_rest` (s), `dip` (m),
`bob`/`bob_time`, `drift`/`drift_time` (along x), `sway`/`sway_time` (yaw
wobble, rad), `motion_phase` (cycles), `glow` (0 to 1). New reads: `middle()`
(the moving centre), `motion()`, `sway_now()`, `rest_len()`, `tip_len()`,
`feinting()`, counters `wakes`, `feints`. The carry includes the motion and the
sway's turn.

Per row of `BLOCKS` in `trap_tumble_run.gd`, in the pilot's units: `steep`
(the tip, a share from SLOPE_SLOW to SLIDE_AUTO), `snap` (lurch speed x),
`ramp` (x), `wake` and `feint` (in tells), `double`, `dip` and `bob` (in small
jumps), `drift` (his heights), `sway` (degrees), `shudder` (shake x). The
plan rows carry `wide`, `narrow`, `dy_worst`, `move`; the plan carries
`exit_wide`, `exit_dy_worst`.

### Verified

`tests/test_tumble_run.gd` (headless, the real yard loop and input actions),
passing three runs in a row:

- The layout at the motion's worst: every widest gap within 75% of a running
  small hop's reach at the highest rise (the test's limit is 85%), every
  narrowest still open (over 0.2 m), the climb onto 3 within a lip a jump
  catches, the exit too; gaps or heights move under all five hops; no two
  blocks meet, the motion counted.
- Every block is meaner than the single cube (tip, lurch, throw, ramp), and the
  run has all seven traits.
- The rider hops A to 1, is carried, then hops 1 to 2 timing it the way a
  player would: he keeps block 1's station, jumps its lurch (it woke as he
  landed and lurched under him), and goes when his own lurch is far enough off
  and he'll land on 2 clear of 2's lurch. Block 2 carries him (jumping its
  lurch if it comes). Each block counts only its own time.
- Each block, set on it as it tips, carries him alone.
- A rider who just stands there is put off every block sooner than the same
  block calmed (round-1 knobs), and is thrown or jolted, not just slid, by 4 of
  5. One run: 1: 3.8 s (calm 4.7), 2: 2.5 (3.1), 3: 6.2 (15.1),
  4: 3.9 (5.1), 5: 3.3 (4.3). Each waking block woke and said "wake".
- A fall resets the run. Import and a headless `--trap=tumble_run` yard load
  (`--quit-after 300`) are clean. `tests/test_trap_giants.gd` passes (the
  single cube unchanged).

### Unverified

- Feel. Whether it now reads as alive and aggressive, or as too much, is for
  play. The scripted rider needed real timing to cross 1 to 2, which is a hint
  the run is genuinely harder. Block 2's quick rhythm leaves about 1.8 s of
  every 2.9 s safe to land in.
- The look: the glow, sway, bob and the slammer's dip and dust were never seen
  (headless). The shake on the slammer (2x) may be too much.
- Whether the feint feels fair or cheap. It never tips, but a player who
  reads only the shudder will jump early.
- The hops 2 to 3 (the climb, now onto a block that double-lurches), 3 to 4 and
  4 to 5 (gaps that open and close), and the exit were not scripted. They are
  held to the worst-case layout arithmetic only. A full A-to-B run was not
  scripted.
- The slammer's double lurch and the drifter's carry under drift were never
  exercised by a rider beyond the carry-each and stander checks.
- Whole suite not run.
