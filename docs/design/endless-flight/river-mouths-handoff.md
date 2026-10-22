# Endless flight, river mouths round

The user's report: "The way the rivers connect to the ocean is not
believable / seamless." This is a prototype round. It is proved by smoke
checks, a skim through the real play loop and before/after stills judged
by eye. There are no committed tests.

## What was wrong (stills of main at cc3f6d1e)

- **A blunt end.** The drawn river stopped on a straight line across the
  channel where its level came within 0.35 m of the sea (`river_mouth`).
  It ended like a lock gate.
- **A dry trough.** Past that line the channel ran on to the beach as a
  sandy trench. Its bed was only 0 to 0.6 m under the sea, and the sea's
  swell heaves about ±1 m right up to the shore. At most moments the
  trough stood bare, with a puddle of sea in its lowest spot.
- **No mouth shape.** The channel kept its width (10 to 24 m) right to
  the beach. It read as a canal.
- **Colour.** The river's deep blue (a depth faked from the bank) met the
  sea's pale shallows and foam with no blend.
- **Stones.** The pebble banks ran on down to the sea.
- **A steep fall.** On steep coasts the river fell 1 to 1.5 m per 8 m over
  its last 50 m, so the drawn water came down to the beach on a slope.

## What changed

- **`scripts/endless/land_field.gd`: the mouth's shape**, over the last
  `RIVER_MOUTH_RISE` (5 m) of the river's fall to the sea:
  - **Funnel.** The river opens out to 1 + `RIVER_FLARE` (2.4) times its
    width. The flare goes with the square of the way into the mouth, so
    the channel is widest at the sea.
  - **Deeper bed.** The bed deepens by up to `RIVER_MOUTH_DEEP` (3.6 m)
    and flattens across, so the sea fills the channel.
  - **Slower current.** The flow slows as the channel widens (speed /
    flare).
  - **Level.** The level eases into the sea's over `RIVER_MOUTH_EASE`
    (1.2 m), a soft floor in place of `max(lv,0)`.
  - **New functions.**
    - `calm_here()` / `sea_calm(x,z)`: how still the sea lies there, 1 in
      a river's channel.
    - `river_drawn()`: the drawn water's height, which the ground shader
      sinks at a mouth.
    - `river_y()` now returns `river_drawn()`.
- **`scripts/endless/endless_sea.gd`.** The sea's depth map is now RG
  float. Red is the height as before. Green is `calm_here`.
- **`shaders/endless_sea.gdshader`: the sea up a mouth** (scaled by
  `river_calm`, 1). Where the green is set:
  - The swell is taken away: the vertex heave and the fragment's slope,
    shift and crest.
  - The shore foam is gone and the shore line drops to 20%.
  - The colour reads the bed it sees rather than the coarse 8 m map.
  - The water fades in over `river_calm_fade` (2 m) of depth rather than
    5 cm.

  These are the only sea shader edits: one function and a few lines in
  the vertex, depth, foam and ALPHA.
- **`shaders/endless_ground.gdshader`: the river at a mouth**
  (`river_mouth_blend`, 1):
  - **Sinking water.** The drawn water doesn't stop on a step. Over its
    last `river_mouth_sink.y` (1.5 m) of level it sinks under the sea's
    still water, which fades in over it. Where it goes under, the paint
    gives way to the bed.
  - **Colour.** Over twice the rise (10 m of level), the water takes on
    the sea's colour formula for the channel's real depth: its tint
    depths, bed fade and calm body light. At most `river_mouth_tint`
    (0.8) of it, so some river blue carries out.
  - **Banks.** The banks' stones give way to sand.
- **`scripts/endless/endless_look.gd`.** It passes those uniforms from
  the field's constants and the sea's material.
- **`studies/endless_flight.gd`.**
  - The skim, the camera and `_on_river` read `river_drawn()`.
  - The sea's CPU swell (`sea_height`) is stilled by `sea_calm` as the
    shader stills it. The plane skims a calm mouth at the same 0.9 m as
    the drawn water.

## Flags and knobs

| Flag | What it does |
|---|---|
| `--river-mouth=0` | The mouths exactly as before. The stills of `off_*` match main's `before_*`, apart from the sea's motion and the clouds. `0..1` gives a share of the change. |
| `--river-flare=X` | Funnel width (scales `RIVER_FLARE`, default 1). |
| `--river-knob=river_mouth_tint=0.8` | Also `river_mouth_rise`, `river_mouth_sink`, `river_mouth_deep`, `river_sea_*`. |
| `--sea-set="river_calm:1.0;river_calm_fade:2.0"` | The sea's side. |

`--no-rivers`, `--river-cut`, `--river-fill`, `--water=old` and
`--sea-body=old` are unchanged and smoke clean.

## Proof

- **Smoke.** `tools/smoke.py studies/endless_flight.tscn` passes with 0
  errors with no flag, and with each of these: `--river-mouth=0`,
  `--no-rivers`, `--water=old`, `--sea-body=old`,
  `--river-cut=0 --river-fill=0`. It also passes at a mouth
  (`--seed=3 --at=548,-731`), with `--river-flare=2`, and at
  `--seed=1 --at=-770,1500 --river-mouth=0.5`.
- **Play loop.** `scratch/mouth/skim.gd` is the rivers round's skim
  driver: real input, nose held down, flaps.
  - Down seed 3's river into its mouth (`--at=520,-731 --heading=90`):
    360 frames over water, at least 0.91 m over it, never under it, no
    touchdown.
  - From `--at=548,-731` into the sea-level part: 0.90 m over the calm
    water, steady at -39.10, so the CPU swell is stilled there too.
- **Land moved** (`scratch/mouth/moved.gd`, 6 km square, compared with
  `--river-mouth=0`). Meadows and flats are kept: the change sits at the
  coast.

  | Seed | Land moved by more than 0.5 m | Newly water | Of that, meadow |
  |---|---|---|---|
  | 1 | 0.64% | 0.26% | 0.001% |
  | 3 | 0.35% | 0.17% | 0.001% |

## Stills (before = main, after = this branch)

They are git-ignored, in this worktree's `captures/river_mouths/`. Each
`sheet_<view>.png` is before on the left and after on the right. The
views are taken by `scratch/mouth/shots.sh PREFIX [views] [-- flags]`
(hour 10).

| View | Seed | Mouth | Camera |
|---|---|---|---|
| `a1` | 1 | (-766,1470) | from over the sea |
| `a1low` | 1 | (-766,1470) | low |
| `a1high` | 1 | both of that bay's mouths | high |
| `a2` | 1 | (-646,1560) | |
| `b1` | 1 | (690,516) | |
| `c1` | 1 | (-760,-1520) | |
| `d1` | 3 | (591,-736) | from over the sea |
| `d1low` | 3 | (591,-736) | low, up the river |
| `e1` | 3 | (250,-82) | |

`off_a1` and `off_d1` are `--river-mouth=0`. The top-down field maps are
`scratch/mouth/map*.png` (before) and `after_map_*.png`, made by
`scratch/mouth/map.gd`. The mouth finder is `scratch/mouth/find.gd`, and
the profile down a river's line is `scratch/mouth/walk.gd`.

## Unverified and open

- **In motion.** I didn't watch the mouths in a moving capture. Not
  checked:
  - the swell stilling between the open sea and the channel (a 1 to 2
    texel fade, 8 m texels);
  - the depth map's 900 m re-bake swapping the calm in (it's in the same
    texture as the depth, so it swaps with it);
  - the ripples' flow slowing into the mouth.
- **Colour front.** Where the drawn water sinks under the sea there is a
  faint lighter band across the funnel (the sea's shallow colour over
  the sunk paint). It reads as a colour front, but could be softened.
- **Funnel shape.** On steep coasts the funnel spans only 25 to 40 m and
  can look boxy (`a2`, `b1`).
- **Far chunks.** These don't cut the channel. There, the drawn water
  runs on over the uncut beach to the shore. It isn't sunk, but it isn't
  a step either. It wasn't looked at closely from high up.
- **Lakes and odd cases.** Not looked at:
  - inland pools at sea level that rivers run into (seed 1 near
    (-2728,-2184) gets the same funnel and calm);
  - a river running along a coast at sea level (seed 2 near
    (-224,-1136)).
- **Other conditions.** Night, other hours and moods, and `--water=old`
  in a rendered still: not looked at.
- **GPU cost.** Per wet pixel: about 2 noise taps more at a mouth, and
  one extra texture tap in the sea's vertex and fragment. Not measured.

## Tests this breaks

None known: no test references the endless land, sea or shaders. The full
suite was not run.
