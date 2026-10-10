extends RefCounted
## The aqueduct isle's art (studies/aqueduct_isle.gd): the ruins
## archipelago's station 2 (studies/island_packs/ruins_archipelago.gd)
## dressed in the gothic ruin kit (scripts/ruin_kit.gd, scripts/
## ruin_kit_aqueduct.gd) on two floating islands, with the henge (its
## terrace, here; the stone circle and grand stair, the kit's) west of it
## on the isle's axis and the heel stone east.
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
	var water := Aqueduct._water(b.root,HEAD+0.5,SNAP-0.15,DECK+WATER_LIFT,WATER_HALF)
	var running := ShaderMaterial.new()
	running.shader = CHANNEL_SHADER
	running.set_shader_parameter("middle",Vector3(MID_X,TOP+DECK,0.0))
	running.set_shader_parameter("half_width",WATER_HALF)
	water.material_override = running
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
	return {"node":node,"parts":parts}

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

# --- The henge: its terrace, the grand stair's landing, the heel stone ------------------

## The henge on the near island's west lobe: the kit's stone circle on a
## round terrace of coursed walling (TERRACE_SIDES straight runs, its
## wall's middle TERRACE_R out from HENGE, TERRACE_TOP high: the grand
## stair's 2 x 8 risers), turfed on top. The stair climbs its east face on
## the isle's axis (z 0: henge, stair, castellum and the aqueduct's head,
## the heel stone beyond); a corner of its north face has fallen in a heap
## of SET_OFF steps (FALLEN_CORNER); buttresses stand out from it, their
## set-offs a third way up.
const HENGE := Vector2(65.0,0.0)
const TERRACE_R := 12.0
const TERRACE_WALL := 0.6
const TERRACE_SIDES := 16
const TERRACE_TOP := 2.0*RuinKit.STEPS*RuinKit.RISER
## The fallen corner (world rect, top over the island): 1.5 and 3.0 m, then
## the terrace's 4.48.
const FALLEN_CORNER := [[Rect2(63.9,-14.6,2.2,2.0),3.0],[Rect2(63.9,-16.6,2.2,2.0),1.5]]
## The buttresses: which of the terrace's runs (from east, toward +z) and
## their stages [top, depth]: a tread at SET_OFF and twice it, then a
## jump-catch onto the coping.
const BUTTRESS_RUNS := [2,6,10,14]
const BUTTRESS_STAGES := [[RuinKit.SET_OFF,2.0],[RuinKit.SET_OFF*2.0,1.2]]
## The grand stair on the axis (its middle, world), climbing west.
const STAIR_AT := Vector3(82.5,TOP,0.0)
## The heel stone: a lone sarsen out east on the axis, leaning (its top a
## pump's catch).
const HEEL := Vector2(118.0,0.0)
const HEEL_SIZE := Vector3(1.7,2.3,1.1)

## The paths worn in the turf between the landmarks (world polylines): the
## stair's foot round the castellum to the slope's foot, on to the heel
## stone; the fallen corner along the north edge to the stumps; round the
## circle's floor.
const PATHS := [
	[Vector2(87.0,0.0),Vector2(90.5,5.5),Vector2(96.0,8.6),Vector2(100.0,10.0),Vector2(106.0,6.5),Vector2(112.0,2.0),Vector2(117.0,0.4)],
	[Vector2(65.0,-17.5),Vector2(71.0,-19.0),Vector2(80.0,-20.5),Vector2(87.0,-20.8),Vector2(92.0,-22.0)],
	[Vector2(76.5,0.0),Vector2(72.5,0.0),Vector2(71.0,3.5),Vector2(67.0,5.8),Vector2(62.0,5.6),Vector2(58.6,2.5),Vector2(58.6,-2.5),Vector2(62.0,-5.6),Vector2(67.0,-5.8),Vector2(71.0,-3.5),Vector2(72.5,0.0)],
]
## The turf's patches: lighter, yellower meadow and deeper hollows in broad
## drifts, the paths a trodden dun.
const MEADOW := [Color("6f8448"),Color("788b4d"),Color("6b8246")]
const HOLLOW := [Color("4a6237"),Color("4e663a")]
const WORN := Color("7f7853")

## A turf facet's colour at `at` (world x, z): the greens, drifting into
## meadow or hollow, worn along the paths.
static func turf_tone(rng: RandomNumberGenerator, noise: FastNoiseLite, at: Vector2) -> Color:
	var c: Color = GRASS[rng.randi()%GRASS.size()]
	var broad := noise.get_noise_2d(at.x*0.35+40.0,at.y*0.35-17.0)
	if broad > 0.1: c = c.lerp(MEADOW[rng.randi()%MEADOW.size()],clampf((broad-0.1)*3.5,0.0,0.85))
	elif broad < -0.15: c = c.lerp(HOLLOW[rng.randi()%HOLLOW.size()],clampf((-broad-0.15)*3.5,0.0,0.8))
	c = c.lerp(WORN*rng.randf_range(0.92,1.06),path_wear(at)*0.9)
	return c*(rng.randf_range(0.93,1.06)+0.08*noise.get_noise_2d(at.x,at.y))

## How worn the turf is at `at` (0 off the paths, 1 on their middle).
static func path_wear(at: Vector2) -> float:
	var best := INF
	for path: Array in PATHS:
		for i in range(path.size()-1):
			best = minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,path[i],path[i+1])))
	return clampf(1.25-best/1.5,0.0,1.0)

## The terrace's outline (world x, z): its runs' outer corners.
static func terrace_outline(r := TERRACE_R) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var step := TAU/TERRACE_SIDES
	for k in range(TERRACE_SIDES):
		var phi := (k+0.5)*step
		poly.append(HENGE+Vector2(cos(phi),sin(phi))*r/cos(step*0.5))
	return poly

## The terrace: its walls coursed under a coping (colliding as built), the
## buttresses, the turf on top (its own faces collide); the fallen corner
## (drawn, its clean boxes in `parts`). {node, parts}.
static func terrace(seed_value: int) -> Dictionary:
	var b := Build.new(seed_value,0.45,"Terrace")
	var step := TAU/TERRACE_SIDES
	var half_len := (TERRACE_R+TERRACE_WALL)*tan(step*0.5)+0.06
	var top := func(_x: float) -> float: return TERRACE_TOP
	var centre := Vector3(HENGE.x,TOP,HENGE.y)
	for k in range(TERRACE_SIDES):
		var phi := k*step
		var out := Vector3(cos(phi),0.0,sin(phi))
		var basis := Basis(Vector3.UP,PI*0.5-phi)
		var pose := Transform3D(basis,centre+out*TERRACE_R)
		RuinKit._plinth_course(b,pose,half_len,TERRACE_WALL)
		RuinKit._courses(b,pose,-half_len,half_len,RuinKit.PLINTH_COURSE.x,top,TERRACE_WALL,Callable(),0.5,true)
		if k in BUTTRESS_RUNS:
			RuinKit._buttress(b,Transform3D(basis,centre+out*(TERRACE_R+TERRACE_WALL)),BUTTRESS_STAGES,1.3)
	var node := b.finish()
	node.add_child(turf_patch(terrace_outline(TERRACE_R),TOP+TERRACE_TOP,seed_value+1))
	# The fallen corner: its courses tumbled into a stepped heap.
	var c := Build.new(seed_value+2,0.6,"FallenCorner")
	var parts: Array = []
	for block: Array in FALLEN_CORNER:
		var r: Rect2 = block[0]
		var high: float = block[1]
		parts.append(["box",r,TOP,TOP+high,"lip"])
		var line := func(_x: float) -> float: return high
		var pose := Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,TOP,r.get_center().y))
		RuinKit._courses(c,pose,-r.size.x*0.5,r.size.x*0.5,0.0,line,r.size.y*0.5-0.01,Callable(),0.5,true)
	RuinKit._drift(c,Vector3(62.4,TOP,-15.6),1.1,5)
	RuinKit._drift(c,Vector3(67.6,TOP,-14.4),0.9,4)
	var heap := c.finish()
	heap.get_node("Body").free()
	node.add_child(heap)
	return {"node":node,"parts":parts}

## Turf over `poly` (world x, z) at `height`: faceted, toned as the
## island's, its faces collided (a trimesh).
static func turf_patch(poly: PackedVector2Array, height: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var points := PackedVector2Array(poly)
	var box := Rect2(poly[0],Vector2.ZERO)
	for p in poly: box = box.expand(p)
	var gx := box.position.x+CELL*0.5
	while gx < box.end.x:
		var gz := box.position.y+CELL*0.5
		while gz < box.end.y:
			var p := Vector2(gx+rng.randf_range(-0.3,0.3)*CELL,gz+rng.randf_range(-0.3,0.3)*CELL)
			if Geometry2D.is_point_in_polygon(p,poly) and _edge_distance(p,poly) > CELL*0.45: points.append(p)
			gz += CELL
		gx += CELL
	var tris := Geometry2D.triangulate_delaunay(points)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var faces := PackedVector3Array()
	for t in range(0,tris.size(),3):
		var a := points[tris[t]]
		var bb := points[tris[t+1]]
		var cc := points[tris[t+2]]
		var mid := (a+bb+cc)/3.0
		if not Geometry2D.is_point_in_polygon(mid,poly): continue
		var pa := Vector3(a.x,height,a.y)
		var pb := Vector3(bb.x,height,bb.y)
		var pc := Vector3(cc.x,height,cc.y)
		faces.append_array([pa,pb,pc])
		var sink := Vector3(0.0,0.02,0.0)
		_tri(v,n,c,[pa-sink,pb-sink,pc-sink],turf_tone(rng,noise,mid),Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := Node3D.new()
	node.name = "Turf"
	var drawn := MeshInstance3D.new()
	drawn.name = "Mesh"
	drawn.mesh = mesh
	drawn.material_override = RuinKit.materials().stone
	node.add_child(drawn)
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
	return node

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

# --- The islands --------------------------------------------------------------------

## The islands' outlines (world x, z), each round its own middle: the big
## one under the head and the arcade, the far one where the aqueduct comes
## down. Authored round the station's floor (its spawn, the slope, the
## piers on the land) and the playground; the 16 m of sky between them
## kept open under the aqueduct.
const NEAR := [Vector2(100.0,-24.4),Vector2(104.0,-24.2),Vector2(109.0,-25.4),Vector2(114.0,-23.2),Vector2(119.0,-24.6),
	Vector2(124.0,-20.0),Vector2(127.0,-13.0),Vector2(126.0,-5.0),Vector2(128.0,2.0),Vector2(124.0,9.0),Vector2(119.0,14.0),
	Vector2(112.0,16.0),Vector2(106.0,15.5),Vector2(100.0,17.5),Vector2(93.0,16.0),Vector2(86.0,18.0),Vector2(80.0,17.0),
	Vector2(74.0,18.5),Vector2(67.0,18.0),Vector2(60.0,16.5),Vector2(54.0,13.0),Vector2(50.0,7.0),Vector2(48.0,0.0),
	Vector2(48.5,-7.0),Vector2(50.5,-13.0),Vector2(55.0,-18.5),Vector2(61.0,-21.5),Vector2(67.0,-21.0),Vector2(73.0,-20.0),
	Vector2(79.0,-23.0),Vector2(86.0,-22.6),Vector2(91.0,-24.8),Vector2(96.0,-24.2)]
const FAR := [Vector2(100.0,-39.8),Vector2(104.0,-40.2),Vector2(109.0,-41.5),Vector2(114.0,-46.0),Vector2(116.0,-53.0),
	Vector2(113.0,-60.0),Vector2(107.0,-64.5),Vector2(100.0,-66.0),Vector2(93.0,-64.0),Vector2(88.0,-59.0),
	Vector2(85.0,-53.0),Vector2(86.0,-47.0),Vector2(90.0,-42.0),Vector2(95.0,-40.4)]
## Grassy rises away from the routes (world x, z, radius, height).
const RISES := [Vector3(117.0,-17.0,6.0),Vector3(108.0,-58.0,5.0),Vector3(108.0,11.0,4.0)]
## Where the ground keeps flat: round the aqueduct's line and the pieces.
const FLAT_HALF := 7.0
## The grass: faceted, cells this size; the turf's tones; the earth and
## rock under it.
const CELL := 2.0
const GRASS := [Color("5a7042"),Color("587040"),Color("5d7445"),Color("546a3d"),Color("61784a")]
const EARTH := Color("6a4f37")
const ROCK := Color("675b50")

## The ground underfoot at (x, z) (world): the island's turf (`base`), or
## the henge's terrace top inside its walls.
static func ground(x: float, z: float) -> float:
	if Vector2(x,z).distance_to(HENGE) < TERRACE_R: return TOP+TERRACE_TOP
	return base(x,z)

## The island's turf at (x, z) (world): TOP, rising on the rises, flat near
## the aqueduct.
static func base(x: float, z: float) -> float:
	var y := TOP
	var keep := clampf((absf(x-MID_X)-FLAT_HALF)/4.0,0.0,1.0)
	for r: Vector3 in RISES:
		var t := clampf(1.0-Vector2(x-r.x,z-r.y).length()/r.z,0.0,1.0)
		y += 1.6*t*t*(3.0-2.0*t)*keep
	return y

## An island: its turf (faceted, drawn and collided as one trimesh: its
## top is the ground) and its sides and keel of hanging rock. `depth` how
## far down its keel's point hangs.
static func island(outline: Array, depth: float, seed_value: int, flat: Callable) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ring := _resample(outline,48*2,rng)
	var node := Node3D.new()
	node.name = "Island"
	var centre := Vector2.ZERO
	for p in ring: centre += p
	centre /= ring.size()
	# The turf: the outline and a jittered grid inside it, triangulated.
	var points := PackedVector2Array(ring)
	var poly := PackedVector2Array(ring)
	var box := Rect2(ring[0],Vector2.ZERO)
	for p in ring: box = box.expand(p)
	var gx := box.position.x+CELL*0.5
	while gx < box.end.x:
		var gz := box.position.y+CELL*0.5
		while gz < box.end.y:
			var p := Vector2(gx+rng.randf_range(-0.6,0.6)*CELL*0.5,gz+rng.randf_range(-0.6,0.6)*CELL*0.5)
			if Geometry2D.is_point_in_polygon(p,poly) and _edge_distance(p,poly) > CELL*0.45: points.append(p)
			gz += CELL
		gx += CELL
	var tris := Geometry2D.triangulate_delaunay(points)
	var heights := PackedFloat32Array()
	for i in range(points.size()):
		var p := points[i]
		var y: float = flat.call(p.x,p.y)
		heights.append(y)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var faces := PackedVector3Array()
	var tone_noise := FastNoiseLite.new()
	tone_noise.seed = seed_value
	tone_noise.frequency = 0.08
	for t in range(0,tris.size(),3):
		var a := points[tris[t]]
		var bb := points[tris[t+1]]
		var cc := points[tris[t+2]]
		var mid := (a+bb+cc)/3.0
		if not Geometry2D.is_point_in_polygon(mid,poly): continue
		var pa := Vector3(a.x,heights[tris[t]],a.y)
		var pb := Vector3(bb.x,heights[tris[t+1]],bb.y)
		var pc := Vector3(cc.x,heights[tris[t+2]],cc.y)
		var tone := turf_tone(rng,tone_noise,mid)
		# Collided at the ground; drawn a hair under it, so feet stand on it.
		faces.append_array([pa,pb,pc])
		var sink := Vector3(0.0,0.02,0.0)
		_tri(v,n,c,[pa-sink,pb-sink,pc-sink],tone,Vector3.UP)
	# The sides: rings under the rim, the turf's lip, the earth, then the
	# rock tapering to a keel in ledges, a spur or two hanging lower.
	var count := ring.size()
	var outward: Array[Vector2] = []
	var ccw := _area(ring) > 0.0
	for i in range(count):
		var tangent: Vector2 = (ring[(i+1)%count]-ring[(i-1+count)%count]).normalized()
		outward.append(Vector2(tangent.y,-tangent.x) if ccw else Vector2(-tangent.y,tangent.x))
	var rims: Array = []
	var top_ring: Array[Vector3] = []
	for i in range(count):
		top_ring.append(Vector3(ring[i].x,float(flat.call(ring[i].x,ring[i].y))-0.02,ring[i].y))
	rims.append(top_ring)
	# Each ring: [inset toward the middle, drop under the top, push out, stride].
	var specs := [[0.0,0.45,0.28,1],[0.0,2.1,0.35,1],[0.1,depth*0.22,0.0,2],[0.32,depth*0.48,0.0,4],[0.6,depth*0.74,0.0,8],[0.82,depth*0.92,0.0,16]]
	var spurs := {}
	for i in range(3): spurs[rng.randi_range(0,count/16-1)] = rng.randf_range(0.15,0.3)*depth
	for spec: Array in specs:
		var r: Array[Vector3] = []
		var stride: int = spec[3]
		for i in range(0,count,stride):
			var p := ring[i]
			var inset: float = float(spec[0])+rng.randf_range(-0.05,0.05)*float(spec[0] > 0.0)
			var q := p.lerp(centre,clampf(inset,0.0,0.95))+outward[i]*float(spec[2])*rng.randf_range(0.3,1.2)
			var drop: float = float(spec[1])*rng.randf_range(0.85,1.15)
			if stride == 16 and spurs.has(i/16): drop += spurs[i/16]
			r.append(Vector3(q.x,TOP-drop,q.y))
		rims.append(r)
	var keel := Vector3(centre.x+rng.randf_range(-2.0,2.0),TOP-depth,centre.y+rng.randf_range(-2.0,2.0))
	for k in range(rims.size()-1):
		var upper: Array = rims[k]
		var lower: Array = rims[k+1]
		var ratio := upper.size()/lower.size()
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			for s in range(ratio):
				var u0: Vector3 = upper[j*ratio+s]
				var u1: Vector3 = upper[(j*ratio+s+1)%upper.size()]
				_tri(v,n,c,[u0,l0,u1],_side_tone(rng,(u0+u1+l0)/3.0,k),_out(centre,(u0+u1+l0)/3.0))
			var ue: Vector3 = upper[((j+1)*ratio)%upper.size()]
			_tri(v,n,c,[ue,l0,l1],_side_tone(rng,(ue+l0+l1)/3.0,k),_out(centre,(ue+l0+l1)/3.0))
	var last: Array = rims[rims.size()-1]
	for j in range(last.size()):
		var a: Vector3 = last[j]
		var b2: Vector3 = last[(j+1)%last.size()]
		var mid := (a+b2+keel)/3.0
		_tri(v,n,c,[a,keel,b2],_side_tone(rng,mid,9),_out(centre,mid)+Vector3.DOWN)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var drawn := MeshInstance3D.new()
	drawn.name = "Mesh"
	drawn.mesh = mesh
	drawn.material_override = RuinKit.materials().stone
	node.add_child(drawn)
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
	node.set_meta("outline",poly)
	return node

static func _side_tone(rng: RandomNumberGenerator, at: Vector3, ring: int) -> Color:
	if ring == 0: return EARTH*rng.randf_range(0.85,1.1)
	var band := 0.9+0.12*sin(at.y*1.7)+0.05*sin(at.y*0.53+1.0)
	var c := ROCK.lerp(EARTH,0.25 if ring == 1 else 0.0)
	return c*band*rng.randf_range(0.88,1.1)

static func _out(centre: Vector2, at: Vector3) -> Vector3:
	return Vector3(at.x-centre.x,0.0,at.z-centre.y).normalized()

## A triangle wound to face `toward`, flat shaded.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, t: Array, colour: Color, toward: Vector3) -> void:
	var p0: Vector3 = t[0]
	var p1: Vector3 = t[1]
	var p2: Vector3 = t[2]
	if (p1-p0).cross(p2-p0).dot(toward) > 0.0:
		var swap := p1
		p1 = p2
		p2 = swap
	var normal := (p2-p0).cross(p1-p0).normalized()
	var linear := colour.srgb_to_linear()
	for p: Vector3 in [p0,p1,p2]:
		v.append(p)
		n.append(normal)
		c.append(linear)

static func _area(ring: Array) -> float:
	var s := 0.0
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i+1)%ring.size()]
		s += a.x*b.y-b.x*a.y
	return s*0.5

static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in range(poly.size()):
		var q := Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])
		best = minf(best,p.distance_to(q))
	return best

## The outline resampled to `count` points evenly round it, each nudged
## out or in a little, so its edge wanders.
static func _resample(outline: Array, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var total := 0.0
	for i in range(outline.size()): total += (outline[i] as Vector2).distance_to(outline[(i+1)%outline.size()])
	var out: Array[Vector2] = []
	var step := total/count
	var seg := 0
	var into := 0.0
	for k in range(count):
		var want := step*k
		while true:
			var a: Vector2 = outline[seg%outline.size()]
			var b: Vector2 = outline[(seg+1)%outline.size()]
			var length := a.distance_to(b)
			if want-into <= length or seg >= outline.size()*2:
				var p := a.lerp(b,clampf((want-into)/maxf(length,0.001),0.0,1.0))
				var normal := Vector2(b.y-a.y,a.x-b.x).normalized()
				out.append(p+normal*rng.randf_range(-0.35,0.35))
				break
			into += length
			seg += 1
	return out

# --- The growth on the islands ---------------------------------------------------------

## Grass tufts in drifts over the turf, thinning toward the ruins' feet;
## `avoid` rects (world) kept bare. Drawn only.
static func growth(seed_value: int, outlines: Array, avoid: Array[Rect2]) -> Node3D:
	var b := Build.new(seed_value,0.5,"Growth")
	var rng := b.rng
	var noise := FastNoiseLite.new()
	noise.seed = seed_value+3
	noise.frequency = 0.09
	for outline: PackedVector2Array in outlines:
		var box := Rect2(outline[0],Vector2.ZERO)
		for p in outline: box = box.expand(p)
		var tries := int(box.get_area()*0.6)
		for i in range(tries):
			var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
			if not Geometry2D.is_point_in_polygon(p,outline): continue
			if noise.get_noise_2d(p.x,p.y) < 0.05+rng.randf_range(-0.15,0.15): continue
			var bare := false
			for r in avoid:
				if r.has_point(p):
					bare = true
					break
			if bare: continue
			var edge := _edge_distance(p,outline)
			var h := rng.randf_range(0.28,0.5)*(1.25 if edge < 2.0 else 1.0)
			_tuft(b,Vector3(p.x,ground(p.x,p.y),p.y),h,rng.randi_range(4,7))
			if rng.randf() < 0.16: _flower(b,Vector3(p.x,ground(p.x,p.y),p.y),h)
	var node := b.finish()
	node.get_node("Body").free()
	return node

## A tuft as the kit's (Build `tuft`), in the turf's living greens: blades
## a shade lighter than the ground, so a drift reads as grass, not shards.
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
