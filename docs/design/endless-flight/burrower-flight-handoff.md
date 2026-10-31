# Burrower in endless flight: handoff

Loop `burrower-flight` (spec: `spec-burrower-flight.md`), branch
`claude/timed-challenges-redesign-fa3049`. The creature itself:
`burrower-handoff.md`. A prototype: smoke checks and throwaway drivers in
`scratch/`, no committed tests, no full suite.

## Play it

`.\run-endless-flight.cmd --burrower-every=5`: a sighting about 5 s after he last
went (with no flag, the first at about a minute of flight, then every 2-3 minutes).
Fly at 100-200 m and look ahead and to the sides, 280-420 m off: a patch of wood
going over and paling, or a white plume with a V on water. Ignored, he sinks after
20-30 s. Come down within 110 m, under 60 m over him, with him ahead, and the run
starts from where he is. He crosses your line and throws up to 3 orbs from behind
his head, then dives. Climb off (over 5 spans for 1.4 s, after 5 s to get low) and
he dives. **Z** or the pad's south face rolls.

The study keeps the off-screen entrance, the skim, bells and gongs; the game doesn't
use them.

- `--no-burrower`: none of it. `--burrower-every=S`: the rest between sightings.
  `--beats=1`: the timed challenges back.
- `--near-hud=glyph`: the tilted tag instead of the ring.
- Study, for the creature alone: `.\run-burrower-study.cmd`.

## What's built

- Beat routes off by default; code kept.
- Sightings (`scripts/endless/burrower_flight.gd`), see Play it. The rest: a thing
  you come across, not a schedule; 2-3 minutes is about 4-6 km of flight at 34 m/s,
  and the first comes at a minute so a new player meets him. Nothing suits: 12 s of
  looks, then 30 s. Only loaded plan cells of 12+ trees with 14+ on his way, or water
  160 m on.
- Far off (over 220 m) `distant` drops ridge, clods, dust, needles and trunks; his
  way, the gust and the wake stay. The gust's map (384 m a side) follows his head, not
  the eye: only he writes it. A sighting's gust is 110 m each side, gains up to 1.6
  with distance (`zs_gust_rect.w`) and pales sprites more; on water he throws a plume.
- Orbs (`push_ups.gd` `_due_head`): he runs across the plane's line and one comes up
  2.5 m behind his head, 1.2-4 s of flight off, rising up to 14 m over the ground to
  meet a plane coming in high. Reach 2.5 m past the study's.
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

**The last round's table was misleading and is gone.** One straight flight with
the head forced on a line said a run cost 2-4 ms. A real 40 s chase, flown through
the stick, woken by the gate, in real time (`scratch/bf_chase.gd`, driver
uncommitted, `--no-burrower` flying the same head's track over the same land),
says this:

**Where the time goes.** The frame is the slower of two things. The GPU takes
about 10 ms at 1440x900 (13 ms at 2560x1440, 8.7 at 640x400; 8 million primitives,
scale 0.75, and the run adds none of it worth measuring). The main thread took
4.4 ms without a run and 7.6 ms with one, measured with 3D off (`--no3d`), which
hides behind the GPU's 10 ms on a quiet PC and shows as soon as anything else
takes the CPU. That is why the last bench saw little: the median barely moves until
the CPU loses the race, then the frame jumps.

Reproduced only with something else on the PC: another session's Godot ran
alongside some passes, which was unplanned. Before the cuts, in those passes, a run
went to 13-15 ms median, 23-25 p95, a quarter of frames over 16.7 ms, while the
off passes stayed at 10-13. One early pass held 20 ms median, 26.5 p95, 50 fps
against 100; it wasn't sampled for what else ran. On the quiet PC a run was only
11 / 14 / 18 ms. The PC when the user played wasn't measured.

ms, whole frame, frames of a run. "others" says if another Godot overlapped.

| window, pass | no burrower | before | after |
|---|---|---|---|
| 1440x900 | 10.5 / 11.4 / 11.9 | 11.1 / 13.9 / 17.8 quiet | 10.1 / 14.0 / 18.7 others |
| 1440x900, again | 10.4 / 11.6 / 13.5 | 12.9 / 24.7 / 31.0 others | 10.5 / 14.0 / 21.8 others |
| 2560x1440 | 13.1 / 14.7 / 17.2 others | 14.6 / 23.2 / 29.3 others | 13.1 / 14.1 / 15.0 quiet |
| 1440x900, 8 cores spun | 10.1 / 14.0 / 25.9 | 13.2 / 18.0 / 21.4 | 10.7 / 14.0 / 16.0 |
| main thread, 3D off | 4.4 / 6.3 / 7.8 | 7.6 net of the bot, 8.9 with it / 11.4 / 13.6 with it | 6.0 / 9.8 / 12.4 |

Median / p95 / p99. After the cuts: over 16.7 ms 53 and 45 of 3000 frames at
1440x900 (others), 12 at 2560x1440 (quiet); before, in the contended passes, 684-707.

By place, after, 1440x900 (A1): meadow 10.1 / 14.0 / 18.2, wood 10.0 / 14.0 / 24.7,
water 9.8 / 10.4 / 13.1 (104 frames only, thin).

The cost, main thread, mean ms a frame, timers in place (first profile, then now):
`GameLand.water_y` marching the sea's waves on land was inside most of these.

| part | was | now |
|---|---|---|
| Bow's rows | 0.87 | 0.06 |
| Clods | 0.78 | 0.58-0.73 with the buffer; not timed since they took turns |
| `_feel` | 0.37 | 0.04 |
| `_wet_at` at the head | 0.34 | 0.03 |
| Samples, stamps (`if wet` branch) | 0.26 | 0.15 |
| Shudder | 0.11 | 0.09-0.14 |
| Rest of the game reacting (react, near, HUD...) | | about 0.5, near noise |

The cuts:

- `GameLand.water_y`: land over 8 m above the sea skips the swell, which marched the
  waves on every call. Biggest cut: see the bow, `_feel` and `_wet_at` above.
- The bow reads the land 30 times a second; between, its rows go along with the
  head. Over 1 m at 34 m/s of stale height at worst.
- Clods: one buffer; lying clods not rewritten; in the air they step every other
  frame, lying every fourth. So clods move at half the frame rate: a real cut, not
  visible in stills, judge it in play.

Stills: `captures/shots/fr_ab_chase.png`, `fr_ab_head.png`, before left, after
right, different moments of two runs. Head, ridge, clods and dust read the same.
The trail and clods look as they did; nothing changed in shaders or materials.

Target (within 2 ms of no burrower, median and p95): median yes. p95 no at 1440x900:
about 2.5 ms over. At 2560x1440 yes, one quiet pass. p99 is 5-8 ms over at 1440x900.
The main thread is still 1.6 ms over at the median and 3.5 at p95.

Not covered: the real launch through the title (all with `--no-title`); a person's
hands; Boost; a second run in one flight, or long play; the pad; a rendered chase
on water for more than a few seconds; a slower PC. Bursts of GPU 17 ms in the
others-overlapped passes look like that other Godot, not proven; the quiet pass
didn't show them. The bench's frames are the plain window: nothing else was open
on purpose but other sessions ran. Multi-second stalls appeared in on and off
passes alike, in no timer of the game's tick; not explained.

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

`scripts/endless/pilot_book.gd`: `pilot.json`, which every checkout and worktree on
this PC shares, held `"metres": null` partway through this round (some run saved
an inf or NaN; which one wasn't found). Every flying frame was then a script error
with a backtrace. `count` drops non-finite, `load_book` drops non-numbers, and the
first save by this branch clears the file. Main lacks the fix.

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
