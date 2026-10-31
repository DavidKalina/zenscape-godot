# Endless flight: Mac graphics presets (handoff, 2026-10-29)

Measured on the user's MacBook Pro, M5 Pro, built-in 3024x1964 screen,
fullscreen, uncapped (vsync off), Metal. Metal reports no GPU time, so every
number is the wall time per frame.

## Built

`scripts/graphics_preset.gd`: three presets, each a render height, a frame cap
and flags laid under the command line's (`LaunchArgs.defaults`, so a flag
typed at launch still wins).

| | Performance (60) | Quality (45) | Full |
|---|---|---|---|
| 3D height (MetalFX spatial) | 900 lines | 1080 lines | the player's cap (`look.cfg` `[display] max_lines`) |
| Frame cap | 60 | 45 | the project's (60 on the Mac) |
| Anti-aliasing | FXAA, no MSAA | FXAA, no MSAA | MSAA 2x |
| Grass | half the tufts, out to 150 m | all, out to 150 m | all, out to 230 m |
| Trees | full crowns to 40 m, far crowns to 120 m, mid to 250 m, no tree shadows | far crowns to 120 m | today's |
| Clouds | 72 march steps, valley fog 16 steps | today's | today's |

- Saved in `user://look.cfg` `[graphics] preset`. `--preset=NAME` wins for a run.
- Default: a Mac runs Performance, anything else Full. Headless runs and
  harness runs (`-s`) run Full unless they pass `--preset=`, so tests and look
  captures keep today's look.
- F3 in flight steps to the next preset, saves it and opens the flight
  again (the grass and trees read their flags when they're made). The F1
  numbers show the preset.
- `render_resolution.gd` `preset_lines` wins over the kept cap; F2 and
  `--render-scale` still win over it.
- Two fixes found on the way: `beat_routes.gd` `_breathe` kept planning after
  its scene was replaced (about 350 errors on any scene change mid-plan); it now
  stops. `endless_look.gd` `_frame_trades` now always sets the screen AA, which
  the root window otherwise carried from the last flight.

## Flight (the same 30 s path from the seed 1 start, fixed step; ms)

| | median | p90 | p99 | frames over 16.7 | over 22.2 |
|---|---|---|---|---|---|
| Full (720 lines, the user's cap) | 25.3 | 30.5 | 34.7 | 99 % | 63 % |
| Full at 1080 lines | 30.3 | 35.1 | 38.6 | 100 % | 98 % |
| Quality | 18.2 | 23.1 | 25.8 | 61 % | 18 % |
| Performance | 15.6 | 19.2 | 21.5 | 30 % | 0.3 % |

Neither preset is locked yet: Performance holds 60 on about 70 % of frames,
Quality holds 45 on about 82 %. With the 3D switched off the frame is 2.6 ms
(p99 6.5), so the GPU sets the pace. Launches of the same setting can differ
by up to about 3 ms; three baselines in a row agreed to 0.1 ms.

## What each thing costs (single switches from a base)

In flight (base: 1080 lines, FXAA, grass half to 150 m; 23.0 ms):
no trees -10 ms; far crowns to 120 m -5.3; no tree shadows -3.2; full crowns
to 40 m -2.7; no clouds -3.3; no valley fog -3.6; shadow map 1024 -3.4;
720 lines -4.1, 900 lines -3.2; mid crowns to 250 m -1.1; no grass -0.4;
tree shadows only to 430 m +1.5 (slower). MSAA 2x in place of FXAA: about +8.

Held low views (1080 lines): grass 7 to 12 ms (reach 150 m from 230 saves
4 to 8, half the tufts 3 to 7), MSAA 2x 3.5, the ground 3.5 to 4, clouds 4
to 5, valley fog about 2, ruins and rocks 1 to 2, sun shadow size 4096 to
2048 nothing, SMAA about 3 more than FXAA.

## Next

- To lock 60: clouds (-3.3) and valley fog (-3.6) are the biggest looks left
  on the table; the trees' far crowns are the biggest cost still standing.
  The p99 over the median is about 6 ms on every setting, likely build
  commits and streaming (spec-lean-frame.md rounds 1 to 2).
- `quality-presets-brief.md` is the PC's agreed ladder (Low keeps grass and
  clouds and gives up sharpness). On the Mac, MSAA and the trees cost far more
  than resolution, so its Low/Medium need the PC measured before merging the two.
- vsync stays off as before; a 45 cap on the ProMotion screen may tear.

Throwaway drivers (git-ignored): `scratch/mac_perf.gd`, `mac_knobs.gd`,
`mac_grass.gd`, `mac_fly.gd`, `preset_check.gd`, the `mac_r*.sh` sweeps.
