# The Long Leat — "Still carrying water to a city that drank it dry"
Lenses: verb TIME A CROSSING · twist the ruin still doing its old job · decay intact-and-working (spans broken, water not) · scale colossal · purpose aqueduct · shape a line

Pitch: You step out of a gatehouse onto the head of a stone water-road 160 m long
over a haze-filled gulf, and the far isle is a lit smudge at its other end.
A thread of water runs in the trough the whole way, and every half minute
the road rumbles and a pale surge comes down it, spills off each broken
span and keeps going: you cross by its clock.

Place: Two basalt pillar-isles with a drowned-dark gulf between, 150-170 m apart, the
far one 9-10 m lower. From the near head (a gatehouse on a corbelled landing
with the cistern's feed pouring from a carved maw behind you) the view is
one long line: a **comb of pier shadows** (`city_causeway`'s signature
silhouette) marching away, a bright ribbon of water in the trough, and at
three places the ribbon **breaks into hanging white veils** where a span has
fallen and the leat spills over the gap into the haze, and a part of that
water lands on the next pier's deck as a second thin trickle. The far end is a
spillway mouth (carved maw) with a plume of mist standing over it; the water
you can see from the start is the water you will ride. Stone is the
makers' weathered basalt (`olmec_stone`), talud piers, corbelled bays; the
water is painted (soft, broad, a pale seam of foam), the wetness darkens
the deck and lips with a green-black tide mark, and moss, ferns and
strangler roots hang in the wet shade of the piers. Broken unevenly: the
head three bays whole, then gaps of 11 m, 14 m and 17 m (bays lost: one, one
and a half, two), each with its far pier leaning; the water finds its own
way over what is left, never stopping.

Top (1 char ≈ 4 m; 40 cols = the whole leat):
```
 gulf (haze)  ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
 [1]==##==##==  ##==##=   ##==##=  ===##==##==##==[2]
 @A  head   g1   mid   g2   mid  g3  tail    far @R
 route: . on the deck lips; = deck; g = gap; ~ water falling
```
```
 [1]  gatehouse + cistern (@) , arena A at the head, gate 'G'
 ==== deck 6.6 wide, trough 2.2 down the middle
 g1/g2/g3 the three gaps, each a waterfall 'W' over the pier stump
 P  refuge niches in the piers (perches), C curb cover
 [2]  far pillar-isle, spillway mouth, mist; 'R' a stair down
```
Side (descent 9.5 m over 160 m, a 3.4 deg grade — the leat is walkable, the
water has a pace):
```
 y+9 [1]=====\
                =====\  g1 W
                       ====\ g2 W
                              =====\ g3 W
 y 0                                   ====[2]
     ^ pier stumps below, haze beyond ^
```

Play: Two routes, and the surge is the clock.
- **The runner** (skill, dry). Leave when the trough is quiet. The deck is
  walkable end to end except the gaps. Each gap is past a plain running
  long jump (`LONG_SPEED` 7.6 m/s, reach near 8.7 m at the viaduct's
  drops) and inside a **chain of three** (10.4 m/s, 10.4 m): so g1 (11 m)
  is a chain-of-two catch off the lip, g2 (14 m) wants chain-of-three plus
  a twirl at the peak, g3 (17 m) can't be jumped dry at all; its far pier
  is shy of the chain's reach. So the dry route fails at g3 unless you take
  the **underhang**: the broken span's far end hangs off the pier (the kit's
  `broken` look) 4 m lower, a ledge-grab chain along the pier's corbels
  (SET_OFF 1.6 steps, each inside GRAB_TOP/CHAIN_TOP) under the waterfall's
  veil, sliding down the wet wall (wall-slide) onto a 4 m shelf, then a
  kick chimney between pier and stump back up. A real climb, slow, wet,
  and you are under the veil when a surge comes: the water drops on your
  head and knocks you off (see Threat). This is the route that costs time.
- **The rider** (timing, wet). Stand in the trough at the gate when the
  tell starts (gate rattles, trough drains, spray from the maw: the
  Sluice Flush's tell, `trap_sluice.gd`). The wave runs the leat at
  pace; `motor.carry` takes you at its speed (faster than he runs); a jump
  taken while carried keeps the wave's pace (the sluice's `rides` rule),
  so at each gap you **jump at the lip and clear it at wave speed**; g3 too,
  because the pace is higher than a chain's. Lose the timing (jump a beat
  early, drop off the trough to the lip) and you are carried over the gap
  tumbling, dropping 10 m to the pier stump below: a fall to the haze, or
  a lucky catch on the stump (a second chance one rim down).
- **The refuge gambit.** Gatehouses and pier niches (perches 3 m over the
  deck, past wave height) let you stand out a wave, and then run the quiet
  after it. Each wave takes about 17 s end to end at wave speed; the quiet
  is long enough to run two bays and never a whole leat.

Threat: **The surge** (Sluice Flush, `scripts/traps/trap_sluice.gd`,
`knobs` `length`, `gap`, `speed`, `tell_time`, `trigger` "timer",
`period`): the makers' own flush, still working. It's the whole motif's
clock, a periodic wave from the cistern gate every ~30 s, the tell
unmissable; the gaps are what the wave spills over (its `gap` knob is the
gap, and `beyond` the next deck). Also Olmec **tenders**: two headless
bodies (`headless_body.gd`) stationed on the piers at the gates' ends,
**climbing the piers** (the `climb` state, `city_wrap` / `city_lip` pieces
put hauling lips on the pier faces) to turn the gate wheels; when the
player is seen on the deck they stop and **pounce** (windup, leap: `leap_max` and
`leap_up` within their reach) from the pier or a gate-top down onto
the deck; the landing shock knocks the pilot, and in a surge a pouncing body
standing in the water is carried too (the wave moves it: it **leaves the
deck over the gap**, an enemy swept away). That is the Sundered Hall seed:
Olmecs on the water-works, above you, on the sides, dropping down.
It's also a tool: the wave carries the pilot away from an Olmec; their
landing shock wakes a gate.

Could combo: surge + headless body (the body's shock knocks you into the
water; or you step aside and the wave takes the body); the waterfall veil + a
wall kick on the stump pier (a rooftop launch); a stunned body (tumbling) in
the trough rides the wave like a log (it has `carry` too); an inhaler head
hovering over g3 (its pull and the wave's push meet midair: head can inhale a
rider jumping the gap). Ports: catches a body thrown in from either
neighbouring isle (the trough is a conveyor: lands on the lip,
rolls to the trough, rides on); throws out at the far spillway at wave
pace (tumbling, a long arc into the next place), so exits can launch.

Mystery: The water comes from somewhere. A cistern that never empties,
carved with a calendar of fills: the player reads that the makers timed their
floods to the day-count (`trap_day_count.gd`); at the far end the spillway
maw feeds a basin that nobody drinks from: an Olmec face bowed into it, the
face's eyes polished. They were *feeding* something below the haze, and the
haze is thick because of what has been poured into it for centuries. The
tenders keep turning wheels for a city that has gone.

Kit used: `city_causeway` (CityKit.PIECES; the aqueduct is inside it: the
file's header says "ol_causeway + city_aqueduct + maker_causeway"),
`city_pillar` (the isles), `city_wrap`, `city_lip` (CityKitClimb: pier
climbing), `city_hall` (CityKitLandmarks: the cistern/gatehouse at the head),
`city_niches` (CityKitRefuges: the pier niches), `maker_cresset` (CityKitFires:
dim warm light on piers in the haze), trap `trap_sluice.gd`, enemy
`headless_body.gd`, `inhaler_head.gd`, `trap_day_count.gd`.
Kit asks:
- `city_waterway` (live water in the trough: a shader flow with a `current`
  vector, wetness on lips, and a spill veil mesh per gap; carries `motor.carry`
  at the current's pace): the causeway's header lists `current` as optional;
  nobody has built the water volume.
- `city_causeway` variant `leat_broken`: a span with a hanging far end and a
  corbelled underhang (the underhang route needs it).
- `city_gate`: the cistern's sluice gate as a piece with a rattle/lift tell
  (the trap has its own greybox; make it a kit piece).
Family knobs: `length` (6-14 bays), `gaps` (1-3, size 11/14/17 m, drawn from
the pilot's chain reaches), `surge_period` (20-45 s), `tenders` (0-3
bodies), `grade` (2-6 deg, total drop 6-14 m).
Sockets: rims at both pillar-isle heads (facing along the leat); arenas at
the head landing (A) and the far isle's spillway apron (the exit); cover:
pier niches and the gatehouse; perches: the gate-top and the pier corbels.
Generator fit: a motif with its own two shores, or an edge between two
places (it is the crossing itself: a pillar-isle at each end, 150-170 m
apart, far end 6-14 m lower). Footprint 170 x 24 m, height span 14 m.
Suits the city's "a line" layer shape and a long gulf in a spread-wide
layer; in the generator it would replace the 'causeway beam' bridge edges
(`city_crossings.gd`'s plan edges, 4-22 m) for one edge per layer.
Distinct from: `city_crossings.gd` (short beams over a few metres), the
Broken Viaduct yard (a skill crossing with no clock, sky kit, one big gap)
and `colonnade_spine`'s rope bridges: here the gulf is the whole motif,
and the water gives it a pulse. It is not the Serpent Crossing (the serpent
is the rail); here the water is.
