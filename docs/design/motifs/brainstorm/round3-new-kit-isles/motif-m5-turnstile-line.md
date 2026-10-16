# The Turnstile Line
Lenses: verb time a crossing; scale human; mood playful; shape a line (three isles in a row, each higher or lower than the last).

Pitch: Three small isles in a row, west to east, and each hop to the next is a clock. A prayer-rope swing is paced by a pendulum, and a hung stair is walkable for only 12 s after you slam its boss. Do the line in one run and the pilot ends the lap with a stolen chest and a plane waiting.

Place: A long thin string of ruin-green isles, strung along the plane's flight line. On arrival from the west you see the Meadow (a flat turf strip with a broken stone ring standing on its north edge, a prayer gate at its east lip) and, beyond a 32 m gap, the Hood Court a little higher, its south wall roofed by a lean-to hood. Past it a lower, smaller rest isle with a bench. Fly the line east and you thread the broken ring, then the gate, then drop to the rest isle's far side.

Top (ASCII, ~40x16, 1 char ≈ 4 m; west left; the line runs east):
```
 x: 0        10        20        30        40
    ..................................
    .  O                         ^^^^^
    . 11111111111~~~~~~~22222222222~~~~3333
    . 1PPPPPPPPP=TTTTT==2222B2C22222~~~~3@33
    . 1111111111~~~~~~~~22222hhhh22~~~~~333
    .                                
```
O = relic_nimbus ring (north edge of the Meadow), T = relic_torana lintel running out from the Meadow's east lip, B = the hung stair's boss in the Court's turf, h = pent_hood on the Court's south wall, C = the chest vault (underneath, in the keel), P = landing strip, 3 = the Rest.
Side (west to east, heights in m above the Meadow turf):
```
        horn 17 O                          ____
         /\  /\                           |    |
   0 ====1====TT\_____                8 ===2==B=hhh======  (gallery below, 5.8)
   Meadow    lintel \_ ropes     rise  \_ shaft __ chest vault
                                                  3 -6  Rest
```

Play: You land on the Meadow's strip, walk to the prayer gate and take the ropes: a pendulum's own rhythm sets how fast you can go, a mistimed release overshoots and you twirl back. The lintel's top walks you onto the Court, where the hood's roof is a slide that funnels you straight at the boss: slam it and a 12 s clock starts that sends you down a dark stair to a vault and back. Nothing here hunts you; the line itself is the tension, and the feeling is a small, quick game of beat the bell.

Set pieces:
- relic_torana (Meadow's east lip): five prayer ropes under a lintel that tilts up eight metres to the Court's rim; each release is timed against the swing, the last lands you on the lintel's top.
- relic_nimbus (Meadow's north edge): the broken ring and its climb up the inner left wall, spoke and outer brackets to the low horn, then a twirled leap to the high horn at 17 m; the shortcut is a sail from the high horn across the gulf to the Court, skipping the ropes. The plane can fly through the ring (11.4 m clear).
- pent_hood (Court's south wall): climb the wall, drop onto the roof's high edge and surf its 20 deg pitch down to the eaves, then slam the boss 3 m below. Its dark gallery under the eaves is a place to catch your breath.
- keel_hung_stair (Court, boss mid-turf, flight in a shaft): a slam on the boss turns the hung stair into a walkable flight for 12 s; at its foot a gallery 26 m long under the Court ends at a tomb_chest vault; run in, grab, run back before the flight swings home.

Threat: only the stair's own throw (stood on it past 70 deg you are tossed off the Court into the gulf) and the gap. Miss the 12 s and the hung flight is a 50 deg slide that surfs you out of the keel into open air toward the Rest, so a miss costs the chest, not your life. A rope that snaps dry (the torana's `weathered` rope) sets a gap in the chain.

Ports: catches the plane along its flight line from the west (the ring on its north edge, the gate over the lip); the Rest's far end throws the pilot out east to whatever isle is next on the chain.

Kit used: `relic_torana`, `relic_nimbus`, `pent_hood`, `keel_hung_stair` (new pieces); `wall`, `stairs`, `floor`, `turret`, `fallen_pier`, `tomb_chest`, `lancet_wall`, `buttress` (RuinKit gothic); `rope_bridge` (scripts/rope_bridge.gd, the Rest's way home).

Kit asks: none (a perch the Court's slam can fall from is the hood itself; if relic_torana lands with fewer than five ropes, the card scales to 3).

Family knobs: `ropes` (3-5: the swing chain's length), `hold` (6-18 s: the stair's clock; 12 default), `vault` (the gallery's length, 12-30 m, so the run is tight at any hold), `lift` (4-12 m: how much higher the Court is than the Meadow, the lintel's tilt).

Sockets: rim (Meadow's east lip facing east to the gate; Court's west lip facing west; Rest's north edge facing the Court's keel), arena (the Court's turf round the boss), cover (the hood's gallery, the vault), perch (the nimbus's horns, the hood's roof).

Fit: role hero/line; footprint about 170 x 40 m (three isles end to end); height span about 25 m (nimbus 17 m above the Meadow, Court +8, Rest -6).

Distinct from: `bell_spires` (rope bridges and a bell, no timed crossings), `hollow_keel` (a hung hall to fly through, no clock) and `sundered_gorge` (two halves, bridges). This is a string where each step is a timed piece, not a climb or a hall.

Layout: the rough map (x east, z south, y up, metres from the Meadow turf = 0).
```json
{
  "isles": [
    {"id":"1","name":"Meadow","x":-50,"z":0,"rx":34,"rz":16,"top":0,"keel":-10,"set_piece":"relic_nimbus + torana gate"},
    {"id":"2","name":"Hood Court","x":38,"z":0,"rx":26,"rz":14,"top":8,"keel":-6,"set_piece":"pent_hood + keel_hung_stair"},
    {"id":"3","name":"The Rest","x":88,"z":0,"rx":14,"rz":10,"top":-6,"keel":-14,"set_piece":"bench and rope bridge home"}
  ],
  "links": [
    {"from":"1","to":"2","kind":"rope"},
    {"from":"2","to":"3","kind":"stair"},
    {"from":"3","to":"2","kind":"rope"}
  ],
  "pilot": [[-70,0,0],[-24,0,2],[-6,5,2],[14,8,2],[34,8,6],[34,8,2],[38,6,0],[62,6,0],[38,6,0],[34,8,2],[62,8,0],[84,-6,0]],
  "threat": [[34,8,-3],[26,8,0],[16,4,0]],
  "tips": [[84,-6,0]],
  "landing": [-76,-4,-34,4],
  "end": [88,-6,0],
  "moments": [
    {"at":[-8,3,2],"label":"The first rope","note":"You swing off the prayer gate's lip and release rising to catch the next knot, the pendulum's own beat telling you when."},
    {"at":[-40,17,-14],"label":"The ring's horn","note":"A twirled leap to the nimbus's high horn: the whole line lies at your feet, and a sail across skips the ropes."},
    {"at":[34,8,6],"label":"Hood slide","note":"You drop onto the hood's roof and surf its pitch down the eaves to the boss 3 m below."},
    {"at":[34,8,0],"label":"Slam, then 12 s","note":"A slam turns the hung stair; the bell of its grit tells you the clock is running."},
    {"at":[62,6,0],"label":"The vault","note":"You grab the tomb chest at the gallery's end and run the 26 m back, up the flight as it begins to swing."},
    {"at":[88,-6,0],"label":"Surfed out","note":"Miss the clock and the hung flight tosses you out of the keel to sail down to the Rest."}
  ],
  "notes": [
    {"at":[0,6,0],"text":"gulf 32 m, lintel rises 8 m"},
    {"at":[-40,9,-10],"text":"ring 11.4 m clear: the plane fits"},
    {"at":[50,6,0],"text":"gallery 26 m, round trip 52 m"},
    {"at":[34,12,4],"text":"hood roof 3 m over the boss"}
  ]
}
```
