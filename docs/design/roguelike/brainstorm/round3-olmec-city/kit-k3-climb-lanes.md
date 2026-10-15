# Kit K3: climb lanes (round 3 brainstorm, the Olmec city)

Lens: **grab / climb, lanes for two bodies.** Verb climb or chase. Mood
oppressive. The new kit (working family `olmec_city`, ids `oc_*`, file
`scripts/ruin_kit_olmec_city.gd`) is built around the Olmec, not around the
plane. The ruins kit stays for the dragon stage. This file is the piece
cards for the places where the two climbers meet.

## The two bodies, in numbers

| | Wanderer | Olmec body (headless_body.gd, layer-round11) |
|---|---|---|
| Vertical | `GRAB_TOP` 1.875 m on a jump; `CHAIN_TOP` 2.575 m on the second; `WALL_KICK` 5.2 m/s between walls | climbs any wall up to `climb_max` (20 units) hand over hand at `climb` 1.25 u/s; steps 1.1 u (`step`) |
| Across | long jump about 7 m at `LONG_SPEED` 7.6; pocket sail (glide) past that | `leap_max` 11 u across, `drop_max` 20 u down; `leap_grab` hangs and hauls up |
| Fits | a ledge 0.5 m deep | 4.4 m wide, 2.4 m deep, 6.7 m to the neck; **stairs at least 5 m wide, landings at least 6 x 6 m, gorge shelves at least 6 m or under 2 m** |
| Speed | run 4.8 m/s, faster | `chase_speed` below the run; the pounce and landing shockwave are his catch |

The rule I design to: **two sizes of lane on one face.** His lane is wide,
flat, plain and rough (6 m, no gaps). The wanderer's lane is narrow, broken
and clever (0.5 m ledges at 1.6 m spacing, slots, undercuts). A piece says
where the lanes share space (he can reach, shake or break the other's lane)
and where they split (the other can't enter). Nothing here is a scripted
chase; a body takes either lane or crosses to the other.

Sizes are written as multiples of `RuinKit.SET_OFF` (1.6 m, under `GRAB_TOP`)
and `CELL` 4.4 m from K5, so the new kit lies on the same grid. Where I
give metres they are before `WorldScale` (the wanderer scale).

**How things break, in common.** The destruction round
(olmec-destruction-round1.md) breaks a pier at a drum joint and a lintel in
two, by his bulk box, a lintel's length, or his shockwave front out to 0.62 of
its reach, with a hit-stop, a camera jolt and a stagger. These pieces use
the same three triggers and make **each piece's breakable part its own
Build** with its own mesh and body, as the colonnade does. What breaks is
always the **wanderer's lane or the decoration, never his only lane**: he can
break a way to the wanderer, but the wanderer cannot break him a way he lacks.
Broken stone becomes `RigidBody3D` rubble (friction 0.9, almost no bounce),
and the rubble is itself a lane (a heap climbs to a ledge).

---

# Relief face (oc_relief, family olmec_city)
Verb: climb. A cliff face carved as one giant seated figure in relief (a
jaguar-faced lord in a headdress, in profile); the wanderer ledge-chains up
the carving, the Olmec simply climbs the stone.
Look: a 14 to 20 m wall, one huge bas-relief carved out of the cliff itself,
battered basalt in `olmec_stone.gdshader` with rune grooves along the bands.
Read from a distance as a face in the haze: brow, a big flat nose, a heavy
lip plug, ear spools, a stepped headdress. The overgrowth is roots hanging
off the headdress and a wet stain under each eye. At the top the cornice is
the headdress's crown, which carries the lip (next card). Nothing glows; in
torchlight the deep eye sockets are black pits and the pale polished cheek
catches the light.
Behaviour: static, with three **breakable lugs** (the nose, the lip plug, one
ear spool). Each is a block on a hidden dowel. They break when his hand or
foot takes them while he climbs (his rays find the face, `standoff` 0.25 m),
and by his shockwave. A broken lug falls as rubble and leaves a socket (a
0.4 m pit, a grab), so the face stays climbable.
Size: face 6 m wide at the base (a hand-over-hand lane for him, and he can
use the whole wall), 14 to 20 m high. The wanderer's lane is the relief: brow
ridge 0.6 m deep at 3.2 m, nose 0.7 m at 4.8 m, lip plug at 6.4 m, ear spool
at 8 m, headdress tiers every 1.6 m above that. That's a series of ledges at
`SET_OFF` spacing, so one jump catches each lip (under `GRAB_TOP`) and the
wanderer chains upward. The wanderer's lane runs up the right of the face
(the profile's nose side) and **crosses the Olmec's centre line at the eye
brow**. Ledge widths are at least 0.5 m so a stand and a rest are possible.
Collision: each ledge a clean `_walk_box` top and a plumb box under it; the
face between is a plumb wall (wall-kickable but not walkable); lugs are
separate convex hulls; the headdress cornice is a deep box.
Motifs it enables: the Face (a cliff the whole motif is arrival at); a
gorge wall one climbs while he climbs the opposite wall; a sheer-sided
pillar isle reached only by the face.
Threat pairing: **he is the threat** and the face is the shared lane. The
wanderer under him is on the same stone: if he stops in the nose and pounds,
the wall shakes (see Catches). Lugs are broken only by him (he breaks, she doesn't),
so the wanderer's lane is never hers to sabotage.
Catches / throws: **standing** on a ledge: carried, safe. **Hanging** on a
lug when it breaks (`oc_relief_lug`): drops as a stunned `toss`, straight
down and out 2 m/s from the wall, `restun_gap` 1.2 s respected, so the fall
becomes a free fall onto whatever is under (the ledge below, a rope, a pilot
glide to a wall). **Airborne**/wall-kicking: the face is a normal wall.
Rubble from a lug (a 0.4 m block) tumbling down is a `knock` (0.2 s stun,
3 m/s down the wall) only if it hits a body; source `oc_relief_rubble`. No
aiming; the face is placed and the lug that breaks is the one he grabs.
Chains with: the hauling lip (top); wind blaster (a gust on the face pushes a
chaining body into the wall or off it); rope bridges that start at the
face's side; the rune serpent passing in front of it (a 90 m body crossing
the eye is the scene: "the eye turns").
Build cost: **high.** A Blender model: the relief carving is one sculpt,
baked (normal, AO, curvature) onto a few low-poly slabs with real silhouette
geometry on brow, nose, plug and crown. Lugs are separate meshes. Collision
is procedural boxes from the same table.
Model budget: sculpt high, bake low (the whole relief); silhouette geometry
(brow, nose, headdress); parallax depth (the groove bands); vertex-colour
grime; LODs and visibility ranges (the far version is a flat slab with the
baked relief); one mesh instanced for a tall face with 3 repeats of the base.

---

# Hauling lip (oc_lip, family olmec_city)
Verb: chase; hide; climb. The cornice at the top of a climbed face, built for
the moment his hands come over the edge in the dark.
Look: a deep cornice (1.2 m overhang) with a **worn hand-trough**: two
palm-width grooves, each 0.6 m long and 0.4 m deep, ground into the top edge
by a thousand years of his kind, 3.2 m apart (his shoulders). A scatter of
fine pale dust in the grooves, rune bands running along the cornice's
lower face, and a dark undercut behind the overhang. Behind it a floor
6 x 6 m of plain stone before anything else (his landing rule; the mantle
sends a small shockwave there). Nothing glows, but a **brazier niche** can be
set in the top, so his head rises into a faint flicker as he comes over.
Behaviour: static, with a **breakable corner**: the end 4.4 m of the cornice
is a pre-cracked slab on a hidden joint. It breaks in two at the groove when
his mantle's small shockwave runs along it, or when he leaps onto it (a pounce
landing on a corner is the usual way). It falls as a ramp of rubble beside
the face.
Size: overhang 1.2 m; the lip is `GRAB_TOP` for a jump-catch from the
ledge below (so the wanderer arrives at it by chain and hauls over in the
usual way). The undercut is 1.0 m deep by 1.6 m high: a wanderer **hanging
under the lip is out of his sight** (cover from the ground above; he does not
look down over the lip unless he has heard her). The grooves are 3.2 m apart
so a wanderer there is on his hand spot and gets shaken.
Collision: the top a clean box 6 x 6 and a plumb box under; the undercut a
cut-out (the wall is not full height in the undercut so a body can hang from
the lip's edge); the pre-cracked slab a separate Build with a box hull.
Motifs it enables: the Heave (the top of any climbed face where he comes
over); an ambush ledge (the wanderer hides under, he stands over); a
dead-end lip with a drop side.
Threat pairing: the lip is his weakness as well as hers. He **cannot see
down the face while hauling** (hands over lip, head still under it), so a
wanderer on the lip's top at the moment he comes over is in his reach but not
his sight (the swat is at `catch_reach`). A wanderer hanging in the
undercut is in neither: the Olmec mantles over and walks away.
Catches / throws: **hanging** under the lip as he mantles: the mantle's
small shockwave jars the wall; a hanger within 3 m of his grooves is `knock`ed
off, 4 m/s away from the face, stunned 0.6 s, source `oc_lip_jar` (a
small fall into the ledge below; a chain with a glide). **Standing** on top
within the mantle shockwave front: thrown back and up as the headless_body
mantle's wave does already (that is his existing `_shock`). **Corner break**:
a body on the slab at break time is carried down as a `toss` with the rubble
(down 6 m/s, still standing on the falling slab for 0.4 s, which can be ridden
to a lower ledge). No aiming.
Chains with: the relief face (below it), the processional stair (a landing
under the lip), the shaft (its exit), rope swings anchored to the cornice.
Build cost: **med.** A small Blender model of the cornice section (grooves,
undercut, runes); the slab and the dust are procedural. The mantle already
exists; the lip's job is to give the model something to stand on.
Model budget: silhouette geometry on the overhang and the corner; bake the
groove wear (normal and AO); parallax for the dust in the grooves;
one mesh, 4 variants by mirroring and a 2 or 4 cell width.

---

# Leaper's pit (oc_pit, family olmec_city)
Verb: time a crossing; climb; chase. A gap with two landings and a narrow
cornice round the pit's inside wall: **the jump is his, the cornice is hers.**
Look: two broad plinths facing each other across a square pit (9 m across, 18
to 30 m deep, black at the bottom, mist in it), each plinth a 6 x 6 m
slab with a worn **stride-mark** on the takeoff: two boot-print hollows,
2.2 m long, set 4.4 m apart, pressed into the stone like the places a giant
stood to jump. Round the pit, 1.6 m under the plinth tops, runs a 0.6 m
cornice of the plinth's own masonry. The pit's walls have rune bands.
Behaviour: static, with a **breaking cornice**: the cornice is built in 4.4 m
segments (K5's CELL), each its own Build, each resting on corbels. The
Olmec's landing shockwave runs out along the ground of the far plinth and
through its stone, and a segment within the wave's reach breaks off in order
nearest first. The wanderer's lane **crumbles in the order he lands**.
Size: the gap **9 m** is the sign. At 9 m the wanderer cannot jump it (his
long jump is about 7 m), but she can glide (pocket sail) it from a run if she
has height; he leaps it (within `leap_max` 11 u). The family sets four gaps:
**4.4 m** (both leap, a stride-mark of one), **9 m** (his, her glide), **14
m** (neither: a bridge or a rope), and **the pit that has a cornice** (hers,
slow). Stride-marks are always on the side he leaps from, so the player reads
who crosses by the worn feet. The cornice's 0.6 m width is a ledge-chain
with a rest every 4.4 m.
Collision: plinth tops clean boxes, the far lip a box; cornice segments boxes
of 4.4 m x 0.6 m; pit walls plumb; the pit's floor a void kill below (`lost`).
Motifs it enables: the Divide (two halves of a city joined by this);
a pit of rubble ahead of a stair; a shortcut with a gap only she can take.
Threat pairing: **his leap is the threat's reach.** He pounces over 9 m
(`pounce_max`) at a wanderer who is on the far plinth. The same landing that
shakes the cornice breaks it, so crossing on the cornice while he leaps over
is a bad idea; but under his arc is out of sight (the arc passes over).
Catches / throws: **standing** on a plinth: stone. **Hanging** on the
cornice when a segment breaks: dropped as a stunned `toss`, straight down
with 2 m/s of drift toward the pit's middle, source `oc_pit_corbel`. That
falls into a pit with no floor: the death. A **gliding** wanderer over the
pit above his arc: clear (his shockwave only touches the ground, the headless
body's rule). **Stunned/tumbling** over the plinth edge: falls into the pit.
Not aimed; the player may aim herself.
Chains with: wind blaster (a gust across a 9 m gap gives a glide the extra
metres); the leap-grab (leap_grab 1: he hangs from the far lip instead, lit
and exposed); seesaw (the plinth carries one) ; the rune serpent crossing
the pit's mouth.
Build cost: **med.** The plinth is procedural boxes and a decal; the
cornice is a repeated Blender piece (one 4.4 m segment with corbels and
carving) and its rubble is physics (one RigidBody3D per segment, falling).
Model budget: instancing (the cornice segment repeats); bake wear; silhouette
geometry on the corbel noses; visibility ranges (far pit is a black quad).

---

# Wrapped pillar (oc_wrap, family olmec_city)
Verb: climb; chase. The city isle as one great pillar with a spiral ramp
wound round it. He walks the spiral; she climbs the core.
Look: a square or round monolith 12 to 16 m across, 30 to 60 m high, its flanks
carved with glyph bands; a 6 m ramp winds round it in a left-hand spiral, one
turn every 24 m, with a low parapet of stepped serpent scales on the outer
edge (the rune serpent's kin). Under each turn the ramp's underside hangs as a
dark soffit with a rib ring. The outside is a drop into the abyss; from far
away the pillar is a dark column with one pale thread winding it, and the
far isles fade in the haze behind. At the top: a flat crown with a hall or
altar (a motif).
Behaviour: static, with **breaking edge slabs**. The ramp's outer 1.6 m is
made of 4.4 m slabs on corbels (the pit's cornice, deeper) that break under
his landing or bulk and leave notches. Each notch is a 4.4 m bite out of the
ramp's outer edge: the ramp is still 4.4 m wide, but the gap is a leap.
Size: ramp 6 m wide (his need is 5 m), slope under 1 in 2 (easy for him,
`step` 1.1 u), turns have a 6 x 6 m landing at each corner of a square
pillar (his landing rule). The core's glyph bands are **plumb with 1.6 m
set-offs** every 3.2 m, so the wanderer climbs the core straight up
between turns, cutting each turn's 24 m with an 8 m climb. Where the ramp
passes over a ledge, there is a 2.4 m gap above the wanderer's climb (a
hatch, window-slot or the soffit) so she can pop out onto the ramp. Chimney
slots 2.4 m wide cut into the pillar corners are wall-kick lanes (K5's
palisade gap).
Collision: ramp tops a clean wedge box; slabs separate boxes; soffit plumb;
core a plumb tower with ledge boxes; parapet scales are a rail-slide (the
balustrade slide).
Motifs it enables: the Spire City; a stack of two wrapped pillars joined by
an aqueduct; a ring of wrapped pillars round a central abyss, as the sky-island
look wants: stone pillars over a void.
Threat pairing: **the two lanes cross every turn.** She climbs 8 m on the
core while he walks 24 m; she arrives at each turn first and can drop onto the
ramp ahead of him or cut back. He cannot reach her on the core except by
climbing (his own climb is faster than the walk and goes the same way as her,
a straight chase up a wall). So the pillar is a race with a choice of
lane. The parapet slide gives a fast way down.
Catches / throws: **standing** on the ramp: moves with the ramp. **Hanging**
from the soffit rib: out of his sight below and behind him as he walks over.
**Tumbling** down the ramp: carries along the slope and is thrown off the
outer edge unless the parapet scales hold it (`oc_wrap_parapet`, restitution
0.6 off the scales, source `oc_wrap_parapet`, which keeps the stun on). A
notch broken by him: a body on the slab falls as a `toss`, straight down, 3
m/s outward, source `oc_wrap_slab`.
Chains with: rope swings between two pillars; wind blaster up the face; the
rail slide down the parapet to a ledge; the plane is out, the glide in.
Build cost: **high.** A Blender model for the pillar shaft (the sculpted
glyphs baked), a procedural spiral ramp (parametric, tiles on the CELL), and
physics for the breaking slabs.
Model budget: instancing (slabs, scales); bake the glyph bands; silhouette
geometry on the parapet; visibility ranges and a billboard impostor for the
far pillars in haze (the city's skyline); the core as a low-poly tube with a
height map.

---

# Slotted wall (oc_slot, family olmec_city)
Verb: hide; climb; time. A thin wall, its two faces two lanes, with arm
slots he can reach through and a chimney she can climb inside.
Look: a 12 m high wall of dark basalt, 4.4 m thick, with a hollow inside: a
2.4 m wide chimney running up the middle, between two walls, open to the sky
at the top. On his side, 1.2 m wide slots cut through the wall at three
heights, each framed with a carved lintel. The slots are dark; the chimney
walls inside are rough-cut with ledges every 1.6 m on one face (a stair for a
wall-kicker). Light enters the chimney only from the top, so a column of
grey falls down the inside; the room itself is black.
Behaviour: static, with a **breaking panel**: one 2.4 m panel of the
slotted wall is a plain slab set in the wall, whose break opens the
chimney to the outside. It breaks under his bulk box (he shoulders it),
or by his shockwave from the ground beside it. It falls inward as rubble
and fills the chimney's floor.
Size: the chimney 2.4 m wide (a wall-kick lane: `WALL_KICK` 5.2 m/s,
kicks up 1.4 m at a time between two faces 2.4 m apart; this sets the
width for a climb of about 12 m). The slots are 1.2 m wide, 2.2 m tall: his
arm reaches in (`catch_reach` swat), a hand 0.6 m. The wanderer's ledge
face has `SET_OFF` 1.6 m steps, so she can climb rather than kick. The wall
is 12 m, within `climb_max`, so he climbs the outside to the top.
Collision: the shell a plumb hull per face; the chimney's floor a box; ledges
clean boxes; the slots cut-outs with a lintel box; the panel a separate Build.
Motifs it enables: the Chimney (a secret lane up through a fortress wall);
a gatehouse with a hidden side; a murder-hole stair up inside a pier.
Threat pairing: she is **safe in the chimney from sight but not from his
hand**. A wanderer in the chimney who has been heard is swatted through a
slot (a reach into the dark is the scare). The whole wall can be torn open
(the break), which turns a hide into a chase.
Catches / throws: **standing/wall-kicking** in the chimney: normal.
**Hit by the swat** through a slot: `knock` 7 m/s into the opposite wall
(she bounces off it: the K5 carom, reflected 0.6, stays stunned), source
`oc_slot_swat`, falling in the chimney onto its floor (a box, safe) or out
through the panel if it is open. The panel break throws a body standing
against it outward as a `toss`, 4 m/s, source `oc_slot_panel`. Top exit: the
chimney's top is a hauling lip (oc_lip).
Chains with: the hauling lip (top), the relief face (the chimney's exit is
behind the nose), K5's palisade (a gap is a chimney).
Build cost: **med.** A Blender shell with slots and ledge faces; the
panel and the carom are procedural; the swat is the existing animation.
Model budget: silhouette geometry on the slot lintels; bake AO inside the
chimney (it is dark); instancing for 2 variants (6 m and 12 m); LODs.

---

# Processional stair (oc_proc, family olmec_city)
Verb: climb or chase. The epic staircase: a wide stair whose flank is a
serpent, meant for both bodies at different speeds.
Look: a stair 6.6 m wide of broad low steps (riser 0.4, tread 0.8, under his
`step`), rising in flights of 12 steps to a 6 x 6 m landing, with three
flights to a turn. On each side a **stepped serpent balustrade**: a
carved serpent (rune-serpent kin) whose body steps with the stair, scales
raised 0.5 m, ending at the bottom in a huge head, jaws open, as the stair
mouth. The side walls outside the serpent are the relief bands of a glyph
wall. In haze the stair is a pale ribbon with dark flanks; in torchlight the
serpent's eye is a polished spot.
Behaviour: static, with **breaking serpent segments** and one **false
flight**: one flight of the three is a ramp of loose drums (the flights on
the processional way is built from them) that fall in sequence when the
shockwave runs through; the pieces roll down the stair (physics) as
rubble. The serpent's body breaks in 4.4 m coils off the stair edge and
fall into the abyss.
Size: width 6.6 m (his need 5; 1.6 m over), flights rise 14 m each, landings 6 x
6 (his), serpent balustrade wide 1.2 m, height 1.6 m at the scales (a
SET_OFF: the wanderer climbs the serpent's back as a ledge-chain over the
parapet). The serpent's back runs as a slide (the balustrade slide) for the
descent. So the climb for her is: the serpent ladder up the balustrade
(1.6 m scales), the stair's side wall, or a run up the stair itself, which is
the wide lane she shares with him. The head at the bottom, 4 m high, is a
good climb.
Collision: stair treads clean boxes, landings boxes, the serpent a stepped
chain of boxes on the stair's slope plus a slide hull; the head a convex
hull with grabbable lips; drums are cylinders with mass by volume.
Motifs it enables: the Procession (a stair climbed in the open under the
haze with the abyss on both sides); a coliseum entry; a stair to the sundered
hall.
Threat pairing: **the stair is his and everyone else's problem.** He climbs it
fast because it's broad, and a wanderer on the stair is in the open. The
serpent is her escape: on its back she is on his flank and above his
reach (he cannot swat through the scales if she is on the outside coil).
Catches / throws: **sliding** down the serpent: carries at 6 m/s along the
balustrade's slope; the head at the bottom is a launch: it throws a body that
leaves the head at slide speed, 5 to 7 m/s, 20 degrees up, **aimable** by
where the stair lands (the generator points the head at the next link),
source `oc_proc_head` (not stunned, a normal toss). **Tumbling** down the
stair: slides and bounces on the treads, carried 8 m/s. A broken coil: a body
standing on it falls (a `toss`, 3 m/s outward, source `oc_proc_coil`). The
false flight's drums rolling down are a `knock` (6 m/s down the stair, 0.8 s
stun, source `oc_proc_drum`) which can sweep her and him alike: **his own
shockwave rolls the drums on her.**
Chains with: the hauling lip (top landing), the wind blaster across the
stair, a rope bridge from a landing, the leaper's pit at the top landing.
Build cost: **high.** The serpent balustrade is a Blender model (a repeated
coil with a head), the stair is a parametric procedural, drums are physics
(a count of about 12 per flight).
Model budget: instancing (coil, tread); bake the scales; silhouette
geometry (the head's jaws); visibility ranges (far stair is a ribbon);
rigid parts on bones is not needed (the drums are physics bodies).

---

## Motif hunches

- **The Face.** A cliff isle whose near side is one oc_relief (the lord's
  profile, 18 m), arrival from below by oc_proc along its foot, summit a
  hauling lip with a hall behind it. The two lanes cross at the brow; he
  comes up the middle in the haze and the first thing you see of him is a
  pair of hands on the headdress.
- **The Spire City.** Three oc_wrap pillars of different heights over a
  common abyss, joined by two aqueduct spans (K-aqueduct from the other lens)
  and an oc_pit gap; a skyline of dark columns with one pale ramp winding each.
  The player never sees the floor; far pillars fade into the haze, and
  the rune serpent turns slowly among them.
