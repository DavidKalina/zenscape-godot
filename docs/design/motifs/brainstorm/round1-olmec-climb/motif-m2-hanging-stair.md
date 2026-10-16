# The Hanging Stair (the colonnade spine's underside)
Lenses: verb fall/descend + climb (his); scale colossal; mood oppressive; shape a hanging underside (three tiers under the temple end), a line of drops.

Pitch: The spine's temple end stays the roof. Three real islands hang in a stack under it, each lower than the last, stitched by stairs, hung rope bridges and floating stones, and the Olmec sleeps on the bottom one. You go down; he climbs up the same hanging faces to his head in the cella, and once he is whole the chase turns over and he follows you down, landing on every tier.

Why this inversion, not "the pilot climbs after him". His climb only ever goes toward his head (headless_body.gd "climb": the head is above the wall), so a tier stack he must go UP gives his hand-over-hand climb, his haul and his mantle (each a tilt kick) a reason on every tier. Pilot-climbs-after-him would leave him nothing to climb: he'd have to run away from the head. Going down also gives the pilot's best verbs on a stack: the pocket sail between tiers, a flow-charge slam, rope bridges that hang down, and a plane waiting at the bottom. And the same tiers serve twice: up for him (climb, haul, mantle), down for the chase (windup, leap, land: the shockwave and the tilt kick fire on each landing). Kept from the seed: islands stitched together, city pieces in ruin style, his climb and tilt used for real.

Place: West of the temple end (the spine's X_WEST 14, the podium at 8 risers = 17.9 m up the ridge) the sky is empty today. Under and past it hang three islands, offset so that each one's rim is 5-7 m out from the one above (a sheer face to climb, not an overhang he can't). Seen from the plane, flying in west to east along the axis, you come in under the keel: the temple's earth hangs down into the first tier, and below it the other two step away into the haze, each face a lit wall of ruin stone with roots hanging. Heights below the temple floor (T = 0): U1 -14, U2 -34, U3 -58. His head is 3.3 m (CRAG_CLIMB 4.0 = 1.2 heads); his stride is 2.4 m, so every face is a climb: U1 to the temple 14 m (4 heads), U2 to U1 20 m (6 heads), U3 to U2 24 m (7 heads). All far under climb_max (20 heads) and far over a pilot's grab (about 2.6 m with a chain), so the pilot never climbs them bare.

Top (ASCII, 1 char = 4 m; north up; the spine runs off to the east at the right):
```
 x: 0         10        20        30        40
    ....................................
    .          ###T############@########===>  spine (temple end T, x 14-43)
    .          ##|#                           
    .       111111  (U1, -14, 36 m)  ".
    .      111111|1                     rope bridge '|' down from T
    .     ~~~~~~~~~~~~~
    .   2222222222222   (U2, -34, 52 m, largest tipping stone)
    .  2222@222|22222    @ = city_terrace hung on its wall, | = stair
    .   ~~~~~~~~~~~~~~
    . 33333333333333333333333333    (U3, -58, 100 m long)
    . 3PPPPPPP33333333333333o3333    P = landing run (west end, 18 m), o = Olmec's plinth (east)
```
Side (the long axis from the west; heights in m under the temple floor):
```
 T  ###########============     0   temple floor, cella, the head
     \__ 1 ____/                -14  U1 Keel shelf   (tips)
          ~ ~ roots
        \___ 2 ______/          -34  U2 Drum court   (tips, largest)
              ~ floating stones
     \____ 3 _________________/ -58  U3 The foot     (too big to tip: groans)
     P landing        o Olmec
```

The three islands (real chunks of land, `KitLand.island` with stepped heights, each its own turf):
- U1 "Keel shelf", 36 m across, -14. The temple's hung earth makes its north wall. Set piece: a gated stair court. Ruin-stone `city_drum_stair` and `city_stair` flights climb the 14 m up to the temple's west gate in two flights with a landing between (his lane is the stair's whole width; hers is the same stair, slow). A hung rope bridge from the south bench's end down onto U1 (the pilot's fast way down). Turf: mown-wild lawn gone to long grass, ivy over the keel.
- U2 "Drum court", 52 m, -34, the middle and widest tipping stone. Set piece: the hanging terrace (`city_terrace`, adapted: two decks on the host wall = U1's face, his stair between them, her shelves up through a hatch, the upper deck's outer tier snaps under his weight) on its north side and a wrapped pillar (`city_wrap`) in its middle. This is where the lanes split. Turf: moss on cut stone, creeper-grown drums.
- U3 "The foot", 100 m long, -58. Set piece: the Olmec's plinth at the east end (`city_pit` across a break in the island: two plinths across a gap inside his jump and past hers). At its west end, 70 m from the plinth, a plain turf run for the plane (see Play). A felled column (`maker_felled`) lies across the gap and is the pilot's and his bridge. Turf: short wiry meadow, standing water in the lee.
Floating stones (WalkerOnly, 0.6 m hops, as round 1's crags use) wind round each rim and between tiers, never across his lane. Between tiers the pilot also has a hung rope bridge (U1 to U2, 20 m down over 30 m run) and the sail.

Play:
1. Arrive by plane. Two landings: the spine's south bench (the existing 14 m run, unchanged) and the foot's west run (18 m, fly in under the keel along the axis; the keel is 44 m over it). The plane never needs the tiers to land.
2. He wakes on arrival (round 1's trigger: grounded on foot in the isle's circle or the plane on the ground there; for the foot, the circle covers U3's whole length). He is on the plinth, 70 m east of the foot's run.
3. Phase 1, he goes UP for his head in the cella (he hears the head, 80 heads away). Route: plinth (U3) to the island's west end by walking, then the face to U2: a climb (24 m, hand over hand at 1.25 heads/s: 20 s of climbing, in plain view from the plane), a mantle onto U2 (the haul = a tilt kick; U2 tips toward him and stays leaned while he stands near the rim), across U2 by `city_wrap`'s ramp or, cut off, through the terrace, then the face to U1 (20 m climb, another haul and tip: U1 is smaller and tips more), then `city_stair`'s flights (his stride), then the temple gate. At the gate he strides through the rose gable (breaks), reaches the head: round 1's reunion.
4. The pilot's route in phase 1 is the other way: from the bench, over the hung rope bridge down onto U1, across U1 to the stair up the keel's north side, down the tier stairs to U2 (the wide stair), then a sail or the rope bridge to U2 (the bridge snaps if he hauls up near it: the bridge is a rope sim, the pilot caught on it falls to the next tier, a chain's drop, not a kill). Where they split: at U2 the terrace and the wrap give two lanes; where they meet: at U2 as he mantles up while the pilot is crossing it. The pilot can be on the wrap's inside recess (the walker's climb with the safe cell halfway up) when he passes, or on the terrace's undercroft (too low for him). He walks by below you; you come out behind him. That's the meeting beat; neither dodges by speed, only by taking a lane he can't.
5. Phase 2, whole, he roams "any way, climbing and leaping still", following you. Now the isles hang below: you are going down. His moves: windup then leap (leap_max 36 m across, drop_max 66 m down) from the temple floor onto U1 (land: shockwave runs out; a pilot on the ground as it passes is thrown, one in the air is clear; U1 tips hard under a landing), then from U1 to U2 (a 20 m drop, a 14 m face the other way), then U3. The pilot goes down faster by the sail but must read the tip: each landing kicks a tier over as a tilt (DIP at the rim). Running upslope against the lurch always wins (olmec_tilt.gd "fair").
6. Chase ends: at the plane. Land on the foot, go up to the temple in phase 1, come down in phase 2 and take off from the foot's run (he is still on the tiers above, a drop behind you). Land on the bench instead and the chase ends there, an up-chase by the stair with him coming from below.

Choices: land on the bench (safe, high, he comes at you from below) or the foot (the chase down ends at your plane, but he wakes 70 m from you); descend by bridge, stair or sail; take the terrace and snap it behind you; lure him onto the felled column (`maker_felled`) at the pit to make him cross it.

Threat: the Olmec (headless_body.gd, `breach` on, `tilt` on). Where his climb fires: the two faces U3 to U2 and U2 to U1 (a 24 and a 20 m wall, each with a `city_lip` cornice on its rim for his hands), the temple face (14 m). Where his tilt fires: U1 (36 m across) and U2 (52 m across) are under TIP_MOST (80 m) and over TIP_LEAST, so each tips when he mantles or lands; U3 (100 m) is too big, it only groans, so the plane's run is on the one island that stays still. Smaller stones that tip too: the terrace's decks (each under 12 m), the `maker_felled` column (a bridge across the pit), the floating stones if he steps on one. Breaks: `city_terrace`'s outer tier snaps under his weight; `city_lip`'s far corner pre-cracks; the pit's east cornice breaks on his landing; the pilot's hung rope bridges can be torn by the shake.

Ports: catches the plane's approach (flying in along the axis under the temple, the keel hanging over the flight) and the sail from the spine; throws out the spine's own routes (the tail east is untouched) and the pilot to the bench or the foot's run.

Kit used (all verified to exist): `city_terrace`, `city_wrap`, `city_lip`, `city_pit`, `city_riser`, `city_wedge` (scripts/city_kit_climb.gd PIECES); `city_drum_stair`, `city_stair`, `city_causeway` (scripts/city_kit.gd PIECES); `maker_felled` (city_kit_breaks.gd); `city_court` (city_kit_landmarks.gd; optional as the foot's alley); RuinKit `stairs`, `grand_stair`, `floor`, `fallen_pier`, `pier`, `arch`, `wall`, `buttress`, `vault`; scripts/rope_bridge.gd, floating stones, `WalkerOnly`, the Art crag machinery (`crag_lands`, `crag_stones`) for the stitching; the spine (`motif_colonnade_spine.gd`) as the roof.

Kit asks:
- A ruin-style stone for the city climb pieces: `CityKit` options `ruin := true` that swaps `city_kit_stone.gd`'s basalt for RuinKit's stone and drops rune grooves (shader) and frets (geometry) from `city_terrace`, `city_wrap`, `city_lip`, `city_pit`, `city_drum_stair`, `city_stair`, `maker_felled`. Shapes, lanes, safe rooms and breaks stay.
- Overgrown variants: moss on tops, ivy and roots down faces, a hung-root fringe on each tier's keel (HangingRoots exists).
- A hung rope bridge that hangs from a rim down to another island (slope up to 14 m over 30 m) that shakes loose when a tilt tips either end.

Family knobs: `tiers` (2-4: how many hang), `drop` (the face height in heads: 4-8), `sway` (how loosely the tipping tiers lean: TIP_LEAST..TIP_MOST_DEG), `landing` ("foot" or "bench": which run the plane lands on).

Sockets: rim (the temple's west gate; each tier's rim); arena (U2's court, the foot's pit); cover (the terrace undercroft, the wrap's safe cell, the wedge hollow); perch (the keel's top, the wrap's summit).

Fit: role hero/underside; footprint about 100 x 60 m under the spine's west end; height span 58 m under the temple floor (around 18 + 58 = 76 m from the plateau's top to the foot, so the isle sits 76 m taller in the sky than today).

Distinct from: `sundered_gorge` (two halves side by side, no Olmec, no vertical), `hollow_keel` (a colossus hall hung under a plate, fly-through, stairs, no climb) and `stair_clouds` (one mesa, one grand stair). This is a stack that hangs, where the climb is the threat and both directions are played.

Cost: high. Three new `KitLand.island`s, the ruin-style retrofit of seven city pieces, a hung rope bridge, the lanes retuned to the real Olmec (not the underground city's), and the colonnade_olmec arming and wake wiring extended to a larger circle (ARM_NEAR 420 m still holds, but the footprint is 76 m taller and the pre-cuts grow). Cheaper cut: two tiers and no `city_court`.

Layout: the rough map (x east, z south, y up, metres from the temple floor = 0).
```json
{
  "isles": [
    {"id":"T","name":"spine temple end","x":82,"z":0,"rx":68,"rz":14,"top":0,"keel":-10,"set_piece":"temple, cella, head"},
    {"id":"1","name":"Keel shelf","x":14,"z":0,"rx":18,"rz":16,"top":-14,"keel":-22,"set_piece":"city_drum_stair + city_stair court"},
    {"id":"2","name":"Drum court","x":8,"z":0,"rx":26,"rz":20,"top":-34,"keel":-44,"set_piece":"city_terrace + city_wrap"},
    {"id":"3","name":"The foot","x":10,"z":0,"rx":50,"rz":20,"top":-58,"keel":-70,"set_piece":"city_pit, maker_felled, plinth"}
  ],
  "links": [
    {"from":"T","to":"1","kind":"rope"},
    {"from":"1","to":"T","kind":"stair"},
    {"from":"1","to":"2","kind":"stair"},
    {"from":"1","to":"2","kind":"rope"},
    {"from":"2","to":"3","kind":"stones"},
    {"from":"3","to":"2","kind":"climb"},
    {"from":"2","to":"1","kind":"climb"},
    {"from":"1","to":"T","kind":"climb"}
  ],
  "pilot": [[-36,-58,0],[-30,-58,0],[40,0,10],[22,-14,8],[10,-34,0],[-5,-58,6],[-30,-58,0]],
  "threat": [[44,-58,0],[10,-58,0],[8,-34,-6],[14,-14,-4],[30,0,0],[22,-14,6],[10,-34,2],[0,-58,4]],
  "tips": [[14,-14,-14],[8,-34,-18],[30,-34,0]],
  "landing": [-40,-5,-22,5],
  "end": [-36,-58,0],
  "moments": [
    {"at":[-30,-58,0],"label":"Under the keel","note":"You fly in beneath the temple and set down on the foot; the plinth wakes 70 m east."},
    {"at":[10,-45,-6],"label":"The long climb","note":"He hauls up the 24 m face to Drum court in plain view; the tier tips as he mantles."},
    {"at":[8,-34,0],"label":"He passes below","note":"You hide in the wrap's cell or the terrace undercroft as he crosses, then come out behind him."},
    {"at":[28,0,0],"label":"The head set again","note":"He reaches the cella and puts his head on; the shock ring rolls out."},
    {"at":[14,-14,-6],"label":"The drop","note":"Whole, he leaps down onto Keel shelf; it lurches under his landing and you run upslope."},
    {"at":[-36,-58,0],"label":"Off the foot","note":"You reach the plane and take off, one drop ahead of him."}
  ],
  "notes": [
    {"at":[8,-34,-12],"text":"terrace undercroft: too low for him"},
    {"at":[8,-34,4],"text":"wrap safe cell"},
    {"at":[10,-46,-6],"text":"U3 to U2 face 24 m, 7 heads (his climb)"},
    {"at":[12,-24,-8],"text":"U2 to U1 face 20 m, 6 heads"},
    {"at":[-10,-58,0],"text":"foot too big to tip: groans only"}
  ]
}
```
