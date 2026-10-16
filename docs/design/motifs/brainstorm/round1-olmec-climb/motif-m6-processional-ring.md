# The Processional Ring
Lenses: verb TIME A CROSSING, mood SACRED, shape A RING
Pitch: Five islands wind up round the colonnade's temple end like a processional way that was never finished: seated on each other's shoulders on the inside, gaping on the outside. The Olmec takes the inside, a stack of cliffs only he climbs, and the pilot takes the outside, ropes and slabs, so every crossing is timed against the hands he can be seen hauling up the face.

Place: The spine stays the centrepiece; the ring starts at its temple end (the west, high end, podium 8 x RISE, 17.9 m up the ridge) and goes round it counter-clockwise (north, west, south) and up. Heights are over the cella floor P. Seen on arrival from the east along the ridge: the temple gate, and past it, over its roof, the ring: a broken wreath of five grey-green islands, each higher than the last, bridges slung across the outside gaps, and one small figure of stone hauling up a cliff face on the inside. Sacred: every island has one hushed set piece built for a rite (court, pit, terrace, felled shaft, sun stair). Ruin-style city pieces, overgrown, no runes, no frets.

Ring (each island is a real chunk of KitLand.island, stepped, turf crown, a keel; 40 to 56 m across). Heights over P and the inner cliff each stands on the one below:

| Isle | Where (spine frame, x east, z south) | Top over P | Inner face up from the one below | Set piece |
|---|---|---|---|---|
| S  | the spine itself, temple at x 14-43 | 0 | - | the colonnade, temple, his plinth (unchanged) |
| 1 Threshold | (-34,-74), 44 x 32 m | +6 | 6 m (1.8 Hh) off the podium's NW corner | The Hauling Lip |
| 2 Pit Court | (-84,-14), 52 x 44 m | +18 | 12 m (3.6 Hh) | The Leaper's Pit |
| 3 Terrace | (-44,52), 48 x 40 m | +32 | 14 m (4.2 Hh) | The Hanging Terrace |
| 4 Shaft | (20,74), 46 x 34 m | +46 | 14 m | The Felled Column |
| 5 Crown | (86,50), 60 x 46 m | +62 | 16 m (4.8 Hh) | The Sun Stair, the summit |

Hh is his head height, 3.36 m at the knobs. Every inner face is over his stride (2.4 m) and his crag haul (CRAG_CLIMB 4.0 m) and well under his climb_max (about 22 m): a climb of 4.3 to 11 s at his climb rate (about 1.4 m/s) plus the mantle (1.4 s) and the landing's shock. Every inner face is sheer for the walker (a dozen times her CHAIN_TOP, 2.6 m): she gets no line up the inside except the two walker-only places named below.

Top (1 char = 4 m; north up; ring about 70 m out from the temple end, the spine east of it):
```
 0         1         2         3
 0123456789012345678901234567890123456789
 0
 1        ~~ 1111111 ~~~
 2       ~ 111"""1111 ~  ~ ~
 3       ~ 1111@1111 .~~
 4    ~~  ~ ~ ~. .~ ~ ~       ~ ~
 5  222222   ~ .  ~ ~ ~~~
 6 2222"2222  ~. ###  ~  ~
 7 22@22222  . ~@@@##############"""""""
 8 2222222~. ~ ~@T@###############o###.##
 9 2222"222   ~ ~@@@##############"""""##
10  22222  ~ .~ ~ ~ ##########  ~
11   ~   . ~~ ~    ~~ ~     55555555555
12    333333 ~  .    ~     555555555555
13   33@3333   ~ . ~ 4444    55555@5555
14   333"333 ~~ ~~~. 4444C~~ 555555555
15    333333 ~   ~~.. 4@44 ~~~  5555
16         ~    ~~~~   4444
```
(T the temple; the numbers' @ the set pieces; '.' the outside route; the inside line is the straight stack of faces from T up through 1, 2, 3, 4, 5 and does not show; 'o' the Olmec's plinth; C the felled column's plinth.)

Side (the ring unrolled along its way, n to s to e; heights over P):
```
                                                       5 +62  ______
                                       4 +46  ______  /      |Sun Stair|
                         3 +32  ______  |inner|       | 16 m  '-'-'-'
             2 +18 ______  |inner|   14 m   '--bridge--..felled column
   1 +6  ____ | inner|  14 m  '- sagged span -'
 S 0 ___| 6 m   12 m   '-- rope 36 m --'     '- rope 44 m (snapped option) -'
   ^ temple podium
```

Connections (outside = the pilot's; inside = his):

| Hop | Outside crossing (pilot) | Inside line (Olmec) |
|---|---|---|
| S to 1 | Live rope bridge from the podium's west corner anchor to 1's east anchor, 36 m, level, whole | 6 m haul up the podium's NW face onto the Threshold |
| 1 to 2 | Live rope bridge, 44 m long, rising 12 m end to end (a taut, steep deck), whole or snapped by the `bridges` knob | 12 m climb, 8.5 s |
| 2 to 3 | A ruin-style causeway span (CityKitWays `span`, state "sagged": two halves down into a V, 30 m, rises 14 m over the whole run); the halves each a long slope, the V's low point a 2 m set-off she chains up | 14 m climb, 10 s |
| 3 to 4 | A ruin-style whole causeway span (state "whole"), 32 m long and rising 14 m, his 8.8 m lane wide. Longer than SPAN_MOST (26 m), so it never cracks under him: it is the quick way up for both of them, and he will walk it | 14 m climb |
| 4 to 5 | Nothing whole. A 14 m gap. The pilot's way over is the felled column (see Play) | 16 m climb, 11.5 s + mantle |

Play (timing the crossing; the clock is where he is on the spiral):

1. Arrival and waking (round 1 as is). The plane lands on the spine's south bench (the 14 m run) or, new, on 1's or 5's lawn (see Landing). He wakes, gets his head from the cella (the existing beat, about 100 s), and the ring is the second act. His head on, the roar rings round the wreath.
2. S to 1. He has just stood the head on his neck at the cella; the pilot is already on the rope bridge at the podium corner. He is the temple's occupant and the tilt there is the existing colonnade's. The first lesson: you can see him. The rope bridge's near anchor stands on a hinge slab (a ruin `floor` slab, about 10 m, one node; 6 to 80 m tips). The pilot crosses at his pace (36 m takes 15 s at a walk of 2.4 m/s, 7.5 s at a run of 4.8 m/s); he climbs the 6 m podium face in 4.3 s plus a 1.4 s mantle, then walks about 20 m to the hinge slab at his chase pace of 4.3 m/s (5 s). That is about 11 s for him against 7.5 s for her at a run: she wins by about 3 s; a walker who stops to look loses it. If he steps onto the hinge slab while she is still on the rope, the slab dips toward his weight (the tilt's DIP and LEAN), the anchor drops, the deck goes slack and the sag is deep: the rope throws her up and down, not off. Fair, readable, and the groan comes first.
3. 1 to 2. The rope is taut and climbs 12 m. The pilot must climb the rope's slope (rope swing or the deck, whichever the bridge sim lets her). The clock: his inside climb is 12 m, 8.5 s plus a 1.4 s mantle, about 10 s from the foot of the face; her 44 m at a run is 9 s plus the slope. A near dead heat on purpose. She is near the far anchor when he comes over the lip, and his mantle lands with a small shockwave (the "mantle's end sends a smaller one"), reaching the court: a walker on the ground within its radius is thrown back and up. So the choice: cross early and be well into the court before he is up, or hold back on the near island and cross after he has gone over (the rope is then his tilt problem, not hers).
4. 2, the Leaper's Pit. The court is split by a pit: two plinths across a 9 m gap inside his jump (3 Hh: about 10 m) and past hers; the east cornice along the fins is hers and breaks under his landing, nearest first. This is the set piece's lesson in miniature: he can leap the gap, she can't jump it, but she crosses by the cornice, and when he leaps the landing's shock and the cornice break behind her. He leaps across the pit toward the pilot (the leap ranges 12 m); his landing tips the plinth he lands on (a block; the pit's plinth tops are about 11 m, within 6 to 80 m) and the shockwave runs over the court. The pilot hops the pit via the cornice just as he commits to the leap (his windup is 1.1 s, a tell: crouch, arms back): she times it to the crouch.
5. 2 to 3. The sagged causeway: she takes the V. Two halves slope down toward a 2 m set-off cracked V (low point 2 m below the halves' high ends); she slides down one half (a slide) and chains up the other. A rope-free crossing, slow, and the Olmec's inside climb (14 m, 10 s + 1.4 s) beats her slide if she dawdles. A cracked V is also where she can lead him if she runs the ring back: sagged spans can crack under him (SPAN_TELL 0.75 s, a tell: dust sifting) and drop him to the island below; he climbs back (layer_olmec's "back up a cliff"), a free 30 s.
6. 3, the Hanging Terrace. Two decks hung on the island's host wall, his stair between them; under the upper deck the undercroft (too low for him) with her shelves up through a hatch: a true safe room. The upper deck's outer tier snaps under his weight (his landing breaks it, nearest first). This is the ring's rest: she can wait in the undercroft and he wanders (lose 2.0 s; chase memory 16 s, lost for 15 s) while the ring stays quiet: sacred, hushed, wind in the overgrowth. If she waits, he searches the terrace and may snap the outer tier and fall one island down; that costs him a climb (about 10 s) and her nothing. If she leaves early, he sees her cross the whole span (3 to 4).
7. 3 to 4. The whole span is the one easy crossing, a long ceremonial causeway that holds under both; the only timed element is the island 4 end, where the span's far pier cap and the felled column's plinth are one stone (the hinge slab, 12 m).
8. 4, the Felled Column. A free-standing drum column of the makers on a stepped plinth at 4's east lip, 6 to 8 drums of 2.2 m (13 to 17.6 m), standing with its fall axis toward 5 across the 14 m gap. His bulk or his landing's shockwave fells it away from the hit: he must come at it from the inside (the west). Felled, the column lies across the gap: its fall puts the capital on 5's lip and it is a 5.5 m wide bridge, the plinth's treads a jump and a grab for her. This is the ring's key timing: she cannot cross the 4-5 gap without it, and he fells it only by arriving from the right side. So she waits at the column for him to climb onto 4 (he comes up the inner face, 11 s), lets him come at her, and slips round the plinth as his landing's shockwave fells it onto 5; the shockwave throws a walker on the ground so she is in the air (a jump timed to the shock, clear of the wave: "one in the air over it is clear") and rides the fall of the column over to the lip. If she times it wrong the wave throws her and the column falls with her on the wrong side: she runs the other way round the ring (back down by the rope bridges, a lap of the ring to earn the shot again; he is now on 4 and has to climb back down... he drops to the next island: his drop_max 22 m).
9. 5, the Crown (summit). The sun stair: a ruin-style pyramid (two stepped tiers, not four) on a long lawn, a stone circle (stone_circle) of loose drums on its edge, a summit shrine whose door only she fits (a safe room) and a walker-only grab chain up the west face. He climbs the 16 m inner face (11.5 s + mantle) onto the lawn, mantles and lands (the lawn's drums tip, a stone circle's drums are 6 to 8 m, they groan and tilt; a walker on one is thrown). The chase ends in one of three ways, her choice: (a) she climbs the west chain (a walker-only chain he can't read) to the shrine: he stands below, loses her, wanders (15 s); (b) she runs the lawn to the plane (the 30 m run) and takes off with him a screen behind; (c) she gets him to leap down the pyramid or off the lip chasing her, so he falls to island 4 or 3 and the ring has to be climbed again.

Choices: take the quick causeway or the long rope; wait in the undercroft or run the ring; fell the column early or lure him to it.

Where his climb fires: six places, each a face he climbs with his rays on the real wall and a lip he hauls over: the podium's NW face (6 m), each of the four inner faces (12, 14, 14, 16 m), and the cliffs he climbs back up after a fall. The Leaper's Pit is his leap (10 m across). Every one ends in a mantle landing.

Where his tilt fires (the stone under his feet, no wider than 80 m flat and at least 6 m): the hinge slabs under each rope bridge anchor (a ruin `floor` slab, 10 m) when he crosses the outer lip; the pit's plinth tops (11 m); the hauling lip's cornice slab (the 6 m court lip); the terrace's upper deck outer tier (before it snaps); the stone circle's loose drums on the crown (6 to 8 m); the column's plinth (7 m) when he stands on it. The islands themselves are too big to tip; they groan.

Threat: the Olmec (headless_body.gd), whole, with `chase` on (hunting), breaching masonry (olmec_breach.gd: the sagged span's crack_under, the felled column, the pit's cornice) and tilting the stone under him. No damage: knock and toss only (the shockwave's thrown walker, the hinge slab's lurch of 3.1 m/s along the fall line, slower than her run).

Landing and chase end:
- Landing (each isle the plane reaches keeps a clear stretch long enough to land by hand): the spine's south bench (14 m run, unchanged); Threshold lawn 18 m, aimed along the island's long axis; Pit Court: two lawns; the Terrace's roof (lawn on the upper deck's roof); Shaft Isle: its lawn; the Crown: a 30 m run along the lawn, the ring's summit and the plane's lair. Each island's run is a measured part of its table.
- The chase ends at the Crown: the shrine (safe room), the plane, or a fall that costs him a climb. It can also end earlier at the Terrace's undercroft. A lap back down the ring (reversing the crossings) is the sacred procession done in reverse.

Ports: Catches from outside only the plane, as the spine does (the sky is the plane's); throws out nothing but the roar when he is whole (a ring and a shake over 90 m, the existing wake and `reunited`) and the ledger rows (new: a moment per island reached, and for the felled column).

Kit used (all verified to exist):
- Ruin: `stone_circle`, `floor`, `grand_stair`, `fallen_pier`, `tomb_chest`, `wall`, `stairs` (ruin_kit.gd PIECES); `aqueduct_stump`, `aqueduct_end` (AQUEDUCT_PIECES); `bridge_anchor` (RuinKit); `hall_slab` (HALL_PIECES).
- Foot: rope_bridge.gd, footbridge.gd, rope_bridge_sim.gd, walker_only.gd, KitLand.island.
- City, in ruin style (these ids exist in the city kit; ruin style is the ask): `city_lip` (Threshold, the S-1 face), `city_pit` (Pit Court), `city_terrace` (Terrace), `maker_felled` (Shaft Isle), `city_pyramid` (Crown, cut to two tiers), `city_wrap`, `city_wedge` (optional dressing on Threshold and Terrace; shortcut ramps), `city_riser` (the Threshold's court stair option).
- City ways: `CityKitWays.span` states whole and sagged, `joint_pier` (functions, not registered piece ids; no `slumped` here, that is a knob).

Kit asks:
- A ruin-stone mode for the city kit: `opts.ruin` (or a `stone` choice in city_kit_stone.gd) that draws the pieces in the ruin kit's stone (RuinKit palette and overgrowth) with no rune grooves (CUSTOM0/1 off) and no frets (the span's fret down its faces, the cornice bands: geometry skipped), keeping shape, lanes and collision unchanged.
- A two-tier `city_pyramid` option (`tiers` opt) so the Crown's footprint is about 40 x 40 m, not the landmark's.
- Rope bridge anchors on a tippable slab: a `hinge_slab` node grouping a `floor` slab and the `bridge_anchor` so the tilt takes them as one node (rope sim reading anchors that move; if the sim can't, the hinge slab is the pier cap beside the anchor and only the lurch acts).
- Assumption to check in the place: his planner does not route onto the live rope bridges (sim deck). If it does, the ropes are his too and the card's timing changes (the ring is then a race on a single line).

Family knobs:
- `isles`: 4 to 6 (the ring's turn; 5 authored); each isle's rise 12 to 16 m (keeps every inner face under his 22 m climb_max).
- `bridges`: whole, one snapped, both snapped (the existing colonnade knob extended: a snapped rope leaves the pilot only the slab spans and the climbs she has).
- `spans`: whole, sagged, slumped, gone per causeway (the city ways' own states).
- `column`: standing, already felled (an easier summit), or absent (the summit then needs the plane).
- `seed`: which isle gets which set piece (Pit and Terrace swap), turf and the lip positions.

Sockets: rims at each island's outer lip toward the next island (facing along the ring, the bridge anchors); arenas: Pit Court's floor, the Crown's lawn; cover: the Terrace's undercroft, the shrine (both walker-only); perches: each Hauling Lip cornice, the column's capital, the pyramid's top tier.

Fit: role hero (extends the colonnade spine's frame, which stays the centrepiece); footprint about 220 x 190 m round the spine's west end (the ring about 140 m across at its widest) plus the spine; height span about 62 m over P plus keels (so about 100 m on the sky's scale); needs the sky's place east of the bell spires cleared by 100 m more to the west (the ring takes the old ferry's far side: clearances to recheck).

Distinct from: broken_ring (eight small islets spiralling 21 m, no enemy, no inside line; here five real islands, 62 m, a double lane with a giant on the inside) and sundered_gorge (two halves and a snapped bridge; here the crossings are many, and timed against a climbing body). The nearest is stair_clouds' stepped mesa, but that is one landmass with one stair and no outside.

Layout: (y is height over the cella floor P)
```json
{
  "isles": [
    {"id": "S", "name": "spine", "x": 70, "z": -14, "rx": 75, "rz": 14, "top": 0, "keel": -24, "set_piece": "temple, colonnade, his plinth"},
    {"id": "1", "name": "Threshold", "x": -34, "z": -74, "rx": 22, "rz": 16, "top": 6, "keel": -18, "set_piece": "Hauling Lip"},
    {"id": "2", "name": "Pit Court", "x": -84, "z": -14, "rx": 26, "rz": 22, "top": 18, "keel": -18, "set_piece": "Leaper's Pit"},
    {"id": "3", "name": "Terrace", "x": -44, "z": 52, "rx": 24, "rz": 20, "top": 32, "keel": -18, "set_piece": "Hanging Terrace"},
    {"id": "4", "name": "Shaft", "x": 20, "z": 74, "rx": 23, "rz": 17, "top": 46, "keel": -16, "set_piece": "Felled Column"},
    {"id": "5", "name": "Crown", "x": 86, "z": 50, "rx": 30, "rz": 23, "top": 62, "keel": -20, "set_piece": "Sun Stair"}
  ],
  "links": [
    {"from": "S", "to": "1", "kind": "rope"},
    {"from": "1", "to": "2", "kind": "rope"},
    {"from": "2", "to": "3", "kind": "span"},
    {"from": "3", "to": "4", "kind": "span"},
    {"from": "4", "to": "5", "kind": "stones"},
    {"from": "S", "to": "1", "kind": "climb"},
    {"from": "1", "to": "2", "kind": "climb"},
    {"from": "2", "to": "3", "kind": "climb"},
    {"from": "3", "to": "4", "kind": "climb"},
    {"from": "4", "to": "5", "kind": "climb"}
  ],
  "pilot": [[14, 0, -22], [-12, 6, -60], [-60, 18, -30], [-84, 18, 6], [-60, 32, 40], [-10, 46, 70], [34, 46, 74], [70, 62, 56]],
  "threat": [[36, 0, -14], [8, 0, -40], [-20, 6, -66], [-70, 18, -34], [-70, 32, 20], [-20, 46, 66], [50, 62, 60]],
  "tips": [[2, 0, -30], [-72, 18, -22], [-50, 32, 52], [28, 46, 70]],
  "landing": [52, 36, 82, 56],
  "end": [88, 62, 50],
  "moments": [
    {"at": [-6, 0, -40], "label": "The first rope", "note": "36 m of live rope from the podium corner; he hauls the 6 m face behind you and steps on the hinge slab; run, don't stop to look"},
    {"at": [-84, 18, -14], "label": "The leaper's crouch", "note": "his windup tells the leap across the pit; hop the cornice on the crouch, it breaks behind you"},
    {"at": [-44, 32, 52], "label": "The hush under the deck", "note": "undercroft too low for him; wait, he loses you, or he snaps the upper tier and falls a climb"},
    {"at": [20, 46, 74], "label": "The column falls", "note": "stand by the plinth, jump on his landing shock, ride the felled drums across the 14 m gap"},
    {"at": [86, 62, 50], "label": "The summit", "note": "walker-only chain to the shrine, or run the 30 m lawn to the plane; his hands come over the lip"}
  ],
  "notes": [
    {"at": [-18, 3, -66], "text": "6 m haul (1.8 Hh)"},
    {"at": [-76, 12, -40], "text": "12 m cliff, 8.5 s"},
    {"at": [-60, 25, 20], "text": "14 m cliff"},
    {"at": [-12, 39, 62], "text": "14 m cliff"},
    {"at": [60, 54, 56], "text": "16 m cliff, 11.5 s"},
    {"at": [-44, 30, 52], "text": "safe room: undercroft"},
    {"at": [48, 46, 74], "text": "14 m gap"},
    {"at": [90, 62, 56], "text": "safe room: shrine"}
  ]
}
```
