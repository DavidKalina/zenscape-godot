extends RefCounted
## The ruin kit's cloister (scripts/ruin_kit.gd, the same stone, wear and
## growth): an abbey's cloister arcade, its ranges of small pointed arches
## on clustered piers carrying a wall-walk; a lavabo pavilion of four such
## arches round a square; the stone heads (abutments) a rope bridge is tied
## to; and a stone slab bridge. Additive: nothing here changes the kit's
## pieces or its gallery (they are not in RuinKit PIECES). The pent hood
## (bottom) is a kit piece by id (RuinKit CLOISTER_PIECES, `piece`).
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

# --- The pent hood (round 2 card: kit-k5-hide-descend.md) -------------------

const WorldScale = preload("res://scripts/world_scale.gd")
## The walker's head over his feet (m at size 1), frozen: the pilot on foot
## (scripts/pilot_physics_ground.gd HEAD) is gone from the flight game,
## whole at the tag archive/before-the-cut.
const WALKER_HEAD := 1.12

## The cloister's pieces built by id (RuinKit CLOISTER_PIECES).
const PIECES := ["pent_hood"]

## The pent hood's gallery: clear width from the back wall's face to the
## parapet's (TOP_ROOM: one body, no passing) and its floor's top.
const HOOD_GALLERY := RuinKit.TOP_ROOM
const HOOD_FLOOR := 0.14
## The parapet: thickness, height over the floor (over WALKER_HEAD,
## so his head ray is hidden behind it; under GRAB_TOP, so one jump catches
## its coping), its coping's depth.
const HOOD_PARAPET := Vector3(0.5,1.45,0.18)
## The roof's pitch (deg): over SLIDE_FROM (a crouch surfs it) and under
## SLOPE_SLOW (he walks it at full pace), its slabs' thickness, and how far
## its eaves overhang the parapet's outer face.
const HOOD_PITCH := 20.0
const HOOD_SLAB := 0.3
const HOOD_EAVES := 0.6
## The room over the parapet's coping under the roof (m, past the head):
## he climbs onto the coping and stands there under the eaves to vault out.
const HOOD_STAND_ROOM := 0.2
## The back wall's head over the roof's high edge: under SET_OFF (he drops
## onto the roof from the wall walk, and one jump catches the walk back).
const HOOD_OVER := 1.1
## Bays along X, each WALL_LENGTH (it lays on a kit wall's line).
const HOOD_BAYS := 2
## How dark the soot under the roof is at its deepest (a share).
const HOOD_SOOT := 0.6
## A fallen bay's gap in the roof: its width along X (m), least and most.
const HOOD_GAP := Vector2(1.6,2.4)

## The hood's numbers across (z) and up (y), its frame: the back wall's
## gallery face, the parapet's faces, the eaves; the roof's underside over
## the parapet's outer face, its top at the wall face and at the eaves.
static func hood_lines() -> Dictionary:
	var zw := -HOOD_GALLERY*0.5
	var zp0 := HOOD_GALLERY*0.5
	var zp1 := zp0+HOOD_PARAPET.x
	var ze := zp1+HOOD_EAVES
	var t := tan(deg_to_rad(HOOD_PITCH))
	var slab := HOOD_SLAB/cos(deg_to_rad(HOOD_PITCH))
	var under_p := HOOD_FLOOR+HOOD_PARAPET.y+WALKER_HEAD*WorldScale.wanderer+HOOD_STAND_ROOM
	var under := func(z: float) -> float: return under_p+(zp1-z)*t
	var high := float(under.call(zw))+slab
	return {"zw":zw,"zp0":zp0,"zp1":zp1,"ze":ze,"tan":t,"slab":slab,"under_p":under_p,
		"under_w":float(under.call(zw)),"high":high,"low":float(under.call(ze))+slab,
		"wall_top":high+HOOD_OVER,"wall_mid":zw-RuinKit.WALL_THICK*0.5}

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"pent_hood": return pent_hood(seed_value,weathered)
	return null

## A pent hood: a lean-to stone roof run out from a wall's face on corbels
## over a low, narrow gallery behind a parapet, `bays` WALL_LENGTH bays
## along X (centred), the back wall toward -Z, the open side +Z. `fallen`
## (0 to bays; -1, by `weathered`): that many bays have a gap of slabs
## gone out of the roof, the sky over the gallery there.
## Collision: the floor, the parapet, the back wall and its walk are clean
## boxes (the walls' faces kickable); the roof one clean tilted box per
## standing stretch (one slope, no seams), real stone on the ground mask
## (an up ray hits it). The corbels and the drawn stones have none.
## Meta: "gallery" AABB (under the roof, over the floor), "gaps" [AABB]
## (the gallery under each gap), "roof" [{x0, x1}] the standing stretches,
## "lines" (hood_lines), "parapet_top", "wall_top", "eaves" (z, top y).
static func pent_hood(seed_value: int, weathered := 0.0, bays := HOOD_BAYS, fallen := -1) -> Node3D:
	var b := Build.new(seed_value,weathered,"PentHood")
	b.settle = 0.5
	var L := hood_lines()
	var zw: float = L.zw
	var zp0: float = L.zp0
	var zp1: float = L.zp1
	var ze: float = L.ze
	var half_len := RuinKit.WALL_LENGTH*bays*0.5
	var wall_top: float = L.wall_top
	var pitch := deg_to_rad(HOOD_PITCH)
	if fallen < 0: fallen = 0 if weathered < 0.45 else (1 if weathered < 0.85 or bays < 2 else 2)
	fallen = clampi(fallen,0,bays)
	# The gaps: one in each of `fallen` bays (picked), somewhere along it.
	var order: Array = range(bays)
	for i in range(order.size()-1,0,-1):
		var j := b.rng.randi_range(0,i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var gaps: Array[Vector2] = []
	for k in range(fallen):
		var bay: int = order[k]
		var bx0 := -half_len+RuinKit.WALL_LENGTH*bay
		var w := b.rng.randf_range(HOOD_GAP.x,HOOD_GAP.y)
		var c := b.rng.randf_range(bx0+w*0.5+0.6,bx0+RuinKit.WALL_LENGTH-w*0.5-0.6)
		gaps.append(Vector2(c-w*0.5,c+w*0.5))
	gaps.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.x < c.x)
	var in_gap := func(x: float) -> bool:
		for g: Vector2 in gaps:
			if x > g.x and x < g.y: return true
		return false
	# Dark under the roof (vertex grime: soot under the eaves), a little
	# less toward the open side.
	var under_w: float = L.under_w
	b.shelter = func(mid: Vector3, _n: Vector3) -> float:
		if mid.z < zw-0.05 or mid.z > ze+0.1 or in_gap.call(mid.x): return 0.0
		if absf(mid.x) > half_len+0.2: return 0.0
		if mid.y > under_w+0.1: return 0.0
		return clampf(0.95-maxf(mid.z-zp1,0.0)*0.9,0.0,1.0)
	# The back wall, coursed, its head whole but worn: drawn only (its clean
	# box below is walked and kicked).
	var keep_hulls := b.hulls.size()
	var dw := RuinKit.WALL_THICK*0.5
	var wall_pose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,L.wall_mid))
	RuinKit._plinth_course(b,wall_pose,half_len,dw)
	RuinKit._courses(b,wall_pose,-half_len,half_len,RuinKit.PLINTH_COURSE.x,RuinKit._worn_top(b,-half_len,half_len,wall_top,0.2),dw,Callable(),0.44,true)
	# The parapet, coursed under its coping (drawn only).
	var dp := HOOD_PARAPET.x*0.5
	var par_pose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,(zp0+zp1)*0.5))
	var par_top := HOOD_FLOOR+HOOD_PARAPET.y
	var line := func(_x: float) -> float: return par_top-HOOD_PARAPET.z
	RuinKit._courses(b,par_pose,-half_len,half_len,0.0,line,dp-0.02,Callable(),0.36)
	var x := -half_len
	while x < half_len-0.05:
		var xb := minf(x+b.rng.randf_range(0.7,1.2),half_len)
		if half_len-xb < 0.35: xb = half_len
		var half := Vector3((xb-x)*0.5-0.008,HOOD_PARAPET.z*0.5,dp+0.04)
		var planes := RuinKit._box(b,half)
		for s: float in [-1.0,1.0]:
			var n := Vector3(0.0,1.0,s*1.3).normalized()
			planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-0.05)))))
		b.solid(planes,par_pose*RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3((x+xb)*0.5,par_top-half.y,0.0)),0.3),RuinKit._stone(b,0.95),false,true)
		x = xb
	# The gallery's floor slabs (drawn).
	x = -half_len
	while x < half_len-0.05:
		var xb := minf(x+b.rng.randf_range(0.6,1.0),half_len)
		if half_len-xb < 0.3: xb = half_len
		var half := Vector3((xb-x)*0.5-0.01,HOOD_FLOOR*0.5,(zp0-zw)*0.5-0.01)
		b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3((x+xb)*0.5,half.y,0.0)),0.2),RuinKit._stone(b,0.85),false,true)
		x = xb
	# The drawn walls' own hulls out: the clean boxes stand for them.
	b.hulls.resize(keep_hulls)
	b.hull_anchors.resize(keep_hulls)
	# The corbels under the roof, out of the wall's face (drawn, no hull),
	# each a stepped pair of stones.
	var corbels := int(round(half_len*2.0/1.3))
	for i in range(corbels+1):
		var cx := -half_len+0.35+(half_len*2.0-0.7)*float(i)/corbels
		if in_gap.call(cx) and b.rng.randf() < 0.6: continue
		var top := under_w-0.02
		var lower := Vector3(0.16,0.17,0.24)
		var upper := Vector3(0.18,0.15,0.4)
		b.solid(RuinKit._box(b,upper,0.03),Transform3D(Basis.IDENTITY,Vector3(cx,top-upper.y,zw+upper.z-0.1)),RuinKit._stone(b,0.92),false,true)
		b.solid(RuinKit._box(b,lower,0.03),Transform3D(Basis.IDENTITY,Vector3(cx,top-upper.y*2.0-lower.y,zw+lower.z-0.1)),RuinKit._stone(b,0.9),false,true)
	# The roof: slabs lapped along X, each from inside the wall to the eaves
	# on the pitch, sagged and cracked at the ends and round a gap.
	var z_in := zw-0.3
	var run := ze-z_in
	var slope_len := run/cos(pitch)
	var tilt := Basis(Vector3.RIGHT,pitch)
	var mid_z := (ze+z_in)*0.5
	var mid_under: float = float(L.under_p)+(zp1-mid_z)*float(L.tan)
	var roof_mid := func(sx: float) -> Vector3:
		return Vector3(sx,mid_under+HOOD_SLAB*0.5/cos(pitch),mid_z)
	x = -half_len
	var lap := 0
	while x < half_len-0.05:
		var xb := minf(x+b.rng.randf_range(0.75,1.25),half_len)
		if half_len-xb < 0.35: xb = half_len
		var cx := (x+xb)*0.5
		if in_gap.call(cx):
			x = xb
			continue
		var edge: bool = absf(cx) > half_len-1.4 or in_gap.call(x-0.5) or in_gap.call(xb+0.5)
		var half := Vector3((xb-x)*0.5+0.03,HOOD_SLAB*0.5,slope_len*0.5)
		var extra: Array[Plane] = []
		if edge or b.rng.randf() < 0.25*weathered:
			# A broken eaves end: a ragged cut off its low corner.
			var side := signf(cx) if edge else (-1.0 if b.rng.randf() < 0.5 else 1.0)
			var n := Vector3(side*b.rng.randf_range(0.5,1.0),0.0,b.rng.randf_range(0.7,1.2)).normalized()
			extra.append(Plane(n,n.dot(Vector3(side*half.x*0.5,0.0,half.z*b.rng.randf_range(0.75,0.92)))))
		var pose := Transform3D(tilt,roof_mid.call(cx)+Vector3(0.0,0.03*float(lap%2),0.0))
		if edge: pose = Transform3D(Basis(Vector3.BACK,-signf(cx)*b.rng.randf_range(0.01,0.03))*pose.basis,pose.origin+Vector3(0.0,-0.03,0.0))
		b.solid(RuinKit._box(b,half,0.04),RuinKit._jiggle(b,pose,0.1),RuinKit._stone(b,1.0),false,true,extra,-1,0.8)
		lap += 1
		x = xb
	# The clean boxes: the floor, the parapet, the back wall (its top the
	# wall walk), the roof per standing stretch.
	RuinKit._walk_box(b,Transform3D.IDENTITY,half_len,-0.3,HOOD_FLOOR,zp0,zw)
	RuinKit._walk_box(b,Transform3D.IDENTITY,half_len,0.0,par_top,zp1,zp0)
	RuinKit._walk_box(b,Transform3D.IDENTITY,half_len,0.0,wall_top,zw,zw-RuinKit.WALL_THICK)
	var spans: Array = []
	var a := -half_len
	for g: Vector2 in gaps:
		spans.append(Vector2(a,g.x))
		a = g.y
	spans.append(Vector2(a,half_len))
	var roof_meta: Array = []
	for s: Vector2 in spans:
		if s.y-s.x < 0.2: continue
		var c := (s.x+s.y)*0.5
		RuinKit._walk_box(b,Transform3D(tilt,roof_mid.call(c)),(s.y-s.x)*0.5,-HOOD_SLAB*0.5,HOOD_SLAB*0.5,slope_len*0.5,-slope_len*0.5)
		roof_meta.append({"x0":s.x,"x1":s.y})
	# Ivy off the eaves and the wall's head; moss on the roof.
	for i in range(int(2+weathered*6.0)):
		var hx := b.rng.randf_range(-half_len+0.4,half_len-0.4)
		if in_gap.call(hx): continue
		b.hang(Vector3(hx,0.0,ze-0.1),b.rng.randf_range(0.4,1.1)*(0.5+weathered),true,float(L.low)-HOOD_SLAB)
	RuinKit._drift(b,Vector3(b.rng.randf_range(-half_len*0.6,half_len*0.6),0.0,ze+0.9),1.1,int(weathered*5.0))
	RuinKit._rubble(b,half_len*0.6,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	# Soot under the roof (vertex grime): the gallery's faces darkened, the
	# deeper the darker, so it reads dark without a light; open under a gap.
	for face: Array in b.pending:
		if not (face[0] is PackedVector3Array) or not (face[2] is Color): continue
		var corners: PackedVector3Array = face[0]
		var m := Vector3.ZERO
		for q in corners: m += q
		m /= corners.size()
		var dark := float(b.shelter.call(m,face[1]))
		if dark <= 0.0 or m.y < -0.1: continue
		var c: Color = face[2]
		face[2] = Color(c.r,c.g,c.b,c.a).darkened(HOOD_SOOT*dark)
	var node := b.finish()
	var gallery := AABB(Vector3(-half_len,HOOD_FLOOR,zw),Vector3(half_len*2.0,float(L.under_p)-HOOD_FLOOR,zp0-zw))
	var gap_boxes: Array = []
	for g: Vector2 in gaps: gap_boxes.append(AABB(Vector3(g.x,HOOD_FLOOR,zw),Vector3(g.y-g.x,float(L.under_p)-HOOD_FLOOR,zp0-zw)))
	node.set_meta("gallery",gallery)
	node.set_meta("gaps",gap_boxes)
	node.set_meta("roof",roof_meta)
	node.set_meta("lines",L)
	node.set_meta("parapet_top",par_top)
	node.set_meta("wall_top",wall_top)
	node.set_meta("eaves",Vector2(ze,float(L.low)))
	node.set_meta("bays",bays)
	return node
