# Kit round 4, k1: grab / climb

Lenses: verb climb (hang, shimmy, chain, wall kick); scale intimate to
human (small pieces that dress any isle); mood playful.

Four pieces, each a few pilot heights tall, each built round one or two of
the motor's hand moves. Each is in the ruin kit's pale stone (RuinKit
Build, `ruin_stone.gdshader`) or, for the scaffold, timber and rope. One
(the scaffold) has a second home in the underground Olmec city.

Names for sizes below, all read from code, never copied:
`BODY` (0.28), `STAND` (CLIMB_IN + BODY, the least tread climbed onto),
`TOP_ROOM` (2 STAND, a walked top), `GRAB_TOP` (one jump's catch, about
1.9 m at wanderer 1.0), `CHAIN_TOP` (the pump's catch, about 2.6 m),
`SET_OFF` (1.6, the rise between standing places on a climbing route),
`WALL_HEIGHT`, all RuinKit; `KICK_GAP` (RuinKitTower: two walls kicked
between); PilotMotor's STEP_UP, WALL_TALL, SLOPE_SLOW (22°), SLIDE_FROM
(10°), SLIDE_AUTO (44°), SHIMMY_SLOPE (a lip rising under 1 in 1),
CURL_MOST, GRAB_REACH, REGRAB, LONG_SPEED, WALLRUN_*; `SwingRope.LENGTH`
and `KNOT`; BobSlab's SINK, TILT, HZ. The pilot stands about 1.1 m.

None of these repeats round 2's twenty, the buttress's set-offs, the tower
shell's kick chimney, the city's niches or slot wall, or the corbel shaft:
each has its own line of moves, and two of them turn the climb into a ride
back down.

---

# Spout Wall (aqueduct_spouts, family aqueduct)
Verb: climb a zigzag of carved spout heads up an overflow wall, in time
with their gushes. A gush slips your hands, and you catch the head below.
Look: a short coursed wall where an aqueduct's channel ends or spills: a
castellum's face with the channel's lip along its top. Up the face, carved
spout heads (blunt rams, fish and lions, cut as a few chamfered blocks,
not sculpted) jut in a staggered zigzag, mouths open and green-stained
under them. A pool basin lies at the foot, and moss and maidenhair grow in
the wet. Some heads dribble, and a few are broken off at the neck (stubs).
Break kind: `wall` (KIND_OF gets `"aqueduct_spouts":"wall"`). The heads
are Build blocks of the wall, so `keep_only` cuts between courses; a gush
whose head no longer stands stops.
Behaviour: the stone is static, and each spout changes state on a cycle.
Every head gushes for GUSH s (about 1.2) and runs dry for DRY s (about
2.4), the rows phased by RIPPLE s (about 0.4) from the top down, so a gush
runs down the wall like a wave and a dry window climbs up it. Fed live:
when the channel's sluice (scripts/traps/trap_sluice.gd) floods upstream,
every head gushes at once for the wave's length (a tell from the channel,
read from the wall). Knobs: `rows` (3-6), `cycle` (GUSH, DRY, RIPPLE),
`stubs` (heads broken off: gaps in the zigzag closed by a pump), `fed`
(the sluice link, on or off).
Size: the wall stands `rows` SET_OFFs plus a coping, its top TOP_ROOM
wide with the channel in it (shallow: a wade, never a swim). Each head's
crown is STAND deep and its front edge a lip. Each row stands one SET_OFF
over the last and is offset sideways by about a STAND past GRAB_REACH, so
no head is caught from straight under the one above: from a hang you
climb on, turn, and hop up and across. A stub in the zigzag leaves a
CHAIN_TOP rise, closed only by the pump off the head below. Heads project
far enough (STAND plus HANG_OUT) that a hanging body's feet clear the
face. The basin is deep enough to swim (SWIM_IN and more) under the
lowest two rows, so any slip off them is a splash, never a fall stun.
No flown opening.
Collision: the face is clean, true hulls (kicked from as any wall). Each
head is a clean box with a true ledge top (`_stand_on`). Each gush is an
Area3D falling from the mouth outward and down, about one STAND across
and two SET_OFFs long, so it washes the head below and never the head it
pours from. The coping and channel are walk boxes, with the channel in
the water query.
Motifs it enables:
- An aqueduct's broken end: a climb up out of the spill pool onto the dry
  channel, the way up from the turf to the deck.
- A cistern court: four spout walls facing in round one basin, each on a
  different cycle, read from the water before you pick a wall.
- A sluice run: flood the channel above and the wall below goes white;
  climb it in the lull after the wave.
Catches / throws: hanging under a gush, his hands slip. He is let go
(not knocked, not stunned) and falls with REGRAB cleared, so the next
head's lip below catches him if he faces it: a slip and a catch, a row
lost. Standing on a head in a gush, he is tossed out and down along the
water (`toss`, about a walk's pace, source "spout") off a STAND-deep crown.
Airborne through a gush, his rise is cut (a down push of about WALL_SLIDE,
no stun). A stunned body knocked into the face is washed down it head to
head (`toss`, still stunned) into the basin, whose water ends the stun. A
twirl-armed tech kicks off the face as any wall. The heads throw nothing
that adds pace.
Build cost: med. The stone is procedural (RuinKit Build blocks; the
heads are three or four chamfered blocks each). The gush is a timed Area3D
and a flow-fall strand (the aqueduct's broken-end fall, shrunk). The new
work is the slip: a ledge let-go that leaves catches open (see Engine
gaps), and the sluice link (the trap's flood signal read by the wall).
Connectors in `ruin_kit_fit.gd`: a `channel` end on top meeting
`aqueduct_end` or a broken span's snapped channel.
Model budget: silhouette geometry (the heads' snouts and broken necks
real, the courses' faces flat). Vertex-colour grime (green streaks under
each mouth and wet dark below the waterline). Import LODs with a visibility
range on the gush strands and dribbles (drop them past about 50 m; the
wall stays). About 2.5-4k triangles of stone. The strands are about 200
each, so a 6-row wall past range saves about 1.5k triangles and the
strands' transparent overdraw, which is the real frame cost (perhaps
0.1-0.2 ms with the wall filling the screen near). Sculpt and bake doesn't
pay at this size, and parallax depth isn't worth it.

---

# Fives Court (fives_court, family gothic)
Verb: kick up the narrow front end of a roofless walled court, cross its
front wall's coping, and boot-surf down a side wall's raking coping to fly
off its low end. Then go round again.
Look: an old walled ball court, three walls and no roof, open at the
back. The front wall is the tallest, pitted with ball marks, with a
moulded step ledge across its face. The two side walls' copings rake down
from the front wall's height to a low end at the open back, each finished
with a carved kneeler. A buttress (the "pepper") juts from one side wall
near the front. A shallow step in the floor halfway runs across the
court. Moss in the corners, and a stone ball left in one.
Break kind: `wall` (KIND_OF gets `"fives_court":"wall"`); a hit topples
a run of side or front wall within the kind's reach. A side wall broken
low turns its rake into a stub walked on a clean top.
Behaviour: static. Knobs: `height` (the front wall, 2-3 WALL_HEIGHTs),
`rake` (the copings' fall, 26-38°), `splay` (how fast the side walls part
toward the back), `pepper` (on or off), `length`.
Size: at the front end the side walls stand KICK_GAP apart, so a jump at
one side wall kicks up between the two to their copings at the front.
They splay apart toward the back past KICK_GAP within about one KICK_GAP
of length, so kicks started further back carry him out into the court and
lose height, and the kick line is the front corner alone. The front step
ledge sits at GRAB_TOP over the floor, STAND deep, caught with one jump,
and a run along it is a shimmy-free walk. The pepper's top stands one
SET_OFF over the step ledge, STAND deep: the slow way up, step ledge to
pepper to the side coping's high end at CHAIN_TOP over the pepper. The
front wall's coping is TOP_ROOM wide (a walk across). The side copings
are STAND wide and rake at `rake`, over SLOPE_SLOW so walking up is slow
and under SLIDE_AUTO so he can stand on them: crouched, he boot-surfs
down at the slope's pull and comes off the kneeler at speed (a narrow,
steep surf, the balustrade's line). The court is long enough (about four
KICK_GAPs) that the surf's end flies him well clear of the open back.
With the wall run unlocked, the side walls' inner faces are long enough
for a WALLRUN_TIME run that ends at the step ledge. The court is too
narrow for the plane: no flown opening.
Collision: the side walls' inner faces are clean, true hulls (kick walls,
as the tower shell's). The front wall's face and the pepper are clean
hulls. The copings are clean walk boxes with true slopes along their rake
(so `_gradient` reads the slope, not a stair), each a lip both sides. The
step ledge and the pepper's top are true ledge boxes (`_stand_on`). The
floor step is under STEP_UP. The stone ball is a static prop (or a
`bearing_stone` if that piece is built).
Motifs it enables:
- A court at an isle's lip, its open back toward the gulf: the surf off
  the kneeler launches him over the drop to the next isle's turf.
- A row of courts stepping up a slope, each one's kneeler throwing him
  toward the next one's kick corner.
- A ruined abbey yard where the court is the quick way onto the cloister
  walk (its front wall shares the walk's height).
Catches / throws: standing, wall-kicking, wall-running and surfing are all
the motor's own; the piece only shapes them. A stunned body knocked into
the court rattles between the near walls and drops to the floor. A
twirl-armed tech kicks off any face, so a knocked pilot can tech straight
into the kick line. A body surfing a coping and steering off its side
falls into the court (inside) or off the isle (outside): the inside drop
is under the fall stun from the low half. It throws nothing itself; the
surf's pace is the slope's, capped by SLIDE_TOP.
Build cost: low. All procedural RuinKit Build walls, copings and
mouldings, with no new mechanics. The care is the rake (tuned so the surf
off the kneeler carries) and the splay (so the kick line is the front only),
proven by walking the loop with the real pilot. Connectors in
`ruin_kit_fit.gd`: `front_top` (the coping, meets a cloister walk or
`wall`) and `back` (the open end).
Model budget: silhouette geometry (the copings' broken ends, the kneelers
and the pepper's chipped arrises real). Parallax depth on the front wall
for its ball pits, the one face seen close and head-on. Vertex-colour
grime in the corners and under the step ledge. Import LODs (about 3k
triangles near, 800 far, about 2k saved a court past 70 m). Sculpt and
bake and rigid bones don't apply.

---

# Pergola Rafters (cloister_pergola, family cloister)
Verb: catch an overhead beam with one jump, climb onto the rafters, and
run and hop the beam tops up a terraced walk. A loose beam end springs
you higher, and a fallen beam is a ramp up or a surf down.
Look: a terraced pergola climbing a slope: paired rows of slender
octagonal stone posts, stone cross beams across each pair, and long
timber-shaped stone rails along the top. Wisteria and vine growth hangs
thick from it. Each bay steps up the hillside. Some cross beams have
dropped at one end and hang slanting from their post, and some rails
overshoot the last post as cantilevered ends. Under it runs a paved walk
with low steps.
Break kind: a registered cut, `"pergola"` (`Kinds.register`). A hit drops
the beams and rails within about one bay of it as `slab` parts and the hit
post as a `column`, and every other bay stands, its rails ending ragged
over the gap. (The built-in `pier` would topple the whole run; `lintel`
leaves no stand.)
Behaviour: static, except the cantilevered ends (`loose`). Each one sinks
and tips under him and springs back as he leaves it, a BobSlab's spring
(SINK, TILT, HZ) pivoted at its last post, so a jump timed on the
rebound goes higher (foot_pieces' existing rebound jump). The fallen beams
are fixed slopes. Knobs: `bays` (3-8), `step` (each bay's rise over the
last), `fallen` (beams hung slanting), `loose` (sprung ends), `growth`.
Size: the cross beams' soffits stand a BODY-plus-a-hand over the walk
under them (walked under upright), their tops a little under GRAB_TOP, so
one jump beside a beam catches its lip and he climbs onto it. The beams
are STAND deep (climbed onto, not walked along at a run). The rails
along the top are a STEP_UP over the beams (stepped onto), STAND wide,
and run the length of the bays: the rafter lane. Rails are missing in
places, the gaps between a running jump and a long jump. Each bay steps
up the slope by `step`, at most a SET_OFF, so the rafter lane climbs
with the walk: a hop up at each bay's end. A fallen beam rakes from its
rail end to the walk at 28-38°: run up it slowly (over SLOPE_SLOW) as a
way onto the rafters, or crouch and surf it down off the top. A sprung
end's rebound jump carries him about a pump past a plain jump, to a
higher bay's rail or to a lip beyond the pergola's end. The pergola is
too low for the plane: no flown opening, and it is never placed on an
isle's landing stretch.
Collision: the posts are clean hulls, slender (under a STAND across), so
walls are never read off them and no stray kick fires. The cross beams
and rails are clean walk boxes with true ledge tops (each a lip both
sides). The fallen beams are clean sloped walk boxes with true gradients.
Each sprung end is a moving body marked `moving_ground`. The growth is
not collided, and it counts as cover from above (the stealth's ray up).
Motifs it enables:
- A hillside garden isle: the paved walk is the slow way to the top
  terrace, the rafters the quick and playful way, and both end at a
  belvedere.
- A pergola bridging two terraces of a stepped mesa, its sprung end the
  only way to the upper lip.
- An overgrown cloister garth, the pergola as its walk round a tarn, and
  its fallen beams the surf into the water.
Catches / throws: standing and hanging are the motor's own. A standing
body on a sprung end is lurched down and up (BobSlab's give and rebound),
and a jump on the rebound keeps its rise (`frame_v`). A stunned body
knocked against a beam's lip can tech-catch it (twirl armed). A stunned
body falling onto the rafters lands on a rail or drops through a gap to
the walk, which is under the fall stun's height from the lowest rail, so
the pergola is a soft place to be knocked. It throws nothing beyond
BobSlab's rebound.
Build cost: low-med. The stone is procedural (Build blocks: octagonal
shafts, beams, rails, a paved walk, low steps). The sprung ends reuse
BobSlab's spring on a pivot rather than a float, which is the only new
motion. The growth is KitFlora and HangingRoots placed along the rails.
Connectors in `ruin_kit_fit.gd`: `foot` and `head` (the walk's two ends)
and `rail_end` (the rafter lane's top).
Model budget: import LODs with a visibility range on the hanging growth
(the growth is most of the triangles: about 4-6k of vine cards against
about 2k of stone; dropping the cards past about 45 m saves about 4k a
pergola and their alpha overdraw, perhaps 0.1 ms under it). Silhouette
geometry (the fallen beams' snapped ends, the posts' chipped capitals).
Vertex-colour grime (leaf litter and wet under the growth). Sculpt and
bake and parallax depth don't apply.

---

# Mason's Scaffold (works_scaffold, family works)
Verb: climb a timber scaffold lift by lift: catch board edges, pump past
missing boards, kick up the hoarded end bay, and surf a brace back down.
Swing off the hoist rope from the top.
Look: a new family, **works**, for the builders' leftovers: timber,
rope lashings and dressed blocks, never finished. A scaffold of round
standards in pairs, ledgers lashed across them, and putlogs run into holes
in a half-built (or half-mended) stone wall, with boards laid on the
putlogs at each lift. Diagonal braces cross the bays. Boards are missing
here and there, and one hangs by one end. The end bay is closed with a
hoarding (a boarded screen). At the top, a hoist jib leans out with a
rope and a bucket, and a stack of dressed blocks and a mallet sit on the
top lift where the masons stopped.
Break kind: a registered cut, `"scaffold"` (`Kinds.register`, toughness
low, about 0.3). A hit (a slam on a lift, the Olmec) drops the bay it
lands in, from that lift up: its boards and putlogs as `slab` parts, its
standards as `column` parts. The neighbouring bays stand, their boards
ending ragged over the gap. The timber parts lie as themselves (only
RuinKit stone merges into the rubble mesh). The wall behind is RuinKit
stone and stands.
Behaviour: static, except the hoist rope (a live SwingRope hung from the
jib, the piece's `ropes` meta) and, when broken, the break. Knobs:
`lifts` (2-5), `bays` (2-6), `missing` (boards gone), `hoarding` (the
kick bay, on or off), `hoist` (the rope, on or off), `finish` (how far
the wall behind is built: its top a lip above the top lift, or level with
it).
Size: each lift stands between GRAB_TOP and CHAIN_TOP over the last (about
2.2 m at wanderer 1.0), so from a board the next lift's edge needs the
pump, and the boards are TOP_ROOM wide, room for the hop and the pump.
The putlog ends standing out between lifts are chunky stubs, a STAND
long, one SET_OFF up from each board: the slow way, a jump to a stub and a
jump to the next lift. A missing board leaves a gap between a running
jump and a long jump (LONG_SPEED's carry) along its lift. The hoarded end
bay stands KICK_GAP off the wall, two or three lifts tall, so a jump at
the wall kicks up between wall and hoarding past the lifts. The braces
cross each bay at 28-36°, STAND wide: run up slowly or crouch-surf down,
lift to lift, the fast way down. The hanging board rakes about 40°, a
steep surf or a lip at its high end. The hoist rope hangs from the jib
with its knot at SwingRope.KNOT over the top lift, so a run along the top
lift takes it, and a timed release throws him out over whatever the
scaffold faces. No flown opening (the jib stays clear of any flown line).
Collision: boards, putlog stubs and the top lift are clean walk boxes
with true ledge tops (`_stand_on`), each board edge a lip. The braces and
the hanging board are clean sloped walk boxes with true gradients. The
wall behind and the hoarding's inner face are clean, true hulls (kick
walls). The standards are thin hulls that only stop him, under a STAND
across so no wall is read off them. The hoist rope collides only through
its catch, as every SwingRope.
Motifs it enables:
- A half-mended chapel on any isle: the scaffold is the way up to its
  roof walk, and the hoist rope throws you onward to a floating stone.
- A tower being rebuilt: scaffold round two faces, and the wall behind
  finished higher than the top lift, so the last move is a pump to the
  wall's own lip.
- Underground, in the Olmec city: the builders' scaffold against an
  unfinished pyramid tier or a stela still being carved (below).
Catches / throws: standing, hanging and kicking are the motor's own. The
hoist rope catches, carries and throws as SwingRope does (its `toss`,
source the rope), and it snags a stunned body knocked past it. A stunned
body knocked off a lift falls past the board edges below; a twirl-armed
tech catches one. A body on a bay when it breaks rides the falling boards
down (the fall's bodies as ground for that moment) and is laid down by the
fall stun only from the top lifts. It throws nothing else.
Second home, the Olmec city: built in the city's dark, smoke-blackened
timber with rope lashings, against the city's basalt (scripts/
city_kit_stone.gd) at an unfinished tier, joined to the `city` family as
the city kit joins its climb pieces (`CityClimb.PIECES`). Its boards,
stubs and braces are walker-only (`WalkerOnly.mark`): the Olmec never
plans onto it, so it is her lane up beside his stair (a pair to
`city_terrace` and `city_riser`). It is not a safe room for long,
though: his landing within reach of a bay is a hub hit (source `olmec`),
and that bay comes down from the lift he shook up. Her line up loses a
bay, so the next lift is a long jump or the kick bay. The fallen boards
lie as walker-only debris and never make him a ramp. Cressets on the
top lift are the city's fires (`mounts`), so the scaffold reads in the
dark.
Build cost: med. The geometry is procedural (cylinders, boards and
lashing bands, with a timber material new to the kit; the wall is RuinKit
or city stone). The work is the registered cut (bays and lifts as parts),
the `ropes` meta spawning the hoist rope (round 2's engine gap), and, for
the city, walker-only marks plus his landing reaching the hub as a hit.
Connectors in `ruin_kit_fit.gd`: `wall_face` (it stands against any
`wall`, `tower_shell` or `lancet_wall` face) and `top_lift`.
Model budget: silhouette geometry (round standards as 6-sided prisms,
lashings as thin bands, the boards' split ends real, grain from texture).
Import LODs with a visibility range on the lashings, bucket, mallet and
rope (drop them past about 40 m; about 1k triangles saved of a 3-5k
scaffold). Vertex-colour grime (mortar splashes on the lower boards, soot
in the city version). Rigid parts on bones don't apply (the broken parts
are physics bodies, not skinned). Sculpt and bake doesn't pay.

---

## Combines with

- **aqueduct_spouts**: `aqueduct_end` and `aqueduct_broken` (its channel
  top), the sluice trap upstream (`fed`), `pent_hood` beside the basin as
  cover from the spray, `fallen_pier` in the pool as stepping stones.
- **fives_court**: the cloister arcade's wall-walk at its front wall's
  height, `stairs` up the outside of a side wall, `stone_circle` or
  `tomb_chest` in the yard round it, floating stones off the kneelers.
- **cloister_pergola**: `stairs` and `grand_stair` as its walk's flights,
  the lavabo or a `stone_circle` at its head, a tarn or `drift` stones off
  a fallen beam's surf, `pent_hood` beside it (cover over cover).
- **works_scaffold**: `wall`, `lancet_wall`, `tower_shell`, `rose_gable`
  (being mended), `tomb_chest` and `floor` blocks as the masons' stack;
  in the city, `city_stair` and `city_terrace` beside it as his lane.

## Engine gaps

- **A slip that leaves catches open** (`aqueduct_spouts`). A let-go now
  starts REGRAB, which blocks the catch on the lip a SET_OFF below
  (falling one SET_OFF takes less than REGRAB). The piece needs a let-go
  that leaves other lips catchable, and a "stream" volume that applies it
  to a hanging body (and a downward push to an airborne one).
- **A trap's signal read by a piece** (`aqueduct_spouts` `fed`): the
  sluice has no flood signal another piece listens to. (Round 2's tally
  item 5, triggers between pieces.)
- **Ropes as part of a piece** (`works_scaffold`'s hoist): still round 2's
  gap; nothing generic spawns a placed piece's `ropes` meta.
- **A pivoted spring** (`cloister_pergola`'s loose ends): BobSlab floats
  and tips; a beam end sprung about a fixed pivot is its spring on a
  hinge. Small, but checked through the motor's `mover` on a tipping top.
- **Thin hulls that aren't walls** (pergola posts, scaffold standards):
  a tall slender collider may answer `wall` and fire a kick. Each piece
  needs a way to mark a collider "stops him, not kicked" (a group or
  layer the wall probe skips), unless the probe already ignores slender
  shapes.
- **His landing as a hit** (the scaffold's city home): the Olmec's
  landing must reach the breakables hub as a hit near walker-only pieces;
  the city's round-2 breaks (maker_skin, maker_chock) already do it for
  their own pieces, so this is a hookup, not new work.
- **The editor**: the spouts' cycle phase and the pergola's sprung ends
  are state the recipe must save (round 2's tally item 1). Fives court and
  the scaffold's static parts place today.
