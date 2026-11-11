# The railroad's tunnels: handoff (lane `rail-tunnels`, 2026-11-10)

Branch `lane/rail-tunnels`, off `iter/railroad` (the steam-train merge).
Files: `scripts/endless/rail_bore.gd` (the node: streaming, lamps, the
flight's answers), `rail_bore_plan.gd` (new: the layout, by rule),
`rail_bore_mesh.gd` (new: the meshes), `shaders/rail_bore_lining.gdshader`
(new). `rail_bore_shape.gd` is unchanged (the standard section, the blocks'
box). No shared file was touched.

## What a tunnel is now

Everything is laid by `rail_bore_plan.gd` from the line, the land's height
over it and the timetable's meeting points, so a re-laid line gets its own.

- **Linings**, along each tunnel:
  - *ashlar* (dressed stone, arch rings every 6 m): the first 36 m in from
    each face, and the whole of a tunnel shorter than 180 m;
  - *brick* (ribs every 12 m, whitewashed refuges every other bay): in to
    150 m, or wherever the cover over the crown is under 45 m;
  - *bare rock* (rough, pushed out of the bore by noise) deeper in, lamps
    every 48 m, a rock spur off a wall every 64 m or so, sides taking turns;
  - *timber sets* (every 3 m) for 42 m on the rock's side of each lining's
    end and every 300 m of a long bare run, each with a rock fall heaped
    against one wall (the uphill side first, then turns);
  - a *cavern*: in a tunnel with enough bare rock, the 168 m of it under the
    deepest cover (70 m or more over the crown) opens to 62 m wide and 31 m
    high over 26 m flares, rock pillars standing either side of the tracks.
- **The arcade**: a row of piers between the tracks, 20 m apart, with
  arches to switch sides through, along the lined middle of a tunnel 150 m
  or longer, only where the timetable never has two trains side by side
  (a train's length and 60 m either side of `RailTrains.LINE_TUNNEL` and
  `LINE_BRIDGE`). Today: the 204 m west tunnel 1. The long tunnel, where
  the trains meet, keeps its gap open.
- **Lamps** on iron brackets at the spring, walls alternating (30 m in
  lined stretches, 21 m in timber, 48 m in rock), and on each cavern
  pillar's face to the tracks. Every head glows; the 8 nearest the eye are
  lit (range 32 m), so there are pools with dark between.
- **Drains** along both walls (drawn only), soot along the crown of lined
  stretches.
- **Portals**, two kinds: *rock-cut* where the hill stands 25 m or more
  over the crown 30 m in (both ends of the long tunnel), else a masonry
  *facade*. Both have a ring of 19 voussoirs (alternating tones, proud of
  the face), a keystone, quoins up the jambs, wing walls splayed out into the
  hillside, soot above the arch. The facade adds pilasters, a string course,
  a parapet's cornice and a date stone; the rock-cut face is broken rock
  with a hood over the ring.

Seed 1 today: shore tunnel (68 m) and start-station tunnel (104 m) all
ashlar with facades; west tunnel 1 (204 m) ashlar, brick and the arcade,
facades; the west tunnel (1160 m) ashlar, brick, timber with a fall, rock
with spurs, timber with a fall, rock, the cavern, rock, timber with a fall,
brick, ashlar, rock-cut portals.

## Openings (WorldScale-sized)

- Cavern pillars: 5 m along, 4 m across, every 40 m a side (staggered 20 m):
  an inner lane `opening(3.5)` = 7 m wide between the cars' side and the
  pillars, an outer lane 10.5 m to the wall, 35 m gaps between pillars to
  cross through.
- Rock falls: their crest `opening(3.5)` under the vault (over the timber
  ribs), their inner foot 1.75 m off a car's side.
- Spurs: 5 m tall, out to 4.2 m from a car's side.
- Arcade arches: 17.4 m long, 12.5 m to the soffit's top, piers 1.8 m thick
  (2.6 m from each car's side).

## Kept honest

The meshes and the answers read the same numbers. `ground`, `land_y`,
`inside`, `tube`, `guide` and `keep` take the section at s (the cavern's
flare, a rib's inset) and the plan's member `stretches` (vertical solid
spans at (s, d), as the arches' and spans' answers do). The camera's sight
stops at members. Each member is its own collider shape, so near misses
tell them apart. Rough rock is pushed out of the answered surface, never
in; pillars and spurs are pulled into their boxes; a fall's stones lie under
its answered top.

## Proof (throwaway drivers in `scratch/`, uncommitted)

- **The long tunnel at cruise** (`scratch/tunnels/fly.gd`, `--trains=0`):
  the gap, over a rock fall, over the spurs, into the cavern, through a gap
  between pillars to the outer lane and back, over the last fall. 0 crashes,
  0 scrapes, 22 near misses (threads through the pillars' gaps). Least
  clearance from the body: wall 1.84 m, roof 2.69, lamp bracket 2.41, spur
  1.93, pillar 1.28, over a fall 4.76. Aimed into a pillar: a crash 18
  frames on. The arcade tunnel (`--tunnel=arcade`), switching sides twice
  through its arches: clean, least 2.40 m from the arcade.
- **The trains' room** (`audit.gd`): no member within the cars' band
  (6 m each side of the track gap) below a riding plane's room; the nearest
  member is 1.75 m off a car's side (a fall's foot); the vault over a car's
  outer top edge is 15.33 m over the bed at least (6.3 m over a riding plane
  on the 9 m boxcar roof, ribs included).
- **The meeting** (`scratch/rail_quick.gd --rail-start=tunnel`): in the gap
  2.78 s between both trains, 0 crashes, the camera never in a car.
  **Riding** (`scratch/ride_line.gd --rail-start=ride --ride-at=418`,
  flat and box, 75 s): on the car throughout, never in stone, nothing scored.
- Smoke: plain, `--no-railroad`, `--train-test`, every `--rail-start`:
  0 errors. Land hash seed 1 `--no-railroad`: `9ceaddb3…fcb3c4e8` (main's).
- **Cost** (headless CPU, the gap through the meeting, alternating A/B, the
  machine shared): frame median +0.2-0.5 ms; the bore's streaming mean
  0.16 -> 0.25 ms, p99 1.5 -> 4 ms (a piece now builds in about 1.9 ms,
  worst 5 ms, against 0.24); the camera's clearance 0.40 -> 0.59 ms; an
  answer 10-70% dearer (ground 11.6 -> 13.3 us, sight of 8 m 18 -> 29 us).
  Lights: 8 omni (was 6), no shadows. GPU unmeasured.

Stills: `scratch/tunnels/sheet_before_*.png` and `sheet_after_*.png`
(portals, inside, the meeting); singles in `scratch/tunnels/before/` and
`after/` (same views). See them: `python3 tools/play.py --no-pull --
--no-title --pilot-file=/tmp/rail.json --at=-4676,-1479 --heading=-177.5
--alt=8` (the west tunnel's mouth), or `--rail-start=tunnel`.

## Weak still

- Bare rock reads a little like veined marble; the rock-cut portal is
  flatter than the hill around it.
- The cavern's vault is dark above the pillars' lamps.
- No daylight shafts or side galleries: today's line has no thin cover
  along its long tunnel, so no rule for them was written.
- A crash in a bore puts the plane back over the mountain (the study's
  `crash` asks the ground from 300 m up); pre-existing, now more likely.
- Near misses in a bore under a mountain are named "land" (NearMiss
  `_standing` compares with the land's top); pre-existing.
