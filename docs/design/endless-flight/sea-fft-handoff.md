# Endless flight sea: FFT cascades (`--sea-fft=1`)

What changed: behind a new flag, `--sea-fft=1` (default off, so the default sea is unchanged), the wind sea and its chop come from three Tessendorf FFT cascades computed on the GPU each frame. The Gerstner swell trains stay.

Now the default (2026-10-24, after the user played it): the FFT sea is on unless `--sea-fft=0`. Headless, with no rendering device, it still falls back to the Gerstner wind sea.

## What was built

- `scripts/endless/sea_fft.gd` (a CompositorEffect, like the foam's): three cascades of 256², tiles 250 / 37 / 5.7 m. Each holds its own band of one JONSWAP spectrum, so no wave is counted twice. Band edges: waves longer than the finer tile / 6 go to the coarser cascade, so cascade 0 holds 250-6.2 m, cascade 1 holds 6.2-0.95 m, and cascade 2 holds 0.95 m down to its grid. The spectrum takes the wind's speed and fetch, and is spread round `body_wind` by cos(θ/2)^2s. Waves move by deep-water dispersion (ω = √(gk)).
- Compute passes, each in its own file under `shaders/`:
  - `sea_fft_spectrum.glsl`: builds h0(k). Runs once, and again when a knob changes.
  - `sea_fft_evolve.glsl`: h(k,t), written as four packed complex spectra per cascade: Dx+iDy, Dz+i∂Dx/∂z, ∂h/∂x+i∂h/∂z, ∂Dx/∂x+i∂Dz/∂z.
  - `sea_fft_fft.glsl`: a Stockham radix-2 inverse FFT in shared memory, one workgroup per row, with a transposed write. It runs twice: rows, then columns.
  - `sea_fft_unpack.glsl`: writes the results into a 6-layer RGBA16F 2D array. Layer c holds the shove xyz and ∂Dx/∂z; layer 3+c holds the slope, ∂Dx/∂x and ∂Dz/∂z.
  - `sea_fft_mips.glsl`: builds 8 mip levels as 2×2 means.
- Every pass reads earlier output through storage buffers or `imageLoad`, never `texture()`. This follows the Metal lesson in water-handoff.md. Not tried on a Mac yet.
- Each pass gets every layer of one mip through RenderingDevice slice type 3 (`TEXTURE_SLICE_2D_ARRAY`). The engine has this type but doesn't name it to scripts, so `sea_fft.gd` passes 3 as an int.
- Sea shader (`shaders/endless_sea.gdshader`, `sea_fft` 1):
  - `zs_swell_body` runs waves 0..4 only, the two swell trains. The wind sea's waves 5..10 and its whitecap loop are skipped.
  - The vertex adds the FFT heave from cascades 0 and 1. Each is read at the mip its sheet cells can hold, faded by `body_reach` like the swell.
  - The fragment samples all three cascades with trilinear and anisotropic mips. Cascade 0's slope joins the swell's slope; cascades 1 and 2 replace the noise chop and the wavelets.
  - The slope variance the mips smooth away (from the spectrum, per octave of each band) goes into `chop_rough`, so roughness and the glitter's sheen widen past the pixel as before.
  - Fresh caps stand where the fold (1 − Jacobian of cascades 0+1) passes a threshold, with ragged edges and clustered by the existing gust field. Far off, a mean cover (`fft_far_foam`) stands in.
  - The crest glow and the trough-to-crest light read the FFT height and Jacobian too.
- Foam buffer (`shaders/endless_sea_foam.glsl`, `scripts/endless/sea_foam.gd`): under the flag, foam is laid where the same Jacobian folds. It reads cascade 0 at mip 0 and cascade 1 at mip 2 (about the buffer's 0.5 m texel) with `imageLoad`, filtering by hand. Drift, lace and ageing are unchanged. The FFT pass inserts itself ahead of the foam pass in the camera's compositor.
- Headless (no RenderingDevice): `SeaFFT.ready()` is false. The material keeps `sea_fft` 0, and the sea and the CPU mirror stay exactly as without the flag.
- Optional subsurface pass: not built. The existing `sss_color` crest glow now reads the FFT crests.

## Flags and knobs

- `--sea-fft=1` turns it on; it needs the body sea (it is ignored under `--sea-body=old` and older).
- `--sea-fft-time` captures GPU timestamps around the passes. The result is in `SeaFFT.gpu_ms`.
- Spectrum: `--sea-fft-set=name:value;...` (values through str_to_var):
  - `wind`: m/s. Default: the look's wind strength × 13.3, which is 8.6 m/s at seed 1's mood.
  - `fetch`: 30000 m.
  - `sizes`: `Vector3(250,37,5.7)`.
  - `chop`: 1.6. How far the shove pulls points into the crests.
  - `spread`: 5.
  - `gamma`: 3.3.
  - `short`: 0.012 m. Waves this short are damped.
  - `long`: 0, which keeps everything. Set it in m to cut longer waves.
  - `scale`: 1.
  - `seed`: 1.
- Shader uniforms through `--sea-set`:
  - `fft_strength`: `Vector3(1.0,0.85,0.45)`, per cascade.
  - `fft_patch`: `Vector2(0.55,1.25)`, the scale in a slick and in a rough stretch.
  - `fft_air`: 0.7, how much the wind's paws scale cascades 1 and 2.
  - `fft_heave`: 1.
  - `fft_foam`: `Vector3(0.25,0.55,1.2)`, where the fold starts and is full, and the amount.
  - `fft_far_foam`: `Vector2(0.05,0.01)`, the far cover in the rough and in a slick.
- Example: `--sea-fft=1 "--sea-fft-set=wind:12;chop:1.8" "--sea-set=fft_foam:Vector3(0.3,0.6,1.0)"`.

## Timing

Setup:
- Windows 11, NVIDIA GeForce RTX 4070 SUPER, Vulkan Forward+.
- Window 2560×1440 (1440×900 asked, display scaling). Vsync off (`--uncapped`), seed 1, same held views.
- 300 warm-up frames, then 600 measured frames, 3 runs each.
- GPU column: `RenderingServer.viewport_get_measured_render_time_gpu` for the root viewport, the GPU timer on the viewport's render.
- FFT pass column: RenderingDevice `capture_timestamp` before and after the FFT dispatches (all passes and mips), read back with `get_captured_timestamp_gpu_time`.
- Whole frame: the wall time between frames.
- Driver: `scratch/fft_perf.gd` (uncommitted).

Medians per run, in ms:

| view | `--sea-fft` | whole frame | GPU (viewport) | FFT pass (GPU) |
|---|---|---|---|---|
| sun, 8 m over open sea | 0 | 12.39 / 11.78 / 11.98 | 12.27 / 12.00 / 11.96 | – |
| sun, 8 m over open sea | 1 | 11.12 / 11.22 / 10.93 | 10.98 / 11.07 / 10.89 | 0.096 / 0.095 / 0.095 |
| cruise, 70 m | 0 | 12.11 / 11.96 / 12.17 | 12.26 / 12.30 / 12.22 | – |
| cruise, 70 m | 1 | 10.84 / 11.51 / 11.39 | 11.40 / 11.43 / 11.58 | 0.096 / 0.096 / 0.095 |

The FFT sea costs about 0.7-1.1 ms less GPU per frame. Its compute is about 0.1 ms, and the six-wave Gerstner, whitecap and wavelet loops it replaces cost more per pixel.

CPU `EndlessSea.height_at`, one call averaged over 5000: 343-471 µs before, 226-270 µs with the flag (5 waves mirrored instead of 11). These are GDScript times measured while the frame loop ran.

## CPU mirror and mismatch

`height_at` (plane skim, walker swim, wake, camera) mirrors only the Gerstner swell trains (waves 0..4) under the flag. That matches the Gerstner part of the vertex heave exactly. The FFT heave is not on the CPU.

How big the gap is:
- From a GPU readback, cascades 0+1 reach at most 0.88 m of height (σ 0.24 m) at strength 1. In a rough stretch (`fft_patch.y` 1.25) the worst case is about 1.1 m; typical is under 0.3 m.
- A throwaway skim through the real flight loop (`scratch/fft_skim.gd`, W held nose-down for 900 frames over open sea, the FFT read back every 10 frames at the plane) measured:
  - the plane at least 0.88 m over the mirror;
  - at least 0.39 m over the drawn surface;
  - FFT heave under the plane up to 0.52 m;
  - never under the drawn surface (0 of 90 samples).
- `captures/water_fft/skim_600.png` shows it riding.

## Captures (`captures/water_fft/`)

- Committed: `cmp_{coast,high,cruise,away,sun}.jpg`, the default sea on top and `--sea-fft=1` below.
- On disk only:
  - `cmp_*.png` for sun, away, low, close, cruise, high and coast;
  - `{old,new}_<view>.png`;
  - a 6-frame motion strip per view, 8 frames (0.13 s) apart: `*_m0..5.png`, `*_motion.gif`;
  - `*_crops.png`, four frames of the middle distance, for shimmer;
  - `skim_*.png` and `skimold_*.png`.
- Drivers (uncommitted): `scratch/fft_cap.gd` (holds the camera and steps land and look by hand; `--stats` prints the spectrum and readback numbers) and `scratch/cmp.py`.

What the captures show:
- The wind sea reads as crossing trains of many lengths under the swell.
- The old crossing-wave lattice in the coast glare and the high view is gone.
- The far sea keeps texture without sparkling between frames in the strips.
- No tile repeat is visible from 170 m.

## What's left

- The FFT heave isn't mirrored on the CPU. The next step would be an async readback of cascades 0+1 (`texture_get_data_async`, about 1 frame late) sampled in `height_at`.
- Toward the sun at low altitude, the sun path reads somewhat crinkled from the finest cascade. `fft_strength.z` and `path_share` are the knobs.
- Fresh caps are still flat cream patches, as before, now ragged-edged.
- The spectrum is built from the wind at start only. A mood change (`show_mood`) changes `_wind` but doesn't rebuild it.
- Not run on Metal. The design follows the imageLoad rule, but the Mac is unverified.
- Seen in both modes, not new: the wake laid into the foam buffer shows blocky axis-aligned squares behind a skimming plane (`skimold_600.png`).

## Checks

- Smoke (headless, 400 frames) passes with the defaults, with `--sea-fft=1` (which falls back without a GPU), and with `--sea-fft=1 --sea-foam=old`.
- Headless can't run the compute or compile the shaders. The rendered runs above (captures, timing, skim) compiled and ran them with no errors.
- Existing tests: none known to break. The suite was not run.
