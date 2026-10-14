# Kit K5: the makers (round 1 brainstorm)

**The family `makers`** (scripts/ruin_kit_makers.gd, ids `maker_*`): what the
people who carved the colossal heads built for themselves. It is the gothic
kit's opposite. Gothic is tall, pierced, pointed and thin. The makers' work is
low, heavy, battered and solid: mass with the openings cut into it, never
framed around it. Most of it is stepped earth faced in basalt, with a few
natural basalt columns, and monoliths set on end. It all wears the Olmec's
stone (shaders/olmec_stone.gdshader) instead of ruin_stone, so a maker ruin and
the inhaler head read as the same quarry.

**Rules.**
- **Module grid.** The cell is `CELL` = the gothic `BAY` (4.4 m, also
  `GRAND_WIDTH`), so a maker terrace butts flush against a gothic vault bay
  or grand stair. The two styles share one ground plan, and the makers' work
  lies underneath because it is older.
- **The rise.** Each tier rises `RuinKit.SET_OFF` (1.6 m, under `GRAB_TOP`
  1.875, so one jump catches every lip). A tier is a battered *talud* (0.6 m,
  sloped about 60°, too steep to stand on) under a vertical *glyph band*
  (1.0 m, plumb). The band can be wall-kicked and carries the runes.
- **The steps** are steeper than the gothic stair: riser 0.4 (under
  `STEP_UP` 0.45) and tread `TREAD` 0.5, so four steps climb one tier
  exactly. A flight of 4n steps always lands on a tier top.
- **The mass.** Every top that is meant to be walked is at least `TOP_ROOM`
  across. Every ledge meant to be climbed onto is at least `STAND` deep. Every
  opening meant to be flown is `WorldScale.opening(toy)`, with its toy width
  named in the file.
- **Joins.** Pieces join face to face on the cell grid, and tier tops land on
  multiples of SET_OFF, so stacked or neighbouring pieces meet at a shared
  height with no step.
- **Collision.** As in RuinKit, every walked top and tread gets clean
  `_walk_box` hulls and the worn masonry is mesh only. A talud is one true
  sloped hull. A glyph band is one plumb box.
- **The stone.** Pieces carry the rest position in UV/UV2 and the baked
  crevice occlusion in COLOR.a, as `inhaler_head_look._dressed` does. Glyph
  bands put their carving in CUSTOM0/CUSTOM1 for a new
  `maker_glyphs.gdshaderinc` (the serpent's include draws its own spine and
  flanks, so it doesn't fit). That include cuts runes as grooves, with the
  serpent's `rune_cut`. It keeps the serpent's lit-groove light only faintly,
  at night and near the pilot, because the kit's rule is that no ornament
  glows. Overgrowth uses RuinGrowth unchanged, but the makers' growth is
  heavier: root mats and strangler roots over the tops, with less ivy.
- **Links, not scenery (everything chains).** The makers built for a game
  played with bodies, and their stone still plays it. Every piece answers
  root metadata the way a hall answers `walk` and `ends`:
  - `mounts` lists where moving or launching pieces attach. Each entry is
    `{kind, at, facing, room}` in the piece's frame. Kinds used below:
    `deck` (a top that can carry a seesaw, wind vent or the head's round),
    `mouth` (a carved mouth that holds a wind blaster or sluice nozzle, aimed
    along its facing), `run` (a straight walked lane for logs or a tumbling
    block), `pivot` (a seesaw's fulcrum), `rope` (a swing-rope anchor), and
    `rim` (where it throws off the isle).
  - `catches` lists landing pads sized to catch a throw, each `{box,
    from}`, where `from` is the arc it's sized for.
  - `throws` lists where it sends a body, each `{at, dir, speed}`.
  The generator never turns isles, so a motif aims a link by how it places
  the piece inside its own frame, and the piece reports its throw in that
  frame.
- **Carom.** Some faces are marked `carom`. A body that is stunned or
  airborne and hits one faster than a run is reflected (restitution about
  0.6, minus the normal's share) as a `toss` with the piece's source name, so
  it stays stunned. That is a small new surface rule in PilotMotor's wall
  contact, and the only new physics the family asks for. Slopes need no new
  code: a talud is too steep to stand on, so a tumbling body slides down it
  and is shed off its foot, going the way the slope faces.
- **Sources.** Each piece's toss names the piece (`maker_court`,
  `maker_head` and so on). That keeps it distinct from the inhaler head,
  the wind blaster and the seesaws, so a chain through makers' stone isn't
  cut short by `restun_gap`.
- **Wear.** `weathered` 0 means the makers' work is long abandoned but still
  sound. At 1 it is slumped. Earth cores bulge through missing facing,
  columns lean and fall, and stelae topple. Every piece keeps what it is: a
  terrace keeps its tops and a stair keeps its steps.

---

# Stepped tier (maker_tier, family makers)
Verb: climb (ledge grab and chain up the glyph bands), wall kick between two
tiers set face to face, run the tops, slide down the inset stair's cheeks.
Look: a square or L-shaped block, one to four tiers (SET_OFF each), each
tier stepping in by `STAND` plus 0.4. Each tier is a sloped talud under a
plumb glyph band. The band is carved in a running frieze of squared,
cleft-browed faces, each like the inhaler's own face shrunk to a hand's
height, so the frieze repeats the enemy in miniature. Corners are
rounded-off cushions of stone, not arrises. Weathered, the facing has fallen
away in sheets and the earth core shows, root-bound and dark, with roots
gripping the band's lip. A variant `stair` face has an inset stair four
steps per tier, running up one side between plain sloped cheeks. The top tier
is a flat paved deck that can carry another piece.
Behaviour: static.
Size: tiers SET_OFF (1.6), so every lip is caught from the tier below with
one jump. Steps in are STAND+0.4, so you can stand on each ledge and take a
run-up. A two-tier rise without a ledge (3.2) is out of reach on purpose,
except on the corner where a root drape gives a halfway hold. One cell is
CELL square, and the footprint is 1x1 to 3x3 cells.
Collision: clean walk boxes for each tier's top and each tread. The talud is
a sloped hull (it sheds the pilot and can't be stood on). The band is a plumb
box (kickable, and its lip is a grab). The stair cheeks are clean sloped boxes
the pilot can rail-slide.
Motifs it enables:
- A sky pyramid stacked over the isle's edge, with its stair facing the
  drop: the stair is the way in, and the far side is a cliff of glyph bands
  to chain up.
- A terraced isle flank whose tiers run around a crag, with rope bridges
  between tier tops on neighbouring isles.
- Two tiers set face to face one opening apart, making a kick chimney the
  plane also threads.
Threat pairing: a talud is where knock-offs happen. A pilot slid or blasted
onto one slides off the tier. The head's pull dragging you across a sloped
course is the danger, but a crouch on the walk box above it braces you.
Weathered, a facing sheet hangs loose: landing a slam on it drops it, which
makes a new ledge below and takes you down with it.
Catches / throws: *Standing*: tops and treads are walked, and the stair
carries logs down. *Airborne*: every band lip catches. The deck is a
`catches` pad at least 2 CELL square, sized for a seesaw toss or a
blaster's knock landing still stunned, which is about 0.8-0.9 s of poise
travelling 6-8 m out. *Tumbling/stunned*: a body landing on a talud slides
down it and off its foot onto the next tier's walk box. A stack of tiers
is a cascade of short drops, each under the fall stun's 6 m, so it delivers
a body to the foot one tier at a time, with each slope pointing it the way
its face looks. It throws by shedding (no `toss`, plain sliding). Its
direction is the face's, so the motif aims it by which face looks where. The
frieze faces' carved mouths are `mouth` mounts: a wind blaster there
`knock`s whoever passes on the tier below out over the edge, aimed along the
face. Mounts: `deck` (top), `mouth` (band, one per cell per face), `run`
(the inset stair, for logs or a tumbling block coming down it), `rim`
(the stair's head when it faces the drop).
Chains with: the inhaler head (blast lands you on a deck; the head's
round can drift a deck), the seesaw and slam seesaw on the deck (a body
thrown onto one end throws the other), logs and the tumbling block down
the inset stair, the wind blaster in a band mouth, and maker_court and
maker_throne as neighbours on the grid.
Build cost: **low-med.** It is procedural, built from Build.solid blocks the
way the gothic wall and buttress are. Talud, band and stair are all plane
cuts. The new parts are the glyph include and the UV rest/occlusion feed
into the Olmec shader.
Model budget: silhouette geometry (chipped lips, the fallen-sheet bites)
applies; flat band faces get their frieze from the shader, which is better
than modelled relief and saves maybe 2-4k tris per band cell. Vertex-colour
grime applies (the kit already bakes it), essentially free. Import LODs and
visibility ranges apply once a layer has many tiers: an estimated 30-50% of
the tiers' draw cost at range. Sculpt/bake, parallax and rigid parts don't
apply.

---

# Column palisade (maker_palisade, family makers)
Verb: climb an organ-pipe stair of column heads, wall kick up the slot between
two rows, slide down a leaning column, hide (cover between the rows).
Look: natural columnar basalt, five- and six-sided prisms set on end side by
side in a line, like the tomb walls the makers built of columns. Their tops
run at uneven heights like organ pipes, and they are lashed at mid-height by
a band of carved stone pegs. Under the shader the basalt is darker and
glassier than the facing stone, with grooves running along the prisms
instead of across them. Moss grows in the joints, and a strangler fig's roots
pour over the line. A `double` variant has two rows a slot apart, roofed by
basalt columns laid across them, forming a tomb passage.
Behaviour: static. Weathered, a few columns lean against their neighbours or
lie fallen across the slot, and that is baked into the build.
Size: a column is about 0.6-0.8 across (6-sided apothem 0.35). Heads step
up the row in rises of SET_OFF or less, and each head is wider than STAND,
so the run of heads is a hop-and-catch staircase. The double row's slot is
under `WorldScale.opening(TOY_THREAD)` wide when it's meant for kicking
(about 1.6-2.2 m, chimney width), or a full flown opening when its roof has
fallen in. That is two variants, never one size in between. A full row is
one CELL long.
Collision: each column is its own hexagonal hull, so its faces can be kicked.
Each head gets a clean walk box, so a column's top is never a gap. A leaning
column is one hull at its angle (a slide ramp, and a rail along its
arris). The roof columns of the double row are walked boxes.
Motifs it enables:
- A tomb passage under a stepped tier: walk in along the slot, then kick up
  the chimney and out through a fallen roof column onto the deck.
- A fence of basalt prisms stepping up a ridge, making a staircase of heads to
  a stela at the top.
- A ring of palisade around a buried head, a corral that held it (see
  maker_head).
Threat pairing: the slot is cover from the dragon and from the head's
pull, because stone blocks the pull completely. It is also a trap: the
headless body climbs palisades, and inside the slot there is nowhere to go
but up. A leaning column that a slam knocks over can bridge you across, or
knock the body off.
Catches / throws: *Airborne*: the column heads are catches and lips for
the run up the organ pipes. *Tumbling/stunned*: a body knocked into the
slot falls between the plumb columns. With the tech on, each side is a wall
to kick off. Without it, the slot floor catches you, a corridor you can't be
knocked sideways out of. The slot is the family's **cannon**: a wind vent
on its floor (`deck` mount) makes the chimney an updraft that throws a
stunned body straight up and out of the fallen roof gap, still stunned. The
vent's push sends him about two pumps over the roof, and the motif sets a
catch pad (a tier deck) beside the gap. A leaning column is a slide ramp. A
downed body slides off its low end with slide speed along the lean, a
shed you can aim (the lean's bearing is a seed knob within the motif's
frame). Mounts: `deck` (slot floor, a vent), `run` (the slot as a lane:
a Ram charging down it, or a tumbling block), `rim` (the roof gap, throwing
upward), `rope` (the strangler fig's roots over a high column hold a swing
rope).
Chains with: the wind trap (vent in the slot), the Ram and the tumbling
block (down the slot, with no dodge but up), maker_tier (the roof gap
throws onto a deck), the headless body (climbs in after you), and maker_head
(the corral around it).
Build cost: **low.** Prisms are the simplest Build.solid (a hexagon cut by two
caps and its wear). The lean and fall are baked, with no physics. It is the
cheapest piece in the family and a good first one to build.
Model budget: silhouette geometry (chipped prism ends) applies, about 12
tris per column extra. Vertex-colour grime in the joints applies. LODs and
visibility ranges apply strongly, since rows repeat: merge a row (RuinKit
`merge`) into one draw. Merged, a 20-column row is about 1 draw call
instead of 20.

---

# Cave-mouth throne (maker_throne, family makers)
Verb: slide or crawl through the niche (a tunnel through the mass), ledge
grab the table top, hide (a cover socket), perch (trader or ledger
activity).
Look: a great rectangular altar block about two tiers high. Its top
overhangs on all sides like a table, carved underneath in a band of
were-jaguar gums and crossed bands. On its front, a deep niche opens as a
cave mouth with a cleft brow. In the niche, a seated figure in the inhaler's
helmet leans out holding a rope that runs carved round the block's flanks to
captives at the corners. Here the figure is hollowed, and the niche goes
right through the block to a second, smaller mouth at the back. Roots hang
from the overhang. A bowl is cut into the top. Weathered, the overhang is
cracked off on one side (a ramp down), and the figure's face is worn smooth.
Behaviour: static. Optionally the cut bowl holds a ledger activity
(rune set, offering), the motif's perch.
Size: block top 2*SET_OFF (3.2) high, out of a standing grab from the
ground on purpose. A plinth course 1.2 high (caught with a jump) runs round
it, and from the plinth the top is 2.0 over, which the pump (CHAIN_TOP 2.575)
catches but a plain jump (GRAB_TOP 1.875) doesn't. Other ways up are the
cracked-off ramp, a kick off a neighbour, or the twirl. The overhang is 0.5 m. A hanging catch on its lip
is a ledge hang and shimmy around the block. The niche is about 1.2 high by
1.4 wide, a crouch-slide tunnel (the pilot's slide height). The top is at
least 2 CELL x 1 CELL.
Collision: clean walk box on the top and plinth course. The overhang lip
is a plumb hull's top edge, so it grabs. The niche is a walked box floor
inside two side hulls and a roof hull (a true tunnel). The figure's hollow is
dressing.
Motifs it enables:
- A ballcourt's end stage: the throne at the head of maker_court, its top the
  perch the plane parks beside.
- A summit shrine on a stepped tier: the tunnel is the shortcut through,
  under the pull of a head drifting outside.
- A camp alcove (a tender mercy): campfire in the niche, out of the wind and
  out of sight.
Threat pairing: the tunnel lines up with the head's breath: crawl through as
the head inhales and you're pulled out the far mouth faster than you can run.
Used on purpose, that's a launch. In a stack, the overhang shadows the tier
below, so the dragon can't see you, and so neither can you.
Catches / throws: the tunnel is a **barrel**. *Sliding/tumbling*: a body
sliding or tumbling into either mouth is kept in the tunnel's line, because
its walls are plumb and its roof low, and comes out the other mouth at its
own speed along the tunnel's axis. *Riding the pull*: the inhaler head
drags you through it faster. With a wind blaster mounted deep in the back
mouth (`mouth` mount), the throne becomes a cannon. Anything that enters the
front is held by the draft and then blown out the front mouth with a
`knock` of about a blaster's 8 m/s, about 0.9 s of poise, about 7 m out
before it falls. The throne's front faces +Z in its frame, so the motif
aims it by how it places the throne. *Airborne*: the overhang lip catches
with a hang, from any side. The top is a catch pad 2 CELL x 1 CELL. The
cracked-off overhang is a short ramp that sheds a downed body down its
slope. Mounts: `mouth` (back of the niche, aimed out the front), `deck`
(the top, a sluice source: the bowl overflows down the front as a flush
through the mouth), `rim` (the front mouth when set at an isle's edge).
Chains with: the inhaler head (inhale through the tunnel, then its blast
from the far side), the wind blaster (the cannon), the sluice (the bowl's
flush washes a downed body out through the tunnel), maker_court (set at
the alley's head, it shoots down the alley), and maker_tier (it stands on
a deck).
Build cost: **med.** The block, overhang, plinth and tunnel are procedural
cuts. The seated figure and its rope relief want a small Blender model
(a seated Olmec-helmeted figure, static, no rig), placed in the niche, since
procedural planes won't read as a body. One model, reused across seeds.
Model budget: sculpt high, bake low applies to the figure: a 2-4k-tri
mesh with baked normals and AO, against about 30k for modelled relief. That
saves around 25k tris per throne. Vertex-colour grime and the occlusion
feed in COLOR.a apply, free. Parallax depth applies to the flank's rope
relief and the jaguar band if the shader grows a height channel: shallow
relief costs no tris but adds an estimated 0.1-0.2 ms per screen-filling
throne on a mid GPU. Weigh that against modelling the relief at about 1-2k
tris. LODs apply to the figure only. Rigid parts don't apply.

---

# Glyph stela (maker_stela, family makers)
Verb: climb (the relief is a climbing route), perch on its crown, read (a
rune set; the binoculars read it from afar); toppled, it's a ramp or a
bridge.
Look: a tall monolith, rounded-topped, slightly tapered, set in a socket
block. Its front carries one figure in deep relief: a striding maker in a
tall headdress, one arm raised and one bent, a hand gripping an infant
were-jaguar, the knees and elbows carved proud. Its sides carry columns of
glyphs (the makers' calendar). Its back is plain and rain-streaked. Roots
clutch its foot. Variants are `standing`, `leaning` (15-30°, propped by
rubble), `toppled` (flat, its face up, a walkway), and `broken` (snapped,
its crown lying beside it).
Behaviour: static. Optional: the glyph column lights rune by rune as a
rune set (a ledger activity) is struck. That's a state change, but the stela
itself doesn't move.
Size: standing height 3*SET_OFF (4.8), with the relief's proud parts making
holds up it no more than SET_OFF apart and STAND deep (raised knee, raised
elbow, headdress band), so it is chained hold to hold with ledge grabs. Its
crown is TOP_ROOM wide, a perch. About 1.6 m wide and 0.8 m thick. Toppled,
it is a walkway TOP_ROOM wide and the full length. Bridged across a gap between
two tiers it spans at most a jump's reach of the gap (left to the motif).
Leaning, its back is a slide ramp (walked if under the floor angle,
otherwise a slide).
Collision: the slab is one hull. Each relief hold is its own small clean box,
so its top grabs and stands. The crown has a walk box. Toppled, a walk box
lies along its face. Sides are plumb: kick between two stelae set one chimney
apart.
Motifs it enables:
- An avenue of stelae up to a terrace stair: a gate of two tall ones with the
  plane threading between them (set an opening apart, `opening(TOY_THREAD)`).
- A toppled stela as the only bridge between two drifting isles, its
  glyphs face up.
- A calendar ring: stelae in a circle around a buried head, each one's crown a
  perch, and the rune set lighting their glyphs in order.
Threat pairing: a leaning stela is a seesaw: a heavy landing (slam) on its
raised end tips it over and drops it (scripts/traps/ seesaw drop as the
mechanism, with this as its body). The pilot's slam fells it as a bridge, and
the headless body's weight fells it under him.
Catches / throws: the `leaning` variant **is a seesaw**: its socket block
is a `pivot` mount, and the slab is the seesaw trap's slab. *Standing*:
walk up its back and your weight tips it slowly. *Airborne/tumbling*: a
body landing on the raised end (a thrown body, a slam) drops it hard. A
body on the low end is tossed up and along the slab's line, still stunned if
it was, at about a seesaw launch's height and reach, a pump and more up.
Each landing counts as a landing, as the seesaw already does. Its bearing is
set by the motif's placement. Weathered past a knob, the drop snaps it off
the pivot and it falls flat as a toppled bridge, a one-shot. *Airborne*: a
standing stela's crown is a narrow catch, a perch for a precise throw. The
relief holds catch a poised body. Toppled, it's a walked catch pad as long as
the slab. Mounts: `pivot` (socket), `deck` (crown), and `rope` (a
standing stela's headdress carries a swing rope's anchor).
Chains with: the seesaw, drop seesaw and slam seesaw (it is their body),
the inhaler head (its blast onto a raised end launches whoever's on the
low end), the headless body (its weight tips it), maker_head (a calendar
ring of stelae around the head, each crown a perch), and maker_tier (a
launch off a stela lands on a deck).
Build cost: **med.** Slab, socket and glyph columns are procedural, with
glyphs in the new include. The front relief figure wants a Blender model or
a sculpt-to-bake plane (one or two poses reused), since holds must line up
with carved features. Holds are placed by the script and modelled to sit
on them.
Model budget: sculpt high, bake low applies to the relief: a flat-ish
slab at around 1k tris with baked normals and AO, against about 20k
modelled. Parallax depth applies to the glyph columns (pits read deeper for
no tris, same 0.1-0.2 ms estimate as the throne). Silhouette geometry
applies to the broken edge and crown chips, about 50 tris. Import LODs apply
to avenues: past 40 m a stela can be a box with the baked texture. Rigid parts
and vertex-colour grime (already baked) are minor.

---

# Sky ballcourt (maker_court, family makers)
Verb: ride (slide down the sloped benches and wall-run along them), time a
crossing (the alley is a launch lane), fly through (the alley is a flown
opening and the ring a knife-edge target).
Look: two long parallel ranges facing each other across a flat paved alley.
Each range is a sloped bench (a talud you can run on, laid in smooth
polished slabs, the one place maker stone is smooth) up to a plumb glyph
band and a flat walked top. On each wall's middle a stone ring stands out on
its edge, carved as a coiled serpent biting its tail, kin of the rune serpent.
At each end is a low cross-wall, one of them broken. The alley runs out over
the isle's edge, as the makers built their courts to throw the ball into the
sky. The paving is sunk into a serpentine mosaic (a jaguar mask, green and
dark) that roots have heaved.
Behaviour: static. Optional: the ring turns a quarter turn when the plane flies
through it (a state change, a toggle, a rune reward).
Size: alley width `WorldScale.opening(TOY_LANE)` (toy 4.0, the hall's lane:
7.2 m at the defaults), the courts' length 3-5 CELL. Bench rise is one tier
(SET_OFF) to the band's foot, then 1.0 band. The bench slope sits just past
the floor angle, so you can't walk it but a slide carries you along and down
it (the slide's SLIDE_AUTO territory). The ring's hole is a knife-edge slot
(`WorldScale.knife()`, 1.9 m at plane 2), flown on a wingtip on purpose. The
top of each range is TOP_ROOM across.
Collision: the alley floor and range tops are walk boxes. The bench is one
smooth sloped hull, deliberately not walked (for slides). The ring is a
torus of convex segment hulls with its hole clear. The band is plumb and
kickable.
Motifs it enables:
- A launch court on a rim: run the alley's length, leap off its open end and
  pocket-sail to the next isle, with the alley's length as the run-up.
- A sunken court between two stepped tiers, where the head drifts the alley
  as its round (the alley is a funnel for the pull).
- A flight test: thread the alley low, pull up through the knife ring, and
  clear the broken end wall.
Threat pairing: the court is a funnel. Benches slope down into the alley,
and the alley runs out into the sky. A head inhaling from the open end turns
the whole court into a slope toward its mouth, while the benches throw you
back in. A rolling stone ball (a court ball, the size of a crouched pilot,
from the tumble trap's physics) rolls the alley length from a slam on the
cross-wall. It's the knock-off, and it rides you out the end if you jump on it.
Catches / throws: the court is the family's **pinball table**, where a body
caroms off ballcourt walls. *Tumbling/stunned*: a body thrown into the court
lands on a bench and slides down it into the alley. The glyph bands are
`carom` faces, so a body hitting one fast comes off it as a `toss`
(`maker_court`) back across the alley, still stunned. Both benches funnel
inward, so a tumble down the court is turned along the alley, not out of it.
*Airborne*: the range tops and alley are catch pads. The alley is a catch at
least `opening(TOY_LANE)` wide and 3 CELL long, sized for a thrown body from
any side. *Riding*: a log or court ball rolling the alley carries a downed
body to the open end. It throws along the alley's axis, out of the open end,
at whatever speed the body or its carrier had. That is the court's port: the
motif aims the alley at the next isle. Mounts: `mouth` (the closed
cross-wall's carved mouth, a wind blaster firing down the alley's length,
so the court is a cannon whose barrel is the alley), `run` (the alley, for
logs, a tumbling block or the court ball), `rim` (the open end), and `deck`
(each range top, for a seesaw facing in across the alley).
Chains with: the inhaler head (its blast from the open end throws you back
up the alley), the wind blaster in the end wall, logs and the tumbling block
(and a court ball as their kin) down the alley, the seesaw on a range top
(lob a body across the court), maker_throne (as the court's end stage and
second cannon), maker_head (under the open end, its brow the catch), and
the plane (the knife ring).
Build cost: **med.** Ranges, benches, alley and walls are procedural (tier
parts reused). The ring is procedural (a segmented torus with a serpent head
cut on one segment). The mosaic is a shader decal on the paving. The `carom` faces need the family's one
new motor rule (a reflect-as-toss on wall contact while stunned), which is
small but touches PilotMotor, so it's Opus work. The rolling
ball, if built, is a trap of its own (scripts/traps/), and that part is high.
Model budget: silhouette geometry applies to the ring (its biting head cut
into the outline, about 100 tris). Parallax depth applies to the mosaic
paving (heaved tiles for no tris). Vertex-colour grime applies at the
bench-band crease. Import LODs and visibility ranges apply to the long
ranges at about 30-50% at range. Sculpt/bake applies only if the ring's
serpent is modelled (2k tris baked against about 15k).

---

# Buried colossus (maker_head, family makers)
Verb: climb (it is terrain: ear-flap set-offs, the helmet band, the brow),
run the helmet's dome, hide in the mouth, slide down the cheeks, perch on
the brow. It is an Olmec piece as terrain, not enemy.
Look: a colossal head in the inhaler's own likeness, three or more times its
size, buried in the isle to its lips or its nose so its jaw and chin are
underground. Its helmet is a broad low dome under a band of carved discs,
its ear flaps stand as stepped slabs at either side, and its brow is a heavy
shelf over two almond eyes, closed or half-lidded. Its lips are parted where
it's buried to the chin: a dark mouth you can walk into. Turf and roots
blanket the dome. A tree grows from the cleft in its crown. Grass runs up
over its cheeks. It shares the Olmec shader with the enemy at the same
`weather`, so from the sky it is unmistakably his kin. Variants:
`to_lips` (mouth open, a shallow cave), `to_nose` (only the dome, brow and
eyes, a hill with a face), `tilted` (rolled 20° on its side, one ear flap a
ramp and the other a cliff).
Behaviour: mostly static. Its eyes change state: they are dark by day, and
when the pilot stands on its brow or a nearby inhaler head is in its tell,
the eyes ease to the Olmec's warm lock-on glow (same `rs_eye` look, same
0.6 s ease). This is a tell that the place is awake. Optionally a slow breath
moves through its mouth (a gentle in-out air, `motor.air` only, no seize), a
quiet threat that helps a glide out.
Size: from the inhaler head (`inhaler_head.gd`'s `size`, from walker
height, as enemy_field's `numbers()`), times a `COLOSSAL` knob of 3-5.
Climbs are kept on the pilot's grid whatever the knob. Ear-flap slabs step
up in SET_OFF rises, each STAND deep. The helmet band is a GRAB_TOP lip from
the flaps. The brow shelf is TOP_ROOM deep and a perch. The dome's slope
starts walkable and steepens to a slide at its sides. The mouth (to_lips) is
at least the pilot's height clear and 2 STAND deep: cover, and the camp
alcove. Its parted lips don't meet the flown openings' sizes, and the head
doesn't need to be flown through.
Collision: built from the head's own glb with a hand-authored collision
set, not a trimesh. Clean boxes for the ear-flap steps, band ledge and brow
shelf. A few convex hulls for the dome (walked top, sliding sides). The cheeks
are one convex hull per side (slides). The mouth is a walked floor box inside
lip and palate hulls. The buried part needs no collision: the isle's own
turf covers it.
Motifs it enables:
- A hill with a face: an isle that is the buried head, its dome the summit,
  ringed by a stela calendar and a palisade corral.
- A head under the ballcourt's open end, as if the ball were thrown to it:
  its brow is the landing perch after the launch.
- The body's grave: the headless body roams an isle where its head is
  buried and can't be lifted. It digs and listens, and it's furious
  (an encounter design for the enemy, in its own round).
Threat pairing: its brow is a lookout, but standing there wakes it: the
eyes lock on, and a nearby inhaler head turns toward you (they share the
gaze). Its slow breath pushes a glide off course, or helps one when timed.
Sliding down its cheeks drops you into whatever lies below.
Catches / throws: the buried head **spits**, which is the "spat from one
head into another" link. *Tumbling/airborne*: a body that tumbles or is
thrown into its open mouth (`to_lips`) is held a beat (0.6 s, the jaw
grinding, no `seize`), then spat out along its gaze as a `toss` with source
`maker_head`, still stunned if it came in stunned. The throw is a pump's
height up and 4-6 CELL out (a knob), aimed by the head's facing in the
motif's frame. Because its source differs from the inhaler head's, an
inhaler blast into a buried head's mouth chains straight into the buried
head's spit. A `knock` there doesn't restun before `restun_gap` passes, but
the throw lands anyway. *Standing*: the dome is walked, and its sides steepen
to slides that shed a body off the head in every direction (a dome is a
360° shed). *Airborne*: the brow shelf is a catch pad at least 2 CELL
wide and TOP_ROOM deep, sized for a throw from up to its own spit's reach,
so two buried heads facing each other at that distance pass a body back and
forth until the chain cap breaks it out. That's a ridden-on-purpose route
for a skilled player who teches onto each brow. Mounts: `mouth` (the spit;
or a wind blaster or sluice nozzle laid in it), `deck` (the dome, where an
inhaler head can make its round), `rope` (the tree in the crown cleft holds
a swing rope over the brow), and `rim` (the gaze, when it faces off the
isle).
Chains with: the inhaler head (blast into the mouth, then the spit; and the
shared gaze), another maker_head (the volley), maker_court (it sits under the
open end, catching on its brow), maker_stela (the calendar ring catches the
spit on its crowns), maker_palisade (the corral), the headless body (the
grave), and swing ropes (the crown tree).
Build cost: **high.** It's a new model in Blender: the inhaler head's
likeness rebuilt as a static colossus (no rig), with its own eye sockets for
the `rs_eye` treatment, three burial cuts, and authored collision boxes on
the pilot's grid. The eye's state and the spit (a mouth trigger volume,
hold, then `toss`) are a small script. It reuses the Olmec
shader and the eye's look, so the look itself is cheap.
Model budget: sculpt high, bake low applies most here: a dense head
sculpt baked onto about 8-12k tris (the low end of the bar, because it's
seen huge), against 100k+ modelled, saving about 90k tris and an estimated
0.3-0.5 ms per head on screen on a mid GPU. Import LODs and visibility ranges
apply, since it reads from across the layer: a 3-4k LOD at range saves a
further 5-8k tris. Silhouette geometry applies to chipped ear flaps and the
nose break. Vertex-colour grime is already the Olmec's COLOR.a feed, free.
Parallax depth would serve the disc band, at about 0.1 ms, optional.
Rigid parts don't apply (no rig).
