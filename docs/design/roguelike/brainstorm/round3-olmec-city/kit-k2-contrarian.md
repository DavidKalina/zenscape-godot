# Kit K2: contrarian (round 3, the Olmec city)

**The family `colossus`** (proposed scripts/olmec_kit_colossus.gd, ids `colossus_*`).
The lens inverts the obvious reading of "an abandoned Olmec city": the city was
not built for the wanderer, or for anyone his size. Its stairs, gates, channels
and floors were cut for bodies like the headless one (4.4 m across, 2.4 m deep,
neck 6.7 m up, per layer-round11-body-routes.md). The wanderer is a mouse in a
temple. So each piece below is either (a) giant-scale and wrong for him, with
the way through it a gap the Olmec cannot fit, or (b) a thing the Olmec does to
you, or (c) a quiet, tiny piece set into the colossal one.

**Rules of the family.**
- **Two scales, one wall.** Every piece has a *giant face* (sized to the body's
  lanes: at least 5 m wide flights, landings and shelves at least 6 x 6 m, or
  under 2 m so nothing lands there) and, sometimes, a *mouse way* (walker-only,
  1.2 to 2 m, on a "walker-only" collision layer that the body's rays skip, the
  layer round 11 asked for). The mouse way is never a gap he *almost* fits:
  under 2 m clear or over 6 m, nothing between (the bell-spire lesson).
- **Wanderer numbers.** Walker size 1.0. Ledge grab top is `RuinKit.GRAB_TOP`
  1.875, step up `STEP_UP` 0.45. Mouse openings are sized as `STAND`/`GRAB_TOP`
  multiples, not copied metres. There is no plane underground, so no
  `WorldScale.opening` for these; sizes come from `PilotMotor.set_size`.
  Check each number against the live constants at greybox time.
- **Destruction.** Follows the colonnade-breaks model
  (feature/olmec-destruction): scripted, not voxels. A piece that breaks is
  built as its own Build with a stump or crack face, pieces topple the way he
  pushed or outward from his shockwave, 4-frame hit-stop. The breakers are his
  bulk box and his landing shockwave front (`headless_body._shock`). Under the
  city's weight most giant pieces *don't* break; the ones that do are the ones
  made to (a keystone, a plug, a lamp).
- **Sources.** Each piece's `toss`/`knock` names the piece (`colossus_drum`,
  etc.) so a chain through the city isn't cut short by `restun_gap` 1.2 s.
- **Stone.** Olmec weathered basalt (shaders/olmec_stone.gdshader) with the
  makers' rune grooves from round 1's K5; this family is the *colossal and
  sparse* half of that kit (K5 was the heavy terraces). No ornament glows;
  light comes from torches and braziers, which are pieces here too.

---

# Giant's riser (colossus_riser, family colossus)
Verb: climb (the mouse way is a chimney behind the treads: wall kick up it),
hide (under a tread), watch (he takes the front, you take the back).
Look: a flight of stairs cut for a god-king's stride. Each tread is 6 m deep and
rises 2.2 m, flanked by plain battered cheeks 6 m wide, no balustrade. Four to
nine treads, landing at the top at least 6 x 6 m (his rule). The risers carry a
single colossal low-relief face each, in the weathered inhaler's brow, with the
mouth a dark slot at the tread's foot. Seen in haze it is a black sawtooth
climbing out of the abyss; in torchlight each riser face has a lit brow and a
black mouth. Under the treads, a back gap runs behind each riser: the stair is
hollow, built as stacked stone drums with a 1.6 m chimney in the fill.
Behaviour: static. Optional state change: `settle` tread (see Destruction).
Size: tread rise 2.2 m is above `GRAB_TOP` 1.875, so the wanderer cannot jump
and grab a tread front from the tread below. That is the point: the front is
for him. The chimney is 1.6 m clear, kickable on both faces, and its mouths
open on the tread side at every second riser as a 1.4 x 1.6 m arch. A mouse who
finds the arch grabs the chimney, wall kicks up two risers per beat, and exits
on a tread. Body lane: the flight is 6 m wide, landings 6 x 6, so he walks it.
Collision: tread tops are clean walk boxes (so the body walks them and the
walker walks them once up); risers are plumb boxes; chimney walls are plumb
kickable boxes on the walker-only layer so the body's rays don't read them as
ground. Cheeks are sloped hulls.
Motifs it enables:
- A staircase of the city that is a wall to you and a road to him: you take the
  chimney while he climbs the front beside you.
- A layer's "epic staircase" set piece, with its summit landing as a perch.
- A hanging flight under an isle, descending into the abyss, to drop him.
Threat pairing: the front is open and fast for the body; he reaches the tread
you stand on from the front while you're in the chimney. The chimney is a tool
and a pocket: he cannot enter, but his landing shockwave on the tread above
shakes dust and a drum loose down it.
Catches / throws: *Standing*: tread top, walked. *Airborne*: the tread front is
a plumb wall, kickable but too tall to grab from below; a body arriving from
above lands on the tread top. *Tumbling/stunned*: a body landing on the stair
bounces down the treads one at a time (2.2 m drops, under the 6 m fall stun)
and ends on a landing: a gentle cascade that throws nothing but delivers a
stunned body to the foot, 2 to 3 s of travel for a flight of five. *Riding*:
n/a. Output: shedding down, no `toss`. Aimed by which way the flight faces.
Mounts: `rim` (landing edge), `run` (tread tops, a tumbling block would roll
down), `deck` (landing).
Destruction: a `settle` tread. A tread marked weak collapses when his
shockwave front reaches it (1-in-3 treads, picked by seed): the drum stack
slumps into a rubble ramp that is walkable by the wanderer. The stair changes
from "wall to you" into "ramp to you" and opens the chimney from the side. It
never removes his lane: the rubble ramp is under his 2 m per 2 m rule.
Chains with: the headless body (his landing shockwave on a landing shakes loose
a tread), the inhaler head (its pull along the stair's axis drags a stunned
body down the treads), logs and tumble blocks rolled down the treads, the rune
serpent flying past the open flank.
Build cost: **low-med.** Procedural, built from Build.solid blocks as the
gothic stair and K5's tier are; the relief faces come from the shader, not
modelled. The `settle` tread is the one physics-adjacent piece: pre-split into
three drum stacks and a rubble ramp, tweened, no sim.
Model budget: shader relief on riser faces (a modelled brow face would cost
roughly 3 to 6k tris each; none paid). Instancing: one tread module repeated
(a nine-tread flight is one mesh drawn nine times). Silhouette geometry on the
tread lip and cheek edges. Visibility ranges and LODs matter most here because
the flight is huge and reads as pure silhouette in haze: estimate 40 to 60% of
draw cost at range. Vertex-colour grime applies. Sculpt/bake isn't needed.

---

# Mouse run (colossus_mouserun, family colossus)
Verb: hide, sneak, cross (a hidden route through the middle of a thing the body
cannot pass), carry nothing.
Look: a tiny walker-only passage cut through the thickness of a colossal wall
or pier, 1.4 m wide and 1.8 m high, with a worn lip where a thousand servants
passed. On the giant face it is a hairline dark slot near the foot, reading as
a drain or a crack. Inside, torch niches the size of a fist and tally-marks
scratched at hand height by cleaners and tenders. The slot is framed by one
small cut stone, a lintel the width of a loaf, unlike the colossal masonry
around it, and that is the tell. The far end opens into a room, a gallery or
the underside of an isle.
Behaviour: static. One variant is a `rubble plug`: the passage is blocked by a
fallen drum and opens when the Olmec's shockwave dislodges it (below).
Size: 1.4 wide, 1.8 clear (under the body's 4.4 width and 6.7 neck: he cannot
fit and cannot reach inside). Length 6 to 14 m, straight with one jog so the
lit niches don't give away the exit. Entry sits at the floor so a walker
doesn't need a grab, but behind a half-height cill (0.45 m, `STEP_UP`) so a
running slide doesn't carry you in by accident.
Collision: floor is a clean walk box; walls plumb boxes (kickable, one wall
kick per jog); ceiling closed. Whole run is on the walker-only layer, so the
body's rays and route reads ignore it and neither plan nor path routes him
through. The giant wall around it is a normal solid.
Motifs it enables:
- A servants' warren beneath a colossal stair or inside a pier: the shortcut
  and the hiding place on a layer where the body hunts in the open.
- A city where the safe route is the small one, with an exit into the middle of
  a gallery he can't reach, on a perch.
- A dead-end that isn't: a plug at its far end opens under his shockwave.
Threat pairing: not a trap, a refuge, which is the contrarian point: a piece
that catches you and throws nothing. The cost is position: it goes where he
does not, and you lose sight of him. When he loses you inside a pier he hunts
the nearest mouth (head-call, `CALL_HEAR`) and stands outside; the pilot can
leave by the other end and the body has to walk round.
Catches / throws: *Standing*: yes. *Airborne*: a body coming down a shaft
lands in the run's floor. *Tumbling/stunned*: a stunned body inside a run
cannot be reached by the body; the run is the only safe place to wait out a
stun. Output: nothing, except the plug: a body next to a plugged end when a
shockwave lands takes a `toss` out of the opening (`colossus_plug`, dir along
the run, 5 m/s, still stunned, as a pop-out). Aimable: yes, through which end
the plug is placed.
Mounts: `rim` (exit lip when the run exits above a drop), `rope` (an anchor
at the far lip), `mouth` (none).
Destruction: the plug variant only. A drum-stack plug at the far end
(three pieces) topples outward when a shockwave or bulk hit reaches within
8 m of the exit's face. The run itself never breaks: it is inside a wall too
thick to destroy (the city is built to bear weight). If a wall around a run is
*thin* (a half-thickness gallery wall), the body's bulk box breaks it and the
mouse run turns into a body gap, a recorded loss.
Chains with: the headless body (loses you, hunts the entry, stops), the inhaler
head (its sight can't see inside; its inhale pulls dust through the slot),
the rune serpent (whose eye can glow at the far mouth), the lit torch niches
for lighting a path in the dark.
Build cost: **low.** Procedural boxes on the walker-only layer plus a
tiny lintel mesh. The layer and the body's skipping rule come from round 11's
"mark what's his" proposal, which is the real cost: confirm that rule exists
before building.
Model budget: almost nothing to model. Instancing and a single trim-sheet for
the lintel stone. The interior never needs LOD; it's culled by the walls.
Visibility ranges for the niche lights. Estimated tris: 200 to 500 per run.

---

# Drum floor (colossus_drum, family colossus)
Verb: time a crossing, stand on the wrong thing, ride his landing.
Look: a broad flat deck of stone slabs, each 4 m square and a metre thick, set
loose on a field of hollow stone drums. The slabs have a single carved ring
each, the makers' tally of a count of years. The seams between slabs are black
cracks a hand wide. The deck feels like a floor and rings like a bell when
anything big lands on it. It sits as a courtyard under a hall, a plaza before a
stair, a ballcourt floor. Hollow underneath: from the abyss side the underside
shows the drums as a dark honeycomb in silhouette.
Behaviour: changes state / launches. Slabs sit on springs (visual only: a short
tween, no sim). When a landing shockwave from `headless_body._shock` reaches
a slab, or when anything lands from over 3 m with a slam, that slab and the two
neighbouring slabs hop 0.4 m for 0.4 s and ring. Anything standing on a hopping
slab is `knock`ed up and sideways.
Size: slabs 4 x 4 x 1. Field 3x3 to 6x6 slabs (12 to 24 m): a body lane
and a landing in one. The hop is 0.4 m (a quarter of `GRAB_TOP`), nothing to
climb. A small-trained wanderer reads it as a floor, which is the trap.
Collision: each slab a clean walk box, one body per slab, sloped by none. Hop is
a kinematic move of the slab's collider for 0.4 s (cheap: nine boxes at most
moving at once; a kinematic body, not physics sim).
Motifs it enables:
- A plaza under a colossal stair where he lands off the stair above and tosses
  the wanderer into the air.
- A coliseum floor made of drums: luring him onto it makes the whole field ring.
- A drum floor under a hanging walkway so a ring can toss you up onto it.
Threat pairing: the Olmec uses it on you. His landing shockwave throws you
from 7 m away; and as a tool you can use his shockwave to launch yourself
onto a ledge: stand on the right slab as he lands and ride the hop up.
Catches / throws: *Standing*: yes, flat. *Airborne*: lands as a floor.
*Tumbling/stunned*: a stunned body on a hopping slab is `toss`ed again
(a stunned body stays stunned) 3 m up, 4 m/s sideways, with a different
direction per slab (slab centre away from the shockwave's origin). *Riding*:
n/a. Source `colossus_drum`; the body's shockwave is `headless_body` so the
two are distinct sources and chain: `knock` by shockwave, `toss` by drum, a
fall stun can hand off from one to another. Output: up 3 m, outward 4 m/s
at the origin's bearing, aimed by where he lands (not by the generator).
Mounts: `deck` for the field, `run` none.
Destruction: the drums break under repeat. A slab whose hop count reaches 3 in
a run cracks at the seams and drops: the field gets a hole 4 x 4 m, then a
void to the abyss below (you fall; he steps round it). The drum field is also
the thing that makes `landing under 6x6` safe for him: the holes are slab-sized
and his feet span them (round 11: "his feet span gaps").
Chains with: the headless body's shockwaves (the piece's trigger), the inhaler
head's pull (a stunned body dragged over the field rings slabs by running),
seesaws and cannons that land you on a slab, the rune serpent's passing
(low-frequency hum, visual only).
Build cost: **med.** Procedural boxes; the hop is a kinematic collider tween
per slab and a ring shader pulse (a uniform on the slab material). A shockwave
reach query is needed: the piece asks `headless_body._shock` for a signal or
polls a group, which is the new coupling.
Model budget: instancing (one slab mesh, 36 instances); shader ring pulse
instead of geometry; unseen underside is a closed box (no tris). Visibility
ranges. Estimated 12 tris per slab plus the tally ring as a decal-style
normal-mapped texture.

---

# Ash bowl (colossus_ashbowl, family colossus)
Verb: fall (land softly), wade, hide, drop him.
Look: a vast shallow bowl in a court's floor, 12 to 16 m across, filled with
fine pale ash and bone-grey dust to a metre deep, long unswept. A ring of
stepped seats runs round it like a tiny coliseum, and one tall stele stands
at its centre with its top snapped. The ash is the only soft thing in the
stone city; in the haze it is a faint pale disc, the brightest pale thing in
the dark. Footprints of the Olmec's body are pressed into it, enormous and
placed in a line. Motes lift when anything lands.
Behaviour: changes state. Ash is a surface with a `ash_depth`: a standing
body wades (speed times 0.55); a body landing from height is *caught*: the
fall stun is waived for drops up to 14 m (normal limit 6 m) because the ash
swallows the impact. His landing shockwave is damped to 0.3 of its reach
on ash (it throws no stun here, and a toss from a shockwave is blocked).
Size: 12 to 16 m across, depth 1 m. Seating ring 0.45 m risers (`STEP_UP`),
so the wanderer climbs out; the Olmec fits the bowl entirely and the seats
are his stair. Rim lip 0.45 m on the walker side, with a gap on one side for
a body lane 6 m wide.
Collision: the ash is a one-box volume with a surface flag read by PilotMotor
(slow, no stun) and by the body (ignore shock). The seating ring is clean
walk boxes in steps; the stele a plumb box.
Motifs it enables:
- A plunge into the dark: a long fall that ends in a pale soft disc, the
  first rest in a layer.
- A coliseum or ballcourt whose floor is not a floor: nothing there is a fight,
  and an Olmec in the bowl cannot shock-throw you.
- A drop target: lure him to stand in it, losing his shockwave there.
Threat pairing: a soft catch is the threat's inverse. Stuck in the ash you
slow while the head's pull and the body's reach still work; and the bowl hides
what is under it (a loosened floor, a pit). As a tool it forgives a bad
drop; as a trap it holds you in his arena.
Catches / throws: *Standing*: wade at 0.55. *Airborne*: catch; waives fall
stun up to 14 m and zeroes horizontal speed to 40%. *Tumbling/stunned*: a
tumbling body hits the ash, loses momentum and stops: it is the one piece
that *ends* a chain in a kind way, and the player can always break out sooner
(stun_chain_cap 3 s applies as usual). Output: nothing; no toss. Not aimed.
Chains with: the cannon or the headless body's cliff-fall (lands you in it),
the inhaler head (its inhale pulls ash into a pale plume which blinds the
head's sight, to confirm in greybox), the seesaw (launching out of the bowl is
a short hop, not a throw).
Destruction: the stele breaks when he plows through the bowl (it is in his
bulk box's path): the snapped stump and a top drum that rolls into the ash.
The bowl's seating is intact (it is solid); the ash is never destroyed. The
footprint line in the ash is a dressing-only hint of where he walked.
Build cost: **low-med.** Procedural bowl (a heightfield cut into the floor),
ash as a surface flag and a scattered-particle shader; the stele a Build.
The PilotMotor surface flag is the only new rule (wading and waiving fall
stun); verify there is a hook for surface speed.
Model budget: shader ash (no mesh detail), particles for motes, instancing for
seats. Visibility ranges. Bowl mesh a few hundred tris.

---

# Votive niche (colossus_niche, family colossus)
Verb: perch, hide (cover from his sight), see, rest.
Look: a tiny shelf set high into the face of a colossal wall or pier, a handspan
of stone with a stub of black candle or a clay lamp in a rounded arch, the
size of a fist for the makers' tenders. Often a string of them, 8 to 20 m
apart, leading up a wall like a path of fireflies in the haze. Each shelf has
a single carved glyph over it. You see them first as warm points in dark
distance, a ladder of dots, before you see the wall they are in. One niche in
a few is bigger: a cell you can stand in, a 2 m alcove where the wanderer is
hidden from every direction but the front.
Behaviour: changes state. The lamps are lit (lamp lights are real but pooled:
a visibility-range light per niche up to a cap). The Olmec's wall hits, his
shockwave, or his climb along the wall knocks a lamp's flame out (`lit` 0)
with a puff of smoke. A lit niche rests the pilot (reduces the stun
duration of any stun he takes on the shelf; or simply a sanctuary no AI
checks). Unlit, it is just a shelf.
Size: the shelf is 1.0 deep and 1.4 wide (STAND-ish), sits on a vertical
wall at spacing 2.2 to 2.8 m, so each ledge can be grabbed from the last
(under `GRAB_TOP` 1.875 plus a jump). Alcove variant 2 m wide, 2.2 m high,
1.5 m deep. The body cannot use them (they are shelves under a 2 m depth, the
"less than 2 m" rule), and his hands are too big to grip them.
Collision: shelf a clean walk box (1.0 x 1.4), the wall a plumb box (kickable
between two opposed rows), the alcove roof a closed box. All on the walker-only
layer for the shelf so the body does not choose it as ground.
Motifs it enables:
- A wall climb that is a ladder of lamps: the chain-climb route up a colossal
  pier, readable at a glance in haze.
- A high alcove where the wanderer hides from the hunting head while the body
  walks under.
- A path of niches that go out one at a time as he climbs the same wall, a
  cost: you are hurried upward by his dark.
Threat pairing: a lamp goes out when he passes, which dims the route, and a
glowing niche is an advertisement: his head's sight picks out a lit niche
silhouette against the haze (a wanderer standing in a lit niche is visible; in
an unlit one is hidden). So light is cover's inverse: light your way, be seen;
douse it, vanish.
Catches / throws: *Standing*: yes. *Airborne*: lip catches (a grab). *Tumbling
/stunned*: a stunned body on a shelf is held (the shelf has a 0.1 m back lip).
Output: none. Mounts: `rope` anchors at every fourth niche (a lamp-chain between
two columns), `rim` none. No aim.
Chains with: the headless body (his climbing hand along the wall extinguishes
lamps and may knock a stunned wanderer off a shelf), the inhaler head (sight
line), the rope bridge, the wind blaster (blows lamps out in a line; also moves
smoke).
Destruction: the lamp breaks when he drags his hand or bulk along its wall, and
the shelf chips: the shelf is 'spalled' (hit count 2) and a gap opens in the
ladder, 2.8 to 5.6 m, requiring a wall kick across. It never leaves the
wanderer without a route: a spalled shelf leaves its bracket stub as a grab.
Build cost: **low.** Procedural shelf plus a baked-in lamp mesh; the light is a
pooled omni light with a visibility cap, the flame a billboard. The lit/unlit
rule needs a cheap sight-visibility term in `body_sight.gd`; verify it can read
a light level or a "lit" group.
Model budget: instancing (one lamp mesh, hundreds of instances), billboard
flame, baked occlusion light with a few real lights near the pilot. Tris about
60 per niche. Pooled lights are the real cost, not the geometry.

---

# Plug-stone (colossus_plug, family colossus)
Verb: lure, solve (get him to break it), run through the gap he opened.
Look: a colossal keystone or wedge block, 8 m across, jammed into a gate, a
spillway or the neck between two halls and holding the whole structure in
place. It is carved with a single huge rune brow, closed, like a held breath.
Hairline cracks radiate from it, and dust sifts from them. It looks like the
gate and fills the opening completely: a wall, not an obstacle, until it is
struck. On the far side, the haze gleams between its cracks.
Behaviour: changes state. Breaks once. Struck by the Olmec's bulk box at speed
(a pounce into it, a charge) or by two of his shockwaves, it cracks, then
falls in four pieces and leaves a rubble gap. The wanderer cannot break it
(tossed or knocked bodies don't, which is the contrarian tell: your strength
is nothing). Nothing else on the layer opens the gate.
Size: 8 m wide, 8 m high (his shoulder reach is 3.3 m at the lintel, neck 6.7:
the plug stands taller than he does), thickness 4 m. Rubble gap afterward is
4 m wide, so he can follow and the wanderer can climb the rubble's 0.5 m
steps. Fall pieces are cosmetic after landing; the rubble is a heap with clean
walk boxes (steps under `STEP_UP`).
Collision: a solid until broken (plumb box, kickable). On break, the box is
swapped for a heap of 5 to 7 boxes at fixed rest poses, with a shared crack
face on each piece.
Motifs it enables:
- A sealed gate between two halls: lure the hunting body so he rams it, then
  slip through the break behind him.
- A spillway plug holding back a flooded reservoir: when it breaks, a flush of
  water or a flood of ash comes through (to confirm with water art).
- A coliseum gate that opens by his hand, which is how the arena gets its crowd.
Threat pairing: it is the Olmec's tool and yours. Open it and he follows through
the new gap, opening a route for you but also for him; leave it and the way is
shut. There is no chain: the rubble spill is 1.5 s of motion, then still.
Catches / throws: *Standing*: a top to walk if the plug is flat-topped (a
cap). *Airborne*: a plumb wall, kickable. *Tumbling/stunned*: slides off its
face. When it breaks the falling pieces knock a standing body in their path
(`knock`, source `colossus_plug`, 3 m/s, dir away from the plug, still
stunned, 0.5 s): a falling stone, not a launcher. Output otherwise nothing;
aimed by placement (the plug fixes where the body must hit).
Chains with: the headless body (the only breaker), the inhaler head
(its sight through the gap), a flood or ash flush if the layer has water, the
rune serpent threading the new gap.
Destruction: this is the destruction piece. Pre-split into four wedge pieces
and a ring of dust; the break is the colonnade model with hit-stop, direction
by his push, and a settled heap at the end. A broken plug stays broken for the
session. A layer with a plug has one hall behind it that is not on the
generator's required route: the plug is an optional gate, never a lock.
Build cost: **med.** Four pre-cut wedges and the rubble heap, a tween rather
than a sim, hooked into the same break manager as colonnade_breaks.gd (a reuse
of its machinery, not new physics). Needs a way for the generator to know the
body will reach it (route reads).
Model budget: instancing (the wedges share a texture); shader cracks revealed
by a `damage` uniform instead of a second mesh; the rubble heap as a few boxes
with silhouette chips. Estimated 400 to 900 tris for the whole plug set, saved
vs sculpted rubble about 4 to 8k.

---

## Motif hunches

- **The Drum Court**: a ballcourt-scale plaza of drum floor under a giant's
  riser, an ash bowl at its low corner, and a mouse run entering the riser's
  hollow. The body arrives down the stair and lands: the slabs ring, and
  wherever the wanderer is, the floor decides, loosely, who is thrown where.
  A place first: the stair is a black sawtooth in haze, the court a pale slate
  floor, the bowl the one soft thing. Nothing is scripted: the body hunts, the
  pieces just sit within reach.
- **The Servants' Pier**: a colossal pier in the haze with a ladder of
  votive niches climbing its face and a hidden mouse run through its heart.
  The body can't climb it or see inside it; you can. A plug-stone at its foot
  holds a gate the body must break to follow you, and the lamps go out as he
  does.
