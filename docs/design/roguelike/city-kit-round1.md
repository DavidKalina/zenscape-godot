# City kit, round 1: the city's bones

The first pieces of the new `city` kit family, for the underground Olmec
city the run starts in. There are four pieces: the basalt pillar-isle, the
drum stair, the epic stair and the causeway. They are built around the
Olmec (`scripts/enemies/headless_body.gd`): his lanes, his breaks, his
stone. The cards they merge are in `brainstorm/round3-olmec-city/`:

| Piece | Cards |
|---|---|
| `city_pillar` | ol_pillar |
| `city_drum_stair` | ol_drum_stair |
| `city_stair` | city_stair, oc_proc, kukul_balustrade, maker_stairfault |
| `city_causeway` | ol_causeway, city_aqueduct, maker_causeway |

The work is on branch `kit/city-bones`, rebased on `roguelike` 24a04be2
(city breaks, beacons and light sight, the walker-only layer and the
underground look).

## Play it

    ./run-city-kit.command                       # the torch look, the Olmec on the stair
    ./run-city-kit.command --underground=haze    # the haze look (L flips them)
    ./run-city-kit.command --olmec=causeway      # the Olmec walks the causeway; the bay drops under him

This opens `studies/city_kit_gallery.tscn`, which has the real pilot, motor
and camera:

- **C, the arrival.** A low pillar-isle whose crown is three courses (14.4
  m) under the rest. The epic stair climbs from it. The stair's first
  landing is a fault over a chamber.
- **The causeway.** It runs four spans from the stair's summit to A. The
  middle third of its first span is a bay that breaks, and C's crown lies
  under it as the lower road.
- **A, the great pillar.** The drum stair winds down a well in its crown.
  Its climb face (east-north-east) has the prism chain up its collars.
- **Five far pillars** stand at other heights in the haze. The first one
  wears a KitLand turf crown.

Stations:

| Key | Station |
|---|---|
| 1 | The arrival |
| 2 | The summit |
| 3 | The causeway's far end |
| 4 | The drum's rim |
| 5 | A turn of the drum |
| 6 | A's collar chain |
| 7 | The cheek crest's head |

R resets everything. Breaks stay broken until the scene reloads. F1
shows the rails (times on a crest, top speed), the breaks and his state.

Flags:

- `--olmec=stair|causeway|none`
- `--no-fault`, `--no-bay`
- `--broken=fault,bay` breaks those floors at the start.
- `--body-at=x,y,z`
- `--body-knob=k=v`, `--head-knob=k=v`
- `--ground=dust|grass|moss|off`, `--no-cover`

## Files

- `scripts/city_kit.gd` holds the family:
  - `PIECES`: the four, plus `CityBreaks.PIECES` (the felled column and
    the drum floor)
  - `piece(id, seed, weathered, opts)`, which hands the breaks' ids to
    `CityBreaks.piece`
  - `ALL` (also the fires, `CityFires.PIECES`) and `stand(id, parent, xform, ...)`,
    which stands any of them and hands fires to `CityFires.build`
  - `name_of`, `walk_areas`, `crown_outline`, `drum_at`
  - The gallery's fire bowls are still plain bowls and lights, not the
    fires round's lightable cressets. The `mounts.cresset` points are where
    those would stand.
- `scripts/city_kit_stone.gd` draws the stone. Convex blocks (sets of
  planes) are drawn in the Olmec's weathered basalt, the material from
  `inhaler_head_look.gd`'s `stone_material`. The vertices are dressed the
  way the Sunken Giant's are: tone, foot occlusion, sparse moss and the
  rest-position grain. Rune bands are the shader's carved grooves, with no
  glow by default.
- `scripts/city_breaks/floor_break.gd` makes the stair's fault and the
  causeway's bay pieces of the breakables hub (`scripts/kit_isle/breakables.gd`).
- `studies/city_kit_gallery.gd` and `.tscn`, and `run-city-kit.command`.
- `scripts/enemies/body_routes.gd` gets one planner change (see "His
  planner").

## Sizes and API

The sizes come from the walker's numbers (RuinKit `SET_OFF` 1.6, `CELL` =
RuinKit `BAY` 4.4, `STAND`, `TOP_ROOM`) and from round 11's rules for him:

- `COURSE` = 3 × SET_OFF = 4.8 m. This is a collar's rise, a flight's rise
  and a drum turn's drop. It is under the fall stun (6 m), so a fall off
  the inside of anything lands standing on the course below.
- `RISER` = SET_OFF / 4 = 0.4 m, and `TREAD` = 0.8 m.
- `LANE` = 2 × CELL = 8.8 m. This is a stair's width and a drum turn's
  width. Round 11's 5 m is his planner's figure, but his bulk (BULK_W: 2
  head heights, 6.7 m with his arms) is eased off any wall it meets. A
  first stair at 6.6 m stalled him at its foot between the serpent heads.
- `LANDING` = 2 × CELL = 8.8 m.
- The deck is 2.5 × CELL = 11 m, with 9.4 m clear between the parapets.
- Every piece is a Node3D with its front toward +Z, a "Mesh" (stone, then
  runes) and a "Body".
- Meta: `ports`, `mounts.cresset` (fire bowls, the only light), `rails`,
  `breaks`, `walk_areas`, `his`, `triangles`.
- What y 0 is depends on the piece. It is where the piece meets its
  neighbours:

| Piece | y 0 |
|---|---|
| Pillar | the crown |
| Drum | the rim |
| Stair | the foot |
| Causeway | the deck |

### `city_pillar` (ol_pillar)

- **Shape.** A hex column with a crown `apothem` (default 7 CELL, 61.6 m
  flat to flat). Under the crown are `courses` (3) collar courses, each a
  COURSE tall and stepping out by `LEDGE`. A course is a talud with a 0.25
  m batter under a tablero with a carved glyph band. Under the last collar
  the shaft goes down to `depth` (70 m), fluted with organ-pipe prisms
  half sunk in its faces.
- **The collars.** `LEDGE` is one SET_OFF (1.6 m). That's a walker's
  ledge, and under his 2 m shelf rule.
- **The climb chain** (`climb`, a face index, -1 for none). On each
  collar, two prisms (1.2 m flat to flat) stand against the course above,
  one and two set-offs up, and then the collar's own lip. They're
  walker-only (`WalkerOnly.mark`): he climbs the face behind them.
- **`crown`.** One of:
  - `"paved"`: a two-tier dais in the middle, with streets 0.58 ×
    apothem round it.
  - `"flat"`
  - `"bare"`: CROWN_SOIL under y 0, for a KitLand turf top.
- **`well`.** A round well in the crown, `well_depth` deep, for a drum
  stair.
- **Ports:** `crown`, `climb_steps`, `climb_foot`, `well`.

**How a motif uses it as its isle.** There are two ways:

1. **The pillar is the isle.** Place it with its crown at the isle's
   height. Its collars and shaft are the isle's sides, and its walk areas
   are the isle's ground for dressing.
2. **KitLand on a bare crown.** Use `pillar(.., {"crown":"bare"})` and lay
   a KitLand turf top on it:

       KitLand.island({"outline": CityKit.crown_outline(a), "ground": flat 0,
                       "top": 0, "depth": COURSE*0.6, "hang": true, "tone": ...})

   The island's hanging sides tuck inside the top course. The gallery's
   first far pillar does this. A motif's own isle (KitLand, cliffs) can
   also sit on a pillar this way.

The generator places isles without turning them, so the climb face is set
by `climb`, not by rotation.

### `city_drum_stair` (ol_drum_stair)

- **Shape.** A stair wound down a round well as an inward spiral, with
  `radius` 6.5 CELL (28.6 m) and `turns` 2.
- **Each turn** goes COURSE down and LANE in, with a 0.4 m step every 30
  degrees. Nothing roofs any turn.
- **Every inner edge** stands one COURSE over the turn below it. Falling
  off the inside of a turn lands on the next turn, standing. Fallen into
  the last turn's inside, you land on the core floor.
- **The rim.** `rim` true builds its own rim ring. With `rim` false it is
  set in a pillar whose `well` equals its `radius`, as A is.
- **The core** holds a cresset mount.
- **Ports:** `rim`, `bottom`, `path`. `drum_at(turn, angle)` gives [y,
  inner, outer] for any point on it.

### `city_stair` (the epic stair)

- **Flights and landings.** `flights` (3) flights of 12 steps rise one
  COURSE each, LANE wide. LANDING-deep landings sit between flights and at
  the summit.
- **The serpent cheeks.** Each cheek is CHEEK (1.2 m) wide. Its crest runs
  a SET_OFF over the nosings (one jump's grab from the stair). Over each
  landing it is eased, so the rail is one unbroken slope. At the summit it
  is eased down into the summit at the stair's pitch.
  - At the foot, the crest runs onto a serpent head and leaves it off the
    snout. The head has an open jaw, fangs, heavy brows and a plume.
  - The crests are their own bodies, `Rail_L` and `Rail_R` (meta `rails`
    has their lines). Crouched on a crest, the motor boot-surfs down it,
    the existing rail-slide (the balustrade's way: no rider, only a steep
    narrow surface). The gallery counts them as rails.
- **The flank.** `flank` (2 CELL) either side is a stepped pyramid flank:
  a tier per course, talud under tablero, a glyph band on each tier.
- **`fault`** (a landing, 1-based):
  - That landing is four pre-cut quarter slabs over a chamber one COURSE
    deep. It is a `FloorBreak` unit.
  - The chamber's back wall has two walker-only set-off ledges up to the
    next flight.
- **Ports:** `foot`, `summit`, `summit_edge`, `landings`. Meta `length`
  (55.2 m) and `top` (14.4 m).

### `city_causeway`

- **Spans.** `spans` (4) spans of SPAN (6 CELL, 26.4 m) run from z 0
  toward -Z.
- **The deck** is two set-offs thick (a deep girder course for the
  silhouette), with glyph frets on the parapets and the deck's face. The
  parapets are a SET_OFF tall, 0.8 m wide and walked.
- **The piers.** Battered square piers, 1.5 CELL at the head, go `drop`
  (48 m) down into the haze. There are none at the ends: it rests on the
  isles it joins.
- **The corbels.** Three courses step out 1 m each from the pier heads, so
  the openings are a comb of stepped false arches, about 14 m clear at the
  top (the rune serpent's bore).
- **`bay`** (a span index): that span's middle third (two cells) is a
  `FloorBreak` of four slabs, each with its parapet run. It falls onto
  whatever road lies under it. The motif provides the lower road, and the
  bay meta names the span. Broken, it leaves an 8.8 m gap.
- **Ports:** `near`, `far`, `piers`.
- Cresset mounts sit on the parapet over each pier.

### Walk areas and ground cover

The coordinator's ask: every piece's meta `walk_areas` lists its walked
tops as `{kind, poly (x, z), y, y1}`. `CityKit.walk_areas(piece, kinds)`
gives them in world space.

| Piece | Kinds |
|---|---|
| Pillar | `crown` (a sector a face round a well), `collar` |
| Drum | `turn` (one a segment) |
| Stair | `landing`, `fault`, `summit`, `flight` (y to y1), `tier` |
| Causeway | `deck`, `bay`, `parapet` |

The gallery lays the underground ground cover on them: `GroundCover.cover`
from scripts/underground/ground_cover.gd, one cover a top, in the piece's
own frame. It covers crowns, landings, summits, decks and flank tiers.

- The cover is `--ground=dust` by default, or `grass`, `moss` or `off`.
  It's laid once, as the gallery stands.
- It doesn't go on the drum turns. Their coil reads best as bare stone
  under the dusted crown.
- It doesn't go on the breaking floors, the fault and the bay, or a cover
  would hang in the air where they were.
- `--no-cover` lays none.

## What he can and can't do on each

Read the planner's notes below first: the city taught it two rules.

| Piece | He can | He can't / won't |
|---|---|---|
| Pillar | walk the crown (round A's well: 8.8 m ring); climb any flank collar to crown | stand on a collar (1.6 m, under his shelf rule); use the prism chain (walker-only) |
| Drum | walk every turn up and down (8.8 m); drop a turn (4.8 m) | be roofed (nothing over him) |
| Stair | walk every flight and landing; drop into the broken fault's chamber and climb its 5.2 m back wall out | slide the crest |
| Causeway | walk the deck (9.4 m clear); fall with the bay; climb back from the road below and leap the 8.8 m gap | climb from under the deck up past the corbels (his planner now knows that) |

## Proof (through the real play loop)

These are throwaway drivers in `scratch/`, uncommitted, and all pass
headless.

**The wanderer, by real input** (`scratch/walker_city.gd`: stick, jump,
crouch as actions, the study's own loop):

- She runs the epic stair from foot to summit (12.5 s).
- She rail-slides the cheek crest from the summit to the foot and off the
  snout: 419 frames on the crest, top speed 10.3 m/s, from y 0 to C at
  -14.4.
- She crosses the causeway from the summit to A.
- She climbs A's collar chain from the lowest collar (y -14.4) to the
  crown: prism, prism, collar, three times.
- She steps off a drum turn's inside at 90°, 180° and 270°. Each time she
  falls 4.4 to 4.8 m, lands on the turn below, and isn't stunned.

**The Olmec** (`scratch/olmec_walk.gd`, his own think, rays, planner and
motor):

- `--olmec=stair`:
  - His body starts at the stair's foot, with his head on the summit.
  - He walks up flight 1, and the fault landing drops under him at 10.1 s:
    four slabs, dust, a hit-stop.
  - He drops into the chamber and climbs the back wall out at 18 s.
  - He walks on, and is whole at the summit at 39.2 s.
- `--olmec=causeway`:
  - His body starts on the summit, with his head at the causeway's far end.
  - The bay drops under him at 8.8 s, and he falls with it 14.4 m onto C.
  - His planner routes him back up onto the causeway's near third. He
    leaps the 8.8 m gap he made, crosses, and is whole at 87.8 s.
- `--olmec=causeway --no-bay`: he crosses whole and is whole at 51 s.
- `studies/headless_body_isle.tscn` with the planner change: the body gets
  whole at 114 s, against 115 s before it.

**Smoke checks, headless, 0 errors:**

- `studies/city_kit_gallery.tscn`
- `studies/run_layer.tscn`, twice (and `--shape=sprawl --seed=2` again after the last rebase):
  - `--shape=sprawl --seed=2`, before the last planner edit
  - `--shape=ring --seed=4 --underground=haze`, with the final code
- `studies/city_breaks_yard.tscn`
- `studies/headless_body_isle.tscn`

## His planner (scripts/enemies/body_routes.gd)

1. **No climbing out from under something.** A climb is planned only if
   nothing lies over the column he climbs from, up to the climb's top
   (`_face`: one ray up).
   - Before this, his planner sent him from C's crown up the pier and
     corbels under the causeway's far deck. That was an overhang, and he
     failed it again and again.
   - The headless body isle's greybox mesas overlap their neighbours'
     boxes. There, a column's base can be a buried floor inside the mesa.
     The ray starts inside the mesa and finds nothing, so those climbs are
     kept, as before.
2. **Merged from city breaks:** floors with under 0.5 m of room aren't read
   (`SLOT`).

**The kit's own rule:** nothing it collides is a solid stood on a walked
top. A buried top reads to his planner as a floor with all the room in the
world, because the room ray starts inside the stone. On this round's first
stair, that made a phantom lane through a cheek wall.

- The pillar collides as columns side by side: the crown and each collar
  ring, all down to the shaft's foot. The stair's flank does the same: a
  column per tier strip.
- A piece standing on another piece's top (the stair on C, a talud on its
  ring, a drum on the well floor) stops its collision `GAP` (0.2 m) over
  that top. The room under it reads 0.2, and SLOT drops it. GAP is never
  used between stacked walls: there, his climb read the slit as a lip.

## Stills

The stills are rendered with the study's camera pinned (`scratch/film_city.gd`).
They're in `captures/city/`, which is gitignored, and I looked at all of
them.

| File | What it shows |
|---|---|
| `arrival_{torch,haze}.png` | from C, the stair across the plaza |
| `summit_causeway_*.png` | the causeway from the summit to A |
| `causeway_side_*.png` | the piers and corbel comb from below |
| `drum_arrival_*.png` | stepping off the causeway onto A, the coil in the well |
| `collar_chain_*.png` | A's collars and the prism chain |
| `serpent_head_*.png` | the cheek's foot and its head |
| `far_*.png` | the stack of pillars in the haze |
| `*_haze.png`, the default look | the ground cover, dust |
| `*_haze_grass.png` | `--ground=grass` |
| `sheet_haze.png`, `sheet_torch.png` | contact sheets of the views |
| `olmec_stair_walk_haze.png` | the Olmec on the stair |
| `olmec_fault_break_haze.png`, `olmec_fault_fallen_haze.png` | the fault going |
| `olmec_fault_climb_haze.png` | him climbing out |
| `olmec_whole_summit_haze.png` | whole at the summit |
| `olmec_causeway_walk_haze.png`, `olmec_bay_break_haze.png`, `olmec_bay_fallen_haze.png` | the bay |
| `sheet_olmec_haze.png` | contact sheet of the Olmec stills |

What they show:

- **The haze look sells it.** The fluted pillars read as a stack of layers
  fading in umber haze, the stair as a stepped pyramid face, and the
  causeway as a long deck on a comb of stepped corbels. The fire bowls
  mark the lanes.
- **The torch look** is cooler and darker, and the forms still read.
- **The breaks read.** You see the dust, the slabs tipping into the
  chamber, and the gap in the deck with a slab going down.

## Models (docs/art/model-budget.md)

The models are procedural basalt blocks. There's no Blender model this
round.

**Triangles, measured.** The whole gallery is about 30.3k stone triangles.
The ground cover adds its skins and the tufts' instances, tile-faded.

| Piece | Triangles | Shapes | Build |
|---|---|---|---|
| Pillar A (well) | 4.7k | 67 | 30 ms |
| Pillar C (44 m) | 4.2k | 43 | 24 ms |
| Far pillar | 2.6k | 45 | 15 ms |
| Drum stair | 1.1k | 73 | 6 ms |
| Epic stair | 4.1k | 76 | 21 ms |
| Causeway | 5.3k | 56 | 27 ms |

How each trick applies:

- **Import LODs and visibility ranges:** apply most.
  - A far pillar is its shaft and pipes: a coarse hex tube with no pipes or
    runes past about 120 m would cut it to about 300 triangles, saving
    about 85% of its triangles.
  - The causeway's parapet runs and frieze quads at range, about 40%.
  - The runes surface could take a visibility range past about 60 m:
    about 0.05 ms and a draw per piece.
  - All told, about 10k triangles and 0.1 to 0.2 ms in the gallery's far
    view.
  - Not done this round: the pieces are one mesh each.
- **Silhouette geometry:** already used. Chips on block corners, the
  pipes' broken tops and the corbel steps are real outline. Detail
  otherwise comes from the shader.
- **Vertex-colour grime:** already used. Foot occlusion and tone are in
  COLOR, at no cost.
- **Sculpt high, bake low:** applies to the serpent head only. A carved
  head (about 6 to 8k triangles baked from a 60k sculpt) would replace
  today's 14 blocks (about 200 triangles). That costs triangles, but the
  head would look right. It's the hero detail to model next.
- **Parallax depth:** optional, for the glyph grooves. About 0.1 ms. Not
  done.
- **Rigid parts on bones:** don't apply.

## Limits

- **The serpent heads** are blocky (14 chamfered blocks). They read as a
  carved beast's head with an open jaw, but they're not Nintendo-beautiful.
  A Blender sculpt is the next step.
- **The drum's flights are broad terraces.** There's a 0.4 m step every 30
  degrees, which on a 28.6 m well is a step about every 9 to 12 m. It
  reads as a coil from above but not as an epic stair close up.
- **The drum doesn't lead out of the well.** Its bottom is a core floor
  with a fire bowl. The door onto a collar from k7's card isn't built.
- **No deep shelves on the pillar.** The collars are all 1.6 m. k7's 6 m
  inside sectors aren't built, so he never stands mid-flank.
- **Stair and drum have no parapets** on their inner edges. The fall
  inward is the point.
- **Fire bowls are omni lights without shadows.** Shadowed lights under the
  torch preset's volumetric fog stalled the renderer at about 4 s a frame
  when many were in view (about 40 bowls), so none cast shadows.
- **The drum turns and the breaking floors are bare stone** under the
  ground cover (see "Walk areas and ground cover").
- **A rendered still run stalled** at about 4 s a frame twice: once in the
  haze look with no shadowed lights, and once in the torch look before the
  bowls' shadows went. The same run then passed in 8 s. It's intermittent
  and unexplained. The other cause may be the window or the shot lock, not
  the scene.
- **Breaks are permanent.** R doesn't restore them. The pieces stay as
  their own meshes, not merged: 4 per break, a handful of draws.
- **The bay falls only onto what the motif puts under it.** Over the void,
  the slabs and he fall out of the world.
- **Rail mounting.** The rail is mounted from the summit (the crest eases
  into it) or by a jump-grab from the stair. Hopping on mid-flight needs
  the grab.
- **The headless body is homing in both proofs.** The whole Olmec's chase
  isn't tested on these pieces.
- **FootPieces leaks.** `scripts/interactables/foot_pieces.gd` leaks
  objects at exit (seen alone in a smoke). The gallery counts its rails
  itself rather than using it. That's not fixed here.

## Tests

None were run or added (prototyping). The planner change (`_face`) touches
every Olmec route, but no committed test covers `body_routes.gd`. I know of
no test it breaks; that's unverified. `test_ruin_kit.gd` doesn't load the
city kit.

## Open questions

- Dust or grass for the city by default? `arrival_haze_grass.png` and
  `drum_arrival_haze_grass.png` show grass, and the others show dust.
- Should the drum stair get the door onto a collar? It would be a tunnel
  under its top turn.
- Is the 8.8 m lane right for his look? It's wider than the cards' 5 to
  6.6 m, and his bulk forced it.
- Should the serpent head be a Blender sculpt?
