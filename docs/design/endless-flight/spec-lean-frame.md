# Endless flight: the lean frame (scope)

The user never opens the editor, so the game does not need a node for
everything it spawns. This scopes how far to take that: from fewer nodes,
to one tick for every system, to one native node that owns the streamed
world. It also covers graphics presets, upscaling and picking settings on
first boot (see Graphics presets). Nothing here is built yet.

## Where it stands (2026-10-29)

From `frame-rate-round2-handoff.md` and `native-react-birds-handoff.md`
(Windows PC: 5800X3D, RTX 4070 Super, 1440x900 at 75 % 3D):

- Low amberlands line: wall median about 6.9 to 7.0 ms, GPU median about
  5.1 ms, p99 about 15 ms, about 2,900 nodes at the end.
- The median is set by steady per-frame script, about 4.5 ms over 15
  systems before the native react and birds round took about 0.85 ms off.
  None alone is over about 1 ms. Named: `look.step` 0.45, near misses 0.43,
  grass 0.44, `_frame` 0.37, traffic 0.2, `knock.before` 0.2.
- Hitches left: single frames of 4 to 8 ms from tunnel, hall and land
  commits, and traffic and beats steps.
- The plane is already not a physics body: it samples the height field
  (`studies/endless_flight.gd` `plane_ground`). Physics is used for
  near-miss rays, the crash box query, the sound probe and the land's
  colliders near the eye (`land_stream.gd` `_collide`, Jolt, 60 Hz).

Two things follow:

1. **Node count is no longer the main cost of the median.** It went from
   about 12,000 to 2,900 and the median moved about 0.5 ms. What is left is
   script work per frame, and hitches when things are added to the tree.
2. **On this PC the GPU (about 5 ms) is the floor.** Cutting the CPU below
   it shows up as smoother frames, not more of them. On low-end hardware
   (the 1.0 target) the GPU will likely be the wall, and nothing here fixes
   that. That is a separate looks-and-presets round.

## What still makes nodes

Per the code (counts are structural, not measured):

- Already server-side: ruin collider shapes (`arch_build.gd`), tree
  colliders (`land_trees.gd`), bird buffers (`endless_birds.gd`), sea FFT
  and foam (`RenderingDevice`).
- Still a node each:
  - land chunks: a MeshInstance3D per chunk, a StaticBody3D +
    CollisionShape3D per near chunk (`land_stream.gd`)
  - rocks: Node3D + MeshInstance3D + StaticBody3D + CollisionShape3D per
    rock (`land_rocks.gd`)
  - halls: a CollisionShape3D per box, 2,556 in one amberlands census, plus
    a MeshInstance3D per piece (`land_halls.gd`)
  - tunnels: meshes, bodies, 16 torch OmniLight3Ds and spot lights
    (`land_tunnels.gd`)
  - grass: a Node3D per tile and holders per cull group
    (`endless_grass.gd`)
  - trees: trunk, crown, shade and floor batches per block, about 1,000
    nodes in the wilderness (`land_trees.gd`)
  - shops, beat marks, rival marks, fish (a MeshInstance3D and an
    AudioStreamPlayer3D each), traffic planes, felled trees
- About 40 scripts define `_process`. Several are one per object: per
  breakable ruin (`breaks/breakables.gd`), per ruin LOD (`ruin_lod.gd`
  polls a worker), per arch build, per flame, per rope bridge, per lake.

## Rounds

Each round keeps a flag back to the old path, as the frame rate rounds did,
and is measured old against new, interleaved.

### 0. A bench, committed (small, do first)

There is no committed bench. Round 2's numbers came from
`scratch/perf_cross.gd`, which is git-ignored. Make it a harness tool:

- `tools/perf.py <route>`: rendered, one window, `--no-title`, a named
  route (`amber-low`, `wild-into-amber`, `wild-spawn`, plus a tunnel and a
  hall run), N frames. It prints wall median, p90, p99, max, frames over
  16.7 and 25 ms, GPU median, node count (`Performance` monitors) and
  draw calls.
- `--systems`: per-system ms from one timing hook in the main tick, with
  no hand-instrumented copies.
- `--ab "<flags>"`: interleaved old and new rounds, like `scratch/ab.sh`.
- Run once at a low-end preset (`--rendering-method mobile`, lower 3D
  scale) to see whether the CPU or the GPU sets the pace there.

Output: the baseline table and a ranked list of the 15 systems. The rest of
this spec is re-ordered by what it shows.

### 1. Node diet (servers for everything the land spawns)

Make the rule: nodes for the few things that are authored (plane, camera,
HUD, sky, sea); `RenderingServer` instances and `PhysicsServer3D` bodies
for everything the land streams in.

- Halls' colliders as server shapes (the round 2 path, about 2,500 nodes).
- Rocks: instance, body and shape RIDs instead of four nodes per rock.
- Land chunks: a `RenderingServer` instance per chunk mesh; near colliders
  as server bodies.
- Grass tiles and tree blocks: the holder Node3Ds go. Cull ranges become
  per-instance visibility ranges on the RIDs.
- Tunnel torches: keep the lights (they need nodes or light RIDs), merge
  the rest.

Gain: mostly the commit hitches (add_child, tree walks, the `sunlit` walk),
and nodes heading under about 1,000. Probably little on the median.

Breaks: anything that finds land pieces by node path or name. Tree knock
(`"T<n>"` is gone already), break kinds that look up a piece's node, drive
helpers and tests that walk the tree. Pieces need an id-to-RID table in its
place. Layout handles (`<route>/<piece>`) and RuinKit piece ids stay as
they are.

### 2. One tick

Replace the per-node `_process` calls with one scheduler in the main tick:

- Systems register with a rate (every frame, every 2nd, every 4th, or on a
  budget) and a time slot, so the light ones stagger across frames.
- Per-object ticks (breakables, ruin LOD polls, flames, rope bridges,
  lakes, arch builds) become one loop over arrays in their system.
- The timing hook from round 0 lives here, so every system is measured
  forever at no cost.
- Read each of the 15 systems for per-frame allocations (new Arrays,
  Dictionaries, Callables) and work that could run every few frames.
  Round 2 named that as the next step.

Gain: the steady median, likely 1 to 2 ms on this PC (an estimate, to be
checked against round 0).

### 3. Native ports, ranked by the bench

The motes, ribbons and birds pattern: the inner loop goes to C++
(`native/terrain_kernels/`), the GDScript stays as fallback and reference,
bit-for-bit checked. Likely candidates: near misses (batch its rays, or
sample the height field and ruin boxes in C++ instead of physics rays),
`look.step`, grass, traffic, the remaining spawning spikes in motes.

Each port costs a Mac rebuild and a Mac equivalence run.

### 4. The world core (only if 0 to 3 show the tree still costs)

One GDExtension node, e.g. `ZenScapeWorld`, owns the streamed land: chunk,
rock, ruin and dressing records in flat arrays, their render and physics
RIDs, streaming and commit slicing, on its own worker threads. GDScript
keeps the rules, the recipes and the flight. The scene tree keeps about a
dozen nodes.

This is the "one node" end. It is a large rewrite of land_stream, rocks,
arches, halls and tunnels, and every later land feature has to be written
against it. Do it only if the bench shows the tree or GDScript glue is
still a large share after rounds 1 to 3.

## Graphics presets (ideas, not started)

The CPU rounds above make frames even. The GPU is what decides whether a
weak machine can run the game at all, and the grass and trees are likely
the biggest GPU costs. This part is about presets, upscaling and picking
settings on first boot.

### Targets (the user's, 2026-10-29)

- **Must:** a locked 60 fps on max settings on an RTX 4070 Super at 1080p
  and 1440p. Upscaling a little is fine.
- **Ideal:** a locked 90 fps at the player's chosen settings, everywhere.
- **Weak hardware:** a locked 30 fps is acceptable.
- The looks come first. A higher rate is better, but not at the cost of
  what makes the game look the way it does at the top preset.

Locked is what matters: the cap is set to a rate the machine holds on its
worst frames (p99), not its median. Budgets: 90 fps is 11.1 ms, 60 is
16.7 ms, 30 is 33.3 ms.

A warning on the "must": today's numbers are at 1440x900 with the 3D at
75 %, about 0.73 megapixels drawn. 2560x1440 native is 3.7 megapixels,
five times as many. If the GPU's 5 ms is mostly per pixel, 1440p native
lands near 15 to 25 ms, so 1440p max will need upscaling (a 3D scale of
about 0.67 to 0.77). Round 0's bench should measure 1080p and 1440p at
several scales before any preset is set.

### What exists now

- `scripts/render_resolution.gd`: a render cap in lines (Native, 1440p
  down to 540p) kept in `user://look.cfg`. FSR 1 upscaling (MetalFX on the
  Mac), `--render-upscale=fsr2` or bilinear, and `--render-scale=X`. It
  already picks a default on its own: native on a discrete GPU, 1080 lines
  on anything else (`default_cap`).
- `scripts/endless/endless_look.gd`: `--msaa=`, `--aa=smaa|fxaa`,
  `--taa=`, `--ssao=`, `--shadow-size=`.
- `project.godot`: directional shadow 8192 with soft filter quality 3,
  MSAA 2x, volumetric fog volume 256 x 256. These are top-preset numbers.
- `endless_grass.gd`: `--grass=` (share), `--grass-range=`, `--grass-lod=`,
  `--grass-cull=`, `--grass-far-lod=` and more. Trees: `--far-trees=`.
- `scripts/look_pass.gd`: an older quality tier (Beauty, Balanced, Ultra)
  from the diorama days. Fold it in or retire it.
- `project.godot` caps the Mac at 60 fps. Windows has no cap.

So most of the knobs exist as launch flags. A preset is mostly a table
that sets them, plus a menu and a saved choice.

### Presets

Low, Medium, High, Ultra, and Custom (any knob changed by hand). Ultra is
today's look. Each knob reads its value from the preset table, and a
launch flag still wins for captures. A first cut of what moves:

| Knob | Ultra | High | Medium | Low |
|---|---|---|---|---|
| 3D scale + upscaler | native or ~0.77 FSR 2 | ~0.77 FSR 2 | ~0.67 FSR 2 | ~0.5 FSR 1 |
| Anti-aliasing | MSAA 2x + SMAA, or TAA under FSR 2 | same | FSR 2's own | FXAA |
| Grass | today's share and range | less range | about half the blades, shorter range | sparse near blades, a painted grass tint on the ground beyond |
| Trees | today's | sprites start nearer | sprites sooner, fewer far trees | sprites only past the near ring |
| Shadows | 8192, soft 3 | 4096, soft 2 | 2048, soft 1, grass casts none | 2048, hard, no grass or far tree shadows |
| Land reach / chunk detail | today's | today's | one quadtree level coarser far out | coarser, shorter |
| Clouds (volume march) | today's steps | fewer steps | half steps, lower res | sheet only |
| Fog volume | 256 | 160 | 96 | 64 or off |
| SSAO, glow, light shafts | on | on | SSAO off | all off |
| Water (FFT size, reflections) | today's | today's | smaller FFT | smallest FFT, no planar reflection |
| Birds, motes, ribbons | today's | today's | fewer motes | fewer flocks and motes |

The numbers are guesses for the bench to fix. Grass and trees need the
most care: the low end has to keep the sense of a meadow, so it should
get its own look pass (blade width and colour, a ground tint where blades
stop) and not just thinner grass. Every preset keeps the meadows and flats
readable for landing.

### Frame cap

A setting with 30, 60, 90, 120, the screen's rate, or Uncapped, with
vsync. The current `--max-fps=N` becomes the setting. Each preset suggests
a cap. Under a fixed cap, pacing matters more than the median, so the
bench reports p99 against the cap.

### Auto-detect on first boot

Pick a preset before the player sees the game, and always let a manual
choice win.

1. **First guess from the hardware.** Adapter type (discrete, integrated,
   Apple), the GPU's name and VRAM (`RenderingServer`), CPU core count.
   That gives a starting preset and resolution, as `default_cap` does now.
   A table of known GPUs goes stale, so keep it to a rough guess.
2. **A short real check.** On first boot, behind the title or the menu,
   fly a fixed 10 to 15 second camera path over grass, trees and ruins at
   the guessed preset. Measure GPU time
   (`RenderingServer.viewport_set_measure_render_time`, which the F1 line
   already reads) and CPU time per frame. Step the preset or the 3D scale
   down until p95 fits the target cap with about 15 % headroom, and up
   once if it fits easily. Save the result in `user://look.cfg`.
3. **Re-check** when the GPU or driver name changes, or from a "Detect"
   button in Settings.
4. **Steam Deck.** Detect it (Steam's environment variable or the GPU
   name) and use a Deck preset: 1280x800, about 0.67 scale with FSR, a 30
   or 40 fps cap. Deck Verified is worth aiming for.

### Dynamic resolution (optional, later)

Godot has no built-in dynamic resolution, but the game can do it: read the
GPU time each frame and nudge `scaling_3d_scale` between a floor and 1.0
to keep under the cap. With FSR 2 the changes are hard to see. It holds a
locked rate through heavy spots (dense forest at sunset, the colosseum)
without dropping the whole preset. Off by default until it is shown
not to shimmer.

### Not in Godot by default

DLSS and XeSS are not built in (FSR 1, FSR 2 and MetalFX are). A
third-party plugin could add them later. FSR 2 is the main tool for now.

### How this fits the rounds

- Round 0's bench takes a `--preset=` flag and a resolution, so each
  preset gets a table on the 4070 Super at 1080p and 1440p, and on any
  weaker machine at hand (the Mac, an integrated GPU, a Deck).
- The preset round comes after round 0. It does not wait for rounds 1 to
  4: the presets are mostly GPU, the rounds are mostly CPU.
- A low-grass and low-tree look pass is its own round, judged by eye, as
  the user plays it.

## Order and size

| Round | Size | Main gain |
|---|---|---|
| 0 bench | small, one agent | knowing where the time goes |
| presets + auto-detect | medium | runs on weak hardware, locked rates |
| low grass and trees look | medium, by eye | the biggest GPU cost on low presets |
| 1 node diet | medium, can split by system | hitches, node count |
| 2 one tick | medium | steady median |
| 3 native ports | one agent per system | the top systems' ms |
| 4 world core | large, a loop (skill `iterate`) | only if needed |

Rounds 1 and 2 touch most of `scripts/endless/`. They clash with any other
work in those files, so run them when the land is quiet.

## Proof

Per round: headless import, smoke of `studies/endless_flight.tscn` (plain,
`--world=amberlands --at=476,-948`), the bench old against new on the named
routes, stills old against new where the look could change, and ray digests
for any collider moved to the server (as `scratch/ruin_rays.gd` did).
Committed tests come in a lock-in round. The Mac is measured after its
kernels are rebuilt.
