# Handoff: finds-more (80 finds, finds pay)

Branch `finds-more`. The wilderness table went from 44 rows to 80, and every
find now pays money once, the first time it is found.

## What changed

- `scripts/endless/finds_table.gd`: 36 new rows. Every old id and spot is
  unchanged. There are three new areas for the far land: `north` (The north
  downs), `east` (The east hills) and `west` (The west lands). AREAS is
  reordered so the logbook pages balance (meadow, north, coast, east, south,
  west, foothills, peak, amberlands). `pay` is documented in the header.
- `scripts/endless/cracked_walls.gd`: five new chambers in SITES.
- `scripts/endless/finds.gd`:
  - Pay: `PAY` by kind (relic 10, landing 10, line 30, event 40), `PAY_ROOM`
    40 for a ring in a chamber, and `pay_of(e)`. `complete()` calls
    `book.earn(pay_of(e))` only when `book.find` is true, so a find already in
    a book is never paid, now or later. Rows from other lanes pay by kind
    without any change.
  - Roof rule: a chamber ring is no longer taken by a pass over the roof.
    The ring's capture reach (9 m) is larger than the room, so a skim over
    the roof used to collect it (seen in the drive below). The rule applies
    to the old rooms too.
- `scripts/endless/finds_ledger.gd`: the old Wilderness page (`--logbook=old`
  / `--ui=old`) has four columns, 1340 px wide, so 80 rows read at full size.
  The default logbook (`ui/logbook_book.gd`) fits its own slots and needed
  no change.

The `amberlands` area belongs to the other world (`--world=doors`). The
wilderness has no land there, so no row was put in it.

## Counts

- **Kinds:** 64 relics, 11 landings, 4 lines, 1 event = 80. New: 26 relics
  (5 of them in chambers) and 5 landings.
- **Areas:** meadow 14, north 6, coast 20, east 5, south 9, west 5,
  foothills 10, peak 11.
- **Groups (new / old):**
  - plain sight: 11 / 17
  - off the path: 15 / 13
  - hidden: 10 / 9
  - The 4 lines and 1 event are outside the groups.
- **New plain sight:** ridge-ring, far-stack, pond-ring, south-field,
  serac-ring, low-hole, downs-ring, downs-flat, east-stack, west-arch,
  west-flat.
- **New off the path:** scarp-field, ridge-arch, shore-arch, south-stack,
  south-ravine, valley-head, spur-ring, bench-eye, boulder-ring, north-stack,
  north-arch, north-split, east-arch, east-flat, west-vale.
- **New hidden:** gully-ring, fold-ring, sill-eye, east-split, west-split,
  and the rooms scarp-room, shelf-room, downs-room, shore-room,
  gorge-mouth-room.

## Pay

Plain sight pays 10, off the path 20, hidden 40 (a chamber ring 40 by
default), a line finished once 30, and the burrower catch 40. Decent flying
earns 5-7 a minute, so a hidden find is worth about 6 minutes of flying and
a plain one about 1.5 minutes. All 80 pay **1760** together: 28 x 10,
28 x 20, 20 x 40, 4 x 30.

## New chambers

Each chamber is a SITES row, built on a worker within 2400 m, with three
solid boxes plus two wall boxes. Five more add five worker builds and their
solids as you fly near. Nothing was measured.

| handle | at (x, z) | yaw | setting |
|---|---|---|---|
| `cracked/south-scarp` | -1130, 2800 | 2.356 | foot of a 60 m scarp, south |
| `cracked/high-shelf` | -1870, -1630 | 4.32 | high ground, 430 m up, on the Peak's north flank |
| `cracked/north-downs` | 710, -2990 | 0.785 | the north downs, 51 m up |
| `cracked/east-shore` | 3290, 430 | 2.749 | the east bay's shore |
| `cracked/west-gorge` | -5476, 2408 | 1.571 | a gorge's mouth under 120 m walls, far west |

Each footprint was searched for the flattest spot within 150 m (worst height
off the front: 0.1 to 2.6 m).

## Checks (run, throwaway, in scratch/)

- `scratch/finds_check.gd`, headless, over all 75 placed finds (the lines and
  the event have no spot). For each find it stands the plane over the spot
  for 90 frames so land, stone and trees stream in. Rings: the centre is over
  the land, the stones at a 5 m radius and any facing are clear, and a
  straight 90 m pass is clear. Landings: dry, with flat, tree-free rollouts.
  No two finds within 40 m of each other.
  Result: `OK every find resolves, clear and fair: 0 bad of 75`.
  - A chamber ring is checked only for a clear centre (its walls stand until
    broken). The ice tunnel ring is checked only for its bore.
  - The first runs failed on all five old rooms, which pass under that rule,
    and on tunnel-deep. Two new rows failed as well (east-arch on arch
    8_-1/0, south-aqueduct); both were moved.
- `scratch/finds_fly.gd`, headless, real loop, on its own book file
  (`--pilot-file`):
  - downs-ring (ground ring, plain) +10
  - north-stack (anchored ring, off) +20
  - north-split (anchored ring, off) +20
  - downs-room (wall broken by the surge roll, then the ring, hidden) +40
  - downs-flat (landing by brake, 5 m from the mark) +10
  - Money went 0 -> 10 -> 30 -> 50 -> 90 -> 100. The corner HUD's chip
    counted it up (its shown and pending values were read).
  - Each find flown again paid +0. The scene was reopened on the same book:
    money 100 -> 100, all five still found, and a pass after that paid +0.
  - `RESULT ... failures 0`.
  - In one run, a flight over the sealed room's roof took the ring before
    the roof rule. With the rule, a pass at about 8.4 m from the centre and
    over the roof did not take it.
- `python tools/smoke.py studies/endless_flight.tscn`: `PASS ... 400 frames in
  5.6 s, 0 errors`.
- Headless dummy-renderer errors appeared in some check runs while the plane
  was teleported across the land: 0, 2 or 9 per run, `multimesh is null` in
  the mesh storage. The cause was not traced.

## Pictures (local, uncommitted)

- Map: `scratch/finds_map.png`. All 80 finds; new ones are diamonds, old ones
  circles. Green is plain sight, orange off the path, red hidden. Squares are
  the lines' first gates.
- Stills: `scratch/look/sheet1.png` and `sheet2.png`, one PNG per find in
  `scratch/look/`:
  - sheet1: downs-ring, west-arch, far-stack, ridge-arch, boulder-ring,
    shore-arch, gully-ring, fold-ring, north-split. It also shows
    south-aqueduct, which was moved because its ring overlapped the
    aqueduct's pier.
  - sheet2: south-ravine and east-arch, plus four new rooms seen from above
    (downs-room, shore-room, gorge-mouth-room, shelf-room). They sit on their
    land. The scarp-room still came out white (a cloud in front of the
    camera).
- Logbook pages with 80 rows: `scratch/look/book_new.png` (default) and
  `book_old.png` (`--logbook=old`). Both read without crowding.

## Not verified

- The money chip's "+N" and coins on screen in a rendered flight. Only the
  HUD's numbers were read, headless.
- Flying any chamber except downs-room. The other four rooms passed the
  footprint and centre checks only.
- Landings except downs-flat. The others passed only the flat, dry and
  rollout check.
- Hand flying, and Boost on any row.
- The scarp-room still.
- Whether north-split and south-ravine read as off the path or as hidden when
  played. Both were moved to off the path from their stills.

## Tests

No test in `tests/` names finds, the ledger, the logbook, cracked walls or
`earn`, so none is expected to break. The suite was not run.

## Tools

- `tools/site_map.py` needs PIL and numpy, and neither is on the Mac's
  python3. A venv in `scratch/venv` was used.
- The harness lacks a ready way to put the plane on a heading at a spot
  mid-flight (`drive.gd`'s `place` calls `study.place`, which endless flight
  doesn't have), so the drivers called `plane.place` themselves.
