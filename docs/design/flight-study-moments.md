# Flight study: moments, not trails (round 6, moments pack)

Branch: `study/flight-moments`, from `integrate/flight-packs` (e7b38c12),
not main. Greybox only.

The user flew the four packs and liked the layouts, but not picking up
long runs of orbs: "too many micro adjustments". They want the difficulty
to be "can you react, fit that tight space, reach that difficult
collectible", not "can you trace the line". Their idea was a collectible
that starts a challenge, alongside collectibles that are just there.

This round has five new stations in a new pack, `moments`. Each one keeps
the stone of a station the user rated highly, and its old trail becomes
an invisible natural line. A station has 3 free collectibles (moments), one
starter, and 3 challenge collectibles that the starter brings out. Each
collectible gets its own difficulty: fit, react and reach, and a band. No
existing station, hash or bench number changed.

## Launch

    ./run-flight-moments.command                              # starts on moments_hall; N cycles the five
    ./run-flight-moments.command --station=moments_cave
    ./run-flight-moments.command --challenge-time=12          # every challenge timed (12 s from the starter)
    ./run-flight-moments.command --challenge-mode=chain       # challenge collectibles one at a time
    ./run-flight-moments.command --bot=sharp                  # watch a bot
    godot --path . res://studies/flight_study.tscn -- --no-title --pack=moments

Bench, layout and tests, all headless:

    godot --headless --path . -s tools/flight_bench.gd -- --pack moments --runs 20             # per-collectible table
    godot --headless --path . -s tools/flight_bench.gd -- --pack moments --runs 20 --no-bonus  # bots ignore moments: the bare line
    godot --headless --path . -s tools/flight_bench.gd -- --pack moments --runs 10 --no-save --moment-ease 0.65   # size sweep
    godot --headless --path . -s tools/flight_moments_check.gd                     # fit/react/reach per moment, no flying
    godot --headless --path . -s tools/flight_moments_check.gd -- --scan lines_bend --pick standard   # candidate spots
    godot --headless --path . -s tools/flight_moments_plan.gd -- --station moments_bend --out /tmp/plan   # plan PNG
    godot --headless --path . -s tools/flight_trace.gd -- moments_hall decent 3   # grabs, challenge, scrapes
    python3 tools/run_tests.py --tests 'test_flight_*.gd'

Stills (opens a window, only when wanted):

    Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_moments.gd -- --no-title [--only=moments_cave]

## Keys and args

The keys are the same as before. N moves to the next station, R restarts,
B changes who flies, F1 shows the live numbers, and Esc frees the mouse.
After a pass, 1-5 rates difficulty and then fun.

| Arg | Does |
|---|---|
| `--pack=moments` | Start on the pack. N stays inside it. |
| `--challenge-time=<s>` | Time every moments station's challenge from when the starter is taken. 0, the default, means no limit. |
| `--challenge-mode=all\|chain` | `all` (default): the starter brings out every challenge collectible at once. `chain`: one at a time, each after the one before is taken. |

Either override gives the station its own hash and its own run record.
The station itself is unchanged.

What you see on a moments station:

- **Gold balls**: free collectibles. They are there from the start.
- **A magenta ring**, spinning, with a ball in it: the starter. Fly
  through it to start the challenge.
- **Orange-red diamonds**, spinning: challenge collectibles. They are only
  there while the challenge is on.

The trail isn't drawn. The stone carries the line. Each collectible is
drawn at a size that follows its pickup reach.

The HUD and F1 show `free x/y, challenge x/y` and the challenge's state:
ON (with time left, if timed), complete, or ended (left the area, time
up, or ended with the pass). The end-of-pass panel shows the same counts
and how the challenge ended. If the bench has been run, it also shows
each collectible's bot band, with `+` on the ones this pass got.

## How it works

**Station data.** A moments station is plain data in
`scripts/flight_pack_moments.gd`. Its `parts` and `tokens` are the source
station's own, by reference (for example `PackLines.STATIONS[0].parts`).
`moments` is a list of `{at, role, kind, ease, note}` and `challenge`
holds the challenge settings.

**The natural line.** With `moments` present and no `guides` list, every
token is a guide (`FlightCourse.guides`). Guides aren't drawn or counted,
and the run ends when the line is flown, as before. Nothing is needed to
clear (`total` 0).

**Taking a collectible.** A moment is taken like a bonus token: the
plane's path passes within that moment's own reach (`REACH × ease`). It is
never missed. A free one is a skill moment you can try for or let go.

**The starter.** Taking it starts the challenge, and every challenge
collectible appears (or only the first, in `chain`). The challenge ends:

- `complete`, when all its collectibles are taken
- `left`, when the plane strays more than `area` m from the line (default
  40)
- `timeout`, after `time` s (default 0, meaning no limit)
- `over`, when the pass ends

Ending is never a penalty. The challenge collectibles go away, and unless
the challenge was complete the starter stands again. Taking it again
brings them all back. A pass records free got, the best challenge try,
the number of tries and how the challenge ended.

**Code.**

- Run plumbing: `FlightRun` `_moments` and `_challenge_*`.
- Numbers: `FlightMetrics.moments` (free_taken, challenge_taken,
  challenge_tries, challenge_complete, moments_got). They are added only
  for a station with moments.
- Hashes: `station_hash` includes `moments` and `challenge` only when
  present, so every older hash is unchanged.

### The three axes (scripts/flight_moments.gd), read off the natural line at cruise

- **fit**: the room round the collectible. This is its clearance less half
  the wingspan, the same measure the line's rooms use. Where level wings
  don't fit, it is the better of level and on edge. `k` means only a knife
  edge fits. A collectible in open air shows as 9.9.
- **react**: seconds from first seen to commit. "Seen" is the start of the
  last spell in which the collectible is in the run's sight cone with a
  clear line to it. Gaps under 2 s don't count, and for a challenge
  collectible the clock only starts once the line has passed the starter.
  "Commit" is the last moment you can start bending off the line for it.
  The lead before passing it is a half-cosine sidestep of `beyond` m at
  full turn rate, plus roll-in, plus knife roll-up where a knife edge is
  needed. Below 0 means it can't be seen in time from the line on a first
  pass.
- **reach**: metres off the natural line. `beyond` is that less its pickup
  reach.

**Band**: the least bot skill that gets the collectible in at least 60% of
runs. For a challenge collectible, only the runs that took the starter
count. "none" means no bot does.

### The bot (scripts/flight_bot.gd, still VERSION 2)

On a moments station the bot flies the natural line itself: pure pursuit
along the smooth line, `look` m ahead, and only forward. It goes for
every collectible it sees, the starter included, nearest first: seen for
its reaction time, within 45° and 30 m, with a clear line. Perfect knows
them all. Two additions:

- **`grab_aim`**: the aim is off by a gaussian miss across its way in.
  Sloppy misses by 0.8 m, decent 0.5, sharp 0.3, perfect 0.
  Without this, pure pursuit homes onto the exact point, and a
  collectible's size never mattered. At ease 0.5 (0.85 m) sloppy still got
  most of them.
- **Unpin**: when it is pinned nose-first on stone, it turns hard toward
  the line for 0.5 s at a time.

Neither touches other stations. The tokens pack's bench numbers are
identical to its handoff. `--no-bonus` now also makes bots ignore
moments, which flies the bare line.

## The stations

The picks come from the user's rated runs in `user://flight_runs`:

- lines_bend, lines_crest and tokens_hall_gates (sundered_flow's hall)
  were rated fun 5.
- sky_pierced was rated 4.
- Every nature station was rated 3. I took nature_cave because it leaves
  and comes back in twice, through its skylights.

Each station's moments sit 1-4 s apart along the line, with at least about
1 s before the next one. Most were chosen with
`flight_moments_check.gd --scan --pick`, which finds spots that are clear
of stone with a clear way back to the line, and then placed by hand.
Pickup sizes were set from a size sweep, aiming for free ones easy to
medium and challenge ones medium to hard.

Each table below gives every collectible's fit (m), react (s) and reach
(m), the get rate for sloppy / decent / sharp / perfect over 20 runs each
(5 look-aheads for perfect), and its band. The "at" column is where along
the natural line the collectible sits, in seconds.

### moments_hall (sundered_flow's hall: tokens_hall_gates), hash bebd38402d9e

| # | role | kind | what | at s | fit | react | reach | ease | got sl/de/sh/pf | band |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | free | reach | out to the right past the first high tie | 2.3 | 1.83 | 1.12 | 4.7 | 1.0 | .80/.95/.95/1 | easy |
| 1 | free | fit | skimming the nave's middle column | 3.1 | 0.02 | 0.44 | 2.1 | 1.0 | .55/.85/1/1 | medium |
| 2 | starter | | left of the line past the low tie | 4.2 | 2.49 | 3.50 | 3.0 | 1.3 | .85/1/.95/1 | easy |
| 3 | free | react | down in the gap, under A's torn end | 7.6 | open | 0.56 | 5.2 | 0.65 | .55/.95/1/1 | medium |
| 4 | challenge | fit | B's first knife slit | 10.0 | 0.39k | −0.49 | 9.0 | 0.6 | .35/.55/.90/1 | hard |
| 5 | challenge | reach | out right under B's roof, past the slits | 11.4 | 1.21 | 1.03 | 8.1 | 0.65 | .24/.50/.95/1 | hard |
| 6 | challenge | react | just over B's roof edge as you climb out | 12.5 | open | 0.25 | 5.8 | 0.6 | .18/.50/1/.80 | hard |

Challenge completed in 10/15/80/80% of runs (sl/de/sh/pf).

### moments_bend (lines_bend's stone and green line), hash 2933e851fa40

| # | role | kind | what | at s | fit | react | reach | ease | got sl/de/sh/pf | band |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | free | reach | up in the broken roof's gap | 2.4 | 0.85 | 1.14 | 5.2 | 0.9 | 1/.95/1/1 | easy |
| 1 | starter | | under the roof before the crest | 5.4 | 3.20 | 4.62 | 3.4 | 1.3 | .95/1/1/1 | easy |
| 2 | free | fit | skimming the spire's face, outside | 9.1 | 0.30 | 2.62 | 3.5 | 1.3 | .95/1/1/1 | easy |
| 3 | challenge | react | just inside the wall as you come back in | 10.7 | 4.50 | 0.24 | 6.2 | 0.6 | .47/.70/1/1 | medium |
| 4 | challenge | fit | between a column and the right wall | 11.9 | 0.05 | 2.51 | 4.7 | 0.5 | .53/.65/.80/1 | medium |
| 5 | free | react | low on the left behind a column as the hall turns | 14.0 | 1.27 | 0.53 | 6.2 | 0.9 | .25/.60/.65/1 | medium |
| 6 | challenge | reach | high on the left near the end | 15.3 | 1.34 | 4.24 | 6.7 | 0.6 | .53/.50/.95/1 | hard |

Challenge completed in 10/30/75/100%.

### moments_cave (nature_cave), hash 9519bf433092

| # | role | kind | what | at s | fit | react | reach | ease | got sl/de/sh/pf | band |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | free | reach | low on the left inside the cave | 4.1 | 1.37 | 1.08 | 4.8 | 0.9 | .90/1/1/1 | easy |
| 1 | starter | | just out of the first skylight | 6.5 | 2.39 | 3.21 | 3.0 | 1.3 | 1/1/1/1 | easy |
| 2 | free | fit | skimming the second pinnacle, on the roof | 8.9 | 0.24k | 1.97 | 4.2 | 1.0 | .65/.60/.95/1 | easy |
| 3 | challenge | fit | close under the second skylight's lip | 10.7 | 0.05 | 1.56 | 4.5 | 0.65 | .50/.65/.90/1 | medium |
| 4 | free | react | low on the left, back inside | 12.4 | 0.40k | 0.60 | 6.2 | 1.0 | .30/.85/1/1 | medium |
| 5 | challenge | react | in a pocket of the right wall | 14.7 | 0.40k | 0.44 | 6.2 | 0.45 | .45/.75/.90/1 | medium |
| 6 | challenge | reach | low on the left out of the far mouth | 19.2 | open | 6.78 | 6.7 | 0.65 | .55/1/1/1 | medium |

Challenge completed in 10/60/80/100%.

### moments_pierced (sky_pierced), hash 9c9d823d5783

| # | role | kind | what | at s | fit | react | reach | ease | got sl/de/sh/pf | band |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | free | reach | left of the tunnel mouth | 3.6 | open | 2.43 | 4.7 | 1.0 | .85/1/1/1 | easy |
| 1 | free | fit | up in the tunnel's corner | 5.3 | 0.25 | 3.38 | 4.2 | 0.8 | .85/1/1/1 | easy |
| 2 | starter | | just out of the tunnel | 9.0 | 5.74 | 1.90 | 3.0 | 1.3 | .90/1/1/1 | easy |
| 3 | challenge | fit | under the outrider's rim | 10.6 | 0.06 | 0.52 | 3.4 | 0.55 | .22/.55/.95/1 | hard |
| 4 | free | react | round the loop, by the stacks | 12.7 | 1.99 | 0.53 | 4.2 | 0.8 | .60/.95/1/1 | easy |
| 5 | challenge | reach | up under the big isle's keel | 16.5 | 4.30 | 1.64 | 3.4 | 0.5 | .50/.60/1/1 | medium |
| 6 | challenge | react | just over the veil's near edge | 19.4 | 1.30 | 0.35 | 5.0 | 0.6 | .56/.90/1/1 | medium |

Challenge completed in 5/25/95/100%.

### moments_crest (lines_crest's stone and green line), hash 1efe8caa5e81

| # | role | kind | what | at s | fit | react | reach | ease | got sl/de/sh/pf | band |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | free | reach | low under the climb out | 3.5 | 2.36 | 2.25 | 5.2 | 0.9 | .65/.90/1/1 | easy |
| 1 | starter | | on the roof before the first gate | 5.3 | 3.67 | 3.06 | 3.4 | 1.3 | .95/1/1/1 | easy |
| 2 | free | fit | between the second big gate and its slit gate | 7.2 | 0.25 | 1.59 | 3.4 | 1.0 | .85/.60/.85/1 | easy |
| 3 | challenge | fit | through the third slit gate | 8.3 | 0.42k | 1.41 | 6.1 | 0.8 | .16/.55/.80/1 | hard |
| 4 | free | react | right of the dive back in | 9.6 | 1.08 | 0.52 | 6.2 | 0.8 | .60/1/1/1 | easy |
| 5 | challenge | react | up on the left, back under the roof | 11.9 | 0.39 | 0.29 | 5.8 | 0.65 | .47/.80/.80/1 | medium |
| 6 | challenge | reach | high on the right near the end | 14.0 | open | 6.77 | 7.2 | 0.55 | .26/.70/1/1 | medium |

Challenge completed in 5/40/60/100%.

## The bench (20 runs, saved)

The bench's per-collectible table is printed after the usual tables
(`moments_table`). For each collectible it gives fit, react, reach, where
it is on the line, the get rate per skill and its band. Then, per skill:
free collectibles got, the share of runs that started the challenge, the
share that completed it, challenge collectibles got (best try), and
bumps. Each moments station's band in the main table is "moments". Its
`bands.json` row carries the per-collectible rows, which is how the
study's end panel shows them.

How it reads:

- **Free ones**: 3 per station. 11 are easy and 4 medium. Decent gets
  2.45-2.95 of 3 everywhere, and sloppy 1.85-2.30.
- **Challenge ones**: 3 per station. 6 are hard and 9 medium. Completion
  climbs with skill on every station: sloppy 5-10%, decent 15-60%, sharp
  60-95%, perfect 80-100%. This is the "optional mastery" gradient. Nothing
  fails, and a pass just yields less.
- **Flow is intact on the line**. With the moments ignored
  (`--no-bonus`), the line-flying perfect bot matches the source
  stations: still 2/21/7/10/17% (hall, bend, cave, pierced, crest), at
  their source times.
- **Chasing every moment costs flow.** The reference that takes them all
  is 23-39% still, with straights up to 1.9 s, and takes 3-6 s longer.
  The bot beelines to a collectible seen 30 m off. A person may curve
  into one, but this is the cost of greed.

## Surprises

- **Pure pursuit makes size irrelevant.** Before `grab_aim`, shrinking
  every collectible to half the reach barely moved the bots' get rates. A
  bot that steers continuously onto a point hits it exactly. Only seeing
  it late, or stone round it, made any difference. A person is different.
  So size is a real dial for people, and for bots only with an aim error.
- **The natural line needs a bot that flies the line, not the tokens.** At
  first the bot chased the guides. After a grab it would turn back for one
  it had passed, or press against a column trying to reach the next guide
  behind it, and once it scraped a column for 38 s.
  - Fix part 1: pursue the smooth line, only forward, aim at the farthest
    sample it can see, and turn to unpin when stuck.
  - Fix part 2: move the moments that sat in traps. The first high tie's
    underside led straight into the nave's middle column 0.5 s later. A
    react moment tucked against the bend's left columns left no room to
    recover, so I moved it to a spot with 1.3 m of room.
- **"React" needs memory and a reveal.** At first a moment seen across a
  loop (the pierced isle) read 15 s of warning. A short gap in view
  wrongly zeroed others.
  - The spell rule, which allows gaps under 2 s, fixed both.
  - Challenge collectibles can't be seen before the starter is taken, so
    their clock starts there.
- **Challenge items in the same moment on opposite sides make no sense.**
  The first hall layout had B's slit (left) and an aisle grab (right) 0.2
  s apart. A pass could never take both. I spaced challenge items at
  least about 1 s apart along the line.
- **Slit grabs are far from the line.** The hall's knife slit is 9 m off
  the natural line (it is the line's neighbour lane). Bots see it 6 s
  early, so it bands on the knife, not on the reach.

## Unverified

- **Nobody has flown it.** The bands are bots'. Whether the moments feel
  like "react, fit, reach" rather than tracing is the round's real
  question, and it is untested.
- **The starter's look and reach.** The magenta ring is a guess at "this
  starts something". Its pickup is generous (ease 1.3), so a pass that
  wanders near it might start a challenge by accident.
- **Moment sizes are tuned to the bots' `grab_aim`**, which is my guess at
  a player's aim error. The numbers are sloppy 0.8 m, decent 0.5, sharp
  0.3.
- **Rendered stills**: 35 chase stills, one before each moment
  (`capture_flight_moments.gd`). The balls, rings and diamonds read
  against the grey stone, and the challenge diamonds show inside B and on
  the crest's slit gate. The starter ring is thin seen side-on (it spins).
  I didn't judge whether "react" spots are surprising from the chase
  camera, which sees more than the bot's cone.
- **Close pairs**:
  - Hall: free reach then free fit, 0.8 s apart.
  - Crest: the free fit at gate 2, then the challenge slit at gate 3, 1.0
    s apart, which is the rhythm of the gates.
  - Bend: the challenge react then the challenge fit, 1.3 s apart.
- **Challenge `area`** (40 m) and `time` were only exercised in tests and
  by bots, never by hand.
- **Tests**: I ran the headless import check, the bench (moments, saved;
  tokens, not saved: unchanged) and
  `python3 tools/run_tests.py --tests 'test_flight_*.gd'`. All 7 pass,
  including the new `test_flight_moments.gd`. I did not run the full
  suite. The user's 56 `_human_` run files were md5'd before and after the
  saved bench, and are unchanged (c2f4aea2312c871915b2e615a7fe1181).

## For the next step: greybox stations in the real sky world

- **Discovery is the starter's job.** A free moment can be just found. A
  starter has to be seen from the approach, and the ring's spin is the only
  draw right now. In the world, it needs reading from 100+ m:
  - a beacon, sound or glint
  - placement on the natural approach line into the set piece, so flying
    in "as you would" passes near it but not through it
- **Leaving the area.** `area` is measured from the station's line. In the
  world, a set piece needs its own region (a volume round its stone), or
  wandering players will trip `left` on approach. The timer is per
  station, so a timed variant is one field.
- **Starting mid-flight.** Here a pass starts at the entry, at cruise, on
  the line. In the world the player arrives from anywhere. Challenge
  collectibles should be placed so they read from more than one approach,
  or the starter should sit where the approach is forced (a mouth, a gap).
- **Retries.** The starter re-arms after a failed try. In the world that
  is the loop: fly out, come round, take the ring again. The run records
  tries, which is a ready-made "did they want another go" signal.
- **The natural line is the set piece's intended route.** The bot-line
  tooling (flying the line, scanning spots round it, the plan PNG) works
  for any greybox stone that has a line through it.

## Suggested next round

1. **Fly the five and rate them.** Fly the free moments first without
   taking the ring, then take it. Is the challenge more fun than the free
   pass? Do the knife slits (hall, crest) feel like "fit" or like
   tracing?
2. **Try the variants**: `--challenge-mode=chain` (one at a time, more
   "react") and `--challenge-time=10`. Say which one feels like Odyssey.
3. **If the starter is taken by accident**, shrink its reach or put it a
   bend off the line.
4. **Calibrate `grab_aim` against the user's own runs.** Each `_human_` run
   keeps its ticks and tokens, so the closest pass to each token, taken or
   missed, can be worked out and the bots' aim error fitted to the user.
   Then the bands mean the user's own skill levels.
5. **Then put two or three stations into the sky world** as set pieces.
   The ring should be visible from the approach, and each needs an area
   volume.

## Files

- New:
  - `scripts/flight_pack_moments.gd`: the five stations.
  - `scripts/flight_moments.gd`: the three axes and the per-collectible
    band.
  - `tools/flight_moments_check.gd`: the per-moment table, `--scan` and
    `--pick`.
  - `tools/flight_moments_plan.gd`: a plan PNG at line height, with
    moments.
  - `tools/capture_flight_moments.gd`: rendered stills.
  - `run-flight-moments.command`.
  - `tests/test_flight_moments.gd`, which pins the 5 hashes and covers the
    mechanics, axes, bot, bench and study.
- `scripts/flight_course.gd`: the pack appended, `moments()`,
  `challenge()`, guides for a moments station, and `moments` and
  `challenge` in the hash only when present.
- `scripts/flight_run.gd`: moments taken and seen, the starter and
  challenge, live counts, and the JSON's `moments`, `challenge` and
  `result.free`/`challenge`.
- `scripts/flight_metrics.gd`: `moments()`.
- `scripts/flight_bot.gd`:
  - flying the line (`_line_aim`)
  - `_moment_target`, `grab_aim` and unpin
  - `grab_aim` added to SKILLS (only read on moments stations)
- `tools/flight_bench.gd`: per-collectible rows and table,
  `--moment-ease`, and `--no-bonus` also ignoring moments.
- `tools/flight_trace.gd`: moment events and scrape spells.
- `studies/flight_study.gd`:
  - the three looks
  - the HUD and panel counts, with per-collectible bands
  - `--challenge-time` and `--challenge-mode`
- `docs/design/flight-study-packs.md`: points here.
