# Kit K7: the vertical abyss (round 3 brainstorm, the Olmec city)

Lens: the city as isles over a void. A tall stack, colossal, or a fragment of
something bigger. Brainstorm only; nothing here is built.

**The family `city`** (proposed scripts/ruin_kit_city.gd, ids `ol_*`). Builds
on round 1's `makers` family (kit-k5-makers.md): same stone (olmec_stone),
same CELL grid, same SET_OFF tiers for the walker. What this round adds is the
*vertical* half, because underground there is no horizon and no plane: the
silhouette in the haze is the whole sell, and the Olmec (4.4 m wide, 2.4 deep,
6.7 m to his neck) is the scale everything is cut to, not the walker.

**Rules for the family.**
- **Two grids.** Walker grid as in `makers` (SET_OFF 1.6, GRAB_TOP, CHAIN_TOP,
  STAND, TOP_ROOM from RuinKit). Body grid on top: any top he is meant to walk
  is at least 6 m across, any stair he is meant to use at least 5 m wide with
  6 x 6 m landings, any shelf is >= 6 m deep or < 2 m (layer-round11). Narrow
  walker-only work (rope stairs, ledges, gutters) is tagged `walker_only` so
  his rays skip it, as round 11 asks for.
- **The turn below.** Every walkable level stacks over another within a fall
  of <= 5.5 m (under the 6 m fall stun, stun-round1.md) wherever the stack has
  an inside edge. Fall off the inside of a turn and you land on the turn
  beneath, standing. Fall off the outside and you go into the abyss. So a
  piece's inner side is always a *well* with a catching shelf, its outer side
  a drop. `ports()` reports `catches` for the inside shelf.
- **Hero silhouettes.** Each piece has one outline that must read in haze at
  200 m and in torchlight as a dark cut-out: a column, an arch, a stepped
  wedge, a notched crown. Detail is for the near view and comes from the
  shader (bands, runes), never from the outline.
- **Breaking.** The destruction round's model (scripted breaks, not voxels:
  `colonnade_breaks.gd`). A breakable piece is built as its own unit, breaks
  into drum/slab pieces that become rubble that is ground to the body and the
  walker, merged when settled, `MAX_BODIES` 24. Breakable pieces are skipped by
  the body's rays (he treats them as air and plows). Each card says what
  breaks, what is left, and what the rubble lands on. Rubble always lands
  on the level below, so destruction *builds* the turn below.
- **Sources.** Every throw names the piece (`ol_pillar`, ...), distinct from
  the inhaler head, blaster and seesaws, so `restun_gap` never cuts a chain.
- **Light.** Pieces carry `cresset` mounts (a torch bowl, `rim`-like), so a
  motif can light a layer in warm firelight against the brown-grey haze.
  The kit's rule is that ornament doesn't glow; fire is a light source, not
  an ornament, and the carved stone itself stays dark.

---

# Basalt pillar-isle (ol_pillar, family city)
Verb: climb (the shaft's collars are a ledge chain), run the crown's streets,
fall inward onto a collar, hide in a crown alley. It is the isle itself.
Look: the unseen floor throws up a colossal hexagonal basalt column, 30-80 m
across and out of sight below, its flanks the true organ-pipe prisms of the
maker tombs, jointed and glassy and streaked. Every ~5 m a *collar*, a ring
of battered talud and plumb glyph band, wraps it like a drum course of a
ziggurat, so the shaft reads as a stack of stepped courses, each a darker
band against the haze. The crown carries a city block: low heavy maker
masonry, a plaza, a stepped pyramid base, alleys. Its outline is a stepped
stump with the crown's pyramid on it, a table with a hat. Roots and hanging
moss from every collar lip; the lower the collar, the more the haze eats it.
Behaviour: static. Optional state: a collar's lip may be `loose` and drop.
Size: shaft 30-80 m across (a knob; the generator only moves isles, it never
turns them, so the stack's facing is by placement). Collars every 5 m (under
the 5.5 m fall rule) and each collar is 6 m deep on the *inside* sectors of a
ring (a place he fits, a landing for a fall) and 1.2-1.6 m (a SET_OFF ledge,
walker only, `walker_only`) on the outside sectors, never between 2 and 6 m.
Crown streets are >= 6 m wide so he walks them; alley slots 2-3 m are
walker-only cut-throughs (cover from his sight; he climbs over them).
Collision: collars are clean walk boxes, ledge lips are grabs, the talud is a
sloped hull (sheds), the band is a plumb kickable box. The shaft between
collars is one plumb hull per face (wall kick up a seam between two prisms,
a 1.6-2 m joint chimney marked in the prism layout). Crown tops are walk
boxes.
Motifs it enables:
- A tall stack: three pillar-isles at different heights joined by causeways
  and drum stairs, the city's "layers in the distance".
- A cliff the Olmec climbs: he mantles up the collars (a ledge chain for
  him, with 6 m inside shelves), a lane the player can follow or ambush.
- A ring of pillars round a central void, each crown a district.
Threat pairing: the Olmec climbs it, leaping collar to collar; his landings
shock the collar (see Breaks). A pilot on a 1.4 m outside ledge with him
coming up behind has nowhere but over. The inside well is a shelter: he
can't reach a pilot who stands under a collar overhang, and he can't see
down it either.
Catches / throws: *Standing*: collars and crowns are walked. *Airborne*:
every collar lip is a ledge grab; the inside shelf (>= 6 x 6 m) is a catch
pad sized for a fall from the collar above (<= 5.5 m, so no stun). *Tumbling/
stunned*: a body knocked off the inside lands on the next collar standing up
or lightly stunned; a body knocked off the outside has no catch (the
outside ledge is 1.2-1.6 m, a slide off a talud lip into the abyss, no
`toss`). It throws only by shedding. Slope sheds the way the face looks.
Mounts: `deck` (crown plazas, a seesaw or vent), `cresset` (each collar
corner), `rim` (collar outside sector, for a thrown body to leave), `rope`
(a crown tower beam).
Chains with: the drum stair (its door opens on a collar), the causeway (it
lands on the crown), hanging terrace (hangs from a collar), the inhaler head
(blasts a body from one collar to the next one down), the headless body (the
Olmec climbs collars, shocks them), seesaws on a crown plaza.
Breaks: yes, in two ways. A *loose lip* on an outside ledge: 3-6 m of a
collar's talud and band, precast as a slab, drops under a leap landing
(shockwave) or a pilot slam and falls to the collar below as a ramp of rubble
there (the 5 m collar below is its catch, and the rubble raises it by 1-2 m
so the ledge chain is shorter). The crown's masonry (a pier-and-lintel row, a
wall) breaks as the colonnade does. The shaft itself never breaks.
Build cost: **med-high.** The shaft and collars are procedural (hex prism
Build.solid, talud and band plane cuts, like the maker tier); the crown block
is the same procedural city kit. One Blender model: a shared hex-prism *cap*
and *joint* kit, 200-400 tris, reused. The haze LOD is the cost: the shaft is
a long mesh seen at 300 m.
Model budget: import LODs and visibility ranges apply hard (the shaft goes to
a coarse hex tube with a baked band texture past 80 m, saving an estimated
60-70% of its draw cost at range); the shaft repeated across a layer should
be `merge`d per pillar (1 draw call). Vertex-colour grime (crevice
occlusion per band) is free. Silhouette geometry for lip chips and the
crown's notched hat, ~100 tris. Parallax for the glassy joint streaks, 0.1
ms, optional. Sculpt/bake and rigid parts don't apply.

---

# Drum stair (ol_drum_stair, family city)
Verb: climb a stair wound round a pillar's inside well, jump the flight rails
to cut a turn, fall into the well onto the turn below, ride the rail down.
Look: the epic stair the user asked for: a circular stair of broad flights
(5-6 m wide) wound round the *inside* of a great shaft or the *outside* of a
pillar, with a 6 x 6 m landing at each turn. Seen from afar it is a coil, a
spiral of thick light bands against the dark shaft, every landing a lamp
(a cresset in the niche). Its outer parapet is a battered wall carved with
a running frieze of the inhaler's faces. The core is open: look down the well
and see six or seven landings stacked below you, the layers in miniature,
fading into the haze. Weathered, a flight has slumped to a ramp and a rail
section is missing.
Behaviour: static. Optional state: one flight is `precast` and breaks.
Size: flight 5.5 m wide (over the 5 m rule), tread 0.5, riser 0.4 (maker
steps, four to a SET_OFF tier); a turn every 5 m of rise so the inside well's
drop is <= 5.5 m; landings 6 x 6 m minimum (8 x 8 where a door opens). The
core is >= 8 m across so a fall inside misses the flight above and lands on
the landing below; if narrower than that the falling body clips a rail (a
shed). The parapet is 1.6 m (a grab from the flight) and 0.6 m thick, wide
enough to stand and run.
Collision: each tread a clean walk box (round 11: widths and landings matter
to him; riser/tread don't), landings clean walk boxes, parapet top a walk box,
inner rail a thin hull that rail-slides. Slumped flight: one sloped hull
that sheds.
Motifs it enables:
- The way up: a coil round a pillar from the abyss's near wall to the crown,
  the player's and the Olmec's route, with the well as the express down.
- A vertical shaft room: a dark well with a drum stair inside it and a
  cresset on every landing, a place you look *down* at.
- A cross-section: a cutaway stair, half the wall fallen, so the whole coil
  shows in the haze as a spiral silhouette.
Threat pairing: a 5.5 m flight is a lane for the Olmec; he walks it and
leaps the turn. The well gives the player a way to dodge him by dropping a
turn (the tool) but the headless body drops after, and his landing shock
(r ~ 8 m) takes the whole landing. The inhaler head drifting in the open core
pulls a pilot off a flight into the well.
Catches / throws: *Standing*: a flight carries a walker and rails slide.
*Airborne*: a fall into the core lands on the landing below, a catch pad 6 x 6
m, sized for <= 5.5 m. *Tumbling/stunned*: a body knocked down a flight
slides to the landing, a short chain of drops, each under the stun cap. A body
knocked off a flight sideways into the well lands on a landing. A body that
overshoots a landing falls on the next, stunned if the drop is > 5.5. The
stair does not throw; its slide direction is the flight's. Mounts: `deck`
(each landing), `run` (a flight, for logs or a tumbling block rolling down
it: five turns of bounce), `cresset` (each landing niche), `rim` (a
broken parapet, to the abyss).
Chains with: logs and the tumbling block (down a flight), the inhaler
head in the well, the headless body (comes up it and drops down it), the
pillar-isle (door onto a collar), the sluice (a gutter rim on the landing).
Breaks: yes, a `precast` flight: when the Olmec lands a leap on its
landing, or a pilot slams it, the flight cracks in 2-3 slabs that fall to
the landing below as a ramp (a slumped flight, still climbable by the
walker and walkable by him). The route never breaks entirely: a precast
flight's neighbours stay whole. The parapet frieze breaks into drums when
he plows it.
Build cost: **med.** Procedural: a flight is a sloped run of walk boxes (the
grand_stair, widened), landings are slabs, a parapet is a wall course with a
frieze. A round plan means sector-ed hulls, 12 per landing, which is the main
effort. No Blender model except the optional faces on the parapet (shader).
Model budget: silhouette geometry for the parapet's chipped top; vertex-colour
grime at tread/riser creases free; import LODs and visibility ranges (stairs
repeat, a 30-50% saving at range as in K5's tier); merge each flight into
one mesh. Parallax depth for the worn tread dishing, 0.1 ms optional.

---

# Colossal causeway (ol_causeway, family city)
Verb: cross (the hero bridge), run the parapet, drop off the side onto the
arch's haunch below, ride a rail section, mantle the pier collar.
Look: the massive bridge in the distance. A flat paved deck, 8-10 m wide,
borne on one-to-three tiers of massive round-headed arches (the aqueduct
family's `two_tier`, scaled up; corbel-vaulted, not gothic pointed) on
battered piers. 60-120 m long, a span between pillars. It is the silhouette
of the whole layer: long, low, a rhythm of black arches with the fire-lit
deck on top, a cresset on every third pier head. The parapet is a low
thick wall with stepped crenels (stepped fret, the Mesoamerican
chevron). Weathered, the arch tiers are chipped and a span has dropped; there
are still the springers on each side, two half-arches reaching for each
other. Roots hang from the soffit.
Behaviour: static. Optionally a causeway has a `loose` bay that drops.
Size: deck 8-10 m wide (a lane for him, at least 6 m of clear walking), a
parapet 1.6 m (a grab from the deck, and a plateau to run). Arch openings
>= 14 m clear (the rune serpent, 4 m through, passes under; not flown by
the player, so no `opening()`), pier 5 x 5 m with a collar at 1.6 m rise on
its base (a stand for the walker, 0.6 m deep, a SET_OFF grab chain up from the
lower tier's deck). Each span 24-30 m, a jump too far (so pilots walk and the
Olmec can walk): the deck is continuous or deliberately broken at a 5 m or
9 m gap (a body leap gap and a pilot's sail gap, not between).
Collision: deck and parapet top clean walk boxes, arch soffits are mesh only
(not collidable from below: nobody climbs the soffit), piers are plumb hulls
with the collar a grab box. A broken end is an authored ragged-edge hull (a
lip that grabs).
Motifs it enables:
- The great bridge: two pillar-isles at two heights, a causeway between them
  rising across the stack on a slope; the hero silhouette.
- A bridge fight: the Olmec body comes across the deck; the pilot swings
  to the arch underside and the haunch below (cover from his rays: the deck
  is solid, though he sees through the arch).
- A gap bridge: the causeway broken mid-span; the springers' tips are a leap
  for him (5 m gap) and a pocket-free jump for the walker (a rope/swing rope
  mount at the broken pier).
Threat pairing: a deck is a corridor; the pull of the head drifting along it
drags a pilot down the deck, and the body charging down it pins one against a
broken end. The parapet is a rail: slide off it and you drop onto the
haunch/lower deck, a tool, or into the abyss, a threat. The arches are cover
(the deck above blocks the rays).
Catches / throws: *Standing*: deck walked; parapet top walked. *Airborne*:
deck is a long catch pad (8 x any); the haunch of the first arch below
(1.5-2 m wide at the pier, widening to 6 m at the springer) is a catch
for a fall off the parapet, sized for <= 5.5 m. *Tumbling/stunned*: a body
on the deck slides to the parapet and over; the haunch catches it; a body
over a broken end falls to the lower deck or the abyss. The causeway throws by
shedding only, but its `run` mount (the deck) is a lane for logs and a
tumbling block and its broken end a `rim` that throws a ridden log off the
end. Mounts: `run` (deck), `rim` (broken end), `rope` (a broken pier head),
`cresset` (pier heads), `deck`.
Chains with: the pillar-isle (lands on its crown), the drum stair (at the
bridge head), logs and the tumbling block down the deck, the inhaler head
over the deck, the headless body (crosses it and shocks it), the seesaws on
a wide deck bay, the rune serpent passing under an arch (the serpent is the
scale reference).
Breaks: yes. The causeway breaks in *bays*: a deck-and-parapet section over a
pier is a precast unit. A leap landing on a bay (the Olmec's shockwave r ~ 8
m, a power 1 landing) cracks it; a second hit drops it as a dozen slabs to the
lower tier (a rubble ramp that bridges to the tier below and shortens the
route). The pier itself is not breakable. A fallen bay leaves a 5 m gap with a
ragged edge, so a bridge can be broken *during* a chase and the Olmec leaps
the gap he made.
Build cost: **high.** The arches are procedural (aqueduct `two_tier`
scaled and corbelled), the deck/parapet/piers cheap. The cost is the
scale (a 120 m bridge is many meshes), the breakable bays (a unit each, the
colonnade's per-unit cost), and the haze LOD. One Blender model: the
arch-ring voussoir kit (a keyed round-arch ring, ~400 tris) reused per span.
Model budget: import LODs and visibility ranges are the whole story here
(a causeway seen at 300 m is a 200-tri silhouette; saves an estimated 70-80%
of its draw cost at range); merge by span; silhouette geometry on the
springer ends and the ragged break, ~80 tris each. Vertex-colour grime on
soffits (free). Sculpt/bake only if the voussoirs carry a relief face.
Rigid parts and parallax don't apply.

---

# Hanging terrace (ol_terrace, family city)
Verb: traverse under an overhang (shimmy), chain up a stepped underside,
stand on a hung balcony, hide (an undercroft).
Look: terraces that *hang*: a stepped city fragment corbelled out of a pillar
collar or the underside of a causeway, each tier overhanging the one below,
like an inverted ziggurat or a wasp's nest on a cliff. Its underside is a
dark row of corbel beams, the ends carved as were-jaguar teeth. On top, a
paved terrace with a low wall, a small altar bowl and a stair down. Chains
hang from the front, tied to a stone, the Olmec's captive ropes made
architecture. Roots drop through. Weathered, one corbel has dropped and the
outer tier sags.
Behaviour: static. Optionally sags and drops on a slam.
Size: terrace deck 6-8 m deep and 12 m long (a place he fits); tier set-back
1.6 m (SET_OFF) so the underside is a chain of grab lips from below; the
corbel lip is 0.5 m (a hang and shimmy). The undercroft is 3.5 m tall under
the first terrace, 4 m deep: cover from above, and too low for him (neck 6.7
m), so he can only reach in with his arms. A stair, 5 m wide, joins the terraces.
Collision: deck and parapet tops clean walk boxes; the underside is mesh only
except for the corbel lip grabs (small boxes); the undercroft floor a walk box
(the collar below).
Motifs it enables:
- A hanging district: a pillar flank with three terraces down it, a
  stair, and the Olmec on top of it.
- A grab-and-shimmy route that goes *under* the causeway: the soffit route.
- A pavilion hung on a broken causeway end, a perch with a view.
Threat pairing: the Olmec stands on the terrace above and shocks it: the
terrace's outer tier snaps. The undercroft is a hide, but a dead end: if he
sits on the deck above, the only way out is the drop.
Catches / throws: *Airborne*: the lower terrace deck is a catch pad (6 x 8)
for a fall from above, sized for <= 5.5 m; the corbel lips are hang catches.
*Tumbling/stunned*: a body falling from the deck above lands on the one
below standing or lightly stunned; a body sliding off the outer tier falls
past the next to the collar. It throws by shedding only; the sagging tier is
a ramp (its slab tips, 15 degrees) that sheds a body outward. Mounts: `deck`
(each tier), `cresset` (parapet corners), `rope` (a corbel).
Chains with: the pillar-isle collar, the drum stair, the causeway soffit,
the wind blaster in a corbel mouth, the sluice (an altar bowl overflow flushes
down the tiers), the headless body.
Breaks: yes. The outer tier is a `precast` slab group: when the Olmec lands on
the terrace above or leaps onto it, the outer 3 m of tier snaps at the corbels
and falls in 3-5 slabs to the tier below, which lands rubble on the collar
(raising it). The corbels left behind are stubs: hang catches. What breaks
is shown in the soffit's pre-cracks.
Build cost: **med.** Procedural: stepped corbelled courses (plane cuts), the
corbel tooth carving in the shader. The break is a per-unit build as in
colonnade_breaks.
Model budget: silhouette geometry for the corbel teeth (the profile cut,
~20 tris each); vertex-colour grime on the soffit; merge by terrace;
import LODs. Parallax for the teeth if the shader grows a height channel.

---

# Wedged chunk (ol_wedge, family city)
Verb: climb a tilted slab (a ramp), wall kick the chimney between the chunk
and the pillar, perch on the broken crown, slide.
Look: a fallen city chunk, a piece of a bigger building (a gate lintel, a
roof course with its pillars, an arch ring) wedged in the abyss between two
pillars or hung off a pillar's side by its own weight. Cracked faces show the
inside: rubble core, a floor level sliced, a carved stair going nowhere. It is
tilted 15-40 degrees, a fragment of something bigger; one end rests on a
collar, the other on a ledge, the middle over open air. Roots have grown in
the crack. Haze eats the underside and fire lights the cut faces.
Behaviour: mostly static. Optionally `unsettled`: it shifts one notch under
a heavy landing (the Olmec's leap, a slam), tilting a degree further and
dropping a loose block.
Size: 20-40 m long, 8-12 m thick; the top slab surface walked at a slope
<= the floor angle for walkers (a ramp 10-14 degrees, walkable) or steeper
(slide). The chimney between chunk and pillar is 1.6-2.2 m wide (kick
width, per K5's palisade) or >= 6 m (a lane for him), never between. Perches
on the crown are >= TOP_ROOM and >= 6 m on the one top he's meant to reach.
Collision: the top is a sloped hull for sliding and a clean walk box strip
on the flat bands; cracks are plumb faces for kicks; the cut stair is real
steps (clean walk boxes). The underside is a trimesh-free convex hull set.
Motifs it enables:
- A shortcut across the void: the chunk is a ramp from a high collar to a
  low one, a one-way (down) bridge.
- A boundary between two pillars: wedged chunk plus palisade, a route in the
  gap for a walker.
- A fragment at the abyss mouth: debris stacked like a dam on the way
  to the lower layers (the layers' catch).
Threat pairing: it shifts. The Olmec's shock lands on it and the whole chunk
tilts a notch, dumping a walker; its sloped top sheds.
Catches / throws: *Airborne*: the top is a long catch pad; a body falling
from the pillar crown lands on it. *Standing*: a walker climbs it at
<= floor angle. *Tumbling/stunned*: a body on the steep section slides to the
low end and off, as a shed (no toss). When it shifts, it `toss`es the body
along the slab's tilt (source `ol_wedge`, a short hop, 3 m out and 2 up,
still stunned) onto the neighbouring collar: a one-shot throw per slam.
Mounts: `run` (the top as a lane for logs), `deck`, `rim` (low end), `rope`.
Chains with: the pillar (collar), the drum stair, the causeway (a chunk fallen
from it, same cracks), seesaws on its flat band, the headless body (the leap
that triggers it), the sluice (the cut stair as a spillway).
Breaks: yes, differently. The wedge is *rubble that has already broken*;
under a shock it breaks further: the loose block drops and the chunk settles
down a notch, and its far end collapses to a rubble ramp onto the collar
below. It never disappears: it lowers, so a stacked chain of wedges is a
staircase the destruction builds.
Build cost: **med.** Procedural for the slab, cracks and cut faces (plane cuts
with a ragged edge noise), a physics settle for `unsettled` (a scripted
rotate by one tween, no rigid-body sim, with the rubble pieces on the cap).
Model budget: silhouette geometry (chipped corners, broken-away edge)
applies most, 100-200 tris; vertex-colour grime in the cracks;
import LODs; sculpt/bake for the cut stair relief (1.5k vs 15k tris).

---

# Beacon tower (ol_beacon, family city)
Verb: dressing (a lookout), climb the stepped tower, perch on its cresset
shelf, ignite (a ledger activity: light the cresset).
Look: a tall, thin, tapered tower, a stepped wedge like an obelisk, set on a
crown or a collar corner. It is the layer's height marker: a stack of 3-4
bands, each narrower, with a fire bowl at the top. In haze, the lit bowls read
as warm dots stacked up the stack, one per layer at its height, and its
black profile as a notched needle: the player counts layers by the lights.
Its flank carries glyphs, a vertical column of the calendar; its crown is an
inhaler face looking down the well. Weathered, the crown is gone and only the
stump stands, unlit.
Behaviour: static, but the cresset can be lit (a state change) by a
ledger activity or by Mudge (mudge.md, a wax candle climber lights itself on
a spire and every Olmec turns to it). Lit, it is a beacon every enemy
turns to.
Size: tower 12-30 m, base 6 x 6 m (a place he fits, walked around), stepped
bands every SET_OFF with set-backs STAND deep so the walker chains up the
flank; the cresset shelf TOP_ROOM across; the crown is a perch.
Collision: bands are plumb boxes with lip grabs; base a clean walk box ring;
crown shelf a walk box; the cresset bowl a small hull.
Motifs it enables:
- A layered readout: one beacon per stratum, so the stack reads in the haze.
- A lit path: a causeway's cresset line (lit or unlit) that tells the player
  which way the Olmec has been.
- A summit lookout with a binocular read.
Threat pairing: a lit beacon pulls enemies; a pilot lighting it brings the
Olmec to the tower, a tool as well as a threat (lure him to a precast bay).
Catches / throws: *Airborne*: the cresset shelf is a narrow catch (a perch
for a precise throw). *Standing*: the band ledges are a chain. *Tumbling*: a
body on a band slides off its flank (shed). Throws nothing. Mounts: `deck`
(shelf), `cresset` (the bowl itself), `rope` (a crown beam).
Chains with: Mudge, the headless body (turns to a lit one), the inhaler
head (its face looks down the well), the causeway (pier heads).
Breaks: yes, simply. He plows through the base and it topples: the tower is
one `precast` unit that falls as 4-5 band drums in the push direction,
settling as a rubble ramp or a bridge across a gap: a felled beacon is a
fallen stela (toppled bridge, K5's stela) bridging a gap of 10-14 m. The fire
goes out.
Build cost: **low-med.** Stepped bands are Build.solid blocks, the cresset a
small bowl with a flicker light (a light node, the one real cost). The fire
is a shader quad.
Model budget: silhouette geometry on the crown notch; flat bands get their
glyphs from the shader; import LODs (at range the needle is a 4-tri tapered
box plus a light dot, nearly free); merge. Light culling is the budget item:
beacons are the only dynamic lights in the haze.

---

## Motif hunches the pieces would make

- **The Stacked Court:** a tall stack of three or four pillar-isles, a
  drum stair inside the well of the middle one, a causeway between the top two,
  beacons at each crown. You arrive at the foot and *look up* at the lights,
  the layers in the distance. A place first: the route up is the stair, the
  causeway or the climb of collars; the Olmec comes up or down any of them;
  breaking a causeway bay shortens a route and makes a gap.
- **The Dam of Chunks:** wedged chunks and hung terraces jammed between two
  pillars at the abyss's neck, where a city fell. It reads as a fragment of
  something bigger. Walkers cross by the chunks' ramps; the Olmec shocks
  them and drops the pile a notch at a time, so the place changes as he
  hunts you through it.

**Strongest piece:** the drum stair, because it makes "falling inside lands on
the turn below" the rule of the kit and gives the epic staircase, and it is
the one the Olmec's lanes (5 m+ flights, 6 m landings) are built around. The
causeway is the hero silhouette.
