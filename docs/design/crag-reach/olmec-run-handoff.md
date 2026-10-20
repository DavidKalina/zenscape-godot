# Handoff: the Olmec builds speed into a run (prototype round `olmec-run`)

**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
To feel the run without his pounces and sucks cutting it short, add
`--body-knob=suck_max=0 --body-knob=pounce_max=0 --body-knob=suck_in=0`.
Any knob below can be tried the same way (`--body-knob=run_up=6`).

## What changed

`scripts/enemies/headless_body.gd`, behind a new knob `run_up` (off by
default, on in `OLMEC_KNOBS` in `studies/crag_reach.gd`). olmec_field,
whole_body_chase and the Olmec boss are unchanged.

- **Speed:** in the chase he sets off at his walk (`walk`, 2.16 m/s) and
  builds to `run_top` over `run_up` s, as long as he heads within 0.3 rad of
  his way and isn't turning. `run_k` (0 to 1) holds the build.
- **What takes it off:** every radian turned faster than 0.2 rad/s costs
  `run_turn_cost` of the build. Any state other than chase (climb, mantle,
  windup, leap, swat, plant, suck, seek) drops it to 0. The build never runs
  more than 0.06 ahead of his real speed, so a wall, skirt, plant or pin that
  slows him takes it off too. With no floor where he would stop, he eases off
  before a rim.
- **Turning at speed:** his turn rate goes from his chase turn (1.62 rad/s)
  at a walk to `run_turn` at the top. He keeps running round turns up to
  1.4 rad off his way, where at a walk he plants at 0.8 rad. A plant at full
  speed brakes at half strength, so he skids on.
- **Gait from real speed:** walk, then `hunt_stride`, then the run clip
  (`run_clip`, else `shoulder_run`). They blend at 0.62–0.85 and
  1.05–1.30 head heights a second (2.1–2.9 and 3.5–4.4 m/s). The phase
  advances by distance over the blended step length (WALK_STEP, STRIDE_STEP,
  RUN_STEP), so each clip's pace matches his real speed. `gait()` returns
  the clip with most weight, for drivers.

## Knobs (default / OLMEC_KNOBS)

| knob | value | meaning |
|---|---|---|
| `run_up` | 0 / **4.0** s | time to build from his walk to his top |
| `run_top` | n.run x 1.15 = **5.52** m/s | top run (old chase 4.32, your run 4.8) |
| `run_turn_cost` | **1.0** | build lost per radian turned past 0.2 rad/s |
| `run_turn` | **0.45** rad/s | turn rate at his top |

Constants beside them: RUN_STRAIGHT 0.3, RUN_EASY 0.2, RUN_WIDE 1.4,
RUN_SKID 0.5, RUN_SLACK 0.06, RUN_EASE 0.8, GAIT_STRIDE, GAIT_RUN.

## Measured (headless, scratch/olmec_run.gd, main's crown)

Straight chase with attacks off (he starts still, you run 0.7 pace):

| t (s) | 0.75 | 1.0 | 1.5 | 2.0 | 3.0 | 3.75 | 4.5 | 4.8+ |
|---|---|---|---|---|---|---|---|---|
| m/s | 1.2 | 1.95 | 2.7 | 3.1 | 3.9 | 4.6 | 5.2 | 5.52 |
| gait | walk | walk | stride | stride | stride | run | run | run |

He reaches the old chase speed at about 3.5 s and his top at 4.8 s. On a
sidestep square off his line at 8–10 m, his speed falls from 5.5 to about
2.9 over 2 s as he swings round at 0.45 rad/s. The gap to you grows from
about 5 m to 8–9 m before he builds again. At 12.7 m he only falls to 3.4.

Foot slip: a planted foot's flat speed (the lower foot, within 0.1 m of
its lowest) is 0.28 m/s walking at 1.5 m/s, 0.23 m/s on the stride at
3.2 m/s and 0.36 m/s running at 5 m/s. The old fixed hunt stride slips
0.35 m/s at 4.0 m/s.

## How it plays with his attacks (not retuned)

- Within 15 m he pounces every 3 s (`pounce_rest`) on open ground, and
  within 30 m relentless sucks. A chase that starts close is all leaps, as
  before, and the run never builds. Same run with `run_up=0`: the same 3
  leaps, frame for frame.
- From 57 m off, with you standing, he plants to suck at 7.3 s, about when
  the old chase got there (7.1 s). He gets there in the same time, slow off
  the mark and faster at the end.
- Running into a swat or plant at full speed, he slides about 2–3 m while
  braking through it.

## Looks off / open

- **The sidestep:** he swings wide and loses speed, but he doesn't
  literally run past your line. He steers at where you are now and is
  faster than you, so he cuts inside the corner. Within 6 m his swat
  (4.4 m) fires before any overshoot shows. A truer overshoot would need
  him to keep more sideways momentum (a lower `accel` at speed), or a lead
  on his aim.
- The rendered sheets (`scratch/shots/olmec_run_*_sheet.png`) read: an
  upright hunt stride, then the shoulder-led run with a forward lean. The
  following camera made skating hard to judge by eye, so the slip figures
  above are the real check. The walk-to-stride blend happens behind dust
  at the start.
- He starts each chase leg from a walk, after every pounce, suck and landing
  too. With his attacks this frequent, players will mostly see walk and
  stride, and the run only on long approaches (he climbs up far off, or you
  break his sight).

## Proof

- Headless import; smoke PASS for crag_reach plain, crag_reach `--olmec`,
  olmec_field and whole_body_chase.
- Throwaway driver `scratch/olmec_run.gd` (uncommitted). It works through
  the real loop, with your moves through the stick. Setup puts him at the
  crown's SW corner. Flags: `--pace=`, `--side-d=` (sidestep when he's this
  near), `--stand`, `--film` (rendered sheets), `--cam-side/up/d`. It
  prints rows of speed, build, gait and clip, plus SLIP lines.
- No committed tests, full suite not run. No test refers to the body's
  chase. The knob is off by default, and `_brake` only gained an optional
  argument, so no existing test should break.

## Harness gaps

- A film view that holds a fixed world camera beside a moving enemy (a
  dolly alongside, not following) would make foot skating readable by eye.
  `follow` either tracks or turns.
- A foot-slip probe (the planted foot's flat speed per clip) would be a
  useful drive.gd helper. This round's is in the scratch driver.
