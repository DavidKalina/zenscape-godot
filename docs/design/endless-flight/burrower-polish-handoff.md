# Burrower polish: handoff

Loop `burrower-polish` (spec: `spec-burrower-polish.md`), branch
`iter/burrower-polish`, on PR 33's head `b55140ff`. A prototype: smoke checks and
throwaway drivers in `scratch/`, no committed tests, no full suite. Not pushed.

## Play it

```
cd /Users/davidkalina/Documents/Projects/zenscape-burrower-polish && python3 tools/play.py -- --burrower-every=5 --pilot=fresh
```

The movement's numbers, with their defaults: `--burrower-orb-off=9` (least metres
off the plane's line an orb comes up, the band 6 m wide; 0: on the line, as before),
`--burrower-reach=2` (m past the study's reach; 2.5 before), `--burrower-swing=18`
(m each side; 0: none), `--burrower-swing-s=7` (s there and back).

## What changed

- **Trail.** The strip takes the ground's real meadow share, not a literal 1.0, leans
  straw on dry ground, and has a bitten edge and a ragged tail. The scar's dash gates
  are smooth noise of uneven length.
- **Sightings.** A wood throws pale chaff off the crowns, doubled past 220 m. Water
  throws a soft mist column with fading drops. Water sightings stay on water:
  `water_goal` sounds the way, he re-plans 36 m short of a shore, and out of the water
  for 0.7 s he goes under (`rouse.why` "ashore"). `wet_along` sounds every 16 m, not
  every 40: it was stepping over sand bars.
- **Wakes.** The tan was foam lit cream by the low sun. His track gets its own white
  foam pass in the sea shader, adding nothing with no burrower. River froth is emissive
  and its centre continuous.
- **Earth.** Clods take the colour of the ground they came from, read every 0.3 s. The
  dome's tint is 40% toward soil, not 80%. The prop-wash grass blades in
  `endless_motes.gd` take more of the ground's tint and are smaller: this is **all
  flight**, not just the burrower.
- **Orbs.** The stretch tops out at 1.13. The fast ball's edge falls to amber and its
  halo draws out behind it.
- **Climb-off.** It counts the plane's own climb, not the ground falling away. Levelled
  off high over a valley, a run now goes on until its orbs are out or 40 s.
- **Dust.** The GIF look: each puff's shape was seeded from `INSTANCE_ID`, and the
  packed list renumbers on every death, so the whole cloud changed shape about 10 times
  a second. Seeded from the puff's colour now. All frame-rate cuts stand.
- **Tree gust.** 10 m each side of his line, on a run and a sighting (it was 30 and
  110). The stamp follows the arc he's turning on, not a straight guess. Trunk and crown
  now shear straight together, so trees lean straight, not bowed.
- **Movement, game only.** Orbs come up 9-15 m off the plane's line, within what a
  half-stick turn can reach. His course swings 18 m each side. The run's turn cap is 1.3
  rad/s, not 2.4, lifted when land shuts ahead. While an orb is due he stays 1.8 s
  ahead, not 2.4, and near trees an orb can rise to 26 m.

## Measured

- Orbs taken of orbs pushed, by stick, seeds 1-3, before and after: straight line 67/72
  to 8/63; chasing him 77/81 to 52/64; steering at the orb 78/78 to 50/63.
- Trees leaning on a run, seed 1 wood: 110, the furthest 94 m off his line, to 26, 10 m.
- Frames where the dust changed shape: wood 45 of 360, sea 41 of 240, run 37 of 300,
  all to 0.
- Sightings going under within 5 s round a shoal: 2 of 21 to 0 of 23.

## Checks, last merge (`da135d7d`)

Smoke PASS on `studies/endless_flight.tscn` and `studies/burrower_study.tscn`, 0 errors.
Rendered drives over meadow, wood, sea and inland water on seed 1, a wood at 2560x1440,
and headless drives on seeds 2 and 3 over sea and wood: 0 errors, 0 FAIL lines. Their
runs outlasted the driver's 900 frames, so none of these drives saw a run end on the
final merge. The lanes saw that on their own branches.

`tests/` was not run. Sea, tree, dust, ridge and wake shaders changed, and tests that
read them weren't run. No test is known broken.

## Open

- **Feel.** No person has flown the movement. A bot can't say if the swing reads as long
  arcs or nerves, or if 9-15 m is fun or fussy.
- **Runs got longer,** 7.5-15 s to 16-23 s, and he sounds more, 2-3.5 a run on meadow
  (steep ground ahead), which can read as hopping. One half-stick meadow set averaged
  15.8 a run: not traced.
- **Dead-top spruce.** The tall bare spikes are authored (variant 5), 8-12.5% of trees
  near that wood against 4.3% by weights. The Blender script paints them silver, and
  they read red-brown. The user's call. At three times today's gust, a trunk still shows
  a bare run past its crown, about half as long as before.
- **Sightings.** No film at the full 280-420 m; the closest is about 240 m. A sharp river
  bend still ends one by going under.
- **The chaff.** Up close it's a big cream cloud. It still swells and thins in gouts, on
  purpose: if "pauses" meant that, the dust fix didn't touch it.
- **Engine errors, not traced.** In long headless runs on lane branches: "unimplemented
  base type" at `instance_set_base` from `_step_dust`, "Condition !F" at `update_end`,
  and `land_stream._commit` "Initializing already initialized RID". None in the final
  checks, which doesn't rule them out.
- **Not swept:** rivers and lakes for the movement, seeds past 3 and frame times. The
  PR's two checks before done, a sighting's frame rate on a quiet PC and the orb hit rate
  from the default start, are still open.
- **Look, small.** A dark vent at the dome's top; clods up close still read as rocks; the
  wood's airborne clods looked near black in `shot_at`'s camera, brown in play; the sea
  arms are clean, close to brush strokes. An orb over a river showed a "FOREST +1" tag
  (`wood_33_run`): not looked into.
- A blue wedge at a river mouth (review's `inland_19_close`) is still there, unexplained.
