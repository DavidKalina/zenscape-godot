# Handoff: the Olmec's chase on a planned route (prototype round `olmec-routes`)

Built on the climb round (`olmec-climb-handoff.md`, e0e557f3).
**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
The climb round's chase comes back with `--body-knob=plan_chase=0` (no graph
is built then).

## What changed

- **`scripts/enemies/olmec_route_graph.gd` (new): his place graph.**
  - Places are body_routes.gd's 1.5 m columns. The room over a place is his
    whole bulk with the head on (9.2 m), not his neck. A walk place also
    needs his shoulders' square clear of rock (`clear`).
  - Special moves are built with his own checks, from a probe body stood on
    each place, 8 ways:
    - **climb:** `_climb_at` = `_climb_find` with no goal. It checks the
      overhang column (`_climb_column`), roof over the lip and room past it.
    - **jump:** `_ledge` plus an arc flown with his bulk.
    - **drop:** out to `down_reach`, down to `down_deep`, a bulk-clear arc
      (`drop_bulk`), room where he lands.
    - **cliff:** `_cliff_find` with no goal, only where the catch dry run
      passes (`_catch_ok`).
  - Each move keeps what it needs to be carried out (throw point, arc rise,
    face, lip).
  - The search is an A* in slices. It returns the route, or the route to the
    place nearest you.
- **`headless_body.gd`, knob `plan_chase`** (off by default, on in
  `OLMEC_KNOBS`). The `_pc_*` section:
  - **Target:** he plans to where he believes you are: seen, else last seen,
    else your throw (`watch_throw`). Relentless, he takes your scent after
    `hunt_search` s.
  - **Replanning:** silently every `chase_replan` s, or when you move 6 m.
    He stops while a search runs only if his old route is badly stale.
  - **Walk legs** go through `_pursue`, so the run builds. The aim cuts no
    route corner by more than 1 m.
  - **Special legs:** he walks to the leg's start, then the stare beat:
    plants, faces you, the search runs, he holds `stare_hold`, turns once
    onto the leg and goes. Before he goes, the move is checked again from
    where he really stands.
  - **Failures:** a failed leg, a let-go climb or a leap that lands off its
    end is banned for 30 s, along with every special move within 3.5 m of
    its spot.
  - **No route:** if he can pull or suck you from here, he plants. If you
    are over him, he walks to a stand that sees you (`_sight_find`), then
    pulls. Otherwise he goes to the nearest place and stares, planning again
    every `stare_replan` s or when you move 3 m.
  - **Smaller fixes:**
    - `_catch_wall` looks lower when his bulk meets the lip's round.
    - On a route walk, a shoulder or knee hit doesn't stop him (his bulk is
      eased along). A pin still fails the leg.
    - A turn on a narrow terrace stops and turns rather than "meeting an
      edge".
- **`body_routes.gd`:** its rays use the body's `_land_mask()`, so
  `parked_off` holds in the world read. This is the same mask for every
  other user.
- **`studies/crag_reach.gd`:**
  - Builds the graph at load from a probe Olmec off the tree. The area is
    the masses, terraces and islets within 260 m.
  - Rebuilds what a break forgets, 4 ms a frame.
  - The never-stuck watch makes no rim walks while `plan_chase` is on.
  - `--olmec-graph=sliced` builds after load instead (4 ms a frame).

## Graph build cost (headless, this Mac)

- About **3.0 s at load** (the study's load goes from ~10 s to ~13 s).
- 3928 places he fits; 4889 built with the narrow and landing places.
- 1438 special moves: 1055 drops, 224 cliffs, 101 jumps, 58 climbs.
- Memory: **~34 MB** (static memory growth over the build).
- Worst single place: 12–17 ms.
- Searches on the built graph:
  - 0.2–12 ms when he finds you.
  - 45 ms for a full "no route" search (4300 places).
  - Each search runs 2.5 ms a frame.
- In play, run alone (islet_12, 47 breaks): worst frame 31 ms, **none
  over 50 ms**.
  - The tables (8 runs at once) show 50–72 ms frames, the same as the
    climb round's tables.
  - The search never builds places itself; the study's slices rebuild what
    breaks forget.
- Not on a worker. Physics queries off the main thread aren't safe here.
  Caching the built graph to disk, keyed by the reach's seed, would remove
  the 3 s.

## Numbers (headless, 20 places, 60 s; `scratch/olmec_reach.gd`)

| | climb round | this round |
|---|---|---|
| reached, seen | 15/20, mean 19.9 s | **15/20**, mean 20.5 s |
| reached, blind | 13/20, mean 24.0 s | **17/20**, mean 24.2 s |
| despawns | 0 | 0 |
| void falls | 0 | 0 |
| stare-no-route seconds (sum, seen / blind) | 141 / 178 | 32 / 31 |

**Seen, newly reached:** west_terrace_1 (31 s), west_spire (46 s), and in
some runs west (45–52 s). All take a cliff leap and a climb.

**Blind, newly reached:** main_terrace_2, north_terrace_2, west,
west_terrace_1 and west_spire.

**Still not reached:**
- **main_terrace_3 and east_terrace_2 (seen):** he gets within 4.8 / 6.4 m,
  and his landing wave throws you off the terrace into the void. You
  respawn at the start. This is the known wave issue, not the route.
- **islet_14:** 54 m under main's rim, unreachable (a safe spot).
- **islet_12 (seen):** 30.7 m off at 60 s, once.
- **north_terrace_1 (blind):** 7.7 m off, staring.

**Rim turning, planted, per rim visit** (ledge round / climb round /
this round):

| | ledge round | climb round | this round |
|---|---|---|---|
| seen, reversals | 0.96 | 0.88 | 0.97 |
| seen, rad | 1.39 | 1.21 | 1.80 |
| blind, reversals | 1.00 | 1.00 | 0.92 |
| blind, rad | 1.08 | 1.08 | 1.46 |

The extra radians are the beat: he turns to you, then onto the leg. No
visit had more than 3 reversals.

**Some places are slower:** main_terrace_3 seen (21 → ~27 s when not
thrown) and islet_12. The route picks a different approach than the old
straight-at-you walk, so the suck-from-30 m comes later.

**The user's stuck case** (`scratch/cases.sh`, him on main_terrace_3, you
on the south lip):
- **11 of 12 starts pulled you down**, in 3.2–13.7 s. The main case
  (4,30,40.6) took 9.0 s; the climb round took 10.7.
- He walks to a stand that sees you and pulls (no route exists up from
  that terrace).
- One start, him at (12,6,32) with you at (4,30,40.6), never got a line.

**main_terrace_2 under the crown:**
- **8 of 8 reached**, in 17–21 s, climbing the clean stretch.
- The 2 "void falls" from (-44,16,-12) are the driver's start point: it is
  off the terrace edge and he falls at once.

## Where to stand to see it

- **A route with a cliff leap and a climb:** east_knoll (about
  (94,42,-20)).
  - He crosses main, stares at main's east rim, leaps at east's west face,
    catches it and hauls over.
  - Sheets: `scratch/shots/cliff_east_knoll_routes_sheet.png` and
    `stare_east_knoll_routes_sheet.png`.
  - Read: the stand, the crouch, the arc, the catch, the haul, the landing
    wave.
- **The pull:** main's south lip at (4,30,40.6), with him on
  main_terrace_3.
- **The west:** west_terrace_1 (-86,30,-21). A cliff leap off the aqueduct
  rocks, then a climb.

## Rules: gated / kept as a move / still needed (with `plan_chase` on)

**Gated (they don't run):**
- `edge_fan`
- the rim skirt and the wall skirt
- `down_to`'s own floor picking (in `_chase` and `_hunt_wall`)
- the stare's way list (`_stare_plan` jobs, `_stand_jobs`, `_stare_work`)
- `cliff_leap`'s and `climb_to`'s pickers (as jobs)
- `leap_catch`'s gap picking (`_wall_leap` in `_hunt_edge`)
- `climb_after` (`_after_try`) and `chase_routes` (`_chase_plan`)
- the never-stuck rim walks (`ledge_walk`)
- the climb-into-any-climbable-wall reaction in `_hunt_wall`

**Kept as moves or checks:**
- the planner's legs: `_ledge`, `_drop_up` arcs, `_down_room`,
  `_arc_clear`, `_cliff_find`, `_wall_arc`, `_catch_ok`, `_climb_find`,
  `_climb_column`, `_face_shelf`, `_room_at`, `_walk_line`
- the climb walk and feel (`_stare_go` / `_rim_arrive` /
  `_climb_walk_met`)
- `_breach_try` (smashing masonry on a walk)
- `_down_find`, kept only for `down_show`: a drop leg takes a landing
  within 9 m of the planned one that your camera sees
- `_sight_find` and `suck_up`

**Still needed:**
- `beam`: the fallen pillar's crest is narrow walk places in the graph,
  but `_pursue`'s beam steering keeps him on the crest.
- `parked_off`: now in the world read too.
- `climb_clear`, `drop_bulk`, `leg_slope`: his body on faces and drops.
- `suck_in`, swat, pounce, `watch_throw`, the run: unchanged.

## Knobs and constants

| knob | default / OLMEC_KNOBS | meaning |
|---|---|---|
| `plan_chase` | 0 / **1** | the chase on the planned route |

**In `headless_body.gd`:**
- `PLAN_US` 2500: search time per frame (µs)
- `PLAN_AIM` 9: how far ahead a walk leg aims (m)
- `PLAN_CUT` 1: how far the aim may cut a route corner (m)
- `PLAN_BAN` 30: how long a ban lasts (s)
- `PLAN_AT` 1.6: how near a leg's start counts as there (m)
- `PLAN_STRAIGHT` 0.45: a jump within this of your way and his facing needs
  no beat (rad)
- `PLAN_BEAT_GAP` 6: no second beat for the same leg within this (s)
- `PLAN_NEAR_MOVE` 7: a special leg this near when a beat picks a walk uses
  that beat (m)
- `PLAN_AGAIN` 0.5: with no route, planned again no oftener than this (s)
- `PLAN_FAILS` 3: failed checks in a row before he gives up to "none"
- `PLAN_CLIMB_NEAR` 5: a wall this near the planned face is taken as it (m)

**In `olmec_route_graph.gd`:**
- `CLIMB_LOOK` 12 m, `CLIMB_COLS` 8
- `DROP_KEEP` 3; drops are built from every other column
- `ARC_COARSE` 4: build arcs flown in 4× steps, then re-flown at full rate
  before the leap
- `CLEAR_W` 0.8, `BAN_NEAR` 3.5 m

**In `crag_reach.gd`:** `OLMEC_GRAPH_US`, `OLMEC_GRAPH_NEAR`,
`OLMEC_GRAPH_GROW`.

## Still off / not done

- **The wave still throws you off narrow terraces** (main_terrace_3,
  east_terrace_2) right as he arrives.
- **Some climbs pass the graph's checks and then let go in play** ("no room
  over the lip", a shelf under a leaning knoll). They are banned by spot
  after one try. The graph's lip-room check (half his neck) is weaker than
  the climb's own.
- **Slow approaches:** he can take a long route where the old chase got a
  suck from 30 m.
- **He can be stranded in a pit he can't leave** (east_terrace_2 after
  you're thrown off). He stares there; nothing teleports him.
- **The landing-wave and void-fall respawn** paths are unchanged.
- **Graph limits:**
  - The 3 s load cost.
  - Drop moves are built only from every other column.
  - Only 8 ways per place.
- **Diagnostics left in:** `plan_text()` (in the F1 overlay), `plan_why`,
  `plan_wall_why`, and the graph's `prof` / `climbs_passed` counters.

## Proof

- Headless import. **Smoke PASS:**
  - crag_reach plain and `--olmec`
  - olmec_field, whole_body_chase
  - city_breaks_yard (uses `chase_routes`)
  - motif_yard `--motif=felled_colonnade`
- **Throwaway drivers** (scratch/, uncommitted):
  - `olmec_reach.gd` (with plan columns), `climb_case.gd`
  - `table.sh`, `both.sh`, `cases.sh`, `rows.py`, `sum.py`
  - `graph_stats.gd` (build cost, memory, sample searches)
  - `climb_probe2.gd`, `what_probe.gd`
- No committed tests, full suite not run.
- **No existing test should break.** The knob is off by default, and the
  new function parameters are optional with the old defaults. The
  body_routes mask is unchanged without `parked_off`.
- **Note:** this round first overwrote the existing
  `scripts/enemies/olmec_places.gd` (the layer's Keeper modes). It was
  restored from git before commit; the graph lives in
  `olmec_route_graph.gd`.

## Harness gaps

- A driver count of "the walker was thrown into the void and respawned"
  would separate the wave issue from reach failures. This round read it off
  `feet` versus `walker`.
- `drive.py` drops the study's `print` lines unless `--all`. A `--grep`
  option would help.
