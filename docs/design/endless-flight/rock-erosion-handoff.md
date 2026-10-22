# Endless flight, rock erosion round

The ask: rock faces that look eroded (runnels and flutes down the face, a few ledges and bands, rounded weathered bulges, broad sizes, no grain), our own lighting and palette kept.

## What changed

- `art/blender/rock_erosion/rock_erosion_build.py` (run with `python tools/blender.py run art/blender/rock_erosion/rock_erosion_build.py`, numpy only) bakes `assets/textures/endless_rock_erosion.png`, 512 px tileable: RGB normal (x across, y down the face), A height. Three forms only: ridged runnels (narrow across, long down, in patches), five terraced ledges across, rounded bulges.
- `shaders/endless_rock.gdshaderinc`: `er_relief()` projects the tile in world space on three axes (x-y, z-y, x-z, weights |n|^4; the top axis keeps half strength) at two tiles, 110 m and 38 m (the small one at 0.55 strength). Each fades by `er_keep` plus the mip (`textureGrad` with the pixel footprint). The offset joins the facet normal before the painted light steps, so the painted light and the sun both follow the relief. The cavity (height) tints the albedo a little.
- `rock_calm` quiets pass 2's painted noise where it fights the relief: plane tone variation, plane tilt, seam cracks, bed lips and dry-brush.
- Flag `--rock-flat`: pass 2 exactly as before (uniform `rock_flat`, set in `scripts/endless/endless_look.gd`, which also sets the texture).
- Not touched: terrain, collision, grass, snow, beach. Arches use the ground material and get the relief (range still shows them fine).

## Launch

`godot --path . res://studies/endless_flight.tscn -- --no-title --seed=1 --at=400,-1065 --heading=22 --alt=35` (valley); `--at=-700,-300 --heading=66 --alt=90` (range, with an arch); `--at=-760,-420 --heading=40 --alt=45` (wall); `--alt=300` at the range spot (far). Add `--rock-flat` for pass 2.

## Knobs (ground material uniforms)

`rock_relief` (1.2, 0 off), `rock_relief_size` (1, scales both tiles), `rock_calm` (0.5, 0 leaves pass 2's paint as it was). The texture's own depth is in the build script (`depth`, and the weights of `h`).

## Stills (git-ignored, in the worktree `scratch/rock3/`)

Side-by-side sheets, pass 2 left and erosion right: `sheet_valley.png`, `sheet_range.png`, `sheet_wall.png`, `sheet_far.png`. Singles: `flat_*.png` and `e3_*.png`. (Earlier tries `e1`, `e2` were stripier.)

## Unverified

- GPU cost: six more texture reads per tile pair on rock pixels only (2 tiles x 3 axes), cheap next to the cell searches; not measured.
- Shimmer in motion; other seeds; night.
- Known: the thin pass 2 bed seams and dotted lines still cross the flutes on a wall seen close; `rock_calm` up or a pass on the seam code would clear them. The relief's flutes are fairly regular; a second, differently seeded tile could break that up.
- Tests: none added or run; none expected to break (shader and look only).
