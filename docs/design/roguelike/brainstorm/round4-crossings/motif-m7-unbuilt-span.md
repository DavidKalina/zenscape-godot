# The Unbuilt Span — "They took it apart to carry it home, and left the stones where they set them down"
Lenses: verb chase / pure platforming · scale a fragment of something bigger · decay dismantled on purpose (twist: the threat as the only way across, in part)

Pitch: You come out of a gallery onto a rim and see the bridge that was
never finished being finished: a causeway of colossal drums and lintels,
pulled apart by its makers mid-lift, every piece stopped in the gulf where
the work crew left it, a whole far isle hazy at the other end. A headless
body is already on the first pier, and it has seen you.

Place: Underground Olmec city, the great gulf between two sunken isles, a
haze-filled dark with the roof lost far above and the floor lost far below.
You arrive on the near rim (a square landing on a corbel, the same stone as
the generator's landings) and look along the *line of the bridge*: it was
meant to be a straight processional causeway, 8 cells wide, and you can read
where it ran because the stones still stand in that line, then wander off it
the further they are. Near: three plinths left at full height with the
causeway deck stub still on them, like a dock. Middle: the field. Drum
stacks of 2, 4, 6 drums standing on their own sunken columns, shafts
vanishing into the haze, each stack topped flat and chipped. One lintel
(a 6 m slab) balanced on a single pier, tilted, one end in the air. A
capital lying on its side as a stepping stone. A rope-less hoist frame (two
leaning posts, nothing hung) is the silhouette that tells you "dismantled",
not "collapsed". The far end is a single standing drum column wearing the
unfinished deck, then the far landing, 70+ m off, small, lit by one lamp.
Pale chisel marks, setting-out lines and a mason's glyph on every stone say
who did it and that it was on purpose. Stone is the city's weathered basalt;
the cut faces are pale where the makers last worked them. Haze, a distant
drip, nothing grows here: it is dry, dusty, worked-over.

Top (1 char ~ 4 m; the gulf runs west to east, 40 chars ~ 160 m):
```
 ^^^^                                                          
 ^1^^ #P#  #  ##     o      #        ##    #P#   ##   ^^^^^   
 ^^^^@#.#  ~  ##  ~  #  ~   #  ~  ##  ~    #.#   ##  ^^2^^^   
 ....# #.###.~~#~~~~~#.~~~~~~#.~~~~#.~~~~~~~#.#####.~~^^^^@^   
      # #       ##    #~~~~~~#                    ##
```
(Digits are the two shores, '#' is a stack top or the lintel/capital
stones, '.' route, 'o' the hunter, 'P' perches on the tall stacks,
'@' the hoist frame and the far lamp. The bridge's axis is the dotted line;
the fast route stays near it, the safe route sags south on lower stacks.)

Side (north-south section along the axis; 1 char ~ 4 m horizontally, 1 row
~ 4 m up):
```
 near rim    plinths    low  tall   lintel   cap.  tall  low   far column  far rim
 ___         _          .    #                     #                  #
 | |_  _    | |_       _    #     ,--/            #   _              #   ____
 | | |_| |__| |  _  _  #  _ #   _/ pier           # __#  _ _  _     #  _|  |
 |_|_|   |  |_| |_| |_|#_|#|#  |_|  |_|   ___ |_|#|_|#_|#_|#_|#_|#__#_|_|__|_|
 ~~~~~~~~~~~~~~ haze: every shaft goes down out of sight ~~~~~~~~~~~~~~~~~~~~~~
```
Drop from near rim to far rim: 6 m down overall; the stacks vary +-9 m.

Play: Two lines through the field, plus the interruptions.

*The fast line (along the axis, risky).* Stay on the dotted line and every
hop is a straight long jump chain, no stops: the tall stacks are 2-3 m above
the low ones, so the line goes high-low-high and each takeoff is a slide
into long jump, each landing a chain (a stone you land on is a re-takeoff:
LONG_CHAIN 0.2 s). Gaps are 7-9 m between stack tops with 1-3 m of rise or
fall, so a plain running long jump (7.6 m/s) covers the low-to-high hops
only if you chain (9.0 m/s) and twirl is the save at the dropped gaps. The
long jumps down (a tall stack to a low one: 9 m gap, 3 m drop) are the
gifts; the long jumps up (low to a tall one) are the toll: a chain of two at
the lip, or a wall kick off the tall stack's face, 5.2 up, to find the top.
The lintel balanced on one pier is a slide: take the high end and slide down
it (SLIDE_AUTO 44) off the low end to launch 6 m further than a plain jump.
Ends at the far column, whose drum face is a kick wall up to the deck stub.

*The safe line (south, slow).* Lower stacks and the capital, 5-6 m gaps,
one rest at each: never above plain jump + pump (JUMPS 0.8, 1.5). Longer,
more landings, more Olmec bearing on you. It rejoins the axis for the last
two hops, because the far column is the one narrow thing: you cannot skip it.
The safe line is where he lands most.

*The choice:* fast and one slip is a fall into the haze (a long way down, a
climb back from the turn below), safe and the hunter has time to reach you.
Skilled players run the axis and let him land behind them.

*Beat by beat:* (1) rim -> three plinths at jog (easy 4-5 m walks, you read
the field, the head turns); (2) the first gap is the "gate": 8.2 m, a
chain of two or a twirl, no choice; (3) the field, hunted; (4) the lintel,
a mid-field set-piece you can slide or pass; (5) the far column, a kick up
a stone face while he lands behind you and rocks it; (6) the far rim.

Threat: **The Hunter**, one headless body (scripts/enemies/headless_body.gd)
that starts on the third plinth with `chase` on and its `jump` and `leap`
planner (`jump_gap` 3.0 Hh, `leap_max` 11 Hh) on. It hunts you pier to pier
by sight (Sight, Hearing), taking the *big* stones: only stacks whose tops
are at least his lane (6.6 m, the destruction card's number) can be landed
on; the small perches, the lintel's high end, the capital are where it
cannot go (the walker-only). Its landing is `_shock` (power 0.6-1.5 by
impact): a ring of dust that knocks anything on the stone it hit, and
**breaks or rocks stones that are marked** (see Kit asks): a stack that is
cracked (pale hairline, dust trickle) shears a drum or two when he lands
hard, a drum lip crumbles off, the lintel rocks and its low end dips so the
slide changes. Landings are permanent for the run: the field is a different
route the second time. He is also the *only way across* in one place: the
far column's deck stub sits past your chain, but he can leap to the
plug/chock, and where he lands a loose lintel falls into the gap as a
bridge (a once-per-seed `chock` trigger, `maker_chock`'s landing rule).
The tool: his shock *knocks* you if you are on the stone, tossing you a
body-length, still stunned; the player can ride the toss to the next stack
(the stun is the combo, never the only way across). A twirl at his landing
is the answer.

Could combo: his landing shock + a stack that shears a drum under your
feet = tossed + a falling drum field (24-body cap, destruction round 1);
a slid lintel off a stack that he just rocked = a launch aimed further
than you chose; a rope-less hoist frame post is wall-kickable and sits
beside the middle stack, a perch to climb out of his reach. Ports: it
catches a body thrown from the near landing (an inhaler head at the near
rim blows a stunned you out over the field) and throws one onto the far
landing if the tumble carries far enough. The far column's deck stub is
where `maker_felled` could lie if the colonnade's drum fell this way.

Mystery: The makers were building a processional bridge to the far isle's
temple and stopped, and the stones they left are numbered: setting-out
lines, tally glyphs, a mason's mark repeated on every drum that matches the
one on the near landing. They didn't fall; they were unstacked. And the
hunter walks the line as if it still has work to do on it. Pale cut faces
say the removal was recent; the haze says it was long ago.

Kit used: city_pillar (CityKit.PIECES), city_causeway (the deck stub and
the near plinths), maker_felled and colossus_drum (CityKitBreaks: the
capital, drums, the plinth), maker_chock (CityKitBreaks2: the lintel's
loose-end rule), city_wedge (CityKitClimb: the jammed slab as a high
perch), city_lip, city_pit (CityKitClimb: two plinths across a gap, the
gate hop). Enemy: headless_body.
Kit asks:
- city_stack: a drum column of N drums on a sunken shaft with a flat chipped top, N 1-6, a mark on the top (cracked/whole), the drum seams cut so it can shear to the authored rubble. The existing `city_pillar` is isle-sized (apothem 7 cells); this is a single drum stack.
- city_lintel_pier: a 6-8 m basalt lintel balanced on one pier, with a tilt knob and a dip-on-landing state (rocks, then settles).
- maker_hoist: two leaning timber-and-stone posts, wall-kickable, a perch dressing.
- A "marked stack" hook so `_shock` can crack a stack (a `breaks` metadata entry) at power over a threshold.
Family knobs: stack_count (14-26 stacks), height_spread (+-5 to +-10 m), axis_bend (0-30 deg, so the bridge wanders), safe_share (how much of the south is walkable; 0 leaves a single line).
Sockets: rim x2 (near rim facing +x, far rim facing -x); arena: the middle stacks (the hunter's, the only ones wide enough); cover: the hoist frame and the tall stacks' lee side; perch: the lintel's high end, the wedge, the capital.
Generator fit: a *crossing between two places* (an edge), the long one: 120-180 m across, +-6 m net drop, +-9 m of internal relief. It replaces a plain `city_crossings` run of column tops wherever the plan has an edge longer than ~60 m; the stones the plan already lays are the fast line (their positions kept, their tops raised into stacks), and the safe line is an add-on. Layer shape: a line, spread wide.
Distinct from: felled_colonnade (one column, one fall, a lure puzzle on one isle: this is a long chase through twenty stacks and the Olmec follows); the generator's column-top stones (identical drums in a line: this is irregular, heights vary, and it has a hunter and a destroyed-on-landing rule).
