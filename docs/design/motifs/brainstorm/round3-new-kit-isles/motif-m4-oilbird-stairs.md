# The Oilbird Stairs
Lenses: verb stay hidden, then fall/descend (and climb out); shape a tight cluster; scale intimate; mood oppressive.
Pitch: Four small isles hang round one dark gulf, and the guacharo circles over every bare stretch of turf. You go down the cluster by the only roofs there are, a hood's gallery and a stair you must slam into place, and you climb out the long way, in the open, up a broken ring.

Place: A ring of four isles round a gulf about 20 m across, each lower than the last: the Lid (top 0), Understair (-5.5), Gutter (-11), Footing (-16.5). The gaps between neighbours are 5 to 8 m, close enough to see a pilot's height of detail across them. The Lid's long open turf is where the plane sets down, and from it you see the other three as a tight grey stair of rims going down, with the broken nimbus standing on the Footing's west end and its high horn level with the Lid's east rim. The guacharo hangs over the gulf.

Top (1 char = 4 m; x east, z south):
```
 0         10        20        30        40        50
 +---------+---------+---------+---------+---------+
 .  1111111111111   .                                   1 Lid (turf, landing LLLL)
 . 1LLLLLLLLLL111"                                      
 .  11111H@11111                         . . . 4444444
 .         2222222        .  ~~~~       .  (N)4444444444    N nimbus
 .         222H2222   .              .   ~  444444444444
 .            .  \  3333333333        .   . 44444444444
 .              ..  3333H@33333>>>>>>>>>>.  4444444
 .                  333HH33333                 (o)        o guacharo over the gulf
```
Side (west to east; heights from the Lid's turf):
```
 0  111111111H@111       . . . (high horn +0.6, the way out)  N
 -5.5     2222H2222                                      /  \ 
 -11          3333H@3333                                /    \
 -16.5                   . . . . . . . . . . . . . . 44444444444
        hood / stair down the cluster -->   <-- nimbus, rope up
```

Play: You land on the Lid's bare strip with the bird already circling, and the only way not to be taken is to get under stone: the hood on the Lid's south wall. From its wall walk you drop on the hung stair's boss, the stair swings into the notch under the lip, and you go down it hidden. Each isle below puts a roof over you and a sky-gap or an open lip between roofs, and you learn to move from cover to cover on the bird's schedule. Going back out is the opposite: no roof, a ring to climb and ropes over the gulf, with the guacharo reading you as fully exposed.

Set pieces:
- `pent_hood` (Lid, 2 bays, fallen 0): the one clean hide, a gallery of about 10 m along the Lid's south wall. The bird loses you in it (cover ray hits the slabs), and the wall walk above it (4.9 m) is the perch for the slam.
- `keel_hung_stair` (Lid notch, then Gutter's east lip): hung it is a 50 degree slide off the lip, so you can't use it. Slam the boss from the hood's wall walk (4.9 m of air, over the 1.8 m needed) and it turns in about 1.7 s to a walkable flight under the turf, held 12 s, carrying you down into the notch of the isle below. The second one, on Gutter, is slammed from Gutter's own hood wall walk.
- `pent_hood` (Gutter, 2 bays, fallen 2): the rim walk with two bays missing, so two dashes through open sky under the bird's up-ray, with the hood's parapet as your only cover from the side.
- `relic_nimbus` (Footing west end): the exposed way out, inner stubs, the spoke round the front, outer brackets, then the twirl leap from the low horn to the high horn at +0.6, and a short jump from there to the Lid's rim. The plane fits through the ring.
- `relic_torana` (Gutter west to Understair's south rim): a lintel tilted up over the gulf with 3 prayer ropes, the shorter way up, but in plain sight of the bird for its whole length.

Threat: The guacharo (scripts/enemies/guacharo.gd, feature `flyer`), home over the gulf. It reads you as exposed on open turf, in the air, on a rope, hanging or by a rim, and marks you, stalks, folds with a scream and stoops; stone over your head (one ray straight up within `cover_up`) makes you cover and it gives up after ABORT s. Strike buffets you in the air and snatches you if stood, then drops you over the nearest void. Under the hood, the turned stair and the lower isles' keel overhangs you are cover; the fallen bays, the lips and every climb are not.

Ports: Catches the plane on the Lid's strip (flown in along the gulf, the nimbus ring is a fly-through on the way out). Throws out a sail or a plane take-off from the Lid, and nothing else.

Kit used: `pent_hood`, `keel_hung_stair`, `relic_nimbus`, `relic_torana`, `wall`, `floor`, `stairs`, `fallen_pier`, `pier`, rope swing ropes (relic_torana's), floating stones (the gulf's hops).
Kit asks: none.

Family knobs: `tiers` (3-5: how many isles the cluster has), `fallen` (0-2: gaps in the lower hoods), `hold` (the stair's turned time, 8-16 s), `bird` (1-2 guacharos).

Sockets: rims: the Lid's east rim and Footing's west end (the nimbus's horn). arenas: the Lid's strip, the gulf in the air above the middle of the cluster. cover: the hood galleries, the notches under each lip. perches: the hood's wall walk (4.9 m) over each boss; the nimbus's horns.

Fit: role hero/descent; footprint about 60 x 40 m; height span about 17 m (the Lid down to Footing), plus the guacharo's circle above.

Distinct from: `hollow_keel` (a fly-through hall under one plate: no hunter, one descent) and `stair_clouds` (one mesa, a grand stair climbed in view). This is four close isles whose way down is hidden and slam-gated and whose way up is open, with a hunter that decides which is which.

Layout:
```json
{
  "isles": [
    {"id":"1","name":"Lid","x":0,"z":0,"rx":24,"rz":15,"top":0,"keel":-9,"set_piece":"pent_hood (clean), hung stair boss, landing strip"},
    {"id":"2","name":"Understair","x":12,"z":13,"rx":11,"rz":8,"top":-5.5,"keel":-12,"set_piece":"the turned stair's foot, torana's top"},
    {"id":"3","name":"Gutter","x":24,"z":26,"rx":12,"rz":8,"top":-11,"keel":-18,"set_piece":"pent_hood (2 gaps), second hung stair, torana's jamb"},
    {"id":"4","name":"Footing","x":42,"z":12,"rx":14,"rz":10,"top":-16.5,"keel":-24,"set_piece":"relic_nimbus"}
  ],
  "links": [
    {"from":"1","to":"2","kind":"stair"},
    {"from":"2","to":"3","kind":"stones"},
    {"from":"3","to":"4","kind":"stair"},
    {"from":"3","to":"2","kind":"rope"},
    {"from":"4","to":"1","kind":"climb"}
  ],
  "pilot": [[-12,0,-6],[6,0,9],[9,4.9,9],[10,-5,12],[18,-5.5,16],[26,-11,24],[34,-11,26],[37,-16.5,18],[34,-16.5,12],[30,0.6,6],[22,0,4]],
  "threat": [[10,18,10],[0,16,-10],[24,16,0],[36,18,20],[20,18,16],[10,18,10]],
  "tips": [[30,0.6,6]],
  "landing": [-22,-9,8,-3],
  "end": [-12,0,-6],
  "moments": [
    {"at":[-8,0,-6],"label":"Bare turf","note":"You land on the strip and the guacharo marks you at once; you taxi off toward the south wall."},
    {"at":[6,0,9],"label":"The hood","note":"You squeeze into the pent hood's gallery; the bird loses you under the slabs and climbs away."},
    {"at":[9,4.9,9],"label":"The slam","note":"From the wall walk you drop on the stair's boss; it shudders, grinds and turns to a walkable flight under the turf, and you have 12 seconds."},
    {"at":[20,-11,26],"label":"Two gaps of sky","note":"On Gutter's hood two bays are gone; you wait in the gallery, watch the bird, and dash the open ones."},
    {"at":[34,-16.5,12],"label":"The ring","note":"The way out is the broken nimbus, in the open: stubs, the spoke, the brackets, with the bird stooping."},
    {"at":[30,0.6,6],"label":"Horn to rim","note":"A twirled leap to the high horn and a jump to the Lid's rim, level with where you began."}
  ],
  "notes": [
    {"at":[8,0,8],"text":"boss: slam from the wall walk, 4.9 m of air"},
    {"at":[24,-11,22],"text":"2 fallen bays: 3 m dashes"},
    {"at":[18,-8,20],"text":"torana: 3 ropes up, no cover"},
    {"at":[36,-8,12],"text":"nimbus: plane fits through the ring"},
    {"at":[-10,0,-6],"text":"landing strip 30 x 6 m"}
  ]
}
```
