# Crown pop-in: handoff

Traced, nothing changed in the game. No C++ ported: nothing universal was worth it. The slow
light has a one-word cause and is the user's call (below).

Measured on this PC (16 threads, RTX, rendered 1440x900, `--no-fixed-fps`, straight lines at
50 m/s with the pose set each frame, the real loop streaming round it). No game was open during
the numbers quoted here, except where marked. Drivers are in `scratch/popin/` (git-ignored):
`trace.gd`, `light.gd`, `lod.gd`, `l7.gd`. Per-level build times came from a temporary
instrumented copy, since reverted.

## What causes it, ranked

1. **The "light that takes forever" is the collar's sky.** The cloud collar went off by default
   (`--collar=1` brings it back), but `EndlessLook.set_collar_sky` stayed on
   (`studies/endless_flight.gd:582`). Above a band and near the Peak it moves the sky's hour from
   the morning to the golden hour, about 7.5 hours of day. It is a position blend, with no time
   constant and no lag:
   - Band: 755-855 m over the sea. Whole out to 1520 m from the collar's centre, gone by 3020 m.
   - Sun bearing swings 133 degrees (yaw -23 to -156), height 0.515 to 0.307, warmer colour, sky
     fill 0.358 to 0.315, haze 1.43 to 1.35.
   - **Flying in level at 1000 m and 50 m/s it takes 26 s** (a = 2900 to 1600). Climbing at
     30 m/s through the band it takes about 3 s.
   - Every shadow on the mountain sweeps with it, and the rock changes colour. With the plane held
     at one height and place, nothing moves but the clock.
   - The coordinator's lead fits: in `scratch/strike/shots/d_wide_sheet.png` the film starts with
     the plane in the band. Same still camera, climbing, `--collar-sky=0` against default:
     `scratch/popin/on_pick.png` turns brown, `scratch/popin/off_pick.png` stays dark.
   - It isn't shadows settling, GI, SDFGI, a probe, exposure or a fade: there is no GI, no probe
     and no auto exposure in the look.
   - Side effect: the rake of `PEAK_SUN` holds only below the band. The plateau and towers
     (880 m and up) are always seen under the golden sun, not the raked one.

2. **The biggest swap lands at about 666 m, all at once, with no fade.** Land levels are plain
   visibility swaps (no geomorph, no dither). The L3 to L2 swap is where three things arrive
   together: the rock's gullies (24 m scale) and ledges, their vertex paint, and the land's
   shadows (only levels 0-2 cast, `land_stream.gd:575`, while the sun's reach is 900 m). This is
   the likeliest "textures out of nowhere", since the rock's relief paint is per vertex.

   | Swap | At about | Height rms / worst | Normals | Relief paint |
   |---|---|---|---|---|
   | L5 to L4 | 2660 m | 7.4 / 80 m | 16 deg | 44/255 |
   | L4 to L3 | 1330 m | 0 | 17 deg | 0 |
   | **L3 to L2** | **666 m** | **6.8 / 40 m** | **24 deg** | **86/255** |
   | L2 to L1 | 333 m | 2.0 / 19 m | 17 deg | 28/255 |
   | L1 to L0 | 166 m | 0 | 16 deg | 0 |

   Four spots on the massif. So yes: `PeakRock` loses detail by level, and this is where it
   shows. The rib at 2660 m is the other one.

3. **Peak chunks arrive about 1 s late in the gorge, up to 4.4 s at the worst.** A Peak chunk
   costs about 180 ms against 15-20 ms for a plain one, and low-priority work has 4 of the pool's
   16 threads (`low_priority_thread_ratio`, default 0.3). Flying up the gorge line (a = 2300 to
   -300, two runs each):

   | Level | Wait median | p90 | Worst |
   |---|---|---|---|
   | L0 (high priority) | 240-250 ms | 480-500 | 900 |
   | L1 | 1000-1070 ms | 2100-2180 | 3300 |
   | L2 | 1180-1240 ms | 1860 | 4260 |
   | L3 | 1320 ms | 2380-2460 | 4440 |

   While a chunk waits its parent stands, so this delays item 2's swap by 50-60 m of flight. It
   doesn't leave holes. Frames stayed at 8 ms median, 11 p95, 1-3 frames over 33 ms a flight.

   Where a Peak chunk's 140-180 ms goes (L0-L3): `PeakMassif.apply_chunk` 95-130, `RockShape.grid`
   25-50 (nearly all of it the ring's heights through the Peak's GDScript), base field, rivers,
   tops and the rest about 10.

## Tried and left out

- **`low_priority_thread_ratio` 0.6: don't.** Twice, the same: frames 8 to 80 ms, a chunk 184 to
  880 ms, waits 4 s and up. Throughput halved with twice the threads, and the main thread stalled
  with the workers. Something is contended, a lock or the debug VM's object checks. Not traced,
  and not checked on a release export, so the shipped build may scale differently.
- **Capping land's low-priority tasks at 5** (they ask for 14, so the sorted queue sits in the
  pool's FIFO). L0 and L1 waits improved 15-25%, but L3-L5 starved, up to 8 s. A trade, not a fix;
  throughput is the limit. The second run of this pair overlapped another agent's work, so the
  first pair is the one that counts.

## Not causes

- Snow's broad bake: 1.2 s on a worker, lands before the first frame.
- Towers and the far body: built during load. The far mesh's toggle is at far-plane distance,
  not traced in flight.
- No texture streams at runtime near the Peak.
- Shader compiles: the Peak's materials have no warm-up, but flights showed no stall bigger than
  60 ms. A first-ever run with an empty pipeline cache was not tested.

## C++: nothing ported

The one universal candidate, `RockShape.grid`, has only 3-4 ms of its own loops; the rest is Peak
heights, which is the held code. Rivers are 2-5 ms and tops 0.2 ms near the Peak. No universal
noise helper runs per vertex there: the Peak's noise is its own.

One universal item is real but isn't pop-in: first-touch site cells cost an L7 chunk about 900 ms
(`splits_in` 550-740, `tunnels_in` 115-170, `ponds_in` 45), then they're cached. That is load
time: 34 L7 chunks at start, 2 in a 52 s flight.

## For the held Peak port

Port `apply_chunk` and the Peak's height in `grid`/`peak_grid`. Both are needed: the rock shape's
ring pays the same height. From about 180 ms to 20-30 ms a chunk is an estimate from the native
base's 5-15 ms, so about 6x throughput, and gorge waits should fall from about 1.2 s to the
250-300 ms level the land shows off the Peak.

That fixes item 3 only. Same output means the 666 m swap stays exactly as sharp, only on time.
What the port does buy is room to spend on item 2 (below).

## Decisions for the user

- **The collar's sky.** Keep it, or drop it. `.\run-endless-flight.cmd --collar-sky=0` tries it
  without a code change. Off, the light is one light all the way up, but that face stays near
  black and the plateau loses its golden hour. Other shapes: a fixed hour near the Peak at any
  height, or a smaller swing. Changing the default changes the mountain's look, so it was left.
- **The 666 m swap.** Options: let L3 keep gullies and ledges (`KEEP_QUADS`), let L3 cast shadows
  (its crests have no `_crest_cut`, so teeth may show), or a dither fade on swaps. All change the
  look or cost frame time. None tried.

## Not verified

- That item 1 is what the user saw: it fits their words and the film, but they haven't been asked.
- A release export, the Mac, and any look change from these findings.
- The cause of the contention at ratio 0.6.
- Sky radiance lag (`INCREMENTAL`) wasn't measured alone. The numbers can't see it; a held still
  camera showed no change.

Smoke passes on both worlds. No code changed; the working tree held another agent's strike edits
at that smoke.
