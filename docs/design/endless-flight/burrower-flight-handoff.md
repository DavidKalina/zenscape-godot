# Burrower in endless flight: handoff

Loop `burrower-flight` (spec: `spec-burrower-flight.md`), branch
`claude/timed-challenges-redesign-fa3049`. The creature itself:
`burrower-handoff.md`. A prototype: smoke checks and throwaway drivers in
`scratch/`, no committed tests, no full suite.

## Play it

`.\run-endless-flight.cmd`, no flags. Skim low over open ground or water with
the camera forward for about a second and a half. It comes in from the side,
crosses ahead and runs for up to 40 s. Climb off (over 5 spans for 1.4 s) and it
dives; it rests 6 s. **Z** or the pad's south face rolls: roll through a gong.

- `--no-burrower`: none of it. `--beats=1`: the timed challenges back.
- `--near-hud=glyph`: the tilted tag instead of the ring.
- Study, for the creature alone: `.\run-burrower-study.cmd`.

## What's built

- Beat routes off by default; code kept.
- The wake gate (`scripts/endless/burrower_flight.gd`): camera within 10 deg,
  1.2 s of NearMiss's skim, 6 s rest, open ground or water for 160 m. A forest
  counts as open; cliffs, stone and steep ground shut it.
- The game's land (`scripts/burrower/game_land.gd`): trail and scar on the
  terrain, grass parted by the shared react stamps. It steers round what stands,
  dives at an edge, resurfaces ahead.
- Forests: it weaves trunks, crowns shudder in a band (`tree_shudder.gd`), the
  chase holds over the canopy, runs bend toward thick stands.
- Water: a ribbon on rivers and lakes (`wake_sheet.gd`), a second track in the
  sea's own wake. Runs may start over water.
- The chain: orb, bell and gong are moves with their own glyphs (120, 200, 380
  base, times pace). The HUD shows no distance on them.
- A gong flown into unrolled: the plane is put back on the face and turned off
  toward the rim, keeping 55% of its speed, with the clank. The chain stands.

## Frame rate

Rendered, 1440x900, vsync off, the same straight 480-frame flight, world seed 1,
two passes each. Meadow: `--start=720,640,-90`, 3 m skim. Wood: a line of 38 trees
in 300 m, level over the crowns, head in the wood all 480 frames, 60 trees shaken.
Median ms frame to frame, with the mean in brackets:

| | off | asleep | run, before | run, after |
|---|---|---|---|---|
| Meadow | 9.4, 10.2 (10.1, 12.0) | 8.8, 9.3 (9.4, 9.8) | 17.1, 22.9 (18.3, 22.9) | 11.2, 11.7 (11.8, 12.2) |
| Wood | 6.4, 6.6 (6.8, 7.0) | 6.4, 7.5 (6.7, 7.5) | 17.9 (18.5), one pass | 10.7, 11.1 (11.0, 11.5) |

The "before" meadow passes were two separate trial runs, with the part-by-part
timers in the second. Asleep is off within noise: the gate is 3.4 us a frame. The
creature's own CPU, timed in place: 8.2-10.7 ms before, 2.2-2.4 ms after on the
meadow, 3.6-3.7 ms in the wood, plus 0.15-0.27 ms for push-ups. p99 after: 23-26 ms
meadow, 20-25 ms wood; off was 17-23 and 13-15.

The cuts:

- The bow's rows read the land at 3 of 11 points, on 3 of 7 rows, one slope and
  colour a row; the rest are lerped. An A/B at full detail
  (`captures/shots/bf_bow_sheet.png`, `bf_bow_full_sheet.png`) looks the same but
  for a slightly longer tongue at the tip.
- `_strip` joins rows laid out once; indices kept; one live mesh reused.
- `game_land.gd`: `open` and `wall` kept by the 2 m cell.
- Clods read the land only when coming down near it.
- The gate looks at one distance a frame, not nine in one frame, because a whole
  pass was 3.7 ms in one frame on an open meadow.

What's left in the wood: move 1.3 ms, shudder 0.7, rebuild 0.9, clods 0.5.

## Stood in, open

- **Look:** the sea wake's tan dashed look and thin white curve; a faint river
  wake; black clods at water edges; a bright green strip along the trail on
  yellow ground; dark gaps in the ridge line; the chase camera passing through
  the gong, a frame or more filled with the disc.
- **Land:** real entrances onto rivers and lakes not proven: the drivers placed
  the head there. The forest's trees are sparse: the best line found held 38 trees
  in 300 m, so the wave of crowns has few to shake. It does sometimes run right
  through a trunk.
- **Tune:** chain scores are guesses. The gong's glance turned the path about
  115 deg when met square, a hard knock; `BUMP_OUT` and `BUMP_LEAST` in
  `push_ups.gd`.
- **Sounds unheard:** no ear in a driver. The streams load.
- **Chain loss:** a run doesn't take a chain. Every loss traced in 4 runs was the
  plane's own touch of the land (the game's rule). Knocking a tree loses it too
  (`TreeKnock.LOSES_CHAIN`), which matters over a wood.
- **Tools:** `scratch/bf_edges.gd`'s forest checks are stale (forest counts as
  open now) and its seed 1 "cliff" launch is the gentle hill in the trail.
  Driver launches in a tight loop ratcheted the FOV until it logged errors; a
  driver thing, real play can't reach it. `scratch/bf_wake.gd` now waits a frame.

## Tests

No test in `tests/` names the burrower, `push_ups`, `game_land`, `land_rocks` or
the near-miss HUDs (grep). None run, no full suite. Sea and tree shaders changed
earlier in the loop: tests reading them weren't run. None known broken.

The study's own `scratch/burrower_trees.gd` was already failing: 2 FAILs (passes
near trees and shoves them 1, leaf bursts 1), the same at the start of the forest
task. It still fails.

## Fixed along the way

`scripts/endless/land_rocks.gd` `_add_bodies`: a typed var took a freed body when
a cell went before its colliders were added. The error came every frame and the
queue's head stuck, so the rock colliders behind it waited. Seen as 1348 errors in
a seed 3 run; a fast teleport or a crash's relaunch could hit it in play.

## Checks run, last round

- Smoke: PASS `studies/endless_flight.tscn` (0 errors), PASS
  `studies/burrower_study.tscn` (0 errors).
- `scratch/bf_gong.gd` seeds 2, 3, 4: 2 glances each, 11/11, 0 flown through;
  chain unchanged at each; flying on 17 m on after 0.75 s; rerun after all cuts,
  seed 3: 7/7.
- `scratch/bf_chain.gd` seed 3: 23/23, rendered, after the cuts. Seeds 2 and 5
  before the cuts: each failed its launch hunt, and seed 5 flew into the ground
  and banked no line.
- `scratch/bf_wake.gd` 15/15, `burrower_rouse` 15/15, `burrower_trail` 18/18.
- `scratch/bf_edges.gd` seeds 2, 3, 4: the cliff gate shuts ('steep', 'rise',
  'rise'); each has one stale forest FAIL.
- Stills looked at: `captures/shots/bf_chain_orb_h_00.png`,
  `bf_chain_bell_h_03.png` (HUD: "ORB +116", "BELL +187", no distance), the two
  bow sheets above.
