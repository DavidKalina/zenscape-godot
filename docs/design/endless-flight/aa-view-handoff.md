# Endless flight: anti-aliasing and draw distance (Windows PC)

On a discrete GPU off the Mac (`LandStream.high_end()`), the endless flight
now draws twice as far and adds SMAA over its 4x MSAA. On the RTX 4070
Super at 2560 x 1440 (native, no render cap) this costs 0.3 to 0.7 ms of
GPU time at the five audit spots. The Mac and integrated GPUs are
unchanged. The round also built the C++ kernels on Windows, and it applies
the NVIDIA white-flash fix to the far grass shader.

## Launch

`godot --path . studies/endless_flight.tscn -- --no-title`. The new
behaviour is the default on a discrete GPU. `--high-end=0` brings back
the old look.

## What changed

1. **`--view=K`, the draw distance** (`LandStream.view()`,
   `scripts/endless/land_stream.gd`). It scales the haze's end
   (`EndlessLook.FOG_END`, 7600 m), the camera's far plane, the land's
   root reach (`root_reach`, which becomes 2 roots past K = 1), the far
   trees' ring (`LandTrees.far_ring`, `FAR.z`/`FAR.w`) and the clouds'
   march (`EndlessClouds` `REACH`, with the weather map's side). The range
   is 0.5 to 2.5. It is `HIGH_VIEW` (2) on a high-end GPU and 1 elsewhere.
2. **SMAA over the MSAA** on a high-end GPU (`EndlessLook._frame_trades`).
   New flags: `--screen-aa=smaa|fxaa|off`, `--taa=1`, and `--msaa=8` (8x
   is now accepted).
3. **Far tuft NaN fix** (`shaders/endless_tuft_far.gdshader`). `pow`'s
   base is kept off 0. NVIDIA's Vulkan driver can return NaN for
   `pow(0, y)` at the blade root, and the glow blooms it into white
   flashes. This is the uncommitted fix from the
   `endless-flight-scene-setup` worktree.
4. **C++ kernels built on Windows** with MSVC Build Tools 2022, godot-cpp
   at the pinned `6cceaf6a`, and SCons 4.8.1 through
   `python -m SCons` (there is no `scons.exe` on this PC; a
   `scons.cmd` wrapper was passed as `--scons`). Debug and release DLLs
   were built and copied into the main checkout too, which had 10/14
   builds without `ZenScapeLandField`. `land_hash.py --seed 1`: native and
   GDScript hashes are identical, at 1.2 s against 4.7 s.

## Numbers

GPU median in ms, frozen at each spot (driver `scratch/gpu_spot.gd` and
`scratch/gpu_run.py`, git-ignored), one window per state:

| spot | MSAA 0 | 2x | 4x (old) | 8x | 4x+SMAA | 4x+TAA | 8x+SMAA | view 1.5 | view 2 + SMAA (new) | grass to 330 m | crowns to 120 m |
|---|---|---|---|---|---|---|---|---|---|---|---|
| meadow | 14.4 | 15.4 | 16.9 | 18.5 | 17.0 | 20.7 | 18.7 | 16.9 | 17.4 | 19.1 | 17.0 |
| woods | 13.9 | 14.6 | 15.9 | 17.9 | 16.1 | 21.1 | 17.7 | 16.1 | 16.4 | 17.9 | 15.3 |
| range | 11.2 | 12.2 | 13.1 | 14.4 | 11.9 | 14.9 | 14.5 | 13.3 | 13.8 | 14.1 | 13.6 |
| coast | 12.9 | 14.2 | 15.2 | 16.7 | 15.4 | 16.5 | 16.7 | 15.5 | 15.5 | 15.4 | 15.2 |
| worst | 13.7 | 15.2 | 16.9 | 18.6 | 16.7 | 20.1 | 19.1 | 17.1 | 17.5 | 18.7 | 17.7 |

Live flight, 40 s over the range from 120 m, two runs each:

| | frame median | p99 | worst |
|---|---|---|---|
| old | 10.6 ms | 13.0 ms | 15 to 16 ms |
| new | 11.7 ms | 14.4 ms | 17.9 ms |

The land kept up the whole time (nothing queued at the end). Frozen
spots read higher than the live flight because they look low over thick
grass.

## Looks (stills in `scratch/shots/`, not committed)

- 8x MSAA is the crispest on the plane's bracing wires and grass blades.
  SMAA smooths the wires but softens the grass a little. TAA was not
  looked at, because it ghosts moving grass and costs 2 to 5 ms.
- At view 2 the far ranges keep more contrast and more ridgelines show
  through the haze. No seam showed at the horizon.

## Not verified

- Clouds at view 2: the weather map's texels are twice as coarse (the
  same texel count over twice the side). They looked the same in the
  stills, but were not judged in motion.
- Far trees past 6.2 km at view 2 (`far_ring` to 12.4 km): stills only.
- Flicker bursts and in-motion AA crawl.
- The Mac (unchanged by design) and other PCs.
- The full suite (a prototype round). Smoke passed.

## Next

- 8x MSAA (`--msaa=8`) fits only with about 2 ms bought back elsewhere.
  Near grass in `reference_surface`'s vertex path is the biggest item
  (frame-rate-handoff.md).
- Longer grass (`--grass-lod=16,30,220,330`) costs about 2 ms where
  meadows fill the view.
