# Spec: the first wilderness demo (`wilderness-demo`)

## What done looks like

The user boots the game fresh, tonight, and has something to complete and
to come back to.

1. `.\run-endless-flight.cmd --fresh` starts at the start meadow with a clean
   book. The saved `user://pilot.json` is left alone: `--fresh` plays on a
   separate save file, and keeps it between `--fresh` runs only if asked
   (`--fresh=keep`).
2. A world tally reads `0 / N`. The logbook has a Wilderness page: each area
   with its count, blanks for what's not found, one short hint for some.
3. About 30 finds of mixed kinds sit between the start and the Peak and along
   the nearest coast. One find is already in view from the start. From any
   find, another thing to go to is in view or a short flight off.
4. A ruin stands in the land, in sight of or close to the start. Fly in, and a
   ruined hall runs on longer than its outside can hold, then you come out of
   a tunnel into the Amberlands. A ruin there brings you back.
5. The coast has islands, a lighthouse and a boat, and they're worth the trip.
6. With a full meter the roll button is a surge roll: it breaks cracked walls
   and catches the burrower. Three standing lines keep a best time.

The test is the user's: finish one find, want the next, close the game with
blanks left to come back for.

## Rules for every agent

- Seed 1 only. Nothing past 8.5 km from the start (the world will be 17 km
  across). No bounds or world edge in this round.
- Medium weight; flown with and without Boost.
- Prototype round: smoke check, a light run through the real play loop,
  rendered stills of anything seen. No committed tests, no full suite, no bot
  sweeps or matrices. Say what's unproved.
- AGENTS.md holds: Handles (stable `<route>/<piece>` names), Sizes (ask
  `WorldScale`), RuinKit piece ids, Meadows and flats, Animation, Models.
- Fly-through places get margin for hand flying, not one exact line.
- Heavy per-frame or per-chunk work goes in C++ too; GDScript may stay as the
  fallback. If a C++ build isn't possible on this PC, say so in the commit.
- Art: weathered and gritty, no glowing portals, no clay-looking rock.
- Never kill a Godot process you didn't start.
- Out of scope: shops (leave them as they are), points for flying low, the
  Peak's ice lake door, things rising from the sea or sky, the Amberlands'
  content beyond its end of the door, other seeds.

## Lanes (parallel, one agent each)

Each keeps its code in new files and its edits to shared files small and
additive. Each ends its commit with **Notes for merge**, listing the shared
lines it touched. Each leaves one still or launch line to judge it by.

### Lane `roll`: the surge roll and smashing

- Remove the double-tap on lean. The roll button (Z, pad A, left click) stays.
- Below a full near-miss `meter`, the button is a quick clean roll. Fix how it
  looks; the sideways hop reads badly.
- With a full `meter`, it is the surge roll: the meter's existing surge, with
  a fast spin and a lunge the player can feel and see. Keep the surge's held
  button as a second way in. Show when it's ready, quietly, by the near-miss
  HUD.
- Connect `scripts/breaks/` to the game: during a surge roll, the plane breaks
  breakable ruin pieces and flies on. Outside a surge, contact works as today.
- A cracked wall a player can spot from the air, with a chamber behind it:
  placeable by a stable handle, signal `broken(name)`. Place two near the
  start as samples.
- A surge roll into the burrower's ridge during a run catches him. He stays
  unseen: the ground bursts, a prize rises, he dives. Signal `caught`.

### Lane `coast`: islands, a lighthouse, a boat

- First find the cheapest way to get islands off seed 1's nearest coast that
  the plane can fly round and land on: land that's part of the field, or
  rock-kit masses with collision and a beach. Existing land outside their
  footprints stays unchanged (`tools/land_hash.py --seed 1`).
- Three islands of different characters, at least one with a landable flat.
- A lighthouse that reads from far off, on a headland or island, with a
  turning beam; a new model through Blender.
- One boat, at rest or on a slow fixed route, with a deck you can land on; a
  new model through Blender.
- Handles under `coast/`. Report each spot and its landing flat in the Notes.

### Lane `hall`: the ruin door

- Replace the amber cloud wall on the default `doors` world with a ruin the
  player can aim at, handle `doors/amber-hall`, within 8.5 km of the start and
  visible from the start meadow or just past it. Read
  `docs/design/endless-flight/doors-handoff.md` first. The cloud wall's code
  stays behind a flag.
- The hall is built from the ruin kit, wide enough for hand flying at Boost.
  It runs 15 to 20 seconds of flight, far longer than the outside suggests,
  with the view ahead always continuing. The world swap happens out of sight
  inside it. You come out of a tunnel into the Amberlands; a glimpse of warm
  light ahead, growing, is the tell.
- A matching ruin in the Amberlands brings you back, into the wilderness ruin.
- Passing it stays a logbook find, as passing a door is today.

### Lane `finds`: finds, the tally, the ledger, the map

- A data table of finds, one file, per world: id, area, kind, named anchor or
  spot, optional hint. Built on `PilotBook.find` and `place_lines.gd`, so the
  saved book holds what's found.
- Kinds: `relic` (a small object you fly through, readable at speed, with a
  sound and a beat of reward; the name is a stand-in), `landing` (stop on a
  spot), `event` (fired by a signal, such as `broken` or `caught`), `line`
  (a place line with a best time). Streamed by distance; cheap with hundreds
  in the table.
- The world tally on the HUD: small, top corner, shown when it changes and
  when the logbook is open. Don't pull the eye off the land.
- The Wilderness page in the logbook, grouped by area, with blanks.
- `--fresh` as above; check it against the title flow.
- `tools/site_map.py`: a top-down picture of seed 1 for a given box, with every
  arch, hall, tunnel, split, sea stack, pond, Peak part, door and find marked
  and named. Output a map of the start-to-Peak patch and the nearest coast.
- Seed the table with five samples so it can be flown.

## The trunk (in order, once the lanes are merged)

Iterations run one at a time on the loop's branch, Opus, the skill's default
cap and budget. The lanes left these open; they come first:

0. **Finish what the lanes left.** Take rendered stills, and judge and fix: the
   surge roll, a wall breaking, how a crack reads from the air, the relic, the
   tally, the ledger. Make landing finds work on a real stop, and find out why
   the bot hovered 3.8 m above the Peak strip. Run `--fresh` and `--fresh=keep`
   through the title flow and check `user://pilot.json` stays untouched. A
   found cracked wall stays open after a reload (`mark_broken`). Trace the
   worst frame just after the hall's swap (193 ms). Check the door ruin reads
   from the start meadow, moving the belfries if it doesn't. The true start is
   (164.8, -32.4), facing the Peak.

1. **Place the finds.** Use the map to fill the table to about 30, tied to
   named sites: thread an arch, a relic deep in the door hall (seed 1's default
   land has no other halls or tunnels), on top of a sea stack, landings (an
   island, the boat, the Peak's ice lake, a flat that looks impossible),
   cracked walls with relics behind, the burrower catch. Mix easy ones for
   wanderers with ones that take skill. Add cracked walls where the land wants
   them. Rerun `tools/site_map.py` so the map shows them.
2. **Three standing lines** (`place_lines.gd` `LINES`): a gorge run, round the
   sea stacks, and a run over the land's arches. Each with a best time.
3. **The pull.** Fly the start through the real play loop. Fix spacing so a
   next thing is always in view. Add a landmark or a sightline where it goes
   dead. Make sure the door ruin and the first find read from the start.
4. **Polish.** Rendered stills of each area, the tally and the ledger; fix
   what reads wrong. Fresh boot end to end. Then finish.

## Smoke checks

- `python tools/smoke.py` on `studies/endless_flight.tscn`.
- A flight of a few minutes through `tools/drive.py` with no script errors.
