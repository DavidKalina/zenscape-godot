# The Hushed Reaches
Lenses: verb STAY HIDDEN, mood OPPRESSIVE, shape SPREAD WIDE.
Pitch: Past the temple's west end the colonnade spine hands on to five wide islands strewn across a gulf, each 12 to 16 m higher than the last, and every gulf is too wide for him to leap but not for the pilot's rope bridges. He is whole and hunting from the cella; the pilot breaks his line of sight in the city pieces' safe rooms, waits him out, and crosses while he climbs the wrong cliff.

## Place
Five real islands, KitLand `island` chunks (outline, stepped height, grabbable cliffs, keel) in the ruin kit's stone, overgrown, no runes or frets, stretched west and up from the temple podium (the spine's X_WEST end, podium 8 RISE = 17.9 m over TOP). Turf and growth on every top. The view on arrival (from the cella's west door, after his head goes on and the roar): a stair of islands going up into cloud, ropes slung between, each with one great stone shape on it, and the faint sound of his steps behind.

Numbers it works from (wanderer 1.0, unit 1.12):
- Pilot: grab 1.9 m (GRAB_TOP), chain about 2.5 m (CHAIN_TOP), SET_OFF 1.6 m, run 4.8 m/s.
- Olmec: Hh 3.4 m, stride/step 2.4 m, climb 1.4 m/s up to 22 m (`climb_max`), leap up to 12 m across (`leap_max`; ledge-to-ledge `jump_gap` 3 Hh = 10 m), drop up to 22 m, walk 2.2 m/s, chase 4.3 m/s (under her run), sight 45 m (15.7 m close, ~1 s grace), seek 12 s then return, swat reach 4.4 m, inhale 15 to 24 m.
- Tilt: what tips is the single node under his feet, 6 to 80 m flat. The islands themselves (30 to 60 m KitLand merged hills) are inside the limit only if a ring of loose stone stands out on them; the big pieces tip, the lawns groan.

| # | Isle | Top over TOP | Size | Set piece | Gap to the last |
|---|------|--------------|------|-----------|-----------------|
| 0 | temple podium (existing) | 17.9 | the spine | the cella, head | |
| 1 | Gatehouse shelf | 30 | 32 m across | `city_terrace` hung on a host wall | 26 m, one rope bridge, one causeway |
| 2 | Cistern lawn | 44 | 56 x 30 m | `city_wedge` chunk, turf landing run 22 m | 30 m, rope bridge + floating stones |
| 3 | Sluice stair | 58 | 44 m | `city_stair` (ruined), `ol_beacon` | 20 m, `city_causeway` (his), rope (hers) |
| 4 | Wrapped crag | 72 | 36 m | `city_wrap` | 34 m, two rope bridges in series via a 9 m satellite |
| 5 | Crown | 86 | 40 m | `city_lip` face, shrine, turf run 16 m | 24 m, rope only |

Heights are in his terms: a rise of 14 m is a 4 Hh wall, inside his 22 m climb, so he can always haul up the outside of an isle if he is on it, but the gaps between are 20 to 34 m of air, beyond his 12 m leap, so he only crosses at a causeway or stair. The pilot's rope bridges are the shortcut: about half his walk.

## Top (1 char ≈ 4 m; west at left, the temple at the right)
```
 ........................................
 5 "" ##@  ~~~~~                          
   ""A      ~~~~ ~~                       
   .  P       ~~ 4 ##o"                    
   .        ~~~~   ""A  ~~~                
   ......                .                 
        ~~~~ 3 ##@ ~~~~~~~ .               
      ~~     "##o     ~~~  2 """"  ~~~     
        ~~~~~  .     ~~~~   """""  ~~~ 1 # 
 ........................ ........ ~~~ ##P ~~
                                          0 ^^#@
```
Digits are the islands, `.` the pilot's ropes and stones, `@` the set pieces, `o` the Olmec's lane, `P` safe rooms.

## Side (rising west, gulf cloud between)
```
                                     5 ____
                              4 ____/  (lip)
                       3 ____/
                2 ____/
         1 ____/
  0 ____/  (temple)
 ~~~~~~~~~ cloud ~~~~~~~~~~~~~~~~~
```

## Play
The Reaches begin when his head goes on (round 1's beat). He knows where she is at the temple, then loses that on the way out: `relentless` is ended at the gatehouse, so past the temple he has only his eyes.

1. **Isle 1, the Gatehouse shelf.** The pilot comes out of the temple gate onto a flight of `stairs` down to a stub, then the rope bridge west. He is behind, climbing the temple's terraces (his tilt: the cella's podium piece tips on the haul). The `city_terrace` (ruin-style) hangs under the shelf's lip: the upper deck is his, the undercroft (2 SET_OFF clear, under his neck, over her head) is hers via a hatch. First hide: she drops into the undercroft, the deck over her, and he arrives at the deck, looks about (`alert`, `seek` 12 s), goes down the stair, returns. The deck's outer tier snaps under his weight, so he leaves with the upper edge gone.
2. **Isle 2, the Cistern lawn.** Open, wide, bright, and nowhere to hide on its turf. The danger is the long open walk: 56 m under his 45 m sight. The `city_wedge` chunk at the lawn's far end is the one cover: the hollow under its high end is her hide, the slab itself his ramp. The wedge is about 10 m long, so it tips: when he hauls onto it the slab rocks and the hide's mouth squeezes. The plane's landing run (22 m) is on the lawn's east side, so a pilot who flew up can leave: the plane is a second route, a hard dive away from him.
3. **Isle 3, the Sluice stair.** The ruined `city_stair`'s fault landing and the `ol_beacon` on top. The pilot can light the beacon (a sight light) to lure his eyes: the beacon is on the far corner of the isle, away from the rope. He climbs the stair toward the light; she crosses the rope at the other end.
4. **Isle 4, the Wrapped crag.** A mid-air satellite (9 m) between two long ropes, `city_wrap` on its crag. The safe cell halfway up the walker's recess is out of reach, sight and inhale. He circles the core on his ramp, the stone tipping with his weight; she waits in the cell until he climbs round the wrong face, then drops down the recess and goes.
5. **Isle 5, the Crown.** The `city_lip` face: he hauls the lip, mantles into the hand-troughs, the cornice's far corner cracks. She goes up the end chain, through the undercut. A shrine door only she fits is the chase's end: the true safe room, out of his reach. The 16 m turf run is the escape for the plane.

**Where the routes split and meet.** At each gap the pilot's rope and floating stones and his causeway or stair part at the near island's rim and meet at the far island's landing; his way is 60 to 70 m longer. The wait is the move: she is across and gone before he has walked round, so each crossing is a decision about when.

**The choices.** (a) Hide now in the safe room and wait him out, or run the open turf. (b) Cross by the short rope while he is on the long way, or stay put to let him lose her. (c) Light the beacon to pull his eyes, or leave it dark. (d) Fly out from the lawn.

**Wait him out.** Lost from sight he goes `seek` (12 s) then `return` to where he was set down: that is back down the last stair. Out of view for 7 s and 34 m off, he goes down into the dark and 6 to 16 s on climbs a cliff of the isle she is on (layer_olmec travel): the climb is the tell (rumble, dust at each hold). The cliff he climbs is the wrong one if she has been seen near it a moment before and is gone from it now. She crosses while he is on the face.

## Where his climb and tilt fire
- **Climb:** every island flank (each ≤ 16 m, under 22) when he travels to her isle; `city_lip` at the Crown; the terraces at isle 1; the temple podium step down.
- **Tilt:** `city_terrace` deck on isle 1 (about 12 m); `city_wedge` slab on isle 2 (about 10 m); the satellite on isle 4 (9 m); the `city_pit` plinths (about 6 m) where used as the isle-3 link.
- **Breaks:** `city_causeway`'s bay at isle 3 (breaks under his weight and cuts him off, so he goes round or travels); the terrace's outer tier; the lip's far corner.

## Threat
The headless body whole, with `chase` on: sight, the swat, the pounce (aimed jump 5 to 15 m), the inhale (15 to 24 m, 5 s) and the swallow. The inhale demands a clear mouth line: the safe rooms and stones block it. Fair because chase (4.3 m/s) is under her run and he cannot cross the gulfs.

## Ports
Catches: the pilot from the plane or on foot from the temple gate (the spine's west door), at isle 1. Throws out: the plane from the lawn or the crown's run; the pocket-sail glide from each isle edge down to the one below (a 14 m drop, a sail's ratio covers 20+ m, so back to the last rope).

## Kit used
Existing ids: `city_terrace`, `city_wedge`, `city_wrap`, `city_lip`, `city_pit`, `city_stair`, `city_causeway`, `city_hush`, `city_slotwall`, `maker_cresset`, `ol_beacon`, `maker_felled` (as the isle-2 bridge across a trench); ruin kit `stairs`, `grand_stair`, `stone_circle`, rope bridges (`scripts/rope_bridge.gd`), floating/bob stones, `bridge_anchor`, `KitLand.island`.
Ruin-style city pieces (shape and lanes kept, rune grooves and frets removed, ruin stone with moss and roots): terrace, wedge, wrap, lip, stair, causeway.

## Kit asks
- Ruin-style variants of the six city climb pieces plus `city_stair`, `city_causeway`, `ol_beacon`: a `runes=false` / `ruined` opt in `CityStone` (same hulls, same meta).
- A `relentless` off switch at a line (a trigger volume or per-isle knob), so his knowledge of her position ends at the temple gate.
- Travel's cliff choice biased to the last place he saw her or the nearest beacon, so "the wrong cliff" is a lure the pilot can set.
- A two-sided `portal` marker on a rope bridge (for his route planner not to read it; likely `WalkerOnly` already).

## Family knobs
- `isles` (3 to 5): how many of the five stand; the crown always.
- `gulf` (22 to 40 m): the gaps' widths, always over his leap.
- `lift` (10 to 16 m): the rise per isle, always under his climb.
- `beacon` (on/off): the lure on isle 3.

## Sockets
Rims: isle 1's east (to the temple's west gate), the lawn's south (plane approach), the crown's west. Arena: the lawn (A). Cover: the undercroft, the wedge hollow, the wrap's cell, the shrine. Perch: the beacon, the crown's cornice.

## Fit
Role: a chain beyond the hero; footprint about 300 x 120 m, 70 m of height. Cost: high.

## Distinct from
The Sundered gorge is two halves a rope bridge apart with no threat; this is five islands in a rising line with a hunter whose walking and climbing set a clock. The colonnade spine itself is one ridge; this goes past its end.

Layout: x east, z south, y over TOP; the temple podium at x 0, the Reaches go west.
```json
{
  "isles": [
    {"id":"0","name":"temple podium","x":10,"z":0,"rx":30,"rz":12,"top":18,"keel":-10,"set_piece":"cella"},
    {"id":"1","name":"Gatehouse shelf","x":-40,"z":10,"rx":16,"rz":14,"top":30,"keel":-8,"set_piece":"city_terrace"},
    {"id":"2","name":"Cistern lawn","x":-110,"z":-10,"rx":28,"rz":15,"top":44,"keel":-10,"set_piece":"city_wedge"},
    {"id":"3","name":"Sluice stair","x":-170,"z":20,"rx":22,"rz":18,"top":58,"keel":-10,"set_piece":"city_stair + ol_beacon"},
    {"id":"4","name":"Wrapped crag","x":-225,"z":-10,"rx":18,"rz":16,"top":72,"keel":-12,"set_piece":"city_wrap"},
    {"id":"5","name":"Crown","x":-285,"z":10,"rx":20,"rz":18,"top":86,"keel":-10,"set_piece":"city_lip + shrine"}
  ],
  "links": [
    {"from":"0","to":"1","kind":"rope"},
    {"from":"0","to":"1","kind":"span"},
    {"from":"1","to":"2","kind":"rope"},
    {"from":"1","to":"2","kind":"stones"},
    {"from":"2","to":"3","kind":"rope"},
    {"from":"2","to":"3","kind":"span"},
    {"from":"3","to":"4","kind":"rope"},
    {"from":"4","to":"5","kind":"rope"},
    {"from":"4","to":"5","kind":"climb"}
  ],
  "pilot": [[-5,18,0],[-40,30,10],[-85,38,0],[-110,44,-10],[-150,52,10],[-170,58,20],[-225,72,-10],[-285,86,10]],
  "threat": [[10,18,0],[-20,18,20],[-45,30,18],[-80,34,30],[-120,44,-4],[-165,58,30],[-215,72,-4],[-270,86,18]],
  "tips": [[-40,30,10],[-125,44,-10],[-225,72,-10]],
  "landing": [-95,-6,-125,6],
  "end": [-290,86,14],
  "moments": [
    {"at":[-5,18,0],"label":"The head goes on","note":"The roar behind her; the Reaches climb away west, ropes slung between islands."},
    {"at":[-40,25,10],"label":"Under the deck","note":"She drops into the terrace undercroft; his steps cross overhead, he seeks 12 s and goes back."},
    {"at":[-110,44,-10],"label":"The open lawn","note":"56 m of bare turf under his 45 m sight; the wedge hollow is the only cover and it tips when he hauls on."},
    {"at":[-170,58,20],"label":"The beacon","note":"She lights the cresset; his eyes go to the light and the stair while she crosses the rope at the other end."},
    {"at":[-225,66,-10],"label":"The wrong cliff","note":"Waiting in the wrap's cell she hears the rumble of his climb up the far face, then drops and crosses."},
    {"at":[-290,86,14],"label":"The shrine door","note":"Only she fits; he stands outside and the chase ends, or she runs the 16 m turf to the plane."}
  ],
  "notes": [
    {"at":[-40,26,10],"text":"safe: undercroft"},
    {"at":[-70,38,-5],"text":"gap 30 m, rope"},
    {"at":[-125,40,-10],"text":"safe: wedge hollow"},
    {"at":[-225,66,-10],"text":"safe: wrap cell"},
    {"at":[-195,65,0],"text":"gap 34 m, 2 ropes"},
    {"at":[-250,60,10],"text":"his cliff, 14 m"}
  ]
}
```
