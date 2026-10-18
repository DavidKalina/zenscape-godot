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
- Keep the table below current: each iteration adds or updates the rows for
  what it built and checks its elements against it.

| Element | Its job (what it gates) | Tool needed / tech margin | Deliberate shortcut? |
|---|---|---|---|
| Colonnade spine (motif, authored seed 61, at its own study's coordinates: ridge x 14..150) | The core: holds 10 of the part spots (cella, pulpit, two portals, balcony, south slab, bench end, three tail fragments); its own stairs, slabs and rope bridges are its routes | Its own (the colonnade study's routes) | The spine's own |
| Strip islet (x 20..122, z ~10..23, turf y 31) | Take-off and landing: 99 m `longest_run`, the plane parked at its east end facing west | None (walk) | No |
| Strip footbridge (lobe x 110 z 4.6, y 31 to the bench lip z -2.6, y 32.7) | The only way from the strip onto the spine (the bench) | Walk over it: the gap is about 7 m with the flank falling under it, past a long jump's 4.24 m carry | No |

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
