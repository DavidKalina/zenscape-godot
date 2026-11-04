# Bore pace: his lead held as a time (handoff)

Branch `iter/bore-pace`. From play: "the burrower doesn't adjust to the speed. It's too
easy to be too far behind, or ahead of his attacks." The fix picked was option A.

## What changed

Only the burrower's pace in the bore changed, in `scripts/endless/burrower_bore.gd` `_pace`.

- **Before:** he aimed at a distance lead of 90-150 m, at a fixed `PACE` of 54 m/s, with
  weak pulls past either end (`CROWD_GAIN`, `WAIT_GAIN`), `ACCEL` 35 and a cap of 95 m/s.
  A plane flying slower than 54 fell 4-12 s behind his attacks. One flying fast closed on
  him.
- **Now:** he aims at `LEAD_S` (2.2 s) of the plane's along-bore flight at its speed now,
  never under `LEAD_LEAST` (60 m). He matches the plane's along-bore speed (eased over
  `ALONG_EASE`, 0.15 s), plus its change (the lead grows with speed), plus `LEAD_GAIN`
  (2.5 m/s per m off). That's within `ACCEL` (150 m/s/s) and between `PACE_LEAST` (15) and
  `PACE_MOST` (140).
- A spur or plug fires when he passes its spot, so it now meets the plane about 2.2 s after
  it fires, whatever the speed. The attacks themselves weren't touched.
- The rumble's gain and pitch keep their old ranges (`RUMBLE_NEAR` 90 m, `RUMBLE_PACE`
  20-95 m/s), so it sounds as before.
- **Tells at 2.2 s:** a spur is fully out (`HOLD_S` 0.8 + `SNAP_S` 0.16) about 1.25 s
  before the plane reaches it. A plug is down (`HOLD_S` 1.1 + `DROP_S` 0.42) about 0.7 s
  before. Both are at or above what a boost run got on main (median fire-to-pass 2.4-2.6 s,
  minimum 1.9). Unchanged.
- **End conditions** (`_gone`) are unchanged. "out", "down" (crashes) and the start
  transient were all seen in the runs. One behaviour change: "lost" by falling behind now
  needs the plane under 15 m/s along the bore. A braked crawl (15-20 m/s) used to end
  "lost". Now he waits 60 m ahead of it. Leaving the bore still ends it "lost" after
  `OUT_S`.
- No longer true from the spec: "a scrape costs the plane speed and he stretches away by
  that alone". He slows with the scraped plane now.

## The numbers

Real input path (`scratch/pace.gd`, stick, Boost and Brake actions). Each run starts in the
bore at mouth A with him 110 m ahead and flies the whole tunnel: `1_1` (2000 m) and `-1_1`.
The styles:

- **boost:** Boost held.
- **slow:** cruise, nothing held.
- **crawl:** Brake at 0.7.
- **vary:** Boost 2.5 s, then Brake 2.5 s, over and over.
- **dive:** in at 100 m/s, swinging crown to floor between spurs, Boost held.

Gap is lead / plane along-bore speed. Fire to pass is the real seconds from a spur or plug
firing to the plane passing it.

| style | tunnel | speed p10/50/90 | gap s p10 / median / p90, before | after | fire to pass s min / median / max, before | after | m off at fire, before | after |
|---|---|---|---|---|---|---|---|---|
| boost | 1_1 | 46/52/55 | 2.15 / 2.51 / 3.16 | 2.09 / 2.19 / 2.32 | 1.95 / 2.43 / 3.37 | 2.00 / 2.18 / 2.48 | 104-156 | 104-122 |
| boost | -1_1 | 46/53/55 | 1.93 / 2.64 / 3.12 | 2.12 / 2.19 / 2.32 | 1.87 / 2.57 / 3.43 | 2.00 / 2.25 / 2.52 | 101-152 | 97-121 |
| slow | 1_1 | 30/34/36 | 4.24 / 4.46 / 5.09 | 2.15 / 2.20 / 2.31 | 2.92 / 4.48 / 5.07 | 1.83 / 2.25 / 2.57 | 112-153 | 65-91 |
| slow | -1_1 | 29/33/36 | 4.26 / 4.52 / 5.24 | 2.14 / 2.20 / 2.34 | 2.80 / 4.65 / 5.87 | 2.05 / 2.27 / 3.35 | 112-160 | 63-89 |
| crawl | 1_1 | 15/18/20 | 8.82 / 11.79 / 15.03 | 2.99 / 3.27 / 4.36 | 4.97 / 10.92 / 14.97 | 2.82 / 3.42 / 4.62 | 117-282 | 59-71 |
| crawl | -1_1 | 15/19/20 | 7.97 / 11.83 / 17.49 | 2.99 / 3.25 / 3.97 | 4.82 / 10.38 / 14.62 | 2.95 / 3.45 / 4.53 | 117-293 | 59-71 |
| vary | 1_1 | 18/32/47 | 3.19 / 4.84 / 8.57 | 2.11 / 2.69 / 4.75 | 2.02 / 4.72 / 5.42 | 1.48 / 2.27 / 3.90 | 104-160 | 63-119 |
| vary | -1_1 | 18/32/46 | 3.31 / 4.82 / 8.49 | 2.10 / 2.71 / 4.59 | 1.90 / 4.95 / 6.08 | 1.68 / 2.97 / 4.27 | 102-169 | 73-121 |
| dive | 1_1 | 46/52/55 | 1.86 / 2.24 / 3.20 | 2.10 / 2.19 / 2.33 | 1.68 / 2.18 / 3.55 | 2.00 / 2.20 / 2.72 | 91-157 | 105-129 |
| dive | -1_1 | 45/52/55 | 1.63 / 2.61 / 3.21 | 2.09 / 2.19 / 2.34 | 1.60 / 2.55 / 3.45 | 2.00 / 2.27 / 2.58 | 87-151 | 92-128 |

How to read it:

- **Above 35 m/s** the gap stays within 1.8-3.1 s after the change (1.5-4.7 s before). The
  highs are brief, after a scrape cuts the plane's speed.
- **Crawl** sits at the 60 m floor by design: 60 m at 18 m/s is 3.3 s.
- **Vary** after the change still has a 1.5 s worst case. A spur fires while the plane is
  slow, then the plane boosts into it. No pace fixes that: the gap is set when it fires.
- **Dive** no longer lets the plane under his lead. The minimum gap was 1.52 s before and is
  1.83 s now.
- **Ends:** every run, before and after, ended "out" at the far mouth, except crawl.
  Crawl ended "lost" before. After, it ended "out" in -1_1 and hit the run's 100 s limit in
  1_1.
- **Crashes:** 0 in every run (the pilot uses a 4.5 m wingtip clearance; at 2 m it hit a
  pair in -1_1, before and after alike).

## Knobs to tune by feel

All in `scripts/endless/burrower_bore.gd`:

- `LEAD_S` 2.2: the warning time. 2.0 is tighter, and leaves a plug down only 0.5 s ahead.
- `LEAD_LEAST` 60: how close he comes to a slow plane.
- `PACE_LEAST` 15: raise it to about 22 to make a braking plane lose him again (ends "lost").
- `LEAD_GAIN` 2.5 and `ACCEL` 150: how stiffly he holds the gap.
- `ALONG_EASE` 0.15: how much of the plane's speed jitter he follows.
- `PACE_MOST` 140: his cap.

## Fly it

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-ac15187768a01deb1 && python3 tools/play.py --no-pull -- --pilot-file=/tmp/bore-pace-pilot.json
```

## Checks

- Smoke of `studies/endless_flight.tscn`: PASS, 400 frames, 0 errors.
- The sweep above (`python3 tools/sweep.py scratch/pace.gd --arg style=boost,slow,crawl,vary,dive --arg tunnel=1_1,-1_1`):
  10 of 10 runs clean, 0 script errors.
- The before numbers come from main's `burrower_bore.gd`, swapped in for the same driver.
- No test in `tests/` names the bore or its constants, so none is known broken. The full
  suite wasn't run.

## Unverified

- **The chase's real start.** The burrower plunges, the plane follows him in from outside,
  and "left" (not following him in). The driver starts inside the bore. He now waits for an
  approaching plane at 2.2 s of its speed, as before, but this wasn't flown.
- **Surges.** A surge (about 75 m/s) wasn't driven. He keeps the gap through it, so a surge
  no longer closes on him.
- **Whether the cracks read.** At 2.2 s they light 105-125 m ahead at boost speed, against
  the spec's 60-85 m. No rendered stills this round.
- **Other tunnels:** `1_-1` and `-2_1` weren't flown.
