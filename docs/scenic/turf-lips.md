# Turf lips

Branch `look/turf-lips`, from main 3bf19986. Not merged. It is separate from `look/cloud-bounce-fill`; the two touch different files.

## What it does

Where the aqueduct isle's turf meets a drop, the turf now rolls over the edge instead of stopping in a cut. That is every crag top in the tiers and the rim of each island and islet.

`scripts/kit_isle/turf_lips.gd` reads a KitLand land's drawn `Ground` and `Crags` meshes. It finds each turf edge that has a drop under it:
- rock below that falls at least 0.6 m, or
- an edge within 0.6 m of the outline.

Each of those edges hangs a lip:
- **Top.** A sod top, drawn in the ground's own material and tone, that starts 0.12 m back on the turf.
- **Crest.** A crest 0.14 to 0.38 m out.
- **Face.** A ragged face that goes dark green to earth, 0.22 to 0.6 m deep, sometimes with a deeper tongue. It is drawn in the rock material with no weathering.
- **Tatters.** Torn strands of sod hanging from the foot.
- **Roots.** The kit's `HangingRoots`, about every 5.5 m over falls of 2.5 m or more.

Reach and droop come from a noise of world position, so the lips of neighbouring edges meet. The lips are drawn only: no collision and no shadows. On the isle they cover 814 edges.

`studies/aqueduct_isle.gd` builds them after the cached art has loaded. To see the old cut edges:

```
--no-turf-lips
```

The motif isles don't use them yet. `TurfLips.dress(land, seed)` works on any KitLand land.

## Proof

- Smoke check passed on `studies/aqueduct_isle.tscn` and `studies/zenscape.tscn`.
- Rendered stills, from before the last tuning pass, are in `scratch/gfx/`:
  - `sheet-lips-close.png`: near-level views, cut and with lips.
  - `sheet-lips-onfoot.png`: the on-foot view.
- The "after" stills also show another session's uncommitted plane-hitch greybox: the crates, a boulder and the "hitch" prompt. That work is not part of this round.

## Model budget (docs/art/model-budget.md)

- About 814 edges × 2 to 3 samples × 8 to 12 triangles comes to roughly 25 to 30k triangles in two draw calls, plus one roots multimesh.
- The lips use the same tricks the land already uses: flat shading, vertex colour instead of textures, and one mesh per material per land.
- Merging them into the land's own Ground and Crags meshes would save two draw calls per land. That is a few hundredths of a millisecond, not worth it yet.
- A distance cull (`visibility_range_end` near the grass's 95 m) would save about 0.1 ms on the establishing shot. It isn't done because the rims carry that shot.

## Not done

- Grass tufts leaning out over the lips. `KitFlora.RIM` keeps tufts 0.5 m back, and the isle's tests read that number.
