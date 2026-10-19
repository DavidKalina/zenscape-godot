# Spec: the wreck cluster, rebuilt round the colonnade spine (loop `wreck-colonnade`)

Round 1 (`docs/design/wreck-cluster/round1.md`) built the study, the deal
and the reset. The user rejected its land: a flat 98 m pancake main body
that reads as one flat isle with bumps, ropes you don't need because you
can just jump the gap, a tower that is an empty shell, an air ring up to a
perch that does nothing. Keep the plumbing (`studies/wreck_cluster.gd`,
`scripts/plane_arc/wreck_arc.gd`, the N re-deal, the pause-menu row, the
in-memory ledger, `run-wreck-cluster.command`); replace the place.

The cluster is where a run starts: the plane lies wrecked, its six parts
scattered, and the player plays this place on foot before taking off. It
is a playground the player works through, built as one set piece.

## Done looks like (what the user plays and sees)

1. **The colonnade spine is the core.** Its knife-edge ridge, processional
   colonnade and temple gate (`scripts/kit_isle/motif_colonnade_spine.gd`,
   `studies/colonnade_spine_isle_art.gd`) stand at the centre of the study,
   built from that code, not redrawn. Round 1's pancake goes.
2. **The silhouette.** From a far still the cluster reads as one upright
   place with open sky all round: the spine and the tower carry the shape,
   2–3 islets sit close round them, nothing is a broad flat disc. No other
   isles in the study.
3. **The tower.** A tower the player works their way up, its inside or
   outside a climb (ledges, wall kicks, stairs, a chain), with something at
   the top worth the climb: at least a part spot and the view over the whole
   cluster, and the start of the coast down.
   **Spec change (after iteration 2):** the user rejected iteration 2's
   tower: a plain black box like a smokestack, a climb of 20 identical wall
   kicks up an empty chimney, and no change to the far silhouette. Redo it
   as a set piece in the colonnade's own gothic architecture (a ruined bell
   tower or campanile, broken open in places), built from RuinKit pieces,
   with bulk at its base that changes the far silhouette. The climb winds
   up outside and inside and varies: ledges, a broken stair, windows and
   breaches to kick between, at least one landing partway up that holds
   something (a part spot or the way on to another sequence), and choices
   of line, never one repeated move. Replace iteration 2's shell, plinth
   and lookout (keep their F4 names where a piece keeps its role).
4. **The coast down.** From the tower top the sail carries the player to a
   place that is hard or impossible to reach any other way (a part spot or
   a route on).
5. **The ropes.** Swing ropes carry the player to one area they cannot
   reach without them.
6. **The slide.** A section the player slides down (a slope, a balustrade
   slide, a ramp of fallen stones) that goes somewhere.
7. **The rune knight** on a deck where knock-offs read well, guarding a
   part spot or a route. On by default in this study, as in round 1.
8. **The islets.** 2–3 islets round the core, each with a job.
9. **The strip.** A clear stretch of turf long enough to take off from and
   land on by hand (AGENTS.md turf rule), the plane parked at its end.
10. **Part spots.** 12–18 spots in the architecture's nooks (under an arch,
    on a broken span, in a niche, at the tower top), not in open fields;
    names stay `wreck_cluster/part_spot_NN`. Each spot is tagged with the
    holder types it could host later: `lying`, `cache` (hidden in a
    breakable ruin piece, slam), `water`, `islet` (a spawned islet),
    `salvager` (dangled by a flying plane on a route past it), `knight`
    (carried by the knight), `jammed` (slam loose). Only `lying` is built
    now; the tags are data for a later round.

## The rule over all of it: everything earns its place

- Every rope, ring, islet, slab and structure gates a part spot, a route or
  a view. If it doesn't, it is cut.
- A gap meant to need a tool (the ropes, the coast down) must beat the real
  tech: a long-jump chain plus the sail, numbers from
  `scripts/pilot_motor.gd`, with the margin written down. Where a skilled
  shortcut exists it is deliberate, and named as a reward in the table.
- **Sequences attach; nothing floats.** (Spec change after iteration 2.)
  A sequence starts on the architecture or the land and ends on it: a
  platform, a ledge, a landing, a doorway that leads somewhere else. No
  slab, rope or platform hangs alone in open sky going nowhere. Because the
  deal is random, a sequence's end may or may not hold a part on a given
  run, so every sequence must add to the level on its own: it reaches a
  place that leads on to another route, a view, or another sequence. Part
  spots sit along and at the ends of these sequences.
- **Chained moves.** At least one sequence chains the player's moves
  through pieces that exist, for example: ground slam onto a slam-spring
  slab (the bob slab's slam spring, see `git show 0d6705b5` and the ring
  route merge `ef7ca136`), launched into a swing rope
  (scripts/interactables/swing_rope.gd), released to grab onto a platform
  or ledge on the architecture, which opens onto a further sequence. Prove
  the chain through the real input path.
- Keep the table below current: each iteration adds or updates the rows for
  what it built and checks its elements against it.

| Element | Its job (what it gates) | Tool needed / tech margin | Deliberate shortcut? |
|---|---|---|---|
| Colonnade spine (motif, authored seed 61, at its own study's coordinates: ridge x 14..150) | The core: holds 10 of the part spots (spot 11 is the tower top) (cella, pulpit, two portals, balcony, south slab, bench end, three tail fragments); its own stairs, slabs and rope bridges are its routes | Its own (the colonnade study's routes) | The spine's own |
| Strip islet (x 20..122, z ~10..23, turf y 31) | Take-off and landing: 99 m `longest_run`, the plane parked at its east end facing west | None (walk) | No |
| Strip footbridge (lobe x 110 z 4.6, y 31 to the bench lip z -2.6, y 32.7) | The only way from the strip onto the spine (the bench) | Walk over it: the gap is about 7 m with the flank falling under it, past a long jump's 4.24 m carry | No |
| Tower plinth + stairs (`wreck_cluster/tower/plinth`, `tower/stairs`; pad at the spine's east end, x 144.5 z -25, turf 31.7) | The way into the tower: a kit flight north from the pad (2.24 m) to a landing under the plinth's lip | Stairs, then a 1.56 m lip (under GRAB_TOP 1.875: jump, grab) | The crest's east lip (x ~138, y 34.6, about 3 m west of the plinth) may jump straight onto the plinth: unchecked, a reward if it holds |
| Tower shell (`tower/shell`, kick walls 28 m over the plinth, rim y 63.5) | The tower climb and the upright in the far silhouette: in at the door, 20 wall kicks up the chimney to the kick walls' heads | Wall kicks (KICK_GAP 1.98); its breaches are rests or ways out | No |
| Lookout beam (`tower/lookout`, off the east wall's head, 3.4 m out over the sky, top y 63.75) | The tower top: the view over the whole cluster, the coast down's start (step 3 gives it a goal), part spot 11 beside it | Reached only from the rim | No |

## Constraints

- AGENTS.md holds: headless checks, `-- --no-title` on windowed runs,
  sizes from WorldScale and the wanderer (`RuinKit.GRAB_TOP`/`CHAIN_TOP`),
  stable `layout_overrides` names for placed pieces, no game pitches or
  comparisons in docs or comments.
- Touch only the study's own files and new files. Shared code (the
  colonnade motif, RuinKit, KitLand, the motor) changes only additively or
  behind an opt-in, so the aqueduct isle and the colonnade's own study build
  as before; smoke them if you touch shared code.
- Never write the user's real save or layouts (`layouts/aqueduct_isle.json`,
  `motifs/authored/*`).

## Proof per iteration

- Smoke `studies/wreck_cluster.tscn` (tools/smoke.py): PASS.
- Routes it built walked through the real play loop (scratch driver).
- Stills of what it built, plus the far silhouette still once the core is
  in (tools/shot.py, `-- --no-title`). Look at them; fix what reads wrong.

## Cap and budget

The iterate skill's defaults.
