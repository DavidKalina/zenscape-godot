# Songbird simple look: handoff

Feedback: the songbirds' movement is good but the look is too blocky.

## What changed

`scripts/songbird_body.gd` builds a simpler, smooth bird in code (smooth
normals, vertex colour), with the same mesh API, so `endless_birds.gd`,
`kit_birds.gd` and `sky_ambient_life.gd` animate it exactly as before:
`meshes_for()` returns the same `{body, head, folded[2], spread[2]}`, each one
surface; `HEAD_AT`, `SHOULDER` and `SIZE` are unchanged.

- **Body:** a teardrop round an axis pitched up to the head (12 sides, 9
  rings). The axis bends up at the front to fill the nape, so the head reads
  as part of the body. The breast colour blends in softly on the front and
  belly, and the head colour where the body meets the head. A small flat tail
  fan comes from under the rump.
- **Head:** a smooth ball, round about its pivot, so the look-about turns
  leave no seam. It has a soft throat tone and a tiny five-sided beak.
- **Wings:** thin cambered blades with an elliptical, slightly swept outline
  and a rounded tip (spread: 0.38 span). The folded wing is the same blade,
  shorter and narrower, laid along the flank with its tip over the tail.
- Legs and eyes are gone. Colours are unchanged. Comments in
  `shaders/songbird.gdshader` and `shaders/endless_birds.gdshader` no longer
  say "faceted".

## Triangles (per bird)

| part | before | after |
|---|---|---|
| body | 220 | 202 |
| head | 140 | 125 |
| one wing (folded or spread) | 36 | 52 |
| whole bird | 432 | 431 |

The count is the same, so the MultiMesh flocks cost the same.

## Model-budget tricks

- **Import LODs:** this would apply to far flocks, but the earlier round
  chose no LOD so birds never pop. A far set of meshes (8-sided body, 8x4
  head, wings at 4 stations) would come to about 200 triangles, roughly half.
  At the flock counts we have, that saves well under 0.1 ms, so it isn't done.
- **Silhouette geometry:** applies, and this round is that trick in reverse.
  The outline is smooth curves, with no detail on it.
- **Vertex-colour grime:** this would apply as a dark tone baked into the
  vertex colours where the wing meets the body. It wasn't done, to keep the
  colours flat as asked. It would cost no triangles.
- **Sculpt high, bake low; parallax depth; rigid parts on bones:** don't
  apply. The bird is a code-built mesh drawn as MultiMeshes, with no texture
  and no skeleton.

## Captures (git-ignored, `captures/shots/`)

`songbird_before_*.png` and `songbird_after_*.png`, each with five views:
- `close`: the three species perched, flying with wings spread, and tucked.
- `above`: looking down on spread wings.
- `front`: spread wings seen head-on.
- `flock`: a flock at about 28 m.
- `flocknear`: the same flock at about 10 m.

They come from a throwaway yard, `scratch/songbird_yard.tscn` (shot with
`scratch/yard_shots.sh`), which uses `endless_birds.gd`'s own parts and shader.

## Checks

The headless import is clean. The smoke check (400 frames) passes with 0
errors for `studies/endless_flight.tscn` and `studies/aqueduct_isle.tscn`.
No existing test checks the bird's geometry, so none should break. The full
suite wasn't run.
