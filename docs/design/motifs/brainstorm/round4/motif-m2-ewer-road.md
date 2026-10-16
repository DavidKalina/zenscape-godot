# The Ewer Road
Lenses: verb carry; scale intimate; mood quiet; shape among isles a line; world sky.

Pitch: A dry cistern on the far isle of a line of five small isles is waiting for water, and the only vessel is a stone ewer the pilot fills at the spring by the plane and carries on his head. Every hard move spills it, so the road is a walk taken slowly: the plain jump, the stepping stones, a swaying rope bridge, and a horn that gusts across the last court.

Place: Five small isles strung east in a line, each a short walk across, the gaps between them a plain jump or one bridge wide. The plane sits on the west isle's long turf beside a spring; from there the whole road is in view as a row of little lit lawns stepping up a few metres to the dry cistern on the last one.

Top (1 char = 4 m):
```
 x:0              40       60        84        108
                  2        3         4         5
   1111111        ##       ~~~~      ^^^^      ##""
  11@~~~~11   ....#o.#...~~~~~~~...#oC.#....A  @##
   1111111  ..    ##  .  rope   . ##P  ##.   cistern
   (spring, strip) stones         horn court
```
Side (rise in pilot terms, one stairs flight per isle):
```
 y +4.5                                          5____
 y +3                                  4____    /
 y +1.5                      3____    /
 y  0.3          2____      /
 y  0   1_______/
        spring
```

Play: He fills the ewer at the spring and sets off with it held on his head: he walks and plain-jumps as ever, but a run, a long jump, a slam, a wall kick or a ledge grab would spill it, so he takes steps, ramps and stones at a walk and sets the ewer down on a lip before a climb, hops up, and lifts it after. The rope bridge sways under him and the walk across has to be steered to its beat; the last court has a wind horn that gusts him. He pours it into the cistern and the cistern gives back a small curtain of water over the rim, a quiet payoff for a slow errand.

Set pieces:
- The spring: a worn stone ring on the landing isle; stand at it and the ewer fills over about a second, the fill showing as a level in the jar.
- The stepping stones (isle 2 to 3): four floating stones, two plain jumps wide each; he carries the ewer across at a walk pace, the bob of each stone shaking a little water.
- The swaying rope bridge (3 to 4): a live rope bridge a pilot can cross at a walk without spilling if he steps to its rhythm; run on it and the water slops over the lip.
- The horn court (4): a wind_horn on a pier-backed dais; he waits behind a pier, crosses between gusts, and a gust that lands makes him drop the ewer, which rolls to a stop a few steps off with half its water gone.
- The dry cistern (5): the stone_circle basin; pouring in it starts a trickle that falls off the rim in a thin curtain and wakes the isle's garden.

Threat: The wind_horn (scripts/ruin_kit_horn.gd, wind blaster `knock` source) on isle 4: it notices him, draws breath (a tell) and gusts along the court. It never kills; its cost is spilled water and a trip back to the spring (or the drip basin) to fill again.

Ports: Catches the plane on isle 1's turf (landing) and the walker from the plane; throws out nothing but a single curtain of water off the last isle, a dressing the plane can fly through. No rim out needed.

Kit used: stone_circle (spring ring, cistern), floor, pier (cover), stairs (a flight per isle, RuinKit.STAIRS rise RISER 0.28, TREAD 0.5), wall (low rim wall), aqueduct_stump (drip basin on isle 3), aqueduct_broken (dry runnel beside the cistern), wind_horn (horn family), rope bridge (scripts/rope_bridge.gd), floating/bob stones, arch (the court's gate, TOY_ARCH_SPAN).

Kit asks:
- carried_ewer (new family carry, from round2): a held-item rider on the pilot, with a fill level that falls with hard moves and rises at a spring; hands-full rules (run capped near `walk`, no long jump, slam, wall kick or ledge grab; plain jump and twirl allowed; stun drops it).
- spring_well (family carry): a fill point, a ring of stone with a bright water face, that tops up an ewer in about a second.
- dry_cistern (family carry): a receiving basin that takes poured water, fills visibly and spills a curtain off its rim.

Family knobs:
- road_length: 4 to 6 isles (isle 3 and 4 repeat), default 5.
- spill: how fast a hard move empties the ewer, from forgiving to strict.
- horn: 0 to 2 horns, the second on the last isle's far rim.
- rise: total climb from 3 m to 6 m, split over the stairs.

Sockets: rim in on isle 1's west edge (the landing turf), rim out off the cistern's east edge; arena on the horn court (isle 4's dais); cover the court's piers; perch the cistern's rim wall.

Fit: role stretch (a connecting line of small isles), footprint about 110 by 24 m, height span about 5 m.

Distinct from: haulway (underground, hauling a sledge along a track) and the round2 carry kit cards, which are pieces, not a place; this is the one place where the pilot himself carries a small thing along a gentle line, and the road is paced by what spills. The sky greyboxes (wardens_well, noon_weir) are relays and timing, not a slow errand.

Layout:
```json
{
  "isles": [
    {"id": "1", "name": "spring", "x": 0, "z": 0, "rx": 24, "rz": 14, "top": 0, "keel": -10, "set_piece": "spring ring + landing strip"},
    {"id": "2", "name": "stones", "x": 40, "z": 2, "rx": 6, "rz": 6, "top": 0.3, "keel": -5, "set_piece": "floating stones"},
    {"id": "3", "name": "rope", "x": 60, "z": -1, "rx": 6, "rz": 6, "top": 1.5, "keel": -6, "set_piece": "drip basin"},
    {"id": "4", "name": "horn court", "x": 84, "z": 0, "rx": 9, "rz": 8, "top": 3, "keel": -8, "set_piece": "wind_horn"},
    {"id": "5", "name": "cistern", "x": 106, "z": 0, "rx": 10, "rz": 9, "top": 4.5, "keel": -9, "set_piece": "dry cistern"}
  ],
  "links": [
    {"from": "1", "to": "2", "kind": "stones"},
    {"from": "2", "to": "3", "kind": "stones"},
    {"from": "3", "to": "4", "kind": "rope"},
    {"from": "4", "to": "5", "kind": "stair"}
  ],
  "pilot": [[-10, 0, 0], [0, 0, 0], [12, 0, 0], [34, 0.3, 2], [46, 0.3, 2], [56, 1.5, -1], [68, 1.5, -1], [78, 3, 0], [90, 3, 0], [100, 4.5, 0], [106, 4.5, 0]],
  "threat": [[84, 3, 6], [84, 3, 0], [90, 3, 0]],
  "tips": [[84, 3, 6]],
  "landing": [-22, -5, 10, 5],
  "end": [106, 4.5, 0],
  "moments": [
    {"at": [0, 0, 0], "label": "The jar fills", "note": "He stands at the spring and the ewer fills; he lifts it to his head and the plane is behind him."},
    {"at": [44, 0.3, 2], "label": "Stones at a walk", "note": "Four floating stones, each a plain jump apart; a run or a long jump would spill it, so he hops them one at a time."},
    {"at": [66, 1.5, -1], "label": "The sway", "note": "A live rope bridge: he steps to its rhythm and the jar stays full; a run slops it over the lip."},
    {"at": [84, 3, 0], "label": "The horn breathes", "note": "He waits behind a pier for the tell, crosses between gusts; a hit drops the ewer half empty."},
    {"at": [106, 4.5, 0], "label": "The cistern drinks", "note": "He pours and a trickle becomes a thin curtain of water off the rim."}
  ],
  "notes": [
    {"at": [0, 0, 8], "text": "plane strip, turf, about 32 m long"},
    {"at": [50, 0.3, 2], "text": "stone gaps: 2 plain jumps"},
    {"at": [60, 1.5, 6], "text": "drip basin: top up half a jar"},
    {"at": [84, 3, -7], "text": "pier cover"}
  ]
}
```
