# Rendering and motion audit — 2026-09-07

The reported gap is perceptual clarity and smoothness while panning/orbiting,
especially shadow edges. This audit establishes a baseline; it does not declare
visual parity or a performance win over the Electron application.

## Findings

1. **The initial atmosphere differs substantially from the source fixture.**
   `studies/atmosphere.gd` starts with mist 0.45 and haze 0.15. The source
   comparison query uses mist 0.02 and haze 0.03. Matching camera and atmosphere
   visibly restores forest/facet contrast. These are the reference query's
   settings, not a claim about every Electron session: the source clear weather
   preset itself is mist 0.04 / haze 0.10. An atmosphere choice must not be
   mistaken for an engine image-quality limitation.
2. **MSAA and added post effects are not the easy explanation.** Live captures
   confirm 4 samples in source WebGL and Godot MSAA enum 2 (4×), no TAA/FXAA,
   and SSAO/glow disabled by the default Balanced selection. Raising AA or
   enabling Beauty is not justified by this evidence.
3. **Shadow parity remains incomplete.** The source fits a fixed light-space
   box around the world with a 4096 map; Godot uses an orthogonal directional
   shadow with max distance 130 and an 8192 atlas. An atlas size alone does not
   establish identical texel density or stability as the camera moves. Godot
   uses normal bias 0.8, versus the source's default zero; the prior shadow
   work chose this to suppress canopy acne. Contact loss versus acne remains
   a tradeoff to measure, not a reason to blindly lower bias. Relevant files:
   `scripts/landscape_lighting.gd`, `project.godot`, source `main.js`, and
   `docs/fidelity/SHADOW-FILTER.md`.
4. **Camera damping is not identical at high refresh rates.** Source
   OrbitControls applies 5% per rendered frame. Godot applies the time-based
   equivalent of 5% at 60 Hz. If the source renders at 120 FPS, its residual
   input takes about 0.49 s to fall to 5%, versus 0.97 s in Godot. This is a
   mathematical difference, not yet evidence that either setting feels better.
   Verify source presentation cadence and compare a matched pointer gesture
   before changing the recent camera tuning.
5. **Steady frame throughput looks healthy; a rare hitch remains unresolved.**
   Two real-time native runs at actual 2880×1706 pixels, 120 FPS cap, VSync off,
   default atmosphere, visible controls, and live animation yielded:

   | Run / phase | Mean interval | p99 | Maximum | Frames >16.67 ms |
   |---|---:|---:|---:|---:|
   | 1 / still | 8.89 ms | 8.95 ms | 511.89 ms | 2 |
   | 1 / orbit | 8.33 ms | 8.68 ms | 9.15 ms | 0 |
   | 1 / still after orbit | 8.33 ms | 9.04 ms | 9.11 ms | 0 |
   | 2 / still | 8.33 ms | 9.02 ms | 9.99 ms | 0 |
   | 2 / orbit | 8.33 ms | 8.74 ms | 16.41 ms | 0 |
   | 2 / still after orbit | 8.33 ms | 8.89 ms | 8.96 ms | 0 |

   Each phase samples eight seconds after a three-second warmup. macOS clamped
   the requested 2880×1800 window to 2880×1706; the reports record actual pixels.
   These are process-frame wall intervals, not GPU time, presentation timing,
   or input-to-photon latency. No competing capture process was run during
   sampling, but this was not an otherwise isolated machine. The 512 ms event
   did not recur in run 2 and has no established cause. Saved/custom gardens,
   sculpting, and longer camera traversals need their own measurements.

## Evidence

- `atmosphere-comparison.png`: Godot default atmosphere LEFT, source-fixture
  atmosphere RIGHT. Same explicit camera, paused animation, phase and resolution.
  Both mist and haze change; this isolates the atmosphere settings as a group.
- `source-native-comparison.png`: source LEFT, Godot RIGHT, matched query/camera.
  Water and fine shadow differences remain. Wildlife/wind clocks are not
  synchronized; moving pixels must not be scored as rendering errors.
- `source.png`: source build on the local server, verified server working
  directory `/Users/davidkalina/Documents/Projects/zenscape`, rendered through
  the existing Chrome/ANGLE Metal capture harness. This uses the source app's
  renderer, but is not an Electron shell timing benchmark.
- `godot-default-air.png`, `godot-matched.png`: full native captures.
- `pacing-1.json`, `pacing-2.json`: raw frame interval summaries.

## Next changes, in order

1. Choose a shared clear atmosphere as the visual baseline, with the same
   viewport pixels, camera, scene and time. Keep misty art direction available.
2. Prioritize shadow fitting stability: record the same slow pan/zoom over tree
   silhouettes and trunk/rock contacts, with scene animation frozen and a
   stationary-camera control. The source shadow box stays anchored during a
   camera pan; Godot's directional fitting depends on the viewing camera.
   Compare world-aligned regions rather than raw moving screen pixels. Then
   separately sweep normal bias (0.8, 0.4, 0.2, 0), retaining current map and
   filter; reject acne even if contacts improve. Still images cannot decide
   shimmer during motion.
3. Compare atmosphere temporal history on/off along that same camera path to
   distinguish atmospheric trails from shadow shimmer. Do not enable full-scene
   TAA merely to hide the cause; judge detail retention in motion.
4. Compare identical pointer gestures and source/native frame cadence. Tune
   camera response only after separating it from rendering stalls.
5. Repeat real-time pacing in the user's edited garden and investigate any
   reproducible long-frame event. Require visual and pacing evidence together
   before accepting an improvement.

## Reproduce native pacing

```sh
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
  --rendering-method forward_plus --script res://tools/profile_frame_pacing.gd \
  -- --size=2880x1800 --out=/tmp/zs-frame-pacing.json
```

The tool also passes scene arguments such as `--garden --garden-file=...` through
to the existing scene. No production rendering or camera defaults were changed.
