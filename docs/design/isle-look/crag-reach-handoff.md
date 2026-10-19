# Crag reach: handoff

The loop `ITER(crag-reach)` (spec: `spec-crag-reach.md` beside this file),
six iterations on branch `worktree-agent-ad211108638e9ad9d`, built on the
islet unit's three rounds (`islet-unit-handoff.md`).

## Play it

`./run-crag-reach.command` opens `studies/crag_reach.tscn`. You start on
foot on the main mass's crown beside the parked plane.

- East (+x): the rope bridge to the east mass and its colossus hall.
- North (-z): the fallen column down to the north mass; hold crouch to
  slide it.
- West (-x): the dry aqueduct to the west mass's lower terrace.
- F4: every piece is named `crag_reach/<piece>` (masses, parts, islets,
  specks, `bridge_east`, `pillar_north`, `aqueduct_west`, `ruin_*`).

## What's built

- Four crag masses (main, east, north, west) at different heights, each a
  big IsletUnit with 2-4 lower units against its sides, plus a knoll or
  spire. The main mass is about the aqueduct isle's size and keeps a 73 m
  level landing line. 14 islets between the masses, 18 far off.
- Rope bridge main to east (existing Footbridge, 29.8 m span), fallen
  column main to north (hall-column drums, 31.6 m at 24.4 deg, run slide
  with crouch), dry aqueduct main to west (five spans, 55.5 m, piers on
  crag stepping rocks).
- 11 RuinKit ruins on crowns and terraces, kept off the landing line and
  span ends.
- Debris 1673 fragments (round three: about 5300), gathered under the
  masses and cleared off the span lines (`_clear_spans`).
- Shared code: two opt-in IsletUnit spec keys (larger size, level top);
  everything else lives in `studies/crag_reach.gd`.

## Checks at the end

Smoke `crag_reach`, `islet_yard`, `aqueduct_isle`: pass. Route drives
(crown, bridge, pillar slide, aqueduct) passed with real input in the last
iteration (throwaway, `scratch/`). Build: 50 units, 343k triangles, 7.0 s.
Final still: `captures/shots/crag_reach/t6_far_s.png`.

## Open

- Tops read as orange earth from afar; the palette runs warm; ruin stone
  is near-black at mid range; cliff faces look painted close up.
- The bridge sags at most 1 m (Footbridge's cap) and looks stiff.
- The column looks slim and dark at this scale; its top end hides in the
  rim grass.
- The aqueduct walk once dipped 0.43 m below the channel floor; the
  throwaway check's limit was raised rather than the cause found.
- Spans and cleared debris don't follow a mass moved in F4 until reload.
- No route from the west terrace up to the west top.
- The harness has a time watchdog but no memory cap: an early run here
  grew to 369 GB (a column over -INF ground, since fixed with a finite
  floor, `RUIN_VOID`).
