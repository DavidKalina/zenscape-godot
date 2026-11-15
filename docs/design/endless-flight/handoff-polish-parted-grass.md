# Handoff: parted grass as a combed mat (polish round, lane)

The ask: the grass pushed over round the parked plane on the title screen
read "stringy" and noisy.

## Diagnosis (title stills, scratch/part/title_*_before.png)

In order of weight:

1. **Crossed comb (a, d).** The menu holds three stamps (plane, eye, the
   midpoint between them), each pushing out from its own centre. Between
   the plane and the eye they push against each other, and the eye's stamp
   radiates out under the camera, so the bottom half of the frame showed
   blades fanned in every direction. Switching only this (all three push out
   from the plane) turned the foreground into one starburst from the plane:
   most of the calm came from this.
2. **Paper-strip fold (b).** The near tuft's blades have one joint (rows
   0 / 0.6). The old offset (shove by height x bend, then a drop that keeps
   each vertex's distance from the root, plus the press) put the joint about
   level and folded the tip down at a hard angle, the pressed tips dug into
   the ground. Worked through for a full push: (0,0) -> (0.10,0.32) ->
   (0.59,0.31) -> (0.98,0.20) before the press.
3. **Striping (c).** Laid blades kept the tuft's domed mass normal and the
   dark-root to pale-tip ramp, so a flat mat read as alternating dark and
   pale strips. Smaller than 1 and 2.

## What changed

- `scripts/endless/grass_react.gd`: `part()` takes `from` (world xz), the
  point a held stamp pushes out from. It rides in the 2D instance
  transform's padding floats (`_buffer[o+2]`, `[o+6]`), which the stamp
  shader reads as `MODEL_MATRIX[2].xy` (no new per-frame CPU work, two more
  floats written into the existing buffer). `push_at` (the CPU twin) does
  the same. `combed` (default on, `--grass-part=old` off) also sets the new
  global `zs_react_lay`.
- `shaders/grass_react_stamp.gdshader`: the out-push is measured from
  `from`.
- `studies/endless_flight.gd` `_react`: the eye and midpoint stamps push out
  from the plane when combed.
- `shaders/grass_react.gdshaderinc`: `zs_react_arc`, the lie of a near
  blade: a curve whose angle from upright is theta*(1-(1-t)^k), theta up to
  1.42 rad, k from 1 (gentle lean, even arc) to 2.6 (laid: bend gathers at
  the root, the rest lies near flat), integrated in 4 midpoint steps per
  vertex, blade length kept, tip off the ground. Only near grass blades
  (`grass_blades`) take it; flowers and the far tufts keep
  `zs_react_offset`. Vertex work only where the push map is non-zero.
- `shaders/reference_surface.gdshader`: laid blades lose 70% of the mass
  normal's dome and their root-to-tip ramp starts at 0.3 instead of 0.
  (A tilt of the mass normal the way they lie was tried at 0.35: the mat
  went washed out; left at 0, `zs_react_lay_tilt`.)
- `project.godot`: global `zs_react_lay` (float, 1).

No mesh change (near tuft vertex count unchanged).

## A/B

`--grass-part=old`: the old shove-and-drop and each stamp pushing from its
own centre (byte for byte the old path, the padding is 0).

## Frame time

`look_views.gd --views=meadow_low --time=240` on the Windows PC (1440x898,
3D scale 0.75), one run each: new 7.70 ms median (p90 8.34), old
(`--grass-part=old`) 7.73 ms. No difference within noise. That view has
little pushed grass; the arc's extra cost (4 steps of pow/sin/cos a vertex)
runs only on vertices inside a stamp, and was not timed separately on the
title.

## Tests

No test pins these numbers (grep of tests/ for grass_react, push_at,
PART_). None expected broken; full suite not run.

## Not verified

- The prop wash in flight: a driven low pass (`--at=720,380 --alt=2.5`,
  wash strength 0.55 reported) gave stills where the chase camera sits too
  far behind to see the washed patch, so new and old look the same there.
  The wash goes through the same arc, so it should lie smoother, but that
  was not seen. Fly low over a meadow with and without `--grass-part=old`.
- `--grass-part=old` reproduces the before title still exactly
  (scratch/part/title_0_oldflag.png against title_0_before.png).
- Upright grass: the low meadow view (scratch/part/after/meadow_low.png)
  looks as before; the arc only runs where the push map is non-zero.
- Mac/Metal and the compatibility renderer: the stamp shader reads the 2D
  instance transform's padding as `MODEL_MATRIX[2].xy`. Proved on Windows
  Forward+ (the title's comb changed as intended). If another renderer
  drops the padding, `from` reads 0 and the stamps act as before (old
  comb), nothing worse.
- Gusts and the walker go through the same arc; not looked at separately.
