# City serpent, round 1: catching the train

The rune serpent as the underground city's train. This round has two parts:

- **The engine.** Moving ground and soft ground in the pilot's motor.
- **The serpent's pieces of the Olmec city kit.** The cards are in
  `brainstorm/round3-olmec-city/`:
  - `kukul_dais`, `kukul_collar`, `kukul_ring` and `kukul_coil` in
    kit-k5-serpent-ride.md.
  - `colossus_ashbowl` in kit-k2-contrarian.md.

The work is on branch `kit/city-serpent`, off `roguelike`.

## Play it

    ./run-city-serpent.command                       # torch look (the default)
    ./run-city-serpent.command --underground=haze    # L flips torch / haze

This opens `studies/city_serpent_yard.tscn`, a basalt plaza over the abyss.

**The serpent's line** is one closed B-spline, about 890 m, about a minute
and a half a lap. It runs:

1. North up a trough beside the waiting dais (east side).
2. Up through the threading ring, which stands over the trough's north end.
3. Off the plaza's end into the dark.
4. Round the coil pillar (north, over the abyss): a turn rising out of the
   haze under the bridge, then two turns up beside the ramp.
5. Along the cap.
6. Back over the abyss in a long loop to the trough.

Two collars ride it, each a stone saddle with a lantern.

**What to do:**
- **Wait on the dais.** Wait in the shrine (a tunnel through, with a low
  door at each end). The eight tick stones across the trough light one a
  second as its head comes.
- **Board at a run.** Run east off the dais's lip:
  - onto the front saddle (a running jump);
  - onto its back (a drop of 1.3 m), then jump-catch the saddle's rim and
    climb up;
  - or catch the saddle's rim and ride hanging.
- **Ride.** Through the ring, under the bridge, then up the coil with the
  saddle 0.3 m over the ramp's edge the whole way.
- **Get off.** Step off onto the ramp at any turn, or onto the cap at the
  top. Stay on past the cap and the collar shrugs you onto it.
- **The ring.** Climb an abutment and the crown courses (each a SET_OFF
  ledge) to the cap, 16 m up, and watch it thread under you.
- **The ash bowl.** The lower court is west, 9.6 m under the plaza.
  - Walk off the plank's end into the ash: it catches you.
  - Walk off the plank's side onto the stone: you're stunned.
  - Wade out over the seat rows, and climb the giant steps back up.
- **The shuttle** is south: a slab ferrying across a gap. It's moving
  ground on its own, the plain test of the engine.

**Keys:**

| Key | What it does |
|---|---|
| 1 | the dais |
| 2 | onto the front saddle |
| 3 | the coil's cap |
| 4 | the plank |
| 5 | the ring's crown |
| 6 | the shuttle's stop |
| 7 | the bridge to the coil |
| C | calls the serpent (about 12 s from the dais) |
| P | holds the serpent still, or lets it go on |
| R | all back |
| L | torch / haze |
| F1 | numbers: its pace, the dais countdown, what you're on, your pace over the ground, the frame, boardings, shrugs, shoves, soft landings |

**Flags:**
- `--underground=haze|torch`
- `--day`
- `--serpent-at=<mark|m>`. The marks are approach, station, ring, coil,
  couple, top, shrug, leave and loop.
- `--serpent-speed=<x>`
- `--girth=<x>`: the whole yard lays out from it (smoked at 1.3, not driven).
- `--no-shuttle`

## Part 1: the engine

### Moving ground (`scripts/pilot_motor.gd`)

**How the serpent ride carried him before.** `studies/serpent_ride.gd` and
the generator's `scripts/kit_isle/serpent_rider.gd` carry him at the scene
level:
- They hold his place on the body (`SerpentBack` hulls).
- They call `motor.carry` with the body's move.
- In the air they slide him by the frame he left in (`air_v`).
- Landing keeps his own pace.

Both are left as they were: nothing in them is marked, so the new rule
doesn't touch them. The motor now does the same job itself, for any body
marked as moving ground. It's the same model, made general:

- **`mover`** (a Callable: a point to the Node3D carrying it, or null).
  `pilot_physics_ground.gd` `mover(p)` does a short ray down. It answers
  only for a body with the `moving_ground` meta (`PhysicsGround.mark_moving`).
  It gives that body's **shape owner**, so each of a serpent's capsules is
  its own rigid piece of ground.
- **Each step, stood on it or hanging from it**, he is first carried by its
  transform's change since the last step (`carry(by, yaw)`).
  - This is exact: no drift, whatever order the platform and he step in.
  - Then the step runs as ever. His `velocity` is his own pace over it.
- **`platform_v`** is its velocity at his feet.
  - It's eased over `PLATFORM_EASE` (0.08 s), so a frame's hitch is not a
    spike.
  - The first step on a new platform takes its pace at once.
- **Leaving it** by a jump, a walk off its edge, a knock or a toss:
  - Its rise is added to his.
  - Its flat pace becomes `frame_v`, the frame he flies in. That frame is
    slid round what stands in the way (a wall takes what it stops) and
    faded under the sail (`SAIL_FRAME`, 0.8 s).
- **Landing:**
  - On moving ground (or stepping from one capsule to the next), its motion
    is taken up at once and his own pace kept. That's a platformer's moving
    ground, so there's no fling from the difference.
  - On still ground, the frame is folded into his own pace, and his run
    bleeds it away like any carried pace.
- **`ground_velocity()`** is the sum. **`moved_by`** and **`turned_by`**
  are what the ground did this step.

**Unset or unmarked, nothing changes.** With no `mover`, `step` is the old
step. With a `mover` that answers null, no state is touched.

### Soft ground (`scripts/pilot_motor.gd`)

**`soft`** (a Callable: a point to `{slow, catch, keep, depth}` or {}).
`pilot_physics_ground.gd` `soft(p)` reads the `soft_ground` meta
(`PhysicsGround.mark_soft`).

- **Standing in it**, his run is `slow` of its pace (a wade).
- **Landing in it:**
  - The fall stun's height is moved up to `catch` (m).
  - His flat pace is cut to `keep`.
  - The step says `"soft"` (the drop) so the study puffs it.
- **A tumbling body** landing in it keeps `keep` of its slide.
- **`soft_now`** is what it gave under him.

The ash bowl's values are `ASH` in the kit: slow 0.55, catch 14 m, keep 0.4,
depth 0.35.

### The other engine changes

**`studies/character_study.gd`** (every study's pilot):
- It wires `motor.mover` and `motor.soft`.
- `_cam_go_with`: on moving ground, the chase camera's follow point goes
  with him. It takes up the ground's turn over `CARRY_CAM_TURN` (0.6 s), a
  boat's sway.
- `_ridden_rid`: the body he rides never draws the camera in.
- Both do nothing on still ground.

**`scripts/rune_serpent.gd`** gains `heave_share` (1 by default). The yard
sets it to 0, so the body runs level in the trough, under the bridge and
beside the ramp.

### Proof (through the real play loop, real input)

All the drivers are uncommitted in `scratch/`, and all pass headless with 0
errors.

**Static ground is unchanged** (`trace_static.gd`):
- The run is 1000 frames of stick and jump input, every frame's feet,
  velocity, move, hold, grounded and stun logged:
  - On the character study's stations: the step ladder, the ledge wall
    (catch, hang, sail), the wall-jump shaft (flip, twirl), the long jump
    chain, the big slope and the tower.
  - On a motif yard isle: a walk, jumps, a wall slide and kick, a long jump
    and a slide.
- The trace taken before any change and with the final code is **byte for
  byte identical** (md5 8dc5ef80…).

**Wait, board, ride, get off** (`ride.gd`):
- **Waiting:** all 8 tick stones lit before he boarded.
- **Boarding:** a run east off the lip and a jump at the lip, onto collar 0.
- **The ride:** 3282 frames through the ring, the dive, under the bridge
  and up the coil to the top.
  - 0 frames off the saddle.
  - His place on the saddle held within **0.002 m**.
  - The worst change of his pace over the ground was 4.3 m/s².
- **Getting off:** a jump toward the cap kept **6.9 of 6.9 m/s** of its pace
  along its way. He landed on the cap at 19.2 m, not stunned.
- `--back`: he landed on its back, walked to the saddle, jump-caught its rim
  and climbed in. He rode to the top within 0.016 m and got off on the cap.
- `--shrug`: he stayed aboard and the collar shrugged him onto the cap.

**The shuttle** (`shuttle.gd`): the slab moves at 5.0 m/s.
- A jump straight up mid-run lands exactly where it left on the slab
  (0.00 m), with a frame of 5.00 m/s in the air.
- He rode it to the far pad and stepped off.

**The ash** (`ash.gd`):
- Off the plank's end it's an **11.2 m drop** (the stun's own is 6.0 m) into
  the ash, with no stun.
- He wades at 2.64 m/s, against 4.80 m/s on the stone, and walks out over
  the seat rows.
- The same plank's side onto the court's stone (9.6 m) stuns him for
  1.24 s.

**The ring** (`ring_climb.gd`): by stick and jump, up the abutment's three
courses and the two crown courses to the cap at 16.0 m. He stayed perched
there while the serpent threaded the bore under him.

**The line** (`line_check.gd`):
- At the dais the line is within 0.05 m of its height.
- In the ring it's on the axis.
- The saddle stands 0.30 m over the coil's ramp (0.57 m at worst, where the
  coupling starts).
- Under the bridge the line is at -7.8, so the cage top clears its
  underside. On the second pass it's +6.3, over it.
- The steepest stretch is 21°.
- Neither its body nor a rider's swept ball touches stone anywhere round
  the lap.

## Part 2: the pieces (`scripts/city_kit_serpent.gd`)

Preload it; it has no `class_name`. A parallel round is editing
`scripts/city_kit*.gd`, so none of them was touched.

**The file gives:**
- `PIECES` (id to one line).
- `build(id, parent, xform, opts)`.
- `set_off`, `bore(girth)`, `saddle_top(girth)` and `wake(piece, points,
  delta)`.
- The helpers in the inner class `Kit`: measures, stone, runes, collision.

**What every piece has:**
- It's a Node3D with its stone mesh and its "Body" (StaticBody3D). The
  collar is its own AnimatableBody3D.
- Meta:
  - `way`: the serpent's line through it, in its own frame, as
    `RuneSerpent.ROUTE` points.
  - `ports`.
  - `triangles`.
  - `strips`: its rune strips.
- **Runes** are GiantStone's rune surface, each strip with its own material.
  They're dead grooves until `wake` finds the serpent near: full within
  5 m, none past 16 m, eased over 0.6 s. The serpent's passing leaves a
  string of gold across the city.

**Sizes:**
- Ledges and treads are SET_OFF and STAND at WorldScale's wanderer.
- The serpent's tube comes from its own constants:
  - `bore` = RADIUS × girth × 1.08, plus its weave reach, its heave reach
    and 0.25. That's 7.02 m at girth 1.
  - The crest is RADIUS × girth × 0.83.
  - The saddle top is the crest plus a SET_OFF.

### `kukul_dais`: `dais(parent, xform, {girth, seed, cover})`

The frame's origin is the dais's middle on the approach's ground. The line
runs toward local -z up its +x side.

- **The platform.** 3 CELL (13.2 m) a side, a SET_OFF high (one
  jump-catch). There are four 0.4 m steps up its west face into the
  shrine's back mouth.
- **The trough.** The body's belly width and 0.5 m a side (5.5 m), a course
  under the top. The line runs up its middle at `line_y`, so the saddle is
  0.3 m over the dais's top and its back is 1.3 m under it.
- **The tick stones.** Eight day-sign stelae across the trough on the far
  bank, facing the dais. `update(ahead_s, passing)` lights one a second
  from 8 s out, south first, and holds all of them lit while the body
  passes.
- **The canopy.** Four posts 4 SET_OFFs tall and a lintel frame (a grab),
  with a feathered frieze and a rune frieze.
- **The shrine house.** 4.4 m, with a low door at each end, a tunnel
  through.
- **The calendar stone.** A kerb ring and thirteen day-signs on the floor.
- **Wake strips:** the trough wall, the calendar, the frieze and the ticks.
- Ground cover on the top.
- **Ports:** `top`, `lip`, `approach`, `line`. The `way` is five points up
  the trough.

### `kukul_collar`: `collar(parent, serpent, ring_k, {lamp, name})`

- It's an AnimatableBody3D marked as moving ground. `follow(delta)` sets it
  on ring `k`'s frame each step (the breath's scale taken out), rolled by
  the shrug.
- **The saddle.**
  - 2.6 × 5.0 m, its top a SET_OFF over the crest.
  - Its rim is a handhold, and a carved handle sits on each flank.
  - The collar band of eight blocks goes round the body under it.
- **The lantern cage** stands at the saddle's tail end:
  - 1.4 m square and 1.9 m tall, with bars at the foot and a SET_OFF up,
    and a cap that's a perch.
  - The cage is low and at the tail, so the chase camera clears it behind a
    rider on the fore half.
  - There's an ember and, with `lamp`, one OmniLight at 16 m. The yard
    lights only the front collar's.
- **The shrug.** `shrug(side)` rolls the collar 0.45 rad and back over
  0.7 s. The yard tosses a rider on it toward the cap, at 8.5 m/s in and
  5 m/s up, in its frame, so he keeps its pace.
- **Other API:** `carries(node)`, `saddle_point(along)`, `forward()`.
- **Ports:** `saddle`, `cage_top`.

### `kukul_ring`: `ring(parent, xform, {girth, ground, seed})`

The frame's origin is the bore's middle, with the axis along z.

- **The voussoirs.** Eight of them, four facets each:
  - The outer face is banded (scale rings) for its silhouette.
  - There's a hairline joint between each.
  - A rune band runs round the bore, one strip a voussoir.
- **The crown courses.**
  - Each side finds the lowest abutment top from which every step up the
    rim has a tread of a stand plus 0.3 m.
  - Steps then follow the rim a SET_OFF apart up to the cap, which carries
    a biting head.
  - **The abutments** step out a course a metre from the ground up to that
    top.
- In the yard the bore is 7.02 m, the abutment 4.8 m over the plaza, and
  the cap 16.0 m over it.
- **Ports:** `crown`, `abutment_l`, `abutment_r`, `foot_l`. The `way` is
  three points on the axis.

### `kukul_coil`: `coil(parent, xform, {girth, shaft 7.5, lane 2 CELL, turns 2, rise 6 SET_OFF, foot, depth, seed})`

The frame's origin is on the axis at the ramp's foot. Angles run from +x
toward -z (counter-clockwise from above), and the ramp rises that way.

- **The shaft.** It reaches `depth` down into the haze, banded with
  courses.
- **The ramp.** A hull every 2.2 m along its middle. The pitch is 7° at the
  middle and 11.5° at the inner edge.
  - It's 8.8 m wide, with 8 m clear under the next whorl.
  - A level landing sits at the foot for a bridge.
  - Its outer face carries a rune band, a quarter turn a strip: the
    serpent lights a spiral of gold climbing the pillar.
- **The cap.**
  - The shaft's top drum with two 0.4 m tiers and a rune stela.
  - A sector of 150° past the ramp's end, roofed only where the whorl under
    it keeps 4 m and more of headroom.
  - The serpent's face looking out.
- **The line.**
  - `line_r` puts the body's flank 1.35 m off the ramp's edge (19.5 m at
    girth 1).
  - `line_y(a)` is the ramp less `line_under`, so the saddle stands 0.3 m
    over the ramp.
  - `way(from)` gives control points coupled to the ramp from `from` to its
    end, and 60° on at cap height. Their radius is widened by the cubic
    B-spline's shrink, so the curve lies on `line_r`.
- **Ports:** `foot`, `cap`, `end`, `cap_edge`.

### `colossus_ashbowl`: `ashbowl(parent, xform, {radius 8, rows 2, seed})`

- **The bowl.** Sunk in a court's floor (y 0). It fills its own square,
  half `reach()` a side, so lay the court round it.
- **The ash.** A collider marked soft (`ASH`), 0.35 m under the drawn
  surface, so the feet sink in.
- **The seats.** A rim a 0.4 m step over the ash, then two seat rows up to
  the floor. The corners are drawn flush and seamless.
- **The stele** stands in the middle with its top snapped off and lying in
  the ash. It has a rune strip.
- **The ash's look.** A drifted disc of pale bone-grey with soft mottling.
  His footprints run in a line across it.
- **Ports:** `ash`, `rim`, `floor`.

### Registering in the city kit

```gdscript
const CitySerpent = preload("res://scripts/city_kit_serpent.gd")
# in the family's PIECES / ALL:  ... + CitySerpent.PIECES.keys()
# to stand one (stand(id, parent, xform, ...)):
var node := CitySerpent.build(id, parent, xform, opts)
# the collar rides a serpent, not a place:
CitySerpent.build("kukul_collar", parent, Transform3D.IDENTITY, {"serpent": s, "ring": k})
# each frame, after the serpent moves (its own _process off, as the yard does):
#   collar.follow(step); CitySerpent.wake(piece, serpent_ring_points, delta)
# the serpent's capsules as ground he rides:
#   PhysicsGround.mark_moving(serpent.get_node("Solid")), and its heave held: serpent.heave_share = 0
```

**A motif builds the serpent's route** from the pieces' `way` metas, each
point through the piece's transform, joined by its own connecting points.
The yard's `line()` is the worked example:
- It needs four or more points in a line for a straight run, such as the
  trough or the bore.
- Weave share 0 wherever stone is near.
- On a closed B-spline, clearance is checked from the control hull.

## Stills

The stills are in `docs/design/roguelike/city-serpent-round1/`, taken
rendered with `scratch/shots.gd --rendered`. The `*.png` files there are
gitignored (`/docs/**/*.png`), as the fires round's were. I looked at all
of them.

The torch and haze versions of each:

| File | What it shows |
|---|---|
| `yard_wide` | the yard |
| `dais_passing` | the dais with its tick stones lit, the calendar, the trough runes and the serpent going by |
| `board_air` | landing in the saddle |
| `aboard` | aboard |
| `ring_threaded` | the full ring, its bore runes blazing, the collar and rider threading it |
| `coil_ridden_wide` | the serpent wound round the coil's foot, the ramp's rune spiral, the bridge |
| `ride_coil` | the chase view in the saddle beside the ramp |
| `off_on_cap` | off on the cap, the collar passing |
| `ash_landing` | the ash bowl's landing |
| `ash_wade` | the ash bowl's wade (he's knee-deep) |

There's also a contact sheet of each look: `sheet_torch.png` and
`sheet_haze.png`.

What I changed by eye:
- **Rune quads.** Some faced away and were culled: the tick stones, the
  bore and the cap stela. Fixed.
- **Lit runes.** Down to 1.4 energy, and the serpent's runes to a dusk
  glow (`zs_daylight` 0.3), so the glows stay dim and warm.
- **The ring.** At first it was sunk to an arch. It's now raised to a full
  ring (centre 7.5 m over the plaza).
- **The ash.** It went from a flat white disc to mottled bone-grey. The
  bowl's corners were drawn as wedge slabs, and are now one flush floor.
- **The cage.** It moved to the saddle's tail and down to 1.9 m, and the
  ridden body no longer draws the camera in.

## Model budget (docs/art/model-budget.md)

Everything is procedural basalt; there's no Blender model.

**Triangles** (stone mesh; the rune strips add two triangles a glyph cell):

| Piece | Triangles | Draws | Shapes | Builds in |
|---|---|---|---|---|
| dais | 4268 | 13 | 32 | 24 ms |
| ring | 1388 | 9 | 51 | 9 ms |
| coil | 3506 | 11 | 84 | 20 ms |
| ash bowl | 4190, plus the ash disc's 800 | 3 | 119 | 30 ms |
| collar | 1936 | 2 | 2 | 10 ms |

How each trick applies:

- **Silhouette geometry: applied.**
  - The ring's banded outer facets and joints, the feathered frieze, the
    cage's lattice (bars and diagonals, not a filled drum: about 1.5k
    triangles against a sculpted cage's 5k or more), the stepped courses
    and the cap's biting head.
  - Faces otherwise take their detail from `olmec_stone`.
- **Vertex-colour grime: applied.** GiantStone's foot occlusion and tone are
  in COLOR, at no cost.
- **Import LODs and visibility ranges: apply next.**
  - The coil is the longest sight-line in the city. Past about 80 m, a
    whorl as a lathe ring with no hull detail, and the runes surface culled
    (its emissive alone reads), would save about 60% of its triangles and
    9 draws: about 2k triangles and an estimated 0.05 ms.
  - The ring past 80 m as 8 boxes would save about 1k triangles and 8 draws.
  - The dais's 11 rune strips could merge into one mesh with a per-vertex
    lit value (a shader change) to save 10 draws.
  - Not done: the pieces are one stone mesh each, as in the city kit.
- **Rigid parts on bones: applied in spirit.** The collar is a rigid mesh
  following a ring's frame, not skinned, at a few transform writes a frame.
- **Sculpt high, bake low: would apply** to the serpent faces (the ring's
  cap head and the coil's face, today blocks). One shared baked head of
  about 6-8k triangles, from a 60k sculpt, would be the hero detail, at a
  cost of triangles over today's 6 blocks. It's the next model to make, the
  same one the city kit's stair asks for.
- **Parallax depth: optional** for the calendar disc and the bore's scale
  rings, about 0.1 ms. Not done.

**Lights:** the front collar's lamp (16 m, no shadow) and the dais's two
fire bowls (`CityFire`, 14 m).

**Rendered cost:** the yard draws at about 10-17 ms a frame on this Mac,
measured with the window's frame times (`scratch/fps.gd`).

## Limits

- **Rendered runs stalled** at about 2 s a frame twice, the first rendered
  run after a pause. Re-run, the same drive took 13-24 s. This is the same
  intermittent stall city-kit-round1 saw. Headless runs never stall.
- **The serpent's back is its capsules**, cut to its crest's height. They're
  round, so standing off the spine slopes. He stands about 0.1-0.2 m off
  the faceted stone at the flanks. The collar is the place to ride. The
  greybox's exact back hulls (`SerpentBack`) are re-pointed every frame
  rather than moved, so the motor's rule can't ride them as they are.
- **The generator's serpent rider and the serpent ride study** keep their
  own scene-level carry. Porting them onto the motor's rule would need
  their hulls as moving shapes. Not done.
- **The shrug only tosses toward the coil's axis** (the yard's rule). A
  collar elsewhere would need its own aim.
- **The wake's shove.** A body in its girth that isn't riding it is tossed
  out of its way: 4.5 m/s out, 4 m/s up, half its pace along. It's a toss,
  never a stun. Its `serpent_wake` source isn't wired to `restun_gap`.
- **No Olmec in the yard.** The ash bowl's "drop him in" (his shockwave
  damped on ash) and his use of the dais and coil lanes are not built or
  checked. His body reads no `soft_ground`.
- **No destruction.** None of the cards' breaks (canopy posts, voussoirs,
  the cage's fall) are built.
- **Pace.** The serpent's pace by stretch is the yard's (`PACE`, set through
  `pace_hold`), not a piece's.
- **The countdown is approximate.** It reads the head's distance over its
  pace now, which changes as it slows for the station.
- **Not placed by the generator.** The registration snippet is above.
- **The bridge to the coil** is a plain deck with kerbs, not the city kit's
  causeway, since that file is under another round's edit.

## Tests

Run headless: `python3 tools/run_tests.py --tests 'test_pilot*.gd' --tests
'test_rune_serpent.gd' --tests 'test_serpent_*.gd'`. 14 ran.

- **13 passed:**
  - test_pilot_figure, test_pilot_footfalls, test_pilot_ledge,
    test_pilot_momentum, test_pilot_motor, test_pilot_moves,
    test_pilot_stun, test_pilot_wake, test_pilot_water
  - test_rune_serpent
  - test_serpent_ride, test_serpent_hops, test_serpent_route
- **`test_pilot_tricks.gd` fails one check:** "Twirling low, Jump pressed
  again neither opens the sail nor flies". It fails the same way on the
  `roguelike` base: I checked by swapping the base's motor, ground bridge,
  study and serpent back in. It is not this round's.

**Smoke** (`tools/smoke.py`, 400 frames), 0 errors each:
- `studies/city_serpent_yard.tscn`, torch and `--underground=haze`.
- `studies/run_layer.tscn --shape=sprawl --seed=1`.
- `studies/serpent_ride.tscn`.
- `studies/character_study.tscn`.

No new tests (prototyping). The full suite was not run.

## Fix: carry

Branch `fix/moving-ground-carry`, off `roguelike`.

**The bug.** The ridden ground's pace outlived the ride. Leaving moving
ground by air sets `platform` to null and keeps its pace as `frame_v`. On
landing on still ground, `_ride_after` found nothing under him (null), the
same as `platform` (null), and returned early. So "onto still ground"
never ran: `frame_v` stayed set while he stood, and slid him through his
next jump. It was seen after a clean landing on the cap, after a stunned
landing, and on R's stage in the Serpent Crossing.

**The fix** (`scripts/pilot_motor.gd`, `_ride_after`): the early return now
skips only when he's on the same moving piece, or on still ground with no
frame. A landing on still ground now does what the header always said: the
frame becomes his own pace and his run bleeds it away, or a catch lets it
go. Landing on moving ground is unchanged: he takes up its motion.

**Proof** (through the real input; drivers in `scratch/`, uncommitted):

| Check | Before | After |
|---|---|---|
| Yard: ride, jump off onto the cap, then a jump straight up there | frame (5.4, 0, -1.8), drifts 2.36 m | frame 0, drifts 0.00 m |
| Yard: off the saddle past the ring, a stunned 9.4 m landing on the plaza, then a jump straight up | frame (0, 0, -9.9), drifts 4.13 m | frame 0, drifts 0.00 m |
| Serpent Crossing: bail onto R's stage, then a jump straight up | frame (0, 0, -7.19), drifts 3.00 m | frame 0, drifts 0.00 m |
| Serpent Crossing: the abutment climb | up to 0.18 m/s of frame | 0 |
| The shuttle: a jump straight up on the moving slab | lands 0.00 m from where it left | 0.00 m |

- The ride (`ride.gd`), the bail's climb to the ring's cap, and the
  re-board from it (onto the serpent's back) all pass as before.
- **Static ground is still byte for byte the same.** The 1000-frame trace
  hashes 8dc5ef80 before and after.

**Tests:** the same 14 as above, with the same result. 13 pass, and
`test_pilot_tricks.gd` fails its one check from the base, as before.

**Smoke** (0 errors each):
- `studies/city_serpent_yard.tscn`.
- `studies/motif_yard.tscn --motif=serpent_crossing`.
- `studies/run_layer.tscn --shape=sprawl --world=under --seed=1`.

## Open questions

- **Boarding.** Is a running jump off the lip right, or should the trough's
  lip let you drop onto its back more easily? The pace by the dais is
  7 m/s.
- **The shrug.** It's a kind toss onto the cap. Should it throw you off the
  coil into the dark instead (a toss you must tech or sail)?
- **The ride's length.** Dais to cap is about 55 s. Shorter (fewer whorls,
  a faster climb) or is the wait the point?
- **The lantern.** The cage at the tail lets the camera clear it. Should
  the rider stand behind it (at the head end) and the camera look over it
  instead?
- **Rune glow.** At 1.4 lit and dead grooves at 0.04, is it too much, or
  too little, in the torch look?
