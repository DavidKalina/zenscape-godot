# The Stepped Reliquary
Lenses: chase, climb; tall stack (isles over isles), a line; colossal, oppressive.
Pitch: Three real islands step up west of the temple end, each higher than the last (about 21 m, 33 m and 47 m over the spine's rim), each with a set piece built from the city's climb pieces in ruin stone and moss. Once the Olmec has his head he comes up after you by his own lanes: the climb faces, the leaps and the tipping slabs, while the wanderer takes the rope bridges, the floating stones and the safe rooms.

Place: The colonnade spine stays as it is: ridge (X 14 to 150, `Spine.TOP` 30, podium 17.9 m over the rim), temple on the head, the crags and the dormant Olmec at x 102 on the east. Past the temple the sky goes on: from the altar on the prow (x 14) a rope bridge and an aqueduct-span stub lead west to I1 and the staircase of islands rises north-west and then curls back over the temple. On arrival from the east you see the whole ridge laid out as a processional way, the cella, and above and behind the gable a stack of three green slabs with towers of ruin on them, one over another.

Islands (heights over `Spine.TOP`; Olmec numbers at the knobs: head height Hh 3.36 m, stride 2.4, `climb_max` about 22 m, `climb` 1.25 walker-heads/s, `jump_gap` 3 Hh = 10 m, `jump_rise` 1.7 m, `leap_max` about 12 m, `drop_max` about 22 m; wanderer: GRAB_TOP 1.9 m, CHAIN_TOP 2.6 m, STEP_UP 0.45 m):

- I1 "Votive Lawn": a 46 x 34 m oval, 7 m of stepped relief (three cliff steps of 2.3 m, each a chain for her, a stride-plus for him), base +21, top +28. Edge ledge 1.1 m over the altar, 9 m of air from the prow. Set piece: the leaper's pit (`city_pit`) in ruin style, cut across the lawn: two plinths 8.5 m apart, inside his jump and past her run-jump, the inner cornice hers, the east cornice pre-cracked (his landing breaks it, nearest first). Turf: a 20 m long clear lawn on its west flank for landing the plane; wild grass, ivy on the plinths.
- I2 "The Hung Slab": a drifted slab 34 x 26 m, one node (inside `OlmecTilt` 6 to 80 m, so it tips as a whole), base +33, top +41 (8 m climb face on its east edge: his haul, her two-step chain and a walker-only stone). Set piece: the wrapped pillar (`city_wrap`) in ruin style, a 12 m pillar on the slab's middle with his ramp wound round and her recess in the south face with its half-way safe cell. Because the slab tips toward him whenever he stands on the pillar's ramp, her climb runs up a leaning pillar. Turf: a 18 m lawn along the slab's north side, tilted only when he stands out on it. Moss, rooted trees on the lee side.
- I3 "The Summit Garth": a 40 x 30 m crown, base +47, top +54 (7 m of terraces), the highest thing for 200 m. Set piece: the hanging terrace (`city_terrace`) in ruin style: two decks hung on a back wall of lancets (`lancet_wall`) with his stair between them, the undercroft too low for him and her shelves up through a hatch; the upper deck's outer tier snaps under his weight and drops into the sky. On the summit lawn behind it, an 18 m clear run for landing the plane (the plane's last chance: it takes off downhill off the garth's lip, 54 m over the rim). Turf: heather-green, ivy on the walls, a lone yew.

Top (ASCII, ~40x16, 1 char about 4 m; north up, spine to the east):
```
 ^^^^^^^^^^^^^^^^^^^^^^^^^^^~~~~~~~~~~~~~~
 ~~~~~~~~~~~~~ 3333333333 ~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~ 33333@C3333P3~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~ 333333333333 ~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~~ 3333333.3  ~~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~~~~~~~ . ~~~~~ ~~~~~~~~~~~~~~~
 ~~~~~~~~~~ 222222 .  ~~~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~ 2222@C222~~~~~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~ 22222222 .~~~~~~~~~~~~~~~~~~~~~
 ~~~~~~ 11111 ..~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~~~~ 11111@111 ~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~~~~ 1111o1111 ~~~~.~~~~~~~~~~~~~~~~~~~~~~
 ~~~~~ 11111 ~~~~~~~ .####### # # # # ####
 ~~~~~~~~~~~~~~~~~~~ @##"""#.#.#.#.#.##"#
 ~~~~~~~~~~~~~~~~~~~~ ###########.######"#
 ~~~~~~~~~~~~~~~~~~~~~ spine head (temple) -> ridge -> east
```
Legend as the brief's; `3` I3, `2` I2, `1` I1, `.` route (stairs, bridges, floating stones), `@` set piece, `o` pit gap, `C` cover, `P` perch. (The spine's head is at the right, its altar prow at x 14.)

Side (heights over the rim, not to scale in x):
```
 m  54 |  I3  ___________            __
    47 |      |  garth   |           ridge: podium 17.9
    41 |  I2  _________   |   
    33 |      |slab hung  |  <- tilts
    28 |  I1  ___ ___     |
    21 |      |pit|       |
    17.9 |_prow altar_/\/\/\/\/____ ridge east, falls to 3 m
     0 |  rim, crags at x 102, Olmec plinth
```

Play: The pilot lands on the spine's south bench (the existing 14 m run), walks the processional way and the cella, and the Olmec wakes and does round 1's beat (climb the crags, tip them, break the colonnade, put his head on in the cella). The pilot's reason to go west is the prow: the altar, the rope bridge and everything above it.
1. Prow to I1. The pilot takes the live rope bridge (9 m span, from `RuinKit` `bridge_anchor`) or the floating stones beside it; the Olmec, whole and hunting, takes a leap off the prow (9 m, inside `jump_gap` 10 m, a 1.1 m rise inside `jump_rise`) and lands on I1's edge lip. The landing's shockwave runs out across the lawn: a walker on the ground is thrown, one in the air is clear. Choice: cross early and be on I1 before he lands, or cross late and meet his leap in the air over the bridge.
2. I1, the pit. She runs the lawn for the pit; the plinths are 8.5 m apart. Her run-jump across, then a wall-kick/chain up the plinth's face to the cornice that is hers. His leap across the pit is a clean `jump`; the east cornice breaks under his landing, so the pilot never stands there when he lands. The plinths are 8 m wide and cut as their own nodes: his haul or landing on one tips it, and the lurch carries her toward the pit's mouth. Landing the plane here is possible on the lawn flank (20 m).
3. I1 to I2. Two floating stones (walker-only; solid-rock hop) and a stair flight (`stairs`, 8 risers) run up I1's north edge to a landing at +31 under I2's 8 m climb face; he cannot stride 8 m but his `climb` (1.4 m/s) takes the face in about 6 s plus a 1.4 s mantle. The pilot climbs the face by a walker chain (two ledge grabs, a stone) in about 4 s. He loses 2 s, a head start, if he goes round the long way to the stair's landing. The face's top lip is where the pilot can see him haul up.
4. I2, the wrapped pillar. The slab tips toward him when he stands out on it: the pilot sits in the recess halfway up the pillar (a safe cell out of his reach, sight and inhale) and watches the slab lean, or goes up and over. His ramp winds round the outside, so he circles the pillar slowly at its foot while she climbs inside it. To leave, a rope bridge (14 m, two anchors on the pillar's top) goes up to I3's lowest terrace, and a floating stone chain goes as a second way. The bridge: she can cross it. He cannot walk a rope bridge (assumption, `body_routes` narrow-way test; to be checked in the greybox); he climbs I3's south face (14 m, inside `climb_max` 22 m) beside it.
5. I3, the terrace. She runs the stairs (his `stairs`) and comes to the hanging terrace: the lower deck by the stair, the undercroft too low for him, her shelves up through the hatch. His stair is the way between decks; the upper deck's outer tier snaps under him and drops. A pilot who baits him onto the outer tier drops him into the sky (he is not killed; he is gone: `fall`, then he travels back by `LayerOlmec`'s travel and comes up a cliff later). The summit lawn behind is the high, calm end: shrine, bench, a long clear run.
6. The chase ends in one of three ways: she hides in the undercroft or the pillar's cell until he gives up (`seek`, `return`); she takes off from the garth's lawn (the plane is on the south bench unless landed here: so land the plane on I3 first and the route is a safe sky-hop); or she pocket-sails off the garth's lip back to the spine's bench (54 m up, the sail covers about 90 m, the bench is about 60 m off) and takes the plane there; he leaps after her to the lower isle and goes round.

The Olmec's route and the pilot's meet and split at four places: the prow gap (bridge / jump), I1 north edge (stair and stones / his climb), the I2 face (grab chain / haul), and the I2-I3 hop (rope bridge / his climb of the south face). His is always a straight line of climbs and leaps; hers is the longer, safer, higher chain of stones and bridges.

Threat: the Olmec (`headless_body`, whole, `chase` on). Fair because his chase speed is slower than her run, his climb (1.4 m/s) and haul are slower than her chains, and every tell is visible (the lean, the dust, the groan). A swat is within `catch_reach`; the pounce is aimed till `pounce_lock` before it goes.

Where his climb fires: (a) I1's pit mouth: a 2.3 m step to the lawn is a stride (2.4); the island's rim faces (7 m) are climbs, the first real use; (b) I2's east face (8 m) and the pillar's own ramp (a wound lane, strides and hauls); (c) I3's south face (14 m) and the terrace's riser (4 m, a haul over the lip); (d) the leap off the prow onto I1 (a jump). He climbs 4 faces and leaps 2 gaps, one drop after the pilot has glided away.
Where his tilt fires (what is below the TIP_MOST 80 m and over 6 m): I1's two pit plinths (8 m, tip about 6 to 9 deg), I2's whole hung slab (34 m wide, one node: a tip of 3 to 4 deg lean while he stands out and a kick of 7 to 9 deg on a haul), the floating stones between I1 and I2 (each 5 to 7 m, the strongest dip), the I3 hanging terrace's decks (22 x 8 m, when he stands on the outer tier). The merged hillside of each island's base is too big to tip, so only these specific nodes lean. The lurch (3.1 m/s) carries a pilot on the slab toward the low side; she runs up the slope and wins.
Where he breaks things (`OlmecBreach`, `colonnade_breaks`): I1's east pit cornice (nearest first), I3's snapping outer tier, and a colonnade on the spine (as round 1).

Ports: catches the plane's approach from the east (the spine's gate), the round-1 spine (the Olmec's crags; the pilot on foot wakes him), and the spine's prow (rope-bridge head `bridge_anchor`, floating stones). Throws out: the pocket-sail glide off I3's lip to the spine's bench (about 60 m off), and the plane's take-off from I3's lawn.

Kit used (verified ids): RuinKit `stairs`, `grand_stair`, `lancet_wall`, `rose_gable`, `wall`, `buttress`, `arch`, `pier`, `fallen_pier`, `floor`, `turret`, `tomb_chest`; aqueduct `aqueduct_span`, `aqueduct_broken`, `aqueduct_stump`, `aqueduct_end`; `bridge_anchor` (ruin_kit_cloister), the live rope bridges (`scripts/rope_bridge.gd`, `footbridge.gd`), floating stones (`Art.floating_stones`), `KitLand.island` (the three islands, stepped heights with grabbable cliffs), `WalkerOnly` stones. City pieces adapted to ruin style (shape and lanes kept, runes and frets dropped, ruin stone and ivy): `city_pit`, `city_wrap`, `city_terrace`, `city_lip`, `city_riser`, plus `maker_felled` as the fallen colonnade felled across the I2-I3 gap (a bridge for her, felled by his bulk).
Kit asks: a ruin-style stone for the city climb pieces (a `Stone` switch in `city_kit_stone.gd` from `olmec_stone.gdshader` to `RuinKit` stone, no `runes`/frets: one "ruin" option on `CityKit.piece`, low-med); `pit_ruin`, `wrap_ruin`, `terrace_ruin` (the same pieces with a `ruin` flag, not new meshes); a rope-bridge head that sits on an island-to-island gap with a place for his jump (existing `bridge_anchor`).
Family knobs: `isles` (2 to 4: I3 dropped at 2); `rise` (how much higher each stands, 8 to 14 m over the last); `bridges` (which rope bridges hold: the spine's own knob, extended); `set` (which set pieces: pit / wrap / terrace; a seed re-rolls the order).
Sockets: rim (the east face of I1, facing the spine's prow: where the plane arrives); arena (I1's lawn, I2's slab, I3's garth); cover (the pit plinths, the pillar's cell, the terrace's undercroft); perch (the garth's lip, the pillar's top, the I2 face lip).
Fit: role hero (extends the colonnade spine into a mini level); footprint about 150 x 90 m past the spine's head (west), plus the spine's existing 136 m; height span 30 to 84 m (54 m of stack over the rim).
Distinct from: sundered gorge (two halves side by side at one height, a gorge to look into); this is a stack rising 47 m, with a hunter climbing it. From stair_clouds (a single mesa with a grand stair): this one is three separate islands joined by bridges and leaps, with his climb and tilt as the hazard. From broken_ring (8 islets spiral): the islands here are big with set pieces, not stepping islets.

Cost: high (three KitLand islands, three ruin-styled city pieces, the new rope bridges, the tilt for slabs and a body-route test for the leaps).

Layout: the card's frame has the spine's prow at (0,0), the ridge running east, y over the rim.
```json
{
  "isles": [
    {"id":"S","name":"spine","x":68,"z":0,"rx":68,"rz":12,"top":18,"keel":-10,"set_piece":"temple + colonnade"},
    {"id":"1","name":"Votive Lawn","x":-34,"z":-22,"rx":23,"rz":17,"top":28,"keel":12,"set_piece":"leaper's pit"},
    {"id":"2","name":"Hung Slab","x":-62,"z":-52,"rx":17,"rz":13,"top":41,"keel":26,"set_piece":"wrapped pillar"},
    {"id":"3","name":"Summit Garth","x":-92,"z":-80,"rx":20,"rz":15,"top":54,"keel":38,"set_piece":"hanging terrace"}
  ],
  "links": [
    {"from":"S","to":"1","kind":"rope"},
    {"from":"S","to":"1","kind":"stones"},
    {"from":"1","to":"2","kind":"stair"},
    {"from":"1","to":"2","kind":"climb"},
    {"from":"2","to":"3","kind":"rope"},
    {"from":"2","to":"3","kind":"climb"}
  ],
  "pilot": [[100,0,6],[40,18,0],[2,18,0],[-18,26,-14],[-40,28,-26],[-52,33,-44],[-62,41,-52],[-78,41,-66],[-92,54,-80]],
  "threat": [[90,3,-4],[40,18,0],[0,18,0],[-14,28,-18],[-34,28,-22],[-48,33,-40],[-62,41,-52],[-80,47,-70],[-92,54,-80]],
  "tips": [[-34,28,-22],[-62,41,-52],[-48,31,-36],[-92,50,-80]],
  "landing": [-50,-28,-30,-28],
  "end": [-92,54,-80],
  "moments": [
    {"at":[0,18,0],"label":"The leap off the prow","note":"He jumps the 9 m gap beside your rope bridge and lands on the lawn; the shockwave runs out."},
    {"at":[-34,28,-22],"label":"The pit","note":"You run-jump the 8.5 m pit; his landing breaks the east cornice and tips the plinth."},
    {"at":[-62,41,-52],"label":"The leaning pillar","note":"The slab tips as he circles the pillar; you sit in the half-way cell and watch him."},
    {"at":[-78,41,-66],"label":"Two ways up","note":"You cross the rope bridge; he climbs the 14 m south face beside it."},
    {"at":[-92,54,-80],"label":"The outer tier","note":"Bait him onto the terrace's outer tier; it snaps and drops him into the sky."}
  ],
  "notes": [
    {"at":[-6,18,0],"text":"9 m gap, his jump"},
    {"at":[-56,36,-46],"text":"8 m face, his haul"},
    {"at":[-70,41,-58],"text":"safe cell in pillar"},
    {"at":[-92,40,-88],"text":"undercroft too low for him"},
    {"at":[-40,28,-28],"text":"20 m landing lawn"}
  ]
}
```
