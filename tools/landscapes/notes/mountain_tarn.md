# Mountain tarn (take 3)

**Intent:** a tall peak with a small lake (a tarn) cut into it near the
summit, water poured on top, filling the tarn and spilling over as a fall.

**Recipe:** `tools/landscapes/mountain_tarn.gd`. Paddle size 3 swell to 3.5 m
for shoulders. Modeller size 3 pinch up to 9 m (a horn). Wire size 1 slice,
pulled down to level the top at 6 m. Chisel size 1 pit, held and pulled
down about 1.6 m in the middle of the sliced top. Water held 3 s over the
pit. 15 s of world at 4x.

**Stills:** /private/tmp/zs-landscapes/mountain_tarn-take3/ (02-peak,
03-pit, 04-tarn, 06-low). The take 2 stills were wiped by a later headless
dry run (see harness wishes).

## Takes
1. **Pit cut into the horn's flank, no slice** (headless only). The Chisel pit's
   floor is level at the press height minus the pull, and points already
   below that level are left alone. On a slope, the downhill rim stood
   *below* the floor (floor 4.76 m, downhill rim 4.54 m). There was no
   basin: the ball became a "spring" whose pool settled 11 m away at the
   foot.
2. **Wire slice to 7 m, then a pit 0.6 m off centre.** The slice left a flat
   only about 1.5 m across, because the horn falls away fast. The pit broke
   its front edge. Result: a shallow tarn (0.64 m³, 0.22 m deep) that
   overflowed through the breach as a **tall, clean waterfall** down the
   rock face into a pool at the foot. This was the best-looking image of
   the session, and it came from a happy accident.
3. **Slice to 6 m, then a pit centred on the summit.** A real tarn: 9.1 m³
   over 8.9 m², 1.68 m deep (floor 4.27 m, rims 4.94 to 5.83 m). It spilled
   over its lowest rim (south-west, away from the camera) as a cascade. But the
   mountain lost its peak and now reads as a **truncated cone, a volcano**
   with a crater lake, not a peak with a tarn.

## What came out
- Water: a tarn that holds, plus an overflow cascade. You get either a deep
  tarn or a fall in view, never both.
- Rock: the pinch's granite paint reads well, and the slice keeps it. The
  Chisel pit walls are crisp, dark rock.
- Life: about 40 trees in 15 s at 4x, including birches on the summit rim.

## How the tools felt
- **Pinch (horn) + Wire slice + Chisel pit** is a good three-tool combo:
  each verb does a different job. The slice is the hidden key. Without it
  the Chisel pit is useless on a slope.
- **Chisel pit on a slope is a trap.** A player would call it a hole, but
  it acts as a level cut that's open on the downhill side. A pit should
  sink below its *lowest* rim, or carry its floor at least X under the
  lowest ground in its outline.
- The fall's direction is not up to you. Water leaves over the lowest rim
  point, and nothing lets you say "spill here". A Chisel tap notch on the
  rim might do it (not tried).
- The Chisel pit reports its verb as `mesa` (worked_as returns "mesa" for
  both directions).

## Gaps
- No "keep the peak, cut a cirque into its side" verb. A real tarn sits in
  a cirque: a bowl carved into the flank with a lip on the downhill side.
  Today you get either a hole open downhill or a decapitated summit.
- No way to choose the overflow point.

## Scores
Buildable 3/5 · Looks 4/5 (take 2: 5/5) · Matched intent 3/5

## Harness wishes (for all four water-at-height builds)
- A headless dry run wipes the rendered stills in the same folder. Keep
  rendered output per take, or have headless write to `<name>-headless/`.
- run.sh's `head -120` counts the `!v.is_finite()` ERROR lines, so the
  LANDSCAPE lines after the pour are cut off the console (report.txt has
  them).
- `still()` leaves the hover name label ("Pine", "Broadleaf") and a white
  ground-mark ellipse in some shots.
- `drag()` steps a fixed share per *frame*. In a windowed run below 60 fps
  a 1.5 to 3 m/s drag misses the clay's 6 px within 0.3 s and becomes a
  hold (a pinch). The take-final scripts use their own `brisk_drag`. The
  harness could pace by wall time, or jump a few px on the press.
- A `spills()` measure (edge falls) and a "water standing above Y m" measure
  would help judge falls and perched lakes.
