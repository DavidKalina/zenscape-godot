# Hall line grass

Branch `look/hall-line-grass`. Not merged.

## Cause

The Sundered line's islands drew their top with the islets' stand-in ground:
every triangle carried its own flat tone (three grass tones picked by a patch
noise, plus a per-face shimmer) with no colour blending between faces, and
the stand-in material had no `facet_soft`. Each triangle read as its own
tile, a quilt of orange and green shards. The main isle's turf
(`KitLook.GroundMesh`) averages each point's tone over the faces that meet
there and uses `KitLook.ground_material()`.

## Fix (surface only)

- `scripts/hall_line_build.gd` `_soften_top`: after `SkyIslets.dress`, the top's
  vertex colours become the area-weighted mean of the faces meeting at each
  point (as GroundMesh does) and the top mesh is rebuilt. Positions and normals are
  unchanged, so collision, the boxes and the lane are untouched.
- `scripts/hall_line.gd` `configure`: the line's islets host gets
  `ground_source = KitLook.ground_material()`, the aqueduct isle's turf
  material (soft facets, wet ground). Its UV layout matches `top_arrays`.

The orange is the isle's autumn turf, the same as the main isle.

## See it

```
python tools/shot.py ... or: Godot --path . studies/aqueduct_isle.tscn -- --no-title --near-ring --autopilot
```
(Windows: `& $env:GODOT --path . --rendering-method forward_plus --windowed studies/aqueduct_isle.tscn -- --no-title --near-ring --autopilot`)

## Cost

One pass over the top's vertices with a dictionary weld, on the worker that
builds the piece, plus one extra mesh build. Not measured; expected a few ms
per piece on the worker, nothing on the main thread. The material is the shared
one the main isle already uses.

## Proof

Headless smoke (`tools/smoke.py studies/aqueduct_isle.tscn -- --near-ring --autopilot`): pass.
Captures (autopilot flight, 1280x720, every 3 s; `scratch/hall_shots.gd`, not committed):
`captures/hall/before_NN.png` and `captures/hall/after_NN.png`, e.g.
`before_09/after_09` (mid), `before_12/after_12`, `before_17/after_17` (close),
and `captures/hall/main_isle.png` for the main isle's turf for comparison.

## Existing tests that might break

`tests/test_isle_hall_chain.gd` and `tests/test_isle_loop_played.gd` mention the
hall line; not run (no full suite). Neither should read colours.

## Not done

The hall's islands carry no grass tufts or flowers (they had none before); the
main isle's tufts come from `KitFlora`.
