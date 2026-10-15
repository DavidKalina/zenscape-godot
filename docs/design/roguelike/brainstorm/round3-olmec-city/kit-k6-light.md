# Kit K6: light and dark (round 3 brainstorm, the Olmec city)

Five pieces for the underground climb, where the pilot carries a torch and the
Olmec's eyes are the only other light. They build on round 1's `makers` family
(kit-k5-makers.md): same CELL grid (4.4 m), same SET_OFF rise (1.6 m), same
Olmec stone, same `mounts`/`catches`/`throws` metadata. Nothing here repeats
K5's tier, palisade, throne, stela, court or buried head. These are the pieces
that hold fire, bend light, or hide you.

## Shared rules (so the five agree)

- **`lit` is a state, not a lighting engine.** Each light piece has a boolean
  `lit` plus a `glow` radius. The *look* is a cheap OmniLight3D (one or two on
  screen, pooled) plus an emissive ember texture on the bowl and a baked warm
  rim on nearby stone (vertex COLOR, the kit's grime channel). Pieces read as
  silhouettes in haze with no light at all: the shape does the work, the flame
  only adds a bright dot. In the brown haze the flame is a smudged orange
  point visible for 100+ m; in torch-dark it is the only room you can see.
- **Beacons.** A lit piece registers in a `beacons` list. The Olmec body and
  head read it through the same hook the head's call and the body's hearing use
  (`headless_body.gd` listens to its head; Mudge's "attractor list" is this
  list). A beacon is a sound-without-sound: a lit cresset pulls every Olmec on
  the layer within `beacon_range` to turn toward it, and the body's route
  planner (`body_routes.gd`) treats it as a goal exactly like a head call. It
  does not make him see you.
- **Sight and shadow.** His sight is the cone in `body_sight.gd` (0.9 rad,
  45 m, awareness meter filling at `sight_fill`, draining at `sight_drain`).
  Light adds to that meter: a lit torch on the pilot or standing in a lit
  cresset's glow multiplies `sight_fill` (knob, ~1.6x); standing in a
  `shade` volume cuts it (knob, ~0.35x) and is cover from the head's gaze too.
  He still hears landings and slams, so shade is not silence.
- **The torch.** The pilot's torch lights any `lit=false` piece it touches
  (a ledge grab beside the bowl, a slam on the wick). It is doused by a
  snuff trough (card 4), by wind, or by a long fall. Relighting costs a
  walk to a lit piece. All of this is a hint for the pilot kit, not designed
  here.
- **His lanes.** Anything a body must walk or land on is at least 6 x 6 m with
  5 m clear to each side or has a drop to broad ground (layer-round11). Any
  pocket smaller than that is marked **walker-only** (tagged so his rays skip
  it) and is where the pilot lives. Light pieces fit that split: the *bowl* sits
  on a landing he fits; the *hide-holes* he can't.
- **Breaks.** Same scripted model as `olmec-destruction-round1.md`: his bulk
  box, a lintel meeting it, or his shockwave front (out to 0.62 of its reach)
  snaps a piece at a joint into a stump plus rigid pieces that settle and
  merge. Each card says how its piece breaks and, because this is a light kit,
  what the breaking does to the light.
- **Sources.** Light pieces name their tosses `light_<piece>`, distinct from
  `maker_*`, the head, the wind blaster and the seesaws, so a chain through
  them is not cut by `restun_gap`.

---

# Great cresset (maker_cresset, family makers)
Verb: solve (find the torch route to the bowl, then light it), climb the plinth
(ledge grab to the bowl's lip), hide behind it when he turns. A lit one is a
choice: a beacon to reveal the route, or a call to the Olmec.
Look: a wide, shallow bowl of black basalt, 2.2 m across at the lip, held on a
squat fat shaft carved as a crouching figure with the inhaler's helmet taking
the weight on its head and shoulders. The bowl's inside is crusted with old
resin and soot; a ring of rune grooves runs round the rim. Four sizes via one
knob: `ember` (a hand-lit sconce in a wall niche), `cresset` (the standard
1 tier plinth), `great` (two tiers, 6 m of stair up to it, the landmark of a
whole district), `spire` (a bowl on a tall natural basalt column, for card 5's
Mudge). Dead and unlit it is a dark cup against haze. Lit, a column of flame
and a smear of warm light that bleeds into the grooves and picks out the
Olmec stone's brow ridges for 20-40 m. Soot streaks the stone above. Overgrowth
is only root and moss at the plinth; nothing grows in the bowl's heat.
Behaviour: changes state. `lit=false` at generation (a seed knob, `lit_share`,
decides how many already burn, so some are beacons you walk toward). Lights
when the torch touches the bowl or a runnel flame arrives (card 3). Burns until
the Olmec's shockwave or the pilot's slam puts it out, or a sluice drowns it
(it does not relight itself). A lit great cresset warms a heat shimmer column
(small `motor.air` updraft, below).
Size: plinth top 1.6 m (one tier, caught by a plain jump); bowl lip another
1.0 m up, so a pump (CHAIN_TOP 2.575) from the plinth catches the lip and
a standing jump does not, which makes lighting a small climb. The `great`
variant has a 4-step stair (the makers' 0.4 / 0.5 steps) up two tiers to a
landing at least `TOP_ROOM` across. Footprint 1 x 1 CELL at standard, 2 x 2
for great; the landing around it is at least 6 x 6 m so the body fits when
it comes to look.
Collision: plinth top and stair treads are clean walk boxes. The shaft is a
plumb hull (wall-kickable, its sides carry holds). The bowl rim is a ring of
convex segment hulls with a clean ledge on the lip (the grab). The bowl's
inside is a shallow clean floor box, standable and out of sight from below
(you can crouch in a dead bowl). The flame is no collision.
Motifs it enables:
- A district of dead cressets climbing a stair: light them in order to see the
  next flight, and every one lit is a bead of light pulling the Olmec up
  behind you.
- A great cresset on a 6 m landing at a stair's head, with the Olmec's eyes
  appearing over the edge once it burns.
- A decoy field: a far unlit cresset you light from a distance with a thrown
  torch or flung ember, steering the body away from your route.
Threat pairing: lighting it is the trap. A lit great cresset is a beacon every
Olmec on the layer turns toward, and it lights the player's own silhouette
on the landing for the sight cone (the glow multiplier). It also reveals his
shape when he climbs over the edge into the light: the flat dark silhouette
of a four-metre-wide body against the flame. Dead, it is the best hide on the
landing (the bowl is a crouch pit).
Catches / throws: *Standing*: plinth, treads and landing are walked. *Airborne*:
the plinth top and bowl lip are catches, the bowl lip a grab. *Tumbling/
stunned*: a body landing in a dead bowl is held (it is a shallow cup) and
rolls out toward its low side with a gentle slide (no `toss`). A body in a
**lit** bowl is lifted by the heat: the column is a small updraft (about a
step of lift, the `flow charge` zone's lower end, `motor.air` only) that
carries a stunned or tumbling body up about 3-4 m and drops it beside the bowl
(the `drop_to` pad on the plinth) with source `light_cresset`. It does not
stun by itself and cannot restun. Aimed by how the motif places the cresset
and which side of the plinth the drop pad lies on. A great cresset on a ledge's
rim is a way to *catch* a fall and a way to *miss* one.
Chains with: the wind blaster (it fans and lengthens the flame, widening the
updraft), the sluice (douses it, then a dry bowl catches), the seesaw (throw a
body onto the plinth deck), the shockwave from his landing (the quake knocks
the flame out), the headless body's route planner (the beacon is a goal), and
card 3 (runnel lights it) and card 5 (Mudge lights it).
Breaks: the bowl is the weak part. His shockwave front or a bulk hit
snaps the shaft at the helmet joint; the bowl falls as a rigid piece, spilling
lit resin as a flame patch on the ground that burns a few seconds (a light and
a beacon on the floor, now on his lane) and settles to a cracked bowl on a
stump. A bowl broken while lit is brighter for those seconds, then out.
Build cost: **med.** Plinth, shaft, stair and bowl are procedural (the
makers' Build.solid blocks and a ring of segment hulls). The crouching figure
wants one small Blender model, static, no rig, shared with the throne's
figure if that is built (same helmet language). The flame is a cheap
billboard-quad particle with one OmniLight3D; the heat updraft is an
`Area3D`. The beacon registration is a few lines on the existing hook.
Model budget: sculpt high, bake low for the figure (~2-3k tris with baked
normals/AO against ~25k modelled). Silhouette geometry on the bowl rim
(chipped lip, ~100 tris). Vertex-colour soot on the shaft and bowl inside is
free. Import LODs and visibility ranges: the `great` cresset is seen for
100+ m through haze, so a 600-tri LOD past 50 m and a billboard flame at
range save an estimated 30-50% of its draw cost; an OmniLight beyond 60 m is
culled and replaced by an emissive impostor.

---

# Sun-mirror (maker_mirror, family makers)
Verb: solve (turn a mirror so its beam lands on a target), time a crossing (a
beam sweeps as the mirror drifts), stay hidden (stand where the beam is not).
Look: a disc of polished black obsidian, 2.4 m across, slightly concave and
very dark, set in a carved stone ring on a squat basalt pedestal. The makers
polished iron-ore and obsidian mirrors; the ring is cut with a face of the
inhaler's brow. The ring turns on a vertical pivot and a horizontal one, set
in a stone socket you can see and push. Bare, it shows the haze and a ghost of
the light shaft above it; in a beam it is a white-hot coin and throws a
visible pale rod of light, a stripe of dust. Moss and roots at the pedestal;
the disc itself is spotless because it was meant to work.
Behaviour: changes state. The disc is `fixed` or `turnable` (knob). A
turnable one rotates in quarter steps (4 compass bearings) each time the pilot
slams the pedestal's `deck` or twirls beside it (the wind blaster also
pushes it round). Each step snaps with a stone clack. A beam originates from a
`shaft` (a pool of falling light from far above, a pale cylinder of dust-lit
haze on the isle; it shines only when the shaft tile is in the isle's light
grid) and the mirror redirects it along its bearing, up to ~40 m, ending on the
first `lit=false` target in the way (a cresset, a runnel head) and lighting
it, or on the first obstruction (a cresset's flame refracts it a little).
The ray is cosmetic plus one logical raycast per turn.
Size: pedestal 1.6 m (one tier) so the disc reads from a stair; the disc's
centre at 2.4 m, out of a standing grab, so you ledge-hang on the pedestal's
lip and push from below, or climb the ring's flange (a 0.5 m band, wall-kick
and chain). Footprint 1 x 1 CELL. The clear lane in front is 6 x 6 m so the
body fits to find you there; the pedestal itself is a pillar-wide obstacle he
walks round.
Collision: pedestal top is a clean walk box; the disc plane is a thin convex
hull (a wall, and the body's bulk box shatters it). The ring's flange is a
clean ledge. The beam has no collision.
Motifs it enables:
- A shaft-court: a pool of light from the ceiling gap, three mirrors on three
  tiers, each turned by the pilot to relay the beam down a chain of ledges to
  an unlit great cresset at the bottom: a lighting puzzle that is also a
  stair climb.
- A beam sweep: a drifting mirror on a slow crane that rakes a stripe of light
  across a plaza; stay in the shadow of the pillars while it passes.
- A fire-starter: the concave disc focuses a shaft onto a wick bowl to
  light it without your torch (the ruin doing its old job).
Threat pairing: a beam is a lit stripe, and a pilot in a lit stripe is
visible (the `glow` multiplier applies: ~1.6x awareness). Turned toward an
Olmec, the beam on his eyes is nothing (they are stone) but the beam on his
body lights his silhouette so you can see where he is. A mirror turned
toward a cresset lights a beacon the player didn't mean to, drawing the body
to the stripe: puzzle solved is also an alarm. The mirror is cover when
shattered: its broken shards lie as a thin ground cover of dark glass.
Catches / throws: *Standing*: the pedestal top is walked. *Airborne*: the
ring's flange is a ledge (grab), the pedestal top a catch pad. *Tumbling/
stunned*: the disc is a **carom face** (reuses K5's one new rule): a stunned
or fast airborne body that meets it is reflected as a `toss`, source
`light_mirror`, with restitution about 0.5 (glass-hard, not stone-hard) and
the *beam's bearing*: the body comes off along the same direction the beam
leaves. That makes a mirror's bearing aimed twice, once for light and once for
a flung body, both set by the motif's placement. *Pushing*: a slam on the
pedestal `deck` turns it a quarter step. It does not output a `knock`.
Chains with: card 1 (the beam lights a cresset), card 3 (the beam lights a
runnel head), the seesaw (a toss onto the pedestal deck turns the mirror as it
lands), the wind blaster (the blast turns it round), the inhaler head (his
inhale pulls a loose disc?), the headless body (his bulk box shatters it).
Breaks: a bulk hit or a shockwave over the pedestal cracks the disc into five
or six shards (rigid pieces, settle as a patch of glass). A broken mirror no
longer redirects a beam; it throws scattered flecks of light (cosmetic, a
glitter ring) for a few seconds. The puzzle is lost, the floor is a hazard
(slick shards, a `slide` surface), and the beam, if it was running, lights the
isle edge instead.
Build cost: **med-high.** The pedestal, flange and ring are procedural. The
disc is a flat-ish concave mesh (a small Blender or procedural lathe; a
shader fakes the mirror: sky-colour, shaft-tint and a Fresnel, no real
reflection). The beam is a raycast plus a stretched emissive mesh. The
turn is a tiny script; the carom face rides K5's one PilotMotor rule (Opus).
Model budget: silhouette geometry on the ring's face (~150 tris). Shader
reflection (a fake env map) replaces any planar-reflection render pass, saving
the cost of a second camera (an estimated 1-2 ms on a mid GPU if it had been
a real mirror). The beam as one stretched quad with a scrolling dust texture
costs about nothing. LODs apply to the pedestal and ring (200 tris at range).
Sculpt-to-bake applies if the brow carving on the ring is wanted (~1k tris).

---

# Oil runnel (maker_runnel, family makers)
Verb: solve (light the head and follow the fire), climb (the lit stretch shows
the holds), time a crossing (a flame running along a wall is a clock).
Look: a shallow carved channel, 0.3 m wide and 0.2 m deep, running along the
face of a glyph band, round the edge of a tier, or across a floor between
cressets. It is lined with glossy black resin that once carried lamp oil from
a cistern to every cresset in the city (the makers lit their halls with
it). A few rune cells sit along it as feed ports: small bowls where the
channel starts. Unlit it is a dark groove picked out by the Olmec stone's own
grooves, hard to tell from carving. Lit, a thin flame (not a blaze: a bright
wick the width of a hand) runs along it at walking pace and leaves the channel
glowing a dull orange behind it for a few seconds, which lights the wall's
holds, the glyph band and the next ledge like a trail. Dry stretches are
cracked, with a gap where it was broken.
Behaviour: changes state; moves (the flame). A runnel is a polyline in the
piece's frame with `speed` (a knob, 2-4 m/s, about a walking pace for the
pilot at run-up), a `head` (the start port; lights from a touch, a cresset, a
beam or a runnel upstream) and a `tail` (where it ends: a cresset it lights, a
dead end, a gap). Each cell of the channel is `fresh` (fuel), `spent` or
`broken`; flame passes only over fresh cells and a broken cell stops it
(stairs break the channel). The trail glows for `afterglow` seconds so the
pilot can see where the holds are. It is a one-shot: a spent runnel stays
dark until a seed re-fuels it (the motif can set a `refill` valve).
Size: the channel is 0.3 m wide on a glyph band (the makers' band, 1.0 m
high), so the pilot is climbing *beside* it, not on it. A flame-lit band is a
visible route of holds spaced SET_OFF or less. Along a floor it is a 0.3 m
groove: walkable, you can slide over it. A runnel is 1 CELL per segment, up to
8 segments on a wall.
Collision: none for the channel itself (a visual groove on an existing
collider). It follows whatever collider carries it (a tier band, a stair
cheek, a stela side).
Motifs it enables:
- A lit stair at night: strike the foot of a long runnel and chase the flame
  up a switchback to the great cresset at the head, always a few steps behind
  its glow, because it outruns a carried torch's reach.
- A fuse wall: a glyph band whose runnel runs up its face; light the bottom
  and climb *with* the flame to the grips it shows.
- A split path: two runnels from one cresset, one to a hide, one to a
  beacon; the flame you light is the route you chose.
Threat pairing: the flame is a clock and a lamp. Lit, it lights the pilot for
the sight cone while they climb beside it. Running ahead of the flame is
safe; running behind it is lit. A broken cell stalls the flame so a lit stretch
ends at a gap the player must cross dark, with the Olmec turned toward the
glow. The Olmec's shockwave through a lit runnel can spill it (the fuse
cells burst into brief burning splashes on the floor, a hazard of slick
resin).
Catches / throws: nothing physical: the runnel is a link of *information*,
not a body. It *carries state*: it hands its flame to a `lit=false` cresset,
mirror target or wick, with a `beacon` on arrival. It does not catch or
throw a body. A resin splash (from a break) is a slick surface (a
`slide` friction patch) that *sheds* a standing body: friction ~0, source
`light_runnel`, no knock.
Chains with: card 1 (lights it at the tail), card 2 (the beam lights its
head), the sluice (water puts a stretch out; fuse stalls), the wind blaster
(blows the flame faster along the groove), Mudge (a lit Mudge's drips can
fuel a spent runnel, an inversion), and the headless body's route planner
(the beacon at the tail).
Breaks: a shockwave or a bulk hit that cracks the carrying band breaks the
cells under it: those cells become `broken`, the flame stops, and a fallen
facing sheet carries a stretch of dead channel down as rubble. Spilled
resin burns briefly on the ground as a flame patch (a light and a slick),
and the dead stretch is a new gap in the route.
Build cost: **low.** It is a shader on an existing band (a CUSTOM data
channel for the polyline, a scrolling emissive for the flame, an afterglow
fade by time since lit), plus a small script that walks the polyline and
lights the tail. No new geometry. The only physics is the slick patch from a
break (reuses the friction/slide surface).
Model budget: parallax depth for the groove is optional (the channel reads
deeper for no tris, ~0.1 ms, only if the shader grows a height channel).
Vertex-colour soot along the channel is free. The flame is a shader trick, so
it is a few hundred pixels, not a mesh; no LOD cost at all.

---

# Hush gallery (maker_hush, family makers)
Verb: stay hidden (a pocket out of his cone and out of the light), solve (the
snuff trough douses your torch so you can use it), listen (the head's pull
cannot reach you in here).
Look: a low gallery cut into a tier's flank: a roofed arcade of squat square
piers, with a stone awning drawn forward over the opening like a heavy brow,
and a hanging curtain of woven hide and root across the gaps (the makers
curtained their sacred rooms). Inside, a narrow trough of still black water
runs the length of the floor, fed from a cistern. The ceiling is lampblack;
the carved piers inside are worn smooth, and the only light is a pale seam of
haze at the opening. From outside it is a dark mouth under a cleft brow;
seen against haze it is the darkest thing in the room. The water is a snuff
trough: a deep stone basin sized for a hand or a torch to be plunged.
Behaviour: changes state. The curtain is passable (parts as the pilot pushes
through) and drifts back. The trough douses a lit torch dipped in it (the
pilot's torch goes out; the `hush` zone is a `shade` volume, awareness
fill x ~0.3 and out of the head's gaze). The gallery is silent: it muffles
footsteps (`hearing` x ~0.5 inside), but a landing or a slam still carries.
There is also a `seep` variant: the trough overflows to a sluice mouth at
the far end, and a cistern valve can be opened by the pilot to flood the
gallery (a `sluice` flush that washes out a tumbling body).
Size: the opening is a crouch-slide height (about 1.2 m high and 3-4 m
wide, under `WorldScale.opening` territory: a walker-only pocket on purpose),
2 CELL deep (8.8 m) and 1-2 CELL wide; the awning projects 1.0 m. Inside is
low (1.8 m) so a standing pilot fits and a body of 6.7 m neck does not.
Walker-only: tagged so the body's rays skip it. The trough is 0.6 m wide, 0.5 m
deep, a ledge to step across and a drop to wade. A gallery sits on a tier
that has a 6 x 6 m landing in front so he can stand there looking for you.
Collision: the floor is a clean walk box; piers are plumb hulls (wall-kick
and slide cover); the awning is a roof hull with a grabbable lip (you can
hang from it from the outside). The curtain is a thin non-colliding trigger.
The trough is a clean-bottomed basin (shallow, wadeable).
Motifs it enables:
- A pocket on a landing with a great cresset: you must put your torch out to
  cross the lit landing in the dark, then relight on the far side.
- A hide-and-crawl: a stair whose only safe stretch is the gallery under the
  tier, with the Olmec's eyes passing at the mouth.
- A cistern gallery: open the valve and the flush washes the Olmec's lane
  below (his shockwave through the water does not cross it).
Threat pairing: the gallery is the trap. He cannot enter (walker-only) but he
can stand at the mouth, and his sight cone stops at the curtain: you are
hidden, and trapped. The head's pull (inhale) is blocked completely by the
stone. If he stays, you leave by the far mouth or the awning's lip; if his
shockwave lands on the tier above, the awning cracks and he can see in.
Catches / throws: *Standing*: the floor is walked. *Sliding/tumbling*: a body
entering the mouth is kept in the line of the piers and, if stunned, held by
the low roof; it exits the far end at its own speed along the gallery's axis
(the K5 throne's "barrel" behaviour, shorter). *Wading*: the trough slows a
step (a shallow-water drag, a state not a throw). *Dousing*: a torch dipped
in the trough goes out; a flaming body (lit, thrown) landing in it is put out
with a hiss and no knock. *Flooded*: the `seep` variant's valve opens a flush
that carries a standing or downed body to the far mouth at slide speed, source
`light_hush`, no `knock`. Mounts: `mouth` (the far end, a sluice nozzle), `deck`
(the roof, a landing for a cresset), `run` (the gallery as a lane).
Chains with: card 1 (the cresset on the roof deck lights the gallery's
mouth), the sluice trap (the seep variant), the headless body (stands at the
mouth), the inhaler head (his pull blocked), the Ram or tumbling block (down the
gallery), and the pilot's torch.
Breaks: the awning is a lintel and breaks as one: a bulk hit or a landing
on the tier above shears it, and it falls across the opening as a roof slab
(a ramp). The curtain tears down. The gallery goes from a hide to a ruined
alcove open to the light: its `shade` volume is deleted when the awning goes,
so a broken gallery is no longer cover and a body can reach in.
Build cost: **med.** The gallery, awning and piers are procedural cuts in the
makers' tier block. The curtain is a cloth/strip shader on a quad (no
physics). The shade volume is an `Area3D` that scales the sight fill; the
snuff trough is a small trigger. The flooded variant reuses the sluice.
Model budget: silhouette geometry on the awning's brow and the curtain's
frayed edge (~200 tris). The interior is dark by design, so texture
resolution can drop there (an estimated 20-30% of the interior's texture
memory) and the pier relief can be a flat decal. Vertex-colour soot on the
ceiling is free. LODs and visibility ranges apply to repeated galleries.

---

# Wick spire (maker_wickspire, family makers)
Verb: climb (a tall lone spire is a vertical gauntlet), perch, solve (get a
light to the top), and, for Mudge, watch it light itself.
Look: a slim natural basalt column (the makers' palisade at full height, but
single and alone), 14-22 m tall and 3.2 m across at the foot, tapering to a
wide crown. The crown is cut into a shallow cup with a stone wick-post at its
centre. Its foot is rooted in a drum of makers' masonry, and its sides carry
shallow glyph steps spiralling up like a ladder and a rope of resin dripped
down the south face. In haze it is a dark needle rising out of the abyss;
isles around it are lower, so it is the highest point on the layer. The base
holds a dry cistern and a hoist. A lit crown from a distance looks like a
star standing on the dark; Mudge, if it has climbed, is at the crown.
Behaviour: static. A `crown` socket takes a cresset (card 1, `spire` size)
or a Mudge. A lit spire registers as a beacon with an extended
`beacon_range` (x ~3, the highest light on the layer: every Olmec turns
toward it, and from far). The glyph steps are a climb route; a dripped resin
rope hangs a swing rope (`rope` mount) on the south face.
Size: the glyph steps are SET_OFF apart (1.6 m) with 0.5 m treads (a ledge
chain, no gap above the pump). The spiral is 3 steps per 90 degrees, so a
full climb is about 14 steps. The crown's cup is at least `TOP_ROOM` across
(a perch) and the wick-post is 1.4 m high: a lit crown is a hand reach above
the lip. A drum base 2 x 2 CELL and 3 tiers; the ground around the drum is a
6 x 6 m landing (so a body arrives at the foot). The spire is *not* a body
route: the glyph steps are narrower than his foot and it is walker-only above
the drum. He reaches the top only by a climb he cannot make; he circles at
the drum.
Collision: the shaft is a convex hexagonal hull (wall-kickable); each glyph
step is a clean box (a grab and stand); the crown is a walk box in the cup. The
wick post is a thin plumb hull.
Motifs it enables:
- A district of isles over an abyss, ringed by lesser spires, with one
  wick spire at the centre that every route leads past; whoever lights it
  makes the whole district a target.
- A race: climb the spire in the dark to light the crown before the Olmec
  climbs the drum, because he turns toward it once it burns.
- Mudge's home: a candle-bodied climber walks up the south rope, sets itself
  on the wick post, and burns.
Threat pairing: lighting the crown is the beacon; everything turns toward it,
including the body, who climbs the drum, then cannot go up. He waits at the
foot, staring up, eyes lit. The player at the top is lit against the dark for
every Olmec and the dragon, in the sight cone's furthest reach. That is also
a tool: from the top the whole district is visible, the way down a swing rope
across the abyss is the ride out.
Catches / throws: *Airborne*: the crown cup is a narrow catch (a perch for a
precise throw, TOP_ROOM wide), and the spire shaft is a wall kick between it
and a neighbouring spire one chimney apart. *Standing*: the glyph steps are
walked and chained. *Tumbling/stunned*: a body landing on the crown rolls
into the cup (held) rather than off, because the cup is concave; one landing
on the shaft slides down the glyph steps and off at the foot (a long fall,
the fall stun). *Swinging*: the rope on the south face is a swing rope anchor
on the crown. Its throw is the swing rope's. It outputs no `knock`; it is a
catch and a perch, and the beacon is its output. Mounts: `crown` (a cresset
or a Mudge), `rope` (the south face), `deck` (the cup).
Chains with: card 1 (the cresset is its crown), Mudge (its home), the swing
ropes, the wind blaster (the crown is in the wind), the headless body
(circles the foot), and the plane-less climb toward the sky above.
Breaks: the spire is basalt and does not break under him (it is the thing
he cannot knock down). It breaks by a scripted *topple* instead: his
shockwave at the drum cracks the base ring and the spire leans, then falls as
one long rigid column that settles across a gap as a bridge, with its crown
cup lying on its side. A lit crown that falls goes out; the beacon is gone and
the route up is gone, but a new bridge is made. The spire's topple is one
event per layer (a `one_shot`), a set piece.
Build cost: **med.** The shaft is a tall hexagonal prism procedural cut with
glyph steps and a crown (the K5 palisade's builder, scaled). The drum is
K5's tier. The crown cup is a lathe. The topple is the destruction round's
rigid-piece model with a single tall cylinder shape. Mudge is its own
enemy (Opus, separate round).
Model budget: silhouette geometry on the crown (chipped lip, ~80 tris).
Merge or instance the shaft prisms (a 24-sided cylinder LOD at range is
~100 tris against ~600 near). Import LODs and visibility ranges apply
strongly, since a wick spire is the farthest-seen piece: a billboard past
80 m. Vertex-colour grime and the occlusion feed are free.

---

## Motif hunches

- **The Lamplighters' Stair.** A grand stair in eight flights (the kit's
  grand_stair, widened to 5-6 m for him) up a drum over the abyss, with a
  dead great cresset on each landing, a runnel along the right wall linking
  them, a mirror in a shaft at the top, and a hush gallery under the fourth
  landing. You climb in the dark, light one landing at a time, and each lit
  landing is a bead the Olmec turns toward; the gallery is where you put the
  torch out when he starts up the stair. A place first (a stair-and-light
  silhouette against the haze), no scripted chain: the runnel, the mirror and
  the cressets are links that meet where the player is, and the route up is a
  stair a torch can climb with no puzzle at all.
- **The Wick District.** A cluster of isles and city fragments round one wick
  spire, with a few dead cressets on landings and a long runnel looping
  between them. Whoever lights what draws the body to a different corner of
  the district, and the spire's crown is the top of the world: the highest
  light for a thousand metres. A climb-at-night motif for a tall stack of
  isles, and Mudge's natural home.
