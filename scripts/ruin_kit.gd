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
## hull. Ivy and moss are faceted too: small cut leaf clumps strung down the
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
const STONE_SHADER = preload("res://shaders/ruin_stone.gdshader")

## The pieces, in the kit's order: the gothic abbey's, here.
const PIECES := ["pier","arch","lancet_wall","rose_gable","buttress","wall","stairs","turret","vault","fallen_pier","tomb_chest","floor"]
## The families: the gothic abbey (here), the aqueduct (scripts/
## ruin_kit_aqueduct.gd) and the colossus hall (scripts/ruin_kit_hall.gd),
## each its pieces in order; ALL_PIECES the lot.
const AQUEDUCT_PIECES := ["aqueduct_span","aqueduct_two_tier","aqueduct_broken","aqueduct_stump","aqueduct_end"]
const HALL_PIECES := ["hall_column","hall_beam","hall_slab","hall_bay"]
const FAMILIES := {"gothic":PIECES,"aqueduct":AQUEDUCT_PIECES,"hall":HALL_PIECES}
const ALL_PIECES := PIECES+AQUEDUCT_PIECES+HALL_PIECES
const NAMES := {"pier":"Clustered pier","arch":"Pointed arch","lancet_wall":"Lancet window wall",
	"rose_gable":"Rose window gable","buttress":"Buttress","wall":"Wall","stairs":"Stair flight",
	"turret":"Stair turret","vault":"Vault ribs","fallen_pier":"Fallen pier","tomb_chest":"Carved chest",
	"floor":"Floor slabs",
	"aqueduct_span":"Aqueduct span","aqueduct_two_tier":"Two-tier span","aqueduct_broken":"Broken span",
	"aqueduct_stump":"Pier stump","aqueduct_end":"Aqueduct head",
	"hall_column":"Colossus column","hall_beam":"Architrave beam","hall_slab":"Roof slabs",
	"hall_bay":"Hall bay"}

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
## the lip a catch allows (GRAB_LOW): 1.875. The third jump of a running
## chain (JUMPS[2] 1.55) catches CHAIN_TOP, 2.625.
const GRAB_TOP := 0.8+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
const CHAIN_TOP := 1.55+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
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
## A plain wall: over GRAB_TOP and under CHAIN_TOP (a running chain catches
## it; broken, its low runs are caught with one jump), thick enough to walk.
const WALL_HEIGHT := 2.4
const WALL_THICK := 1.2
const WALL_LENGTH := 5.2
## The plinth course at a wall's foot: its height (under STEP_UP: stepped
## onto) and how far it stands out.
const PLINTH_COURSE := Vector2(0.4,0.16)
## The least clear width of an opening meant to be flown through: the
## plane's wingspan (SPAN 1.4) and three quarters of it clear either side at
## cruise (SkyGlide CRUISE 6 m/s, SKIM 0.9 over ground).
const THREAD := PlaneFigure.SPAN*2.5
## The pointed arch: clear span, the springing (capital tops) and the
## arc's radius as a share of the span (1 is equilateral). Its crown stands
## SPRING + ARCH_SPAN*0.866, 6.8 m: room for the plane over its SKIM.
const ARCH_SPAN := 4.2
const SPRING := 3.2
const ARCH_PITCH := 1.0
## The arch's moulded orders: each order's radial depth, the inner one set
## back RECESS from the faces, and the hood mould over them.
const ORDER := 0.32
const RECESS := 0.17
const HOOD := Vector2(0.13,0.1)
## The thickness of an arch, a window wall or a gable.
const ARCH_DEPTH := 1.1
## The lancet window: clear width (two lights under one head; with its
## mullion gone, at THREAD and over), sill height (caught from the ground;
## the sill as deep as the wall, STAND and more) and springing; its head
## equilateral.
const WINDOW := Vector3(3.6,1.6,3.4)
const WINDOW_WALL := Vector2(6.8,7.8)
## The rose: its centre's height, outer radius (frame included) and the
## frame's radial depth; the glass circle within is 3.96 m across, wider
## than THREAD with its spokes gone.
const ROSE := Vector3(6.6,2.4,0.42)
## The gable: width, the height of its eaves, its apex.
const GABLE := Vector3(8.4,5.2,10.6)
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


## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
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
	# The other families, loaded when asked for (they build on this script).
	if id in AQUEDUCT_PIECES: return load("res://scripts/ruin_kit_aqueduct.gd").piece(id,seed_value,weathered)
	if id in HALL_PIECES: return load("res://scripts/ruin_kit_hall.gd").piece(id,seed_value,weathered)
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

## The shared materials: {stone}.
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

## 2. A pointed arch on two clustered piers: equilateral, of two moulded
## orders under a hood mould, the spandrels coursed up into a steep gable
## over it; stepped buttresses either side give the way up to the
## springing. Weathered, the gable is torn down to a ragged line, the outer
## order and hood half gone, the crown fallen on one side, rubble below;
## the opening stays clear.
static func arch(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"Arch")
	var h := ARCH_SPAN*0.5
	var d := ARCH_DEPTH*0.5
	var radius := ARCH_SPAN*ARCH_PITCH
	var ring := ORDER*2.0
	var px := h+ring*0.5
	for side: float in [-1.0,1.0]:
		_pier(b,Transform3D(Basis.IDENTITY,Vector3(side*px,0.0,0.0)),SPRING,INF,false)
		# The buttress at its outer side, stepped up to the springing.
		var pose := Transform3D(Basis(Vector3.UP,side*PI*0.5),Vector3(side*(px+0.45),0.0,0.0))
		_buttress(b,pose,[[SET_OFF,2.35],[SPRING,1.25]],BUTTRESS_WIDTH,weathered > 0.5 and b.rng.randf() < 0.5)
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
	# The head's ring outlasts the walling round it, as a window's does.
	_arch_ring(b,Transform3D.IDENTITY,0.0,WINDOW.z,w,radius,d,true,lost,-1.0 if b.rng.randf() < 0.5 else 1.0)
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
		_ring_order(b,Transform3D.IDENTITY,side*(0.12+light),WINDOW.z,light,light*2.0,0.0,0.13,t,4,keep,side,_stone(b,1.06))
	var oculus := Vector3(0.0,WINDOW.z+_rise(light,light*2.0)+0.62,0.5)
	if not broken or b.rng.randf() < 0.3:
		_circle_ring(b,Transform3D.IDENTITY,Vector2(oculus.x,oculus.y),oculus.z,0.12,t,10,0.0 if not broken else 0.6)
	if weathered > 0.0:
		for i in range(int(1+weathered*4.0)):
			b.hang(Vector3(b.rng.randf_range(-w*0.7,w*0.7),0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.6,2.2)*weathered,true)
	_drift(b,Vector3(b.rng.randf_range(-1.5,1.5),0.0,d+1.0),1.6,int(weathered*7.0))
	_rubble(b,half_len+0.8,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	b.root.set_meta("sill",sill.size())
	return b.finish()

## 4. The end gable: coursed walls up to the eaves and a steep gable over
## them with crocketed coping and a finial; a moulded pointed door below; a
## rose window high up: a frame of sixteen stones, an inner ring, a hub and
## twelve spokes; buttresses at the corners, stepped up to the eaves.
## Weathered, the gable's head is torn down, the rose's spokes broken off,
## its hub fallen, its inner ring mostly gone, ivy hanging over it all.
static func rose_gable(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"RoseGable")
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
		b.solid(_axial_prism(8,0.34,0.26),Transform3D(Basis(Vector3.RIGHT,b.rng.randf_range(0.2,0.6)),Vector3(b.rng.randf_range(-1.0,1.0),0.3,d+1.4)),_stone(b,1.05))
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
	var half_width := STAIR_WIDTH*0.5
	var run := (STEPS-1)*TREAD+LANDING
	var front := run*0.5
	for i in range(STEPS):
		var z0 := front-i*TREAD
		var z1 := z0-(LANDING if i == STEPS-1 else TREAD)
		var top := (i+1)*RISER
		var settle := b.rng.randf_range(0.0,0.025)+b.rng.randf_range(0.0,0.05)*weathered
		# Each tread in one or two slabs, the joint wandering.
		var cut := b.rng.randf_range(-0.5,0.5) if b.rng.randf() < 0.6 else 99.0
		var parts: Array = [[-half_width,half_width]] if cut > 50.0 else [[-half_width,cut],[cut,half_width]]
		for p: Array in parts:
			var x0: float = p[0]
			var x1: float = p[1]
			var hh := Vector3((x1-x0)*0.5-0.008,(top-settle)*0.5,(z0-z1)*0.5-0.006)
			var planes := _box(b,hh)
			# The nosing worn back, more at the middle where feet went.
			var n := Vector3(0.0,1.0,1.0).normalized()
			planes.append(Plane(n,(hh.y+hh.z)/sqrt(2.0)-0.03-0.05*b.age))
			var extra: Array[Plane] = []
			if b.rng.randf() < weathered*0.4 and absf(x0) > 0.9 or absf(x1) > 0.9 and b.rng.randf() < weathered*0.4:
				var side := signf(x0+x1)
				var m := Vector3(side,b.rng.randf_range(0.4,0.9),b.rng.randf_range(0.0,0.6)).normalized()
				var keep := Vector3(side*(x1-x0)*0.5*b.rng.randf_range(0.4,0.7),hh.y,hh.z)
				extra.append(Plane(m,m.dot(keep)))
			var tilt := Basis(Vector3.RIGHT,b.rng.randf_range(-0.012,0.012)+b.rng.randf_range(-0.03,0.03)*weathered)*Basis(Vector3.BACK,b.rng.randf_range(-0.01,0.01))
			b.solid(planes,Transform3D(tilt,Vector3((x0+x1)*0.5,hh.y,(z0+z1)*0.5)),_stone(b),true,true,extra)
	# The cheeks: ramped with the flight, level by the landing, in courses
	# cut by the slope, a sloped coping, a newel post at the foot.
	var foot_z := front
	var head_z := front-(STEPS-1)*TREAD
	var slope := Vector3(0.0,TREAD,RISER).normalized()
	var torn := -1.0 if b.rng.randf() < 0.5 else 1.0
	for side: float in [-1.0,1.0]:
		var x0 := side*half_width
		var x1 := side*(half_width+CHEEK.x)
		var lo := minf(x0,x1)
		var hi := maxf(x0,x1)
		var line_at := func(z: float) -> float: return RISER+CHEEK.y+maxf(0.0,(foot_z-z))*RISER/TREAD if z > head_z else STEPS*RISER+CHEEK.y
		var ruin: Callable = func(_z: float) -> float: return INF
		if weathered > 0.25 and side == torn:
			ruin = _ruin_line(b,front-run,front,0.5,STEPS*RISER*0.8,weathered)
		var z := front
		var course := 0.42
		var cy := 0.0
		while cy < STEPS*RISER+CHEEK.y-0.02:
			var y1 := cy+course*b.rng.randf_range(0.85,1.15)
			z = front-(0.0 if int(cy/course)%2 == 0 else 0.35)
			while z > front-run+0.02:
				var z1 := maxf(front-run,z-b.rng.randf_range(0.7,1.2))
				if z1-(front-run) < 0.3: z1 = front-run
				var mid := (z+z1)*0.5
				var stand := minf(line_at.call(mid),ruin.call(mid))
				if cy+0.12 < minf(line_at.call(z),line_at.call(z1)) and cy+0.15 < stand:
					var planes: Array[Plane] = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.DOWN,-cy),Plane(Vector3.UP,y1),Plane(Vector3.BACK,z),Plane(Vector3.FORWARD,-z1)]
					planes.append(Plane(slope,slope.dot(Vector3(0.0,RISER+CHEEK.y-0.11,foot_z))))
					planes.append(Plane(Vector3.UP,STEPS*RISER+CHEEK.y-0.11))
					if stand < y1:
						var m := Vector3(0.0,1.0,b.rng.randf_range(-0.8,0.8)).normalized()
						planes.append(Plane(m,m.dot(Vector3(0.0,stand,mid))))
					b.solid(_bevel(planes,Vector3((lo+hi)*0.5,(cy+y1)*0.5,mid),0.03),Transform3D.IDENTITY,_stone(b,0.97))
				z = z1
			cy = y1
		# The coping: sloped stones along the ramp, then level by the landing.
		var count := 4
		for k in range(count+1):
			var za := foot_z-(foot_z-head_z)*k/count
			var zb := foot_z-(foot_z-head_z)*(k+1)/count if k < count else front-run
			if ruin.call((za+zb)*0.5) < STEPS*RISER: continue
			var ya: float = line_at.call(za)-0.11
			var yb: float = line_at.call(zb)-0.11 if k < count else ya
			var ang := atan2(ya-yb,za-zb)
			var len := Vector2(za-zb,ya-yb).length()
			var pose := Transform3D(Basis(Vector3.RIGHT,-ang),Vector3((lo+hi)*0.5,(ya+yb)*0.5+0.07,(za+zb)*0.5))
			b.solid(_box(b,Vector3(CHEEK.x*0.5+0.04,0.07,len*0.5-0.01)),_jiggle(b,pose,0.8),_stone(b,1.06))
		# The newel at the foot: a square post under a little gabled cap.
		var nx := side*(half_width+CHEEK.x*0.5)
		var post := NEWEL.y-0.18
		b.solid(_box(b,Vector3(NEWEL.x*0.5,post*0.5,NEWEL.x*0.5)),_settle(b,Vector3(nx,post*0.5,foot_z+NEWEL.x*0.3),0.6),_stone(b,1.0))
		if not (weathered > 0.4 and side == torn):
			_gablet(b,Transform3D(Basis.IDENTITY,Vector3(nx,post,foot_z+NEWEL.x*0.3)),NEWEL.x*0.5+0.05,0.42)
	_rubble(b,half_width+1.0,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

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

## 11. A carved chest: a stepped plinth, the chest's sides cut into blind
## arcading (little pointed niches between buttressed posts), a heavy lid
## with its edge chamfered deep. No figure, no lettering: a carved block.
## Weathered, the lid is cracked across and half slid off askew, a corner
## post broken away, moss in the niches.
static func tomb_chest(seed_value: int, weathered := 0.0) -> Node3D:
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
			var y1 := minf(top,cy+b.rng.randf_range(0.42,0.58))
			if top-y1 < 0.2: y1 = top
			# In two blocks, front and back, the joint staggered course by course.
			var split := depth*(0.45 if k%2 == 0 else 0.62)
			for part: Vector2 in [Vector2(-0.05,split),Vector2(split,depth)]:
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
		if yy > cut-0.1: break
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
	_ring_order(b,pose,cx,spring,h,radius,ORDER,ORDER,d,n-1,99,lost_side,_stone(b,1.0),lost+int(b.rng.randf()*2.0*b.weathered),top)
	if hood:
		for s: float in [-1.0,1.0]:
			var hp := pose*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,s*(d+HOOD.y*0.5)))
			_ring_order(b,hp,cx,spring,h,radius,ORDER*2.0,HOOD.x,HOOD.y*0.5,n+2,99,lost_side,_stone(b,1.06),lost+1+int(b.rng.randf()*3.0*b.weathered),top,false,b.weathered*0.5)

## One order of a pointed arch: voussoirs from `radius`+`r0` out `dr`,
## `d` deep (half), `n` a side; the first `keep` of each side (99, all);
## `lost` from the crown on `lost_side` gone; stones over `top` gone;
## `chamfer` its inner arrises moulded; `gaps` odds a stone is missing.
static func _ring_order(b: Build, pose: Transform3D, cx: float, spring: float, h: float, radius: float, r0: float, dr: float, d: float, n: int, keep: int, lost_side: float, tone: Color, lost := 0, top := Callable(), chamfer := false, gaps := 0.0) -> void:
	for side: float in [-1.0,1.0]:
		var centre := Vector3(cx-side*(radius-h),spring,0.0)
		var ri := radius+r0
		var ro := ri+dr
		var apex_in := acos(clampf((radius-h)/ri,-1.0,1.0))
		var apex_out := acos(clampf((radius-h)/ro,-1.0,1.0))
		var apex := (apex_in+apex_out)*0.5
		for i in range(n):
			if i >= keep: break
			if side == lost_side and i >= n-lost: continue
			if side != lost_side and i >= n-maxi(0,lost-1)-int(lost > 0 and b.rng.randf() < 0.5): continue
			if gaps > 0.0 and b.rng.randf() < gaps: continue
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
			if top.is_valid() and float(top.call(mid.x)) < mid.y+0.1: continue
			var loose := 0.4+0.6*float(i)/n
			b.solid(planes,pose*_jiggle(b,Transform3D.IDENTITY,loose*0.18),tone*(1.0+b.rng.randf_range(-0.06,0.06)),true,true,[],-1,0.6)

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
	var sag := SAG.x+(SAG.y-SAG.x)*b.weathered*b.settle
	var y := y0
	var k := 0
	var cap := 0.2 if coping else 0.0
	while y < most-cap-0.06:
		# Courses of uneven height: mostly about `course`, now and then a
		# thin one or a deep one, as old walling is.
		var roll := b.rng.randf()
		var h := course*(b.rng.randf_range(0.5,0.66) if roll < 0.15 else (b.rng.randf_range(1.3,1.55) if roll > 0.86 else b.rng.randf_range(0.8,1.18)))
		if most-cap-(y+h) < course*0.45: h = most-cap-y
		var ya := y
		var yb := y+h
		x = x0-(0.0 if k%2 == 0 else b.rng.randf_range(0.25,0.5))
		while x < x1-0.02:
			var xa := maxf(x,x0)
			var pick := b.rng.randf()
			var xb := minf(x+(b.rng.randf_range(0.35,0.6) if pick < 0.22 else (b.rng.randf_range(1.45,2.0) if pick > 0.8 else b.rng.randf_range(0.7,1.3))),x1)
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
				var half := Vector3((sb-sa)*0.5-0.006,(yb-ya)*0.5-0.006,d+b.rng.randf_range(-0.045,0.02))
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
	if count <= 0: return
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
static func _rubble(b: Build, reach: float, count: int) -> void:
	if b.weathered <= 0.0: return
	count = int(round(count*Build.detail))
	for i in range(count):
		var a := b.rng.randf()*TAU
		var dist := reach+b.rng.randf_range(-0.3,1.0)
		var s := Vector3(b.rng.randf_range(0.1,0.26),b.rng.randf_range(0.07,0.16),b.rng.randf_range(0.1,0.24))
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.3,0.3)),Vector3(cos(a)*dist,s.y*0.8,sin(a)*dist))
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
	for a in range(3):
		var e := (a+1)%3
		for sa: float in [-1.0,1.0]:
			for se: float in [-1.0,1.0]:
				var cc := minf(base*b.rng.randf_range(0.45,1.9),least*0.45)
				var n := Vector3.ZERO
				n[a] = sa
				n[e] = se
				var corner := Vector3.ZERO
				corner[a] = sa*half[a]
				corner[e] = se*half[e]
				n = n.normalized()
				out.append(Plane(n,n.dot(corner)-cc))
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
	## Applied to every block (a piece turned or leaning as a whole).
	var frame := Transform3D.IDENTITY
	## Blocks are cut off level under this height (the piece's frame, y):
	## what is sunk in the ground is not drawn. -INF, none.
	var ground := -INF
	## How far its stones have moved out of true as it weathered, as a share
	## of the abbey's (1): a heavy arcade or a hall's walls settle less, so
	## a ruin of them reads settled, not shaken.
	var settle := 1.0
	static var _materials := {}
	## How much of the small growth and scatter is built (RuinKit
	## `set_detail`): 1 all of it; under 1 fewer ivy strands, moss
	## cushions, tufts and rubble stones; 0 none (a far or cheap ruin).
	static var detail := 1.0

	static func materials() -> Dictionary:
		if _materials.is_empty():
			var s := ShaderMaterial.new()
			s.shader = STONE_SHADER
			s.set_shader_parameter("fill",1.2)
			s.set_shader_parameter("rim",0.14)
			s.set_shader_parameter("roughness_value",0.95)
			_materials = {"stone":s}
		return _materials

	func _init(seed_value: int, amount: float, label: String) -> void:
		rng.seed = hash([seed_value,label,"gothic"])
		weathered = clampf(amount,0.0,1.0)
		age = AGE+(1.0-AGE)*weathered
		stone = STONE.lerp(STONE_COOL,rng.randf())
		noise.seed = seed_value
		noise.frequency = 1.0
		noise.fractal_octaves = 2
		root = Node3D.new()
		root.name = label

	## How thick `points` stand at their thinnest (RuinKit `hull_thickness`).
	static func thickness(points: PackedVector3Array) -> float:
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
		var cut: Array[Plane] = planes.duplicate()
		for p in extra: cut.append(p)
		if wear:
			# The wear's tilted faces never grow a block past where it stood
			# unworn: a sliver whose sides tilt open would run on for metres.
			var worn := _wear(cut,rough,open)
			var base := Geometry3D.compute_convex_mesh_points(cut)
			if base.size() >= 4:
				var box := AABB(base[0],Vector3.ZERO)
				for q in base: box = box.expand(q)
				box = box.grow(maxf(0.15,box.get_longest_axis_size()*0.08))
				for q in Geometry3D.compute_convex_mesh_points(worn):
					if not box.has_point(q):
						worn = cut
						break
			cut = worn
		var xf := frame*pose
		if ground > -INF: cut.append(xf.affine_inverse()*Plane(Vector3.DOWN,-ground))
		var points := _unique(Geometry3D.compute_convex_mesh_points(cut))
		var open_face := PackedVector3Array()
		if points.size() < 4: return open_face
		var linear := colour.srgb_to_linear()
		# The block's faces, and the biggest, so the small ones (worn
		# arrises, chips) can be told.
		var polys: Array = []
		var biggest := 0.0
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
			polys.append([on,plane.normal,mid,area])
		for p: Array in polys:
			var on: Array[Vector3] = p[0]
			var normal := (xf.basis*(p[1] as Vector3)).normalized()
			var mid := xf*(p[2] as Vector3)
			var small := wear and float(p[3]) < biggest*0.16
			var shade := _shade(mid,normal,linear,small) if growable else linear*(1.0+rng.randf_range(-0.06,0.06))
			if not growable: shade.a = 1.0
			for k in range(1,on.size()-1):
				_wound(faces,xf*on[0],xf*on[k],xf*on[k+1],normal,shade)
			if growable and normal.y > 0.8 and float(p[3]) > 0.03:
				var poly := PackedVector3Array()
				for q in on: poly.append(xf*q)
				tops.append([poly,float(p[3])])
		if growable:
			var box := AABB(xf*points[0],Vector3.ZERO)
			for q in points: box = box.expand(xf*q)
			var world: Array[Plane] = []
			for plane in cut: world.append(xf*plane)
			solids.append([box.grow(0.01),world])
		if collide:
			var hull := PackedVector3Array()
			for q in points: hull.append(xf*q)
			# A sliver (a block cut nearly away by a hole's line or a break)
			# stays drawn but gets no hull: Jolt cannot build one so thin.
			if thickness(hull) >= HULL_THIN: hulls.append(hull)
		return open_face

	## The piece: ivy and moss grown on it, then the mesh and the body.
	func finish() -> Node3D:
		frame = Transform3D.IDENTITY
		_ivy()
		_cushions()
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
		var instance := MeshInstance3D.new()
		instance.name = "Mesh"
		instance.mesh = mesh
		root.add_child(instance)
		root.move_child(instance,0)
		var body := StaticBody3D.new()
		body.name = "Body"
		for hull in hulls:
			var shape := ConvexPolygonShape3D.new()
			shape.points = hull
			var holder := CollisionShape3D.new()
			holder.shape = shape
			body.add_child(holder)
		root.add_child(body)
		root.set_meta("weathered",weathered)
		return root

	## The weathering's cuts on one block: every face's wobble (some even as
	## built), corners chipped (a few even as built, more as it weathers),
	## maybe a chunk gone. Plane `keep` keeps its place.
	func _wear(planes: Array[Plane], rough: float, keep: int) -> Array[Plane]:
		var a := clampf(age*rough,0.0,1.0)
		var w := clampf(weathered*rough,0.0,1.0)
		var out: Array[Plane] = []
		var wobble := WOBBLE.x+(WOBBLE.y-WOBBLE.x)*w
		for i in range(planes.size()):
			var p := planes[i]
			if i == keep:
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
		var chips := int(round((CHIPS.x*rough+CHIPS.y*w)*rng.randf_range(0.3,1.0)))
		for c in range(chips):
			var corner := points[rng.randi()%points.size()]
			if keep >= 0 and absf(planes[keep].distance_to(corner)) < 0.01: continue
			var n := ((corner-centre).normalized()+Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(-0.35,0.35),rng.randf_range(-0.35,0.35))).normalized()
			var reach := -INF
			for q in points: reach = maxf(reach,n.dot(q))
			out.append(Plane(n,reach-least*rng.randf_range(CHIP.x,CHIP.y)*(0.35+0.65*a)))
		if rng.randf() < CHUNK_ODDS*w+0.05*minf(rough,1.0):
			var n := Vector3(rng.randf_range(-1,1),rng.randf_range(0.0,1.0),rng.randf_range(-1,1)).normalized()
			var reach := -INF
			var low := INF
			for q in points:
				reach = maxf(reach,n.dot(q))
				low = minf(low,n.dot(q))
			out.append(Plane(n,reach-(reach-low)*rng.randf_range(CHUNK.x,CHUNK.y)))
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
		var count := mini(IVY_MOST,int(area*lerpf(IVY_STRANDS.x,IVY_STRANDS.y,weathered)*detail+rng.randf()*detail))
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
				# A mat over the top it comes from.
				for j in range(rng.randi_range(2,4)):
					var on := mid-out*rng.randf_range(0.0,0.3)+edge.normalized()*rng.randf_range(-0.25,0.25)+Vector3.UP*0.02
					_leaf(on,Vector3.UP,rng.randf_range(IVY_LEAF.x,IVY_LEAF.y),0.0)
				_strand(start,out,minf(mid.y,rng.randf_range(0.4,1.0)*longest),false)
				break
		for hi in range(hangs.size()):
			var h: Array = hangs[hi]
			# Fewer free strands with less detail (by index: the seed's draw is kept).
			if detail < 1.0 and fmod(hi*0.618,1.0) >= detail: continue
			var at: Vector3 = h[0]
			var from: float = h[3]
			if from < 0.0:
				# Look up for the underside to hang from.
				from = -1.0
				var y := 0.5
				while y < 14.0:
					if _inside(Vector3(at.x,y,at.z)):
						from = y-0.04
						break
					y += 0.1
				if from < 0.0: continue
			var length: float = h[1]
			if length < 0.2: continue
			_strand(Vector3(at.x,from,at.z),Vector3(rng.randf_range(-1,1),0.0,rng.randf_range(-1,1)).normalized(),minf(length,from-0.2),true)

	## One strand from `start` down, `out` the way the face looks; `free`:
	## hanging in the air, swaying a little.
	func _strand(start: Vector3, out: Vector3, length: float, free: bool) -> void:
		var along := Vector3(-out.z,0.0,out.x)
		var p := start
		var travelled := 0.0
		var size := rng.randf_range(IVY_LEAF.x,IVY_LEAF.y)*1.15
		var in_air := 0.0
		while travelled < length:
			var taper := 1.0-0.55*smoothstep(length*0.55,length,travelled)
			for j in range(2+int(rng.randf() < 0.5)):
				var off := along*rng.randf_range(-0.16,0.16)+Vector3(0.0,rng.randf_range(-0.05,0.05),0.0)+out*rng.randf_range(0.0,0.05)
				_leaf(p+off,out,size*taper*rng.randf_range(0.75,1.1),0.5)
			var step := rng.randf_range(0.11,0.17)
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
		for k in range(5):
			var a := turn+TAU*k/5.0+rng.randf_range(-0.2,0.2)
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
		count = int(round(count*detail))
		var keep := frame
		frame = Transform3D.IDENTITY
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

	## Moss cushions on mossy tops: low faceted mounds, not solid.
	func _cushions() -> void:
		if detail <= 0.0: return
		var found := tops.duplicate()
		for t: Array in found:
			var poly: PackedVector3Array = t[0]
			var area: float = t[1]
			var odds := (0.08+0.55*weathered)*minf(1.0,area*2.0)*detail
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
				for e in range(6):
					var a := turn+TAU*e/6.0
					planes.append(Plane(Vector3(cos(a),0.0,sin(a)),r))
					var n := Vector3(cos(a+0.5)*0.8,1.0,sin(a+0.5)*0.8).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,r*0.4,0.0))))
				solid(planes,Transform3D(Basis.IDENTITY,at-Vector3(0.0,0.02,0.0)),Color(MOSS_LIGHT).lerp(Color(MOSS),rng.randf()*0.6),false,false,[],-1,1.0,false)

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
