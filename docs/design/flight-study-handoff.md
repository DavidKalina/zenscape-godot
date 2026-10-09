# Flight study handoff (round 1)

Branch: `study/flight-harness` (from main ce50f324). This is a greybox harness
for finding out which kinds of flying set piece you want before any more kits
get built. Eight hand-placed stations are flown in the game's own plane, by
you or by CPU pilots of four skills. Every run is recorded, measured and saved
so the data builds up across sessions. Plane only. It doesn't touch the game:
all new files, no hooks.

## Launch

    ./run-flight-study.command
    godot --path . res://studies/flight_study.tscn -- --no-title [--station=slalom] [--bot=sharp]

Bench (headless, about 7 s for all stations at 20 runs):

    godot --headless --path . -s tools/flight_bench.gd -- --station all --runs 20
    godot --headless --path . -s tools/flight_trace.gd -- hidden_turn decent 3   # why runs went as they did
    python3 tools/flight_report.py --open                                         # HTML + markdown + CSV

Tests: `python3 tools/run_tests.py --tests 'test_flight_*.gd'`.

## Keys

| Key | Does |
|---|---|
| WASD / left stick | turn and pitch (W noses down, as in the game) |
| Space / RT | boost |
| Shift / LT | brake |
| Q E / shoulders | held: knife edge; double-tap: barrel roll |
| mouse / right stick | look round (the game's chase camera) |
| 1-9 | teleport to a station's entry, at cruise, heading in |
| R | restart the station |
| N | next station |
| B | switch pilot: you → sloppy → decent → sharp → perfect bot |
| F1 | live numbers |
| Esc | free the mouse |
| after a station: 1-5 | felt difficulty, then 1-5 fun (Enter skips) |

Your input goes through the same dict the wanderer fills
(`scripts/wanderer_eye.gd` `_fly_input` and `_plane_input`). The bot fills the
same dict. Both go through `SkyPlane.step` and then `RuinBump.bump`, which is
the same step and bump-and-recover as the game's plane against the Sundered
hall.

## Files

- `scripts/flight_course.gd`: the stations as data, their solids, signed
  distances, the per-gap room, the station hash, and building the colliders.
  The colliders sit on the ruins' layer.
- `scripts/flight_run.gd`: one run, which steps the plane, takes and misses
  tokens, tracks what has been seen, records each tick and gives live numbers.
- `scripts/flight_metrics.gd`: pure functions (data in, data out) for the
  line, the needs, warnings, reversals, effort, demand, curve, band and slack.
- `scripts/flight_bot.gd`: the CPU pilot.
- `scripts/flight_log.gd`: the JSON files and `bands.json`.
- `studies/flight_study.gd/.tscn`, `run-flight-study.command`: the study scene
  and its launcher.
- `tools/flight_bench.gd`, `tools/flight_trace.gd`, `tools/flight_report.py`.
- `tests/test_flight_metrics.gd`: fake runs with known answers.
- `tests/test_flight_bench.gd`: the sharp bot clears the gentle arc, a
  replay matches, and save/read and bands work.
- `tests/test_flight_study.gd`: a scene smoke test.

## Stations

Each station is `{id, key, name, intent, parts, tokens}` in local metres. The
entry is at local 0,0,0, the plane flies north (-Z) at 14 m/s, and the floor
is 40 m below. Stations stand 260 m apart along x. Parts are `box`, `pillar`,
`gate` (posts, lintel and sill) and `ring` (12 boxes). The intent field is my
guess at a band and is never used to judge anything. A later round can
generate stations by emitting the same dictionary.

| Key | id | What |
|---|---|---|
| 1 | gentle_arc | 8 tokens on a 90° right curve of about 40 m radius; two pillars off the line |
| 2 | slalom | 9 tokens weaving ±4.5 m round 4 pillars 24 m apart |
| 3 | hidden_turn | an 8 m lane up the side of a deep block; at its end the line hooks 90° west behind the block, out of sight until the lane's end |
| 4 | tight_slot | a 2.4 m slot between two walls, offset 6 m east (level wings clear 0.5 m a side) |
| 5 | climb_rings | 5 rings of 3.5 m radius climbing 21 m over 64 m |
| 6 | dive_arch | a 37 m dive under a floor arch with an 8 × 5 m opening, then a pull up |
| 7 | open_swoop | a wide 3D S-curve with no obstacles near it |
| 8 | mixed_spike | 4 easy tokens in a straight line, one spike 7 m east and 2 m up within 10 m, then 3 easy tokens |
| 9 | sundered | round 2: a greybox stretch of the Sundered hall (below) |

Tokens use the game's plane pickup: `PLANE_REACH` 1.1 plus half an air token
(1.2 m), so 1.7 m. Tokens are greybox spheres. Taking a later token misses the
earlier standing ones. A token also counts as missed once the plane is 3 m past
it, along the line's direction there. A run ends when every token is taken or
missed, after 40 s, or when the plane gets 120 m from the next token.

## Recorded data

Each run is one JSON file in `user://flight_runs/`. On macOS that's
`~/Library/Application Support/Godot/app_userdata/ZenScape — Landscape Sandbox/flight_runs/`.
The path is printed when the run is saved. Each file holds:

- `format`, `station`, `station_hash`, `station_name`, `intent`
- `pilot` (`human` or `bot:<skill>`), `skill` (the bot's parameters,
  including `version`), `started` (UTC)
- `entry`, `tokens`, `reach`, `span`, `rooms`
- `ticks`, stored as columns: `t`, `x y z`, `heading`, `pitch`, `bank`,
  `speed`, `in_turn`, `in_pitch`, `in_boost`, `in_brake`, `in_lean`,
  `in_roll`, `bump`
- `events`: token `seen`, `hit` or `miss`, and `bump`, each with a time
- `result`, `metrics` (below) and `rating` (`difficulty` and `fun`, 1-5;
  human runs only)

`station_hash` is the md5 of the parts, tokens, reach and format version. It
doesn't depend on git, so runs on the same layout pile up, and any change to a
layout starts a new record. `bands.json` keeps each station's latest bench
band under its hash. The study's end-of-run report shows that band only when
the hash matches.

## Metrics (`scripts/flight_metrics.gd`)

A gap is the leg into a token: gap 0 runs from the entry to token 0, and gap g
from token g-1 to token g. The line is a centripetal Catmull-Rom curve through
the entry and the tokens, sampled every 0.5 m. It starts with a 10 m straight
lead-in along the entry heading.

- **duration**: entry to end, in seconds. **tokens**: collected / total.
  **cleared**: every token taken. **bumps**: how many times the plane hit a
  solid.
- **turn demand (need)**: the line's yaw rate at CRUISE 14 m/s, smoothed over
  0.2 s of flight, divided by TURN_RATE 1.6. Given as peak and
  length-weighted mean. **pitch demand** works the same way against
  PITCH_SPEED 1.4. These depend only on the course, not on who flies it.
- **flown turn and pitch**: the run's actual heading and pitch rates over the
  same limits, as peak and mean.
- **warning**, per token: warning = commit − first seen, where
  commit = reached − (turned / TURN_RATE + pitched / PITCH_SPEED + ROLL_IN).
  - turned and pitched are the gap's total radians on the line.
  - ROLL_IN is 0.32 s, which is two of the plane's EASE_ROLL_IN, added only
    if the gap turns at all.
  - Seen means the token is within 40° of the direction of travel and 160 m,
    with a clear physics line to it.
  - A token never seen counts as seen on arrival, so its warning is −commit.
  - The warning is clamped to [−commit, 10] s.
- **reversals per second**: sign changes of the turn input and of the pitch
  input past a 0.2 deadzone.
- **effort**: stick travel per second (|Δturn| + |Δpitch|), plus the share of
  ticks with either input past 0.8.
- **room**, per gap: the line's least clearance to any solid (signed distance)
  minus half the wingspan (0.7 m), capped by the 1.7 m reach.
- **gap demand**: demand = 0.5 · max(turn, pitch) + 0.25 · hurry + 0.25 · tight
  - turn and pitch are the gap's peaks as shares of the limits, clamped to
    0..1.5.
  - hurry = (1 − clamp(warning / 1.5 s)) · clamp(commit / 1.0 s), so it's 0
    when there's nothing to swing for.
  - tight = 1 − clamp(room / 2.0 m).
- **demand_peak / demand_mean / demand_spike**: the largest gap demand, the
  time-weighted mean, and the peak minus the median gap. A lone hard moment
  shows up as a large spike.
- **grade**: the peak demand graded as under 0.35 easy, 0.55 medium,
  0.75 hard, otherwise very hard. It's a guess. The bot band is the
  measured label.
- **demand curve**: every 0.25 s, a row of [t, gap demand, flown turn share,
  flown pitch share, stick held].
- **live slack** (F1): distance / speed − (|heading error| / TURN_RATE +
  |pitch error| / PITCH_SPEED + ROLL_IN) to the next token, once it's seen.

The weights and easy ends are a first guess. Calibrate them against your
ratings once a few dozen rated runs exist. They're filters and target ranges,
never things to maximise (`generation-harness.md`).

## Bots (`scripts/flight_bot.gd`, VERSION 1)

The bot uses pure pursuit. It aims at the point `look` metres ahead along the
path from itself through the tokens it knows. It knows a token once that token
has been in view for `reaction` seconds; the perfect bot knows them all. It
steers from its own pose as it was `lag` seconds ago. Its stick drifts with
slow random noise of size `noise` (half as much in pitch), and `gain` sets how
hard it corrects. With `brake` on, it brakes when the next token is more than
0.6 rad off its nose and within 30 m. It doesn't dodge, use the knife edge or
roll.

| skill | reaction s | lag s | look m | noise | gain | brake |
|---|---|---|---|---|---|---|
| sloppy | 0.45 | 0.12 | 4 | 0.12 | 2.0 | no |
| decent | 0.30 | 0.08 | 6 | 0.08 | 2.6 | yes |
| sharp | 0.18 | 0.04 | 8 | 0.03 | 3.2 | yes |
| perfect | 0 | 0 | best of 3, 5, 7, 9, 12 | 0 | 3.5 | yes, knows all |

**Band** = the least skill that clears the station (takes every token) in at
least 60% of its runs. The bands are sloppy → easy, decent → medium,
sharp → hard, perfect only → expert, and none → broken.

## First bench (20 runs per skill, VERSION 1)

| station | intent | band | clear rate (sloppy/decent/sharp/perfect) | ref time s | demand peak | mean | spike | warning min s | room min m |
|---|---|---|---|---|---|---|---|---|---|
| gentle_arc | easy | **easy** | 0.75 / 1.0 / 1.0 / 1.0 | 6.22 | 0.20 | 0.17 | 0.03 | 0.73 | 1.70 |
| slalom | medium | **medium** | 0.0 / 1.0 / 1.0 / 1.0 | 8.07 | 0.63 | 0.55 | 0.09 | 0.11 | 1.70 |
| hidden_turn | hard | **hard** | 0.0 / 0.1 / 1.0 / 1.0 | 6.78 | 0.71 | 0.33 | 0.40 | 0.33 | 1.70 |
| tight_slot | medium | **medium** | 0.2 / 0.7 / 1.0 / 1.0 | 5.37 | 0.32 | 0.23 | 0.04 | 0.28 | 0.41 |
| climb_rings | medium | **easy** (wrong band) | 1.0 / 1.0 / 1.0 / 1.0 | 8.10 | 0.28 | 0.14 | 0.16 | 0.58 | 1.70 |
| dive_arch | medium | **medium** | 0.5 / 1.0 / 1.0 / 1.0 | 6.50 | 0.51 | 0.33 | 0.20 | 0.18 | 1.35 |
| open_swoop | easy | **easy** | 0.8 / 1.0 / 1.0 / 1.0 | 9.33 | 0.24 | 0.18 | 0.07 | 0.35 | 1.70 |
| mixed_spike | hard | **hard** | 0.0 / 0.1 / 1.0 / 1.0 | 6.68 | 0.79 | 0.38 | 0.29 | 0.72 | 1.70 |

The "ref" columns come from the perfect bot's best run.

Being honest about how the bands were reached:

- The first layouts of hidden_turn and mixed_spike both read **medium**:
  decent cleared them every time. The first hidden turn could be seen round
  the end of a thin wall, and the first spike was too gentle (6 m over 12 m).
  I tightened both once: the hidden turn is now a deep block with the hook
  close behind it, and the spike is 7 m over 10 m. The bands above are for
  the tightened versions.
- climb_rings is meant to be medium but is easy. Even sloppy clears it 100%
  of the time, because pitch is forgiving (it has no bank lag) and the rings
  sit in a straight line.
- Several clear rates sit near the 60% line, so bands there can flip between
  benches: tight_slot (decent 0.7), dive_arch (sloppy 0.5), and gentle_arc
  and open_swoop (sloppy 0.75–0.8). At 5 runs they did flip, so use 20.
- No station reads expert or broken, so nothing yet needs the perfect bot
  alone.

## Surprises

- **The spike's hard part is the way out.** In mixed_spike the decent bot
  usually takes the spike token and then misses the next one. It overshoots
  coming back, so the difficulty sits in the recovery gap, not the spike gap.
- **Wall scrapes in the slot.** When a bot misses the slot entrance,
  bump-and-recover (`RuinBump`) turns the plane along the wall's face. The bot
  keeps steering at the token behind the wall, so it scrapes along the face
  for up to 5 s (30 bumps) before it gives up the token. A player holding into
  a wall gets the same. Something to check in the game feel.
- **The tight slot reads easy on demand but medium on bots.** Its demand peak
  is only 0.32, because the room weight (0.25) is small next to turn. The bots
  find it harder than the score says, so the room weight is probably too low.
- **The line's turn need can exceed 1.0.** mixed_spike's need peaks at about
  2.2 × TURN_RATE on the exact curve, yet sharp clears it, because the 1.7 m
  reach lets you cut the corner. Read need above 1 as "you must cut", not
  "impossible".
- **The first gap always reads hurried.** It is short (12 m, about 0.75 s from
  spawn), but needs nothing, so the commit weighting keeps its demand near 0.

## Unverified

- **The study scene has not been looked at.** No window was opened. These are
  untested in a real renderer: the F1 bar drawing, the report panel layout,
  the grid look at this scale, the chase camera framing and the Label3D signs.
  The headless smoke test steps the scene, ticks it, saves runs and records
  ratings, but the dummy renderer never calls the `draw` callback.
- **Keyboard and pad input haven't been tried by hand.** The double-tap roll,
  the lean and the look use the same actions as the game, but I haven't
  pressed them.
- **No human runs exist yet.** The demand weights have no ratings to be
  checked against.
- I ran the import check and the three new tests only (all pass), not the full
  suite, as asked.

## Known gaps

- The bot is analog, but many people fly with keys (bang-bang ±1). Add a
  "keys" bot that quantises its stick so those bands mean the same thing.
- Bots never use the knife edge, boost or rolls. No station needs them yet.
- "Seen" is a cone from the direction of travel, not the camera's real view.
  The chase camera sits behind and above, so a person may see a bit more.
- Bumps don't fail a run. They show only as counts and lost time.
- A missed token stays missed. You can't loop back for it.
- The live demand curve in F1 is the line's demand with no warning term (the
  run's warnings aren't known until it ends). The saved curve includes them.
- Bands are per bot version. Change `SKILLS` or the steering and bump
  `VERSION`; the report keeps versions apart.

## Suggested round 2

1. Fly every station a few times and rate them. Then fit the demand weights
   (and the grade cuts) to your felt difficulty. A tiny regression over
   `flight_runs.csv` is enough.
2. Add a keyboard-quantised bot. Fix the room weight if the slot keeps
   reading too easy.
3. Write a station generator that outputs the same dictionary: parametric
   arcs, slaloms, slots, rings and spikes. Run the bench over N variants and
   keep only those inside the target ranges (band, duration, spike).
4. Add more kinds: knife-edge slots under wingspan, boost straights, barrel
   roll gates, and two-way forks (choice).
5. Cluster on the CSV columns (need, warning, room, spike, duration) to name
   section types. That data then feeds the set-piece kits and the common
   set-piece interface in `generation-harness.md`.

# Round 2: the Sundered hall station and threading

After flying all eight, the user liked climb_rings best (easy, fun 4): it's
more fun going through things than flying in the open, as with threading
cliffs, coves and openings in the real world. The open-air stations rated
fun 2. Round 2 adds a station that flies like the Sundered hall
(`docs/scenic/sundered-hall.md`) and a number for "going through things".

## Launch straight into it

    ./run-flight-study.command --station=sundered
    ./run-flight-study.command --station=sundered --bot=sharp      # watch a bot fly it
    godot --headless --path . -s tools/flight_bench.gd -- --station sundered --runs 20

Key 9 jumps to it in the study, and N cycles through it after mixed_spike.

## The station (`sundered`, key 9, hash 72a9caa4ed86)

A new part kind, `["bay", at, yaw, plan]`, is one bay of the hall's nave at
the real dimensions from `scripts/ruin_kit_hall.gd`: BAY 8 m, outer
columns at ±9.4 m (r 1.2, 10 m tall), walls at ±12.4 m, roof beams at the
bay lines (10-11.1 m), slabs over them in six strips, ties with soffits at
4 m (low) and 6 m (high), inner columns at 0 or ±2.6 m, the lane (z 4-8,
y 1-3.6) and the knife-edge screen (a 1.15 m slit). The plan keys are
documented on `FlightCourse._bay` and are the same words the real planner
uses (`roof` whole/broken/open, `gaps`, `tie`, `inner`, `breach`, `screen`,
`torn`, `beam`, `last`), so a generator can emit bays. The hash covers
only this station's own data; stations 1-8 keep their hashes (pinned in
`test_flight_metrics.gd`).

The real hall is 9-10 pieces and about a minute. I took four of its acts
and squeezed them into two pieces, about 166 m of line (12.7 s for the
perfect bot):

- **Piece A, 8 bays (gate, shafts, cloister):** in through the gate's
  roofed mouth. A low tie is flown under, then the line climbs over a high
  tie (5.9 m up, 1.3 m over the tie, 1.8 m under the beam), under broken
  roof. Then come two open cloister bays. The line jinks right between the
  row's columns at mid-bay, over a low breach in the right wall, and out
  past the torn end.
- **Gap:** 22 m, stepping down 5 m (a short drop; the real hall's are
  12-30 m with ±5 m steps, and its drop is 34-40 m and 8-11 m down).
- **Piece B, 6 bays (slit, apse):** it starts with a torn mouth. Next come
  screens with knife-edge slits on the left every other bay, paired inner
  columns, a low tie and high ties. The lane runs open on the right. Then
  the apse: two open bays, and the line climbs 13 m out through the open
  roof to the sky.

16 tokens. Their trail goes in at the gate, along the nave, out the side
breach, across the gap, along B's lane and out through the roof.

Simplified, on purpose:

- Plain boxes and drums. There are no gables, lancets, doors, buttresses,
  fallen beams, rubble, parapets, islands or podium edges.
- Torn and open walls have one height each (3 m and 7.5 m).
- The hall is straight. The real pieces curve (radius ≥ 70 m) and kink
  ≤ 0.14 rad at gaps.
- **B sits 8 m right of A** so the line out of A's side breach runs
  straight on into B's lane. My first layout put B in line with A, and the
  hard swing back left after the breach lost every bot below perfect, with
  long wall scrapes in B.
- **No token goes through a slit.** The bot has no knife edge, and a
  missed token can't be skipped (taking a later token misses it), so a
  slit token would make the station unclearable for bots. The slits stand
  there for a person to try. A knife-edge bot and an optional-token rule
  are for a later round.
- The aqueduct act, the long drop and the nave's side arches aren't in.
  Arches are in the part kind (`breach` "arch") but unused.

### Bench (VERSION 1 bots, 20 runs)

| station | intent | band | clear rate (sloppy/decent/sharp/perfect) | ref time s | demand peak | mean | spike | warning min s | room min m | threading | openings/s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sundered | hard | **hard** | 0.0 / 0.1 / 0.9 / 1.0 | 12.65 | 1.11 | 0.45 | 0.70 | -0.06 | 0.40 | 40% | 0.24 |

What makes it hard is one moment: **the jink out through the side
breach.** The line has to cross the row of columns between two bay lines
(8 m apart, 5.6 m clear) and the wall within about 6 m. That's about a
40° swing with 0.4 m room either side of the wings, and the line's need
is 1.47 × TURN_RATE. Decent bots take 15 of 16 tokens almost every time.
They bump a column there and miss the token at the crossing or the one
after it. Sharp bots bump once and clear 90% of the time. Every other part
is medium at most: the tie hop needs about 1.7 × PITCH_SPEED on the exact
line, but pitch is forgiving, and every bot from decent up takes it.
These are the real hall's own breach dimensions. If the user finds it too
hard, the fix is in the layout: a wider breach bay, or a fallen column at
that bay line. Don't fix it by tuning the bot.

## Threading metric (`FlightMetrics.threading`, `threading_at`)

- **Rule:** a tick threads when a solid lies within **8 m both left and
  right** of the plane (level rays square to its heading), or within
  **12 m straight above** it (a roof, a lintel, a tie, a ring's top). The
  rays are tested exactly against the station's boxes and upright
  cylinders. Downward rays aren't cast, so neither the floor 40 m down nor
  a hall's own floor counts.
- **threading_share** = threading ticks / all ticks. **threading_s** =
  share × duration.
- **openings** = spells of threading, with spells less than 0.2 s apart
  joined, so each ring, gate, slot or roofed stretch counts once.
  **openings_per_s** = openings / duration.
- It goes into the run JSON's `metrics` (`summarise(run, solids)`; run
  files from now on carry it). It shows on the F1 overlay ("threading
  NOW / open air", share so far, openings and their rate), on the
  end-of-run panel, in the bench table (`thread`, `open/s`, perfect bot)
  and in `tools/flight_report.py`. There it appears in the overview (the
  people's mean, the reference), in the per-station bot and people tables,
  and in a **Threading vs fun** table of every rated run with Pearson r.
- **Backfill works.** `tools/flight_threading.gd` (headless) reads every
  run without the numbers. For each one whose station hash still matches,
  it measures threading from the recorded ticks and writes
  `threading_backfill.json` next to the runs. The run files are only read,
  and the user's human runs are unchanged (checked byte for byte against a
  copy). `flight_report.py` runs it by itself when it finds runs without
  the numbers and Godot is found (`GODOT_BIN`, `~/Applications/Godot.app`
  or `godot` on PATH). `--no-backfill` skips it. Runs of changed layouts
  are listed as stale and left out.

### Threading vs the user's ratings (9 rated runs, backfilled)

| station | threading | openings/s | felt difficulty | fun |
|---|---|---|---|---|
| gentle_arc (×2) | 0% | 0.00 | 2, 1 | 3, 3 |
| slalom | 0% | 0.00 | 3 | 2 |
| open_swoop | 0% | 0.00 | 1 | 2 |
| mixed_spike | 0% | 0.00 | 4 | 2 |
| dive_arch | 2% | 0.15 | 3 | 3 |
| climb_rings | 5% | 0.61 | 1 | **4** |
| tight_slot | 10% | 0.18 | 1 | 3 |
| hidden_turn | 27% | 0.14 | 2 | 3 |
| sundered | not flown yet | | | |

The reference shares (perfect bot) are about the same: hidden_turn 28%,
tight_slot 10%, climb_rings 5%, dive_arch 3%, the rest 0%, and sundered
40%.

Pearson r with fun over these 9 runs: **openings/s 0.80**, threading share
0.32. On this little data, how often you pass through something tracks fun
better than how long you spend enclosed. climb_rings has the least time
inside (the rings are 1 m thick) but by far the most openings a second.
hidden_turn's 8 m lane reads as a long threaded stretch but rated only 3.
All four 0% stations rated 2 or 3. It's one person and nine runs, so read
it as a hint. Sundered's ratings will be the real test: 40% share but only
0.24 openings/s, because the roofed nave is one long spell. If it rates
high, the share matters too. If it rates middling, count bay lines, ties
and columns passed as openings, not just the spells.

## Files changed

- `scripts/flight_course.gd`: the `bay` part, `_bay`, the `sundered`
  station.
- `scripts/flight_metrics.gd`: `ray_hits`, `threading_at`, `threading`,
  and `summarise(run, solids)`.
- `scripts/flight_run.gd`: the live threading and the solids passed to
  summarise.
- `studies/flight_study.gd`: F1 and the report line, keys 1-9.
- `tools/flight_bench.gd`: the threading columns.
- `tools/flight_threading.gd`: new, the backfill.
- `tools/flight_report.py`: the threading columns, the threading-vs-fun
  table and the auto backfill.
- Tests: `test_flight_metrics.gd` (hashes 1-8 pinned; threading on a fake
  run with walls, a lintel and a lone pillar) and `test_flight_bench.gd`
  (the hall stands, sharp clears it in 10-20 s, threads > 25%).

## Unverified (round 2)

- **No window was opened.** The hall greybox, the chase camera inside the
  nave (it pulls in off solids, but 177 of them in a narrow nave are
  untested), the F1 line and the taller panels haven't been seen.
- **Nobody has flown the station by hand yet**, so it has no fun rating.
- The knife-edge slits are physically there (1.15 m), but nobody has
  threaded them. No token rewards them.
- I ran the import check and `run_tests.py --tests 'test_flight_*.gd'`
  (3/3 pass) only, not the full suite.
- The first round-2 commit's bench test reads `threading_share`, which
  only lands in the second commit. Check out both together.

# Round 3: flow, and a hall built for it

The user: "I like it when there's continuous movement. I don't like it when
you go straight for a bit and then you go up and then you go straight for a
bit and then you go down... Continuous movement is the way to go, so the
levels need to be designed [for it]." Measured on `sundered`'s perfect line,
29% of the run is flying straight, and only 43% of the swing is sideways.
The rest is pitching over and under ties, with flats in between, which is
the step feel. Round 3 adds a number for this and a second hall built
round a line that doesn't settle.

## Launch

    ./run-flight-study.command --station=sundered_flow        # key 0
    ./run-flight-study.command --station=sundered             # key 9, unchanged, for A/B
    godot --headless --path . -s tools/flight_bench.gd -- --station sundered,sundered_flow --runs 20
    python3 tools/flight_movement.py --station all --timeline # where the straights are, per run

## Flow metric (`FlightMetrics.flow`, `swing_rates`)

Flow is read off the flown direction (the heading and pitch in the ticks),
not the stick, so stick noise the plane doesn't follow doesn't count.

- **swing** (deg/s): how fast the flight direction swings. The change of
  heading and of pitch over the last **0.25 s** (`FLOW_SMOOTH`), divided by
  that time, combined as sqrt(yaw² + pitch²). It's measured over less time
  at the start, and is 0 on the first tick.
- **still_share**: the share of ticks swinging under **6 deg/s**
  (`FLOW_STILL`), which is flying straight. A curve wider than about 130 m
  at cruise reads as straight. A steady climb at a fixed pitch is straight
  too.
- **straights**: still spells of **0.5 s** or more (`FLOW_STRAIGHT`).
  **longest_straight**: the longest still spell, in seconds. A spell runs
  from its first calm tick to the first tick that isn't calm.
- **swing_mean** (deg/s), and **yaw_share** = Σ|yaw rate| / (Σ|yaw| +
  Σ|pitch|), the sideways share of the swing.
- **swing_reversals_per_s**, the jerkiness guard: sign changes of the yaw
  rate and of the pitch rate past **10 deg/s** (`FLOW_REVERSE`), per
  second. A weave reverses about once per token. A wobble reverses far
  more: the sloppy bot on `sundered` reverses 4.4 /s against the perfect
  line's 0.55. So a sloppy pilot's low still share isn't flow.
- **A station's flow is its perfect reference run's.** The bench prints
  each skill's still share and reversals next to it, so a wobble shows.

Where flow shows up:

- **Run JSON**: `metrics.still_share`, `straights`, `longest_straight`,
  `swing_mean`, `yaw_share` and `swing_reversals_per_s`.
- **F1**: a compact line, `flow: still 28% · longest 1.2 s`, which adds
  `· straight NOW` while you've been straight for 0.5 s.
- **End-of-run panel**: one Flow line.
- **Bench**: `still` and `longst` columns, plus a separate flow table.
- **`flight_report.py`**: the overview (the reference's still and longest
  straight, and the people's still), the per-skill bot table, the people
  table, and the rated-runs table, now titled "Threading and flow vs fun",
  with Pearson r for still share and longest straight.
- **`tools/flight_movement.py`** (the user's script, refactored): it
  recomputes flow the same way from the ticks, with `--dir`, and prints a
  timeline with one character per 0.25 s and a space for straight.

**Backfill**: `tools/flight_threading.gd` now also writes
`flow_backfill.json` next to the runs. Flow needs only a run's own ticks,
so it is measured for stale layouts too. The run files are only read. The
user's 14 `_human_` files were checked byte for byte (md5) before and after,
and are unchanged. `flight_report.py` runs the backfill when a run lacks
either number. 563 old runs were backfilled.

### Flow vs the user's ratings so far (9 rated runs, backfilled)

Pearson r with fun: still share **0.05**, longest straight −0.26
(openings/s is still 0.80). So on the round-1 stations, flow doesn't track
fun yet. That's not surprising: none of those stations was built to test
it, and climb_rings (fun 4) is 21% still for the person and 71% for the
perfect line, because it's a steady climb. The A/B below is the real test.

## The station (`sundered_flow`, key 0, hash 2a22c9b41180)

It uses the same hall vocabulary and dimensions as `sundered`:
`ruin_kit_hall` bays at 8 m, rows at ±9.4, walls at ±12.4, ties with
soffits at 4 m and 6 m, inner columns, screens with knife-edge slits, torn
ends, broken and open roofs, and an arch breach. It is 15 bays, 21 tokens
and about 190 m of line. The perfect bot flies it in 13.4 s. The difference
is that **the line was designed first and the hall stood round it**. The
layout comes from `tools/flight_flow_layout.py`, which prints the
`STATIONS` entry. Its header holds the formulas, and its constants are the
knobs.

- **Piece A, 9 bays, curving left (radius 110 m).** Inside it, the line is
  a slow corkscrew in the nave's own frame:
  - across = ±4 m sin(πs/24), and up = 5.4 + 3 cos(πs/24) m over the floor.
  - One tie leads to the next every 3 bays. The ties are high, low and
    high, at bay lines 1, 4 and 7. You fly over a high tie 1.5 m clear,
    under its beam 1.6 m clear, and under a low tie 1.6 m clear.
  - The ties sit where the line crosses the nave's middle. There the
    climb's curve is strongest and the sideways curve is zero. Out at the
    sides, where the height levels off, the sideways curve is strongest. So
    the up-down and the side-to-side hand over to each other instead of
    alternating with flats. That's the "sine, not steps" idea, with the
    two axes 90° out of phase.
  - The nave's own curve keeps the direction turning even at the hand-over
    points.
  - Inner columns stand at the bay lines where the line is out to a side,
    so it weaves round them: right of the middle columns, then left.
  - The entry sits at the corkscrew's low point, and the whole station is
    turned so the line leaves the entry heading north and level, as the
    plane is spawned. Before this, the first token was 3.6 m up and 10 m
    out, and the decent bot missed it every time.
- **Gap**: there's no flat gap. A cubic Hermite swoop, about 20 m, runs
  from A's torn end to 8 m before B's mouth. It turns right by about 0.75
  rad while it drops (the floors step down 5 m; the line drops about 2 m).
  A curves left and the swoop curves right, so the hall as a whole is one
  big S.
- **Piece B, 6 bays, curving right (radius 80 m).**
  - It starts at a torn mouth, and a low tie is flown under.
  - Next is the slit act. Screens with knife-edge slits stand on the left
    at bay lines 2 and 3, and the corkscrew carries the line out right of
    them.
  - Then a high tie, and the apse. From the low tie on, the height is a
    half-cosine climb of 20.4 m, so the line rises over the high tie and
    out through the apse's open roof while it still weaves and the nave
    still curves. The climb happens inside the turn, not between flats.
  - The high tie's bay line has **no roof beam** (`beam: false`). With
    the beam, the climbing line passed 0.1 m from it, which was the room
    minimum.
- The tokens are at every bay line (8 m apart), plus 2 in the swoop. There's
  still no token in a slit (same reason as round 2).
- Curved bays are separate boxes, each turned 0.07 rad (A) or 0.1 rad (B)
  from the last. On the outside of the curve, that leaves wedge-shaped
  chinks up to about 0.9 m (A) and 1.2 m (B) in the walls and roof. On
  the inside, the boxes overlap. It's greybox, and has not been seen.

### A/B bench (VERSION 1 bots, 20 runs; reference = perfect bot's best)

| station | band | clear sl/de/sh/pf | ref time s | demand peak | mean | spike | room min m | threading | openings/s | **still** | **straights ≥0.5 s** | **longest s** | swing °/s | yaw share | swing rev/s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sundered | hard | 0.0/0.1/0.9/1.0 | 12.65 | 1.11 | 0.45 | 0.70 | 0.40 | 40% | 0.24 | **29%** | 2 | **1.25** | 18.8 | 43% | 0.55 |
| sundered_flow | **medium** | 0.0/0.9/1.0/1.0 | 13.37 | **0.67** | 0.42 | 0.25 | 0.59 | 37% | **0.45** | **4%** | **0** | **0.32** | 27.3 | **65%** | 0.75 |

The targets are met: still is 4% against a target of ≤ 10%, and the
longest straight is 0.32 s against a target under 0.5 s. **Flow wasn't
bought with demand**:

- Peak demand fell from 1.11 to 0.67, and the mean is about the same
  (0.42 against 0.45).
- The band dropped from hard to medium: decent clears 90%.
- The swing per second is higher (27 against 19 deg/s), but only because
  `sundered` spends 29% of its time not swinging. While swinging, the two
  are about the same: 28 deg/s here against 26.5 there.
- Swing reversals are 0.75 /s against 0.55, which is roughly one per weave
  and not a wobble. The sloppy, decent and sharp bots stay at 0.9-1.1 /s
  on it.
- Openings per second nearly doubled (0.45 against 0.24), because the
  roofed and open bays alternate along the corkscrew.

Sloppy clears neither station. On `sundered_flow` it takes 13-18 of 21:
its misses are spread out, with almost no bumps. There is never a flat to
recover on, which is the cost of continuous demand.

Timelines, one character per 0.25 s (a space means straight; `. : - = + *
#` mean swinging harder):

    sundered       perfect  |     :::..-==:.::=++=-**+-.:.::...  :::::: . .::.  |
    sundered_flow  perfect  |=--:::::-------:::--:::---::.::--===-::---:..::----:. |

### Flow per station (perfect reference)

| station | time s | demand peak | mean | still | straights | longest s | swing °/s | yaw share | swing rev/s | openings/s |
|---|---|---|---|---|---|---|---|---|---|---|
| gentle_arc | 6.22 | 0.20 | 0.17 | 23% | 1 | 1.18 | 13.5 | 100% | 0.00 | 0.00 |
| slalom | 8.07 | 0.63 | 0.55 | 26% | 1 | 0.50 | 23.3 | 100% | 0.50 | 0.00 |
| hidden_turn | 6.78 | 0.71 | 0.33 | 28% | 2 | 0.70 | 20.6 | 100% | 0.15 | 0.15 |
| tight_slot | 5.37 | 0.32 | 0.23 | 42% | 2 | 1.05 | 8.3 | 100% | 0.19 | 0.19 |
| climb_rings | 8.10 | 0.28 | 0.14 | 71% | 3 | 4.00 | 4.3 | 0% | 0.00 | 0.62 |
| dive_arch | 6.50 | 0.51 | 0.33 | 17% | 1 | 0.70 | 19.9 | 0% | 0.15 | 0.15 |
| open_swoop | 9.33 | 0.24 | 0.18 | 14% | 1 | 0.57 | 12.9 | 73% | 0.11 | 0.00 |
| mixed_spike | 6.68 | 0.79 | 0.38 | 55% | 2 | 2.87 | 19.6 | 83% | 0.45 | 0.00 |
| sundered | 12.65 | 1.11 | 0.45 | 29% | 2 | 1.25 | 18.8 | 43% | 0.55 | 0.24 |
| sundered_flow | 13.37 | 0.67 | 0.42 | **4%** | **0** | **0.32** | 27.3 | 65% | 0.75 | 0.45 |

- **Every round-1 station starts with a straight.** Each first token is
  dead ahead, 10-14 m from the spawn, so there's about 0.7 s of still
  flying before anything happens. That alone is 8-12% of a 6-8 s station.
- After `sundered_flow`, the best flowing old stations are open_swoop (14%)
  and dive_arch (17%). climb_rings is the stillest at 71%: it's a steady
  climb in a line, the straightest flying there is. Yet the user rated it
  most fun (4). So flow alone doesn't make fun. Going through things does
  too, and the flowing hall is meant to test both at once.

## Files changed (round 3)

- `scripts/flight_metrics.gd`: `flow`, `swing_rates`, the `FLOW_*`
  constants and `FLOW_KEYS`, and `summarise` merges the flow numbers in.
- `scripts/flight_run.gd`: live flow (`still`, `longest_straight`,
  `straight_now` in `live()`).
- `studies/flight_study.gd`: the F1 flow line, the panel's Flow line, and
  key 0 (the hints now say 0-9).
- `scripts/flight_course.gd`: the `sundered_flow` station. The other nine
  keep their hashes, and `sundered`'s is now pinned in the test as well.
- `tools/flight_flow_layout.py` (new): the layout generator.
- `tools/flight_bench.gd`: the flow columns, `flow_table`, and per-skill
  flow stats.
- `tools/flight_threading.gd`: `backfill_flow`, which writes
  `flow_backfill.json`.
- `tools/flight_report.py`: the flow columns, the flow side file, and the
  flow-vs-fun r.
- `tools/flight_movement.py`: the user's script, committed and aligned to
  the GDScript definition, with `--dir`.
- Tests:
  - `test_flight_metrics.gd`: flow on a straight, turn, straight fake run
    (still about 45%, two straights, the longest about 1.05 s, all
    sideways, no reversals), and the wobble guard (not still, about 4
    reversals/s).
  - `test_flight_bench.gd`: the flowing hall stands, key 0 maps to it, the
    sharp bot clears it in 10-20 s, and the perfect line (look 7) has
    still ≤ 10% and its longest straight under 0.5 s.

## Unverified (round 3)

- **No window was opened.** Nobody has seen the curved hall, the wedge
  chinks between the curved bays, the camera inside a curving nave, or
  the F1 flow line.
- **Nobody has flown `sundered_flow`.** Whether the corkscrew feels like
  "continuous movement" or like being stirred (monotone, or seasick) is
  the open question. It has one rhythm, 3.4 s per full weave, the whole way
  through.
- The definitions are guesses: the 6 deg/s still threshold, the 0.25 s
  window and the 0.5 s straight. Nothing fits them to ratings yet, and on
  the 9 old rated runs still share doesn't track fun (r 0.05).
- The beam left off at B's high tie, and the bays turned at a constant
  curve, depart from the real hall. The real hall's pieces curve too
  (radius ≥ 70 m), but I haven't checked whether a real bay can drop its
  beam.
- Tests: I ran the headless import check and
  `run_tests.py --tests 'test_flight_*.gd'` (3/3 pass), not the full
  suite.

## Suggested round 4

1. **Fly the A/B**, key 9 then key 0, and rate both. If flow wins, the
   numbers to keep are still share and longest straight. Use them as
   filters (still ≤ 10%, no straight over 0.5 s) for generated set pieces,
   next to openings/s.
2. If the corkscrew reads as monotone, vary its period and amplitude per
   act (`HALF`, `SIDE`, `RISE` in the layout tool). For example, a tight
   weave through the slit act and a long lazy swoop through the cloister,
   keeping the hand-over between the axes.
3. Spawn every station into its line's tangent (the round-1 stations all
   start with a 0.7 s straight). Do that as new layouts, since changing
   them would change their hashes.
4. Add a knife-edge bot and optional tokens, so the slits can carry a
   token.
5. Generalise `flight_flow_layout.py` into the station generator from
   round 1's list: a curve (pieces, gaps, corkscrew parameters) in,
   bays and tokens out, benched and filtered on band, demand and flow.

# Round 4: a mix of moves, and the knife edge

`sundered_flow` got the first fun 5 (difficulty 4; flown 21/21, 5% still,
longest straight 0.25 s). The user: "there needs to be more side-to-side,
like left and right. The corkscrew is great but I want a mix of up and
down, left or right, corkscrew, having to do the [knife edge] when you
press Q and E." Round 4 keeps the line that never settles but changes the
move every few seconds, and puts tokens through two knife-edge slits.

## Launch

    ./run-flight-study.command --station=sundered_mix          # key -
    ./run-flight-study.command --station=sundered_mix --bot=sharp
    godot --headless --path . -s tools/flight_bench.gd -- --station sundered_flow,sundered_mix --runs 20
    python3 tools/flight_flow_layout.py --station mix --check   # the line's needs, beats, slits
    python3 tools/flight_flow_layout.py --station mix --write   # rewrite the station in flight_course.gd

The `-` key (after 0) jumps to it; N reaches it after `sundered_flow`. Every
other station, `sundered` (9) and `sundered_flow` (0) included, keeps its
layout and hash (all 11 now pinned in `test_flight_metrics.gd`).

## Collision on a knife edge

- **The bump already honoured it.** `RuinBump` bumps a slab of
  `PlaneFigure.SPAN` × 0.3 × 1.2 m (span × thickness × length), turned by
  heading, pitch, bank and roll. On edge (bank ±π/2) the slab is 1.4 m tall
  and 0.3 m wide, so it fits the 1.15 m slit with 0.42 m a side and 0.95 m
  above and below. Level, its wings don't fit. The tiny-layout test shows
  both: the knife-edge bot threads a lone slit clean, and the same bot told
  never to lean bumps the screen.
- **The room metric didn't honour it.** It was a sphere (clearance less
  half the span), so a slit read as negative room. Now `FlightCourse.survey`
  keeps the sphere wherever that is ≥ 0, so every older station's rooms are
  unchanged. Where it is < 0, it tests the wing line both ways
  (`wing_room`: 5 points tip to tip, less the 0.15 m half thickness): level
  (across the way) and on edge (square to the way and to level).
  - The room is the better of the two.
  - Where on edge beats level by ≥ 0.2 m and level doesn't fit, the sample
    is a **knife sample**.
  - Runs of knife samples are **knife zones** (`knife_zones`): gap, start,
    end, way and room. In `sundered_mix` each is about 1 m long with 0.4 m
    of room on edge.
  - The rooms in the run JSON mark that gap `"knife": true`, and its commit
    time gets `KNIFE_IN` (2 × EASE_KNIFE, 0.24 s) for the roll.
  - The survey is cached per station hash, so benches don't redo it.

## Knife-edge bot (`scripts/flight_bot.gd`, VERSION 2)

Still the same input dict: it only fills `lean` (−1..1), which it never did
before. On a station with no knife zones a v2 bot flies exactly as v1 did.
The knife's randomness has its own RNG, and every v1 station's bench
numbers came out identical. VERSION went to 2 because SKILLS changed, so
the report lists v2 bots separately.

- **Detects:** the run's knife zones (above). It knows a zone once it has
  seen it for its `reaction` time (the run's `knife_seen`; the perfect bot
  knows all). This uses the slit, not the token, because the token in a
  slit is often hidden behind the screen until you're lined up.
- **Lines up:** from `LINE_UP` (1.5 s) before it means to lean, it stops
  cutting between tokens and holds the smooth line itself (`_track`). It
  steers for the line's way a little ahead (the bank's lag) and corrects
  the sideways and up/down miss over `knife_look` (6 m). It adds half the
  line's own turn and climb rate as feed-forward (`track_ff` 0.5). Pure
  pursuit with a 4 m look cut the curve by 0.3-0.4 m, enough to clip the
  screen's jamb. Full feed-forward overshot. 0.5 cleared every sharp run
  in a sweep.
- **Leans:** `knife_lead` s before the zone (at its speed), it holds `lean`
  toward the side the line turns next (right if straight on). It lets go
  1.2 m past the zone's end. Per zone, the lead wanders by
  `knife_jitter` (gaussian), and with chance `knife_forget` it doesn't lean
  at all.

| skill | knife_lead s | jitter s | forget | (plus its usual lag, noise, gain) |
|---|---|---|---|---|
| sloppy | 0.25 | 0.15 | 25% | lag 0.12, noise 0.12 |
| decent | 0.40 | 0.10 | 5% | lag 0.08, noise 0.08 |
| sharp | 0.50 | 0.05 | 0 | lag 0.04, noise 0.03 |
| perfect | 0.60 | 0 | 0 | none |

## Knife metrics (`FlightMetrics.knife`, merged into `summarise`)

The run tracks each zone like a token:

- **`knife_seen`**: the point 1.5 m before the zone comes into view (the
  same cone, range and clear line as a token).
- **`knife_in`**: the plane reaches the zone, with its |bank| then and
  whether it is on edge (|bank| ≥ `KNIFE_ON` 1.2 rad, about 70°, where the
  slab is under 0.8 m across).
- **`knife_out`**: it leaves, `clean` if it stayed on edge all through
  with no bump. **`knife_skip`**: it went by without coming within 4 m.

From these, every run gets:

- `knife_moments` (zones on the station) and `knife_clean`.
- `knife_warning_min` / `_mean`: reached less seen, in seconds.
- `knife_lead`: how long it had been on edge when it got there, mean over
  zones reached on edge.
- `on_edge_s` and `edge_spells`.

The run JSON gets a `knife` list of the zones. These show on F1 ("knife:
1/2 slits clean · on edge 0.8 s · ON EDGE · next slit 1.2 s"), on the end
panel, in a separate bench `knife_table`, and in the report's bot and
people tables ("knife clean", "on edge s") and its CSV.

## Move segments (`tools/flight_flow_layout.py --station mix`)

A piece's line is a list of segments. Each move works the same way: a pair
of alternating **beats** in the nave's own frame.

- `across` swings between +side and −side, `half` m apart.
- `up` swings round `mid` by `rise`, half a beat later, so one axis turns
  hardest where the other has levelled off.
- A natural cubic spline through each axis's beats joins the segments with
  no corner and no flat. A new segment only changes the size and spacing of
  the beats that follow.

| move | what | params used |
|---|---|---|
| weave | side to side between the columns: big side, a bob of 0.5-0.6 m so the line keeps moving where the weave crosses | half 16-20, side 3-4.2 |
| corkscrew | both axes, as round 3 | half 20, side 3.6, rise 1.6 |
| wave | over and under the ties: big rise, a 1.5 m sway | half 22.5, rise 2.9 (2.5 → 8.3 m: under a low tie, over a high one) |
| knife | see below | approach 26-28, hold 8 |
| swoop | between the pieces, round 3's Hermite: a banked turn | turn −1.4 rad (left), gap 24 m, drop 5 m |
| climb | from the slit's trough, the height rises `top` in a half cosine over `len`, while the beats go on and the nave tightens past the hall's end (radius 30): the climbing turn out | top 9, len 48 |

**The knife segment.** The slit is on the left of the nave, on a bay line,
as in the kit (across −6.0, 2.65 m up).

- The segment before it runs until `approach` m before the slit.
- The beat there is a high one, capped at `side_in`. A low beat too close
  is dropped, or a high one is added.
- The line then swings left into the slit at the bottom of an up/down dip.
- It runs in line with the slit for `hold` m either side, with beats 0.15 m
  off its line so the spline lies flat.
- Then it swings out.

The hold is what makes it threadable. With the slit at the peak of a swing
(my first try), the line was still turning at 0.8 × TURN_RATE inside the
slit. Even the perfect bot clipped a jamb, and decent and sharp missed it
most of the time. With the hold, the dip through the slit keeps the pitch
swinging (about 10°/s), so it doesn't read as a straight. The perfect line's
longest straight is still 0.33 s.

**Bays follow the line** (`auto_plan`), using the same plan keys as before:

- A screen with inner columns at −2.6 where it threads a slit.
- A low tie where it dips under 2.7 m.
- A high tie where it crests over 8.2 m (flown over), or ducks under 4.7 m
  (flown under, every other bay line).
- Inner columns at 0 (and ±2.6) on bay lines it swings at least 3 m wide of.
- Roofs follow a whole/broken/open rhythm, open where it climbs out.
- A torn end on each piece.
- `plans` per piece overrides any bay.

The whole layout is the `MIX` dict, so a later round can emit variants:
change the segments, beats or curvature and `--write`. The tool rewrites
the block between the `# >>> sundered_mix` and `# <<< sundered_mix` markers
in `flight_course.gd`. `segment_marks()` gives where each move starts.

## The station (`sundered_mix`, key -, hash db59c1bb79c5)

There are 26 bays at the real hall dimensions: piece A has 11 and curves
right (R 70), and piece B has 15 and curves right (R 70). It has 329
solids, 36 tokens (one every bay line, plus 4 m either side of each slit)
and 290 m of line. The perfect bot flies it in **19.95 s**. Times below
are from that run.

| t (s) | move |
|---|---|
| 0.0-3.2 | **weave**: wide (±4.2 m), round the middle columns, in from the gate |
| 3.2-5.3 | **corkscrew** under two high ties |
| 5.3-8.1 | **knife slit 1**: swing left, dip, on edge through the slit at 7.4, out over A's torn end |
| 8.1-9.9 | **swoop**: banked left turn, dropping to B |
| 9.9-13.2 | **wave**: under two low ties, up over a high tie (8.3 m) |
| 13.2-16.2 | **weave**: quicker (half 16 m), round columns |
| 16.2-18.7 | **knife slit 2**: swing left into it, on edge through it at 18.1 |
| 18.1-20.0 | **climbing turn**: up out of the torn end while turning |

It stands at x 2600 and bends east, away from `sundered_flow` (its
nearest solid is about 180 m from that station's). My first layout curved
left, came within about 30 m of `sundered_flow`, and its last tokens'
way pointed back at the entry, so the run's "3 m past it" rule missed them
on the first tick. See the surprises below.

### Bench (VERSION 2 bots, 20 runs; reference = perfect bot's best)

| station | band | clear sl/de/sh/pf | ref time s | demand peak | mean | spike | room min m | threading | openings/s | still | longest s | swing °/s | yaw share | swing rev/s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sundered_flow | medium | 0.0/0.9/1.0/1.0 | 13.37 | 0.67 | 0.42 | 0.25 | 0.59 | 37% | 0.45 | 4% | 0.32 | 27.3 | 65% | 0.75 |
| sundered_mix | **hard** | 0.0/0.45/1.0/1.0 | 19.95 | 0.66 | 0.38 | 0.25 | 0.12 | 49% | **0.55** | 5% | 0.33 | 26.1 | **71%** | 0.80 |

Knife moments on `sundered_mix` (2 slits, tokens through both):

| skill | slit 1 reached / clean | slit 2 reached / clean | knife warning min s (mean) | on edge s | lead s (on edge before arriving) | edge spells |
|---|---|---|---|---|---|---|
| sloppy | 4 / 2 of 20 | 1 / 0 of 20 | 7.6 | 0.82 | 0.26 | 1.1 |
| decent | 13 / 9 of 20 | 14 / 14 of 20 | 4.5 | 1.42 | 0.22 | 1.9 |
| sharp | 20 / 20 | 20 / 20 | 3.7 | 0.98 | 0.27 | 2.0 |
| perfect | 1 / 1 | 1 / 1 | 3.5 (mean 4.8) | 1.35 | 0.42 | 2.0 |

How it compares with the targets:

- Sideways share is 71%, against 65% on `sundered_flow` (the bots fly
  72-79%).
- Still is 5% and the longest straight 0.33 s.
- Demand peaks at 0.66, about the same as `sundered_flow`'s 0.67.
- Openings rose to 0.55 /s.
- Sharp threads both slits in every run, so I didn't widen anything. The
  slit stays 1.15 m.
- **The band is hard, not medium.** Decent clears 45% (on
  `sundered_flow`, 90%). The demand number doesn't see this, because the
  difficulty is the knife edge, not the line.
  - Decent's misses are almost all at slit 1: it reached it in 13 of 20
    runs and was clean in 9. It threads slit 2 whenever it reaches it.
  - It arrives up to a metre off the line. With an 0.08 s lag and that
    stick noise, its line-up oscillates. It bumps a jamb, the bump turns
    it along the screen, and it never gets in.
  - Slit 1 comes straight out of the corkscrew. Slit 2 comes after a calm
    weave.
  - I tried a longer hold (11 m). It made the swings in and out steeper,
    and decent fell to 30%.
- **Sloppy clears neither station.**

## Surprises

- **The "3 m past it" miss rule depends on the layout's shape.** A token is
  missed once the plane is 3 m past it along the line's way there, however
  far away the plane is. A course that turns past ~100° and comes back
  toward the entry misses its late tokens on the first tick. I changed the
  layout rather than the rule, so older runs stay comparable. A
  generator must either avoid this or add "and within N m" to the rule
  (`flight_run.gd` `_tokens`).
- **Slits are seen early.** Through open bays and the hall's curve,
  slit 2 is in view (cone and clear ray) about 6 s before it's reached, so
  its warning is long. The cone is still a stand-in for the camera.
- **Wall scrapes** (round 1) show up again in the failed decent runs: up
  to 400 bumps against a screen, ending in a timeout.
- **The perfect bot's best look-ahead is now 9 m**, picked from
  PERFECT_LOOKS, as before.

## Files changed (round 4)

- `scripts/flight_course.gd`: `survey`, `wing_room`, `knife_zones`, the
  knife-aware `rooms`, `MINUS_KEY` and `key_name`, and the generated
  `sundered_mix` block.
- `scripts/flight_bot.gd`: VERSION 2, the knife skills, `_knife`, `_side`,
  `_track` and `_nearest`.
- `scripts/flight_run.gd`: `line`, `zones`, the `knife_*` tracking and
  events, the live knife numbers, and `knife` in the run JSON.
- `scripts/flight_metrics.gd`: `KNIFE_ON`, `KNIFE_IN`, `KNIFE_KEYS`,
  `knife()`, and the commit time on knife gaps.
- `studies/flight_study.gd`: the `-` key, the F1 knife line, and the panel's
  Knife edge line.
- `tools/flight_bench.gd`: `knife_table` and the per-skill knife stats.
- `tools/flight_report.py`: the knife columns and CSV keys.
- `tools/flight_flow_layout.py`: the move segments, `MIX`, `--station mix`,
  `--write` and `segment_marks`. `sundered_flow`'s output is byte-identical.
- Tests:
  - `test_flight_bench.gd`: a one-slit layout is one knife zone; the sharp
    bot threads it on edge, 0 bumps, already on edge when it gets there;
    held level, it bumps. Also: `sundered_mix` stands on `-`, sharp clears
    it with both slits clean, and the perfect line has still ≤ 8%, longest
    straight ≤ 0.5 s, sideways ≥ 68%, 2/2 slits, in 15-22 s.
  - `test_flight_metrics.gd`: all 11 hashes pinned.

## Unverified (round 4)

- **No window was opened.** Nobody has seen the mixed hall, the slits from
  the chase camera, the F1 knife line or the panel line. Whether the camera
  shows a slit early enough to roll in time is the big open question. The
  bot's seen rule is a cone, not the camera.
- **Nobody has flown it.** Q/E through a 1.15 m slit with the real input,
  as a person, is untested. The bot needs about 0.4 s on edge before the
  slit, and the slab clears 0.42 m a side.
- The knife-edge visuals (the plane drawn on edge) are the game's own. I
  haven't checked them here.
- Decent's 45% is with my line-up controller. A person lines up differently,
  so the band is the bots' measure, not a prediction.
- Tests: I ran the headless import check and
  `run_tests.py --tests 'test_flight_*.gd'` (3/3 pass) only, not the full
  suite. The user's 38 `_human_` run files were checked by md5 before and
  after the saved bench, and are unchanged.

## Suggested round 5

1. **Fly `-` and rate it**, next to `0`. Say whether slit 1 (straight
   out of the corkscrew) or slit 2 (after a calm weave) felt fair. That
   answers how much calm a knife moment needs before it.
2. If the slits feel too hard, lengthen the swing in (`approach`), not the
   slit. If they feel trivial, cut `hold`. The cut is the lever the bots
   are sensitive to.
3. **Generate variants.** Build segment orders from the vocabulary in
   `MIX` (weave/wave/corkscrew/knife and their half, side and rise). Bench
   each, and keep those with still ≤ 8%, longest straight ≤ 0.5 s, sideways
   share 65-80%, demand peak ≤ 0.7, sharp clearing 100%, and a band the
   user picks.
4. Add "within N m" to the token miss rule before generating layouts that
   curl back (see Surprises). It changes no existing station's numbers
   unless a bot strays.
5. A bot that flies the knife with keys, bang-bang Q/E plus a turn, would
   give a band closer to how people fly.
