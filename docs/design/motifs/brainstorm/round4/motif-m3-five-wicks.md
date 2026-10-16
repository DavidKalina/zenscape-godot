# Five Wicks
Lenses: verb stay hidden; mood oppressive; shape a tight cluster; world under (the Olmec city).
Pitch: Four great cressets burn round a sunken court on a tight cluster of pillars, and the one headless body that walks its ring is lit as plain as day anywhere in it. Light is what betrays you here, so you put your own torch out, keep to the dark outer faces, and get him to knock the fires over for you.

Place: Six pillar-isles close enough to jump between, round a court. The arrival A (paved crown, south) looks north over a sunken court V ringed by its four great cressets (C1-C4, bowls lit since ever) with a headless body walking the ring road. Behind and above, four wick spires (W1-W4) stand off V's corners, crowns lit, glyph stairs spiralling up their shafts. Far north, X, a higher pillar with its crown lit and the rim out. No sky, no plane: the only light is the fires', and they all fall on the court.

Top (1 char ~ 4 m; x east, z south):
```
 0         10        20        30        40
 +---------+---------+---------+---------+
 .          X  @ (rim out, +4.8)
 .        W3         W4          W3 W4 spires
 .           \       /
 .   (C3)  1111111111  (C4)      C cressets on V's ring
 .      \   1 V court 1    /     o body walks the ring
 .  W1   .  1  o ->   1  .  W2
 .      /   1111111111  \
 .   (C1)    ..   ..    (C2)
 .             \   /
 .              AAAA            A arrival, trough T
 .            T AAAAAA
```
Side (west to east, from A):
```
   W1 +9.6        W2 +9.6          X +4.8 @
   |  spire        |  spire        /
   |      C1  C2    ..           /
 A 0 ..... V -3.0 (court, lit) ..../ gap
```

Play: You step out onto A and the whole court is lit and the body is in it, so you go the other way first: into the snuff trough on A's lip, where your torch hisses out, and you read dark. From there you hug the outer faces of the spires, where the fires' light has died away, and climb a spire's glyph stair to a perch over the ring. A noise from the perch (a slam, a rune) draws him off his beat past a cresset; he barges it, it tips and spills, the pool goes dark and he stands over the spill looking for you, and that is the window. Four fires, four windows, and the last of them opens the way across the court to X, where a lit fire relights your torch.

Set pieces:
- The trough (`city_hush`'s snuff on A's north lip): step in and the torch goes out; the lit lamp at X's mouth is the only relight, so you cross the cluster dark and cannot go back lit.
- The wick spires (`maker_wickspire`, 2 courses up): each a perch over its quarter of the ring with a glyph stair to climb; a slam or a rune taken from the top is the lure, loud enough for the beat's far side.
- The tipped cresset (`maker_cresset`, great): on his lane, barged and spilled into a Beacon he looks at for the spill's life, then dark. The spill burns a while, so the window is short, not a rest.
- The court (`city_pillar` crown, sunk a course): bare when dark, a stage when lit. The seams between two pools sum their light, so the seam is the brightest ground in the place.

Threat: One headless body (scripts/enemies/headless_body.gd) walking V's ring in a patrol loop (body_routes.gd). Sight (body_sight.gd): lit by the pools he reads you out to far, dark only his near range (`dark_range`); the awareness meter fills a second seen and holds a grace unseen. Hearing (body_hearing.gd): a step, a landing, a grab or a slide scrape on the bus draws him within its loudness (steps in the court carry; a slam carries to the far side). Caught, a pounce knocks you (`knock`, a heart); it climbs and mantles, so a spire's stair is a perch, not safety, and the spiral's lowest turn is where he stands to look. Walls do not block light (SightLight has no occlusion), so a pool lights you through a spire; keep out of the radius.

Ports: Catches the walker at A's south rim (rim in) and nothing else (no plane underground). Throws out at X's north rim.

Kit used: `city_pillar` (A, V, X, the spire bases), `city_hush` (the trough on A), `maker_cresset` (great, C1-C4, tips), `maker_wickspire` (W1-W4), `city_niches` optional (a lit alcove on X's face), headless body (scripts/enemies/headless_body.gd), NoiseBus noises.
Kit asks: `maker_snuffcap`, a stone lid on a spire's crown cup the pilot drops with a slam to douse its cresset on purpose, so a window does not depend on a lure.

Family knobs: `fires` (3-5: cressets on the ring), `beat` (0.7-1.3: how fast he loops), `spill` (4-10 s: how long a tipped fire burns), `hearing` (0.8-1.2).

Sockets: rims: A's south edge (in), X's north edge (out). arenas: V's court and ring road. cover: the spires' outer faces and the lit-pool seams' dark flanks (not the seams). perches: the four spire crowns (2 courses up) and the glyph stairs.

Fit: role the hero hide place; footprint about 80 x 70 m; height span about 15 m (V's court up to a spire crown, X a course over A).

Distinct from: `lamplighters_stair` (a Z stair of lit lamps climbed in the open, his lane at the top) and the hush gallery refuge (one dark hall to pass through). Here the dark is made, by dousing your own torch and by getting him to put the fires out, in a cluster where he is always in earshot.

Layout:
```json
{
  "isles": [
    {"id":"A","name":"Arrival","x":0,"z":38,"rx":14,"rz":9,"top":0,"keel":-40,"set_piece":"paved strip, snuff trough on north lip"},
    {"id":"V","name":"Court","x":0,"z":8,"rx":14,"rz":11,"top":-3,"keel":-40,"set_piece":"ring road, 4 great cressets"},
    {"id":"W1","name":"West spire","x":-24,"z":14,"rx":6,"rz":6,"top":9.6,"keel":-40,"set_piece":"wick spire, glyph stair"},
    {"id":"W2","name":"East spire","x":24,"z":14,"rx":6,"rz":6,"top":9.6,"keel":-40,"set_piece":"wick spire, glyph stair"},
    {"id":"W3","name":"NW spire","x":-20,"z":-12,"rx":6,"rz":6,"top":9.6,"keel":-40,"set_piece":"wick spire, perch over the north ring"},
    {"id":"X","name":"Exit","x":0,"z":-34,"rx":13,"rz":9,"top":4.8,"keel":-40,"set_piece":"lit fire, rim out"}
  ],
  "links": [
    {"from":"A","to":"W1","kind":"stones"},
    {"from":"W1","to":"W3","kind":"climb"},
    {"from":"W3","to":"X","kind":"stones"},
    {"from":"A","to":"V","kind":"stair"},
    {"from":"V","to":"X","kind":"stair"}
  ],
  "pilot": [[0,0,36],[-4,0,32],[-22,0,28],[-24,9.6,14],[-20,9.6,-12],[-8,4.8,-24],[0,4.8,-34]],
  "threat": [[-9,-3,0],[9,-3,0],[9,-3,16],[-9,-3,16],[-9,-3,0]],
  "tips": [[-9,-3,0],[9,-3,16]],
  "landing": [-12,34,12,42],
  "end": [0,4.8,-36],
  "moments": [
    {"at":[0,0,36],"label":"A lit court","note":"You step out on the strip, the four fires all on the court and the body walking in them; you are seen anywhere near."},
    {"at":[-6,0,32],"label":"The trough","note":"You step into the snuff trough on A's lip: your torch hisses out and you read dark; the fires are all that lights you now."},
    {"at":[-24,0,22],"label":"The outer face","note":"You hug the outside of the west spire, outside the fires' reach, and climb its glyph stair in the dark."},
    {"at":[-24,9.6,14],"label":"The lure","note":"From the spire's crown you slam; he leaves his beat past C1, barges it, and it tips and spills: a short, dark window."},
    {"at":[-8,4.8,-24],"label":"The seam","note":"The last fire is out but the court's north seam is still lit by C3 and C4 together; you take the spire stones round it."},
    {"at":[0,4.8,-34],"label":"The relight","note":"At X's lit fire your torch catches again and the rim is a few steps on."}
  ],
  "notes": [
    {"at":[-6,0,34],"text":"landing: on foot only, clear paved strip 24 x 8 m"},
    {"at":[-9,-3,0],"text":"C1 on his lane: lure him past it"},
    {"at":[0,-3,0],"text":"seam: two pools sum, brightest ground"},
    {"at":[-24,9.6,22],"text":"spire stair: perch, not cover"}
  ]
}
```
