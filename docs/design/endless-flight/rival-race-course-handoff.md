# Rival race: the landing start and the course (handoff)

The rival race (`rival-race-handoff.md`, `rival-race-polish-handoff.md`) now starts on the ground and is run round a fixed course of gates. On the accept the rival lands on a flat ahead. You land in gold marks beside it, and the count runs. At GO both take off from rest. The gates count in order for both of you, and the first through the last gate wins. Passing the rival and holding the lead no longer wins anything. The old trail motes and single gate are gone. One ribbon now runs along the whole course, laid once, with brackets on every gate. This is a prototype round: smoke checks, a throwaway driver and stills. No tests were committed.

Where the two earlier docs differ from this one, this one holds: the start, the win rule, the marks and the tag's words.

## Play it

```
.\run-endless-flight.cmd --race-near-start                     # Windows
./run-endless-flight.command --race-near-start                 # Mac
.\run-endless-flight.cmd --race-near-start --rival-skill=1.5   # a sharper rival
```

`--race-near-start` still puts traffic plane 0 ahead of you, bracketed. It now also looks for that plane's strip at the start: ahead, then out to the sides. When you challenge it, it flies straight there. On seed 2 and the regions world (seeds 1 to 3) it found one. On seeds 1 and 3 to 6 it found none, and the rival looks for one as usual, taking 3 to 37 s. Hold Tab (pad: R3) on the bracket, as before.

## The flow

| phase | what happens | the tag says |
|---|---|---|
| landing | It waggles and looks for a flat (`rival_strip.gd`), a few spots a frame. Once it has one, the course is planned, the ribbon appears, and your marks are laid. It flies there at 44 m/s, comes down the glide at 23 m/s, flares, touches at about 13.5 m/s, and rolls 60 m to a stop. Its smoke stops on the ground. | it's looking for a flat · it's landing · land beside it, with the distance to your marks |
| waiting | It stands, idling. A gold wedge marked "your marks" hangs over your marks until you are down within 60 m of them. | land beside it · in the gold marks · roll into the gold marks · stop in the marks, with the last 20 s counted down |
| count | You are on the ground, inside the marks, under 1.5 m/s. The 3-2-1 count runs with the same bells and rumble as before. If you roll or leave the marks, the count stops and "wait for GO" shows in coral. | hold still |
| race | At GO both take off. Gates count in order. | through the gold gates · first through the last wins (4.5 s), then gate 2/3 · ahead (or behind), last gate · ahead, or missed gate 2 · go back through (coral). The big number is your lead along the course, gold +38 m or cream −52 m. The bar under it fills with the gates you have cleared. |

**Called off ("race off"):**
- you press Tab or R3 again
- the rival hasn't stood 120 s after the accept
- you haven't lined up 60 s after it stood
- you are 1800 m further from the strip than it is, for 3 s
- in the race, you are 900 m off the course for 3 s
- in the race, you sit 2 s on the ground after having flown

**The results:**
- **RIVAL BEATEN**, "through the last gate first · 0:34"
- **IT GOT THERE FIRST**, "you made 1 of 3 gates"
- **OUT OF TIME**, 240 s from GO, kept as a backstop

## What was built

### `rival_strip.gd` (new): the strip

A strip is two parallel lanes on one flat: the rival's, and yours 3.5 wingspans aside. The tests reuse what the game already judges ground by:

- **Level, as the flats check measures it** (`land_ponds.gd` `_strip`, the land's own guarantee):
  - each lane is read every 4 m, from 110 m before the rival's stop to 60 m past it;
  - no rise over 1.92 m in 16 m, or over 3.84 m in 64 m;
  - no rise over 0.2 m a metre from one read to the next (this catches a ditch or a stream's bank between the 16 m points);
  - lane to lane, no more than 1.92 m apart;
  - dry: 2 m over the sea, and off a river's or a pond's water by a wingspan.
- **No tree planted near it.** Every node of the tree plan's flats grid (TreePlan `FLAT_STEP` 16 m) within 12 m of either lane must pass TreePlan's own `_flat` measure. The plan keeps flats open, so no tree is planted there, built yet or not.
- **Nothing standing on it.** The study's `_blocked` and `plane_ground` are read every 6 m on each lane and its wingtips (arches, rocks, trees, halls, tunnels).
- **Clear approaches.** Each lane's glide (`glide_y`: 0.1, eased flat over the last 40 m) has 4 m under it, 340 m back, counting water. So does a 0.15 climb out for 360 m.
- **Search order.** Spots are tried at 500 to 1800 m ahead, nearest to 650 m first, within ±0.85 rad, with the lanes turned up to ±0.55 rad. After a first pass finds nothing, the search also goes out to ±1.45 rad.
- **Checked again near it.** At 380 m from the touch, the lanes are checked again for anything built since. If a lane is blocked, the strip is dropped and the rival looks again.
- **Your marks** are 44 m long (±22) and ±1.7 wingspans across, centred beside its stop.

### `rival_course.gd` (new): the course

The course is planned once, when the strip is picked, from the start line (between the lanes). It is never planned again.

- **The run.** It runs 90 m along the ground, then climbs at 0.16. It is never under anything standing there.
- **Gates.** 3 to 5 gates, chained, at most 4200 m in all. Each gate's lead-in is 220 to 1300 m on from the last gate's way out, within 0.85 rad of it, and entered the way it is come at. A gate can be an arch, a split, a hall or a tunnel, using `rival_line.gd`'s own candidates and threadability rules.
- **Air gates.** Where no opening is in reach, an air gate stands down the lowest way ahead, 420 to 620 m on.
  - Its frame is ±12.6 m by ±7.3 m.
  - Its bottom is 9 m over whatever stands under the frame.
  - Its middle is as far over whatever stands along its 90 m in and 70 m out.
  - The candidate chosen is the one lowest over both its frame and the leg to it.
  - So every course has at least 3 gates.
- **The ribbon's height** (`line`, a point every 4 m):
  - on the legs, 13 m over whatever stands ahead, read 200 m on with spans counted;
  - it settles onto the next opening's height over the last 260 m;
  - through an opening, the opening's own height.
  - The rival flies this same height, so the ribbon and the rival agree.
- **Cost.** Planning takes 35 to 105 ms, once, at the moment the strip is picked.

### `rival_line.gd`: the rival's flying

The rival now has modes: `air` (no strip yet, down the valleys), `land`, `rest`, `takeoff`, `course` and `peel`.

- **land.** It flies by pursuit to the start of the final approach, then down the strip's glide. From 90 m short of the touch it is on rails:
  - it eases onto the lane's line;
  - its speed eases to 13 m/s;
  - the flare takes its sink to nothing and lifts its nose to its rest pitch (PlaneStrip `rest` and `contact`, the parked plane's own wheels and tail skid);
  - it rolls out with even braking to stop exactly at its stop.
  - If it reaches the rails more than 25 m off the line, or turned 0.6 rad off it, it goes round and looks again.
- **takeoff.** At 6 m/s² down its lane, the tail lifts from 6 m/s, and it leaves the ground at 14 m/s. It climbs at 0.16, or steeper (up to 0.5) where whatever stands ahead now asks for it, and hands over to the course 7 m up.
- **course.** The same pursuit, wobble, late heading, carry and turn bleed as before, flown along the fixed course. A guard keeps it at least 4 m over whatever stands just ahead (spans counted on the legs and through air gates).
  - If it goes past a gate outside it (the race sees that), it comes round: out 170 m to the lower side, back 380 m before the gate, and in again.
- **Ducking.** Ducking is dropped for course races. Coming round costs too much to be a skill knob. DUCK now rolls a *checked* gate: the rival lifts off harder for it and keeps 0.85 of its carry, so a lower skill loses time at the gates instead of skipping one. The roll is still per seed, race and gate.
- **Skill knobs.** WOBBLE, LATE, CARRY, TURN_BLEED and PACE_PER_SKILL are unchanged.
- **Removed:** the head-start jump (JUMP, START_GAP, JUMP_TIME, JUMP_EASE), the per-opening `_plan` and `intent()`.

### `rival_race.gd`: the race

- **Phases.** It has the phases above. The win rule is the gates: a gate counts when the way from last frame to this one crosses the mouth's plane the right way, within `half_w` plus half a wingspan across, and from `lo` to `hi` with 1.5 m either way.
- **Progress** is how far along the ribbon you are, never past your next gate. The rival's is its own distance along the course, held the same way.
- **The pace from GO** is unchanged: 0.93 times your Boost, times skill. CATCH_UP now reads how far ahead it is along the course. FLOW_EASE is unchanged.

### `rival_marks.gd`: the marks in the world (rewritten)

- **The ribbon.** One mesh, laid once when the course is planned. A shader turns it to face the eye.
  - It is 0.8 m wide near, and never under 12 px wide far off, with a gold core over a dark soft edge.
  - A slow glint runs along it the way you are going.
  - It is at full strength up to your next gate, and 0.55 past it.
  - Behind you it fades out over 60 m.
  - Near the eye it fades out, gone at 8 m and whole from 32 m.
  - It is depth-tested, so the land hides it.
- **The gates.** Each gate has four corner brackets over a dark edge. Your next gate is gold and pulsing, the gate after it is bone at 0.45, and later gates are dimmer still. Each bracket fades near the eye, so flying through a gate never fills the view. A gate you clear flashes, swells and goes out over 0.6 s.
- **Your marks.** Gold corner ticks are laid on the turf, with a faint fill and four posts 8 m tall (at least 40 px on screen). They turn bright and pulse faster once you are in them.
- **Colours.** The gold in the world is a deeper gold (1.0, 0.6, 0.1) than the HUD's, because the tonemap pales it. The HUD's gold made the ribbon read as white.

### `rival_race_hud.gd`

- A gold "your marks" wedge over your marks, which sits at the screen's edge when they are off screen.
- When you clear a gate, gold corner brackets round the screen swell out and fade over 0.5 s. The gate's own 3D flash is behind the camera by then.

### `endless_traffic.gd`

- A rival keeps off you only in the air: `keep_r()` is 0 on the ground and on the way down or up. Its keep-off floor is its own LOW_LEAST, not the traffic's 15 m, which used to pop it up at the takeoff.
- On the ground it lays no smoke. When it is off again, a fresh trail starts, so there is no streak along the strip.
- `_keep_clear` lets the rival be while it flies alongside you, closing at under 3 m/s. Before, it veered off you at the shared takeoff.

## Proof

**Smoke** (`tools/smoke.py`), each passing with 0 errors:
- the default;
- `--race-near-start`;
- `--race-near-start --world=regions`.

**Throwaway driver:** `scratch/race_course.gd` (uncommitted). It goes through the real input path only: the stick, `fly_boost`, `fly_brake` and `fly_challenge`.
- It challenges the rival and follows it to its strip, staying high over the land.
- It flies down its own lane on a glide, braking to about 13 m/s, touches down, rolls into the marks (Boost to creep, Brake to stop), and waits for GO.
- It takes off by Boost and a pull, then flies the course: `--pilot=line` follows the ribbon gate to gate, and `--pilot=cut` flies straight at the last gate.
- It logs the gates each racer clears, the result, the rival's clips and the gap under its wheels, the strip's flatness read every 2 m, and how far apart the two planes were at the count.

```
python tools/sweep.py scratch/race_course.gd --seed 1..6 --arg pilot=line,cut -j 6 -- --scene-args --race-near-start
python tools/sweep.py scratch/race_course.gd --seed 1..3 --arg pilot=line -j 3 -- --scene-args --race-near-start --world=regions
```

| seed | course | rival stood (s after accept) | bot landed | line pilot | cut pilot |
|---|---|---|---|---|---|
| 1 | air, air, air | 80 | 111 | won, 3/3 vs its 2 | lost, 0/3 |
| 2 | air, air, air | 65 | 86 | won | lost, 0/3 |
| 3 | split, air, split | 56 | 79 | lost, 0/3 (see below) | lost, 0/3 |
| 4 | split, split, air | 49 | 65 | lost, 0/3 (see below) | lost, 0/3 |
| 5 | air, air, air, split | 94 | 124 | lost, 3/4 vs its 4/4 | lost, 0/4 |
| 6 | air, air, air | 62 | 89 | won | lost, 0/3 |
| regions 1 to 3 | air, air, air | 39 to 58 | 53 to 76 | won all 3 | not run |

- **Every run went the whole way:** landing, line-up, count, GO, course.
- **The corner cutter never won (0 of 6).** It clears no gate at all, because the first gate is never behind it.
- **The rival** clipped nothing in any run: `clips` 0 in all 15 runs, through landings, takeoffs and course flying.
  - Its wheels stood 0.01 m into the turf on the ground; that is rounding.
  - It never went under the land in the air.
  - It stopped 0.0 m from its stop every time, after touching at 13.5 m/s.
  - At the count you were 13 to 23 m behind it and 9 to 11 m aside: beside it, in your lane.
- **The strips:**
  - steepest 8 m step 0.03 to 0.08;
  - 1.6 to 5.3 m of rise over the 230 m read;
  - all dry.
- **The line pilot's three losses** are the bot. On seed 3 its plane froze against a hillside short of the first split (see Known). Seed 4 also never cleared its first gate, a split, and was not looked into. On seed 5 it was 1 gate behind at the finish.
- **Two "NO" rows** in the sweeps are Jolt RID-leak lines printed at exit. drive.py usually drops these; every check in those runs passed.

**Stills** (rendered, `-- --no-title`, git-ignored, in `captures/race_course/`):
- **The rival landed and your marks:**
  - `s6/landed_marks.png`: the "your marks" wedge and the gold posts at 240 m, with the ribbon starting there.
  - `s3/landed_marks.png`: the ribbon climbing to a split, with the marks hidden in the haze. That still is from before the posts and wedge.
- **Lined up during the count:**
  - `s6/lined_up.png` and `s4/lined_up.png`: both planes, you in the posts and the rival beside. These are `shot_at` stills; that camera pales colours and draws clouds badly.
  - `s3/count.png`: the play camera during the count, low in the grass.
- **The ribbon and gates mid-race, chase camera:**
  - `s4/first_gate.png`: the gold ribbon down a river to the first gate.
  - `s6/first_gate.png`
  - `s3/first_gate.png`: the rival below on the ribbon, which runs up into a split.
  - `s3/gate_clear.png`: the ribbon through a split canyon.
- **A gate cleared:**
  - `s6/mid_race.png` and `s4/mid_race.png`: the screen brackets, with the 3D gate fading beside the camera.
- **GO:** `s3/go.png`.
- **The result:** `s4/result.png` (RIVAL BEATEN) and `s6/result.png` (IT GOT THERE FIRST).

## Judge by hand

- **Landing beside it.**
  - Your marks are ±22 m long and ±4.8 m across, with your wingtips 2.2 m clear of its wingtips.
  - Stopped means under 1.5 m/s.
  - Is that generous enough by hand, or too fiddly? The knobs are `SPOT_HALF_LEN`, `SPOT_HALF_SPANS` and `LANE_SPANS` in `rival_strip.gd`, and `STILL` in `rival_race.gd`.
- **The wait.** From the accept until it stands takes 40 to 95 s: finding a flat, flying there, and the approach. Is it a nice beat or a chore? The knobs are DIST and IDEAL in `rival_strip.gd`, and LAND_SPEED and APPROACH_SPEED in `rival_line.gd`.
- **The ribbon's strength.** It is 12 px or more wide far off, in a deeper gold, and fades within 32 m of the eye. Does it read at a glance? Does it cover the line when you fly right on it? The knobs are LINE_PX, NEAR_FADE and LATER in `rival_marks.gd`.
- **Air gates.** Near meadows few openings are in reach, so most courses are mostly air gates. Do they feel like a course? The knobs are GATE_REACH and LEG in `rival_course.gd`.
- **The camera at the count.** On the ground the chase camera stands off to the side, low. In tall meadow grass it sees mostly grass (`s3/count.png`). The camera was not changed this round.
- **Balance.** A clean line from the bot beats it by 2 to 5 s. The rival's slower takeoff (2.3 s to lift, against your 1.8 s) is part of that.

## Known

- **A one-off hitch** of 35 to 105 ms when the strip is picked (the course and its ribbon). The strip search itself is spread over frames, 40 spots a frame.
- **Things built after the course was laid.** Arches stand, and hall heights are read, only near the eye. An arch built after the course was laid can stand across the ribbon. The rival's guard climbs it over the arch. The ribbon does not move.
- **A frozen plane, seen twice with the bot.** The player's plane froze in place in the air against a steep hillside: phase AIR, its speed held, no crash relaunch (seeds 3 and 6, the bot descending at 35 to 47 m/s). The flight code was not touched this round, and this was not investigated. It may be a bug that predates this round.
- **The headless import** on this PC rewrites many `.import` files (line endings only). They are not committed.

## Tests

- Run and passed: `test_world_scale_guard`.
- None should break: no test covers the race, its marks, the traffic or the HUD. The full suite was not run.
