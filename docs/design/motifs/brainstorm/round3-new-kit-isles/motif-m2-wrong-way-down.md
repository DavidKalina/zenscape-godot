# Wrong Way Down
Lenses: verb fall/descend + stay hidden (inverted); scale human; mood wrong; shape a hanging underside (a low isle tucked under a plate's lip).
Pitch: A plate isle with a small isle hung under its south lip, and every new piece reads the wrong way first: the stair is a chute, the ring is a doorway onto a drop, the covered gallery is the trap and the one exposed place, its roof, is the safe one. The way home runs up a lintel's ropes and, for twelve seconds, down a stair that is hungry to throw you back out.

Why the inversion. The pieces announce themselves: a stair is a route, a hood is shelter, a ring is a frame to reach, a lintel's ropes are a way across. Here each is met by its first reading and punished or paid for it. The player learns the isle by being wrong once, in a place where being wrong costs a short fall and a few seconds, not a life.

Place: A plate isle, the Lid, 88 m across, flat turf and a long clean run on its north side where the plane parks. On its south lip, a worn stone ring stands on the edge: the broken nimbus, its hole opening onto the drop. Looking through it from the turf you see, 7 m down and under the Lid's overhang, a second small isle (Under) with a dark pent hood on it and a leaning lintel with ropes at its far end. Half way along the lip, one step down (2.5 m), a turf shelf holds a carved boss at its edge and a stair hanging off it, steep and bare underneath.

Top (ASCII, 1 char = 4 m; north up):
```
 x: -44      -24       -4        16        36
    ........................................
    .   1111111111111111111111111111111111   Lid (0)
    .  1PPPPPPPPPPPPPPP111111111111111111    P = landing run (north)
    .  1111111111111111111111111^1@1111111   @ nimbus on the lip, ^ perch over the boss
    .                          1 1  22        shelf (2) at -2.5, boss + hung stair
    .                      ~~~333333333~~~
    .                     33333CCoooo3333T    Under (3) at -7.5: C hood, o blast line, T torana
    .                      ~~~3333333333~~
```
Side (from the east; heights in m, Lid top = 0):
```
 Lid  ======================@nimbus====  0
                     \ shelf B | -2.5   B = boss, hung stair hangs out on the drop side
                      \_ 50 deg chute _
        Under  ====C hood=====T torana   -7.5   (tucked 6 m under the Lid's lip)
```

Play: You park on the north run and walk south to the ring, where the lip shows you the whole underside in one look. Down is by the nimbus (step through the ring and fall or sail 8 m onto Under's north strip) or by the hung stair (step on it from the shelf and it surfs you off into the hood). Under is small, shaded and tight; the hood looks like the one safe room and is the trap; the way home is the torana's ropes, a rise to the shelf, and the slam that turns the stair is also a short cellar you can raid and must leave quickly. It leaves the player a little uneasy and a little proud of reading it.

Set pieces:
- relic_nimbus on the Lid's south lip, its hole facing the gulf. Passing through the ring from the north steps over the trough (0.8 m) and off the lip: the nimbus frames a fall. The plane fits (clear ring 11.43 m over WorldScale.opening(TOY_THREAD) 7.0), so a flown pass through the ring is a stunt that ends on the run's west. Its climb (inner rays, spoke, brackets, horns) is an optional stunt to the horns at 17 m, a view of the whole isle and a sail start.
- keel_hung_stair on the shelf: the boss at the shelf's south edge, the flight hung out on the drop at 50 deg (a chute, not a stair), landing him on Under's east end beside the hood. A slam from the Lid's lip (the perch, 2.5 m above the boss, over the 1.8 m of air a slam needs) turns it for 12 s: the flight goes into a shaft cut under the shelf, to a cellar (the only cover on the isle nothing can see into, one collectible). Stay past the hold and the tell (0.5 s) tips the flight back out: stood on it past 70 deg he is tossed (knock at a run) out over Under onto the hood's gallery.
- pent_hood on Under, two bays, one fallen gap. The gallery (floor to eaves 2.8-3.5 m, TOP_ROOM wide) is where a wind blaster's plate sits at its dead end; stepping on it makes the mouths nearest where he stands inhale and blast, and with the fallen bay open and the parapet at 1.59 the blast shoves him out the gap. The roof (a 20 degree crouch surf off the eaves) and the wall walk (4.93 m) are exposed in view of the Lid, and above the blast: they are the safe way east.
- relic_torana at Under's east end: the jamb on Under's lip, three ropes, the lintel tilted up toward the shelf, the far end a SET_OFF over the shelf's lip when the release is good, as the card describes. This is the way up. A poor release meets the lintel's face and its lip; a miss drops back to Under's grass (a short fall).

Threat: wind blaster (scripts/traps/trap_wind_blaster.gd): a plate at the gallery's end, four mouths along the hood's back wall, aimed where he stands. `lead` 0.5, `delay` 0.6 s. Keep moving and the blast lands behind; stop and he is shoved through the fallen bay and drops 8 m to the Under's cliff-foot meadow, not a kill. The roof is the intended answer: climb the wall (it is `GRAB_TOP` high from the dune ramp) to the eaves, surf across, and no plate to step on.

Ports: catches the plane's approach on the Lid's north run (west to east, 50 m clear), and a sail from any neighbouring isle onto the Lid's run; throws out the Lid's south lip (the nimbus's hole) and the torana's top at the shelf, which are both within a short fall of the rest of the isle.

Kit used: pent_hood, relic_nimbus, keel_hung_stair, relic_torana (all four new, ids in scripts/ruin_kit*.gd FAMILIES: cloister, relic, keel); `floor`, `wall`, `buttress` and `stairs` (gothic) for the shelf's court and the cellar's lining; trap_wind_blaster; KitLand.island for the Lid, shelf and Under.

Kit asks:
- A shaft/cellar cut in a KitLand shelf (a lined hole under the boss for the turned stair), if KitLand.island has none.
- A hanging-root fringe on the Lid's overhanging keel (HangingRoots exists; just a placement).

Family knobs: `hood_bays` (1-3: how long the trap gallery is), `hold` (the stair's turned hold, 8-20 s), `ropes` (the torana's chain, 3-5), `drop` (Under's depth below the Lid, 6-10 m: how far the ring's fall is).

Sockets: rim (the Lid's south lip at the ring, facing south), arena (Under's meadow and hood), cover (the cellar and, falsely, the gallery), perch (the Lid lip over the boss; the nimbus horns).

Fit: role accent/underside; footprint about 88 x 70 m; height span 24 m (Lid at 0, nimbus top 17, Under 7.5 below).

Distinct from: hollow_keel (a colossus hall fly-through, switchback stairs, nothing inverts) and sundered_gorge (two drifted halves side by side). This is a plate with a tiny hung isle that works as a set of reversals, none flown through, all on foot.

Layout: the rough map (x east, z south, y up; metres, Lid top = 0).
```json
{
  "isles": [
    {"id":"1","name":"The Lid","x":0,"z":0,"rx":44,"rz":26,"top":0,"keel":-7,"set_piece":"relic_nimbus on the south lip"},
    {"id":"2","name":"Shelf","x":30,"z":28,"rx":10,"rz":5,"top":-2.5,"keel":-6,"set_piece":"keel_hung_stair (boss, cellar)"},
    {"id":"3","name":"Under","x":8,"z":42,"rx":34,"rz":14,"top":-7.5,"keel":-16,"set_piece":"pent_hood + relic_torana"}
  ],
  "links": [
    {"from":"1","to":"3","kind":"stones"},
    {"from":"2","to":"3","kind":"stair"},
    {"from":"3","to":"2","kind":"rope"},
    {"from":"2","to":"1","kind":"climb"}
  ],
  "pilot": [[-30,0,-8],[0,0,10],[6,0,24],[6,-7.5,32],[20,-5,42],[34,-7.5,40],[36,-4,34],[32,-2.5,30],[30,0,20],[-30,0,-8]],
  "threat": [[24,-7.5,42],[18,-7.5,44],[12,-7.5,50]],
  "landing": [-40,-14,10,-4],
  "end": [-30,0,-8],
  "moments": [
    {"at":[6,0,24],"label":"The ring on the lip","note":"A worn ring stands on the edge; through it you see Under, the hood and the lintel, 7 m down."},
    {"at":[30,-4,32],"label":"The stair that surfs","note":"The hung stair looks like the way down; it is a 50 deg chute that slides you off into the hood."},
    {"at":[16,-7.5,42],"label":"The cover that bites","note":"The gallery is dark and out of sight; at its dead end a plate fires the blast and shoves you out the gap."},
    {"at":[20,-4.5,42],"label":"The exposed roof","note":"Up on the hood's roof, in view of the Lid, you are above the blast and the way east is open."},
    {"at":[36,-4,36],"label":"The prayer ropes","note":"Three ropes under a lintel tilted at the shelf; a good release lands on top, a poor one on its lip."},
    {"at":[30,-2.5,27],"label":"Twelve seconds","note":"You slam the boss from the lip, the stair turns, and you raid the cellar before it tips back and throws you out."}
  ],
  "notes": [
    {"at":[24,-7.5,42],"text":"plate: stand and the blast shoves you out"},
    {"at":[30,-6,30],"text":"hung stair 50 deg: no standing"},
    {"at":[30,0,24],"text":"perch 2.5 m over the boss: the slam"},
    {"at":[6,0,24],"text":"ring 11.4 m clear: plane fits"},
    {"at":[-15,0,-8],"text":"north run: 50 m of clean turf for the plane"}
  ]
}
```
