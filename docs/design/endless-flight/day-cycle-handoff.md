# Day cycle (handoff)

Endless flight now has a day cycle, on by default. A flight opens on
today's 8.6 h morning, and then the clock runs: day, golden hour, sunset and
afterglow, a short blue hour, then dawn, sunrise and morning again. One
full cycle takes 20 minutes. There is no real night. After the afterglow
the sun sinks only 0.1 (sun height) under the horizon and runs along under
it to where it rises, as the sun does on a midsummer night in the far
north. The sky turns a deep clear blue, the first stars come out, and the
land stays readable.

```
cd ~/Documents/Projects/zenscape-daycycle && python3 tools/play.py -- --ledger=/tmp/day_cycle_ledger.json
```

To watch a whole cycle in two minutes: add `--day-length=120`, or press `]`
in flight.

## How the clock works

- `scripts/endless/day_cycle.gd` (`DayCycle`) keeps `t`, the number of
  seconds into the cycle, and maps it to the sun's phase. The phase is
  celestial's turn of the sun's ring: 0 is midnight, 0.25 sunrise, 0.5 noon
  and 0.75 sunset. `EndlessLook.step` advances the clock and writes the
  phase to `celestial.phase`. Then `celestial.advance` draws the rig as
  before. Celestial's own 480 s loop (`cycling`) stays off.
- **The pace.** The ring is cut into parts by the ring's sun height (taken
  before the floor), and each part gets its own seconds (`PARTS`). Inside a
  part the sun turns at an even rate. Between parts the rate eases over
  `BLEND` (0.006 of a turn each side, three box passes), and each part's
  weight is then trimmed until its eased seconds come out right. The sun
  never changes pace with a step. Golden hour and sunrise linger because
  their parts hold many seconds for a small arc. The turn under the
  horizon is quick. The table is built once, in 8 ms.
- **The night floor** is `celestial.night_floor`, which endless flight sets
  to `DayCycle.FLOOR` (0.1). Under the horizon the sun's height is eased by
  a tanh, so it can sink no deeper than the floor, and it keeps its ring's
  bearing. The descent carries straight on through the horizon. Above the
  horizon nothing changes, so the day's light is exactly as it was. With
  no floor set (0, every other scene) celestial behaves as before.
- **The blue hour** is `celestial.blue_hour`, the `BLUE_*` constants, and it
  only exists with a floor. As the sun sinks from 0.04 to 0.085 below the
  horizon, after the afterglow's rose:
  - the sky blends to a deep blue (`BLUE_UP` overhead, `BLUE_DOWN` low);
  - the night (`zs_night`: the stars, the night dome, the moon) comes only
    28% of the way in;
  - the night look's rod-lit grade comes half way;
  - the moon's key is halved;
  - the clouds take a dim twilight blue;
  - the Belt of Venus goes.

  The land's night fill keeps the full night's strength, so the meadows
  read. The Milky Way (the dusty-rose band, `zs_night_light` in
  `reference_sky.gdshader`) now only shows well into a real night
  (`zs_night` 0.4 to 0.8). At dusk it had stood in the sky as pink vertical
  beams.
- **WorldClock is not used.** `scripts/world_clock.gd` keeps honest hours
  with a full night, and it brings the calendar, the moon's month and the
  aurora plan with it. Endless flight wants a paced cycle with no night, so
  a small clock owned by the look was simpler. The moon therefore stays
  full, as it was.
- **The menu holds the clock.** While the main menu holds the flight, the
  cycle is `held`, so a flight starts at its opening hour. R (respawn) keeps
  the time.

## The pace (at the default 1200 s)

| part | ring sun height | seconds | minutes |
|---|---|---|---|
| twilight (before sunrise) | -0.10 rising to 0 | 70 | 1.2 |
| sunrise and morning golden light | 0 to 0.42 | 150 | 2.5 |
| day | over 0.42 | 540 | 9 |
| golden hour | 0.42 to 0 setting | 210 | 3.5 |
| afterglow | 0 to -0.10 | 100 | 1.7 |
| blue hour | under -0.10 (the floor holds it near -0.1) | 130 | 2.2 |

That makes dawn 3.7 min, day 9, dusk with its golden hour 5.2, and the blue
hour 2.2. The eased seconds match the table to within 0.3 s. A new flight
opens 0.36 h into "day", 309 s into the cycle. At 1x, 10 s of flight moves
the clock 0.14 h by day. To change the pace, edit the seconds in
`DayCycle.PARTS`.

## Flags and keys

| | what it does |
|---|---|
| (none) | the cycle runs from the opening hour (the world's paint hour, 8.6) |
| `--day-length=S` | seconds per cycle (1200) |
| `--day-at=dawn\|noon\|dusk\|blue` (or an hour) | where the cycle starts |
| `--hour=H` | the time stands still at H (no cycle) |
| `--hour=H --day=1` (or `--day`) | the cycle runs from H |
| `--day=0` | no cycle, at the opening hour |
| `--mood=M` | the mood starts at its own hour and the cycle runs from there; L (next mood) keeps the time |
| `--night=1` | no floor: the full night as before, though the clock still hurries through it |
| **T** | sweeps forward to the next stop: dawn (5.75 h, just before sunrise), noon, dusk (17.24 h, deep golden), the blue hour (midnight). The sweep runs through the hours in between, so nothing jumps. It works with the time stood still too |
| **]** / **[** | time faster or slower: 1, 8, 30 or 120 times |

The HUD's look line (F1) shows the part and the speed, for example
`alpine morning, 17.24 h (golden hour, x8)`, or `still` when the clock is
stopped. I checked these keys against the existing bindings. `]` and `[`
were free. T used to step to the next quarter of the day.

A world of regions (`--world=regions`) still blends the regions' colours
by the eye. While the clock runs, the regions' own hours are ignored.

## What follows the light

Almost everything in the land was already live per frame from celestial's
globals: sky, fog and haze, sun and rim, the hemisphere fill, the leans,
the clouds, the sea and rivers, the ground, the grass and the spruce
sprites. A scout audit found nothing baked from the sun at build time:
- The far crowns' colours and the tuft colours are paint, not light.
- The spruce sprite atlas is baked unshaded and lit live.
- The valley fog map is shaped by the land and lit live.
- The chunk vertex colours read no sun.

Fixed this round:
- **The clouds after sunset.** The moment the set sun's light fell under
  the moon's, the key took the moon's tint, and every cloud lit
  moon-white at full strength. In the time-lapse, red clouds turned
  white. The clouds now keep the sun's tint and lean on the moon as the
  sun sinks 0.07 under the horizon. This is in `celestial.gd` and so
  applies everywhere.
- **The Milky Way at dusk** (above).

Not done, and why:
- **The sky's radiance map.** A mirror ball in front of the camera
  reflects black at noon and at the blue hour, under both the incremental
  and the realtime sky. Nothing in the game visibly reads it, so it is
  not redrawn as the sun moves (a redraw would only cost frames). If a
  glossy surface ever needs it, the sky's radiance is black today, before
  this round too.
- **The moon** stays full and rides high through the blue hour. There are
  no moon phases without a WorldClock.
- **The haze's hue near 17 h.** `EndlessLook.horizon` caps the horizon's
  display colour at 0.98. When its brightest channel switches from green to
  red, the scene-linear haze turns quickly. It is continuous on screen and
  takes about 7 s at the default pace. I didn't judge it by eye at that
  pace.
- **Noon clouds read tan.** That is the existing cloud look (cream at
  8.6 h), and I didn't touch it.

## Proof

- **Time-lapse**, through the real play loop. The game ran its own tick
  and the clock advanced in `look.step`, at `--day-length=120`, with the
  plane put back on a fixed spot and heading each frame so the chase
  camera stood still. Each view got 30 stills over one full cycle:
  - toward where the sun sets, over the sea (720, 520, 70 m up);
  - toward where it rises, over hills and a river (120, -40, 60 m up).

  Sheet: `scratch/dc/day_cycle_sheet.png`, with the sunset view on top and
  the sunrise view below. Each view's own sheet is
  `scratch/dc/lapse_sunset/sheet.png` and `scratch/dc/lapse_sunrise/sheet.png`.
  The driver is `scratch/dc/lapse.gd` (uncommitted).
- **Per-frame jumps over the cycle** in the sun's energy, the fill, the
  haze (as displayed), the zenith, the horizon glow and the night grade.
  The largest single-frame step is 9 to 40 times the mean step, at the
  pace's turns: the blue hour into twilight near 5.3 h, and sunrise near
  6.1 h. Those are ramps over many frames, not pops, and at 1200 s they
  are ten times smaller again.
- **Frame times** at 1440x900, rendered, over the full 120 s cycle (7200
  frames), from frame to frame:

  | view | clock | median | p99 | worst | over 33 ms |
  |---|---|---|---|---|---|
  | sunset, sea | running (stills left out) | 15.2 ms | 17.6 | 30.1 | 0 |
  | sunrise, land | running, no stills | 26.0 ms | 31.0 | 39.2 (frame 3, the start) | 1 |
  | sunrise, land | held | 26.6 ms | 31.0 | 42.2 (frame 3) | 1 |

  The running clock costs nothing measurable and causes no spikes. In the
  runs with stills, every frame over 33 ms came three frames after a still
  was saved.
- **The t=0 match against main** (`scratch/dc/t0.gd`). The cycle was held
  on its first frame and stills were taken from three fixed views after
  900 frames, against main (0b43b0f9) from a throwaway worktree:
  - hills: identical;
  - cruise: 87 of 1.3M pixels off by at most 5/255;
  - toward the sun: 43 off by at most 4/255.

  Two runs of main against each other were identical. With the clock
  running, the same views are 15 s and more later in the morning, and
  read the same.
- **Keys and flags** through the real input path (`scratch/dc/keys.gd`,
  real key taps): `]` and `[`, and T to noon, dusk, the blue hour and
  dawn. The menu (`--title`) holds the clock. I also checked `--hour`,
  `--day=0`, `--hour=H --day=1`, `--day-at=`, `--day-length=`, `--mood=` and
  `--night=1`.
- **Smoke checks** passed: endless flight (default, `--world=regions` and
  `--day-length=20`) and flight_study. The rendered runs showed no shader or
  script errors.

## Existing tests

No test drives endless flight's look or celestial's dusk directly. I ran
`test_sky_sea_peaks` (it loads `reference_sky.gdshader`) and
`test_world_clock`, and both pass. The gpu tests that render the sky or
clouds at a low sun could shift, through the cloud tint after sunset
(celestial, everywhere) and the Milky Way's gate at dusk (any `zs_night`
under 0.8). The gpu tests were not run.

## What's left

- Tune by playing:
  - the parts' seconds (`DayCycle.PARTS`);
  - the blue hour's blue, its stars, and how readable the land is
    (`celestial.gd` `BLUE_*`, `FLOOR`);
  - the dawn and dusk stops (`DayCycle.STOPS`).
- If the moon should wax and wane, the moon needs a WorldClock or a phase
  of its own.
- Regions could give each region's hour a share of the clock (an offset)
  instead of ignoring it.
