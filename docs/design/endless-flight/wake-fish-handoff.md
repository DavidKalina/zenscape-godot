# Leaping fish: handoff

Prototype round, for the user to play; it replaces the wake run that was played
and rejected. Now and then, low over a lake, a fish leaps where the camera can see
it. `--wake-fish=0` turns all of it off; pond leaps are EndlessFish's and unchanged.

## Fly it

`.\run-endless-flight.cmd --at=2334,-1534 --heading=90 --alt=3` starts over the
biggest lake of seed 1, 2.8 km. The moments are rare on purpose, so to see them
quickly add `--leap-gap=6`. Over the plane only fires at about wingtip height:
let it settle onto the water, hands off, on a steady line. Other lakes: (87,250)
1.1 km (heading 180), (1344,-4857) 1.7 km, (-6841,3527) 1.7 km, (4796,-3688) 1.5 km.

Knobs: `--leap-gap=S` the mean gap (default 45 s, gaps run from 2/3 to 4/3 of it),
`--leap-size=X` the fish times X.

## What it is

- `scripts/endless/wake_fish.gd`, a child of EndlessFish. Shaders
  `shaders/wake_fish.gdshader` (the body) and `shaders/wake_splash.gdshader`.
  The model: `art/blender/fish/fish_build.py` writes
  `assets/models/fish/hero_fish.glb` and `hero_fish_skin.png`.
- The clock counts time low (under 45 m) over a lake, so distance and how close
  it skims don't enter. It stops over land. The first moment comes at 0.15 to
  0.55 of a gap, so a short lake isn't nothing. The gaps are not seeded by the land.
- Lakes as before: under the sea's level, 300 m inside the world's edge line. The
  tarn, ponds and rivers get no moments.
- Four moments, never the same twice running: over the plane, off a wing, far off
  in a corner, a pair (the rare one). A moment with no water to fall in tries the
  other side, then another moment, then 0.3 s later.
- Each is worked out backwards from the point where the fish should be: the plane's
  line is carried on through the swirl and the rise, turning as it is turning.
  The real speed is used, so no Boost (36 m/s) works the same.
- The chase camera at speed is about 12 m behind the plane and 3.6 m over it, FOV
  about 87. So the near moments are placed by the eye, not the wing: they pass
  between the camera and the plane. Fish seen from over them are mostly against
  water, not sky, so most roll a flank up to the eye (`_flank_to`).
- Over the plane is only offered under 3.4 m (plane's centre over the water) and
  turning under 0.35 rad/s. The fish is led onto the line after it leaves: up to
  5 m in the air, 10 m under the swirl. That is a cheat of a metre or so a second
  against a plane doing 57.
- A fish flies on the CPU: real gravity on a clock slowed a little round the top
  (the path stays a parabola), nose leading the arc, a roll through the leap, the
  spine bent each frame: a held curve thrown over 1 to 3 times, and a tail beat that
  is hard out of the water, dies at the top and flicks going in. Height, run,
  twist, bend, beat and kind (four paints) all vary. Two fish at most.
- The water: `EndlessSea.leaps` feeds marks to `shaders/endless_sea.gdshader`
  (`zs_leap_slope`), real slope on the real surface, so the sky and sun take it: a
  dome and turn before it breaks, then rings, and a boil of small slopes where it
  went through. Only while marks live. Rings need no foam: laying WaterContact's
  foam patch looked like a white sheet, so it was taken out.
- The splash is laid when the fish really goes through the surface: a crown
  (a torn wall on a real arc), drops off its rim, a ribbon of drops shed along the
  fish's path on the way out, a stem of a jet where it went in, a little mist.
  Past 20 m the crown stands a little taller than it is, and drops don't go under
  about a pixel and a half.
- First use: the fish and the splash are drawn folded for the first half second,
  so their pipelines build at the start. Everything loads in `setup`.
- Removed: the wake leaps, the idle leaps over lakes, `WaterContact.stir()`,
  the rings and boil quads.

## Numbers (headless, medium weight, driver over the 2.8 km lake)

Real gaps, default `--leap-gap`, circling with a wobble in the line, seeded as it
then was:

| | time over water | gaps | mean | least | most |
|---|---|---|---|---|---|
| Boost | 470 s | 9 | 49.1 s | 38.2 s | 58.9 s |
| no Boost | 490 s | 10 | 45.9 s | 38.2 s | 59.1 s |

Variant mix at `--leap-gap=4`, 240 s of wingtip height: 17 far, 12 over, 11 pair,
19 wing, in both, and none twice running. At 8 m: 15 far, 0 over, 10 pair, 20 wing.
Over the plane, 24 fish in those runs with the wobble: flat miss median 0.28 m, worst
2.9 m; 22 of 24 were over the plane's centre by 0.7 to 2.4 m. The two that weren't
(about 0.5 m under) were where the wobbling pilot climbed after the fish had left.

Cost, headless: 0.011 ms a frame idle, 0.033 ms with a fish in the air, 0.26 ms on
the frame a moment is laid, worst 0.62 ms in 3000 frames. One 18 ms frame turned up
once in an earlier 3600-frame run and didn't come back; its cause wasn't found.

## The big leap

A fifth moment, `big`, a fifth of the moments by default (about one every 3-4
minutes low over a lake). A 2.6-3.8 m fish beside the view, or 3.4-4.6 m further
off with the whole arc in sight (40%), 4.6-8 m high, about 2.5 s in the air on real
gravity, a slow tail (2.6-4.2 Hz), a stiffer body, a longer swirl first and a second
burst when the hole closes. The splash stops rising past size 2.56 (`thrown` in
`shaders/wake_splash.gdshader`) but its drops grow and stay up longer (`heft`).

To see it: `.\run-endless-flight.cmd --at=2334,-1534 --heading=90 --alt=3
--leap-gap=6 --leap-big=1`. Knob: `--leap-big=S[,X]` the share of the moments
(0 none, 1 all) and their length times X.

## The swimmer

A big fish (4.2-5.4 m, the hero fish's mesh) that comes up from behind and keeps
pace beside the plane just under the surface for 5-8 s, with one surge ahead,
then dives back and away. Half the time it breaches once on real gravity, with
WakeFish's splashes and rings. 30% of the time a smaller second fish comes along.
`scripts/endless/swim_fish.gd`, owned by WakeFish; leaps hold off while it swims.

- Gap: a mean of 60 s low (under 14 m) over a lake, 36-84 s, the first at 0.3-0.7
  of one.
- Its slot: 2 m behind to 4 m ahead of the plane's centre, 5-6.5 m out, so 14-18 m
  from the eye on Boost; off Boost the camera's narrower and the slot slides up to
  5 m further on. Its middle 0.9 m under the swell (it rides `EndlessSea.height_at`),
  wandering 0.08 m.
- What shows is a real mesh under the real sea sheet. The sea draws its own water
  over it (`shaders/endless_sea.gdshader`): `zs_swim_hit` finds the pixels whose
  bed is the fish's body (inside its footprint, no deeper than its belly), so its
  back isn't taken for a shallow (no shore foam, no clear edge) and the water over
  it is its own: dark blue-green at its back, going to the water's colour down its
  sides and toward nose and tail (`swim_see`, `swim_clear`). `zs_swim_one` adds a low
  hump ahead of the head, a hollow behind, the chop stilled over its back, a little
  less sky, and where the fin cuts, spray and two short ripples.
- The fish shader (`shaders/wake_fish.gdshader`, `under`/`surface_y`) takes the
  water's colour under the surface and dims its sun glint; leaps leave `under` at 0.

To see it: `.\run-endless-flight.cmd --at=2334,-1534 --heading=90 --alt=3
--swim-gap=8`, and fly low (under 14 m) over the lake. Knobs: `--swimmer=0` none,
`--swim-gap=S` the mean gap (s), `--swim-size=X` its length times X.

Numbers, headless, medium, 360 s each circling the 2.8 km lake at 3 m with a wobble
in the line (the real stick). On screen: its middle inside the frame, which is not
the same as seen through the water.

| | time over water | swimmers | gaps | mean | least | most | on screen |
|---|---|---|---|---|---|---|---|
| Boost (55.8 m/s) | 312 s | 5 (2 pairs, 3 breaches) | 4 | 54.6 s | 39.1 s | 77.5 s | 5.1-8.0 s of 8.4-11.1 |
| no Boost (35.3 m/s) | 313 s | 5 (3 pairs, 2 breaches) | 4 | 67.1 s | 49.4 s | 77.3 s | 6.7-8.9 s of 8.6-10.7 |

Cost, rendered (1440x900, 3D scale 0.75, this PC): its script 0.069 ms a frame
while it swims. The frame's GPU time with it off, on, off: 5.75/5.89/5.85 ms and
5.83/5.71/5.90 ms, so the sea's added work is inside the noise (about 0.15 ms).

## Model budget

444 triangles, 289 vertices, a 1024x256 mask skin.

- Sculpt high, bake low: not used. The fish is under about 100 px; a normal map
  would save nothing and cost a texture. The scales are in the mask.
- Import LODs: tried and off (`hero_fish.glb.import`): Godot's generated LODs made
  the fish vanish past about 20 m. No visibility ranges: it's on screen for 2 s
  in 45 s. Saving: none needed, at most 888 triangles.
- Silhouette geometry: applies. Real fins, forked tail and adipose, about 110
  triangles of the 444, carry the outline; the flanks' detail is all paint.
- Rigid parts on bones: no bones at all. The spine is nine joints in a uniform,
  sections set on it in the vertex shader. No skeleton node and no skinning pass,
  perhaps 0.05 ms a frame while one flies (an estimate).
- Parallax depth: no, under 100 px.
- Vertex-colour grime: no; the vertex colours flag fin, eye and paired fin.

## Open

- Sound was not heard: nothing here can listen. Fish-plop and water-pop a beat
  after going in, -20 to -10 dB by size. The levels are a guess.
- Stills can't show how it feels at speed: a fish over the plane is on screen about
  1.3 s, the last 0.3 s of it fast. The sequences show frames, not whether it's
  caught by the eye while flying. Hang, tail beat and the 60 fps flicker of the
  gleam need playing.
- The sun's flash on the flank is short, and was seen rarely in the sequences.
- Far fish are 1.4 times longer than the 0.4 to 0.8 m range (`big` in `FAR`).
  At 55 m and more nothing shows the difference.
- The sea shader's cost while marks live (about 5 s after a moment) wasn't measured
  on a GPU.
- The plane's own foam patch under the camera is much the brightest thing near the
  fish at low height. It's as it was and wasn't touched.
- The big leap's heavier splash is mostly seen on the far ones: near fish leave
  the frame before they land, so it wasn't judged in a close still.
- The swimmer: judged only in stills (chase camera, noon and 16.2, Boost and
  cruise). In the sun's glare at noon and at about 22 m after a breach it's lost;
  some cruise frames show it darker navy with harder edges. At 0.9 m the dorsal
  seldom cuts the surface, so its spray and ripples seldom show; shallower than
  about 0.8 m its back now and then stands out of a trough `height_at` misses,
  as a black cut-out. No sound for it; the hump and slick barely read at its range.
