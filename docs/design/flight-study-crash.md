# Flight study: crash and restart (round 7)

Branch: `study/flight-crash`, from `study/flight-moments` (327c93e7), not
main. Greybox only.

The user asked for "maybe 'dying', or like hitting something and then
restarting". Until now, hitting stone meant bump and recover
(`scripts/ruin_bump.gd`): the plane is knocked off the stone and loses a
share of its speed, but it never crashes. This round adds crash and
restart as an **opt-in mode next to bump and recover**, so the two can be
compared directly. Off is the default, and with it off every station hash
and every bench number is unchanged.

The user then decided that only hard collisions crash. So `hard` is the
main mode, and `any` is kept as a debug mode. The crash rule is decided
per solid, through a crash class, so obstacles added later only need
tagging.

## Launch

    ./run-flight-crash.command                                  # the moments pack, --crash=hard, restart at checkpoint
    ./run-flight-crash.command --restart=ring                   # or entry
    ./run-flight-crash.command --crash-speed=6                  # a harsher stone threshold (m/s into the face)
    ./run-flight-crash.command --station=moments_bend --bot=sharp
    godot --path . res://studies/flight_study.tscn -- --no-title --pack=moments --crash=hard

Bench, tuning and tests, all headless:

    godot --headless --path . -s tools/flight_bench.gd -- --pack moments --runs 20 --crash hard --restart checkpoint
    godot --headless --path . -s tools/flight_bench.gd -- --pack moments --runs 20 --crash hard --no-bonus --no-save   # the bare line
    godot --headless --path . -s tools/flight_crash_tune.gd -- --pack moments --runs 10   # contact speeds, for the threshold
    python3 tools/run_tests.py --tests 'test_flight_*.gd'

Stills (these open a window, so only run them when you want to look):

    Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_crash.gd -- --no-title [--station=moments_hall] [--bot=sloppy] [--crashes=2]

## Keys and flags

| Key | Does |
|---|---|
| C | crash off ↔ hard (`any` joins the cycle only if you launched with `--crash=any`). The station starts afresh. |
| T | restart point: checkpoint → ring → entry. The station starts afresh. |
| R, N, B, F1, ... | as before |

| Flag | Study | Bench | Does |
|---|---|---|---|
| `--crash=off\|hard\|any` | yes | `--crash` | `off` (default): bump and recover. `hard`: hard hits crash. `any`: every contact crashes (debug) |
| `--restart=checkpoint\|ring\|entry` | yes | `--restart` | where you fly on from after a crash (default checkpoint) |
| `--crash-speed=<m/s>` | yes | `--crash-speed` | stone's hard threshold (default 8) |

The HUD (F1) has a crash line: off, or the mode, the rule, the restart
point, crashes so far and CRASHED while one plays. The end panel adds
"Crashes N (crash hard, restart at checkpoint) · back to checkpoint N".
When the bench has been run with the same rules, the panel shows the
per-collectible bands for those rules.

## Crash rules (scripts/flight_crash.gd)

This is a layer round RuinBump, which is not changed. Each tick, RuinBump
still bumps the plane out of stone. With crashing on, the run then
re-queries the same body box at the plane's pose from before the bump
(`FlightCrash.contact`). From that it gets:

- the solid's face normal
- the plane's speed into that face: −velocity · normal
- the solid's crash class

`FlightCrash.crashes` decides. A crash is never decided in the 0.3 s grace
after a restart.

- **off**: no layer at all. The code path is the old one, line for line.
- **hard**: each crash class has a threshold. For scenery stone (`stone`),
  that is `HARD` = **8 m/s into the face**. At cruise (14 m/s) that is a
  hit at more than about 35° to the face. At boost (22 m/s) it is more
  than about 21°. Glancing scrapes and skims always bump. A 6° scrape at
  cruise is 1.4 m/s.
- **any**: every contact crashes (debug).

**Per-solid crash classes, the hook for obstacles.** A solid may carry
`"crash": "<class>"`. `FlightCourse.build` puts it on the static body as
meta `crash_class` (default `"stone"`), and `contact` reads it back from
the body that was hit. `CLASSES` holds two classes:

- `stone`: `{hard: 8}`
- `obstacle`: `{hard: 0}`, meaning any touch crashes. It is a placeholder
  that nothing uses yet.

So a later obstacle is just a solid tagged `"crash": "obstacle"`, or a new
class with its own threshold. The test tags a slanted wall as `obstacle`:
the same 1.4 m/s scrape that only bumps on stone crashes there.

**How the threshold was picked** (`tools/flight_crash_tune.gd`: bots fly
with crashing armed but out of reach, and every contact's speed into the
face is logged):

| per run, all 5 stations | contacts | would crash at ≥6 | ≥7 | **≥8** | ≥9 | ≥10 |
|---|---|---|---|---|---|---|
| sloppy | 28.7 | 5.0 | 4.2 | **3.0** | 2.4 | 2.1 |
| decent | 19.3 | 4.5 | 3.9 | **1.8** | 1.5 | 1.2 |
| sharp | 12.4 | 4.5 | 3.9 | **1.4** | 1.2 | 0.9 |
| perfect | 6.5 | 2.8 | 2.6 | **1.1** | 1.0 | 0.6 |

There is a clear knee between 7 and 8. That cluster is the plane
re-touching stone just after a bump: it has dropped to 55% of cruise,
7.7 m/s, and is nose-in. At 8, a scrape and its bounce-back stay a bump,
but any real impact at cruise or faster crashes. Most contacts are under
45°: 0-15° and 30-45° are the big bins.

## Crash feedback (studies/flight_study.gd)

A crash takes 0.7 s from impact to flying (`FlightCrash.HOLD`), then the
view fades back in over 0.2 s while the plane is already flying:

- **0-0.1 s**: a warm white flash (60%), fading.
- **0-0.35 s**: the camera is held where it was and jolts, by up to
  0.45 m, decaying.
- **The plane's figure gives way to a wreck**, a second plane figure. It
  tumbles at 9 rad/s, bounces off the face at 3.5 m/s, keeps a third of
  its speed along the face, and falls.
- **14 greybox debris boxes** fly off the face at about 6 m/s and spin.
  Every third one is plane-red.
- **The last 0.2 s** dim to dark (85%). Then the cut: the chase camera
  resets behind the plane at the restart point, and the view fades in.

The run's clock is stopped during the hold, so run durations don't count
it. The rendered stills (moments_hall, sloppy bot, two crashes,
`/tmp/flight_crash`) read well. The flash, the tumble and the red debris
are clear against the grey stone. The grey debris is lost against grey
stone, and the red pieces carry it.

## Restart points and the challenge

Every restart puts the plane on the station's natural line, at cruise
(14 m/s), heading and pitch along the line. Guides from that point on
stand again, so the line and the bots' route are whole. Free collectibles
already taken stay taken.

| restart | where | a challenge that was on |
|---|---|---|
| **checkpoint** (default) | 2 s (28 m) back along the line from the crash, then further back to the first point ≥ 2 m clear of stone with no knife slit starting within 1 s ahead. If there is none, the entry. | **carries on**: its collectibles taken so far count, and the timer (if any) keeps its time (the hold doesn't count) |
| **ring** | on the line at the starter | **starts afresh**: it is ended as "crash" and immediately started again (a new try, every challenge collectible back). With no challenge on, ring falls back to checkpoint |
| **entry** | the station's entry | **ends** ("crash"): the challenge collectibles go and the starter stands again. Retaking the ring retries it |

The "crash" end shows as "ended: crashed" on the HUD and as "ended, you
crashed" on the panel.

R (restart) is as fast as before. A fresh moments station takes at most
5.7 ms (the test measures every moments station), so it is instant.

## Records

- The run JSON gets events `crash` (`into`, `speed`, `solid`, `at`,
  `line_s`) and `respawn` (`restart`, `at`, `line_s`). Bump events gain
  `into`, `speed` and `solid`, but only with crashing on.
- The run also gets `crash` (the rules), `cuts` (the tick rows where the
  plane jumped to a restart point) and `result.crashes`.
- Metrics: `crashes`, `crash_into`, `crash_restarts` and `crash_spots`.
  The flown turn and pitch rates and the flow numbers skip the jump at
  each cut, so a restart isn't read as a 3 rad turn.
- `station_hash` is tagged, for example `bebd38402d9e:crash-hard-checkpoint`,
  or `...:crash-hard@6.0-checkpoint` with a non-default threshold. So crash
  runs pile up apart from bump-and-recover runs in `flight_report.py`, and
  bands.json keys them `<id>:<tag>`. The station's own hash is unchanged.
- The bench with crashing on writes no run files, only the bench summary
  and the tagged bands. That keeps the bump-and-recover record clean. I
  saved hard/checkpoint, hard/ring, hard/entry and any/checkpoint, so the
  end panel has bands for those.
- The bot (still VERSION 2) forgets its state after a restart and picks
  the line up again. It gives up a moment it has crashed going for twice
  (`GIVE_UP`). This stands in for a person learning. Without it, the
  deterministic perfect bot crashed into the same column every pass until
  the 40 s time limit.

## The bench: off vs hard vs any (moments pack, 20 runs, perfect = 5 look-aheads)

**With crash off, the whole bench is byte-identical to before.** I benched
every station (`--station all`, 160 lines of tables) on 327c93e7 and on
this branch, and diff found no change.

Challenge completed (sl/de/sh/pf) and crashes per run:

| station | off: completed | hard·checkpoint: completed / crashes | hard·ring | hard·entry | any·checkpoint |
|---|---|---|---|---|---|
| hall | .10/.15/.80/.80 | .10/.45/.85/.80 · 5.4/1.8/1.8/0.6 | .00/.50/.60/.80 · 5.7/1.9/2.6/0.6 | .00/.20/.55/.80 · 6.3/3.3/2.3/0.6 | .10/.30/.60/.40 · 7.3/4.3/4.0/5.6 |
| bend | .10/.30/.75/1 | .20/.50/.70/1 · 5.0/3.4/3.2/2.2 | .00/.15/.30/1 · 3.9/3.7/3.5/2.2 | .00/.05/.25/.60 · 2.3/2.2/2.0/1.6 | .10/.60/.50/1 · 7.0/4.4/4.2/4.0 |
| cave | .10/.60/.80/1 | .05/.65/.80/1 · 2.6/1.6/0.3/0 | .05/.70/.80/1 · 4.0/1.7/0.2/0 | .00/.45/.75/1 · 2.9/1.6/0.3/0 | .10/.15/.25/1 · 7.4/5.7/4.7/3.8 |
| pierced | .05/.25/.95/1 | .00/.15/1/1 · 1.4/0.9/1.0/1.0 | .05/.15/1/1 · 1.7/0.8/1.0/1.0 | .00/.25/1/1 · 1.3/0.8/1.0/1.0 | .00/.15/.30/0 · 3.6/2.4/3.0/3.0 |
| crest | .05/.40/.60/1 | .10/.35/.85/.80 · 2.9/2.6/1.9/1.6 | .00/.20/.40/.20 · 3.9/3.8/3.1/2.4 | .00/.20/.25/0 · 2.6/2.4/2.3/2.4 | .00/.20/.40/0 · 4.9/4.4/3.7/5.0 |

Free collectibles got barely move between off and hard·checkpoint
(within ±0.5 of 3 everywhere; bend's perfect bot drops from 3.0 to 2.6, giving up the column-side react). Runs that ran out of the 40 s limit,
sl/de/sh/pf:

- hard·checkpoint: never above 0.10.
- hard·ring: bend .90/.85/.75/0, crest .30/.40/.45/.40.
- hard·entry: hall 1/.50/.35/0, bend 1/.90/.90/.60, crest .65/.65/.70/1.

**How the bands shift** (per collectible, off → hard·checkpoint):

- **Hall**: all three challenge collectibles go hard → medium. Decent's
  completion triples (.15 → .45).
- **Bend**:
  - the free react behind the column as the hall turns: medium → expert
    (.45/.55/.45/.60)
  - challenge reach: hard → medium
  - challenge fit: medium → easy
- **Cave**: the free react goes medium → easy. Everything else holds.
- **Pierced**:
  - challenge reach under the keel: medium → hard
  - challenge react over the veil: medium → easy
- **Crest**: no band changes.

Under ring and entry, more collectibles reach expert or none: bend's and
crest's late challenge reach, and crest's challenge reach under entry
becomes none. That is mostly the 40 s limit cutting runs short, not the
collectible.

Under **any**, the bands spread: cave's challenge fit becomes expert, and
pierced's rim fit and bend's free react become none. Even the perfect bot
crashes 3-5.6 times a run, mostly on knife slits and fit moments whose
whole point is to brush stone.

### Where the bots crash, and whose fault it is

| station | hot spots (line s at cruise, hard·checkpoint) | what is there |
|---|---|---|
| hall | 10.0 (x47), 2.5-4.5 (x94) | B's knife slit (challenge fit); the first high tie and the free fit skimming the nave's middle column |
| bend | 12.0 (x64), 14.0-14.5 (x101), 15.5 (x36) | challenge fit between a column and the wall (0.05 m room); the free react low behind a column; challenge reach high left |
| cave | 9.0 (x39), 12.5 (x26) | the free fit skimming the second pinnacle (knife); the free react back inside (knife) |
| pierced | 4.5 (x58) | the free fit up in the tunnel's corner |
| crest | 8.5 (x54), 11.5-12.0 (x52) | the third slit gate (challenge fit, knife); challenge react up on the left under the roof |

**The control: bots that ignore the moments and only fly the natural line
(`--no-bonus`) almost never crash.** Crashes per run with hard·checkpoint:

| station | sl/de/sh/pf |
|---|---|
| hall | 0.05 / 0 / 0 / 3.4 (one perfect look-ahead cuts the middle column at 3.5 s) |
| bend | 0 / 0 / 0 / 0 |
| cave | 0.25 / 0 / 0 / 0 |
| pierced | 0.10 / 0 / 0 / 0 |
| crest | 0 / 0 / 0 / 0 |

So the line itself is crash-free. The crashes come from going for
collectibles placed against stone, in two ways:

1. **Crude bot grabs (most of it).** The bot beelines at a moment by pure
   pursuit, with a deliberate aim error (`grab_aim`), and doesn't plan a
   way back out. Moments with 0.02-0.3 m of fit (bend's column-and-wall
   fit, the tunnel corner, the hall's middle column) get hit nose-first at
   about 12 m/s. A person would curve into them, or brake.
2. **Bot knife-edge timing.** The hall's B slit, crest's third slit gate
   and the cave's pinnacle are knife moments. The bot's lean comes from
   the jitter, lead and forget numbers, so a late or forgotten roll hits
   the slit's jamb head-on. Under bump and recover that was a scrape
   through. Under hard it is a crash.

So the bots' high crash counts are about how they grab, not the course.
Even the perfect bot crashes 1-2 times a run on bend, crest and pierced,
so those spots are tight for anyone aiming straight at the collectible.

## Surprises

- **Crashing with a checkpoint is kinder than bumping for the bots.** In
  bump and recover, a sloppy bot pinned on the hall's stone bumps 60 times
  a pass, at 55% speed each time. A checkpoint puts it back on the line at
  cruise. Decent's hall completion rises from .15 to .45. A crash that
  costs 0.7 s plus 2 s of line can cost less than grinding along a wall.
- **The threshold's knee is the plane's own bump speed.** After a bump the
  plane is at 7.7 m/s (55% of cruise). Re-touching stone nose-in at that
  speed is the biggest single cluster of contacts. A threshold under that
  turns every scrape into a crash a tick later.
- **Ring and entry interact badly with the 40 s run limit.** Every crash
  replays the station from the ring or the entry, so a pilot who keeps
  crashing at the same late spot runs out of time. That is the Trackmania
  loop, but the study's limit cuts it off. For a person it would be a
  retry loop, and the run records tries.
- **Deterministic bots loop forever without learning.** Hence `GIVE_UP`.

## Unverified

- **Nobody has flown it.** Whether a 0.7 s crash plus a 2 s checkpoint
  feels like Trackmania or Celeste rather than a punishment is the real
  question. So is whether the 8 m/s line matches the user's sense of
  "hard".
- **How the crash looks, from 10 stills only** (hall, sloppy bot). I
  haven't judged it in motion: the jolt's frequency, whether the dim
  before the cut is too dark, and whether 0.7 s is too long or too short.
  No sound.
- **The checkpoint rule** (2 s back, 2 m clear, no slit within 1 s) was
  only checked on the test lane and in the benches. On a station that
  loops back on itself, the nearest-line search could put a checkpoint on
  the wrong lap. That only happens when the plane is more than 12 m off
  the line.
- **The `obstacle` class** has only been exercised in the test. No solid
  uses it yet.
- **Knife zones and bonus tokens after a restart** keep their first-pass
  state. A slit already passed isn't re-tracked in the knife metrics.
- **Tests run**:
  - the headless import check
  - `python3 tools/run_tests.py --tests 'test_flight_*.gd'`: 8 of 8 pass,
    including the new `test_flight_crash.gd`
  - the off bench on every station, identical to 327c93e7
  - the four crash benches on the moments pack, plus the `--no-bonus`
    control

  I did not run the full suite. The user's 59 `_human_` run files were
  md5'd before and after (b55d510405f79492f188e9d154b95824, unchanged).

## Suggested next round

1. **Fly `./run-flight-crash.command` and rate it next to
   `./run-flight-moments.command`.** Say whether crashes make the fit
   moments feel more like skill, or just make them scary. Try
   `--crash-speed=6` and `10` to bracket "hard".
2. **Pick the restart.** Checkpoint is the gentlest and the bench's
   favourite. Ring is the cleanest "retry the challenge". If ring wins,
   drop the 40 s limit for crash runs, or end on N tries.
3. **Teach the bot to curve into a moment** (aim for a point past it along
   a smooth arc, then brake near stone) before reading much into
   crash-on bands. Today most crashes are the bot's beeline.
4. **Tag the first real obstacles** (`"crash": "obstacle"`) when they
   arrive. The hook is in place. For the sky world, the same layer would
   sit round the world's RuinBump call, with the class on the ruin bodies.

## Files

- New:
  - `scripts/flight_crash.gd`: rules, classes, thresholds, contact and
    tags.
  - `tools/flight_crash_tune.gd`: contact speeds per threshold.
  - `tools/capture_flight_crash.gd`: rendered stills.
  - `tests/test_flight_crash.gd`.
  - `run-flight-crash.command`.
- `scripts/flight_run.gd`: `set_crash`, `_crash_tick`, `_crash`,
  `_checkpoint`, `_nearest_line`, the hold, the record. With crash off the
  old path runs unchanged.
- `scripts/flight_course.gd`: `build` puts each body's crash class in its
  meta.
- `scripts/flight_metrics.gd`: `crash()`, and `cuts` in `rates`,
  `swing_rates` and `flow` (an optional argument, empty by default).
- `scripts/flight_bot.gd`: forgets its state after a restart, and
  `GIVE_UP`.
- `tools/flight_bench.gd`: `--crash`, `--restart`, `--crash-speed`,
  `crash_stats`, `crash_table`, crashes in the moments table, and tagged
  bands.
- `studies/flight_study.gd`: flags, C and T, the crash playing, HUD and
  panel.
- RuinBump, the sky world, `cozy_worlds` and the sky layout are untouched.
