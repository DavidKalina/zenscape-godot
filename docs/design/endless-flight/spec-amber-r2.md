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

## Lanes landed (2026-10-28)

Both lanes are merged into the loop's branch (their commits' Notes carry
the details):

- Pieces: `scripts/ruin_kit_gothic.gd`, ids `gothic_nave`, `belfry_tower`,
  `rose_gate`; `openings(id, seed, weathered)` and `plan(...)` give every
  opening's frame, size and kind without building the piece. Open points:
  the nave's inside reads near-black in shade (lighter stone or more
  bounce); a far LOD for the nave (~71k tris) is not built;
  `tests/test_ruin_kit.gd`'s 30 m size cap fails on them (lock-in round).
- Bridges: `scripts/endless/bridge_plan.gd` / `bridge_build.gd`, the
  `bridges` layer, `--no-bridges`. Not done: the flown pass under an arcade
  and through a broken gap (trunk step 2 covers it; candidates on seed 1 in
  the lane's last commit). Amberlands loads ~1.6 s slower (bridge cells
  planned on the main thread at prime). Most bridges come out two-tier.

## Spec change: the bridges become great road bridges (2026-10-28)

The user saw the bridge stills: "looks a bit weird, just like a double
stacked aqueduct". They want a great old stone **road bridge**, not an
aqueduct. A third lane, `lane/amber-bridge-look`, reworks how a bridge is
built; the placer (`bridge_plan.gd`: which rims, chains, broken) stays.

- A **wide flat deck** (a road, ~12–16 m across) with **parapet walls**
  along both edges, paving, worn and broken in places.
- Carried on **few, massive arches**: big round or segmental spans on
  thick tapered piers with cutwaters and buttressed footings, not rows of
  small arches; tall drops get taller piers, not a second tier.
- **Gate arches over the deck**: a gatehouse or great arch at each end
  and, on long spans, one midway, so you can fly *along* the deck and
  thread them. Also flown: under the big arches, between pier and gorge.
- **Broken bridges**: a span gone from the middle, the deck snapped off
  with its paving and parapet ragged, rubble below.
- Readable from a kilometre off as one heavy structure.

The trunk's flyability step checks the deck lane and gate arches too.

Then the user clarified: keep the aqueduct-style bridges too; "we also
need a bridge proper". The road bridge is an added form beside the
aqueduct one, the placer choosing per bridge (a seeded mix with a knob).

## Spec change: the ruins overgrown (2026-10-28)

The user: "the ruins need more of the overgrowth". The kit's growth
(`scripts/ruin_growth.gd`: ivy, vine curtains, leaf mats, moss; swaying,
parting round the plane, never collided) is laid on lightly by default;
`scripts/sundered_growth.gd` shows it laid on thick over a flown hall. The
gothic pieces (lane `lane/amber-growth`) and the new bridges (lane
`lane/amber-bridge-look`) get it thick: curtains from ribs, vaults, arch
soffits and deck undersides, ivy down piers and walls, mats on wall heads
and parapets, long trails off broken ends. Flown openings keep a clear
core (thin strands at their edges are fine: the plane parts them). Growth
colour suits the amber palette (muted, not saturated green).

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
