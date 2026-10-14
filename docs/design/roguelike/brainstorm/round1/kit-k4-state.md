# Kit K4: things that change state (round 1 brainstorm, 2026-10-13)

> **Status: brainstorm, nothing decided.** Five kit piece cards in the motif
> brief's format (docs/design/roguelike/motif-brief.md, section 4). Theme:
> the mystery pieces, a ruin that reacts and a player who learns its rules.
> Sizes are named from the pilot (RuinKit Scale, PilotMotor, WorldScale);
> metres in brackets are at the default sizes (walker 1.0, plane 2.0) and
> are only there to read by.

## The rune logic (one signal language for all five)

The makers wired their buildings in stone: **a rune is a switch, a lit
groove is a wire, and every state change runs along a groove you can see.**
Each piece has *sources* (a glyph plate that is stepped on or slammed, a
font a rune is spent into, a chime stone that hears noise, a sun/dragon
glyph that reads shadow, a slow water-clock that is time) and *sinks* (the
thing that moves). A source lights; its light runs along a groove cut in
the stone at a steady pace (about a run's pace, so you can race it), and the
sink changes state when the light arrives. Grooves are the serpent's lit
rune grooves (shaders/rune_serpent_runes.gdshaderinc on
shaders/olmec_stone.gdshader, `runes` on): dark and dented when cold, warm
when lit, so the whole circuit reads from a scouting distance and the player
traces it with the eye. Three rules, the same everywhere: **lit holds,
dark lets go** (every sink has a lit state and a dark state, and the dark
one is where it rests); **a line drains as it times out** (a held state
shows its remaining time as the groove going dark back toward its source,
a fuse you can read); **one glyph per channel** (a source and its sinks
share a sigil carved at both ends, so two circuits on one isle never
confuse). Triggers in the one vocabulary: *step* (weight on a plate, held
while you or a thrown rune stand on it), *slam* (the flow charge's
downdraft onto a plate, or any body landing on it hard: latches it), *spend* (a rune into a font: lit for a
time), *noise* (a landing on resonant stone, a slam, a bell, a chime
struck), *the dragon* (its shadow crossing a sun glyph, or its roar as
noise), *time* (a water-clock basin that fills and tips). The generator
wires a circuit as data (source, groove path, sink, channel glyph, hold
time), so the same pieces make a puzzle, a tool or a trap by wiring alone.

**The circuits don't care who trips them (everything chains).** A plate
counts any body, so a stunned pilot thrown onto it, a headless body
knocked onto it, a tumbling block or a drifting raft all press it. Noise
is any impact over a threshold, so a ragdolled landing, a seesaw slam or
a door dropping all sound the chimes and wake the faces. Light is any lit
groove, so one circuit lit by accident shrinks the roots next to it. So a
state piece is a link in two ways. It throws bodies (a `knock` or `toss`
under its own source name, so the per-source `restun_gap` lets it chain
with everything else). It also **rewires the place mid-chain**: a body
tumbling out of one trap slams a plate, the basin floods, the flood
lifts the body to the rim and washes it onto a seesaw. The circuit's
groove shows the rewiring as it happens, so a chain one player sets off
by accident is a route the next player reads off the stone and rides on
purpose. Each card's Catches / throws names the source a piece knocks
under, and whether the generator can aim what it throws at the next link.
The stun rules (docs/design/roguelike/stun-round1.md) keep it fair:
different sources chain freely, the same source can't restun inside 1.2 s,
and after 3 s stunned the pilot can always break out.

---

# Weir Basin (weir_basin, family maker)
Verb: time a crossing, ride (the water lifts you), solve (flood to reach,
drain to descend).
Look: a square sunken court of the makers' basalt, stepped down on all
four sides in deep courses like a ballcourt's benches, a squat weir head on
one side with a jaguar-mouthed spout and a drain throat in the floor under
a carved grate. Pumice rafts (porous pale stone blocks, holes like a
sponge) lie on the floor when dry. Lichen tide-lines on the courses mark
where the water last stood; reeds and moss only below the high mark. The
weir head carries the channel glyph and a groove running round the rim, the
basin's "level" readable as a lit band.
Behaviour: changes state. Two states, dry and flooded, with a fill and a
drain between (8-12 s each, a knob). Trigger: spend (a rune into the weir
head's font floods it for a hold time, then it drains), slam (the floor
plate under the grate latches it drained until slammed again), time (a
water-clock variant floods and drains on a cycle). Fill: the spout roars,
water rises at a steady pace, rafts lift and float to the rim, bobbing like
the bob slabs. Drain: the grate opens, a whirl forms over the throat
(Plughole, ideas-traps.md 21) pulling loose things and the pilot toward it
at a wade's pace for the last third, the rafts settle back on the floor
where they lie, not where they were.
Size: each bench course SET_OFF high (1.6) and STAND deep or more, so the
dry basin is climbed out course by course; the basin's depth 3-4 courses
(4.8-6.4), past any single jump, so the dry floor is a pit you climb out
of. Rafts TOP_ROOM across and more (2 x 2), floating with their tops just
under STEP_UP (0.45) over the water. A flooded basin is a field of rafts a
twirl gap (3.0) apart at most. Water deeper than STAND does not drown: he
floats at the surface (a buoyant `motor.carry`), wades and jumps out with
the wade's reduced jump, so deep water is slow, never death.
Collision: courses and rim are clean walk boxes; the weir head's faces are
wall-kickable; rafts are one box hull each, physics bodies only in the
vertical (buoyant), drifting on the surface current. Water is an area, not
a body. The grate is a walk box while closed, an open hole in the drain.
Motifs it enables:
- A sunken court on the drowned nave's line: dry, the way on is across the
  floor; flooded, the rafts lift you to a high doorway on the far side.
- A stack: a basin on an upper isle whose drain spout feeds one below,
  flooding it (one circuit, two isles).
- A "rune-or-climb" toll: spend one rune to float up, or climb four
  courses bare-handed.
Threat pairing: the drain is the trap: a pilot standing in the basin when
it times out is drawn to the throat; a grate over a layer drop is a fall
(Plughole's softer fail, one layer down). Flooding is a trap in reverse:
an enemy (headless body, ram) standing in it floats and drifts, so a
flooded basin is a knock-off arena; a speedrunner rides the rising water
past four courses in one go.
Catches / throws: catches *any* body that lands in it. Standing or riding a
raft: lifted with the water (buoyant carry), never stunned. Airborne or
tumbling: falls into the water, which ends the fall without a fall stun (the
basin is a net), but a stunned body stays stunned and floats limp. It also
*catches as a trigger*: a body landing hard on the slam plate under the
grate latches the drain, and a body thrown into the weir head's font
basin counts as a spent rune's weight (a step) on the water-clock variant.
Throws in three ways. **Rim spill**: the last 1 s of a fill overtops one
low notch in the rim (the weir's lip, a chosen side), and anything floating
at the surface goes over it at a wade's pace plus the water's push (about a
run's pace, level, a `toss`, source `weir_spill`). A stunned body goes
over still stunned. **Throat spit**: the drain throat, unblocked with a
body in it, spits it out of the spout below the isle's lip (`toss` down
and out, a long jump's speed, source `weir_throat`) or, on a stack, into
the basin under it. **Raft heave**: a raft surfacing under a body pops it
up about a first jump's height (`toss`, `weir_raft`). Aimed: yes. The
spill notch and the spout face a side the generator picks, so the throw
points at the next link.
Chains with: from the seesaw (a launched stunned body landing on the
slam plate drains the basin it lands beside), the tumbling block or
logs (rolling onto the plate), the sluice (its spill falls into the
basin and floods it a step: a sluice feeds a weir), the inhaler head (a
body it spits into the basin), the headless body (knocked onto the
plate it presses it as long as it lies there). To the seesaw (the rim
spill drops a floating body on its low end), rope bridges (the spill
notch faces a bridge head), a lower basin (throat), the Plughole
whirl, and a Sleeping Face (the weir's roar on filling is noise).
**The chain:** the tumbling block knocks him onto the slam plate; the
basin floods; he floats up to the rim limp and the spill washes him onto
a seesaw's low end, which flings him on. Next time he does it on purpose:
slam the plate himself, ride the water up, and take the spill as a free
launch.
Build cost: med. Procedural (Build.solid courses and weir, KitWater's
`still` sheet raised and lowered), the rafts reuse the bob slab's motion,
the whirl reuses the sluice's drain tell; new: the buoyant carry in the
motor and a level-driven water sheet.
Model budget: silhouette geometry (chips on the course edges only, the
faces' wear from the stone shader); vertex-colour grime (tide-lines and
crevice dark baked per course, as the Olmec bakes occlusion into vertex
alpha); visibility ranges on rafts (they read as the basin's colour past
~80 m). Est. 2-3k triangles for the basin, 60-100 a raft; savings ~1-2k
triangles over chipped faces, negligible frame time. Sculpt-bake, bones,
parallax: not needed (procedural stone).

---

# Shy Root Lattice (shy_roots, family maker)
Verb: climb (grown), pass (retracted), time a crossing (it closes behind
you).
Look: a tall maker doorway or a bridge gap choked with a pale, fibrous root
mass, thick as an arm, grown through the stone's rune grooves as if
feeding on them. Grown, it is a woven lattice that fills the opening;
shrunk, it hangs back as knotted curtains in the jambs and a mat on the
lintel. Overgrowth as the threat (the brief's twist): the roots shy from
light, and they are the only living thing in the ruin that moves.
Behaviour: changes state, grows and retracts over 1-2 s with snappy holds
(a shiver, a hesitation, then the pull). Trigger: a lit groove within
their reach (any circuit lit nearby: spend, step, slam), a thrown lit rune
landing among them (the "runes as ammo" wildcard), or the dragon's fire
(they shrink fast and stay out longer: scorch). Dark again (the circuit
times out), they grow back from the jambs inward. Timing knobs: retract
time, hold, regrow time, regrow pace (the "fuse" groove drains as their
hold ends).
Size: the opening is a walker's doorway (2 TOP_ROOM across and over
WALL_HEIGHT) or, at the flown size, `WorldScale.opening(TOY_THREAD)` (7.0
at the defaults), so a lit lattice lets the plane through and a dark one
does not. The grown lattice's holds are spaced under SET_OFF (1.6) up and
1 STAND apart across, so a grown lattice is a climbing wall (ledge grab and
chain to the top), and its upper strands are under GRAB_TOP from the lintel
mat.
Collision: grown, one flat wall-kickable box per lattice panel plus ledge
boxes at the hold rows; shrunk, only the jamb curtains (thin boxes against
the jambs, so they never narrow the opening below its size). The growth
sweeps its box across: a pilot in the way is pushed out to the side he
entered from (`motor.carry` with the strands), never crushed.
Motifs it enables:
- A walled garden (the makers' nursery?) where each doorway is a lattice
  and the lit plates are behind them: light one to open the next.
- A bridge gap filled with roots: dark, a climb across underneath; lit, a
  clear run (two routes, one circuit).
- A plane-only find behind a lattice that only a lit rune (or the dragon's
  fire) opens to the sky.
Threat pairing: regrowth closes the door behind you or shoves you back out
mid-pass; a lattice across a ledge regrows and pushes the pilot off the
ledge's open side. As a tool: its push is a launch (stand in the jamb as it
grows and ride it sideways across a gap), and grown it is a free climbing
wall.
Catches / throws: grown, it catches airborne and tumbling bodies like a
net: a stunned body thrown into it sticks for a beat (0.3 s), then slides
down the strands to the threshold, and the stun is not renewed (a soft
catch, the lattice a backstop). Standing or climbing, it holds. Retracting
with a body on it: it lets go and he drops. Growing back is the throw: the
strands sweep from both jambs to the middle, so a body in the opening is
shoved out along the door's axis, toward the side it is nearer. Standing:
a `toss`, a run's pace with a little lift (source `roots`). Stunned: thrown
still stunned with fresh poise. A body caught in the lintel mat as it
regrows is flung *up and over* (a first jump's height, a `toss`), a
launch onto the wall top. Aimed: along the door's axis only, in or out by
which side the body is on. The generator aims it by facing the doorway at
the next link.
Chains with: from any lit circuit nearby (a weir's flooded rim, a lit
span, an open chime door all light grooves and make it shrink), the
dragon's fire (scorch), the wind vents and blaster (blowing a body into
the grown net), the inhaler head (spat into it). To a seesaw or a rope
bridge set outside the doorway (the regrowth shove carries onto it), the
Sluice (a lattice across a channel releases the body into the wave when
it shrinks), and the gulf (a lattice on a ledge regrows a body off).
**The chain:** a lit span times out behind him, its groove going dark
lets the roots regrow, and their sweep throws him, still running, out of
the doorway onto the far seesaw. The rewiring is the point: light anything
on the isle and every lattice near it opens, so one rune spent for the
bridge also opens the garden door.
Build cost: med. Procedural strands (swept tubes from the kit's growth,
scripts/ruin_growth.gd) animated by a grow parameter; collision is boxes
gated by the parameter. No rig.
Model budget: silhouette geometry (strands are the silhouette; keep them 4-6
sided); import LODs / visibility ranges (drop fine strands past ~40 m, keep
the mass); vertex-colour grime (dark root crotches). Est. 3-5k triangles
grown, ~2k with LOD at range, saving ~60% at distance; one draw call.

---

# Lit Span (lit_span, family maker)
Verb: time a crossing, solve (keep it lit), fly through (dark).
Look: two squat maker pylons facing across a gap, each a block carved with
the channel glyph and a groove running down its face into the sky.
Between them, a line of square stone tiles hangs in the air. Lit, the
tiles sit end to end in a level walkway, their grooves joining into one
glowing line. Dark, they drift apart in loose formation along the gap
(the floating/drift stones), a tile's width or more apart, slowly turning.
Behaviour: changes state. Lit: tiles glide into line from the source end
outward (0.15 s a tile, a ripple you can watch), and hold. Dark: the line
drains from the far end back to the source (the fuse), each tile letting
go as the light leaves it and drifting out. Trigger: spend (a rune lights
it for a hold time, 8-15 s), step (a plate on the near pylon holds it lit
only while weighed: you can't stand on it and cross, so leave a thrown rune
or a carried object on it), the dragon (a sun glyph variant that lights
while its shadow is *not* over it, so the dragon's pass snaps the bridge
mid-crossing), time (lights on a cycle).
Size: the gap is 3-6 long-jump reaches (13-25 m, beyond a glide's reach
from level so you need the bridge or a planned drop). Lit tiles are
TOP_ROOM wide or more (2.0) and STAND deep each, flush. Dark tiles drift
apart to between one and two twirl gaps (3-6 m) and up and down within
SET_OFF, so the dark span is a hard but legal hop line (the bare-handed
route the ledger's validator asks for). Dark, the column of drifting tiles
leaves `WorldScale.opening(TOY_THREAD)` (7.0) clear somewhere for the
plane; lit, it is a wall to fly round or under.
Collision: each tile a clean walk box; pylon tops walked, pylon faces
wall-kickable. Tiles are kinematic, moving as the foot pieces' slabs move,
carrying the pilot.
Motifs it enables:
- A causeway of three spans in a row, each wired to a different source:
  one spent rune, one plate, one sun glyph (learn three rules in one
  crossing).
- A ring of pylons round a central crown, spans flicking on and off with
  the time source: a clock you cross on its rhythm.
- A span whose plate is on the far side: hop the dark tiles across, step
  the plate, and the walkway forms behind you for the return trip.
Threat pairing: the timed-out span drops you into the drift (now you're
hopping moving tiles mid-gap); the far-to-near drain means stopping halfway
is always the worst choice. The sun glyph turns the dragon into a bridge
breaker. As a tool: the forming ripple carries you (ride the line as it
assembles), and a dark span's drifting tiles are perches for an enemy you
can knock into the gap.
Catches / throws: catches standing and riding bodies (carried as the
foot slabs carry). Airborne bodies land on a tile, and tumbling ones too:
a stunned body on a tile is carried as any grounded body is. As a
trigger, a body lying on the step plate (a stunned pilot, a knocked-out
headless body, a thrown rune) holds the span lit, so an enemy you knock
onto the plate is a bridge. Throws in two ways. **Snap-in**: lit, each
tile glides into line hard (0.15 s), so a body on a drifting tile as it
snaps is thrown off its far side in the snap's direction, about a twirl's
speed (`toss`, source `lit_span`). Standing, he can jump it (rides the
snap's pace, as the sluice's riders do). **Let-go**: dark, each tile drops
a little and turns as it lets go, shedding a body on it sideways, a low
`toss` (it rolls off). A stunned body keeps its stun. Aimed: the snap
throws along the span's axis, outward from the source pylon. The
generator aims a span by which pylon is the source.
Chains with: from anything that throws a body onto the plate (seesaw,
logs, tumble block, the ram's buck, the headless body knocked down on
it), the dragon (sun glyph: its pass lets go of the span), the bell (a
bell-timed span). To the Shy Root Lattice (the groove going dark regrows
them), the wind vents (a vent under the gap catches a body shed by a
let-go tile and lifts it to the next tile), the gulf, and the Sky Ray
(a body shed onto its back rides it).
**The chain:** a stunned headless body knocked by the ram lands across
the plate and the span forms under the pilot as he falls off the ledge.
The snap-in throws him across the gap, still tumbling, onto the next
pylon. The route: knock the enemy onto the plate on purpose and ride the
snap.
Build cost: low-med. Tiles reuse the drift/bob stones and the foot pieces'
carry; pylons are two Build.solid blocks; the logic is a circuit plus a
tween between two tile layouts. New: the shadow sampler for the sun glyph.
Model budget: silhouette geometry (tiles' chipped edges); vertex-colour
grime; visibility ranges (tiles to flat boxes past ~100 m). Est. 80-120
triangles a tile, 600 a pylon, ~2-3k total; savings small (~30%) since
it's already cheap.

---

# Chime Door (chime_door, family maker)
Verb: solve (the order), ride (its exhale), stay hidden (the hall behind).
Look: a single colossal slab door in a maker wall, as tall as the headless
body, its face a relief of a stylised Olmec mouth with heavy lips; round it
on the jambs, three to five chime stones (pale polished cylinders hung in
niches, the Olmec eye's stone) each carved with a glyph. The door's sigil
is the order, and the card names it in the ledger's voice (Echo module 14:
"strike N chimes in the card's remembered order").
Behaviour: changes state. Closed / opening / open (held) / closing. Trigger:
noise: a chime stone sounds when struck (slide into it, slam beside it,
land on its niche's lip) and its groove lights to the door; the right order
lights the mouth and the slab grinds up into the lintel in jerks (1.5 s,
dust, a hold, then up). A bell rung anywhere in earshot (bell spires) or
the dragon's roar counts as a strike on every chime at once: a wrong
answer. Wrong answer: the door *exhales*: a short gust from the mouth's
lips (the wind trap's shove, `air_at`) knocks back anyone in front of it.
Open holds for a time (knob, the fuse groove on the lintel), then the slab
drops with a slam (0.4 s) that is itself noise.
Size: the opening a walker's doorway (2 TOP_ROOM across, over WALL_HEIGHT)
or, flown, `WorldScale.opening(TOY_THREAD)`. Chime niches set at SET_OFF
steps up the jambs so striking the high ones is a climb (ledge grab, chain)
or a wall-kick off the opposite wall. The exhale throws the pilot about a
long jump (4.2) with a lift, so in front of a door over a gap it's a
knock-off, and in a corridor it's a dash.
Collision: the slab is one box hull, kinematic, its foot a lip the pilot
can stand on as it rises (it lifts him to the lintel, a ride up). The
mouth's lower lip is a ledge (GRAB_TOP over the threshold). The closing
slab never crushes: a pilot under it is pushed out the way he faces.
Motifs it enables:
- A maker tomb whose hall is behind the door: the card's order is the
  puzzle, the bell spires next door are the noise that spoils it.
- A door at the top of a stair where the exhale throws a wrong-answering
  pilot down the flights (comedy, a long way).
- A wind tunnel: two doors facing across a corridor, each exhale a gust
  you can ride across (the door as a tool you set off on purpose).
Threat pairing: the exhale as the trap, the falling slab as a timed
crossing; a speedrunner strikes a wrong chime on purpose to ride the gust
or rides the rising slab to the lintel and over the wall. Kin to the
inhaler head (it inhales, this exhales): the makers built breath into
their stone.
Catches / throws: the chimes catch any impact as a strike: a stunned body
thrown into a chime stone sounds it (a ragdoll can solve the door or ruin
it). The rising slab catches a standing body on its foot lip (a lift to
the lintel). The mouth's lower lip catches a grab. Throws in three ways.
**Exhale** (a wrong answer, a bell, a roar): a gust from the mouth, a
`knock` (source `chime_door`) about a long jump out with a lift, so it
stuns a standing pilot and re-throws a stunned one with fresh poise
(different source, so it chains straight off a ram or a seesaw). **Slab
lift**: the rising slab carries a body on its lip up to the lintel and,
at the jerk at the top, tosses it up a first jump's height over the wall
(`toss`, `chime_slab`). **Slab drop**: the closing slab pushes a body
under it out the way it faces (`toss`, a run's pace), and its slam is
noise. Aimed: the exhale points straight out of the door's face; the
generator aims it by placing the door.
Chains with: from the seesaw, logs, ram or inhaler head throwing a body
into the chimes; the bell spires and the dragon's roar (both sound every
chime at once); the slam of another door. To the wind vents (an exhale
aimed over a vent becomes a lift), a Sleeping Face (the slab's slam is the
noise that wakes it), a Weir Basin (the exhale throws a body into it), a
Rotten Bridge or seesaw on the exhale's line, and the gulf. Inhaler head
and chime door are breath-kin: an inhaler hovering in front of a door is
fed by its exhale.
**The chain:** a seesaw flings him tumbling into a chime stone. Wrong
order, so the door exhales and knocks him back across the court into the
Weir Basin, which ends his fall. The slam of the door closing wakes the
Sleeping Face on the cliff above. A route rider plays the same notes on
purpose: hit the wrong chime, ride the exhale across the gulf.
Build cost: med. The slab and wall are procedural; the mouth relief wants a
sculpted look (could be a carved panel from the Olmec head's Blender
source); the gust reuses trap_wind's push; chimes need hit detection on
slide/slam/landing and a sound bank (three to five pitched stone tones).
Model budget: sculpt high, bake low (the mouth relief: baked normal and AO
onto a flat slab, ~500 triangles instead of a 20k sculpt); parallax depth
(the relief's lips and grooves, so the slab stays flat geometry);
silhouette geometry on the slab's chipped edges; vertex-colour grime in the
niches. Est. ~3k triangles door plus wall; the bake saves ~15-20k
triangles over modelled relief, ~0.1 ms at distance.

---

# Sleeping Face (sleeper_face, family maker)
Verb: climb (asleep), ride (awake: its breath pulls and throws), stay
hidden (don't wake it).
Look: a colossal Olmec face carved into an isle's cliff or a maker wall,
the inhaler head's kin as terrain not enemy (the brief's twist): heavy
brow, flat nose, thick lips parted on a dark mouth, eyes shut under heavy
lids, the weathered basalt and its lit grooves. Asleep, roots and moss
drape the brow and lips; awake, the growth tears and falls as the lids
lift on the pale polished almond eyes that lock on (the inhaler head's eye
and its lock-on light).
Behaviour: changes state. Asleep / waking (the tell: 1.5-2 s, grooves
light from the chin up, dust sifts from the brow, a low hum, the lids
crack) / awake (inhaling or exhaling, 4-6 s) / settling (eyes droop, the
grooves drain, 2 s). Trigger: noise (a hard landing on its face, a slam,
a bell, a door's slam, a sounded trap within earshot: the pilot learns to
land softly), the dragon (its roar wakes every face on the isle), spend (a
rune in the font on its brow wakes it on purpose, and chooses inhale or
exhale by which eye's glyph you feed). Awake, the eyes track and it
inhales (a pull toward the mouth along the facing, `air_at` a wind sink)
or exhales (a gust and an updraft rising out of the mouth up the face).
Size: the face is 4-6 SET_OFFs tall (7-10); the brow, nose ridge, lips and
cheekbones are ledges SET_OFF apart, STAND deep, so asleep it is a
climbing route to the top. The mouth is a walker's doorway (2 TOP_ROOM by
over WALL_HEIGHT) into a short throat: a hiding place and a way through the
isle. The inhale pulls at about a run's pace within a long jump or two
(4-8) of the lips; the exhale's updraft is the flow charge's updraft, so a
sail out of the mouth climbs the face.
Collision: brow, nose, lip and cheek ledges are clean walk boxes on a
convex hull face; the cheeks are wall-kickable; the mouth floor walked.
Eyes and lids carry no collision (dressing). The face itself never moves:
only air, light and the falling growth change.
Motifs it enables:
- A maker shrine whose cliff is one face: climb it quietly to the brow, or
  wake it and ride the exhale up in one go.
- A gulf crossing toward a face: wake it with a slam on the far side and
  let the inhale pull your glide across (the threat as the only way
  across), then slip into the mouth.
- A ring of faces round a basin that wake in turn when the dragon passes,
  their breath crossing the court.
Threat pairing: the inhale drags a careless pilot off a ledge into the
mouth (the softer fail: the throat drops one layer down, a chute) or
across the air short of a landing; the exhale blows climbers off the
face. As a tool, both: a free pull over a gap, a free updraft up a wall,
and a lure (its pull drags enemies off narrow ledges into the gulf).
Catches / throws: inhaling, it catches everything in its breath: standing
bodies are dragged (a slide toward the mouth), airborne and tumbling ones
are pulled into the mouth and swallowed (held 0.6 s in the throat, the
eyes narrowing, a stunned body staying stunned). Gliding bodies are pulled
in on the sail. Asleep, it catches climbers like any wall. Throws in two
ways. **Spit**: a swallowed body is spat back out along the face's facing,
a hard `knock` (source `sleeper_face`), two long jumps' reach with a
rising arc, so it is a cannon. A stunned body leaves restunned with fresh
poise (a new source, so it chains straight off an inhaler head's spit).
**Exhale updraft**: up the face, the flow charge's updraft (`toss`
upward, plus the air it adds), which carries a stunned body up and drops
it on the brow. Or the **chute**: the throat's floor opens one layer down
if it swallows on its third breath (the softer fail). Aimed: yes, more
than any other piece. Its spit leaves along the face's facing, and its
eyes swing the spit up to 30 degrees toward what they're locked on.
So the generator points it at the next link, and a second face can be
placed in the arc: face to face, spat from one into the other.
Chains with: from the inhaler head (spat into its pull), the chime door's
slam and the weir's roar and any bell (wake it), the dragon (roar), the
seesaw and the ram (a body thrown into its breath). To another Sleeping
Face or an inhaler head (spit into the next mouth), the wind vents and
the pocket sail (the updraft), a Lit Span's plate or a Weir Basin's slam
plate (spit lands on it), Shy Root Lattice (a grown lattice catches the
spit as a net).
**The chain:** a hard landing on its brow wakes it; it inhales him off the
ledge, swallows, and spits him stunned across the gulf onto the Weir
Basin's slam plate. The basin drains under the rafts the next player
needed, or floods for the one who meant it: two faces aimed mouth to mouth
across a gulf make a cannon route a skilled player takes in one breath.
Build cost: high. A new model (the face as terrain: a sculpt in Blender,
baked, with lids as separate rigid parts) plus its collision ledges laid
by hand to the pilot's sizes; the breath reuses the wind trap and flow
charge air; eyes reuse the inhaler head's eye shader and lock-on.
Model budget: sculpt high, bake low (the face from a dense sculpt onto
~8-12k triangles, saving ~100k+); rigid parts on bones (the lids as rigid
meshes on two bones, no skinning); import LODs and visibility ranges
(a cliff-sized landmark: three LODs, ~2k at range, ~70% saving far away);
parallax depth (cracks and the grooves' cut); vertex-colour grime (the
Olmec's baked occlusion in vertex alpha, under the brow, in the mouth).
Est. frame-time saving ~0.2-0.4 ms on a layer with two faces in view.

---

## Notes across the five

- **Shared asks:** the circuit (source, groove path, sink, channel glyph,
  hold) as one small script both kit pieces and traps use; the buoyant
  carry (weir_basin) and a noise event bus (slam, landing impact,
  bell, door slam, dragon roar) that chime_door and sleeper_face listen
  to. The noise bus also lets existing pieces (bell spires, the sluice's
  rumble) speak the same language.
- **Chain asks:** plates and chimes count any body (the pilot stunned or
  not, enemies, blocks, rafts, thrown runes) by weight and impact, not by
  "is the pilot"; each piece knocks under its own source name
  (`weir_spill`, `weir_throat`, `weir_raft`, `roots`, `lit_span`,
  `chime_door`, `chime_slab`, `sleeper_face`) so the per-source
  `restun_gap` chains them with everything else; each throw that can be
  aimed exposes its facing to the generator, so it can point one link at
  the next and validate the landing as it validates a jump.
- **Family "maker":** all five are in the Olmec makers' own style, the
  brief's named style gap; they reuse olmec_stone.gdshader with `runes` on,
  so they sit beside the inhaler head and headless body by construction.
- **Ledger fit:** each piece is a natural home for a card row (a spent
  rune is a sink in the economy; a circuit's source is where the card's
  "do I stop for that?" lives), and each keeps a bare-handed route (dry
  climb, grown lattice, dark tiles, a wrong-answer gust, a quiet climb), so
  the validator's skip route always exists.
- **Cheapest first:** lit_span (low-med) proves the circuit and the fuse
  groove; shy_roots and weir_basin next; chime_door; sleeper_face last (a
  model).
