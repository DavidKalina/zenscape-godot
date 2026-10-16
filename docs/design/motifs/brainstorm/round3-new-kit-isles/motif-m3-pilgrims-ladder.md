# The Pilgrim's Ladder
Lenses: climb; a tall stack (isles over isles); colossal, sacred.
Pitch: Three isles hang one over the next like the stages of a pilgrimage, and each stage is climbed with one of the new relics: a rope lintel up to the second isle, a broken stone halo up to the third, and at the top a hung stair that opens only to a slam. The way back is the same stair, hung again, which throws you off the crown and down the whole stack.

Place: A tall, narrow stack in a column of cloud. The base isle ("Threshold", top y 0) is the broad landing lawn with a pilgrims' hostel (a pent hood gallery) on its east side and a lone colossal jamb on its lip. Over it and east, the second isle ("Halo Terrace", top y +12) holds a second hood and a standing stone halo 17 m tall. The third ("Lantern Crown", top y +27) overhangs the halo's east side. On arrival the player sees the three stages in profile and the halo framing the sky between them.

Top (ASCII, ~40x16, 1 char about 4 m; north up):
```
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~~~~~~~~~~~~~~~~ 3333333 ~~~~~
 ~~~~~~~~~~~~~~~~~~~~~~~~  333@C3P33~~~~~
 ~~~~~~~~~~~~~~~~~~~~ 22222. 333333 ~~~~~
 ~~~~~~~~~~~~~~~~~ 2222@2222C2222~~~~~~~
 ~~~~~~~~~~~~~~~ 11111.2222222222 ~~~~~~~
 ~~~~~~~~~~~~ 11111@~~.222oo22222~~~~~~~~
 ~~~~~~~~~~ 1111111C11 ~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~ 11111111111111 ~~~~~~~~~~~~~~~
 ~~~~~~~~~ 111"""""""111 ~~~~~~~~~~~~~~~~
 ~~~~~~~~~~ 111111111 ~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~ 11111 ~~~~~~~~~~~~~~~~~~~~~~
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```
Legend as the brief's; `1` Threshold, `2` Halo Terrace, `3` Lantern Crown, `@` the set pieces (jamb and hood on 1, halo on 2, boss and hood on 3), `o` wind blaster, `"` the clear landing strip.

Side (heights, not to scale in x):
```
 y 29 |                         __ halo's high horn      ____ 3 crown (27)
   27 |                        /  \                     |boss|  hung stair under
   17 |                       (halo)                    keel 19
   12 |                _ 2 terrace ______________/
   10 |   lintel tip ./
    5 |   jamb ___./
    0 | 1 lawn ________________
  -14 |   keel
```

Play: The pilot lands on the lawn, walks to the hostel and the jamb, and swings up the rope lintel (ropes of the Prayer Lintel) to the terrace. There a wind blaster sweeps the terrace and the halo's foot: a sacred ring to climb, ray by ray, spoke and outer bracket to the horn, with the gusts as the pressure. From the high horn the pilot sails over the crown's lip and slams the boss, and the stair turns for a short, holy 12 s. Stand on it past its tilt and it throws you; go down it into the reliquary shaft and the shrine; come back by the turned stair, or let it hang you over the sky.

Set pieces:
- `relic_torana` at Threshold's east lip: the jamb (niches are the slow way) and a tilted lintel over the gulf; ropes under it chain up to the terrace's lip; a dry rope (weathered) makes you twirl to the next. A wind gust (`wind`) crosses the gulf: a stunned body is snagged by a rope.
- `relic_nimbus` at the terrace's west half: the pilot climbs inner stubs, the spoke, the outer brackets, the low horn, the twirled leap to the high horn (17.1 m over the terrace). The plane fits through the ring (11.4 m clear) on its approach to the terrace.
- `keel_hung_stair` on the crown's west lip: boss on the turf, the flight hung down and out over the gulf (a 50 degree soffit that surfs you off) until a slam from the high horn (2.1 m over the boss turf, a sail and a slam) turns it; turned it lies in a shaft under the turf (12 s), into the reliquary chamber.
- `pent_hood` x2: Threshold's hostel (the covered gallery is cover from the wind and its roof is a step up to the jamb's lowest niche) and the crown's shrine arcade (hides the reliquary hatch).

Threat: `wind` blaster pulses (scripts/traps) on the terrace between the halo and the lintel's landing, and the hung stair's own throw: stand on it past its knock angle and it knocks you. Fair: the blaster has a telegraph, the hood and halo give lee, and the stair's turn is slow (1.2 s turn, 0.5 s tell).

Ports: catches the plane's approach from the west (the lawn is the landing) and any sail from outside onto the crown. Throws out: the hung stair surfs you off the crown's keel (south, 50 degree soffit) for a pocket sail back to the lawn, 27 m down.

Kit used: relic_torana, relic_nimbus, keel_hung_stair, pent_hood (the new four); floor, stairs, pier, wall, lancet_wall, arch, rose_gable, tomb_chest, buttress (gothic); KitLand.island for the three isles.
Kit asks: none.
Family knobs: `stages` (2 to 3: crown dropped at 2, the nimbus's high horn then the summit); `rise` (stage gap, 11 to 14 m); `ropes` (3 to 5 on the lintel); `weathered` (0.2 to 0.9: ropes dry, stubs shorter).
Sockets: rim (Threshold's west edge, facing the plane's approach); arena (the terrace, the crown's turf); cover (the two hoods, the halo's foot); perch (the halo's horns, the lintel's top).
Fit: role hero; footprint about 110 x 70 m; height span 27 m plus keels (-14 to +29).
Distinct from: stair_clouds (one mesa, a grand stair in flights): this is separate isles climbed by distinct verbs, with the halo as a 17 m climb face; from broken_ring (8 islets in a spiral): three large stages each ending in a landmark; from hollow_keel (a hall under a plate): a small shaft stair, not a hall.

Layout: frame is the column; Threshold at the origin.
```json
{
  "isles": [
    {"id":"1","name":"Threshold","x":0,"z":0,"rx":34,"rz":24,"top":0,"keel":-14,"set_piece":"torana + pent_hood"},
    {"id":"2","name":"Halo Terrace","x":62,"z":-12,"rx":22,"rz":15,"top":12,"keel":0,"set_piece":"relic_nimbus + pent_hood"},
    {"id":"3","name":"Lantern Crown","x":88,"z":-30,"rx":17,"rz":12,"top":27,"keel":19,"set_piece":"keel_hung_stair"}
  ],
  "links": [
    {"from":"1","to":"2","kind":"rope"},
    {"from":"2","to":"3","kind":"climb"}
  ],
  "pilot": [[-26,0,10],[10,0,4],[28,0,-4],[40,10,-8],[48,12,-12],[54,12,-12],[56,29,-12],[80,27,-26],[86,27,-30]],
  "threat": [[60,12,-4],[66,12,-12],[72,12,-18]],
  "landing": [-30,6,-4,10],
  "end": [86,27,-30],
  "moments": [
    {"at":[28,5,-4],"label":"The prayer ropes","note":"You step off the jamb's niches and swing rope to rope up the tilted lintel over the gulf."},
    {"at":[50,12,-12],"label":"The halo","note":"A stone ring 17 m tall; the blaster gusts across the foot while you climb the stubs, the spoke, the outer brackets."},
    {"at":[56,29,-12],"label":"The twirl to the high horn","note":"At the top of the halo, a twirl from horn to horn, with the crown opening beyond."},
    {"at":[84,27,-30],"label":"The slam","note":"You sail off the horn and slam the boss: the stair turns and the shaft opens for 12 s."},
    {"at":[86,19,-26],"label":"The surf","note":"Back out, the stair hangs again and surfs you off the keel into the sky, a pocket sail down to the lawn."}
  ],
  "notes": [
    {"at":[-17,0,8],"text":"landing strip, 26 m of clear turf"},
    {"at":[35,6,-4],"text":"gulf under the lintel"},
    {"at":[66,12,-12],"text":"blaster"},
    {"at":[84,23,-26],"text":"2.1 m of air for the slam"}
  ]
}
```
