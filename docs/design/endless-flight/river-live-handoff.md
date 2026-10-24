# Endless flight rivers: moving water (`--river-live=1`)

What changed: behind a new flag, `--river-live=1` (default off), the river's water in the ground shader moves as a current with a shape instead of one sheet sliding down the valley. With the flag off, chunks, mesh format and shader output are as before (the river pixels of six held views match the pre-change captures exactly; the only differing pixels are far haze and trees streamed in at a different frame).

## What was built

- **Channel frame per vertex** (`scripts/endless/land_stream.gd` `_river_frame`, flag on only). Each chunk gets a CUSTOM2 channel (RGBA float), computed on the worker from the chunk's own CUSTOM1 plus a two-sample ring read from the field, so the differences are central everywhere and match the neighbouring chunks:
  - xy: the channel's direction (perpendicular to the signed distance's gradient, turned to the flow). It follows the meanders; the old flow vector follows the valley line and is byte-quantised.
  - z: curvature, the divergence of the distance's unit gradient (1/m). Positive means the side of positive distance is the bend's outside, so `curvature × distance` > 0 on the outside.
  - w: the water's width change per metre down the flow (negative = narrowing).
  - Zeros where no river is within 40 m. LandField, the native kernels, colliders and the river level are untouched.
- **Ground shader live path** (`shaders/endless_ground.gdshader`, `river_live` 1). The old ripple, streak and mirror code stays as the else branch.
  - Shear: the current is `spd × mix(bank, centre, (1−u²)^p)`, with u = |distance| / half-width. It runs faster on a bend's outside. The river's speed already rises with its fall and stills in pools (LandField `RIVER_FLOW`/`RIVER_STILL`).
  - Flow map: every ripple layer is advected by that per-pixel velocity. There are two copies per layer, cross-faded half a cycle apart, offset by ±half a cycle (centred) so the stretch is halved. A slow noise staggers the copies' phase, so no pulse crosses the whole river.
    - Cycles are short (0.65 s × (size/3)^0.3). Longer cycles, or a steep phase noise, gave a marbled smear at 3 m/s.
  - Ripples, with `--sea-fft=1` and a rendering device: the sea's FFT cascades 1 and 2 (slope layers 4 and 5), tiles shrunk to 0.25 and 0.7 of the sea's (9.3 m and 4 m), plus the 9 m noise layer at 0.6 for broad swell.
    - Without the FFT: the three noise maps as before, but advected.
    - In both cases the amplitude rises with local speed and drops in eddies.
  - Riffles: trains of standing crests across the flow, held in world space, wavelength 2πv²/g (0.7 to 3.5 m), in patches drawn out across the flow, crests wavering.
    - Each of the four nearest 18 m cells turns its frame to the local flow about its own centre, and the four are blended. Turning about the world origin would swing the pattern round bends. The trains share a wavelength, so blending only swells and dims them.
    - Where: river speed 1.1 to 2.6 m/s, narrowings (−widen), bends (|curvature|), denser on 40 m gravel-bar patches, and a little wherever it runs.
    - White water: on crests where riffles are strong and steep. It thickens the drifting flecks there over a thin wash.
  - Eddies near the banks, on a bend's inside, where it widens, and in noise patches. The current turns back (up to 0.4 of its speed) and swirls: the curl of a noise height, so the swirl is divergence-free. The ripples go glassier there.
  - Foam:
    - Lace flecks (the mid-line of a height noise, gathered into rafts) advected by the same velocity field, so they shear and slow at the banks.
    - Cover gathers at the banks, a bend's outside, eddies, white water and riffles. Faint lines held at fixed distances from the bank (constant in the signed distance, wobbling) run down the flow.
    - Foam also covers the mirror.
  - Depth cues: the bed shows a stone and weed pattern, shifted by the ripples' slope × depth (refraction). Caustics drift with the current, in the shallows only.
  - Everything fine fades by pixel footprint like the old layers. The cruise view at 70 m shows no frame-to-frame sparkle.
- **`scripts/endless/endless_look.gd` `_river_live`**: sets `river_live`, builds the height noise texture and its normal map (512², seamless). When the sea has an FFT, hands its texture and sizes to the ground (`river_fft`, `river_fft_maps`).

Decision: `--river-live=1` uses the FFT only when `--sea-fft=1` is also on (it shares the sea's cascades, at no extra compute). On its own it falls back to the noise maps, with shear, riffles, eddies, foam and bed unchanged.

## Flags and knobs

- `--river-live=1` turns it on. `--river-live=1 --sea-fft=1` gives the FFT ripples.
- Uniforms through the existing `--river-knob=name=value` (str_to_var):
  - `river_shear` `Vector4(0.12,1.3,0.6,3.0)`: speed share at the bank and in the middle, profile power, bend outside speed-up.
  - `river_live_cycle` `Vector2(0.65,22)`: copy life (s), phase-stagger noise size (m).
  - `river_fft_use` `Vector4(0.25,0.7,0.30,0.22)`: tile shares of cascades 1 and 2, their slope strengths.
  - `river_live_riffle` `Vector4(1.1,2.6,0.45,1.0)`: start and full speed (m/s), slope strength, white water.
  - `river_riffle_where` `Vector4(0.7,0.5,40,0.3)`: narrowing weight, bend weight, gravel-bar size (m), base share.
  - `river_eddy` `Vector4(1.0,1.4,5.0,0.3)`: strength, turn-back (1 still, 2 full reverse), swirl size (m), swirl strength.
  - `river_foam` `Vector4(0.7,0.35,1.0,1.0)`: flecks, fleck size (m), gathering, lines.
  - `river_bed` `Vector4(1.0,0.5,1.0,1.8)`: bed pattern, refraction shift, caustics, caustic size (m).
  - `river_live_debug` (int): 1 bend outside/inside, 2 eddies, 3 riffles, 4 speed, 5 foam (paints the mask over the water).
- Example: `--river-live=1 --sea-fft=1 "--river-knob=river_live_riffle=Vector4(0.9,2.2,0.6,1.0)"`.

## Timing

Setup:
- Windows 11, RTX 4070 SUPER, Vulkan Forward+.
- Window 2560×1440, vsync off (`--uncapped`), seed 1.
- View: 6 m over the river at (-690, 2684), looking down a 2.5 m/s stretch; water fills about a third of the frame (`captures/river_live/perf_view.png`).
- 300 warm-up frames, then 600 measured, 3 runs each.
- GPU column: `RenderingServer.viewport_get_measured_render_time_gpu` (root viewport). Whole frame: the wall time between frames.
- Driver: `scratch/river_perf.gd` (uncommitted).

Medians per run, in ms:

| flags | whole frame | GPU (viewport) |
|---|---|---|
| (default) | 10.98 / 10.79 / 11.17 | 11.32 / 11.15 / 11.14 |
| `--river-live=1` | 11.28 / 11.29 / 11.25 | 11.64 / 11.65 / 11.68 |
| `--river-live=1 --sea-fft=1` | 11.15 / 11.23 / 11.16 | 11.59 / 11.62 / 11.58 |

So the live river costs about 0.5 ms of GPU at this view. The FFT row also includes the sea round's FFT sea, which is slightly cheaper than the Gerstner sea on the strip of sea in view.

CPU, chunk builds on the workers (headless, 400 frames at (-1000, 2650), mean per chunk): 48.7 ms without, 54.0 ms with the frame (+5 ms).
- In this worktree the native kernels don't load ("ZenScapeLandField is not version 1": the copied DLL is older than the branch), so the land grows in GDScript. These are GDScript-field numbers.
- With the native field, the ring samples get cheaper, but `_river_frame`'s GDScript loops (about 4k vertices) remain.

## Captures (`captures/river_live/`)

Spots: seed 1. A river traced from (-1675, 2656) down to (-620, 2745). It speeds up from 0.3 to 2.9 m/s, with a 0.72 rad bend at trace step 85.

- Committed: `cmp_skim.jpg`, `cmp_bend.jpg`, `cmp_cruise.jpg`, `cmp_bank.jpg`, `cmp_over.jpg` (default on top, `--river-live=1 --sea-fft=1` below), and `cmp3_steep.jpg` (default / `--river-live=1` alone / with the FFT).
- On disk only:
  - `{old,off,live,fft}_<view>.png` and `_m0..5.png`, 8 frames (0.133 s) apart.
  - `*_motion.gif` per tag and view.
  - `dbg{1,3,4}_*.png` (mask views) and `perf_view.png`.
  - Views: skim (3 m), bend (from 30 m off its outside), steep (6 m, fastest stretch), cruise (70 m down the valley), bank (2.6 m, at the water's edge; standing eye height), over (9 m, looking down).
- Drivers (uncommitted): `scratch/river_cap.gd` (traces a river, holds the camera, steps land and look by hand), `scratch/river_perf.gd`, `scratch/river_build.gd`, `scratch/river_scan.gd` (finds fast stretches for a seed), and `scratch/{sheet,motion,gifs,shear}.py`.

What they show:
- Shear: a vertical-shift correlation per column band between frames m0 and m1 of the over view (`scratch/shear.py`):
  - default: 0 px everywhere;
  - live: 0 at the banks rising to 8 px mid-channel;
  - FFT: 0 at the banks, up to 7 px mid-channel.
- Standing white crests survive a 6-frame average in the steep view while the chop and flecks blur. The riffles hold their place.
- The bank and over views show the bed, caustics and the foamy edge.

## What's left

- Riffle crest trains read clearly only in the average and in motion. In a single still under the FFT chop they are subtle. `river_live_riffle.z` is the knob.
- Foam on a bend's inside (the eddy share) reads a little heavy in the bend view; the outside gathers less than it might.
- The lace flecks are isotropic. Real foam streaks along the current, and only the shear stretches them here. A flow-aligned frame (like the riffles' four cells) would cost about 4× the taps.
- Frame derivatives are per chunk vertex. On coarse chunks (8 m+ steps) curvature and width change get rough, but by then the features have faded by footprint.
- Pre-existing, seen in both modes: triangle facets in the water's depth colour and the bank edge near the camera (the distance field is piecewise linear per triangle).
- The native kernels in this worktree are stale (see Timing). `_river_frame` is GDScript; a native port would be the next step if the build cost matters.
- Not run on Metal. The live path uses only `texture`/`textureGrad` in the spatial shader, nothing new in compute.

## Checks

- Smoke (headless import, then `studies/endless_flight.tscn` for 400 frames) passes with the defaults, with `--river-live=1`, and with `--river-live=1 --sea-fft=1`. Headless has no RenderingDevice, so that last one falls back to the noise maps, and headless compiles no shaders.
- The rendered runs above (captures, timing) compiled and ran the shader with no errors.
- Walker swimming and the river level: not touched. `LandField.river_y`, `river_drawn`, the colliders and `endless_walker.gd` are unchanged; only the ground shader's paint and the chunks' extra vertex channel change.
- Existing tests: none known to break. The suite was not run.
