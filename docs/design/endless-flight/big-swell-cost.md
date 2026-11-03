# The big swell's cost (task 8, 2026-11-02)

Driven flights, not flown ones: a bot holds the stick and Boost through the
real input path. Rendered, 1440x900, `--uncapped` (no vsync, no frame cap),
one window at a time, on the Mac. Each config ran 3 times, interleaved
(on, `--surge=0`, `--spray=0`, main; then again). Each leg is about 990
frames. The table gives the median ms from frame to frame: the median of
the three runs' medians, with their range in brackets.

| leg | swell on | `--spray=0` | `--surge=0` | main |
|---|---|---|---|---|
| belt, skimming at 2 m on Boost (8300,900 north) | 17.14 (16.92-17.65) | 16.06 (16.05-16.16) | 15.38 (15.33-15.41) | 16.32 (16.23-16.36) |
| belt, 140 m hands off | 17.23 (17.22-17.84) | 16.94 (16.55-16.99) | 16.35 (15.49-16.41) | 16.46 (16.46-16.66) |
| coast, 60 m from 6400,420 east toward the belt | 17.17 (17.14-17.22) | 17.29 (17.23-17.42) | 17.17 (17.03-17.24) | 17.09 (17.04-17.20) |
| inland, 60 m from 720,900 north | 27.22 (26.57-27.75) | 27.47 (27.39-27.48) | 27.02 (26.99-27.16) | 27.16 (26.84-27.17) |

The study's own tick (frame log), belt low: on 2.97, `--spray=0` 2.92,
`--surge=0` 2.50, main 2.62 ms. All three runs agree to within 0.1 ms. At
140 m the tick is the same with the surge on or off (1.4-1.6 ms).

- **In the belt the swell costs about 1.8 ms a frame low, and 0.9-1.3 ms at
  140 m.** The spray is about 1.1 ms of it low (0.3-0.6 ms high). The surge's
  shading is about 0.7 ms. Almost all of that is GPU time: Metal reports no
  GPU time (`render_gpu` 0), so it is the wall time left over once the CPU
  parts are taken out.
- **The height read shows in the tick, not in the frame.** Low in the belt
  the tick grows 0.47 ms: the camera's probes 0.33 -> 0.59 ms, near misses
  0.34 -> 0.55, `look` 0.12 -> 0.17, `t_input` 0.09 -> 0.11. The frame is
  bound by the GPU (about 17 ms against a tick of 3 ms). Low, `--spray=0`
  is 0.68 ms slower than `--surge=0`; at 140 m, where the tick doesn't
  change, the gap is the same or larger (0.6-1.1 ms). So the 0.47 ms of
  reads hides under the wait for the GPU. **`surge_at` stays in GDScript;**
  it has no native port.
- **Inland and at the coast the sea is no slower:** on, off and main are
  within each run's own spread. The coast leg's camera spikes (20-30 ms
  ticks, about 60-70 frames over 10 ms) are in main too: they are the
  game's, not the swell's.
- Main has 14 commits that the branch doesn't (the burrower's cave chase), so
  the branch-against-main gaps include them. `--surge=0` on the branch is
  the clean A/B for the swell.
- Noise: in some runs every part of the tick, even ones that don't touch
  the sea (`birds`, `t_input`), ran up to 2x slower, inland and at the
  coast. That happened in the swell-on runs and in main alike, while
  `--spray=0` (surge still on) stayed fast, so it is the machine's CPU pace
  between runs, not the swell's work. The frame times above didn't move
  with it (the GPU binds them).

Not measured: the PC (its GPU and CPU balance differ; if it binds on the
CPU, the 0.47 ms of reads would show there), a hand flight, Boost at 140 m,
dawn and night.

If the belt's 1.8 ms is too much, the spray is the biggest piece. It draws
22.4k vertices, each with two `zs_surge` calls and one `zs_surge_breaks`,
plus overdraw from its translucent cards. To cut the CPU 0.47 ms, the place
to look is the camera's 12 probes, each of which reads the swell when it is
low. Both changes would show in the look or the feel, so they are for the
user to decide.

Rerun (scratch, git-ignored): `zsh scratch/cost_series.sh r1 r2 r3`
(it runs `scratch/swell_cost.gd` on drive.gd, and a copy of it in the main
checkout's scratch/), then
`python3 scratch/cost_split.py scratch/cost/cost_*.csv` and
`python3 tools/frame_report.py A.csv B.csv`.
