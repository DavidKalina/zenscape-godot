# World regions: handoff

`--world=regions` plays one endless world stitched from regions, which are
the existing world profiles (`wilderness`, `overgrown`). The spec is
`spec-world-regions.md`, and the loop's commits are `ITER(world-regions)`
on `claude/world-regions-flight-b54ec7`. The default world is still
`wilderness`. You decide after playing whether regions becomes the default.

```
& $env:GODOT --path . studies/endless_flight.tscn -- --world=regions --no-title
& $env:GODOT --path . studies/endless_flight.tscn -- --world=regions --region-border --region-debug --no-title
```

## What it does

- **Map.** Each region is a warped Voronoi cell, about 6 km across (one
  site per 6 km square, jittered, the point warped by two octaves of value
  noise). Cells get regions by an R2 walk over the shares, so the shares
  hold and no run of one region is longer than 3 cells in a line.
  Weights are exactly 1 inside a cell and ease over a band of 1.5 km
  (`scripts/endless/world/region_map.gd`).
- **Land.** `LandField` grows one field per region recipe (native where
  built) and blends heights, meadow, rivers and colour by weight on a 64 m
  lattice (`scripts/endless/land_blend.gd`).
  - A chunk wholly inside one region is that region's own native chunk,
    the same path as before.
  - A region with sharp forms (mesas, terraces, notches, crisp ridges)
    also grows a soft twin. The sharp forms come in by w³ over the band,
    so they don't stand as thin steps.
  - Seams are 0 at every LOD. The collider equals the mesh.
- **Flora.** Trees and grass come from each region's own tables. In the
  band they are dithered per tree and per tuft by the land's weights
  (`land_trees.gd` `_build_mixed`, `endless_grass.gd` `_dither`).
- **Paint.**
  - The sky (mood and hour), sea, globals and grass underside blend by
    the eye's weights.
  - The ground carpet, the far tuft ring and the grass underside are
    painted per spot from a region-weight map round the eye
    (`zs_region_map`, `shaders/region_paint.gdshaderinc`).
- **Layers.** Overgrown's halls and tunnels stand only where their whole
  footprint, plus 128 m, lies inside a region that grows them. Arches
  follow the region mask, so the trees agree with them.
- **Caption and debug.**
  - A caption names the region when its weight under the plane passes
    0.7.
  - `--region-debug` shows the region, the cell and the weights.
- **Start.** You start inside a wilderness cell, 1.5 km clear of the band,
  with a border under a minute away at cruise.
  - `--region-border` starts you 600 m short of the nearest border,
    heading across it.

## Registering a region

1. Write `scripts/endless/world/profiles/<id>.gd` the same way as any
   world: `id`, `title`, `land`, `flora`, `paint`, `layers` and `spawn`
   (see `profiles/overgrown.gd`). It plays alone as `--world=<id>`.
2. Add one entry to `REGISTRY` in `scripts/endless/world/regions.gd`:
   `{"id":"<id>","share":1.0,"start":false}`. `share` is any positive
   number; the shares are normalised. `start` says whether the start may
   lie in it, and at least one entry needs `true`.

You don't need to do anything else. The land blend, the soft twin for
sharp forms, the flora tables, the paint arrays and the layer gates all
read the profile.

- **A fifth region.** The paint map holds 4 regions (RGBA). Regions 4 and
  up fall back to the eye's paint. Widen to a second texture in
  `profiles/regions.gd` (`_paint_spots`) and `region_paint.gdshaderinc`.
- **New paint keys.** A shader key gets per-spot paint when its shader has
  a `<key>_r` array uniform. Otherwise it blends by the eye.

## Knobs

These are flags. The registry only sets the defaults.

| flag | default | what |
|---|---|---|
| `--world=regions` | (wilderness) | play the patchwork |
| `--regions=id:share[:start],...` | the registry | the list for a run, e.g. `--regions=wilderness:2:start,overgrown:1` |
| `--region-size=` | 6000 m | the cells' spacing |
| `--region-blend=` | 1500 m | the band's width |
| `--region-seed=` | `--seed=` | the layout's own seed |
| `--region-border` | off | start 600 m short of the nearest border, heading across |
| `--region-debug` | off | region, cell and weights on screen |

Every other world flag (`--halls=`, `--tunnels=`, `--arches=`, `--ground-set=`,
`--mood=`, `--hour=`, ...) applies to every region and wins over each one.
`--land-native=0`, `--trees-native=0` and `--grass-native=0` work as
before.

## Checks of the last round (task 6)

### Unchanged worlds

- `tools/land_hash.py`: wilderness seed 1 gives exact `c515311f…`, the
  same as at the spec. Seed 7 (`cd244951…`) and overgrown seed 1
  (`9385c033…`) were last checked in task 5.
- The land and field code paths for uniform worlds are untouched.

### Flats

`scratch/regions/flats.gd` uses the overgrown rounds' method.

- A cell is flat when it slopes no more than 0.06 over 64 m and is dry.
- A strip is 192 m of flat cells in a line, within 3 m of height.
- For each 256 m land block, the scan measures the distance from its
  centre to the nearest strip.
- The scan covers a 12 km square centred on each seed's regions start, and
  each world is scanned over the same square.
- A "band" block is one where no region's weight passes 0.99 at its
  centre.

Each cell reads ">400 m / >600 m / worst m":

| seed | regions, band | wilderness, same blocks | overgrown, same blocks | regions, inside | regions, whole square |
|---|---|---|---|---|---|
| 1 | 30 / 14 / 1104 (337 blocks) | 22 / 9 / 1233 | 6 / 3 / 803 | 73 / 23 / 1328 | 103 / 37 / 1328 |
| 3 | 18 / 2 / 668 (320) | 23 / 4 / 816 | 14 / 0 / 590 | 69 / 22 / 1103 | 87 / 24 / 1103 |
| 7 | 14 / 4 / 842 (421) | 18 / 2 / 665 | 13 / 3 / 755 | 63 / 16 / 852 | 77 / 20 / 852 |
| 42 | 49 / 10 / 830 (378) | 38 / 5 / 725 | 20 / 3 / 736 | 100 / 34 / 1277 | 149 / 44 / 1277 |

The square as a whole, wilderness then overgrown:

- seed 1: 117 / 40 / 1586, then 57 / 21 / 1328
- seed 3: 129 / 34 / 1103, then 35 / 1 / 604
- seed 7: 97 / 19 / 829, then 54 / 8 / 879
- seed 42: 146 / 42 / 1396, then 70 / 18 / 912

What this shows:

- A landing flat stays in reach across borders as it does inside a
  region. In every seed, the band's worst block is no farther than the
  worst block inside the regions.
- The band runs a little behind its two parents on seeds 1 and 42. Over
  the band the blend tilts the land by (h1 − h2) / 1500, so 60 m between
  the two regions' heights adds 0.04 of slope. That tilt eats into the
  0.06 limit.
- If it matters, a softer blend of heights only over meadows would win
  flats back.

### Frame time

These are rendered runs at 1440x900 with `--uncapped`, flying at boost
with an A/D weave for 60 s of real time each
(`scratch/regions/perf.gd`, `drive.py --rendered --no-fixed-fps`).

Each cell reads "wall mean / p95 / p99 / max ms", with GPU mean / p95.
The first few seconds after ready are left out, and so is the first
frame, which is the first draw.

| run | frames | wall | GPU | hitches >25 ms |
|---|---|---|---|---|
| wilderness, run 1 | 7166 | 7.54 / 11.58 / 12.49 / 17.4 | 7.33 / 11.45 | 0 |
| wilderness, run 2 | 5978 | 9.03 / 9.95 / 10.35 / 13.9 | 8.94 / 9.83 | 0 |
| regions, inside (default start, the whole minute in wilderness) | 6370 | 8.48 / 9.79 / 10.22 / 51.0 | 8.37 / 9.68 | 1 (51 ms, main-thread 19.6 ms, at 10 s while the start streamed) |
| regions, crossing the band (`--region-border`, 2471 m of band) | 6129 | 8.82 / 10.75 / 11.92 / 41.6 | 8.70 / 10.61 | 2 (41.6 ms just after the first frame; 38.1 ms at 12 s, main-thread 32 ms with 21 chunks queued) |

- **The flight.** Flying inside a region costs what it costs today.
  Crossing a border at boost costs about the same per frame, with no
  hitch at the crossing. Render CPU in the band averages 1.1 ms (p99
  2.0).
- **Run 3.** A third run across the band, after the prime fix below,
  gave p95 12.2 and p99 12.8 ms. Its GPU ran about 2 ms slower overall:
  overgrown inside that run took 11.8 ms. The one hitch was 55 ms at 13.6
  s, with 24 ms of main-thread work.
- **Slowest commits.** Land: 15 to 17 ms in both worlds.
- **First frame.** 3.0 s in wilderness, 5.6 s in regions and 6.4 s at
  `--region-border`. Regions has more shader variants (the region paint).

### Cost of one band item

These are worker functions run on the main thread, headless, along the
`--region-border` line (`scratch/regions/costs.gd`). They cost a worker's
time, not a frame's.

| item | band | pure in regions | wilderness | overgrown |
|---|---|---|---|---|
| land chunk L0 (64 m) | 45 ms | 7 ms | 4-5 ms | ~24 ms* |
| land chunk L1 to L4 | 44-51 ms | 10-16 ms | 4-10 ms | 23-31 ms* |
| tree block (256 m) | 169 ms (max 230) | 21 ms | 5 ms | 8 ms |
| tree far cell (1 km) | 115 ms (max 146) | 19 ms | 9 ms | 14 ms |
| grass near cell, both carpets | 300 ms (max 370) | 71 ms | 67 ms | 89 ms |
| grass far cell | 63 ms | 10 ms | 8 ms | 30 ms |

\*Overgrown's own world was timed while it was still streaming its start,
so its numbers are high.

- A band item costs 4 to 9 times a native one. Each one is GDScript over
  the blend: every region's native build, then a per-vertex or per-tree
  mix.
- **Threads.** The band work also scales badly over threads
  (`scratch/regions/par.gd`, 16 jobs on 16 threads against serial):
  - blended point samples: 1.7x
  - band chunks: 3.4x
  - wilderness point samples: 2.0x
  - native wilderness chunks: 7.6x

  The likely cause is many dynamic GDScript-to-native calls per sample.
  That is why the band's cost shows up in load time, not in frame time.

### Load time

| start | ready, rendered | ready, headless smoke | every queue empty, rendered |
|---|---|---|---|
| wilderness | 9.9-10.3 s | 7.7 s | 13.4 s |
| regions (default) | 20.0 s | 15.1 s | 45 s |
| regions `--region-border`, before the fix | 81.4 s | 42.0 s | |
| regions `--region-border`, now | 41.0 s | 34.9 s | not within 60 s |

The starting prime, headless, `--region-border` (before the fix):

- land 6.4 s (wilderness 0.74 s)
- trees 27.9 s (wilderness 0.32 s)
- grass 1.1 s

The default regions start primes land in 5.2 s and trees in 2.3 s.

**Fixed this round.** The trees' prime built every block and far cell the
rings want, and waited for them. In the band those builds are GDScript, and
they starved each other on the workers. Now, in a world of regions, the
prime leaves band far cells past `PRIME_BAND_FAR` (2 km) to stream after
the start. Those far cells fill in within about 20 s
(`scratch/regions/fill.gd`), at 1 km and more away.

- Blocks are still all primed: with them streamed instead, the mid ring
  was patchy for about 40 s.
- Uniform worlds don't take this path.

**Still open.** The land prime adds about 5 s to every regions start. It
comes from the band chunks' per-vertex GDScript blend.

### Tunnel startup ("built in ~10 s worst")

This was contention, not the tunnel. Its build (`_make`, about 250 ms
alone) ran on a worker while the trees' band prime flooded the pool.

- After the prime fix, a start beside a tunnel
  (`--at=-1578,200 --heading=189.5`) reports "built in 1117 ms worst".
- `--world=overgrown` at the same spot reports 503 ms.

### Smoke and stills

- **Smoke.** `tools/smoke.py studies/endless_flight.tscn` passed with 0
  errors for each of:
  - no flag
  - `--world=overgrown`
  - `--world=regions`
  - `--world=regions --on-foot`
  - `--world=regions --region-border --region-debug`
  - `--world=regions --region-border --land-native=0`
- **Stills** (`captures/regions/`, git-ignored):
  - `final_border_0/1/2.png`: the `--region-border` start at 250 m, then
    10 s and 25 s on into the band. The paint, sky and land ease from the
    alpine morning to overgrown's straw and violet. No gaps show in the tree rings.
  - `final_same_sheet.png` and `final_same_crop.png`: the same spot at
    overgrown weight 0.7, `--world=overgrown` against `--world=regions`.
    The dashed light line along the ridge crest and the pale ground
    facets are in plain overgrown too. Neither comes from the band.

## What's stood in or open

- **Tunnels are rare** with 6 km regions: 2 in a 32 km square on seed 1,
  against 35 in the overgrown world. A tunnel needs a 2.5-3 km box with
  128 m clear, wholly inside overgrown. `--region-size=9000` or more gives
  more. `--tunnel-test` still places its tunnel at the start, whatever
  the region.
- **The paint map holds 4 regions.** See above.
- **The pale rectangular ground facets** were here before regions. They
  show the same way in plain `--world=wilderness` and `--world=overgrown`.
  Look at the land chunks' far LOD and vertex colour, not the regions code.
- **Band work is GDScript.** That covers the land chunk blend, band tree
  blocks and far cells, and band grass. It only costs load time and
  streaming backlog; frame time holds. To speed it up:
  - The leads are a native blend kernel (`LandBlend.build_chunk`'s
    per-vertex loop) and band trees planned natively per region over each
    region's own field, with heights then read from the blend. Any native
    change means rebuilding the Windows DLLs (debug and release) and the
    Mac dylib.
  - A band grass cell grows twice when the two regions' carpets differ.
    It could grow the grass once when the two differ only in flowers.
- **Near trees' autumn** stays by the eye. The near crowns' shader comes
  from `geometry.scn`.
- **Native code.** This loop changed none, so the Mac dylib needs no
  rebuild.
- **Exit noise.** Regions runs end with about 50-70 "ObjectDB instances
  leaked" lines and rendered runs with "shaders never freed". This is the
  same exit noise as in earlier rounds; no script errors.
