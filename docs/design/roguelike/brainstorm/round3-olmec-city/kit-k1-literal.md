# Kit K1: the city, literally (round 3 brainstorm, lens LITERAL)

**The family `city`** (proposed scripts/ruin_kit_city.gd, ids `city_*`): the
things the user named, built the way the Olmec's makers would. It builds on
round 1's `makers` family (kit-k5-makers.md: CELL, SET_OFF tiers, talud under
band, `mounts`/`catches`/`throws`, `carom`, `maker_*` sources). `maker_tier`,
`maker_palisade`, `maker_throne`, `maker_stela` and `maker_head` stay as the
small-scale and dressing pieces. This family is the **big architecture**
those pieces sit in, and sized for him first.

## Rules that every card below keeps

- **Two scales on one piece.** Heavy weathered basalt, rune grooves, talud under
  tablero, stepped massing, shaded by `shaders/olmec_stone.gdshader` (same
  quarry as the head and body). Every piece has a *body lane* sized for the
  headless body and a *walker line* (a rail, a ledge, a slot) sized from the
  pilot, so the two never fight for the same stone.
- **His numbers** (layer-round11): 4.4 m wide, 2.4 deep, neck 6.7 m up, `step`
  1.23 m (a riser under about 2 m per 2 m is walked), shockwave on every
  landing (`shock_r` 4 Hh), `jump_gap` / `leap_far` about 22 m, `grab_up`
  15 m. Therefore: body lanes are **at least 5 m wide, landings and tops at
  least 6 x 6 m, roofs and lintels over a lane at least 7.5 m clear**, shelves
  under a rim **at least 6 m or under 2 m**, and every ledge a drop can reach
  has a clear drop side to broad ground. A walker-only piece is tagged so his
  reads skip it (the "body ground" group the round-11 doc asked for).
- **Pilot numbers**: tiers `SET_OFF` 1.6 (one jump catches, under `GRAB_TOP`
  1.875), a pump reaches `CHAIN_TOP` 2.575, standing room `STAND`, walked tops
  `TOP_ROOM`, module `BAY` 4.4. Flown openings do not exist underground (no
  plane), so no `WorldScale.opening` widths are used. Slots are in pilot
  terms (a kick chimney, a crouch-slide height).
- **How things break.** From olmec-destruction-round1: scripted breaks, not
  voxels. A piece builds as its own unit when `breakable` is on, and breaks at
  a seam into Jolt `RigidBody3D` pieces (mass from volume, friction 0.9),
  settles to static rubble in 0.25 s or 2.5 s, then merges (`RuinKit.merge`).
  He is stopped only 55% for 0.5 s, and standing breakables are air to his rays
  (`_skip`) so he plows. Settled rubble is ground to him and to the planner
  (`BodyRoutes.forget`). The cap is `MAX_BODIES` 24, past which a piece lies
  where it would land. **Each card says what its seams are and what the rubble
  leaves** (always a new route or a closed one, never just mess).
- **Rune serpent.** It is 90 m long and 4 m through. It threads the city. So
  any arch, hall aisle or aqueduct bay meant for it is at least 6 m clear and
  8 m high (a knob on the piece, off by default). Its coils can rest on a
  pyramid terrace. It is the only thing that ever sits on the stone and is not
  made of it.
- **Light reads.** In a brown-grey haze only the silhouette survives, so each
  piece has one signature outline (stepped triangle, row of pillars, bowl
  rim, repeating pier shadows). In torchlight, bracket points (`torch`
  mounts, a wax candle can sit on one: Mudge's beacon) light the talud and
  leave the tablero in shadow, so the stepped massing reads as bands of
  light and dark.

---

# Causeway aqueduct (city_aqueduct, family city)
Verb: run the long way from isle A to isle B; walk the channel lip; drop
inside a pier's niche to hide; hang from a corbel under the deck.
Look: a heavy stone water-channel carried on **stout battered piers** (talud,
not tall thin arches) with **corbelled openings** (each stone course stepping
in, the Mesoamerican false arch), not the gothic round arch. The deck is
a broad slab with a **sunk water trough** down its middle, its lips carved as
a running band of grooves (a frieze of linked glyphs). The pier faces bear
a flat tablero panel with a worn face. It reads at range as a **comb of
shadow**: a long dark bar over a row of identical wedge-shaped shadows. At
its end the trough spills out over the edge into the abyss as a thread of
water falling into haze. Weathered, the deck is cracked and root-split; spans
sag; one pier is just a stump. Variants: `span` (one bay of deck on two
piers), `two_tier` (a lower channel under the upper, the pair a kick chimney
for the walker), `end` (the spillway mouth, with a carved maw), `broken`
(a span fallen flat with its far end hanging off a pier).
Behaviour: static. Optional: water flows in the trough (a shader flow with
a `current` vector); a `gate` slab in the trough can be raised or lowered
by a rune set (state change).
Size: deck 6.6 m wide (4.4 + 2.2): central trough 2.2 m wide and 0.7 deep,
two lips each 2.2 m. **His lane is the whole deck** (6.6, over the 5 m rule;
the trough is under his 1.23 step, so his feet span it). The walker's line
is the lip, 2.2 m, with room for a run. Bay length 3 BAY = 13.2 m (a jump
clears a short gap; the span between piers is 2 BAY of corbel opening, 8.8 m,
tall 7.5 m so he walks beneath on lower floors and the serpent can pass at
the `serpent_bay` knob). Deck height over the pier foot: 3, 4 or 5 x SET_OFF.
Piers are 3.2 x 3.2 m on plan at the foot, battered to 2.4 at the top.
Collision: deck lips and trough floor as clean walk boxes (the trough floor
a lane, 0.7 below the lip, so a wall to hug and a stair-less step up
of 0.7 under `STEP_UP`... the lip is a **climb** at 0.7 m, passed by a hop).
Piers: plumb boxes with a sloped talud hull (kickable band above the
talud). Corbel steps: clean stepped hulls, grabbable from below (each course
SET_OFF or less), so the pilot can climb the underside of a bay from pier to
deck. Tagged **body ground** (he walks it).
Motifs it enables:
- A causeway from a cliff-top gate to a distant pyramid isle: the main
  A-to-B line of a layer, with a gap between spans left as a jump.
- A tiered aqueduct stacked over a gorge, upper deck for him, lower
  channel and corbels for the walker.
- A flooded junction: the trough feeds a pool on a court's floor and is the
  reason the court is wet.
Threat pairing: the deck is a bridge and a funnel in one. He walks it with
his shockwaves, and his pounce landing on a deck sends the wave along the
trough. A pilot on the lip is in the lane of the wave (his `shock_air`
0.45 m jumps it) and a trough gate raised to wall the lane is the tool that
hides the pilot.
Catches / throws:
- *Standing*: lips and trough are walked; a trough with flow carries a
  standing body along its current at about 2 m/s (a gentle ride, a `push`
  not a `toss`).
- *Airborne*: the deck (6.6 m) is a catch pad. Corbel steps catch a hanging
  grab from below.
- *Tumbling/stunned*: a body landing in the trough is held by its two lips
  and carried by the flow along the deck's line toward the spillway. With the
  gate lowered, the flow gathers and it is a **flush**: `toss` along the
  trough at about a sluice's speed, source `sluice` (the existing trap's
  name) so it chains from the aqueduct's own flow; the `end` piece's
  spillway throws a stunned body off the lip out over the abyss at the
  trough's speed (a `rim` throw, still stunned) toward the next catch pad
  (the generator aims it by placing the piece).
- Aimable: the trough runs in the piece's +Z frame; the generator aims it
  by where it puts the piece.
Breaks: **seam at the pier head.** His shockwave or body topples a pier
(leaning and falling the way he pushed); the two spans it carried drop on
that end and hang (a ramp) or fall (a gap). The trough water spills over the
break as a fall (visual only). Rubble: the fallen span lies as a **ramp
between the deck and the floor below**, a route down, or, if the far pier
holds, as a leaning slab bridge. A shockwave through a corbel opening breaks
courses loose to leave a broader gap (the serpent's door).
Chains with: the sluice (the gate and the trough are one trap), the wind
blaster (a `mouth` in the end maw blasts a stunned body down the trough), the
inhaler head (pulls a body along the deck), city_pyramid and city_stair (the
causeway lands on their landings), the rune serpent (passes through a bay or
coils a pier).
Build cost: **med, procedural.** Deck, trough, pier battering and corbel
courses are all `Build.solid` plane cuts, like the gothic aqueduct family
(RuinKit already has `span`, `two_tier`, `broken`, `stump`, `end`; this
re-skins them in basalt and corbels, so it reuses their joins). The glyph
frieze is shader work. Breaking is the destruction branch's code (a pier seam
and a span-halves seam); flow is a shader plus a small push volume.
Model budget: silhouette geometry (chipped lip, ragged stump), about 30
tris per pier. Vertex-colour grime and occlusion in COLOR.a, free. Parallax
depth for the frieze, roughly 0.1 ms. Merged rows (`RuinKit.merge`): a
20-bay causeway can be a handful of draws. Import LODs and visibility ranges
strongly apply (a long repeating row seen in haze can be a box with baked
texture past 60 m). Sculpt/bake and rigid parts don't apply.

---

# Pyramid stair (city_stair, family city)
Verb: climb a long way up (run, hop, rail-slide the balustrade), cross a
landing, slide or tumble back down.
Look: **the epic staircase**: a broad flight rising in short runs between
**landings**, flanked by two sloped balustrades (alfardas) that are not rails
but **a stone serpent's body running down the cheeks**, its head at the foot,
mouth open, scales as grooves, tail at the top (Mesoamerican practice, and a
kin of the rune serpent in miniature, wearing the same stone). Between
flights the landing is a flat slab with a sunk glyph panel. Risers carry a
running band of faces. A glance from far reads as a **dark ladder cut into a
triangle**, with the paler serpent edges drawing the climb in haze.
Variants: `flight` (one straight run), `landing` (a corner slab), `switchback`
(a flight, a landing, a flight turned back), `broken` (a flight with the
middle gone, the upper flight hanging free), `hung` (a flight with no mass
below, a stair floating on one pillar).
Behaviour: static. Optional: the serpent's eyes carry the Olmec lock-on glow
when he is near (the same ease, 0.6 s).
Size: flight width **6.4 m** between the cheeks (over his 5 m rule, so he can
walk it), each balustrade 1.0 m wide sloped on top (so total 8.4 m). Landings
**8 x 8 m** (over his 6 x 6). Riser 0.4 m, tread 0.8 m (a grand shallow
stair for him; the pilot runs it at pace). A flight is 8 risers (3.2 m, two
SET_OFF), so a **landing is a place the pilot can hop onto a rim** with a
single jump from the flight below, and every second flight a higher
landing (a 6.4 m rise, three tiers). Height of the full stair: 5 to 9 flights,
19 to 29 m. The stair is for him *because he is told to come up it*, not
just a dead end.
Collision: treads are clean walk boxes (one box per flight on a ramp
shape, not per tread, so the pilot's feet find a single sloping hull of
0.5 slope: walked as an incline under the floor angle). Landings: clean
boxes. Cheeks: balustrades are sloped hulls (rail-slide, SLIDE_AUTO) and
a plumb back face the walker can kick off. The foot's serpent head is a
plumb hull with an open mouth (a niche 1.4 m: crouch cover). The `hung` stair
has a drop on both sides, to broad ground below within 22 m (his drop rule).
Motifs it enables:
- A grand climb as the face of a pyramid isle, taking the player from the
  abyss floor's ledge to the summit shrine.
- A stair "river" you can slide down: a serpent's back as a rail slide,
  the whole length of the flight, into the landing's catch.
- A stair that has been cut and bridged by an aqueduct, so the climb is two
  levels linked (a route choice).
Threat pairing: the stair is a lane for him, and **a long open line that
gives no cover**. A pounce landing on a flight shears its treads into a slope
(see Breaks), and his shockwave runs up the stair in one straight line. The
pilot rail-slides the balustrade clear of the wave.
Catches / throws:
- *Standing*: treads and landings are walked.
- *Airborne*: landings (8 x 8) are catch pads; the balustrade cap catches
  a grab.
- *Tumbling/stunned*: a body falling down the flight tumbles to the next
  landing and stops there; each landing is a short drop (3.2 m, under the
  6 m fall stun, so no extra stun) so a fall down the stair is a cascade
  that sends a body one landing at a time, **a long way down but with a
  stop at every flight**. Sloped balustrades shed a body outward off the
  cheek (a rim throw, plain slide, aimed by the stair's facing).
- *Riding*: a log or tumble block on the flight (`run` mount) rolls the
  whole length and bumps off the landing; the open serpent mouth at the foot
  is a `mouth` mount for a wind blaster aimed up the stair (a cannon with
  the stair as barrel: blast a stunned body up two flights, still stunned).
- Source name: `city_stair` for balustrade throws.
Breaks: **seams at each flight's midpoint and at the landing's slab joint.**
His pounce (or a shockwave) on a flight shears its middle: the lower half
slumps into a ramp, the upper half hangs (a 3.2 m gap, a jump or a grab, and
he can leap it). A landing's slab breaks into four quarters; they drop
and tilt, leaving a **6 x 6 m rubble field** (still his, and walker-hoppable).
Balustrade pieces topple outward and fall as rolling logs that can ride the
flight below. Rubble opens a *route down* (the ramp) and closes the original
lane (the hung half).
Chains with: the wind blaster (the serpent mouth), the tumble run
(the flight is its track), the seesaw (on a landing), the inhaler head
(pull from the summit), city_pyramid (the stair is its face), city_aqueduct
(lands on its landing), maker_stela (flanks the foot).
Build cost: **med, procedural, with one small model.** Flights, landings and
balustrades are `Build.solid` cuts reused from the gothic `grand_stair`
(RuinKit already has `grand_stair`; this makes it wider, with landings sized
for him, and a serpent cheek). The serpent head wants a small Blender model
(a static head, no rig, 2-3k tris baked), reused on every stair.
Model budget: sculpt high, bake low for the serpent head (3k tris against
20k+, saving about 17k tris per stair). Scales and grooves by the shader
(CUSTOM0/1, the serpent's `rune_cut`), better than modelling. Silhouette
geometry for chipped tread edges. Vertex-colour grime and COLOR.a occlusion
at the riser creases, free. LODs and merged flights (a six-flight stair merged
to two draws) strongly apply. Rigid parts and parallax don't.

---

# Sundered hall (city_hall, family city)
Verb: run a nave, hide among the pillars (walker slots), kick up a pillar
slot, cross the crack on a fallen roof slab.
Look: a **hypostyle hall of squat square pillars**, flat roof slabs laid
beam-to-beam (no vault, no pointed arch), carved with a vertical band of
stacked glyphs and a worn face at the capital. The roof is a stone
**lintel grid**; light shafts down through gaps where slabs have slid. It is
**sundered**: a clean crack through the hall splits it into two halves; one has
drifted and dropped so the floors differ by `SET_OFF`. Pillars on the crack
edge are cut clean and their roof slabs hang over the void. Seen far off:
a **long dark box on a row of pillars, split by a lighter fracture**.
Variants: `nave` (3 rows of pillars, a lane between), `crack` (the sundered
variant, with the offset), `ruin` (roof mostly fallen, pillars standing),
`court` (a hall with a roofless middle).
Behaviour: static; breakable (see below).
Size: pillar 2.2 x 2.2 m, 4.4 m high to the roof slab's underside on the
**side aisles**, and the **nave raised, 7.8 m clear** (over his 6.7 neck).
Pillar pitch 6.6 m along a row (1.5 BAY); the nave between the two inner rows
is 5.6 m clear (over his 5 m), the side aisles between an inner and an outer
row are 1.8 m clear, a walker slot too narrow for him (and a **kick chimney**:
two plumb faces 1.8 m apart). Roof slabs sit on the pillars at 4.4 m (aisles)
and 7.8 m (nave), 0.9 m thick. Roof tops are a walkable 6.6 x 4.4 m. The
crack is 3.2 m wide (a jump) in `crack`, 6.6 m (his jump_gap, a pilot
long-jump with a run) in `wide`; floors offset by 1.6 m.
Collision: floor as clean walk boxes; pillars as plumb boxes (kickable);
roof slab as clean walk boxes (a top route over the hall); slab edges
grabbable; hung slabs over the crack as sloped hulls. Nave and roofs tagged
body ground; the 1.8 m aisle slots tagged walker-only (his reads skip them).
Motifs it enables:
- A sundered hall as a central landmark: the layer's A-to-B line crosses
  the crack on a fallen slab.
- A roof run: climb a pillar slot, run the slab tops above the nave, and look
  down on him.
- A hall behind a pyramid stair, the stair's landing opening into the nave.
Threat pairing: the hall is a **corridor with a ceiling for the one who
drops to find you**. The aisle slots are cover and a trap in one: he can't
enter them (1.8 m), but he reaches in with his arm (`arm`) and breaks
pillars to widen the slot. The nave is a lane for the headless body to
charge up.
Catches / throws:
- *Standing*: floors and roofs are walked.
- *Airborne*: roof slabs are catch pads (6.6 x 4.4); the crack's lip is a grab.
- *Tumbling/stunned*: a body falling into the crack drops 1.6 m to the lower
  half (no real fall stun); a body knocked into an aisle slot is kept by the
  plumb pillars (kick or wait). A hung roof slab is a sloped hull that
  **sheds a body down toward the crack** (aimable by the crack's bearing).
- *Hit by him*: a pillar he topples falls as a **log across the aisles**
  (`toss` along its roll, source `city_hall`).
Breaks: **seams at the pillar's base and head.** A pillar snaps at
mid-height (like the kit's drum break); the roof slab above drops on one
corner, a 2.2 x 4.4 m piece hanging or fallen. Three adjacent pillars gone
bring down the whole slab row (a **hall collapse**, rubble of slab chunks).
Rubble: slab pieces lie as a stepped heap, **a new route up to the roof**, and
a closed aisle slot (the walker's cover is lost). The roof's slab joints open
shafts of light (a lighting change in torchlit haze).
Chains with: the rune serpent (passes through the hall's long axis if the
slabs are removed), the inhaler head (inhales along the nave), the seesaw (on
a roof slab), the tumble run (a pillar rolling down an aisle), city_stair and
city_aqueduct (landings), the headless body (charges the nave, takes down
pillars).
Build cost: **med, procedural.** Pillars, slabs and floors are
`Build.solid` boxes with wear, just like the existing hall family (RuinKit
already has colossus column, architrave beam, roof slabs and hall bay), so
this is a re-skin in square basalt pillars with a different capital, plus
the crack cut. The collapse is the destruction branch's breaker. Face
carvings are shader work.
Model budget: silhouette geometry for crack edges and chipped slab
corners. Vertex-colour grime at slab-pillar joins. Merged pillar rows into
one draw each, LODs and visibility ranges apply strongly (halls repeat
pillars). Sculpt/bake, parallax and rigid parts: minor.

---

# Ballcourt coliseum (city_court, family city)
Verb: run and slide the walls; hang from the high stone rings and swing;
time a crossing of the alley; look down from the tiers and hunt.
Look: the **coliseum** as the Mesoamerican ballcourt: a long **I-shaped
sunk court** (flat alley, two end zones) between **tall battered walls**
(talud at the base, sloped, laid in polished slabs) ending in a vertical
tablero. High on each long wall a **stone ring** stands on edge (a coiled
serpent biting its tail, with its mouth at the hole). Around the rim are
**tiered grandstands**, rows of stepped seats (SET_OFF per row), where
the city's people watched the game. It reads from far as a **long hollow
bowl** ringed by stepped bands. Weathered, the rings lean, the paving is
heaved, seats are missing in rows. In the centre of the alley the paving
is cut by a round **shaft** (the ball's grave) that opens to the abyss.
Variants: `alley` (the long court, 3 to 6 BAY long), `bowl` (an oval coliseum
with tiers all the way round), `broken` (one wall slumped, a ramp into the
court).
Behaviour: static. Optional: a `ball` (a heavy stone ball, as large as a
crouched pilot, from the tumble trap's physics) rolls the alley on a trigger
(a slam on the end wall).
Size: alley **12 m wide** (his 4.4 plus room to turn; a place he fits with
margin) and 3 to 6 BAY long (13 to 26 m). Walls 9 m high: a 3.2 m talud (two
SET_OFF, out of a standing grab: a **slide face**), then a 5.8 m tablero
band. Rings at 7.5 m (over CHAIN_TOP, a **hang catch** reached from the
wall's talud-top ledge, or from the grandstand above), 2.4 m across outside,
a 1.2 m hole (a twirl or a swing through). Grandstand rows: 1.6 m rise,
1.6 m tread (STAND-wide); the rows reach 8 rows (12.8 m) above the rim.
Rim tops: TOP_ROOM across.
Collision: alley paving: clean boxes round the shaft; shaft: open (a fall).
Talud: smooth sloped hull (slide, not walked). Tablero: plumb hulls
(kick, wall-run). Rings: torus of convex segment hulls, hole clear.
Seat rows: clean walk boxes per row (a cascade of ledges). All tagged body
ground except the rings.
Motifs it enables:
- A coliseum bowl as a mid-run arena: he hunts the alley, the pilot rides
  the tiers above, the rings are a route over.
- A sunk court with a shaft that is the way down (a descent isle).
- A ring-swing: the pilot hangs from a ring, flicks to the next, crosses the
  alley 8 m up.
Threat pairing: the alley is a **trap floor and a lane for him**. He pounces
from the tiers into the alley (a 12-15 m drop, `shock_r` fills the floor);
the pilot's refuge is the ring's rim or the top of the tablero. The shaft in
the floor is the place a knocked body falls to the abyss.
Catches / throws:
- *Standing*: paving, rows and rim tops are walked.
- *Airborne*: rim tops and rows are catch pads; the rings catch a grab and
  swing (a `rope` mount at each ring's rim, the swing from the hole's lip).
- *Tumbling/stunned*: a body landing on a talud slides down into the alley
  and meets the alley floor, funneling inward. A body that hits a tablero band
  fast is reflected (`carom`, restitution about 0.6) as a `toss`, source
  `city_court`, still stunned, back across the alley. The shaft is a hole to
  the abyss (a fall).
- *Riding*: the ball rolls the alley at about 6 m/s (source `court_ball`)
  and carries a downed body, or knocks it, to the open end.
- Aimable: the alley's axis in the piece's frame; the generator points its
  open end toward the next link.
Breaks: **seams at the ring's stud, the tablero's slab joints and the tier
rows.** His shockwave knocks a ring loose: it falls from 7.5 m and **rolls
down the alley as a hoop** (a ring rolls, 2.4 m across, a brand-new threat
born of the break, `RigidBody3D`, the cap's rubble rule applies). Seat rows
break into stepped chunks that tumble down the tier as a rockfall. A wall
slab hit by a pounce drops its facing to expose the earth core, leaving a
**ramp for the walker and a gap for him**.
Chains with: the ball and the tumble trap (alley as a track), the seesaw (on
a rim top, lobbing across), the wind blaster (a `mouth` in the end wall
firing down the alley), the inhaler head (inhales across the bowl), the
headless body (the pounce target), the rune serpent (circles the bowl in
the haze), and city_pyramid (the court sits at a pyramid's foot).
Build cost: **high.** The walls, tiers and alley are procedural, reused
from `maker_court` and the tier parts. The rings are procedural (a
segmented torus with a snake head cut on one segment). The rolling hoop
and ball are **physics**: new trap code (high), plus the rubble break.
The `carom` rule is a small PilotMotor change (Opus work).
Model budget: silhouette geometry for the ring's biting head, about 100
tris. Parallax depth for the paving. Vertex-colour grime at the talud-tablero
crease. LODs and visibility ranges apply to the grandstand rows (far
tiers become flat bands). Merged rows, one draw per tier. Sculpt/bake only if
the ring head is modelled (2k tris baked). Rigid parts apply to the ring
(a separate mesh, so it can fall).

---

# Temple pyramid (city_pyramid, family city)
Verb: climb the tiers (grab and chain up the tablero, run the tread),
wall-kick between tiers, reach the summit shrine, hide in its door.
Look: a **talud-tablero stepped pyramid**, 6 to 9 tiers, a broad **central
stair** (city_stair) on one or four faces, and a **temple room** on the
summit with a roof comb. Each tier is a sloped talud under a plumb tablero
band; the tablero carries a recessed glyph panel. The corners are battered
and rounded off, not arrises. It reads from far as a **stepped triangle
silhouette**, the oldest shape in the city and the first thing seen in haze;
at night a torch at each tier's corner draws the steps as a line of dots.
Weathered, the facing has fallen off in sheets, roots grip the lips, a
whole face has sheared away leaving the earth core. Variants: `full` (4
faces with stairs), `one_stair` (a stair on the front, three plain faces),
`sheared` (one face a cliff of exposed core), `stump` (only the lower
tiers left, the summit gone), `hung` (the pyramid is the isle's top, a
pillar underneath).
Behaviour: static; breakable.
Size: tiers rise **1.6 m (SET_OFF)** so every lip is a jump-grab, with
**6.6 m treads** (he fits, 6 x 6 over). The talud is 0.6 m (steep, shed
face), the tablero 1.0 m (plumb, kickable). Footprint 3 to 8 cells, summit
at 9.6 to 14.4 m. A stair up the middle is 6.4 m wide (the pyramid stair).
Temple room: floor 8 x 8 m, ceiling 7.8 m (over his neck), door 3.2 m wide
and 3.5 m high (his *no*: a walker-only door, and a niche inside for
cover). The roof comb is a 3 m wall on top (kick and perch).
Collision: tier tops as clean walk boxes; talud as a sloped hull (shed);
tablero as plumb boxes (grab on the lip, kick). Stair as city_stair. Temple:
floor box, side hulls, roof hull (a true room). The comb: plumb hulls, a
perch on its top. Tiers tagged body ground; the door tagged walker-only.
Motifs it enables:
- A pyramid isle as a spiral climb's centre: ring the pyramid by tiers.
- A shrine summit where a ledger activity sits (a rune set, an offering).
- A sheared pyramid with a core cliff: climb the exposed earth as a root-bound
  wall.
Threat pairing: the tiers are a ring of ledges **he can leap up** (`grab_up`
15 m reaches 9 tiers' 14.4 m). He hunts up the stair or leaps the tablero
and shockwaves the tier tops. The temple door is a bottleneck: he can't
enter, and a pilot in the room is safe but cornered, and will have to
wait for him to give up.
Catches / throws:
- *Standing*: tier tops, summit and temple floor are walked.
- *Airborne*: every tablero lip is a grab; the summit is a catch pad
  (8 x 8) and the comb a perch.
- *Tumbling/stunned*: a body landing on a talud slides down it and lands on
  the tread below (a cascade of 1.6 m drops, each under the fall stun),
  shed in the face's direction (plain sliding, no toss; the face the player
  falls on decides the way). On the summit, the temple door is a **barrel**:
  a body sliding in is kept in the line and comes out the back wall's
  niche or stops.
- Aimable: a pyramid sheds toward whichever face looks at the next isle;
  the generator never turns isles but picks the face by placement.
Breaks: **seams at the facing sheets, the temple roof and the summit comb.**
His shockwave on a tread sheds a facing sheet (a 6.6 x 1.6 m slab sliding
down the talud as a ramp that collapses a tier's grab lip, **removing a
route**, or leaving an earth ramp, **adding one**). A pounce on the temple
roof drops the roof slab into the room (it crushes the cover, opens the
sky); the comb falls off as a log. Rubble builds a heap down the face, a
stepped ramp for the walker and a way up for him.
Chains with: city_stair (the face), city_hall (the pyramid's foot),
city_court (at its foot), city_aqueduct (a causeway to a landing), the
seesaw (on a tread), the wind blaster (a `mouth` at a tablero panel on the
pilot's tier), the rune serpent (coiled on the terrace), the inhaler head
(hovers over the summit), maker_stela and maker_throne (dressing).
Build cost: **med, procedural, plus one model.** Tiers and stairs are
plane cuts reused from `maker_tier` and city_stair. The temple room is
procedural. The comb carving wants no model (shader). The destruction
adds the facing-sheet break (a sheet seam per tier face).
Model budget: silhouette geometry (chipped lips, sheared edge), about 50
tris per face. Vertex-colour grime and COLOR.a occlusion, free. The
frieze by shader (saves 2-4k tris per band cell, per K5). Merged tiers
(a pyramid as 3 draws). LODs and visibility ranges apply strongly (it is the
first thing seen from across the layer, and the lowest detail it can have is
a stepped box with a baked texture past 80 m). Sculpt/bake and parallax:
minor; rigid parts: the roof slab only.

---

## Motif hunches (not cards)

- **The Stair That Was a River.** A pyramid isle whose central stair is
  also a flooded aqueduct's outfall, the serpent balustrades wet. The
  causeway reaches its landing, the sundered hall sits at the foot, and the
  rune serpent circles. A place first: a stepped triangle with water
  falling down its centre in a brown haze. The pilot can climb the cheek
  (the balustrades) or the face (the tablero), and he comes up the stair.
  Not a chain: every piece sits loosely within reach.
- **The Coliseum Pit.** A ballcourt bowl, shaft in the floor, rings on the
  walls, grandstands ringing a drop to the abyss. The place first is the
  bowl seen from the rim in the haze. The route runs the tiers, the rings or
  the shaft's far edge, and he hunts the alley floor.
