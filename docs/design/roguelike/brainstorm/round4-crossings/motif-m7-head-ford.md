# The Head Ford — "A great head came down here and the river of stones runs round it"
Lenses: verb chase / pure platforming · scale a fragment of something bigger · decay dismantled on purpose (twist: an Olmec piece as terrain, not enemy)

Pitch: Two isles with a quarter-mile of air between them, and in the middle
of it a colossal basalt head that fell on its side and sits like a boulder
in a stream, its brow a cliff, its ear a cave, its ruined stones scattered
around it as a ford. You jump to it, over it, through it, with something
else in the dark that came from the same head.

Place: A high chamber of the city, shaped like a long drowned valley with
no water, lit from one direction by the roof's rift. The near rim is a pier
on the nearer isle with a pair of fallen lamp-stands. The sight on arrival
is the head: the size of a house, lying on its right cheek, the eye
socket empty, the headless-body's own cutting grooves round the neck stump
(the same carving as the walking bodies), the same pebbled stone with
lichen and a stripe of pale where it was lowered. A skirt of its own
chipped pieces and neck drums lies round it. Beyond it, further than the
gulf you could cover, the far isle sits like a cloud bank. How it broke:
the head was being carried across the gulf on a sledge of timbers (the
timbers are long gone, the sledge's stone runners lie in the gulf), and
dropped. The ford of stones is where the runners and the sledge's cribs
landed: low-set blocks, less than the drum stacks of the Unbuilt Span.
Land: basalt, haze, dry ash-fall; the head has dry lichen on its brow, and
the view is the quietest of the set.

Top (1 char ~ 4 m):
```
  ^^^^                                                     ^^^^^^
  ^1^^ #.#  #  #  ~  #.#   ########   #.#  #    #.#  #.#  ^^2^^^^^
  ^^^^.#   ~~ #. #~~~#.##~~#  HEAD ##~~#.##  ~~~#.###.#~~~~^^^^^^^
       #. #       #       ########        #     #    
```
Side (1 row ~ 4 m up):
```
 near          low blocks      THE HEAD           low blocks      far
  ___          _     _        ,-----""-.         _    _             ___
 | | |_      _| |_  _| |_   ,'  (eye)    `.    _| |_| |_    _     | |
 |_|_|_|____|_|_|_|_|_|_|__/ chin   ear   \__|_|_|_|_|_|__|_|___|_|_|
 ~~~~~~~~~~~~~~~~~~~~~~~~~~ haze, no floor ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

Play: The head is a *hub*: both routes touch it, and where you cross it
decides what you face.

*Over the head (fast, risky).* From the near ford, long-jump chain onto the
low blocks (8.5 m gaps, 1.5 m rises), a wall-kick up the brow's cliff (the
brow face is 5 m of kickable basalt: WALL_KICK 5.2, WALL_RISE 1.5 per kick,
three kicks, with ledge grabs on the eyebrow ridge), across the crown (a
broad curved top: sliding down its far side, SLIDE_AUTO 44, builds enough
speed that a slide-jump off the nape clears 11 m to the far blocks, and a
twirl at the peak adds more). The head's crown is a rest (it is wide) and a
perch (the hunter cannot climb it fast, its climb knob is 20 wanderer
heights but the face is overhung).

*Through the head (slow, safe).* Walk in the left ear, under the head's
cheek through a dark passage (the neck stump's hollow), lamp-lit with the
rift's light. Out through the mouth (a shelf, 3 m up, with a dropped
lower lip at the head's front), onto the far ford. No jumps greater than a
pump. It is slow, narrow and dark, and the hunter's sight can't see into it
(Sight is blocked by the head's mass), but the hearing carries (a landing
on the chin shell hushes nothing).

*Around (the ford).* Low blocks left and right of the head, a pure long-jump
chain with no rest, 9-10 m gaps, the hunter's way too.

Threat: **The Stalker**, a headless body that comes from the far isle
and has to cross as well: it takes the ford (its planner jumps and leaps,
`jump_gap` 3 Hh), and *climbs the head* (its `climb` and `climb_max` knobs:
the head's brow is a 5 m wall: past a normal step 2.4 m, within
`climb_max` 20 wanderer heights). So the hunter crosses *toward* you, not
after you, and the head is the single place you'd meet. Its landing
shockwave breaks the ford's low blocks (marked) and can rock the head
(it does not move: it is a tomb, it settles). Its approach tells where
you'd use the ear passage (it stops outside, and listens). A body that
is stunned out of the ear is tossed onto the ford. The tool: take its
shock knock to launch you onto the head's crown (its throw is a body
length; the crown is a body length away).

Could combo: a knocked body on a low block lands on the head's brow =
a shortcut; the hunter's climb up the brow while you slide down the crown
= you pass each other; an inhaler head hovering over the crown (its suck
pulls you toward it) = the passenger of a head of a head. Ports: it
catches a body thrown from the near pier and throws one toward the far
isle at a roughly flat angle.

Mystery: The head is the same carving as the walking bodies, but it has an
eye. It is the one that was *not* made headless. It fell; or it was
dropped by the ones who were told to carry it. Something inside the ear
shows runes in the dark.

Kit used: city_pillar (the near/far piers), maker_felled (the neck drums
and plinth), colossus_drum (the broken skirt), city_wedge (jammed slabs on
the crown), city_lip (the mouth shelf, the ear sill), city_riser (the
cheek-step), headless_body (the stalker) and inhaler_head (the pull).
Kit asks:
- maker_head_fallen (family city): a colossal head on its side, a convex crown, a 5 m brow cliff, an ear passage (collision tunnel), an empty socket, a neck stump with hollow; walker-only holds and an Olmec climb face; the model-budget tricks of instancing the pebbled scale mesh and a hull-only collision.
- maker_ford_block: a low (1-3 m) cut block with a mark, shearable.
- A sight-block flag for big stones (hush), reuse city_hush logic.
Family knobs: head_yaw (the head's lie across the axis, 0-80 deg), ford_density (6-14 blocks), ear_side (left/right), stalker_present (0/1: a quiet version without the stalker is a pure platforming crossing).
Sockets: rim x2, arena: the head's crown, cover: the ear passage, perch: the brow ridge and the lip.
Generator fit: a *motif with its own two shores* (a crossing as a place): footprint 100-140 m by 40 m, height span +-14 m (the head is 14 m tall), drop between rims -4 to +4 m. A tall-stack shape of the layer; place it when the plan has a long edge with a gap too wide for the Unbuilt Span's length, or as a middle motif.
Distinct from: the Unbuilt Span (many stacks, one hunter behind you; this is one dominant object and a hunter that comes toward you); felled_colonnade (a fall that makes a bridge: here the fall already happened and the head is the terrain).
