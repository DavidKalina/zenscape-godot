# Endless flight: frame rate (round 2, the amberlands' hitches and nodes)

The user found the frame rate uneven, worst entering the amberlands. On the
Windows PC (Ryzen 7 5800X3D, RTX 4070 Super, 154 Hz screen, the game's
1440x900 window with the 3D at 75 %), a frame took about 7.3 ms against the
screen's 6.5 ms. With vsync on, the rate jumped between 154 and 77 fps.
Flying low over the amberlands the main thread set the pace (GPU about
5.8 ms), with build hitches of 10 to 50 ms. Worker threads and the GPU trades
made no difference (round 1 of this investigation).

This round cut the hitches and most of the nodes. The median frame moved
little, so the steady per-frame script is what is left (see Left).

## What changed

1. **Ruin colliders as server shapes** (`scripts/endless/arch_build.gd`
   `_ruin`, `add_shapes`). A ruin's collider boxes go on its body through
   the physics server when it is committed. Each box size gets one shared
   BoxShape3D, kept in the body's meta (a freed shape drops off the body).
   Before, each box was its own CollisionShape3D node. The amberlands' Arches
   go from about 13,600 nodes to under 1,000. A bridge no longer costs
   2 to 6 ms of tree walks and add_child on the frame it joins. The
   colosseum's Feed already worked this way.
2. **Arch commits sliced per arch** (`scripts/endless/land_arches.gd`
   `_commit_one`). A cell commits one arch at a time within the 1.5 ms
   budget, where before the whole cell went in one frame. A cell's records
   stand in `_cells` from its first arch on, so the flight's solid and
   `sets_near` see what is committed.
3. **The shop strip search on a worker** (`scripts/endless/shop_sites.gd`
   `_look_off`, `_tries`). The search ran on the main thread and checked its
   budget only between tries (6 headings × up to 39 land samples). Over
   terraced land that cost 2 to 53 ms a frame while a square was still
   looking. Now one square's tries run on a worker with their own Field. The
   site is named (layout file) and printed on the main thread as before.
4. **Shop materials warmed at setup** (`_warm`). The first shop built in
   flight spent about 27 ms compiling the lamp, glint and pennant shaders.
   They are now compiled at setup on a mesh 10 km down, freed next frame.
   The lamp's glow is one material for every shop.
5. **Each shop's still meshes joined** (`_merged`): one mesh per material and
   shadow setting (the hangar, the mast's pole and bands, the edge posts).
   Shops go from 196 nodes to 58 in a wilderness census. The sock (it
   sways), the pennant (its shader waves it), the glint and the lamp stay
   as they were.
6. **Tree sprites batched per 2x2 blocks** (`scripts/endless/land_trees.gd`
   `_regroup`). The near trees' sprites draw opaque (alpha scissor plus
   alpha-to-coverage) with no distance range, so a bigger batch draws the
   same. There is one batch per variant for each 2x2 group of blocks: 516
   sprite batches become 179, and the Trees go from 1,933 nodes to 1,575.
   A knocked tree's sprite shrinks in its group's batch and in its block's
   own buffer, so it stays down when the group is rebuilt.
7. **Tree colliders as server shapes** (`_fill`). Each tree is a shape on
   its cell's body. A knock disables the tree's shape, where before it
   removed the tree's "T<n>" node.
8. **`--max-fps=N`** (`studies/endless_flight.gd`): a frame cap with vsync
   kept. Pick a rate the machine holds every frame, e.g. 77 or 120 on a
   154 Hz screen, so it never flips between the screen's rate and half of
   it. The default is unchanged (Windows has no cap in project.godot).

Not merged:
- **The trees' trunk, crown and shade batches** and the forest floor. Each
  is culled by the block node's distance (`visibility_range_end`). A bigger
  batch changes when trunks drop, or needs a wider range and draws more.
- **The grass**, as the user asked.

## Flags (each brings back the old behaviour)

- `--ruin-shape-nodes`: one CollisionShape3D node per ruin box.
- `--arch-commit=cell`: a cell's arches all in one frame.
- `--shop-look=main`: the strip search on the main thread, BUDGET_MS a frame.
- `--shop-warm=0`: shop materials compiled on the first build.
- `--shop-merge=0`: one node per shop part.
- `--tree-sprite-groups=0`: one sprite batch per block.
- `--tree-shape-nodes`: one CollisionShape3D ("T<n>") per tree.

All seven together are the "old" column below.

## Numbers

Rendered, 1440x900, `--uncapped`, drive.py's fixed 60 fps step (both
columns fly the same path; wall ms is what each frame cost). Old and new
were interleaved, two rounds each. Other Godot processes were running on
the PC throughout, so the rounds spread by about a millisecond. Driver:
`scratch/perf_cross.gd` with `scratch/ab.sh` (git-ignored).

**Low over the amberlands** (`--world=regions --regions=amberlands:1:start,wilderness:0.01`,
from -200,-1300 at 35 m heading -30°, 4,000 frames):

| | old r1 | new r1 | old r2 | new r2 |
|---|---|---|---|---|
| wall median ms | 7.86 | 7.43 | 8.00 | 7.05 |
| p90 | 13.88 | 11.10 | 11.65 | 10.97 |
| p99 | 26.29 | 15.45 | 16.62 | 14.71 |
| max | 2823 | 29.6 | 84.8 | 36.8 |
| frames > 25 ms | 48 | 1 | 4 | 2 |
| GPU median ms | 5.20 | 5.14 | 5.48 | 5.10 |
| nodes at the end | 12,623 | 2,916 | 12,272 | 2,906 |

The 2.8 s stall in old r1 happened once and may have come from the PC.

**Wilderness into the amberlands** (`--region-border --regions=wilderness:1:start,amberlands:1`,
1,200 m short of the border, 5,000 frames), wilderness part / amberlands part:

| | old r1 | new r1 | old r2 | new r2 |
|---|---|---|---|---|
| wall median ms | 8.59 / 7.04 | 9.09 / 7.68 | 9.16 / 7.21 | 7.64 / 6.99 |
| p99 | 18.4 / 13.7 | 17.3 / 15.2 | 19.4 / 14.6 | 14.6 / 13.2 |
| max | 98.7 / 18.9 | 60.3 / 25.0 | 105.8 / 29.9 | 54.5 / 25.8 |
| nodes at the end | 4,675 | 1,973 | 4,652 | 1,984 |

Here the medians sit inside the noise. The worst wilderness frame drops from
about 100 ms to about 57.

**Per-step maxima** (the tick timed step by step, low amberlands run, the
first changes only, one run each, uncontrolled load): arches.step 10.4 → 5.7 ms,
shops.step 32.6 → 2.5 ms. The hitch log before the change showed bridge
commits of 4 to 6.5 ms (sunlit 1.5 to 2.2, the body walk 0.6 to 1.0,
add_child 1.8 to 3.2), shop searches of 2 to 53 ms, and the first shop build
at 30 to 47 ms.

## Verified

- Headless import; smoke of `studies/endless_flight.tscn` in the default
  world, `--world=wilderness`, and `--world=amberlands --at=476,-948`: no
  errors.
- Ruin colliders: `scratch/ruin_rays.gd` casts 2,700 to 3,150 rays (down and
  across) over the ruins near -477,-520 (bridges, aqueducts) and 476,-948
  (the nave and bridges). The new and old builds hit the same points
  (identical digests).
- Trees: `scratch/knock_check.gd` knocks the nearest tree with a collider
  in both paths. Its collider is gone (a ray down now hits the ground), its
  sprite batch shrinks, and with groups its block's buffer keeps it shrunk
  after every group is rebuilt.
- Stills, old against new (`scratch/stills/`): a wilderness shop with
  woods, and an amberlands bridge. The differences are temporal (grass
  wind, water, cloud shadows, tree sway), spread evenly over the frame,
  with nothing on the shop or the bridge (mean 1.7 to 3.5 of 255).
- `tests/test_world_scale_guard.gd` passes. No other committed test touches
  these files. The full suite was not run.

## Left

- **The median is set by the steady per-frame script** (about 4.5 ms over
  15 systems; none alone over about 1 ms). In the low amberlands run:
  `_react` 0.95 ms (eddies about 0.5, motes about 0.5: grass reaction,
  left alone), birds 0.45, grass 0.44, `look.step` 0.45, near misses 0.43,
  `_frame` 0.37, traffic 0.2, knock.before 0.2. No step offered a clear
  cut without changing behaviour. Next round: read each for per-frame
  allocations and work that could run every few frames.
- **Halls' colliders**: land_halls makes a CollisionShape3D per box (2,556
  in one amberlands census). They could take the same server-shape path.
- **The remaining hitch sources** (single frames of 4 to 8 ms): tunnels,
  halls and land commits; traffic and beats steps.
- **The trees' trunk, crown, shade and floor batches** (about 1,000 nodes in
  the wilderness): merging them would need visibility ranges per tree in
  the shaders.
- **The Mac** was not measured.
