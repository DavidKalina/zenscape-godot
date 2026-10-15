# The Haul-Way — "They never finished the delivery. The last slab is still on its way."
Lenses: ride/carry · mechanism+quarry · colossal · spread wide, a line · intact and still working (a counterweight rig on its old job) · quiet, then wrong
Slug: `haulway`

Pitch: You come out on the high lip of a quarry-cut shore and the far isle is a
hundred metres away across black air, a grey ledge with a green crown. Between
you and it two hawsers as thick as columns sag in a long curve, and a sledge
the size of a house, a single squared slab, is already sliding out along them,
slowly, with something small and headless standing on it.

Place: The near shore (A, 0 m) is a cut face of basalt: stepped quarry
benches, wedge marks still in the rock, a half-dressed slab left on its rollers
at the lip. A **haul-house** stands over the lip, two colossus columns
(`hall_column`) and a heavy beam (`hall_beam`) that carry the hawser
anchors, with the sledge's cradle under it. The two hawsers run out and down,
sagging to a **relay pier** (R, mid-gulf, -7 m), one lone basalt pillar
(`city_pillar`) with a capstan collar, and on to the far shore (B, -16 m), a
low green terrace with a matching haul-house, its cradle empty. A second
sledge rides the same cables the other way, up from B: the pair are
counterweights, one full and heavy going down, one light going up, and
they pass each other at the relay pier. The gulf is dark with a pale haze
floor; far pillar crowns hang in it. The stone is the city's weathered
basalt, the hawsers are carved stone cable (links of drum-stone, a rope of
rock slung loose), the grass is painted turf on B and bare quarry grit on A.

View on arrival (from the quarry lip beside the cradle, looking out and down):
the two cable curves converge on R, the sledge already underway small and
dark against the haze, B's green lip beyond, the passing second sledge a
speck coming up. The eye goes cradle, cables, sledge, pier, far green. You see
the whole crossing, and the ride before you take it.

Top (1 char ≈ 4 m, east is right; the cut gulf is ~26 chars):
```
  AAAAAAA                                    BBBBBBBB
 AAA^AAAAA  HH                              BBBB"""BBB
 AAAA#AAAA  HH===========o======R=========o===BBB"^"BBB
 AAAAAAAA   cc          s>        <s       cc BBBBBBBB
  AAAAA     HH=====================#======   BB""""BB
   AA           ~~~~~~~~~~~~~~~~~~~~~~~~~~
        ~~~~  (gulf, 96 m wide: 24 chars)  ~~~~
                  P  (a drop-ledge shelf under R: the kept route)
H haul-house   c cradle   = hawser (two, 6 m apart)   s sledge   > < direction
R relay pier   o Olmec   # stone   " growth   ^ rim in
```
Side (the span, A left, B right; each char 4 m across, 1 row ≈ 3 m):
```
 A 0m  HHH
  ####|   \__ hawser sag
  ####|      \_________           R  -7m
  ####|  [s>]          \____  __ _|#|__   <s]
  ####|                        \_/       \____
       ~~~ void, 80 m to the haze floor ~~~    |B -16m
```

Play:
- **Route 1, ride the sledge (the clean way).** The sledge stops at the cradle
  on a timetable (a pawl clunks, 8 s dwell, a visible tell: the cradle's stone
  chocks drop). Hop on over a gap the size of a plain jump, then stand on a
  deck wide enough to run on: 8 m long by about 4 m wide (a wanderer is ~2 m
  tall; scale it with `WorldScale.wanderer`). It rides at 3 m/s, under walking
  speed (WALK 2.4, RUN 4.8 in `pilot_motor.gd`), so 100 m takes about 35 s. That
  is the quiet beat: the view, the wind in the cables, the second sledge
  coming up on the other cable, passing the pier. Walking forward on the deck
  lets you drop onto the pier early (R's top is 1.5 m above the passing
  deck) or hop across to the passing sledge.
- **Route 2, the cable walk (platforming, fast).** The hawser links are fat
  stone drums (wide as a wanderer is tall). Step out of the haul-house onto
  the near hawser's first link and run its back: a rail slide, the pilot's
  slide on a curved line, and a tilt of 8 to 14 degrees, steeper than
  the viaduct's 4.5 degree run-up. A slide speeds you to about 9 m/s down
  the sag. Past the relay pier the cable rises again, so the slide dies on
  the climb and you must hop to the pier (R is lower than the cable's lowest point by
  a pier-top step you chain-jump, `GRAB_TOP`) or jump to the sledge. Falling here
  drops to the haze floor: a death.
- **Route 3, the counterweight.** Standing on the empty sledge going UP is the
  slow tough way: it lifts you back to A. The player who falls onto the
  relay pier's shelf (P, 3 m under R) rides the passing sledge up or down by choice.
  Going down the second time is a retreat, not a failure.
- **What the player chooses between:** the slow safe ride (but Olmecs board),
  the fast fragile slide, and the third: timing the pass at R to change
  sledges mid-gulf, a hop of ~2 m between two decks moving opposite ways at a
  combined 6 m/s, an easy jump if you leap early and a missed one if late.

Threat: **Olmec riders and a heavy rig.** Headless bodies (`scripts/enemies/headless_body.gd`)
haul themselves up the cable's hanging slack and over the sledge's lip
mid-gulf, the way they climb ledges today (`climb_max`, `leap_max`, `jump_gap`
knobs). One waits on the relay pier's capstan; as a sledge passes it vaults
aboard (a leap from a fixed ledge onto a moving deck, a cue: its windup, then
the leap, `pounce_*` knobs). On a deck it shoulders you off the edge: a
`knock` along the deck's lateral. The deck has a low lip on the drop side (0.5 m, a
curb the pilot can hop), so the fight is always where the edge is. Also the
rig itself: at the dwell's end the sledge sets off with a jolt (a `toss`
of the unseated, small, 2-3 m/s) and at the relay pier a **fender block**
swings out to catch the passing deck's edge: stand at the rail wrong and it clouts
you (`knock`, source `haulway_fender`). As a tool: the Olmec that boards
can be shouldered off by the same lurch, or lured to the deck's rim and
dropped by a twirl; the fender can throw a stunned body onto the other sledge.

Could combo:
- A headless body mid-leap onto a deck meets the jolt of the pawl release
  and lands stunned: the pilot gets its seat.
- The fender clouts you off sledge 1 and the passing sledge 2 is
  moving the other way under you, so you land on its deck (catches: tumbling,
  riding). It carries you back up to A, free.
- A pilot slid down the cable and flung (`toss`) by the capstan collar meets
  the sledge's deck, and the Olmec is already there.
- Ports: catches a body thrown from an adjacent isle (a cannon or a spat
  head from A's quarry) that arrives on the deck; throws a rider off the
  far end at the dock with the dock's arrival jolt (a low `toss` of 3 m/s, not stunned).

Mystery: What the makers hauled and where. The slab on the cradle is dressed
with a face's brow on its under side, half-carved: a great stone head, sent in
pieces. Runes on the haul-house beam count slabs (the tally goes up to a number
and the last notches are fresh). At B's cradle the sledge's load does not
come off; it has been unloaded a thousand times. Where the heads go, the player
pieces together later in the city (a link to `motif-face`).

Kit used (verified in code): `hall_column`, `hall_beam`, `hall_slab` (RuinKit hall
family, `scripts/ruin_kit.gd` HALL_PIECES); `city_pillar`, `city_causeway`
(CityKit.PIECES, `scripts/city_kit.gd`); `city_lip` (Hauling lip, `city_kit_climb.gd`);
`colossus_drum`, `maker_felled` (`city_kit_breaks.gd`); `aqueduct_end`
(`scripts/ruin_kit.gd` AQUEDUCT_PIECES); `trap_logs.gd` (the carry-by-surface
pattern, `motor.carry`); `scripts/rope_bridge.gd` (cable sag sim, as reference
only); `scripts/kit_isle/airship_ferry.gd` (a body moved with its collider, the
moving-deck pattern).

Kit asks:
- `haul_sledge` (a moving deck on a path: the airship_ferry's moving-body trick on a spline, carrying the pilot with `motor.carry`, with a dwell and a tell).
- `haul_hawser` (stone cable of drum links with a sag, walkable on its back, slideable).
- `haul_fender` (a swinging stone block as a knock source).
- Headless-body ask: board a moving deck from a ledge, and stay on it (ride-aware movement).

Family knobs:
- `span`: 72 to 120 m (gulf width; at 120 m the relay pier is two).
- `drop`: 8 to 20 m (A above B; the sag and the slide speed follow).
- `rig`: "counterweight pair" (default) or "single, one-way" (the sledge runs once; you wait at B for a sledge going up).
- `riders`: 0 to 3 headless (and a cargo head on the sledge, rare).

Sockets: rim in on A (facing the gulf), rim out on B (facing back), arena on the
sledge deck (as it moves), perch on the haul-house beam and the relay pier's
capstan collar, cover under the haul-house colonnade.

Generator fit: a crossing between two places (an edge) is the best fit: A is
the previous place's exit, B the next one's entrance. Footprint is a long thin
band, 100 to 130 m by 30 m, falls 8 to 20 m. It suits the "spread wide" and
"line" layer shapes, and gives the "islands far apart" feel by itself. Uses
no sprawl isle (its two shores are small and each is a tiny arrival terrace).

Distinct from: **the Serpent Crossing** (same ride-across verb, but that is a
living, sacred animal on a loop with no way to walk the road itself).
The Haul-Way is dead machinery and stone, on a straight line, with a tilted
cable you can slide, and it comes with a platforming alternative. Not the
viaduct either: that's a fixed span. This one moves, and you are cargo.

## Place (round 4)

Yard: `python3 tools/smoke.py studies/motif_yard.tscn -- --motif=haulway`
(add `--underground=haze` for the city look; `--no-olmec` drops the two
Olmecs; `--haul-at=S` starts the cycle S s in, default 14 s so both sledges
are already out when he arrives). Code: `scripts/kit_isle/greybox/gb_haulway.gd`
(one LAYOUT table) and `haulway_sledge.gd` (the machine). Registry: MOTIFS and
WORLD "under".

**The place.**
- A: a turf shore cut by a quarry pit. Its benches, a set-off each, step down
  in arcs from the rim in (16 m over the cradle) to a slot at the lip. Two
  half-dressed slabs lie on rollers, with wedge-split blocks, felled drums
  and stelae.
- A rib of uncut rock (the haul road) runs along the pit's north side to the
  north anchor.
- The haul-house is down: its beam broke and its two halves lie on the
  shoulders. Each hawser anchors into its own drum column with a capital,
  so from the rim in the hawsers run out over the gulf between the columns.
- Two drum-link stone hawsers, 15 m apart, sag 108 m to B's lintel.
- A sledge hangs 7.5 m under each hawser on one mast. It is a 14 x 8 x 3 m
  basalt slab with a keel, a curb on its long sides and a lantern; the
  down-going one carries a dressed block with a brow.
- The relay pier stands between the hawsers: a capital 1.2 m over the
  passing decks, a capstan, and a stepped root widening into the haze.
- B: a low turf terrace with a knoll and a lit beacon. Its slot steps up
  east in set-offs.

**Routes.** All walked through the real input by `scratch/haulway_routes.gd`,
rim in to rim out; all pass after the resize.
- *Ride*: down the benches, hop the 1 m gap onto sledge 0 while it waits, ride
  30 s, hop off at B, up the slot's steps to the rim out.
  - He is carried by the motor's own moving ground
    (`PhysicsGround.mark_moving` on an AnimatableBody3D, `motor.mover`).
  - His feet drift at most 0.058 m on the deck.
  - He jumped off mid-gulf and landed back on the deck, still carried.
- *Slide*: round the rim, along the rib to the north anchor's capital, onto
  the hawser's back, crouch. This is the motor's slide on a narrow slope.
  - It reaches 12 m/s and dies at x 83, the sag's low point.
  - From there he walks the back up to B's lintel, then down B's shoulders.
- *Relay*: ride sledge 0. As the two sledges pass, hop up onto the capital,
  then down onto sledge 1 going back up. Ride it home to A (the retreat).

**Threat** (set loosely):
- STAND-IN: a whole Olmec waits on the pier's capital; another walks B's
  cradle. They use the Lamplighters' Keeper beat, chase on. The headless
  body can't ride a moving deck; `headless_body.gd` is untouched.
  - The pier Olmec chased a rider at the inner edge and swatted him.
  - In a later run it inhaled him (suck, gulp, spit).
  - It never pounced onto a deck.
- The fenders (built here): a stone arm on an upright pivot each side of the
  capital's middle.
  - It shivers, swings out across a passing deck's inner half and holds
    while the 14 m deck slides through.
  - An inner-edge rider gets `knock` 3.5 m/s outward, 3 up. Checked.
- The jolts:
  - Setting off, a stunned rider is thrown on (a toss, still stunned).
  - Docking, a standing rider gets a 3 m/s toss toward the shore.
  - The chocks drop 2 s before departure (the tell).

**Real vs stand-in.**
- Real: KitLand land, the motor's carry, crouch slide, knock and toss, and
  the city's fires.
- Built here as stand-ins for the kit asks: `haul_sledge`, `haul_hawser` and
  `haul_fender`, drawn in GiantStone basalt.
- STAND-IN: the yard's `motor.mover`/`soft` wiring, copied from the Serpent
  Crossing. The fix belongs in `studies/kit_isle.gd` `_build_pilot`.
- STAND-IN: the Olmec riders.
- Left out:
  - The slab tally: GiantStone's runes glow, too bright for the city.
  - P, the shelf under R: built, it would be a dead end.

**Distances changed from the card:**
- Drop: B 17.1 m under A's cradle (card 16). The pier's capital is at -12.8
  (card -7).
- Gulf: 100 m lip to lip; 84 m between the docked decks' middles.
- Hawsers 15 m apart (card 6), to fit the pier between two 8 m-wide hanging
  decks.
- The sledges hang under the hawsers (the card has them slide along), so
  the hawsers' backs stay clear for the slide.
- Speed: 3.2 m/s cruise, 0.8 m/s² ramps. 30 s across, 8 s dwell, a 76.5 s
  cycle.
- Hawser tilt: 26 to 28° at A, about 11° at the pier, flat at x 84, then
  about 7° up to B (card 8 to 14°). It must pass SLIDE_FROM 10° near A to
  carry the slide.
- Slide top: 12 m/s (card about 9).
- Deck change: deck to capital to deck, 0.5 m gaps (no direct deck-to-deck
  hop with the pier between).

**Read of the stills** (`captures/shots/haulway/`, `--underground=haze`):
`r3_own.png` (the play camera at the arrival), `r3_rim.png`, `r3_lip.png`,
`r3_three.png`; reference `ref2_lamplighters_three.png`.
- From the arrival, the first read past the pit is the two anchor columns,
  the hawsers running out, both sledges near the pier with the Olmec on the
  capital, and B's beacon.
- Lamps carry the line in the haze: the north anchor, the pier, the sledge
  lanterns, B's lintel and beacon.
- Still less land than the Lamplighters' Stair: two shores and a machine
  against one big hillside.
- A's south benches read a little like contour slices. The sledges read as
  heavy slabs from the lip, smaller from the rim.

**Model budget** (`docs/art/model-budget.md`). About 21k triangles stand
still: hawsers about 16k, pier about 1.9k, houses about 2k, stones about
1k. The machine moves about 1.6k.
- Import LODs and visibility ranges apply to the hawsers. One far tube per
  hawser past about 60 m would cut about 11k triangles, roughly 0.1 to 0.2 ms
  a frame (estimated).
- Silhouette geometry applies and is used: drum links, chipped and fallen
  beam.
- Vertex-colour grime is already used.
- Parallax, bones, and sculpt-and-bake don't apply.

## Polish (round 4)

A dressing pass on the Haul-Way, in place in
`scripts/kit_isle/greybox/gb_haulway.gd`. `--haul-grey` builds the grey
boxes instead, for A/B. It is not in the yard's `--grey` table
(`studies/motif_yard.gd` GREY_FLAGS, `tools/harness/chain.gd`), so pass the
flag itself. The machine (`haulway_sledge.gd`) and the `motor.mover`
rewiring are unchanged; only the machine's numbers in LAYOUT moved. One new
kit file: `scripts/kit_isle/hanging_roots.gd`.

**The gulf, longer and deeper.** The user's read was that the isles were
not far enough apart.

| | Before | After |
|---|---|---|
| Lip to lip | 100 m | 140 m (A 4 to B 143.4) |
| Docked decks' middles | 84 m | 124 m |
| B's cradle under A's | 17.1 m | 24.1 m |
| Pier (x, capital) | 54, -12.8 | 74, -19.3 |
| Hawsers | 108 m, sag 9 | 148 m, sag 12 |
| Ride | 3.2 m/s, 30 s, cycle 76.5 s | 4.0 m/s, 36 s, cycle 88 s |
| Slide | 12 m/s, dies at x 83 | 12.2 m/s, dies at x 107.9 |

- The hawser tilt keeps its shape: 27° at A, 11° at the pier, flat at
  x 118, then about 7° up to B.
- The slide still carries well past the pier. After it dies, he walks
  about 40 m up the back to B's lintel.
- B's lip was pulled to x 143.4, a 0.4 m gap from the docked deck. The
  motor drops a walker into any crack, so it is a hop.
- B's Olmec walks the terrace (x 159-164) at its own ground. On the
  cradle floor it spawned inside the shoulder and fell, a bug that was
  there before this round.

**A, a quarry-cut headland.**
- Every bench line and every step of the shore's fall wanders on its own
  (`_cut`). Benches pinch into double cut faces and widen into shelves.
- In patches a line is gone: a bench has slumped into the one below,
  leaving a cross step where the patch ends.
- Some faces have slumped to rounded scree.
- Each bench's lip, and the rim's lip over the pit, is rounded over in
  turf (`pit` knobs).
- Four rough spoil heaps (`spoil`) with rubble on them.
- A great half-dressed slab is sunk where it slid across two benches, its
  rough end unworked.
- Three wedge-split blocks, their wedges still in the split.
- The grass is thicker (`tufts` 6).
- I tried rounding the turf at the void's edge and dropped it: it made
  dark notches where the hanging sides meet the turf.

**B, a low green terrace worth arriving at.**
- The shoulders are held low (`low` 3 set-offs), so B's lintel stands on
  its two columns. From the docked deck the terrace opens past the empty
  cradle.
- Two more knolls.
- The delivery, laid out on the turf: five dressed pieces of a great head
  (brow ridges), brow to chin, with one place empty. The last slab is
  still on its way.
- The beacon tower's blaze is replaced by a dim cresset on a two-course
  plinth on the knoll.

**Wear and story.**
- Hawsers: about 22% of the drum halves are spalled (smaller, nine faces,
  a paler fresh break). Moss sits on their tops (GiantStone's up-face
  moss).
- The pier's capstan collar is in eight stones: one has fallen out and one
  has slumped. One spoke is snapped short (its stub lies on the capital)
  and one is gone.
- Roots (HangingRoots, one MultiMesh) hang from under both shores' turf
  lips, the capital's ends, the collar and the stepped root into the haze.
- Lamps are dim, warm crown cressets (beam 1.5, was 2.4).

**Routes.** All were walked through the real input in the yard
(`scratch/haulway_routes.gd`, `scratch/haulway_chain.gd` with chain.gd
jitter of ±0.5 m), with `--no-olmec`.

| Route | Result |
|---|---|
| Ride | 5/5, carried 36 s, his feet drift 0.072 m, the jump off and back on mid-gulf holds, off at B to the rim out |
| Slide | 5/5 |
| Relay | Passes: deck to capital to sledge 1, carried home (drift 0.076 m) |
| Fender | Knocks an inner-edge rider |

- With the Olmecs on, the ride now fails 0/3 (before this round: 3/3).
  About 15 m past the pier, the pier Olmec's worn head locks on (tell,
  inhale) and pulls the rider in the open outer lane off the deck. With
  only B's Olmec, the ride passes.
- This is the stand-in threat landing harder on the longer, lower run, not
  a geometry fault. Tune it (the head's `worn_reach`, or cover on the
  deck) or keep it as the ride's price.

**In a layer.**
- `run_layer --world=under --shape=sprawl --seed=1 --knob=greybox=haulway`
  places it (isle 5, greed). The layer smoke is clean, and the motif and
  its machine stand (fenders swing).
- I could not walk a route there. Under `drive.gd` the walker never ticks
  in an underground run_layer: he takes no stick, and a deck leaves from
  under him. The Lamplighters' Stair (seed 3) does the same, so this is a
  harness gap, not this motif's.
- Plans: sky plans are byte-identical. Underground plans move wherever the
  Haul-Way is drawn, because its footprint is 40 m longer. Ring seed 3 no
  longer fits it, and drops it.

**Stills** (`captures/shots/haulway/`, `--underground=haze`):
- Before: `p0_three`, `p0_lip`, `p0_rim`, `p0_own`.
- After: `p6_three`, `p6_lip`, `p6_rim`, `p6_own`, plus B from the deck
  (`p6_b`), B from above (`p6_bhigh`) and the pit's south side
  (`p6_south`).
- Reference: `ref3_lamplighters_three`. Side by side:
  `sheet_before_after.png`.

What the stills show:
- The three view now reads as a long sag to a far, low shore.
- B reads as a turf terrace with a colonnaded gate, a lamp on its knoll
  and the head laid out.
- Close up, the pit reads as broken quarry benches.
- From the arrival camera the south benches' faces still read as dark,
  shard-like slivers (KitLand prisms seen edge-on). That is the weakest
  view left.
- The white puffs in some stills are the stand-in Olmecs' dust.

**Model budget** (`docs/art/model-budget.md`; the yard, headless):

| Part | Before | After |
|---|---|---|
| A's land | 17.6k tris, 15.1k shapes | 16.1k tris, 13.3k shapes |
| B's land | 6.1k tris, 3.5k shapes | 4.9k tris, 1.9k shapes |
| Hawsers | 16.3k tris | 21.6k near tris in 17.6 m runs, plus 2.8k of far tubes |
| Stones | 1.0k tris, 19 shapes | 3.0k tris, 41 shapes |
| Roots | none | 6.4k tris (128 strands, one MultiMesh, no shadows) |
| Pier | 1.9k tris | 2.0k tris |
| Machine | 1.6k tris | 1.6k tris |

- Import LODs and visibility ranges apply and are used. Each hawser run
  swaps to a 7-sided tube past 70 m. At the arrival that draws about 8k
  hawser tris where 16k drew before (estimated at about 0.1 ms a frame).
  Roots are faded past 140 m.
- Silhouette geometry applies and is used: spalled drums, the broken
  collar, the snapped spoke, split blocks, the slab's rough end.
- Vertex-colour grime applies and is used (GiantStone).
- Bones, parallax and sculpt-and-bake don't apply.
- Build: 625 ms before, 1.0-1.2 s after, headless on the Mac;
  `build_cost` is now 1000. Most of the growth is A's ground function (the
  wandering bench lines) under KitLand's cliff probes. That is motif
  GDScript in the kit's callback; a cached height grid or a kernel would
  win it back.

**Unverified.**
- Routes in a generated layer (the harness gap above).
- Haze vs torch differ only in stills, and I shot haze only.
- No tests were run or added (prototyping). No existing test is known to
  depend on this motif's numbers.
