# Round 4, kit k2: moving pieces

Theme: pieces that move on their own and that you ride, dodge or race.
Lenses: scale colossal, mood wrong, shape a ring or spread wide. There are four
pieces. Two make a chase: the Rolling Head chases you and you chase the Flown
Capital. The Unmaking Span is a race.

Every number comes from the pilot (scripts/pilot_motor.gd: RUN 4.8, WALK 2.4,
JUMPS 0.8/1.5, the long jump's 4.2 m chained to about 6.7, SLOPE_SLOW 22°,
SLIDE_AUTO 44°), RuinKit's Scale section (GRAB_TOP 1.875, CHAIN_TOP 2.575,
STAND 0.58, TOP_ROOM 1.16, WALL_HEIGHT 2.4), the hall and aqueduct modules
(COLUMN_R 1.2, COLUMN_H 10, ABACUS 1.7, DECK_WIDTH 2.3, ARCH_SPAN) and
WorldScale (`opening(TOY_THREAD)` 7.0 at the defaults). A figure "at the
defaults" is a reading, not a constant to copy.

These are already built or carded, so they are not proposed again: the haul-way
sledges, the rune serpent, the airship ferry, the sky ray, the logs, the tumble
block and the tumble run, the flip slabs, the voussoirs, the millstone beetle,
the second walker, bob/drift/sink slabs, swing ropes, live rope bridges, and
round 2's twenty (noria, channel_float, arch_swing, hall_drum_roll, haul_ferry,
well_sweep and the rest).

**How the riders work.** The motor has two ways to move a rider:

- **`mover`**: an AnimatableBody3D marked `PhysicsGround.mark_moving`. It
  carries his feet and his hang by the body's full transform change, turns
  him by its yaw, and keeps its motion as `frame_v` when he leaves it.
- **`motor.carry`**: the trap moves him itself, as the logs, the tumble block
  and the ray do.

Three of the four pieces use `mover` and stay inside what is proven (a
translation and a yaw). The Rolling Head carries him by a flat translation,
because a pitch carry would tip him. The Flown Capital's bank is the one
step past the proven path, and its card flags it.

---

# Orrery Arm (orrery_arm, family relic)
Verb: ride a rotating bridge out to a ring of isles, and jump its sweep on the
hub.
Look: a colossal stone armillary on a low isle at the ring's middle. A hall
column drum, squat and banded with bronze-green rings, is the pivot. Through
its head runs one long stone beam, the arm: a walkable deck of dressed slabs
with a broken balustrade on one side, reaching far out over the gulf. A short
counter-arm on the other side ends in a stone ball the size of a tomb chest
and rides low over the hub's paved round. Rim isles stand in a ring round the
hub, each with a worn stone cradle at its edge where the arm's tip has rested
for centuries.
Behaviour: it moves on its own clock. The arm turns at a tip pace of about
WALK (2.4 m/s at the tip), docks at each rim isle and rests `dwell` s (8 by
default) with its tip deck a SNAP under the cradle's turf, then turns on.
The tell before it leaves is a grinding judder and grit sifting off the
deck, `tell` s (1.5). The wrong part is the `order` knob:
- `round`: the arm visits the isles in ring order.
- `skip`: it passes some cradles without stopping.
- `wrong` (the default in a wrong-mood motif): every few docks, when he
  is past the arm's middle, it stops, holds a beat, and turns back the way
  it came.

The counter-arm's ball sweeps the hub's round at shin height, one sweep a
lap.
Size: the arm's reach is the `radius` knob, 40 to 80 m from the pivot to the
tip. At 60 m and WALK at the tip, a lap of a five-isle ring takes about
3 minutes with the dwells. The deck is DECK_WIDTH (2.3) across, about two
TOP_ROOM, so he can walk it at a run with room either side. It sits at the
rim isles' turf height over a gulf.
- **Pivot drum:** COLUMN_R x 2 across. Its band ledges are a SET_OFF apart, so
  he can climb from the hub round to the arm's root.
- **Counter-arm:** the ball's top is 0.55 over the round, a margin under
  JUMPS[0] 0.8, so a plain jump clears it. The arm's underside is at least
  `opening(TOY_THREAD)` over anything below it, so the plane can fly under
  it.

Collision:
- The deck is a run of clean boxes on one AnimatableBody3D, marked moving
  ground. The balustrade stumps are low boxes, under STEP_UP, so he steps
  over them.
- The deck's ends and sides have lips he can hang from.
- The pivot drum is a static cylinder: he can wall-slide and wall-kick off
  it, and its bands are ledge lips.
- The counter-arm's ball is a sphere hull on the same body. It knocks; it is
  not ground.
- The cradles are static boxes.

Motifs it enables:
- Orrery Ring: five isles at the points of a ring, linked only by the arm.
  Each isle holds part of a route, and the arm in `wrong` order means the
  next isle is rarely the one you planned for.
- Severed Orrery: the arm is broken off halfway, so its stub turns as a
  sweeping platform over the gulf. You catch the stub from a rim isle as it
  passes and ride it round to an isle that has no cradle.
- Twin orreries on two hubs whose arms pass over each other: you transfer
  arm to arm where they cross, a pump's height apart.

Catches / throws:
- **Standing or hanging on the deck** (`mover`): he is carried by its yaw
  about the pivot (`carry` with a turn about up, the proven path). Jumping
  off keeps the tip's sideways pace as `frame_v`, so a jump to a cradle has
  to lead the cradle.
- **Airborne:** landing on the deck takes up its motion at once.
- **Tumbling or stunned:** carried as a crate.
- **The ball's sweep:** a body standing in it is knocked along the sweep's
  tangent at the ball's pace plus 2 m/s up, source this node. The motor's
  `restun_gap` keeps it from locking him.
- **The `wrong` reversal:** no throw. The reversal eases over 1.5 s so he
  is not flung.
- **The plane:** the arm is solid, a bump like any kit wall.

Break: the arm's deck is tagged `break_kind "lintel"` (a KIND_OF line:
`"orrery_arm":"lintel"`) with `toughness 1.0`. The Olmec breaks it, and so
does a full-power slam (strength 1.0). That is on purpose: a high slam onto
the arm's root snaps it, and the stub left standing keeps turning (the
Severed Orrery). The pivot is `pier` with `toughness 1.6`, so it does not
break.
Build cost: medium. It is all procedural kit stone (the hall column, beam
slabs and the tomb-chest stone for the ball). The motion is one yaw a frame
plus a docking table read off the rim isles' cradles. The risk is checking
that `frame_v` off a long arm's tip lands where it should.
Model budget:
- Import LODs and visibility ranges: the arm is seen from every rim isle,
  60 m out.
- Silhouette chips on the arm's broken balustrade and its tip.
- Vertex-colour grime in the deck joints.

Sculpt-and-bake is not needed. At 1.2-2k triangles the arm is in line with
a hall beam.

---

# Rolling Head (relic_rolling_head, family relic)
Verb: be chased round a ring gutter by a colossal stone head, and escape by
niches, by speed, or by getting on top of it.
Look: the head of a fallen colossus, about 4.5 m across (four pilot heights).
It is weathered round, with the nose and brow worn almost flat, and rolls in
a ring gutter round an isle. The gutter is a sunken causeway between two
banks of kit walls, about two heads' widths across. Its walls are cut every
so often with niches, shallow shrines just deep enough for a body. The wrong
part: it rolls face over face, but every time the face comes up it is turned
to where he is, its eyes level with his.
Behaviour: it moves and changes state, in four states:
- **`rest`:** it sits in its socket, a scooped dip on the gutter's line,
  face toward the dip's mouth.
- **`wake`:** he steps down into the gutter. The face grinds round to him,
  and a 2 s tell of dust and a low tone follows.
- **`roll`:** it rolls after him round the ring, gaining at 1.5 m/s² up to
  `pace`. The default `pace` is 0.92 of RUN, about 4.4 m/s, so a plain run
  loses ground slowly. A slide, a long-jump chain or a slide hop opens a
  gap.
- **`settle`:** it loses him (out of the gutter, or hidden in a niche for
  `lose` s, 3 by default) and rolls on, slowing to its socket over half a
  lap.

The ring has no end: if he never leaves the gutter, it keeps coming round.
Size:
- **Head:** 4.5 m across, its top well over CHAIN_TOP, so he cannot jump
  it and must go round or on top of it.
- **Gutter:** two heads wide (about 9 m). Its walls are 2.4 m, WALL_HEIGHT,
  so a pump catches the lip. That is an escape that takes a moment he may
  not have.
- **Niches:** STAND x 2 deep and a body wide, with the head clearing their
  mouths by 0.3 m.
- **Ring:** the `radius` knob is 25 to 45 m, so a lap is 160 to 280 m, about
  35 to 60 s at a run.

Collision:
- The head is a sphere shape on an AnimatableBody3D. It is not marked moving
  ground, because the trap carries him itself (below).
- The gutter floor is the isle's ground.
- The gutter walls are kit `wall` pieces: clean boxes, wall-kickable, with
  lips he can hang from. Two walls a gutter's width apart are too far to
  kick between.
- The niches are boxes cut into the wall line, built as a kit wall's gap.

Motifs it enables:
- Gutter Ring: a crown of shrines on a ring bank round a sunken court. Each
  shrine's relic is reached from the gutter, and the head guards the whole
  ring.
- The lure: a gate pier stands in the gutter. You let the head chase you
  past it and it breaks the pier (below), opening the way to the inner
  court.
- Riding the head over a span where the gutter crosses a gap between two
  isles on an aqueduct. Only the head's top clears the span's break.

Catches / throws:
- **Standing in its path:** knocked forward along the gutter at its pace
  plus 1 m/s, and up 4 m/s, stunned, source this node. It keeps coming; the
  `restun_gap` (1.2 s) means its next touch only throws him on. After
  `stun_chain_cap` (3 s) he can always break out. His teched landing is the
  roll, which keeps his pace.
- **On top:** `motor.carry` by a flat translation only, with no pitch. On
  the top of a rolling ball the surface moves forward at the ball's pace,
  relative to its middle, so standing still he is walked off its front into
  its own path. He runs back along it at its pace to stay up. While he
  stays on top it does not lose him; the face turns up under his feet,
  looking up at him.
- **In a niche:** passed by, untouched.
- **Hanging on the gutter wall's lip:** passed by. The head's top clears
  the lip's hands by 0.3 m.
- **Tumbling bodies and loose tumble stones** in its path are tossed on
  ahead.
- **The plane:** the head is a bump.

Break: two parts.
- **The head as a breaker:** it calls `hub.hit(at, 2.2, 1.0, &"rolling_head")`
  on whatever kit piece stands in the gutter in front of it. That is a new
  breaker source, on by default in its own motif. A pier, wall or fallen
  pier there breaks on the touch, and the head rolls on through the rubble,
  slowed by half for 1 s.
- **The head itself:** a registered cut, `Kinds.register("colossus_head",
  cut)`, with `toughness 1.0` (the Olmec only, never itself). The cut leaves
  no stands and drops the head as two `chunk` halves, each a convex hull.

Build cost: high.
- **The head:** a Blender sculpt baked low.
- **The face-turning:** the mesh's roll about its axle is split from the
  face's turn toward him, done by rotating the roll axis about the vertical
  so the face lands on him.
- **The gutter:** procedural kit walls on the turf; no terrain cut is needed.
- **Logic:** the chase state is a small trap on the trap contract.

Model budget:
- Sculpt high, bake low: the head about 8-12k triangles from a dense
  sculpt, with normal, AO and curvature maps.
- Import LODs.
- Silhouette chips on the worn brow and the chin's break.
- Parallax depth for the cracks across the face.
- Vertex-colour grime in the eyes and mouth.

It saves about 100k+ triangles against using the sculpt directly, and keeps
the one moving colossal mesh cheap enough to roll every frame.

---

# Unmaking Span (aqueduct_unmade, family aqueduct)
Verb: race a wave of unmaking along a long aqueduct between far isles, or
ride the stones it lifts up to a higher route.
Look: a long aqueduct of many bays strung over the gulf between two isles a
long way apart. Its deck slabs and the voussoirs of its arches sit a finger's
width apart, as if never mortared. When the wave passes, the stones come
away upward: they lift off the piers, slowly, turning a little, shedding
grit that falls up. They hang in a loose cloud over the span, then drop back
into their seats with one heavy clap per bay.
Behaviour: it moves on its own clock (`period` s), or starts when he steps
onto the first bay (`trigger` knob).
1. **The tell:** at the start pier a hum, and grit beading upward off the
   deck.
2. **The wave:** it runs bay by bay along the span at `pace`. The default is
   0.95 of RUN, about 4.6 m/s. A clean run from the start pier at the tell
   just wins; a stumble, a stop or a walk loses; a slide hop chain wins with
   room.
3. **Each bay the wave reaches:** its deck slabs lift in a staggered order
   (the far edge first), at 1 m/s, so gaps open under his feet. They rise
   `lift` m (6 to 12) and hang. The voussoirs lift with them, and the arch
   below opens.
4. **The rest:** after `hold` s (8), the bays drop back in the same order
   at 3 m/s, each settling with a clap.

Bays the wave has not reached are still. The wrong part is that the stones
fall upward and the span puts itself back together.
Size:
- **Bays:** each is ARCH_SPAN (8.4 at the defaults), so each arch is a flown
  opening of at least THREAD.
- **Length:** the `bays` knob, 10 to 24 bays, 85 to 200 m: a far isle, not a
  neighbour.
- **Deck:** DECK_WIDTH (2.3) across, in slabs STAND x 3 long.
- **The lifted cloud:** the stagger leaves neighbouring hanging slabs within
  a pump's catch of each other, under CHAIN_TOP in rise and under the long
  jump's 4.2 m apart. So the cloud is a climb as well as a ruin: ridden up,
  it reaches a ledge `lift` m over the far isle's rim.

Collision:
- Each deck slab and each voussoir he can stand on is a clean box on its
  own AnimatableBody3D, marked moving ground while it moves. Slabs are only
  bodies in the wave's few active bays; the rest are part of the static
  span. That is about 12 live bodies at once.
- The piers are static `aqueduct_stump` pieces.
- The deck's sides are lips he can hang from (a hang is carried up with the
  slab).
- The plane: the hanging cloud is solid. A flight through it is a slalom.

Motifs it enables:
- Long Unmaking: two isles far apart with only this span between them, a
  race every crossing. You can only lose it by falling into the gulf, which
  costs only position and time.
- The upper route: a find on a ledge over the far isle that you reach only
  by riding a rising slab and hopping the cloud before the clap.
- Two spans crossing at different heights, their waves out of step. A
  slab lifted off the low span rises into the high one's path.

Catches / throws:
- **Standing on a lifting slab** (`mover`): carried up by translation, with
  a small yaw. Jumping off keeps the slab's rise, at most 1 m/s. A plain
  jump then reaches about 1.07 m instead of 0.8. That puts a little pace
  into height, the rule question round 2 raised, so it is kept small on
  purpose.
- **Standing on a dropping slab:** carried down. On the clap he is tossed
  up 2 m/s, not stunned (as the haul-way's dock tosses), or tossed on still
  stunned if he was tumbling.
- **Airborne:** landing on a moving slab takes up its motion.
- **Tumbling or stunned:** carried as a crate. The clap tosses him on.
- **On the deck when the gap opens:** he falls, his pace kept. The wave
  never knocks.

Break: the span answers the hub (contract way 3). It joins `breakable` and
its `take_hit(hub, at, radius, strength, source)` starts an unmaking at the
bay hit, running both ways, instead of the shared fall. A slam onto a bay
sets off a wave from under his own feet. Its stones are never physics
bodies, so it never uses the 24-body cap. The piers are ordinary
`aqueduct_stump` pieces (kind `pier`), adopted and broken as ever. A broken
pier drops its two bays for good (they hang and never reseat).
Build cost: medium.
- The slabs and voussoirs come from the aqueduct module's deck and arch
  builds, split per bay with `Build.keep_only`.
- The motion is tweened transforms on a timeline: no physics, no
  simulation.
- The work is the per-bay split and making the hanging cloud a fair climb.

Model budget:
- Visibility ranges, so the far bays drop to the static span's merged mesh.
- Import LODs on the merged span.
- Silhouette chips on every slab edge, which read in the lifted cloud.
- Vertex-colour grime along the joints.

The live bays are the only extra draw calls, about 12 bodies at about 100
triangles each.

---

# Flown Capital (hall_flown_capital, family hall)
Verb: chase a colossal capital that flies from roost to roost across far
isles, catch it, and ride it home.
Look: the capital of a colossus column, the hall's own (an echinus under an
ABACUS-square abacus), torn off its shaft and flying. It has no wings. It
moves the way a startled bird does: a lurch, a climb, a glide, and its shed
grit trails behind it. It roosts on the broken tops of bare hall columns on
isles spread wide apart. One column in the set, the tallest, is its own and
stands whole but for the empty bed on top.
Behaviour: it moves and changes state, in five states:
- **`roost`:** it sits on a stump's top, rocking slightly.
- **`shy`:** he comes within `shy` m on foot (12 by default, measured flat
  and level with it or below), or the plane within `shy_plane` m (60). It
  lifts with a 0.6 s tell (a shudder, grit) and flies to another roost
  along an authored curve between isles, at about 1.5 RUN in a glide, with
  dips low over the gulf.
- **`blind`:** it does not shy from above. A pilot dropping onto it from a
  higher ledge, or gliding down under the sail, is not seen. That is how it
  is caught.
- **`ridden`:** with him on top, it flies the rest of its round of roosts,
  banking up to 18° to throw him. That is under SLOPE_SLOW, so standing he
  holds on and the stick fights the lean. It settles on its own column only
  if he is still on it when it passes.
- **`home`:** it settles on its own column and stays. The column is whole
  again, its top a perch over the isles.

Size:
- **The capital:** ABACUS x 2 (3.4 m) square on top, which is about three
  TOP_ROOM, so he stands and moves on it but not freely. It is CAPITAL_H
  deep plus the echinus.
- **Roost stumps:** COLUMN_R across, at heights from GRAB_TOP to the full
  COLUMN_H.
- **The `blind` drop:** from SET_OFF to two pump heights over its abacus.
  Falling further would fall-stun him, and the sail never stuns.
- **The roost set:** 4 to 7 roosts on 3 to 5 isles, 60 to 200 m apart. On
  foot he cannot follow it across a gulf; the chase is by plane between
  isles and on foot within one.

Collision:
- The abacus top is a clean box on an AnimatableBody3D marked moving
  ground.
- The abacus edges are lips he can hang from, so a short drop can be caught
  by the hands, and the hang is carried with it.
- The echinus is a convex hull, a wall he can kick off.
- Roost stumps are static `hall_column` pieces cut at a height.
- The plane: the capital is a bump. Flying into it in the air knocks it
  into an early `shy`, and the plane takes a bump.

Motifs it enables:
- Scattered Peristyle: isles spread wide, each with a stump or two of one
  vanished temple. Following the capital by plane shows you every isle of
  the set, and riding it home rebuilds the temple's one whole column, the
  set's landmark and perch.
- The high blind: a roost that can only be caught from a ledge above it,
  reached by a climb that the capital is watching. You climb on its far
  side and come over the top.
- A rider's crossing: a far isle with no landing strip and no ferry. The
  only way there on foot is aboard the capital.

Catches / throws:
- **Standing or hanging** (`mover`): carried by its full transform change.
  The yaw is the proven path. **The bank is the open step:** round 2's gap
  "a rider on moving ground", riding a slope on a tilting collider. The
  motor reads ground off the collider and its slope from heights, so it
  should hold. The card keeps the bank under SLOPE_SLOW so that, if it
  doesn't, the bank can be cut to zero and the piece still works.
- **Leaving it:** jumping off keeps its flight as `frame_v`. That is fast
  (1.5 RUN), so a jump off it over an isle is a long fall forward, and the
  sail fades the frame (SAIL_FRAME).
- **Airborne onto it:** takes up its motion at once.
- **Tumbling or stunned:** carried as a crate. A hard bank tosses a stunned
  body off, still stunned.
- **On a terrace in the line of its lift-off or dip:** knocked along its
  flight at its pace plus 3 m/s up, source this node.

Break: a registered cut, `Kinds.register("capital", cut)`, with `toughness
1.2`. That is over the slam's full strength (1.0), so a rider's slam never
breaks his ride, and only a stronger source does (none today; the Olmec at
1.0 can't either). The cut leaves no stands, and drops the abacus as a
`slab` and the echinus as a `chunk`. Broken in flight, both fall into the
gulf and the capital is gone until the motif reloads. Its roost stumps are
plain `hall_column` (kind `pier`) and break as ever. A broken roost drops
out of the roost set.
Build cost: high.
- The model is cheap: the hall kit already builds the capital.
- The cost is the behaviour:
  - authored flight curves between isles;
  - the shy test against both the walker and the plane;
  - the `blind` cone;
  - a roost table shared across several isles (a motif spanning far isles,
    or a link between motifs);
  - the banked ride.
- `home` is a world state that wants saving, which is round 2's trigger and
  save gap.

Model budget:
- Visibility ranges and an LOD for the flying copy, since it is chased
  across 200 m and mostly seen small.
- Silhouette chips on the torn bed under the echinus, where it broke off its
  shaft.
- Vertex-colour grime.

At about 1k triangles it needs no sculpt.

---

## Engine asks this file adds

- **A tilting collider under a rider** (the Flown Capital's bank): round 2's
  gap 2, still untested.
- **A breaker source that is a piece** (the Rolling Head's
  `rolling_head`): the hub takes named breakers already; this one is a
  moving trap rather than an enemy.
- **Pieces that span isles far apart** (the Orrery Arm's ring, the Flown
  Capital's roost set): the motif contract has one footprint per motif.
  These pieces want sockets on several isles, or a link between motifs.
- **The editor can place only static pieces** (round 2's gap 1). All four
  of these pieces have that gap.
