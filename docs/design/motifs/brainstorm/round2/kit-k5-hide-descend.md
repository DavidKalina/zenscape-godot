# Kit k5: stay hidden / fall and descend

Lenses: verb stay hidden + fall/descend; scale intimate to human; mood
oppressive; shape a tall stack (isles over isles).

Sizes are named by their source: the pump is PilotMotor `JUMPS[1]`, the
fall stun `fall_stun_height()` (FALL_STUN_PUMPS pumps), the fall that hurts
FALL_HURT_PUMPS / FALL_HARD_PUMPS pumps, his height PhysicsGround.HEAD,
reach RuinKit GRAB_TOP / CHAIN_TOP / STAND / SET_OFF, flown openings
`WorldScale.opening(toy)`.

What "hidden" means in the code today, which these pieces are built to:
- The guacharo (scripts/enemies/guacharo.gd `_sense`) reads him as "cover"
  when one ray straight up from his middle hits anything (`field.blocked`,
  walker-only layer stripped) within `cover_up` walker units. Hanging, on a
  wall, on a rope or by a rim he is exposed, unless that ray finds cover.
- The body's sight (scripts/enemies/body_sight.gd) casts rays to his feet,
  chest and head (`pilot_points`, PhysicsGround.HEAD tall, not lowered by
  crouch) and stops them on the ground's mask.
- The body's ears (scripts/enemies/body_hearing.gd) hear the NoiseBus. A
  landing is loud by the drop (a 4-pump fall is about 41 m of loudness),
  and crouched on the touch it is quieter (scripts/noise/wanderer_noise.gd).
- The Weeper moves only while the camera can't see it, so cover that hides
  him also hides it.

---

# Pent hood (`pent_hood`, family cloister)
Verb: stay hidden under it; on top, slide off it down the stack.
Look: a lean-to stone roof run out from a wall face on stone corbels, its
  slabs lapped like a cloister's pentice, sagged and cracked at the ends,
  with a low parapet along the open side. Under it is a dark, low gallery,
  narrow and close: a place you squeeze along rather than walk.
Behaviour: static. Knob `fallen` (0-2 bays) drops slabs out of the roof,
  leaving gaps where the sky shows through. Under a gap he is not covered,
  and you can see where the gaps are from inside.
Size: clear headroom under the eaves a little over PhysicsGround.HEAD (he
  stands, never jumps), the gallery's floor STAND to TOP_ROOM wide (one
  body, no passing). The parapet is taller than PhysicsGround.HEAD and
  under GRAB_TOP, so standing behind it hides his head ray and one jump
  catches its coping to vault out. The roof's pitch is steeper than
  SLIDE_FROM and under SLOPE_SLOW: he can stand and walk on it, and if he
  lands or presses crouch there he surfs (the balustrade's pitch is a good
  first value). Its high edge is under the wall's top by less than
  SET_OFF, so he can drop onto it from the wall walk. Bays are
  WALL_LENGTH long, so it lays on a kit wall.
Collision: the roof's top is one clean box per bay, tilted to the pitch,
  so the surf reads one slope with no seams. The gallery floor and the
  parapet's coping are clean boxes. The parapet's outer face and the back
  wall are hulls, wall-kickable (the gallery is too low for a kick to rise
  in). The corbels have no collision (they sit inside the roof's box).
  The underside of the roof slabs is real stone on the ground mask, so it
  is what the guacharo's up-ray hits.
Motifs it enables:
  - A rim walk round the top isle of a stack, hooded the whole way, with
    the guacharo circling outside. Each fallen bay is a dash across open
    sky.
  - A run down the hood's roof and off its eaves into a long jump or the
    sail, falling to the next isle down: the hide and the drop are one
    piece.
  - A headless body walks the open turf outside the parapet while he
    crouches in the gallery. The parapet blocks its sight; the noise he
    makes is the only thing that gives him away.
Catches / throws: standing: covered underneath, and on the roof he stands
  or surfs. Airborne: lands on the roof and, crouched, surfs down the fall
  line to the eaves and flies off at the slope's pace (SLIDE_PULL, capped
  by SLIDE_TOP). Tumbling/stunned: a body knocked onto the roof slides down
  it as any stunned body on a slope and is thrown off the eaves, still
  stunned. Outputs nothing of its own: no knock, no toss.
Build cost: low. Procedural in RuinKit's Build (boxes, wear, growth),
  roughly a vault and a wall's coping put together. Connectors in
  ruin_kit_fit.gd: its back to a wall face, bay to bay along it.
Model budget: silhouette geometry (chipped slab ends and broken bays are
  real geometry, the slab faces flat); vertex-colour grime (dark soot
  under the eaves, so the gallery reads dark without a light); import LODs
  and a visibility range (it repeats round a rim).

---

# Corbel shaft (`corbel_shaft`, family tower)
Verb: descend through the isle, hidden all the way down, and out of its
  keel into the gulf above the isle below.
Look: a square shaft sunk into an isle's turf, roofed at the top with a
  small well house (a pointed door, a capstone) and open at the bottom
  through the keel. It is coursed stone inside, wet, with corbel stones
  stepping down the two side faces and arrow slits on the outward face
  where you can look out over the gulf. The bottom opens as a ragged
  throat in the keel, with hanging roots round its lip.
Behaviour: static. Knobs: `stages` (2-5, how deep it goes through the
  plate), `slits` (which stages have a slit), `throat` ("open" into the
  void, or "heap": a heap of soft ash at the foot on an isle you can't fall
  out of).
Size: the side faces stand ruin_kit_tower.gd's KICK_GAP apart, so he can
  wall-slide one face (no faster than WALL_SLIDE) and kick across to the
  other, down or up. Because a wall slide restarts the fall stun's height,
  a shaft any depth can be slid down without a stun. Corbel ledges are
  STAND deep and SET_OFF wide, set at most 3 pumps apart down alternating
  faces (under `fall_stun_height()`), so a missed slide or a plain drop
  from one ledge to the next never stuns. The well house's door is the
  kit's DOOR. The slits are at PhysicsGround.HEAD and narrower than twice
  SOLE, so he can look out but can't fit through. The throat's lip is a
  STAND-deep ring that he hangs from before letting go. Front to back
  (DEPTH) is wider than KICK_GAP, so he faces the side walls to kick.
Collision: each corbel top is a clean box (grabbed falling past, as the
  ledge finder wants a top to stand on). The side faces are hulls standing
  well over WALL_TALL (wall-slide and kick faces). The capstone and well
  house roof are real stone on the ground mask, so the up-ray from inside
  hits stone at every stage. The slits are cut through the outward hull.
  The throat's lip is a clean ring of boxes.
Motifs it enables:
  - A stack read from the top down: each isle's shaft drops you out of its
    keel, and you sail across to the next isle's well house and go down
    again, never under open sky for long.
  - An escape hatch: the guacharo is stalking you on the top turf, you duck
    into the well house, and it loses you ("cover", then ABORT).
  - A sealed dark shaft (`throat` "heap") under the underground look: you
    feel your way down by wall slide, and the slits are the only light.
Catches / throws: standing: covered inside and hidden from sight (the stone
  stops the rays). Airborne: falling past a corbel lip he faces, he catches
  it; with the stick held into a face, he wall-slides. Tumbling/stunned: no
  catching, so a stunned body falls the whole shaft. On "heap" it lands on
  soft ground and is caught. On "open" it falls out of the keel into the
  gulf, and the poise gives him the sail on the way down. A twirl-tech
  near a corbel catches its lip. Outputs: out of the throat straight
  down at his own fall speed, no knock or toss.
Build cost: med. Procedural (the tower shell's walls turned inside out and
  sunk, with corbels), but it cuts down through the isle: KitLand has to
  leave a hole through the turf and the keel for it (see engine gaps).
Model budget: silhouette geometry (broken corbels and the ragged throat
  are real, the coursed faces are flat); parallax depth for the coursing
  and wet joints inside (seen up close the whole way down); vertex-colour
  grime (it darkens with depth, drips under each corbel); import LODs (the
  inside is never seen from far, so the inner faces can be culled by
  visibility range).

---

# Catch net (`catch_net`, family cloister)
Verb: fall into it: a stop on the way down the stack. Hide under it.
Look: an old fishing/cargo net of tarred rope slung between two stone
  heads (the cloister's bridge heads) or two piers, under an upper isle's
  rim. It sags, with patches of moss and dead leaves caught in it, and is
  torn in places. From above it looks like the only soft thing in a hard
  place.
Behaviour: changes state. It sags under a landing (a dip and a spring back
  over about a second) and carries him as it moves. Knob `torn` (0-3
  holes: each one a gap you fall straight through to the next tier).
  Knob `spring` (off by default): if he slams into it, it throws him back
  up about a pump. That is the net bouncing back, never higher than he
  fell from.
Size: spans two to three TOP_ROOMs across and as long as a rope bridge's
  gap. It hangs under the rim above by up to FALL_HARD_PUMPS pumps, so a
  fall off the rim lands in it unhurt. Its soft meta: `catch` at
  FALL_HARD_PUMPS pumps (no stun, no harm on any fall from the tier
  above), `keep` small (his pace is killed: he stops where he lands),
  `slow` like a wade (crossing it is slow going). The hem rope is a lip
  under GRAB_TOP over the stone at each end, so he climbs off it onto a
  head. A hole is wider than twice TOP_ROOM, so you see it.
Collision: one clean, gently dished box surface (or a few, following the
  sag) marked soft ground and moving ground, its offset driven by the sag
  spring. It is on the ground mask, not walker-only, so it is cover from
  the guacharo for anything under it, and the hem boxes are a ledge. The
  holes are left out of the surface. No hulls: you can't kick off it.
Motifs it enables:
  - A stack built to fall down: each tier's rim has a net under it, and the
    way down is jumping (and choosing which net, past the torn ones).
  - The safety net under a fight: a body or ram that knocks you off the top
    isle drops you into the net, not the void. Climbing back up is the
    cost.
  - A hiding place under the net: the guacharo circles, you cling to a pier
    under the net's belly, covered.
Catches / throws: standing: he wades across it, and it carries him through
  the sag. Airborne: he lands in it with no stun and no harm from up to
  FALL_HARD_PUMPS pumps, and his flat pace is cut to `keep`. Tumbling/
  stunned: the soft ground keeps `keep` of his slide, so a knocked body
  stops in it still stunned and stands up when the stun ends, a stun
  landed on rope. Slammed: with `spring` on, it uses `toss` up about a pump
  (source "catch_net", so restun_gap applies). Out of the holes: a plain
  fall.
Build cost: med. The sag is a procedural mesh with one spring (cheaper than
  the live rope-bridge sim, scripts/rope_bridge.gd). Soft and moving ground
  already exist (pilot_physics_ground.gd `mark_soft`, `mark_moving`). The
  muffled landing needs a small engine change (gaps).
Model budget: the net's mesh is alpha-cut: one sagged grid of quads with a
  rope-net texture, not modelled cords (thousands of triangles saved;
  alpha-scissor costs a little overdraw). Silhouette geometry only on the
  hem rope and the lashings to the stone. Import LODs (down to a single
  quad sheet far off).

---

# Hung screen (`keel_screen`, family gothic)
Verb: the plane threads under it or through its window. On foot you sail
  to it, hang hidden on it, and drop from its foot to the isle below.
Look: a lancet window wall hung under an isle's keel by two rusted iron
  straps sunk into the rock, as if the floor beneath the wall gave way and
  the wall stayed. Ragged at its foot, roots hanging from its top, the
  mullion gone from its window, in the gap between two isles of the
  stack.
Behaviour: static by default. Knob `sway` (off, slow): it swings like a
  slow pendulum on its straps, a few degrees, and carries him as moving
  ground. If he slams onto its sill it rocks (the floating stones' slam
  shove), so the window's clear moves for a few seconds: something to
  time the plane through.
Size: the window clear is the kit's WINDOW (`WorldScale.opening(TOY_WINDOW)`
  wide, the lancet wall's), flown with the mullion gone. Under its foot it
  leaves at least `WorldScale.opening(TOY_THREAD)` (THREAD) of clear
  height plus the plane's height to the isle below, so the plane can thread
  under it as well as through. The sill and the foot are the wall's depth
  (ARCH_DEPTH, over STAND), so both are lips to hang from and stand on.
  The foot hangs over the isle below by under `fall_stun_height()`, so
  letting go from it lands without a stun. The keel overhead is within
  `cover_up`.
Collision: the sill top and the broken foot's top are clean boxes (ledges
  and stands). The faces are hulls (wall-slide and kick; the plane bumps
  them as it bumps the kit's walls). The straps have thin hulls the plane
  can hit (a fair fail). The window's clear is empty, with the plane's
  bump hulls kept outside the WINDOW width.
Motifs it enables:
  - A stack you fly through: the plane threads between two isles and
    through the hung window of a wall that doesn't reach the ground.
  - The middle step of a descent: sail off the top isle's rim, catch the
    window sill, shimmy along it hidden from the guacharo (the keel is over
    you, the wall between you and the gulf), drop from the foot to the
    isle below.
  - A gallery of screens in a row under one long keel, each a hide and a
    window, with the Weeper on the isle below, moving only while the walls
    hide it.
Catches / throws: standing: on the sill (STAND deep) he is covered from
  above and hidden from the side the wall faces. Airborne / sailing: the
  sail folds into its face and he grabs or wall-slides (pocket sail
  meeting a wall). Hanging: he shimmies the sill and the foot. Tumbling/
  stunned: falls past (no catch), unless he techs into it, and the tech
  kicks off its face or catches a lip. Riding the plane: the plane flies
  through the window or under the foot. Outputs: none of its own. With
  `sway`, it hands him its swing as `frame_v` when he leaves it.
Build cost: low-med. It reuses the lancet wall's build (RuinKit
  `lancet_wall`, its WINDOW and wall sizes) cut at the foot and hung with
  two strap meshes. Static is low. `sway` needs a moving body and the
  slam shove (med), using the foot_slab code.
Model budget: silhouette geometry (the ragged foot and broken mullion
  stubs are real, the faces flat); import LODs and a visibility range
  (seen from far in flight); vertex-colour grime (rust bleeding down from
  the straps, damp under the keel); the straps are simple extruded bars,
  no detail.

---

## Combines with

- `pent_hood`: `wall` and `lancet_wall` (its back), `turret` or `stairs`
  (the way up to its roof), cloister arcade ranges (a hooded run round a
  garth), `balustrade` slide (a second slide line off the same rim),
  `rose_gable` (its end).
- `corbel_shaft`: `tower_shell` (its above-ground sibling: up one, down the
  other), `floor` slabs (the well house's floor), `fallen_pier` (the heap
  at a "heap" foot), hanging roots (the throat's fringe), `keel_screen`
  (what you see and sail to when you drop out of the throat).
- `catch_net`: the cloister's rope-bridge heads (its anchors), rope bridges
  (a bridge and a net strung from the same heads), `aqueduct_stump` and
  `pier` (posts to sling it from), sink and bob slabs (soft and hard ways
  down side by side), the plinth ram and headless body (what knocks you
  into it).
- `keel_screen`: `lancet_wall` (the build it is cut from), the hall family
  (`hall_column`, `hall_slab`: the hollow_keel motif's hung undercroft), `corbel_shaft` (it drops you
  out right by it), `swing_rope` (hung from the same keel as a second
  hold), floating and drift stones (rests in the gap between isles).

## Engine gaps found

- **Crouch doesn't hide him from sight.** `DragonSight.pilot_points` puts
  his sight points at fixed shares of PhysicsGround.HEAD whatever his
  pose, so a parapet only hides him if it is taller than his standing
  head. Lowering the points while crouched would make low walls cover.
- **Cover is one ray straight up.** The guacharo's "cover" is a single
  `field.blocked` ray from his middle: any roof with holes reads all or
  nothing, an open-topped shaft is never cover, and anything walker-only
  overhead isn't cover. The pent hood's fallen bays and the shaft's
  capstone are designed around this. A few rays, or a share, would let a
  torn net or a slatted roof read partly covered.
- **Soft ground doesn't muffle a landing.** scripts/noise/wanderer_noise.gd
  makes a landing's loudness from the drop and crouch only. The motor
  reports "soft" (the drop) in its events, but the noise ignores it, so a
  landing in the catch net or an ash heap is as loud as one on stone. A
  soft-ground `hush` share, alongside {slow, catch, keep}, would fix that.
- **A hole through an isle.** KitLand islands are a height function over
  a keel. A shaft going down through the turf and out of the keel needs a
  cut, or a collider and mesh mask, that KitLand doesn't offer yet.
  Without it, `corbel_shaft` can only stand in a built plinth or the edge
  of a cliff step.
- **Catching a lip at terminal speed.** A ledge catch falling past a lip
  at TERMINAL moves him about 0.3 m a frame against GRAB_LOW / GRAB_HIGH
  slack. Corbel spacing at 3 pumps keeps him under terminal, but this
  should be checked in the real motor before deeper spacings are used.
- **Nothing gives a slammed body back its height.** The motor's rule is
  that no pace turns into height. The catch net's `spring` would be the
  first world piece to turn a slam into a rise, through `toss`, and
  belongs off by default until it is played.
