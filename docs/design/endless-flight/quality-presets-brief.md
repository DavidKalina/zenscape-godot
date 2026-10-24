# Endless flight: quality presets (brief for a future round)

The user played the current defaults (FSR1 at 75%, MSAA 2x, the cloud
weather map in slices; `cloud-weather-slices-handoff.md`) and wants that to
be **Medium**: still looking great, with High and Ultra pushing past it.
Not built yet.

## The ladder the user agreed

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| 3D resolution (FSR1) | 67% | 75% | 100% | 100% |
| MSAA | off (SMAA only) | 2x | 4x | 4x |
| Sun shadow map | 4096 | 8192 | 8192 | 8192 |
| Cloud march | half | half | half | full |
| More world | - | - | - | longer view, denser grass and trees |
| GPU ms, worst spot, RTX 4070 SUPER at 1440p | ~9 (estimate) | 11.6 | 15.3 | ~18+ (estimate) |

- Medium is exactly today's defaults. High is the old max (native, MSAA
  4x). Ultra is allowed to be expensive; it is where the game is pushed.
- Low keeps the look by giving up sharpness and edge smoothing, not by
  cutting grass or clouds.
- The cloud weather slices stay on in every tier (no visible change).

## Where the knobs are today

- 3D resolution: `scripts/render_resolution.gd` (`native_scale`,
  `scale_override`, `--render-scale=`), set for endless flight by
  `studies/endless_flight.gd` `NATIVE_3D`. F2 cycles `SCALES` while flying.
  The player's render-resolution cap (Native, 1440p, 1080p...) is kept in
  `user://look.cfg` `[display] max_lines`; the Mac draws at 720 lines.
- MSAA, shadows, screen AA, SSAO: `scripts/endless/endless_look.gd`
  `_frame_trades` (`MSAA_3D`, `--msaa=`, `--shadow-size=`, `--screen-aa=`,
  `mac_trades`).
- Cloud march resolution: `scripts/endless/endless_clouds.gd` `quality[2]`
  (`--cloud-full-res`, `--cloud-half-res`; half on a discrete GPU via
  `LandStream.high_end()` and on the Mac).
- Grass rings and LOD: `scripts/endless/endless_grass.gd` (`--grass-cull=`,
  `--grass-far-lod=`, `--grass-sub=`); `frame-rate-handoff.md` has their
  costs.
- An older quality tier (Beauty / Balanced / Ultra) is saved in
  `user://look.cfg` `[quality] tier` by the diorama's Settings dialog
  (`studies/diorama.gd`, `scripts/look_pass.gd` `apply_tier`). Endless
  flight does not read it. Decide whether presets reuse that key or get
  their own; don't break the diorama's.

## What the round should build

1. The four presets as one table in code, each a set of the knobs above,
   applied at boot and live.
2. Saved in `user://look.cfg`. Default: Medium on a discrete GPU. Check
   what Apple's GPUs and integrated GPUs should default to against today's
   Mac trades (720 lines, MSAA 2x, shadow 4096, half-res clouds).
3. A key that cycles the presets while flying, with the preset's name on
   the hint line and the F1 numbers. There is no settings menu in endless
   flight yet.
4. Flags still win over the preset, for tuning.
5. Time each preset at the spots in `frame-rate-handoff.md` (meadow,
   woods, range, coast, worst), frozen and flying, and look at stills of
   each. Time the Low and Ultra estimates for real.

Ultra's "more world" (view distance, grass ring reach, tree detail bands)
needs its own pass by eye and cost; it can follow as a separate round.

## How the numbers were taken

A driver extending `tools/harness/drive.gd`, run with
`tools/godot.py --rendered ... --resolution 2560x1440`, making the window
borderless at the screen's size and turning vsync off. It opens
`studies/endless_flight.tscn` at a spot, waits for the land to stand,
samples `RenderingServer.viewport_get_measured_render_time_gpu` while
flying, then freezes (`Engine.time_scale = 0`) and samples again. The
cloud passes have their own GPU timestamps
(`RenderingDevice.get_captured_timestamp_*`, names "Cloud ... done").
Pass flags that the scene reads after `--scene-args`; the harness replaces
the scene's launch args, so `--msaa=` and the like are lost otherwise.
After editing a `.glsl`, re-import (`python tools/godot.py --editor
--import`): the harness only re-imports for scripts, and a stale shader
runs silently.

## Known quirks

- Switching to FSR2 while the game runs makes the engine print
  `Parameter "uniform_set" is null` every frame after. Starting with it is
  clean. FSR2 was no faster than FSR1 here and softer, so no preset uses
  it.
- `--render-upscale=fsr2` leaves MSAA on, which made it slower than native.
