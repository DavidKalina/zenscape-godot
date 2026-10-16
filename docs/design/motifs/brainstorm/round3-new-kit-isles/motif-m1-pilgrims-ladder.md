# The Pilgrim's Ladder
Lenses: verb climb (with a hide and a descent); scale human to colossal; mood sacred; shape a tall stack (four isles, each higher and further east than the last), the literal reading of the seed.

Pitch: Four sky isles stepped up like a pilgrimage, one new piece for each station: the prayer lintel's ropes lift you off the landing isle, the broken nimbus carries you up to the horns, a hooded cloister hides you from the bird on the crown, and a slam from the horn turns the hung stair into the way down. The plane lands on the foot isle, flies through the ring on the way out, and the whole climb is one loop back to it.

Place: A stack drifting up and east. Isle 1 "Threshold" (broad, top 0) has the plane's strip on its west half and a lone torana jamb on its east lip, its lintel tilted up over the gulf. Isle 2 "Halo" (top 7) is a round plate with the nimbus standing on it, the ring's centre 8.2 m up so it reads from isle 1 as a great broken wheel on the horizon. Isle 3 "Crown" (top 22) is a stepped plate with a kit wall and a pent_hood along its north rim, and a carved boss on its turf near the south lip. Isle 4 "Cellar" hangs under the Crown's keel (top 13), reached only through a shaft. On arrival you see the lintel, then the wheel beyond it, then the Crown's wall high behind it.

Top (ASCII, 1 char = 4 m; north up):
```
 x:  -44      -20       4        28       52       76       100
     ..........................................................
        11111111111111111@|~~~~~~222222~~~~~~~~~33333333
       1PPPPPPPPPP11111111 T=======2222@2222~~~~~~3C"CCC3
        11111111111111111 |~~~~~~~222222~~~~~~~~33B3333333o
         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~4443~~
  P plane strip   T torana (jamb + lintel)  @ nimbus on 2   C pent_hood
  B boss and the hung stair   o guacharo   4 cellar under 3
```
Side (heights in m, x east):
```
                                                   horn 24     3 crown 22
                                       ring  ____/\      ___________
                                    15 ___/      \ ~~~~sail~~|C|___B_
            lintel 7  ___________________ 2 halo 7           | shaft
 1 threshold 0 ____P_____|jamb/ropes~~~~~gulf~~~~~~~~~~~~~~~~~~ 4 cellar 13
```

Play: You land on the foot isle, walk to the jamb and take the ropes up under the lintel, each a little higher than the last, onto the lintel's top and across to the Halo. There the ring is a ladder of stubs, a spoke and brackets round to the horns, a long climb in the open. From the high horn you sail across to the Crown, where a bird circles; you creep under the pent hood along the north wall, and when you come in off the horn you slam the boss to turn the stair, then run down it before the twelve seconds are up. It leaves you a long way up and a long way from home, and the way back is down.

Set pieces:
- relic_torana (Threshold's east lip): 4 ropes under a lintel that rises 1.6 m per rope to the Halo's lip; a dry rope snaps and throws you on, so the chain has a gap to twirl. The niche sills on the jamb are the slow way up.
- relic_nimbus (Halo's centre): the climb is inner stubs up the left wall, the spoke round the front, outer brackets, then the low horn and a twirled leap to the high horn. The plane flies through the 11.4 m ring (over the 7.0 toy opening).
- pent_hood (Crown's north wall, 2 bays): a dark gallery to crouch along under the bird's up-ray; one fallen bay is an open dash. Its roof is a pent slide off the eaves down to the Crown's lower step.
- keel_hung_stair (Crown's south lip, boss on the turf): hung, its soffit hangs off the lip as a 50 deg slide that dumps you into the sky; slammed (from the sail in off the high horn, 2.1 m above the boss), it turns into a stair down a shaft to the Cellar for twelve seconds. Standing on it when it turns back throws you.

Threat: One guacharo (scripts/enemies/guacharo.gd) circles the Crown and hunts by up-ray, so the hood hides you and the open bay does not. It wakes when you step onto the Crown from the horn sail. The hung stair's own turn-back is the second hazard (a toss or knock).

Ports: catches the plane on Threshold's strip and flies it out through the nimbus; throws out the sail from the Crown's east lip (the ordinary descent back to Threshold, 22 m down, long) and the hung slide.

Kit used: `relic_torana`, `relic_nimbus`, `pent_hood`, `keel_hung_stair`, `wall`, `floor`, `stairs`, `buttress`, `fallen_pier`, `arch` (RuinKit pieces; scripts/rope_bridge.gd and floating stones for a spare crossing at the Halo).

Kit asks: none.

Family knobs: `ropes` (3-5), `ring_stubs` (2-6), `bays` (1-3), `hold` (8-16 s).

Sockets: rims: Threshold's east lip (facing east, torana), Halo's west lip (receives the lintel); arena: the Crown's top; cover: the pent_hood gallery; perch: the high horn (also the slam perch over the boss).

Fit: role hero/vertical; footprint about 150 x 50 m; height span 22 m plus the ring's 17 m (horn 24 m).

Distinct from: `stair_clouds` (one mesa with a grand stair), `broken_ring` (a ring of islets, no climbed piece) and `hollow_keel` (a hall hung under a plate, flown through); this is a stack where each isle is built around one new piece.

Layout:
```json
{
  "isles": [
    {"id":"1","name":"Threshold","x":-10,"z":0,"rx":40,"rz":22,"top":0,"keel":-14,"set_piece":"relic_torana jamb + landing strip"},
    {"id":"2","name":"Halo","x":70,"z":0,"rx":22,"rz":16,"top":7,"keel":-4,"set_piece":"relic_nimbus"},
    {"id":"3","name":"Crown","x":100,"z":0,"rx":20,"rz":16,"top":22,"keel":8,"set_piece":"pent_hood + boss"},
    {"id":"4","name":"Cellar","x":92,"z":-4,"rx":9,"rz":7,"top":13,"keel":8,"set_piece":"shaft foot"}
  ],
  "links": [
    {"from":"1","to":"2","kind":"rope"},
    {"from":"2","to":"3","kind":"climb"},
    {"from":"3","to":"4","kind":"stair"},
    {"from":"3","to":"1","kind":"stones"}
  ],
  "pilot": [[-30,0,0],[28,0,0],[48,7,0],[70,7,6],[69,24,0],[86,22,6],[92,13,-4],[96,13,10],[-8,0,6]],
  "threat": [[110,28,-8],[100,28,-12],[88,28,-6],[96,28,8],[110,28,4]],
  "tips": [[84,22,6]],
  "landing": [-38,-5,-8,5],
  "end": [-30,0,0],
  "moments": [
    {"at":[34,3,0],"label":"The ropes","note":"You run in, swing, release rising and catch the next rope up under the lintel; a dry rope snaps and you twirl to the one past it."},
    {"at":[70,15,0],"label":"The wheel","note":"You climb the broken ring by stubs, the spoke and brackets to the low horn; the plane can fly through the same ring."},
    {"at":[69,24,0],"label":"The leap","note":"A twirled leap to the high horn, the whole stack in view."},
    {"at":[97,22,-12],"label":"Under the hood","note":"You creep the gallery under the circling bird; the fallen bay is a dash across open sky."},
    {"at":[86,22,6],"label":"The slam","note":"Sailing in off the horn you slam the boss; the stair turns with a grind and you have twelve seconds."},
    {"at":[92,13,-4],"label":"The cellar","note":"You reach the Cellar before the stair turns back and throws the late; a sail from its lip takes you home."}
  ],
  "notes": [
    {"at":[28,0,8],"text":"jamb niches: the slow way up"},
    {"at":[70,15,0],"text":"ring clear 11.4 m: plane fits"},
    {"at":[78,24,0],"text":"horn to Crown: sail, 10 m"},
    {"at":[84,22,12],"text":"hung stair: 50 deg slide off the lip"},
    {"at":[100,22,-12],"text":"pent_hood gallery 2 bays"}
  ]
}
```
