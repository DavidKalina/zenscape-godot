# The Wick (vigil of the great censer)
Lenses: Verb defend; Mood sacred; Scale colossal; World sky.
Pitch: A censer the size of a chapel hangs from a hall column over a ring of stone, and its flame draws every Olmec in the sky toward it along three aqueducts. The pilot has no weapon, so he keeps the vigil by turning the place against them: a bell to call the flame back up, horns to blow bodies off the spans, and a slam to drop a span under them.
Place: One broad turf isle (the Apron) carries the landing strip, then a stone terrace rises to the Altar, a ring of four colossus columns (hall_column) with architrave beams (hall_beam) and a great bowl slung under the beams, burning. Three aqueducts (aqueduct_span, one broken, one two_tier) reach in from lone outer isles; the sky behind them is lit from the bowl. On arrival you see the bowl's glow from the strip and the three spans, each with a small dark figure walking.

```
Top (1 char ~ 4 m)
 N
                     3
                  ##### 
        ..........| A |.........  4
   P   .          | @ |        .#####
  ###  .   ###    |   |   ###  .
 1 ####....#C##....|. .|...##C#.....
 ====>>>   ###    '"""'   ###
 landing   (terrace)   o  o
          2  ..........o...........  (west span)
  ~~~                              ~~~
```
Side (west to east; '@' bowl, '|' column, 'H' wind_horn, 'b' bell)
```
                 ====beams====
              |     (  @  )     |        b
   H          |                 |       ##
  ###        ###################### 
 #####  ______terrace_____________   ===== span ===>  isle 3
 ##### /  Apron (landing)         \  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```
Play: Land on the Apron, walk up the terrace and the flame is already burning; bodies come out of the three spans in turn, slow and pulled toward the bowl. The pilot gets each of them off the span before it reaches the terrace: lure one onto a horn's line and let it gust it off, slam the broken span's loose voussoir so the whole run goes, or wall-kick up a column and flow-charge down onto the one that got through. A body that stands at the bowl for its dwell lowers the flame a notch; ring the bell and the flame climbs back. The feeling is of keeping a very large, very old thing lit.
Set pieces:
- The bowl: lit height shown by the flame; each body that reaches it for its dwell drops it a notch. At three notches it goes out and the vigil ends (the Altar goes dark, bodies drift away, you may relight it from the bell).
- The bell on a high perch (cloister side): ringing it lifts the flame one notch and every body on the spans looks up and stops for a count.
- The broken span: a loose voussoir at its mid arch; slammed (down-charge) it drops the span's far half with whatever is on it.
- Two wind_horns on the terrace rim, aimed along two spans: blow a body that stands in their line off the edge.
Threat: Headless bodies (scripts/enemies/headless_body.gd) walking the spans by the Beacon's draw (scripts/enemies/beacon.gd: the bowl is the Beacon; its `dwell` and `gather` do the tiring), a whole Olmec on the third wave. The pilot takes the usual knock if caught (restun_gap 1.2 s, stun_chain_cap 3 s).
Ports: Catches the plane on the Apron; the bowl's glow is the sight line to the outer isles. Throws out: a ridden updraft from the bowl's mouth (flow charge) carries a pilot to the beam walk and over to isle 4.
Kit used: hall_column, hall_beam, hall_slab, hall_bay, aqueduct_span, aqueduct_broken, aqueduct_stump, aqueduct_two_tier, aqueduct_end, wind_horn, buttress, grand_stair, floor, relic_torana (the Apron's gate), pent_hood (the bell perch); belfry bell (scripts/ruin_kit_belfry.gd); Beacon; headless_body.
Kit asks:
- A hung censer bowl piece (hall family) that is the Beacon, dims by notches and takes a relight.
- A switch (pull/ring) that notifies a Beacon, if the belfry bell can't be hooked to one.
Family knobs: number of spans (2-4), notches before the flame goes out (2-4), wave length (1-3 bodies each), whether the third wave is a whole Olmec.
Sockets: rim on the terrace's three span heads (arriving enemies), arena on the ring of columns, cover under the beams and behind the buttresses, perch on the bell tower and the beam walk.
Fit: role: set piece / anchor. Footprint: about 200 pilot-widths across the ring plus three spans, each 20-30 pilot-widths long; height span: about 30 pilot heights from Apron to beam walk and bell.
Distinct from: warden's_well and vigil_bellows (the horns there throw the pilot, here they throw bodies, and the point is holding a place not crossing it); noon_weir and plinth_ram (traps that kill nothing in a loop, not a wave you stage). Not like round 3's pilgrims_ladder (a climb, no hold).
Layout:
```json
{
  "isles": [
    {"id": "1", "name": "Apron", "x": -75, "z": 0, "rx": 38, "rz": 24, "top": 2, "keel": -14, "set_piece": "landing and torana gate"},
    {"id": "2", "name": "Altar", "x": 0, "z": 0, "rx": 36, "rz": 30, "top": 7, "keel": -18, "set_piece": "the great censer"},
    {"id": "3", "name": "North span isle", "x": 10, "z": -95, "rx": 20, "rz": 14, "top": 6, "keel": -10, "set_piece": "gate arch"},
    {"id": "4", "name": "East span isle", "x": 105, "z": 5, "rx": 20, "rz": 16, "top": 9, "keel": -12, "set_piece": "bell tower"},
    {"id": "5", "name": "South span isle", "x": -5, "z": 100, "rx": 18, "rz": 12, "top": 4, "keel": -9, "set_piece": "broken span"}
  ],
  "links": [
    {"from": "3", "to": "2", "kind": "span"},
    {"from": "4", "to": "2", "kind": "span"},
    {"from": "5", "to": "2", "kind": "span"},
    {"from": "1", "to": "2", "kind": "stair"}
  ],
  "pilot": [[-80, 2, 0], [-40, 3, 0], [-20, 7, 0], [0, 7, 10], [30, 7, 5], [60, 8, 0], [100, 12, 5]],
  "threat": [[10, 6, -95], [10, 6, -60], [5, 7, -25], [0, 7, -8], [105, 9, 5], [70, 8, 4], [38, 7, 2], [-5, 4, 100], [-3, 5, 60], [0, 7, 28]],
  "tips": [[0, 24, 0]],
  "landing": [-105, -8, -52, 8],
  "end": [0, 7, 0],
  "moments": [
    {"at": [-60, 2, 0], "label": "The glow", "note": "Land on the Apron: the strip runs under the torana; the bowl burns far ahead, and a body is already on the north span."},
    {"at": [20, 7, -25], "label": "Horn line", "note": "Stand a body in the wind_horn's line on the north span; it blows it off the edge."},
    {"at": [-5, 4, 70], "label": "The loose stone", "note": "Slam the broken span's voussoir from above; the far half and the body on it fall."},
    {"at": [0, 12, 0], "label": "Flame low", "note": "A body stood its dwell at the bowl: a notch gone. Wall-kick up a column, flow-charge down on it."},
    {"at": [100, 12, 5], "label": "The bell", "note": "Run the east span to the bell perch and ring it: the flame climbs a notch and every body looks up."},
    {"at": [0, 7, 8], "label": "The Olmec comes", "note": "The whole Olmec on the south span; draw it onto the broken run and drop it."}
  ],
  "notes": [
    {"at": [-30, 3, 0], "text": "terrace stair, 8 flights"},
    {"at": [10, 7, 0], "text": "four colossus columns, bowl hung between"},
    {"at": [105, 12, 5], "text": "bell perch (cloister side)"}
  ]
}
```
