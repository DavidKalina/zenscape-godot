extends RefCounted
## The ruin kit's cloister (scripts/ruin_kit.gd, the same stone, wear and
## growth): an abbey's cloister arcade, its ranges of small pointed arches
## on clustered piers carrying a wall-walk; a lavabo pavilion of four such
## arches round a square; the stone heads (abutments) a rope bridge is tied
## to; and a stone slab bridge. Additive: nothing here changes the kit's
## pieces or its gallery (they are not in RuinKit PIECES).
##
## A range runs along X at the arcade's centreline, its front (+Z) toward
## the garth, its back (-Z) toward the alley; its foot on y 0. `piers` are
## the piers' x (corner to corner); each bay between two piers is an arch
## of the kit's two moulded orders under a hood, springing at SPRING, its
## crown RISE over that (the arc's radius found from the bay), the spandrels
## coursed up to the wall-walk, a coping on top. The wall-walk is walked on
## a clean, true box (RuinKit `_walk_box`, as the kit's stairs are), so no
## worn coping or course joint is a gap; the stone's own hulls stand under
## it (wall kicks, the plane's bump).
##
## Fallen bays have no arch nor walling; a pier inside a fallen run is a
## stub snapped at a given height, its break walked on a clean top. Heaps of
## fallen blocks (`heap`) are clean boxes drawn worn: a way up a broken end.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build

## The arcade: its springing, the arches' rise over it, the wall-walk's top
## (two kit flights: a kit stair or two reach it) and the wall's thickness.
const SPRING := 1.75
const RISE := 1.75
const WALK := 2.0*RuinKit.STEPS*RuinKit.RISER
const THICK := 1.2
## The coping's depth under the walk's top.
const COPING := 0.2
## A pier's shafts stand this far each side of its middle at the arch's
## springing (the kit arch's px less its clear half span).
const PIER_HALF := RuinKit.ORDER
## How far a pier's shafts reach from its middle (a main shaft's centre
## and its apothem's corner): the clear between two piers' shafts, the
## room through a bay over their bases, is their spacing less twice this.
static var PIER_REACH: float = RuinKit.SHAFT_MAIN.y+RuinKit.SHAFT_MAIN.x/cos(PI/8.0)
## The least walk top over a bay whose piers stand `pitch` apart: its arch
## (pointed; round where the bay is wide), the ring's two orders and the
## hood under the coping, a hand of walling over them.
static func bay_top(pitch: float) -> float:
	var h := pitch*0.5-PIER_HALF-0.15
	var rise := maxf(RISE,h)
	var radius := maxf(h,(rise*rise+h*h)/(2.0*h))
	return SPRING+RuinKit._rise(h,radius)+RuinKit.ORDER*2.0+RuinKit.HOOD.x+COPING+0.1
## A stub's walked top (m, square) and a rope bridge's stone head.
const STUB_TOP := 0.9
const ABUTMENT := Vector3(2.2,0.0,2.4)
const POST := Vector3(0.36,0.95,0.36)

## A range (see the header). `opts`:
##   fallen: Array of bay indices fallen (bay i between piers i and i+1);
##   stubs: {pier index: height} of piers snapped off;
##   tall: {bay index: walk top} for a bay whose walk stands higher (a
##     wider arch, its crown over the arcade's); where it stands a riser or
##     more over a standing neighbour's walk, steps on that walk climb to
##     it (`_steps_up`, the kit's RISER and TREAD): the wall-walk is still
##     walked over it;
##   ends: Vector2 how far the wall-walk reaches past the first and last
##     piers (a corner);
##   buttresses: Array of x where a stepped buttress stands on the garth
##     face (set-offs at SET_OFF and twice it: a climb onto the walk);
##   skip_piers: Array of pier indices not built (another range's corner).
## Meta "walk": [{from, to, top}] the walked stretches (piece frame);
## "stubs": [{at (top middle), size}]; "bays": [{x0, x1, top, fallen}].
static func range_run(seed_value: int, weathered: float, piers: Array, opts := {}) -> Node3D:
	var b := Build.new(seed_value,weathered,"CloisterRange")
	b.settle = 0.45
	var fallen: Array = opts.get("fallen",[])
	var stubs: Dictionary = opts.get("stubs",{})
	var tall: Dictionary = opts.get("tall",{})
	var ends: Vector2 = opts.get("ends",Vector2(0.6,0.6))
	var skip: Array = opts.get("skip_piers",[])
	var d := THICK*0.5
	var walks: Array = []
	var stub_meta: Array = []
	var bays: Array = []
	for i in range(piers.size()):
		if skip.has(i): continue
		var x: float = piers[i]
		if stubs.has(i):
			var h: float = stubs[i]
			RuinKit._pier(b,Transform3D(Basis.IDENTITY,Vector3(x,0.0,0.0)),SPRING,h)
			# Its break walked on a clean top, the drawn break a little under.
			var s := STUB_TOP*0.5
			RuinKit._walk_box(b,Transform3D(Basis.IDENTITY,Vector3(x,0.0,0.0)),s,h-0.6,h,s,-s)
			stub_meta.append({"at":Vector3(x,h,0.0),"size":Vector2(STUB_TOP,STUB_TOP)})
			RuinKit._drift(b,Vector3(x+b.rng.randf_range(-0.6,0.6),0.0,b.rng.randf_range(0.8,1.6)),1.0,2+int(weathered*3.0))
			continue
		RuinKit._pier(b,Transform3D(Basis.IDENTITY,Vector3(x,0.0,0.0)),SPRING,INF)
	for i in range(piers.size()-1):
		var x0: float = piers[i]
		var x1: float = piers[i+1]
		var down: bool = fallen.has(i)
		var top: float = float(tall.get(i,WALK))
		bays.append({"x0":x0,"x1":x1,"top":top,"fallen":down})
		if down:
			# In the alley only under the gap's middle: its ends are kept for
			# the heaps (a way up).
			if fallen.has(i-1) and fallen.has(i+1): RuinKit._drift(b,Vector3((x0+x1)*0.5,0.0,-1.4),1.3,3+int(weathered*5.0))
			RuinKit._drift(b,Vector3((x0+x1)*0.5+b.rng.randf_range(-0.5,0.5),0.0,1.3),1.1,2+int(weathered*4.0))
			continue
		var a := x0-(ends.x if i == 0 else 0.0)
		var e := x1+(ends.y if i == piers.size()-2 else 0.0)
		# A bay next to a fallen one ends over its pier and a little past.
		if i > 0 and fallen.has(i-1): a = x0-PIER_HALF
		if i < piers.size()-2 and fallen.has(i+1): e = x1+PIER_HALF
		_bay(b,x0,x1,top,d,x0-a,e-x1)
		_walk_span(b,a,e,top,d)
		walks.append({"from":Vector3(a,top,0.0),"to":Vector3(e,top,0.0),"top":top})
		# Steps up from this walk onto a taller neighbour's.
		for k: int in [i-1,i+1]:
			if k < 0 or k > piers.size()-2 or fallen.has(k): continue
			var high := float(tall.get(k,WALK))
			if high-top < RuinKit.RISER*0.9: continue
			var way := -1.0 if k < i else 1.0
			_steps_up(b,x0 if k < i else x1,way,top,high,d)
	for x: float in opts.get("buttresses",[]):
		var pose := Transform3D(Basis.IDENTITY,Vector3(x,0.0,d))
		RuinKit._buttress(b,pose,[[RuinKit.SET_OFF,1.9],[RuinKit.SET_OFF*2.0,1.05]],1.3,false,false)
	# Ivy down the faces and from the arches' heads.
	for i in range(int(3+weathered*8.0)):
		var bay: Dictionary = bays[b.rng.randi_range(0,bays.size()-1)]
		if bay.fallen: continue
		b.hang(Vector3(b.rng.randf_range(float(bay.x0)+0.6,float(bay.x1)-0.6),0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.6,1.8)*(0.5+weathered),true)
	RuinKit._rubble(b,2.5,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	var node := b.finish()
	node.set_meta("walk",walks)
	node.set_meta("stubs",stub_meta)
	node.set_meta("bays",bays)
	return node

## One bay from the pier at `x0` to the one at `x1`: its arch, the
## spandrels coursed up under the coping, the coping (`top` the walk's top).
static func _bay(b: Build, x0: float, x1: float, top: float, d: float, ea := 0.0, eb := 0.0) -> void:
	var cx := (x0+x1)*0.5
	var h := (x1-x0)*0.5-PIER_HALF-0.15
	# The arc's radius for the rise wanted (pointed; round if it can't be).
	var rise := maxf(RISE,h)
	var radius := maxf(h,(rise*rise+h*h)/(2.0*h))
	var lost_side := -1.0 if b.rng.randf() < 0.5 else 1.0
	var lost := 0
	if b.weathered > 0.4 and b.rng.randf() < 0.25*b.weathered: lost = 1
	var hood := RuinKit._rise(h,radius)+RuinKit.ORDER*2.0+RuinKit.HOOD.x < top-COPING-SPRING
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	RuinKit._arch_ring(b,pose,0.0,SPRING,h,radius,d,hood,lost,lost_side)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < SPRING: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(h,radius,outer-radius,y-SPRING))
	var under := top-COPING
	var line := func(_x: float) -> float: return under
	RuinKit._courses(b,pose,-(x1-x0)*0.5-ea,(x1-x0)*0.5+eb,SPRING,line,d-0.04,hole,0.48)
	# The coping: slabs across the wall's whole thickness, chamfered both
	# sides, drawn only (the walk is the clean box under them).
	var x := x0-ea
	var end := x1+eb
	while x < end-0.05:
		var xb := minf(x+b.rng.randf_range(0.7,1.2),end)
		if end-xb < 0.35: xb = end
		if not (b.weathered > 0.3 and b.rng.randf() < 0.12*b.weathered):
			var half := Vector3((xb-x)*0.5-0.008,COPING*0.5,d+0.02)
			var planes := RuinKit._box(b,half)
			for s: float in [-1.0,1.0]:
				var n := Vector3(0.0,1.0,s*1.3).normalized()
				planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-0.06)))))
			b.solid(planes,RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3((x+xb)*0.5,top-half.y,0.0)),0.3),RuinKit._stone(b,0.93),false,true)
		x = xb

## Steps set on a walk at `low`, up to `high` at `at` (along X), climbing
## toward `way` (+1 or -1): the kit's TREAD, risers RISER or a little
## under, each block the wall's depth, walked on a clean box.
static func _steps_up(b: Build, at: float, way: float, low: float, high: float, d: float) -> void:
	var count := maxi(1,int(round((high-low)/RuinKit.RISER)))
	var riser := (high-low)/count
	for k in range(count):
		# Step k from the foot: its top, its run back from `at`.
		var top := low+riser*(k+1)
		var near := at-way*RuinKit.TREAD*(count-1-k)
		var far := at-way*RuinKit.TREAD*(count-k)
		var x0 := minf(near,far)
		var x1 := maxf(near,far)
		var half := Vector3((x1-x0)*0.5-0.01,(top-low+COPING)*0.5,d+0.01)
		b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3((x0+x1)*0.5,top-half.y,0.0)),0.3),RuinKit._stone(b,0.97),false,true)
		_walk_span(b,x0,x1,top,d)

## The walk's clean box from `a` to `b2` along X at `top`, `d` (half) deep.
static func _walk_span(b: Build, a: float, b2: float, top: float, d: float) -> void:
	var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3((a+b2)*0.5,0.0,0.0))
	var half := (b2-a)*0.5
	RuinKit._walk_box(b,pose,d,top-0.7,top,half,-half)

## A heap of fallen blocks at a broken end (a way up it): `blocks` [middle
## of its top (x, y, z), size (x, y, z), yaw], each walked on a clean box,
## drawn worn and settled a little; a drift of smaller stones round it.
static func heap(seed_value: int, weathered: float, blocks: Array) -> Node3D:
	var b := Build.new(seed_value,weathered,"FallenHeap")
	for spec: Array in blocks:
		var top: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		var half := size*0.5
		var pose := Transform3D(Basis(Vector3.UP,float(spec[2])),top-Vector3(0.0,half.y,0.0))
		b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,1.02),false,true,[],-1,1.2)
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
		RuinKit._drift(b,Vector3(top.x,0.0,top.z)+Vector3(b.rng.randf_range(-1.0,1.0),0.0,b.rng.randf_range(-1.0,1.0)),0.9,2)
	return b.finish()

## A lavabo pavilion: four piers round a square `side` m (pier to pier),
## an arch on each side, the spandrels coursed up to a walked top at `top`
## (its whole square walked), fallen drums heaped at one corner (`steps`:
## [middle of top, size] clean blocks, a way up). Its foot on y 0, middle at
## the origin.
static func pavilion(seed_value: int, weathered: float, side: float, top: float, steps: Array) -> Node3D:
	var b := Build.new(seed_value,weathered,"Lavabo")
	b.settle = 0.4
	var h := side*0.5
	var d := 0.45
	for c in range(4):
		var a := TAU*c/4.0
		var corner := Vector3(cos(a)-sin(a),0.0,sin(a)+cos(a))*h
		RuinKit._pier(b,Transform3D(Basis.IDENTITY,corner),SPRING,INF)
	for s in range(4):
		var keep := b.frame
		b.frame = Transform3D(Basis(Vector3.UP,PI*0.5*s),Vector3.ZERO)*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,h))
		_bay(b,-h,h,top,d)
		b.frame = keep
	RuinKit._walk_box(b,Transform3D.IDENTITY,h+d,top-0.6,top,h+d,-h-d)
	for spec: Array in steps:
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		var half := size*0.5
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.3,0.3)),at-Vector3(0.0,half.y,0.0))
		b.solid(RuinKit._prism(8,minf(half.x,half.z),minf(half.x,half.z)*0.96,-half.y,half.y,b.rng.randf()*TAU),pose,RuinKit._stone(b,0.98),false,true)
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x*0.85),Plane(Vector3.LEFT,half.x*0.85),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z*0.85),Plane(Vector3.FORWARD,half.z*0.85)])
	for i in range(int(2+weathered*5.0)):
		b.hang(Vector3(b.rng.randf_range(-h,h),0.0,b.rng.randf_range(-h,h)),b.rng.randf_range(0.5,1.5),true)
	RuinKit._rubble(b,h+1.6,int(round(weathered*5.0)))
	return b.finish()

## A stone slab bridge `length` (X) by `width` (Z), its top at y 0: two or
## three long slabs side by side on a corbelled end each side, walked on a
## clean box the slabs' length.
static func slab_bridge(seed_value: int, weathered: float, length: float, width: float) -> Node3D:
	var b := Build.new(seed_value,weathered,"SlabBridge")
	var parts := 2 if width < 1.8 else 3
	for i in range(parts):
		var z0 := -width*0.5+width*i/parts
		var z1 := -width*0.5+width*(i+1)/parts
		var half := Vector3(length*0.5,0.16,(z1-z0)*0.5-0.01)
		b.solid(RuinKit._box(b,half,0.05),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.16,(z0+z1)*0.5)),0.25),RuinKit._stone(b,1.05),false,true,[],-1,0.6)
	RuinKit._walk_box(b,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3.ZERO),width*0.5,-0.32,0.0,length*0.5,-length*0.5)
	for i in range(2): b.hang(Vector3(b.rng.randf_range(-length*0.3,length*0.3),-0.3,b.rng.randf_range(-width*0.4,width*0.4)),b.rng.randf_range(0.4,1.0),true,-0.32)
	return b.finish()
