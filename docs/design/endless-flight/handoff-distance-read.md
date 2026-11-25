# Handoff: the land reading with depth (distance read), round 1

A prototype round. Nothing is committed as a test. Every part has a flag
that turns it off.

## What changed

1. **Haze through the middle distance, and more of it on far crowns.**
   - The depth fog's curve is now 0.5 (was 0.75). Begin (120 m) and end
     (7600 m) are unchanged. At 1 km the fog's share goes from about 0.09
     to 0.2, at 2 km from 0.25 to 0.4, and at 150 m it stays about 0.01.
   - Godot's aerial perspective by day is now 0.42 (was 0.35).
   - The ground's own haze (`endless_height_haze`) reads the engine's
     numbers every frame, so it follows on its own.
   - Every tree crown is mixed a further share toward the haze colour:
     `zs_tree_haze`, none inside 150 m, full (0.35) by 1.8 km. This covers
     the near crowns (`reference_surface`), the rings, the far crowns, the
     sprites and the painted canopy on the forest floor.
   - The tree haze colour is the mood's own horizon colour (`endless_look`
     `horizon`), 55% toward its grey and 10% lighter. That makes it relative
     to each mood.
   - All of this fades with the sun. It is full by day, 80% less at golden
     hour (`zs_haze_sun`), and off once the sun is down
     (`DistanceRead.day_share`). Without that, at dusk the far woods turned
     pink and lighter than the ground.
   - Code: `scripts/endless/distance_read.gd` (knobs, flags, globals),
     `scripts/endless/endless_look.gd` (`setup` and `_haze`),
     `shaders/distance_read.gdshaderinc`.
2. **Darker, cooler grass under the woods.**
   - The signal is the one the forest floor already used: each near
     block's floor sheet weight (TreePlan `floor_weight`, the vertex alpha
     of `_floor_arrays`). No new plan or noise.
   - `scripts/endless/wood_map.gd` stamps those weights into a wrapped
     256x256 R8 texture, one texel per 16 m lattice node, as blocks stand.
     It clears a block's square as the block goes and uploads at most once
     a frame (64 KB), only after a change.
   - Both tuft rings read it in the vertex shader (`reference_surface` near,
     `endless_tuft_far` far). They darken and cool the instance colour
     toward the floor's shade, and the tufts shrink by up to 35% so the
     floor sheet shows. Tufts and turf therefore take the same weight.
   - The floor sheet's own colour is a little darker and cooler
     (`land_trees` `FLOOR_WOOD`).
   - Lone meadow trees get nothing (their floor weight is 0), so there are
     no dots.
   - Placement, heights and the native kernels are untouched.
3. **Variation between trees.**
   - `zs_tree_vary` hashes the tree's foot xz in the shader. The same tree
     gets the same answer on the near crown, ring, far crown and sprite,
     because all of them read the same foot, so hand-overs agree.
   - Value is spread 0.82 to 1.16. A fifth of the trees go near blue-black,
     a quarter go olive, and about 7% are paler and greyer.
   - This is computed in the shaders, not in the MultiMesh instance colour.
     In native builds the near and mid instance tints are made in C++
     (`nat.block`/`nat.far`), and the near crowns read their bake back out
     of the instance colour's luma, so putting the spread there would have
     meant a C++ change and repainting the bake.
   - The foot is a pure function of seed and cell, so this is still "from
     the tree's seed". It costs nothing on the CPU.

New shader globals in `project.godot`: `zs_dread` (vec4), `zs_haze_tint`
(vec4) and `zs_wood_map` (sampler2D). All are 0 off the endless land, so the
isles are unchanged. No varyings were added to `reference_surface`.

## Knobs (launch flags)

- `--far-haze=X`: change 1 (0 turns it off; 1 is as tuned; above 1 scales
  only the crowns' extra haze).
- `--wood-floor=X`: change 2.
- `--tree-vary=X`: change 3.
- `--far-haze=0 --wood-floor=0 --tree-vary=0` gives the old look exactly.

Finer flags:

- `--haze-curve=C`: the fog curve.
- `--tree-haze=S`: the crowns' extra share (0.35).
- `--wood-shade=S`: how far the grass goes to the floor shade (0.7).
- `--wood-shrink=S`: how much tufts shrink under woods (0.35).

Constants:

- `DistanceRead`: `FOG_CURVE`, `AERIAL`, `TREE_HAZE`, `TREE_TINT`, `GOLD`,
  `WOOD_SHADE`, `WOOD_SHRINK`.
- `distance_read.gdshaderinc`: the haze band (150 to 1800 m), the shade
  colour and the vary hues.
- `land_trees`: `FLOOR_WOOD`.

## Sheets

Each sheet puts before (all three flags at 0) and after side by side, with
one row per view. Both columns come from the same build and the same
harness. The sheets are git-ignored and sit in the round's worktree under
`captures/distance-read/`, and also in `scratch/dr/sheets/`:

- `default.png` (8.6, the opening hour): coast, cruise, forest, high,
  hills, rock and wood.
- `h6.5.png` (dawn), `h9.6.png`, `h12.5.png` and `h18.5.png` (dusk): cruise,
  forest, high, hills and wood.

Some things differ from run to run whatever the flags: clouds, the
aurora, and a pond in the high view. They also differ between two "off"
runs.

look_measure (`aerial` far against near): the far land lost more
saturation and less value. For example, wood at 8.6 went from dS -0.09 to
-0.15 and dV -0.175 to -0.12, and cruise went from dS -0.05 to -0.11 and
dV -0.15 to -0.06. The near median luma is unchanged (within 0.01).

## Frame time

Measured with `look_views --time=240`, median ms from frame to frame, vsync
off, on this Mac.

- All three on against all off, two runs each at the same window size:
  - forest: 49.3 off, 50.1 and 50.1 on (+0.8 ms, about 1.6%).
  - cruise: 26.8 off, 27.1 and 27.1 on (+0.3 ms).
- One part off at a time:
  - Most of the forest cost is the wood floor's per-vertex texture read in
    the near tufts: wood-floor off gives 49.3, against 49.1 with all off.
  - Haze and vary are within noise.
  - Cruise is within noise for each part.

If the 0.6 ms matters, read the wood weight once per tuft on the CPU (in
the grass cell's instance colour) rather than per vertex.

## Tests at risk

- None found that touch these knobs. The tests were grepped for the fog
  curve, aerial, the tree, tuft and floor shaders, and the globals.
- `test_ground_look.gd` already fails on main ("reference_surface adds no
  varyings: 16 declarations", limit 14). That is not from this round, and
  this round adds no varyings.
- `test_sky_peak_look.gd` passes.
- GPU-dependent checks were not run.

## Next steps

- Let the user fly it at several moods. The haze has only been checked at
  the default mood (alpine_morning) across the clock. The other eight moods
  were not shot. Their haze colour comes from their own sky, but they are
  unverified.
- The ground under the woods past the tuft ring (230 m) gets darker only
  through the floor sheet. If the woods still read as dark trees on a
  bright lawn from cruise height, raise `FLOOR_STRENGTH` or `FLOOR_WOOD`.
- At dusk the woods keep their dark silhouettes by design (`day_share`). If
  the user wants dusk haze too, ease `GOLD` or the sun-height ramp.
- Already planned and left alone: smooth-cone lighting for far crowns, and
  depth and normals in the sprite atlas.
