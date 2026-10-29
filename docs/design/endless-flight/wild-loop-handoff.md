# Handoff: the wilderness loop (`wild-loop`, 2026-10-28)

Spec: `spec-wild-loop.md`. Branch `claude/wilderness-gameplay-combos-a07806`,
the trail `git log --grep='^ITER(wild-loop)'`. Not merged into main.

## Play it

`.\run-endless-flight.cmd` (or `python tools/play.py`) from this branch's
worktree. The wilderness is the default; `--world=amberlands` works too.
Your book is kept at `user://pilot.json` (it holds `{"flights": 14}` from
early agent runs, before drivers stopped writing it; delete it to start
clean). `--pilot=fresh` flies with an empty book that is never written.

## What's built

- **Lines read moves.** A line earns named moves: late pull, knife edge,
  inverted, carve, canopy run, canyon run, climb, surf, slalom, stack
  orbit, plus the near misses. The multiplier is how hard each move was.
  A repeat is worth less, a new kind the most. The chain caps at x12. At
  bank the tag reads the line back on a dark plate: its moves, the land
  crossed and, for a rich line, a name. A banked line pays money:
  points/1600 x sqrt(mult), at least 1.
  Files: `scripts/endless/line_moves.gd`, `near_miss.gd`,
  `near_miss_hud_handoff.gd`.
- **Landing summary.** Coming to rest shows the flight's card: time and
  distance aloft, best line, money, tallies, the route's result, new
  records. It goes at take-off.
  Files: `landing_summary.gd`, `pilot_tallies.gd`.
- **Logbook (J).** Every tally, record and find over all flights, plus
  money. `logbook_view.gd`.
- **Beat routes.** Starters stand in the land with a crown. Fly through
  one along its way and a pan previews the route; any key skips it. Then
  the beats come one at a time, each flashing and gone if you're late. The
  last is a landing at the lit strip by the finish. Pay: 2 a beat, 6 the
  finish, 1 per 15 s spare. `--beats=0` turns the routes off.
  Files: `beat_routes.gd`, `beat_marks.gd`, `beat_pan.gd`.
- **Shop.** A shop beside a strip; the first is near the start. Stop on
  its strip and the overlay opens: 7 paints and 5 ribbons to buy and
  wear. What you wear is kept.
  Files: `shop_sites.gd`, `shop_view.gd`, `shop_stock.gd`.
- **Photo mode (O).** Holds the flight and gives a free camera with the
  HUD hidden; it saves stills to `user://photos/`. `photo_mode.gd`.
- **The book.** `pilot_book.gd`: money, tallies, records, finds, owned and
  worn items, this flight.

## Frame rate

Two regressions in this round, both fixed and measured in a real window,
real time, 1440x900:

- **The beat planner** (trunk 2, da0a9f3e). It took up to 33 ms a frame
  while it planned; now about 2 ms.
- **The cloud tally** (e73a475c). It sank a flight from 26 to 3.6 fps over
  two minutes; this is what made play feel awful. Now 115-182 fps in the
  wilderness over 2 min and 118-181 in the Amberlands, against 140-195
  before the round.

Neither has been measured on low-end hardware.

## Stood in

- Line names (Fine, Bold, Wild, Legend Line) and the grass-blade count are
  placeholders.
- The shop is a simple building. The stock is paints and ribbons only.
- No new sounds: the loop uses the existing ones.

## Open

- **Flaps stay down after take-off.** Land with flaps, take off, and the
  plane crawls until F is pressed. This is existing flap behaviour, but
  the loop's landings make players hit it.
- **One easy late pull out of a dive scored 19,795.** Its line (x5.4) paid
  178, nearly the dearest paint, in the first 75 s. The pay has no bound
  per line.
- **A shop landing ends the flight.** The route's summary then misses the
  lines flown before it.
- **No driver has flown these moves:** slalom, canopy run, canyon, climb,
  surf, stack orbit, knife edge, inverted.
- The rival race was never driven to GO.
- Photo mode doesn't hold shader time.
- The hint line is too long for the window.
- The pan's beats aren't numbered.
- **Smoke flake.** One Amberlands smoke in about 10 failed: "unimplemented
  base type encountered in renderer scene cull". Not reproduced.
- **Memory in the Amberlands** climbs with the streamed land: 1.2 to 1.9 GB
  in 60 s. Not measured over a long flight.
- **No stills** of the shop overlay, the pan, a beat, the finish or the
  summary: the rendered loop runs were too slow, because of the cloud
  tally.
- **Prototype only.** No committed tests. The drivers are in `scratch/`
  (`loop_drive.gd`, `perf_mem.gd`, `cloud_same.gd`, `plan_cost.gd`).
