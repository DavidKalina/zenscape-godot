# Kit K4: destruction and state change (round 3, the Olmec city)

Lens: **destruction / state change.** Decay: dismantled live. Twist: the
threat as the only way across.

Builds on round 1's `makers` family (kit-k5-makers.md: CELL 4.4 m, tiers of
SET_OFF 1.6 m, talud under glyph band, Olmec stone shader, `mounts`/`catches`/
`throws`, `carom`). That doc made the makers' stone *static*. This one makes
it *change*. Same family, same stone: these are `maker_*` ids too.

## Rules for every breakable (read first)

**What destruction round 1 proved, and what it limits.** (Branch
`feature/olmec-destruction`.) A break is scripted, not voxel: the piece is cut
ahead of time along masonry joints (drum joints, slab seams), a few Jolt
`RigidBody3D` pieces fly (capped at `MAX_BODIES` 24; past the cap a piece is
laid down where it would land, frozen at once), they freeze static after
0.25 s still (or 2.5 s slow), then their meshes merge into one and the bodies
stay as collision. Settled rubble is ground to the walker *and* to his
planner; standing breakables and flying pieces are air to his rays so he
plows through; `BodyRoutes.forget` re-plans after each settle. Costs
measured: about 8 pieces per pier-and-two-lintels, 15-20 ms build hitch,
+12% draw calls when un-merged. Limits: no per-hit fracture; rubble can't be
kicked; breaks are permanent for the session; the 3.4 m gothic pier read as
"fence posts" at his 10 m size. **So the makers' breakables are big** (drums
2-3 m across, slabs 6 m long) and fall slowly with a long dust plume.

**The three-state rule (my addition).** Every breakable is authored as three
frozen states, not simulated into whatever it lands as:
1. *Whole*: collision A.
2. *Cracked* (optional tell): hairline fault, dust trickle, a low groan, same
   collision as whole.
3. *Fallen*: **authored rest collision**, a designed rubble heap with clean
   walk boxes. The flying pieces are the show; they are steered to settle
   *into* the authored heap (pieces are laid toward its slots, the same trick
   as the over-cap "laid where it would land"). So the outcome is
   route-designed and the generator can reason about it before anything
   falls, and a break never costs more than the 24-body cap.

**Route contract.** A break *trades* a route, it never deletes the only one:
the generator gives each breakable a `before` and `after` route set (a
`breaks` metadata entry: `{trigger, before_routes, after_routes}`) and
checks each isle keeps at least one route to the exit in both states.
Fallen heaps for the Olmec's lanes: walk-through width **at least 6.6 m**
(1.5 CELL), rubble steps no higher than his step knob 2.4 m, no pocket
under 6 x 6 m that he can drop into and can't leave (round 11's traps).
Anything narrower than 2 m is fine: he won't take it.

**Who breaks it.** Four triggers, named for `breaks`:
`body` (his bulk box, a swat, a leap's landing), `shock` (his landing
shockwave, reach scaled by `power`), `slam` (the wanderer's flow-charge
downdraft slam, which is already a landing force on a bell), and `trap`/
`serpent` (a rolling drum, the rune serpent's passing coil: 4 m through, 90 m
long, it can brush a causeway off its piers). The wanderer's own bulk is far
too light (1.0 vs. his 10 m); only a slam breaks things, and only things
marked *chocked* or *cracked*.

**How breaks stay readable** (in dim haze and in torchlight):
- **Fresh stone is pale.** The makers' stone is weathered dark basalt; every
  cut face is raw pale grey-tan (the Olmec stone shader's rest position in
  UV/UV2 already separates surface from interior). A fallen heap reads as
  light stones in a dark city, a silhouette-and-value change visible from far
  off in haze. This is the single biggest readability lever.
- **Dust is the signal.** A column of dust 20-30 m tall holds in the haze for
  8 s: you see *that* something fell from three isles away, and the pale
  fresh-cut shows where.
- **Cracked is a tell**, not a surprise: dust sifts from a faulted joint,
  one drum slips 0.1 m and a small pebble tick, a deep groan 4-6 s before a
  load-bearing piece goes.
- **Silhouette first.** The fallen state changes the skyline of the piece
  (a gap in the causeway, a gable gone), not just a texture, so it reads even
  at fade distance.
- **Persistent.** Fallen stays fallen; the heap's pale stone weathers by
  nothing, so the scar is visible to the end of the layer.

**Tuning note.** Round 1's "reads small" lesson: slow topple, bigger
dust on the first frames, hit-stop on his side only. Everything below is
sized so the *pieces* are about the size of his hands.

---

# Felled column (maker_felled, family makers)
Verb: lure him into a column to fell it as a bridge (or a ramp); then run,
slide and rail-slide along the felled drums; jump the seams; or, from the
other side, dodge the rolling drums.
Look: a free-standing hall column of the makers, 5.5 m across (a drum stack
of 2.2 m drums, 6 to 8 drums, 14-18 m tall), a great round-faced capital
with a heavy square abacus carved with the cleft-browed face frieze, set on a
stepped plinth. It is not gothic: no taper, no flutes, the drums slightly
barrel-bulged like a cut ceiba trunk. Rope-scars and iron-black strangler
roots wind round it. Drum joints show as recessed bands with the glyph ring
cut into each. Cracked state: one joint gapes a hand's width and trickles
dust. Beside the Olmec it reads as the same quarry stone and the same scale
class: his hand span is a drum.
Behaviour: changes state. Trigger `body` (he walks into the plinth side),
`shock` (a pounce landing within about 10 m), or `slam` (only when *cracked*).
The column snaps at the *marked joint nearest the hit* (the card declares 2-3
legal joints) and falls **along its authored fall axis, on whichever side the
hit came from, to the far side of itself**: a two-way hinge, so the lure
decides the direction. The stack takes about 2.5 s to fall (slow, weighty),
the drums break apart at their joints in the last 0.6 s and **roll** up to 6
m, then freeze. Rest state: a felled bridge of drums, lying along the axis,
a chosen number of drums long.
Size: column 5.5 m across (a wanderer-and-a-half-wide jump to stand on the
abacus); fallen, the drum top is a 5.5 m round (rounded, so the walker slides
a little) with seams of at most 0.3 m, but stacked pairs rise to 4.4 m
(climbable by drums, GRAB_TOP 1.875: a two-drum rise gets a step drum
laid beside it, authored). Stump ring at the base: a plinth 1.6 m high, the
grab. For his lane: the fallen line is a 5.5 m wide span **plus a flank
apron of broken drum-halves, authored to widen it to 6.6 m** wherever it is
meant to be his bridge.
Collision: standing: the barrel as a cylinder hull; the abacus top is a
clean walk box (reachable by wall-kicking the plinth). Fallen: each drum is
a cylinder hull but the *top strip* of the lying line is a clean 2 m wide
walk box on the crown so the walker doesn't roll off. Wall-kickable: the
standing shaft.
Motifs it enables:
- **The Felled Way**: two pinnacle isles 30 m apart over the abyss, a
  column on one of them tall enough to bridge. A head-hunting Olmec stands
  between the player and it. The player lures him into the column from the
  right side to drop the column across the gap. No chain, just a choice:
  which column, which side.
- **Colonnade of a burnt hall** with every third column cracked; the body
  passing through lays a line of them like a toppled row of dominoes (each
  falling into the next, on purpose).
- **Rolling drum alley** at the foot of a stair: drums that rolled off.
Threat pairing: the falling column is the trap. A body at the stump or on
the abacus when it goes is carried down with it (a ride); drums rolling off
the end are a slow log trap along the run. Anyone who lures the Olmec into
the *wrong* column drops a bridge onto their own route.
Catches / throws: *Standing*: the abacus and plinth ring catch (clean tops).
*Airborne*: abacus lip is a grab. *Tumbling/stunned*: lands on the barrel and
slides off it (no `toss`). *Riding*: a body on a falling column rides it down;
the felled crown catches the ride, still standing. Rolling drums: `knock` a
standing body, `toss` a stunned one, source `maker_drum`, about 1.5-2
pilot-runs (8-10 m/s) along the roll, no aim except the fall axis. The
direction of a roll is the fall axis, so the generator aims it by placing
the column (it never turns an isle).
Chains with: the wind blaster (a body knocked at a cracked column's shaft
doesn't break it: only `slam` does); a stunned body thrown onto the felled
crown stays stunned and slides; the headless body (the trigger); the
rune serpent brushing a tall column; the inhaler head's pull (sucked-up
drums, hunch: the head inhales loose drums from a heap).
Build cost: **med.** Procedural (stacked cylinders with recessed glyph
rings, one Blender-authored capital with the frieze, instanced). The fall is
a scripted hinge for the first 2 s (no physics), then 6-8 Jolt cylinders
for the last 0.6 s, laid toward authored slots, 8 bodies. The two-way
authoring (rest states for each direction) doubles collision but not mesh.
Model budget: **Import LODs and visibility ranges** (drums are identical; a
single instanced drum with a visibility range; 6 drums x ~120 tris = under
1k), **vertex-colour grime**, and **silhouette geometry** for chipped
abacus corners. The glyph rings are shader, not geometry (saves 2-3k tris/
column). **Rigid parts on bones doesn't apply**; the fall is scripted
transforms.

---

# Causeway span (maker_causeway, family makers)
Verb: cross the abyss on a raised road, run its length, drop to the lower
road when it falls, chain up the pier-stack to get back on; or ride a slab
as it tilts.
Look: a stone road 6.6 m wide (1.5 CELL), 1.6 m of plumb coursed slab thick
under a paved deck, carried on **trestle piers**: paired drum columns of 2.2
m drums with a corbelled cap (each course juts over the one below) holding
2-3 long deck slabs, 6.6 m long each, bridging span to span. It's the
makers' aqueduct without the channel: low, heavy, battered. Deck edge has a
curb of low stelae (hand-high), no rail. Wear: deck slabs slumped, a pier
leaning, strangler roots through the joints; weathered 1 is a road with
holes. The road runs on for hundreds of metres into the haze: a line of
trestles fading, each a silhouette.
Behaviour: changes state. **Slabs** are the weak link, not the piers.
Trigger: `shock` (the pier or slab within shockwave reach drops a *slab*),
`body` (he walking across loads it; a *cracked* span takes his weight for
about 1.5 s of stride then gives), `serpent` (a coil sweeping through a
span). A broken span sheds its two slabs: the near end drops first and the
slab **hinges on the far corbel, ending as a ramp** that runs from the deck
down to the next road level below, if there is one (every causeway sits over a
lower road on a different tier, the authored rest heap). Pier breaking is
separate: a trestle with its pairs knocked from the base lets a whole
two-slab span go flat onto the lower road.
Size: deck 6.6 m (his lane, by design: the whole causeway is his road;
the generator marks it `body_lane`); slab is 6.6 x 6.6 m so a fallen slab is
a landing of his own minimum. Pier spacing 13.2 m (3 CELL) so a missing slab
is a gap of 6.6 m: a plane-less jump is about 3.5-4 m, so **a gap of 6.6
m is not jumpable by the wanderer, and a pocket-sail glide over it works**.
The ramp is steeper than a stair (a slab fallen at about 30°); the walker
walks it, a body shed off it slides.
Collision: deck is clean walk boxes per slab. Fallen: two clean sloped boxes
(the ramp), the pier stumps' tops (clean boxes, 2.2 m round, for wanderer
only), the lower road tops. Curbs: wall-kickable (hand-high, so kick only
from the deck edge below). Corbel courses are a grab ladder up the trestle.
Motifs it enables:
- **The Long Fall** (a layer-scale route): a causeway runs the isle chain,
  the body is on it; when it hunts you onto a span and lands, the span goes,
  and you ride the slab down to the lower road *with him still above*.
- **Dismantled in progress**: a span that already fell, leaving a 6.6 m gap
  crossed by a rope bridge hung from the stump; the Olmec cannot cross, so the
  gap is a pocket the player uses to lose him.
- **Two roads over the abyss**: upper road for him, lower road for the
  wanderer; breaking a slab of the upper road *makes* the stair between.
Threat pairing: the road is itself the trap when a body stands on a cracked
span. The only way across a section can be the span he has to cross too;
his landing shockwave on the deck is the same shockwave that drops a slab, so
the player has to stand *between* the shocks.
Catches / throws: *Standing*: deck and the fallen ramp both carry. *Airborne*:
curb lip is a grab; the lower road is a `catches` pad (6.6 m wide). *Tumbling/
stunned*: lands on the deck and slides down a fallen ramp (no `toss`).
*Riding*: a body on a slab as it hinges rides it down (about 0.7 s,
rotating 30°). On `shock` or `slam`, the dropped slab on a standing body
within its footprint is a `knock`, source `maker_slab`, straight down and out
along the road at about 1 pilot-run, never aimed (just the road's axis).
Chains with: the wind blaster (blast a body onto a cracked span to drop it),
logs and tumbling blocks on the deck (rolling heavy things break cracked
slabs), the headless body (the main trigger), plinth ram, the rune serpent.
Build cost: **med-high.** Procedural trestles and slabs, a scripted hinge
(not physics) for the slab, a Jolt pass only for the last debris; the
authored rest state per slab (ramp/flat/tilted) is what costs. The
generator needs the `breaks` metadata and the two-level placement rule (a lower
road under every upper one).
Model budget: **Import LODs / visibility ranges** (repeating trestles at a
distance collapse to a merged strip, which the haze hides; a causeway of 20
spans stays under about 8k tris at distance), **silhouette geometry** for
slump and the corbel stair steps, **vertex-colour grime**. A 20-trestle
run is the one place the far-fade merge matters.

---

# Corbel vault (maker_corbel, family makers)
Verb: pass through (a gate, hall, tunnel); then, once it falls, go over its
roof; hide in it from the head; fight for the keystone slab; wall-kick the
corbel stair.
Look: the Mesoamerican vault with no true arch: each course juts toward the
middle until a flat capstone slab closes the gap. A hall 8.8 m wide (2 CELL)
at the floor narrowing in 6 stepped courses to a 2.2 m slot at 12 m, capped
by 2 long capstone slabs; the outside is a stepped pyramid mass, one tier per
two courses, so it reads as a *building*, not a tunnel. Inside the vault:
steps of corbel courses, dark, lit by torch niches. Wall-reliefs of the same
cleft-browed faces. Rubble-and-mortar core fills the haunches (visible where
facing fell). Cracked: capstone slab with a dark hairline and a soft run of
grit.
Behaviour: changes state. Trigger: `body` (he passes through: his shoulders
clip the lowest course at 10 m, shedding a **face of the corbels** into
the hall; harmless), `shock` (a landing on its roof drops the capstones),
`slam` (a flow-charge slam on a *cracked* capstone). The break: the
capstone slabs fall and the upper corbel courses behind them let go,
**turning the hall into an open-roofed trench** half-filled with rubble:
the roof route (walked on the haunch tops) is now *open*, the inside route is
now a rubble climb, and the vault is now **a skylight**: you can see the
haze above it and gain verticality to the isle above. Rest state authored:
rubble ramp from floor at one end, haunch ledges as a stair.
Size: 8.8 m floor (his lane: it is a hall he walks through; the vault
clearance at his head, 10 m, is met at the 5th course); the haunch tops
are 2.2 m wide ledges (stand, take a run-up; under 6 m so he doesn't use
them, perfect for the player); courses are 1.6 m (SET_OFF) each side so
a wall kick between two corbel faces is possible for a wanderer in the
upper 5 m (the vault is a chimney there, slot 2.2 m = about the plane-less
kick gap). Capstone: 2 slabs 6.6 m long.
Collision: floor and each course's tread are clean walk boxes; the corbel
faces are plumb (kickable) with the ledge a grab. Roof: a clean top slab
walk box. Fallen: ramp hulls and the haunch tops.
Motifs it enables:
- **The Hall of the Hundred Faces**: a long corbel hall with an Olmec at
  the far end; the player hides in the haunch ledges (above his eyes), and
  when he slams at the end a roof section drops on him.
- **Gate city**: a vaulted gateway of the city wall, the only way through
  until the capstone is knocked; then a second route over.
- **Skylight stair**: a stack of vaulted floors, each opened by the one above.
Threat pairing: the vault's dark is cover; its capstone, the trap. A body
in the slot when the capstone goes is `knock`ed down and out along the hall,
source `maker_slab`. Torch niches: the head's glance sees the lit one.
Catches / throws: *Standing*: floor, haunch ledges. *Airborne*: courses
grab; the slot is a kick chimney (catches with a kick). *Tumbling*: falls
down a course stair, no `toss`. *Riding*: no. On break, bodies under the
capstone get a straight-down `knock` (falls 12 m = twice the stun fall,
so a drop onto rubble is a real stun, which makes this a hazard to *wait
under*). Not aimable beyond its axis.
Chains with: the headless body (the trigger), the head's inhale (loose
capstone slabs? no: too heavy, but the dust draws the head's attention),
wind blaster in a torch niche mouth, ledge grabs into the haunch.
Build cost: **med.** Procedural (stacked course boxes with batter); the
authored rubble rest state; the capstone is 2 slabs, and ~14 Jolt pieces
(the cap handles it). No Blender model; the corbel faces use the glyph
include.
Model budget: **Silhouette geometry** (stepped courses are the silhouette),
**vertex-colour grime** (the vault dark is baked occlusion, free), **import
LODs**. Shader frieze instead of relief saves about 3-5k tris per bay. A hall
of 6 bays is 15-20k tris unoptimised, 6-8k with the tricks.

---

# Facing sheet wall (maker_skin, family makers)
Verb: climb a wall that peels, ride a sheet down, use the exposed earth core
as a fast slope; or, when it's his wall, wait.
Look: the makers' mass construction at its truest: a rubble-and-earth core
faced in a skin of fitted basalt blocks, each block face a big boss
(1.1 x 0.8 m) with a glyph. Tiered like maker_tier but the *facing* is the
point: 3 m wide sheets of dressed blocks held by ties into the core, each
sheet a different shade (quarry batches). Where weathered, sheets have
slid and the **earth core shows**, orange-brown, root-bound, near
vertical; the wall is two materials at once, dark facing and bare earth.
Behaviour: changes state, per sheet. Trigger: `shock` (sheets within reach
shear off, chance by distance, certain inside half range), `body` (his
climb: he grips the face, and the sheets under his hands and feet let go
in 1-2 blocks, his "dust and stones knocked off" climb effect made real),
`slam` (on a *cracked* sheet only). A sheet falls out flat from the top
edge (hinge at the foot, 3-6 m of fall), breaks into 4-6 blocks, rests as
a **scree ramp** against the wall's foot, and leaves the earth core as a
steep dirt face. Earth is one stage: it slumps if shocked again, a loose
slope the walker slides down (a state change of slope, `slump`).
Size: a sheet is 3 m wide (two CELLs by 0.7), 1.6 m (SET_OFF) tall per course,
three courses a sheet; blocks 1.1 m. The exposed core has a talud-like
slope of 70°, climbable by hand-over-hand only with the root drape; the scree
ramp is 3 m of rise per sheet (inside GRAB_TOP twice over: it's the
wanderer's stair). For his lane the foot of a *climb wall* is 6.6 m apron of
scree, no stair; he climbs, so the skin gives his hands purchase to the 22 m
his climb allows.
Collision: facing sheets are plumb boxes (kickable, lips grabbable); the
core is a steep hull (shedding); scree is walk boxes; the earth slump is a
sloped hull that sheds.
Motifs it enables:
- **The Peeling Pyramid**: a stepped pyramid the Olmec climbs after you,
  stripping the faces as he goes so that route you chained up is gone behind
  you (a route closing, not opening).
- **Tell-tale wall**: the pale scree at a wall's foot tells you which sheets
  have gone and which hold.
- **Breach**: a city wall a body can't pass until the sheet is shocked off and
  the earth core is a mound to cross.
Threat pairing: sheets under your hands fall when he climbs the same wall
(shared holds). A fresh scar is also a new ledge: his tear-off is the new
route's start. Roots through the core are a handhold that is always there.
Catches / throws: *Standing*: tops. *Airborne*: lips and roots are grabs;
a sheet falling is a `knock` source `maker_slab` straight down and out from
the wall (about 0.5 pilot-run), 4 m max reach. *Tumbling/stunned*: scree
catches and slides, earth slump sheds out and down. *Riding*: a body grabbing
a sheet as it falls rides it down (hanging at the lip: it is a *ride* to the
foot). Not aimed.
Chains with: the headless body's climb (the trigger), the shockwave of a
leap onto the plateau above, rolling drums stopped by scree.
Build cost: **low-med.** Procedural (plane-cut sheet blocks), a scripted tip
for the sheet (hinge), 6-10 pieces. The earth-core shader is a cheap
parallax/colour swap. No Blender.
Model budget: **Silhouette geometry** (the chipped block edges on the sheet
top), **vertex-colour grime**, **parallax depth** for the bare core's
pits and roots (no tris). Merge fallen sheets (round 1 merge). Saves a
modelled relief wall maybe 6-8k tris per wall cell.

---

# Chocked slab (maker_chock, family makers)
Verb: strike the chock (slam) to drop a slab on purpose; ride the slab; use
the slab as a lid, a bridge, a stair or a trap on the Olmec.
Look: the makers' working stone: a huge slab 6.6 x 6.6 x 1.6 m held
**on edge or tilted over a drop by a wooden-and-stone wedge**: a chock (a
rough basalt wedge with a rope-wrapped timber lever and a crude carved
face) and a counterweight stone hanging in a sling. It is mid-construction
or mid-dismantling: the city half-taken-down by the same hands that raised
it. Rope scars, tool marks, a wooden sledge half-sunk in the earth, a
chisel-cut line where the next cut was meant to go. It is the "dismantled
live" piece: a place where the makers (or the rune-serpent's own fellow)
were taking the city apart for stone and stopped. Weathered, the ropes are
roots and the chock is cracked: it holds only just.
Behaviour: changes state, a hair-trigger. Trigger: `slam` (the wanderer's
flow-charge downdraft slam lands on the chock's strike plate, a marked
2.2 m plate) or `shock` (a leap's shockwave within about 10 m; the chock is
cracked so that it needs only 0.4 power) or `body` (he steps on the plate).
Once struck: a 0.6 s crack/tilt tell, then the slab **swings down on its
pivot, 90 degrees in 0.9 s**, to land across a gap (a bridge), against a wall
(a stair; it ends at 30°), or flat (a lid on a shaft). Or the reverse: the
counterweight drops and the slab **rises** to a standing wall (a closed
gate). Each chock has *one* authored swing, so the motif knows the two
states. Re-armable? No, one shot per layer.
Size: the slab 6.6 m, the same as his minimum landing and lane, the strike
plate 2.2 m (the wanderer's own scale; he steps on it too if it's on his
lane); swing sweep is 6.6 m radius, clear zone marked by a scrape-line on
the floor; fallen slab to adjoining deck must meet within 0.3 m so the walk
box joins (authored hinge to socket).
Collision: slab is a clean walk box in both states, with the swing a moving
kinematic body (carries a rider); the chock plate a clean 2.2 m box; the
counterweight stone a hull.
Motifs it enables:
- **The Wright's Yard**: a quarry-like isle of slabs, stairs and cranes
  caught mid-job; several chocks, each opening one route and closing
  another, so the layout the player leaves behind isn't the one they found.
- **Lid and lure**: a slab that drops to seal a shaft the Olmec is in
  (briefly), then he lifts it and comes out as a landing.
- **Drawbridge ruin**: a slab bridge across a gap, up on its edge until
  struck, the only way across the section; and the body, who can't jump the
  gap until it is down, comes across with you.
Threat pairing: the slab is a trap on bodies under its sweep (a `knock` on
a standing body, about 1.2 pilot-runs along the swing's tangent, source
`maker_chock`, **aimable by the swing direction the card authors**); but a
striker who hits it from the plate rides the plate down. For the Olmec,
the slab is an obstacle he walks through (it's a lintel to him: Break it
and the slab itself *breaks* into the rubble ramp: round 1 cut-slab in two).
Catches / throws: *Standing*: tops, plate. *Airborne*: slam on the plate is
the trigger; the slab edge is a grab. *Tumbling/stunned*: a stunned body
thrown onto the plate **triggers it** (a `toss` thrown weight counts as
`shock` at 0.4); lands on the slab and rides it down, still stunned. A
swinging slab hits bodies with `knock`/`toss` along the swing tangent.
*Riding*: carries the rider through the swing (kinematic, deterministic).
Chains with: the wind blaster (blast a body onto the plate), a seesaw's
end (thrown onto the plate), the head's inhale (a slab on edge is in the
head's pull path), the headless body (the shock is the trigger), the
tumbling block (rolled onto the plate).
Build cost: **med.** Procedural slab with hinge and sling props; the
kinematic swing is deterministic (no Jolt). Rope and timber props as simple
low-poly. One shot, so no reset state needed. Needs a `breaks` entry per
state.
Model budget: **Import LODs / visibility ranges**, **silhouette geometry**
(chisel-cut line and chipped edges), **vertex-colour grime**. The sling
rope is a mesh cylinder (under 200 tris). Saves little but costs little.

---

# Coursed pier of the great stair (maker_stairfault, family makers)
Verb: climb the grand stairs; at a fault, use the fall to descend a floor
(or lose the stair); wait at the landing for the Olmec's weight to drop it.
Look: the **epic staircase**: a stair 6.6 m wide (2 x 3.3, the Olmec lane),
riser 0.4 / tread 0.5 (round 1's maker stairs), up between battered
cheek-walls, broken every 8 flights by a **landing platform 8.8 x 8.8 m**
on a **rubble-core pier** faced in coursed basalt. The landing is the
thing: a stone raft carried on a stepped pier with a hollow chamber under
(unfilled mortar), crown-shaped from a distance. Cracked: the facing stones
at the pier's shoulder slip, a seam opens along the landing's edge.
Behaviour: changes state. Trigger: `shock` (his landing on the landing, or
one flight above; the landing is the weak link), `body` (his weight on a
cracked landing for about 1 s). The break: the **landing drops onto the
chamber below**, collapsing 4-6 m into the hollow (a hole with a rubble
cone), with the flight above falling into a steeper rubble ramp. Rest
state: a sunken landing (below the original level), rubble cone ramp from
the pier's chamber floor, the upper flight ending 4-6 m up in a lip
overhanging the sink, a gap. So the break *closes the stair's walking route
and opens a short-cut down into the chamber and its lower stair* (a lower
level of the city), the climb now needs a jump-and-grab across the
lip, or the lower route.
Size: flights 6.6 m wide (his lane exactly, over the "narrower than ~5 m"
trap), landings 8.8 m (over 6 x 6 m). The sunken landing floor is 8.8 m, so
he can still wade it; the lip gap from the upper flight to the rubble is 4-6 m
(a drop he takes by design, a hang-and-drop for the wanderer, never a
jump). Chamber: 6 m tall, 8.8 wide; the lower exits are authored.
Collision: steps are clean boxes (one box per flight rise); landings are
clean walk boxes; the sink is a clean box with a cone of walk boxes; cheek
walls plumb.
Motifs it enables:
- **The Great Ascent**: the epic staircase of the city, 12 landings, a few
  cracked; the Olmec comes up behind you and each landing of his makes the
  next one more likely to fail: the pressure of the stair.
- **Fault stair**: the stair is the only way, but a landing is cracked;
  the player spends the Olmec's attention to cross it first, or lets him
  drop it for a back door down.
- **Chamber below**: a hollow under every landing, unknown until one falls.
Threat pairing: landings are the traps; the fall is a drop of 4-6 m
(under the 6 m stun fall unless the player is thrown). The Olmec, falling
with the landing, takes his landing's `shock` in the chamber (a pit
shockwave that fans sideways).
Catches / throws: *Standing*: flights and landings. *Airborne*: landing lip
and chamber floor catches, the lip is a grab. *Tumbling/stunned*: slides
down a rubble cone into the chamber (no `toss`). *Riding*: a standing body on
a landing as it drops rides it down, still standing, 4-6 m (about 0.5 s).
Falling landing slab as a `knock`: only beside, never under, source
`maker_stairfault`, 0.4 pilot-runs outward. Not aimed.
Chains with: the headless body (the trigger), the wind blaster at the
head of a flight, logs rolled down the stair (they cross the sink's gap),
tumble run, plinth ram.
Build cost: **med.** Procedural stair and pier from boxes, hollow
chamber authored, the drop scripted as a kinematic sink (no Jolt),
only the rubble cone of 8-12 stones with Jolt. The generator needs a
`levels` link to the chamber below (a motif must provide a lower floor).
Model budget: **Import LODs / visibility ranges** (the flights repeat),
**silhouette geometry** (battered cheek walls), **vertex-colour grime**.
Instancing one flight 8 times makes a staircase 8 flights for the cost of
2k tris at distance.

---

## Motif hunches (the pieces make these; not cards)

- **The Wright's Descent.** A causeway city fragment where the makers were
  mid-dismantle: rolled-back scaffolding, chocked slabs, a felled column
  laid as a bridge across a gap that the earlier crew chose. A body-lane
  of causeway slabs with every one a different rest state, so by the time
  the Olmec arrives the layout has already changed.
- **The Hall of Falling Faces.** A corbel hall at the foot of a stair
  whose landings are cracked; the head waits above, the body climbs the
  stair behind you, and the stair drops a floor at a time, the pale
  fresh-cut dust marking where. The rune serpent threads the hall's skylight
  hole once the capstone is down.
