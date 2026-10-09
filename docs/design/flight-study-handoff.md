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
