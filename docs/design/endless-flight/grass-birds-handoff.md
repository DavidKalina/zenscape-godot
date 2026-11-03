# Grass birds handoff

Prototype round, 2026-11-02. Birds down in the meadow grass go up in a wave
along the plane's line as it skims low and fast, drawn dark by default.

## Fly it

```
.\run-endless-flight.cmd
python tools/play.py -- --bird-look=song
python tools/play.py -- --grass-birds=2
python tools/play.py -- --grass-birds=0
python tools/play.py -- --no-title --at=1093,921 --heading=-131.4 --alt=8
```

The last one starts low over a rich meadow on seed 1.

## What's here

- `scripts/endless/grass_birds.gd`: where coveys are, when they go, the burst,
  the sound. A child of the birds node, stepped from its `step`.
- `scripts/endless/dark_bird_body.gd`: the dark bird, 94 triangles, built in code.
- `shaders/grass_birds.gdshaderinc`: the whole flight and flap, both looks.
- `shaders/grass_birds_dark.gdshader`, `grass_birds_song.gdshader`: the looks.

Coveys come from a 36 m grid: a cell's hash and a slow 320 m noise pick cells,
and only those read the land (meadow over 0.45, flat, off the water), at most
one read a scan, up to 250 m ahead. The same meadow has them in the same
places every flight. A covey goes when the wave's front, 1.25 s ahead of the
nose, reaches it; birds within 62 m of the line go, later toward the sides.
Height decides how many: all under 16 m, none over 34 m. Speed: none under
16 m/s, all over 30 (medium cruise is 36.5, Boost 56).

A burst writes its birds to a MultiMesh ring once. The shader flies each from
its start time and launch; only `clock` is set each frame, and only while
birds fly. The song look uses the same flight, with the songbird's body merged
into one mesh per species and a single stiff wing hinge.

Tuning is at the top of `grass_birds.gd`: `PATCH_OVER` and `CELL_SHARE` for how
often, `COVEY` and `RADIUS` for how thick, `LEAD` for how far ahead,
`LAUNCH_*` and `AWAY_*` for how they scatter, `SPAN_DARK` for size. The beat
rates are at the top of the shader include.

## Cost

Rendered, 1920x1080, Boost, the rich meadow, 9 s, this PC, medium, harness
preset. Off vs default vs 3x, repeated for off and 3x:

| | off | default | 3x |
|---|---|---|---|
| birds in the run | 0 | 2786 | 8353 |
| GPU render, median ms | 11.52, 11.52 | 11.71 | 11.72, 11.69 |
| GPU render, p99 ms | 12.53, 12.57 | 12.66 | 12.77, 12.65 |
| render CPU, p95 ms | 2.43, 2.32 | 2.33 | 2.30, 2.40 |
| birds step, worst frame ms | 0.38, 0.30 | 0.63 | 1.42, 1.47 |
| birds step, mean ms | 0.10, 0.10 | 0.13 | 0.14, 0.15 |

So about 0.2 ms GPU with the ring full (1500 birds, shadows on). A burst is
0.15 to 0.4 ms in GDScript on the frame it goes, and a land read about 0.1 ms.

This is a driven run, not a hand flight. The real check is a user flight with
`--frame-log`, looking at the `birds` part.

## Native

No C++ was added and NATIVE_VERSION is still 1: there is no per-bird work
after the burst to move. If a port is ever wanted, `_burst`'s loop is it. The
toolchain is on this PC (SCons 4.8.1 under Python 3.11, BuildTools MSVC,
`builds/godot-cpp` in the main checkout), but no build was run this round.

## Proof

Smoke passes, dark and song. Driven through the real input (`scratch/gb_pass.gd`,
`gb_wave.gd`, `gb_view.gd`, not committed), medium, stick wobble on:

| flight | bursts | birds |
|---|---|---|
| 7 m over the rich meadow, 10 s | 22 | 1732 |
| same on Boost | 34 | 2710 |
| 24 m | 21 | 780 |
| 45 m | 0 | 0 |
| another meadow, 30 s | 39, then none for the last 12 s | 3098 |
| the start, Boost, 30 s | 1 | 67 |

Start delay against distance along the line correlates about 0.7 per burst:
nearest first, with the side delay and jitter on top.

## Not verified

- The sound by ear. Five voices played the clips in rendered runs, but whether
  they sit over the engine at speed is a guess from levels: `wings-1..4.wav` are
  about -20 dB RMS, the engine loop -15, and they get +1 to +9 dB. `WING_DB` is
  the knob.
- Mac and low presets. Shadows are on and were not measured apart.
- By hand. The stills are from a straight autopilot.
- Whether the wing blur reads in motion: the stills show poses, not the 17 Hz
  beat as seen at 60 fps.

## Seen and left

- Birds passing in front of clouds leave a faint grey ghost in the cloud, and
  any opaque edge there (a spruce too) gets a thin blue fringe. It looks like
  the clouds' own pass rather than the birds, but that wasn't traced.
- In a rich meadow the bursts run almost without a break (0.1 to 1.5 s apart).
  That is the running trail asked for; if it's too constant, raise `PATCH_OVER`.
- A bird climbing near a hillside can go through it: the shader doesn't know
  the land. Coveys are on flat ground, so it's rare and far behind the plane.
- No test touches the birds, so none breaks. The full suite wasn't run.

## Model budget

The dark bird is 94 triangles with no textures, so most of the list doesn't
apply: no sculpt bake, parallax, rigid parts or grime, and silhouette geometry
is the mesh itself. Import LODs: none. A far LOD with fewer body sides would
save perhaps 30 triangles a bird, about 45k across 1500, under 0.05 ms at the
0.2 ms measured; not worth a second draw call. Song uses the existing meshes.
