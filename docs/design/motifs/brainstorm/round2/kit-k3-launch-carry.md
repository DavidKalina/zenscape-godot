# K3: launch / carry (kit piece cards)

Lenses: verb = carry (move something, or yourself, across a gap); scale =
intimate; mood = quiet; shape among isles = spread wide.

Sizes are in pilot terms: PilotMotor constants as `set_size` fits them
(`run`, `walk`, `jumps[0]` the plain jump, `jumps[1]` the pump), RuinKit's
Scale section (`GRAB_TOP`, `CHAIN_TOP`, `STAND`, `STAIR_WIDTH`) and
WorldScale. "Long jump" is the running long jump's reach (LONG_SPEED over
its LONG_HEIGHT arc; the swing rope's header puts it near four of his body
heights). Any metres in brackets are only a reader's check at wanderer 1.

Proposed family for all four: `carry` (a new FAMILIES entry beside `horn`;
the name is the verb, not the motor's `carry()` call).

---

# Well Sweep (well_sweep, family carry)
Verb: carry (himself): hang from the sweep's seat and turn it round its post
to swing out over a gulf and set down, or let go, on the far side.
Look: a shadoof in ruin stone. A squat stone post with a forked head and a
stone trunnion pin; across it a long dressed beam, the long arm reaching
out over the gulf and the short arm ending in a woven-iron basket of
fieldstones (the counterweight) with a carved cup in its floor (a
`bearing_cradle` socket, below). From the long arm's tip hangs a short rope
to a stone seat bar, worn smooth where hands held it. Moss in the fork,
lichen on the beam's top, the basket rusted.
Behaviour: moves. Empty, the counterweight holds the long arm up and the
seat bar hangs at a plain jump's catch over the near rim. Caught (the swing
rope's catch: hands within reach of the bar, from any ordinary jump or a
walk off the rim into it), his weight eases the long arm down over about a
second until he hangs with his feet a pump under the rim's top (the rider
holds him as the rope's "swing" hang). Hanging, the stick along the arm's
tangent pumps the beam round its post (the rope's PUMP pattern: only while
it turns the stick's way), up to `run` at the seat, losing DAMP of its pace
a second; the beam turns at most 180 degrees from its rest heading to a
stone stop peg. Jump lets go (a toss, below); crouch drops off. Let go of,
the counterweight swings the empty arm slowly back up and round to rest
(about four seconds), so the sweep is always waiting on the side it was
built for. Ballasted (a bearing stone set in the basket's cup), the
counterweight wins against him: the arm rises as it turns, so at the far
end of its arc the seat stands a `CHAIN_TOP` higher than unballasted.
Size: post head (the pivot) at a `CHAIN_TOP` plus a `STAND` over its foot,
so the beam is out of a plain jump's reach and no ledge in it is caught by
accident. Long arm 1.5 long jumps from the pivot, so a half turn carries the
seat across three long jumps of gulf: a gap no unaided jump makes, and well
short of the swing rope's launch. Short arm a third of the long. Seat rope
a body height. The basket's floor a `STAND` over the rim at rest, so he can
reach in to set a stone without a jump.
Collision: post a clean cylinder hull, taller than WALL_TALL, wall-kickable.
Beam a narrow clean box along its top (walkable as the balustrade's coping
is, nothing holding him there; at rest it is pitched up past SLIDE_AUTO, so
it is only walked once ballasted and level). Basket a box hull (a step
onto its rim, not a ledge: its lip sits under GRAB_LOW of a catch). Seat
bar and rope: no collision, caught by the rider's reach only. The beam and
basket are `moving_ground` bodies (pilot_physics_ground.gd `mover`). The
plane bumps the post and beam (ruin_bump.gd: a slab, never a crash).
Motifs it enables:
- A string of small stone isles spread wide, each with one sweep on its far
  rim: island-hopping by hanging, turning and letting go, one quiet swing
  at a time.
- A cliff garden where a sweep lifts him only once he has carried a stone up
  from the shore to its basket.
- A well-court on a single isle where the sweep is just a well: dressing,
  until the gulf behind it is noticed.
Catches / throws:
- Standing: the basket on the short arm sweeping round at more than `walk`
  meets a standing body with a `toss` at the basket's own pace along its
  tangent, a hop up (`jumps[0]`'s take-off), source "well_sweep_weight":
  a nudge, never a knock or a stun.
- Airborne: catches him by the seat bar (the swing rope's CATCH and
  CATCH_BODY), as the rope does, his pace across the arm turned into the
  beam's turn at once.
- Tumbling/stunned: a stunned body meeting the bar is snagged as the rope
  snags it: it rides still stunned (move "tumble"), the twirl arming the
  tech, until the sweep gives his poise back (`regain`) at the end of the
  turn or the peg throws him on (below), still stunned.
- Riding: Jump lets go with the seat's velocity (up to `run` along the
  tangent) and a plain jump's take-off up; no timing boost (it is a carry,
  not a launch); twirl, wall run and sail fresh after it. Reaching the stop
  peg at over `walk`, the beam knocks on it and he is thrown on: `toss` at
  0.8 of the seat's pace along the tangent and a plain jump's take-off up,
  source "well_sweep" (stunned riders thrown on as a body). Under `walk` it
  stops and he hangs, to drop off or let go at leisure.
Build cost: med. Procedural from RuinKit.Build (post courses, beam,
trunnion, basket bars) like the wind horn's pedestal and head; the rider
reuses swing_rope.gd's catch, hang and pump with a yaw-only beam in place
of the pendulum; the weight/counterweight balance is a one-axis spring like
the seesaw's tilt. No Blender model, no physics engine bodies.
Model budget: silhouette geometry (chips on the beam's ends and the post's
fork; flat faces textured), vertex-colour grime in the fork and under the
basket, import LODs and visibility ranges (spread-wide isles see each
other's sweeps from far off: a far copy is post + beam boxes only, about
90% of its triangles saved past mid range, a few hundred tris each).
Parallax depth not needed. Est. 3-5k tris near, under 0.05 ms per copy.

---

# Haul Ferry (haul_ferry, family carry)
Verb: carry (himself): stand on a floating stone deck and haul it hand over
hand along a rope strung between two isles; or haul the empty deck to him
from the bank.
Look: a flat floating slab (the foot slabs' stone and its sag) with a
knee-high worn kerb, and amidships two stone thole posts with a groove worn
in each where the rope runs through. The rope runs from a stone bollard on
one isle's rim (a squat post with an iron ring, a rope coiled at its foot)
to another's, sagging a little over the gulf. Mooring stones at each end:
a cut notch in the rim where the deck docks.
Behaviour: moves; driven by him. On the deck at the thole posts, the stick
into the rope takes hold of it (hold "haul": feet kept at the posts, the
rider's), and the stick along the rope's line hauls the deck along it up to
`walk`, easing up over about half a second; let go, it coasts and drags to
a stop (a long, quiet glide of several long jumps from `walk`). With the
bollards at different heights the rope slopes and the deck is a gravity
tram: unhauled it runs down toward the low bollard, gaining as his surf
gains on a slope but capped at `run`; hauling against it brakes it; hauling
uphill goes at `walk` times SLOPE_SLOWEST at the steepest allowed. Within a
long jump of either dock it eases to a stand at the notch whatever its
pace, so arriving never flings him. From the bank, standing at a bollard
with the stick into its ring, the same haul draws the empty deck along the
rope toward him at `walk`, so a deck left on the far side is never lost.
Size: deck square, a second of his `run` each way (about four of his body
heights), so a knock on it has room to land. Kerb under STEP_UP (stepped
over to board, not a wall; knob `rails` stands a waist-high balustrade on
the two long sides). Rope at his hands' height hauling (the shoulders'
share of his body over the deck). Span 3 to 12 long jumps (knob): long and
slow on purpose; at 12 a crossing from `walk` takes about half a minute.
Rope slope under SLOPE_SLOW, so the tram never runs faster than his `run`.
Deck top level with the dock notch's floor to within a step (STEP_UP).
Collision: deck a clean box (moving_ground, carried by
pilot_physics_ground.gd `mover`, his frame_v kept when he jumps off it);
kerb a thin box under STEP_UP; thole posts cylinders under WALL_TALL (not
kicked); bollards cylinders a plain jump tall (stood on). The rope: no
collision for him (taken only by the haul's reach) and none for the plane:
flown through, it twangs and shudders (the rope bridge sim's shake), never
a bump.
Motifs it enables:
- Two quiet isles a long way apart, a ferry the only foot way across, the
  crossing a long look at the gulf with nothing to do but haul.
- A chain of ferries spread wide, each rope a different slope, so one leg is
  hauled and the next runs down on its own.
- A ferry crossing past a wind horn on a third isle: a gust across the deck
  mid-crossing, the rails knob the difference between a stumble and a sail.
Catches / throws:
- Standing: carried as any moving ground (`carry`), his own run over it.
- Airborne: landing on the deck takes up its motion at once, his pace kept
  (the motor's moving ground: no fling from the difference).
- Tumbling/stunned: a stunned body landing on it is carried, laid down on
  the deck as on any ground; it slides to a stop on TUMBLE_SKID and the kerb
  does not stop it (a fast knock carries over the edge, unless `rails`).
- Riding (hold "haul"): Jump lets go as a plain jump from moving ground (the
  deck's pace kept as his frame); a knock clears the hold as any rider.
- Throws: nothing of its own. The ease at the docks is its contract: no
  toss, no knock, no source.
Build cost: med. Deck reuses foot_slab.gd's look and sag and drift_slab.gd's
carrying along a path (here a path the haul drives, not a clock); the rope
is the rope bridge's shader-swayed line (or a simple catenary); new code is
the "haul" hold (a rider on a mover) and the bank haul at the bollard.
Procedural, no Blender model.
Model budget: vertex-colour grime (rope grooves, kerb foot), silhouette
geometry (deck edge chips only), import LODs and visibility ranges (the far
dock seen across 12 long jumps of gulf: deck and bollards as boxes past mid
range; the rope a single strip at any range). Est. 1.5-2.5k tris near; the
far copy about 80% fewer; negligible frame time.

---

# Bearing Stone (bearing_stone, family carry; with bearing_cradle)
Verb: carry (a thing): pick up a carved stone ball, carry it in both arms,
set it in a cradle or lob it across a gap he can't jump with it in hand.
Look: a ball of dressed stone with one carved band round it (a worn groove
and a ring of small cups), heavy-looking, darker where hands have held it.
Its home is a `bearing_cradle`: a short stone plinth with a cupped top,
the cup's lip worn on one side. Cradles also stand where a stone is wanted
(the well sweep's basket floor is one; a socket in a floor or a tomb
chest's lid is another), each with the same cup, so any stone fits any
cradle.
Behaviour: changes state, and is carried. Crouch pressed at a stand beside
a stone (within GRAB_REACH, facing it within GRAB_FACING) lifts it (half a
second, a squat and a lift, held at the chest: hold "carry"). Carrying, he
moves at 0.7 of his `run` and turns at TURN_RUN; jumps only the plain jump
(`jumps[0]`, no pump, no long jump), and no twirl, sail, wall kick, wall
run, ledge catch, slide or slam; a ledge stepped off he falls with it. So a
stone goes where steps and short hops go: its route is the stairs. Crouch
again sets it down in front (or in a cradle within GRAB_REACH, which takes
it: it settles into the cup with a soft knock and the cradle's "seated"
signal goes). Twirl pressed carrying lobs it two-handed: off his chest at
his `run` forward and a pump's take-off up, falling on his own GRAVITY
(its gravity scaled to match), so it lands about three quarters of a long
jump out, rolls a little, and a cradle in reach of where it lands takes it.
Dropped into the void, it is lost for a beat and then rises slowly out of
its home cradle's cup again.
Size: diameter his hips' height (about four tenths of his body height): big
enough to need both arms, small enough to read as carried, not pushed.
Cradle top a `STAND` over its foot plus the cup (he sets it at the chest
without bending); cup diameter the stone's plus a hand. Cradle plinth under
`jumps[0]`, so he can hop up on one.
Collision: stone a sphere hull on a RigidBody3D (collision layer of the
seesaw's `loads`, so the seesaw flings it), walkable as a round top but
never a ledge (no lip with a stand-on top). Cradle a clean box hull with a
cylinder cup; its top is walked. The plane does not collide with a stone
(below the bump's interest), only with cradles.
Motifs it enables:
- A small garden isle of empty cradles, its stones scattered over three
  neighbouring isles: carry them home one by one, the short way round
  because a stone in hand makes every gap a stair.
- A seesaw across a gulf: stand on the low end and lob the stone onto the
  high end; the stone's fall is the seesaw's `impact` and he is thrown
  across.
- A ballast puzzle: the well sweep that won't lift him until its basket
  holds a stone, the stone at the cliff's foot.
Catches / throws:
- The stone, met: a stone moving over `walk` (lobbed, rolling, flung by a
  seesaw) meets a standing or airborne pilot with a `toss` along its way at
  half its pace and a plain jump's take-off up, source "bearing_stone":
  never a knock, never a stun. Under `walk` it is only in the way.
- Carrying, knocked: the stone drops (it keeps half his velocity at the
  blow) and he tumbles as ever; a stunned body can't lift a stone.
- Carrying, tossed (a sweep's weight, a seesaw): he keeps the stone; the
  toss's airtime has no sail, so a toss over a gulf with a stone is a fall.
- Thrown things: the stone is a load for the seesaw (`loads`; its fall on
  the high end is `impact(arm, speed)`), weight for the sweep's basket, and
  (with the engine gap below) weight on sink and bob slabs.
- Output of a cradle: a "seated"/"emptied" signal and `seated` state, for
  any piece that reads weight.
Build cost: med. Stone and cradle are tiny procedural meshes (a carved
sphere and a lathe, RuinKit stone); the cost is the motor's new hold
"carry" (move limits, pick, set, lob, drop on knock), a figure pose for it
(Blender clips: lift with anticipation and a settle, a carry walk with the
weight in the hips, a two-handed lob with follow-through, a set-down) and
the home-cradle respawn. The clips are the expensive part.
Model budget: sculpt high, bake low for the stone only (it is seen at arm's
length: a 1-2k tri ball with the band baked from a dense sculpt, against a
10k+ tri modelled band, about 85% saved); vertex-colour grime in the cup;
import LODs (a 200-tri ball past near range). The cradle: silhouette chips
on its rim. Negligible frame time; one RigidBody3D sleeping per stone.

---

# Flue Well (flue_well, family carry)
Verb: carry (himself, and the plane): stand on the grate of an old well
whose breath rises warm out of the isle, be lifted, and sail up it; fly the
plane through its column for height. Launches gently.
Look: a round well-head of stone courses, waist high, a fallen lid slab
leaning on one side, an iron grate over the mouth with two bars missing.
Out of it, faint: dust and seed fluff rising and turning in a slow spiral
(sky_currents' painterly strokes, a few of them), the air over it
shimmering. Ferns at the foot where the warm air keeps them green.
Behaviour: launches; steady or tidal (knob `breath`). The well's column is
a placed thermal: in it the pocket sail climbs (the sail's own thermal
rule, up to THERMAL_MOST), so he opens the sail over the grate and rises.
Tidal, it breathes on a slow cycle (about eight seconds: a gathering hush,
a long rise, a still): the start of each rise is a puff that tosses
whatever stands on the grate up (below), enough for the sail to open; the
still is a few seconds with no lift at all. Steady, there is no puff: he
jumps from the grate and opens the sail. A bearing stone set in the cup on
the well-head's rim (a `bearing_cradle`) stops the breath (the cap): its
twin flue on another isle (knob `twin`) breathes double for as long as it
stays, so the way up moves to the other isle.
Size: mouth (the grate) a STAIR_WIDTH across, the well-head's ring wall
under `jumps[0]` tall and a body wide on top (hopped onto and walked round).
The column's radius at the grate is the mouth's plus a half sail turn, and
it widens with height to at least `WorldScale.opening(TOY_THREAD)` across
at its top so the plane, flown straight through, gets lift for a moment.
Column height (knob) 8 to 16 pumps over the grate for the sail (it fades
over its top quarter), and on to twice that, weaker, for the plane: from
the low isle to a spread-wide isle's rim and over.
Collision: ring wall a clean cylinder hull (walkable top, under WALL_TALL,
not kicked); grate a clean box, walkable (no hole: he can't fall into the
shaft); lid slab a leaning box (a ramp, under SLIDE_AUTO). The column has
no collision: it is air (`air` at a point: {wind, thermal}). The plane
bumps the well-head only.
Motifs it enables:
- Isles spread wide at different heights, the high ones reached on foot
  only by riding a flue's column up and sailing across to them.
- A quiet hollow where the well is the only sound, and the way out is up.
- A pair of flues on two isles, one capped: carry the stone from one well's
  rim to the other's to choose which isle the air lifts you to.
Catches / throws:
- Standing on the grate at the puff (tidal): `toss` straight up at a pump's
  take-off speed (`jumps[1]`), no flat pace, source "flue_well", a fresh
  airtime (the sail opens from it). Once a breath.
- Airborne, sail open in the column: lifted by the thermal, no toss.
  Airborne without the sail: nothing (the column only lifts the sail).
- Tumbling/stunned: on the grate at the puff, thrown up still stunned (a
  toss on a tumble throws the body); poise comes back in the air and the
  sail is his again, so the stun over a flue is a delay, not a fall.
- Riding (a rope, a sweep): untouched.
- The plane: in the column it gets the thermal's lift (sky_plane.gd reads
  `thermal` from its air), a gentle climb, no shove.
- A bearing stone on the grate at the puff is tossed up the same way and
  falls back to the grate (it can't be lost down the shaft).
Build cost: low-med. The well-head is procedural RuinKit.Build courses (the
wind horn pedestal's octagon made round) with a grate of bars; the column
reuses the sail's existing thermal and the sky's ribbon strokes. New code:
a placed thermal the on-foot sail on the kit isle reads (engine gap, below),
the tidal puff, and the cap/twin link (a signal from the cradle).
Model budget: vertex-colour grime (soot inside the mouth, damp at the
foot), silhouette geometry (the broken bars, the lid's chipped edge),
parallax depth for the shaft's dark inside under the grate (a fake depth
in place of modelled courses down the shaft: a few hundred tris saved and a
deep look), import LODs and visibility ranges (the column's strokes thinned
with distance; seen from other isles it is the waymark, so the strokes stay
longest). Est. 1.5-3k tris near; strokes cost as one ribbon set.

---

## Combines with

- well_sweep: `bearing_stone` (its basket's ballast), `floor` and
  `stone_circle` (the rim court it stands on), `fallen_pier` (a toppled
  pier as a far landing), rope bridges and `bridge_anchor` (the way back),
  `trap_seesaw` (the weight's toss and the seesaw's launch on one rim).
- haul_ferry: `aqueduct_stump` and `aqueduct_end` (dock heads and bollards
  in the same stone), `bridge_anchor` (bollard style), `wind_horn` (a gust
  across the deck mid-crossing), foot slabs (`drift_slab` beside it as the
  hard way across), `slab_bridge` at the docks.
- bearing_stone: `trap_seesaw` (`loads`, `impact`), `well_sweep`,
  `tomb_chest` (a cradle cut in its lid), `stone_circle` (a cradle at each
  sarsen), `sink_slab` and `bob_slab` (weight, with the gap below),
  `grand_stair` and `stairs` (its routes), `flue_well` (the cap).
- flue_well: `wind_horn` (a horn knock into the column, poise back, sail
  up), `tower_shell` (a flue inside the shell: the tower as a chimney),
  `hall_bay` (a flue under a broken roof), cloister `pavilion`, `bearing_stone`.

## Engine gaps found

- No carried-object state in PilotMotor: a hold "carry" (pace cap, the move
  limits above, pick, set, lob, drop on a knock) and its figure clips. There
  is no interact button either; the cards overload crouch pressed at a
  stand near a stone (crouch at a stand is now only CROUCH_BRAKE) and the
  twirl while carrying.
- A rider on moving ground: the sweep's seat turns on a moving beam and the
  ferry's "haul" holds him on a moving deck. `rider` and `mover` exist
  apart; the ride must own his feet while the deck or beam carries him,
  and his frame_v must come from the body when he lets go.
- Placed thermals for the on-foot sail: the pocket sail reads `thermal`
  from the motor's `air`, and sky_currents has `add_thermal` for the
  glide/plane, but I found no kit-isle hook that hands a piece's column to
  the walker's `air`. To check before the flue is built.
- Weight on foot slabs: seesaw reads RigidBody3D `loads`; bob, sink and
  drift slabs read only the pilot standing. A shared "weight on" contract
  (the pilot, a stone in a cradle, a stone resting) would let one stone sink
  a sink slab into a lift.
- Thrown props fall on project gravity, not the pilot's GRAVITY: a lobbed
  stone needs its gravity scaled so its arc reads in his jump's terms.
- Thin lines and the plane: the ferry rope wants a "twang, no bump" answer
  from the plane (ruin_bump.gd only knows stone slabs).
- Optional, not asked by any card: plane cargo (a bearing stone carried
  from isle to isle in the plane) would make the spread-wide carry a flight.
