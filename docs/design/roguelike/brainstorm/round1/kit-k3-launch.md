# Kit K3: things that launch or carry the pilot, UP

Brainstorm, round 1 (motif-brief.md, Kit piece cards). Theme: launchers and
carriers that make a vertical stack of isles traversable, and that are the
spine of the chain.

**How these change what a layer can be shaped like.** Every edge the
generator knows today (scripts/roguelike/layer_plan.gd: stones, bridge, trap,
hard, climb, gulf with serpent/ferry/cannon) runs *across*: a corridor laid
flat from a rim out to a rim, and even the `tier` knob's `climb` edge only
gains a few metres by stepping stones up at the footbridge's grade. So a layer
is always a spread of isles at roughly one height, and the rule "an isle may
stand over another, never in it" is only ever used by accident. Each piece
below is a *vertical edge*: its corridor is a column, not a lane, so the next
isle can be stood straight up (offset mostly in y, its flat offset inside the
piece's reach) over an arena of the one below. That gives the generator a new
layer shape, **the stack**: a neighbourhood of two or three tiers, isles over
isles, the exit high above the base instead of across a gulf. It also changes
what failure costs: a missed launch or a lost ride lands on the tier below
(the soft fall the plan already favours, "over another isle"), so the stack
can be harder per step than a spread without being crueller. And because a
stack puts many launchers within a throw of each other, it is where chains
happen: each piece below says what it catches (including a tumbling body)
and what it throws, and has an aim the generator sets (an aim knob inside the
piece, never a turned isle) so it can point one link at the next. Four of the
five are the makers' own (the Olmec's basalt, a new `maker` family filling the
kit's style gap), and they all run on *breath*: the heads did not only
inhale; the isles were breathed aloft, and some of the old lungs still work.

**A chain through a stack, as the generator could aim it** (every link a
different source, so each may stun afresh; `restun_gap` 1.2 s only stops one
source re-stunning, keyed per instance, so two wells are two sources):
an inhaler head gulps him and blasts him off the low tier (`knock`, stunned)
→ he tumbles into a Breath Well's exhaling column, which juggles the limp
body up (a shove, no new stun) → past `stun_chain_cap` 3 s, or with his
poise back, he twirls out and opens the sail and rides the thermal → off its
top he sails into a Gullet window, is carried up, spat from the top mouth
(`toss`, in control) → lands on a Root Sling's pad, which fires on the hard
landing → flung to the Calendar Wheel's top slab, hop to the exit tier. By
accident it is a comedy of bounces that still ends higher; on purpose it is
the fastest way up the layer.

Pilot numbers used below (scripts/pilot_motor.gd, scripts/pocket_sail.gd,
scripts/updraft.gd, scripts/ruin_kit.gd, stun-round1.md): small jump 0.8 m,
chain 1.5 m; GRAB_TOP 1.875 m, CHAIN_TOP 2.575 m; gravity 26 m/s² rising (a
rise of h needs sqrt(52 h) m/s: 10 m is 22.8 m/s); wall kick 1.4 m up and 5.2
m/s out; sail PACE 5.5 m/s, TURN 2.4 rad/s (a turn radius of about 2.3 m),
SINK 1.5; a thermal climbs the sail up to THERMAL_MOST 5 m/s with no ceiling;
the updraft lifts up to 7 m at full charge, and the slam cashes height in as
impact; the fall stun from 6 m; `poise_for(v)` 0.5 s + 0.04 s per m/s, at most
1.2 s. Launchers go through `PilotMotor.toss` (fresh airtime, sail ready; a
stunned body stays stunned with a fresh poise) or `knock(v, source)` (stuns,
the piece itself the source), riders through `motor.carry` (as the ram and the
inhaler's pull do), air through the motor's `air` ({wind, thermal}, as
trap_wind.gd's `air_at`). All of these are walker-sized; nothing here is flown
by the plane, so `WorldScale.opening` does not apply (the sizes come from the
wanderer: `PilotMotor.set_size`, RuinKit's GRAB_TOP/CHAIN_TOP, KitMotif
`pilot()`).

---

# Breath Well (breath_well, family maker)
Verb: ride (sail up a column of breath); time it to the exhale.
Look: a colossal Olmec face lying on its back, sunk to the cheekbones in the
isle's turf, the inhaler head's own kin and its own weathered basalt
(shaders/olmec_stone.gdshader, `weather` 1.0): squared masonry brow, heavy
lids shut, the mouth a round dark well pointing at the sky. Moss in the lip
creases, roots fingering into the nostrils, a ring of flattened grass round
it. Above, the upper isle's underside is stained pale where the breath has
scoured it for centuries. Beside the hovering heads it reads as "one that
fell and kept breathing".
Behaviour: changes state on a slow cycle, `exhale` / `hold` / `inhale`:
- exhale (`exhale` 6 s): a thermal column `thermal` 3.25 units (the sail
  climbs at its full 5 m/s) from the mouth to `top` (the upper rim's lip
  plus 3 m, so he crests and sails in). Dust, leaves and the inhaler's
  streak ribbons (scripts/enemies/inhaler_head_air.gd, run backwards) spiral
  up it; the grass leans out from the mouth.
- hold (`hold` 1 s): the column dies away from the bottom up (the tell: the
  lids twitch, the streaks stall and hang).
- inhale (`inhale` 3 s): the column reverses, `wind.y` under 0 (the sail's
  downwash path: it takes the lift away and presses him down), and near the
  mouth the inhaler head's pull (`pull_at`'s falloff, aimed up the column).
On foot by the mouth during an exhale he is only buffeted; jumping in and
opening the sail rides it.
Size: column radius twice the sail's turn radius (about 5 m) so he can
circle in it while it climbs; mouth opening 3 m (two and a half of his
heights: the gulp must read). A ride of `exhale` 6 s at 5 m/s is a 30 m tier;
`top` sets it. The walkable rim round the mouth is a band at least his run-up
wide (KitMotif run_up, about 3.6 m).
Collision: the face is clean boxes: forehead and cheeks walked (gentle
slopes under SLIDE_FROM), the brow's edge a ledge under GRAB_TOP, the nose a
wall-kickable block. The mouth's throat has no floor (a hull ring round it,
open down to a stop 6 m under the lip, so the gulp has somewhere to be).
Motifs it enables:
- The Lung Stack: three tiers each with its well, the top tier's well blowing
  past the exit gate; the whole neighbourhood breathes on one shared cycle,
  so the climb is a rhythm.
- A drowned well: a tarn in its mouth, bubbling on the exhale, the thermal
  only rising when the water is blown out (a sluice cousin).
- Under a hanging underside (hollow_keel-like): the well blows up into the
  undercroft through a slot in the plate.
Threat pairing: the inhale is the inhaler head's breath without a head to
dodge: caught low in the column he is pressed down into the pull, gulped
(PilotMotor `seize`, the figure hidden, the face's cheeks bulging) and
blasted out (`knock`, stunned). By design that is also the fastest way up:
a bold player dives into the inhale on purpose to be spat at the next link
in a tumble, trusting the generator's aim.
Catches / throws:
- standing on the face: buffeted on the exhale (a sideways shove off the
  mouth, `motor.carry`); on the inhale pulled toward the mouth as by a head
  (crouch braces); reaching the mouth, gulped.
- airborne, sail open: the thermal (exhale) or the downwash (inhale), the
  sail's own air.
- airborne, sail shut, in control: the exhale slows his fall to `cushion`
  (the sail's SINK x 2) over the mouth, a soft landing however far he fell
  (the fall stun's measure restarts in the column, as the sail restarts it).
- tumbling / stunned: the exhale juggles the limp body up the column (an
  upward shove `lift_body` 6 m/s in `before`, as the wind trap shoves a
  tumbling body: a ragdoll rising like a leaf), never a new stun; when his
  poise returns, or at `stun_chain_cap`, he twirls out and opens the sail in
  the thermal. The inhale catches any body in the column, stunned or not, and
  gulps it.
- riding: none (a rider passing over, on the wheel, is only buffeted).
- throws: the blast after the gulp, `knock(v, well)`: out along the aim at
  `spit` (enough for the aimed landing: about 16-22 m/s for a 10-15 m rise
  and 10 m across), stunned for `poise_for(v)` (about 1.2 s, the cap). The
  exhale's top throws nothing: he leaves it under the sail, in control.
- aim: `spit_yaw` and `spit_pitch` knobs (the generator sets them toward the
  next link; it never turns the isle, only the blast's lean, from straight up
  to 45 degrees off it); the cheeks and brow carve a groove the way it leans,
  so a reader can see where it spits.
Chains with: from an inhaler head's blast or the wind blaster's knock (a
body thrown into the column is juggled up); from the Plinth Ram's charge off
a rim above (falls into the column, cushioned); into a Root Sling's pad, a
Gullet window or a Seesaw's high end (the spit aimed there); with an inhaler
head over it, two breaths fighting: a head's draw across the column tips a
rising sailor out of the thermal. Spitting into another Breath Well is a
chain: each well is its own source.
Edge kind: **"breath"** (vertical: from an arena socket on the lower isle to
a rim of the upper whose lip lies within the column's radius plus a sail
glide of 2 s, facing back over the well).
Build cost: **med-high.** A new Blender model (a face, not the head: no rig,
only the lids and cheek bulge as two shape keys or rigid parts), reusing the
head's look script, the stone shader and the air visuals. The air is cheap:
the thermal and downwash already go through `air`; the pull and gulp/blast
are inhaler_head.gd's, lifted into a shared helper. The aimed spit needs a
`landing_for` (as the cannon's) so the generator can place it.
Model budget: sculpt high, bake low (the face is the hero: 8-12k triangles
with baked normal/AO, versus 40k+ sculpted, about 0.2 ms saved per well on
the draw); import LODs (a well is seen from the tier above and below: LOD1 at
30 m, LOD2 at 80 m, roughly 70 % fewer triangles at range); vertex-colour
grime (the shader already reads baked occlusion from vertex alpha); parallax
depth for the lip creases and nostril cracks (no geometry, maybe 1-2k
triangles spared). Rigid parts on bones: not needed (no skeleton).

---

# Root Sling (root_sling, family growth)
Verb: launch; land on it, or slam it for the full fling.
Look: a root as thick as his body grown out of a split maker stele, bent
down in a long bow and held under a stone collar (a broken Olmec jaw, its
teeth gripping the root). At its tip a cupped knot of root and moss, the pad.
Leaves along the bow; old rope and rune-pegs show someone once trained it.
It leans toward where it throws, like a sapling toward light.
Behaviour: launches. A spring along a fixed arc, stepped by plain maths as
the sail is:
- landed on: the pad sags under him (squash, anticipation) and rebounds;
  a jump at the bottom of the sag (a `bounce` window, 0.15 s, the jump buffer)
  tosses him up `pop` (the chain jump plus 2 m, about 3.5 m). No jump, it
  just bobs him.
- slammed (scripts/slam.gd), or landed on hard (a fall past the fall stun's
  6 m): the collar's teeth let go, the root whips fully and he is thrown
  along its lean, rise = `rise_base` plus `keep` 0.8 of the height he fell,
  capped at `rise_top`. So the updraft then slam combo, which gains nothing
  on its own, becomes height here: the one place flow turns into altitude.
- follow-through: after a fling the root overshoots past rest and thrashes
  back down for `settle` 1.2 s, then the collar bites again (re-armed).
Size: pad a disc of 1.6 m (two stances), the bow 6-8 m long, rest height of
the pad CHAIN_TOP over its foot (so it is boarded with a chain jump or
dropped onto from above). `rise_top` sized per placement from the target:
the generator asks the sling for a `landing_for` as it asks the cannon.
Collision: the pad is a moving clean box (AnimatableBody3D) carried along
the bow; the bow itself has a thin capsule chain he can land on and run up
(a rail-slide ramp to the pad at rest); the stele and collar are static
kit boxes, the collar's top a ledge under GRAB_TOP.
Motifs it enables:
- The Overgrown Ballcourt: sloped maker walls, a sling in each end zone
  flinging up to a gallery ring; roots where the ball once flew.
- Root-bound stack: a tier cracked apart by one giant root, slings budding
  off it to every ledge above.
- Greed branch: a sling at a rim that only throws to the prize perch if
  slammed from the very top of an updraft.
Threat pairing: it fires on anything that lands hard on the pad: a stone
off the Loose Voussoirs, a falling keg, the Plinth Ram's charge, him
knocked onto it. A sling set beside a route can throw him off the isle (over
a soft fall to the tier below), and the thrash after a fling knocks him off
its bow if he is standing on it. Stand clear of the lean; use it on purpose.
Catches / throws:
- standing: bobbed; the timed jump pops him `pop`.
- airborne, landing: a soft landing is a stand; a hard one (or a slam) fires.
- tumbling / stunned: a body falling onto the pad fires it however it falls
  (a landing is a landing, the seesaw's rule), and a downed body lying on a
  pad that something else then hits (a voussoir slab, a slam ring) fires too.
- riding: none.
- throws: the fling is a `toss` along the lean, rise up to `rise_top` (10-16
  m, about 15-18 m/s): in control, sail ready, if he came in on his feet;
  still stunned with a fresh poise if he came in tumbling (toss keeps the
  stun and adds none, so it never counts against `restun_gap`). The thrash
  is a `knock(v, sling)` sideways off the bow, about the wind blaster's
  blow (run x 1.3 out, 2 m up): the only stun it deals.
- aim: `lean_yaw` (any way round its foot) and `lean_pitch` (50-80 degrees)
  are build knobs; the bow is grown that way, so it reads where it throws.
  The generator points it at the next link with `landing_for`.
Chains with: the slam and updraft (the combo cashed in as height); the
Seesaw (a seesaw launch onto a pad fires it; a sling onto a seesaw's high
end tips it); the Loose Voussoirs (a slab falling from a run above fires a
pad below, launching whatever lies on it); the Breath Well (its spit lands a
tumbling body on the pad); the Plinth Ram (a ram charging across the pad
fires it, under itself or under him); into a Breath Well's column or a
Calendar Wheel slab.
Edge kind: **"fling"** (from a rim or arena of the lower isle up to a rim of
the upper, the arc a corridor like the cannon's shot; vertical rise 6-16 m,
flat run under 12 m).
Build cost: **med.** The bow as a procedural segmented mesh bent along a
spring curve (no Blender rig), the stele and jaw from kit stone, the spring
and toss in plain maths, and a `landing_for` the generator can call; needs
Opus (moving body, timing, feel). A Blender pass later for the jaw.
Model budget: silhouette geometry (the bow's knots and leaf clumps on the
outline, its bark as texture: about 1.5k triangles for the whole root against
6k modelled); import LODs not worth it (small); vertex-colour grime on the
stele's crevices (no texture cost). Rigid parts on bones: the collar teeth
as separate rigid meshes if it ever gets a rig.

---

# Patient Plinth (plinth_lift, family maker)
Verb: ride (a slow lift), stay still and balanced on it.
Look: a squared basalt drum, a head's plinth without its head, the neck's
stump worn smooth on top and ringed by a lit rune band, standing in a shaft
of stacked masonry courses notched where the drum's guides run. At the top
of the shaft a stone collar under the upper isle's lip. Breath hisses from
the courses as it moves; pale salt streaks where it has always risen.
Behaviour: moves on a trigger. Slammed on its rune cap (or landed on hard),
the rune lights and the drum rises at `rise_speed` (walk x 0.5, 1.2 m/s:
slow, a held breath) to the upper lip's height, stops `hold` 3 s level with
it, then sinks back at `sink_speed` (twice the rise) and rests with a jolt.
It is balanced on breath: the cap tilts toward where he stands, `tilt` per
metre off its middle (up to 12°), easing back when he returns to the centre
ring; past `tip` (his weight at the edge for 0.6 s) it lurches and he slides
(the motor's slope slide) off.
Size: cap radius 2.4 m (four of his stances: room to dodge, not to run); the
rise any tier height (8-30 m); its stopping height level with the upper rim,
its outer edge a hop (`hop_reach` x 0.5) from that rim's lip. The shaft's
notched courses step out every GRAB_TOP so a fall off the drum can be caught
on the way down.
Collision: the cap is a moving clean box (AnimatableBody3D) carrying him by
`motor.carry` (as the ram does); the shaft's courses are static boxes, every
other one a ledge he can catch, the shaft's face wall-kickable.
Motifs it enables:
- The Headless Court: four plinths round a square, one with its head still
  hovering over it (an inhaler head as the lift's guard), the others lifts to
  a gallery where the heads were once raised.
- A plinth in a gulf's narrows, its shaft a pier standing up from the void
  under both rims (a vertical alternative to the ferry).
- The Unfinished Stack: three plinths in steps, each lifting to the next's
  foot, the top one stuck halfway (its rune cracked), its upper hop a jump.
Threat pairing: a still, slow ride with nowhere to hide is exposure: the
generator pairs it with an inhaler head drifting at mid-height, whose pull
across the cap drags him to the edge where the tilt does the rest; crouched
in the centre ring he braces (the head's `brace`) and the tilt holds. And
it is a tool against the heads: a head inhaling at the drum is a head facing
away from the rest of the isle, and from the top of a rising drum a slam
lands on the head's crown.
Catches / throws:
- standing: carried; the tilt follows where he stands.
- airborne, landing: lands and rides; a hard landing (past the fall stun's
  6 m, or a slam) on the resting cap lights the rune, so a body dropped onto
  it from the tier above sends it up.
- tumbling / stunned: a body landing on the cap lights it too, and is
  carried up as a body (as the Sky Ray's fix carries one); lying off the
  middle it is weight off centre, so the cap tilts and slides it to the low
  side. With `stun_chain_cap` the player may get up before the top and
  re-centre; if not, he is shed.
- riding: it is the ride.
- throws: the shed off the tilted cap (a slide off its edge, his own momentum,
  no stun: the world's position cost); the stop at the top `breathes`, a puff
  that tosses anything on the cap `puff` (small jump height, 0.8 m) toward
  `shed_yaw` (enough to hop him, or roll a body, onto the upper rim); the jolt
  at the bottom tosses the same up. No knock: it never stuns, so it is a calm
  link between stunning ones.
- aim: `shed_yaw`, the way the cap rests tilted and puffs, a build knob the
  generator turns toward the upper rim, or toward the next link (a Breath
  Well's column, a Root Sling's pad on a ledge below).
Chains with: an inhaler head (its pull is the tilt's partner; its blast can
throw him onto the cap, which lights it); the Breath Well (puff a body into
the column); the Root Sling (a body shed off the top lands on a pad below
and fires it); the Seesaw Drop and the Loose Voussoirs (a slab from above
lands on the cap, which lights it, sending up whatever lies there); the
Plinth Ram (a ram stood on a cap is weight off centre: it tips and sheds the
ram, the only lift in the game that throws a bull).
Edge kind: **"lift"** (from an arena or rim of the lower isle, the shaft
standing on it or just past its lip, to a rim of the upper isle overhanging
it; any rise; the corridor the shaft's column).
Build cost: **med.** All procedural kit stone (the drum and courses are
RuinKit-style boxes and octagons, the rune band the serpent's grooves),
one moving body with carry, tilt as a spring on the cap's basis. Opus for the
ride and tilt feel; the look is cheap.
Model budget: vertex-colour grime (courses and drum, free); parallax depth
for the rune band and the course joints (instead of cutting grooves: about
2k triangles per plinth spared); import LODs on the shaft (a tall repeated
column seen from every tier: visibility ranges for the far courses, perhaps
0.1 ms per plinth at range). Sculpt-bake and rigid parts: not needed.

---

# Gullet (gullet, family maker)
Verb: climb (wall-kick up a chimney), timed to its breath.
Look: a tall square chimney of maker masonry rising from the lower isle
through a hole in the upper isle's rim, its outside carved as heads stacked
on heads, each face's mouth a window into the shaft. Inside, two facing walls
of rough courses, soot-dark, the breath's moss growing only on the upwind
side. At its foot a doorway (a mouth at ground level); at its top the
highest face's open mouth spills him out onto the upper isle.
Behaviour: static stone, changing air. The shaft breathes on a cycle like the
Breath Well, faster: `exhale` 2.5 s (wind up the shaft: each kick rises
WALL_JUMP plus `assist` 0.8 m, a glide in it climbs) and `inhale` 1.5 s
(wind down: a kick rises barely more than the slide loses). A fluttering
streak and dust in the windows tell the change a beat early. Ledges every
`rest` courses (GRAB_TOP deep sills) let him hang through an inhale.
Size: the inner width from the kick: wall to wall WALL_KICK x the kick's
rise time (5.2 m/s x 0.33 s, about 1.7 m) plus his body, so 2.0-2.2 m clear
between the walls (a knob, `width`, from the pilot's numbers so a wanderer
scale change follows), and 2.4 m deep. Height a tier, 8-24 m; a window every
6 m, wide enough to leave through (a stance and a half), so a lost climb
ends on a sill, not at the bottom.
Collision: the two inner walls are flat clean boxes (wall-kickable, taller
than WALL_TALL everywhere); the sills are boxes whose tops pass `_stand_on`
(catchable, climbable); the outside faces are a wall too, with the brow
ledges under GRAB_TOP, so a skilled player can climb the outside instead,
out of the breath's help and out of its trouble.
Motifs it enables:
- The Speaking Tower: a single isle-high gullet in a ring of lower isles,
  the exit at its mouth; the whole layer reads the tower.
- Twin gullets breathing opposite (one exhales while the other inhales), a
  side window between them: switch shafts mid-climb.
- Under a hanging underside: a gullet climbs up into the undercroft of the
  isle above and opens in its floor.
Threat pairing: the inhale is a downdraft down the shaft: kicking against
it loses height and a sail opened in it is pressed down and folds on the
walls; stray to a window in an inhale and the shaft's draw sucks him back
in (a short inward pull). A greed-branch gullet blows its exhale hard enough
(`force` over the sail's catch) that leaving by a window flings him out
over the void, a launch only the brave ride to the perch beside.
Catches / throws:
- standing: walks in at the door; on the exhale the shaft's floor lifts him
  a hop (a free first kick).
- airborne, in control: kicks wall to wall, assisted or hindered by the
  breath; a sail opened in the exhale climbs the shaft as a narrow thermal.
- tumbling / stunned: a body thrown into the door or any window during the
  exhale is carried up the shaft as a body (shoved up, bouncing off the walls
  limp: the ragdoll's spin knocked off each wall) and spat out the top mouth;
  during the inhale a body at a window is drawn in and falls the shaft to the
  door. Never a new stun from the shaft itself.
- riding: none.
- throws: the top mouth's spit, a `toss` out along that mouth's facing at
  `spit` (run x 1.5 out, 2 m up: a short lob onto the upper rim or to the
  next link), keeping whatever state he came in with (still stunned if he
  was, with a fresh poise); the door's spill at the bottom on the inhale, a
  `toss` out at walk pace. The greed window's fling is `knock(v, gullet)`
  (run x 1.6 out, 3 m up), the shaft's only stun.
- aim: which of the four top mouths is open (`mouth` knob, the others
  carved shut) and which windows are open, set by the generator toward the
  upper rim or the next link. The top lob is short and certain, so a
  generator can rely on it.
Chains with: from a Breath Well's spit or an inhaler head's blast into a
window (a stunned body carried up instead of falling); into a Root Sling
pad or onto a Patient Plinth's cap by the top mouth; from the wind blaster
(a corridor of mouths along a ledge blowing him into a window); the Calendar
Wheel (a slab passes a window: board it from inside); an inhaler head
hovering at the top mouth, drawing on the shaft, turns the whole chimney
into an inhale.
Edge kind: **"chimney"** (from a doorway at the lower isle's arena to the top
mouth's exit, a rim of the upper isle; the upper isle must stand round or
beside the shaft; vertical rise 8-24 m, flat run under 4 m).
Build cost: **low-med.** Procedural kit stone (RuinKit courses and boxes),
the faces as the tower_shell's carving pass or later a shared Blender face
tile; the breath is the existing `air` (wind up/down) and a pull zone at the
windows. The risk is feel: whether the motor's kick-between-walls climbs at
these widths, and how a limp body bounces up a shaft, which want a throwaway
check through the real play loop.
Model budget: rigid repeated tiles (one face tile instanced up the shaft:
a MultiMesh, maybe 80 % of the shaft's triangles shared); vertex-colour
grime for the soot; parallax depth for the course joints inside; import LODs
on the face tile. Sculpt-bake on the face tile only if it goes to Blender.

---

# Calendar Wheel (calendar_wheel, family maker)
Verb: ride (a slow vertical wheel), time the boarding and the hop off.
Look: an upright stone wheel as tall as a tier, its face a maker calendar:
rings of rune glyphs round a hub carved as an Olmec face, the pale eye open
and slowly turning with the wheel (it does not watch, it counts). Round its
rim hang stone gondola slabs on bronze-green pins, kept level by their own
weight. Roots have climbed one spoke and stopped it once; the break is
patched with older stone. It stands between two tiers, its foot by the lower
rim and its top by the upper.
Behaviour: moves, always. Turns at a rim speed of `rim_speed` (walk x 0.5,
1.2 m/s); the slabs swing level on their pins with a lag (follow-through: a
slab sways after a landing and as it rounds the top). He boards at the bottom
as a slab passes the lower lip, rides up (carried by `motor.carry`), and hops
off at the top as it passes the upper lip. Miss the top and he rides down the
far side and round again (about a minute a turn; the patience is the cost).
Size: radius half the tier's rise (a 20 m tier, a 10-11 m wheel); 8-12
slabs, each 2.2 m long and 1.6 m deep; the gap between neighbours along the
rim a chain jump's reach, so a quick player climbs slab to slab faster than
the wheel turns. The lower and upper lips each a hop (hop_reach x 0.5) from
the slab's path at its passing.
Collision: the slabs are moving clean boxes carried round, each slab's
underside a ledge (GRAB_TOP under its top), so a mistimed hop catches the
slab above; the wheel's rim and hub are static-in-their-own-frame hulls
(wall-kickable, but turning); the spokes have no collision (no shove from a
spoke he cannot see coming).
Motifs it enables:
- The Observatory Stack: three wheels in a vertical chain, each a different
  speed (the calendar's rings), up a tall pinnacle to the exit gate.
- A wheel spanning a gulf's narrows on edge, half under the rims, a rider's
  crossing for a layer without a ferry.
- A stopped wheel (root-bound): its slabs a stair at odd angles until a slam
  on the root breaks it free and the wheel lurches round.
Threat pairing: one slab in each wheel is cracked at a pin (`loose` knob):
it swings free, tipping when he lands off its middle, a seesaw on a wheel;
and at the top the wheel passes close under the upper isle's overhang, so a
rider standing tall is knocked off by the lip (crouch, or hop off in time).
As a tool: the wheel's top is the highest point on the tier; a sail opened
off a slab at the top reaches what nothing else does.
Catches / throws:
- standing (on a slab): carried round, level.
- airborne: lands on a slab, or catches a slab's underside lip (a ledge);
  a body thrown across the wheel's face from anywhere is very likely to meet
  a slab, so the wheel is a net in a stack.
- tumbling / stunned: a body landing on a slab rides it as a body; the loose
  slab tips it off; rounding the top a downed body is slid off the slab's
  outer edge by its sway (`toss` along the wheel's tangent at rim speed plus
  the swing, about 3 m/s: a drop to the far side's tier, never a stun).
- riding: the ride; carried bodies (a keg, a fallen stone, a ram that
  boarded by accident) ride too.
- throws: the overhang's lip, `knock(v, wheel)` on a standing rider at the
  top, out along the tangent and down (run x 1.0, the slab's way), stunned:
  the wheel's one stun; the loose slab's tip, a `toss` off its low side at
  his own pace. A hop off at the top is his own jump plus the rim's 1.2 m/s.
- aim: the wheel's plane (its yaw, set at build) and its turning way (`spin`
  knob) decide where the top throws: the generator turns the plane so the
  top's tangent points at the upper rim, or past it at the next link (a
  Breath Well below the far side, a Root Sling's pad).
Chains with: the Breath Well (a well under the far side catches what the
top sheds; its spit lands on a slab); the Root Sling (flung onto a slab; or
a slab's shed body falls onto a pad); the Seesaw (a loose slab on a wheel is
its cousin; a seesaw's launch reaches the wheel's lower slabs); the Gullet
(a slab passes a window); an inhaler head hovering by the wheel draws a
rider off a slab at its height, and its blast at the wheel is caught by the
slabs (the net).
Edge kind: **"wheel"** (from a rim of the lower isle to a rim of the upper,
both facing the wheel; vertical rise 12-30 m, flat run its diameter or
less; the corridor the wheel's disc).
Build cost: **high.** A Blender hub face and calendar face (a hero piece at
tier size), many moving bodies (slabs carried round with lag), boarding and
hop-off timing the generator must check against the pilot's reach, and a
large occupancy disc to keep clear of both isles. Opus.
Model budget: sculpt high, bake low (hub face and calendar rings as one baked
mesh, 10-15k triangles against 60k+ sculpted, about 0.3 ms at close range);
import LODs (it is seen across the whole layer: LOD2 at 100 m a few hundred
triangles); parallax depth for the glyph rings (no geometry for hundreds of
glyphs, perhaps 20k triangles spared); rigid parts (the slabs as one shared
mesh, MultiMesh or instanced, not skinned); vertex-colour grime on the rim.

---

## Notes for whoever builds these

- The cannon cannot be a link yet: it is boarded on foot only
  (cannon-round1.md). The user's chain ("shot by a cannon while ragdolled")
  wants a cannon mouth that catches a body thrown into it and fires it on
  its aim, a `toss` keeping the stun. Not a card here; a cannon round.
- Every piece names itself as the `knock` source (the motor keys
  `restun_gap` by instance), so two wells, or a well and a gullet, chain
  freely, and no piece can lock him: each one's own stun is at most one a
  pass, and the carriers (plinth, wheel, gullet's carry, well's juggle)
  never stun at all.
- The generator's new edges all need the piece's own `landing_for` (or a
  reach check) so the stack stays solvable on foot by construction, with the
  chain as the fast way rather than the only way.
