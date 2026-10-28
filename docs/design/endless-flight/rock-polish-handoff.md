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

- **The shared kit (`scripts/endless/rock_shape.gd`, RockShape).** It
  bakes a rock mesh's shape once, on a worker: how proud or sunk each
  vertex stands at 4, 14 and 40 m, into CUSTOM3 (RGBA8). Proud is over
  0.5 and sunk is under; a is 1 where the shape was baked. Any mesh drawn
  with the land's ground material takes it in two lines:
  `RockShape.bake(arrays)`, then `RockShape.format(arrays)` as the
  surface's format flags. The sea stacks and hoodoos (`rocks/rock_build.gd`,
  every rock kind) and the rock arches (`arch_build.gd`) use it.
  - **Any mesh (`bake`).** Each vertex is measured along its normal
    against the centroid of the surface within each radius. The surface is
    read as clusters of vertices, each weighted by its share of the
    triangles' area, so the cost doesn't grow with the radius. The bake
    adds about 60 ms to the slowest rock group's build (73 to 137 ms) and
    about 120 ms to the slowest arch (330 to 450 ms). Both run on workers
    while the land streams.
- **The land's chunks (`RockShape.grid`, called from `land_stream.gd`
  `_build`).** Each vertex's height is compared with the ring round it. Each radius uses its own
  grid of the chunk's nodes, a power of two of the chunk's step. The chunk's
  own heights fill the inside, and only the ring past it is sampled
  (`f.grid`), so neighbouring chunks' edges match exactly (checked at L0,
  L2 and L4). A chunk with no ground steeper than 0.9 up gets no shape.
  The cost is about 2 to 6 ms on a worker for a chunk with rock, against
  10 to 120 ms to build it. It is GDScript and needs no native rebuild.
- **`shaders/endless_rock.gdshaderinc`.** Every rock surface uses this
  one include, so the palette (the `ER_*` constants and the strengths)
  changes all rock at once.
  - `er_rock_shaped` takes the shape, and `er_rock` passes none, so arches,
    stacks and other rock meshes are untouched.
  - `rock_shape`: proud edges are worn pale, in the sun's gold where it hits
    and a cool sky tone in shade. In the sun only the small edges wear
    pale, since a whole stack stands proud at the larger sizes. Crevices,
    ledge corners and recesses get darker and cooler, more so in the sun,
    and their bounce light drops. Buttresses are a little lighter in
    shade.
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

- Smoke check of `studies/endless_flight.tscn` three ways (default,
  `--rock-start=stacks`, and `--rock-look=old --rock-shape=0`): pass, no
  errors.
- `test_native_*.gd` (11 tests) pass. No committed test covers the rock
  or arch builders. The full suite was not run.
- Chunk seams: `scratch/shape_cost.gd` compares a chunk's +x edge with
  its neighbour's -x edge: the same bytes at L0, L2 and L4.
- Stills: this worktree's `scratch/rock/` (git-ignored). The `ab3_*`
  sheets show the carve spots; `ab2_*` show close cliffs, lit and in shade;
  `ab_c_*` show close stacks and hoodoos, old against new. Drivers:
  `scratch/rock_views.gd`, `scratch/rock_spots.sh` and
  `scratch/rock_stats.gd` (build cost, and a close still of the nearest
  group: `--close=45 --turn=0`).

## Open

- Sunlit stacks read warmer and lighter than before. The rich pass calms
  the old dark vertical streaks, and lit faces carry their form only by
  the ledges' shadows. This is a matter of taste: judge it in flight.
- The ruins and tunnels use their own stone shader and get none of this.
- The palette is still constants. Making them uniforms would let a region
  or a `--rock-knob` set them.
- The mesh bake is plain GDScript; the cluster gather is the place to
  speed it up.
- The 4 m edge is measured at the chunk's step where that step is coarser,
  so a level change can shift the rims a little. It has not been watched
  in flight.
- Frame time was not measured. The shader adds a few ALU ops and a vertex
  channel.
