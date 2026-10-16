# Kit round 2, k1: grab / climb

Lenses: verb climb; scale colossal or a fragment of something bigger; mood sacred.

A proposed new family, **relic**: pieces of colossal sacred works (a gate, a
censer, a votive figure, a halo) of which only one part still stands, in the
ruin kit's pale stone and growth (RuinKit Build, `ruin_stone.gdshader`),
not the city's basalt. They would sit in `RuinKit.FAMILIES` as
`"relic": RELIC_PIECES`, so the motif editor's palette lists them under
"Relic", with connectors in `scripts/ruin_kit_fit.gd`.

Names for sizes below: `GRAB_TOP` (one jump's catch), `CHAIN_TOP` (the
pump's catch), `SET_OFF` (the rise between standing places on a climbing
route), `STAND` (the least tread for a climb), `TOP_ROOM` (a walkable top),
all RuinKit; `KICK_GAP` (RuinKitTower: two walls kicked between);
`SwingRope.LENGTH`, `SwingRope.KNOT`; `WorldScale.opening(toy)`,
`WorldScale.SNUG`; motor constants by their PilotMotor names.

Existing colossal figures (gb_sunken_giant's hand and torso, gb_face's
seated lord, the Olmec) are motif stand-ins in basalt. None of the pieces
below is a hand, a face or a whole figure, so they don't repeat those.

---

# The Prayer Lintel (relic_torana, family relic)
Verb: climb by rope. Run in, swing, let go rising, catch the next rope, and
go up a chain of ropes hung under a lintel that tilts up out over the gulf,
until a release lands you on the lintel's top.
Look: what's left of a colossal gate. One square jamb stands on the isle's
lip, carved with a column of shallow votive niches. Its lintel, a long
coursed beam with corbelled tiers, snapped off the far jamb and settled
tilted, rising as it reaches out over the drop. The far jamb is rubble far
below, or gone. Prayer ropes hang from iron rings set into its soffit, each
with a weathered cloth tag (SwingRope `add_tag`), and a bronze bell on the
last knot. Growth hangs off the soffit between the ropes.
Behaviour: the stone is static. The ropes are live SwingRopes (pendulum,
pump, timed release, snag). The bell rings on every catch of the last rope
(a cue only). Knobs: `ropes` (3-5), `tilt` (how much each rope's knot rises
over the last), `weathered` (a rope gone dry: it snaps on the catch and
throws him on, so the chain has a gap and you must twirl to the one past
it).
Size: rope 1 hangs over the turf, its knot at SwingRope.KNOT, so a run
takes it (RUN_IN). Each rope after it hangs from a soffit ring one SET_OFF
higher (the lintel's tilt), its length shortened to keep the knot under
the soffit, never under about half SwingRope.LENGTH so the swing still
launches. Ropes hang about one SwingRope.LENGTH apart along the lintel.
The swing's own arc (under MOST) nearly carries the hands to the next rope,
so any release catches it and a perfectly timed one overshoots. The mistake
it teaches is too much, fixed with a twirl back (TWIRL_BACK). The lintel's
top is TOP_ROOM wide. Its outer end stands about SET_OFF under where a
well-timed release from the last rope peaks, so a good release lands you on
top. A poor one meets the lintel's face, which has a lip at its top edge
(STAND deep), caught as you fall past. The jamb's niches are SET_OFF apart
up its face, each a ledge STAND deep: the slow way up to the lintel's root
without ropes. Under the lintel, between jamb and drop, an opening of
WorldScale.opening(RuinKit.TOY_THREAD) lets the plane thread the gate.
Collision: the jamb and lintel are clean boxes. The lintel's top is a
walk box. The niche sills and the lintel's outer lip are true ledge boxes
with a top to stand on (`_stand_on`). The jamb's faces are wall-kickable
hulls. The ropes collide only through the rope catch, never the plane.
Motifs it enables:
- A rope causeway: two isles joined only by a tilted lintel's ropes, the
  far isle higher.
- A pilgrim's ascent: tiers of lintels, each one's top the next one's
  run-in.
- A gulf of the fallen: ropes hung where a trap's knocks throw you, so the
  sacred ropes catch the stunned.
Catches / throws: running or airborne, a rope takes him (its catch). A
tumbling or stunned body knocked past a rope is snagged (SwingRope SNAG):
he swings limp until he gets his poise back, so a knock off the jamb or the
lintel is often saved. Released, a rope throws him along its swing (up to
SwingRope.TOP, POP up) through its `toss`; the source is the rope. A dry
rope snaps on the catch and throws him on, stunned if he was.
Build cost: low-med. The stone is procedural from RuinKit Build blocks (a
pier, a coursed beam, corbel tiers), and the ropes are the existing
SwingRope. The work is the piece carrying its ropes as meta (`ropes`:
[{anchor, length}], as city_court and gb_sunken_giant already pass them)
and a host spawning them into FootPieces.
Model budget: silhouette geometry (the snapped end and corbel chips real,
the courses' faces flat). Vertex-colour grime under the soffit and in the
niches. Import LODs with a visibility range on the ropes and tags (drop
them past about 60 m; the lintel stays). Parallax depth is not worth it.
Roughly 2-4k triangles of stone. Ropes and tags are the cost: about 300
each, so a 5-rope lintel saves about 1.5k triangles and a draw call or two
past range.

---

# The Censer Well (relic_censer, family relic)
Verb: climb by sail. Open the pocket sail in the censer's rising smoke,
ride it up the bowl to ledges and out of the crown. In a lull, kick up the
neck instead. A slam on the coals stokes it.
Look: a colossal stone censer on three clawed legs. It has a deep bowl with
a moulded rim band and a pierced dome lid, cracked and slid half off, with
quatrefoil holes all round it. A narrow neck rises to a crown ring. Cold
incense still smoulders on the coal bed at the bowl's foot, and a pale
smoke column (SkyCurrents' wisps, smoke-toned) rises through the dome and
out of the crown. The half-slid lid leaves a crescent of open sky on one
side.
Behaviour: changes state on a cycle and on a trigger. The smoke breathes,
as if swung by an unseen hand: it swells for BREATH_IN seconds (thermal
lift past the sail's sink, `thermal` ridden) and lulls for BREATH_OUT
seconds (thermal under the sink, so the sail only slows its fall). A
slam (scripts/slam.gd) on the coal bed stokes it, holding a full swell for
STOKE seconds with a ring puff off the coals. The slam spends nothing, so
any drop into the bowl can stoke it. Knobs: `breath` (the cycle's
seconds), `lid` (how far it slid: how much crescent is open), `neck`
(height in SET_OFFs).
Size: the legs' claw feet and knees are SET_OFF steps up to the rim band
(about four SET_OFFs from the turf). The rim band's top is TOP_ROOM wide,
walked right round. Inside, the bowl is wide enough to circle in the sail
(several TOP_ROOMs across, so a turning sail clears its wall). Up its
inner wall, corbel rings stand every two to three SET_OFFs, each STAND
deep with gaps in it. They are over CHAIN_TOP apart, so no ring is jumped
to from the one below: the thermal or nothing. The quatrefoils' sills are
lips both sides of the thin dome wall, caught from the smoke or from
outside. The neck's bore is KICK_GAP, so in a lull it is the tower shell's
kick chimney. The thermal's top sits a SET_OFF over the crown ring and no
higher, and the lift ends there (the thermal climbs with no ceiling, so
the piece must give it one). Out of the crown you come onto the slid lid's
top, a perch, or into the open crescent to sail away.
Collision: the legs, rim band and rings are clean boxes. The dome wall is
convex facet hulls with true ledge boxes at each quatrefoil sill. The
neck's bore walls are clean, true hulls (kicked on, as RuinKitTower's kick
walls). The coal bed is a walk box in the slam's group. The smoke is not
collided.
Motifs it enables:
- A temple court whose one way up to the high isle is the censer, in time
  with its breath.
- A string of censers across a gulf, sailed from crown to crown, each
  thermal holding you up just long enough.
- A vigil yard: censers lit one at a time by slams, each opening a higher
  perch.
Catches / throws: an open sail in the column rises (thermal). A body
falling, standing or stunned is not carried (the smoke holds only the
sail). A stunned body knocked into the bowl falls to the coal bed, which
is a soft cushion of ash (`soft_ground`, `catch` sized so the bowl's own
drop doesn't stun), so the bowl is a safe pit. A wall-kicking body in the
neck kicks as in the tower. It throws nothing itself. The stoke's puff is
cosmetic and never knocks.
Build cost: med. The stone is procedural (RuinKit Build: rings, facets, a
lathe of courses for bowl and dome, the tower's kick walls for the neck).
The breath needs a thermal whose lift changes over time. The real cost is
plumbing: the piece's thermal reaching the motor on foot (Engine gaps).
Model budget: silhouette geometry (the lid's crack and slid edge, the
quatrefoils cut through, not textured). Vertex-colour grime (soot down
from the quatrefoils and round the crown). Parallax depth on the bowl's
inner face for soot-pitted stone (seen close, from inside, in the sail).
Import LODs: the pierced dome is the heavy part; its far LOD closes the
quatrefoils to dark decals. About 5-7k triangles near, 1.5k far. Closing
the holes saves about 3k triangles a censer past 80 m, which counts in a
string of them.

---

# The Bowing Votary (relic_votary, family relic)
Verb: climb by being carried. Catch the votary's diadem while it bows low,
hang on as it rises upright, and let go at the top onto a terrace too high
to climb, or ride its rise into a jump.
Look: a fragment of a colossal kneeling figure, the torso from the hips
up, arms lost at the shoulders, head bowed. It is set on a stone pivot
drum at its hips on a low terrace at the foot of a sheer step. Its crown
is a carved diadem band. Its back and shoulders are broad, worn smooth
where something used to stand. Moss grows on the shoulders, and the
pivot's grooves are polished from turning.
Behaviour: moves on a fixed cycle (an AnimatableBody3D marked
`moving_ground`): it bows down over BOW seconds, holds low for HOLD_LOW,
rises upright over RISE (slow, eased), holds up for HOLD_UP, and repeats.
It has no trigger. It keeps time, so you learn its rhythm. Knobs: `rise`
(the high terrace's height in SET_OFFs), `cycle` (the four times), `phase`
(so two votaries side by side bow out of step).
Size: the high terrace stands `rise` SET_OFFs over the low one (default
4, always over CHAIN_TOP), its face sheer and unkickable, with no lip
under its top. Bowed low, the diadem's lip is at GRAB_TOP over the low
terrace, caught by one jump. Upright, the diadem's lip is level with the
high terrace's lip, with a STAND-deep gap (closed by a plain hop off the
hang, or by shimmying round the diadem to its side and climbing on). The
back, bowed, is a ramp under SLIDE_AUTO, walked up from the low terrace
onto the shoulders. Upright, the back stands vertical. The figure's height
from pivot to crown comes from the bow's arc: the crown moves `rise`
SET_OFFs plus GRAB_TOP through about 60 degrees. The shoulders' top is
TOP_ROOM across.
Collision: the body is clean boxes on the moving body: the back plates,
the shoulder top (walked), and the diadem as a true ledge ring with a
STAND-deep top (`_stand_on`) whose lip stays within the motor's grab
facing through the bow. The pivot drum is static. The low terrace under
the bowed head has a marked "crush" zone.
Motifs it enables:
- A shrine stair of votaries, each one's high terrace the next one's low
  one, bowing in a wave you climb in time.
- A court of votaries bowing out of phase round a high altar, read from
  the ground before you commit.
- A cliff isle whose only way up the sheer face is the votary. Once up,
  the plane is parked on top.
Catches / throws: a hanging body is carried (`mover`, hanging from it).
A standing one is carried on the shoulders and back. Let go or jumped off
during the rise, he keeps its motion (`frame_v`: the rise added to his
jump), so a jump at the top of the rise flings him higher than the
terrace, an over-the-top launch onto a further ledge. A body stood on the
head as it bows is lurched down and forward, never knocked. A body under
the head as it comes down (the crush zone, standing, tumbling or stunned)
is knocked back out along the terrace: a short low `knock` (source
"votary"), never into the drop. The restun gap keeps it from pinning a
body that stays.
Build cost: high. It needs a Blender model (a sculpted torso and head,
baked low), a moving body on a timed cycle, moving ground carrying both
standing and hanging bodies through a rotation (the hang's lip turns as it
rises), and a knock zone. It's physics and feel, so an Opus round.
Model budget: sculpt high, bake low (the figure's drapery and face: a
dense sculpt baked to about 8-10k triangles with normal, AO and curvature
maps). Rigid parts on bones don't apply: it is one rigid body, transformed
whole, never skinned, which is the saving: no skinning cost. Vertex-colour
grime in the drapery folds. Import LODs: 10k near, 3k mid, 800 far. A pair
of votaries in view saves about 14k triangles past 60 m against the near
mesh.

---

# The Broken Nimbus (relic_nimbus, family relic)
Verb: climb a ring. Shimmy up its rim where the curve is gentle, chain its
sunray ledges where it steepens, surf its inner trough to launch up the
far side, and leap the broken crown from horn to horn. Spend a flow charge
built on the ring to reach the high horn.
Look: a colossal stone halo, the nimbus of a statue long gone (only the
halo stands), set on edge in the turf and broken at the crown into two
horns of unequal height. Its front face carries a moulded rim band right
round its outer edge. Inside it, carved sunrays run from the inner edge
toward the centre, broken off at varying lengths, so their stubs project
inward like spokes. The inner surface is smooth and worn into a trough at
the bottom. It faces the sunrise (an `orient` knob), so the dawn light
comes through the ring.
Behaviour: static. Knobs: `radius`, `gap` (the crown break's width),
`horns` (how unequal the two horns are), `rays` (how many ray stubs stand
unbroken).
Size: the ring band is TOP_ROOM deep front to back, so its outer top is
walked on the low arcs. Where the outer curve rises past SLOPE_SLOW you
slow, and past SLIDE_AUTO you surf back down, so you can't run it all.
The rim band's lip runs right round. Hanging on it, the shimmy follows the
curve up to SHIMMY_SLOPE (about 45 degrees along) and stops there. Over
that, where the arcs steepen to the horns, the ray stubs on the inner edge
are ledges one SET_OFF apart, STAND deep. The radius is large enough that
the curvature stays under the hang's CURL_MOST and the inner face reads as
a wall along the run within WALLRUN_GLANCE (several KICK_GAPs). The inner
trough at the bottom is steeper than SLIDE_AUTO at its sides and flat at
its floor, a half-pipe: surf down one side, slide-jump up the other onto
the lowest ray. The crown gap is over a pump's carry and under a twirled
long jump's, so the leap from the low horn to the high one needs the
twirl. The high horn's tip is over anything the rays chain to by
CHAIN_TOP, so it is reached by the leap or by the updraft (flow charge)
spent from the low horn. The ring's inner opening is at least
WorldScale.opening(TOY_THREAD) at every height the plane can pass, so the
plane flies through the halo, and the crown gap is at least WorldScale.SNUG
past each wingtip if it is meant to be threaded.
Collision: the outer top and the trough are clean, faceted walk boxes
(one per arc step, true slopes so the motor reads its gradient, not a
staircase). The rim band's lip is a chain of true ledge boxes along the
arc with a STAND-deep top. The ray stubs are boxes, each a ledge with a
top. The inner face is clean, true facet hulls, kickable and wall-run.
The horn tips are perch tops.
Motifs it enables:
- A halo isle: a single nimbus on a bare knoll, its high horn the perch
  over the landing strip.
- Two halos interlocked at right angles (a sphere's armature), the inner
  troughs crossing, routes swapping between rings.
- A sunrise court: a row of nimbi of growing size, each high horn the
  next one's low horn.
Catches / throws: standing (walks the low arcs, surfs back down the steep
ones), hanging (the rim band, the rays), sliding (the trough sends him up
the far side at the pace he brought), wall run (the inner face, if
unlocked). Flow builds from the slide, the slide jump, the kicks and the
twirl, so a lap of the ring charges the updraft. A tumbling or stunned
body that falls inside slides down the trough to its floor and comes to
rest (a cradle, no further fall). It throws nothing; the half-pipe returns
pace, it adds none (the motor's caps hold).
Build cost: med. It's procedural: arc segments from RuinKit Build blocks,
ray stubs as broken piers, and the walk and ledge boxes generated along
the arc. No physics. The care is tuning the arc so the shimmy, the surf
and the wall run each take over where they should, proven through the
real play loop.
Model budget: silhouette geometry (the crown break and ray stubs real,
the band's moulding as geometry only on its outer profile). Vertex-colour
grime in the trough and under the rays. Import LODs: the ring is long and
seen from far, so its LOD drops the rays' facets and the moulding (about
6k triangles near, 1.2k far, saving about 5k past 100 m). Parallax depth on
the inner face for its worn ray-carving where the rays broke off, seen
close in the wall run.

---

## Combines with

- **relic_torana**: `aqueduct_stump` and `aqueduct_end` (its root on the
  jamb side), `stairs` or `grand_stair` up to the jamb's foot, the
  cloister's rope-bridge heads (a rope bridge onward from the lintel's
  top), `stone_circle` (a gate into a ring), `fallen_pier` as the far
  jamb's rubble below.
- **relic_censer**: `tower_shell` (the same kick chimney, side by side as
  the quick and the slow way), `stone_circle` (censers in a ring),
  `lavabo` (the cloister's pavilion as the court it stands in), `tomb_chest`
  and `floor` round its feet, `wind_horn` (its gust across the column).
- **relic_votary**: KitLand cliffs as its low and high terraces (a step
  over CHAIN_TOP), `buttress` beside it as the long climbing way round,
  `vault` or `hall_bay` on the high terrace, seesaw or tumble traps on the
  low terrace timed against the bow.
- **relic_nimbus**: `stone_circle` (a halo over a henge), `grand_stair`
  up to its foot, floating/bob stones across the crown gap as an easier
  line, swing ropes hung from its high horn, `hall_column` stumps where
  the statue stood.

## Engine gaps

- **Piece-carried thermals on foot.** No kit piece can give the motor's
  `air` a thermal. `wanderer_eye._walker_air` reads only the sky's air,
  gated on `islands` and `glide_enabled`, and only layer_hazards.gd wires
  SkyCurrents.add_thermal into `motor.air` (for the viaduct). relic_censer
  needs a piece meta (`thermals`: [{base, top, radius}]) that the motif
  yard, kit isles and editor read into one SkyCurrents, plus a lift that
  changes over time (add_thermal takes a fixed `lift`) for the breath.
- **Ropes as part of a piece.** Swing ropes are FootPieces, placed by
  each motif. city_court and gb_sunken_giant pass `ropes` meta, but
  nothing generic (the editor's motif_authored.gd) spawns a placed
  piece's ropes. relic_torana and relic_nimbus need it.
- **A rotating hang.** `mover` carries a hang from a moving body, but the
  only movers so far translate or tilt a little (slabs, the serpent). A
  lip turning through about 60 degrees (relic_votary) needs the ledge
  finder and GRAB_FACING checked on a rotating lip, and the climb-on
  (`_stand_on`) on a top that is no longer level.
- **Wall run on a curve.** The wall run reads a wall along his way at a
  glance. A faceted concave ring (relic_nimbus) is untested; facets
  may break the run at each joint.
- **The editor and moving or stateful pieces.** The palette builds a
  piece from (id, seed, settings). A cycle's phase (votary) and a breath's
  phase (censer) need to be settings saved in the recipe, so a saved
  motif replays in step.
