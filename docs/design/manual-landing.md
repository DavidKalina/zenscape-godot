# Manual landing (round 1)

Branch: `study/manual-landing` (from main 3ecaabec). This round puts the
"true landing" into a greybox study first, as asked, and then into the real
game behind `--manual-landing`. The game's default play is unchanged.

The user asked for this:

> I really want the player to have to find a spot on the island. And
> actually land and like slow down and kind of come to a brake and then
> only then can they get out. I also want them to have to get back into the
> plane to fly.

## Launch

    ./run-landing-study.command                       # the greybox study, station 1
    ./run-landing-study.command --station=islet --bot=sharp
    ./run-landing-study.command --stranded=pickup     # the plane comes for you instead (see below)
    ./run-manual-landing.command                      # the real game, by hand, in the plane over home
    ./run-manual-landing.command --resume             # the same in your last world

Both are also in the title's Scenes picker: "Manual landing" under Flight
greyboxes, and "Landing by hand" under The game.

Bench and trace, headless:

    godot --headless --path . -s tools/landing_bench.gd -- --runs 20 [--station islet] [--skills sloppy,decent] [--save]
    godot --headless --path . -s tools/landing_trace.gd -- short_ledge sloppy 1000

Tests:

    godot --headless --path . --script tests/test_manual_landing.gd        # rules + study, about 2 s
    godot --headless --path . --script tests/test_manual_landing_game.gd   # the live game, about 20 s, tagged slow

## The rules (scripts/manual_landing.gd)

- **No auto-land.** F and the pad's Y never land the plane. In the air they
  lower and raise the flaps. On the wheels they ask to get out.
- **The touch is judged** on the step before the wheels meet the land. It
  is good only if all of these hold:
  - slower than 10.5 m/s along the ground
  - sinking slower than 2.4 m/s
  - wings within 0.35 rad of level, and not mid-roll
  - nose no lower than -0.4 rad
  - ground no steeper than 0.4 m per m
- **A bad touch bounces**, never crashes. It thumps, shakes the camera and
  pulses the pad, and the plane is kicked back up to go round. The kick is
  3.2 m/s plus half the sink, the nose goes up to 0.3 rad, it loses 1 m/s,
  and the wheels don't count for 0.7 s. It rises about 1 to 2.5 m. The
  hint or flash says why: too fast, too steep, wings not level, nose
  first, or ground too steep.
- **A good touch settles** with a small double hop, then rolls on its
  wheels:
  - It slows by 0.9 m/s² rolling, and up to 4.2 m/s² more with Brake held.
    From 8 m/s that is about 35 m with no brakes and 6 m with full brakes.
  - Slopes pull on it: uphill stops sooner.
  - The stick steers the tail wheel.
  - Boost pushes at 4.5 m/s², and with Boost held it lifts off at
    9.5 m/s (a touch-and-go).
  - Rolling off the land's edge, it flies again after a moment's drop.
  - Rolling into a tree, rock or water stops it dead with a thump (game
    only).
- **Stopped** means under 0.25 m/s for 0.25 s. The brakes hold and the
  engine idles. It never gets out by itself. F asks to get out: the engine
  spins down, the pilot hops out, and the plane stays parked where it
  stopped. F while rolling or flying is refused ("Stop first"). Boost
  stopped rolls it off again.
- **Nothing summons the plane** (game, and the study's walker):
  - A jump is only a jump. The held-jump flight is gone.
  - Walking off an island's edge (or an islet's) drops the pilot, carried
    on at their run, and the skydive canopy opens by itself 0.8 s later
    (X sooner). The plane stays parked. No other island is claimed on the
    way down.
  - Come down on the plane's own island and you walk back to it.
  - Once 20 m under the edge, or down anywhere else (another island, an
    islet, the sea, the island's rock skirt), you are **stranded**. After
    3 s you are back on foot beside the parked plane, still to board it.
  - Space by the plane boards it and takes off, using the old takeoff
    (BOARD, TAXI, ROLL, LIFT).
- **Ejecting (X) works as before**: the plane flies itself and lands near
  you on the island, and an eject into the sea is picked up by the plane.

### What I chose on the open points

- **Air brake: flaps on F / Y, a toggle.** They suit a pad better than a
  hold, because the triggers are already busy. With flaps down:
  - the engine holds 5.5 m/s and the floor drops from 7 to 5 m/s
  - it sinks 0.5 m/s more
  - Boost overrides them, for a go-around

  Shift's brake alone gets the plane to 8 m/s, which is enough to land.
  Flaps are for short fields: the touch drops to about 5.7 m/s and the
  rollout to about 4 m. This is a new optional `flaps` input on
  `SkyPlane.step`. It is 0 unless asked for, so the plane flies exactly as
  before everywhere else.
- **Where a canopy landing puts you: back beside the plane.** A canopy only
  sinks, and an island's top is the highest land near it. So a step off
  the edge almost never lands back on the plane's island. A plane pickup
  would have you flying without boarding, which breaks "get back into the
  plane to fly". So a stranded pilot waits 3 s (the study fades to dark)
  and stands beside the parked plane, facing it.
- **The sea pickup by the plane** is kept only as a study variant
  (`--stranded=pickup`: wait 3 s, then you are flying, nose up over where
  you came down), for comparing the two. After an eject (X) the old instant
  pickup is unchanged, in the game and as the user asked.
- **No auto guidance.** The bots read the field like a pilot. The one cue
  is the game's existing touchdown mark under a low plane, which is now lit
  brighter when the hand judge says a touch now would land. That's a
  judgement call; it's one line to turn off (`would_land` passed to the
  plane figure's `update` in both scenes).
- **Stepping in with no plane parked** (the game, flag on) parks one beside
  the pilot. Otherwise a new world would have no plane at all. A flight
  set from outside (`--skydive`'s start, a set piece's N hop) takes the
  parked plane, so there is only ever one.

## Controls

| | Keys | Pad |
|---|---|---|
| Turn, pitch (W noses down) | WASD | left stick |
| Boost (and on the wheels, power) | Space | RT / A |
| Brake (and on the wheels, the wheel brakes) | Shift | LT |
| Flaps down or up (air) / get out (stopped) | F | Y |
| Knife edge, twice: barrel roll | Q E | LB RB |
| Open the canopy sooner | X | X |
| On foot: walk / board by the plane / hop | WASD / Space / Space | left stick / A / A |
| Study: stations, again, next, who flies, numbers | 1-5, R, N, B, F1 | |

## The study (studies/landing_study.tscn)

Five greybox fields, 500 m apart over a sea at -60 m. You start 170 m short
of each field, 24 m up, flying at it at cruise:

| Key | Station | What |
|---|---|---|
| 1 | long_field | 90 × 24 m, flat |
| 2 | short_ledge | 30 × 18 m, ending at a ledge; a lower shelf 22 m down beyond it |
| 3 | slope_field | 50 × 20 m, rising 1 in 7 away from you |
| 4 | islet | round, 18 m across |
| 5 | crosswind | 60 × 10 m strip, wind across it from the west, 2.5 ± 1 m/s gusting |

Each approach is a run (scripts/landing_run.gd). It ends when the plane
stops, or after 120 s. Its JSON goes to `user://landing_runs/`, and a report
shows:
- the time to stop and the rollout
- the good touch's speed and sink, and the first touch's if they differ
- bounces and why, go-arounds, touch-and-gos, rolls off the edge, and
  exits asked too early
- where it stopped

F1 shows the live numbers: speed, sink and bank bars against the limits,
height over the land, flaps, and "a touch now would LAND / bounce". After a
takeoff or a pickup, the next approach is a new run on the nearest field.

B cycles the pilot: you, then the sloppy, decent, sharp and perfect bots
(scripts/landing_bot.gd). A bot:
- holds the middle line by pursuit on its ground track, so it crabs in wind
- comes down a fixed glide path, flares (or forgets to), and brakes
- goes round after a bounce with little field left, a roll off the edge,
  or overshooting
- gets out once stopped

Skill sets when it descends and how steep, when it brakes, whether it uses
flaps, flare height, the chance of missing the flare, aim error and stick
noise.

### Bot metrics per station (20 runs each; perfect flies once)

Means over the runs; time, touch, sink and rollout over the stopped runs.

| station | skill | stopped | time to stop s | touch m/s | sink m/s | bounces | go-arounds | rollout m | off edge |
|---|---|---|---|---|---|---|---|---|---|
| long_field | sloppy | 20/20 | 19.3 | 9.1 | 0.58 | 0.8 | 0.0 | 19.5 | 0.0 |
| long_field | decent | 20/20 | 19.8 | 8.8 | 0.88 | 0.0 | 0.0 | 10.4 | 0.0 |
| long_field | sharp | 20/20 | 21.9 | 8.5 | 0.55 | 0.0 | 0.0 | 8.0 | 0.0 |
| long_field | perfect | 1/1 | 30.1 | 5.6 | 0.53 | 0.0 | 0.0 | 3.0 | 0.0 |
| short_ledge | sloppy | 2/20 | 18.1 | 10.0 | 1.00 | 1.5 | 1.6 | 22.8 | 1.2 |
| short_ledge | decent | 19/20 | 25.5 | 9.0 | 1.01 | 0.0 | 0.1 | 10.3 | 0.1 |
| short_ledge | sharp | 20/20 | 26.7 | 5.8 | 0.56 | 0.0 | 0.0 | 3.9 | 0.0 |
| short_ledge | perfect | 1/1 | 28.9 | 5.7 | 0.53 | 0.0 | 0.0 | 3.2 | 0.0 |
| slope_field | sloppy | 18/20 | 17.3 | 9.3 | 0.85 | 0.8 | 0.0 | 15.4 | 0.0 |
| slope_field | decent | 20/20 | 18.2 | 9.2 | 0.90 | 0.0 | 0.0 | 9.3 | 0.0 |
| slope_field | sharp | 20/20 | 19.9 | 8.8 | 0.54 | 0.0 | 0.0 | 7.1 | 0.0 |
| slope_field | perfect | 1/1 | 29.1 | 5.7 | 0.53 | 0.0 | 0.0 | 2.6 | 0.0 |
| islet | sloppy | 0/20 | - | - | - | 1.4 | 2.0 | - | 0.7 |
| islet | decent | 13/20 | 46.4 | 9.3 | 1.44 | 0.0 | 1.0 | 9.5 | 0.7 |
| islet | sharp | 20/20 | 26.5 | 5.9 | 0.57 | 0.0 | 0.0 | 3.9 | 0.0 |
| islet | perfect | 1/1 | 28.8 | 5.8 | 0.53 | 0.0 | 0.0 | 3.2 | 0.0 |
| crosswind | sloppy | 19/20 | 21.5 | 8.8 | 0.59 | 0.7 | 0.1 | 18.1 | 0.1 |
| crosswind | decent | 20/20 | 20.1 | 8.3 | 0.87 | 0.0 | 0.0 | 9.4 | 0.0 |
| crosswind | sharp | 20/20 | 22.4 | 8.3 | 0.54 | 0.0 | 0.0 | 7.6 | 0.0 |
| crosswind | perfect | 1/1 | 23.0 | 8.4 | 0.50 | 0.0 | 0.0 | 6.8 | 0.0 |

How to read it:
- The long field forgives everything. Sloppy bounces about once and still
  stops.
- The short field and the islet are where skill shows. Without flaps and
  prompt brakes a good touch still rolls off the end. Sloppy stops on the
  islet 0 times in 20, decent 13 times.
- The sloped field is a little easier than the flat one, because uphill
  stops you.
- The crosswind strip barely bites at 2.5 ± 1 m/s with the bots' crab. The
  rules don't judge drift at the touch: in this flight model the sideways
  part of the velocity is the wind's and can't be flown out. Its difficulty
  is staying on a 10 m strip.
- Perfect is the slowest to stop, because it uses flaps everywhere but the
  wind.

## Tuning constants (current values)

scripts/manual_landing.gd:

| Constant | Value | What |
|---|---|---|
| TOUCH_FAST | 10.5 m/s | fastest good touch, along the ground |
| TOUCH_SINK | 2.4 m/s | hardest good sink |
| TOUCH_BANK | 0.35 rad | most bank (any barrel roll bounces) |
| TOUCH_NOSE | -0.4 rad | lowest nose |
| TOUCH_SLOPE | 0.4 m/m | steepest ground |
| BOUNCE_UP, BOUNCE_GIVE | 3.2 m/s, 0.5 of the sink | the kick back up |
| BOUNCE_PULL | 9.0 m/s² | how fast the kick dies |
| BOUNCE_NOSE | 0.3 rad | nose thrown up to |
| BOUNCE_SCRUB | 1.0 m/s | speed lost |
| BOUNCE_GRACE | 0.7 s | before the wheels count again (after a lift-off too) |
| ROLL_DRAG | 0.9 m/s² | rolling, throttle closed |
| WHEEL_BRAKE | 4.2 m/s² | full wheel brakes |
| PUSH | 4.5 m/s² | throttle on the wheels (PlaneLanding PUSH) |
| SLOPE_PULL | 7.0 m/s² per m/m | slope's pull |
| TAXI_TURN, TAXI_FULL | 0.9 rad/s, from 3 m/s | tail-wheel steering (a quarter of it stopped) |
| LIFT_SPEED | 9.5 m/s | touch-and-go lift-off (PlaneLanding LIFT_SPEED) |
| STOP_SPEED, STOP_HOLD | 0.25 m/s, 0.25 s | what counts as stopped |
| SETTLE, SETTLE_TIME | 0.09 / 0.025 m, 0.26 / 0.16 s | the good touch's two small hops |
| LOW_PASS, GO_AROUND | 3 m, 8 m | a go-around: under LOW_PASS over the land, then over GO_AROUND without stopping |

The getting out reuses PlaneLanding BEAT_TIME 0.35 s, HOP_TIME 0.5 s and
SPIN 0.35 s.

scripts/sky_plane.gd (new, off unless `flaps` is given): FLAP_SPEED
5.5 m/s, FLAP_SLOW 5.0 m/s, FLAP_SINK 0.5 m/s.

scripts/wanderer_eye.gd, under the flag:

| Constant | Value |
|---|---|
| STEP_OFF_OPEN | 0.8 s |
| STRAND_BELOW | 20 m |
| STRANDED_WAIT | 3 s |
| SHAKE_TIME, SHAKE | 0.4 s, 0.3 m |

studies/landing_study.gd: the same step-off numbers (STEP_OFF_OPEN 0.8,
STRAND_BELOW 20, PICKUP_WAIT 3, FADE 0.5); SHAKE 0.35 m. The thump is a
0.22 s, 58 Hz decaying sine.

## Files

- `scripts/manual_landing.gd`: the rules, as plain state and maths.
- `scripts/sky_plane.gd`: the `flaps` input.
- `scripts/landing_course.gd`, `landing_run.gd`, `landing_bot.gd`: the
  study's fields, runs and CPU pilot.
- `studies/landing_study.gd` / `.tscn`, `run-landing-study.command`.
- `tools/landing_bench.gd`, `tools/landing_trace.gd`.
- `scripts/wanderer_eye.gd`: `--manual-landing`. See the header paragraph
  and the "By hand" section. Every change is behind `manual` or `_hand()`.
- `run-manual-landing.command`, `scripts/scene_catalog.gd` (two entries).
- `tests/test_manual_landing.gd`, `tests/test_manual_landing_game.gd`
  (slow).

## Unverified

- **Nothing was looked at rendered.** Everything ran headless only. That
  leaves unseen:
  - the greybox fields' look
  - the camera framing on the roll (`chase.cine`), the shake and the hop out
  - the study's capsule walker, its foot camera, and the canopy and its
    camera over the study
  - the fade and the touchdown mark's new brightness
  - how the thump sounds
- **The pad's rumble and Y as flaps/exit** haven't been tried on hardware.
- **How it feels to a person.** The thresholds are tuned against the bots
  only.
- **Only the import and the two new tests were run** (and the scene picker's
  entry checks, which also smoke-run both new entries for 6 to 9 s without
  script errors). The existing plane, skydive, landing and gamepad tests
  weren't. Default play is unchanged by construction: every new path is
  behind the flag, and flaps default to 0. Those tests have not confirmed
  it.
- **Game findings worth a look:**
  - Over the island the wind's ridge lift and gust fronts lift by up to
    6.5 m/s. That can hold a slow plane up just over the ground. The live
    test needed retries and a push of the nose to touch down on some seeds.
    Landings into a windward slope may feel floaty, or impossible in a
    strong wind.
  - The plane rides over tree crowns as before, so it can't land among
    trees. It floats over a wood and on off the island.
  - The island's solid reaches a little past the walkable land outline.
    Stepping just off the shore onto that rock skirt counts as stranded.
  - Islets: the plane can't land on one under the flag. It skims them and
    the old perch from the plane is off. Under `--below` the old rules hold.
  - After an eject, the plane still lands itself near you on the island
    (kept, as asked). That's the one way the plane still comes to you.

## Next steps

- Fly both. Judge the thresholds, the bounce's height and the brake
  strength first.
- Decide stranded "return" against "pickup" (`--stranded=pickup` in the
  study).
- Decide whether the touchdown mark's "would land" brightness stays.
- Calm the ridge lift and gusts within a few metres of the ground for a
  slow plane, or decide they are part of the challenge.
- Give the plane somewhere to land on an islet (park on islets), or rule
  islets out of landing for good.
- If it stays, make the flag the default and retire PlaneLanding's line-up
  half and the old F landing, keeping its takeoff.
- Optionally, a crosswind rule that judges the crab (nose off the track at
  the touch) rather than the drift.
