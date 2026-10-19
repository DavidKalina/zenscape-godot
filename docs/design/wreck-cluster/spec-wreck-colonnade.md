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
    **Spec change: `cache` is built now too.** A dealt part can sit hidden
    inside a breakable kit piece on its spot and come out when the player
    breaks it (slam, side slam). Reuse the kit caches
    (scripts/kit_isle/kit_caches.gd, kit_cache_glint.gd, kit_breaks.gd;
    docs/design/kit-breaks/kit-caches-handoff.md): the faint one-spot glint,
    the dust puff on a too-weak hit, the find stepping out of the rubble. The
    cache holds a plane part instead of a glyph. Several spots get a
    breakable piece that can host a cache, and each deal hides one or two of
    the six parts in caches, chosen at random among those spots, the rest
    lying. N's re-deal rebuilds the broken pieces and re-hides. Do this as
    its own task after the tower redo.

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
| Colonnade spine (motif, authored seed 61, at its own study's coordinates: ridge x 14..150) | The core: holds 10 of the part spots (spots 11 and 12 are the tower's, 13 the coast rock's, 14 the rope rock's) (cella, pulpit, two portals, balcony, south slab, bench end, three tail fragments); its own stairs, slabs and rope bridges are its routes | Its own (the colonnade study's routes) | The spine's own |
| Strip islet (x 20..122, z ~10..23, turf y 31) | Take-off and landing: 99 m `longest_run`, the plane parked at its east end facing west | None (walk) | No |
| Strip footbridge (lobe x 110 z 4.6, y 31 to the bench lip z -2.6, y 32.7) | The only way from the strip onto the spine (the bench) | Walk over it: the gap is about 7 m with the flank falling under it, past a long jump's 4.24 m carry | No |
| Tower rock (`wreck_cluster/tower_rock`, a KitLand shelf off the spine's north-east corner, turf y 30.4) | Holds the tower's podium where the pad falls away (nothing hangs in the air); its turf is a walk round the tower's foot | Down from the pad; back up the skirt (2.3 m, under CHAIN_TOP) | No |
| Tower podium + skirt + stairs (`tower/plinth`, `tower/skirt`, `tower/stairs`; shell at x 144.5 z -22, turf 31.7, podium top y 35.5) | The way into the tower: a kit flight north from the pad (2.24 m) to a landing under the podium's lip; the stepped skirt is the base's bulk | Stairs, then a 1.56 m lip (under GRAB_TOP 1.875: jump, grab) | Reward: the crest's east lip (x ~137, y ~35-36) jumps onto the podium's west side (checked: two jumps) |
| Tower shell (`tower/shell`, kick walls 20 m over the podium, rim y 55.5, back wall torn open) | The inside line: in at the door, wall kicks the whole shaft to the rim (15 kicks, the long one-move line); the upright of the tower | Wall kicks (KICK_GAP 1.98) | No |
| Belfry (`tower/belfry`, ruin_kit_belfry against the shell's open back, north; floor y 41.7, wall head y 46.1) and the west buttress (`tower/buttress`) | The outside line: round the shell's east side to the belfry's outer stair (three flights round three faces), in at the west opening to the floor, two corbels up to the wall head: the landing partway up, part spot 12, the bell under you, the view over the spine | Stairs, then two jump-grabs (corbels 1.4 m apart, the head 1.64 over the high corbel) | No |
| Lintel (`tower/lintel`, jammed across the shell's open back from the belfry's south wall head, top y 45.95) | Joins the two lines: from the belfry's head out into the shaft, then 6 kicks up the last 9.5 m to the rim | Wall kicks from its south end (the kick walls start 1.4 m in from the shell's back edge) | No |
| Lookout beam (`tower/lookout`, off the east wall's head, 3.4 m out over the sky, top y 55.75) | The tower top: the view over the whole cluster, the coast down's start, part spot 11 on the east wall's head | Reached only from the rim | No |
| Coast rock (`wreck_cluster/coast_rock`, a tall islet east of the tower at x 188 z -20, turf y 46, keel 26 m; `coast/arch` on its west side) | The coast down's end: part spot 13 under the arch (tags lying, islet, salvager); the way on is the sail off its west edge down to the tail's first fragment (spot 08), where a slam from that sail opens the cache (checked: drop 6.5-10.5, strength 0.63-0.96) | The sail off the lookout: measured 4.35 m on per m down after the jump, so at y 46 he is 46.7 m out; the rock's near edge is 30 m out (16 m margin; he lands at y ~46-49). From the next highest ground, the belfry's wall head (y 46.1, 35 m from the near edge), the sail is 4.9 m out at y 46 (30 m short) and meets the flank at y ~39; the flank is one smooth overhanging hull (`sheer`), nothing to catch, so he slides off it (checked in still air, `--fronts=0`) | Reward: a gust front's lift (GUST_LIFT, atmosphere fronts) can hold a sail level from the belfry head all the way across; riding a gust there is the deliberate lucky line |
| Rope chain (`wreck_cluster/ropes/spur`, `ropes/slab`, `ropes/column`, `ropes/jib`, `ropes/rope`, `ropes/landing`; off the north shelf at x 84, y 37.6) | The chain: run out along the spur off the shelf's edge, hop and slam onto the slam-spring slab (top 36.6), the launch (9 m) carries him into the swing rope hung from the jib's end (anchor y 49.5, knot over the slab), pump, let go rising north, and he lands on (or grabs) the stone landing off the rope rock's south rim 14 m on. Starts on the shelf, ends on the rock | The rope: let go rising, his feet are still over the landing's grab height (44.6) 13.4+ m on (checked, real input, lands at y 46.5). Without it the slab's launch (apex 44.25) plus the twirl and sail keeps his feet over 44.6 only 0-5 m on (14.6 needed: about 9 m margin); the colonnade's highest lintels (x 64, y 47.4, 34 m off) fall far short (checked); the tower rim is 71 m off (its sail reaches 47 m) | Reward: an updraft charge saved and spent at the launch's top (+3.7 m) sails him 14.3 m on, to a grab on the landing's edge (checked). Unchecked: the portal crowns (x 88 y 55.1, x 117.5 y 51.3) hold him if dropped there and would sail across; no way up them was found |
| Rope rock (`wreck_cluster/rope_rock`, a sheer islet north of the spine at x 84 z -62.7, turf y 46.5; `ropes/arch` on it) | The rope chain's end: part spot 14 under its chapel arch (tags lying, islet, salvager); the start of the next sequence (the slide, planned next) | Reached only by the rope chain (above); its sides are `sheer` | As the rope chain |
| Caches (`wreck_cluster/cache_01`, `_07`, `_08`, `_10`: a pier in the cella, a buttress at the bench's east end, a wall on the tail's first fragment, a pier stump on the last fragment; studies/wreck_cluster_caches.gd) | Each deal hides 1 or 2 of the six parts inside them (the rest lying; cache spots never hold a lying part); the one-spot glint, a dust puff off a weak hit, the part stepping out of the rubble; N stands them all again and re-hides. A piece that hides nothing breaks to rubble | Slam with 2.6 m of drop or more (toughness 0.32; a hop's slam is 0.25 and only flares), or the side slam (0.65). Heights to slam from: the cella's walls (01, unchecked), the crest over the bench's end (07, about 5 m over its foot, unchecked), the tower's skirt (08, unchecked), and for 10 the crest north of it: jump, sail 18 m south, slam over it (checked: drop 3.4, strength 0.38) | No |

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

## Carried to the look pass (from the review of iteration 3)

- The tower's podium and stepped skirt read as plain grey boxes in front of
  the belfry; dress or reshape them so the base is part of the ruin.
- The far silhouette is still a long low hull with a slim block at the east
  end. The tower alone won't fix it at the spine's 136 m length; the islets
  and the look pass must add height and mass so the cluster reads upright.
