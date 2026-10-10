extends RefCounted
## The ruin kit's belfry family (scripts/ruin_kit.gd, its Build and its
## stone): a ruined bell tower to crown a rock spire, with its bell still
## hanging, and the stone anchors a rope bridge (scripts/rope_bridge.gd)
## is tied to, so the bridges between the bell spires belong to the ruins.
## Additive: nothing here changes what the kit's own pieces build. The bell
## spires isle (studies/bell_spires_isle.gd) places them.
##
## Every piece, as the kit's: a Node3D, its foot on y 0 round the origin,
## "Mesh" (stone and growth) and "Body" (the blocks' hulls; steps, floors
## and tops walked on clean, true boxes). No ornament glows.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build

## The belfry: its square's outer width and walls (a 2.6 m shaft inside,
## the archipelago's tower), its belfry floor (the head of the outer stair:
## 22 of the kit's risers), the belfry's openings (width, sill over the
## floor, spring, the pointed head's rise), the wall head and its coping.
const WIDTH := 5.2
const WALL := 1.3
const FLOOR := 22*RuinKit.RISER
const OPENING := Vector4(1.4,0.5,2.3,0.8)
const HEAD := 10.6
## The outer stair's line (out from the walls' faces: a cheek and half a
## flight), its width, its flights' steps, the corner piers' half size.
const STAIR_WIDTH := 1.5
const STAIR_OUT := WIDTH*0.5+RuinKit.CHEEK.x+STAIR_WIDTH*0.5
const FLIGHTS := [8,8,6]
const PIER := 0.8
## The piles of stone inside the belfry's corners, stepping up to the wall head (top
## heights over the ground, corner signs), their size.
const CORBELS := [[FLOOR+1.4,Vector2(1.0,-1.0)],[FLOOR+2.8,Vector2(-1.0,-1.0)]]
const CORBEL := 0.7
## The bell: its beam's height (under its top), the bell's mouth and
## height, bronze gone dull and green.
const BEAM := 9.55
const BELL := Vector2(0.62,1.1)
const BRONZE := Color("6c6346")
const VERDIGRIS := Color("5f6d59")
const TIMBER := Color("4f3b2a")
## A bridge anchor: its posts (half size across, height), the sill and
## the plinth under it.
const POST := Vector2(0.19,1.3)
const SILL := Vector3(0.75,0.22,0.55)
const PLINTH := Vector3(1.15,1.4,0.75)

## A ruined bell tower on a spire's summit, its front (door, the outer
## stair's foot) toward +Z. Its walls coursed round a 2.6 m shaft, a door
## at the foot into the dark room under the belfry floor; slit windows;
## the belfry stage open on four sides under pointed heads; the wall head
## ragged on one side, a pinnacle snapped at each corner. Up the outside
## from the front, the stair winds round three faces in three flights on
## corner piers to the west opening at the belfry floor; inside, two
## corbels step up to the wall head, which runs round as a walk. The bell
## hangs from its beam ("Bell", a node of its own: swing it by its x).
## Meta: "floor" (y), "head" (the wall head's least standing top), "way"
## (the outer stair's points, foot to the floor), "corbels" (their tops),
## "bell" (its pivot), "door".
static func belfry(seed_value: int, weathered := 0.4) -> Node3D:
	var b := Build.new(seed_value,weathered,"Belfry")
	var half := WIDTH*0.5
	var d := WALL*0.5
	# The openings by wall: the west one at the floor (the stair comes in
	# there), the others at sill height; a door at the foot of the south.
	var hole_for := func(sill: float, door: bool) -> Callable:
		return func(y: float) -> Vector2:
			if door and y < 2.2: return Vector2(0.0,0.6)
			if door and y < 2.6: return Vector2(0.0,0.6*sqrt(maxf(0.0,1.0-pow((y-2.2)/0.4,2.0))))
			var spring := FLOOR+OPENING.z
			if y >= sill and y < spring: return Vector2(0.0,OPENING.x*0.5)
			if y >= spring and y < spring+OPENING.w: return Vector2(0.0,OPENING.x*0.5*sqrt(maxf(0.0,1.0-pow((y-spring)/OPENING.w,2.0))))
			# Slit windows up the shaft.
			if y > 2.9 and y < 4.1: return Vector2(0.0,0.09)
			return Vector2(0.0,-1.0)
	var ragged := RuinKit._ruin_line(b,-half,half,HEAD-1.6,HEAD,weathered,true)
	var whole := RuinKit._worn_top(b,-half,half,HEAD,0.4)
	# [pose, length's half, sill, door, top]
	var walls := [
		[Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,half-d)),half,FLOOR+OPENING.y,true,whole],
		[Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-(half-d))),half,FLOOR+OPENING.y,false,whole],
		[Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(half-d,0.0,0.0)),half-WALL,FLOOR+OPENING.y,false,ragged],
		[Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(-(half-d),0.0,0.0)),half-WALL,FLOOR,false,whole],
	]
	for w: Array in walls:
		var l: float = w[1]
		RuinKit._courses(b,w[0],-l,l,-0.4,w[4],d,hole_for.call(float(w[2]),bool(w[3])),0.42,false)
		# The wall head walked on a true top, where it stands whole.
		var pose: Transform3D = w[0]
		var x := -l
		while x < l-0.01:
			var x1 := minf(x+0.5,l)
			var top := minf(float(w[4].call(x)),float(w[4].call(x1)))
			if top > HEAD-0.45:
				RuinKit._walk_hull(b,pose,[Plane(Vector3.LEFT,-x),Plane(Vector3.RIGHT,x1),Plane(Vector3.UP,top-0.06),Plane(Vector3.DOWN,-(top-0.6)),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)])
			x = x1
	# A string course round the belfry floor's level, outside.
	for k in range(4):
		var a := k*PI*0.5
		var pose := Transform3D(Basis(Vector3.UP,a),Vector3.ZERO)
		var y := FLOOR-0.3
		var planes: Array[Plane] = [Plane(Vector3.LEFT,half),Plane(Vector3.RIGHT,half),Plane(Vector3.DOWN,-y),Plane(Vector3.UP,y+0.16),Plane(Vector3.BACK,half+0.1),Plane(Vector3.FORWARD,-(half-0.2))]
		var m := (Vector3.BACK+Vector3.UP*1.2).normalized()
		planes.append(Plane(m,m.dot(Vector3(0.0,y+0.16,half+0.02))))
		b.solid(planes,pose,RuinKit._stone(b,1.06),false)
	# Snapped pinnacles at the corners where the head stands.
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			if sx > 0.0 and sz < 0.0: continue
			var at := Vector3(sx*(half-0.35),HEAD,sz*(half-0.35))
			RuinKit._spire(b,Transform3D(Basis.IDENTITY,at),0.3,1.9,true)
	# The belfry floor (stone slabs on the walls), walked true.
	b.solid(RuinKit._box(b,Vector3(half-WALL+0.05,0.15,half-WALL+0.05)),Transform3D(Basis.IDENTITY,Vector3(0.0,FLOOR-0.15,0.0)),RuinKit._stone(b,0.92),false)
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,half-0.2),Plane(Vector3.RIGHT,half-0.2),Plane(Vector3.BACK,half-0.2),Plane(Vector3.FORWARD,half-0.2),Plane(Vector3.UP,FLOOR),Plane(Vector3.DOWN,-(FLOOR-0.35))])
	# The corbels up the inside, each a jump-catch above the last.
	var corbel_tops: Array = []
	var inner := half-WALL
	for c: Array in CORBELS:
		var top: float = c[0]
		var s: Vector2 = c[1]
		# A pile of squared stones in the corner (the stump of a stair to
		# the wall head), laid in courses up from the floor.
		var mid := Vector3(s.x*(inner-CORBEL*0.5),top,s.y*(inner-CORBEL*0.5))
		var y := FLOOR
		while y < top-0.05:
			var y1 := minf(top,y+b.rng.randf_range(0.38,0.5))
			if top-y1 < 0.2: y1 = top
			var size := Vector3(CORBEL*0.5,(y1-y)*0.5,CORBEL*0.5)
			b.solid(RuinKit._box(b,size),RuinKit._settle(b,Vector3(mid.x,(y+y1)*0.5,mid.z),0.3),RuinKit._stone(b,1.04),false)
			y = y1
		RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,-(mid.x-CORBEL*0.5)),Plane(Vector3.RIGHT,mid.x+CORBEL*0.5),Plane(Vector3.FORWARD,-(mid.z-CORBEL*0.5)),Plane(Vector3.BACK,mid.z+CORBEL*0.5),Plane(Vector3.UP,top),Plane(Vector3.DOWN,-(FLOOR-0.1))])
		corbel_tops.append(Vector3(mid.x,top,mid.z))
	# The bell's beam across the shaft, east to west, its ends in the walls.
	b.solid(RuinKit._box(b,Vector3(half-0.3,0.14,0.16),0.03),Transform3D(Basis.IDENTITY,Vector3(0.0,BEAM+0.14,0.0)),TIMBER,true,false)
	# The outer stair: up the east face from the front, round the north on
	# a corner pier, down the west to the opening, on corner piers.
	var way: Array = []
	var s_out := STAIR_OUT
	var edge := s_out-PIER
	var tread := RuinKit.TREAD
	# [turn, steps, landing]: up the east face toward -z, the north toward
	# -x, the west toward +z; each but the last meets a corner pier.
	var specs := [[0.0,FLIGHTS[0],0.5],[PI*0.5,FLIGHTS[1],2.0*edge-(FLIGHTS[1]-1)*tread],[PI,FLIGHTS[2],OPENING.x*0.5+0.15+edge-(FLIGHTS[2]-1)*tread]]
	var rise := 0.0
	for i in range(specs.size()):
		var steps: int = specs[i][1]
		var landing: float = specs[i][2]
		var run := (steps-1)*tread+landing
		var basis := Basis(Vector3.UP,float(specs[i][0]))
		# Its head (the -z end of its own frame) at the next pier's edge;
		# the last's foot at the north-west pier's.
		var middle := Vector3(0.0,rise,-s_out)
		match i:
			0: middle = Vector3(s_out,rise,-edge+run*0.5)
			1: middle = Vector3(-edge+run*0.5,rise,-s_out)
			2: middle = Vector3(-s_out,rise,-edge+run*0.5)
		var placed := Transform3D(basis,middle)
		RuinKit._flight(b,placed,steps,STAIR_WIDTH,landing,rise)
		way.append(placed*Vector3(0.0,0.0,run*0.5+0.5))
		rise += steps*RuinKit.RISER
		way.append(placed*Vector3(0.0,steps*RuinKit.RISER,-run*0.5+0.3))
		if i < 2:
			# The corner pier at its head, coursed to the landing's height.
			var corner := Vector3(s_out,0.0,-s_out) if i == 0 else Vector3(-s_out,0.0,-s_out)
			var top := rise
			var line := func(_x: float) -> float: return top
			RuinKit._courses(b,Transform3D(Basis.IDENTITY,corner),-PIER,PIER,-0.6,line,PIER,Callable(),0.42,false)
			RuinKit._walk_hull(b,Transform3D(Basis.IDENTITY,corner),[Plane(Vector3.LEFT,PIER),Plane(Vector3.RIGHT,PIER),Plane(Vector3.BACK,PIER),Plane(Vector3.FORWARD,PIER),Plane(Vector3.UP,top),Plane(Vector3.DOWN,0.6)])
			way.append(corner+Vector3.UP*top)
	# The landing by the west opening, walked through the wall.
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,s_out+STAIR_WIDTH*0.5),Plane(Vector3.RIGHT,-(half-WALL-0.1)),Plane(Vector3.BACK,OPENING.x*0.5-0.05),Plane(Vector3.FORWARD,OPENING.x*0.5-0.05),Plane(Vector3.UP,FLOOR),Plane(Vector3.DOWN,-(FLOOR-0.3))])
	way.append(Vector3(0.0,FLOOR,0.0))
	RuinKit._rubble(b,half+1.6,int(round(weathered*8.0)))
	var node := b.finish()
	node.add_child(bell(seed_value+1))
	node.set_meta("floor",FLOOR)
	node.set_meta("head",HEAD-1.6)
	node.set_meta("way",way)
	node.set_meta("corbels",corbel_tops)
	node.set_meta("bell",Vector3(0.0,BEAM,0.0))
	node.set_meta("door",Vector3(0.0,0.0,half+0.6))
	return node

## The bell, hanging from a pivot at its node's origin (its crown under
## it): bronze in faceted rings, lip, waist, shoulder and crown, its
## clapper inside; drawn only (it swings: turn the node about its x).
static func bell(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.3,"Bell")
	var r := BELL.x
	var h := BELL.y
	# [bottom r, top r, low, high] down from the pivot.
	var rings := [[r,r*0.96,-h,-h+0.1],[r*0.9,r*0.66,-h+0.1,-h+0.45],[r*0.66,r*0.58,-h+0.45,-0.3],[r*0.58,r*0.32,-0.3,-0.14],[r*0.25,r*0.2,-0.14,-0.04]]
	for i in range(rings.size()):
		var ring: Array = rings[i]
		var tone := BRONZE.lerp(VERDIGRIS,b.rng.randf_range(0.2,0.7))*b.rng.randf_range(0.92,1.06)
		b.solid(RuinKit._prism(12,ring[0],ring[1],ring[2],ring[3],PI/12.0),Transform3D.IDENTITY,tone,false,false)
	# The crown's loop on the pivot, and the clapper.
	b.solid(RuinKit._box(b,Vector3(0.05,0.08,0.16),0.01),Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,0.0)),BRONZE*0.8,false,false)
	b.solid(RuinKit._prism(6,0.03,0.03,-h+0.25,-0.2),Transform3D.IDENTITY,Color("3e3a33"),false,false)
	b.solid(RuinKit._prism(8,0.09,0.05,-h-0.05,-h+0.25),Transform3D.IDENTITY,Color("3e3a33"),false,false)
	var node := b.finish()
	node.get_node("Body").free()
	var pivot := Node3D.new()
	pivot.name = "Bell"
	pivot.position = Vector3(0.0,BEAM,0.0)
	pivot.add_child(node)
	return pivot

## A rope bridge's stone anchor: two square posts either side of the deck
## (`width` m) under weathered caps, a sill stone the deck's end rests on,
## its top at y 0 (the walk), and a coursed plinth under it standing out
## of a cliff's lip; the bridge goes out toward -Z. The posts and the sill
## collide (the sill walked true); the plinth only draws if `plinth`.
## Meta "posts": the posts' tops (for perching birds).
static func bridge_anchor(seed_value: int, weathered := 0.4, width := 0.74, plinth := true) -> Node3D:
	var b := Build.new(seed_value,weathered,"BridgeAnchor")
	var tops: Array = []
	for s: float in [-1.0,1.0]:
		var x := s*(width*0.5+POST.x+0.12)
		var high := POST.y*b.rng.randf_range(0.9,1.05)
		b.solid(RuinKit._box(b,Vector3(POST.x,(high+0.6)*0.5,POST.x)),RuinKit._settle(b,Vector3(x,(high-0.6)*0.5,0.0),0.4),RuinKit._stone(b,1.02))
		# A cap: a low pyramid over a thin projecting course.
		b.solid(RuinKit._box(b,Vector3(POST.x+0.05,0.06,POST.x+0.05)),Transform3D(Basis.IDENTITY,Vector3(x,high+0.06,0.0)),RuinKit._stone(b,1.06),true,true)
		if b.rng.randf() > weathered*0.6:
			b.solid(RuinKit._prism(4,(POST.x+0.04)*1.0,0.02,high+0.12,high+0.4,PI*0.25),Transform3D.IDENTITY.translated(Vector3(x,0.0,0.0)),RuinKit._stone(b,1.04),true,true)
		tops.append(Vector3(x,high+0.12,0.0))
		# The ropes' groove: a darker band where they were lashed.
		b.solid(RuinKit._box(b,Vector3(POST.x+0.01,0.05,POST.x+0.01),0.0),Transform3D(Basis.IDENTITY,Vector3(x,0.85,0.0)),Color("3f3a33"),false,false)
	b.solid(RuinKit._box(b,SILL*Vector3(1.0,0.5,1.0)+Vector3(width*0.5,0.0,0.0)*0.0),Transform3D(Basis.IDENTITY,Vector3(0.0,-SILL.y*0.5,0.15)),RuinKit._stone(b,1.08),false)
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,SILL.x),Plane(Vector3.RIGHT,SILL.x),Plane(Vector3.BACK,0.15+SILL.z),Plane(Vector3.FORWARD,SILL.z-0.15),Plane(Vector3.UP,0.0),Plane(Vector3.DOWN,SILL.y)])
	if plinth:
		var line := func(_x: float) -> float: return -SILL.y
		RuinKit._courses(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,0.2)),-PLINTH.x,PLINTH.x,-SILL.y-PLINTH.y,line,PLINTH.z*0.5,Callable(),0.38,false)
	var node := b.finish()
	node.set_meta("posts",tops)
	return node
