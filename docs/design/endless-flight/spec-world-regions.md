# Spec: world regions (loop `world-regions`)

Endless flight becomes one world stitched from regions. Fly any heading and
you cross from one region into the next: the land, its grass and trees, its
ground paint and its sky change across a border band, with no seam, cliff or
pop. Each region is an existing world profile (`wilderness`, `overgrown`), and
adding one later is a profile script plus one line in a registry.

Read first: `world-profiles-handoff.md` (the seam this builds on, and its
**Regions** section, which already sketches the plumbing),
`overgrown-tunnels-handoff.md` (the overgrown layers: halls and tunnels), and
`scripts/endless/world/world_profile.gd`.

## What the user decided

- **Borders blend.** Over a band about 1.5 km wide the land itself morphs
  (wilderness hills ease into overgrown terraces and mesas), and the grass
  colour, the trees, the ground paint and the sky shift as you fly over. One
  continuous world, not islands or walls.
- **Size.** A region is about 6 km across, about 2 minutes at boost.
- **Layout.** A patchwork from the seed: irregular cells (warped Voronoi or
  similar) scattered endlessly over the map, each given a registered region
  by its share. Any heading reaches new ones. Neighbouring cells may hold the
  same region; that is fine, but runs of one region should not go on far
  (no run of more than about 3 cells in a line from one region when two or
  more are registered).

## Done (what the user plays and sees)

- `--world=regions` plays the patchwork world. The start is inside a
  wilderness cell, well away from a border, and a border is within about a
  minute's flight.
- Flying across a border by hand at cruise and at boost: the land rises,
  falls and changes kind smoothly; no cliffs, steps, holes or seams in the
  ground, at every LOD and in the colliders; rivers and coast don't end in a
  wall. Grass and trees change share, kind and colour across the band with no
  hard line of cells popping. The sky (mood and hour), the ground paint, the
  far tuft ring and the sea's tint ease over the band as the eye crosses it,
  with no snap.
- Each region's own layers only stand inside it: overgrown's halls and
  tunnels sit wholly inside overgrown cells, clear of the band (their massifs
  and cuts never straddle a border). Arches follow the region mask too, so the
  trees agree with them.
- A small caption names the region when you cross into it (its profile's
  `title`), and a debug flag shows where you are (region, weights).
- **Registering a region later** is: write `profiles/<id>.gd` as today, add
  one entry to the registry (`id`, `share`, whatever else the registry needs,
  e.g. whether it may hold the start). Nothing else. A doc section says so.
- **Knobs** (flags, the profile only sets defaults, as everywhere):
  region size, blend width, the registry's list and shares, a separate
  region-layout seed, and a test start at the nearest border heading across
  it (e.g. `--region-border`), so the user can try a crossing in seconds.
- **Meadows and flats** (AGENTS.md): a landing flat stays in reach across
  borders as inside each region. Check with a flats scan across a few borders
  (seeds 1, 3, 7, 42).
- **Unchanged:** `--world=wilderness` (the default) and `--world=overgrown`
  play exactly as before: wilderness's `tools/land_hash.py` (seed 1
  `c515311f…`, seed 7 `cd244951…`) and overgrown's hash before/after match.
  The default world stays wilderness; the user decides after playing whether
  regions becomes the default.
- **Frame time:** chunks wholly inside one region cost what they cost today
  (the native path untouched). Report the cost of border chunks and of
  flying across a border at boost (rendered, `--uncapped`), against flying
  inside one region.

## How (leads, not rules)

- The regions world is a WorldProfile with `uniform = false` holding its
  child profiles and the region map; it answers `at`, `weights_at` and
  `layer_at`. The registry is its own small file, e.g.
  `scripts/endless/world/regions.gd`.
- Land: per the handoff, one field impl (native where available) per child
  recipe inside `LandField`, blending heights and meadow by weight per
  sample, and only where a chunk isn't wholly one region (test its corners,
  with the band's width as the margin). The land is all local per-point
  noise (rivers, coast and ponds included; hall and tunnel carves applied on
  top in `sample`/`shape`/`apply_chunk`), so a per-sample blend is sound.
  Keep it deterministic and thread-safe (every worker builds the same land).
  Watch `river_y`, `colour`, `snow_line`, ponds and anything else a caller
  reads from the field: they must agree with the blended heights.
- Flora: one native grass and tree object per child profile, picked per cell
  or block. Dither by weight in the band so there is no hard line.
- Paint: today each profile's paint is applied once at setup. Grass colour is
  per-instance colour times shader globals and uniforms; the ground is one
  material. The ground and grass colours need a per-spot answer (e.g. a
  low-resolution region-weight texture the ground and grass shaders sample
  around the eye, or per-instance colour baked from the region at grow time).
  The sky, sea and globals can blend by the eye's weights live; the look
  already changes mood and hour at runtime (`show_mood`, `set_phase`).
- Halls and tunnels: gate their sites with `at(site)` and keep each site's
  whole footprint (massif, cut) inside its region away from the band.

## Where

- Branch `claude/world-regions-flight-b54ec7`, worktree
  `C:\Users\Tenut\zenscape-godot\.claude\worktrees\world-regions-flight-b54ec7`
  (Windows), on main with the overgrown tunnels merged. Already set up with
  `tools/worktree.py setup` (native kernels in place).
- One trunk, no lanes: everything hangs off the region map and the blended
  field.
- A native change (a `configure_regions` in C++, say) is allowed if it pays
  for itself; rebuild the Windows DLLs (debug and release,
  `docs/desktop-builds.md`) and keep GDScript and native bit-for-bit, and say
  in the handoff that the Mac dylib needs rebuilding.

## Checks each iteration

- Smoke (`tools/smoke.py`) of `studies/endless_flight.tscn` with no flag,
  `--world=overgrown`, `--world=regions`, and `--world=regions --on-foot`
  (and `--region-border` once it exists).
- Flight across borders through the real play loop (`tools/drive.py`, a
  hand-like weave, not one exact line), left in `scratch/`.
- Stills (`tools/shot.py`, `-- --no-title`) for anything seen: a border from
  the air at a few heights, looking along and across it, and from the ground.
  Look at them and fix before committing.
- From the land blend on: `tools/land_hash.py` for wilderness and overgrown
  unchanged, and a seam scan across borders (height steps between adjacent
  samples, chunk edges at each LOD, collider vs mesh).

Prototyping rules hold: no committed tests, no full suite.

Cap: the skill's default.
