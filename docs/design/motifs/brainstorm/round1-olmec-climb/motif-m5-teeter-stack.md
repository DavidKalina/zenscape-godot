# The Teeter Stack
Lenses: verb fall/descend then climb again; mood playful; shape a tall stack (isles over isles)
Pitch: Past the temple end, five small isles are lapped one onto the next like dropped plates, each higher than the last, and every one of them is light enough to tip. When the Olmec hauls up onto a plate it dips under his weight toward the plate below, flinging the far rim up into a grab or the near rim out from under your boots, and you read his hands on the face to choose where to stand.

Place: A column of stone off the spine's east tail (the tail end is the zero; the gap is 10 m of sky). A fixed low "cradle" island hangs 7 m under the tail's level with a spring pool and the long turf run; on its east rim three plates are seated one over the next (each laps 2 m onto the one below, as round 1's crags do: `CRAG_SEAT`), and a fixed summit crowns it. The view on arrival: the plane comes in from the west along the spine, the stack standing ahead like a leaning cairn of thin turf discs, each with a ruin on its lip, and the summit's horn on top. Plates are flat, 14-24 m across, with thin keels and a hanging tuft of roots; each is its own node (never merged into the cradle or summit), so `olmec_tilt` sees each as a stone of 6-80 m.

Numbers (his: head 3.36 m, stride 2.4, haul and climb up to 22 m, leap 12 m across and 0.5 head up; hers: grab 1.875, chain 2.575, `SET_OFF` 1.6):

| # | Isle | Top over the tail | Radius | Tips? | Set piece |
|---|---|---|---|---|---|
| 1 | Tail end (the spine's) | 0 | fixed | no | the landing run on the south bench |
| 2 | Cradle | -7 | 17 | no | spring pool, the 26 m turf run, `city_wedge` as a hide |
| 3 | Plate A | +0.5 | 12 | yes, 1.9 m at the rim at 9 degrees | `maker_felled` column on its east rim |
| 4 | Plate B | +8 | 9 | yes, 1.4 m | `turret` with a stair; two arches |
| 5 | Plate C | +15.5 | 7 | yes, 1.1 m | `city_lip` face (ruin-style), the belvedere |
| 6 | Summit | +23 | 22 | no | `stone_circle`, `wind_horn`, 30 m turf run |

Each stack face is 7.5 m, nearly two crag faces (`CRAG_CLIMB` 4.0): over his stride, so he hauls and the tilt fires on every rung. The rim dip is r x sin(angle), so the smaller the plate the less it moves: A gives a full grab (1.9 m), C only a nudge. The lurch is 3.1 m/s for 1.1 s, about 3 m along the fall line, slower than any run.

Top (1 char about 4 m; north up; the stack bends east and north):
```
                                    6666666
                                   666@6666       @ horn, circle
                                    6666666
                                        .
                                      5555        C belvedere
                                     55o55
                    ~~~~~~~~~~~~~     555
 ###########%%%%%                    .
 ######....1111       .~~~~~     4444
 #####                           44#44            B turret
 ##                         ..  444
                          3333
                  2222   33C33  <-- A, felled column on its rim
                 222222   333
                 22"~~22
                  222222        . = pilot's route, o = tips on haul
                    222
```
Side (west is left; heights over the tail, m):
```
 +23                                           66666
                                             .      66
 +15.5                              555     /
 +8                        444     /  \____/
 +0.5     1111      333   /  \___/
  0 ______/    \__ 3333 _/
                      \ 22222222
 -7                    \_cradle_____ (pool, run)
```

Play:
1. Arrive by plane on the cradle's 26 m run (or the tail's south bench) and walk up. The Olmec wakes on arrival and goes after you once he has his head.
2. From the tail, three floating stones (0.6 m hops, 2.5 m apart) cross 10 m to plate A, which sits level with the tail, so the pilot crosses without a climb and he can leap it (10 m across is inside his 12 m, rise 0.5 m is level). The pilot reads the first of three tells: if he is far off, A is still and flat.
3. On A the felled-column plinth stands at the east rim. A `stairs` flight on its lee (the west rim) climbs a floating pew stone at +4, which is 3.5 m over A's rim at rest: out of a chain. Don't wait for him there: the pew is only in reach once A has tipped.
4. He arrives. He leaps from the tail onto A (a leap kick), or hauls up the cradle face at the plate's south rim. Hands over the lip, the rim dips toward the cradle. A's far (north-east) rim lifts 1.9 m, which puts the pew at 1.6 m over it: inside a grab. A pilot standing there is flung up to the pew; a pilot at the south rim is lurched 3 m off the edge and falls 7.5 m to the cradle's turf, unhurt, with the pool to land in. Either way it reads: the hands, the groan, the dust off the rim, the camera quake. Running upslope (north-east) always wins; the lurch is slower than the run.
5. Fall branch: from the cradle you climb back by the `city_riser` (her chimney inside the left cheek) up to A's keel, or by the rope bridge (a live one, 14 m) back to A's rim. Falling costs height and time; the cradle is a rest with the long turf run and a way to the plane.
6. B (+8): reached by a rope bridge from A's pew (12 m), or by the turret's stairs, or a hauled catch off the pew. The Olmec climbs B's face from A (7.5 m, hands and mantle) and B tips under him. The pilot who stands on B's near rim is carried toward A; the one on B's far rim is lifted and can catch plate C's lip: C's lip is 4.2 m over B at rest, 2.3 over with B tipped, inside a chain. So B asks you to be on the far side as he climbs.
7. C (+15.5, r 7, the narrowest): the belvedere. Its `city_lip` face is his (the hauling lip with its cornice); the pilot's shelf chain climbs the face's end. When he hauls onto C it nudges 1.1 m, a tell more than a push. On C the tilt is only the warning; the plate holds.
8. Summit (+23): a 12 m leap gap from C is just inside his leap, but a 22 m stand-off wall (his `climb_max`) is not: the summit's skirt is taller than he takes, so he cannot climb it. The pilot reaches it by the rope bridge from C or by the `wind_horn`'s updraft (pocket sail). This is the chase's end: he stalls beneath on C pacing and groaning, and from the summit the pilot has the 30 m run and takeoff, a long downhill glide off the edge.
What the player chooses: wait on the up side and take the lean for height; go the slow way by stair or bridge while he climbs; or drop to the cradle on purpose to buy a rest and climb back up behind him.

Threat: the Olmec's haul and leap (`olmec_tilt`: TIP_MOST 80, DIP 2.2, TIP_LEAST 6 m, 2 to 9 degrees, LURCH 3.1 m/s for 1.1 s along the fall line). No extra trap. Fairness: the tilt never stuns; the lurch is under run speed; the fall is a drop to a safe cradle; the camera and the groan tell first.

Ports: takes the plane's arrival at the cradle's run or the tail's south bench; takes the spine's wake (colonnade_olmec.gd) and his climb off the crags (the crags knob moves). Throws out: a pilot who falls goes to the cradle; at the summit, the plane's takeoff.

Kit used: RuinKit `stairs`, `turret`, `arch`, `lancet_wall`, `stone_circle`, `wind_horn`, `tomb_chest`; city `city_riser`, `city_lip`, `city_wedge`, `maker_felled`; the live rope bridges; walker-only floating stones (`WalkerOnly`); `KitLand.island`.
Kit asks: ruin-style, rune-free, overgrown variants of `city_lip`, `city_riser`, `city_wedge` and `maker_felled`, with their lanes unchanged. A "plate" helper that makes one tippable floating isle (its own node, a thin keel, a convex climb solid for his rays, seated 2 m on the isle below), the crags' construction generalized from three fixed sizes. A pew stone whose top is a grab height only when its plate is tipped (a plain floating stone placed to the numbers; no new code).
Family knobs: `plates` (3 to 5, more is a taller stack), `lean` (the plate radii, 7 to 14 m, so the tip is 1 to 2.2 m), `cradle` (the fixed island's size and whether it has the pool and wedge), `bridges` (rope bridges holding or one snapped).
Sockets: rim: cradle west edge facing the tail, tail-gap east. Arena: the cradle run and plate A. Cover: the cradle's `city_wedge` hide, the turret. Perch: the summit horn and the belvedere.
Fit: role hero; footprint about 85 m east-west (past the spine's tail) by 60 m north-south; height span 30 m (-7 to +23). Cost: med (new plate helper and four ruin-style city pieces, no new enemy code; the tilt is already built).
Distinct from: stair_clouds (one stepped fixed mesa on a grand stair) and broken_ring (a spiral of fixed islets): here every step is a free plate that moves under him, and the fall is part of the way.

Layout: x east from the tail end, z south, y over the tail's top.
```json
{
  "isles": [
    {"id":"1","name":"tail end","x":-6,"z":0,"rx":12,"rz":8,"top":0,"keel":-6,"set_piece":"landing bench"},
    {"id":"2","name":"cradle","x":22,"z":14,"rx":17,"rz":17,"top":-7,"keel":-16,"set_piece":"pool, turf run, city_wedge"},
    {"id":"3","name":"plate A","x":22,"z":0,"rx":12,"rz":12,"top":0.5,"keel":-3,"set_piece":"maker_felled column"},
    {"id":"4","name":"plate B","x":38,"z":-12,"rx":9,"rz":9,"top":8,"keel":5,"set_piece":"turret, arches"},
    {"id":"5","name":"plate C","x":52,"z":-22,"rx":7,"rz":7,"top":15.5,"keel":13,"set_piece":"city_lip belvedere"},
    {"id":"6","name":"summit","x":72,"z":-32,"rx":22,"rz":22,"top":23,"keel":10,"set_piece":"circle, wind_horn, turf run"}
  ],
  "links": [
    {"from":"1","to":"3","kind":"stones"},
    {"from":"2","to":"3","kind":"climb"},
    {"from":"3","to":"4","kind":"rope"},
    {"from":"3","to":"4","kind":"climb"},
    {"from":"4","to":"5","kind":"stair"},
    {"from":"4","to":"5","kind":"climb"},
    {"from":"5","to":"6","kind":"rope"}
  ],
  "pilot": [[-6,0,0],[10,0.5,0],[22,0.5,-6],[22,4,-8],[38,8,-12],[52,15.5,-22],[72,23,-32]],
  "threat": [[-6,0,0],[10,0.5,0],[22,0.5,0],[38,8,-12],[52,15.5,-22]],
  "tips": [[22,0.5,0],[38,8,-12],[52,15.5,-22]],
  "landing": [10,6,36,22],
  "end": [72,23,-32],
  "moments": [
    {"at":[10,0.5,0],"label":"Three stones across","note":"Hop the 10 m of sky to plate A while he wakes behind you; A is still and flat."},
    {"at":[22,0.5,-6],"label":"Hands on the rim","note":"His hands come over A's south lip; A dips toward him and the far rim lifts 1.9 m into a grab. Run upslope to the pew."},
    {"at":[22,-7,12],"label":"The drop","note":"Stand at the low rim and the lurch drops you 7.5 m to the cradle's pool: no harm, a rest, and the long run."},
    {"at":[38,8,-12],"label":"Far side of B","note":"Stand on B's far rim as he climbs; it lifts you to plate C's lip, a chain."},
    {"at":[52,15.5,-22],"label":"The belvedere nudges","note":"C moves only 1.1 m, a tell; the summit is in sight."},
    {"at":[72,23,-32],"label":"Too tall for him","note":"The summit skirt is past his climb; he paces below while you take off down the 30 m run."}
  ],
  "notes": [
    {"at":[22,-7,24],"text":"cradle rest, hide in city_wedge"},
    {"at":[16,0.5,-4],"text":"gap 10 m, inside his leap"},
    {"at":[62,23,-30],"text":"skirt over his 22 m climb_max"}
  ]
}
```
