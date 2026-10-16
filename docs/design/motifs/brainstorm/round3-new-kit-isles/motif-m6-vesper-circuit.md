# The Vesper Circuit
Lenses: verb RIDE (the plane as much as the pilot), shape A RING, scale A FRAGMENT OF SOMETHING BIGGER, mood QUIET
Pitch: Four isles are the surviving arcs of a colossal processional ring road, and the gates of the road still stand: a broken nimbus the plane flies through, a prayer lintel it flies under. The pilot on foot rides the same circuit in his own way (roof slide, rope swing, soffit surf, sail), and his climb crosses the plane's line twice, once inside the nimbus and once under the lintel.

Place: The ring road is about 130 m across and three quarters gone: from the parked plane on the west lawn you see the other three isles hung round a quiet gulf, each carrying one gate-fragment of a thing too large to be seen whole. No threat: the wind, a bell on the last rope, and the plane's own long loop. Seen on arrival: a low lawn with a pent hood along its north edge, and across the gulf a grey ring standing on its foot, with the lintel of another gate beyond it, tilted up into the light.

Isles (clockwise from the west; tops over the lawn of isle 1):

| Isle | Where (x east, z south) | Top | Set pieces |
|---|---|---|---|
| 1 Hood Lawn | (-64, 10), 68 x 48 m | 0 | pent_hood, landing lawn |
| 2 Nimbus Isle | (-8, -62), 64 x 44 m, deep overhanging keel | +10 | relic_nimbus, keel_hung_stair, undercroft |
| 3 Lintel Isle | (64, -8), 56 x 44 m | +20 | relic_torana |
| 4 Vesper Court | (6, 64), 52 x 36 m | +4 | second lawn, hall_bay, the quiet end |

Top (north up; 1 char about 5 m; digits isles, H the hood, O the nimbus, T the torana, S the hung stair, '.' the pilot's way, '=' the plane's loop, '~' gulf):
```
 0123456789012345678901234567890123456789
 0
 1             ~  222222222  ~
 2        ~    2222"O="2222S2    ~
 3     ~.~   .=...22222..=222    ~    ~
 4   1111111~.      ~~~.  ~~   . 333333
 5  111"HH1111.            ~    . 3"3T3 33
 6  11111111111              ~    3333333
 7  1111@11111  ~   ~   ~   ~     333@33
 8   111111~                  ~   ~3333
 9    ~~      ~    ~       ~  ~  ~
10         ~     .~~~~444444~~~
11              ~   44@4444"4~
12                  4444444
```
(the plane enters from isle 1 and circles clockwise: it passes through O, then under T; the pilot's way crosses it at both.)

Side (the circuit unrolled, heights over isle 1's lawn):
```
                                   .ring.        lintel top +30
                                 /  O  \ horn +27   ____/
           hood        rope    __|__   _|___   stones  | T gate
 lawn 0 ___H___|_|___ bridge __| isle 2 |+10 undercroft   __ isle 3 +20
                                  \keel/ ====>S shaft        sail home
                                                              isle 4 +4
```

Play: You start in the hood and ride your way round: slide the pent roof to the lawn or take the wall walk to the rope bridge, climb the broken nimbus in the plane's shadow, leap to the high horn and slam down onto the stair's boss, then run the turned stair into the undercroft before it folds. At the far isle you swing up the torana's ropes while the plane's loop passes under your boots, and sail home from the lintel's top. A second pilot's way is the plane's: thread the ring and the gate with nothing hanging on the stick. It is a circuit to be ridden twice, once on foot and once in the air, and both are quiet.

Set pieces:
- relic_nimbus (isle 2): the plane flies through the ring (clear 11.4 m across, over WorldScale.opening(TOY_THREAD) 7.0) while the pilot climbs it: inner rays up the left wall, the spoke round the front, outer brackets, the low horn, then a twirled leap to the high horn (17.1 m over its foot, 1.6 m above the low horn).
- keel_hung_stair (isle 2): boss on the turf 6 m in front of the ring; hung, its soffit is a 50 degree slide off the lip. A flow-charge slam from the high horn (about 17 m of air) turns it (0.5 s tell, 1.2 s turn); it lies under the turf 12 s as a stair into the keel, then folds.
- relic_torana (isle 3): rope 1 hangs over the turf for a run-in; the tilted lintel carries 4 ropes (`weathered` makes one snap) up to its top. Under it the plane threads the gate, an opening of WorldScale.opening(RuinKit.TOY_THREAD).
- pent_hood (isle 1): two bays (10.4 m) along the lawn's north edge, the gallery is the start and the first lesson in covered travel; the 20 degree roof is a slow slide, the back wall (4.93 m) is the way to the rope bridge head.

Threat: none. The only pressure is the stair's 12 s, a tell the pilot sees before it ever matters, and a snapped rope. Knocks happen only if he stands on the turning flight past 70 degrees (the stair's own throw).

Ports: Catches the plane from anywhere in the sky (two landing lawns) and the pilot's sail from outside. Throws out the bell on the last rope (the cue that the circuit is complete) and the stair's grind.

Kit used: pent_hood (cloister), relic_nimbus (relic), relic_torana (relic, in the build), keel_hung_stair (keel), hall_bay (hall), wall, stairs, buttress (gothic, the slam perch's step-offs), aqueduct_broken (isle 4 to 1 span), stone_circle (isle 4 dressing); rope_bridge.gd, floating stones, KitLand.island, swing ropes (the torana's own).

Kit asks: A rope bridge head that mounts on the pent_hood's back wall (a bridge_anchor on its `top` connector) so the hood's wall walk is the bridge's start.

Family knobs:
- `ropes`: 3 to 5 (the torana's chain; 4 authored).
- `hold`: 8 to 16 s (the stair's turned time; 12 authored; at 8 the undercroft is tight).
- `weathered`: 0.2 to 0.8 (hood gaps, a dry rope, ring wear).
- `loop`: clockwise or anticlockwise (which gate is met first).

Sockets: rim: isle 1's east lip (bridge head, facing east) and isle 3's west lip (facing the gulf); arena: isle 1's lawn; cover: the hood gallery and the undercroft; perches: the nimbus high horn, the lintel's top, the hood's wall walk.

Fit: role hero (a big quiet loop); footprint about 190 x 180 m (isles over a 130 m ring); height span about 30 m over the lawn plus 22 m of keel below isle 2.

Distinct from: broken_ring (an islet spiral, no gates, no loop to fly) and hollow_keel (the keel hall is a fly-through; here the undercroft is a pilot's twelve-second prize and the gates are what the plane threads); also m6 of round 1, which was a chase, not a ride.

Layout:
```json
{
  "isles": [
    {"id": "1", "name": "Hood Lawn", "x": -64, "z": 10, "rx": 34, "rz": 24, "top": 0, "keel": -14, "set_piece": "pent_hood, landing"},
    {"id": "2", "name": "Nimbus Isle", "x": -8, "z": -62, "rx": 32, "rz": 22, "top": 10, "keel": -22, "set_piece": "relic_nimbus, hung stair"},
    {"id": "3", "name": "Lintel Isle", "x": 64, "z": -8, "rx": 28, "rz": 22, "top": 20, "keel": -14, "set_piece": "relic_torana"},
    {"id": "4", "name": "Vesper Court", "x": 6, "z": 64, "rx": 26, "rz": 18, "top": 4, "keel": -16, "set_piece": "second lawn"}
  ],
  "links": [
    {"from": "1", "to": "2", "kind": "rope"},
    {"from": "2", "to": "3", "kind": "stones"},
    {"from": "3", "to": "4", "kind": "climb"},
    {"from": "4", "to": "1", "kind": "span"}
  ],
  "pilot": [[-74, 0, 16], [-52, 5, -6], [-30, 10, -48], [-10, 18, -66], [-10, 27, -66], [-4, 10, -56], [4, -2, -50], [30, 2, -40], [50, 12, -20], [56, 20, -14], [38, 30, -10], [6, 4, 60]],
  "threat": [],
  "tips": [],
  "landing": [-84, 6, -40, 14],
  "end": [6, 4, 60],
  "moments": [
    {"at": [-70, 0, 18], "label": "The hood", "note": "start under the pent roof, quiet; slide its 20 degree roof or take the wall walk to the rope bridge"},
    {"at": [-10, 18, -66], "label": "Through the ring", "note": "the plane threads the broken nimbus while the pilot climbs its inner rays and spoke"},
    {"at": [-10, 27, -66], "label": "The slam", "note": "twirl to the high horn, charge down 17 m onto the boss; the hung soffit turns into a stair"},
    {"at": [4, -2, -50], "label": "Twelve seconds", "note": "run the turned stair into the undercroft before it folds, out to stones toward the lintel isle"},
    {"at": [40, 24, -10], "label": "Under the lintel", "note": "swing up the torana's ropes as the plane threads the gate beneath your boots"},
    {"at": [30, 30, -10], "label": "Sail home", "note": "from the lintel's top glide to the court; the last rope's bell rings"}
  ],
  "notes": [
    {"at": [-10, 18, -66], "text": "plane: ring 11.4 m clear"},
    {"at": [40, 24, -14], "text": "plane: gate 7.0 m opening"},
    {"at": [-64, 4, 10], "text": "landing lawn 44 m"},
    {"at": [0, 6, -56], "text": "perch 17 m above boss"},
    {"at": [6, 8, 64], "text": "second lawn"}
  ]
}
```
