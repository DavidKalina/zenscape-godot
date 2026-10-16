# Worn paths drawn per pixel

Branch `look/path-dirt`, from main 85ef29a0. Not merged.

## Why they looked flat

The aqueduct isle's worn paths were baked into the turf's vertex colours. `KitLook.ground_tone` blended each 1–2 m facet toward a gravel-earth brown by `path_wear`. That made a smooth brown smear with the mesh's blurred edges and no grain of its own.

## What changed

The ground shader now draws the paths per pixel, in `shaders/path_dirt.gdshaderinc`, included by `reference_surface.gdshader` and used on ground only.

**Wear.** The isle hands its path segments to the ground material: 44 of them, from `Art.paths()`, through `scripts/kit_isle/path_dirt.gd`. Each pixel's wear is its distance to the segments, on the same curve as `path_wear`.
- The edge wanders with noise, so grass pushes in.
- Tufts of grass hold on as small islands away from the trodden middle.

**Dirt.** The dirt is the old baked colour, lifted (×1.35) and greyed toward dust (0.3). It reads as a soil texture, with no pebbles; round 1's pebbles read as dots.
- Soil in clumps, at three sizes.
- Warmer and greyer earths in patches.
- Damp hollows, darker and cooler.
- A paler, dustier trodden crown down the middle.
- Soft scuff streaks running along the path.
- Fine crumbs and dust specks up close, faded out with distance.
- A darker, richer soil band where the grass gives way.
- A low relief, with the scuffs, for the light.

**Lighting and colour.** The path keeps the turf's soft lighting normal, so the mesh facets don't show through. The dirt enters as the ground's source colour, so the ground's own look (palette, sun warmth, wet sheen) treats it as it treated the baked wear.

**The turf.** The isle no longer bakes wear into its turf. `--vertex-paths` brings back the old baked paths, for comparison.

**Other scenes.** Any scene that sets no segments (`path_count` 0) draws the ground as before. The flora still reads `path_wear`, so path middles stay bare as before.

## Proof

- Smoke check passed on `studies/aqueduct_isle.tscn` and `studies/zenscape.tscn`.
- Stills are in `scratch/gfx/`:
  - `sheet-pd-onfoot.png`: before (`--vertex-paths`) and after, by the stair.
  - `sheet-pd-castle.png`: by the castellum.
- No test reads the turf's path colour. The full suite was not run.

## Not done

- Stones and flagstones along the edges (option 3).
- No look presets other than Alpine morning were captured.
- The motif isles' paths. `PathDirt.paint` works on any ground material once an isle has path polylines.
