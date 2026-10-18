extends RefCounted
## The gothic ruin kit: the pieces the lower world's ruins will be put
## together from (aqueducts, stairways to the clouds, colonnades, towers), in
## a darker, romantic gothic: an abbey in the oak wood, centuries after the
## roof fell in. Weathered charcoal stone with an umber or a cool cast (never
## the peaks' black basalt, scripts/rock_looks.gd), clustered piers under
## leafy capitals, pointed arches of moulded orders, tall lancets and a rose
## window with their tracery broken, stepped buttresses under pinnacles, a
## turret's stair winding up past its broken shell, vault ribs breaking off
## in mid-air, ivy hanging down the faces. Nothing is placed in the world
## here; the gallery (studies/ruin_kit_gallery.tscn) shows them.
##
## Every block is one convex solid cut by planes (`Build.solid`): a box with
## its arrises worn off unevenly, a prism, a voussoir, then the weathering's
## own cuts (chips, a missing chunk, a ragged break) as more planes, so each
## face is one flat facet, coloured face by face and lit as the folk are
## (shaders/ruin_stone.gdshader). Each block is its own convex collision
## hull, but a stair's: its treads and cheeks walk on clean, true boxes
## (`_walk_box`, `_walk_hull`), so no joint or worn edge is a gap. Ivy and moss are faceted too: small cut leaf clumps strung down the
## faces and low cushions on the tops, never collided.
##
## Never new-built: even at `weathered` 0 the stone is centuries old (AGE):
## courses uneven, blocks out of true, lines sagging, arrises worn round in
## facets, corners chipped, stains running down in bands, lichen, moss and
## a little ivy. At 1 it is a melancholy ruin: tracery broken, spans fallen,
## walls torn down to ragged lines, rubble in drifts at their feet and ivy
## draped heavy over the heads of walls and hanging from the arches. Never
## so ruined that a piece stops being what it is: an arch keeps its opening,
## a stair its steps.
##
## Each piece is a static func taking a seed and `weathered` (0 to 1) and
## giving a Node3D, its foot on y 0 round the origin, its front toward +Z:
## "Mesh" (stone and growth, one surface) and "Body", a StaticBody3D of the
## blocks' hulls. `piece` builds one by its PIECES id. No ornament glows:
## the ruins are stone and growth only.
##   ./run-ruin-kit.command

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const STONE_SHADER = preload("res://shaders/ruin_stone.gdshader")
## The growth's own surface and wind (docs/scenic/ruin-overgrowth.md).
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
## The stone's look (classic, or a clean one: docs/scenic/ruin-stone.md).
const Style = preload("res://scripts/ruin_stone_style.gd")
const NativeIsleKernels = preload("res://scripts/native_isle_kernels.gd")

## The pieces, in the kit's order: the gothic abbey's, here.
const PIECES := ["pier","arch","lancet_wall","rose_gable","buttress","wall","stairs","turret","vault","fallen_pier","tomb_chest","floor","grand_stair","stone_circle"]
## The families: the gothic abbey (here), the aqueduct (scripts/
## ruin_kit_aqueduct.gd) and the colossus hall (scripts/ruin_kit_hall.gd),
## each its pieces in order; ALL_PIECES the lot.
const AQUEDUCT_PIECES := ["aqueduct_span","aqueduct_two_tier","aqueduct_broken","aqueduct_stump","aqueduct_end"]
const HALL_PIECES := ["hall_column","hall_beam","hall_slab","hall_bay"]
## The tower (scripts/ruin_kit_tower.gd): the broken shell with a wall-kick
## chimney inside.
const TOWER_PIECES := ["tower_shell"]
## The wind-horn (scripts/ruin_kit_horn.gd): the pedestal and its turning head.
const HORN_PIECES := ["wind_horn"]
## The cloister's pieces built by id (scripts/ruin_kit_cloister.gd): the
## pent hood (a lean-to roof over a hidden gallery).
const CLOISTER_PIECES := ["pent_hood"]
## The relics built by id (scripts/ruin_kit_relic.gd): fragments of
## colossal sacred works, the broken nimbus (a halo on edge).
const RELIC_PIECES := ["relic_nimbus"]
## The keel's pieces (scripts/ruin_kit_keel.gd): what hangs under an isle,
## the hung stair (a flight turned on a hinge by a slam on its boss).
const KEEL_PIECES := ["keel_hung_stair"]
## The relic family's prayer lintel (scripts/ruin_kit_torana.gd): a gate's
## jamb and tilted lintel, its swing ropes carried as meta.
const TORANA_PIECES := ["relic_torana"]
const FAMILIES := {"gothic":PIECES,"aqueduct":AQUEDUCT_PIECES,"hall":HALL_PIECES,"tower":TOWER_PIECES,"horn":HORN_PIECES,"cloister":CLOISTER_PIECES,"relic":RELIC_PIECES+TORANA_PIECES,"keel":KEEL_PIECES}
const ALL_PIECES := PIECES+AQUEDUCT_PIECES+HALL_PIECES+TOWER_PIECES+HORN_PIECES+CLOISTER_PIECES+RELIC_PIECES+TORANA_PIECES+KEEL_PIECES
const NAMES := {"pier":"Clustered pier","arch":"Pointed arch","lancet_wall":"Lancet window wall",
	"rose_gable":"Rose window gable","buttress":"Buttress","wall":"Wall","stairs":"Stair flight",
	"turret":"Stair turret","vault":"Vault ribs","fallen_pier":"Fallen pier","tomb_chest":"Carved chest",
	"floor":"Floor slabs","grand_stair":"Grand stair","stone_circle":"Stone circle",
	"aqueduct_span":"Aqueduct span","aqueduct_two_tier":"Two-tier span","aqueduct_broken":"Broken span",
	"aqueduct_stump":"Pier stump","aqueduct_end":"Aqueduct head",
	"hall_column":"Colossus column","hall_beam":"Architrave beam","hall_slab":"Roof slabs",
	"hall_bay":"Hall bay","tower_shell":"Tower shell","wind_horn":"Wind-horn",
	"pent_hood":"Pent hood","relic_nimbus":"Broken nimbus","keel_hung_stair":"Hung stair","relic_torana":"Prayer lintel"}

# --- Scale: what the pilot on foot and the plane can do drives these ---------
# (scripts/pilot_motor.gd, scripts/plane_figure.gd, scripts/sky_glide.gd)

## The pilot's body radius (scripts/wanderer_eye.gd RADIUS). A climb sets him
## down CLIMB_IN from the lip with his body behind that, so a tread or ledge
## meant to be climbed onto is at least STAND deep; a top meant to be walked
## along, TOP_ROOM across (room either side).
const BODY := 0.28
const STAND := PilotMotor.CLIMB_IN+BODY
const TOP_ROOM := 2.0*STAND
## The highest lip one plain jump catches: the first jump's height (JUMPS[0]
## 0.8) plus the hands over the feet hanging (HANG_DROP) plus the slack under
## the lip a catch allows (GRAB_LOW): 1.875. The pump, jumped again on
## landing (JUMPS[1] 1.5), catches CHAIN_TOP, 2.575.
const GRAB_TOP := 0.8+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
const CHAIN_TOP := 1.5+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
## The rise between one standing place and the next on a climbing route (a
## buttress's set-offs, a vault wall's broken steps), a margin under GRAB_TOP.
const SET_OFF := 1.6
## A step's rise and going: under STEP_UP (0.45) with room for a weathered
## step's settling, so a flight is walked; a comfortable stride for a pilot
## about 1.1 m tall. Carried over from the pale kit, as its flight was liked.
const RISER := 0.28
const TREAD := 0.5
const STEPS := 8
const STAIR_WIDTH := 2.0
const LANDING := 1.0
## The cheek walls (the stair's ramped stringers): thickness, height over the
## nosings; the newel post at their foot.
const CHEEK := Vector2(0.42,0.34)
const NEWEL := Vector2(0.56,0.95)
## A plain wall: over GRAB_TOP and under CHAIN_TOP (the pump catches
## it; broken, its low runs are caught with one jump), thick enough to walk.
const WALL_HEIGHT := 2.4
const WALL_THICK := 1.2
const WALL_LENGTH := 5.2
## The plinth course at a wall's foot: its height (under STEP_UP: stepped
## onto) and how far it stands out.
const PLINTH_COURSE := Vector2(0.4,0.16)
## The openings the plane flies through keep their toy-era widths in
## wingspans (scripts/world_scale.gd `opening`: toy width x plane x RATIO,
## 1.8x at the defaults); static vars, read once. At `--plane-scale=1
## --opening-ratio=1` each is its toy width.
## The least clear width of an opening meant to be flown through: toy 3.5
## (2.5 spans), 6.3 at the defaults (1.75 m past each wingtip).
const TOY_THREAD := 3.5
static var THREAD: float = WorldScale.opening(TOY_THREAD)
## The pointed arch: clear span (toy 4.2, 3.0 spans: 7.56 at the
## defaults), the springing (capital tops: the walker's, kept) and the
## arc's radius as a share of the span (1 is equilateral). Its crown stands
## SPRING + ARCH_SPAN*0.866 (9.75 at the defaults): it rises with the width.
const TOY_ARCH_SPAN := 4.2
static var ARCH_SPAN: float = WorldScale.opening(TOY_ARCH_SPAN)
const SPRING := 3.2
const ARCH_PITCH := 1.0
## The arch's buttresses: their face out from the pier's middle, and their
## foot's depth out from that face.
const ARCH_BUTTRESS := Vector2(0.45,2.35)
## The arch's moulded orders: each order's radial depth, the inner one set
## back RECESS from the faces, and the hood mould over them.
const ORDER := 0.32
const RECESS := 0.17
const HOOD := Vector2(0.13,0.1)
## The thickness of an arch, a window wall or a gable.
const ARCH_DEPTH := 1.1
## The lancet window: clear width (two lights under one head; with its
## mullion gone, flown: toy 3.6, 2.6 spans, 6.48 at the defaults), sill
## height (caught from the ground; the sill as deep as the wall, STAND and
## more) and springing; its head equilateral. The wall round it is as much
## wider than the toy's 6.8 and taller than its 7.8 by the head's rise on
## that (WINDOW_GROW).
const TOY_WINDOW := 3.6
static var WINDOW := Vector3(WorldScale.opening(TOY_WINDOW),1.6,3.4)
static var WINDOW_GROW: float = WINDOW.x-TOY_WINDOW
static var WINDOW_WALL := Vector2(6.8+WINDOW_GROW,7.8+WINDOW_GROW*0.866)
## The rose: its centre's height, outer radius (frame included) and the
## frame's radial depth; the glass circle within is TOY_ROSE (3.96 m)
## across in the toy era, an opening (7.13 at the defaults) flown with its
## spokes gone. The rose and the gable round it are the toy ones grown by
## ROSE_GROW (the gable 8.4 wide, 10.6 to its apex, the rose's centre 6.6
## up); the door under them stays.
const TOY_ROSE := 3.96
static var ROSE_GROW: float = maxf(1.0,WorldScale.opening(TOY_ROSE)/TOY_ROSE)
static var ROSE := Vector3(6.6*ROSE_GROW,2.4*ROSE_GROW-0.42*(ROSE_GROW-1.0),0.42)
## The gable: width, the height of its eaves, its apex.
static var GABLE := Vector3(8.4*ROSE_GROW,5.2*ROSE_GROW,10.6*ROSE_GROW)
## The door under the rose: clear width, springing.
const DOOR := Vector2(2.0,1.8)
## The clustered pier: the core's apothem, the four main shafts' and the
## four lesser ones' and how far out they stand; the sub-base (a step, under
## STEP_UP) and its half width (the pier's foot stood round on: STAND
## outside the shafts).
const PIER_CORE := 0.36
const SHAFT_MAIN := Vector2(0.15,0.41)
const SHAFT_LESSER := Vector2(0.09,0.43)
const SUB_BASE := Vector2(0.4,1.2)
## The capital's abacus apothem: TOP_ROOM across and more.
const ABACUS := 0.68
## The buttress's stages: each SET_OFF higher than the last, each tread
## STAND and more (from the face out, m).
const BUTTRESS_DEPTH := [3.0,1.95,0.95]
const BUTTRESS_WIDTH := 1.3
## The stair turret: outer and inner apothem (octagon), the newel's radius,
## steps a turn (each RISER), turns.
const TURRET := Vector3(1.95,1.42,0.22)
const TURRET_STEPS := 12
const TURRET_TURNS := 1.5
## The vault fragment: the bay's side (m), springing, the walls' stepped
## heights from the corner out (each SET_OFF or less over the next).
const BAY := 4.4
const VAULT_SPRING := 3.6
const VAULT_STEPS := [4.2,2.75,1.4]
## The chest: length, width, height (caught with a jump), lid thickness.
const CHEST := Vector4(2.3,1.05,0.95,0.2)
## Floor slabs: the patch's side, a slab's rough size, thickness (stepped on).
const FLOOR := Vector3(4.2,0.85,0.2)
## The grand stair: two of the stair's flights (STEPS each) one above the
## other, GRAND_WIDTH wide, a landing GRAND_LANDING deep between them; its
## head 2 STEPS RISERs up (4.48 m), onto a terrace or a hill's top.
const GRAND_WIDTH := 4.4
const GRAND_LANDING := 2.0
## The grand stair's own steps, finer than a flight's (a ceremonial way for
## folk about 1.1 m tall, not a giant's): GRAND_STEPS a flight, to the same
## head (2 STEPS RISERs, 4.48 m), each GRAND_RISER by GRAND_TREAD.
const GRAND_STEPS := 12
const GRAND_RISER := 2.0*STEPS*RISER/(2.0*GRAND_STEPS)
const GRAND_TREAD := 0.42
## How far a stair's walked boxes run on past its flight's back (m), under
## the next flight's foot or into what it climbs to, so flights meet seamless.
const WALK_OVERLAP := 0.05
## The stone circle: its sarsens, the gap the plane flies between two
## (at their inner faces) and the ring's radius (to its stones' middles)
## that gap sets: 9.3 at plane 2, 8 sarsens. The toy era's circle (14
## sarsens 1.7 wide, TOY_HENGE 2.1 m gaps) wasn't flown, so the gap is the
## wider of SNUG's (1.2 m past each wingtip, 5.2 at plane 2) and the toy
## gap's opening (4.2 at the defaults, floored): 5.2. A sarsen's width
## along the ring, height and thickness (over CHAIN_TOP: climbed by the ways the circle gives, not
## from the floor); the lintels' depth across the ring (TOP_ROOM and more:
## the ring is run round on them) and thickness. A lintel stands LINTEL.y
## over the bare top of a sarsen whose other lintel fell.
## The sarsens stand as tall as the toy era's in wingspans (an opening on
## its 3.4 m, scripts/world_scale.gd: 6.12 at the defaults), so the plane
## passes under the lintels with the toy's vertical feel; HENGE_GROW how
## much taller, and they grow a little chunkier with it (1.6 by 1.25 m at
## the defaults; the toy's 1.5 by 1.1).
const CIRCLE_STONES := 8
const TOY_SARSEN := Vector3(1.5,3.4,1.1)
static var HENGE_GROW: float = WorldScale.opening(TOY_SARSEN.y)/TOY_SARSEN.y
static var SARSEN := Vector3(TOY_SARSEN.x*(1.0+0.08*(HENGE_GROW-1.0)),TOY_SARSEN.y*HENGE_GROW,TOY_SARSEN.z*(1.0+0.17*(HENGE_GROW-1.0)))
const LINTEL := Vector2(1.3,0.6)
const HENGE_ROOM := WorldScale.SNUG
const TOY_HENGE := 2.1
static var HENGE_GAP: float = maxf(WorldScale.gap(HENGE_ROOM),WorldScale.opening(TOY_HENGE))
static var CIRCLE_RADIUS: float = (HENGE_GAP+SARSEN.x)/(2.0*sin(PI/CIRCLE_STONES))+SARSEN.z*0.5
## A fallen lintel breaks in its middle: a piece LINTEL_BREAK long drops
## into the grass and the two ends stay on their sarsens, out over the gap,
## so the ring is still run round with a twirled jump over the break (the
## walker's, scaled with him). A lintel whose sarsen went (`missing`)
## leaves the same end on the sarsen still standing.
static var LINTEL_BREAK: float = 3.0*WorldScale.wanderer
## The great trilithon across the back of the ring: an upright's width,
## height (the toy's 4.6 m grown as the sarsens: 8.28 at the defaults) and
## thickness, the slot between the pair (a window along the circle's axis,
## flown on a knife edge: WorldScale.knife), its middle's distance in from
## the ring's middle (its lintel TRILITHON_IN in from the ring's back
## lintel and over it: a jump-catch at the toy's 1.2 m, a pumped one, 2.16
## m, at the defaults: the circle's summit).
## Its height over the sarsens never past TRILITHON_RISE (a pumped catch,
## CHAIN_TOP and a margin: 2.16 m at ratio 0.9 was caught, 2.28 at 0.95
## wasn't), so a bigger ratio keeps the summit a jump from the back lintel.
const TOY_TRILITHON := Vector3(1.8,4.6,1.2)
const TRILITHON_RISE := CHAIN_TOP-0.45
static var TRILITHON := Vector3(TOY_TRILITHON.x,minf(TOY_TRILITHON.y*HENGE_GROW,SARSEN.y+TRILITHON_RISE),TOY_TRILITHON.z)
static var TRILITHON_SLOT: float = WorldScale.knife()
const TRILITHON_IN := 2.29
static var TRILITHON_AT: float = CIRCLE_RADIUS*cos(PI/CIRCLE_STONES)-TRILITHON_IN
## The fallen trilithon: its stub's height (STUB_UNDER under the ring's lintels'
## top, by the lintel STUB_AT's middle: 2.5 in the toy era), its partner
## lying in toward the middle (its top caught from the floor, the stub's
## from it; the taller stub's broken-off pieces lie stacked on the lying
## stone's end as steps between, each 1.5 m and under: `stone_circle`).
static var STUB: float = SARSEN.y+LINTEL.y-STUB_UNDER
## How far under the lintels' top the stub stands.
const STUB_UNDER := 1.5
## How far in from the lintels' inner face the stub stands (m): a hop out
## and up onto the lintel from its top (0.25 was a near miss at ratio 1).
const STUB_OFF := 0.25
## How far in from its inner edge the stub's top is broken off (m): kept
## small so the run-up for the hop out onto the lintel is on its flat top.
const STUB_CORNER := 0.2
const STUB_AT := 4
## The most a step up the fallen trilithon's broken pieces rises: a jump
## caught a quarter metre under the walker's catch top (GRAB_TOP).
const STUB_STEP := GRAB_TOP-0.25
## The leaning stone: a sarsen fallen in against the ring's upright LEAN_AT,
## its width and thickness, the slope of its top (walked up, surfed down:
## the toy's 30°, steeper as the sarsens grow, 40° at the defaults, under
## the walker's 44° so it is still walked) and how high its head rests
## against the upright: 0.75 m under the lintels' top (3.25 in the toy
## era, a jump-catch onto them), but never reaching further in than the
## toy's (LEAN_REACH: a longer one would lie across the ring's middle), so
## 4.72 at the defaults, with a block on its head (LEAN_BLOCK) the step up
## to the lintels.
const LEAN_REACH := 3.25/0.57735
static var LEAN := Vector3(1.5,0.8,30.0+12.5*(HENGE_GROW-1.0))
static var LEAN_TOP: float = minf(SARSEN.y+LINTEL.y-0.75,LEAN_REACH*tan(deg_to_rad(LEAN.z)))
## Where LEAN_TOP is under the toy's jump-catch, a block lies wedged on the
## lean's head against the upright, this deep: its top the step between.
const LEAN_BLOCK := 0.9
const LEAN_AT := 1
# --- Look --------------------------------------------------------------------

## The stone (sRGB): an umber charcoal gritstone and a cool slate-grey one,
## each piece somewhere between. Both darker than the earlier kits, warmer
## or bluer and far lighter than the peaks' basalt, so the facets still part
## by day.
const STONE := Color("59534d")
const STONE_COOL := Color("50545a")
## How far a block's tone wanders from its stone, and a face's from its
## block (each half either way).
const BLOCK_TONE := 0.2
const FACETS := 0.12
## Worn arrises and chips, the small faces, go toward this paler, dustier
## stone (EDGE_MIX of the way, more with age).
const EDGE := Color("8e887e")
const EDGE_MIX := 0.2
## Stains: dark bands running down the vertical faces (the noise's
## STREAK_SCALE bands a metre), up to STREAK darker; the soot-dark of the
## oldest runs.
const STREAK := 0.32
const STREAK_SCALE := 1.3
## The damp foot, darker, up to DAMP_RISE m; undersides darker.
const DAMP := 0.7
const DAMP_RISE := 1.1
const UNDER := 0.72
## Lichen: pale and ochre, the odds a face takes it.
const LICHEN := [Color("8e9180"),Color("8d7f5c"),Color("7f887a")]
const LICHEN_ODDS := 0.05
## Grass tufts at the feet of things (Build `tuft`): the gallery plate's
## darker olive greens.
const GRASS := [Color("4c6136"),Color("56693a"),Color("44582f"),Color("5f7240")]
## Moss on what looks up (sRGB), and its cushions.
const MOSS := Color("374726")
const MOSS_LIGHT := Color("4e612e")
const MOSS_UP := 0.5
const MOSS_SCALE := 0.8
## The moss a top has at weathered 0 (centuries old) and what it gains.
const MOSS_AGE := 0.14
const MOSS_COVER := 0.45
const CUSHION := Vector2(0.08,0.22)
## Ivy: its leaves' greens, from deep shade to sunlit, the leaf clumps' size
## (m), strands per m² of high top at weathered 0 and at 1, and the longest
## a strand hangs at either.
const IVY := [Color("23361f"),Color("2d4526"),Color("36532b"),Color("44622f"),Color("587a38")]
const IVY_LEAF := Vector2(0.15,0.27)
const IVY_STRANDS := Vector2(0.2,1.3)
const IVY_LENGTH := Vector2(0.9,4.2)
const IVY_MOST := 46
## Lean stone's cap (Build `lean`: the halls, built by the dozen).
const IVY_LEAN := 8
## The stone every piece has at weathered 0: AGE of the way to ruined in
## the wearing of its arrises and the wobble of its faces.
const AGE := 0.32
## The arrises' worn chamfer (m) and how much further age takes it.
const CHAMFER := 0.045
const ARRIS := 1.4
## Weathering: a face's wobble (radians, at none and at full), corner chips
## per block (as old, and more at full), their depth (share of the block's
## least half size), the odds of a chunk gone and its depth, a block's tilt
## (radians) and shift (m) out of true, as built and at full ruin.
const WOBBLE := Vector2(0.014,0.05)
const CHIPS := Vector2(1.2,4.0)
const CHIP := Vector2(0.12,0.42)
const CHUNK_ODDS := 0.3
const CHUNK := Vector2(0.12,0.34)
const TRUE_OFF := Vector2(0.02,0.055)
const SHIFT := Vector2(0.01,0.05)
## The sag of a long course (m at its middle), as old and at full ruin.
const SAG := Vector2(0.03,0.09)
## The thinnest block given a collision hull (m): Jolt's convex shapes need
## a real volume (its margin is 0.04), and a sliver walks like the block
## beside it anyway.
const HULL_THIN := 0.06
## Hidden-face culling (Build `cull`): how far off a face its probes stand
## (m; a joint thinner than this is closed) and the occluders' grid (m).
const CULL_OFF := 0.03
const CELL_CULL := 2.0
## How near two stones (or a stone and the ground) count as touching, for
## the floating-stone check (Build `floating`).
const FLOAT_TOUCH := 0.2
## The most stones a group resting on nothing may have and still count as
## loose (in a piece that doesn't drop its floaters).
const FLOAT_MOST := 3


## The piece with PIECES id `id`, its recipe kept as meta "kit_piece"
## ([id, seed, weathered]: a break, scripts/kit_isle/kit_breaks.gd, builds
## it again in parts from it).
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	var node := _piece_of(id,seed_value,weathered)
	if node != null: node.set_meta("kit_piece",[id,seed_value,weathered])
	return node

static func _piece_of(id: String, seed_value: int, weathered: float) -> Node3D:
	match id:
		"pier": return pier(seed_value,weathered)
		"arch": return arch(seed_value,weathered)
		"lancet_wall": return lancet_wall(seed_value,weathered)
		"rose_gable": return rose_gable(seed_value,weathered)
		"buttress": return buttress(seed_value,weathered)
		"wall": return wall(seed_value,weathered)
		"stairs": return stairs(seed_value,weathered)
		"turret": return turret(seed_value,weathered)
		"vault": return vault(seed_value,weathered)
		"fallen_pier": return fallen_pier(seed_value,weathered)
		"tomb_chest": return tomb_chest(seed_value,weathered)
		"floor": return floor_slabs(seed_value,weathered)
		"grand_stair": return grand_stair(seed_value,weathered)
		"stone_circle": return stone_circle(seed_value,weathered)
	# The other families, loaded when asked for (they build on this script).
	if id in AQUEDUCT_PIECES: return load("res://scripts/ruin_kit_aqueduct.gd").piece(id,seed_value,weathered)
	if id in HALL_PIECES: return load("res://scripts/ruin_kit_hall.gd").piece(id,seed_value,weathered)
	if id in TOWER_PIECES: return load("res://scripts/ruin_kit_tower.gd").piece(id,seed_value,weathered)
	if id in HORN_PIECES: return load("res://scripts/ruin_kit_horn.gd").piece(id,seed_value,weathered)
	if id in CLOISTER_PIECES: return load("res://scripts/ruin_kit_cloister.gd").piece(id,seed_value,weathered)
	if id in RELIC_PIECES: return load("res://scripts/ruin_kit_relic.gd").piece(id,seed_value,weathered)
	if id in KEEL_PIECES: return load("res://scripts/ruin_kit_keel.gd").piece(id,seed_value,weathered)
	if id in TORANA_PIECES: return load("res://scripts/ruin_kit_torana.gd").piece(id,seed_value,weathered)
	return null

## How thick a hull's points stand at their thinnest (m): their spread
## along the least axis of their scatter (the covariance's smallest
## eigenvector), 0 for a flat or degenerate one. Jolt cannot build a convex
## shape from a sliver, so a block thinner than HULL_THIN gets no hull.
static func hull_thickness(points: PackedVector3Array) -> float:
	return Build.thickness(points)

## How much of the small growth and scatter pieces are built with from
## now on: 1 (the default) all of it; 0.5 about half the ivy, moss
## cushions, tufts and rubble; 0 none. The stone itself, its wear and its
## collision never change, so a cheap or far ruin is the same ruin; a LOD
## pass can build a piece at two details and swap them by distance.
static func set_detail(amount: float) -> void:
	Build.detail = clampf(amount,0.0,1.0)

## Merges the stone of `root`'s built children (each a piece: "Mesh" and
## "Body") into one "Mesh" of one surface and one "Body" on `root`, so a
## run or a long hall draws as one mesh and collides as one body; the
## children stay (as empty frames, with their water, spill and metadata).
## A later LOD pass can swap the merged mesh as a whole. Safe on a worker:
## a built mesh keeps its arrays (meta "arrays") so they are never read
## back from the renderer; `forget_arrays` lets them go once merged.
static func merge(root: Node3D) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var growth := RuinGrowth.Faces.new()
	var body := StaticBody3D.new()
	body.name = "Body"
	for child in root.get_children():
		if not child is Node3D: continue
		var xf: Transform3D = (child as Node3D).transform
		var mesh := child.get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var arrays: Array = mesh.mesh.get_meta("arrays") if mesh.mesh.has_meta("arrays") else mesh.mesh.surface_get_arrays(0)
			var mv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var mn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var mc: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in range(mv.size()):
				v.append(xf*mv[i])
				n.append((xf.basis*mn[i]).normalized())
			c.append_array(mc)
			var grown := RuinGrowth.arrays_of(mesh.mesh)
			if not grown.is_empty(): RuinGrowth.append(growth,grown,xf)
			mesh.free()
		var old := child.get_node_or_null("Body")
		if old != null:
			for holder in old.get_children():
				var shape := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
				var points := PackedVector3Array()
				for p in shape.points: points.append(xf*p)
				var moved := ConvexPolygonShape3D.new()
				moved.points = points
				var h := CollisionShape3D.new()
				h.shape = moved
				body.add_child(h)
			old.free()
	if v.is_empty(): return
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = v
	surface[Mesh.ARRAY_NORMAL] = n
	surface[Mesh.ARRAY_COLOR] = c
	var merged := ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
	merged.set_meta("arrays",surface)
	merged.surface_set_material(0,materials().stone)
	RuinGrowth.add_surface(merged,growth)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = merged
	root.add_child(instance)
	root.move_child(instance,0)
	root.add_child(body)

## Lets go of the arrays a built ruin's meshes keep for `merge` (its own
## "Mesh" and its children's).
static func forget_arrays(root: Node) -> void:
	for node in [root]+root.get_children():
		var mesh := (node as Node).get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.mesh.has_meta("arrays"): mesh.mesh.remove_meta("arrays")
		if mesh != null and mesh.mesh != null and mesh.mesh.has_meta("growth_arrays"): mesh.mesh.remove_meta("growth_arrays")

## The triangles a built ruin draws (its own "Mesh" and its children's).
static func triangles(root: Node) -> int:
	var count := 0
	for node in [root]+root.get_children():
		var mesh := (node as Node).get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or mesh.mesh == null: continue
		for s in range(mesh.mesh.get_surface_count()): count += mesh.mesh.surface_get_array_len(s)/3
		# Growth lifted out into chunks under it (scripts/ruin_lod.gd).
		for part in mesh.get_children():
			if part is MeshInstance3D and (part as MeshInstance3D).mesh != null and part.name == &"Growth":
				for s in range((part as MeshInstance3D).mesh.get_surface_count()): count += (part as MeshInstance3D).mesh.surface_get_array_len(s)/3
	return count

## The shared materials: {stone, growth}.
static func materials() -> Dictionary:
	return Build.materials()

# --- The pieces -----------------------------------------------------------------

## 1. A clustered pier: a sub-base step, a moulded base, a core with four
## main and four lesser shafts bundled round it in drums, a shaft-ring, and
## a bell capital wreathed in faceted leaves under an octagonal abacus.
## Weathered, it is snapped off partway with a ragged head, its drums
## slipped, the capital and upper drums lying in a drift at its foot (a way
## up to its head).
static func pier(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Pier")
	var broken := INF
	if weathered > 0.2: broken = lerpf(SPRING-0.3,1.6,clampf(weathered*b.rng.randf_range(0.7,1.1),0.0,1.0))
	var lean := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.004,0.012)+0.03*weathered)
	_pier(b,Transform3D(lean,Vector3.ZERO),SPRING,broken)
	if broken < INF:
		# What fell: the capital tipped on its side and a drum or two.
		var at := Vector3(b.rng.randf_range(1.4,1.9),0.0,b.rng.randf_range(0.6,1.4))
		var tip := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(1.2,1.6))
		_capital(b,Transform3D(tip,at+Vector3(0.0,ABACUS*0.8,0.0)))
		_drift(b,Vector3(-1.2,0.0,0.9),1.0,3+int(weathered*3.0))
		for i in range(1+int(b.rng.randf() < 0.6)):
			var lie := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,PI*0.5)
			_drum_cluster(b,Transform3D(lie,Vector3(b.rng.randf_range(-1.8,-0.9),0.5,b.rng.randf_range(-1.6,-0.8))),0.62,[])
	_rubble(b,1.5,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## The pointed arch's footprint on its ground, about its middle: half its
## width (buttress toe to toe, so it grows with ARCH_SPAN) and half its depth
## (the buttresses' or the piers' sub-base, the wider).
static func arch_foot() -> Vector2:
	return Vector2(ARCH_SPAN*0.5+ORDER+ARCH_BUTTRESS.x+ARCH_BUTTRESS.y,maxf(BUTTRESS_WIDTH,SUB_BASE.y)*0.5)

## 2. A pointed arch on two clustered piers: equilateral, of two moulded
## orders under a hood mould, the spandrels coursed up into a steep gable
## over it; stepped buttresses either side give the way up to the
## springing. Weathered, the gable is torn down to a ragged line, the outer
## order and hood half gone, the crown fallen on one side, rubble below;
## the opening stays clear.
static func arch(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Arch")
	b.drop_floating = true
	var h := ARCH_SPAN*0.5
	var d := ARCH_DEPTH*0.5
	var radius := ARCH_SPAN*ARCH_PITCH
	var ring := ORDER*2.0
	var px := h+ring*0.5
	for side: float in [-1.0,1.0]:
		_pier(b,Transform3D(Basis.IDENTITY,Vector3(side*px,0.0,0.0)),SPRING,INF,false)
		# The buttress at its outer side, stepped up to the springing.
		var pose := Transform3D(Basis(Vector3.UP,side*PI*0.5),Vector3(side*(px+ARCH_BUTTRESS.x),0.0,0.0))
		_buttress(b,pose,[[SET_OFF,ARCH_BUTTRESS.y],[SPRING,1.25]],BUTTRESS_WIDTH,weathered > 0.5 and b.rng.randf() < 0.5)
	var crown_lost := 0
	if weathered > 0.35 and b.rng.randf() < 0.75*weathered: crown_lost = 1+int(b.rng.randf()*2.0*weathered)
	var lost_side := -1.0 if b.rng.randf() < 0.5 else 1.0
	_arch_ring(b,Transform3D.IDENTITY,0.0,SPRING,h,radius,d,ARCH_DEPTH > 0.0,crown_lost,lost_side)
	# The spandrels, coursed up into the gable over the arch.
	var gable_half := px+1.5
	var apex := SPRING+_rise(h,radius)+ring+2.9
	var eave := SPRING+0.5
	var gable := func(x: float) -> float: return eave+(apex-eave)*(1.0-absf(x)/gable_half)
	var top := gable
	if weathered > 0.05:
		var ragged := _ruin_line(b,-gable_half,gable_half,lerpf(apex,SPRING+2.5,weathered),apex,weathered)
		top = func(x: float) -> float: return minf(gable.call(x),ragged.call(x))
	var outer := radius+ring+0.04
	var hole := func(y: float) -> Vector2:
		if y < SPRING: return Vector2(0.0,99.0)
		var w := _arc_half(h,radius,outer-radius,y-SPRING)
		return Vector2(0.0,w)
	_courses(b,Transform3D.IDENTITY,-gable_half,gable_half,SPRING,top,d-0.08,hole,0.5)
	# Coping along the gable's rakes where it still stands whole.
	_rake(b,Transform3D.IDENTITY,gable_half,eave,apex,d,top)
	if weathered > 0.0:
		for i in range(int(2+weathered*5.0)):
			b.hang(Vector3(b.rng.randf_range(-h*0.8,h*0.8),0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.5,1.6)*weathered,true)
	_drift(b,Vector3(lost_side*h*0.4,0.0,1.6),1.4,int(weathered*6.0))
	_rubble(b,h+2.5,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	return b.finish()

## 3. A wall pierced by a tall pointed window of two lights under an
## oculus, its jambs and head in moulded orders, the sill a ledge as deep as
## the wall (caught from the ground). Weathered, the tracery is broken (the
## mullion a stub, a sub-arch fragment hanging), the wall's head torn down
## in a ragged line, the window clear to fly through.
static func lancet_wall(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"LancetWall")
	b.drop_floating = true
	var half_len := WINDOW_WALL.x*0.5
	var d := ARCH_DEPTH*0.5
	var w := WINDOW.x*0.5
	var radius := WINDOW.x
	var ring := ORDER*2.0
	var top: Callable = _worn_top(b,-half_len,half_len,WINDOW_WALL.y,0.5)
	if weathered > 0.05:
		top = _ruin_line(b,-half_len,half_len,lerpf(WINDOW_WALL.y,3.6,weathered),WINDOW_WALL.y,weathered)
	_plinth_course(b,Transform3D.IDENTITY,half_len,d)
	var outer := radius+ring+0.04
	var hole := func(y: float) -> Vector2:
		if y < WINDOW.y: return Vector2(0.0,-1.0)
		if y < WINDOW.z: return Vector2(0.0,w+ring)
		return Vector2(0.0,_arc_half(w,radius,outer-radius,y-WINDOW.z))
	_courses(b,Transform3D.IDENTITY,-half_len,half_len,PLINTH_COURSE.x,top,d,hole,0.48)
	# The sill: a long stone over the wall under the opening, its top the ledge.
	var sill := b.solid(_box(b,Vector3(w+ring,0.09,d+0.06)),_settle(b,Vector3(0.0,WINDOW.y-0.09,0.0),0.5),_stone(b,1.03))
	# The jambs, in moulded orders up to the springing.
	_jambs(b,Transform3D.IDENTITY,w,WINDOW.y,WINDOW.z,d,top)
	var lost := 0
	if weathered > 0.5 and b.rng.randf() < weathered: lost = 1+int(b.rng.randf()*1.5)
	# The head's ring outlasts the walling round it, as a window's does. Its
	# frame at the springing, so its stones settle about there, not about the
	# ground (a wide window's springers swung into its opening).
	_arch_ring(b,Transform3D(Basis.IDENTITY,Vector3(0.0,WINDOW.z,0.0)),0.0,0.0,w,radius,d,true,lost,-1.0 if b.rng.randf() < 0.5 else 1.0)
	# The tracery: the mullion, two lancet lights' heads, the oculus.
	var t := 0.14
	var light := (w-0.12)*0.5
	var mullion_top := WINDOW.z
	var broken := weathered > 0.3
	if broken: mullion_top = WINDOW.y+b.rng.randf_range(0.25,0.9)
	var mullion: Array[Plane] = _box(b,Vector3(0.12,(mullion_top-WINDOW.y)*0.5,t))
	var extra: Array[Plane] = []
	if broken: extra = _break(b,mullion_top-WINDOW.y,0.12,0.4,(mullion_top-WINDOW.y)*0.5)
	b.solid(mullion,Transform3D(Basis.IDENTITY,Vector3(0.0,(WINDOW.y+mullion_top)*0.5,0.0)),_stone(b,1.05),true,true,extra)
	for side: float in [-1.0,1.0]:
		if broken and b.rng.randf() < 0.55+0.4*weathered: continue
		var keep := 99 if not broken else b.rng.randi_range(1,2)
		# Broken, a light's head keeps only its springers off the jamb: the
		# mullion under its inner springers is a stub.
		_ring_order(b,Transform3D.IDENTITY,side*(0.12+light),WINDOW.z,light,light*2.0,0.0,LIGHT_RING,t,4,keep,side,_stone(b,1.06),0,Callable(),false,0.0,side if broken else 0.0)
	# The oculus over the lights' heads, sized to the window (`oculus`).
	# Broken, the lights' heads are gone under it, so it is gone too (its
	# stones in the drift below): it never hangs in the window's head.
	if broken: b.rng.randf()
	else:
		var oculus := _oculus(w,light)
		_circle_ring(b,Transform3D.IDENTITY,Vector2(0.0,WINDOW.z+oculus.x),oculus.y,oculus.z,t,10)
	if weathered > 0.0:
		for i in range(int(1+weathered*4.0)):
			b.hang(Vector3(b.rng.randf_range(-w*0.7,w*0.7),0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.6,2.2)*weathered,true)
	_drift(b,Vector3(b.rng.randf_range(-1.5,1.5),0.0,d+1.0),1.6,int(weathered*7.0))
	_rubble(b,half_len+0.8,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	b.root.set_meta("sill",sill.size())
	return b.finish()

## A lancet window's oculus (half width `w`, its two lights each `light`
## across half, their head rings LIGHT_RING deep): (its middle over the
## springing, its ring's middle radius, its half depth radially). Its ring
## rests on the two lights' heads (touching their extrados) and is
## OCULUS_FIT of the widest that would also touch the window's own arc
## (radius 2w), so it grows with the window: 0.63 m out in the toy's 3.6
## m window, 1.2 m at 6.84. A fixed 0.62 m ring had hung in a wide
## window's head with nothing under it.
const OCULUS_FIT := 0.7
const LIGHT_RING := 0.13
static func _oculus(w: float, light: float) -> Vector3:
	var reach := 0.12+2.0*light
	var rests := func(outer: float) -> float: return sqrt(maxf(0.0,pow(2.0*light+LIGHT_RING+outer,2.0)-reach*reach))
	var low := 0.0
	var high := w
	for i in range(40):
		var mid := (low+high)*0.5
		if w*w+pow(float(rests.call(mid)),2.0) < pow(2.0*w-mid,2.0): low = mid
		else: high = mid
	var outer := low*OCULUS_FIT
	var dr := 0.12*outer/0.62
	return Vector3(float(rests.call(outer)),outer-dr,dr)

## 4. The end gable: coursed walls up to the eaves and a steep gable over
## them with crocketed coping and a finial; a moulded pointed door below; a
## rose window high up: a frame of sixteen stones, an inner ring, a hub and
## twelve spokes; buttresses at the corners, stepped up to the eaves.
## Weathered, the gable's head is torn down, the rose's spokes broken off,
## its hub fallen, its inner ring mostly gone, ivy hanging over it all.
static func rose_gable(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"RoseGable")
	b.drop_floating = true
	var half := GABLE.x*0.5
	var d := ARCH_DEPTH*0.5
	var gable := func(x: float) -> float: return minf(GABLE.z,GABLE.y+(GABLE.z-GABLE.y)*(1.0-absf(x)/half))
	var top: Callable = gable
	if weathered > 0.05:
		# Never down past the rose's middle: its lower half stands, a horseshoe.
		var ragged := _ruin_line(b,-half,half,lerpf(GABLE.z,ROSE.x+0.3,weathered),GABLE.z,weathered)
		top = func(x: float) -> float: return minf(gable.call(x),ragged.call(x))
	_plinth_course(b,Transform3D.IDENTITY,half,d)
	var dw := DOOR.x*0.5
	var ring := ORDER*2.0
	var door_top := DOOR.y+_rise(dw,DOOR.x)+ring
	var hole := func(y: float) -> Vector2:
		if y < DOOR.y: return Vector2(0.0,dw+ring)
		if y < door_top+0.05: return Vector2(0.0,_arc_half(dw,DOOR.x,ring+0.04,y-DOOR.y))
		var r := ROSE.y+0.04
		var dy := y-ROSE.x
		if absf(dy) >= r: return Vector2(0.0,-1.0)
		return Vector2(0.0,sqrt(r*r-dy*dy))
	_courses(b,Transform3D.IDENTITY,-half,half,PLINTH_COURSE.x,top,d,hole,0.5)
	_jambs(b,Transform3D.IDENTITY,dw,0.0,DOOR.y,d,top)
	_arch_ring(b,Transform3D.IDENTITY,0.0,DOOR.y,dw,DOOR.x,d,true,0,1.0,top)
	_rake(b,Transform3D.IDENTITY,half,GABLE.y,GABLE.z,d,top,true,INF if weathered < 0.3 else ROSE.x)
	# The rose: the frame, an inner ring, hub and spokes.
	var centre := Vector2(0.0,ROSE.x)
	var inner := ROSE.y-ROSE.z
	var ruin := clampf((weathered-0.15)*1.4,0.0,1.0)
	_circle_ring(b,Transform3D.IDENTITY,centre,ROSE.y-ROSE.z*0.5,ROSE.z*0.5,d+0.02,16,0.0,top)
	if ruin < 0.4: _circle_ring(b,Transform3D.IDENTITY,centre,inner-0.08,0.08,d-0.14,16,ruin*0.3,top)
	# Ruined, the hub has fallen (it lies in the drift below).
	var hub := ruin < 0.3
	var mid_r := inner*0.62
	if ruin < 0.3: _circle_ring(b,Transform3D.IDENTITY,centre,mid_r,0.07,0.15,14,ruin,top)
	if hub: b.solid(_axial_prism(8,0.34,0.26),Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,ROSE.x,0.26)),_stone(b,1.05))
	var spokes := 12
	for k in range(spokes):
		var a := TAU*(k+0.5)/spokes
		var dir := Vector3(cos(a),sin(a),0.0)
		var r0 := 0.3
		var r1 := inner-0.12
		if ruin > 0.0:
			var roll := b.rng.randf()
			if roll < ruin*0.7: continue
			elif roll < ruin*0.95 or not hub:
				# A stub from the frame, broken off a short way in.
				r0 = r1-b.rng.randf_range(0.25,0.55)
		var mid := Vector3(centre.x,centre.y,0.0)+dir*(r0+r1)*0.5
		if top.call(mid.x) < mid.y+0.2: continue
		var pose := Transform3D(Basis(Vector3.BACK,a-PI*0.5),mid)
		b.solid(_box(b,Vector3(0.065,(r1-r0)*0.5,0.15),0.02),pose,_stone(b,1.06))
		# A small pointed head between this spoke and the next, at the frame.
		if ruin < 0.3 or b.rng.randf() > ruin*1.6:
			var a2 := a+PI/spokes
			var at := Vector3(centre.x,centre.y,0.0)+Vector3(cos(a2),sin(a2),0.0)*(inner-0.42)
			if top.call(at.x) > at.y+0.3:
				var cusp: Array[Plane] = [Plane(Vector3.BACK,0.13),Plane(Vector3.FORWARD,0.13),Plane(Vector3.DOWN,0.0)]
				for s: float in [-1.0,1.0]:
					var n := Vector3(s*0.8,0.6,0.0).normalized()
					cusp.append(Plane(n,n.dot(Vector3(0.0,0.26,0.0))))
				b.solid(cusp,Transform3D(Basis(Vector3.BACK,a2-PI*0.5),at),_stone(b,1.04),false,true)
	# The corner buttresses, stepped up toward the eaves, pinnacled.
	for side: float in [-1.0,1.0]:
		var pose := Transform3D(Basis.IDENTITY,Vector3(side*(half-0.62),0.0,d))
		_buttress(b,pose,[[SET_OFF,2.1],[SET_OFF*2.0,1.25],[SET_OFF*3.0,0.62]],1.24,weathered > 0.4 and b.rng.randf() < weathered,true)
	if weathered > 0.0:
		for i in range(int(2+weathered*5.0)):
			var a := b.rng.randf_range(0.2,PI-0.2)
			b.hang(Vector3(cos(a)*inner*0.9,0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.5,2.0)*weathered,true,ROSE.x+sin(a)*inner)
	if not hub and weathered > 0.0:
		# Fallen to one side of the door, never across the way through it.
		var off := (dw+0.8)*(1.0 if b.rng.randf() < 0.5 else -1.0)+b.rng.randf_range(-0.3,0.3)
		b.solid(_axial_prism(8,0.34,0.26),Transform3D(Basis(Vector3.RIGHT,b.rng.randf_range(0.2,0.6)),Vector3(off,0.3,d+1.4)),_stone(b,1.05))
	_drift(b,Vector3(b.rng.randf_range(-2.0,2.0),0.0,d+1.2),2.0,int(weathered*8.0))
	_rubble(b,half+1.0,int(round(weathered*b.rng.randf_range(5.0,9.0))))
	return b.finish()

## 5. A buttress against a stub of wall: three stages, each set back with a
## weathered set-off (each SET_OFF higher, each tread STAND deep: a way up),
## a gablet and a crocketed pinnacle on top. Weathered, the pinnacle is
## snapped, the wall stub torn down, and a flying buttress's arm leaps from
## its head back over the wall and breaks off in mid-air. Built standing
## out toward +X (its profile to the front), the wall's stub along Z.
static func buttress(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Buttress")
	b.drop_floating = true
	# Turned side on: its stepped profile and the flyer read from the front.
	b.frame = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(-0.3,0.0,0.0))
	var depth: Array = BUTTRESS_DEPTH
	var stages := [[SET_OFF,depth[0]],[SET_OFF*2.0,depth[1]],[SET_OFF*3.0,depth[2]]]
	var wall_z := -1.2
	var top: Callable = _worn_top(b,-1.7,1.7,6.2,0.5)
	var flyer := weathered > 0.4
	if weathered > 0.05:
		var ragged := _ruin_line(b,-1.7,1.7,lerpf(6.2,3.0,weathered),6.2,weathered)
		# Under the flyer's arm the wall is down, so the arm leaps clear.
		top = func(x: float) -> float: return minf(float(ragged.call(x)),4.1 if flyer and absf(x) < 0.9 else 99.0)
	_courses(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,wall_z+0.5)),-1.7,1.7,0.0,top,0.5,Callable(),0.5)
	var snapped := weathered > 0.3 and b.rng.randf() < 0.4+weathered*0.6
	_buttress(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,wall_z+1.0)),stages,BUTTRESS_WIDTH,snapped,true)
	if flyer:
		# The flyer: a straight sloping arm of long stones under a coping,
		# leaping from the pinnacle's foot back over the wall toward the
		# nave that is gone, broken off in mid-air after a few stones.
		var slope := deg_to_rad(32.0)
		var way := Vector3(0.0,sin(slope),-cos(slope))
		var lift := Basis(Vector3.RIGHT,slope)
		var at := Vector3(0.0,SET_OFF*3.0+0.1,wall_z+1.0+0.2)
		var keep := 3+int(b.rng.randf()*1.5*weathered)
		for i in range(keep):
			var half := Vector3(0.26,0.24,0.38)
			var middle := at+way*(half.z*2.0*i+half.z)
			var extra: Array[Plane] = []
			if i == keep-1:
				var m := (Vector3.FORWARD+Vector3(b.rng.randf_range(-0.6,0.6),b.rng.randf_range(-0.5,0.5),0.0)).normalized()
				extra.append(Plane(m,b.rng.randf_range(0.0,0.15)))
			b.solid(_box(b,half),Transform3D(lift,middle),_stone(b,1.03),true,true,extra)
			if i < keep-1:
				b.solid(_box(b,Vector3(0.32,0.07,0.38)),Transform3D(lift,middle+lift*Vector3(0.0,0.3,0.0)),_stone(b,1.08),true,true)
	_drift(b,Vector3(b.rng.randf_range(-1.0,1.0),0.0,1.8),1.3,int(weathered*6.0))
	_rubble(b,2.2,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## 6. A plain wall of uneven courses on a plinth course, a chamfered coping
## along its head: WALL_HEIGHT, caught from a running chain. Weathered, it
## is broken: its head a jagged line with a gap torn down through it, the
## fallen blocks in a drift at its foot (and its low runs caught with one
## jump).
static func wall(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Wall")
	b.drop_floating = true
	var half_len := WALL_LENGTH*0.5
	var d := WALL_THICK*0.5
	var top: Callable = _worn_top(b,-half_len,half_len,WALL_HEIGHT,0.25)
	if weathered > 0.05:
		top = _ruin_line(b,-half_len,half_len,lerpf(WALL_HEIGHT,0.8,weathered),WALL_HEIGHT,weathered,true)
	_plinth_course(b,Transform3D.IDENTITY,half_len,d)
	_courses(b,Transform3D.IDENTITY,-half_len,half_len,PLINTH_COURSE.x,top,d,Callable(),0.44,true)
	_drift(b,Vector3(b.rng.randf_range(-1.2,1.2),0.0,d+0.9),1.5,int(weathered*7.0))
	_rubble(b,half_len+0.5,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## 7. A straight flight (the pale kit's, liked, restyled): STEPS of RISER
## by TREAD, STAIR_WIDTH wide, climbing toward -Z from its foot at +Z to a
## landing, between ramped cheek walls (the stringers) built in courses
## under a sloped coping, a gabled newel post at each foot. Weathered, steps
## crack and settle (never past a walkable rise), corners break off, a
## cheek is torn down, rubble and ivy over it.
static func stairs(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Stairs")
	_flight(b,Transform3D.IDENTITY,STEPS,STAIR_WIDTH,LANDING)
	_rubble(b,STAIR_WIDTH*0.5+1.0,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## A flight of the stair's steps at `pose`: `steps` of `riser` by `tread`
## (the kit's RISER by TREAD unless given),
## `width` wide, climbing toward -Z from its foot at +Z (the run centred on
## the pose), the last step a landing `landing` deep; ramped cheek walls
## either side under a sloped coping, a gabled newel at each foot. `foot`:
## how far under the pose its steps and cheeks reach down (0 on the ground;
## a flight set on a landing reaches down to the ground under it). A flight
## wider than the stair's lays each tread in more slabs. Weathered (the
## Build's): steps crack and settle (never past a walkable rise), corners
## break off, one cheek torn down.
static func _flight(b: Build, pose: Transform3D, steps: int, width: float, landing: float, foot := 0.0, riser := RISER, tread := TREAD) -> void:
	var weathered := b.weathered
	var half_width := width*0.5
	var run := (steps-1)*tread+landing
	var front := run*0.5
	var sections := maxi(1,int(round(width/STAIR_WIDTH)))
	var section := width/sections
	for i in range(steps):
		var z0 := front-i*tread
		var z1 := z0-(landing if i == steps-1 else tread)
		var top := (i+1)*riser
		var settle := b.rng.randf_range(0.0,0.015)+b.rng.randf_range(0.0,0.03)*weathered
		# Each tread a slab a section, now and then two, the joint wandering.
		var parts: Array = []
		for s in range(sections):
			var mid := -half_width+section*(s+0.5)
			var cut := b.rng.randf_range(-0.4,0.4) if b.rng.randf() < 0.3 else 99.0
			if cut > 50.0: parts.append([mid-section*0.5,mid+section*0.5])
			else: parts.append_array([[mid-section*0.5,mid+cut*section/STAIR_WIDTH],[mid+cut*section/STAIR_WIDTH,mid+section*0.5]])
		for p: Array in parts:
			var x0: float = p[0]
			var x1: float = p[1]
			var hh := Vector3((x1-x0)*0.5-0.008,(top-settle+foot)*0.5,(z0-z1)*0.5-0.006)
			# Laid as the halls' cheap stone is (Build `lean`): its top kept
			# level and true, its arrises chamfered only along the tread,
			# few chips and no chunk bitten from the walking face, so the
			# flight reads as crisp steps, not a heap of loaves.
			b.lean = true
			var planes := _box(b,hh)
			# The nosing worn back, more at the middle where feet went.
			var n := Vector3(0.0,1.0,1.0).normalized()
			planes.append(Plane(n,(hh.y+hh.z)/sqrt(2.0)-0.03-0.05*b.age))
			var extra: Array[Plane] = []
			if b.rng.randf() < weathered*0.25 and absf(x0) > half_width-0.1 or absf(x1) > half_width-0.1 and b.rng.randf() < weathered*0.25:
				var side := signf(x0+x1)
				var m := Vector3(side,b.rng.randf_range(0.4,0.9),b.rng.randf_range(0.0,0.6)).normalized()
				var keep := Vector3(side*(x1-x0)*0.5*b.rng.randf_range(0.65,0.85),hh.y,hh.z)
				extra.append(Plane(m,m.dot(keep)))
			var tilt := Basis(Vector3.RIGHT,b.rng.randf_range(-0.005,0.005)+b.rng.randf_range(-0.012,0.012)*weathered)*Basis(Vector3.BACK,b.rng.randf_range(-0.004,0.004))
			b.solid(planes,pose*Transform3D(tilt,Vector3((x0+x1)*0.5,hh.y-foot,(z0+z1)*0.5)),_stone(b),false,true,extra)
			b.lean = false
		# Walked on clean: the step's own box, the flight's full width, its
		# top true, from its nose back past the flight's back (so no joint
		# between treads or slabs, no settled slab or worn nosing, is a gap
		# for the feet's ray to drop through).
		_walk_box(b,pose,half_width+0.02,-foot,top,z0,front-run-WALK_OVERLAP)
		_tread_core(b,pose,half_width,-foot,top,z0,z1,i == steps-1)
	# The cheeks: ramped with the flight, level by the landing, in courses
	# cut by the slope, a sloped coping, a newel post at the foot.
	var foot_z := front
	var head_z := front-(steps-1)*tread
	var slope := Vector3(0.0,tread,riser).normalized()
	var torn := -1.0 if b.rng.randf() < 0.5 else 1.0
	for side: float in [-1.0,1.0]:
		var x0 := side*half_width
		var x1 := side*(half_width+CHEEK.x)
		var lo := minf(x0,x1)
		var hi := maxf(x0,x1)
		var line_at := func(z: float) -> float: return riser+CHEEK.y+maxf(0.0,(foot_z-z))*riser/tread if z > head_z else steps*riser+CHEEK.y
		var ruin: Callable = func(_z: float) -> float: return INF
		if weathered > 0.25 and side == torn:
			ruin = _ruin_line(b,front-run,front,0.5,steps*riser*0.8,weathered)
		var z := front
		var course := 0.42
		var cy := -foot
		while cy < steps*riser+CHEEK.y-0.02:
			var y1 := cy+course*b.rng.randf_range(0.85,1.15)
			# Every other course broken joint: its first stone a short one.
			z = front
			var first := -1.0 if int((cy+foot)/course)%2 == 0 else 0.35
			while z > front-run+0.02:
				var z1 := maxf(front-run,z-(first if first > 0.0 else b.rng.randf_range(0.7,1.2)))
				first = -1.0
				if z1-(front-run) < 0.3: z1 = front-run
				var mid := (z+z1)*0.5
				var stand := minf(line_at.call(mid),ruin.call(mid))
				if cy+0.12 < minf(line_at.call(z),line_at.call(z1)) and cy+0.15 < stand:
					var planes: Array[Plane] = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.DOWN,-cy),Plane(Vector3.UP,y1),Plane(Vector3.BACK,z),Plane(Vector3.FORWARD,-z1)]
					planes.append(Plane(slope,slope.dot(Vector3(0.0,riser+CHEEK.y-0.11,foot_z))))
					planes.append(Plane(Vector3.UP,steps*riser+CHEEK.y-0.11))
					if stand < y1:
						var m := Vector3(0.0,1.0,b.rng.randf_range(-0.8,0.8)).normalized()
						planes.append(Plane(m,m.dot(Vector3(0.0,stand,mid))))
					b.solid(_bevel(planes,Vector3((lo+hi)*0.5,(cy+y1)*0.5,mid),0.03),pose,_stone(b,0.97),false)
					_walk_hull(b,pose,planes)
				z = z1
			cy = y1
		# The coping: sloped stones along the ramp, then level by the landing.
		var count := 4
		for k in range(count+1):
			var za := foot_z-(foot_z-head_z)*k/count
			var zb := foot_z-(foot_z-head_z)*(k+1)/count if k < count else front-run
			if ruin.call((za+zb)*0.5) < steps*riser: continue
			var ya: float = line_at.call(za)-0.11
			var yb: float = line_at.call(zb)-0.11 if k < count else ya
			var ang := atan2(ya-yb,za-zb)
			var len := Vector2(za-zb,ya-yb).length()
			var cope := Transform3D(Basis(Vector3.RIGHT,-ang),Vector3((lo+hi)*0.5,(ya+yb)*0.5+0.07,(za+zb)*0.5))
			b.solid(_box(b,Vector3(CHEEK.x*0.5+0.04,0.07,len*0.5-0.01)),pose*_jiggle(b,cope,0.8),_stone(b,1.06),false)
			# Walked as laid true, end to end, over the courses' slope.
			var cope_half := Vector3(CHEEK.x*0.5+0.04,0.07,len*0.5+0.02)
			_walk_hull(b,pose*cope,[Plane(Vector3.RIGHT,cope_half.x),Plane(Vector3.LEFT,cope_half.x),Plane(Vector3.UP,cope_half.y),Plane(Vector3.DOWN,cope_half.y+0.12),Plane(Vector3.BACK,cope_half.z),Plane(Vector3.FORWARD,cope_half.z)])
		# The newel at the foot: a square post under a little gabled cap.
		var nx := side*(half_width+CHEEK.x*0.5)
		var post := NEWEL.y-0.18
		b.solid(_box(b,Vector3(NEWEL.x*0.5,post*0.5,NEWEL.x*0.5)),pose*_settle(b,Vector3(nx,post*0.5,foot_z+NEWEL.x*0.3),0.6),_stone(b,1.0))
		if not (weathered > 0.4 and side == torn):
			_gablet(b,pose*Transform3D(Basis.IDENTITY,Vector3(nx,post,foot_z+NEWEL.x*0.3)),NEWEL.x*0.5+0.05,0.42)

## A step's bed, drawn only: a dark block the step's full width under its
## slabs, its top TREAD_BED under the tread and its front TREAD_BED_IN back
## from the nose, so a joint between slabs (or a slab and a cheek) shows
## stone a few cm down, not the ground or the sky through it. Built on an
## RNG of its own, so the flight's seeded stream (its look) is unchanged.
const TREAD_BED := 0.05
const TREAD_BED_IN := 0.08
static func _tread_core(b: Build, pose: Transform3D, half_width: float, bottom: float, top: float, z0: float, z1: float, last: bool) -> void:
	var keep := b.rng
	b.rng = RandomNumberGenerator.new()
	b.rng.seed = 1
	var y1 := top-TREAD_BED
	var front := z0-TREAD_BED_IN
	var back := z1+0.01 if last else z1-0.03
	var x := half_width-0.002
	var planes: Array[Plane] = [Plane(Vector3.RIGHT,x),Plane(Vector3.LEFT,x),Plane(Vector3.UP,y1),Plane(Vector3.DOWN,-bottom),Plane(Vector3.BACK,front),Plane(Vector3.FORWARD,-back)]
	b.solid(planes,pose,b.stone*0.55,false,false,[],-1,1.0,false)
	b.rng = keep

## A stair's walked collision, invisible (Build `hulls` only): a box
## `half` either side of x 0, from `bottom` to `top`, from `z_front` back to
## `z_back`, at `pose` (in the Build's frame). A stair's drawn treads are
## worn, settled, tilted and laid in slabs with joints between them; their
## hulls left gaps and pits a ray straight down fell through (Jolt rounds a
## hull's edges by its margin), so the stair walks on these instead.
static func _walk_box(b: Build, pose: Transform3D, half: float, bottom: float, top: float, z_front: float, z_back: float) -> void:
	_walk_hull(b,pose,[Plane(Vector3.RIGHT,half),Plane(Vector3.LEFT,half),Plane(Vector3.UP,top),Plane(Vector3.DOWN,-bottom),Plane(Vector3.BACK,z_front),Plane(Vector3.FORWARD,-z_back)])

## The convex block `planes` (outward, at `pose` in the Build's frame) as a
## hull only, true: no wear, chips, bevels or settling, so blocks laid face
## to face (a cheek's courses, its coping) walk as one surface.
static func _walk_hull(b: Build, pose: Transform3D, planes: Array) -> void:
	var cut: Array[Plane] = []
	for p: Plane in planes: cut.append(p)
	var points := Geometry3D.compute_convex_mesh_points(cut)
	if points.size() < 4: return
	var xf := b.frame*pose
	var hull := PackedVector3Array()
	for q in points: hull.append(xf*q)
	if b.thickness(hull) < HULL_THIN: return
	b.hulls.append(hull)
	b.hull_anchors.append(NAN)

## 8. A stair turret: an octagonal shell on a battered plinth, laid in
## courses two or three stones a side, a string course, slit windows up the
## sides, a pointed door at its foot; round a newel the steps wind up
## (TURRET_STEPS a turn, RISER each, the stairway to the clouds to come) to
## a landing under a corbel table and an octagonal stone cone, its tip
## snapped and a bite gone from one side, centuries old. Weathered, the
## shell is torn down across its front, the spiral of steps laid open and
## going on up past the broken walls, the cone fallen but for a stub.
static func turret(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Turret")
	var outer := TURRET.x
	var inner := TURRET.y
	var count := int(TURRET_STEPS*TURRET_TURNS)
	var height := count*RISER+0.4
	var door_side := 2
	# The tear faces the front (+Z), a little to one side.
	var open_at := PI*0.5+b.rng.randf_range(-0.3,0.3)
	var tear_floor := lerpf(height,0.55,clampf(weathered*1.25,0.0,1.0))
	var ragged := _ruin_line(b,-PI,PI,0.0,1.0,1.0)
	# The shell's height by angle: whole, or torn down round `open_at` in a
	# ragged vee, lowest at its middle.
	var shell := func(a: float) -> float:
		if weathered <= 0.05: return height
		var off := absf(wrapf(a-open_at,-PI,PI))
		var tear := clampf(1.0-off/(PI*0.8),0.0,1.0)
		var line := lerpf(height,tear_floor,smoothstep(0.0,0.55,tear))
		return minf(height,line+float(ragged.call(wrapf(a,-PI,PI)))*0.8*weathered)
	var batter := 0.12
	for side in range(8):
		var a := TAU*side/8.0
		var n := Vector3(cos(a),0.0,sin(a))
		var along := Vector3(-sin(a),0.0,cos(a))
		var s0 := Vector3(cos(a-PI/8.0),0.0,sin(a-PI/8.0))
		var s1 := Vector3(cos(a+PI/8.0),0.0,sin(a+PI/8.0))
		var left := Plane(-s0.cross(Vector3.UP).normalized(),0.006)
		var right := Plane(s1.cross(Vector3.UP).normalized(),0.006)
		var half_side := outer*tan(PI/8.0)
		var door := side == door_side
		var slits := side in [0,4,5,7]
		var y := 0.0
		var k := 0
		while y < height-0.02:
			var plinth := y < 0.5
			var y1 := minf(height,y+(0.5 if plinth else b.rng.randf_range(0.3,0.44)))
			if height-y1 < 0.15: y1 = height
			var standing := minf(float(shell.call(a)),minf(float(shell.call(a-PI/8.0)),float(shell.call(a+PI/8.0))))
			var most := maxf(float(shell.call(a)),maxf(float(shell.call(a-PI/8.0)),float(shell.call(a+PI/8.0))))
			if y+0.12 > most: break
			# Where the course is cut along its side: two or three stones,
			# their joints staggered course by course; a slit window a gap.
			var cuts: Array[float] = [-1.0]
			var slit := slits and y > 1.6+0.6*float(side%2) and y < 3.4+0.6*float(side%2)
			if slit: cuts.append_array([-0.11,0.11])
			elif k%2 == 0: cuts.append(b.rng.randf_range(-0.35,0.35))
			else: cuts.append_array([-0.42+b.rng.randf_range(-0.08,0.08),0.38+b.rng.randf_range(-0.08,0.08)])
			cuts.append(1.0)
			for c in range(cuts.size()-1):
				if slit and c == 1: continue
				var u0 := cuts[c]*half_side*1.3
				var u1 := cuts[c+1]*half_side*1.3
				var mid := (u0+u1)*0.5
				if door and y < 2.35 and absf(mid) < half_side*0.75: continue
				var out := outer+(batter*(1.0-y/0.5) if plinth else 0.0)
				var planes: Array[Plane] = [Plane(n,out),Plane(-n,-inner),Plane(Vector3.DOWN,-y),Plane(Vector3.UP,y1)]
				planes.append(left if c == 0 else Plane(-along,-u0-0.006))
				planes.append(right if c == cuts.size()-2 else Plane(along,u1-0.006))
				if plinth:
					# The plinth's sloped weathering at its top.
					var m := (n+Vector3.UP*1.4).normalized()
					planes.append(Plane(m,m.dot(n*outer+Vector3.UP*y1)))
				var here := minf(standing,float(shell.call(a+mid/outer)))
				var extra: Array[Plane] = []
				if y1 > here:
					if y+0.18 > here: continue
					var m := (Vector3.UP+n*b.rng.randf_range(-0.4,0.4)+along*b.rng.randf_range(-0.7,0.7)).normalized()
					extra.append(Plane(m,m.dot(n*outer+along*mid+Vector3.UP*here)))
				b.solid(planes,_settle(b,Vector3.ZERO,0.15),_stone(b),true,true,extra)
			y = y1
			k += 1
		# The door's head: a pointed lintel, two slanting halves.
		if door and float(shell.call(a)) > 2.9:
			for h: float in [-1.0,1.0]:
				var hd := along*h
				var planes: Array[Plane] = [Plane(n,outer+0.04),Plane(-n,-inner+0.04),Plane(Vector3.UP,2.75)]
				planes.append(Plane(hd,half_side*0.78))
				planes.append(Plane(-hd,0.0))
				var slant := Vector3.DOWN-hd*0.9
				planes.append(Plane(slant.normalized(),-2.6/slant.length()))
				b.solid(planes,Transform3D.IDENTITY,_stone(b,1.06))
		# A string course round the middle, standing out, where it stands.
		var band := 2.6
		if float(shell.call(a)) > band+0.4 and float(shell.call(a-PI/8.0)) > band+0.2 and float(shell.call(a+PI/8.0)) > band+0.2:
			var planes: Array[Plane] = [Plane(n,outer+0.09),Plane(-n,-(outer-0.2)),Plane(Vector3.DOWN,-band),Plane(Vector3.UP,band+0.14),left,right]
			var m := (n+Vector3.UP*1.2).normalized()
			planes.append(Plane(m,m.dot(n*(outer+0.02)+Vector3.UP*(band+0.14))))
			b.solid(planes,Transform3D.IDENTITY,_stone(b,1.06))
	# The newel, in drums, up to the last step.
	var y := 0.0
	while y < count*RISER:
		var y1 := minf(count*RISER+0.25,y+b.rng.randf_range(0.5,0.7))
		b.solid(_prism(8,TURRET.z,TURRET.z,y,y1),Transform3D.IDENTITY,_stone(b,0.95))
		y = y1
	# The steps: wedges round the newel from the door, rising anticlockwise,
	# their nosings worn; a little lighter than the shell, so the spiral reads.
	var start := TAU*door_side/8.0+PI/8.0+0.1
	var gone := -1
	if weathered > 0.6: gone = b.rng.randi_range(int(count*0.6),count-2)
	for i in range(count):
		if i == gone: continue
		var a0 := start+TAU*i/TURRET_STEPS
		var a1 := a0+TAU/TURRET_STEPS+0.02
		var top := (i+1)*RISER-b.rng.randf_range(0.0,0.03)*weathered
		var mid := (a0+a1)*0.5
		var radial := Vector3(cos(mid),0.0,sin(mid))
		var planes: Array[Plane] = [Plane(Vector3.UP,top),Plane(Vector3.DOWN,-(top-0.3))]
		planes.append(Plane(Vector3(sin(a0),0.0,-cos(a0)),0.0))
		planes.append(Plane(Vector3(-sin(a1),0.0,cos(a1)),0.0))
		planes.append(Plane(radial,inner+0.05))
		# The nosing: the leading edge (at a1, where the next step rises from
		# a0... the lower edge) worn back.
		var lead := Vector3(sin(a0),0.0,-cos(a0))
		var nose := (lead+Vector3.UP).normalized()
		planes.append(Plane(nose,nose.dot(Vector3(0.0,top,0.0))-0.04))
		var wedge := Transform3D(Basis(radial,b.rng.randf_range(-0.01,0.01)),Vector3.ZERO)
		# Kept clear of ivy and moss (walked on), so the spiral reads.
		b.solid(planes,wedge,_stone(b,1.14),true,true,[],-1,0.5,false)
	# The landing at the head: the floor but where the stair comes up.
	var land := count*RISER
	var la := start+TAU*count/TURRET_STEPS
	if weathered < 0.3:
		var planes: Array[Plane] = [Plane(Vector3.UP,land+0.02),Plane(Vector3.DOWN,-(land-0.25))]
		for k in range(8):
			var a := TAU*k/8.0
			planes.append(Plane(Vector3(cos(a),0.0,sin(a)),inner+0.05))
		var cut_dir := Vector3(cos(la),0.0,sin(la))
		planes.append(Plane(-cut_dir.cross(Vector3.UP).normalized(),0.15))
		b.solid(planes,Transform3D.IDENTITY,_stone(b,1.04))
	_turret_cap(b,height,outer,shell)
	# The fallen: in drifts to either side of the tear, the way into the
	# stair left clear.
	for s: float in [-1.0,1.0]:
		var d := Vector3(cos(open_at+s*1.1),0.0,sin(open_at+s*1.1))*(outer+0.8)
		_drift(b,d,1.1,int(weathered*4.0))
	_rubble(b,outer+0.9,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## The turret's head over `height`: a corbel table on little corbels, and on
## it an octagonal cone of stone in stepping rings, its tip snapped and a
## bite gone from one side; ruined, only its lowest rings, where the shell
## under them still stands.
static func _turret_cap(b: Build, height: float, outer: float, shell: Callable) -> void:
	var eave := height+0.22
	var rise := 3.9
	var base := outer+0.06
	var bite := b.rng.randf()*TAU
	var snap := rise*b.rng.randf_range(0.62,0.8)
	var keep_rings := 99 if b.weathered < 0.35 else int(2.0*(1.0-b.weathered)+b.rng.randf())
	for side in range(8):
		var a := TAU*side/8.0
		var whole := float(shell.call(a)) >= height-0.05 and float(shell.call(a-PI/8.0)) >= height-0.05 and float(shell.call(a+PI/8.0)) >= height-0.05
		if not whole: continue
		var n := Vector3(cos(a),0.0,sin(a))
		var along := Vector3(-sin(a),0.0,cos(a))
		var s0 := Vector3(cos(a-PI/8.0),0.0,sin(a-PI/8.0))
		var s1 := Vector3(cos(a+PI/8.0),0.0,sin(a+PI/8.0))
		var left := Plane(-s0.cross(Vector3.UP).normalized(),0.006)
		var right := Plane(s1.cross(Vector3.UP).normalized(),0.006)
		b.solid([Plane(n,outer+0.16),Plane(-n,-(outer-0.45)),Plane(Vector3.DOWN,-height),Plane(Vector3.UP,eave),left,right],Transform3D.IDENTITY,_stone(b,1.05))
		var half_side := outer*tan(PI/8.0)
		for k in range(3):
			var x := (k-1.0)*half_side*0.62
			b.solid(_box(b,Vector3(0.08,0.1,0.09),0.015),Transform3D(Basis(Vector3.UP,-a),n*(outer+0.07)+along*x+Vector3(0.0,height-0.1,0.0)),_stone(b,0.95),false,true)
		# The cone's rings on this side: each a sloped stone, stepping in.
		var slope := (n*rise+Vector3.UP*base).normalized()
		var y := 0.0
		var ring := 0
		while y < rise-0.1 and ring < keep_rings:
			var y1 := minf(rise,y+0.42)
			var at := Vector3(0.0,eave,0.0)
			var off := absf(wrapf(a-bite,-PI,PI))
			var bitten := off < 0.5 and y > rise*0.35
			if y > snap or bitten: break
			var r_in := maxf(0.0,base*(1.0-y1/rise)-0.32)
			var planes: Array[Plane] = [Plane(slope,slope.dot(at+n*base)),Plane(Vector3.DOWN,-(eave+y)),Plane(Vector3.UP,eave+y1),left,right]
			if r_in > 0.05: planes.append(Plane(-n,-r_in))
			var extra: Array[Plane] = []
			if y1 > snap-0.05 or (off < 0.9 and y1 > rise*0.35):
				var m := (Vector3.UP+n*b.rng.randf_range(-0.5,0.5)+along*b.rng.randf_range(-0.6,0.6)).normalized()
				extra.append(Plane(m,m.dot(at+Vector3.UP*(y+(y1-y)*0.4)+n*base*0.5)))
			b.solid(planes,_settle(b,Vector3.ZERO,0.2),_stone(b,1.0+0.04*float(ring%2)),true,true,extra)
			y = y1
			ring += 1

## 9. Vault ribs: the corner of a bay, two walls meeting, a respond of three
## shafts in the corner and on its capital a solid springer, from which three
## heavy ribs spring (two along the walls, one across the bay), the vault's
## web laid in thin courses between them, the whole breaking off in mid-air.
## The walls step down from the corner (VAULT_STEPS: a way up to the
## springing). Weathered, ribs and web are shorter, the walls lower and more
## ragged.
static func vault(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Vault")
	# The corner at the back left, the bay opening toward the front right, so
	# the back wall's rib is seen whole and the diagonal across.
	b.frame = Transform3D(Basis.IDENTITY,Vector3(-1.4,0.0,-1.1))
	var t := 0.9
	var steps: Array = VAULT_STEPS
	for wall_i in range(2):
		# Along +X (the back wall) or +Z (the left), from the corner out.
		var pose := Transform3D.IDENTITY if wall_i == 0 else Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3.ZERO)
		var length := BAY*0.75
		var drop := lerpf(0.0,0.7,weathered)
		var line := func(x: float) -> float:
			var s := 0 if x < length*0.36 else (1 if x < length*0.68 else 2)
			return float(steps[s])-drop*(0.5+0.5*float(s))
		var top: Callable = line
		if weathered > 0.05:
			var ragged := _ruin_line(b,-t,length,0.0,6.0,weathered*0.5)
			top = func(x: float) -> float: return minf(line.call(x),maxf(ragged.call(x)+0.6,line.call(x)-0.6*weathered))
		# Each wall's inner face on the corner's lines (x 0 and z 0), its body
		# outside them.
		var inward := -t*0.5 if wall_i == 0 else t*0.5
		_courses(b,pose*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,inward)),-t if wall_i == 0 else 0.0,length,0.0,top,t*0.5,Callable(),0.5)
	# The respond: three shafts in the corner, a capital on them.
	var corner := Vector3(0.24,0.0,0.24)
	var offsets: Array[Vector3] = [Vector3(0.12,0.0,0.12),Vector3(0.36,0.0,0.0),Vector3(0.0,0.0,0.36)]
	for k in range(3):
		var at: Vector3 = corner+offsets[k]
		var y := 0.0
		while y < VAULT_SPRING-0.6:
			var y1 := minf(VAULT_SPRING-0.55,y+b.rng.randf_range(0.6,0.9))
			b.solid(_prism(8,0.15 if k == 0 else 0.11,0.15 if k == 0 else 0.11,0.0,y1-y),_settle(b,at+Vector3(0.0,y,0.0),0.4),_stone(b,1.0))
			y = y1
	b.solid(_prism(8,0.4,0.36,0.0,0.2),Transform3D(Basis.IDENTITY,corner+Vector3(0.14,0.0,0.14)),_stone(b,0.95))
	_bell(b,Transform3D(Basis.IDENTITY,corner+Vector3(0.12,VAULT_SPRING-0.55,0.12)),0.3,0.56,0.42,7)
	# The ribs: two wall ribs and the diagonal, heavy, each a pointed arc.
	var spring := corner+Vector3(0.12,VAULT_SPRING,0.12)
	var depth := 0.5
	var specs := [[Vector3(1.0,0.0,0.0),BAY*0.5,7,7],[Vector3(1.0,0.0,1.0).normalized(),BAY*0.707,9,8],[Vector3(0.0,0.0,1.0),BAY*0.5,7,6]]
	var curves: Array = []
	for r: Array in specs:
		var dir: Vector3 = r[0]
		var half: float = r[1]
		var stones: int = r[2]
		var keep: int = r[3]
		if weathered > 0.0: keep = maxi(3,keep-int(round(weathered*b.rng.randf_range(1.5,3.5))))
		var basis := Basis(dir,Vector3.UP,dir.cross(Vector3.UP))
		var at := spring
		if dir.x < 0.5: at += Vector3(0.0,0.0,0.16)
		elif dir.z < 0.5: at += Vector3(0.16,0.0,0.0)
		var radius := half*1.12
		_rib(b,Transform3D(basis,at),half,radius,depth,0.24,stones,keep)
		# How high its kept stones reach, for the web.
		var apex := acos(clampf((radius-half)/radius,-1.0,1.0))
		var reach := radius*sin(PI-apex*float(keep-1)/stones) if keep < stones else radius*sin(apex)
		curves.append([at,dir,radius,reach])
	# The springer: the ribs' lowest courses laid solid as one, stepping out
	# from the corner along both walls, before they part.
	for k in range(2):
		var y0 := VAULT_SPRING-0.12+0.36*k
		var reach := 0.95-0.25*k
		var planes: Array[Plane] = [Plane(Vector3.DOWN,-y0),Plane(Vector3.UP,y0+0.36),Plane(Vector3.LEFT,-0.05),Plane(Vector3.FORWARD,-0.05)]
		var n := Vector3(1.0,0.0,1.0).normalized()
		planes.append(Plane(n,n.dot(corner+Vector3(reach,0.0,reach)*0.62)))
		planes.append(Plane(Vector3.RIGHT,corner.x+reach))
		planes.append(Plane(Vector3.BACK,corner.z+reach))
		b.solid(planes,_settle(b,Vector3.ZERO,0.3),_stone(b,0.98))
	# The web: between each wall rib and the diagonal, thin courses resting on
	# the ribs' backs, up as far as both ribs still stand (less, ruined).
	var web := 0.2
	for pair: Array in [[0,1],[2,1]]:
		var c0: Array = curves[pair[0]]
		var c1: Array = curves[pair[1]]
		var top := minf(float(c0[3]),float(c1[3]))-0.2-0.5*weathered*b.rng.randf()
		var y := 0.62
		var course := 0
		while y < top-0.1:
			var y1 := minf(top,y+0.34)
			if b.rng.randf() < 0.18*weathered and course > 0: break
			var pts := PackedVector3Array()
			for c: Array in [c0,c1]:
				for h: float in [y,y1]:
					var p := _rib_point(c,h,depth*0.5)
					pts.append(p)
					pts.append(p+Vector3.UP*web)
			var planes := _planes_round(pts)
			if not planes.is_empty():
				b.solid(planes,Transform3D.IDENTITY,_stone(b,0.92+0.06*float(course%2)),true,true,[],-1,0.5)
			y = y1
			course += 1
	for i in range(int(1+weathered*3.0)):
		var f := b.rng.randf_range(0.6,2.0)
		b.hang(Vector3(f,0.0,f),b.rng.randf_range(0.4,1.4),true,VAULT_SPRING+0.6+f*0.35)
	_drift(b,Vector3(1.6,0.0,1.6),1.4,int(1+weathered*6.0))
	_rubble(b,2.6,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## The point on a rib (`curve`: [springing, way, radius, reach]) at `h` over
## its springing, `inset` in from its back.
static func _rib_point(curve: Array, h: float, inset: float) -> Vector3:
	var at: Vector3 = curve[0]
	var dir: Vector3 = curve[1]
	var radius: float = curve[2]
	var r := radius-inset
	var theta := PI-asin(clampf(h/r,-1.0,1.0))
	return at+dir*(radius+r*cos(theta))+Vector3.UP*(r*sin(theta))

## The planes of the convex hull round `points` (outward), from every face
## three of them make with all the rest behind it.
static func _planes_round(points: PackedVector3Array) -> Array[Plane]:
	var out: Array[Plane] = []
	var n := points.size()
	var centre := Vector3.ZERO
	for p in points: centre += p
	centre /= n
	for i in range(n):
		for j in range(i+1,n):
			for k in range(j+1,n):
				var normal := (points[j]-points[i]).cross(points[k]-points[i])
				if normal.length_squared() < 1e-8: continue
				normal = normal.normalized()
				if normal.dot(centre-points[i]) > 0.0: normal = -normal
				var d := normal.dot(points[i])
				var ok := true
				for p in points:
					if normal.dot(p) > d+1e-4:
						ok = false
						break
				if not ok: continue
				var seen := false
				for q in out:
					if q.normal.dot(normal) > 0.9999 and absf(q.d-d) < 1e-4:
						seen = true
						break
				if not seen: out.append(Plane(normal,d))
	return out

## 10. A fallen pier: the shaft lying along X in three clustered drums,
## parted and rolled; its capital toppled past one end, its base still on
## its sub-base at the other. Weathered, the drums lie further apart,
## turned, sunk and broken.
static func fallen_pier(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"FallenPier")
	var x := -2.4
	# The stump of its foot, standing.
	b.solid(_box(b,Vector3(SUB_BASE.y*0.42,SUB_BASE.x*0.5,SUB_BASE.y*0.42)),_settle(b,Vector3(x,SUB_BASE.x*0.5,0.0),0.3),_stone(b,0.92))
	b.solid(_prism(8,0.6,0.55,SUB_BASE.x,SUB_BASE.x+0.22,PI/8.0),_settle(b,Vector3(x,0.0,0.0),0.4),_stone(b))
	_drum_cluster(b,Transform3D(Basis.IDENTITY,Vector3(x,SUB_BASE.x+0.22,0.0)),0.35,_break(b,0.35,0.5,0.8,0.0))
	x += 0.9
	var yaw := 0.0
	for i in range(3):
		var length := b.rng.randf_range(0.8,1.15)
		yaw += b.rng.randf_range(-0.1,0.1)+b.rng.randf_range(-0.25,0.25)*weathered
		var roll := b.rng.randf()*TAU
		var lie := Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,-PI*0.5)*Basis(Vector3.UP,roll)
		var sink := b.rng.randf_range(0.02,0.06)+0.08*weathered
		var extra: Array[Plane] = []
		if i == 0 or b.rng.randf() < 0.3+0.5*weathered: extra = _break(b,length,0.5,0.25+0.3*weathered,0.0)
		_drum_cluster(b,Transform3D(lie,Vector3(x,0.55-sink,b.rng.randf_range(-0.1,0.1)+b.rng.randf_range(-0.3,0.3)*weathered)),length,extra)
		x += length+b.rng.randf_range(0.04,0.15)+b.rng.randf_range(0.1,0.5)*weathered
	var tip := Basis(Vector3.UP,yaw+b.rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,-PI*0.5+b.rng.randf_range(-0.3,0.3))
	_capital(b,Transform3D(tip,Vector3(x+0.3,ABACUS*0.92,b.rng.randf_range(-0.2,0.2))))
	_rubble(b,2.4,1+int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## A rope bridge's stone anchor (not one of PIECES: a fitting the kit isles
## set where a live rope bridge, scripts/rope_bridge.gd, comes to ground;
## docs/scenic/kit-isle-shared.md): the one anchor every isle's bridges
## hang from. Two squared posts either side of the deck, ANCHOR_POST (side,
## height) in two or three courses under a projecting course and a low
## pyramid cap, the ropes' lashing a band of rope round each; a long
## dressed sill across between their feet, its top the walk (y 0), walked
## on a clean hull; under it, by `spec`, a coursed plinth standing out of a
## cliff's lip, or a whole coursed head block the deck comes onto. The posts
## collide as clean blocks to their caps' tops; weathered, they lean, a cap
## may lie at a foot (drawn only), a little rubble.
## `spec` (the anchor's own frame, y up; each isle sets where its bridge's
## end and its ground are):
##   post_x    the posts' middles across X (default: just outside `width`)
##   post_z    their middles along Z
##   sill      the sill's half extents, `sill_at` its middle (its top y 0)
##   plinth    a coursed plinth under the sill: (half width, depth, half
##             depth), at `plinth_z`
##   head      a coursed head block instead of a sill: (width, depth under
##             its top, depth), its top walked
## Meta "posts": the posts' tops (for perching birds).
const ANCHOR_POST := Vector2(0.42,1.15)
const ANCHOR_LASHING := Color("8a7350")
static func bridge_anchor(seed_value: int, weathered := 0.4, width := 0.74, spec := {}) -> Node3D:
	var b := Build.new(seed_value,weathered,"BridgeAnchor")
	var post := ANCHOR_POST
	var post_x: float = spec.get("post_x",width*0.5+0.42)
	var post_z: float = spec.get("post_z",-0.15)
	var tops: Array = []
	# The ground (the anchor's frame), if the isle gives it: rubble lies on
	# it (none over a drop) and nothing is drawn under it.
	if spec.has("terrain"): b.terrain = spec.terrain
	# The base: a head block, or a sill (on a plinth).
	if spec.has("head"):
		var head: Vector3 = spec.head
		var hx := head.x*0.5
		var hz := head.z*0.5
		var foot := head.y
		b.settle = 0.35
		var top := func(_x: float) -> float: return foot-0.12
		_courses(b,Transform3D(Basis.IDENTITY,Vector3(0.0,-foot,0.0)),-hx,hx,0.0,top,hz,Callable(),0.42)
		for s: float in [-1.0,1.0]:
			var cap := Vector3(hx*0.5-0.01,0.06,hz+0.05)
			b.solid(_box(b,cap),_jiggle(b,Transform3D(Basis.IDENTITY,Vector3(s*hx*0.5,-0.06,0.0)),0.3),_stone(b,1.08),false,true)
		_walk_box(b,Transform3D.IDENTITY,hx,-foot,0.0,hz,-hz)
		b.settle = 0.0
	else:
		var sill: Vector3 = spec.get("sill",Vector3(width*0.5+0.75,0.12,0.4))
		var sill_at: Vector3 = spec.get("sill_at",Vector3(0.0,-sill.y+0.03,-0.2))
		b.lean = true
		b.solid(_box(b,sill,0.04),Transform3D(Basis.IDENTITY,sill_at),_stone(b,1.02),false)
		b.lean = false
		_walk_hull(b,Transform3D(Basis.IDENTITY,sill_at),[Plane(Vector3.RIGHT,sill.x),Plane(Vector3.LEFT,sill.x),Plane(Vector3.UP,sill.y),Plane(Vector3.DOWN,sill.y),Plane(Vector3.BACK,sill.z),Plane(Vector3.FORWARD,sill.z)])
		if spec.has("plinth"):
			var plinth: Vector3 = spec.plinth
			var under := sill_at.y-sill.y
			var line := func(_x: float) -> float: return under
			_courses(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,float(spec.get("plinth_z",0.2)))),-plinth.x,plinth.x,under-plinth.y,line,plinth.z,Callable(),0.38,false)
	# The posts, coursed, capped, the ropes lashed round them.
	for side: float in [-1.0,1.0]:
		var lean := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.004,0.01)+0.03*weathered)
		var foot := Transform3D(lean,Vector3(side*post_x,-0.18,post_z))
		var y := 0.0
		var k := 0
		while y < post.y-0.05:
			var h := minf(post.y-y,b.rng.randf_range(0.38,0.52))
			if post.y-(y+h) < 0.2: h = post.y-y
			# Each course drawn worn; the post walks past as one clean block.
			var half := Vector3(post.x*0.5-0.01*k,h*0.5-0.004,post.x*0.5-0.01*k)
			b.solid(_box(b,half,0.04),foot*_settle(b,Vector3(0.0,y+h*0.5,0.0),0.3),_stone(b,1.0+0.03*k),false)
			y += h
			k += 1
		# Collided as one clean upright block to its cap's top, so a walker
		# brushing past slides along it (the projecting course and the cap
		# would catch his shoulder).
		var tall := post.y+0.4
		_walk_hull(b,foot*Transform3D(Basis.IDENTITY,Vector3(0.0,tall*0.5,0.0)),[Plane(Vector3.RIGHT,post.x*0.5),Plane(Vector3.LEFT,post.x*0.5),Plane(Vector3.UP,tall*0.5),Plane(Vector3.DOWN,tall*0.5),Plane(Vector3.BACK,post.x*0.5),Plane(Vector3.FORWARD,post.x*0.5)])
		b.solid(_box(b,Vector3(post.x*0.5+0.04,0.05,post.x*0.5+0.04)),foot*Transform3D(Basis.IDENTITY,Vector3(0.0,post.y+0.05,0.0)),_stone(b,1.06),false,true)
		var cap: Array[Plane] = _prism(4,post.x*0.6,0.04,0.0,0.3,PI*0.25)
		if weathered > 0.45 and b.rng.randf() < weathered*0.6:
			var tip := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(1.1,1.5))
			# Lying where it fell: drawn only, never a stumble at a bridge's end.
			b.solid(cap,Transform3D(tip,Vector3(side*(post_x+0.55),0.12,post_z+b.rng.randf_range(-0.4,0.0))),_stone(b,1.05),false)
		else:
			b.solid(cap,foot*Transform3D(Basis.IDENTITY,Vector3(0.0,post.y+0.1,0.0)),_stone(b,1.05),false)
		b.solid(_box(b,Vector3(post.x*0.5+0.025,0.055,post.x*0.5+0.025),0.01),foot*Transform3D(Basis.IDENTITY,Vector3(0.0,0.86,0.0)),ANCHOR_LASHING,false,false,[],-1,1.0,false)
		tops.append(foot*Vector3(0.0,post.y+0.12,0.0))
	_rubble(b,post_x+0.9,int(round(weathered*b.rng.randf_range(1.0,3.0))),0.35 if spec.has("terrain") else INF)
	var node := b.finish()
	node.set_meta("posts",tops)
	return node

## 11. A carved chest: a stepped plinth, the chest's sides cut into blind
## arcading (little pointed niches between buttressed posts), a heavy lid
## with its edge chamfered deep. No figure, no lettering: a carved block.
## Weathered, the lid is cracked across and half slid off askew, a corner
## post broken away, moss in the niches.
static func tomb_chest(seed_value: int, weathered := 0.0, with_lid := true) -> Node3D:
	var b := Build.new(seed_value,weathered,"Chest")
	var hl := CHEST.x*0.5
	var hw := CHEST.y*0.5
	var plinth := 0.2
	b.solid(_box(b,Vector3(hl+0.2,plinth*0.5,hw+0.2)),_settle(b,Vector3(0.0,plinth*0.5,0.0),0.3),_stone(b,0.9))
	var body := CHEST.z-CHEST.w-plinth
	var y0 := plinth
	# The core, set back; the rails and posts proud of it.
	b.solid(_box(b,Vector3(hl-0.07,body*0.5,hw-0.07)),Transform3D(Basis.IDENTITY,Vector3(0.0,y0+body*0.5,0.0)),_stone(b,0.78),true,true)
	for s: float in [-1.0,1.0]:
		b.solid(_box(b,Vector3(hl,0.06,hw)),_settle(b,Vector3(0.0,y0+0.06+(0.0 if s < 0.0 else body-0.12),0.0),0.4),_stone(b,1.0))
	# Niches along each long side: posts between, a pointed head in each.
	var niches := 5
	var pitch := CHEST.x/niches
	for face: float in [-1.0,1.0]:
		for k in range(niches+1):
			var x := -hl+pitch*k
			if weathered > 0.5 and (k == 0 or k == niches) and b.rng.randf() < weathered*0.5: continue
			b.solid(_box(b,Vector3(0.06,body*0.5-0.1,0.07),0.015),_settle(b,Vector3(x,y0+body*0.5,face*(hw-0.06)),0.5),_stone(b,1.02))
		for k in range(niches):
			var x := -hl+pitch*(k+0.5)
			for h: float in [-1.0,1.0]:
				var planes: Array[Plane] = [Plane(Vector3.BACK,0.06),Plane(Vector3.FORWARD,0.06),Plane(Vector3.UP,0.12)]
				planes.append(Plane(Vector3(-h,0.0,0.0),0.0))
				planes.append(Plane(Vector3(h,0.0,0.0),pitch*0.5-0.05))
				var slant := Vector3(h*0.62,-0.78,0.0).normalized()
				planes.append(Plane(slant,slant.dot(Vector3(h*(pitch*0.5-0.06),-0.2,0.0))))
				b.solid(planes,Transform3D(Basis.IDENTITY,Vector3(x,y0+body-0.24,face*(hw-0.06))),_stone(b,1.0),false,true)
	# The ends: a quatrefoil-ish boss in a square panel.
	for s: float in [-1.0,1.0]:
		b.solid(_axial_prism(8,0.16,0.05),Transform3D(Basis(Vector3.BACK,PI*0.5)*Basis(Vector3.RIGHT,PI*0.5),Vector3(s*(hl-0.02),y0+body*0.5,0.0)),_stone(b,1.0),false,true)
	# Without its lid (the treasure chest, scripts/chest/, builds its own to lift).
	if not with_lid:
		_rubble(b,1.7,int(round(weathered*b.rng.randf_range(2.0,4.0))))
		return b.finish()
	# The lid.
	var lid := Vector3(hl+0.07,CHEST.w*0.5,hw+0.07)
	var lid_y := CHEST.z-CHEST.w*0.5
	var lid_planes := _box(b,lid,0.02)
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.BACK,Vector3.RIGHT]:
			var n := (axis*s+Vector3.UP*0.9).normalized()
			lid_planes.append(Plane(n,n.dot(axis*s*(lid.dot(axis.abs()))+Vector3.UP*(lid.y-0.1))))
	if weathered > 0.3 and b.rng.randf() < 0.4+weathered*0.6:
		var at := b.rng.randf_range(-0.4,0.4)
		var cut := Vector3(1.0,0.0,b.rng.randf_range(-0.4,0.4)).normalized()
		var moved := Transform3D(Basis(Vector3.UP,b.rng.randf_range(0.12,0.3))*Basis(Vector3.BACK,-0.07-0.08*weathered),Vector3(0.28,0.0,0.2*weathered))
		for side: float in [-1.0,1.0]:
			var planes := lid_planes.duplicate()
			planes.append(Plane(cut*side,side*at-0.01))
			var pose := Transform3D(Basis.IDENTITY,Vector3(0.0,lid_y,0.0))
			if side > 0.0: pose = Transform3D(moved.basis,Vector3(0.0,lid_y+0.06,0.0)+moved.origin)
			b.solid(planes,pose,_stone(b,1.05))
	else:
		b.solid(lid_planes,_settle(b,Vector3(0.0,lid_y,0.0),0.5),_stone(b,1.05))
	_rubble(b,1.7,int(round(weathered*b.rng.randf_range(2.0,4.0))))
	return b.finish()

## 12. Floor slabs: a patch of uneven slabs in rough rows, sunk and tipped
## out of true even as laid long ago, grass and moss in the joints; one
## worn ledger in the middle. Weathered, slabs are gone (moss where they
## lay), heaved, cracked and settled, a pier's broken base among them.
static func floor_slabs(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Floor")
	var size := FLOOR.x
	var z := -size*0.5
	while z < size*0.5-0.05:
		var depth := minf(FLOOR.y*b.rng.randf_range(0.75,1.25),size*0.5-z)
		if size*0.5-(z+depth) < 0.35: depth = size*0.5-z
		var x := -size*0.5
		while x < size*0.5-0.05:
			var x1 := minf(x+FLOOR.y*b.rng.randf_range(0.7,1.6),size*0.5)
			if size*0.5-x1 < 0.35: x1 = size*0.5
			var edge := x < -size*0.5+0.1 or x1 > size*0.5-0.1 or z < -size*0.5+0.1 or z+depth > size*0.5-0.1
			if b.rng.randf() > (0.42 if edge else 0.2)*weathered:
				var lift := b.rng.randf_range(-0.035,0.01)+b.rng.randf_range(-0.05,0.04)*weathered
				var tilt := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.008,0.03)+b.rng.randf()*0.09*weathered)
				var at := Vector3((x+x1)*0.5,FLOOR.z*0.5+lift,z+depth*0.5)
				var half := Vector3((x1-x)*0.5-0.03,FLOOR.z*0.5,depth*0.5-0.03)
				if b.rng.randf() < 0.3*weathered:
					var n := Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized()
					for side: float in [-1.0,1.0]:
						var planes := _box(b,half)
						planes.append(Plane(n*side,-0.012))
						var drop := Vector3(0.0,-0.04,0.0) if side > 0.0 else Vector3.ZERO
						b.solid(planes,Transform3D(tilt,at+drop),_stone(b,1.02))
				else:
					b.solid(_box(b,half),Transform3D(tilt,at),_stone(b,1.02))
			x = x1
		z += depth
	# The bed under it, green where the slabs part.
	var bed := Color(MOSS).lerp(Color("4a4234"),0.55-weathered*0.5)
	b.solid(_box(b,Vector3(size*0.5+0.06,0.05,size*0.5+0.06),0.01),Transform3D(Basis.IDENTITY,Vector3(0.0,0.04,0.0)),bed,true,false,[],-1,1.0,false)
	if weathered > 0.4:
		var at := Vector3(b.rng.randf_range(-1.2,1.2),0.0,b.rng.randf_range(-1.2,-0.4))
		b.solid(_prism(8,0.62,0.56,0.0,0.36,PI/8.0),_settle(b,at,0.5),_stone(b,0.95))
		_drum_cluster(b,Transform3D(Basis.IDENTITY,at+Vector3(0.0,0.36,0.0)),0.4,_break(b,0.4,0.5,0.9,0.0))
	return b.finish()

## 13. A grand stair: two of the stair's flights (`_flight`, GRAND_STEPS
## each of GRAND_RISER by GRAND_TREAD), GRAND_WIDTH wide, one above the
## other with a landing GRAND_LANDING deep between them, climbing toward -Z
## to its head 2 STEPS RISERs up (4.48 m): a broad ceremonial way up onto
## a terrace or a hill.
## The upper flight stands on its own steps and cheeks carried down to the
## ground; newels at the foot and on the landing. Weathered: steps cracked
## and settled, a cheek torn down on each flight, a newel's cap fallen at
## the foot, rubble. Meta "foot" and "head": the middle of its foot on the
## ground and of its head's landing on top.
static func grand_stair(seed_value: int, weathered := 0.0, shelter := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"GrandStair")
	b.shelter = shelter
	var run1 := (GRAND_STEPS-1)*GRAND_TREAD+GRAND_LANDING
	var run2 := (GRAND_STEPS-1)*GRAND_TREAD+LANDING
	var front := (run1+run2)*0.5
	var rise := GRAND_STEPS*GRAND_RISER
	_flight(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,front-run1*0.5)),GRAND_STEPS,GRAND_WIDTH,GRAND_LANDING,0.0,GRAND_RISER,GRAND_TREAD)
	_flight(b,Transform3D(Basis.IDENTITY,Vector3(0.0,rise,front-run1-run2*0.5)),GRAND_STEPS,GRAND_WIDTH,LANDING,rise,GRAND_RISER,GRAND_TREAD)
	# A newel's cap fallen off at the foot, lying in the grass beside it.
	if weathered > 0.3:
		var side := -1.0 if b.rng.randf() < 0.5 else 1.0
		var at := Vector3(side*(GRAND_WIDTH*0.5+CHEEK.x+0.9),0.0,front+b.rng.randf_range(-0.6,0.4))
		_gablet(b,Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,side*1.2),at+Vector3(0.0,0.24,0.0)),NEWEL.x*0.5+0.05,0.42)
	_rubble(b,GRAND_WIDTH*0.5+1.2,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	var root := b.finish()
	root.set_meta("foot",Vector3(0.0,0.0,front+0.6))
	root.set_meta("head",Vector3(0.0,2.0*rise,front-run1-run2+LANDING*0.5))
	return root

## 14. A stone circle, the abbey's elder: a ring of CIRCLE_STONES great
## sarsens, rough-dressed and narrowing a little to their tops, out of
## plumb, carrying a ring of lintels cut to the curve (run round as a loop,
## LINTEL.y over the bare top where one has fallen: a twirled jump over the
## gap, or kicks up between its sarsens); a gap at the front (+Z) for the
## way in. Inside, the great trilithon across the back, its narrow slot a
## window on the circle's axis, its lintel the summit; an altar stone
## before it; a fallen trilithon by the ring (its stub standing, its
## partner lying in toward the middle, its lintel broken in the grass:
## steps up onto the ring); a sarsen fallen in, leaning against the ring
## (walked up, a jump-catch onto the lintels). Centuries old even at
## weathered 0, moss on the tops and lichen; weathered, lintels have fallen
## (round(weathered x 3), never one a way up lands on) and lie toppled in
## the grass, cracked; ivy hangs from the lintels. Meta "ring": {top,
## lintels [[top middle, standing]], trilithon (its top's middle), stub,
## lying (their tops' middles), lean_foot, lean_head, fallen, missing,
## gone}. `missing`: sarsens (by index) broken away with the ground under
## them (a crag's slumped edge): neither they nor the lintels they carried
## (`gone`, standing false) are built, the scene places them; no lintel
## next to the gap falls, so the ring runs on to its edge.
static func stone_circle(seed_value: int, weathered := 0.0, missing: Array = []) -> Node3D:
	var b := Build.new(seed_value,weathered,"StoneCircle")
	b.ground = 0.0
	var pitch := TAU/CIRCLE_STONES
	var ring_top := SARSEN.y+LINTEL.y
	# The fallen lintels: never the entrance's (over the front gap), the
	# back one (before the great trilithon), nor those the leaning stone and
	# the stub lead up onto; never two side by side.
	var keep := [CIRCLE_STONES-1,CIRCLE_STONES/2-1,LEAN_AT-1,LEAN_AT,STUB_AT-1,STUB_AT,STUB_AT+1]
	var gone: Array = []
	for k in range(CIRCLE_STONES):
		if k in missing or (k+1)%CIRCLE_STONES in missing: gone.append(k)
	for k: int in gone:
		keep.append_array([k,(k+1)%CIRCLE_STONES,(k+CIRCLE_STONES-1)%CIRCLE_STONES])
	var may: Array = []
	for k in range(CIRCLE_STONES):
		if not k in keep: may.append(k)
	var fallen: Array = []
	var count := int(round(weathered*3.0))
	for attempt in range(40):
		if fallen.size() >= count: break
		var k: int = may[b.rng.randi()%may.size()]
		if k in fallen or (k+1)%CIRCLE_STONES in fallen or (k+CIRCLE_STONES-1)%CIRCLE_STONES in fallen: continue
		fallen.append(k)
	# The sarsens.
	for k in range(CIRCLE_STONES):
		if k in missing: continue
		var a := (k+0.5)*pitch
		_sarsen(b,Transform3D(Basis(Vector3.UP,a),_round(a,CIRCLE_RADIUS)),SARSEN,0.15)
	# The lintels, each from one sarsen's middle to the next's, cut to the
	# radii there; the fallen ones toppled in the grass.
	var lintels: Array = []
	for k in range(CIRCLE_STONES):
		var a0 := (k+0.5)*pitch
		var a1 := (k+1.5)*pitch
		var am := (k+1.0)*pitch
		var mid := _round(am,CIRCLE_RADIUS*cos(pitch*0.5))
		lintels.append([mid+Vector3(0.0,ring_top,0.0),not k in fallen and not k in gone])
		var half := Vector3(CIRCLE_RADIUS*sin(pitch*0.5)+LINTEL.x,LINTEL.y*0.5,LINTEL.x*0.5)
		# Broken: which ends stay on their sarsens (-1 the first's, +1 the
		# next's), out over the gap to the break.
		var stays: Array = []
		if k in fallen: stays = [-1.0,1.0]
		elif k in gone:
			if not k in missing: stays.append(-1.0)
			if not (k+1)%CIRCLE_STONES in missing: stays.append(1.0)
		if k in fallen:
			_toppled_lintel(b,am,LINTEL_BREAK+0.5)
		if (k in fallen or k in gone) and stays.is_empty(): continue
		var pose := Transform3D(Basis(Vector3.UP,am),mid+Vector3(0.0,SARSEN.y+half.y,0.0))
		if stays.is_empty(): pose = _jiggle(b,pose,0.3)
		var inv := pose.affine_inverse()
		var ends: Array[Plane] = [inv*Plane(Vector3(cos(a1),0.0,-sin(a1)),-0.008),inv*Plane(-Vector3(cos(a0),0.0,-sin(a0)),-0.008)]
		# Each walked on a true hull too (`_walk_hull`): a worn chunk out of
		# a lintel this long can take its top for metres.
		if stays.is_empty():
			b.solid(_box(b,half,0.07),pose,_stone(b,1.08),true,true,ends,-1,1.2)
			_walk_hull(b,pose,_box(b,half)+ends)
		else:
			for side: float in stays:
				var n := Vector3(-side,b.rng.randf_range(-0.35,0.35),b.rng.randf_range(-0.3,0.3)).normalized()
				var cut: Array[Plane] = ends.duplicate()
				cut.append(Plane(n,n.dot(Vector3(side*LINTEL_BREAK*0.5,0.0,0.0))))
				b.solid(_box(b,half,0.07),pose,_stone(b,1.08),true,true,cut,-1,1.2)
				_walk_hull(b,pose,_box(b,half)+cut)
			continue
		if b.rng.randf() < 0.3+0.5*weathered:
			b.hang(mid+Vector3(0.0,0.0,0.0)+_round(am,b.rng.randf_range(-0.4,0.4)),b.rng.randf_range(0.8,2.4),true,SARSEN.y)
	# The great trilithon across the back, its lintel the summit.
	var tri := Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-TRILITHON_AT))
	for s: float in [-1.0,1.0]:
		_sarsen(b,tri*Transform3D(Basis.IDENTITY,Vector3(s*(TRILITHON_SLOT+TRILITHON.x)*0.5,0.0,0.0)),TRILITHON,0.12)
	var span := TRILITHON_SLOT+TRILITHON.x*2.0+0.1
	b.solid(_box(b,Vector3(span*0.5,LINTEL.y*0.5,TRILITHON.z*0.5+0.04),0.08),tri*_settle(b,Vector3(0.0,TRILITHON.y+LINTEL.y*0.5,0.0),0.3),_stone(b,1.08),true,true,[],-1,1.2)
	b.hang(Vector3(0.0,0.0,-TRILITHON_AT),b.rng.randf_range(1.2,2.6),true,TRILITHON.y)
	# The altar stone before it, lying.
	b.solid(_box(b,Vector3(1.6,0.32,0.5),0.08),_settle(b,Vector3(b.rng.randf_range(-0.3,0.3),0.22,-TRILITHON_AT+2.6),0.6),_stone(b,1.0),true,true,[],-1,1.4)
	# The fallen trilithon: its stub by the ring, turned end on to it (its
	# width along the way up from the lying stone to the lintel), broken
	# across its inner corner, its partner lying in from it, its lintel
	# broken in two in the grass.
	var sa := (STUB_AT+1.0)*pitch
	var stub_r := CIRCLE_RADIUS*cos(pitch*0.5)-LINTEL.x*0.5-STUB_OFF-TRILITHON.x*0.5
	var stub_size := Vector3(TRILITHON.x,STUB,TRILITHON.z)
	var corner := Vector3(0.7,1.0,b.rng.randf_range(-0.3,0.3)).normalized()
	var broken: Array[Plane] = [Plane(corner,corner.dot(Vector3(TRILITHON.x*0.5-STUB_CORNER,(STUB+0.3)*0.5,0.0)))]
	_sarsen(b,Transform3D(Basis(Vector3.UP,sa+PI*0.5),_round(sa,stub_r)),stub_size,0.06,broken)
	# The lying partner broke as it fell: the toy's length lies here, a
	# little shorter as the stones grow (4.0 m at the defaults: a whole 8 m
	# stone would block the ring's floor across its middle; its inner end
	# keeps clear of a turret or an altar by the middle).
	var lying := Vector3(TOY_TRILITHON.x,TOY_TRILITHON.y-0.75*(HENGE_GROW-1.0),TOY_TRILITHON.z)
	var lie_r := stub_r-TRILITHON.x*0.5-0.15-lying.y*0.5
	var lie := Basis(Vector3.UP,sa+b.rng.randf_range(-0.04,0.04))*Basis(Vector3.RIGHT,PI*0.5)*Basis(Vector3.UP,b.rng.randf_range(-0.03,0.03))
	b.solid(_box(b,lying*0.5,0.1),Transform3D(lie,_round(sa,lie_r)+Vector3(0.0,TRILITHON.z*0.5-0.15,0.0)),_stone(b,1.1),true,true,[],-1,1.6)
	# The stub's broken-off pieces, stacked on the lying stone's end by it:
	# steps up from the lying stone's top to the stub's, each the same and
	# 1.5 m and under (none in the toy era, the stub one step up).
	var lie_top := TRILITHON.z-0.15
	# (Rises up to STUB_STEP: three of 1.13 m packed 1.25 apart at ratio
	# 0.95 weren't climbed, nor three of 1.21 at 1.0; two of 1.5 or 1.62 are.)
	var steps := ceili((STUB-lie_top)/STUB_STEP)-1
	for k in range(steps):
		var top := lie_top+(STUB-lie_top)*float(k+1)/float(steps+1)
		var r := stub_r-TRILITHON.x*0.5-0.75-1.25*float(steps-1-k)
		var piece := Vector3(TRILITHON.z*0.5,(top-lie_top)*0.5+0.05,0.6)
		b.solid(_box(b,piece,0.06),Transform3D(Basis(Vector3.UP,sa+PI*0.5+b.rng.randf_range(-0.05,0.05)),_round(sa,r)+Vector3(0.0,lie_top+piece.y-0.1,0.0)),_stone(b,1.06),true,true,[],-1,1.4)
	var la := sa-0.42
	var piece_len := (span-0.4)*0.5
	for s: float in [-1.0,1.0]:
		var tip := Basis(Vector3.UP,la+PI*0.5+s*0.2+b.rng.randf_range(-0.1,0.1))*Basis(Vector3.BACK,b.rng.randf_range(-0.12,0.12))
		var at := _round(la,CIRCLE_RADIUS-3.6)+_round(la+PI*0.5,s*(piece_len*0.5+0.3))+Vector3(0.0,LINTEL.y*0.5-0.1,0.0)
		var cut: Array[Plane] = [Plane(Vector3(-s,0.25,0.0).normalized(),piece_len*0.5-0.05)]
		b.solid(_box(b,Vector3(piece_len*0.5+0.2,LINTEL.y*0.5,TRILITHON.z*0.5),0.08),Transform3D(tip,at),_stone(b,1.05),true,true,cut,-1,1.5)
	# The leaning stone, fallen in against the sarsen LEAN_AT: its top a
	# slope from the floor to LEAN_TOP against the sarsen's inner face, its
	# head cut square on it.
	var al := (LEAN_AT+0.5)*pitch
	var slope := deg_to_rad(LEAN.z)
	var head := CIRCLE_RADIUS-SARSEN.z*0.5-0.05
	var low := head-LEAN_TOP/tan(slope)
	var r_a := low-0.9
	var r_b := head+0.4
	var top_mid := Vector2((r_a+r_b)*0.5,LEAN_TOP-(head-(r_a+r_b)*0.5)*tan(slope))
	var centre := top_mid-Vector2(-sin(slope),cos(slope))*LEAN.y*0.5
	var lean_pose := Transform3D(Basis(Vector3.UP,al)*Basis(Vector3.RIGHT,-slope),_round(al,centre.x)+Vector3(0.0,centre.y,0.0))
	var square: Array[Plane] = [lean_pose.affine_inverse()*Plane(_round(al,1.0),head)]
	b.solid(_box(b,Vector3(LEAN.x*0.5,LEAN.y*0.5,(r_b-r_a)/cos(slope)*0.5),0.1),lean_pose,_stone(b,1.1),true,true,square,-1,1.4)
	# Where its head rests lower than a jump-catch under the lintels (the
	# taller sarsens), a block broken off the upright lies wedged on it
	# against the sarsen: LEAN_BLOCK deep, its top a jump up from the slope
	# at its foot, the lintels a jump up from it.
	var lean_head := _round(al,head-0.35)+Vector3(0.0,LEAN_TOP-0.35*tan(slope),0.0)
	if LEAN_TOP < ring_top-0.76:
		var foot_y := LEAN_TOP-LEAN_BLOCK*tan(slope)
		var top := minf(foot_y+1.55,ring_top-0.75)
		var half := Vector3(LEAN.x*0.5,(top-foot_y)*0.5+0.2,LEAN_BLOCK*0.5)
		b.solid(_box(b,half,0.06),Transform3D(Basis(Vector3.UP,al),_round(al,head-LEAN_BLOCK*0.5)+Vector3(0.0,top-half.y,0.0)),_stone(b,1.08),true,true,[],-1,1.4)
		lean_head = _round(al,head-LEAN_BLOCK*0.5)+Vector3(0.0,top,0.0)
	# Tufts at the stones' feet.
	for k in range(CIRCLE_STONES):
		if b.rng.randf() < 0.6 and not k in missing: b.tuft(_round((k+0.5)*pitch+b.rng.randf_range(-0.12,0.12),CIRCLE_RADIUS+b.rng.randf_range(-0.9,0.9)),b.rng.randf_range(0.25,0.45),5)
	var root := b.finish()
	var stub_top := _round(sa,stub_r)+Vector3(0.0,STUB,0.0)
	root.set_meta("ring",{"top":ring_top,"lintels":lintels,"fallen":fallen,"missing":missing.duplicate(),"gone":gone,"break":LINTEL_BREAK,
		"trilithon":Vector3(0.0,TRILITHON.y+LINTEL.y,-TRILITHON_AT),
		"stub":stub_top,"lying":_round(sa,lie_r)+Vector3(0.0,TRILITHON.z-0.15,0.0),
		"lean_foot":_round(al,low-0.6),"lean_head":lean_head})
	return root

## A point `r` out from the middle at angle `a` (from +Z toward +X).
static func _round(a: float, r: float) -> Vector3:
	return Vector3(sin(a),0.0,cos(a))*r

## A sarsen at `pose` (its foot's middle, X along its face): `size` wide,
## tall and thick, rough-dressed, its faces narrowing `taper` (m a side,
## half that on its thin faces) to a flat top, sunk a little, out of plumb;
## cut by `extra` too (its own frame: the middle of the block, sunk 0.3).
static func _sarsen(b: Build, pose: Transform3D, size: Vector3, taper: float, extra: Array[Plane] = []) -> void:
	var tall := size.y+0.3
	var half := Vector3(size.x*0.5,tall*0.5,size.z*0.5)
	var planes := _box(b,half,0.12)
	for s: float in [-1.0,1.0]:
		var n := Vector3(s*tall,taper,0.0).normalized()
		planes.append(Plane(n,n.dot(Vector3(s*half.x,-half.y,0.0))))
		var m := Vector3(0.0,taper*0.5,s*tall).normalized()
		planes.append(Plane(m,m.dot(Vector3(0.0,-half.y,s*half.z))))
	var lean := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.0,0.01)+0.008*b.weathered)
	b.solid(planes,pose*Transform3D(lean,Vector3(0.0,size.y-half.y,0.0)),_stone(b,1.12),true,true,extra,-1,1.6)

## A lintel fallen from the ring at angle `a`, `length` long: in the grass
## just outside the ring or in, lying across the way it fell, tipped, half
## sunk; weathered, cracked in two.
static func _toppled_lintel(b: Build, a: float, length: float) -> void:
	var r := CIRCLE_RADIUS+(1.7 if b.rng.randf() < 0.65 else -2.0)
	var yaw := Basis(Vector3.UP,a+b.rng.randf_range(-0.35,0.35))*Basis(Vector3.BACK,b.rng.randf_range(-0.1,0.1))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.2,0.2))
	var at := _round(a,r)+Vector3(0.0,LINTEL.y*0.5-0.12,0.0)
	var half := Vector3(length*0.5,LINTEL.y*0.5,LINTEL.x*0.5)
	if b.weathered > 0.5:
		var crack := Vector3(1.0,0.0,b.rng.randf_range(-0.4,0.4)).normalized()
		var off := b.rng.randf_range(-0.5,0.5)
		for s: float in [-1.0,1.0]:
			var cut: Array[Plane] = [Plane(-crack*s,-s*off-0.03)]
			var shift := Transform3D(Basis(Vector3.UP,s*b.rng.randf_range(0.03,0.12)),crack*s*0.08+Vector3(0.0,-0.04*float(s > 0.0),0.0))
			b.solid(_box(b,half,0.07),Transform3D(yaw,at)*shift,_stone(b,1.06),true,true,cut,-1,1.5)
	else:
		b.solid(_box(b,half,0.07),Transform3D(yaw,at),_stone(b,1.06),true,true,[],-1,1.5)

# --- Parts --------------------------------------------------------------------

## A clustered pier at `pose`, `height` to its abacus top: sub-base, moulded
## base, drums of core and shafts, a shaft-ring, the capital; snapped at
## `broken` (its drums ending in a ragged head) if that is under height.
## `sub`: on its sub-base step (a lone pier) or straight on its base.
static func _pier(b: Build, pose: Transform3D, height: float, broken := INF, sub := true) -> void:
	var y := 0.0
	if sub:
		b.solid(_box(b,Vector3(SUB_BASE.y*0.5,SUB_BASE.x*0.5,SUB_BASE.y*0.5)),pose*_settle(b,Vector3(0.0,SUB_BASE.x*0.5,0.0),0.3),_stone(b,0.9))
		y = SUB_BASE.x
	b.solid(_prism(8,0.66,0.6,0.0,0.24,PI/8.0),pose*_settle(b,Vector3(0.0,y,0.0),0.4),_stone(b,0.96))
	b.solid(_prism(16,0.6,0.52,0.0,0.13),pose*_settle(b,Vector3(0.0,y+0.24,0.0),0.4),_stone(b,1.02))
	y += 0.37
	var shaft_top := height-0.62
	var ring_at := lerpf(y,shaft_top,0.5)
	var ringed := false
	while y < minf(shaft_top,broken)-0.05:
		var length := minf(b.rng.randf_range(0.55,0.8),shaft_top-y)
		if shaft_top-(y+length) < 0.25: length = shaft_top-y
		var extra: Array[Plane] = []
		var last := y+length >= broken-0.05
		if last:
			length = maxf(0.3,broken-y)
			extra = _break(b,length,0.55,0.3+0.35*b.weathered,0.0)
		var slip := Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1))*(0.006+0.025*b.weathered)
		_drum_cluster(b,pose*Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.03,0.03)+b.rng.randf_range(-0.12,0.12)*b.weathered),Vector3(0.0,y,0.0)+slip),length,extra)
		y += length
		if not ringed and y >= ring_at and y < minf(shaft_top,broken)-0.2:
			ringed = true
			b.solid(_prism(16,0.53,0.53,0.0,0.09),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,0.0)),_stone(b,1.05))
			y += 0.09
		if last: return
	if broken >= height: _capital(b,pose*_jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,shaft_top,0.0)),0.6))

## One drum of a clustered shaft from its foot at `pose`, `length` tall:
## the octagonal core, four main shafts and four lesser in the diagonals,
## each its own block; `extra` cuts all of them (a break).
static func _drum_cluster(b: Build, pose: Transform3D, length: float, extra: Array[Plane]) -> void:
	var tone := _stone(b)
	b.solid(_prism(8,PIER_CORE,PIER_CORE,0.0,length,PI/8.0),pose,tone,true,true,extra)
	for k in range(8):
		var a := TAU*k/8.0
		var main := k%2 == 0
		var s: Vector2 = SHAFT_MAIN if main else SHAFT_LESSER
		var at := Vector3(cos(a),0.0,sin(a))*s.y
		var cut: Array[Plane] = []
		for p in extra: cut.append(Plane(p.normal,p.d-p.normal.dot(at)))
		b.solid(_prism(8 if main else 6,s.x,s.x,0.0,length),pose*Transform3D(Basis.IDENTITY,at),tone*(1.0+b.rng.randf_range(-0.04,0.04)),true,true,cut,-1,0.8)

## A capital from its foot at `pose`: a bell wreathed in leaves, the abacus.
static func _capital(b: Build, pose: Transform3D) -> void:
	_bell(b,pose,0.5,ABACUS,0.46,8)
	b.solid(_prism(8,ABACUS,ABACUS-0.04,0.0,0.16,PI/8.0),pose*_settle(b,Vector3(0.0,0.46,0.0),0.5),_stone(b,1.04))

## A capital's bell from its foot at `pose`, `low` to `high` apothem over
## `h`, and `leaves` faceted leaves curling out from round its top: stiff-
## leaf, cut in planes.
static func _bell(b: Build, pose: Transform3D, low: float, high: float, h: float, leaves: int) -> void:
	var tone := _stone(b,1.02)
	b.solid(_prism(8,low,high*0.88,0.0,h,PI/8.0),pose,tone)
	b.solid(_prism(8,low+0.03,low+0.03,0.0,0.07,PI/8.0),pose,tone*0.95)
	for k in range(leaves):
		var a := TAU*(k+0.5)/leaves+b.rng.randf_range(-0.1,0.1)
		var out := Vector3(cos(a),0.0,sin(a))
		if b.rng.randf() < 0.35*b.weathered: continue
		# A leaf: a lozenge rising up the bell and curling out under the
		# abacus's lip.
		var basis := Basis(out.cross(Vector3.UP).normalized(),Vector3.UP,-out.cross(Vector3.UP).normalized().cross(Vector3.UP))
		basis = Basis(out.cross(Vector3.UP).normalized(),(Vector3.UP+out*0.55).normalized(),out)
		basis = basis.orthonormalized()
		var leaf: Array[Plane] = [Plane(Vector3.BACK,0.06),Plane(Vector3.FORWARD,0.05),Plane(Vector3.DOWN,0.0),Plane(Vector3.UP,h*0.8)]
		for s: float in [-1.0,1.0]:
			leaf.append(Plane(Vector3(s,0.3,0.0).normalized(),0.11))
			leaf.append(Plane(Vector3(s,-0.6,0.0).normalized(),0.02))
			leaf.append(Plane(Vector3(s*0.5,0.0,0.85).normalized(),0.06))
		var at := out*(low+0.02)+Vector3.UP*h*0.12
		b.solid(leaf,pose*Transform3D(basis,at),tone*(1.0+b.rng.randf_range(-0.06,0.08)),false,true,[],-1,0.6)

## A buttress at `pose` (its back against the face it props at the
## origin, standing out toward +Z), in `stages` [top, depth] from the
## ground up, `width` across: each stage coursed, each set-off a sloped
## weathering at its front (the rest flat: a tread), `pinnacle` a gablet
## and spire on the last, `snapped` its spire broken.
static func _buttress(b: Build, pose: Transform3D, stages: Array, width: float, snapped := false, pinnacle := false) -> void:
	var y := 0.0
	var hx := width*0.5
	for i in range(stages.size()):
		var top: float = stages[i][0]
		var depth: float = stages[i][1]
		var cy := y
		var k := 0
		while cy < top-0.08:
			var y1 := minf(top,cy+b.rng.randf_range(0.42,0.58)*(2.0 if b.lean else 1.0))
			if top-y1 < 0.2: y1 = top
			# In two blocks, front and back, the joint staggered course by course.
			var split := depth*(0.45 if k%2 == 0 else 0.62)
			# Lean stone: one block a course, front to back.
			for part: Vector2 in ([Vector2(-0.05,depth)] if b.lean else [Vector2(-0.05,split),Vector2(split,depth)]):
				if part.y-part.x < 0.2: continue
				var half := Vector3(hx-0.004,(y1-cy)*0.5-0.004,(part.y-part.x)*0.5-0.004)
				var at := Vector3(0.0,(cy+y1)*0.5,(part.x+part.y)*0.5)
				var planes := _box(b,half)
				if i < stages.size()-1 and y1 >= top-0.01 and part.y > depth-0.01:
					# The set-off's weathering: the front edge sloped off.
					var n := Vector3(0.0,1.0,1.1).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,half.y,half.z-0.24))))
				b.solid(planes,pose*_settle(b,at,0.4+0.2*i),_stone(b,1.0 if i%2 == 0 else 0.97))
			cy = y1
			k += 1
		y = top
	var last: float = stages[-1][1]
	if pinnacle:
		var base := pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,last*0.5))
		_gablet(b,base,hx+0.02,0.55,last*0.5+0.02)
		_spire(b,base*Transform3D(Basis.IDENTITY,Vector3(0.0,0.2,0.0)),minf(hx,last*0.5)*0.62,2.1,snapped)

## A gable cap on a block's head at `pose` (its foot's middle): `half`
## across, `rise` high, ridged along Z, `depth` (half) from the middle; with
## a ragged ridge when weathered.
static func _gablet(b: Build, pose: Transform3D, half: float, rise: float, depth := -1.0) -> void:
	if depth < 0.0: depth = half
	var planes: Array[Plane] = [Plane(Vector3.DOWN,0.0),Plane(Vector3.BACK,depth),Plane(Vector3.FORWARD,depth)]
	for s: float in [-1.0,1.0]:
		var n := Vector3(s*rise,half,0.0).normalized()
		planes.append(Plane(n,n.dot(Vector3(s*half,0.0,0.0))))
	planes.append(Plane(Vector3.UP,rise-0.03))
	b.solid(planes,_jiggle(b,pose,0.6),_stone(b,1.05),true,true,[],-1,1.2)

## A pinnacle's spire from its foot at `pose`: a square shaft with little
## gablets, then a steep four-sided spire with crockets up its edges and a
## finial knop; `snapped`, broken off partway.
static func _spire(b: Build, pose: Transform3D, r: float, h: float, snapped: bool) -> void:
	var tone := _stone(b,1.04)
	var shaft := h*0.32
	var cut := INF
	if snapped: cut = b.rng.randf_range(0.2,0.75)*h
	if cut < 0.25: return
	var extra: Array[Plane] = []
	if cut < shaft: extra = _break(b,cut,r,0.5,0.0)
	b.solid(_prism(4,r,r,0.0,minf(shaft,cut),PI*0.25),pose,tone,true,true,extra)
	if cut <= shaft: return
	var spire := _prism(4,r*1.05,0.015,shaft,h,PI*0.25)
	var cuts: Array[Plane] = []
	if cut < h: cuts = _break(b,cut,r*0.6,0.25,0.0)
	b.solid(spire,pose,tone,true,true,cuts,-1,0.7)
	# Crockets: a small knob up each edge every third of the way.
	for k in range(3):
		var t := (k+0.6)/3.6
		var yy := lerpf(shaft,h,t)
		if yy > (cut*0.7 if cut < h else cut-0.1): break
		var rr := lerpf(r*1.05,0.02,t)*1.414
		for e in range(4):
			if b.rng.randf() < 0.3*b.weathered: continue
			var a := TAU*e/4.0
			var at := Vector3(cos(a)*rr,yy,sin(a)*rr)
			b.solid(_box(b,Vector3(0.05,0.05,0.05),0.01),pose*Transform3D(Basis(Vector3.UP,-a)*Basis(Vector3.BACK,0.5),at),tone,false,false)
	if cut >= h: b.solid(_prism(6,0.07,0.04,h-0.05,h+0.14),pose,tone,false,false)

## A pointed arch ring at `pose`, centred at `cx`, springing at `spring`,
## clear half span `h`, arc radius `radius`, `d` deep (half), in two moulded
## orders and a hood: `lost` voussoirs fallen from the crown on side
## `lost_side`; stones whose middle stands over `top` (a ruin line) gone.
static func _arch_ring(b: Build, pose: Transform3D, cx: float, spring: float, h: float, radius: float, d: float, hood: bool, lost := 0, lost_side := 1.0, top := Callable()) -> void:
	var n := maxi(5,int(round(radius*1.6)))
	_ring_order(b,pose,cx,spring,h,radius,0.0,ORDER,d-RECESS,n,99,lost_side,_stone(b,1.03),lost,top,true)
	var outer := _ring_order(b,pose,cx,spring,h,radius,ORDER,ORDER,d,n-1,99,lost_side,_stone(b,1.0),lost+int(b.rng.randf()*2.0*b.weathered),top)
	if hood:
		# The hood rests on the outer order's face: it never runs on past
		# where that order still stands (`cap`), so no length of it hangs
		# over a lost crown.
		for s: float in [-1.0,1.0]:
			var hp := pose*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,s*(d+HOOD.y*0.5)))
			_ring_order(b,hp,cx,spring,h,radius,ORDER*2.0,HOOD.x,HOOD.y*0.5,n+2,99,lost_side,_stone(b,1.06),lost+1+int(b.rng.randf()*3.0*b.weathered),top,false,b.weathered*0.5,0.0,outer)

## One order of a pointed arch: voussoirs from `radius`+`r0` out `dr`,
## `d` deep (half), `n` a side; the first `keep` of each side (99, all);
## `lost` from the crown on `lost_side` gone; stones over `top` gone;
## `chamfer` its inner arrises moulded; `gaps` odds a stone is missing;
## `only_side` (-1 or 1) builds only the half springing on that side.
static func _ring_order(b: Build, pose: Transform3D, cx: float, spring: float, h: float, radius: float, r0: float, dr: float, d: float, n: int, keep: int, lost_side: float, tone: Color, lost := 0, top := Callable(), chamfer := false, gaps := 0.0, only_side := 0.0, cap := Vector2(2.0,2.0)) -> Vector2:
	var stood := Vector2.ZERO
	for side: float in [-1.0,1.0]:
		if only_side != 0.0 and side != only_side: continue
		var whole := true
		var centre := Vector3(cx-side*(radius-h),spring,0.0)
		var ri := radius+r0
		var ro := ri+dr
		var apex_in := acos(clampf((radius-h)/ri,-1.0,1.0))
		var apex_out := acos(clampf((radius-h)/ro,-1.0,1.0))
		var apex := (apex_in+apex_out)*0.5
		for i in range(n):
			if i >= keep: break
			if side == lost_side and i >= n-lost:
				whole = false
				continue
			if side != lost_side and i >= n-maxi(0,lost-1)-int(lost > 0 and b.rng.randf() < 0.5):
				whole = false
				continue
			if gaps > 0.0 and b.rng.randf() < gaps: continue
			if float(i)/n >= (cap.x if side < 0.0 else cap.y): continue
			# Angles from the horizontal at the springing (0) up to the
			# crown; the arc's centre lies across the opening from it.
			var ta := apex*i/n
			var tb := apex*(i+1)/n
			var mid_t := (ta+tb)*0.5
			var dir_a := Vector3(side*cos(ta),sin(ta),0.0)
			var dir_m := Vector3(side*cos(mid_t),sin(mid_t),0.0)
			var planes: Array[Plane] = [Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)]
			# The lower joint (toward the springing), the upper (the crown's
			# is upright, where the two sides meet).
			var low_n := Vector3(side*sin(ta),-cos(ta),0.0)
			planes.append(Plane(low_n,low_n.dot(centre)))
			if i == n-1:
				planes.append(Plane(Vector3(-side,0.0,0.0),-side*cx))
			else:
				var up_n := Vector3(-side*sin(tb),cos(tb),0.0)
				planes.append(Plane(up_n,up_n.dot(centre)))
			planes.append(Plane(-dir_m,(-dir_m).dot(centre+dir_a*ri)))
			planes.append(Plane(dir_m,dir_m.dot(centre+dir_m*ro)))
			if chamfer:
				for s: float in [-1.0,1.0]:
					var cn := (-dir_m+Vector3(0.0,0.0,s)).normalized()
					planes.append(Plane(cn,cn.dot(centre+dir_m*ri+Vector3(0.0,0.0,s*d))-0.07))
			var mid := centre+dir_m*(ri+ro)*0.5
			if top.is_valid() and float(top.call(mid.x)) < mid.y+0.1:
				whole = false
				continue
			var loose := 0.4+0.6*float(i)/n
			b.solid(planes,pose*_jiggle(b,Transform3D.IDENTITY,loose*0.18),tone*(1.0+b.rng.randf_range(-0.06,0.06)),true,true,[],-1,0.6)
			if whole:
				if side < 0.0: stood.x = float(i+1)/n
				else: stood.y = float(i+1)/n
	return stood

## How high a pointed arch of half span `h` and arc radius `radius` rises
## over its springing.
static func _rise(h: float, radius: float) -> float:
	return sqrt(maxf(0.0,radius*radius-(radius-h)*(radius-h)))

## The half width of a pointed arch's ring at `dy` over its springing, out
## to `off` beyond the arc (its extrados); -1 over its top.
static func _arc_half(h: float, radius: float, off: float, dy: float) -> float:
	var r := radius+off
	if dy < 0.0: return h+off
	if dy >= r: return -1.0
	var w := sqrt(r*r-dy*dy)-(radius-h)
	return w if w > 0.0 else -1.0

## A ring round `centre` (x, y) in the XY plane: `segments` stones from
## `radius`-`dr`/2... its middle radius `r_mid`, `dr` half depth radially,
## `d` half thick; each stone gone at odds `ruin`, or if over `top`.
static func _circle_ring(b: Build, pose: Transform3D, centre: Vector2, r_mid: float, dr: float, d: float, segments: int, ruin := 0.0, top := Callable()) -> void:
	var c := Vector3(centre.x,centre.y,0.0)
	for k in range(segments):
		var a0 := TAU*k/segments
		var a1 := TAU*(k+1)/segments
		var am := (a0+a1)*0.5
		var dm := Vector3(cos(am),sin(am),0.0)
		var mid := c+dm*r_mid
		if top.is_valid() and float(top.call(mid.x)) < mid.y+0.1+0.3*b.weathered: continue
		if ruin > 0.0 and b.rng.randf() < ruin*(0.5+0.5*maxf(0.0,dm.y)): continue
		var planes: Array[Plane] = [Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)]
		planes.append(Plane(Vector3(sin(a0),-cos(a0),0.0),Vector3(sin(a0),-cos(a0),0.0).dot(c)-0.004))
		planes.append(Plane(Vector3(-sin(a1),cos(a1),0.0),Vector3(-sin(a1),cos(a1),0.0).dot(c)-0.004))
		planes.append(Plane(-dm,(-dm).dot(c+dm*(r_mid-dr))))
		planes.append(Plane(dm,dm.dot(c+dm*(r_mid+dr))))
		b.solid(planes,pose*_jiggle(b,Transform3D.IDENTITY,0.4),_stone(b,1.04))

## A rib at `pose` (its springing; +X the way it runs, +Y up): a pointed
## arc of half span `half` and radius `radius`, `depth` deep radially and
## `width` (half) across, in `stones`, the first `keep` of them standing,
## the last broken off ragged.
static func _rib(b: Build, pose: Transform3D, half: float, radius: float, depth: float, width: float, stones: int, keep: int) -> void:
	var centre := Vector3(radius,0.0,0.0)
	var apex := acos(clampf((radius-half)/radius,-1.0,1.0))
	for i in range(mini(keep,stones)):
		var ta := PI-apex*i/stones
		var tb := PI-apex*(i+1)/stones
		var da := Vector3(cos(ta),sin(ta),0.0)
		var db := Vector3(cos(tb),sin(tb),0.0)
		var tm := (ta+tb)*0.5
		var dm := Vector3(cos(tm),sin(tm),0.0)
		var planes: Array[Plane] = [Plane(Vector3.BACK,width),Plane(Vector3.FORWARD,width)]
		var na := Vector3(-sin(ta),cos(ta),0.0)
		planes.append(Plane(na,na.dot(centre)))
		var nb := Vector3(sin(tb),-cos(tb),0.0)
		planes.append(Plane(nb,nb.dot(centre)))
		planes.append(Plane(dm,dm.dot(centre+dm*radius)))
		planes.append(Plane(-dm,(-dm).dot(centre+dm*(radius-depth))))
		# The rib's moulding: its soffit (inner, under) arrises chamfered.
		for s: float in [-1.0,1.0]:
			var cn := (-dm+Vector3(0.0,0.0,s)*0.9).normalized()
			planes.append(Plane(cn,cn.dot(centre+dm*(radius-depth)+Vector3(0.0,0.0,s*width))-0.05))
		var extra: Array[Plane] = []
		if i == mini(keep,stones)-1 and keep < stones:
			var m := (nb+Vector3(b.rng.randf_range(-0.5,0.5),b.rng.randf_range(-0.5,0.5),b.rng.randf_range(-0.6,0.6))).normalized()
			extra.append(Plane(m,m.dot(centre+(da+db*2.0).normalized()*(radius-depth*0.5))))
		b.solid(planes,pose*_jiggle(b,Transform3D.IDENTITY,0.08+0.02*i),_stone(b,1.04),true,true,extra,-1,0.6)

## Jambs for an opening of half width `w` from `y0` to `spring`, `d` deep
## (half): two orders of stones either side, long and short, their inner
## arrises chamfered (the splay); stones over `top` gone.
static func _jambs(b: Build, pose: Transform3D, w: float, y0: float, spring: float, d: float, top: Callable) -> void:
	for side: float in [-1.0,1.0]:
		for order in range(2):
			var x0 := w+ORDER*order
			var x1 := x0+ORDER
			var dd := d-RECESS if order == 0 else d
			var y := y0
			var k := order
			while y < spring-0.05:
				var y1 := minf(spring,y+(0.62 if k%2 == 0 else 0.42)*b.rng.randf_range(0.9,1.1))
				if spring-y1 < 0.2: y1 = spring
				var mid := side*(x0+x1)*0.5
				if float(top.call(mid)) < (y+y1)*0.5: break
				var half := Vector3(ORDER*0.5-0.004,(y1-y)*0.5-0.004,dd)
				var planes := _box(b,half)
				if order == 0:
					for s: float in [-1.0,1.0]:
						var cn := Vector3(-side,0.0,s).normalized()
						planes.append(Plane(cn,cn.dot(Vector3(-side*half.x,0.0,s*half.z))-0.07))
				b.solid(planes,pose*_settle(b,Vector3(mid,(y+y1)*0.5,0.0),0.5),_stone(b,1.03 if order == 0 else 1.0))
				y = y1
				k += 1

## A plinth course along X at `pose`, `half_len`, round a wall `d` deep
## (half): the wall's foot standing out PLINTH_COURSE.y, its top chamfered.
static func _plinth_course(b: Build, pose: Transform3D, half_len: float, d: float) -> void:
	var x := -half_len-PLINTH_COURSE.y
	var end := half_len+PLINTH_COURSE.y
	while x < end-0.05:
		var x1 := minf(end,x+b.rng.randf_range(0.9,1.6))
		if end-x1 < 0.45: x1 = end
		var half := Vector3((x1-x)*0.5-0.005,PLINTH_COURSE.x*0.5,d+PLINTH_COURSE.y)
		var planes := _box(b,half)
		for s: float in [-1.0,1.0]:
			var n := Vector3(0.0,1.0,s*1.2).normalized()
			planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-PLINTH_COURSE.y*0.8)))))
		b.solid(planes,pose*_settle(b,Vector3((x+x1)*0.5,half.y,0.0),0.3),_stone(b,0.92))
		x = x1

## Coping along a gable's two rakes at `pose`: sloped stones from the eaves
## (`eave` at `half` out) to the apex, with crockets, a finial at the apex;
## only where the gable stands whole under `top`. `wide`: the gable's own
## wall, so the coping overhangs it.
static func _rake(b: Build, pose: Transform3D, half: float, eave: float, apex: float, d: float, top: Callable, finial := true, highest := INF) -> void:
	var slope := atan2(apex-eave,half)
	var length := half/cos(slope)
	var count := maxi(3,int(length/1.0))
	var whole := 0
	for side: float in [-1.0,1.0]:
		for k in range(count):
			var t0 := float(k)/count
			var t1 := float(k+1)/count
			var xa := side*half*(1.0-t0)
			var xb := side*half*(1.0-t1)
			var ya := eave+(apex-eave)*t0
			var yb := eave+(apex-eave)*t1
			var mid := Vector3((xa+xb)*0.5,(ya+yb)*0.5,0.0)
			if float(top.call(mid.x)) < mid.y-0.05 or mid.y > highest: continue
			if k == count-1: whole += 1
			var basis := Basis(Vector3.BACK,side*-slope)
			var half_ext := Vector3(length/count*0.5-0.01,0.12,d+0.08)
			var at := mid+basis*Vector3(0.0,0.1,0.0)
			b.solid(_box(b,half_ext),pose*_jiggle(b,Transform3D(basis,at),0.6),_stone(b,1.06))
			# A crocket: a leaf-knob on the rake.
			if b.rng.randf() > 0.25*b.weathered:
				var ca := at+basis*Vector3(0.0,0.16,0.0)
				b.solid(_box(b,Vector3(0.08,0.1,0.09),0.015),pose*Transform3D(basis*Basis(Vector3.BACK,side*0.6),ca),_stone(b,1.04),false,false)
	if finial and whole == 2:
		var at := pose*Transform3D(Basis.IDENTITY,Vector3(0.0,apex+0.05,0.0))
		b.solid(_prism(4,0.2,0.2,0.0,0.5,PI*0.25),at,_stone(b,1.05))
		_spire(b,at*Transform3D(Basis.IDENTITY,Vector3(0.0,0.5,0.0)),0.17,1.1,false)

## Coursed walling at `pose` along X from `x0` to `x1`, from `y0` up to the
## ruin line `top` (x -> height), `d` deep (half): courses about `course`
## high and uneven, blocks of random length staggered, the courses sagging,
## blocks out of true; blocks a broken line passes through cut along it,
## blocks under the line's dips gone; a `hole` (y -> Vector2(centre, half
## width); half < 0 none) left open, the blocks round it cut to it;
## `coping` a chamfered coping course on whatever stands at full height.
static func _courses(b: Build, pose: Transform3D, x0: float, x1: float, y0: float, top: Callable, d: float, hole: Callable, course: float, coping := false) -> void:
	var most := -INF
	var x := x0
	while x <= x1:
		most = maxf(most,float(top.call(x)))
		x += 0.2
	most = maxf(most,float(top.call(x1)))
	var sag := (SAG.x+(SAG.y-SAG.x)*b.weathered*b.settle)*Style.share("sag")
	var y := y0
	var k := 0
	var cap := 0.2 if coping else 0.0
	while y < most-cap-0.06:
		# Courses of uneven height: mostly about `course`, now and then a
		# thin one or a deep one, as old walling is.
		var roll := b.rng.randf()
		var h := course*(b.rng.randf_range(0.5,0.66) if roll < 0.15 else (b.rng.randf_range(1.3,1.55) if roll > 0.86 else b.rng.randf_range(0.8,1.18)))
		if most-cap-(y+h) < course*0.45: h = most-cap-y
		if hole.is_valid() and (hole.call(y+0.001) as Vector2).y < 0.0 and (hole.call(y+h-0.001) as Vector2).y >= 0.0:
			# A hole's sill inside the course: the course ends at it, so no
			# stone straddles the sill and juts into the hole.
			var a := y
			var c := y+h
			for i in range(14):
				var m := (a+c)*0.5
				if (hole.call(m) as Vector2).y < 0.0: a = m
				else: c = m
			if c-y > 0.12: h = c-y
		var ya := y
		var yb := y+h
		x = x0-(0.0 if k%2 == 0 else b.rng.randf_range(0.25,0.5))
		while x < x1-0.02:
			var xa := maxf(x,x0)
			var pick := b.rng.randf()
			var xb := minf(x+(b.rng.randf_range(0.35,0.6) if pick < 0.22 else (b.rng.randf_range(1.45,2.0) if pick > 0.8 else b.rng.randf_range(0.7,1.3)))*(2.2 if b.lean else 1.0),x1)
			if x1-xb < 0.3: xb = x1
			x = xb
			var mid := (xa+xb)*0.5
			var standing := float(top.call(mid))
			if ya+h*0.35 >= standing: continue
			# Its pieces after the hole: one, or two either side, or none.
			var spans: Array = [[xa,xb,null,null]]
			if hole.is_valid():
				var ha: Vector2 = hole.call(ya+0.001)
				var hb: Vector2 = hole.call(yb-0.001)
				var hm: Vector2 = hole.call((ya+yb)*0.5)
				var wa := maxf(ha.y,0.0)
				var wb := maxf(hb.y,0.0)
				var wm := maxf(hm.y,0.0)
				if ha.y >= 0.0 or hb.y >= 0.0 or hm.y >= 0.0:
					var c := hm.x
					var monotonic := wm <= maxf(wa,wb)+0.005 and wm >= minf(wa,wb)-0.005
					if not monotonic:
						wa = wm
						wb = wm
					spans = []
					# Left of the hole: cut by the line from (c-wa, ya) to (c-wb, yb).
					if xa < c-minf(wa,wb):
						var p0 := Vector3(c-wa,ya,0.0)
						var p1 := Vector3(c-wb,yb,0.0)
						var along := p1-p0
						var n := Vector3(along.y,-along.x,0.0).normalized()
						if n.x < 0.0: n = -n
						spans.append([xa,minf(xb,c-minf(wa,wb)),Plane(n,n.dot(p0)),null])
					if xb > c+minf(wa,wb):
						var p0 := Vector3(c+wa,ya,0.0)
						var p1 := Vector3(c+wb,yb,0.0)
						var along := p1-p0
						var n := Vector3(along.y,-along.x,0.0).normalized()
						if n.x > 0.0: n = -n
						spans.append([maxf(xa,c+minf(wa,wb)),xb,null,Plane(n,n.dot(p0))])
			for s: Array in spans:
				var sa: float = s[0]
				var sb: float = s[1]
				if sb-sa < 0.08: continue
				var centre := Vector3((sa+sb)*0.5,(ya+yb)*0.5,0.0)
				# The sag: the course dips toward the middle of the run.
				var t := clampf(((sa+sb)*0.5-x0)/maxf(x1-x0,0.1),0.0,1.0)
				centre.y -= sag*sin(PI*t)*clampf((ya-y0)/2.0,0.2,1.0)
				# Lean stone overlaps a little, so its hidden joints close (Build `cull`).
				var joint := -0.012 if b.lean else 0.006
				var depth := b.rng.randf_range(-0.045,0.02)
				# A clean look: the stones flush, butted (no joint to see).
				if Style.clean():
					joint = 0.0
					depth *= float(Style.get_value("depth"))
				var half := Vector3((sb-sa)*0.5-joint,(yb-ya)*0.5-joint,d+depth)
				var planes := _box(b,half)
				var local := Transform3D(Basis.IDENTITY,centre)
				var inv := local.affine_inverse()
				for p: Variant in [s[2],s[3]]:
					if p != null:
						var pl: Plane = p
						if pl.distance_to(centre) > 0.0 and absf(pl.distance_to(centre)) > half.length(): continue
						planes.append(inv*pl)
				var extra: Array[Plane] = []
				var ea := float(top.call(sa))
				var eb := float(top.call(sb))
				if minf(ea,eb) < yb or standing < yb:
					var ragged := b.weathered > 0.05
					var p0 := Vector3(sa,clampf(ea,ya+0.1,yb+0.2) if ragged else ea,0.0)-centre
					var p1 := Vector3(sb,clampf(eb,ya+0.1,yb+0.2) if ragged else eb,0.0)-centre
					var along := p1-p0
					var n := Vector3(-along.y,along.x,b.rng.randf_range(-0.3,0.3)*along.x*float(ragged)).normalized()
					extra.append(Plane(n,n.dot(p0)))
					for j in range((1+int(b.rng.randf() < 0.6)) if ragged else 0):
						var m := Vector3(b.rng.randf_range(-0.9,0.9),1.0,b.rng.randf_range(-0.5,0.5)).normalized()
						extra.append(Plane(m,m.dot(Vector3(b.rng.randf_range(-half.x,half.x)*0.7,clampf(standing-centre.y,-half.y*0.3,half.y)+b.rng.randf_range(0.0,0.12),0.0))))
				var tone := _stone(b)
				b.solid(planes,pose*_jiggle(b,local,0.4+0.6*clampf((ya-y0)/4.0,0.0,1.0)),tone,true,true,extra)
		y = yb
		k += 1
	if coping:
		x = x0
		while x < x1-0.02:
			var xb := minf(x+b.rng.randf_range(0.9,1.5),x1)
			if x1-xb < 0.35: xb = x1
			if minf(float(top.call(x)),float(top.call(xb))) >= most-0.01:
				var half := Vector3((xb-x)*0.5-0.005,cap*0.5,d+0.06)
				var planes := _box(b,half)
				for s: float in [-1.0,1.0]:
					var n := Vector3(0.0,1.0,s*0.9).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-0.12)))))
				b.solid(planes,pose*_settle(b,Vector3((x+xb)*0.5,most-cap*0.5,0.0),0.6),_stone(b,1.06))
			x = xb

## The head of a wall as old as it is whole: `high` all along but for a
## stone or two of its top course gone here and there (`course` deep).
static func _worn_top(b: Build, x0: float, x1: float, high: float, course: float) -> Callable:
	var gaps: Array[Vector3] = []
	for i in range(1+int(b.rng.randf() < 0.6)):
		var at := b.rng.randf_range(x0+0.4,x1-0.4)
		gaps.append(Vector3(at,b.rng.randf_range(0.35,0.7),high-course*b.rng.randf_range(0.7,1.3)))
	return func(x: float) -> float:
		var y := high
		for g in gaps:
			if absf(x-g.x) < g.y: y = minf(y,g.z)
		return y

## A ruin line over X from `x0` to `x1`: heights between `low` and `high`,
## ragged (stepping and notched, a gap torn down somewhere), more broken the
## more `amount`. `gap`: one deep notch for sure.
static func _ruin_line(b: Build, x0: float, x1: float, low: float, high: float, amount: float, gap := false) -> Callable:
	var count := maxi(4,int((x1-x0)/0.45))
	var heights := PackedFloat32Array()
	var phase := b.rng.randf()*TAU
	for i in range(count+1):
		var t := float(i)/count
		var wave := 0.5+0.5*sin(t*PI*b.rng.randf_range(1.2,2.2)+phase)
		var hgt := lerpf(low,high,clampf(wave*0.7+b.rng.randf()*0.5,0.0,1.0))
		heights.append(hgt)
	# A notch torn down somewhere along it.
	if gap or b.rng.randf() < amount:
		var at := b.rng.randi_range(1,count-1)
		var depth := lerpf(low,high,0.0)-(high-low)*0.2
		heights[at] = maxf(0.5,minf(heights[at],low*0.6+0.3))
		if at+1 <= count and b.rng.randf() < 0.6: heights[at+1] = minf(heights[at+1],lerpf(heights[at],high,0.4))
		if depth < 0.0: pass
	return func(x: float) -> float:
		var u := clampf((x-x0)/maxf(x1-x0,0.01),0.0,1.0)*count
		var i := mini(int(u),count-1)
		return lerpf(heights[i],heights[i+1],u-i)

## A drift of fallen stones heaped against a piece at `at`: `count` blocks,
## the bigger low, the smaller stacked up on them, within `reach` m; a
## climb's first steps as often as not.
static func _drift(b: Build, at: Vector3, reach: float, count: int) -> void:
	# Lean stone: fewer, the more so with less detail (a drift's few big
	# stones still read).
	if b.lean: count = int(ceil(count*(0.4+0.3*b.level)))
	if count <= 0: return
	at.y += b.floor_at(at.x,at.z)
	var keep := b.frame
	for i in range(count):
		var s := Vector3(b.rng.randf_range(0.28,0.6),b.rng.randf_range(0.16,0.3),b.rng.randf_range(0.22,0.42))*(1.0-0.4*float(i)/count)
		var r := reach*sqrt(b.rng.randf())*(0.4+0.6*float(i)/count)
		var a := b.rng.randf()*TAU
		var y := s.y*0.7+0.18*float(i)/count*b.rng.randf()
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3(1,0,0),b.rng.randf_range(-0.35,0.35))*Basis(Vector3(0,0,1),b.rng.randf_range(-0.3,0.3)),at+Vector3(cos(a)*r,y,sin(a)*r*0.6))
		b.solid(_box(b,s),pose,_stone(b,0.96),true,true,[],-1,2.0)
	b.frame = keep

## Rubble scattered round a weathered piece: `count` small broken stones
## within `reach` and a little beyond.
## `drop`: a stone whose ground lies more than this under the piece's foot
## (over a cliff's edge) is left out.
static func _rubble(b: Build, reach: float, count: int, drop := INF) -> void:
	if b.weathered <= 0.0: return
	count = int(round(count*b.level))
	for i in range(count):
		var a := b.rng.randf()*TAU
		var dist := reach+b.rng.randf_range(-0.3,1.0)
		var s := Vector3(b.rng.randf_range(0.1,0.26),b.rng.randf_range(0.07,0.16),b.rng.randf_range(0.1,0.24))
		var floor_y := b.floor_at(cos(a)*dist,sin(a)*dist)
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.3,0.3)),Vector3(cos(a)*dist,s.y*0.8+floor_y,sin(a)*dist))
		if floor_y < -drop:
			continue
		b.solid(_box(b,s),pose,_stone(b),false,true,[],-1,2.0)

## Planes cutting a drum's head (`h` tall, radius `r`) in a ragged break
## down to `depth` of it; `at` the drum's middle height in its frame (0 for
## a drum standing on its foot: the break's middle stays near its head).
static func _break(b: Build, h: float, r: float, depth: float, at_mid := 0.0) -> Array[Plane]:
	var out: Array[Plane] = []
	var base := h*(1.0-depth)-at_mid
	var top := h-at_mid
	var a := b.rng.randf()*TAU
	var lean := b.rng.randf_range(0.3,0.7)
	var n := Vector3(cos(a)*lean,1.0,sin(a)*lean).normalized()
	out.append(Plane(n,n.dot(Vector3(0.0,lerpf(base,top,0.5),0.0))))
	for i in range(1+int(b.rng.randf() < 0.6)):
		var c := a+b.rng.randf_range(1.6,4.6)
		var steep := b.rng.randf_range(0.9,1.6)
		var m := Vector3(cos(c)*steep,1.0,sin(c)*steep).normalized()
		out.append(Plane(m,m.dot(Vector3(cos(c)*r*0.6,lerpf(base,top,0.3),sin(c)*r*0.6))))
	return out

## A block's resting pose at `at`: out of true even as built (TRUE_OFF.x),
## leaning and shifted further as it weathers, more the higher `loose`.
static func _settle(b: Build, at: Vector3, loose: float) -> Transform3D:
	return _jiggle(b,Transform3D(Basis.IDENTITY,at),loose)

static func _jiggle(b: Build, pose: Transform3D, loose: float) -> Transform3D:
	var tilt := (TRUE_OFF.x+(TRUE_OFF.y-TRUE_OFF.x)*b.weathered*b.settle)*loose
	var shift := (SHIFT.x+(SHIFT.y-SHIFT.x)*b.weathered*b.settle)*loose
	if Style.ruled():
		tilt *= Style.share("true_off")
		shift *= Style.share("true_off")
	var axis := Vector3(b.rng.randf_range(-1,1),b.rng.randf_range(-0.3,0.3),b.rng.randf_range(-1,1)).normalized()
	var move := Vector3(b.rng.randf_range(-1,1),b.rng.randf_range(-0.3,0.1),b.rng.randf_range(-1,1))*shift
	return Transform3D(Basis(axis,b.rng.randf_range(0.3,1.0)*tilt)*pose.basis,pose.origin+move)

## A block's colour: the piece's stone wandering toward umber or cool (times
## `tone`).
static func _stone(b: Build, tone := 1.0) -> Color:
	var c := b.stone.lerp(STONE_COOL if b.rng.randf() < 0.5 else STONE,b.rng.randf_range(0.0,0.45))
	return c*(tone*(1.0+b.rng.randf_range(-0.5,0.5)*BLOCK_TONE))

# --- Planes ---------------------------------------------------------------------

## A box of half extents `half` about its middle, its twelve arrises worn
## off unevenly: each chamfered `c` (CHAMFER grown with age, unless given)
## times a share of its own.
static func _box(b: Build, half: Vector3, c := -1.0) -> Array[Plane]:
	var out: Array[Plane] = []
	for axis in range(3):
		for s: float in [-1.0,1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			out.append(Plane(n,half[axis]))
	var base := c if c >= 0.0 else CHAMFER*(1.0+ARRIS*b.age)
	var least := minf(half.x,minf(half.y,half.z))
	var longest := 0 if half.x >= maxf(half.y,half.z) else (1 if half.y >= half.z else 2)
	for a in range(3):
		var e := (a+1)%3
		if b.lean and c < 0.0 and 3-a-e != longest: continue
		for sa: float in [-1.0,1.0]:
			for se: float in [-1.0,1.0]:
				# Lean: only the upper arrises (the lower meet the course below).
				if b.lean and c < 0.0 and ((a == 1 and sa < 0.0) or (e == 1 and se < 0.0)): continue
				var roll := b.rng.randf_range(0.45,1.9)
				var cc := minf(base*roll,least*0.45)
				var n := Vector3.ZERO
				n[a] = sa
				n[e] = se
				var corner := Vector3.ZERO
				corner[a] = sa*half[a]
				corner[e] = se*half[e]
				n = n.normalized()
				var bevel := Plane(n,n.dot(corner)-cc)
				out.append(bevel)
				# A clean look draws the box without its worn arrises (the
				# same numbers drawn, so the piece is otherwise the same); an
				# eroded look keeps what it needs to dial the arris (`solid`):
				# where it runs (round the top, upright, at the foot), how
				# worn the classic drew it (a share), how deep, its cap.
				if c < 0.0 and Style.ruled():
					var kind := "arris_top" if (a == 1 and sa > 0.0) or (e == 1 and se > 0.0) else ("arris_low" if a == 1 or e == 1 else "arris_side")
					b.bevels[bevel] = [kind,(roll-0.45)/1.45,cc,least*0.45]
	return out

## Chamfers on the four vertical arrises of axis-aligned `planes` round
## `middle` (an upright block given as planes).
static func _bevel(planes: Array[Plane], middle: Vector3, c: float) -> Array[Plane]:
	var out: Array[Plane] = planes.duplicate()
	var points := Geometry3D.compute_convex_mesh_points(planes)
	if points.size() < 4: return out
	for dx: float in [-1.0,1.0]:
		for dz: float in [-1.0,1.0]:
			var n := Vector3(dx,0.0,dz).normalized()
			var reach := -INF
			for p in points: reach = maxf(reach,n.dot(p))
			out.append(Plane(n,reach-c))
	return out

## An upright `sides`-sided prism from `low` to `high`, its faces' middles
## `bottom` and `top` from the axis, turned `turn`.
static func _prism(sides: int, bottom: float, top: float, low: float, high: float, turn := 0.0) -> Array[Plane]:
	var out: Array[Plane] = [Plane(Vector3.DOWN,-low),Plane(Vector3.UP,high)]
	for k in range(sides):
		var a := turn+TAU*k/sides
		var radial := Vector3(cos(a),0.0,sin(a))
		var n := (radial*(high-low)+Vector3.UP*(bottom-top)).normalized()
		out.append(Plane(n,n.dot(radial*bottom+Vector3.UP*low)))
	return out

## A prism round Y from -`half_h` to +`half_h` (to be turned onto another
## axis by its pose), apothem `r`.
static func _axial_prism(sides: int, r: float, half_h: float) -> Array[Plane]:
	return _prism(sides,r,r,-half_h,half_h,PI/sides)

## A prism round Y from 0 to `h`, apothem `r`.
static func _axial_prism_y(sides: int, r: float, h: float) -> Array[Plane]:
	return _prism(sides,r,r,0.0,h)

# --- Building -------------------------------------------------------------------

## A piece being built: its stone (and growth) faces, its blocks'
## hulls, their planes (for the ivy to find the faces by), the tops that
## look up, the strands asked to hang free.
class Build extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var weathered := 0.0
	## How worn every arris and face is: AGE as built, 1 at full ruin.
	var age := 0.0
	var stone := Color()
	var root: Node3D
	var noise := FastNoiseLite.new()
	var faces := Faces.new()
	var hulls: Array[PackedVector3Array] = []
	## Every block's [AABB, planes] in the piece's frame, for the ivy.
	var solids: Array = []
	## Faces that look up: [polygon, area].
	var tops: Array = []
	## Strands asked to hang free: [at, length, free, from height].
	var hangs: Array = []
	## Boxes (the piece's straight frame) no strand of growth hangs into: a
	## flown lane or corridor kept clear (`kept_clear`; a strand stops at
	## one).
	var clear: Array[AABB] = []
	## Applied to every block (a piece turned or leaning as a whole).
	var frame := Transform3D.IDENTITY
	## Blocks are cut off level under this height (the piece's frame, y):
	## what is sunk in the ground is not drawn. -INF, none.
	var ground := -INF
	## How far its stones have moved out of true as it weathered, as a share
	## of the abbey's (1): a heavy arcade or a hall's walls settle less, so
	## a ruin of them reads settled, not shaken.
	var settle := 1.0
	## The ground the piece stands on: a Callable(x, z) -> y in the piece's
	## frame, or none (flat, y 0). Feet, footings and walls reach down to it
	## and below; drifts and rubble lie on it.
	var terrain := Callable()
	## Cheap stone (the colossus halls, built by the dozen into landforms):
	## a box's arrises chamfered only along its length, a third of the chips.
	var lean := false
	## Faces hidden inside other blocks (course joints, stacked drums, wall
	## cores) or buried under the ground are left out of the mesh.
	var cull := false
	## A bend (a hall laid along a curve): an object with `xform(s) ->
	## Transform3D`, the frame at distance s along it (X along, Y up, Z
	## across). Every block is built straight (x along the bend) and drawn
	## bent: each corner to xform(x) * (0, y, z); a block built while
	## `rigid` is on (a column, a fallen beam) is carried whole instead, by
	## the frame at its middle, so it stays round and true.
	var path: Variant = null
	var rigid := false
	## How sheltered a face is, 0 (open air) to 1 (deep under a roof): a
	## Callable(middle, normal) -> float (straight), drawn into the vertex
	## alpha for the stone shader's bounce (shaders/ruin_stone.gdshader);
	## none, open air.
	var shelter := Callable()
	## The faces as built (straight), drawn at `finish`: [corners, normal,
	## colour, occluder (its block's index in `solids`, or -1), anchor (a
	## rigid block's middle x, or NAN)].
	var pending: Array = []
	## Each hull's anchor (as `pending`'s), side by side with `hulls`.
	var hull_anchors: PackedFloat32Array = []
	## The growth being built (RuinGrowth `attrs`: where it hangs from, how
	## it sways), empty while building stone: a face built with it goes to
	## the growth's own surface (`growth`), not the stone's.
	var grow := PackedFloat32Array()
	var growth := RuinGrowth.Faces.new()
	## A clean look's (Style): the worn arrises `_box` cut (left out of
	## the drawn and solid block), and the piece's own stone.
	var bevels := {}
	var clean_stone := Color()
	## An eroded look's record of the last `_wear`'s chips and chunk (its
	## planes after the block's own, in order): ["chip", how deep the classic
	## drew it (a share), on an upper corner, its bite, its cap] or ["chunk",
	## its roll (a share of the odds), its share, the block's depth across].
	var worn_cuts: Array = []
	static var _materials := {}
	static var _dressed := ""
	## How much of the small growth and scatter is built (RuinKit
	## `set_detail`): 1 all of it; under 1 fewer ivy strands, moss
	## cushions, tufts and rubble stones; 0 none (a far or cheap ruin).
	static var detail := 1.0
	## Every finished piece's random state, hashed in turn: the same in
	## every stone look when the looks draw the same numbers
	## (tools/ruin_stone_dump.gd checks it).
	static var draws := 0
	## The floating-stone check (tools/collision_audit.gd, tests/
	## test_ruin_floating.gd): on, every finished piece looks for drawn
	## stones resting on nothing (`floating`) and adds them to `floaters`.
	static var check_floating := false
	static var floaters: Array = []
	## How many blocks `drop_floating` took out of this piece.
	var dropped := 0
	static var _floaters_lock := Mutex.new()
	## Each drawn block's corners and planes (the piece's frame), kept
	## while `check_floating` or `drop_floating` is on: [points, planes,
	## marks (where its faces, tops, hull and solid start in `pending`,
	## `tops`, `hulls`, `solids`, then where they end)].
	var blocks: Array = []
	## A standing ruin whose stones are taken away by rule (a crown lost, a
	## notch, a breach, a ragged head): its stones left resting on nothing
	## (`floating`) have fallen, so `finish` takes them out (drawn, solid
	## and grown on). Off for what floats on purpose (drifting stones).
	var drop_floating := false
	## With `drop_floating`: only loose stones (a group of FLOAT_MOST or
	## fewer resting on nothing) are taken out, for a build whose walls
	## stand on ground it doesn't know (coursed down a hill, over the sky).
	var drop_loose := false
	## Only the blocks this keeps are drawn, solid and grown on: a
	## Callable(centre: Vector3, the block's corners' middle in the piece's
	## frame) -> bool, or none. Set round one piece's build (the Olmec's
	## destruction, scripts/kit_isle/colonnade_breaks.gd: a wall built again
	## as its pre-cut slabs, each the same stones as the whole, by its
	## joints). The blocks are laid as ever (the same draws), then those
	## not kept taken out at `finish`, after `drop_floating`.
	static var keep_only := Callable()
	## This build's `keep_only` and `detail`, taken when it begins: the
	## statics, or what `per_thread` set for the thread it runs on (a build
	## on a worker, its settings its own, not the main thread's statics).
	var keeps := Callable()
	var level := 1.0
	## With `per_thread`'s "hand": finish makes its mesh, instance and body
	## (the renderer's and physics' RIDs) through it, on the main thread.
	var hand := Callable()
	static var _threads := {}
	static var _threads_lock := Mutex.new()

	## Settings for builds begun on this thread from now on ({keep_only,
	## detail, hand}), or {} to go back to the statics.
	static func per_thread(settings: Dictionary) -> void:
		_threads_lock.lock()
		if settings.is_empty(): _threads.erase(OS.get_thread_caller_id())
		else: _threads[OS.get_thread_caller_id()] = settings
		_threads_lock.unlock()

	static func materials() -> Dictionary:
		if _materials.is_empty():
			var s := ShaderMaterial.new()
			s.shader = STONE_SHADER
			s.set_shader_parameter("fill",1.2)
			s.set_shader_parameter("rim",0.14)
			s.set_shader_parameter("roughness_value",0.95)
			_materials = {"stone":s,"growth":RuinGrowth.material()}
		# Dressed when the look changes (the same values every time else):
		# isles built side by side on workers call this at once.
		var key := "%s %s" % [Style.current,Style.weather()]
		if _dressed != key:
			Style.dress(_materials.stone)
			_dressed = key
		return _materials

	## The ground's height at (x, z) in the piece's frame: 0 with no terrain.
	func floor_at(x: float, z: float) -> float:
		return float(terrain.call(x,z)) if terrain.is_valid() else 0.0

	## Whether `p` is in a box kept clear of growth (`clear`).
	func kept_clear(p: Vector3) -> bool:
		for box: AABB in clear:
			if box.has_point(p): return true
		return false

	func _init(seed_value: int, amount: float, label: String) -> void:
		keeps = keep_only
		level = detail
		if not _threads.is_empty():
			_threads_lock.lock()
			var mine: Dictionary = _threads.get(OS.get_thread_caller_id(),{})
			_threads_lock.unlock()
			if not mine.is_empty():
				keeps = mine.get("keep_only",Callable())
				level = float(mine.get("detail",1.0))
				hand = mine.get("hand",Callable())
		rng.seed = hash([seed_value,label,"gothic"])
		weathered = clampf(amount,0.0,1.0)
		age = AGE+(1.0-AGE)*weathered
		stone = STONE.lerp(STONE_COOL,rng.randf())
		if Style.ruled(): clean_stone = Style.stone_of(seed_value)
		noise.seed = seed_value
		noise.frequency = 1.0
		noise.fractal_octaves = 2
		root = Node3D.new()
		root.name = label

	## How thick `points` stand at their thinnest (RuinKit `hull_thickness`).
	static func thickness(points: PackedVector3Array) -> float:
		var kernel: Object = NativeIsleKernels.get_kernel()
		if kernel != null: return kernel.thickness(points)
		if points.size() < 4: return 0.0
		var mean := Vector3.ZERO
		for p in points: mean += p
		mean /= points.size()
		var c := Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		for p in points:
			var d := p-mean
			c.x += d*d.x
			c.y += d*d.y
			c.z += d*d.z
		# The two widest axes by power iteration, the least across them both.
		var axes: Array[Vector3] = []
		var m := c
		for k in range(2):
			var v := Vector3(0.577,0.577,0.577) if k == 0 else Vector3(-0.41,0.82,-0.41)
			if not axes.is_empty(): v = (v-axes[0]*axes[0].dot(v))
			for i in range(40):
				var w := m*v
				if not axes.is_empty(): w -= axes[0]*axes[0].dot(w)
				if w.length_squared() < 1e-20: break
				v = w.normalized()
			if v.length_squared() < 1e-12: return 0.0
			axes.append(v.normalized())
		var least := axes[0].cross(axes[1])
		if least.length_squared() < 1e-12: return 0.0
		least = least.normalized()
		var low := INF
		var high := -INF
		for p in points:
			low = minf(low,least.dot(p))
			high = maxf(high,least.dot(p))
		return high-low

	## Asks for a strand of ivy hanging free from the underside over `at`
	## (x, z; from height `from`, or found by looking up), `length` m long.
	func hang(at: Vector3, length: float, free := true, from := -1.0) -> void:
		hangs.append([at,length,free,from])

	## One convex block: `planes` (outward, in the block's frame) cut, unless
	## `wear` is off, by the weathering's planes and `extra`; drawn at `pose`
	## (in `frame`) in `colour` (sRGB), face by face, except plane `open`
	## (whose corners are given back); its hull solid if `collide`. `rough`
	## scales the weathering; `growable`: ivy and moss may grow on it.
	func solid(planes: Array[Plane], pose: Transform3D, colour: Color, collide := true, wear := true, extra: Array[Plane] = [], open := -1, rough := 1.0, growable := true) -> PackedVector3Array:
		# The native kernel does all of this (the classic and eroded looks).
		var kernel: Object = NativeIsleKernels.get_kernel()
		if kernel != null and not (growable and Style.clean()): return _solid_native(kernel,planes,pose,colour,collide,wear,extra,open,rough,growable)
		var marks := PackedInt32Array([pending.size(),tops.size(),hulls.size(),solids.size()])
		var cut: Array[Plane] = planes.duplicate()
		for p in extra: cut.append(p)
		# An eroded look: the block's own planes as built (its faces, worn
		# arrises and breaks), and whether the wear took (its chips and
		# chunk in `worn_cuts`).
		var source := cut
		var wore := false
		if wear:
			# The wear's tilted faces never grow a block past where it stood
			# unworn: a sliver whose sides tilt open would run on for metres.
			var worn := _wear(cut,rough,open)
			wore = true
			var base := Geometry3D.compute_convex_mesh_points(cut)
			if base.size() >= 4:
				var box := AABB(base[0],Vector3.ZERO)
				for q in base: box = box.expand(q)
				box = box.grow(maxf(0.15,box.get_longest_axis_size()*0.08))
				for q in Geometry3D.compute_convex_mesh_points(worn):
					if not box.has_point(q):
						worn = cut
						wore = false
						break
			cut = worn
		var xf := frame*pose
		if ground > -INF: cut.append(xf.affine_inverse()*Plane(Vector3.DOWN,-ground))
		var points := _unique(Geometry3D.compute_convex_mesh_points(cut))
		var linear := colour.srgb_to_linear()
		# A clean look (Style) on stone: the block as cut, worn as the
		# classic's only to draw the same numbers (so the rest of the piece
		# is the same), then drawn and made solid without the wear and
		# without its worn arrises, its faces coloured by the look's rule.
		var cleaned := growable and Style.clean()
		# A look other than classic on stone colours its faces by the look's
		# rule (`Style.shade`); an eroded one keeps the classic's block.
		var ruled := growable and Style.ruled()
		var made: Array = _polys(cut,points,open)
		if cleaned:
			if points.size() >= 4:
				for p: Array in made[0]:
					_shade(xf*(p[2] as Vector3),(xf.basis*(p[1] as Vector3)).normalized(),linear,wear and float(p[3]) < float(made[2])*0.16)
				_tops(made[0],xf)
			var bare: Array[Plane] = []
			var keep := -1
			for i in range(planes.size()+extra.size()):
				if i < planes.size() and bevels.has(planes[i]): continue
				if i == open: keep = bare.size()
				bare.append(planes[i] if i < planes.size() else extra[i-planes.size()])
			if ground > -INF: bare.append(xf.affine_inverse()*Plane(Vector3.DOWN,-ground))
			cut = bare
			open = keep
			points = _unique(Geometry3D.compute_convex_mesh_points(cut))
			made = _polys(cut,points,open)
		if points.size() < 4: return PackedVector3Array()
		var block: Array = []
		if (check_floating or drop_floating or keeps.is_valid()) and growable:
			var corners := PackedVector3Array()
			for q in points: corners.append(xf*q)
			var faces: Array[Plane] = []
			for plane in cut: faces.append(xf*plane)
			block = [corners,faces,marks]
		var polys: Array = made[0]
		var biggest: float = made[2]
		var occluder := solids.size() if growable else -1
		var anchor := NAN
		if rigid and path != null:
			var middle := Vector3.ZERO
			for q in points: middle += xf*q
			anchor = middle.x/points.size()
		var eroding := ruled and Style.eroded()
		# An eroded look: the block worn as the classic's, then its wear
		# dialled (`_dial`); drawn at `finish`, when its open faces can be
		# told, so only the wear on its open arrises and corners shows
		# (`_erode`). Its hull, its ivy, what it gives back and the numbers
		# drawn are the classic's.
		var dialled: Array = _dial(source,cut,wore,planes.size()) if eroding else []
		var shape := points
		if eroding:
			var mine: Array[Plane] = []
			for d: Array in dialled: mine.append(d[0])
			var drawn := _unique(Geometry3D.compute_convex_mesh_points(mine))
			if drawn.size() >= 4: shape = drawn
		var centre := Vector3.ZERO
		var part := 1.0
		if ruled:
			for q in shape: centre += xf*q
			centre /= shape.size()
			part = colour.get_luminance()/maxf(stone.get_luminance(),0.001)
		if eroding:
			var world: Array[Plane] = []
			var kinds := PackedByteArray()
			for d: Array in dialled:
				world.append(xf*(d[0] as Plane))
				kinds.append(int(d[1]))
			pending.append(["erode",world,centre,part,occluder,anchor,kinds])
		if cleaned and Style.carves():
			# A carved look (Style `carve`): the block is drawn at `finish`,
			# when every block stands and its open faces can be told, so
			# its arrises can be cut in broad facets (`_carve`).
			var world: Array[Plane] = []
			for plane in cut: world.append(xf*plane)
			pending.append(["carve",world,centre,part,occluder,anchor])
			polys = []
		for p: Array in polys:
			var on: Array[Vector3] = p[0]
			var normal := (xf.basis*(p[1] as Vector3)).normalized()
			var mid := xf*(p[2] as Vector3)
			var small := wear and float(p[3]) < biggest*0.16
			var shade: Color
			if cleaned: shade = Style.shade(clean_stone,centre,mid,normal,part)
			elif ruled:
				# The classic's colour worked out only to draw its numbers.
				_shade(mid,normal,linear,small)
				if eroding: continue
				shade = Style.shade(clean_stone,centre,mid,normal,part,small)
			else: shade = _shade(mid,normal,linear,small) if growable else linear*(1.0+rng.randf_range(-0.06,0.06))
			if not growable: shade.a = 1.0
			var corners := PackedVector3Array()
			for q in on: corners.append(xf*q)
			pending.append([corners,normal,shade,occluder,anchor,grow if not grow.is_empty() else null])
		if growable and not cleaned: _tops(polys,xf)
		if growable:
			var box := AABB(xf*points[0],Vector3.ZERO)
			for q in points: box = box.expand(xf*q)
			var world: Array[Plane] = []
			for plane in cut: world.append(xf*plane)
			solids.append([box.grow(0.01),world])
		if collide:
			# An eroded look's hull is the classic's worn block, so its routes
			# are the classic's whatever the dial (the drawn wear differs from
			# it by a few centimetres at most).
			var hull := PackedVector3Array()
			for q in points: hull.append(xf*q)
			# A sliver (a block cut nearly away by a hole's line or a break)
			# stays drawn but gets no hull: Jolt cannot build one so thin.
			if thickness(hull) >= HULL_THIN:
				hulls.append(hull)
				hull_anchors.append(anchor)
		if not block.is_empty():
			marks.append_array([pending.size(),tops.size(),hulls.size(),solids.size()])
			block[2] = marks
			blocks.append(block)
		return made[1]

	## `solid` in the native kernel (isle_kernels.h `ruin_solid`): the very
	## same draws, faces, tops, solid, hull and block, appended here.
	func _solid_native(kernel: Object, planes: Array[Plane], pose: Transform3D, colour: Color, collide: bool, wear: bool, extra: Array[Plane], open: int, rough: float, growable: bool) -> PackedVector3Array:
		var flags := int(collide)|int(wear)<<1|int(growable)<<2|int(lean)<<3|int(rigid)<<4|int(path != null)<<5|int(check_floating or keeps.is_valid())<<6|int(drop_floating)<<7
		var out: Array = kernel.ruin_solid(_solid_consts(),noise,bevels,rng.state,PackedFloat64Array([weathered,age,ground,pending.size(),tops.size(),hulls.size(),solids.size()]),
			flags,planes,extra,pose,frame,colour,stone,open,rough,grow)
		rng.state = out[0]
		pending.append_array(out[2])
		tops.append_array(out[3])
		if out[4] != null: solids.append(out[4])
		if out[5] != null:
			hulls.append(out[5])
			hull_anchors.append(out[6])
		if out[7] != null: blocks.append(out[7])
		return out[1]

	## The kit's constants the native `solid` reads, by look (made once each).
	static var _solid_consts_by_look := {}

	static func _solid_consts() -> Dictionary:
		var key := Style.current
		_native_lock.lock()
		if not _solid_consts_by_look.has(key):
			var lichen: Array = []
			for c: Color in LICHEN: lichen.append(c.srgb_to_linear())
			_solid_consts_by_look[key] = {"ruled":Style.ruled(),"eroded":Style.eroded(),"erode":(Style.LOOKS[key] as Dictionary).get("erode",{}),
				"wobble":WOBBLE,"chips":CHIPS,"chip":CHIP,"chunk":CHUNK,"chunk_odds":CHUNK_ODDS,"facets":FACETS,"edge_mix":EDGE_MIX,
				"streak":STREAK,"streak_scale":STREAK_SCALE,"damp":DAMP,"damp_rise":DAMP_RISE,"under":UNDER,"lichen_odds":LICHEN_ODDS,
				"moss_up":MOSS_UP,"moss_scale":MOSS_SCALE,"moss_age":MOSS_AGE,"moss_cover":MOSS_COVER,"hull_thin":HULL_THIN,
				"edge_linear":Color(EDGE).srgb_to_linear(),"moss":Color(MOSS),"moss_light":Color(MOSS_LIGHT),
				"moss_linear":Color(MOSS).srgb_to_linear(),"lichen_linear":lichen}
		var out: Dictionary = _solid_consts_by_look[key]
		_native_lock.unlock()
		return out

	## An eroded look's block (Style `erode`): its classic worn planes `cut`
	## (the block's own as built, `source`, then the wear's chips and chunk,
	## then the ground's), dialled: each face's wobble scaled back toward
	## true (tops more), the worn arrises the classic wore least left sharp
	## and the rest worn deeper, the shallowest chips and the least likely
	## chunks left out and the rest cut deeper. [plane, kind] each: 0 a face,
	## a break or the ground, 1 a worn arris, 2 a chip, 3 a chunk.
	func _dial(source: Array[Plane], cut: Array[Plane], wore: bool, count: int) -> Array:
		var out: Array = []
		for i in range(cut.size()):
			var p := cut[i]
			if i < source.size():
				var s := source[i]
				var n := p.normal
				var d := p.d
				if wore and not p.is_equal_approx(s):
					# The classic tilted the face about its point nearest the
					# middle and set it in a little: both scaled.
					var share := Style.erode("wobble_top" if s.normal.y > 0.85 else "wobble")
					var off := p.normal.dot(s.normal*s.d)-p.d
					n = s.normal.lerp(p.normal,share).normalized()
					d = n.dot(s.normal*s.d)-off*share
				var info: Variant = bevels.get(s) if i < count else null
				if info is Array:
					var arris: Array = info
					if float(arris[1]) < 1.0-Style.erode(arris[0]): continue
					d -= minf(float(arris[2])*Style.erode("arris"),float(arris[3]))-float(arris[2])
					out.append([Plane(n,d),1])
				else: out.append([Plane(n,d),0])
			elif wore and i-source.size() < worn_cuts.size():
				var w: Array = worn_cuts[i-source.size()]
				if w[0] == "chip":
					if float(w[1]) < 1.0-Style.erode("chip" if w[2] else "chip_low"): continue
					var more := minf(float(w[3])*Style.erode("chip_depth"),float(w[4]))-float(w[3])
					out.append([Plane(p.normal,p.d-maxf(more,0.0)),2])
				else:
					if float(w[1]) >= Style.erode("chunk"): continue
					var more := (minf(float(w[2])*Style.erode("chunk_depth"),0.5)-float(w[2]))*float(w[3])
					out.append([Plane(p.normal,p.d-maxf(more,0.0)),3])
			else: out.append([p,0])
		return out

	## A block's faces from its planes `cut` and corners `points`: [faces
	## ([corners, normal, middle, area] each, in the block's frame), the
	## corners of plane `open` (not a face), the biggest face's area].
	func _polys(cut: Array[Plane], points: PackedVector3Array, open: int) -> Array:
		var polys: Array = []
		var open_face := PackedVector3Array()
		var biggest := 0.0
		if points.size() < 4: return [polys,open_face,biggest]
		for i in range(cut.size()):
			var plane := cut[i]
			var on: Array[Vector3] = []
			for q in points:
				if absf(plane.distance_to(q)) < 0.0015: on.append(q)
			if on.size() < 3: continue
			var mid := Vector3.ZERO
			for q in on: mid += q
			mid /= on.size()
			var u := Vector3.ZERO
			for q in on:
				if (q-mid).length() > 0.0001:
					u = (q-mid).normalized()
					break
			var v := plane.normal.cross(u)
			on.sort_custom(func(p: Vector3, q: Vector3) -> bool: return atan2((p-mid).dot(v),(p-mid).dot(u)) < atan2((q-mid).dot(v),(q-mid).dot(u)))
			if i == open:
				open_face = PackedVector3Array(on)
				continue
			var area := 0.0
			for k in range(1,on.size()-1): area += (on[k]-on[0]).cross(on[k+1]-on[0]).length()*0.5
			biggest = maxf(biggest,area)
			polys.append([on,plane.normal,mid,area,i])
		return [polys,open_face,biggest]

	## The faces of `polys` (at `xf`) that look up, for the ivy and moss.
	func _tops(polys: Array, xf: Transform3D) -> void:
		for p: Array in polys:
			var normal := (xf.basis*(p[1] as Vector3)).normalized()
			if normal.y > 0.8 and float(p[3]) > 0.03:
				var poly := PackedVector3Array()
				for q: Vector3 in p[0]: poly.append(xf*q)
				tops.append([poly,float(p[3])])

	## One growth face (RuinGrowth): `corners` (a fan, in the piece's
	## frame), drawn with the growth's `grow` attrs; never solid.
	func growth_face(corners: PackedVector3Array, normal: Vector3, colour: Color) -> void:
		pending.append([corners,normal,colour,-1,NAN,grow.duplicate()])

	## The piece: ivy and moss grown on it, then the mesh and the body.
	func finish() -> Node3D:
		frame = Transform3D.IDENTITY
		if keeps.is_valid(): _keep_only()
		elif drop_floating: _drop_floating()
		if check_floating:
			var found := floating()
			if not found.is_empty():
				_floaters_lock.lock()
				for box: AABB in found: floaters.append({"label":root.name,"root":weakref(root),"box":box})
				_floaters_lock.unlock()
		if not _finish_native():
			_ivy()
			RuinGrowth.fringes(self)
			_cushions()
			_draw()
		if hand.is_valid(): hand.call(_nodes)
		else: _nodes()
		_body()
		root.set_meta("weathered",weathered)
		draws = hash([draws,rng.state])
		return root

	## The mesh and its instance made from what finish drew (on the main
	## thread, through `hand`, for a build on a worker: the renderer's RIDs).
	func _nodes() -> void:
		var mesh := ArrayMesh.new()
		var m := materials()
		for part: Array in [[faces,m.stone]]:
			var f: Faces = part[0]
			if f.v.is_empty(): continue
			var surface := []
			surface.resize(Mesh.ARRAY_MAX)
			surface[Mesh.ARRAY_VERTEX] = f.v
			surface[Mesh.ARRAY_NORMAL] = f.n
			surface[Mesh.ARRAY_COLOR] = f.c
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
			mesh.surface_set_material(mesh.get_surface_count()-1,part[1])
			# Kept for `merge`, which may run on a worker, where reading a
			# mesh's arrays back waits on the renderer (and the main thread).
			mesh.set_meta("arrays",surface)
		# The growth: its own surface (second), in the wind.
		if mesh.get_surface_count() > 0: RuinGrowth.add_surface(mesh,growth)
		var instance := MeshInstance3D.new()
		instance.name = "Mesh"
		instance.mesh = mesh
		root.add_child(instance)
		root.move_child(instance,0)

	## The body, of the hulls finish drew (physics' RIDs are made on a
	## worker too, as the isles' threaded builds do).
	func _body() -> void:
		var body := StaticBody3D.new()
		body.name = "Body"
		for i in range(hulls.size()):
			var hull := hulls[i]
			if path != null:
				var bent := PackedVector3Array()
				for q in hull: bent.append(bend(q,hull_anchors[i]))
				hull = bent
			var shape := ConvexPolygonShape3D.new()
			shape.points = hull
			var holder := CollisionShape3D.new()
			holder.shape = shape
			body.add_child(holder)
		root.add_child(body)

	## The kit's constants the native finish reads (made once).
	static var _native_consts := {}
	static var _native_lock := Mutex.new()

	static func _native_constants() -> Dictionary:
		_native_lock.lock()
		if _native_consts.is_empty():
			var ivy: Array = []
			for c: Color in IVY: ivy.append(c.srgb_to_linear())
			var vine: Array = []
			for c: Color in RuinGrowth.VINE: vine.append(c.srgb_to_linear())
			_native_consts = {"ivy_linear":ivy,"vine_linear":vine,"ivy_leaf":IVY_LEAF,"ivy_strands":IVY_STRANDS,"ivy_length":IVY_LENGTH,
				"ivy_most":IVY_MOST,"ivy_lean":IVY_LEAN,"cushion":CUSHION,"moss":Color(MOSS),"moss_light":Color(MOSS_LIGHT),
				"stem_colour":Color("3b4a26").srgb_to_linear(),"cull_off":CULL_OFF,"cell_cull":CELL_CULL,"leaf":RuinGrowth.LEAF,
				"leaf_width":RuinGrowth.LEAF_WIDTH,"stem":RuinGrowth.STEM,"node_step":RuinGrowth.NODE_STEP,"stem_step":RuinGrowth.STEM_STEP,
				"lean_scale":RuinGrowth.LEAN_SCALE,"tendril":RuinGrowth.TENDRIL,"spacing":RuinGrowth.SPACING,"strands":RuinGrowth.STRANDS,
				"strands_lean":RuinGrowth.STRANDS_LEAN,"length_gain":RuinGrowth.LENGTH_GAIN,"longest":RuinGrowth.LONGEST,
				"fringe_rate":RuinGrowth.FRINGE_RATE,"fringes":RuinGrowth.FRINGES,"fringes_lean":RuinGrowth.FRINGES_LEAN,
				"fringe_length":RuinGrowth.FRINGE_LENGTH}
		var out := _native_consts
		_native_lock.unlock()
		return out

	## `finish`'s ivy, fringes, curtains, cushions and drawing in the native
	## kernel (scripts/native_isle_kernels.gd), the very same faces and draws;
	## false (nothing done) without it, or for what it does not draw (a ground
	## callable, shelter, a bend, a carved look), which `finish` then does here.
	func _finish_native() -> bool:
		if terrain.is_valid() or shelter.is_valid() or path != null: return false
		var kernel: Object = NativeIsleKernels.get_kernel()
		if kernel == null: return false
		var build := _native_constants().duplicate()
		build.state = rng.state
		build.weathered = weathered
		build.age = age
		build.detail = level
		build.ground = ground
		build.lean = lean
		build.vines = RuinGrowth.vines
		build.cull = cull
		build.clean_stone = clean_stone
		build.look = Style.LOOKS[Style.current]
		build.solids = solids
		build.tops = tops
		build.hangs = hangs
		build.clear = clear
		build.pending = pending
		var out: Dictionary = kernel.ruin_finish(build)
		if out.is_empty(): return false
		rng.state = int(out.state)
		faces.v.append_array(out.v)
		faces.n.append_array(out.n)
		faces.c.append_array(out.c)
		growth.v.append_array(out.gv)
		growth.n.append_array(out.gn)
		growth.c.append_array(out.gc)
		growth.uv.append_array(out.guv)
		growth.uv2.append_array(out.guv2)
		growth.cu.append_array(out.gcu)
		pending.clear()
		grow = PackedFloat32Array()
		return true

	## Drawn stones resting on nothing (with `check_floating`): the blocks
	## joined to the ground (a block reaching within FLOAT_TOUCH of the
	## ground under it, or under the piece's lowest stone's top) through
	## blocks touching (within FLOAT_TOUCH: no face of either standing
	## clear of the other) are set; any other is floating. Their boxes (the
	## piece's frame, bent as drawn).
	func floating() -> Array:
		var out: Array = []
		for i: int in _floating_blocks():
			var box := _block_box(i)
			if path != null:
				var bent := AABB(bend(box.position),Vector3.ZERO)
				for k in range(8): bent = bent.expand(bend(box.get_endpoint(k)))
				box = bent
			out.append(box)
		return out

	func _block_box(i: int) -> AABB:
		var pts: PackedVector3Array = blocks[i][0]
		var box := AABB(pts[0],Vector3.ZERO)
		for q in pts: box = box.expand(q)
		return box

	## Takes out the floating blocks (`_floating_blocks`): their faces,
	## tops and hulls; their solids stand far off (their indices are kept).
	func _drop_floating() -> void:
		var gone := _floating_blocks()
		if gone.is_empty(): return
		_drop_blocks(gone)
		dropped += gone.size()

	## Takes out the blocks `keep_only` doesn't keep, and with
	## `drop_floating` the floating ones (all at once: a block's marks are
	## its places in `pending` as laid).
	func _keep_only() -> void:
		var gone: Array = _floating_blocks() if drop_floating else []
		dropped += gone.size()
		var floating_set := {}
		for i: int in gone: floating_set[i] = true
		for i in range(blocks.size()):
			if floating_set.has(i): continue
			var pts: PackedVector3Array = blocks[i][0]
			var mid := Vector3.ZERO
			for q in pts: mid += q
			if pts.is_empty() or not bool(keeps.call(mid/pts.size())): gone.append(i)
		if not gone.is_empty(): _drop_blocks(gone)

	## Blocks `gone` (indices into `blocks`) taken out: their faces, tops
	## and hulls; their solids stand far off (their indices are kept).
	func _drop_blocks(gone: Array) -> void:
		var drop_pending := {}
		var drop_tops := {}
		var drop_hulls := {}
		for i: int in gone:
			var m: PackedInt32Array = blocks[i][2]
			for k in range(m[0],m[4]): drop_pending[k] = true
			for k in range(m[1],m[5]): drop_tops[k] = true
			for k in range(m[2],m[6]): drop_hulls[k] = true
			for k in range(m[3],m[7]): solids[k] = [AABB(Vector3.ONE*1e6,Vector3.ZERO),[Plane(Vector3.UP,-1e7)]]
		var kept: Array = []
		for k in range(pending.size()):
			if not drop_pending.has(k): kept.append(pending[k])
		pending = kept
		var kept_tops: Array = []
		for k in range(tops.size()):
			if not drop_tops.has(k): kept_tops.append(tops[k])
		tops = kept_tops
		var kept_hulls: Array[PackedVector3Array] = []
		var kept_anchors := PackedFloat32Array()
		for k in range(hulls.size()):
			if drop_hulls.has(k): continue
			kept_hulls.append(hulls[k])
			kept_anchors.append(hull_anchors[k])
		hulls = kept_hulls
		hull_anchors = kept_anchors
		var still: Array = []
		var gone_set := {}
		for i: int in gone: gone_set[i] = true
		for i in range(blocks.size()):
			if not gone_set.has(i): still.append(blocks[i])
		blocks = still

	## The indices of the blocks resting on nothing.
	func _floating_blocks() -> Array:
		var n := blocks.size()
		if n == 0: return []
		var boxes: Array[AABB] = []
		var low := INF
		for blk: Array in blocks:
			var pts: PackedVector3Array = blk[0]
			var box := AABB(pts[0],Vector3.ZERO)
			for q in pts: box = box.expand(q)
			boxes.append(box)
			low = minf(low,box.position.y)
		var held := PackedByteArray()
		held.resize(n)
		var frontier: Array[int] = []
		for i in range(n):
			var box := boxes[i]
			var c := box.get_center()
			var under := floor_at(c.x,c.z) if terrain.is_valid() else 0.0
			if box.position.y <= maxf(under,low)+FLOAT_TOUCH or (ground > -INF and box.position.y <= ground+FLOAT_TOUCH):
				held[i] = 1
				frontier.append(i)
		# A grid of the boxes, so each block meets only its neighbours.
		var grid := {}
		for i in range(n):
			var box := boxes[i].grow(FLOAT_TOUCH)
			for cx in range(floori(box.position.x/CELL_CULL),floori(box.end.x/CELL_CULL)+1):
				for cy in range(floori(box.position.y/CELL_CULL),floori(box.end.y/CELL_CULL)+1):
					for cz in range(floori(box.position.z/CELL_CULL),floori(box.end.z/CELL_CULL)+1):
						var key := Vector3i(cx,cy,cz)
						if not grid.has(key): grid[key] = PackedInt32Array()
						grid[key].append(i)
		while not frontier.is_empty():
			var i: int = frontier.pop_back()
			var box := boxes[i].grow(FLOAT_TOUCH)
			var seen := {}
			for cx in range(floori(box.position.x/CELL_CULL),floori(box.end.x/CELL_CULL)+1):
				for cy in range(floori(box.position.y/CELL_CULL),floori(box.end.y/CELL_CULL)+1):
					for cz in range(floori(box.position.z/CELL_CULL),floori(box.end.z/CELL_CULL)+1):
						for j: int in grid.get(Vector3i(cx,cy,cz),PackedInt32Array()):
							if held[j] == 1 or seen.has(j): continue
							seen[j] = true
							if not box.intersects(boxes[j]): continue
							if _touch(blocks[i],blocks[j]):
								held[j] = 1
								frontier.append(j)
		var out: Array = []
		for i in range(n):
			if held[i] == 0: out.append(i)
		if (drop_floating and not drop_loose) or out.is_empty(): return out
		# Not a piece that drops its floaters (walls coursed down a hill, a
		# run of stumps, drifting stones): only a stone or two resting on
		# nothing counts, not a whole structure standing on its own.
		var small: Array = []
		var left := {}
		for i: int in out: left[i] = true
		while not left.is_empty():
			var first: int = left.keys()[0]
			left.erase(first)
			var group: Array[int] = [first]
			var k := 0
			while k < group.size():
				var i := group[k]
				k += 1
				for j: int in left.keys():
					if boxes[i].grow(FLOAT_TOUCH).intersects(boxes[j]) and _touch(blocks[i],blocks[j]):
						left.erase(j)
						group.append(j)
			if group.size() <= FLOAT_MOST: small.append_array(group)
		return small

	## Whether two blocks ([points, planes]) touch within FLOAT_TOUCH: no
	## face of either has all the other's corners past it.
	static func _touch(a: Array, b: Array) -> bool:
		for pair: Array in [[a,b],[b,a]]:
			var faces: Array[Plane] = pair[0][1]
			var pts: PackedVector3Array = pair[1][0]
			for plane in faces:
				var clear := true
				for q in pts:
					if plane.distance_to(q) <= FLOAT_TOUCH:
						clear = false
						break
				if clear: return false
		return true

	## Where straight point `p` is drawn: along the bend (by its own x, or
	## a rigid block's `anchor`), or where it is with no bend.
	func bend(p: Vector3, anchor := NAN) -> Vector3:
		if path == null: return p
		if is_nan(anchor): return path.xform(p.x)*Vector3(0.0,p.y,p.z)
		return path.xform(anchor)*(p-Vector3(anchor,0.0,0.0))

	## The faces built so far into the mesh: those hidden (with `cull`)
	## left out, the rest bent along `path`.
	func _draw() -> void:
		var grid := {}
		var carving := false
		for face: Array in pending:
			if face[0] is String:
				carving = true
				break
		if cull or carving:
			for i in range(solids.size()):
				var box: AABB = solids[i][0]
				for cx in range(floori(box.position.x/CELL_CULL),floori(box.end.x/CELL_CULL)+1):
					for cy in range(floori(box.position.y/CELL_CULL),floori(box.end.y/CELL_CULL)+1):
						for cz in range(floori(box.position.z/CELL_CULL),floori(box.end.z/CELL_CULL)+1):
							var key := Vector3i(cx,cy,cz)
							if not grid.has(key): grid[key] = PackedInt32Array()
							grid[key].append(i)
		if carving:
			var faces_out: Array = []
			for face: Array in pending:
				if face[0] is String: faces_out.append_array(_erode(face,grid) if face[0] == "erode" else _carve(face,grid))
				else: faces_out.append(face)
			pending = faces_out
		for face: Array in pending:
			var corners: PackedVector3Array = face[0]
			var normal: Vector3 = face[1]
			if cull and _hidden(corners,normal,int(face[3]),grid): continue
			var anchor: float = face[4]
			var shade: Color = face[2]
			if shelter.is_valid():
				var mid := Vector3.ZERO
				for q in corners: mid += q
				shade.a = 1.0-clampf(float(shelter.call(mid/corners.size(),normal)),0.0,1.0)
			var turn := Basis.IDENTITY
			if path != null:
				var middle := Vector3.ZERO
				for q in corners: middle += q
				middle /= corners.size()
				var at: float = middle.x if is_nan(anchor) else anchor
				turn = (path.xform(at) as Transform3D).basis
				normal = (turn*normal).normalized()
				var bent := PackedVector3Array()
				for q in corners: bent.append(bend(q,anchor))
				corners = bent
			if face[5] != null:
				RuinGrowth.emit(growth,corners,normal,shade,face[5],turn)
				continue
			for k in range(1,corners.size()-1):
				_wound(faces,corners[0],corners[k],corners[k+1],normal,shade)
		pending.clear()

	## A carved look's block (`solid`'s ["carve", planes (straight, the
	## piece's frame), middle, part, occluder, anchor]) as faces to draw:
	## each arris between two open faces (not against another block, not
	## buried) that is a top's edge or an upright corner may be cut in one
	## broad facet (Style `carve`: how often, how deep, how far round),
	## chosen by the arris's line and stretch (no random draw), so flush
	## neighbours along one wall head or step take the same cut and read as
	## one carved edge. Tops stay flat; collision is the uncut block's.
	func _carve(entry: Array, grid: Dictionary) -> Array:
		var planes: Array[Plane] = entry[1]
		var centre: Vector3 = entry[2]
		var part: float = entry[3]
		var own: int = entry[4]
		var anchor: float = entry[5]
		var points := _unique(Geometry3D.compute_convex_mesh_points(planes))
		var out: Array = []
		if points.size() < 4: return out
		var made: Array = _polys(planes,points,-1)
		var box := AABB(points[0],Vector3.ZERO)
		for q in points: box = box.expand(q)
		var least := minf(box.size.x,minf(box.size.y,box.size.z))
		var carve: Dictionary = Style.get_value("carve")
		var faces: Array = made[0]
		var open: Array = []
		for f: Array in faces:
			var corners := PackedVector3Array(f[0] as Array)
			open.append(not _hidden(corners,f[1],own,grid))
		var cuts: Array[Plane] = planes.duplicate()
		for i in range(faces.size()):
			if not open[i]: continue
			for j in range(i+1,faces.size()):
				if not open[j]: continue
				var ni: Vector3 = faces[i][1]
				var nj: Vector3 = faces[j][1]
				var top := -1
				if ni.y > 0.85 and absf(nj.y) < 0.35: top = i
				elif nj.y > 0.85 and absf(ni.y) < 0.35: top = j
				var upright := absf(ni.y) < 0.35 and absf(nj.y) < 0.35 and absf(ni.dot(nj)) < 0.6
				if top < 0 and not upright: continue
				# Their shared arris.
				var shared: Array[Vector3] = []
				for q: Vector3 in faces[i][0]:
					for r: Vector3 in faces[j][0]:
						if q.distance_squared_to(r) < 1e-6:
							shared.append(q)
							break
				if shared.size() < 2: continue
				var a: Vector3 = shared[0]
				var b: Vector3 = shared[1]
				if a.distance_to(b) < 0.25: continue
				var along := (b-a).normalized()
				var mid := (a+b)*0.5
				var pi := Plane(ni,ni.dot(a))
				var pj := Plane(nj,nj.dot(a))
				var key := [Vector3i((ni*20.0).round()),int(roundf(pi.d*20.0)),Vector3i((nj*20.0).round()),int(roundf(pj.d*20.0)),
					int(floorf(along.abs().dot(mid)/float(carve.stretch)))]
				if ni.x+ni.z*0.7 > nj.x+nj.z*0.7: key = [key[2],key[3],key[0],key[1],key[4]]
				var h := hash(key)
				var u := Style.unit(h)
				# Lean stone (the halls, by the dozen) carves half as often.
				var odds: float = (float(carve.edge) if top >= 0 else float(carve.corner))*(float(carve.lean) if lean else 1.0)
				if u >= odds: continue
				var v := Style.unit(hash([h,1]))
				var w := Style.unit(hash([h,2]))
				var depth: Vector2 = carve.edge_depth if top >= 0 else carve.corner_depth
				var c := minf(lerpf(depth.x,depth.y,v),least*float(carve.share))
				# How far round from the one face to the other the facet
				# looks: a top's lip leans to the face below, steep.
				var turn := lerpf(0.35,0.65,w) if top < 0 else lerpf(0.5,0.7,w)
				var first := ni if top != j else nj
				var second := nj if top != j else ni
				if top >= 0:
					first = faces[top][1]
					second = nj if top == i else ni
				var n := (first*cos(turn*PI*0.5)+second*sin(turn*PI*0.5)).normalized()
				cuts.append(Plane(n,n.dot(a)-c))
		# Broad planes across the open faces themselves: each open face's
		# plane is laid out in stretches (`stretch` m along it, by the
		# world, not the stone), and in a stretch one crease runs across,
		# the face past it turned a few degrees away (tops barely: still
		# flat underfoot). Every stone in the plane and the stretch takes
		# the same cut, so a coursed wall reads as a few broad planes, not
		# as its stones.
		for i in range(faces.size()):
			if not open[i]: continue
			var n: Vector3 = faces[i][1]
			var mid: Vector3 = faces[i][2]
			var flat := n.y > 0.85
			if not flat and absf(n.y) > 0.35: continue
			if float(faces[i][3]) < float(carve.crease_area): continue
			var plane_key := [Vector3i((n*20.0).round()),int(roundf(n.dot(mid)*20.0)),"crease"]
			var d: Vector3
			if flat:
				var a := Style.unit(hash(plane_key))*TAU
				d = Vector3(cos(a),0.0,sin(a))
			else:
				d = n.cross(Vector3.UP).normalized()
			d = (d-n*n.dot(d)).normalized()
			var stretch: float = carve.stretch
			var s := d.dot(mid)
			var cell := floorf(s/stretch)
			var h := hash(plane_key+[int(cell)])
			if Style.unit(h) >= float(carve.crease)*(float(carve.lean) if lean else 1.0): continue
			# The crease across the stretch, and which way the face past it
			# turns away (toward the stretch's nearer end).
			var at := (cell+lerpf(0.3,0.7,Style.unit(hash([h,2]))))*stretch
			var way := 1.0 if Style.unit(hash([h,1])) < 0.5 else -1.0
			var room := ((cell+1.0)*stretch-at) if way > 0.0 else (at-cell*stretch)
			var most: float = carve.crease_flat if flat else float(carve.crease_side)
			var tilt := atan(minf(most,room*tan(deg_to_rad(lerpf(carve.crease_angle.x,carve.crease_angle.y,Style.unit(hash([h,3]))))))/maxf(room,0.01))
			var dd := d*way
			var from := mid+d*(at-s)
			var m := (n*cos(tilt)+dd*sin(tilt)).normalized()
			cuts.append(Plane(m,m.dot(from)))
		if cuts.size() > planes.size():
			var carved := _unique(Geometry3D.compute_convex_mesh_points(cuts))
			if carved.size() >= 4:
				points = carved
				made = _polys(cuts,points,-1)
		for f: Array in made[0]:
			var corners := PackedVector3Array(f[0] as Array)
			var normal: Vector3 = f[1]
			out.append([corners,normal,Style.shade(clean_stone,centre,f[2],normal,part),own,anchor,null])
		return out

	## An eroded look's block (`solid`'s ["erode", planes (straight, the
	## piece's frame), middle, part, occluder, anchor, kinds (each plane's:
	## 0 a face or break, 1 a worn arris, 2 a chip, 3 a chunk gone)]) as
	## faces to draw: the wear shows only where the stone is open, so a wall
	## reads worn at its head, its ends and its breaks, not stone by stone.
	## A worn arris stays where both faces it rounds are open (not against
	## another block); a chip where two of the faces round its corner are;
	## a chunk always. Collision stays the worn block's (`solid`).
	func _erode(entry: Array, grid: Dictionary) -> Array:
		var planes: Array[Plane] = entry[1]
		var centre: Vector3 = entry[2]
		var part: float = entry[3]
		var own: int = entry[4]
		var anchor: float = entry[5]
		var kinds: PackedByteArray = entry[6]
		var out: Array = []
		# The block without its arrises and chips: which of its faces are open.
		var base: Array[Plane] = []
		for i in range(planes.size()):
			if kinds[i] == 0 or kinds[i] == 3: base.append(planes[i])
		var faces: Array = _polys(base,_unique(Geometry3D.compute_convex_mesh_points(base)),-1)[0]
		var open: Array[Vector3] = []
		var shut: Array[Vector3] = []
		for f: Array in faces:
			if _covered(PackedVector3Array(f[0] as Array),f[1],own,grid): shut.append(f[1])
			else: open.append(f[1])
		var keep: Array[Plane] = []
		var kept := PackedByteArray()
		for i in range(planes.size()):
			var kind := kinds[i]
			if kind == 1 or kind == 2:
				var n := planes[i].normal
				var reach := 0.6 if kind == 1 else 0.3
				var seen := 0
				var hid := 0
				for m in open:
					if m.dot(n) > reach: seen += 1
				for m in shut:
					if m.dot(n) > reach: hid += 1
				if kind == 1 and hid > 0: continue
				if kind == 2 and seen < 2: continue
			keep.append(planes[i])
			kept.append(kind)
		var points := _unique(Geometry3D.compute_convex_mesh_points(keep))
		if points.size() < 4: return out
		for f: Array in _polys(keep,points,-1)[0]:
			var normal: Vector3 = f[1]
			var worn := kept[int(f[4])] != 0
			out.append([PackedVector3Array(f[0] as Array),normal,Style.shade(clean_stone,centre,f[2],normal,part,worn),own,anchor,null])
		return out

	## Whether a face (its corners, straight) is mostly against another
	## block or the ground (an eroded look's joint, `_erode`): its middle
	## and at least half of its corners, drawn in halfway, a little off it
	## lie inside other blocks; so a course's top under the next course's
	## worn foot, or a stone set a little back, still counts as a joint.
	func _covered(corners: PackedVector3Array, normal: Vector3, own: int, grid: Dictionary) -> bool:
		var middle := Vector3.ZERO
		for q in corners: middle += q
		middle /= corners.size()
		if not _solid_at(middle+normal*CULL_OFF*2.0,own,grid): return false
		var inside := 0
		for q in corners:
			if _solid_at(q.lerp(middle,0.5)+normal*CULL_OFF*2.0,own,grid): inside += 1
		return inside*2 >= corners.size()

	## Whether `p` lies inside a block other than `own`, or under the ground.
	func _solid_at(p: Vector3, own: int, grid: Dictionary) -> bool:
		if p.y < floor_at(p.x,p.z)-0.01 or p.y < ground-0.01: return true
		var key := Vector3i(floori(p.x/CELL_CULL),floori(p.y/CELL_CULL),floori(p.z/CELL_CULL))
		if not grid.has(key): return false
		for i in grid[key]:
			if i == own: continue
			var s: Array = solids[i]
			if not (s[0] as AABB).has_point(p): continue
			var inside := true
			for plane: Plane in s[1]:
				if plane.distance_to(p) > 0.0:
					inside = false
					break
			if inside: return true
		return false

	## Whether a face (its corners, straight) is hidden: every corner (drawn
	## in a little toward its middle) and its middle, stood a little off the
	## face, lie inside another block or under the ground.
	func _hidden(corners: PackedVector3Array, normal: Vector3, own: int, grid: Dictionary) -> bool:
		var middle := Vector3.ZERO
		for q in corners: middle += q
		middle /= corners.size()
		var probes := PackedVector3Array([middle])
		for q in corners: probes.append(q.lerp(middle,0.1))
		for q in probes:
			var p := q+normal*CULL_OFF
			if p.y < floor_at(p.x,p.z)-0.01 or p.y < ground-0.01: continue
			var key := Vector3i(floori(p.x/CELL_CULL),floori(p.y/CELL_CULL),floori(p.z/CELL_CULL))
			if not grid.has(key): return false
			var found := false
			for i in grid[key]:
				if i == own: continue
				var s: Array = solids[i]
				if not (s[0] as AABB).has_point(p): continue
				var inside := true
				for plane: Plane in s[1]:
					if plane.distance_to(p) > 0.0:
						inside = false
						break
				if inside:
					found = true
					break
			if not found: return false
		return true

	## The weathering's cuts on one block: every face's wobble (some even as
	## built), corners chipped (a few even as built, more as it weathers),
	## maybe a chunk gone. Plane `keep` keeps its place.
	func _wear(planes: Array[Plane], rough: float, keep: int) -> Array[Plane]:
		var a := clampf(age*rough,0.0,1.0)
		var w := clampf(weathered*rough,0.0,1.0)
		var out: Array[Plane] = []
		var wobble := WOBBLE.x+(WOBBLE.y-WOBBLE.x)*w
		# An eroded look (Style `erode`) dials the classic's cuts, drawing
		# the same numbers.
		var eroded := Style.eroded()
		worn_cuts = []
		for i in range(planes.size()):
			var p := planes[i]
			# Lean stone keeps its tops level (walked, and stacked flush).
			if i == keep or (lean and p.normal.y > 0.99):
				out.append(p)
				continue
			var tilt := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))*wobble
			var n := (p.normal+tilt-p.normal*p.normal.dot(tilt)).normalized()
			out.append(Plane(n,n.dot(p.normal*p.d)-rng.randf()*0.012*a))
		var points := _unique(Geometry3D.compute_convex_mesh_points(out))
		if points.size() < 4: return out
		var centre := Vector3.ZERO
		for q in points: centre += q
		centre /= points.size()
		var box := AABB(points[0],Vector3.ZERO)
		for q in points: box = box.expand(q)
		var least := minf(box.size.x,minf(box.size.y,box.size.z))*0.5
		var chips := int(round((CHIPS.x*rough+CHIPS.y*w)*rng.randf_range(0.3,1.0)*(0.15 if lean else 1.0)))
		for c in range(chips):
			var corner := points[rng.randi()%points.size()]
			if keep >= 0 and absf(planes[keep].distance_to(corner)) < 0.01: continue
			var n := ((corner-centre).normalized()+Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(-0.35,0.35),rng.randf_range(-0.35,0.35))).normalized()
			var reach := -INF
			for q in points: reach = maxf(reach,n.dot(q))
			var size := rng.randf_range(CHIP.x,CHIP.y)
			var bite := least*size*(0.35+0.65*a)
			out.append(Plane(n,reach-bite))
			if eroded: worn_cuts.append(["chip",(size-CHIP.x)/(CHIP.y-CHIP.x),corner.y >= centre.y,bite,least*0.75])
		var odds := (CHUNK_ODDS*w+0.05*minf(rough,1.0))*(0.5 if lean else 1.0)
		var roll := rng.randf()
		if roll < odds:
			var n := Vector3(rng.randf_range(-1,1),rng.randf_range(0.0,1.0),rng.randf_range(-1,1)).normalized()
			var reach := -INF
			var low := INF
			for q in points:
				reach = maxf(reach,n.dot(q))
				low = minf(low,n.dot(q))
			var share := rng.randf_range(CHUNK.x,CHUNK.y)
			out.append(Plane(n,reach-(reach-low)*share))
			if eroded: worn_cuts.append(["chunk",roll/odds,share,reach-low])
		return out

	## A face's colour (linear): its block's, a facet's own step lighter or
	## darker; worn arrises paler; dark stain bands down the sides; the damp
	## foot and the undersides darker; lichen here and there; moss on what
	## looks up.
	func _shade(at: Vector3, normal: Vector3, base: Color, worn: bool) -> Color:
		var c := base*(1.0+rng.randf_range(-0.5,0.5)*FACETS*2.0)
		if worn: c = c.lerp(Color(EDGE).srgb_to_linear(),EDGE_MIX*(0.55+0.45*age)*rng.randf_range(0.6,1.2))
		if absf(normal.y) < 0.6:
			var band := noise.get_noise_2d(at.x*STREAK_SCALE*1.7+at.z*0.31,at.z*STREAK_SCALE*1.7-at.x*0.29)
			c *= 1.0-STREAK*smoothstep(-0.05,0.45,band)*(0.45+0.55*age)
		c *= lerpf(DAMP,1.0,smoothstep(0.0,DAMP_RISE,at.y))
		if normal.y < -0.3: c *= UNDER
		if rng.randf() < LICHEN_ODDS*(0.6+age) and normal.y > -0.2:
			c = c.lerp(Color(LICHEN[rng.randi()%LICHEN.size()]).srgb_to_linear(),rng.randf_range(0.25,0.5))
		var patch := noise.get_noise_3dv(at*MOSS_SCALE)*0.5+0.5
		if normal.y > MOSS_UP and patch < (MOSS_AGE+weathered*MOSS_COVER)*normal.y:
			return Color(MOSS).lerp(Color(MOSS_LIGHT),rng.randf()*0.6).srgb_to_linear()*(0.9+0.15*normal.y)
		if absf(normal.y) < 0.5 and patch < weathered*0.3 and at.y < 2.5:
			c = c.lerp(Color(MOSS).srgb_to_linear(),0.3*weathered)
		return Color(c.r,c.g,c.b,1.0)

	## Whether `p` lies inside any block.
	func _inside(p: Vector3) -> bool:
		for s: Array in solids:
			if not (s[0] as AABB).has_point(p): continue
			var inside := true
			for plane: Plane in s[1]:
				if plane.distance_to(p) > 0.0:
					inside = false
					break
			if inside: return true
		return false

	## How far from `p` along `dir` the stone is (up to `most`).
	func _gap(p: Vector3, dir: Vector3, most: float) -> float:
		var t := 0.0
		while t < most:
			if _inside(p+dir*t): return t
			t += 0.04
		return most

	## The ivy: strands hung from the heads of walls and the edges of high
	## tops, draping down the faces (pushed out round what stands proud,
	## hanging free under overhangs a little way), mats over the tops they
	## come from, a spread where they reach the ground; and the free strands
	## a piece asked for under its arches.
	func _ivy() -> void:
		var high: Array = []
		var area := 0.0
		for t: Array in tops:
			var poly: PackedVector3Array = t[0]
			if poly[0].y < 0.75: continue
			high.append(t)
			area += float(t[1])
		# As many strands as the tops' area asks, capped (lean stone, fewer),
		# then thinned by the detail (so a big ruin thins too).
		var count := int(mini(IVY_LEAN if lean else IVY_MOST,int(area*lerpf(IVY_STRANDS.x,IVY_STRANDS.y,weathered)+rng.randf()))*level)
		var longest := lerpf(IVY_LENGTH.x,IVY_LENGTH.y,weathered)
		for i in range(count):
			if high.is_empty(): break
			for attempt in range(8):
				var roll := rng.randf()*area
				var pick: Array = high[0]
				for t: Array in high:
					roll -= float(t[1])
					if roll <= 0.0:
						pick = t
						break
				var poly: PackedVector3Array = pick[0]
				var centre := Vector3.ZERO
				for q in poly: centre += q
				centre /= poly.size()
				var k := rng.randi()%poly.size()
				var p0 := poly[k]
				var p1 := poly[(k+1)%poly.size()]
				var edge := p1-p0
				var out := Vector3(edge.z,0.0,-edge.x).normalized()
				if out.length() < 0.5: continue
				var mid := p0.lerp(p1,rng.randf_range(0.15,0.85))
				if out.dot(mid-centre) < 0.0: out = -out
				# Only where the face falls away under the edge.
				if _inside(mid+out*0.12+Vector3.DOWN*0.3) or _inside(mid+out*0.1+Vector3.UP*0.08): continue
				var start := mid+out*0.05+Vector3.UP*0.03
				# A mat over the top it comes from (it only flutters).
				grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.35,fposmod(mid.x*3.17+mid.z*5.31,1.0),false,0.6)
				for j in range(rng.randi_range(2,4)):
					var on := mid-out*rng.randf_range(0.0,0.3)+edge.normalized()*rng.randf_range(-0.25,0.25)+Vector3.UP*0.02
					_leaf(on,Vector3.UP,rng.randf_range(IVY_LEAF.x,IVY_LEAF.y),0.0)
				_strand(start,out,minf(mid.y,rng.randf_range(0.4,1.0)*longest),false)
				break
		# The free strands a piece asked for under its arches, beams and
		# decks: vine curtains (RuinGrowth).
		RuinGrowth.curtains(self)
		grow = PackedFloat32Array()

	## One strand from `start` down, `out` the way the face looks; `free`:
	## hanging in the air, swaying a little.
	func _strand(start: Vector3, out: Vector3, length: float, free: bool) -> void:
		var along := Vector3(-out.z,0.0,out.x)
		var p := start
		var travelled := 0.0
		var size := rng.randf_range(IVY_LEAF.x,IVY_LEAF.y)*(1.45 if lean else 1.15)
		var in_air := 0.0
		var phase := fposmod(start.x*3.17+start.z*5.31,1.0)
		while travelled < length:
			var taper := 1.0-0.55*smoothstep(length*0.55,length,travelled)
			# Swaying from where it starts: free in the air, or hugging its
			# face (RuinGrowth `attrs`).
			grow = RuinGrowth.attrs(start.y,length,out,1.0 if free else clampf(in_air/0.4,0.0,1.0),1.0,fposmod(phase+travelled*0.37,1.0))
			for j in range((1 if lean else 2)+int(rng.randf() < 0.5)):
				var off := along*rng.randf_range(-0.16,0.16)+Vector3(0.0,rng.randf_range(-0.05,0.05),0.0)+out*rng.randf_range(0.0,0.05)
				_leaf(p+off,out,size*taper*rng.randf_range(0.75,1.1),0.5)
			var step := rng.randf_range(0.11,0.17)*(1.8 if lean else 1.0)
			var next := p+Vector3.DOWN*step+along*rng.randf_range(-0.05,0.05)*(0.4 if free else 1.0)
			if not free:
				var pushed := 0.0
				while _inside(next) and pushed < 0.7:
					next += out*0.05
					pushed += 0.05
				if pushed >= 0.7: break
				var gap := _gap(next,-out,0.45)
				if gap < 0.45:
					next -= out*maxf(0.0,gap-0.05)
					in_air = 0.0
				else:
					in_air += step
					if in_air > 1.0: break
			elif _inside(next): break
			if next.y < 0.05:
				# A spread where it meets the ground.
				grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.35,phase,false,0.6)
				for j in range(rng.randi_range(2,5)):
					var on := Vector3(next.x,0.03,next.z)+out*rng.randf_range(0.0,0.5)+along*rng.randf_range(-0.4,0.4)
					_leaf(on,Vector3.UP,rng.randf_range(IVY_LEAF.x,IVY_LEAF.y),0.0)
				break
			p = next
			travelled += step

	## One clump of leaves at `at`, facing `out` (tipped down by `droop`):
	## a low, cut, five-sided mound, a green of the ivy's, never solid.
	func _leaf(at: Vector3, out: Vector3, size: float, droop: float) -> void:
		var face := (out+Vector3.DOWN*droop*rng.randf_range(0.3,1.0)+Vector3(rng.randf_range(-0.4,0.4),rng.randf_range(-0.3,0.3),rng.randf_range(-0.4,0.4))).normalized()
		var side := face.cross(Vector3.UP if absf(face.y) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side,face,side.cross(face)).orthonormalized()
		var planes: Array[Plane] = [Plane(Vector3.DOWN,0.0)]
		var turn := rng.randf()*TAU
		for k in range(3 if lean else 5):
			var a := turn+TAU*k/(3.0 if lean else 5.0)+rng.randf_range(-0.2,0.2)
			planes.append(Plane(Vector3(cos(a),0.0,sin(a)),size*rng.randf_range(0.42,0.55)))
			var n := Vector3(cos(a+0.6)*0.9,1.0,sin(a+0.6)*0.9).normalized()
			planes.append(Plane(n,n.dot(Vector3(0.0,size*0.32,0.0))))
		var light := clampf(face.y*0.5+0.5+rng.randf_range(-0.3,0.3),0.0,0.999)
		var colour: Color = IVY[int(light*IVY.size())]
		solid(planes,Transform3D(basis,at),colour,false,false,[],-1,1.0,false)

	## A tuft of grass at `at` (on the ground or a ledge): `count` blades about
	## `height` tall, each a thin cut sliver leaning its own way, in the
	## plate's olive greens; never solid.
	func tuft(at: Vector3, height: float, count := 7) -> void:
		count = int(round(count*level*(0.5 if lean else 1.0)))
		var keep := frame
		frame = Transform3D.IDENTITY
		# Standing up from its root, bending as the grass does.
		grow = RuinGrowth.attrs(at.y-0.02,height*1.15,Vector3.ZERO,1.0,0.6,fposmod(at.x*3.17+at.z*5.31,1.0),true)
		for i in range(count):
			var h := height*rng.randf_range(0.55,1.15)
			var w := rng.randf_range(0.035,0.06)*(0.7+0.6*h)
			var planes: Array[Plane] = [Plane(Vector3.BACK,0.012),Plane(Vector3.FORWARD,0.012),Plane(Vector3.DOWN,0.0)]
			for s: float in [-1.0,1.0]:
				var n := Vector3(s*h,w,0.0).normalized()
				planes.append(Plane(n,n.dot(Vector3(s*w,0.0,0.0))))
			var lean := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(0.1,0.5))
			var off := Vector3(rng.randf_range(-1,1),0.0,rng.randf_range(-1,1))*height*0.3
			var colour: Color = GRASS[rng.randi()%GRASS.size()]*rng.randf_range(0.85,1.12)
			solid(planes,Transform3D(lean,at+off-Vector3(0.0,0.02,0.0)),colour,false,false,[],-1,1.0,false)
		frame = keep
		grow = PackedFloat32Array()

	## Moss cushions on mossy tops: low faceted mounds, not solid.
	func _cushions() -> void:
		if level <= 0.0: return
		# Moss never moves: still growth, on the growth's surface.
		grow = RuinGrowth.still()
		var found := tops.duplicate()
		for t: Array in found:
			var poly: PackedVector3Array = t[0]
			var area: float = t[1]
			var odds := (0.08+0.55*weathered)*minf(1.0,area*2.0)*level*(0.5 if lean else 1.0)
			if rng.randf() > odds: continue
			for j in range(1+int(area*2.0*weathered)):
				var k := rng.randi()%poly.size()
				var centre := Vector3.ZERO
				for q in poly: centre += q
				centre /= poly.size()
				var at := centre.lerp(poly[k].lerp(poly[(k+1)%poly.size()],rng.randf()),rng.randf()*0.75)
				var r := rng.randf_range(CUSHION.x,CUSHION.y)*minf(1.0,sqrt(area))
				var planes: Array[Plane] = [Plane(Vector3.DOWN,0.0),Plane(Vector3.UP,r*rng.randf_range(0.3,0.5))]
				var turn := rng.randf()*TAU
				var sides := 4 if lean else 6
				for e in range(sides):
					var a := turn+TAU*e/float(sides)
					planes.append(Plane(Vector3(cos(a),0.0,sin(a)),r))
					var n := Vector3(cos(a+0.5)*0.8,1.0,sin(a+0.5)*0.8).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,r*0.4,0.0))))
				solid(planes,Transform3D(Basis.IDENTITY,at-Vector3(0.0,0.02,0.0)),Color(MOSS_LIGHT).lerp(Color(MOSS),rng.randf()*0.6),false,false,[],-1,1.0,false)
		grow = PackedFloat32Array()

	static func _tri(target: Faces, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
		for p in [a,b,c]:
			target.v.append(p)
			target.n.append(normal)
			target.c.append(colour)

	## A triangle wound to face `normal` (front faces are clockwise).
	static func _wound(target: Faces, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
		if (b-a).cross(c-a).dot(normal) > 0.0: _tri(target,a,c,b,normal,colour)
		else: _tri(target,a,b,c,normal,colour)

	static func _unique(points: PackedVector3Array) -> PackedVector3Array:
		var out := PackedVector3Array()
		for p in points:
			var seen := false
			for q in out:
				if p.distance_squared_to(q) < 1e-8:
					seen = true
					break
			if not seen: out.append(p)
		return out

## A surface's faces as they are built.
class Faces extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
