# Kit brainstorm K2: things that move (round 1, 2026-10-13)

> **Status: brainstorm, nothing decided, no code.** Theme: the makers'
> moving stone (rune rings, sinking slabs, folding stairs, counterweights,
> rolling drums) beside the Olmec head and body. Numbers are at the default
> sizes (wanderer 1.0, plane 2.0) and come from PilotMotor / RuinKit /
> WorldScale: walk 2.4 and run 4.8 m/s, jumps 0.8 / 1.5 (pump), a running
> plain jump's reach about 2.4 m, long jump 4.2, twirled gap 3.0, GRAB_TOP
> 1.875, CHAIN_TOP 2.575, SET_OFF 1.6, STEP_UP 0.45, STAND 0.58, TOP_ROOM
> 1.16, WALL_TALL 1.2, gravity 26, THREAD = `WorldScale.opening(3.5)` = 7.0.
> Each card names the formula as well, so a resize carries through.

**The family: `works` (the makers' works).** These are the first kit pieces in
the Olmec makers' own style, not the gothic abbey's. They are cut from the
head's and body's weathered basalt (`shaders/olmec_stone.gdshader`, with its
`runes` knob on, so the grooves are cut and lit as on the rune serpent), and
they are still doing their old jobs. Each one is a `trap.gd` subclass with a
kit-style look builder ("Mesh" plus moving "Body" nodes, foot on y 0). It
shares the movers' machinery that already exists:

- **Moving bodies.** Each moving part is an `AnimatableBody3D` posed once per
  physics step in `_physics_process` (the seesaw's 2026-10-12 fix, so Jolt
  loads ride it). The pilot is carried by the part's transform delta since
  his last frame (`motor.carry`, as the seesaw, flip and tumble do), and a
  part's pace at his feet leaves with him (`velocity_at`, as foot slabs do).
- **Motion.** Motion either chases a target on the seesaw's damped spring
  (`tip_time`, `bounce`) or runs on a phase rhythm (the flip's
  FLAT/TELLING/FLIPPING, with the tumble's rest/tip/lurch/stop-dead).
- **Weight.** Weight is the seesaw's balance of moments: `pilot_mass` 80 plus
  the masses of its RigidBody3D `loads`.
- **Blows.** `impact(arm, speed)` is a blow from anything: a landing, a
  "slammed" event, `drop_hit`.
- **Throws.** A throw is `motor.toss`; a hard stop or a slap is
  `motor.knock(v, self)`. The source is the piece itself, so `restun_gap`
  (1.2 s) and `stun_chain_cap` (3 s) apply per piece, and two different
  works chain freely.

The one new shared part would be a **rune link**: a carved rune (touched by
the body, slammed, weighted, or hit by a thrown load or enemy) wired to one
or more actuators. Its tell borrows the Olmec eye's lock-on light. The
grooves glow faintly at rest (0.3 by day) and ease to 3.2 over 0.6 s before
the piece moves, with `tell_sound` "grind" before and "clack" on the stop.
Every work is therefore read the same way: the runes light, then the stone
moves. Everything is sized from `pilot()` and RuinKit's Scale constants.

---

# Rune Dial (works_dial, family works)

**Verb:** ride, time a crossing, solve. You hop ring to ring and wait for the
bridges to line up, or you turn the rings yourself.

**Look:** A colossal sunken calendar dial is laid flat in an isle's floor: two
or three concentric basalt rings round a central dais, which is the inhaler
head's cradle. Each ring has a carved band of day-signs on its rim, and one
"tongue", a short slab bridge that juts across the gap to the next ring
inward. Roots have grown into the gaps and been sheared off flat where the
rings have turned for centuries. The rings tier down toward the centre like a
ballcourt bowl. On the rim stand four waist-high rune posts. When the head
docks on the dais, it is clearly the dial's master.

**Behaviour:** Each ring drifts slowly and continuously (`drift`, its outer
edge at most walk x 0.25, so a stood pilot is carried visibly but can always
walk against it). It also clicks round one notch (TAU/`notches`, default 12)
when its rune is triggered. The notch is a lurch with a hard stop:

- **Tell:** the ring's band lights for `tell` 0.6 s and grinds.
- **Turn:** the ring turns over `notch_time` 0.9 s, eased.
- **Stop:** "clack".

Triggers:

- touching a rim post (walking or running into it, a twirl, a wall kick off
  it): the outer ring;
- slamming a ring's own rune slab: that ring;
- the head settling on the dais: every ring, one notch.

When all the tongues line up, a straight road runs from the rim to the
centre (the "path"). Otherwise the crossing is a hop between rings with the
tongues as stepping stones.

**Size:**

- **Rings:** each is run x 0.5 wide (2.4, over TOP_ROOM).
- **Gaps:** reach x 0.5 between rings (about 1.2, a running plain jump).
- **Tier drop:** `tier` per ring inward, from 0 up to SET_OFF. At STEP_UP or
  less the dial is a bowl you walk down. At SET_OFF it is a ziggurat: when
  the tongues are out of line you climb ring to ring by ledge grabs, under
  GRAB_TOP.
- **Dais:** radius run x 0.5. The inhaler head's chin hover fits over it.
- **Overall:** 3 rings come to about 13 m in radius.
- **Upright variant (`upright`):** the dial stands like a calendar wheel. The
  centre is an open bore of `WorldScale.opening(TOY_THREAD)`, so the plane
  threads it, and the ring gaps line up into a flight slot only at "path".

**Collision:**

- **Hulls:** each ring is one AnimatableBody3D of 16 convex segment hulls.
  Its walk tops are clean chord boxes overlapping by WALK_OVERLAP (sagitta
  0.25 at 13 m, inside the 2.4 width).
- **Tongues:** clean boxes on the same body.
- **Tier risers:** at SET_OFF tiers, the riser faces are flat hulls at least
  WALL_TALL tall, so they can be wall-kicked.
- **Rim posts:** single convex hulls, kickable.

**Motifs it enables:**

- *The cradle court*: an inhaler head's home isle. The dial is its bed, and
  the path opens only when it is docked or lured away.
- *The calendar well*: an upright dial in a cliff face. The plane threads it
  at "path"; the walker climbs its tiers.
- *The orrery stack*: three dials on three isles over one another, their
  paths offset. You fall or are thrown from one path's end onto the next.

**Threat pairing:**

- **Danger:** the notch's stop dead jolts you off tangentially, into a gap
  or off the outer rim. A tongue swinging away mid-stride leaves you running
  onto air. The head itself turns the dial whenever it docks.
- **Tool:** the same jolt is a free sling, and you choose when it fires by
  touching the post.

**Catches / throws:**

- **Catches:**
  - *Standing and riding:* carried round with the ring (`motor.carry` with
    turn, so his facing turns too).
  - *Tumbling/stunned:* carried the same way, as the logs do.
  - *Airborne:* nothing until he lands. A landing on a tongue mid-notch
    counts as riding.
- **Throws, at the stop dead:**
  - *Grounded:* `motor.toss` at `jolt` x the stone's pace under his feet,
    along the tangent, with a little up (jump[0] x 0.3). At the outer ring's
    peak notch pace (about 1.6 x arc/time, roughly 8 m/s at 13 m with 12
    notches) that is a long-jump-plus fling.
  - *Hanging from a tier lip as it stops:* shaken loose (`toss`).
  - *Stunned body:* takes the toss still stunned.
  - *Ring-edge teeth (`teeth` knob):* low day-sign stones on the ring rims
    sweep the gap they face, and a body in their way is
    `motor.knock(v, dial)` at the ring's pace.
- **Aim:** the throw is tangential, so its direction is set by where on the
  ring you stand when it stops, and the motif authors the stop angles
  (`stops`). The generator can point the outer ring's sling at the next
  link's rim by setting `phase`. Speed is set by `notch_time` and the radius.

**Chains with:**

- **Inhaler head:** its blow lane can be aimed across the dial so a spat
  pilot lands on a ring and is carried. Docking turns the rings, and a pilot
  on a ring is slung off.
- **Seesaw high end:** slung onto it, the landing flings whatever is on the
  low end.
- **Wind vent / updraft:** at the rim, it catches the sling.
- **Sluice spill:** washes bodies onto the outer ring.
- **Breath Pillars** (below): a dial's path can end over a pillar field.
- **Headless body:** a body standing on a ring is carried into the pilot's
  slide lane (knock it off).

**Build cost: high.** The model is procedural (Build.solid segments, no
Blender), but it needs:

- carry with turn on a large radius;
- a ratchet rhythm plus a drift;
- a rune link wired to the inhaler head's dock state;
- the upright variant's plane slot;
- tuning the jolt so it is a sling and not a random death.

It is mostly an Opus job (moving bodies, feel).

**Model budget:**

| Trick | Applies? | Estimated saving |
|---|---|---|
| Silhouette geometry | Yes: chips on the ring rims and tongue ends only, the faces flat. | About 3-4k tris a ring instead of 15k+ chipped all over. |
| Parallax depth | Yes: the day-sign bands as parallax and lit shader grooves (the olmec_stone `runes` path), not modelled. | Saves roughly 20-40k tris of carved glyphs. |
| Vertex-colour grime | Yes: in the ring gaps and under the tongues. Build already does this. | No new cost. |
| Import LODs and visibility ranges | Yes: dials are seen from other isles. Far LOD at 40 m drops the chips. | About half the tris at range; under 0.05 ms. |
| Sculpt high, bake low | Not needed. | n/a |
| Rigid parts on bones | Not needed: no skinning. | n/a |

---

# Yoke Lift (works_yoke, family works)

**Verb:** ride (an elevator), carry (load the other pan), launch.

**Look:** A tall stone post carved as a stacked Olmec torso, headless, its
shoulders a crossbeam. The yoke is a long stone beam rocking on the shoulders
like a balance scale's. From each end hang two square basalt pans on carved
stone chains of interlocking rings, rune grooves on every link. One pan holds
a counterweight: a rough head-sized basalt ball with a single blind eye
carved shut, which is the makers' weight. The chains are overgrown with
hanging moss, and a vine is torn where the pan last moved. It reads as the
headless body's kin: the same shoulders, holding a balance instead of a
head.

**Behaviour:**

- **The balance.** The pans stay level as they go up and down. Their pace is
  Atwood's machine, run through the seesaw's spring (`travel_time`,
  `bounce`): the side with the greater moment (pilot 80, the ball `ball_mass`
  default 100, loads, a headless body) sinks.
- **Default rest.** The ball's pan is down. Stepping on the high pan alone
  does not lift it (80 < 100). It needs a second load, a slam, or something
  heavier.
- **Slam.** A slam on a pan is `impact`: that pan drops hard, and the other
  pan rises fast and stops dead at the top of its travel (`top_stop`), where
  whatever stands on it is flung.
- **Rune on the post.** At reach height, it locks the yoke (`lock` s) when
  touched, so a ride can be held at the top.
- **Tell:** the chain runes light up the side that is about to rise, and the
  links "chink" (tell_sound) as they pay out.

**Size:**

- **Pans:** run x 0.5 square (2.4).
- **Travel:** `travel` = n x SET_OFF, 2 to 4 (3.2 to 6.4 m), so the low pan
  sits at floor level and the high one tops a cliff or ledge.
- **Pan rims:** STEP_UP high, a lip you step over.
- **Clearance:** chains run up from the pan's corners, leaving a clear
  standing square of at least TOP_ROOM.
- **Post shoulders:** their top is a perch, CHAIN_TOP above the high pan's
  top stop, reached by a pump catch.

**Collision:**

- **Pans:** each is an AnimatableBody3D, a clean walk box plus four low rim
  boxes.
- **Chains:** thin capsule hulls the pilot cannot pass through (they are not
  climbable for now; a later rope-climb could use them).
- **Post:** a convex hull stack; its broad flat back can be wall-kicked.
- **Ball:** a RigidBody3D load (continuous CD, like the seesaw's blocks), so
  it can be flung out of its pan.

**Motifs it enables:**

- *The weighing hall*: an isle split by a cliff, and the yoke is the only
  way up. Weigh it with what the isle gives you: a block, a knocked-down
  enemy, the ball itself.
- *The judgement over the void*: the pans hang off the isle's edge, one over
  a lower layer, so a missed ride drops you a layer (a soft fail).
- *The body's scale*: a headless body patrols onto the low pan. Its weight
  sends the pilot's pan rocketing up and off.

**Threat pairing:**

- **Danger:** your pan sinks under you to a pit or past the isle's lip. The
  other side's slam, a falling block, or a headless body stepping on sends
  your pan up and the top stop throws you.
- **Tool:** slam the low pan and ride the high one's throw to a ledge you
  could never jump to. Or stand on the ball's pan and slam to fling the
  ball (at an enemy, or onto a seesaw's high end).

**Catches / throws:**

- **Catches:**
  - *Standing and riding:* carried.
  - *Airborne:* a landing on a pan is weight plus a blow scaled by fall pace,
    so a high drop onto one pan is a launch on the other.
  - *Tumbling/stunned:* weighs, rides and is thrown as a load would be.
  - *A stunned body landing from a knock:* still counts as `landed` with its
    fall speed, so being thrown onto a pan is itself a trigger.
- **Throws:**
  - *At the top stop:* `motor.toss` straight up at `launch` x the pan's pace
    (capped near the seesaw's cap, sqrt(2 g pump x 1.5), about 7.8 m/s, so
    roughly 1.5 pumps of rise), plus `along` x that horizontally in the
    yoke's aim. A stunned body is thrown still stunned. Not a knock: a pan
    arriving is a lift, not a blow.
  - *If the yoke beam swings into a body on the shoulder perch:*
    `motor.knock(v, yoke)`.
  - *Loads:* flung by the seesaw's mass formula.
- **Aim:** the throw is vertical by default. `along` (0 to 0.5) and
  `aim_yaw` (the yoke's own yaw, set by the motif) lean it toward the next
  link, and its speed is set by the slam or drop that caused it. An Atwood
  pan driven by a heavier load gives a smaller, steadier throw.

**Chains with:**

- **Inhaler head:** spat onto the low pan from height, the blow is the slam,
  and you ride up the other side.
- **Cannon:** fire a powder keg onto a pan to send the far pan's rider up.
- **Seesaw:** flung onto a pan.
- **Seesaw (load):** the ball flung onto a seesaw's high end launches
  whatever is on the seesaw.
- **Wind updraft:** over the high pan's top stop, the throw becomes a sail.
- **Headless body:** as counterweight and victim. Its mantle-wave stomp near
  the pan is an impact.
- **Fold Stair:** the top stop can deliver you to a closed wall's rune.

**Build cost: medium-high.**

- *Physics:* the seesaw's moment, spring and impact code ports almost
  directly, with vertical travel instead of tilt and two kinematic pans
  instead of one slab.
- *New:* the top stop throw and the chain links' visual paying-out.
- *Model:* the post and yoke are a small Blender model (a torso stack), as
  the headless body's style is sculpted; the pans and chain are procedural.

**Model budget:**

| Trick | Applies? | Estimated saving |
|---|---|---|
| Sculpt high, bake low | Yes: the torso post, baked to about 6k tris. | Instead of 60k+ sculpted. |
| Silhouette geometry | Yes: on the yoke ends and pan corners. | n/a |
| Rigid parts on bones | Applies in spirit: the chain is rigid links on transforms, never skinned. 8 links a chain, each a 48-tri ring. | About 1.5k tris for 4 chains. |
| Parallax depth | Yes: link grooves as shader runes. | n/a |
| Vertex-colour grime | Yes. | n/a |
| Import LODs | Yes: the chains can drop to 2 links' worth beyond 30 m. | About 0.02 ms. |

---

# Fold Stair (works_fold, family works)

**Verb:** climb, chase (the stair folds away behind and under you), launch.

**Look:** A sheer basalt wall face carved with a column of shallow slab
outlines and a single deep rune at hand height (GRAB_TOP - 0.3). The rune is
an open hand, the makers' "let me up". Each slab outline is a tread folded
flat into the face, hinged at its foot along a groove. Ivy hangs over the
face and is torn every time a tread swings out. The treads' undersides are
pale and unweathered, a tell of how often they move. A headless body could be
standing in front of it as a gate guard.

**Behaviour:**

- **Opening.** Touch the hand rune (run into it, wall-kick off it, or have a
  thrown load or stunned enemy hit it) and the treads unfold down from the
  face, one after another bottom to top (`ripple` 0.1 s per tread, each
  swinging 90 degrees in `unfold` 0.25 s). They become a cantilevered stair
  climbing diagonally up the face.
- **Holding.** The stair holds for `hold` s (default: twice the time to
  walk it).
- **Closing.** The treads fold back up into the wall bottom first, rippling
  upward at `chase` = walk x 0.9. A walker at the top is safe; a dawdler is
  chased off.
- **Fling.** A tread swinging shut lifts its outer edge up and toward the
  wall. Something stood at the edge is thrown up the face, the flip's
  knock-angle maths turned through 90 degrees.
- **Peg mode (`mode` = "pegs").** A stair (RISER and TREAD, walked) or
  staggered pegs at SET_OFF rise and a plain jump's reach apart, hopped.
- **Tell:** the rune lights, then each tread's groove lights a beat before
  it moves. A "grind" sounds before a fold, a "clap" when it slaps shut.

**Size:**

- **Wall:** 3 x SET_OFF tall (4.8, over CHAIN_TOP, so it can't be climbed
  without the stair or a wall kick chain).
- **Stair mode:** treads RISER 0.28 by TREAD 0.5 by STAIR_WIDTH 2.0, so 17
  treads run about 8.5 m along the face.
- **Peg mode:** pegs STAND deep by TOP_ROOM wide, SET_OFF apart up, reach x
  0.6 apart along.
- **Rune:** within a standing reach.
- **Face:** flat at least WALL_TALL in every bay, so the closed wall can be
  wall-kicked between treads.

**Collision:**

- **Treads:** each is its own AnimatableBody3D hinged at the wall: a clean
  walk box, solid only while it is more than 30 degrees open (so a closed
  tread is just wall, and no sliver of collision juts out).
- **Wall:** a flat convex hull, wall-kickable, with tread recesses filled
  (no ledge lips, except in peg mode, where a closed peg leaves a STAND-deep
  lip at a set-off, so the closed wall is a ledge-grab route for a skilled
  climber).

**Motifs it enables:**

- *The makers' gate*: a sheer wall to the summit where only the hand opens
  the way. The headless body stands at the rune and must be lured off it.
- *The folding tower*: a shaft lined with four fold stairs on four faces,
  each one's top opening the next face's rune, a spiral you have to keep
  moving up.
- *The sling cliff*: peg mode on a cliff over a gulf. The fold throws you
  across to the next isle when you stand on the outer edge.

**Threat pairing:**

- **Danger:** the stair folds under you as you climb, and the tread at your
  feet slaps shut, tipping you off outward or flinging you into the face
  (that is, back down). A tread unfolding into a pilot hanging or climbing
  in front of it slaps him off.
- **Tool:** the fold's fling is a free pump up the face. Chained tread to
  tread, it is the fastest climb, and the unfolding slap knocks enemies off
  ledges.

**Catches / throws:**

- **Catches:**
  - *Standing:* carried by the tread's swing.
  - *Airborne:* a landing on a tread counts.
  - *Hanging from a tread lip:* carried with it.
  - *Tumbling/stunned:* a stunned body on a tread is carried and folded off
    like anyone, and a stunned body thrown into the hand rune triggers it.
- **Throws:**
  - *Tread folding shut, past `knock_angle` (1.0 rad):* `motor.toss` at the
    tread's pace at his feet. That is mostly up the face and a little in,
    about pump x 1 to 1.4 of rise at the tread tip, so you're thrown up
    alongside the next tread or a wall-kick height. A stunned body goes up
    still stunned.
  - *Tread unfolding into a body in front of the face:*
    `motor.knock(v, fold)`, outward and down at the tread tip's pace (about
    6 m/s at a 1.5 m tread in 0.25 s). This one stuns.
  - *Hanging on a closing tread's lip:* shaken off (`toss`).
- **Aim:** both throws are fixed to the face. Up the face (toss) or straight
  out from it (knock), aimed by the wall's own facing, which the motif sets.
  `kick_out` tilts the fold's toss away from the wall (0 to 0.6), so it can
  throw across a gulf instead of up.

**Chains with:**

- **Yoke Lift:** the top stop delivers you to the rune.
- **Seesaw:** a seesaw at the foot of the wall flings a block at the rune.
- **Wind vent:** an updraft at the top of the stair catches the fold's fling.
- **Tower shell's chimney:** a folding face inside it.
- **Rune Dial:** a dial's sling hits the rune from across a gap.
- **Headless body:** unfold-knocked off its ledge, or its mantle wave
  triggers the rune.
- **Inhaler head:** spits you flat against the face, and you catch a tread.
- **Cannon:** shoot the rune.

**Build cost: medium.** It is the flip trap's per-slab phase rhythm and
knock-angle throw, re-axed to a vertical hinge layout, plus the rune link.
The collision-while-open rule and the chase ripple are the new feel work.
The model is procedural (a flat face and slab treads).

**Model budget:**

| Trick | Applies? | Estimated saving |
|---|---|---|
| Parallax depth | The big one: the closed treads' outlines, the hinge grooves and the hand rune are parallax and shader grooves on one flat face, not real recesses. | About 8-12k tris saved per wall. |
| Silhouette geometry | Yes: the treads' outer edges chipped (they're seen edge-on as they swing). | n/a |
| Vertex-colour grime | Yes: the dark under each tread, pale underside. | n/a |
| Import LODs | Yes: a closed wall at range is one quad set. | n/a |

Total about 3k tris for a 17-tread wall.

---

# Breath Pillars (works_breath, family works)

**Verb:** time a crossing, ride (an elevator), launch, escape (a well).

**Look:** A tight field of square basalt pillars standing flush into a floor,
like the tops of a buried colonnade. Each top is carved with a closed-mouth
face, the inhaler head's lips with no eyes, and the joints between them
breathe dust. The field is one held breath: water and air in a sealed cistern
under the floor, built by the same makers as the head that inhales. Moss
grows thickest on the pillars that have not moved in a while, which is the
tell of a quiet one.

**Behaviour:**

- **Sinking.** A pillar with weight on it sinks at `sink` (walk x 0.2) after
  `wait` 0.2 s, down to `deep`.
- **Rising.** The field's volume is conserved: the sunk volume rises evenly
  in its neighbours (the 4 or 8 around it, `reach_mode`), at the same rate,
  up to `high`.
- **Running across.** A wave rises behind the runner, and the field is
  flat ahead of him.
- **Standing still.** He sinks into a well while the walls round him rise
  past GRAB_TOP.
- **Slam.** A slam on a pillar is a blow: it drops `deep` at once, and its
  neighbours spring up by the same share at once, stopping dead at `high`.
  That flings whatever stands on them.
- **Relaxing.** With no weight, the field relaxes back to level at
  `exhale`.
- **Overrun.** Past `deep`, a pillar's face-lips part (the mouth opens) and
  the top tips open as a valve, dropping you one layer down.
- **Tell:** a pillar's lips glow faintly as it is loaded, and its neighbours'
  rims glow brighter as they are about to rise. The field "inhales" (a
  breath sound) as it rises. A quiet idle swell (0.05 m, 4 s) shows the
  field is live.

**Size:**

- **Tops:** run x 0.5 square (2.4, over TOP_ROOM).
- **Spacing:** pillars flush or with `gap` up to reach x 0.4.
- **Wells:** a sunk pillar between risen neighbours is a 2.4 m wide well,
  under KICK_GAP from tower_shell, so it can be wall-kicked out.
- **Range:** `deep` CHAIN_TOP (2.575), `high` SET_OFF. A full well from the
  sunk top to the risen tops is over CHAIN_TOP, so it needs a wall kick or a
  slam-fling to leave.
- **Field:** 4x4 to 6x6. Rows of 1 x n make a corridor.

**Collision:**

- **Pillars:** each is an AnimatableBody3D, a clean top box plus a tall
  convex shaft whose flat side faces are wall-kickable (at least WALL_TALL
  exposed when it sits proud of a neighbour).
- **Valve top:** two half boxes that hinge down past `deep`.

**Motifs it enables:**

- *The breathing court*: the floor of an inhaler head's arena. The head's
  inhale and the field's breath are one rhythm, and the head's pull drags
  you across a field that wells under you.
- *The lung stair*: a 1 x 6 corridor up a slope. Each pillar you stand on
  lifts the next, so standing still climbs you (slowly), and a slam
  catapults you up the row.
- *The cistern floor*: drowned, the risen pillars sit just above water, and
  the wells fill.

**Threat pairing:**

- **Danger:** stand still and you're walled into a well, and stay too long
  and the valve drops you a layer. A headless body stomping in the field
  slams a pillar, so the ones around it (and you) are flung.
- **Tool:** slam where you want the spring, and the neighbour you stand on
  is a launch pad you aim by choosing which neighbour. Lure the body onto
  the field to fling it, or to sink it into a well where it is stuck and
  harmless.

**Catches / throws:**

- **Catches:**
  - *Standing and riding:* sinks or lifts with the pillar.
  - *Airborne:* a landing loads and blows by fall pace, so a high drop is a
    slam-lite: a pilot dropped from a throw sets off the field.
  - *Tumbling/stunned:* a downed body weighs and sinks, so a stunned pilot
    sinks into a well while he is down, which is a real Spelunky moment.
  - *Hanging from a pillar's lip in a well:* carried up or down with it.
- **Throws:**
  - *A risen pillar stopping dead at `high`:* `motor.toss` straight up at
    `launch` x the rise pace (capped about 7.8 m/s, roughly 1.5 pumps), with
    `lean` x that away from the slammed pillar. Still stunned if stunned.
  - *Valve:* not a throw but a drop: "layer" under.
  - *A pillar rising into a body hanging from a neighbour's lip:*
    `motor.knock(v, breath)` up and outward, the pillar shoving him off the
    lip.
- **Aim:** each throw leans away from the pillar that was slammed. The 8
  neighbours give 8 directions, and the motif or generator chooses which
  pillar carries the rune-marked "slam here" plate, so the field can be
  pointed at the next link. Speed is set by the slam (or drop) speed.

**Chains with:**

- **Inhaler head:** its gulp-and-spit lands you on the field, which is a
  slam.
- **Headless body:** its mantle wave.
- **Seesaw dropper:** blocks fall onto pillars.
- **Wind updraft:** catches a pillar launch.
- **Rune Dial:** its path ends over the field.
- **Yoke Lift:** pans set in the floor as a field's corner pillars.
- **Calendar Drum:** a drum rolling across the field is a moving load,
  pressing a trough of risen pillars as it goes, which flings anything in
  its wake.

**Build cost: medium.**

- *Simple bodies:* vertical kinematic boxes, simpler than the seesaw.
- *The new logic:* the conserved-volume step, where each pillar chases a
  target height on the spring, and the targets come from the loads summed
  over the field.
- *The valve:* small.
- *The model:* procedural shafts, with one carved face top sculpted once and
  instanced.

**Model budget:**

| Trick | Applies? | Estimated saving |
|---|---|---|
| Sculpt high, bake low | Yes: for the face top, baked to about 600 tris and instanced. | 36 pillars cost about 25k tris, not 300k+. |
| Import LODs and visibility ranges | Yes: past 30 m the face tops swap to a flat quad. | n/a |
| Parallax depth | Yes: the lips and the joint cracks. | n/a |
| Vertex-colour grime | Yes: down the shafts below the rest level (seen only in a well). | n/a |
| Silhouette geometry | Only on the top rims. | n/a |
| Shafts | Flat-sided, 12 tris each. | Frame time is mostly the 36 bodies: Jolt kinematic steps, about 0.1 ms. |

---

# Calendar Drum (works_drum, family works)

**Verb:** time a crossing, ride (hop on at the turn), slide (the trough is a
half-pipe), launch.

**Look:** A colossal basalt cylinder lies on its side in a U-shaped stone
trough. Its round face is carved as a calendar stone, a day-sign ring round a
blind Olmec face, and its barrel is banded with runes. The trough is worn
glassy-smooth along its fall line, with roots growing over its lips. The drum
rolls back and forth in the trough as it has for millennia, a pendulum that
never stopped. At each end the trough rises to a lip with a stone stop shaped
as two cupped hands. Where it sits beside an inhaler head's isle, the
calendar face is the head's own, carved flat.

**Behaviour:**

- **Swing.** It swings back and forth on a pendulum (`period` default 5 s)
  between the two end lips, honestly rolling: spin = travel / radius, so
  its top surface runs at about 2x its pace.
- **Pace.** At the bottom it goes over run pace (height `rise` = drum
  diameter, so pace is about sqrt(4/3 g rise), roughly 9 m/s at 2.6 m). At
  each end it stalls for `stall` 0.5 s against the hands, clacks, and rolls
  back.
- **Rune at a lip.** Touching it holds the drum at that end for `hold` s
  (a wedge drops), and touching it again releases it as a hard push (a
  "shot").
- **Loop variant (`track` = "loop").** The drum runs at an even pace round
  a ring-shaped groove round a motif, like a millstone round a pivot.
- **Tell:** the trough's fall-line groove has a rune line that lights just
  ahead of the drum (you see where it is going), a rumble rises with its
  pace, and dust lifts from the lip it approaches.

**Size:**

- **Drum:** diameter CHAIN_TOP (2.575). Over a pump (1.5), so jumping it
  takes a pump plus twirl (TWIRL_RISE) or a wall kick off the trough side.
  Length run x 0.5 (2.4).
- **Trough:** floor width = drum length + 2 x STAND (alcove margin is not
  enough on its own). Sides curve up to about 40 degrees (under SLIDE_AUTO
  44, so they can be stood on and run along) and rise SET_OFF to the lips.
- **Alcoves:** every reach x 1 along the sides there is a STAND-deep cut, a
  cover socket the drum passes.
- **Length:** end lip to end lip is about the pendulum's travel, roughly 4
  to 5 drum lengths.
- **Size knob:** the `size` knob runs from 1.6 (a small drum: a pump clears
  it) to 4 (colossal: a flying-through bore is not offered; too heavy).

**Collision:**

- **Drum:** an AnimatableBody3D cylinder hull (convex, so it is honest), with
  a top the pilot can stand on.
- **Trough:** convex wedge hulls for the curved sides (walkable slope
  faces), clean boxes for the floor and lips, and alcove walls flat and
  kickable.

**Motifs it enables:**

- *The ballcourt*: two parallel troughs with a drum each, swinging out of
  phase, between two stepped stands. The crossing is the perpendicular
  dash.
- *The mill*: the loop track round an isle's dais (or round a Rune Dial's
  rim, turning it as it passes).
- *The descent*: a long sloped trough down an isle, where the drum runs
  away to the lip and drops onto the layer below (one-shot, `runaway`).

**Threat pairing:**

- **Danger:** it fills the trough, so you must time the crossing or duck
  into an alcove. Standing on its top as it speeds up throws you forward
  off it.
- **Tool:** hop on at the stall, ride its first metre, and jump off forward
  carrying its top's pace (2v), a running long jump plus. The trough sides
  are a half-pipe for slide-jumps. Held by the lip rune and released, it is
  a battering ram for enemies.

**Catches / throws:**

- **Catches:**
  - *Standing on its top:* carried by its surface (`motor.carry` with the
    rotation delta: he is walked round it, as on the logs), so standing
    still near the bottom of its swing walks him off its front.
  - *Airborne:* a landing on it counts.
  - *Tumbling/stunned:* carried and rolled off like anyone, as the logs.
  - *In its path on the trough floor:* hit.
- **Throws:**
  - *Hit by its barrel:* `motor.knock(v, drum)` along its direction of
    travel at its pace plus a pace's share up (about 9 m/s at the bottom,
    under 2 at the stall). It stuns, and he's bowled down the trough ahead
    of it, toward the next lip.
  - *Leaving its top:* his velocity is `velocity_at` the drum's top (a
    plain carry-off, no toss).
  - *At a stall, a body on the drum's top:* `motor.toss` past the lip at
    `jolt` x the top pace as it stops dead against the hands. That is the
    out-of-trough throw, up and over the lip. A stunned body is tossed still
    stunned.
- **Aim:** knock and toss both run along the trough's axis, so the trough's
  orientation (set by the motif) and which end is the aim. The released
  "shot" picks the speed. The loop variant throws tangentially from the
  point it stalls at, if `stops` are set.

**Chains with:**

- **Seesaw:** its high end at a lip, so the drum's arrival is an `impact`
  and flings the low end's rider. That is idea 4's "into a Seesaw's high
  end", made real.
- **Logs:** a drum bowls a stunned body onto a run of logs.
- **Breath Pillars:** across them, a moving load.
- **Yoke Lift:** the stall toss lands on a pan, a blow.
- **Inhaler head:** its blow lane down the trough is an extra shove, and the
  head can be bowled by a released drum (a later enemy reaction).
- **Plinth ram and headless body:** knocked off.
- **Wind vent:** at a lip, it catches the toss.
- **Sluice:** a flooded trough is drums plus wash.

**Build cost: medium-high.**

- *Physics:* the motion is kinematic (no rolling RigidBody, so it can't
  jam), but the honest spin and carry, the alcove and side-slope feel with
  the motor's slope rules, and the stall toss need tuning.
- *Model:* the calendar face is a Blender sculpt baked down (the face is
  the showpiece). The trough and barrel are procedural.

**Model budget:**

| Trick | Applies? | Estimated saving |
|---|---|---|
| Sculpt high, bake low | Yes: both calendar faces, about 4k tris each. | Down from 80k+. |
| Parallax depth | Yes: barrel runes, the trough's polished groove. | n/a |
| Silhouette geometry | Yes: chips on the drum's rims only (they turn, so the outline reads). | About 1.2k on the barrel instead of a chipped 10k. |
| Vertex-colour grime | Yes: in the trough's corners and under the lips. | n/a |
| Import LODs | Yes: the face drops to normal map only at range. | About 0.03 ms. |
| Rigid parts on bones | Not needed: a single rigid body. | n/a |

---

## Notes for whoever builds these

- All five are moving bodies and feel work: Opus per AGENTS.md. Each round
  proves itself through the real play loop (the yard's TrapField, real
  input), with a smoke check, as the prototyping rule says.
- The rune link plus the eye-light tell is worth building once, first, with
  the Fold Stair (the simplest trigger to actuator case). The Yoke Lift and
  Breath Pillars then reuse the seesaw's weight and impact code. The Rune
  Dial and Calendar Drum need the carry-with-turn and the tumble's stop-dead
  jolt.
- Every throw names its piece as the `knock` source. Pieces that only lift
  (pans, pillars, folds, the drum's stall) `toss`, so a chain through them
  never spends a restun.
