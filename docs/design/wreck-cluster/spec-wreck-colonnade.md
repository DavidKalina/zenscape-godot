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
| Colonnade spine (motif, authored seed 61, at its own study's coordinates: ridge x 14..150) | The core: holds 7 of the part spots, 01-07 (cella, pulpit, two portals, balcony, south slab, bench end; 08 and 09 are the tower rock's, 10 the strip lobe's, 11 and 12 the tower's, 13 the coast rock's, 14 the rope rock's, 15 the tilt rock's, 16 the knight's causeway's, 17 the south flank walk's, 18 the north flank walk's); its own stairs and slabs are its routes. Its tail (five fragments, the stepping stones between them, two rope bridges and their anchors) is cut in this study as floating clutter (`studies/wreck_cluster.gd` TAIL_CUT; the motif still builds it elsewhere) | Its own (the colonnade study's routes) | The spine's own |
| Strip islet (x 20..122, z ~10..23, turf y 31) | Take-off and landing: 99 m `longest_run`, the plane parked at its east end facing west; part spot 10 on its lobe by the footbridge's foot, under the bench (tags lying, water) | None (walk) | No |
| Strip footbridge (lobe x 110 z 4.6, y 31 to the bench lip z -2.6, y 32.7) | The only way from the strip onto the spine (the bench) | Walk over it: the gap is about 7 m with the flank falling under it, past a long jump's 4.24 m carry | No |
| Tower rock (`wreck_cluster/tower_rock`, a KitLand shelf off the spine's north-east corner, turf y 30.4; its root hangs 74 m under it in three fangs, so the tower and its rock stand as one upright stack at the east end) | Holds the tower's podium where the pad falls away (nothing hangs in the air); its turf is a walk round the tower's foot. Its south-east lobe (`TAIL_LOBE`, x 146..161, z -16..-5) takes the place where the spine's tail fragments floated: part spot 08 and its cache (the coast down's way on lands there), joined to the pad's east end (a 0.7 m step down). Part spot 09 and its cache stand on its turf under the belfry's north face | Down from the pad (checked: pad -> lobe, walk); back up the skirt (2.3 m, under CHAIN_TOP) | No |
| Tower podium + skirt + stairs (`tower/plinth`, `tower/skirt`, `tower/stairs`; shell at x 144.5 z -22, turf 31.7, podium top y 35.5) | The way into the tower: a kit flight north from the pad (2.24 m) to a landing under the podium's lip; the stepped skirt is the base's bulk | Stairs, then a 1.56 m lip (under GRAB_TOP 1.875: jump, grab) | Reward: the crest's east lip (x ~137, y ~35-36) jumps onto the podium's west side (checked: two jumps) |
| Tower shell (`tower/shell`, kick walls 20 m over the podium, rim y 55.5, back wall torn open) | The inside line: in at the door, wall kicks the whole shaft to the rim (15 kicks, the long one-move line); the upright of the tower | Wall kicks (KICK_GAP 1.98) | No |
| Belfry (`tower/belfry`, ruin_kit_belfry against the shell's open back, north; floor y 41.7, wall head y 46.1) and the west buttress (`tower/buttress`) | The outside line: round the shell's east side to the belfry's outer stair (three flights round three faces), in at the west opening to the floor, two corbels up to the wall head: the landing partway up, part spot 12, the bell under you, the view over the spine | Stairs, then two jump-grabs (corbels 1.4 m apart, the head 1.64 over the high corbel) | No |
| Lintel (`tower/lintel`, jammed across the shell's open back from the belfry's south wall head, top y 45.95) | Joins the two lines: from the belfry's head out into the shaft, then 6 kicks up the last 9.5 m to the rim | Wall kicks from its south end (the kick walls start 1.4 m in from the shell's back edge) | No |
| Lookout beam (`tower/lookout`, off the east wall's head, 3.4 m out over the sky, top y 55.75) | The tower top: the view over the whole cluster, the coast down's start, part spot 11 on the east wall's head | Reached only from the rim | No |
| Coast rock (`wreck_cluster/coast_rock`, a tall islet east of the tower at x 188 z -20, turf y 46; under it a stack 50 m deep, near-vertical then stepping in twice, leaning east; `coast/arch` on its west side) | The coast down's end: part spot 13 under the arch (tags lying, islet, salvager); the way on is the sail off its west edge down to the tower rock's south-east lobe (spot 08), where a slam from that sail opens the cache (checked: drop 6.8, strength 0.66) | The sail off the lookout: measured 4.35 m on per m down after the jump, so at y 46 he is 46.7 m out; the rock's near edge is 30 m out (16 m margin; he lands at y ~46-49). From the next highest ground, the belfry's wall head (y 46.1, 35 m from the near edge), the sail is 4.9 m out at y 46 (30 m short) and meets the flank at y ~39; the flank is a stack of smooth overhanging hulls (`sheer`, each ring no wider than the one over it), nothing to catch, so he slides off it (checked in still air, `--fronts=0`) | Reward: a gust front's lift (GUST_LIFT, atmosphere fronts) can hold a sail level from the belfry head all the way across; riding a gust there is the deliberate lucky line |
| Rope chain (`wreck_cluster/ropes/spur`, `ropes/slab`, `ropes/column`, `ropes/jib`, `ropes/rope`, `ropes/landing`; off the north shelf at x 84, y 37.6) | The chain: run out along the spur off the shelf's edge, hop and slam onto the slam-spring slab (top 36.6), the launch (9 m) carries him into the swing rope hung from the broken end of a flying buttress (`ropes/column` its gothic pier on the shelf, collided as one clean battered block with no lip to climb; `ropes/jib` its arm leaping north off the pier's head, broken off in mid-air; anchor y 49.5, knot over the slab), pump, let go rising north, and he lands on (or grabs) the stone landing off the rope rock's south rim 14 m on. Starts on the shelf, ends on the rock | The rope: let go rising, his feet are still over the landing's grab height (44.6) 13.4+ m on (checked, real input, lands at y 46.5). Without it the slab's launch (apex 44.25) plus the twirl and sail keeps his feet over 44.6 only 0-5 m on (14.6 needed: about 9 m margin); the colonnade's highest lintels (x 64, y 47.4, 34 m off) fall far short (checked); the tower rim is 71 m off (its sail reaches 47 m) | Reward: an updraft charge saved and spent at the launch's top (+3.7 m) sails him 14.3 m on, to a grab on the landing's edge (checked). Unchecked: the portal crowns (x 88 y 55.1, x 117.5 y 51.3) hold him if dropped there and would sail across; no way up them was found |
| Rope rock (`wreck_cluster/rope_rock`, a sheer islet north of the spine at x 84 z -62.7, turf y 46.5; under it three overhanging tiers down to two fangs 44 m down, its top 6 m kept as the slide's lodge needs; `ropes/arch` on it) | The rope chain's end: part spot 14 under its chapel arch (tags lying, islet, salvager); the start of the slide (below) | Reached only by the rope chain (above); its sides are `sheer` | As the rope chain |
| Slide (the tilt rock's own land: a tongue of turf and rock running up north-east from its east end under the rope rock's west rim, `Art.slide_ground`; no placed piece. Along it: a flat lodge tucked under the rope rock's overhang, top y 40.8, 5.7 m under the rim, reaching 0.8 m past the old head; a 52° steep drawn as rock; a 24° ease down into the tilt rock's turf; crowned across, 5-9 m wide; a finer grid (1 m) over it) | The rope rock's way on: walk off the west rim onto the lodge (a full run's walk-off lands on it, no stun; checked 1.2-2.5 m either side of the middle too), surf the steep (past SLIDE_AUTO: he can't stand, boot-surfs) and the ease (crouched) onto the tilt rock, the pace running out up its rising turf (checked, real input: rest at x ~56) | One way down. From below: hopping up the steep works (slide jumps gain on it), but the rim stands 5.7 m over the lodge; the highest feet reached by hops and side flips was 42.8, under the 43.5 line where the hollow turf over him would pop him onto it (pilot_physics_ground REACH 3.0) and far past CHAIN_TOP. A hop off the rim (not a walk-off) lands past the lodge on the steep from over 6 m: a stun | The updraft (any saved charge) lifts him from the lodge back to the rim, as it beats every height gate here |
| Tilt rock (`wreck_cluster/tilt_rock`, a long islet tilted like a dropped slab, x 43.5..68.5, z -61..-46, turf 34.4 at its east end rising 5° west; `slide/wall` a lancet wall at its high west end, `slide/chest` a carved chest before it) | The slide's end: part spot 15 by the chest (tags lying, islet, cache); the way on is the footbridge off its south edge (`TiltBridge`) to the north balcony (spot 04) and a jump-grab (1.6 m) onto the north shelf (checked: spot 15 -> bridge -> balcony -> shelf) | None from the spine (the bridge walks); the slide is the way down from the rope rock | No |
| Knight's causeway (`wreck_cluster/knight/causeway`, `knight/pier`: a snapped stone deck 3.2 m wide jutting 24.5 m west off the strip's west end at z 16, its top level with the strip's turf (y 31.03), broken off at x -4 with a snapped pier on its tip; drawn as ruin: coursed sides and under-course, a ragged tip, two lost piers' stumps with arch springers hanging under it, its drawn deck stopping at the strip's rim (no plank on the turf); it collides as its one clean deck box. `knight/parapet`: two short broken parapets by the tip's pier and a fallen coping stone at the root, collided, a piece of their own, because a second shape in the deck's body makes the knight's teeter fall land on the deck and shatter instead of going over) | The rune knight's deck (Art.knight_line(): he patrols from 3 m in on the strip's turf out to the pier, so a push back toward the strip leaves him standing): he guards part spot 16 on the tip in the pier's lee (tags lying, knight, cache); sky on both sides and past the tip, so a knock-off, his or yours, is a fall out of the cluster (checked: two crosswise hits push him off the side and he falls past the rim, gone); also the view back down the runway | Walk (checked, real input, knight off: strip -> causeway -> spot 16); past the knight: he notices within 5 m and slashes from the deck (checked: notice, track, gather, slash, the crescent knocks him). Knocking him off by the player's own input (checked, real key taps, from the strip's turf at x 27 z 19, about 20° off his line): Z three times at his back while he patrols west near the root (two shoves, braced, skid him to the north lip, he teeters; the third puts him over, "gone"); or Q in his crescent's window (a parry, he reels) and Z at him reeling (a riposte cracks a rune and skids him 7 m along its line to the lip), then Z once more over the side, "gone". Shots from in front while he isn't reeling are caught and slashed back | Reward: the parry and riposte are the quick way past him (two shots, not three, and from in front) |
| South flank walk (`wreck_cluster/flank_s/walk_1`..`walk_5`, `flank_s/rubble_1`..`rubble_4`, `flank_s/stair_1`..`stair_5`, `flank_s/fallen_pier`; studies/wreck_cluster_art.gd FLANK_S) | A second layer under the crest on the spine's south flank: a broken terrace walk of coursed stone decks set against the flank's rock (each 2.6 m clear out from where the rock last stands over its top, `flank_s_out`, so the rock rises behind it as a wall), x 98.5 to 43, rising west 33.2 -> 38.0; the breaks filled by fallen blocks (two halfway up: hop, hop; two sunk 0.5: step down, then a 1.6 m jump-grab), so no gap opens onto the flank's rock below, whose facets hold a fallen walker in pockets far from anything. Joins the bench's west end (east), the pulpit (west: a broken stair of five blocks, 1.2-1.3 m each, 44.3 -> the pulpit's 45.6, so spot 02 is reached from below too and the podium has a way down), and the strip (a pier fallen from the strip's north rim at x 75.5 up onto walk_2, 12°, outside the runway's clear band; strip run still 99 m). A loop: strip, fallen pier, walk, bench, footbridge. Part spot 17 on walk_4 against the rock (tags lying, jammed; mass `flank`) | Walk, hops and grabs (all under GRAB_TOP). Checked, real input: bench -> walk -> stair -> pulpit and back; strip -> pier -> walk -> bench; dropped into each break, out again | No |
| North flank walk (`wreck_cluster/flank_n/walk_1`..`walk_3`, `flank_n/rubble_1`, `rubble_2`, `flank_n/stair_1`, `stair_2`; studies/wreck_cluster_art.gd FLANK_N) | The south walk's north run, built the same way (`flank_n_out`): three stretches of stone deck under the north shelf, x 65.8 to 97.2, falling east 37.0 -> 34.6 -> 32.6 from the north balcony (spot 04; 1.6 m down off its east rim), low under the rope chain's spur and slab (the slab's underside 3.3 m over the deck; a walk or a missed hop off the spur's end lands on it, 5 m, no stun), then a broken stair of two blocks (33.7, 34.9) onto the shelf by the cleft (x ~102, 36.1). Both breaks filled by a fallen block halfway (hop, hop). A loop: shelf, balcony, walk, stair, shelf. Part spot 18 on walk_3 past the slab (tags lying, jammed; mass `flank`) | Walk and hops (all under GRAB_TOP; back onto the balcony a 1.6 m grab). Checked, real input: balcony -> walk -> stair -> shelf and back; off the spur's end onto the walk; the rope chain unchanged (wc_ropes) | No |
| Caches (`wreck_cluster/cache_01`, `_07`, `_08`, `_09`: a pier in the cella, a buttress at the bench's east end, a wall on the tower rock's south-east lobe, a pier under the belfry's north face; studies/wreck_cluster_caches.gd) | Each deal hides 1 or 2 of the six parts inside them (the rest lying; cache spots never hold a lying part); the one-spot glint, a dust puff off a weak hit, the part stepping out of the rubble; N stands them all again and re-hides. A piece that hides nothing breaks to rubble | Slam with 2.6 m of drop or more (toughness 0.32; a hop's slam is 0.25 and only flares), or the side slam (0.65). Heights to slam from: the cella's walls (01, unchecked), the crest over the bench's end (07, about 5 m over its foot, unchecked), the coast rock's west edge for 08 (the coast down's way on: checked, drop 6.8, strength 0.66), and for 09 the belfry's outer stair: a jump off its east flight (x 147.5, y 37.7), sail 5 m north, slam (checked: drop 7.8, strength 0.74) | No |

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
  (Done in the look pass's third task: coursed ashlar on a rubble core,
  quoins, a string course, coping, a plinth course either side of the
  stairs, a broken parapet on the podium's east edge, fallen coping stones;
  collided on the same clean boxes as before.)
- The far silhouette is still a long low hull with a slim block at the east
  end. The tower alone won't fix it at the spine's 136 m length; the islets
  and the look pass must add height and mass so the cluster reads upright.
- (Review of iteration 6.) The rope's column and beam read as a plain dark
  gallows; make the rope hang from the ruin itself (a broken flying
  buttress, an arch's overhang, a jutting lintel of the colonnade).
  (Done in the look pass's second task: a broken flying buttress.)
- (Done in the look pass's first task: each land hangs its own rock,
  `Art.hangs()`: the strip a deep blade with four fangs, the tower rock a
  74 m root, the coast rock a stepped stack, the rope rock tiers, the tilt
  rock a flat-bottomed slab. Their own architecture is still to come.)
  The coast rock and the rope rock are both bare inverted cones with one
  arch. Later islets must not repeat that shape: vary the outline (a
  ledge-stepped rock, a slab tilted, ruin built down its side), and give
  each its own architecture.
- (User, after iteration 9.) Clean up the floating rocks and debris: the
  loose stones, hanging fragments and small rocks drifting round the spine
  and islets (including the colonnade's tail fragments and stepping stones
  where they read as clutter). Cut any that carry no route, spot or view.
  Ones that do (the tail fragments hold spots 08 and 10 and their caches,
  and the coast down's way on lands on the first) are either joined to the
  land or architecture so they no longer float alone, or their spot, cache
  and route move to solid ground; re-run the drivers of anything moved and
  update the spot table. This is its own look task, done early in the look
  pass, with the silhouette work.

## Spec change after the user played iteration 14

Do these two next, in this order, before L5 and L6:

1. **The slide is natural terrain.** (Done: a tongue of the tilt rock's
   own turf and rock; the entablature pieces `slide/upper`, `slide/lower`
   are gone.) The user found the entablature slide
   weird. Replace the slab (both halves, the head block and their dressing)
   with a natural slope of turf and rock, part of the land itself (a KitLand
   ramp or a sloped shelf of the rope rock / tilt rock, not a placed
   architectural piece). Keep what the slide does: it starts from the rope
   rock, the player slides or surfs down it to the tilt rock, it stays
   one-way (the iteration 7 notes say why: slide jumps climb steep slabs, and
   the ground pop within 3 m), and spot 15 and the bridge back stay
   reachable. Re-run wc_slide.
2. **The colonnade's flanks are walkable.** (Done: the south and north
   flank walks in the table.) The spine's sides are steep rock
   the player can only fall down. Give its flanks routes along them: ledges,
   narrow shelves, broken walkways or terraces, grabbable lips and short
   climbs that let the player walk and platform along the sides of the
   colonnade, not only along its crest and bench. They join places that
   already exist (bench, shelves, balcony, pulpit, the strip, the tower pad,
   the rope chain's shelf) so the flanks become a second layer of the
   playground, and can host part spots (renumber nothing; add new spots
   after 16 if any). The colonnade motif is shared code: build the flank
   routes in the study's own files, on top of the spine, and keep its own
   study and the aqueduct isle unchanged. Every flank route attaches at both
   ends (the spec's rule) and is walked through the real input path.

## Spec change: overgrowth on the isles' sides (user, after iteration 15)

The cluster should read as an ancient piece of the earth itself, torn up
and suspended in the air, not clean rock. Add overgrowth to the sides and
undersides of every land mass (the spine's flanks, the strip, the tower
rock, the coast, rope and tilt rocks): hanging roots and vines trailing
down the keels and off the rims (scripts/kit_isle/hanging_roots.gd exists;
see kit_flora.gd and kit_life.gd for what else is there), moss and turf
lips spilling over the edges, ferns, shrubs and the odd small tree clinging
to ledges and cracks, ivy on the ruin where it meets the rock. Heavier where
the rock is old and shaded, lighter on fresh breaks. Overgrowth is dressing:
it must not block or add collision to any route, ledge, grab lip or the
flank routes (re-run the drivers), must not grow over part spots or cache
glints, and keeps the strip's runway clear. Watch the frame cost (use the
existing multimesh/shader flora paths) and note the triangle count. This is
a look task: do it after the flank routes, alongside L5, before L6.

## Spec change: the shared grass carpet (user, after iteration 15)

(Done: `flora_site()` is `IsleFlora.carpeted(motif.flora_site())`, `_grow()`
calls `IsleFlora.calm(flora)`; `--grass-drifts` gives the old drifts.)

Grow the grass the way the aqueduct isle and the Olmec field do: the shared
carpet over all the turf. `studies/aqueduct_isle_flora.gd`
`IsleFlora.carpeted(site)` on the study's `KitFlora.Site` (see
`studies/olmec_field.gd` `flora_site()` and its `_grow()` calling
`IsleFlora.calm(flora)`), on every land mass in the cluster, the spine's
turf included. Reuse it, don't copy its numbers. Keep part spots, cache
glints and the strip's runway readable. Do this as its own small task next,
before the overgrowth: the turf colour task (L6) may then need less, or
nothing.

## Spec change: the overgrowth look target (user, during iteration 19)

The user judged the first overgrowth bad and gave a reference image:
`docs/design/wreck-cluster/look-reference.png`. Open it and match its
qualities (not its literal layout). In order of how much they matter:

1. **Keep the dark rock.** (User: the reference is for its overgrowth only;
   the rock colour stays as it is.)
2. **A moss and grass mantle draped over every rim.** The top turf spills
   over the edges as a thick green blanket that runs a few metres down the
   cliff faces, unevenly, heavier on ledges and in cracks.
3. **Vine curtains.** Dense clusters of leafy vines and ivy hanging off the
   rims and from the undersides, long and grouped, not single thin strands
   evenly spaced.
4. **Trees and bushes on the tops and ledges,** so every land mass has a
   leafy silhouette from afar (small trees, shrubs, ferns at the feet of
   ruins), kept clear of routes, part spots and the runway.
5. **Ruins grown in:** moss and ivy on the ruin's stone where it meets the
   ground and along cornices; the ruin stone reads light and mossy too.
6. Nice to have: one waterfall spilling off a rim into the clouds
   (scripts/kit_isle/kit_water.gd), and paving stones with grass between
   them on the main paths.

Rules from the overgrowth change still hold: no collision on routes, no
growth over spots or glints, runway clear, cost reported. Split this into
several look tasks (mantle and vines, then trees, then ruins); each one re-runs the route drivers and shows a still next to the
reference.
