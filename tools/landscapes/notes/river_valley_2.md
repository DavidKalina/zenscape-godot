# River valley (take 2, two runs)

**Intent:** fix take 1 (river_valley.md). Get a river that actually runs
along a carved S-meander, from high ground into a lake.

**Recipe:** `tools/landscapes/river_valley_2.gd` (run B, the Wire-free one).
Common to both runs: a size-2 Paddle swell at the head (to 2.2 m, against take
1's 5.5 m size-3 dome), a size-3 swell down for the lake (-1.2 m), and one 3 s
spring on the head, just above the channel's top. Willows on the inside bank,
oaks east, reeds round the lake.
- **Run A:** a size-3 Paddle sweep along the S, then a Wire gorge (Shift,
  shallow) drawn along the same S from the head into the lake. Stills are in
  `river_valley_2-take1/`.
- **Run B:** two slow Modeller grooves along the S (the second deepens the
  first), then a size-3 Paddle sweep over them for shoulders.

**Stills:** /private/tmp/zs-landscapes/river_valley_2/ (run B: 01-carved,
02-water, 05-meander, 07-meander-noon). Run A: `river_valley_2-take1/`
(01-carved, 02-water).

## What came out
- **It worked, in both runs: the water follows the S into the lake.** The
  spring makes a short cascade off the head into the channel's top, and the
  water fills the channel all the way round. Run A at 20 s: r1-r6 each held
  0.7-3.8 m³ (0.4-0.6 m deep), and the lake held 10.7 m³. By 45 s that was
  4-6 m³ per station, the lake 19.5 m³, 0.8 m deep. Run B came out almost
  identical (lake 16.7 m³, channel 0.8 m deep). Fish swim the channel, and
  dragonflies and frogspawn arrive.
- **But it is a flooded canal, not a river.** Every cut hit the same floor.
  After the gorge, the stations read r2-r6 at -1.18, -1.26, -1.49, -1.50,
  -1.50 and the lake -1.49. After the grooves and sweep: r2-r6 all -1.50, the
  lake -1.38. -1.5 m is the land's MIN_HEIGHT (native_terrain_data.gd), and
  the plate starts at 0-0.8 m. **There are only about 2 m of depth to carve
  into**, so the channel has no fall: water stands level from the foot of the
  cascade to the lake. It reads as an S-shaped lake (a fjord with a waterfall
  at its head), with no current, rapids or narrowing.
- **What it took** was not digging deeper. It was **keeping the head low
  enough** (2.2 m) that its spring's steepest descent went into my channel
  instead of down a flank, and making the channel deeper than the land's
  fall. Take 1's 0.45 m sweep could not hold the water. Two thumb grooves or
  one Wire gorge both could. The spring's course still chose its own pool
  point, at (2.2, -3.0) in run A and (4.2, -4.5) in run B, which is off the S on
  the east side. The cascade spilled over that pool's rim back into the
  channel only because the channel was lower.
- **Look:** run A's Wire gorge is the most dramatic carved form in my builds.
  It has sheer granite walls, a crisp S, and a canyon's head (01-carved). It
  is a canyon, though, not a valley. Run B's grooves plus sweep gave a softer,
  more valley-like S with earth banks (07-meander-noon). Morning mist sits
  over the whole channel in both, and only the noon still shows the water
  well.
- **Life:** spruce no longer dominates (run B: 32 spruce out of 104 trees,
  plus broadleaf and birch). Trees grow **in the channel** (birches standing in
  the water in 05-meander and 07-meander-noon), and willows are hard to tell
  apart.

## How the tools felt
- **Wire gorge:** it does what it says. Its bed rule ("never climbs, falls
  0.02 m/m, cuts through the dip's far side") is exactly what a river wants.
  But on this plate its 2.6 m depth (1.04 m at Shift) runs straight into the
  -1.5 floor.
- **Thumb groove twice, then a Paddle sweep:** this gets the same result as
  the Wire, softer. So for rivers, Wire and repeated grooves overlap.
  The Wire just does it in one stroke and paints rock.
- **Paddle sweep over a groove:** it opens the banks well. It is the one use
  of the sweep that read on screen.

## Gaps
- **The relief budget is one-sided.** Up is 5-8 m, down is about 2 m. A river
  needs fall, so the head has to be raised. But the higher the head, the
  more likely its spring runs down some other flank (take 1).
- **No way to say "water goes here".** The spring's descent and pool are
  chosen by the sim, not the player. It worked here only because the channel
  was the deepest line nearby.
- **The level sim water has no flow cue.** There is no current texture or
  foam on a channel at the same level as the lake. A river at rest looks like
  a lake.
- **Trees in water:** trees grew on cells under 0.5-0.8 m of standing water.

## Scores
Buildable 3/5 · Looks 4/5 (the Wire's canyon and the cascade are lovely) · Matched intent 3/5 (water follows the S, but as a lake)
