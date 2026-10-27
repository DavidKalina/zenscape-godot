# Endless flight, rock polish round

The ask: the rock faces look good but could be richer and more polished,
standing out while still blending in. This is a prototype round with no
committed tests. Both parts are on by default on this branch.

## Launch

`.\run-endless-flight.cmd` in this worktree, or by hand with
`-- --no-title [--seed=1 --at=400,-1065 --heading=22 --alt=35]`. The
carve round's spots (`rock-carve-handoff.md`) show it best: the valley wall
above, and the wall up close at `--at=-760,-420 --heading=40 --alt=45`.

| Flag | What it does |
|---|---|
| `--rock-look=old` | The shader as it was (`rock_rich` and `rock_shape` 0). |
| `--rock-shape=0` | The land skips baking its shape (no CUSTOM3). |
| `--rock-knob=rock_rich=X`, `--rock-knob=rock_shape=X` | Each part's strength (default 1). |

## What changed

- **The land's shape (`scripts/endless/land_stream.gd` `_shape`).** On a
  worker, after the chunk is built, each vertex's height is compared with
  the ring round it at 4, 14 and 40 m: proud is over 0.5 and sunk is
  under. This goes to the mesh as CUSTOM3 (RGBA8). Each radius uses its own
  grid of the chunk's nodes, a power of two of the chunk's step. The chunk's
  own heights fill the inside, and only the ring past it is sampled
  (`f.grid`), so neighbouring chunks' edges match exactly (checked at L0,
  L2 and L4). A chunk with no ground steeper than 0.9 up gets no shape.
  The cost is about 2 to 6 ms on a worker for a chunk with rock, against
  10 to 120 ms to build it. It is GDScript and needs no native rebuild.
- **`shaders/endless_rock.gdshaderinc`.**
  - `er_rock_shaped` takes the shape, and `er_rock` passes none, so arches,
    stacks and other rock meshes are untouched.
  - `rock_shape`: proud edges are worn pale, in the sun's gold where it hits
    and a cool sky tone in shade. Crevices, ledge corners and recesses get
    darker and cooler, and their bounce light drops. Buttresses are a
    little lighter.
  - `rock_rich`: colour zones about 60 m across (rose, ochre, grey); some
    beds pale and creamy, some rust; dark or rust stains run down from each
    ledge; sage and orange lichen; each bed shaded as a bevelled block; a
    cooler shade side and a warmer lit side. Faces in shade that point up
    take the sky. It also calms the old plaid of bed tone steps, gully
    streaks and fissures.
- **`shaders/endless_ground.gdshader`** reads CUSTOM3 into `land_shape`.
- **`scripts/endless/endless_look.gd`** adds `--rock-look=old`.

## Tried and dropped

Light bands where `er_planes`' snapped planes meet. They traced contours of
the snap, not real edges, and read as white scribbles.

## Checks

- Smoke check of `studies/endless_flight.tscn`, default and with
  `--rock-look=old --rock-shape=0`: pass, no errors.
- `test_native_stream_geometry.gd` and `test_native_pond_attributes.gd`
  pass. The full suite was not run.
- Stills: this worktree's `scratch/rock/` (git-ignored). The `ab3_*`
  sheets show the carve spots; `ab2_*` show close cliffs, lit and in shade.
  Drivers: `scratch/rock_views.gd` and `scratch/rock_spots.sh`.

## Open

- Sea stacks, hoodoos and arches have no shape yet. Their meshes would
  need their own CUSTOM3, or a curvature from their build.
- The 4 m edge is measured at the chunk's step where that step is coarser,
  so a level change can shift the rims a little. It has not been watched
  in flight.
- Frame time was not measured. The shader adds a few ALU ops and a vertex
  channel.
