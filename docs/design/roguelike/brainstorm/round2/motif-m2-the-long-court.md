# The Long Court — "The game was played until the ball was a mountain"
Lenses: chase · ballcourt · half-collapsed · colossal · oppressive · a tight cluster
Pitch: You step out of the clouds onto the judges' terrace and look down a
trench of basalt two hundred paces long: a ballcourt for players who were
giants, its floor a green-black lawn gone to moss, and something stone and
horned is already turning its head to you down there. The court is the
bull's, the walls are yours, and the whole way home is a run you start
the moment you decide to go down.

Place: A colossal, half-collapsed ballcourt, the long I-shaped kind: a sunken
  alley about 56 m long and 14 m wide, the playing floor a ground of old turf
  and moss between two parallel walls that rise 9 m (about 5 set-offs of
  SET_OFF 1.6) in great sloped batter-courses, topped by a flat crest 3 m
  wide that was the stands' walk. The isle is a plateau of dark rock the
  court was cut down into, so from outside it reads as a long low mesa with a
  slot in it; from the air the slot is the whole silhouette, a black stroke
  with a pale lawn in it. The stone is rune-grooved basalt (the Olmec
  weathered look, not the gothic abbey grey): sloping walls with a carved
  band of ball-players and serpent scrolls under the crest, the grooves
  full of moss.
  Arrival view: you land on the NORTH judges' terrace, a stepped platform
  raised 5 m over the court's head, between two stumps of the old
  loggias. You look straight down the court's axis: the two walls run away
  in converging lines, the west wall (WEST) still whole to its crest with a
  stone hoop-gap high in its face (a ring-shaped opening 6 m up, rimmed with
  carved stone, a doorway for a ball nobody will throw again), the east
  wall (EAST) fallen in its middle third into a long scree slope of
  blocks, ferns and a fan of roots, so the daylight pours in at a slant
  across the lawn. At the far south end the court simply stops: the end
  wall is gone, the floor runs out past a broken lip into open sky, and
  the sky is the lightest thing in the picture. Oppression is the
  proportion: you are standing at the foot of walls three times your
  height, in a stripe of shadow, with a pale square of sky at the end
  and a pair of horns moving on the lawn.
  How it broke: unevenly. The EAST wall slumped in its middle (a collapse
  that left two standing end buttresses, an unbroken north stub 10 m long
  and a south stub with the wall's last 3 courses leaning); the west wall
  lost only its crest at three places (three notches in the stands' walk).
  The floor is cracked along one seam: a long fissure across the court at
  two-thirds, about 5 m wide, that the roots of a fig have broken open.
  Mostly land with stone on it: the court is a lawn of turf, the walls are
  piled courses, growth takes the east scree and the crest.

Top (ASCII, 1 char ~ 4 m; N up):
```
 12345678901234567890123456789012345678
                   .
          [ 2 ]  ..@..  [ 3 ]        judges' terrace (@) with two
          ..:   :  @ :   :..          flank stands 2, 3 (satellites)
         ^^^#####=======#####^^^
         ###"""""":::::"""""###       WEST wall ##### crest, hoop H
         #W        o        E#        court floor, bull(s) 'o'
         #W   o              E"""     EAST wall slumped: scree """
         #W                  """"
         #W~~~~ fissure ~~~ E""""
         #W                  E##
         ^^^###########===###^^^
             . . .    6 ~~~~~~        broken south lip -> drifted shard 6
              5      ~~~              (and 4: the ball-house islet)
```
Side (the court seen from the east, N at left):
```
 terrace ___                      crest _______________________
      __|   |___                       |                       \
    5m  stump \___ court floor lawn____|  ...fissure...         \_lip
        |_____ 9 m walls (W whole, E slumped) ______           broken ~
                                                     ~ ~ ~ gulf ~ ~
```

Play: The court is a place you cross from the north terrace to the south
  lip, where the exit rope bridge hangs to the next isle (rim: south). Two
  rams (Plinth Ram, scripts/enemies/plinth_ram.gd) live in the court and
  notice you at their `notice` range. At least two routes:
  1. THE FLOOR (fast, committal): hop down the terrace's steps (5 m, three
     drops of ~1.6 m, all grab-catches back up) and run the lawn. A ram
     tells (scrapes), you keep your line, then dodge near the south lip so it
     overshoots into the sky (the original ram kill), or near the
     fissure so it goes in. The floor is a one-dimension gauntlet; the
     fissure is a 5 m jump (running jump, then a late dodge so the bull
     tries it and fails). The cost of a mistake is a knock: the horn throws
     and stuns, and you tumble down the lawn.
  2. THE CREST (slow, exposed): from the terrace's west stump, ledge-grab
     and climb the WEST wall in set-offs of 1.6 m (batter courses read as a
     staircase of grabs, 5 of them, chain-jump 2.575 where wide), then run the
     3 m crest on its length. Three notches (each ~5 m of missing crest,
     jump 4-5 m or wall-kick over the gap, or drop to the floor and
     climb again) break it, so a skilled runner never touches the floor but
     the bulls watch from below, and a ram at the foot of the wall rams
     the wall (a thud that shakes loose a coping stone onto the crest, a
     spill you step around).
  3. THE SCREE (middle, messy): the east slump is a long rubble slope of big
     blocks (1.4-2.2 m stepping, mostly walk-up, some leaps) running from the
     floor to the crest of the east stubs. Bulls climb scree poorly (a ram
     slows and loses its line on blocks, `chase_turn` low off flat ground),
     so the scree is the place to catch breath, and from its top you can
     leap to the west crest across the 14 m court (no: too far; you drop
     into the hoop's ledge instead, below) or ride the stub's crest south.
  Choice: the floor (fast, kills a bull), the crest (safe from horns, long,
  three jumps with a drop at each), the scree (a slow third way, forced to
  cross the fissure's edge). Every route ends at the south lip bridge or
  at the flank stands' satellite bridges (the flank stands 2, 3 are
  reached by the cluster's rope bridges from the crest).

Threat: THE PLINTH RAM, two of them, living in the court. It is the court's
  old beast: you are the red flag; it hooks after you, dodges near a rim
  send it over. Here the "rims" are the court's own: the south lip, the
  fissure and the ragged holes in the east slump's lower edge. The court is
  built so that the bull's honest rim is always in sight (the sky at the end
  of the lawn) and the pilot's wish is always to be at the other end of it.
  It's also a tool: a bull rushed at the fissure goes in and the fissure
  fills? No (physics, not damage): a bull that overruns the south lip
  takes its dust with it; a bull rammed into the west wall under the
  hoop (when the player stands in the hoop's doorway, six metres up and
  dodges) cracks coping onto the floor; and a bull that has lost its
  quarry returns to idle. A ram can also be knocked by something else (a
  blaster, a tumbled player, the head) like any enemy. Optionally one
  roaming inhaler head on a long lazy circuit over the crest ( "the ball" )
  pulling the player UP the court toward it, so floor and crest meet a
  second chaser, the airborne kind.

Could combo: (hunches, never a line) the ram's horn-throw sends a stunned
  pilot tumbling down the lawn toward the south lip, where the wind-horn
  or the hover head would catch a body thrown out; a pilot in the west
  hoop's doorway dodged into by the other bull; a body that tumbles off
  the crest onto the scree rolls down to the floor and to the other
  bull; a blaster on the south stub's crest (a wind-blaster trap) throws a
  pilot out over the gulf toward shard 6. Ports: it catches a body thrown
  in from the terrace side and from the flank stands (a seesaw or a
  cannon from satellite 2 or 3 could drop you into the court mid-lawn),
  and throws out at the south lip (a pilot knocked off the lip tumbles
  toward 6 and 5, the bridge head and the drifting ball-house). The dragon's
  swipe would find the open crest.

Mystery: The Olmec makers' ball was played here for a reason: the carved
  band under the crest shows the players, then the ball getting larger on
  each panel until in the last panel it is a mountain and the players are
  the size of a hand. The hoop's inner face has a counted row of 7
  grooves, six filled with moss and one clear. The bull is the
  "ball's keeper", the same stone as the colossus heads. The fissure came
  after, the way the roots were reading the court. The player pieces
  together that the court was a calendar of games, and that someone made
  the beasts to keep it.

Kit used (ids verified in scripts/ruin_kit.gd): `wall`, `buttress`, `floor`,
  `grand_stair` (terrace flight), `stairs`, `fallen_pier`, `hall_column`,
  `hall_beam`, `hall_slab`, `tomb_chest`, `stone_circle` (the hoop, set on
  its edge), `aqueduct_stump`, `aqueduct_broken`; rope bridges
  (scripts/rope_bridge.gd), floating stones; scripts/enemies/plinth_ram.gd;
  (optional) scripts/enemies/inhaler_head.gd; scripts/wind_horn.gd and
  scripts/traps/trap_wind_blaster.gd.
Kit asks:
  - Court wall (batter walls): a long sloped wall piece, 9 m, in 1.6 m
    set-offs, with a flat 3 m crest, the Olmec stone and a carved band
    (kit-k5 "Stepped Tier"/"Sky Ballcourt" ask is the nearest).
  - Court hoop: a carved stone ring set in a wall face, a 6 m doorway.
  - Scree slope: a heap of fallen wall blocks (a rubble-ramp generator).
Family knobs: `east_collapse` (0.3-0.9: how much of the east wall is scree),
  `crest_notches` (1-4), `fissure` (none/narrow 3 m / wide 5 m), `bulls` (1-2,
  or 1 plus a head overhead).
Sockets: rim: north terrace (arrival, facing south) and the south lip
  (exit, facing south) plus 2 flank stands on the west/east (facing out);
  arena: the court floor (50 x 12 m); cover: the hoop doorway, the stub
  buttresses, the leaning stub; perch: the crest and the terrace.
Generator fit: role: set-piece / mid-layer hub; footprint ~60 x 36 m plus a
  cluster ring of 3-4 satellites within one plane-widths gap; height span 9 m
  down, 5 m up; suits a tight cluster (the satellites ring the court like a
  stand).
Distinct from: sundered_gorge (a split valley with a bridge, here the trench
  is one ruin, not two halves, and a chaser lives in it) and colonnade_spine
  (a ridge you walk on top of; here the high route is optional and the floor
  is the heart). Not benchfall (a pit you fall down: here you cross a lawn
  at the same level as a bull).
