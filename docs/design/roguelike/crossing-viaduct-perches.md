# Broken Viaduct: perches (routes out, slam to silence, low perches)

Branch `feature/viaduct-perches`, cut from `feature/viaduct-heights` (492b5243). Not merged.
The skill line is unchanged: the beats, gaps and rises are the same.

## Run it

    ./run-crossing-yard.command --beat=2        # start at the piers
    godot --path . res://studies/crossing_yard.tscn -- --no-title [--beat=n] [--arrows=0]

Keys are as before: **R** start rim · **1-5** beats · **K** arrows on/off · **N** next crossing.
New in play:

- **Out to a horn:** run off the departure, Space to jump, Space again to open the sail, and
  Space over the first stone to fold the sail and drop onto it.
- **The slam:** hop off the last stone toward the perch, then Shift/C in the air once you're
  over its top.

A toast reads "Slammed the horn: silenced for 8 s". The foot card has a hint line.

## Why the far perch didn't fire, and the fix

Measured headless: placed and standing on piers 6-10, the old far perch did fire. In play it
lost on two counts:

1. **Turns.** Launchers took turns, but the left perch was checked first every frame, and its
   zone covered the whole field. So it took almost every turn. A player pumping through the
   last piers was usually shoved or thrown by the left perch before the far perch's one-second
   window opened.
2. **Zone.** The far perch's zone left out the safe stair. On the stair beside the later piers
   it never fired, though it stood about 16 m away, which reads as "out of its range".

The fix (`gust_arrows.gd step`, `crossing_viaduct.gd`):

- **Fair turns.** Of the launchers that are ready, the one that has waited longest winds up
  first.
- **Zones split.** The left perch fires only up to `ARCHER_TO` 0.7 of the way to the plinth.
  Piers 8-10 belong to the far perch alone.
- **Stair in the far zone.** The far zone (`on_far_piers`) now takes in the stair from 45% on.
  The stair is covered only from the left now.
- **Moved.** The far perch now stands at the end of its route: along about 25, about 20 right
  of the piers, mouth at y 4.5 local. Its shots burst on him at piers 8 and 10 (tested).

## The perches and their routes

Each perch is a dark column. Its top is `PERCH_TOP` 3.2 m square and you can stand on it. The
horn sits on the top, `HORN_BACK` 0.9 m back from the middle. A route is built by `_route()`
from walker numbers:

1. **The sail gap.** From the departure's edge to the first stone is `sail_gap` 7.38 m: the
   plain long jump's reach (5.88 at the `ROUTE_DROP` 1.5 m drop) plus `SAIL_SPARE` 1.5. The
   sail's cautious reach is 9.62 m (asserted). A jump can't make it; a jump plus the sail can.
2. **Three stones, `STEP_GAP` 1.4 m apart** (a running hop):
   - a plain bobbing stone (`BobSlab`);
   - a **sinking stone**, the new `scripts/interactables/sink_slab.gd`: after 0.25 s stood on
     it sinks 0.7 m/s, down to 6 m, and rises back 1.2 m/s once left;
   - a plain stone.
3. **The perch's top.** It is `slam_over` 3.3 m under the last stone (the slam's `LOW` 1.8 plus
   a pump's height), and `PERCH_STEP` 0.6 m out from it.
4. **The way back.** An updraft (`PERCH_DRAFT_RADIUS` 4.5) stands just past each routed perch.
   Its top is set so a ridden sail glides back to the departure.

| Perch | Launcher | Route |
|---|---|---|
| left | 0 | off pier 4, 70° left of the piers |
| far | 1 | off the slot's plinth, 125° right (back down the field) |
| deck | 2 | no route (it sits beside the run-up; the deck's parapets are in the way) |
| low (3) | 3-5 | none: they hang in the void |

The stones are foot pieces. The yard builds them from `crossing.foot_stones()` in
`_build_stones`, so they bob and carry him. A perch also fires at you on its own route
(`on_route`): the detour is under fire. The balls fly through the route stones
(`DragonAirBlast.see_through`, empty by default, so the dragon is unchanged). Without that, the
stones shielded the line each perch guards: the left perch's shots popped right at its mouth.

## Slam to silence

- **The rule.** A slam whose touch lands on a perch's top disables it for
  `GustArrows.DISABLE_TIME` = **8 s**. "On its top" means within `SLAM_UP` 0.6 of the top's
  height and inside its half size plus `SLAM_EDGE` 0.3.
- **While it's down:** no tell, no shot, and any wind-up is cancelled. The horn tips over onto
  its bell and its orange bell turns grey. Balls already in flight fly on.
- **Coming back:** it rights itself over 0.6 s, then takes turns again.
- **How it's wired.** Each launcher joins the slam's group (`scripts/slam.gd GROUP`) and answers
  `slam(at, radius, strength)`.

The knob is `DISABLE_TIME` in `studies/crossings/gust_arrows.gd`.

## Low perches

`LOW_PERCHES` lists three, 18-32 m under the turn platform: left of the piers, right past the
stair, and back by the run-up.

- **When they fire:** only at a pilot in the air (`airborne`), meaning falling or under the
  sail. Not while he tumbles, hangs from a ledge, or rides an updraft (the swirl is shelter;
  the glide to it is what they guard).
- **Where:** only when he is `ROUTE_CLEAR` 3 m below the turn platform or lower, and within
  `LOW_REACH` 30 m of the perch's height.
- **Pacing:** they lead him (`LOW_LEAD` 0.6, since a sail flies steady and turning is the
  counter), cool down slower (`LOW_COOLDOWN` 3 s), reach less far (`LOW_RANGE` 45), and take
  turns with all the others (`TURN_GAP`).
- **A hit on a sailing pilot:** gust_arrows' air hit calls `motor.knock`, whose `_knock` already
  rests the sail. So the hit throws him out of the sail into a tumble. After `KNOCK_SAIL`
  0.35 s, Space opens the sail again. **No motor change** was needed.

## The horn stand-in and the one-line swap

`studies/crossings/horn_stand_in.gd` is a box head on a squat base:

- **Nodes:** `Head` (turns to face him) and `Mouth` (a `Marker3D` under the head, where the
  ball leaves).
- **Methods:**
  - `aim_at(world_point, delta)`: turns toward him;
  - `tell(share)`: shudders;
  - `fired()`: kicks back;
  - `disabled(seconds)`: tips over;
  - `is_disabled()`.
- **No collider:** you stand on the column's top.

The launcher reads the ball's start from the `Mouth` marker. It keeps its own down timer, so it
doesn't depend on the horn's timer.

The swap is in `crossing_viaduct.gd perch_piece()`:

    return RuinKitHorn.wind_horn(seed_value,weathered)

Also add `const RuinKitHorn = preload("res://scripts/ruin_kit_horn.gd")`. Unchecked: the real
horn's mouth height and footprint. If it has a collider bigger than the stand-in's head, check
that there's still room on the top to land.

## Verified

**Headless**, `tests/test_crossing_viaduct_perches.gd`: 0 failures. It runs the yard's own
`_process` frames, driven by Input actions:

- The far perch fires, and its ball reaches him, on piers 8 and 10. It also fires at him on
  the stair beside pier 9.
- Off pier 4, he runs, jumps, opens the sail and folds it over the first stone, landing on it.
- He hops onto the sinking stone. It sinks 0.40 m in 0.75 s, and his feet go down 0.52 m with
  it. A hop still makes the last stone, and the sinking stone rises back once left.
- A hop off the last stone and Shift/C at 3.1 m over the top: he slams onto the left perch.
  It is down 8 s with its horn tipped, and the yard gets "silenced".
- On pier 2 in its zone through those 8 s: no tell and no shot. It fires again 0.8 s after it's
  back.
- Under the sail off the left of the piers, the first low perch fires and hits him. He is
  thrown out of the sail into a tumble, and after 0.45 s Space opens the sail again.
- Standing on the turn platform, no low perch fires.

Also run:

- `test_crossing_viaduct.gd`: 0 failures.
- `test_crossing_viaduct_arrows.gd`: 0 failures. Its standing-on-pier-5 shove now comes from
  the far perch.
- `test_crossing_viaduct_heights.gd`: 0 failures. This was only after the updraft-shelter rule:
  before it, a low perch knocked him out of the sail as he entered the right updraft, and the
  test doesn't press Space again.
- Load check (`--quit-after 300`): no errors. The exit report now lists about 880 leaked
  objects (it was 9). That comes from loading `scripts/interactables/foot_pieces.gd` in this
  yard: the same happens with the baseline foot_pieces and without the sinking stone. It is an
  exit-time script-reference report, not a runtime leak, and I didn't chase it.

**In the window** (forward_plus, `-- --no-title`): the same script with captures
(`captures/viaduct_perches/drive.gd`, throwaway, gitignored). Everything played out. One
check failed there: the "down 8 s" time. The driver counts frames at 1/60 s while the window
ran slower; there were 0 tells and 0 shots. Captures are in `captures/viaduct_perches/`:

- `1_route_from_pier4.png`: the three stones out to the left perch's column;
- `2_sailing_to_first_stone.png`, `3_on_first_stone.png`, `4_on_sinking_stone_sunk.png`;
- `5_last_stone_horn_below.png`;
- `6_slam_touch.png`, `7_horn_tipped_over.png`: with the "silenced for 8 s" toast;
- `8_horn_down_seen_from_pier2.png`, `9_horn_back_telling.png`;
- `10_low_perch_tell.png`, `11_ball_at_glider_a.png` / `_b.png`: the ball streaking at him
  under the sail;
- `12_hit_out_of_sail.png`, `12_tumbling.png`, `13_sail_again.png`.

## Not verified / open

- **Feel at human timing:**
  - Is the 7.4 m sail gap readable?
  - Is the sinking rate too mean?
  - Is 8 s worth the detour? The way back is the perch's updraft: a ride, then a glide back to
    the departure, so a silenced left perch buys perhaps the second half of the piers.
- The far route and both perch updrafts are not ridden or walked in any test. Only the left
  route is. The far route is built by the same function.
- The deck perch has no route, and its shots over the parapets are still untested.
- From the piers, a tipped horn is small at 20+ m. A bigger "down" cue may be needed.
- The low perches' placement is a first guess. Only one low perch's hit is tested.
