# Grass birds handoff

Second round, 2026-11-02. The first round's wave along the plane's line was
played and rejected: too many birds, bats, a bad whirr. It's gone. Now, every
45 s or so of flying low over meadow, a small covey goes up out of the grass
ahead of the nose, the plane catches them and they scatter.

## Fly it

```
.\run-endless-flight.cmd
python tools/play.py -- --no-title --at=1093,921 --heading=-131.4 --alt=8
python tools/play.py -- --flush-gap=12 --flush-sound=2
python tools/play.py -- --flush-size=1.4
python tools/play.py -- --grass-birds=0
```

The second starts low over a rich meadow on seed 1. Use a short `--flush-gap`
to see several in a flight, for the look and the sound.

| flag | what | default |
|---|---|---|
| `--flush-gap=S` | mean seconds of low meadow between flushes; a draw is S x 0.66 to 1.34 | 45 |
| `--flush-size=X` | bird size over the default span, about 0.57 m | 1 |
| `--flush-sound=N` | what you hear, below | 1 |
| `--grass-birds=X` | birds in a covey over 8 to 20; 0 no flushes | 1 |

## Sound

Nobody here can hear them, so these are by description. Choose with `--flush-sound=N`.

| N | what |
|---|---|
| 0 | silent |
| 1 | alarm chatter (default): one short `chirp-*`, then 2 or 3 `twitter-*` clips overlapping within about half a second |
| 2 | the same chatter over a very soft flutter (`flutter-loop.wav`, a second of it, faded) |
| 3 | pips only: 3 or 4 short `chirp-*`, spaced out, no twitter |
| 4 | the soft flutter alone |

The voices sit at the covey and go with it. Gains are `CHATTER_DB`, `PIP_DB`
and `FLUTTER_DB` in `grass_birds.gd`. By level the chatter is 5 to 13 dB under
the first round's wings at the same distance, but it sits at 4 to 5 kHz, where
the engine (centroid about 0.5 kHz) doesn't cover it.

## What's here

- `scripts/endless/grass_birds.gd`: when, where and how a flush goes, the grass
  and the sound. A child of the birds node, stepped from its `step`.
- `scripts/endless/endless_birds.gd`: the covey's flight, `put_covey` and
  `_covey`, a flock state of its own (COVEY). Drawn with the songbird's six
  parts through the same `_draw`, so native or not it costs no new path. Flying
  is GDScript only; `_fly_native` never sees a covey.
- `scripts/songbird_body.gd`: the `starling` species, dark with warm brown
  wings and breast. Six more MultiMeshes, empty unless a covey is up.
- `grass_react.gd` `shake`, `endless_motes.gd` `puff`: the grass where a bird left.

Removed: `dark_bird_body.gd`, the shader ring, `shaders/grass_birds*`,
`--bird-look`, the 36 m covey grid and its patches, the whirr.

## How a flush goes

**When.** Every 0.25 s it reads the place: under 24 m off the ground, off the
wheels, at least 24 m/s, meadow over 0.45 one second's flight ahead. Only those
seconds count down, so rarity is in time, whatever the meadow holds. The wait
is drawn afresh after each flush. A due flush that finds no spot retries at the
next read. The first of a flight comes at 0.3 to 0.6 of a gap.

**Where.** 1.4 to 1.9 s ahead along the line, bent by the plane's smoothed turn,
mostly within 4 m of it, 35% of the time 7 to 16 m out. The spot must be meadow,
flat and dry, on screen, with no rise of land between the eye and it.

**How.** The birds fly on ahead of the plane at 13 to 19 m/s and it catches them
in 2.5 to 3 s at cruise. So each flush is aimed: a miss distance of 1.5 to 10 m
at the moment it catches them, on the side they rose from or, 30% of the time,
across the nose; the slant follows from that. Height, pace, count, patch size,
fan and raggedness are drawn too. A covey close on the line splits round it
about a third of the time.

**The birds.** One goes first, alone. The rest follow nearest the line first
over about half a second; about one in six is late by up to 0.75 s more. Each
flies itself: a hard low scramble to 2 to 8 m with jinks and elbowing, a flare
off the plane's line in the last second (`FLARE_*`), a toss from the plane going
by, then level, fanning, whirr and set glide, and down into the grass. Tuning is
at the top of each file: `COVEY_*`, `FLARE_*`, `WHIRR`, `GLIDE` in `endless_birds.gd`.

## Proof

Smoke passes. `scratch/` drivers, not committed: `flush_low.gd`, `flush_film.gd`,
`flush_close.gd`, `flush_same.gd`, `flush_ms.gd`.

**The gaps.** Ten simulated minutes each through the real loop, medium, 9 m with
a stick wobble, the driver hopping to a new meadow when one ran out or it crashed
(38 and 54 hops). Seconds of low meadow between flushes, the first one left out:

| flight | flushes | low meadow | gaps (s), low meadow | mean | wall-clock gaps (s) |
|---|---|---|---|---|---|
| no Boost, 36 m/s | 10 | 461 s of 600 | 34.5, 35.8, 40.3, 40.5, 41.8, 44.0, 47.5, 49.0, 50.5 | 43.4 | 47 to 68 |
| Boost, 54 m/s | 9 | 412 s of 600 | 32.5, 37.5, 38.5, 39.5, 43.3, 46.0, 53.5, 56.0 | 44.8 | 44 to 82 |

The draw can't go below 29.7 or above 60.3 s of low meadow at the default, and a
failed spot adds up to a few reads. Birds came no nearer than 7.8 m in these
runs. Across both: 8 to 20 birds, 5 crossed the nose, 7 split round it.

**Cost.** The birds' whole step, headless, Boost, 7 simulated minutes alone on
the machine: mean 0.35 ms with a covey up against 0.12 without, worst frame 5.9
against 2.7 (4.1 just after a driver hop). The 5.9 wasn't traced. Rendered at
1440x900 over a short flight the same split was median 0.41 against 0.13, worst
2.55 against 1.42. Worst frames of 20 to 35 ms in the 10 minute runs were two
headless runs and a window sharing the machine; they went away run alone. A
flush going is 0.3 to 0.5 ms, a read 0.05 ms. No C++: 20 birds for a few seconds
in 45. The real check is a user flight with `--frame-log`, the `birds` part.

**Never touches the flight.** The same scripted stick with flushes and with
`--grass-birds=0`, three flushes in the first, down to a landing and a stop:
identical to the printed digits, touchdown at 14.15 s in both. Nothing here
writes to the plane; birds have no colliders, and none comes nearer than
`SWEPT` (1.8 m).

Motion was judged from consecutive frames, chase camera, 20 stills a second,
medium, stick wobble on, plus a fixed eye in the meadow beside the covey. It
read as a ragged scatter of small birds and the close view as real birds with
real wing poses. Those sequences are in `scratch/film/` (not committed).

## Not verified

- The sound by ear, all options. Levels are from the files, and that the voices
  play is from the run below.
- Whether it feels panicked in motion. Stills show poses and paths, not the
  10 Hz beat or the timing at 60 fps. The user's eye decides.
- The grass shake by eye. The stamps go in (14 to 19 more alive than without),
  but no still shows it clearly. The chaff shows as pale specks up close, not
  from the chase camera. The fixed-eye film draws a far-grass view, not the near
  tufts, so it can't show it either.
- By hand. Everything is a stick script with a wobble. With a big turn the bent
  line guesses wrong and a covey goes wider of the nose.
- Size. 0.57 m reads as specks until the plane is close; `--flush-size` is there.
- The fan and the drop into the grass mostly happen behind the camera. Their
  frames were only seen from the fixed eye, and only the early part.
- Mac, low presets. No test touches the birds; the full suite wasn't run.

## Seen and left

- The first birds sit visible on the ground for a moment where the grass is thin.
  In the near tufts they're hidden; from the chase camera they're too far to tell.
- Long headless runs that teleport the plane print 3 or 4 RID errors from the
  dummy renderer (`Initializing already initialized RID`, `unimplemented base
  type`). They come with `--grass-birds=0` too, so not from this round.
- `film` views other than `play` draw the ground without near tufts and with
  clouds reflected into it. It's the harness's camera, not the game.

## Model budget

No new geometry: the songbird's meshes in a new palette, so sculpt bake, parallax,
rigid parts and grime don't apply. Birds are drawn at any distance with no LOD;
a far LOD would save little at 20 birds, about 9k triangles at most for a few
seconds, well under 0.1 ms.
