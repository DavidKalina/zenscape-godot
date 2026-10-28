# Endless flight: where the frame goes, and the land's grass paint skipped

Measured on the Windows PC (RTX 4070 SUPER), full screen 2560 x 1440, the
current defaults (FSR1 at 75%, MSAA 2x, the cloud march at half
resolution), at the five spots of `frame-rate-handoff.md`. Plane pinned,
world frozen (`Engine.time_scale = 0`), each part hidden at run time and
interleaved over 3 rounds (spread mostly under 0.3 ms).

## Where the frame goes (GPU ms saved by hiding each part)

| Part | Meadow | Woods | Range | Coast | Worst |
|---|---|---|---|---|---|
| Frame | 11.65 | 10.54 | 8.48 | 9.21 | 10.00 |
| Grass | 3.14 | 2.00 | 0.25 | 0.02 | 1.61 |
| Land | 1.28 | 0.80 | 1.16 | 3.73 | 1.46 |
| Clouds, all | 1.94 | 1.84 | 1.25 | 2.06 | 1.99 |
| - march (half res) | 1.06 | 1.04 | 0.46 | 1.12 | 1.04 |
| - weather map | 0.37 | 0.37 | 0.39 | 0.38 | 0.40 |
| - resolve | 0.27 | 0.27 | 0.26 | 0.27 | 0.27 |
| Sun shadows | 1.01 | 1.06 | 0.85 | 1.03 | 1.08 |
| MSAA 2x | 0.87 | 0.98 | 0.79 | 1.42 | 1.36 |
| Trees | 0.63 | 0.41 | 1.24 | 0.35 | 0.23 |
| Sea | 0.20 | 0.12 | 0.05 | 1.29 | 0.11 |
| Fog, glow, arches, birds | under 0.3 each | | | | |
| 3D scale 75% to 50% | 2.22 | 1.93 | 2.41 | 2.74 | 2.28 |

The frame is GPU-bound (wall time matches GPU time). The cloud march at
full resolution costs 3 to 3.8 ms, so half to full is about 3.2x, not 4x:
a quarter-res march would save roughly 0.3 to 0.8 ms (not built).
`--cloud-steps=60` saves 0 to 0.3 ms.

## What changed

`shaders/endless_ground.gdshader`: the grass's paint (patches, wind crests,
specks, washes, near grain, flower drifts, react) now runs only where some
of it shows. Where sand, a river bank or snow covers the ground whole and
no rock does (rock's ledges and moss take the grass's colour), it is
skipped. The rock, beach and snow weights are worked out first; the rock
takes the grass as it stood before the near grain (`moss_grass`), as it did.

- `--land-skip=0` paints the grass everywhere, as before.
- `--land-skip=show` paints the skipped pixels magenta (beaches, banks,
  snowy peaks; 13% of the screen at the coast, 0.4 to 1.6% elsewhere).
- Flag read in `scripts/endless/endless_look.gd`, uniform `grass_skip`.

## GPU ms (frozen, 6 interleaved rounds)

| Spot | Original shader | New, skip off | New, skip on | Saved |
|---|---|---|---|---|
| Coast | 9.18 | 8.57 | 7.68 | 1.50 |
| Meadow | 11.63 | 11.31 | 11.23 | 0.40 |
| Worst | 9.86 | 9.68 | 9.68 | 0.18 |
| Woods | | 10.27 | 10.31 | 0 (noise) |
| Range | | 7.87 | 7.87 | 0 |

The new shader is faster than the original even with the skip off
(0.2 to 0.6 ms), probably because the grass paint now finishes before the
rock and sand, so fewer values stay live through them. Not proven.

## Pixel A/B (frozen, `--no-clouds`, plane hidden, full 2560 x 1440)

- Skip on against off: meadow, woods and worst 0 pixels differ. Coast: 0
  outside a patch that also changes between two frames of the same state.
  Range: about a dozen far snow pixels differ by exactly 1/255 (float
  rounding of the blend); the rest of its differences (sky specks round the
  sun) also differ between frames of the same state.
- New shader against the original (the reorder itself): coast exact. Meadow:
  two flower-paint dots, 90 pixels in all, differ (up to 30/255), the same
  each time; same-state frames don't differ. Most likely the compiler
  rounding differently and a dot's noise threshold tipping. Invisible side by
  side at 8x zoom; the amplified diff shows one speck.

## Not checked

- Flying (only frozen), other GPUs, the Mac (Metal), `--world=regions`.
- The full suite (a prototype round). Smoke passes with and without the skip.

## Tests this breaks

None known.

## The grass, split (plane pinned where it starts, frozen)

GPU ms saved, meadow / worst. Variants are the grass's own shaders with one
piece cut, swapped onto the live tufts at run time.

| Part | Meadow | Worst |
|---|---|---|
| Far ring (270k tufts, 10M vertices) | 1.52 | 1.69 |
| - its fragment made flat | 0.71 | 0.46 |
| - sheen, cloud shade, react, backlight, region colour | 0 to 0.1 each | |
| Flowers | 1.14 | 0.62 |
| - their sway (nod, flutter) | 0.44 | 0.43 |
| - their fragment made flat | 0.34 | 0.30 |
| Near tufts | 0.93 | 1.10 |
| - fragment made flat | 0.51 | 0.66 |
| - sway (most of it the breeze) | 0.36 | 0.47 |
| - tread, wind tool, local gusts, char, ground normal | 0 to 0.13 each | |

A grass-only vertex path would buy 0.1 to 0.25 ms (the walker-era tread,
wind tool and local gusts). About 1 ms of the far ring is its sheer
geometry (sub-pixel triangles), not its shader. (The earlier "worst" rows in
this file are where the plane got to 400 frames after starting there, about
30 m up, where the near ring is small.)

## The depth prepass: keep it

`rendering/driver/depth_prepass/enable` set false while running breaks the
frame (Forward+, 4.7.2): the colour pass still expects the prepass's depth,
and the sea draws over the land. Timings taken that way (2 to 3 ms "saved")
are of a broken frame. Off from the start (`override.cfg`), the picture is
the same bar a few pixels where far tree crowns overlap, and the frame is
much slower:

| Spot | Prepass on | Off (from start) |
|---|---|---|
| Meadow | 11.35 to 11.71 | 18.09 to 18.33 |
| Worst | 11.43 to 11.45 | 18.35 to 18.55 |

The grass does go through its vertex shader twice, but the prepass saves far
more in shading hidden behind other grass, trees and land. Woods, range
and coast were not timed.

## Drivers (git-ignored)

`scratch/perf/grass_cost.gd` (`--states=group:cut`), `scratch/perf/prepass.gd`
(`--fixed --label=`, with `scratch/perf/prepass_boot.ps1` alternating runs
with and without `override.cfg`),

`scratch/perf/cost.gd` (parts, cloud pass timestamps, `--states=`,
`skip_off`, `old_shader`), `scratch/perf/skip_ab.gd` (`--seq`, `--old`,
`--no-glow`), `scratch/perf/ab_diff.py`.
