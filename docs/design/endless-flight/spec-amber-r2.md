# Amberlands, round 2: gothic set pieces and plateau bridges (spec)

Loop slug `amber-r2`, trail prefix `ITER(amber-r2):`. Branch
`claude/game-mechanics-gameplay-830092` (worktree
`.claude/worktrees/game-mechanics-gameplay-830092`). Round 1 and its
handoff: `docs/design/endless-flight/amberlands-round1-handoff.md` (read
"Round 2 needs" and "Harness gaps"). Fly it with
`.\run-endless-flight.cmd --world=amberlands`.

## What done looks like

You fly amberlands and the ruins are the level:

- **Giant semi-gothic set pieces** stand on the terraces and around the
  massifs, big enough to read from a kilometre off and to pick from the high
  view. Each has **tight, precise openings** you thread by hand: lancet
  windows in a nave's walls, the gaps under flying buttresses, an open
  belfry, a broken vault you fly the length of and leave through a window.
  Some openings are **knife-edge slots on purpose** (`WorldScale.knife()`),
  where you roll to fit. The rest are sized from a toy width with
  `WorldScale.opening()`. They are harder than the wilderness arches: the
  threading is finer.
- **Bridges and aqueducts join the high ground**: from a plateau top, a
  massif shoulder or a terrace shelf to another one at a matched height,
  whatever lies between. Some are whole; some are **broken in the middle**,
  leaving a gap to fly through. Some run along a chain of chunks, so you can
  fly a line *along* them, not only across. Tall drops get two-tier arcades.
- Every opening you are meant to fly is **hand-flyable**, checked with wobble
  and margin through the real play loop, not one exact autopilot line.
- The **meadows-and-flats** rule still holds: a landable flat is never far
  off.
- Wilderness and overgrown look and plan exactly as before.

## Lanes (built in parallel, each in its own worktree, merged before the trunk)

1. **`lane/amber-pieces`: the gothic set pieces as RuinKit pieces.** Two
   pieces with stable ids, scaffolded with `tools/kit_piece.py`, in their
   own new file(s), with collision, the kit's weathered stone and growth
   material, layout handles, and `KIND_OF` entries
   (`scripts/breaks/break_kinds.gd`) so they break like the others:
   - a **ruined nave**: a long hall of piers and lancet walls with flying
     buttresses down its flanks and a part-fallen vault, flown through
     lengthwise, with lancets and buttress gaps as side ways in and out;
   - a **belfry tower**: a tall broken tower with an open belfry, tracery
     window and stepped buttresses, threaded through near the top.
   Both come with a kit yard and stills. If there's budget, a third: a
   standing **rose gable** gate with a round opening.
2. **`lane/amber-bridges`: plateau-to-plateau bridges and aqueducts.** A new
   placer in its own file (e.g. `scripts/endless/bridge_plan.gd`), a pure
   function of seed and cell like `arch_plan.gd`: it finds pairs of rims
   (plateau tops, massif shoulders, terrace shelves) within reach at matched
   heights, exposing what the land field needs (the mesa field, `last_mesa`)
   in small additive edits. It builds spans whose two ends are both rims,
   some broken in the middle, some chained along several chunks, and two-tier
   arcades past a drop of about 40 m (the kit has `two_tier`). It is on only
   where a profile's layers set it (amberlands), and it keeps clear of the
   arch planner's sites, halls and tunnels.

Lanes keep shared-file edits small and additive and end their commits with
**Notes for merge**. Lane commits: `ITER(amber-r2): lane <part>: <task>`.

## Trunk (the loop, after the merge, in order)

1. **Set piece placer**: a placer for standalone structures (own file) that
   puts the lane-1 pieces on the amberlands land: around massifs and on
   terrace shelves, facing so their openings are flown with the land's flow,
   spaced so a region isn't crowded, clear of arches, bridges, halls,
   tunnels and landing flats. Pieces named through
   `scripts/layout_overrides.gd` (`amberlands/<piece>`). Amberlands layers
   only.
2. **Flyability**: a wobble and margin check through the real play loop for
   each opening kind (nave lengthwise, lancet, buttress gap, belfry, knife
   slot, broken bridge gap, under-arcade); fix sizes that fail.
3. **The rival's course** may pick the new openings as gates (if small: add
   them to `rival_line.gd`'s candidates).
4. **Look and stills**: low passes through each set piece and bridge, from
   high, an A/B against round 1c; a frame-time glance at a crowded spot.
5. **Flats check** over the new land, and smoke of every scene below.

## Checks for every iteration

- Smoke (`tools/smoke.py`): `--world=amberlands`, `--world=regions`, the
  default world. Must PASS with 0 script errors.
- Stills (`tools/shot.py`, `-- --no-title`, one window at a time) for
  anything seen; looked at and fixed before committing.
- Throwaway drivers in `scratch/` (round 1's are in `scratch/amberlands/`);
  no committed tests, no full suite (prototype rules, AGENTS.md).

## Model and cap

Opus (new kit pieces, new kinds of place). Cap: the skill's default.
