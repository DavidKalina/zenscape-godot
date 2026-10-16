# The Same Floor
Lenses: verb fall/descend; mood wrong; scale a fragment of something bigger; world sky.
Pitch: A slice of a tower pokes out of a plate's east lip and runs on down into the cloud: three rooms stacked, each the very same room (same pier, same chest, same lancet), cut open on one side like a dollhouse. Down is the goal, and the building wants you down: each room's hole is somewhere you did not expect, and the third floor has no floor under it, because the tower goes on without you.
Place: A turf plate (the landing strip on its west run) whose east lip is eaten by a tower fragment: a clean vertical cut through a much bigger building, three floors showing, a ragged stub of a fourth. From the lip you look down into the section: three identical rooms, one under the other, and the cloud where the rest should be. Far below and out lies a small meadow isle (Base) with the tower's footing, the only place the tower's stair comes out again.

Top (1 char ≈ 4 m):
```
 ^^^^^^^^^^^^^^^^^^^^
 ^""""""""""""""""""^
 ^"" 1 plate  ....>.#A   <- lip, the slice (A,B,C floors under)
 ^"" landing run  ...#
 ^""""""""""""""""""^
 ^^^^^^^^^^^^^^^^^^^^ ~~~~~~~~~    ~~~~~~~~~
                      ~~~~~  2 Base  ~~~~~
                      ~~~~~  "@" footing
```
Side (west to east, y up):
```
 plate 0 =====\  lip
              |A| floor A  -5.4   [hole SE]
              |B| floor B  -10.8  [hole NW, blaster pier]
              |C| floor C  -16.2  [hole where the pier was]
              :  ragged stub, then cloud
                        ~ sail ~~~>  Base -34  ("@" footing, stair up)
```
Play: You walk to the lip, see the rooms, and step in through the missing wall. Each room teaches you its hole, and the next shows the same room with the hole moved, so you cannot run on memory; you read the slab, hang from a hole's lip and let go for a short drop. The third room ends at the cut: you leave it by the pocket sail, out and down to Base, with the whole slice hanging over you like a bell. It leaves a small chill: the place is not broken, it is just not for you, and you are only passing through it.

Set pieces:
- The section: three `floor`-slab rooms 14 m square (about 12 pilot heights across), 5.4 m apart (about 4.5 pilot heights, so no floor can be climbed up from the one below; drops are short from a hanging lip). Each has a `pier` in the centre, a `tomb_chest` by the north wall, a `lancet_wall` on the north, and the south or east wall left off as the cut. Built from one recipe stamped three times: only the hole differs.
- The holes: A's hole is the SE corner, B's the NW, C's the centre where its pier stood. Each is about 3 pilot widths, a drop you can hang from and let go (1.2 m fall) or just step into (5 m).
- The eager pier: B's `pier` is a wind blaster's plate; stand in B and its mouths inhale and shove you toward the nearest open side, the cut, where a fall is 22 m down to the cloud. Keep moving and it blasts behind you; stand still and the building posts you out.
- The stub: C's slab ends in a ragged edge with the start of a fourth floor's `wall` and `pier` stumps, the tower still going on under the cloud. The pocket sail opens off the edge; the glide to Base is long and slow, a view of the whole cut.

Threat: wind blaster (scripts/traps/trap_wind_blaster.gd) in B only, knobs `count` 4, aimed where he stands. The harm is the fall off the cut (cause "fall"), not the blast. Holes are staggered (A SE, B NW), so B is always crossed and never skipped.

Ports: catches the plane on the plate's west run (landing) and a sail from any isle above or beside the plate's lip; throws out a sail off C's stub onto Base, then a stair up Base's footing (a long `stairs` flight, 8 m rise) to a ledge chain back onto the plate's east lip, so the loop closes.

Kit used: floor, pier, tomb_chest, lancet_wall, wall, stairs (gothic, in ruin_kit.gd PIECES); tower_shell (tower family, for the cut's ragged edge and the stub); trap_wind_blaster; KitLand.island for the plate and Base.
Kit asks:
- A "section" cut flag on tower_shell (or `wall`): a face left open, with a clean sawn edge and the slab's end showing, so the slice reads as cut from something bigger.
- One-call stamping of a room recipe N times down a column (`stack(piece_recipe, n, pitch)`), for the identical floors; if RuinKit placement can't repeat, a loop in the greybox does it.

Family knobs: `floors` (2-5: how many identical rooms), `drift` (0-1: how far each hole moves between floors; 0 is the same hole, a gift), `pier_blaster` (which floor's pier is the trap; 0 none), `base_drop` (22-40 m: how far under the last slab Base lies).
Sockets: rim (the plate's east lip at the cut, facing east), arena (the middle room, B), cover (the chests, the piers on A and C, not B's), perch (the plate's lip over A; Base's footing).
Fit: role set piece/descent; footprint about 90 x 50 m (plate 64 x 40, slice 14 x 14, Base 24 x 20); height span about 40 m.
Distinct from: round3 m2 Wrong Way Down (a descent under a plate through reversals) and plumb_well (a shaft, oculi and a plumb wall): this is a stack of one identical room read for its moved hole, cut as a section, and the way out is a glide, not a chute or a slam chain.
Layout:
```json
{
  "isles": [
    {"id":"1","name":"Plate","x":0,"z":0,"rx":32,"rz":20,"top":0,"keel":-12,"set_piece":"landing run, the cut on the east lip"},
    {"id":"2","name":"Base","x":78,"z":10,"rx":12,"rz":10,"top":-34,"keel":-42,"set_piece":"tower footing, stair back up"}
  ],
  "links": [{"from":"1","to":"2","kind":"stair"}],
  "pilot": [[-20,0,0],[28,0,0],[36,-5.4,4],[40,-10.8,-4],[40,-16.2,0],[50,-16.2,0],[78,-34,10]],
  "threat": [[38,-10.8,0],[44,-10.8,0]],
  "tips": [[40,-10.8,0]],
  "landing": [-30, -6, 6, 6],
  "end": [78,-34,10],
  "moments": [
    {"at":[30,0,0],"label":"The section","note":"The lip opens on three identical rooms in a stack, cut open like a dollhouse; the cloud where a fourth should be."},
    {"at":[36,-5.4,4],"label":"Floor A, the first hole","note":"SE corner: hang from the slab lip and let go, a short drop onto B."},
    {"at":[40,-10.8,-4],"label":"Floor B, the same room","note":"Same pier, chest and window, hole now NW; the pier is a wind blaster that posts a standing body out of the cut."},
    {"at":[40,-16.2,0],"label":"Floor C, no floor under","note":"The hole is where the pier stood; its slab ends in stumps of a fourth floor, tower going on into the cloud."},
    {"at":[60,-26,6],"label":"The glide","note":"Off the stub with the pocket sail, a slow turn round the cut hanging overhead like a bell."},
    {"at":[78,-34,10],"label":"The footing","note":"Base's meadow, the tower's foot; a long stair climbs back to the plate's lip."}
  ],
  "notes": [
    {"at":[-20,0,0],"text":"landing run: plane parks here"},
    {"at":[44,-5.4,0],"text":"rooms 14 m square, floors 5.4 m apart"},
    {"at":[52,-16.2,0],"text":"the cut: 22+ m to the cloud"}
  ]
}
```
