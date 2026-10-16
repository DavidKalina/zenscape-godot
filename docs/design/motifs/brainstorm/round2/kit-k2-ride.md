Round 2, kit k2: moving pieces you ride. Lenses: verb ride; scale human; mood
playful; shape among isles a line. Four pieces, all aqueduct or hall, so a
line of isles strung on an aqueduct run can carry the player along it. Every
number below comes from the pilot (scripts/pilot_motor.gd), RuinKit's Scale
section (GRAB_TOP, CHAIN_TOP, STAND, TOP_ROOM, SET_OFF), the aqueduct's
module (scripts/ruin_kit_aqueduct.gd: CLEAR, SPAN, SPRING, DECK, CHANNEL,
PARAPET) or WorldScale. A figure "at the defaults" is a reading, not a
constant to copy.

Not repeated here: bob, drift (path and spin), sink slabs; swing ropes and
the grapnel line; live rope bridges; the balustrade slide; the seesaw, flip,
logs and tumble block; the haul-way's hawser sledges; the sky ray, the rune
serpent and the airship ferry. Round 1 asked for a tippable plate and rope
bridges on moving ends; neither is proposed again.

# Noria (noria, family aqueduct)
Verb: ride up (board at the foot, ride a cradle round, get poured out at the
top), or climb it faster than it turns, cradle to cradle.
Look: a great timber water wheel stood in a pool at an aqueduct pier's foot,
iron-strapped, black with wet, moss on its lower half; clay-and-stone
cradles (squat troughs) hung level on pins round its rim, outboard of the
wheel's face like a ferris wheel's cars, each dripping as it climbs. At the
top a stone lip juts from the channel's side: the pour trough the cradles
empty into.
Behaviour: moves on its own clock. Turned by the water (rim pace a share of
WALK, about 1 m/s at the defaults, so a ride from the pool to the top
takes about 20 s); faster while a sluice upstream runs
(it listens to `trap_sluice` if one is wired; else steady). Each cradle stays
level by its pin, swinging a little (a damped pendulum, the lag of the
wheel's turn) and sagging and tipping toward him as a FootSlab does. Just
past the top a cam trips its latch: the tell is a clack and a lurch (a
quarter second), then it tips over its lip toward the pour trough, past
SLIDE_AUTO, slowly enough to read (about half a second), and rights itself
on the way down.
Size: diameter from the pool's floor to the deck: the top cradle's floor a
STEP_UP over the channel floor (DECK), so a full noria serves an aqueduct
span's height (about 13 m at the defaults). `rise` knob: a shorter wheel
reaching the two-tier span's gallery course (MID) instead. Cradles: as many
as keep the rim spacing a margin under CHAIN_TOP (ceil(pi x diameter /
(CHAIN_TOP - 0.3))): on the wheel's climbing side the next cradle's lip is
always a pump's catch above the one he stands in, so a player who chains
jumps climbs it about twice as fast as it turns. A cradle's floor is TOP_ROOM
by STAND x 2, its lips under STEP_UP (stepped into and out of, not a wall).
Collision: each cradle a clean box floor plus four low lip boxes, an
AnimatableBody3D marked moving ground (PhysicsGround.mark_moving), each on
its own node so the motor's `mover` hands back the cradle he stands in. The
hub is a cylinder, a wall to him (too round to stand on). The wheel's face is
one convex disc hull behind the cradles: wall-slid and wall-kicked (a
kick off it pops him back out to the cradle he slid past). Spokes have no
collision. The pour trough is a static floor at deck height.
Motifs it enables:
- A run of aqueduct spans along a line of isles whose deck is only reached
  by the noria at each isle's pool: ride up, get poured into the channel,
  walk the channel to the next isle's break, drop, ride again.
- A noria climb race: a collectible on the top cradle that the turn would
  take away before you ride up to it, so you chain cradle lips to beat it.
- A cradle you can't reach from the pool because the pool is under a
  broken span: you ledge-hang from the snapped channel's end and drop into
  a passing cradle.
Catches / throws: standing in a cradle: carried by its full move (rim
velocity plus its pendulum sway as `platform_v`); jumped out of on the
rising side, its rise goes with him (up to foot_pieces' RISE_KEEP). At the
pour: a standing body surfs out down the tipped floor by the motor's own
slope rule (move "slide", toward the pour trough at the surf's pace,
landing a step down onto the channel floor). Airborne: a body landing in a
cradle is caught by its lips (a hard landing kicks the cradle down and
swings it, FootSlab's GIVE). Hanging from a cradle's lip: carried as from
any moving lip, so a hang on the rising side lifts him (he can climb in at
any point). Stunned or tumbling: a body that lands in a cradle rides in it
limp, stays stunned (no restun: the noria has no `knock`), and at the pour
is thrown on with `toss` (pour trough-ward, about WALK out, a plain jump's
rise up; source "noria"), so a knocked-off player is carried back up and
dropped at the top, not lost. Falling off the descending side into the
pool: deep water, no fall stun.
Build cost: med. One Blender model (wheel, strap, one cradle mesh
instanced), a script that turns the wheel and keeps each cradle level
(AnimatableBody3D per cradle, a few lines like haulway_sledge.gd's), the
pour as a scripted tilt of the same body. No new physics: the motor's mover
and slope rules do the carrying and the pour.
Model budget: rigid parts on bones (cradles, straps and pins as separate
meshes on the wheel's rotating node, never skinned); import LODs and a
visibility range (the far side of a line of norias shows only the wheel's
silhouette); silhouette geometry on the rim (broken paddles) with flat
faces textured; vertex-colour grime for the wet low half. Est. 6-9k tris a
wheel with 16 cradles instanced; LODs save about half past 60 m.

# Channel Float (channel_float, family aqueduct)
Verb: ride along (stand on it as the channel's current carries it down an
aqueduct run; jump off before the break, or ride it over).
Look: a hollowed half-log (a ruin's old punt or a timber trough, grey and
split, a bronze ring at its nose) sitting in the channel, its sides just
inside the parapets, water slapping at its stern; a sluice-like head gate
at the aqueduct_end that lets one go every so often.
Behaviour: moves on its own clock. The head gate releases a float every
`every` s (a knob; the gate's wooden flap thumps as the tell); it runs down
the channel's "walk" metadata at the current's pace (a share of RUN, about
WALK x 1.2 at the defaults, so a running player overtakes it and a walking
one falls behind), easing round a run's bends, bobbing a little and
sagging, tipping toward him under his weight on a stiffer spring than a
bob slab's. A low obstacle in the channel (a fallen voussoir, a hall_beam
across it at head height) is a beat: duck (crouch) or hop it. At a broken
span's snapped end it noses over the spill and drops with the water into
the pool below, then sinks out of sight and is gone (the next one comes).
Where a run is dry past a break, it grounds and stops at the dry channel
(a resting place, still standable).
Size: its width CHANNEL less a body each side (so it rides inside the
parapets, never clipping), its length three TOP_ROOMs (room for a run up
on it and a jump off the nose), its deck under STEP_UP over the channel
floor and under the parapet (so he steps onto it from the channel or from
a parapet, and off again). A break meant to be jumped from it: wider than a
running long jump on still ground (LONG_SPEED's reach) and under the same
long jump with the float's pace added for its airtime, so only the ride
makes it; the snapped end's lip is a hang (CHAIN_TOP under the far deck's
channel top at most) so a short jump still catches it.
Collision: the deck a clean box; its gunwales low boxes (under STEP_UP, not
walls); an AnimatableBody3D marked moving ground, moved each physics frame.
Not wall-kickable. The channel and parapets are the aqueduct's own.
Motifs it enables:
- A line of isles linked only by one long aqueduct: you ride floats down
  it, hopping off each before the break and onto the next span's float
  that the next head releases on its own clock.
- Ride it over on purpose: go with the float down the spill into the
  pool under the break, the quick way down to the lower isle.
- A channel threat run: a beam to duck, then a tumble block or wind blaster
  sweeping the deck, and the float the only footing that moves you on.
Catches / throws: standing: carried at the current's pace (`platform_v`
along the channel), so a jump off it carries that pace as `frame_v`; a long
jump from a run along the deck (crouch, Jump) leaves at his long jump plus
the float's pace. Landing on it airborne takes up its motion at once (no
fling). Stunned or tumbling: a body washed into the channel (the sluice's
wave) or knocked onto the float rides it limp; at the spill it is thrown on
with `toss` (the float's pace forward, down the fall, still stunned; source
"float") into the pool, which is deep: no fall stun, he swims out. The
float itself never knocks.
Build cost: low-med. One small Blender model (or procedural: a split
cylinder), a script that walks a body along the run's "walk" path at a
pace and noses it over the spill (an extension of drift_slab.gd's path
walker with a one-way end), and the head gate's release clock. The spill's
drop is a scripted pitch and fall of the body.
Model budget: silhouette geometry (the split and the broken stern on the
outline, the grain in the texture); vertex-colour grime (wet line, moss at
the waterline); import LODs. Est. 600-900 tris a float; with three in a
run and a visibility range, negligible frame time.

# Arch Swing (arch_swing, family aqueduct)
Verb: ride and pump (stand on a hung board, pump it higher with crouch,
leap from it to the next arch's swing or off its high end).
Look: a wide stone board (a broken tomb lid, chamfered, its face worn) hung
by two iron chains from an aqueduct arch's crown, swinging along the run
under the arches; ivy trailing off the chains, a rust stain where they
meet the board. A line of them hangs under a run, one an arch.
Behaviour: moved by the pilot's weight, with a little clock of its own. A
breeze rocks each swing to a third of its most (so a still board never
waits dead), and successive swings are set half a swing apart. Pumped
like a playground swing stood on: crouch held through the ends (the high
points) and stood up through the bottom adds to the swing; crouch held at
the wrong time takes from it. Each good pump adds a share up to the
most. Let off (stood still), it settles back to the breeze's rock over a
few swings. A hard landing on it kicks it (FootSlab's GIVE, along the
swing).
Size: chains from the crown (SPRING plus CLEAR's rise) to a board whose top
hangs SET_OFF over the arch's floor at the bottom of the swing (about
9-10 m of chain at the defaults: a slow swing, about 4.5 s there and
back). The board: TOP_ROOM x 2 along the run by STAIR_WIDTH across. The
swing's most keeps the board's far edge a body (BODY) clear of each pier,
so at its top the board stands a pier's width (PIER.x) and two bodies from
the next swing's board at its near top: a plain jump. At the bottom its pace
is about RUN; jumping off forward there carries it as `frame_v`, and a
long jump off the board at the bottom goes the reach of a running long jump
and its pace again.
Collision: the board a clean box (walked, slid along, crouched on), moving
ground on its own node. Its edge is a lip: a pilot who falls short catches
it (GRAB_TOP from the floor at the swing's bottom: one jump) and hangs from
it as it swings, then climbs on. Chains have no collision (no rope catch;
that's swing_rope's). Not wall-kickable.
Motifs it enables:
- A line of arches with the deck long gone: the swings are the only way
  along under the channel, handed one to the next by timing their highs.
- An aqueduct spanning a gulf between two isles in a line, its middle
  arches fallen: pump the last swing high and leap off its far top to the
  far isle's broken span, sail the rest.
- A playful timing toy at a hub: four swings in a row set off by the
  breeze, a coin on each board's underside reached from the hang.
Catches / throws: standing: carried by the board's full move (`platform_v`
along its arc, rising at each end), so a jump timed at the rising end goes
higher (rise kept up to RISE_KEEP) and one at the bottom goes further.
Crouched at a stand he stays put on it (CROUCH_BRAKE); sliding onto it at a
run he slides along it and off its end with its pace added. Airborne:
lands on it and takes up its motion; a hand under its lip catches it.
Hanging: carried with it, so a hang becomes a short ride and a drop at the
top of the swing is a launch. Stunned or tumbling: a limp body landing on it
slides by TUMBLE_SKID on the tilted pace and usually rides; past half its
most a tumbling body slides off its high end and is thrown with the board's
pace (a `toss`, source "arch_swing", still stunned). It never knocks.
Build cost: low-med. Board and chains are procedural (a RuinKit slab and
chain links instanced); a pendulum script with a pump rule read off the
motor's `crouch` and his place on the board; moving ground as the drift
slab is.
Model budget: silhouette geometry (chipped board ends); chain links as one
instanced mesh (MultiMesh), not modelled per link; vertex-colour grime
(rust under the chain plates). Est. 300 tris a board, 40 a link x 24 a
chain; negligible.

# Rolling Drum (hall_drum_roll, family hall)
Verb: ride and steer (stand on a fallen column drum and run on it to roll
it along a causeway, the way a circus ball goes: run against the way you
want it to go; leave it where you want a step).
Look: one colossus column drum (the hall's fluted stone, a broken arris,
lichen in the flutes) lying on its side on a paved causeway with raised
kerbs, a groove worn in the paving where it has rolled before.
Behaviour: moved by the pilot's weight. Standing on its top, his own pace
over its surface spins it: the drum rolls the other way at the pace he runs
on it (it lags, heavy: about a second to come up to speed), and he goes
with it. Stood still on it, it coasts, slowing on the paving, and carries
him off its top the way it rolls. On a slope it runs downhill on its own
(gravity on the drum, his run fighting or helping). It stops dead against a
kerb or a wall (a thump and a dust puff), pitching what stands on it on
at its pace. Left anywhere, it stays (a step he placed).
Size: radius the hall's COLUMN_R, so its top stands between GRAB_TOP and
CHAIN_TOP over the paving: one pump catches it, a plain jump doesn't, but
stood on it a ledge GRAB_TOP over its top is caught (a step he steers to a
wall, about SET_OFF short of a lip two climbs up). Its length TOP_ROOM x 2
(room to run across its top, side to side, but not to stand two wide). The
causeway: its clear width the drum's length plus a body either side, kerbs
under STEP_UP (not walls to him, walls to the drum). Top pace: RUN at his
full run on it; downhill, capped near LONG_SPEED.
Collision: a convex cylinder hull (24 sides) of moving ground on a 1-D
track (scripted, not a RigidBody: its place along the causeway and its
spin from his pace and the slope). The rounded top is a slope: standing
off its crown he is on ground steeper than SLOPE_SLOW, off-centre past
SLIDE_AUTO he surfs off, so keeping his feet near the top is the skill. Its
round ends are wall-slid and wall-kicked as any wall.
Motifs it enables:
- A causeway along a line of isles where the gaps are ash or shallow water
  (soft ground, a wade): the drum rolls you over them at a run where
  walking is slow.
- Steer the drum under a cliff lip two climbs high and climb off it; the
  isle's next tier is reached only from where you leave it.
- A downhill drum run ending at a kerb by the rim: it stops dead and pitches
  you on at its pace, a launch to the next isle's lip.
Catches / throws: standing on top: carried by the drum's roll (the contact
point's pace, so `platform_v` is the surface's: twice the drum's at its
crown when coasting, the motor's slide taking him off), his own run over it
driving it. Airborne: lands on it and takes up its surface motion (running
on it at once keeps him up). Standing in its way: a rolling drum over a
walking pace knocks him (`knock`, along its way at its pace, up a hop,
source "drum"; restun held off by the source gap) and a slower one shoves him
(`toss` along). Stunned or tumbling: a body on it is carried off its top the
way it rolls and dropped behind it; one in its way is tossed on, never run
over twice (the source lock). At a kerb's dead stop, a standing body is
thrown on with its pace kept as `frame_v`; a stunned one with `toss`.
Build cost: med. The drum mesh exists (the hall's column drum); new is a
script that rolls it on a track from his pace over it and the slope, the
dead stop, and the knock. The carry is the logs trap's (motor.carry with the
roll's delta, his facing not pitched). Tuning the "run against it" feel is
the risk: plan a playable yard round for it.
Model budget: reuse the hall drum's mesh and LODs; parallax depth for the
flutes rather than geometry; vertex-colour grime in the flutes. No new
triangles.

Combines with:
- noria: `aqueduct_span`, `aqueduct_two_tier` (MID as the short wheel's
  top), `aqueduct_broken` (its pool at the pier's foot), `aqueduct_end`;
  `trap_sluice` (spins it faster); swing ropes off a hall_beam beside it
  for a leap from the top cradle.
- channel_float: `aqueduct_end` (the head gate), `aqueduct_span` runs,
  `aqueduct_broken` (the spill it rides over), `hall_beam` or a fallen
  voussoir across the channel (duck it), `trap_tumble` or the wind blaster
  over the deck; bob slabs in the spill's pool.
- arch_swing: `aqueduct_span` and `aqueduct_two_tier` arches, `aqueduct_broken`
  (deck gone, arches standing), `aqueduct_stump` (the pier it lands short
  of), the pocket sail off its last high; floating stones past the last arch.
- hall_drum_roll: `hall_column` (its source), `floor` slabs as the causeway,
  `hall_slab` kerbs, `wall` and `buttress` as the lips it is steered under,
  `fallen_pier` as a kerb; soft ground (ash) and a shallow wade to cross.

Engine gaps found:
- Moving pieces aren't RuinKit pieces. The kit's contract is Mesh + Body,
  static; the foot pieces are built by scripts/interactables/foot_pieces.gd,
  not placed by id. The motif editor can't place any of these four until the
  kit (or the editor) has a "live" piece kind that hands its node to a
  stepper (foot_pieces or the trap field).
- Two carry paths. foot_pieces carries slabs with `motor.carry`; the
  haul-way and serpent use the motor's `mover` with moving-ground bodies.
  Each piece here should pick the `mover` path (moving ground marked on its
  body), but RISE_KEEP (the rise kept leaving a slab) lives only in
  foot_pieces: off `mover` ground the motor keeps all of the rise. Decide
  one.
- A tipped moving floor (the noria's pour) relies on the motor reading
  slope off a moving collider's tilt (`_gradient` via the physics ground
  rays): unchecked; the flip trap throws instead of letting him surf.
- Crouch-pumping (arch_swing) needs the piece to read the motor's `crouch`
  and his place on the board each frame; nothing does that today (the rope's
  pump reads the stick through `rider`, and a board isn't a rider).
- A drum's carry about a horizontal axis must move his feet without pitching
  him (the logs trap handles this; the generic `carry` takes only a yaw
  turn: check it accepts a pitch in `by`).
- Water has no current. The channel's water is a crafted shader 0.16 m deep;
  the float's pace is scripted along the run's "walk" path, and the motor's
  `water` gives no push, so a pilot wading the channel beside it isn't
  carried.
