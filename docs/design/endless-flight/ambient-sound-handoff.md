# Ambient sound: the living ground

`scripts/endless/ambient_sound.gd`, a child `FlightSound` makes and steps
(`--ambient-sound=0` leaves it out). Mix unjudged by ear; volumes below are
from a headless `--sound=on` drive.

## What it does

- Beds on the "Ambience" bus, by place and hour (`celestial.daylight`):
  birds (`kit/bird-chorus-loop.wav`) over flat, low, dry land by day;
  crickets (`cricket-bed.wav`) on land at dusk and night; frogs
  (`frog-bed.wav`) near ponds, lakes and rivers, a third as loud by day.
- Presence: flying, the beds top out at 0.6 of landed and fall with speed
  (`fast` 0.3 to 0.95, to 0.15) and height over the ground (12 to 160 m, to
  0.12). Wheels down and slow (`fast` under 0.5) rises to 1.0.
- Calls, one at a time, 14-32 s apart flying, 6-14 s landed, from per-group
  shuffled decks (never the same clip twice running): meadow (bluebird,
  chickadee, robin, kinglet, hermit-thrush, jay-1, jay-2), rock (raven placed
  14-40 m up, nutcracker), water (heron-call by day, frog-croak after dark),
  night (owl). Placed ahead (1.2-2 s of flight) and 22-55 m aside, so one
  passes at speed. Gain 0.12 (quiet) to 0.22 (landed).
- The land is read in two alternating slices 0.6 s apart (about 20 height
  or river samples each, plus `ponds_in` for ponds), none per frame. Clips
  load one a frame from the first frame; 6 players (3 beds, 3 call players).

## Volumes seen (linear gain; engine for scale)

| case | birds | crickets | frogs | engine |
|---|---|---|---|---|
| day, meadow, low cruise | 0.046 | 0 | 0.001 | 0.103 |
| day, meadow, boost | 0.013 | 0 | 0 | 0.165 |
| day, meadow, 200 m up | 0.002 | 0 | 0 | 0.165 |
| day, meadow, landed | 0.137 | 0 | 0.003 | 0.136 |
| day, by a pond, landed | 0.121 | 0 | 0.028 | 0.137 |
| night, meadow, low cruise | 0 | 0.040 | 0.005 | 0.103 |
| night, meadow, landed | 0 | 0.108 | 0.011 | 0.136 |
| night, by a pond, landed | 0 | 0.097 | 0.094 | 0.137 |

Landed beds sit at about the engine's idle level or above; that is the
intent, to be judged by ear.

## Unused clips (before this round; verified by grep in scripts and studies)

Used now: bird-chorus-loop, cricket-bed, frog-bed, bluebird, chickadee,
robin, kinglet, hermit-thrush, jay-1, jay-2, nutcracker, raven, owl,
heron-call, frog-croak. Still unused: rain-bed and thunder-1..3 (no weather
in flight), stream-bed, water-bed, kit/chirp-1..8, kit/twitter-1..6,
kit/cricket-3/4-N, kit/frog-1..6 (only the walker-era `genesis_audio.gd`
names a few). Gaps: no river-specific clip is used (rivers get frogs);
no dedicated lake-edge bird; no day insect bed over meadows.

## Not verified

By ear; a rendered run with players (the drive ran headless); true dusk
(the drive's `--hour=17` read daylight 0.85 and 18.5 read 0, so the
crossfade of birds to crickets was not logged); rivers (frogs are driven by
`river_y`, ponds and lakes, not checked on a long river); no frame-log
flight (the cost is about 40 field samples per 0.6 s).
