# The Peak's strike: handoff

Round two of 2026-10-31 on `claude/mountain-peak-visual-polish-d83e07`, not pushed, after the user flew round one ("way
too swirly"). Lightly proved on purpose; the user judges it by flying it. Frames are in the git-ignored
`scratch/strike/shots/`, drivers in `scratch/strike/` (`film2.gd`, `head.gd`, `play.gd`, `runs2.py`).

## What it does now

While you climb, a spire picks the route down the mountain on your side and grows down it at you.

1. **Tell** (1-1.2 s): the spiral's tip draws in and a point pushes 150 m out of the spire down the route it picked. No
   coil, no spin-up. `rouse` now only draws the tip in.
2. **Run:** one body lengthening, head first, 270-330 m/s, about 1100 m/s² off the mark, laid along the route behind it.
   It comes off the ribbon where the ribbon passes nearest the route's start. On a stretch shared with another route it
   changes fork if the other comes 70 m nearer the plane.
3. **Lunge:** within 340 m of a plane still by the route it leaves the route and goes straight, 190 m/s, for your line.
   "By the route" is 120 m, or 48 m if your own line is taking you off it. Rock between stops it. Rock in its way breaks it.
4. **Otherwise** it runs on 180 m past you, stops, holds 0.3 s. **Recoil:** it draws back up the way it came, 460 m/s and
   gaining.

The hit is round one's: a shove back and down, stick live, no damage.

**The body** (`shaders/peak_strike.gdshader`): the spirals' cloud and light on one solid round body, no helix. The noise is
stretched along it, runs toward the head, and scales with the girth, so streaks close in to the point. The head is a
120 m taper to a flat diamond section, its noise bite cut so the edge is clean. The body sits a shade under the head.

## Routes

13, listed in `scripts/endless/peak_strike_routes.gd` `_table` (that order is what `--peak-strike-route=` counts):

| n | Route | Spire | From |
|---|---|---|---|
| 0 | slot | 0 | `LINE_SLOT` |
| 1 | dike | 0 | Slot to a 650, then `DIKE` crest |
| 2 | ice | 0 | Slot to a 285, into the ice gorge |
| 3, 4 | west crest, west gully | 0 | Slot's shelf, then down the -v arm |
| 5 | back left | 0 | traced spur |
| 6, 7 | back spur, back gully | 1 | traced |
| 8 | back right | 2 | traced spur |
| 9, 10 | east gully, east crest | 2 | Bench, then down the +v arm |
| 11 | bench | 2 | `LINE_BENCH` |
| 12 | rock | 2 | Bench to a 650, into the rock gorge |

The traced tables came from a height grid of seed 1 (lowest or highest way down) and want refitting if the land changes.
Rows without a height lie 46 m over the land (never under 34, read 18 m each side); the flown lines keep their own height.
Baked once at setup, about 130 ms. Pick: the route passing nearest where you'll be in 2.5 s,
within 480 m, at least 500 m down it, repeats marked down.

## The stop

The top is over 860 m over the sea inside 370 m of the plateau's centre: past the rim, inside the ring of spires, whose feet
stand about 450-475 m out. Or over the highest tip anywhere. Then none start and any live one goes home at 900 m/s. They
start again once you're under 640 m over the sea or 1300 m from the crown's middle. The strip's keep-out stays (420 m round
the plateau, under 170 m over the strip); climbing in from the front it usually calls a strike off just before the top does.

## Flags

- `--peak-strike=0`: none.
- `--peak-strike=SECONDS`: forces one that long after launch and every SECONDS after, wherever you are. Not 1. Forced strikes
  ignore the top and the keep-out.
- `--peak-strike-spire=0|1|2`, `--peak-strike-route=N` (0-12).
- Driver: `study.strike.force(spire, route)`.

## Numbers to tune

In `scripts/endless/peak_strike.gd` unless noted:

| What | Constants |
|---|---|
| Cadence | `FIRST_WAIT`, `GAP`, `GAP_SPREAD`, `SHOULDER`, `SPIRE_FOOT`, `WATCH`, `CLIMB`, `NEAR_SPIRE` |
| Tell | `TELL_TIME`, `TELL_OUT` |
| Pick and forks | `PICK_R`, `PICK_AHEAD`, `PICK_FROM`, `PICK_AGAIN`, `SWITCH_BY` |
| Run | `SPEED`, `ACCEL`, `OVERRUN`, `HOLD`, `RUN_MAX`, `LEAD_MAX`, `LEAD_SHARE` |
| Dodge | `LUNGE_FROM`, `LUNGE_REACH`, `LEAVE_T`, `LEAVE_BY`, `LEAVE_REACH`, `LUNGE_SPEED`, `LUNGE_TURN`, `HIT_R`, `WARN_UNDER` |
| The top | `TOP_R`, `TOP_Y`, `RESET_Y`, `RESET_R` |
| Shove | `WIND`, `RISE`, `FALL`, `DOWN`, `NOSE_DOWN`, `NOSE_TURN`, `WINGS` |
| Body | `GIRTH`, `FLOW_SHARE`; in the shader `HEAD_LEN`, `NECK_LEN`, `HEAD_WIDE`, `HEAD_FLAT`, `HEAD_CRISP`, `HEAD_GRAIN`, `BODY_SHADE`, `ALONG` |
| Land | `HUG`, `HUG_LEAST`, `WIDE` in `peak_strike_routes.gd` |

## Proved, lightly

Seed 1, medium, a bot on the real stick, Boost held, one run a case unless noted.

- **Picks your side:** from 8 places round the mountain the game's own trigger took the route there: west gully, east gully,
  back spur, back left, back right, ice, bench, dike. One run took the Bench/Rock fork.
- **Held line:** hit on west crest and back spur. Runs on slot and east gully don't count: the bot crashed into the land.
- **Leaving the route:** 8 runs turning 90 degrees off at 0.7 or 1.4 s into the run. West crest, bench and east crest: 6 of 6
  got away (5 passed, 1 lunge missed, 104-152 m clear on the passes). Back spur: 0 of 2. It starts 590 m off there and the
  bot breaks too late.
- **The top:** 3 flights to the top. Strikes stayed stopped from topping out until the bot left, 6 s or more, none starting.
  Two live strikes were called off on the way in, both by the keep-out just before the top line.
- Smoke passes on `endless_flight`, `--peak-strike=0`, `--peak-strike=3 --peak-strike-route=8` and `--world=regions`, 0 errors.
- Frames at 0.1 s: a clean lengthening down the route from afar, on west crest, back spur and bench.

## Weak

- **Dead head-on along a straight stretch** the body stacks up behind the head, and the plane sits in front of it. It reads
  as a fan of streaks closing on the plane, better than a ball but softer than a point. On a curving route (`f3_play_015.png`)
  it reads best.
- **Land hides it.** On jagged ground a plane low over the route loses the head behind ridges until late. Raising `HUG` from
  26 to 46 helped.
- **Near the spires** there's the least warning. `PICK_FROM` keeps strikes 500 m down a route at least, and back spur still
  beat the dodge.
- **Holding a new straight line after a late break** can still be hit if you were inside 48 m of the route at the lunge.
- The tell is small from far off. I saw it only in wide sheets, never close up.
- Where a route leaves a spire it can cross open air to the land before it lies down, as the Bench does.
- A strike along the Slot or Bench passes the Eyes and Sills by its height table, not by testing them.

## Not verified

- Flown by hand, or motion at full frame rate.
- Frame cost, and the first-strike compile hitch. The shader now takes 65 points, and the box is larger.
- Coming back after the top by flying down: both bot attempts crashed on the way out, and the restart seen was after a crash
  respawn moved the plane away (tell 3 s later). The rule is read, not flown.
- A live strike stopped by the top line itself rather than the keep-out.
- The landing on the strip with strikes on, strikes inside the gorges, and the shove's safety on the new routes. The shove code
  is unchanged. Routes bake on seed 1's land; other seeds aren't looked at.
- Dodging behind rock on purpose: one lunge broke on rock, by chance.
- Sound by ear; a second whoosh now marks the launch.

## Tests

No test under `tests/` names the spirals, strike or `flight_sound`, so I know of none this breaks. The suite wasn't run.
