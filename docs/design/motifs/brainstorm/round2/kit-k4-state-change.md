# Round 2, k4: state-change kit pieces

Theme: state-change (verb: solve). Lenses: scale = a fragment of something
bigger; mood = wrong (uncanny); shape among isles = a hanging underside.

All four are a new family, **keel**: pieces hung under an isle's keel or
from the underside of a plate (the hollow keel's undercroft, a hanging
islet's soffit), each the one surviving part of a mechanism or a building
far bigger than the isle. Each changes state on something the pilot or
plane gives, and the new state opens or closes a route.

Sizes are in pilot terms: RuinKit's Scale section (STAND, TOP_ROOM,
GRAB_TOP, CHAIN_TOP, SET_OFF, RISER, TREAD, STAIR_WIDTH), PilotMotor
(WALK, RUN, JUMPS, STEP_UP, SLIDE_AUTO) and WorldScale (`opening`,
`gap`). No metres are copied.

Triggers named here exist today unless listed under Engine gaps: the slam
group (`slam(at, radius, strength)`, `Slam.decent`), the updraft's
`wind_pushable` group (`wind_push(origin, dir, power)`), standing and
landing on a body (foot_slab.gd's weight and `landed`), moving ground
(PilotMotor `mover`, bodies marked `moving_ground`, carrying him standing
or hanging), `knock` and `toss` with a source.

---

# Keel counterweight (keel_counterweight, family keel)
Verb: ride, solve (weigh the scale).
Look: the counterweight of a lift long gone. A deep stone pan, its rim
carved with a frieze of feet, hung on two chains from a pulley housing set
into the keel's underside. Its partner, a slab leaf with a drum-shaped
cheek, hangs on the chains' other ends further along the keel. The chains
run up into the rock and are not seen to come out. The wrong thing: on
arrival the pan already hangs low, as if something were standing in it.
Behaviour: changes state (moves between two rests). `sense` "weight":
stood on, the pan sinks and the leaf rises; stepped off, both creep back
after `hold` s. `sense` "absence" (the uncanny default): the pan sits low
while empty and *rises* under him, so to lower the leaf he has to leave the
pan, and someone has to be on the leaf as it moves. Travel `drop` in
SET_OFFs (default 3), at a pace under WALK so he rides it standing.
A decent slam into the pan drops it the full `drop` at once and jerks the
leaf up the same distance, faster than his pump's rise (the launch below).
Size: pan top 3 to 4 STAND across, its rim a ledge at GRAB_TOP over the
pan floor (caught from inside, climbed out). The leaf's top TOP_ROOM wide
and at least 2 STAND deep. At one rest the leaf's top sits a STEP_UP under
a keel ledge or a hanging islet's lip (walked onto); at the other it sits
GRAB_TOP under it (caught with one jump), or at CHAIN_TOP for a route that
asks for the pump. Pan and leaf stand at least a running long jump apart
(PilotMotor LONG_SPEED's reach), so he can't cheat from one to the other.
Collision: pan floor and leaf top are clean boxes, both `moving_ground`,
carrying him standing and hanging from their lips. The pan's outer wall is
over WALL_TALL and wall-kickable. Chains are dressing, with no hull. The
pulley housing is a static hull under the keel.
Motifs it enables:
- The empty scale: a hanging islet reachable only on the leaf, which only
  rises while the pan is empty, so he stands on the leaf and lures a
  stunned enemy or a rolled tumble stone into the pan to stay up.
- The weighing gate: the pan is the only way down from a keel ledge to the
  hollow keel's undercroft, and it only goes down while he steps off it
  and hangs from its rim.
- The catapult: slammed from the plate above, the leaf flings anyone on it
  up past the keel's lip to the isle's top. It is a one-way way up.
Catches / throws: standing on the pan or leaf, carried as moving ground.
Hanging from either lip, carried. A stunned or tumbling body counts as
weight (any body the foot pieces know, so a knocked enemy or a tumble
stone weighs the pan). A slam on the pan `toss`es whoever stands on the
leaf straight up at a speed that rises about 3 of his pump heights
(JUMPS[1]), his flat pace kept, source "keel_counterweight". On his feet
that is a launch, not a stun. Already stunned, he stays stunned. Nothing
knocks.
Build cost: med. The stone is procedural (RuinKit stone on boxes and a
lathed pan). There are two moving_ground bodies on one shared spring
(foot_slab's spring, read as one value), a chain mesh stretched between
fixed and moving points, and a "weight" query over the foot pieces. There
is no Blender model.
Model budget: silhouette geometry (the frieze and chipped rim on the
outline only); vertex-colour grime in the pan's crease and round the chain
eyes; import LODs plus a visibility range on the chains, because from the
plane at a distance the pair reads as two blocks.
State and reset: the state is the spring's rest (0 = pan high, 1 = pan
low), worked out from what stands on it every frame. Nothing latches, so
there is nothing to save. `reset()` and an isle reload snap both to
`start` with no motion.
Editor recipe: `"set": {"sense": "absence", "drop": 3, "hold": 1.5,
"start": 1, "slam": true}` plus `"leaf": [x, y, z]`, the leaf's offset in
the piece's frame, dragged as a second handle. The pilot-scale guides
draw both rests of the leaf against the nearest lip (STEP_UP, GRAB_TOP,
CHAIN_TOP ticks).

---

# Hung stair (keel_hung_stair, family keel)
Verb: solve, climb, slide.
Look: a full flight of the kit's own stair (RuinKit `stairs`: its risers,
treads, cheek walls and newel) hanging upside down from the keel, treads
facing the void and the soffit facing the sky. It is part of a building
whose upper storey is below it and gone. A hinge beam runs along the
flight's length at its upper cheek, socketed into the rock. Moss grows
down off the treads, hanging toward the sky the wrong way. On the plate
above, a carved boss in the turf marks where its axle runs.
Behaviour: changes state (turns 180 degrees about the hinge, along the
flight). Hanging, it shows its soffit: a smooth slope steeper than
SLIDE_AUTO, so landed on it he boot-surfs down it and off its foot. That
is a slide route off the keel. Turned, the treads face up and it is a
plain walked flight from a hanging islet or a keel ledge up into the
keel's shaft. Triggers: a decent slam on the boss above, or an updraft
from under it (the flow charge spent beneath the flight). The turn takes
`turn` s (default 1.2, near trap_flip's `flip`), after a `tell` (it
grinds and sheds grit, default 0.5 s). It stays turned for `hold` s
(default 12, long enough to run its length and back again), then tells
and turns back. `latch` keeps it turned.
Size: the kit's flight (STEPS of RISER and TREAD, STAIR_WIDTH wide,
cheek walls CHEEK), so turned it climbs STEPS x RISER. Its foot lands
within a STEP_UP of the lower ledge and its head within a STEP_UP of
the shaft floor. `flights` 1 to 3 chains whole flights on landings
(LANDING) along one hinge for a taller rise. Hanging, its foot sits at
GRAB_TOP over the lower ledge, so the lip of the hung soffit can be
caught and shimmied but not climbed over (the soffit is too steep).
Collision: treads and soffit are clean boxes on one rotating body, marked
`moving_ground`. Cheek walls are wall-kickable in either state. The hinge
beam is a static box, walkable along its top (TOP_ROOM across: a narrow
beam route under the keel).
Motifs it enables:
- The upside-down approach: from the hanging islet the way up into the
  isle is a stair that hangs the wrong way, and the pilot has to go up
  top, find the boss and slam it, then sail back down and run it before it
  turns back.
- The turn-under: a climb up the hung flight's cheeks while it turns, so
  he rides the rotation over the top and is set down on its treads.
- The slide drop: the hung soffit is the fast way off the keel to a
  satellite. Turned, that slide is gone and only the long stair remains.
Catches / throws: standing on it as it turns, he is carried (moving
ground) until it passes `knock_angle` (trap_flip's rule), then thrown off
along the hinge's swing with the body's own pace at his feet: a `toss`
when it turns slowly, a `knock` (source "keel_hung_stair") past
`knock_pace`. Hanging from a cheek or tread lip, he is carried round with
it. If he hangs on when it stops, he is the right way up on the other
side. Tumbling or stunned bodies on the soffit surf down it like him and
leave at its pace.
Build cost: med. It reuses the `stairs` piece's mesh and hulls whole (one
rotating parent), trap_flip's turning, carry and throw-off logic, and the
slam group. The updraft trigger needs the gap below.
Model budget: none new for the flight (it is the kit's stair). Vertex-colour
grime on the hinge sockets; import LODs and a visibility range on the
upside-down moss strands.
State and reset: two states, `hung` and `turned`, plus the timer.
`reset()` and a reload put it back to `start` ("hung" by default).
Latched, it is a mark the isle's run state could keep (Engine gaps).
Editor recipe: `"set": {"start": "hung", "flights": 1, "hold": 12,
"latch": false, "trigger": ["slam", "updraft"], "knock_angle": 70}` plus
`"boss": [x, y, z]`, a second handle snapped to the plate's turf above.
It snaps to the keel by its hinge connector (new connector "hinge" in
scripts/ruin_kit_fit.gd), with its foot and head as connectors to ledges
and stair landings.

---

# Keel oculus (keel_oculus, family keel)
Verb: solve, time a crossing (flown or run).
Look: the lantern eye of a dome that is no longer there. A thick stone
ring, its inner face carved as a rose window's tracery (rose_gable's
language), set upright in a hanging curtain of masonry under the keel.
Inside the ring an iris of wedge-shaped stone leaves meets at a boss.
Closed, it reads as a carved blind roundel. The wrong thing: when the plane
comes near, the iris tracks it, the boss turning a little to follow, and
on its `wary` rhythm it blinks.
Behaviour: changes state (closed, open, blinking). The leaves slide back
into the ring over `open_time` (default 0.8 s) and close over
`close_time`. Triggers:
- A decent slam on its keystone, a separate boss set in the plate's floor
  above (or on the curtain's walked top), opens it for `hold` s (default
  long enough for him to sail down to the plane and fly through: tuned in
  the place).
- `mode` "wary": it opens and shuts on its own rhythm (`period`, `blink`),
  and shuts early while the plane is within `near`, unless it has been
  slammed open.
- A slam while it is open latches it for the run (`latch` true).
- Landing on the lip inside the open ring holds it open while he stands
  there (weight), so on foot it is a doorway into the hall behind.
Size: the clear opening when open is `WorldScale.opening(TOY_OCULUS)`,
TOY_OCULUS 3.5 (the kit's TOY_THREAD: a snug threading width in
wingspans). The ring's own sill is a ledge STAND deep and walked. On foot,
from a keel ledge, the open sill sits GRAB_TOP over the ledge. Closed, the
leaves are a flat wall with the boss a STEP_UP proud, a foothold for a
wall kick.
Collision: ring and curtain are static boxes and wall-kickable. Each leaf
is a clean box hull on its own sliding body. They are walkable while
closed (a flat face only from the side, so not stood on), and gone from
the opening while open. The plane's hull meets the leaves as solid. The
sill is `moving_ground` only while the iris moves.
Motifs it enables:
- The blind dome: a hollow-keel style hall under an isle whose only flown
  way in is the oculus, and the slam that opens it is on the isle's top,
  so the pilot works the isle on foot, then runs back to the plane in time.
- The blinking curtain: a hanging curtain of three oculi on staggered
  `wary` rhythms. The plane threads whichever is open and the eyes follow
  the plane as it comes.
- The held door: on foot he can only stand in the ring to keep it open. A
  stunned enemy or a tumble stone left on the sill holds it while he goes
  through.
Catches / throws: standing in the ring as it closes, the leaves knock him
out along the ring's axis on whichever side he is nearer, up a little,
source "keel_oculus" (lock rules as any knock). A stunned body caught in
it is thrown the same way with `toss`. The plane meeting a closed or
closing iris takes its normal crash or bounce off stone (whatever the
plane does against a static hull today).
Build cost: med-high. The ring and leaves are procedural (rose_gable's
tracery code and wedge leaves on short slides), plus the keystone link and
the blink timing. The plane against moving hulls and a general
"plane near" query are engine gaps (below).
Model budget: silhouette geometry (the tracery cut through, the leaves
plain); parallax depth for the blind roundel's carving on the closed
leaves; import LODs, since from the plane it is seen across the whole sky
long before it is reached.
State and reset: `closed`, `open` (with a timer) or `latched`, plus the
`wary` phase. Reload puts it back to `start`. A latch is a run-state mark
(Engine gaps), so a run that opened the dome keeps it open on return.
Editor recipe: `"set": {"mode": "wary", "period": 4.0, "blink": 1.4,
"hold": 20, "near": 2.0, "latch": true, "start": "closed"}` (`near` in
plane spans, read through WorldScale) plus `"key": [x, y, z]`, a second
handle for the keystone boss. The pilot-scale guides draw the opening's
WorldScale width ring so the threading line is judged in the editor.

---

# Colossus hand (keel_hand, family keel)
Verb: solve, climb, stay hidden (inside it).
Look: the hand of a statue far too big for any isle, broken off at the
wrist and hung palm-up under the keel, with its wrist stump socketed into
the rock. The four fingers and thumb are curled shut over the palm, and
the knuckles are a row of worn stone humps. Something glints between the
fingers (a find in the palm). The wrong thing: it closes again slowly when
no one is looking at it, so through the binoculars it is still, and from
the corner of the eye it has moved.
Behaviour: changes state, one finger at a time. A decent slam on a
knuckle, or a landing from a fall stun's height, uncurls that finger over
`open_time` (default 1.0 s, a heavy anticipation crouch then a snap
open) into a flat beam reaching out over the gulf. Open fingers curl back
after `hold` s, slowly (`close_time`, default 4 s, slower than WALK pace
at the tip), and faster while the camera is turned away (`shy`, the
uncanny rule, off by default). A slam on the palm from inside opens all
five at once (the way out). The fingers are rigid parts on hinges at the
knuckles (no bending).
Size: palm floor 3 to 4 STAND across. Curled, the fingers make a cage
over it whose gaps are under the pilot's body, and its knuckle row is a
walked top TOP_ROOM wide whose humps step by under STEP_UP. An open
finger is a beam TOP_ROOM wide and 4 to 6 STAND long. Its tip either sits
GRAB_TOP under the next isle's lip or leaves a gap of a running jump to
it. Fingers open to different angles (`spread`), so a chain of open
fingers is a fan of beams at different heights, each SET_OFF apart: a
climb up the hand's fingers.
Collision: palm, knuckle row and each finger top are clean boxes, each
finger its own `moving_ground` body, carrying him standing or hanging
from its tip. The finger sides are wall-kickable. Closed, the fingers'
inner faces are the cage, wall-kickable from inside, with a gap at the
top under CHAIN_TOP that is too narrow to climb out through.
Motifs it enables:
- The open hand: a hanging islet off the keel, reached only along an
  opened finger. He opens the next finger from the one he stands on, so
  he crosses by opening his own bridge, one slam ahead.
- The closed fist: the find in the palm. He gets in by riding a finger as
  it curls and being rolled into the palm, then has to slam his way out.
- The fan: a climb up five fingers at five heights, timed against their
  slow curl.
Catches / throws: standing on a finger as it curls, he is carried until it
passes `roll_angle`, then rolled down it into the palm with a `toss`
(source "keel_hand", not a stun: a soft fall into the cage). Hanging from
a fingertip, he is carried up and over into the palm the same way.
Tumbling or stunned bodies on a curling finger roll into the palm too. The
cage holds them, so the hand is also where a knocked enemy ends up. The
all-five slam from inside opens them at the snap's pace, so whoever is on
a finger tip leaves with that finger's pace (moving ground's `frame_v`).
Build cost: high. It needs a Blender model (the hand sculpted, five finger
meshes rigid on the knuckle hinges), five `moving_ground` hinged bodies
with their own clocks, the curl-and-roll carry, and a buried-find style
reveal for the palm's find. The `shy` rule needs a camera-facing query
(cheap).
Model budget: sculpt high, bake low (the hand's knuckles and nails baked
onto a light mesh); rigid parts on bones (each finger a separate mesh on
its hinge, never skinned); silhouette geometry for the wrist's break;
vertex-colour grime in the palm's creases; import LODs, since from the
plane the curled fist is a single lump.
State and reset: five finger angles and timers, plus `found` for the
palm's find. Reload curls it shut (`start`: "fist", or "open" for a hand
already spread). The find's `found` belongs to the run's finds (as a
buried find's is), and the fingers never latch.
Editor recipe: `"set": {"start": "fist", "hold": 8, "open_time": 1.0,
"close_time": 4.0, "spread": [10, 25, 40, 55, 70], "shy": false,
"find": "rune_token"}`. It snaps to the keel by its wrist connector (new
"wrist" connector in scripts/ruin_kit_fit.gd), and each open fingertip is
a connector shown as a ghost, so the editor can line a tip up under the
next lip.

---

## Combines with

- keel_counterweight: `floor` and `hall_slab` (the keel ledges it serves),
  the hollow_keel's undercroft, `trap_tumble` stones and stunned enemies as
  weight, `bridge_anchor` and rope bridges from its leaf's high rest,
  `tower_shell` (a lift shaft for the vanished lift above the pulley).
- keel_hung_stair: `stairs` and `grand_stair` (it is their flight), the
  hollow_keel's shaft and its switchback grand stairs, `buried_find` (a
  boss slammed the same way), `trap_flip` (its turning code),
  `floating stones` (bob and drift slabs) as the way back up top to the
  boss.
- keel_oculus: `rose_gable` (its tracery), `vault` ribs and `hall_bay`
  for the dome fragment behind it, the belfry `bell` (rung within reach of
  the oculus as a trigger once the bell sends one), `wind_horn` (a ward
  that blows him off the sill), `trap_tumble` stones to hold its door.
- keel_hand: `hall_column` and `fallen_pier` (the rest of the colossus,
  broken on the isles nearby), `buried_find` (the palm's find), swing
  ropes hung off the open fingertips, `trap_seesaw_slam` (another slam
  puzzle on the same isle), rope bridges anchored at the wrist.

## Engine gaps found

- **Per-piece settings in recipes.** Authored pieces
  (`motifs/authored/*.json`, scripts/kit_isle/motif_authored.gd) store id,
  seed, weathered, at, turn, sink and `on` only. These pieces need an
  additive `"set": {...}` dictionary passed to `RuinKit.piece` as opts,
  and a linked second handle (`leaf`, `boss`, `key`) in the piece's frame.
  Leaving both out should build each piece in its rest state, so older
  saves load unchanged (the editor's `stable` rule).
- **No saved world state.** RunState (scripts/roguelike/run_state.gd)
  keeps hearts and falls but no per-isle marks, so a latched piece (stair
  `latch`, oculus `latch`) forgets on reload. It needs a small marks
  dictionary keyed by isle and piece index.
- **The updraft reaches nothing overhead.** Its ring pushes the
  `wind_pushable` group flat, within 0.6 of its radius up or down. A piece
  hung over him needs an upward column query (or `wind_push` with a
  reach-up for things above), so it can hear the flow charge spent
  beneath it.
- **"The plane passed near" is local to the bell spires.**
  `plane_near(at)` lives in motif_bell_spires.gd. The oculus's wary blink
  (and any piece that reacts to the plane) needs a general group the
  flight calls each frame or on a close pass.
- **The bell sends nothing.** The belfry bell swings but has no rung
  signal, so it can't be a trigger for other pieces.
- **To check: the plane against moving hulls.** Whether the plane's
  flight collides with bodies that move (the oculus's leaves, the hand's
  fingers) as it does with static stone, and what happens when a hull
  closes on it.
- **A weight query for the counterweight.** It needs "what bodies stand on
  me": the pilot's feet (foot pieces know this), stunned enemies and
  tumble stones (which don't report it today).
