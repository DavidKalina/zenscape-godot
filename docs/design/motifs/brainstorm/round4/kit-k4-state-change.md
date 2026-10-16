# Round 4, k4: state-change kit pieces

Theme: state-change (verb: solve). Lenses: mood = quiet; shape among isles =
spread wide. Each piece changes shape or state when something acts on it
(the pilot's slam or updraft, water, the sun, the wind, a storm, a
breaker), and the new state opens one route and closes another. Two of
the four are set on one isle and read on another, far off. Each card says
what signal that needs.

Sizes are in pilot terms: RuinKit's Scale section (BODY, STAND, TOP_ROOM,
GRAB_TOP, CHAIN_TOP, SET_OFF, WALL_HEIGHT), PilotMotor (WALK, STEP_UP,
WALL_TALL, LONG_SPEED, SWIM_OUT, SWIM_HOP, SLIDE_AUTO, SLOPE_SLOW) and
WorldScale (`opening`). No metres are copied.

Triggers named here exist today unless listed under Engine gaps: the slam
(`slam(at, radius, strength)`, `decent`), the updraft's `wind_pushable`
group (`wind_push(origin, dir, power)`), the breakables hub (`hit`,
sources `slam` 0.5, `olmec` 1.0, `plane` off), `moving_ground`, the motor's
`water` callable (swimming), the WorldClock (`hour`, `phase`, `daylight`),
the weather scheduler's `current` sky, and the atmosphere's wind and gusts.

None of these is one of round 2's twenty.

---

# Float well (aqueduct_float_well, with aqueduct_headgate, family aqueduct)
Verb: solve, ride (the water carries him up).
Look: a round well-head of the aqueduct's dressed stone, its coping worn
by ropes long gone, at the dry end of an aqueduct line. Inside, a broad
float of pale porous stone (a pumice drum, its top cut with a cross of
drain grooves) sits in the shaft. A culvert arch opens at the shaft's
foot, out to a keel ledge or the gulf side. The **headgate** is its pair,
on another isle at the line's head: a stone gate slab in a grooved frame
across the aqueduct_end's channel, held by a pawl with a carved boss on
the walk beside it.
Behaviour: changes state (the water's level, continuous). The headgate has
two states, `shut` and `open`. A decent slam on its boss toggles it after
a `tell` (the pawl knocks, the slab grinds 0.6 s). Open, water runs down
the channel: the line is `flowing`. The well fills at `fill` (the full
`rise` in about 40 s by default, slow enough that he rides the float
standing) while its line flows, and drains through the culvert at `drain`
while it doesn't. Rain tops it up: the weather scheduler's `rain` or
`storm` adds `rain_fill` (a quarter of `fill` by default) even with the
gate shut, so a well left dry can fill on its own in a storm. The float
rides the surface. Full, the culvert is under water and the float sits
under the coping. Empty, the float rests on the floor and the culvert is
a dry doorway.
Spread wide: the headgate is on one isle and the well on another, one
aqueduct line apart (the line may cross the gulf on spans, or break and
fall as a thread to the next isle). The signal is a named water line
(`line`): a world-state value {flowing, since} that the headgate writes.
The well works its level out from it on load (level = rate x time since
the last change, clamped), so the far isle needs no simulating while
unloaded. Visible between them: the channel's water sheet (KitWater
`still`) and the fall threads at broken spans run while the line flows,
so from the plane the player can follow the water from gate to well.
Size: the float's top is 3 STAND across, walked. The gap between the float
and the shaft wall is under 2 BODY, so he can't drop down it. `rise` is
in SET_OFFs (default 3). Full, the float's top sits a STEP_UP under the
coping and the coping sits GRAB_TOP under the upper route's lip (a terrace,
a span's deck): a catch and a climb. Empty, the float's top sits a
STEP_UP over the culvert's sill, and the culvert is at least STAND+BODY
wide and WALL_HEIGHT tall, so he walks out of the shaft's foot. The
headgate's boss sits in the walk beside the channel, the frame's cap
CHAIN_TOP over it (slammed from the cap). The channel lip stays under
STEP_UP so he can wade the running channel (wading, not swimming:
shallower than SWIM_OUT).
Collision: the coping and the shaft wall are static boxes. The wall is
over WALL_TALL and wall-kickable inside the shaft, but the shaft is too
wide to kick across (wider than a standing jump), so with the float low
the water is the only way up.
The float is one clean box hull, `moving_ground`. The water in the shaft
answers the motor's `water` callable at the live level, so off the float
he swims (SWIM_HOP onto the float or the coping). The gate slab is a
static box in either state.
Motifs it enables:
- The long line: open the headgate on the high isle, fly the plane down
  the aqueduct watching the water go, and land at the far well as it
  fills; the float lifts him to a terrace that had no other way up.
- Two doors in one well: empty, the culvert lets him out onto the keel
  ledges below; full, the float lifts him to the rim. He works out which
  one he needs and goes back to the gate to set it.
- The storm well: a well on a line whose headgate is broken. Only the rain
  fills it, so the high route opens only in a storm.
Catches / throws: standing on the float, carried (moving ground) at the
level's pace, well under WALK. Swimming in the shaft, he floats at the
level. A stunned or tumbling body on the float rides with it. A slam on
the float pushes it down a STEP_UP and it bobs back (a splash, no launch;
it does not turn the slam's pace into height). Nothing knocks.
Build cost: med. The stone is procedural (lathed shaft, coping and float,
the headgate a slab in a frame). One `moving_ground` body on a level. The
water sheet at a live height (KitWater `still` over a disc, raised each
frame) and the channel sheet turned on and off. The cross-isle line needs
world state (Engine gaps). No Blender model.
Model budget: silhouette geometry on the coping's rope-worn notches and
the float's chipped rim; vertex-colour grime as a tide line inside the
shaft (a band of dark at the full level, so the empty well shows where
the water reaches); import LODs and a visibility range on the float, which
can't be seen from the plane at range.
Break kind or cut: the headgate frame tagged `wall` (tough 0.6: over the
slam's 0.5, so slamming the boss never breaks it; the Olmec does), and the
gate slab `slab` (1.6, unbreakable by any breaker today). Broken, the frame drops the slab into the channel and the
line is jammed `flowing` for the run. The well registers a cut `well`:
`stands` the shaft with a breach at the hit's height, `parts` the broken
courses as `chunk`. A breached well drains to the breach's sill for good,
so a breach at mid-height leaves a half well (the float stops at the
breach).
State and reset: the headgate's state and `since` are a world-state mark
(Engine gaps). The well's level is derived from it, never stored. A
reload of either isle reads the mark. `reset()` puts the gate to `start`
and the level to what the line gives.
Editor recipe: headgate `"set": {"line": "east_line", "start": "shut"}`;
well `"set": {"line": "east_line", "rise": 3, "fill": 40, "drain": 60,
"rain_fill": 0.25}`. The pilot-scale guides draw the full and empty float
tops against the coping and the culvert sill (STEP_UP, GRAB_TOP ticks).

---

# Sun mirror (relic_heliostat, with relic_sun_eye, family relic)
Verb: solve (aim it), climb (the steps it raises).
Look: a bronze disc gone dark green at the rim and polished bright at the
centre, as tall as a wall, held upright in a stone yoke on a round
turntable plinth. The plinth's rim is carved with eight sun ears, bosses
set in the turf round it. The **sun eye** is its pair, on another isle: a
clear lens of rock crystal in a stone collar on a low drum, with a ring of
sunk stone drums round it, flush with the turf.
Behaviour: changes state. The mirror turns a notch (of `notches`, default
8) when he slams the ear on the opposite side from the way it should turn
(the ear pushes away from the slam), over `turn` s (default 1.0) after a
`tell`. Each notch holds an authored tilt, so each heading is aimed. The
mirror reflects only while the sun is up (WorldClock `daylight` over
`light_min`), on the mirror's face side, and the sky isn't covered (the
scheduler's `current` not `overcast`, `mist`, `rain`, `storm` or
`snow`). So a notch that aims at an eye lights it only in a window of
hours that the sun's path gives. A beam is drawn (a pale shaft in the
haze, a god-ray card along the line) from the disc while it reflects. The
eye, lit for `dwell` s (default 3), raises its drums one after another
(each over 0.8 s, 0.3 s apart) into a stair of stepping stones. They stay
up while it stays lit, and once unlit they sink slowly, one at a time, the
top one first (`sink`, default 2 s each, after `hold` s, default 20). `moon`
(off by default): a full moon (the clock's lunar phase) gives a beam at
night with `dwell` doubled.
Spread wide: mirror and eye stand on different isles, as far apart as a
clear line of sight allows (`reach`). The signal is the mirror's notch, a
world-state value, plus the sun's direction and the sky's cover, which
both isles read from the shared clock and scheduler. The eye knows its
mirror and the notch that lights it (an authored pair), so it needs no
ray across the gulf while the far isle is unloaded. The beam is drawn only
for the player. Line of sight is checked once in the editor against the
isles' bounds (KitLand outlines), not at run time.
Size: the disc is WALL_HEIGHT across, so it reads from the plane. The
turntable's top is TOP_ROOM round the yoke's feet, walked. The yoke's cap
is CHAIN_TOP over the turntable, reached by a SET_OFF on its post, and the
ears lie within a standing jump of the cap's edge, so he drops from the
cap onto an ear with more than the slam's LOW of air (a decent slam). The
eye's drums rise to SET_OFF steps, each top STAND deep and 2 STAND across,
the last within GRAB_TOP of a high ledge. Sunk, they sit flush (a STEP_UP
lip at most).
Collision: the turntable top and yoke cap are clean boxes. The yoke posts
are over WALL_TALL and wall-kickable. The disc is a thin box hull, a wall
he slides on, not walked. Each drum is its own `moving_ground` box. The
lens collar is a static step.
Motifs it enables:
- The morning door: the eye's stair leads into a sealed tower, and it
  only rises in the morning hours, when the sun is behind the mirror's
  isle. He sets the notch, then flies over in time.
- The relay: two mirrors on two isles, the first lighting a lens on the
  second that turns it a notch (a mirror's own eye), so the beam is
  passed across three isles to the last eye.
- Eight bearings: one mirror at the hub of a spread of isles, each notch
  lighting a different isle's eye, so turning it closes one isle's way up
  and opens another's.
Catches / throws: standing on the turntable as it turns, he is carried
round (moving ground, slow). Standing on a drum as it rises, carried up.
As it sinks, he stays on it to the turf. A body on a drum that rises
under a ledge is pushed off along the drum's top (`toss`, flat, source
"relic_sun_eye", never a stun). Nothing knocks.
Build cost: med-high. The stone is procedural (lathed plinth, yoke,
drums, collar), the disc a lathed bronze dish with a mirrored metal
material (an existing bronze shader with a high-metal centre). The beam
is a card. The sun's direction from the clock's phase, the cover from the
scheduler, the notch table, the drum rig (`moving_ground` bodies on a
sequence), and the cross-isle mark (Engine gaps). No Blender model.
Model budget: silhouette geometry on the disc's rim (dents and a chipped
edge); vertex-colour grime in the yoke's joints and round the sunk drums'
seams; import LODs, and the beam's card faded out by a visibility range
on the far side.
Break kind or cut: registers `mirror`: `stands` the yoke and turntable,
`parts` the disc as a `drum` (tough 0.8, over the slam's 0.5, so slams
turn it and only the Olmec or the dragon breaks it). A fallen disc
reflects nothing and its eye goes dark for the run, a route closed. The
eye's drums tag `pier` (risen they can be broken and stay broken, so a
stair can lose a step for the run).
State and reset: the notch is a world-state mark, and so is `broken`. The
eye's drums are derived (lit or not) every frame from the clock, the sky
and the mark, so a reload in the right hours shows them up. `reset()` sets
`start` notch.
Editor recipe: mirror `"set": {"pair": "dawn_eye", "notches": 8,
"start": 3, "tilts": [...], "light_min": 0.3, "moon": false}`; eye
`"set": {"pair": "dawn_eye", "notch": 5, "drums": 6, "dwell": 3,
"hold": 20}`. The editor draws the aimed line and the hours it lights
(from the sun's path for the season), so the window is judged there.

---

# Weather vane (tower_vane, family tower)
Verb: solve (wait for the wind, or make it), ride.
Look: a long stone beam balanced on a bronze pivot on a stump or a
tower_shell's top: a walked nose at one end and a tall pierced stone fin
at the other, cut like a lancet's tracery so the wind sings through it.
A ring of notches is cut in the stump's cap round the pivot, and a stone
pawl hangs over them from the beam's underside, raised.
Behaviour: changes state (its heading). Free, it weathers into the wind,
the nose pointing upwind, its heading easing toward the atmosphere's wind
direction and wobbling with the gusts (`lag`, default 3 s; the tip's
pace capped under WALK). Calm holds it where it is, and a storm swings it
wide and fast (its gusts, still capped). He can turn it himself: the
updraft spent beside the fin pushes it (`wind_push`: the vane joins the
`wind_pushable` group, the fin at his height), a notch's worth a push.
The plane's prop wash, passing within `near`, pushes it the same way. A
decent slam on the pivot's cap drops the pawl into the nearest notch: it
is pinned, a fixed bridge, until a second slam lifts the pawl. The nose's
tip sweeps a circle; at the headings where the circle passes a
neighbour's rim (a stack, a stump, a spire top, another vane's nose) it
is a bridge to it.
Size: the nose is TOP_ROOM wide and 4 to 6 STAND long past the pivot. At
a bridging heading its tip comes within STEP_UP of the neighbour's walked
top and a gap under a standing jump from it (or touches it). The pivot's
cap stands a SET_OFF over the beam's top, so he slams it from the fin's
top. The fin is WALL_HEIGHT over the beam, its top STAND deep and walked
(the slam's perch). The beam rides a STEP_UP over the stump's cap, so
from the cap he steps onto it at any heading.
Collision: the beam, nose and fin top are one rotating body, clean boxes,
`moving_ground`. The fin's faces are over WALL_TALL and wall-kickable
(kicked up from the beam to its top). The tracery is cut in the mesh
only; the hull is a solid slab. The pivot and stump are static.
Motifs it enables:
- The wind's road: a line of stumps across a spread of islets, each with
  a vane. On a day the wind sits right the noses link up into a road;
  on others he pins them one by one with the updraft and the slam.
- Fly the key: the vane on a lone spire turns only when the plane passes
  near it, so he flies a close pass to swing its nose round to the cliff,
  then lands and walks over.
- The storm crossing: in a storm the free vane sweeps its arc and he
  rides the nose round to the far stack, stepping off as it passes.
Catches / throws: standing on the beam, carried round (moving ground) at
its pace, under WALK at the tip, so he walks it as it turns. Hanging from
the nose's lip, carried. When the nose swings into a wall or a rim edge
it stops there (the swing is blocked, it doesn't push him through), and
a body on the nose's tip as it stops keeps its own pace (it leaves at
the vane's `frame_v`, a step, never a toss). Nothing knocks.
Build cost: med. The beam and fin are procedural stone (the lancet wall's
tracery cut into the fin's mesh), one rotating `moving_ground` body, a
heading spring toward the wind, `wind_push` from the updraft (exists),
the plane push (Engine gaps: plane near), the pawl's latch. No Blender
model.
Model budget: silhouette geometry (the fin's tracery cut through, seen
against the sky from the plane); vertex-colour grime in the pivot's
bronze collar and the notch ring; import LODs, since from far off it reads
as a single cross.
Break kind or cut: registers `vane`: `stands` the stump and the beam,
`parts` the fin as a `slab`. Without its fin it no longer weathers: it
stays at the heading it broke at for the run (a bridge kept or lost by
where it pointed when the Olmec hit it). The stump tags `pier`.
State and reset: heading (and `pinned`). Free, the heading is the wind's
and isn't saved. Pinned, it is a world-state mark so a pinned bridge
stays on return. `reset()` puts it at `start` with the pawl up.
Editor recipe: `"set": {"start": 0, "notches": 12, "lag": 3, "length": 5,
"pinned": false, "plane": true}`. The editor draws the tip's circle and
marks the headings where it meets a neighbour's top (STEP_UP and jump
ticks).

---

# Shored spire (gothic_shored_spire, family gothic)
Verb: solve (choose which way it falls), climb (before), walk (after).
Look: a tall, thin spire of coursed stone standing on an isle's rim,
leaning a little, with set-offs up its faces like a buttress's. Two great
raking shores hold it, timber baulks on stone footings on opposite
sides, one toward each of the two islets nearest it. Each shore is wedged
under a carved collar; the wedges are worn pale where the spire has
pressed on them. A copper rod runs up its tip, green with age.
Behaviour: changes state once, for good: standing, then felled one of two
ways. Break a shore and the spire falls away from the other one, toward
the broken shore's side, so it comes down across the gulf on that side
as a beam bridge to that islet. Breakers: the slam (the shore is a `post`,
tough 0.4, under the slam's 0.5), the Olmec, the plane when it is on. The
weather: in a storm the rod draws the kit's lightning (a strike target
beside the towers), and a strike splits the shore on the weather side
(the side the wind comes from), so a storm fells it the wind's way if he
hasn't. The fall: a `tell` (the shore cracks, dust falls off the collar,
the spire creaks, 1.2 s), then it falls on an authored hinge at its foot,
slowly at first then faster (`fall`, default 2.4 s), and lands with its
tip seated on the far rim. It settles with a shake and the hub's quake
(`shake`, `changed(box)` so enemies re-plan their routes). Felled, it
is a static walked beam. The other shore falls away with nothing to hold.
Size: standing, 6 to 8 SET_OFFs tall, its shaft TOP_ROOM across and its
set-offs SET_OFF apart, STAND deep: a climb to a perch at its tip.
Felled, the shaft's top is the walked beam, TOP_ROOM wide. Its length
sets the gulf it spans (the gulf plus a seat STAND deep at each end), and
the two islets' rims sit within its length x sin(SLOPE_SLOW) of its foot,
so the felled beam is walked, not surfed. The shore's footing is a ledge
GRAB_TOP over the turf beside the spire; its collar is CHAIN_TOP over
the footing, a perch to slam the shore's head from.
Collision: standing, the spire's faces are over WALL_TALL and
wall-kickable, its set-offs clean boxes. Shores are static boxes, their
tops walked as ramps under SLIDE_AUTO. During the fall it is one
rotating body, not `moving_ground` (riding a falling spire isn't a
route). Felled, a static box beam and the rubble of its broken shore.
Motifs it enables:
- The fork: one spire between two islets, each holding a different find
  or way on. Felling it toward one closes the other for the run, so he
  looks at both first (binoculars from the tip).
- The far bridge: the spire is the only way to an islet across a gulf too
  wide to jump, and its shores are behind a climb. He fells it from its
  own collar, then walks back down the beam he made.
- Waiting for the storm: the shore on the near side is out of reach, and
  only a storm from the right quarter fells it the right way. He comes
  back in that weather.
Catches / throws: anything under the falling shaft's line (a box swept
along its arc) when it lands is knocked out from under it, square to the
beam: `knock` with source "shored_spire", strength by where along the
shaft (the tip's heavier). Standing on the spire as it falls (on its tip
or a set-off), he is thrown off at the shaft's pace at his feet (`toss`
past `toss_pace`, else he just falls), so he can't ride it over. A stunned
enemy struck goes over the rim.
Build cost: med. The spire is procedural (the turret's coursing and the
buttress's set-offs, a taller, thinner shaft). The fall is option 3 of
the break contract (it joins the group `breakable` and answers
`take_hit` with its own choreography: the shore broken by the hub's kind
`post`, the spire's hinge fall scripted, never free physics, so it always
lands seated). The lightning hook is new (Engine gaps). No Blender model.
Model budget: silhouette geometry on the spire's coping and chipped
set-offs, and the split end of a broken shore; vertex-colour grime under
the collars and down the lee face; import LODs and a visibility range on
the shores' wedges.
Break kind or cut: answers the hub (option 3); the shores are `post`
inside it. Felled, the beam itself tags `slab` (1.6: no breaker today
breaks it, so a felled bridge stays).
State and reset: `standing`, `felled_a` or `felled_b`, a world-state mark
(Engine gaps): once felled it stays felled on return. `reset()` stands it
up (the yard and the editor only).
Editor recipe: `"set": {"start": "standing", "height": 7, "rod": true,
"fall": 2.4}` plus two handles, `"seat_a"` and `"seat_b"`, the tip's
landing on each far rim, which set the shores' sides and the hinge. The
editor draws both felled beams as ghosts with their slope against
SLOPE_SLOW, and warns when a felled beam would cover the landing strip.

---

## Combines with

- aqueduct_float_well / aqueduct_headgate: `aqueduct_end` (the gate sits
  in its channel head), `aqueduct_span`, `aqueduct_broken` (where the line
  falls as a thread to the next isle), the noria (round 2: a full well
  feeds it), `hall_slab` keel ledges at the culvert's mouth.
- relic_heliostat / relic_sun_eye: `tower_shell` (the eye's stair into a
  sealed tower), `relic_nimbus` (an eye set in the halo's rim), the belfry
  (a mirror on its wall head), `stone_circle` (eight eyes round a ring, one
  mirror at its centre).
- tower_vane: `aqueduct_stump` and `tower_shell` as its pivot stumps, the
  `wind_horn` (its blast pushes the vane as the updraft does), rope
  bridges anchored where the nose stops pinned.
- gothic_shored_spire: `buttress` and `turret` (its language),
  `fallen_pier` (spires already felled nearby, the tell of what this one
  does), the Olmec's walk (he fells it on his own if he reaches a shore).

## Engine gaps found

- **Saved world state with a clock.** A small marks table keyed by isle
  and piece (round 2 asked for it) is not enough here: the headgate's line
  needs `since` (world time of its last change) so the far well can work
  out its level, and the mirror's notch, the vane's pin and the spire's
  fall all need to outlast a reload and be read by a piece on another
  isle. Proposed: RunState marks {key: {value, since}}, keys a recipe can
  name (`line`, `pair`), not only a piece index.
- **Named links between pieces on different isles.** The editor's recipes
  hold no cross-motif names. `line` and `pair` are plain strings both
  recipes share; the editor should list the open ones so an orphan shows.
- **The sun's direction and the sky's cover as queries.** The clock has
  `phase` and `daylight`, the scheduler `current`. A piece needs
  `sun_dir()` (from the celestial rig's phase and the season) and
  `sky_clear()` (from the weather) without reaching into kit_weather's
  node. Also the moon's phase for `moon`.
- **The wind's direction on a kit isle as a query.** The atmosphere's
  `gust_at` and strength are read by the bells, but a heading for the vane
  needs its direction (`zs_wind_direction`) through the same door.
- **Lightning has no targets but towers.** kit_weather `strike` flashes
  inside the nearest standing tower. The spire needs a `lightning_rod`
  group the strike can pick, and a call back to it (`struck(at)`).
- **Piece water for the motor.** The motor has one `water` callable (the
  isle's). A piece with its own rising water (the well) needs the isle's
  callable to ask pieces too (a `water_pieces` group answering depth at a
  point).
- **The plane near, again** (round 2's gap): the vane's prop-wash push
  needs the general plane-near group that only the bell spires have.
- **Scripted falls through the hub.** Option 3 of the break contract
  exists, but the spire is the first piece whose fall must land in an
  exact pose. It needs the hub's `changed(box)` and the 24-body cap to
  count a scripted fall as one body.
