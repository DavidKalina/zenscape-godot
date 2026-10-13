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

## Round 3: ride it, don't step on it

> "Too easy still. I was able to jump from point A to point B without even getting a scratch."

The diagnosis, which the user agreed with ("Yeah, maybe they're too close
together. I like that."): every hop was makable at any moment, so he could
chain running jumps from A to B and spend under a second on each block.
Round 2's aggression only punished lingering, and nothing made him linger.

### What changed: the ferries

The blocks are now spread out (63.8 m of route, was 31.5), and each one
slides along the route: the **ferry**. It slides back toward the entry and
on toward the exit, holds at each end, and lunges into the ends. It is
quickest arriving and stops dead with a "dock" sound and a puff of dust.
Every block runs on one shared **beat** (9.7 s), and neighbours slide
against each other. A hop opens only when the block he is on is held **on**
and the next one is held **back**. Their ends then overlap along the route
by `meet` and are `gap` apart across x. Half a beat later the next hop
opens. So he lands at a block's back end, rides it forward through its
lurch, and goes from its front end. Outside the window the hop is a long
diagonal across the void, past his jump.

- Neighbours stay apart across x, and a cube turning about x never swings
  out along x. So they slide past each other's ends without ever touching.
  Blocks on the same side slide together and stay a body or more apart.
  `clear_of` counts the ferries.
- Jumping or stepping off a ferry, he keeps its slide's velocity. Landing
  on one, that velocity becomes the ground's again (`ferry_velocity`, in
  `trap_tumble.gd`'s `before`). Without this he hung in the air over a
  sliding block and came down a metre off; with it, a jump made late, as
  the ferry lunges away, carries him off backward.
- His reach is no longer a formula. `Run.leap(kind, dy)` steps the real
  motor (`pilot()`) off an edge at a run: a small hop, a hop caught by the
  lip, the pump (the higher chained jump) caught by the lip, and the pump
  with a twirl pressed at its best moment and caught. The plan and the
  test both use it.

### Layout

In the pilot's units (`BLOCKS`). Metres are for the wanderer at size 1.0.
The beat is `BEAT` (3.2) of the single cube's walk-across times. "Open" is a
running small hop's reach (85% of it) both as he leaves and as he lands, an
airtime later. "His jump" is the pump caught by the lip.

| hop | at its window | held shut | rise | open each beat | within his jump | with a twirl | what makes the window |
|---|---|---|---|---|---|---|---|
| A to 1 | 0.86 m straight on | 8.0 m | +0.36 m | 1.1 to 1.7 s | 29% of the beat | 78% | 1 docks back against the start deck (its ferry is the longest, 3.6 m each way) |
| 1 to 2 | 0.91 m across | 12.0 m | 0.0 | 1.6 s | 28% | 60% | 1 docks on, 2 docks back; they meet over a 1.0 m strip at 1's front end |
| 2 to 3 | 0.84 m across | 11.0 m | +1.36 m, a climb (catch the lip) | 1.7 to 2.0 s | 28% | 55% | 2 on, 3 back; a narrower strip (0.6 of his height) |
| 3 to 4 | 1.30 m across | 10.7 m | -0.80 m | 1.1 to 1.6 s | 21% | 60% | 3 on, 4 back; 4 holds its ends a little shorter (`hold` 0.1) and turns the other way |
| 4 to 5 | 0.88 m across | 11.6 m | +0.24 m | 1.4 to 1.5 s | 31% | 63% | 4 on, 5 back |
| 5 to B | 1.42 m straight on | 8.1 m | -1.16 m | 1.2 s | 24% | 100% | 5 docks on against the far deck |

The next hop opens at least 3.1 s after the last one shuts. Each window
recurs once a beat at the same place in it.

What each block asks between its windows: land at its back end as it docks
back, wake it, ride its lurch while it carries you forward, and get to its
front end, by the edge facing the next block, before it docks on.

- 1 (the waker) and 5 (the finale) lurch about once per ride.
- 2 (the jitter) lurches about every 3 s and feints, so you usually ride two.
- 3 (the slammer) double-lurches, and you climb onto it.
- 4 tips its front end down because it turns the other way. Ride its lurch
  at its back (uphill), then run down to the front for the window.

A perfect run is about 6 half-beats (about 30 s). The scripted rider who
waits made A to B in 45.8 s, missing a window on 4 and on 5.

New knobs on `trap_tumble.gd` (all off by default, so the single `tumble`
lane is unchanged):

- `shuttle`, the ferry's travel each way (m)
- `shuttle_time`, its cycle (s)
- `shuttle_hold`, the share of the cycle it holds at each end
- `shuttle_phase`, in cycles
- `shuttle_ease`: 1 eases in and out of its ends, -1 lunges into them

New reads:

- `shuttle_wave()`
- `docked()`
- `top_span()`, the top face's extent and its heights along the route as it lies
- `ferry_velocity`

On `trap_tumble_run.gd`:

- Row fields: `gap` (now the hop at its window: from the deck along the
  route, otherwise across x), `meet`, `ferry` and `hold`.
- Constants: `BEAT`, `FIRST`, `HOLD`, `LUNGE`.
- Functions: `leap()`, `open_reach()`, `beat()`, and `hop_now(i)`, which
  gives the gap and rise of hop `i` as the blocks lie.
- Plan rows now carry `shut` and the three reaches.

### Not done: the route through a face

No face feature (step, lip, pocket) was made the way on. The neighbours sit
across x and a block turns about x, so no face ever turns toward a
neighbour. The ride from back end to front end through a lurch is the
route through the block. A face-feature route would need neighbours laid
along the route, with their corner swings kept clear.

### Verified

`tests/test_tumble_run.gd` (headless, the real yard loop, input actions;
now `## suite: slow`, about 1:40). In its last full run:

- The plan: every hop at its window is within 85% of a running small hop
  (the climb within a lip he catches). Held shut, every hop is past his jump
  (the pump caught by the lip) by more than 15%. No two blocks meet, the
  ferries counted.
- The windows, with the blocks stepped through two beats: every hop opens
  once a beat for 0.8 to 2 s, at the same place in each beat. Every hop is
  past his jump at least half of every beat (21 to 31% within it). No two
  hops in a row are open at once.
- A rider who chains running jumps from A without waiting gets on block 1
  and falls into the void going for 2 (2.7 s).
- A rider who waits for each window (keeping his block's station, riding
  its lurches with a hop and a pump high up the slope, going to the front
  edge and leaping when the hop opens) made A, 1, 2, 3, 4, 5, B in 45.8 s.
  He rode each block 2.9 to 10.5 s and jumped 11 lurches.
- Each block carries him alone. A rider who just stands there is put off
  every block sooner than the same block calmed (ferry off too). A fall
  resets the run.
- Import and a headless `--trap=tumble_run` yard load (`--quit-after 300`)
  are clean apart from the engine's usual exit notices.
  `tests/test_trap_giants.gd` passes (the single cube unchanged), and so
  does `tests/test_world_scale_guard.gd`.

### Unverified

- **The twirl, the long jump and the sail still outreach the shut gaps.**
  The stepped motor gives these reaches on the flat:

  | move | lands at | caught by the lip at |
  |---|---|---|
  | running small hop | 2.2 m | 3.1 m |
  | pump | 3.0 m | 3.8 m |
  | small hop + twirl | 5.2 m | 6.4 m |
  | pump + twirl | 6.2 m | 7.2 m |
  | long jump | 3.9 m | |
  | long jump + twirl | 7.1 m | 8.5 m |

  The pocket sail glides about 3.7:1.
  - The middle hops beat the twirl only around their widest: a twirling
    player can make them 55 to 63% of each beat.
  - The deck hops (A to 1, 5 to B) are twirlable nearly always, because the
    decks don't move.
  - The long jump and the sail are not counted at all.

  So a player who twirls everywhere can still hurry through, though not
  chain freely: the next hop still opens half a beat later. Holding the
  run against these moves is the user's call. Options: ferries about twice
  as long (5 m or more each way), or the run folding the twirl and sail
  while he is on it.
- **Feel and look were never seen** (headless):
  - whether the dock (the stop, the sound, the dust) and the slide read as
    the window's tell;
  - whether 1 to 2 s windows feel fair;
  - whether 3 to 3.6 m ferries look like stone blocks or like moving
    platforms.
- **Ferry velocity is new physics.** He keeps the ferry's velocity
  leaving it and loses it landing. A late jump as the ferry lunges away
  flings him backward, which is meant as the window closing but was never
  played.
- **The test rider's timing varies.** The yard runs on real headless frame
  times, so the rider gets up to three tries from A and the best counts.
  - While developing, about 2 of 3 single tries reached B. The others got
    to block 3 and fell going for 4, after the slammer's double lurch put
    him off the strip.
  - The rider is a bot: it rides each lurch with a hop and then a pump at
    the ridge. A human may find another way (the pocket), or have a harder
    time.
- The window numbers use the gap at takeoff and at landing. A human's
  real window is shorter than the 1.1 to 2.0 s measured.
- Whole suite not run.
