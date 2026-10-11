extends RefCounted
## The aqueduct isle's art (studies/aqueduct_isle.gd): the ruins
## archipelago's station 2 (studies/island_packs/ruins_archipelago.gd)
## dressed in the gothic ruin kit (scripts/ruin_kit.gd, scripts/
## ruin_kit_aqueduct.gd) on two floating islands, with the hill west of it
## on the isle's axis (its tiers, cliffs, walls and winding way, here; the
## stone circle crowning it and the stairs, the kit's), floating stones
## and islets round the isle, and the heel stone east. The ground wears
## the game's terrain look (the sky islets' material and palette).
##
## The station's numbers stand: the channel 2.4 m wide at 6 m, piers 2 m
## thick, arches 4 m wide with 4 m clear, the blind wall 12 m, the 30° rubble
## slope, 16 m of sky crossed on hanging piers, the 3 m fallen span, the
## 1.2 m drops, the buttress 1 x 6 x 5.2 m 2.6 m off the wall. The aqueduct
## is built here from the kit's own parts (its piers, pointed arch rings,
## coursed spandrels, deck slabs, water and spill) at those numbers, since
## the kit's own spans are 6.4 m apart with a deck at 10.8 m; its stone
## draws only, and the station's boxes collide under it (invisible), so the
## routes proven on the greybox hold. What the station never had collides
## as built here: the parapet stones (`parts`, clean boxes), the arches'
## haunches (clean boxes inside the stone), the islands' tops (their own
## faces) and the playground's kit pieces (the kit's hulls).
##
## Everything is in the world's frame (the station's: the aqueduct's middle
## line on x 100, the islands' tops at 30 m). The aqueduct's own frame
## (`AQ`): x along the run from its head (world -z), z across (world x
## less 100), y over the island.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Build = RuinKit.Build
const CHANNEL_SHADER = preload("res://shaders/aqueduct_channel.gdshader")

## The islands' tops, the aqueduct's middle line (world x).
const TOP := 30.0
const MID_X := 100.0
## The aqueduct's frame: its x along world -z from z 0, z along world x
## from MID_X, y up from TOP.
const AQ := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(MID_X,TOP,0.0))
const WEATHERED := 0.6
## The arcade (aqueduct frame): each pier's middle and foot (0 on the
## island, under it where it hangs), the arches' middles (34, the fallen
## span), the walled-up arches' in the blind wall.
const PIERS := [[19.0,0.0],[25.0,-9.0],[31.0,-11.0],[37.0,-10.0],[43.0,0.0]]
const ARCHES := [16.0,22.0,28.0,40.0]
const BLIND := [4.0,10.0]
const BLIND_PIERS := [7.0,13.0]
const PIER := Vector2(2.0,2.4)
## The arches: half the clear span, the arc's radius as a share of the
## clear span (under 1: a drop arch, so the crown stands at 4 m with the
## springing over a walker's head), the crown's height.
const HALF := 2.0
const PITCH := 0.75
const CROWN := 4.0
## The deck's top (the channel's floor, walked), its floor slabs' depth,
## the walls' half depth under it.
const DECK := 6.0
const SLAB := 0.4
const FACE := 1.2
## The head (the blind wall's south end, where the rubble slope tops out),
## the channel's snapped end and where it starts again past the fallen
## span, the end of its last span.
const HEAD := 2.0
const SNAP := 32.5
const RESUME := 35.5
const END := 44.0
## The water in the channel: over the deck by WATER_LIFT (a film the feet
## splash through, under the wade's slowing), its half width.
const WATER_LIFT := 0.06
const WATER_HALF := 0.7
## The parapets: their middle off the channel's middle, half thickness,
## height; the stretch of the east side kept clear (aqueduct x), where the
## kicks up from the buttress catch the channel's lip.
const PARAPET_Z := 0.95
const PARAPET := Vector2(0.2,0.42)
const EAST_CLEAR := Vector2(-1.0,16.0)

static func spring() -> float:
	return CROWN-RuinKit._rise(HALF,HALF*2.0*PITCH)

## The water the pilot wades in the channel (PilotPhysicsGround `pools`):
## world rect and top.
static func pools() -> Array:
	return [{"rect":Rect2(MID_X-WATER_HALF,-SNAP+0.1,WATER_HALF*2.0,SNAP-HEAD-0.6),"top":TOP+DECK+WATER_LIFT}]

# --- The aqueduct -----------------------------------------------------------------

## The aqueduct's stone, water and spill (drawn only), and its clean
## collision for what the station lacks: {node, parts}.
static func aqueduct(seed_value: int) -> Dictionary:
	var b := Build.new(seed_value,WEATHERED,"Aqueduct")
	b.settle = Aqueduct.SETTLE
	var parts: Array = []
	var sp := spring()
	var radius := HALF*2.0*PITCH
	var d := FACE-0.1
	var wall_top := DECK-SLAB
	# The piers: on the island, or hanging over the sky, their feet broken.
	for p: Array in PIERS:
		var x: float = p[0]
		var foot: float = p[1]
		Aqueduct._pier(b,x,foot,sp,wall_top,PIER,0.0,INF,foot >= 0.0)
		if foot < 0.0: _broken_foot(b,x,foot)
	# The arches and the spandrels over them; the fallen span's springers.
	for cx: float in ARCHES:
		_span(b,cx,sp,radius,d,wall_top,Callable())
	_fallen_span(b,sp,radius,d,wall_top)
	# The blind wall: two arches walled up, their rings set flush in it.
	_blind_wall(b,sp,radius)
	# The deck: whole to the snap, again past the fallen span to the end.
	Aqueduct._deck(b,HEAD,SNAP,DECK,Callable(),true,FACE+0.05)
	Aqueduct._deck(b,RESUME,END,DECK,Callable(),false,FACE+0.05)
	_parapets(b,parts)
	# The water: from the head to the snap, then the spill down into the sky.
	# The edit chunks' water is laid in the world's frame (`channel_water`);
	# --old-water keeps the channel's own running film.
	var water: Node3D = null
	if KitWater.old_water():
		var film := Aqueduct._water(b.root,HEAD+0.5,SNAP-0.15,DECK+WATER_LIFT,WATER_HALF)
		var running := ShaderMaterial.new()
		running.shader = CHANNEL_SHADER
		running.set_shader_parameter("middle",Vector3(MID_X,TOP+DECK,0.0))
		running.set_shader_parameter("half_width",WATER_HALF)
		film.material_override = running
	else: water = channel_water()
	Aqueduct._spill(b.root,Vector3(SNAP-0.12,DECK+WATER_LIFT-0.02,0.0),Vector3.RIGHT,seed_value,-70.0)
	# The rubble slope at the head and the drops at the far end.
	_rubble_slope(b)
	_drops(b)
	# The arches' haunches: clean boxes inside the stone (the station has
	# only its spandrels from 4 m), so a walker under an arch keeps clear of
	# the ring where it comes down to the piers.
	for cx: float in ARCHES:
		for s: float in [-1.0,1.0]:
			for step: Array in [[0.0,0.3],[0.3,0.7],[0.7,1.2]]:
				var x0: float = cx+s*(HALF-float(step[0]))
				var x1: float = cx+s*(HALF-float(step[1]))
				var u := float(step[1])
				var low := sp+sqrt(maxf(0.0,2.0*radius*u-u*u))-0.15
				_part_box(parts,minf(x0,x1),maxf(x0,x1),-FACE,FACE,maxf(low,sp),CROWN)
	# Ivy hanging from the deck's underside and the arches.
	for i in range(18):
		var x := b.rng.randf_range(15.0,42.0)
		if x > SNAP-0.5 and x < RESUME+0.5: continue
		b.hang(Vector3(x,0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.6),true)
	var node := b.finish()
	node.get_node("Body").free()
	node.transform = AQ
	return {"node":node,"parts":parts,"water":water}

## The channel's water (scripts/kit_isle/kit_water.gd), in the world's
## frame (the chop reads world axes): the edit chunks' water a hand deep
## over the channel's floor, from the head to the snap, its edges at the
## parapets' inner faces, tipping over the snap into the spill. So thin a
## film would be clear glass by the live water's shallows (shallow_clear),
## its stone barely darkened: the plate's teal tint stays all the way up
## (CLEAR 0), so it reads as clear teal water over the stone, deeper where
## a settled slab lies lower. The plate's running water over it read as a
## pale teal slab (docs/scenic/kit-isle-water.md), so only the wind's chop
## moves on it.
const CLEAR := 0.0
static func channel_water() -> MeshInstance3D:
	var inner := PARAPET_Z-PARAPET.x
	var snap := SNAP-0.12
	return KitWater.still({"name":"Channel","level":TOP+DECK+WATER_LIFT,
		"ground":func(_x: float, _z: float) -> float: return TOP+DECK,
		"rect":Rect2(MID_X-inner-0.5,-snap-0.5,(inner+0.5)*2.0,snap-HEAD+0.5),
		"inside":func(p: Vector2) -> bool: return absf(p.x-MID_X) < inner and p.y > -snap and p.y < -(HEAD+0.5),
		"clear":CLEAR})

## A span: the pointed arch at `cx` (aqueduct x), its spandrels coursed up
## from the springing to the deck's foot.
static func _span(b: Build, cx: float, sp: float, radius: float, d: float, wall_top: float, stands: Callable) -> void:
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	RuinKit._arch_ring(b,pose,0.0,sp,HALF,radius,d,true,0,1.0,stands)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < sp: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(HALF,radius,outer-radius,y-sp))
	var top := func(_x: float) -> float: return wall_top
	RuinKit._courses(b,pose,-3.0,3.0,sp,top,d-0.04,hole,0.55)

## The fallen span between the piers at 31 and 37: the arch's springers
## standing on either pier, a ragged stub of spandrel and deck over each
## (the station's 0.5 m stubs: 32 to 32.5, 35.5 to 36), between them the
## gap down to the sky.
static func _fallen_span(b: Build, sp: float, radius: float, d: float, wall_top: float) -> void:
	var cx := 34.0
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	var stands := func(x: float) -> float: return 99.0 if absf(x) > 1.15 else -99.0
	RuinKit._arch_ring(b,pose,0.0,sp,HALF,radius,d,true,0,1.0,stands)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < sp: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(HALF,radius,outer-radius,y-sp))
	# The walling over each pier stands to the stub's end, then breaks off
	# down and away in a ragged line.
	var ragged := RuinKit._ruin_line(b,-3.0,3.0,0.0,1.0,1.0)
	var top := func(x: float) -> float:
		var reach := absf(x)
		if reach >= 1.5: return wall_top
		return wall_top-(1.5-reach)*3.2+(float(ragged.call(x))-0.5)*0.6
	RuinKit._courses(b,pose,-3.0,3.0,sp,top,d-0.04,hole,0.55)
	# A few voussoirs and a length of channel caught on the broken pier
	# heads below the gap, and fallen stones hung up on the springers.
	for i in range(3):
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,b.rng.randf_range(-0.5,0.5))
		var s := Vector3(b.rng.randf_range(0.25,0.4),b.rng.randf_range(0.2,0.3),b.rng.randf_range(0.4,0.7))
		var side := -1.0 if i%2 == 0 else 1.0
		b.solid(RuinKit._box(b,s),Transform3D(tumble,Vector3(cx+side*b.rng.randf_range(1.6,1.9),sp+b.rng.randf_range(0.4,1.2),b.rng.randf_range(-0.6,0.6))),RuinKit._stone(b,0.98))

## The blind wall from the head (x 2) to the first open arch (x 14): the
## arches walled up, their rings flush with the wall's faces (its east face
## the wall run's), the infill in smaller, paler courses set back a little,
## the old piers' strips between them; coursed solid to the deck's foot.
static func _blind_wall(b: Build, sp: float, radius: float) -> void:
	var wall_top := DECK-SLAB
	for cx: float in BLIND:
		var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
		RuinKit._arch_ring(b,pose,0.0,sp,HALF,radius,FACE,true)
		var outer := radius+RuinKit.ORDER*2.0+0.04
		var hole := func(y: float) -> Vector2:
			if y < sp: return Vector2(0.0,-1.0)
			return Vector2(0.0,RuinKit._arc_half(HALF,radius,outer-radius,y-sp))
		var top := func(_x: float) -> float: return wall_top
		RuinKit._courses(b,pose,-3.0,3.0,sp,top,FACE-0.02,hole,0.55)
		# The infill: under the ring, smaller stones, set back 6 cm.
		var inside := func(x: float) -> float:
			if absf(x) >= HALF: return -1.0
			return sp+sqrt(maxf(0.0,radius*radius-(radius-HALF+absf(x))*(radius-HALF+absf(x))))-0.02
		var keep := b.stone
		b.stone = b.stone*1.08
		RuinKit._courses(b,pose,-HALF+0.02,HALF-0.02,0.0,inside,FACE-0.06,Callable(),0.36)
		b.stone = keep
	for x: float in BLIND_PIERS:
		Aqueduct._pier(b,x,0.0,sp,wall_top,Vector2(2.0,FACE*2.0),0.0)
	# The piers' height under the springing between the infills at the
	# walled arches' feet (x 2 and the old pier at 13 joins the first
	# open arch's span).
	Aqueduct._pier(b,HEAD+0.6,0.0,sp,wall_top,Vector2(1.2,FACE*2.0),0.0)

## A hanging pier's foot at `foot`: the last courses broken off ragged and
## a few stones still hanging under it, ivy and roots trailing down.
static func _broken_foot(b: Build, x: float, foot: float) -> void:
	for i in range(4):
		var s := Vector3(b.rng.randf_range(0.3,0.75),b.rng.randf_range(0.3,0.8),b.rng.randf_range(0.35,0.9))
		var at := Vector3(x+b.rng.randf_range(-0.6,0.6),foot-s.y*b.rng.randf_range(0.4,1.1),b.rng.randf_range(-0.7,0.7))
		var cut: Array[Plane] = []
		var m := Vector3(b.rng.randf_range(-0.8,0.8),-1.0,b.rng.randf_range(-0.8,0.8)).normalized()
		cut.append(Plane(m,b.rng.randf_range(0.0,0.2)))
		b.solid(RuinKit._box(b,s),Transform3D(Basis(Vector3(b.rng.randf(),0.0,b.rng.randf()).normalized(),b.rng.randf_range(0.0,0.2)),at),RuinKit._stone(b,0.92),true,true,cut)
	for i in range(3):
		b.hang(Vector3(x+b.rng.randf_range(-0.8,0.8),foot,b.rng.randf_range(-1.0,1.0)),b.rng.randf_range(1.5,4.0),true,foot)

## The parapets along the channel: stones 0.42 m high, gone in runs, never
## on the east side where the kicks catch the lip, nor over the gap; each
## stone collides as a clean box (`parts`).
static func _parapets(b: Build, parts: Array) -> void:
	for s: float in [-1.0,1.0]:
		for run: Vector2 in [Vector2(HEAD+0.4,SNAP-0.4),Vector2(RESUME+0.5,END)]:
			var x := run.x
			var gone := 0
			while x < run.y-0.3:
				var xb := minf(x+b.rng.randf_range(0.7,1.2),run.y)
				var mid := (x+xb)*0.5
				if gone > 0: gone -= 1
				elif b.rng.randf() < 0.22: gone = b.rng.randi_range(1,4)
				var clear := s > 0.0 and mid > EAST_CLEAR.x and mid < EAST_CLEAR.y
				if gone == 0 and not clear:
					var half := Vector3((xb-x)*0.5-0.01,PARAPET.y*0.5,PARAPET.x)
					var planes := RuinKit._box(b,half)
					for k: float in [-1.0,1.0]:
						var n := Vector3(0.0,1.0,k*1.1).normalized()
						planes.append(Plane(n,n.dot(Vector3(0.0,half.y,k*(half.z-0.08)))))
					var pose := Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.03,0.03)),Vector3(mid,DECK+half.y,s*PARAPET_Z))
					b.solid(planes,pose,RuinKit._stone(b,1.06))
					_part_box(parts,x+0.02,xb-0.02,s*PARAPET_Z-PARAPET.x,s*PARAPET_Z+PARAPET.x,DECK,DECK+PARAPET.y)
				x = xb

## The rubble slope up onto the head: the station's 30° ramp (aqueduct x
## -8.4 to 2, 2.4 m wide) laid as the fallen end's channel floor and
## walling, broken into stones tilted up the slope, their tops in its plane
## (a stone a hair under, none over), the heap of fallen courses under them.
static func _rubble_slope(b: Build) -> void:
	var low := -8.4
	var high := HEAD
	var angle := atan2(DECK,high-low)
	var along := Vector3(cos(angle),sin(angle),0.0)
	var length := (high-low)/cos(angle)
	var t := 0.0
	while t < length-0.1:
		var step := minf(b.rng.randf_range(0.75,1.3),length-t)
		if length-(t+step) < 0.4: step = length-t
		var split := b.rng.randf_range(-0.5,0.5) if b.rng.randf() < 0.7 else 99.0
		var pieces: Array = [[-FACE,FACE]] if split > 50.0 else [[-FACE,split],[split,FACE]]
		for p: Array in pieces:
			var z0: float = p[0]
			var z1: float = p[1]
			var sink := b.rng.randf_range(0.0,0.04)
			var half := Vector3(step*0.5-0.02,0.2,(z1-z0)*0.5-0.015)
			var basis := Basis(Vector3.BACK,angle)*Basis(Vector3.UP,b.rng.randf_range(-0.04,0.04))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.03,0.03))
			var top_mid := Vector3(low,0.0,(z0+z1)*0.5)+along*(t+step*0.5)
			var centre := top_mid-basis*Vector3(0.0,half.y+sink,0.0)
			b.solid(RuinKit._box(b,half),Transform3D(basis,centre),RuinKit._stone(b,b.rng.randf_range(0.9,1.12)),true,true,[],-1,1.6)
		t += step
	# The heap under the stones: courses of fallen walling stepping down.
	var heap := func(px: float) -> float: return clampf((px-low)*tan(angle)-0.45,0.2,DECK-0.6)
	RuinKit._courses(b,Transform3D.IDENTITY,low+0.8,high,0.0,heap,FACE-0.12,Callable(),0.5)

## The rubble heaped beside the slope on its west side, down toward the
## castellum: loose blocks under the slope's line, each colliding as built
## (a scramble up beside the slope); a stone or two low on its east side,
## clear of the run along the blind wall. Its own piece, its hulls kept.
static func rubble_heap(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.6,"RubbleHeap")
	b.frame = AQ
	var low := -8.4
	var angle := atan2(DECK,HEAD-low)
	var x := low+1.0
	while x < HEAD-0.3:
		var line := (x-low)*tan(angle)
		var s := Vector3(b.rng.randf_range(0.3,0.5),b.rng.randf_range(0.2,0.42),b.rng.randf_range(0.25,0.45))
		var y := minf(line-0.35,1.4)-s.y
		if y > -s.y*0.5:
			var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.2,0.2)),Vector3(x,maxf(y,0.0)+s.y*0.9,-FACE-s.z-b.rng.randf_range(0.05,0.5)))
			b.solid(RuinKit._box(b,s),pose,RuinKit._stone(b,0.96),true,true,[],-1,2.0)
		x += b.rng.randf_range(0.5,0.9)
	for i in range(3):
		var s := Vector3(b.rng.randf_range(0.2,0.32),b.rng.randf_range(0.1,0.16),b.rng.randf_range(0.2,0.3))
		var at := Vector3(b.rng.randf_range(-7.8,-6.0),s.y*0.7,FACE+b.rng.randf_range(0.2,0.5))
		b.solid(RuinKit._box(b,s),Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU),at),RuinKit._stone(b,0.95),false,true,[],-1,2.0)
	return b.finish()

## The far end's rubble: its last span's walling broken down in the
## station's 1.2 m drops (aqueduct x 44 to 53.6), each a level top.
static func _drops(b: Build) -> void:
	var tops := [4.8,3.6,2.4,1.2]
	for i in range(4):
		var x0 := END+2.4*i
		var x1 := x0+2.4
		var high: float = tops[i]
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,Transform3D.IDENTITY,x0,x1,0.0,line,FACE-0.02,Callable(),0.5,true)
	RuinKit._drift(b,Vector3(END+10.6,0.0,0.6),1.4,6)

## The buttress east of the blind wall: 1 by 6 by 5.2 m, 2.6 m off the
## wall's east face (world x 103.8 to 104.8, z -12 to -6), coursed, under a
## coping; drawn only (the station's box collides).
static func buttress(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.45,"Buttress")
	var top := func(_x: float) -> float: return 5.2
	var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(104.3,TOP,-9.0))
	RuinKit._plinth_course(b,pose,3.0,0.5)
	RuinKit._courses(b,pose,-3.0,3.0,RuinKit.PLINTH_COURSE.x,top,0.5,Callable(),0.5,true)
	var node := b.finish()
	node.get_node("Body").free()
	return node

static func _part_box(parts: Array, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	# Aqueduct frame to the world's: x along -z, z along x.
	var a := AQ*Vector3(x0,y0,z0)
	var c := AQ*Vector3(x1,y1,z1)
	var rect := Rect2(minf(a.x,c.x),minf(a.z,c.z),absf(c.x-a.x),absf(c.z-a.z))
	parts.append(["box",rect,minf(a.y,c.y),maxf(a.y,c.y),"lip"])

# --- The castellum: the summit --------------------------------------------------------

## The castellum at the aqueduct's head (world): the water tower, 4 m
## square, its crown 7.8 m up, its south-east quarter fallen in SET_OFF
## steps (each 1.6 m, a jump caught): rubble 1.4 m at its foot, then 3.0,
## 4.6, 6.2 and the crown at 7.8. Its east face 1.8 m off the aqueduct's
## west face: a running jump either way between the channel and its 6.2 m
## step. Each block collides as a clean box (`parts`), the stone over
## it drawn only.
const CASTELLUM := [
	[Rect2(93.0,-3.0,2.0,4.0),7.8],
	[Rect2(95.0,-3.0,2.0,2.0),6.2],
	[Rect2(95.0,-1.0,2.0,2.0),4.6],
	[Rect2(95.0,1.0,2.0,2.0),3.0],
	[Rect2(95.3,3.0,1.7,1.6),1.4],
]

static func castellum(seed_value: int) -> Dictionary:
	var b := Build.new(seed_value,0.5,"Castellum")
	var parts: Array = []
	for block: Array in CASTELLUM:
		var r: Rect2 = block[0]
		var high: float = block[1]
		parts.append(["box",r,TOP,TOP+high,"lip"])
		var long_x := r.size.x >= r.size.y
		var length := r.size.x if long_x else r.size.y
		var depth := r.size.y if long_x else r.size.x
		var pose := Transform3D(Basis.IDENTITY if long_x else Basis(Vector3.UP,PI*0.5),Vector3(r.get_center().x,TOP,r.get_center().y))
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,pose,-length*0.5,length*0.5,0.0,line,depth*0.5-0.01,Callable(),0.55,high > 2.0)
	# The crown's broken parapet on its west and north edges (drawn and
	# collided: knee high, stepped over), a slit window or two.
	for edge: Array in [[Vector3(93.2,0.0,-1.0),PI*0.5,3.6],[Vector3(94.0,0.0,-2.8),0.0,1.8]]:
		var at: Vector3 = edge[0]
		var pose := Transform3D(Basis(Vector3.UP,float(edge[1])),Vector3(at.x,TOP+7.8,at.z))
		var len: float = edge[2]
		var ragged := RuinKit._ruin_line(b,-len*0.5,len*0.5,0.0,0.42,0.8)
		RuinKit._courses(b,pose,-len*0.5,len*0.5,0.0,ragged,0.18,Callable(),0.25)
		var turned := float(edge[1]) != 0.0
		var r := Rect2(at.x-0.2,at.z-len*0.5,0.4,len) if turned else Rect2(at.x-len*0.5,at.z-0.2,len,0.4)
		parts.append(["box",r,TOP+7.8,TOP+7.8+0.3,"lip"])
	RuinKit._drift(b,Vector3(97.4,TOP,4.6),0.9,4)
	var node := b.finish()
	node.get_node("Body").free()
	return {"node":node,"parts":parts}
## The heel stone: a lone sarsen out on the axis east of the aqueduct,
## leaning away from the henge, a drift of turf and tufts at its foot;
## colliding as built.
static func heel_stone(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.5,"HeelStone")
	b.ground = 0.0
	var lean := Basis(Vector3.BACK,-0.07)
	RuinKit._sarsen(b,Transform3D(lean,Vector3.ZERO),HEEL_SIZE,0.14)
	for i in range(6): _tuft(b,Vector3(b.rng.randf_range(-1.4,1.4),0.0,b.rng.randf_range(-1.1,1.1)),0.4,5)
	var node := b.finish()
	node.position = Vector3(HEEL.x,TOP,HEEL.y)
	return node

# --- The hill: its tiers, the way winding up, the crag the circle crowns -----------------

## The near island's west lobe rises round HILL (world x, z) in tiers, each
## edged by a cliff of the ground's own rock (or a retaining wall): the
## meadow at TOP; the lower tier T1 (the grand stair's head, 4.48 m) round
## the east, south and north; the upper tier T2 a ledge BAND2 wide round
## the north, west and south under the summit, and the west shelf; the
## summit, the crag the stone circle crowns, a plane tilted down to the
## east (toward the aqueduct) by SLANT (the circle tilted with it), its south-east edge bitten
## away (BITE) where the ring's sarsen MISSING went with the ground.
##
## Angles (`polar`, degrees) run from east (+x) toward north (-z). The way
## up winds round it once, counterclockwise from above: the grand stair
## (east, meadow to T1), round T1 north, the ramp cut along T2's cliff
## (RAMP_FROM to RAMP_TO, T1 to T2, behind a retaining wall), the west
## shelf, the ledge south, and the kit's stair (KIT_STAIRS_AT, up into a
## notch in the crag) onto the summit through the ring's gap.
const HILL := Vector2(61.0,0.0)
const T1 := 2.0*RuinKit.STEPS*RuinKit.RISER
const RAMP_RISE := 4.2
const T2 := T1+RAMP_RISE
const BAND2 := 3.3
const BAND1 := 4.3
## The lower tier's east face (world x): a straight retaining wall either
## side of the grand stair, buttressed (BUTTRESS_STAGES: set-offs a way up).
const EAST_FACE := 77.55
const BUTTRESS_STAGES := [[RuinKit.SET_OFF,2.0],[RuinKit.SET_OFF*2.0,1.2]]
const SLANT := 0.0524
const RAMP_FROM := 100.0
const RAMP_TO := 160.0
const SHELF_TO := 215.0
const BAND_TO := 280.0
## The bite: its middle (degrees), half its width (degrees), how far in it
## reaches (m from HILL).
const BITE := Vector3(296.0,16.0,7.8)
## The kit stair up the crag: its way (degrees, the gap between the ring's
## sarsens 9 and 10), its run.
const KIT_STAIRS_AT := 257.14
const KIT_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
## The ledge widened before the kit stair's foot (m at its middle, half
## its width in degrees): room to come round and turn up it.
const APRON := 2.6
const APRON_HALF := 10.0
## The ring's sarsen broken away over the bite (it floats there, at the
## lintels' height, a stepping stone round the ring).
const MISSING := 11
## The grand stair on the axis (its middle, world), climbing west, its back
## at x 77.5 on the lower tier's face (its run 12.24 m).
const STAIR_AT := Vector3(83.62,TOP,0.0)
## The heel stone: a lone sarsen out east on the axis, leaning (its top a
## pump's catch).
const HEEL := Vector2(118.0,0.0)
const HEEL_SIZE := Vector3(1.7,2.3,1.1)

## Distance and angle (degrees, east toward north) of world (x, z) from HILL.
static func polar(x: float, z: float) -> Vector2:
	var d := Vector2(x-HILL.x,z-HILL.y)
	return Vector2(d.length(),fposmod(rad_to_deg(atan2(-d.y,d.x)),360.0))

## The world (x, z) at angle `t` (degrees), `r` from HILL.
static func at_polar(t: float, r: float) -> Vector2:
	var a := deg_to_rad(t)
	return HILL+Vector2(cos(a),-sin(a))*r

## The summit's edge, unbitten (m from HILL): a crag's wandering line.
static func summit_r(t: float) -> float:
	var a := deg_to_rad(t)
	return 12.4+0.9*sin(2.0*a+1.3)+0.55*sin(3.0*a+0.6)+0.35*sin(7.0*a+2.0)

## The upper tier's ledge and the lower tier's width at angle `t` (m): never
## one width all round, so the tiers wander, not stack as rings.
static func band2(t: float) -> float:
	var a := deg_to_rad(t)
	return BAND2+0.6*sin(4.0*a+0.3)

static func band1(t: float) -> float:
	var a := deg_to_rad(t)
	return BAND1+1.6*sin(2.0*a+2.2)+0.7*sin(5.0*a)

## The summit's edge with the bite taken out of it.
static func edge_r(t: float) -> float:
	var r := summit_r(t)
	var off := absf(t-BITE.x)
	if off < BITE.y: r -= (r-BITE.z)*(0.5+0.5*cos(PI*off/BITE.y))
	return r

## The upper tier's outer edge, and the lower tier's (the east face's line
## where it is nearer).
static func r2(t: float) -> float:
	var off := absf(t-KIT_STAIRS_AT)
	var apron := APRON*(0.5+0.5*cos(PI*off/APRON_HALF)) if off < APRON_HALF else 0.0
	return summit_r(t)+band2(t)+apron

static func r1(t: float) -> float:
	var r := minf(summit_r(t)+band2(t)+band1(t),21.0)
	var c := cos(deg_to_rad(t))
	if c > 0.05: r = minf(r,(EAST_FACE-HILL.x)/c)
	return r

## The kit stair's frame (world): its foot on the upper tier's ledge, its
## back (-Z) in the crag at the summit's height.
static func stairs_frame() -> Transform3D:
	var a := deg_to_rad(KIT_STAIRS_AT)
	var u := Vector3(cos(a),0.0,-sin(a))
	var foot := summit_r(KIT_STAIRS_AT)+band2(KIT_STAIRS_AT)-0.6
	return Transform3D(Basis(Vector3.UP.cross(u),Vector3.UP,u),Vector3(HILL.x,TOP+T2,HILL.y)+u*(foot-KIT_RUN*0.5))

static var _summit0 := NAN
static var _notch := Transform3D()

## The summit's plane over HILL (world y): the kit stair's head meets it.
static func summit_y0() -> float:
	if is_nan(_summit0):
		var f := stairs_frame()
		_notch = f.affine_inverse()
		var back := f*Vector3(0.0,0.0,-KIT_RUN*0.5)
		_summit0 = TOP+T2+RuinKit.STEPS*RuinKit.RISER+SLANT*(back.x-HILL.x)
	return _summit0

## The summit's height at world (x, z).
static func summit(x: float, z: float) -> float:
	return summit_y0()-SLANT*(x-HILL.x)

## The circle's place: on the summit over HILL, facing east, tilted with it.
static func circle_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK,-atan(SLANT))*Basis(Vector3.UP,PI*0.5),Vector3(HILL.x,summit_y0(),HILL.y))

## True in the notch cut in the crag for the kit stair (and its cheeks).
static func in_notch(x: float, z: float) -> bool:
	summit_y0()
	var l := _notch*Vector3(x,TOP+T2,z)
	return absf(l.x) < RuinKit.STAIR_WIDTH*0.5+RuinKit.CHEEK.x+0.03 and l.z > -KIT_RUN*0.5+0.02 and l.z < KIT_RUN*0.5+0.6

## The ground underfoot at world (x, z): the hill's tiers, ramp and summit
## on the west lobe, the island's turf (`base`) elsewhere.
static func ground(x: float, z: float) -> float:
	var p := polar(x,z)
	var r := p.x
	var t := p.y
	if r > 23.0: return base(x,z)
	if r < edge_r(t):
		if in_notch(x,z): return TOP+T2
		return summit(x,z)
	if r < r2(t) and t >= RAMP_FROM and t <= BAND_TO: return TOP+T2
	if r < r1(t):
		if t >= RAMP_FROM and t < RAMP_TO: return TOP+ramp(t)
		if t >= RAMP_TO and t <= SHELF_TO: return TOP+T2
		return TOP+T1
	return base(x,z)

## The ramp's height over TOP at angle `t`.
static func ramp(t: float) -> float:
	return T1+RAMP_RISE*clampf((t-RAMP_FROM)/(RAMP_TO-RAMP_FROM),0.0,1.0)

## The island's turf at (x, z) (world): TOP, rising on the rises, flat near
## the aqueduct.
static func base(x: float, z: float) -> float:
	var y := TOP
	var keep := clampf((absf(x-MID_X)-FLAT_HALF)/4.0,0.0,1.0)
	for r: Vector3 in RISES:
		var t := clampf(1.0-Vector2(x-r.x,z-r.y).length()/r.z,0.0,1.0)
		y += 1.6*t*t*(3.0-2.0*t)*keep
	return y

## Where a cliff stands against a retaining wall (its face kept inside the
## wall's thickness).
static func _walled(e: Vector2) -> bool:
	if absf(e.x-EAST_FACE) < 0.3 and absf(e.y) < 12.0: return true
	var p := polar(e.x,e.y)
	return p.y >= RAMP_FROM-1.0 and p.y <= RAMP_TO-3.0 and absf(p.x-r2(p.y)) < 0.3

## The way up the hill on foot, no jump (world x, z): the grand stair from
## its foot, round the lower tier north, up the ramp, over the west shelf,
## along the ledge south, up the kit stair through the ring's gap.
static func way_up() -> Array:
	var way: Array = [Vector2(91.0,0.0),Vector2(76.0,0.0)]
	var t := 10.0
	while t <= 95.0:
		way.append(at_polar(t,(summit_r(t)+r1(t))*0.5))
		t += 10.0
	t = 100.0
	while t <= 195.0:
		way.append(at_polar(t,(r2(t)+r1(t))*0.5))
		t += 6.0
	t = 202.0
	while t < KIT_STAIRS_AT-8.0:
		way.append(at_polar(t,(summit_r(t)+r2(t))*0.5))
		t += 6.0
	var f := stairs_frame()
	for l: float in [KIT_RUN*0.5+1.6,KIT_RUN*0.5-RuinKit.TREAD,-KIT_RUN*0.5-0.8]:
		var at := f*Vector3(0.0,0.0,l)
		way.append(Vector2(at.x,at.z))
	return way

## The paths worn in the turf (world polylines): the stair's foot round the
## castellum to the slope's foot, on to the heel stone; the north edge to
## the stumps; the way up the hill.
const PATHS := [
	[Vector2(90.8,0.0),Vector2(91.4,5.5),Vector2(96.0,8.6),Vector2(100.0,10.0),Vector2(106.0,6.5),Vector2(112.0,2.0),Vector2(117.0,0.4)],
	[Vector2(72.0,-22.0),Vector2(80.0,-21.5),Vector2(87.0,-21.0),Vector2(92.0,-22.0)],
]
static var _paths: Array = []

## How worn the ground is at `at` (0 off the paths, 1 on their middle).
static func path_wear(at: Vector2) -> float:
	if _paths.is_empty():
		_paths = PATHS.duplicate()
		var hill: Array = way_up().slice(1)
		hill.pop_back()
		_paths.append(hill)
	var best := INF
	for path: Array in _paths:
		for i in range(path.size()-1):
			best = minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,path[i],path[i+1])))
	return clampf(1.25-best/1.5,0.0,1.0)

## The world's ground look: the kit isles' (scripts/kit_isle/kit_look.gd,
## the plate's ground material and palette).
static func palette() -> Dictionary:
	return KitLook.palette()

static func ground_material() -> ShaderMaterial:
	return KitLook.ground_material()

# --- The islands --------------------------------------------------------------------

## The islands' outlines (world x, z), each round its own middle: the big
## one under the head and the arcade, its west lobe round the hill; the far
## one where the aqueduct comes down. The 16 m of sky between them kept
## open under the aqueduct.
const NEAR := [Vector2(100.0,-24.4),Vector2(104.0,-24.2),Vector2(109.0,-25.4),Vector2(114.0,-23.2),Vector2(119.0,-24.6),
	Vector2(124.0,-20.0),Vector2(127.0,-13.0),Vector2(126.0,-5.0),Vector2(128.0,2.0),Vector2(124.0,9.0),Vector2(119.0,14.0),
	Vector2(112.0,16.0),Vector2(106.0,15.5),Vector2(100.0,17.5),Vector2(93.0,16.0),Vector2(86.0,18.0),
	Vector2(80.0,19.5),Vector2(73.0,22.8),Vector2(66.0,24.3),Vector2(59.0,24.6),Vector2(52.0,22.8),Vector2(45.5,18.6),
	Vector2(40.5,12.5),Vector2(37.6,5.5),Vector2(37.0,-2.0),Vector2(38.6,-9.5),Vector2(42.0,-16.0),Vector2(47.5,-21.5),
	Vector2(54.0,-25.0),Vector2(61.0,-26.5),Vector2(68.0,-26.0),Vector2(74.5,-24.8),Vector2(80.0,-23.8),
	Vector2(86.0,-22.6),Vector2(91.0,-24.8),Vector2(96.0,-24.2)]
const FAR := [Vector2(100.0,-39.8),Vector2(104.0,-40.2),Vector2(109.0,-41.5),Vector2(114.0,-46.0),Vector2(116.0,-53.0),
	Vector2(113.0,-60.0),Vector2(107.0,-64.5),Vector2(100.0,-66.0),Vector2(93.0,-64.0),Vector2(88.0,-59.0),
	Vector2(85.0,-53.0),Vector2(86.0,-47.0),Vector2(90.0,-42.0),Vector2(95.0,-40.4)]
## Grassy rises away from the routes (world x, z, radius, height).
const RISES := [Vector3(117.0,-17.0,6.0),Vector3(108.0,-58.0,5.0),Vector3(108.0,11.0,4.0)]
## Where the ground keeps flat: round the aqueduct's line and the pieces.
const FLAT_HALF := 7.0
## The ground's faces: cells this size (the hill's finer); the earth and
## rock of the islands' sides.
const CELL := 2.0
const HILL_CELL := 1.2
const EARTH := Color("6a4f37")
const ROCK := Color("675b50")
## How many boulders lie at the crags' feet (`hill_walls`).
const BOULDERS := 22

## An island: its top (the plate's ground look, its faces collided as one
## trimesh: its top is the ground; its crags in the islets' rock) over
## `flat` (world (x, z) -> y), and its sides and keel of hanging rock down
## from `top`, its keel's point `depth` under it. `hill`: the hill's cliffs
## laid in as ground points, its faces finer. The kit isles' shared builder
## (scripts/kit_isle/kit_land.gd `island`).
static func island(outline: Array, depth: float, seed_value: int, flat: Callable, top := TOP, hill := false) -> Node3D:
	var spec := {"outline":outline,"depth":depth,"seed":seed_value,"ground":flat,"top":top,
		"tone":KitLook.turf(seed_value,func(p: Vector2) -> float: return path_wear(p))}
	if hill:
		var box := Rect2(HILL.x-23.0,HILL.y-23.0,EAST_FACE+1.0-(HILL.x-23.0),46.0)
		# Probed off the round numbers (the isle's axis is z 0): no row of
		# points on a line a ray is likely cast along.
		spec.cliffs = Rect2(HILL.x-23.0+0.137,HILL.y-23.0+0.213,EAST_FACE+1.0-(HILL.x-23.0),46.0)
		spec.cliffs_nudge = Vector2.ZERO
		spec.walled = func(e: Vector2) -> bool: return _walled(e)
		spec.fine_box = box
		spec.fine = HILL_CELL
	return KitLand.island(spec)

static func _perimeter(outline: Array) -> float:
	return KitLand.perimeter(outline)

## A small islet's outline: a wandering ring `r` round `centre`.
static func blob(centre: Vector2, r: float, seed_value: int) -> Array:
	return KitLand.blob(centre,r,seed_value)

static func _area(ring: Array) -> float:
	return KitLand.area(ring)

static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	return KitLand.edge_distance(p,poly)

static func _resample(outline: Array, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	return KitLand.resample(outline,count,rng)

# --- The growth on the islands ---------------------------------------------------------

const BLADES := [Color("7d9a52"),Color("6f8b49"),Color("88a35b"),Color("75914c"),Color("94ab62")]

static func _tuft(b: Build, at: Vector3, height: float, count: int) -> void:
	var rng := b.rng
	for i in range(count):
		var h := height*rng.randf_range(0.55,1.15)
		var w := rng.randf_range(0.035,0.06)*(0.7+0.6*h)
		var planes: Array[Plane] = [Plane(Vector3.BACK,0.012),Plane(Vector3.FORWARD,0.012),Plane(Vector3.DOWN,0.0)]
		for s: float in [-1.0,1.0]:
			var n := Vector3(s*h,w,0.0).normalized()
			planes.append(Plane(n,n.dot(Vector3(s*w,0.0,0.0))))
		var lean := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(0.1,0.5))
		var off := Vector3(rng.randf_range(-1,1),0.0,rng.randf_range(-1,1))*height*0.3
		var colour: Color = BLADES[rng.randi()%BLADES.size()]*rng.randf_range(0.9,1.1)
		b.solid(planes,Transform3D(lean,at+off-Vector3(0.0,0.02,0.0)),colour,false,false,[],-1,1.0,false)

## Wildflowers among the tufts: a few faceted heads on stalks, cream,
## buttercup or harebell, small and soft (no glow).
const FLOWERS := [Color("efe9d2"),Color("e8cf5a"),Color("a99fcf"),Color("f1e3e8")]

static func _flower(b: Build, at: Vector3, height: float) -> void:
	var rng := b.rng
	var colour: Color = FLOWERS[rng.randi()%FLOWERS.size()]
	for i in range(rng.randi_range(2,4)):
		var h := height*rng.randf_range(0.9,1.35)
		var foot := at+Vector3(rng.randf_range(-0.18,0.18),0.0,rng.randf_range(-0.18,0.18))
		var stalk: Array[Plane] = RuinKit._prism(4,0.012,0.008,0.0,h)
		b.solid(stalk,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),foot),Color("6f8b49"),false,false,[],-1,1.0,false)
		var r := rng.randf_range(0.035,0.055)
		var head: Array[Plane] = RuinKit._prism(5,r,r*0.6,0.0,r*0.9,rng.randf()*TAU)
		b.solid(head,Transform3D(Basis.IDENTITY,foot+Vector3(0.0,h,0.0)),colour*rng.randf_range(0.92,1.05),false,false,[],-1,1.0,false)

# --- The hill's walls and kerbs -------------------------------------------------------

## The hill's built edges, colliding as laid (the kit's hulls): the lower
## tier's east face either side of the grand stair, coursed to T1 under a
## coping, a buttress out from each run (its set-offs a way up from the
## meadow); the ramp's retaining wall, cut along the upper tier's cliff as
## the ramp climbs it; kerbs of low stones along the ramp's open edge, the
## west shelf's, and the ledge's south, gone in places.
static func hill_walls(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.45,"HillWalls")
	var east := Basis(Vector3.UP,PI*0.5)
	var face_top := func(_x: float) -> float: return T1
	for run: Vector2 in [Vector2(-11.7,-2.72),Vector2(2.72,11.7)]:
		var mid := (run.x+run.y)*0.5
		var half := (run.y-run.x)*0.5
		var pose := Transform3D(east,Vector3(EAST_FACE+0.05,TOP,mid))
		RuinKit._plinth_course(b,pose,half,0.3)
		RuinKit._courses(b,pose,-half,half,RuinKit.PLINTH_COURSE.x,face_top,0.3,Callable(),0.5,true)
		RuinKit._buttress(b,Transform3D(east,Vector3(EAST_FACE+0.35,TOP,mid+signf(mid)*1.2)),BUTTRESS_STAGES,1.3)
	# The ramp's retaining wall: straight runs along the upper tier's edge,
	# each from under the ramp up to T2.
	var t := RAMP_FROM-1.5
	while t < RAMP_TO-3.0:
		var t1 := minf(t+4.0,RAMP_TO-3.0)
		var a := at_polar(t,r2(t))
		var c := at_polar(t1,r2(t1))
		var along := c-a
		var low := TOP+ramp(t)-0.6
		var pose := Transform3D(Basis(Vector3.UP,atan2(-along.y,along.x)),Vector3((a.x+c.x)*0.5,low,(a.y+c.y)*0.5))
		var wall_top := func(_x: float) -> float: return TOP+T2-low
		RuinKit._courses(b,pose,-along.length()*0.5-0.06,along.length()*0.5+0.06,0.0,wall_top,0.3,Callable(),0.45,true)
		t = t1
	# Boulders fallen from the crags, at the cliffs' feet (colliding as laid),
	# off the way up and the stairs' feet.
	var placed := 0
	for attempt in range(400):
		if placed >= BOULDERS: break
		var u := b.rng.randf_range(0.0,360.0)
		var upper := b.rng.randf() < 0.45
		var r := (r2(u) if upper else r1(u))+b.rng.randf_range(0.5,1.4)
		if upper and ((u >= RAMP_TO and u <= SHELF_TO) or (u >= RAMP_FROM-2.0 and u < RAMP_TO)): continue
		if u < 40.0 or u > 330.0: continue
		var p := at_polar(u,r)
		if path_wear(p) > 0.05 or absf(u-KIT_STAIRS_AT) < 14.0: continue
		var y := ground(p.x,p.y)
		var steep := false
		for d: Vector2 in [Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(0.0,1.0),Vector2(0.0,-1.0)]:
			if absf(ground(p.x+d.x,p.y+d.y)-y) > 0.2: steep = true
		if steep: continue
		var s := Vector3(b.rng.randf_range(0.35,0.75),b.rng.randf_range(0.3,0.6),b.rng.randf_range(0.35,0.7))
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.3,0.3))
		b.solid(RuinKit._box(b,s,0.12),Transform3D(tumble,Vector3(p.x,y+s.y*0.6,p.y)),ROCK*b.rng.randf_range(0.8,1.0),true,true,[],-1,2.2,false)
		placed += 1
	# The kerbs.
	_kerb(b,RAMP_FROM+2.0,RAMP_TO,func(u: float) -> float: return r1(u)-0.35,func(u: float) -> float: return TOP+ramp(u))
	_kerb(b,RAMP_TO,SHELF_TO-12.0,func(u: float) -> float: return r1(u)-0.35,func(_u: float) -> float: return TOP+T2)
	_kerb(b,SHELF_TO+1.0,KIT_STAIRS_AT-6.0,func(u: float) -> float: return r2(u)-0.3,func(_u: float) -> float: return TOP+T2)
	_kerb(b,KIT_STAIRS_AT+6.0,BAND_TO-1.0,func(u: float) -> float: return r2(u)-0.3,func(_u: float) -> float: return TOP+T2)
	return b.finish()

## Low kerb stones from angle `t0` to `t1` along `radius` (angle -> m),
## standing on `base_y` (angle -> world y): 0.22 to 0.36 m tall (stepped
## over), some gone.
static func _kerb(b: Build, t0: float, t1: float, radius: Callable, base_y: Callable) -> void:
	var t := t0
	while t < t1:
		var r: float = radius.call(t)
		var length := b.rng.randf_range(0.6,1.0)
		var span := rad_to_deg(length/r)
		if b.rng.randf() < 0.22:
			t += span*b.rng.randf_range(1.0,2.5)
			continue
		var tm := t+span*0.5
		var p := at_polar(tm,r)
		var h := b.rng.randf_range(0.22,0.36)
		var a := deg_to_rad(tm)
		var yaw := atan2(cos(a),-sin(a))
		var half := Vector3(length*0.5-0.03,h*0.5+0.06,b.rng.randf_range(0.14,0.2))
		var lean := Basis(Vector3.UP,yaw+b.rng.randf_range(-0.08,0.08))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.06,0.06))
		b.solid(RuinKit._box(b,half),Transform3D(lean,Vector3(p.x,float(base_y.call(tm))+h-half.y,p.y)),RuinKit._stone(b,0.95),true,true,[],-1,1.3)
		t += span+b.rng.randf_range(0.0,0.08)*span

# --- Floating stones and islets --------------------------------------------------------

## The stones hovering round the isle, each a platform: {name, at (its
## top's middle, world), size (along, thick, across), yaw (radians: its
## length's way, world), kind ("block" a cut stone torn up with a clod of
## earth under it; "sarsen", "lintel": the ring's own, no clod), chain}.
## Spaced to the moves (docs/design/island-packs/ruins_archipelago.md):
## a step up 1.35 m over about 1.8 m of air (a jump caught), a step down
## about 0.65 m over 1.2 to 2 m (a running jump); level gaps about 2 m.
##   south: up from the lower tier round the crag's shoulder to the bite.
##   drift: down from the summit's north-east edge to the castellum's crown.
##   west: from the west shelf to the west islet; east: off the meadow's
##   east edge to the east islet.
##   ring: the ring's broken-off sarsen at the lintels' height over the
##   bite, a lintel fallen across the bite's mouth, another into it.
const DRIFT := [[73.6,-8.0],[77.2,-7.2],[80.8,-6.3],[84.4,-5.4],[88.0,-4.4],[91.3,-3.0]]
const WEST_ISLET := Vector3(32.0,-0.5,3.6)
const EAST_ISLET := Vector3(135.0,-8.0,4.0)
const WEST_TOP := TOP+8.9
const EAST_TOP := TOP+1.9

static var _platforms: Array = []
static func platforms() -> Array:
	if not _platforms.is_empty(): return _platforms
	var out: Array = []
	var k := 0
	for spec: Vector2 in [Vector2(330.0,14.0),Vector2(315.0,14.0),Vector2(300.0,14.0),Vector2(285.0,13.3)]:
		k += 1
		var p := at_polar(spec.x,spec.y)
		var a := deg_to_rad(spec.x)
		var s := {"name":"south_%d" % k,"at":Vector3(p.x,TOP+T1+1.35*k,p.y),"size":Vector3(1.9,0.7,1.7),
			"yaw":atan2(cos(a),-sin(a)),"kind":"block","chain":"south"}
		# The first lies where it fell on the lower tier, sunk a little.
		if k == 1:
			s.size = Vector3(2.0,1.6,1.8)
			s.grounded = true
		out.append(s)
	var lip := at_polar(32.0,12.3)
	var from_y := summit(lip.x,lip.y)
	for i in range(DRIFT.size()):
		var at := Vector2(DRIFT[i][0],DRIFT[i][1])
		var y := lerpf(from_y,TOP+7.8,float(i+1)/(DRIFT.size()+1))
		var nxt := Vector2(DRIFT[mini(i+1,DRIFT.size()-1)][0],DRIFT[mini(i+1,DRIFT.size()-1)][1])
		var prv := Vector2(DRIFT[maxi(i-1,0)][0],DRIFT[maxi(i-1,0)][1])
		var way := (nxt-prv).normalized()
		out.append({"name":"drift_%d" % (i+1),"at":Vector3(at.x,y,at.y),"size":Vector3(2.0,0.65 if i%2 == 0 else 0.9,1.8),
			"yaw":atan2(-way.y,way.x)+(0.25 if i%2 == 1 else -0.15),"kind":"lintel" if i == 2 else "block","chain":"drift"})
	out.append({"name":"west_1","at":Vector3(39.0,TOP+T2+0.5,0.5),"size":Vector3(2.2,0.8,2.2),"yaw":0.4,"kind":"block","chain":"west"})
	out.append({"name":"east_1","at":Vector3(128.8,TOP+1.3,-6.5),"size":Vector3(2.0,0.8,2.0),"yaw":-0.3,"kind":"block","chain":"east"})
	out.append({"name":"east_0","at":Vector3(125.4,TOP+0.55,-6.3),"size":Vector3(1.6,0.85,1.3),"yaw":0.5,"kind":"block","chain":"east","grounded":true})
	# The ring's broken-off sarsen, lying along the ring at its lintels' top.
	var xf := circle_transform()
	var pitch := TAU/RuinKit.CIRCLE_STONES
	var am := (MISSING+0.5)*pitch
	var top := xf*Vector3(sin(am)*RuinKit.CIRCLE_RADIUS,RuinKit.SARSEN.y+RuinKit.LINTEL.y,cos(am)*RuinKit.CIRCLE_RADIUS)
	var tangent := xf.basis*Vector3(cos(am),0.0,-sin(am))
	out.append({"name":"ring_sarsen","at":top,"size":Vector3(3.0,1.1,1.25),"yaw":atan2(-tangent.z,tangent.x),"kind":"sarsen","chain":"ring"})
	# A lintel fallen across the bite's mouth, resting on its lips.
	var rb := 10.4
	var lo := BITE.x
	while edge_r(lo) < rb: lo -= 0.25
	var hi := BITE.x
	while edge_r(hi) < rb: hi += 0.25
	var ea := at_polar(lo,rb)
	var eb := at_polar(hi,rb)
	var mid := (ea+eb)*0.5
	var span := eb-ea
	out.append({"name":"bite_lintel","at":Vector3(mid.x,maxf(summit(ea.x,ea.y),summit(eb.x,eb.y))+0.3,mid.y),
		"size":Vector3(span.length()+1.2,0.6,1.3),"yaw":atan2(-span.y,span.x),"kind":"lintel","chain":"ring"})
	# The other lintel the missing sarsen carried, fallen into the bite.
	var down := at_polar(BITE.x,10.9)
	out.append({"name":"bite_floor","at":Vector3(down.x,TOP+T1+0.42,down.y),"size":Vector3(2.8,0.6,1.3),
		"yaw":deg_to_rad(BITE.x),"kind":"lintel","chain":"ring","grounded":true})
	_platforms = out
	return out

## The platform called `name`.
static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

## The floating stones (`stones`, platforms as `platforms` lays them; this
## isle's own if none): each drawn worn (laid lean, its top kept true) and
## walked on a clean, true box (RuinKit `_walk_hull`, as the kit's stairs
## are), a clod of earth and rock hanging under the torn-up ones, ivy
## trailing.
static func floating_stones(seed_value: int, stones: Array = []) -> Node3D:
	var b := Build.new(seed_value,0.55,"FloatingStones")
	for p: Dictionary in (stones if not stones.is_empty() else platforms()):
		var size: Vector3 = p.size
		var half := size*0.5
		var at: Vector3 = p.at
		var pose := Transform3D(Basis(Vector3.UP,float(p.yaw)),at-Vector3(0.0,half.y,0.0))
		var sarsen: bool = p.kind == "sarsen"
		b.lean = not sarsen
		b.solid(RuinKit._box(b,half,0.06 if p.kind == "lintel" else -1.0),pose,RuinKit._stone(b,1.12 if sarsen else 1.04),false,true,[],-1,1.5 if sarsen else 1.0)
		b.lean = false
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
		if p.kind == "block":
			# The clod torn up with it: earth and rock to a root-hung point.
			var deep := b.rng.randf_range(0.9,1.6)
			var clod := RuinKit._prism(5,0.12,minf(half.x,half.z)*0.95,-half.y-deep,-half.y+0.02,b.rng.randf()*TAU)
			b.solid(clod,pose,EARTH.lerp(ROCK,0.4)*b.rng.randf_range(0.85,1.05),false,true,[],-1,1.6,false)
			for i in range(3): _tuft(b,pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.8,half.y,b.rng.randf_range(-half.z,half.z)*0.8),0.3,4)
		if not p.has("grounded"):
			for i in range(2): b.hang(pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.7,0.0,b.rng.randf_range(-half.z,half.z)*0.7),b.rng.randf_range(0.8,2.2),true,at.y-size.y)
	return b.finish()

## The two islets: little islands of the same ground and rock, the west a
## vista out over the open sky, the east one off the meadow's end.
static func islets(seed_value: int) -> Array:
	var out: Array = []
	for spec: Array in [[WEST_ISLET,WEST_TOP,"WestIslet"],[EAST_ISLET,EAST_TOP,"EastIslet"]]:
		var c: Vector3 = spec[0]
		var top: float = spec[1]
		var flat := func(_x: float, _z: float) -> float: return top
		var node := island(blob(Vector2(c.x,c.y),c.z,seed_value+out.size()),7.0,seed_value+out.size(),flat,top)
		node.name = spec[2]
		out.append(node)
	return out
