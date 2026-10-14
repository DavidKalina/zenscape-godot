# The Rootbound Cut — "They stopped mid-stroke, and the roots finished the job"
Lenses: stay hidden · quarry · root-bound · quiet · spread wide
Pitch: You glide in over a broad, low hill that someone was slowly sawing
apart, and the whole afternoon is quiet: wind in leaves, a distant knock of
stone on stone. Somewhere down among the cuts a basalt body is walking its
rounds, and you move through the slots of the hill the way a thief moves
through a sleeping house.

Place: A wide, gentle whale-back of grey-green hill, about 170 m long and
60 m across, low (12 m of relief) so it reads as a *field* rather than a
tower. It was a basalt quarry: the makers cut it not in a pit (Benchfall's
way) but by long straight saw-trenches across the hill, 3 m wide and 5 to
6 m deep, in a loose comb pattern, leaving tall free-standing ribs of rock
between them with flat tops. From the arrival edge (the east rim, a low
grassy lip where you land off the previous isle, looking west along the
long axis, a little above the hill) you see the combed silhouette first:
parallel dark slots, pale ribs between, all of it furred with moss, and
one enormous banyan-like tree squatting at the hill's heart whose roots
have poured down the nearest trenches like frozen waterfalls, gripping the
rib walls, roofing some slots over into green tunnels. Past the tree, at
the far end, the makers' unfinished work: a colossal head, half cut out of
the living rock and still attached by its nape, one eye socket carved,
the other a blank, face tilted to the sky. Smaller finished blocks lie
about on skid-rails of worn stone, some tipped over on their sides, one
jammed across a trench as an accidental bridge. Stone is dark basalt with
pale saw-marks and faint rune tallies scratched on the rib faces (counts of
blocks, never words). Roots are thick and ropy, grey-brown, not leafy.
The hill is mostly land: grass and fern on the rib tops, bare cut stone
only where the saws went. Broken unevenly: the north end of the comb is
whole and crisp, the south end has caved into a ravine of rubble where the
roots took over completely.

Top (1 char ~ 4 m; east is right, you arrive at right):
```
        0         1         2         3
        0123456789012345678901234567890123456789
   N  ^ """"""##""#"""""~~~~~~~""""""""""""""""
      ^ ##=##=##=##=##=##=##=#  ##=##=##=##=##^
      ^ ##.##.##.##.##.##.##.#  ##.##.##.##.##^   ^ rim, arrival at E
      ^ ##=##=##=##=##=##=##=#  ##=##=##=##=##^
      ^ """"""""""""""""""@@@@"""""""""""o"""1<-- landing
      ^ ##=##=##=##=##=##=#@@@@#  ##=##=##=##^
      ^ ##.##.##.##.##.##.#@@@@#  ##.##.##.##^
      ^ ##=##=##=##=##=##=#@@@@#  ##=##=##=##^
      ^ """"""""""""""""""""""""""""""""""""^
   S  ^ "RR"RRRR"""""""~~~~""""""""""""""""""
        head       banyan (@)        comb
        (P)        roots down          (C everywhere in the slots)
   '=' = rib top (walkable, open to sight)   '.' = trench (hidden, low)
   '#' = rib wall   'o' = the body   '~' = gulf   'R' = rubble ravine (caved, rooty)
```
Side (long axis, W to E):
```
 head blank           banyan                     comb ribs
  _P_                   /\^^/\                _     _     _     _
 /   \__          _    /roots\   _     _     | |   | |   | |   | |
|      \___    __/ \__/ || || \_/ \___/ \____|  |__|  |__|  |__|  |__ landing
 ravine (rubble, roots)  root-roofed slots      slots 5-6 m deep
```

Play: Two ways through, both about crossing the *comb* without being
spotted by the walking body, then reaching the head at the far (west) end.
- **Top road (open and quick).** Run the rib tops. Ribs are ~3 m wide
  with a 3 m slot between them: a running jump (about 6 m of reach at a
  run, crouched long jump farther) crosses a slot, no wall needed. You are
  in plain sight to the body when it stands in a slot, but a flat cone sees
  you only if you are on its side; it is blind to what is behind it. Pick
  your moment, jump on its back-turn. Fast, risky, spotted means chase.
- **Slot road (slow and hidden).** Drop into a trench and walk it
  (crouch-walk to keep quiet, see below). Slot walls cut sight; the body sees
  you only when it enters the same slot or looks down it from a cross-cut.
  Cross-cuts are every few ribs: you pause at the mouth, watch the body's
  head turn, then cross a lit gap in two strides. Slots are dead ends
  where a block lies jammed; climb out by wall kick (walls 5-6 m, kick
  chains reach 3 m, then ledge grab on the rib lip), or by the root
  ropes hanging down the nearer slots (kit ask below, or by stairs
  where the makers cut ramps).
- **Under the roots (third, sub-route).** The banyan's root-roofed
  slots are green tunnels: dark, safe from sight even at 4 m, but narrow
  (pilot 1 m, tunnel 2 m) so a headless-body shockwave in them is a hard
  knock. They come out at the banyan's foot where you can climb the trunk
  to its crown and glide west (pocket sail) over the whole comb to the
  head, trading sight for height.
Choose between speed and exposure, or crown and tunnel. Reaching the
head means the carved eye socket (a perch): the isle's goal stone.

Threat: One **whole headless body** (scripts/enemies/headless_body.gd, with
its head back and chase on: whole-body-chase-round1.md) doing the quarry's
overseer rounds along the slots. It has a flat sight cone with an awareness
meter (unaware, suspicious, spotted; scripts/enemies/body_sight.gd) so
cover is real: ribs, root roofs, crouching behind fallen blocks. It listens
(hears within `hear`) and walks heavily, shaking the ground; its landings
send shockwaves that throw a walker on the ground. It is also a tool: a
body that has spotted you and chases will climb and leap after you and leave
its slot, so you can lure it up onto a rib, then dodge below; its
shockwave landing in a slot throws only walkers on the ground, so jump it.
A spotted body that loses you wanders (lost_for), a window to cross.

Could combo (hunches, nothing sequenced): the body's landing shockwave
could knock a pilot hiding in a slot up and out onto a rib top; a pilot
thrown into the open could be seen by a second body in the next slot; a
tumbling pilot could land across a jammed block and be caught by it. If a
second isle puts an inhaler head near the arrival rim, its pull could
drag a pilot across the whole comb. Ports: catches a body thrown in from a
neighbouring isle at the east rim (lands in grass, soft); throws out the
west end only as a leap from the head's brow (a long jump to the next isle).

Mystery: They cut one face from this hill and never finished it. The
tallies on the rib faces stop at the same number. Each trench holds a
block cut free and left; the roots grew round them, not through, as if the
tree was told to wait. Who stopped the work, and was the tree planted or
simply let in?

Kit used: wall, floor, stairs, fallen_pier, tomb_chest, hall_column
(cut-block stand-ins on skid rails), hall_slab (block lids across trenches),
stone_circle (the banyan's ring of stones), aqueduct stump (rib ends),
rope bridges (one slung over the caved ravine).
Kit asks: Root Curtain (kit-k1-grab.md, already carded) as the climb-out
ropes and the root roofs; and a Rib piece (long thin slab wall with a flat
top, 3 m wide and 5 m high, tileable: a basalt-saw cut wall, low cost,
procedural like wall).

Family knobs: `ribs` (6 to 12, how many trenches), `caved` (how much of
the south end has fallen into the ravine), `roots` (how many slots the
banyan has roofed), `bodies` (1 or 2 walking the rounds).

Sockets: rim at east (facing W, the landing lip); arena = the open rib
tops; cover = every slot and root tunnel (this is the motif); perch = the
head's carved eye socket (far west) and the banyan's crown.

Generator fit: role = traverse/goal; footprint about 170 x 60 m, height span
under 15 m; suits layer shape spread wide (a long field placed across the
layer, other isles beyond its west end).

Distinct from: Benchfall (quarry too, but a deep pit you fall down tier by
tier; this is a shallow comb you cross sideways and the verb is hiding, not
falling). Astronomer's Hush (hidden too, but four islets round a henge from
a head that circles; this is one continuous field with a walking overseer
and cover made of the land itself). Colonnade_spine (a ridge you walk along
a line; this a wide comb with many ways).

## Place (round 2)

**Revision after the user's play (2026-10-14):** the banyan and its ring of stones are removed for now, along with the root roofs (they only made sense with the tree); the mound and the cut through its foot stay, open to the sky. The climb-out ropes now hang from makers' hoist jibs (a basalt post seated on the rib, its beam over the slot). Every block, rail and kit piece is seated on the lowest ground under its footprint and sunk 0.15 m; the hall_slab lid sits on the rib tops either side of S2 (`scratch/rootbound_seat.gd`: 0 floating). Routes re-walked: 26/27 jittered runs reach the rim out; the miss was the overseer spotting him on the top road, swatting and pouncing him off the north edge. Stills: `rootbound_cut_arrival.png`, `rootbound_cut_three.png`, `rootbound_cut_jib_low.png`, `rootbound_cut_mound_low.png`. The notes below predate this revision where they mention the tree, the roofs or the stone circle.

Built as a place on the kit's terrain and look:
`scripts/kit_isle/greybox/gb_rootbound_cut.gd` (one LAYOUT table near the
top), registered in `scripts/kit_isle/greybox/registry.gd`. Uncommitted.

```
python tools/smoke.py studies/motif_yard.tscn -- --motif=rootbound_cut
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=rootbound_cut --sky
python tools/drive.py scratch/rootbound_cut_routes.gd -- [--route=top|slot|road] [--calm] [--jit=N] --scene-args --motif=rootbound_cut
```

**The land.** One KitLand island, 136 x 68 m (footprint x 1-137, z -33 to 35),
keel to treetop -17 to +24 m. The card guessed 170 x 60. I cut it to 136:
the other isles in the "motifs" pool run 40-110 m, the top road still takes
about 40 s at a run, and the planner fits it (see Generator). The hill is a
whale-back about 12 m high, the cuts are 4-5.4 m deep and the turf is on.
The east lawn sits at 0 m and the hill rises west past the banyan's mound
(~5.4 m) to the knoll the head is cut from (7 m). The rib tops swell
unevenly. A 9 m haul road is sunk along the spine (this is the overseer's
beat; see Threat). The north comb is crisper: 9 trenches, no two alike. N2,
N5 and N8 are sawn out through the flank (notches in the silhouette). N4
stops mid-stroke, its floor rising to a blind end. N7 is half filled by a
slump, N3 has a second, deeper cut started in its floor, and two shallow
stubs were begun and left. The south comb is more ragged: S4, S5 and a
tunnel through the mound's foot are roofed by roots, and S5 and S6 break out
into the south-west ravine. The ravine drops in terraces (each a SET_OFF)
to the caved edge, with three rubble islets below. Rib tops slump where a
rib fell in, in three places. The trench widths and angles vary (bent by up
to about 15 degrees), and the spacing runs 5-9 m.

**The ruin.**
- **The colossal head.** The inhaler head's own model, dressed in the same
  stone and 16 m chin to crown. It lies in the quarry court tipped back 55
  degrees, face up and east toward the arrival, its nape buried in the knoll,
  collided as drawn. A stack of three cut blocks (chin step, jaw step, a
  wedge in its lips) climbs to the face.
- **The makers' basalt** (`giant_stone.gd`). A yard of finished blocks on
  skid rails on the landing lawn. Blocks lie on the road (cover), one is
  jammed across N2 (a bridge), and others lie fallen in N5, N6, the court
  and the ravine. Tally runes on four blocks use the same glyph seed (the
  same count).
- **Kit pieces.** A stone circle round the banyan, a hall_slab lid over S2,
  a hall_column on the lawn, a tomb_chest in the court, two fallen piers in
  the ravine and an aqueduct stump.

**Routes** (sizes from the pilot). A running hop reaches about 2.4 m and a
long jump about 4.2 m. A jump catches a lip 1.875 m up, the pump 2.575 m,
and a climbing step is 1.6 m. All are walked rim in (landing, east) to rim
out (knoll, west) through the real input: stick, jump, crouch+jump for the
long jump, jump to climb from a hang.
1. **Top road** (open, about 40 s). From the lawn, take the rib tops along
   z -22 across 8 slots: 3 long jumps (N1, N3, N5), the rest hops caught by
   the far lip. Then up the knoll's north side and benches to the knoll.
2. **Slot road** (hidden, about 50 s). Down the road ramp into N1's mouth,
   along N1, cross-cut X1, N2, X2, N3 and up its floor step. Watch from the
   mouth, then dash 9 m across the road into S3, along XS1, under S4's root
   roof, through the root tunnel, along S5 and out into the ravine, then
   west along the terraces. Up 1.6 m into the court, up the cutters' steps
   onto the face, to the carved eye (the perch), over the brow and onto the
   knoll.
3. **Haul road** (exposed, about 38 s). Wait at the ramp head till the
   overseer is 24 m off, follow it down the road, then the head as above.

Results: 27/27 jittered runs (±0.5 m start, 0-10 s delay, overseer live,
seeds 1-8 + base) reached the rim out, plus all 3 with the overseer moved
off the road (`--calm`). The top road was spotted once in most runs and
never caught. The slot and road routes went unspotted. One beat of
patience is scripted: the driver waits at a slot mouth, or the ramp head,
till the overseer is clear.

**Cover check** (`scratch/rootbound_cover.gd`). Stood still for 30 s while
the overseer passed 9 m away: in a slot floor (N4, S3) its awareness stayed
at 0.00. On the rib top beside the slot it spotted him both times.

**Threat.** One whole headless body with its head worn and chase on
(`chase` 1, `routes` 0), set down on the haul road. It sees with its flat
cone and awareness meter, and spotted, it chases, climbs, pounces and sucks
as its own code does. From the road its eyes (~9.6 m up) clear the rib tops
but not the slots, so a slot hides you unless it looks straight down it. The
card's "rounds along the slots" can't work as written: the body is ~4.4 m
broad and ~10 m tall, and a 3 m slot can't hold it. So it walks the road,
and the slots run off it.

**Real vs stand-in.**
- Real: KitLand land and turf, flora and life (KitLife), RuinKit pieces,
  giant_stone basalt, the inhaler head model, the headless body and inhaler
  head enemies (unchanged), and swing ropes (FootPieces via `g.rope`).
- STAND-IN, the overseer's patrol: a small `Patrol` node in the motif turns
  the unaware body along three road waypoints. A whole body otherwise roams
  any way. The node also holds the body at its post till the land under it
  has stood (in a rendered yard the art builds on a worker after the stage
  is set), and puts the head back on after the yard's reset (R).
- STAND-IN, the Root Curtain: bark cylinders, merged into one mesh, with the
  roofs collided as one lid box each (walkable over, and they block sight).
  Two plain swing ropes hang in N5 and S3 as the climb-out curtains (not
  walked by the driver).
- STAND-IN, the banyan: the hero oak glb scaled 3.6x with a flat green leaf
  material, a cylinder trunk, and one root ramp (walk box) to a crotch perch
  ~8 m up. Climbing to the crown and gliding west is not built or walked.
- The Rib piece wasn't needed: the ribs are the terrain left between the
  cuts.
- Not built: the rope bridge over the ravine, the one-eyed carving (the
  model has two sockets, its eyes left out), and the second body (`bodies`
  knob). No family knobs yet (`ribs`, `caved`, `roots`, `bodies`).

**Distances changed from the card.**
- Slots are 2.0-3.2 m wide, not 3. The card's "about 6 m of reach at a
  run" is really 2.4 m for a hop and 4.2 m for a long jump.
- Slots are 4-5.4 m deep (card: 5-6) and ribs 2.5-7 m wide (card: 3).
- Relief is about 12 m as asked, but it is a rising hill, not a flat
  field.
- The body's beat moved from the slots to the road.
- N2 narrowed to 2.0 m: at 2.3 m a hop fell short of its far lip, which is
  1 m higher because the hill rises west.

**Read of the stills against the bar.** Stills: `captures/shots/rootbound_cut_three.png`,
`rootbound_cut_arrival.png` (from the east rim looking west) and
`sundered_gorge_three.png` (the bar). In the yard both motifs' turf renders
orange, so judge the shapes, not the colour.
- From the rim it reads as one low, cut hill. Ragged slot mouths open onto
  the sunken road, which climbs west. The overseer stands on the road, the
  banyan on its mound in its ring of stones, and the head at the far end
  (half hidden behind the body from this exact spot). It does not read as a
  comb of boxes from there.
- From high above, the north comb still reads as a run of parallel slab
  terraces. The trench walls are the kit's plumb rock faces under flat turf,
  and nothing grows on the walls. The gorge's land reads looser.
- The banyan's ring of trilithons reads as a pavilion round a low-poly oak.
- Next pass:
  - roots and moss down the slot walls (a kit piece: the Root Curtain);
  - more rib tops slumped, the north comb's lips less straight;
  - a real banyan.

**Model budget** (docs/art/model-budget.md). The built isle draws about
196k triangles.
- Stone circle: 75k (weathered 0.8). Biggest, and the easiest to cut.
- Head: 60k at LOD0. Godot's generated LODs, as the enemy head has.
- Hill: 30k (turf 18k, crags 10k, sides 2k).
- Kit pieces: 25k.
- Oak: 1.8k. Roots: 2.6k in one mesh.
- Basalt: 0.8k.

Collision: the hill's cliffs make about 24k prisms in 12 bodies, and the
head is a concave trimesh of its ~60k faces. Build is about 1.9 s headless
on this Mac. 1.85 s of that is the KitLand island, whose ground function is
this motif's GDScript (~6 µs a call); a native ground or a baked height grid
would move it off the GDScript lock.

Which tricks apply:
- **Import LODs + visibility ranges.** The head already has LODs. Add
  visibility ranges on the head and the stone circle: about -100k triangles
  past ~120 m, ~0.3-0.5 ms a frame at range on a mid GPU (estimate).
- **Silhouette geometry.** Applies to the rib lips (real chips on the
  outline), not to the faces.
- **Vertex-colour grime.** Already used (giant_stone, the head).
- **Sculpt high, bake low** and **parallax depth** don't apply to the
  terrain. The stone circle at weathered 0.5 instead of 0.8 would save
  roughly 30k triangles (estimate).
- **Rigid parts on bones:** n/a.

**Generator** (`python tools/sweep.py tools/layer_dump.gd --seed 1..13 --shape sprawl,ring`).
Registering it puts it in the default "motifs" pool, which changes the
default plans.
- With three rims (landing in, north_flank in, knoll out), ring seeds 1-13
  all plan, and sprawl 12/13. Sprawl seed 8 fails: "no way onto
  gb_plumb_well", 59 attempts.
- The same pool without the Cut plans seeds 5-13 (seed 8 included).
- With only two rims, sprawl 5 and 8 failed. The flank rim fixed 5.
- It is placed in 13 of the 18 plans checked with `--isles` (sprawl 1, 2,
  4-7, 9, 10; ring 1, 2, 5, 6, 9), twice in sprawl 4 and 10.
- The planner often enters at the north flank, skipping the east half of
  the comb. When it relaxes ways it can also leave by the landing (sprawl
  6, 9). All the yard's routes end at the knoll.

**Not verified.**
- A full-layer run with it placed.
- The swing ropes as climb-outs.
- The crotch perch and a glide west from it.
- A chase that ends in a catch (no route was caught; the swat, pounce and
  suck are the body's own, tested in its study).
- The body leaving the road after a spot and finding its way back.
- The yard's R reset with the patrol: it re-wears the head in the driver's
  `reset_all`, but this was not pressed by hand.
