# Pirate ship gray box: handoff

## Two ships

Two sail at once (`CoastSites.ships`), each a whole PirateShip. `coast.ship` is still the
first, the one with the ring. No more than two, and the first's route is unchanged.

- **The second route:** middle (3500, 4700), handles `coast/ship2` and
  `coast/ship2-route`. It's the deep basin south-east of the first, past the isles
  off the Horn. The first's 1300 m oval doesn't fit there in deep water (17 m at best,
  and 380 m from her route), so this one has straights of 500 m and is turned 45
  degrees (`ROUTE2_LEG`, `ROUTE2_TURN`). Under the hull: at least 27 m, against the
  first's 43.5 m. No point of either route is inside rock, arch, hall or tunnel. The
  farthest it gets from the start is 6.3 km.
- **Spacing:** they start 1840 m apart. Their laps differ, so it drifts: 665 to 2715 m,
  1 to 2 km for 64% of the time. The routes never come within 664 m, so guns (520 m) can
  overlap only for a plane between them at the closest. Reaching the second from the
  first took the bot 32 s, but that run crashed three times: see Unproved.
- **The ring:** `carries()` also asks that the row is anchored to her `handle`, so the
  second never has one, and pays `SINK_POINTS`.
- **The return:** the same rule each, and no spot within `RETURN_APART` 1050 m of the
  other ship, unless she's gone.
- **Per ship:** guns, balls and `BALLS` (24 each; a ball only ever meets the plane or
  the sea), plates, sink, return. Glance, wreck solids and camera `_solid` go through
  `CoastSites` (`deck_way_off`, `ground`, `inside`, `in_wreck`).
- **Picked by `CoastSites`:** `skim_scale` is the most either ship gives (`skim`).
  The eye is the newest sink's (`wants_eye`); an older sink lets go for good
  (`give_up_eye`), and the eye eases across.
- **`--full-meter`:** also refills once when the plane is `RESEAL_FAR` off a sinking
  ship, since her plates don't come back for the next ship's run.
- **Flags:** `--ship-start` is by the first, `--no-ship` drops both, `--ship-return`
  and `--ship-blocks` apply to both. New: `--one-ship` drops the second, for cost pairs.
- **Shared:** the glb's meshes, the ball, smoke, flash, puff and mist meshes, the plank
  material (`twin`). `--ship-blocks` builds its own blocks and materials per ship, as
  it's only for comparing.
- **Without `--full-meter`:** the bot reached the second on 0.41 of a meter, because
  the surge drains on after the first. Its meter was topped up by hand, so a second
  run straight after a ring run needs charging on the way.

**What it costs**, two ships against `--one-ship`. Provisional: load was 3 to 8, and
this is two pairs of the three, with one sink pair. Counts settle most of it. From the
start she adds nothing. A sight of her at about 2 km adds 20 to 50 draws, and 40 to 80
in `both_view`. Over her at about 120 m, where `far2k_away` happens to sit now, she adds
290 draws and 200k primitives. Her script adds about 10 us a frame when far. Medians
moved by less than the run-to-run noise (0.1 to 1.0 ms up in most pairs, down in some).
A quiet timing has to settle `near300_guns` (+1.0 and -0.8 ms) and `far2k_away` p95.

**Proved** on Mac by bots on real input (`scratch/ship_two.gd`, `scratch/ship_sea.gd`,
not committed): sink the first with the ring (no points), fly to the second, sink her
(25,000 on her alone), both back after 60 s (1414 and 1100 m off the plane, out of view,
2.7 and 2.6 km from each other), no ring mark, then the returned first pays. The eye
framed the right ship on 92% and 96% of settled frames, and never both. Two sinks
overlapping: the newest took the eye, no tug, and it came home. Each ship's guns
fired alone. Near either the skim rate held x8. `ship_wall.gd --second` passes on her.
All of it without a rendered look: there is no still of both ships.

Bots changed for two ships: `ship_wall.gd` gained `--second`; `ship_cost.gd` steps both
and has a `both_view` case; `cost_runs.sh` pairs two against `--one-ship`. `ship_sink.gd`,
`ship_model.gd` and `ship.gd` needed no change.

**Unproved:** a clean flight between them. The bot held 30 m over the sea on a straight
line and crashed three times on the isle at about (3050 to 3110, 4120 to 4160), which
stands 56 m or more over the sea, right on that line. So whether the second can be seen
from the first's sink is open too: the isle may hide her, and no still was taken. Hand
flying any of it. The third cost pair. Spacing after more than one return. A
`coast/ship` delete in a layout with the second kept. No PC number.

## The sink, the return, the cost

Both plates open with no ring aboard sinks her: the ring taken, or a ship with no
ring. A miss leaves her to reseal. All knobs are at the top of `pirate_ship.gd`.

- **The sink:** she lurches, settles by the end broken last, lists away from the
  plane, then plunges (`SINK_KEYS`). Under in about 20 s. Foam, mist, planks, a gong
  and the finds toast; guns stop, balls in flight finish, no reseal.
- **Solids:** the flat `loose` record comes off. `wreck_ground`, `wreck_inside` and the
  StaticBody follow her true tilt, and any touch of her is a glance, never a crash,
  including the water right beside her and never pushing the plane down.
  A plane in the gun deck when it floods is let go (`_ghost`: her solids go off).
- **The return:** `RETURN_S` 60 s after she's gone (`--ship-return=S`), then every
  0.5 s the farthest of 24 route spots that is 600 m off the plane and eye and outside
  the view (cosine 0.17 off its axis), or 4 km off anywhere.
- **The ring:** `carries()` reads the book, so a reload with it found is a ship with
  no ring. A ring taken on an earlier run of the same ship counts as no ring: she pays.
- **Points:** `SINK_POINTS` 25,000 for a ship with no ring, 4 s into the sink, through
  `NearMiss.prize`: a line of its own named "Ship sunk", no multiplier, not lost to a
  scrape, left out of the best-line records. With the corridor's own 15,000 a pass
  banks about 40,000. Either alone fills the 4000 meter; the ring ship pays no points.
- **The eye (`watch`):** from 1 s into a sink the free look eases round so she's in
  frame past the plane, and the flight controls still fly it. The right stick (or
  right mouse held) pans; letting go hands the chase camera back after its usual
  2.5 s linger, for the rest of that sink. So does the sink's end, 1300 m off, or land
  or sea coming up on the plane's way. `free_to` and `free_ease` stay at their defaults
  outside a sink.
- **Flags:** `--ship-return=S`, and `--no-ship` for the cost pairs.

**What it costs.** Timings are provisional: another session was running on this Mac.
Window 1440x900, vsync off, three alternating present/absent runs before the range cut
below, median ms (each run), ship present / absent:

| Case | Present | Absent | Her draws (toggled) |
|---|---|---|---|
| Start meadow | 16.0, 18.3, 15.8 | 16.6, 15.7, 18.4 | none |
| 2 km, looking at her | 14.3, 15.1, 15.0 | 15.1, 15.0, 15.2 | 108, now 45 |
| 2 km, facing away | 14.3, 14.4, 14.3 | 14.3, 14.2, 14.2 | none |
| 300 m, guns | 13.6, 14.8, 15.2 | 15.2, 14.8, 15.2 | 328 in view |
| Gun deck, at speed | 6.1, 5.9, 6.0 | 14.4, 14.4, 14.4 | not like for like |
| Sink, 300 m | 13.7, 13.8, 13.9 | 13.9, 13.7, 13.8 | +298 on the frame |

Every present/absent difference is inside the noise, except the gun deck, where her
walls hide the land, so that pair says nothing about her cost. The decision rests on
counts. She draws nothing out of view. Her script is about 10 to 15 us a frame afloat
and far, about 0.2 ms near with guns, about 0.7 ms in a sink. Physics stays near
0.05 ms. Only one count was worth acting on: 108 draw calls at 2 km on a ship that
small. `INNER_FAR` 700 m cuts the gun deck's inside, its guns and the plate shards:
108 to 45 draws, 23k to 2k primitives at 2 km, and no change at 120 m or 300 m. No
script gating: there was nothing to gain.

**Several ships** (throwaway extra ships, stepped by the driver): each in view at
300 m adds about 330 draws and 125k primitives. Out of view each adds no draws and
about 15 us of script. 1, 2 and 4 ships at 300 m: 477, 683, 969 draws. Medians stayed
at about 14.5 ms, inside the noise. Two look affordable, and four should be while
they're spread out. Four together in view need a quiet-machine timing.

To rerun on a quiet machine: `zsh scratch/cost_runs.sh quiet`, then read
`/tmp/ship_cost_quiet.txt`. `scratch/` isn't committed.

**Proved** on Mac by bots on real input (`scratch/ship_sink.gd`, not committed): ring
run sinks her, no crash on her, guns stop; she returns unseen (2.3 km off, behind the
eye) with no ring; a bare run pays 25,000 once and she sinks again; reload with the find
saved has no ring and pays; flying at her at 3 to 16 s (gun deck, beam, over the top,
raised end) never crashes or sticks; a right-stick pan moved the eye 1.9 rad, the eye
came home clean, no crash, 89% of unpanned frames with her in view. `ship_model.gd
--part=fly` now waits for the return between passes; `ship_wall.gd` and `ship.gd
--part=block` are unchanged.

Stills: `pirate-ship-stills/22_sink_15s.jpg`, `23_sink_20s.jpg`.

**Unproved:** hand flying through all of it. Looking back while framed, the check on
the plane's way reads only its straight line, so a cliff alongside isn't seen: the bot
passed close by the Rock in one pan. **A real miss:** the ring's capture is 9 m
round the middle of an 18 by 10 m deck, and the bot couldn't fly past it, so the miss was
proved with the ring lifted out of the way, not by flying. Sound levels are unheard. The
eye swinging round from a low skim. No PC number.

## Model in

`assets/models/pirate_ship.glb` now sails on the moving ship. `--ship-blocks`
brings the gray box back to compare. `solids()`, flight, gun and meter tuning are
unchanged: the bot's flight trace through the corridor is the same to the digit
with either look.

- **Guns and relic:** the 12 muzzles are read off the `Gun_*` empties, and match
  the gray box's numbers exactly. `Relic` sits at the deck's middle, on the finds
  row. Flash and smoke are still the gray box's cubes.
- **The break:** a burst throws the plate's `CrackPlug_*` shards with
  `SmashBreaks`' numbers (`KEEP`, `OUT`, `UP_V`, `SPIN`): on ahead of the plane,
  out from its line. Hit from outside, they go down the gun deck, stay between its
  walls and lie on the floor. Hit from inside, they go out to sea. They are drawn
  only and stay under their plug in her frame. The reseal puts them back whole.
  Knobs: `SHARD_*` at the top of `pirate_ship.gd`.
- **Rigging:** `visibility_range_end` 450 m, set in code.
- **Sway:** a roll of 0.8 degrees over 9 s and a pitch of 0.3 degrees over 13 s,
  on the model only (`SWAY`, `SWAY_S`). So the look drifts from the solids by up
  to about 0.3 m at her ends; nothing in play reads it.
- **Proved** by a bot on real input (`fly_boost`, `fly_roll`, `scratch/ship_model.gd`,
  not committed): stern to bow, bow to stern, then stern to bow again, each after
  a reseal on its own at about 301 m. Six bursts, no crash, relic counted. Stills
  looked at: approach, burst, gun deck, bow exit, from outside.
- **Frame time** (Mac window, 1440x900, vsync off), model against blocks, median
  ms: 16.0 / 14.8 at 180 m off the stern, 21.1 / 19.9 inside, so about 1.2 ms.
  p95 inside is about 31 ms with either look. No full-screen or PC number.
- **Unproved:** hand flying, shards and sway in motion (stills only), a shard
  passing near the camera at speed. At the ship start she is off the plane's left
  wing, so she isn't in the first view.

## What was built

`scripts/endless/pirate_ship.gd`: a block ship on an oval over the deep water
west of the Horn. She replaces the moored boat. Broadside guns fire at the
plane. A surge roll breaks the crack in the stern (or the bow), and the plane
flies the 110 m gun deck, takes the relic and bursts out of the other end. Seed
1, medium weight.

## Launch

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/pirate-ship-greybox && python3 tools/play.py --no-pull -- --no-title --fresh --ship-start --full-meter
```

Drop `--full-meter` to charge the meter yourself. `--fresh` is the throwaway
save: this branch has no `--ledger=` flag. The plane starts 240 m off her beam,
16 m up, flying her way, already under fire. Her stern is behind her direction
of travel; both ends break.

## Knobs

- `scripts/endless/pirate_ship.gd`, top of file: route (`ROUTE_AT`, `ROUTE_LEG`,
  `ROUTE_R`, `SPEED` 9 m/s), gun deck (`TOY_WIDE` 8, `TOY_HIGH` 5, `LONG` 110),
  guns (`RANGE` 60 to 520 m, `ARC` 1.05 rad off abeam, `EVERY` 1.15 s, `TELL`
  0.85 s, `REST` 3 s), balls (`BALL_SPEED` 110 m/s, `BALL_DROP`, `BALL_R`,
  `BALLS` 24), near miss reach (`PASS_REACH` 14 m), a hit (`HIT_KEEP`,
  `HIT_SHOVE`, `HIT_YAW`), skim (`SKIM_SCALE` x8 within `SKIM_NEAR` 500 m),
  `RESEAL_FAR` 300 m.
- `scripts/endless/near_miss.gd`: a ball's pass scores as a `graze` with base 200
  (`BASE`), through `shot_pass`. The bank-on-full rule is at `# The bank:`.

## What I chose where the brief left it open

- **Moving solid:** three records in `LandArches.loose` (hull, stern, bow) whose
  `pos`, `cos` and `sin` are rewritten each frame. `plane_ground`, `_blocked`,
  the camera and the surge's `_strike` all read her without new code. A StaticBody
  under the ship serves the wing rays. The plane is never carried or pushed.
- **Replay:** both plates come back when the plane is 300 m from her. Nothing is
  saved. With `--full-meter` the meter refills at that moment.
- **Which end:** both plates break, so she can be entered at either end. The
  other plate stays stone, and the surge is held hot while the plane is in the
  corridor (`keep_hot`), so it breaks on the way out.
- **Corridor:** 18 m wide by 10 m high (toy 9 by 5, against a cracked room's 14
  by 9).
- **Balls in a surge:** a ball that reaches the plane while the surge is hot does
  nothing.
- **Guns:** they fire only within about 60 degrees of abeam, so her ends are safe.
- **Bank on full:** applies everywhere in the game, not only near her. It banks
  when meter + chain x multiplier reaches full, and doesn't re-bank on a full meter.
- **`boat-deck`:** now on Light Rock's south shelf at (2225, 3330), radius 90, and
  retitled. The id is unchanged. The new row is `ship-hold`, so the table is 34 rows.
- **Sails** are drawn with no collision. The plane flies through them.
- **Removed:** the boat's model use, solids, deck and `deck_at`. `assets/models/boat.glb`
  stays.

## What's proved

Bot flying through real actions (`scratch/ship.gd`, not committed):

- Balls fire and lead, and a held line gets hit.
- A hit drops the chain and knocks the plane 0.3 rad off line. No crash; meter
  unchanged.
- Passes score. Bot dodges measured 3 m clear for about 800 points and 11 m for
  about 300. Nothing scores past 14 m clear.
- The meter banks at once mid-skim.
- `fly_roll` on a full meter breaks both plates on the moving ship: 2.25 s inside,
  relic counted, no crash.
- The burst held at offsets to x 6 m and y 5 to 11 m (y is over the waterline; the
  deck's middle is 8). Runs at y 5 scraped the floor two or three times and still
  got through.
- It also works while she turns (x 3 m, from 300 m back) and entering head on at
  the bow, out at the stern.
- The plates came back on their own at 302 m, `--full-meter` refilled, and a second
  burst flew clean.
- At 57 m/s without a surge the crack is a crash, the plate stands, and the plane
  flies on from clear of the hull.
- The moved `boat-deck` was landed on and found.
- Smoke passes with and without the flags.
- Stills of the ship, crack, corridor, tell and ball were looked at.

## What's unproved

- **Hand flying.** The bot steers perfectly. Whether a person can dodge a ball,
  swing to the end of a moving ship and hit a 18 by 10 m plate at surge speed is
  for you to judge.
- **Ball speed and tell timing:** tuned by reasoning only.
- **Wheels on the deck:** one bot run scraped once and flew on, slowly, without
  sticking. Landing there isn't built.
- **A second lap of the route** and long runs: only the first turn was flown.
- The full suite was not run. `test_world_scale_guard.gd` passes.

## Worth knowing

- **The meter fills fast.** The bot filled it from three close passes in under 8 s.
- **One moment can nearly fill it.** Dropping to skim height banked 3,654 points
  in 0.6 s. The kind wasn't logged; it was probably a pull-out. That is existing
  scoring, now banked at once.
- **The corridor pays more than a full meter:** one run scored a thread and a
  "canyon run" inside and banked 14,879 points just past the bow, against 4,000 to
  fill. The meter stood at 0.93 straight after, so a burst nearly refills itself.
- **Finds grid:** a row anchored to the ship stays in the grid cell of her start;
  it streams correctly while she keeps within about 2 km of it, and the route does.

## Existing tests

No test in `tests/` touches the near-miss code, the finds table, the boat or the
coast by name (grep). I expect none to break, but the suite wasn't run.

## Tools

The harness lacked nothing. One trap for drivers: `study._launch` makes a new
plane object, so re-read `study.plane` after it and after a crash.

## Models

All blocks with no model, so the tricks in `docs/art/model-budget.md` don't apply
yet. The Blender round should assess them; silhouette geometry and vertex-colour
grime look like the likely ones.

## Contract for the model

Her frame: metres, origin at the waterline amidships, -z bow, +z stern, +x
starboard, y up. Values are at the default sizes; `solids()` in
`pirate_ship.gd` is the source. Corridor width and height come from
`WorldScale.opening`.

**Ship:** hull 24.75 m beam by 113 m long, draught 6 m, top deck at y 15. With the
stem, about 129 m overall.

**Gun deck (corridor):** x -9 to 9, y 3 to 13, z -55 to 55. Keep it clear; visible
guns and lamps inside must stay within 1 m of the walls. Middle at y 8.

**Cracks (breakable plates):** each 18 by 10 m, filling the corridor's end.
- Stern: x -9 to 9, y 3 to 13, z 55 to 56.5.
- Bow: x -9 to 9, y 3 to 13, z -56.5 to -55.

**Relic:** at (0, 8, 0), ring opening 10 m.

**Guns:** 12, six a side at z -40, -24, -8, 8, 24, 40. Muzzle at x ±15.375, y 8. They
fire outward.

**Collision boxes (x0, y0, z0 to x1, y1, z1):**

| Part | Box |
|---|---|
| Hull below the deck | -12.375, -6, -56.5 to 12.375, 3, 56.5 |
| Port wall | -12.375, 3, -56.5 to -9, 13, 56.5 |
| Starboard wall | 9, 3, -56.5 to 12.375, 13, 56.5 |
| Deck | -12.375, 13, -56.5 to 12.375, 15, 56.5 |
| Poop | -12.375, 15, 30 to 12.375, 24, 56.5 |
| Forecastle | -12.375, 15, -56.5 to 12.375, 20, -38 |
| Stem, inner | -9, -6, -64.5 to 9, 3, -56.5 |
| Stem, outer | -4.5, -6, -72.5 to 4.5, 3, -64.5 |
| Foremast | -1, 15, -23 to 1, 55, -21 |
| Mainmast | -1, 15, 5 to 1, 59, 7 |
| Mizzen | -1, 24, 41 to 1, 51, 43 |

The stem stays below y 3 so the bow's exit is clear. Anything the model adds
outside these boxes is look only unless it is added to `solids()`.
