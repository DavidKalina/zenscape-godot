extends RefCounted
## Builds the Sundered hall (scripts/sundered_hall.gd plans it) for the
## sky clusters (scripts/sky_clusters.gd): its islands, the hall's far and
## near detail, the aqueduct crossing a gap, the apse and its tower, and
## the streaming of the near detail in and out.
##
## `solve` (on a worker): the layout, then each piece's island authored as
## a long ridge island along its chord (SkyIslet `author`, the outline's
## ellipse fixed: IslandOutline `mask` `form`), the hall's footprint
## levelled into a bed at the floor and cleared of what grows, walker
## blocks along the walls and columns; the aqueduct's small island. Each
## member carries `yaw` (its turn about up) and `hall` (the hall frame in
## its own frame).
##
## Detail. Far (`far`): one cheap mesh a piece made with the plan: plain
## FAR_SIDES-sided columns, each wall a block or two, the roof strips as
## whole slabs, the gables, beams, podium; no carving, no collision, the
## overgrowth only as a few hanging strips (scripts/sundered_growth.gd);
## stood with the island and always there. Near (`near`, built
## on a worker when the eye comes within NEAR_BUILD of a piece, one piece
## at a time): the ruin kit's bays at Hall.IN_WORLD detail, the podium the
## hall stands on with its torn ends hanging over the sky, the apse's
## ring and tower, all dressed in the overgrowth (scripts/sundered_growth.gd:
## curtains, ivy, cascades, vines trailing off the torn ends; growth only);
## one merged mesh and one body (RUIN_LAYER, the plane's
## bump, scripts/ruin_bump.gd). Shown inside NEAR_SHOW (the far hidden),
## let go past NEAR_FORGET. Stood in a frame within the sky's frame budget
## (scripts/sky_commits.gd), its collision split by bay over frames.

const Sundered = preload("res://scripts/sundered_hall.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const HallPath = Hall.HallPath
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SunderedGrowth = preload("res://scripts/sundered_growth.gd")

## The physics layer the ruins' bodies stand on (the plane's bump asks
## only this one).
const RUIN_LAYER := 1 << 10
## Near detail: built within NEAR_BUILD of the eye, shown within NEAR_SHOW,
## let go past NEAR_FORGET (m, to the nearest point of a piece's line).
const NEAR_BUILD := 340.0
const NEAR_SHOW := 240.0
const NEAR_FORGET := 480.0
## Hulls a body chunk holds (stood one chunk a frame).
const CHUNK := 120
## The far detail's columns' sides.
const FAR_SIDES := 8
## The islands' outline: a rounded oblong (IslandOutline `form` square),
## so the land stays wide under the hall to its torn ends.
const SQUARE := 4.0
## The islands' grid step (m: coarser than an islet's, a big island).
const ISLE_STEP := 1.0
## The bed: the hall's footprint across (half, m, to the podium's face)
## and how far the ground eases back to its own past it.
const BED_HALF := 14.6
const BED_EASE := 4.0
## The podium under the floor: its face's middle across (m), its top
## under the floor, its courses (m) and their count (a range), the blocks'
## length along it.
const PODIUM_Z := 14.0
const PODIUM_TOP := -0.3
const PODIUM_COURSE := 1.25
const PODIUM_COURSES := Vector2i(2,4)
const PODIUM_BLOCK := 2.2
## The apse: its ring of columns' radius (m) and how far past the hall's
## end its middle stands; the tower's half size, height (a range), where
## it stands (path space, from the end).
const APSE_RADIUS := 10.0
const APSE_PAST := 2.0
const TOWER_HALF := 3.6
const TOWER_HIGH := Vector2(19.0,26.0)
const TOWER_AT := Vector3(-6.0,0.0,-(Hall.WALL_Z+7.0))
## The aqueduct: its spans, the line's height over its island's ground
## under the arch it threads, the snapped stub past the last pier (m).
const AQ_SPANS := 3
const AQ_LINE := 2.6
const AQ_STUB := 1.7
## The kinds of island by act.
const KINDS := {"gate":"meadow","nave":"grove","shafts":"hills","cloister":"meadow","slit":"hills","apse":"meadow"}

# --- Solving --------------------------------------------------------------------

## The plan with its members (islands): see the header.
static func solve(seed_value: int, yaw := 0.0) -> Dictionary:
	var plan := Sundered.layout(seed_value,yaw)
	var members: Array = []
	for piece: Dictionary in plan.pieces: members.append(_isle(plan,piece))
	if plan.has("aqueduct"): members.append(_aqueduct_isle(plan))
	plan.members = members
	return plan

## A piece's island: authored long along +X, turned to the chord, its
## middle under the floor; the bed levelled, the plants cleared off it, the
## walker's blocks set.
static func _isle(plan: Dictionary, piece: Dictionary) -> Dictionary:
	var isle: Dictionary = piece.island
	var half: Vector2 = isle.half
	# An oblong (a squared ellipse, SQUARE), its area as the oblong's.
	var r := sqrt(half.x*half.y)*1.08
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isle.seed)
	var kind: String = KINDS.get(piece.act,"meadow")
	var spec := {"kind":kind,"radius":r,"step":ISLE_STEP,"outline":{"aspect":half.x/half.y,"heading":0.0,"drift":0.0,"bays":0,"lobes":0.3,"square":SQUARE},
		"room":maxf(0.0,half.x*1.15+4.0-r*SkyIslet.REACH-SkyIslet.MARGIN),"dome":rng.randf_range(0.6,1.2),
		"trees":Vector2i(10,18),"tree_pool":{"tree":1.0,"birch":0.6,"broadleaf":0.5,"juniper":0.4},"mixed":true,"tree_size":Vector2(0.9,1.4),
		"drifts":Vector2i(4,8),"far_trees":180.0,
		"rock":{"palette":["basalt","slate","basalt_warm"][rng.randi()%3],"tone":rng.randf_range(0.88,1.06)},
		"keel":RockLooks.keel(r,rng.randf_range(1.0,1.25))}
	spec.rock.vary = RockLooks.vary_of(int(isle.seed))
	if kind == "grove": spec.trees = Vector2i(18,28)
	var shape: RefCounted = SkyIslet.author(int(isle.seed),spec)
	# The hall frame in the island's (xz first; its height by the bed).
	var yaw: float = isle.yaw
	var at: Vector3 = isle.at
	var island := Transform3D(Basis(Vector3.UP,yaw),at)
	var to_isle := island.affine_inverse()*(piece.frame as Transform3D)
	var path: HallPath = piece.path
	var length: float = piece.length
	var lo := -Sundered.FORECOURT if piece.first else 0.0
	var hi := length+(Sundered.APSE_ROOM if piece.last else 0.0)
	# The floor: the ground under the footprint, a little over half of it
	# under the floor, so the hall sits down into its island.
	var heights: Array = []
	var s := 0.0
	while s <= length:
		for z in [-12.0,-6.0,0.0,6.0,12.0]:
			var q := to_isle*path.point(Vector3(s,0.0,z))
			var p := Vector2(q.x,q.z)
			if shape.on_land(p): heights.append(shape.ground_at(p))
		s += 4.0
	heights.sort()
	var floor_local: float = heights[int(heights.size()*0.6)] if not heights.is_empty() else SkyIslet.GROUND
	_bed(shape,to_isle,path,lo,hi,floor_local)
	# The island stands with its floor at the piece's.
	var offset := Vector3(at.x,float(piece.floor)-floor_local,at.z)
	var hall := Transform3D(Basis(Vector3.UP,yaw),offset).affine_inverse()*(piece.frame as Transform3D)
	shape.recipe.blocks = _blocks(piece,hall)
	return {"name":isle.name,"role":"piece","seed":int(isle.seed),"shape":shape,"offset":offset,"yaw":yaw,"features":[],
		"piece":int(piece.index),"hall":hall,"floor_local":floor_local}

## Levels the hall's footprint (path space s in lo..hi, |z| <= BED_HALF)
## to the floor, the ground higher round it eased down to it over BED_EASE
## (lower ground left: the podium's face shows there), and clears what
## grows on it.
static func _bed(shape: RefCounted, to_isle: Transform3D, path: HallPath, lo: float, hi: float, floor_local: float) -> void:
	var back := to_isle.affine_inverse()
	var bed := floor_local-0.06
	var points: PackedVector2Array = shape.points
	var dist: PackedFloat32Array = shape.shore_distance
	var heights: PackedFloat32Array = shape.heights
	for i in range(points.size()):
		if dist[i] < 0.0: continue
		var q := back*Vector3(points[i].x,0.0,points[i].y)
		var loc := path.locate(q)
		var out_s := maxf(lo-loc.x,loc.x-hi)
		var out_z := absf(loc.z)-BED_HALF
		var d := Vector2(maxf(out_s,0.0),maxf(out_z,0.0)).length()
		if d <= 0.0:
			heights[i] = bed
		elif d < BED_EASE and heights[i] > bed:
			heights[i] = lerpf(bed,heights[i],smoothstep(0.0,BED_EASE,d))
	shape.heights = heights
	var kept: Array[Dictionary] = []
	for o: Dictionary in shape.objects:
		var q := back*Vector3(float(o.x),0.0,float(o.z))
		var loc := path.locate(q)
		var in_s: bool = loc.x > lo-1.5 and loc.x < hi+1.5
		if in_s and absf(loc.z) < BED_HALF+1.5: continue
		kept.append(o)
	shape.objects = kept

## The walker's blocks (island frame, Vector3(x, z, radius)): the columns
## and the walls, but where a breach or a door lets a walker through.
static func _blocks(piece: Dictionary, hall: Transform3D) -> Array:
	var out: Array = []
	var path: HallPath = piece.path
	var plans: Array = piece.plans
	var add := func(p: Vector3, r: float) -> void:
		var q := hall*path.point(p)
		out.append(Vector3(q.x,q.z,r))
	for i in range(plans.size()):
		var p: Dictionary = plans[i]
		var x0 := i*Hall.BAY
		for z: float in [-Hall.ROW_Z,Hall.ROW_Z]+(p.inner as Array):
			add.call(Vector3(x0,0.0,z),Hall.COLUMN_R+0.15)
		var breach: Vector2i = p.breach
		for k in range(2):
			if Hall.BREACHES[breach[k]] != "": continue
			var z := (k*2-1)*Hall.WALL_Z
			var x := x0+0.6
			while x < x0+Hall.BAY:
				add.call(Vector3(x,0.0,z),0.75)
				x += 1.2
	return out

## The aqueduct's island in its gap: long along the run (its +X), the run
## crossing the line square, one arch over the line.
static func _aqueduct_isle(plan: Dictionary) -> Dictionary:
	var aq: Dictionary = plan.aqueduct
	var half: Vector2 = aq.half
	var r := sqrt(half.x*half.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(aq.seed)
	var spec := {"kind":"hills","radius":r,"outline":{"aspect":half.x/half.y,"heading":0.0,"drift":0.0,"bays":0,"lobes":0.4},
		"room":maxf(0.0,half.x*1.15+3.0-r*SkyIslet.REACH-SkyIslet.MARGIN),"dome":0.3,"mounds":[],
		"trees":Vector2i(2,4),"tree_pool":{"juniper":1.0,"tree":0.6},
		"rock":{"palette":"slate","tone":rng.randf_range(0.9,1.04),"vary":RockLooks.vary_of(int(aq.seed))},"keel":1.3}
	var shape: RefCounted = SkyIslet.author(int(aq.seed),spec)
	# The run: its last pier a metre in from the rim on +X, the snapped stub
	# out past it; the arch of span 1 over the line.
	var rim := float(shape.rim_radius(0.0))
	var last := rim-1.0
	var origin_x := last-Aqueduct.SPAN*AQ_SPANS
	var cross_x := origin_x+Aqueduct.SPAN*1.5
	var ground_cross: float = shape.ground_at(Vector2(cross_x,0.0))
	# Level the run's line: the ground along it eased to the crossing's.
	shape.claim(Vector2(cross_x,0.0),0.0,0.0,Vector2(Aqueduct.SPAN*AQ_SPANS*0.5+3.5,Aqueduct.DECK_WIDTH*0.5+1.4))
	var crossing: Vector3 = aq.crossing
	var basis := Basis(Vector3.UP,float(aq.yaw))
	# The island's middle so the crossing point sits on the line.
	var middle := crossing-basis*Vector3(cross_x,0.0,0.0)
	var offset := Vector3(middle.x,crossing.y-AQ_LINE-ground_cross,middle.z)
	aq.run = {"origin":Vector3(origin_x,ground_cross,0.0),"spans":AQ_SPANS,"crossing_x":cross_x}
	return {"name":"aqueduct","role":"aqueduct","seed":int(aq.seed),"shape":shape,"offset":offset,"yaw":float(aq.yaw),"features":[]}

# --- Far detail ------------------------------------------------------------------

## A member's far detail and what stands up with it (on a worker):
## {far: ArrayMesh, triangles}.
static func prepare(member: Dictionary, plan: Dictionary) -> Dictionary:
	if member.role == "aqueduct":
		var aq := _far_aqueduct(plan)
		return {"far":aq,"triangles":_tris(aq)}
	var piece: Dictionary = plan.pieces[int(member.piece)]
	var mesh := far(piece)
	return {"far":mesh,"triangles":_tris(mesh)}

static func _tris(mesh: ArrayMesh) -> int:
	var n := 0
	if mesh == null: return 0
	for s in range(mesh.get_surface_count()): n += mesh.surface_get_array_len(s)/3
	return n

## A piece's far detail, in its hall frame (see the header).
static func far(piece: Dictionary) -> ArrayMesh:
	var b := Build.new(int(piece.seed),0.0,"SunderedFar")
	b.lean = true
	b.path = piece.path if (piece.path as HallPath).curved() else null
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piece.seed)+7
	var plans: Array = piece.plans
	var bays := plans.size()
	var soffit := Hall.COLUMN_H+Hall.BEAM.x
	# The overgrowth's hint on its own stream (the stone's draw unchanged).
	var grow_rng := RandomNumberGenerator.new()
	grow_rng.seed = int(piece.seed)+77
	for i in range(bays):
		var p: Dictionary = plans[i]
		var x0 := i*Hall.BAY
		var torn: int = p.get("torn",0)
		var lines: Array = [0.0]
		if i == bays-1: lines.append(Hall.BAY)
		for x: float in lines:
			var torn_line: bool = (x == 0.0 and torn & 1 != 0) or (x > 0.0 and torn & 2 != 0)
			var zs: Array = [-Hall.ROW_Z,Hall.ROW_Z]
			if x == 0.0: zs.append_array(p.inner)
			for z: float in zs:
				var h := rng.randf_range(2.5,7.0) if torn_line else Hall.COLUMN_H
				_far_block(b,RuinKit._prism(FAR_SIDES,Hall.COLUMN_R*1.04,Hall.COLUMN_R,0.0,h),Vector3(x0+x,0.0,z),0.92)
			if (bool(p.beam) or x > 0.0) and not torn_line:
				_far_block(b,RuinKit._box(b,Vector3(Hall.BEAM.y,Hall.BEAM.x*0.5,Hall.WALL_Z)),Vector3(x0+x,Hall.COLUMN_H+Hall.BEAM.x*0.5,0.0),1.0)
				if (x == 0.0 and bool(p.gable)) or (x > 0.0 and bool(p.get("last_gable",false))):
					_far_block(b,_gable_planes(),Vector3(x0+x,soffit,0.0),0.98)
		# The roof strips.
		var edges := [-Hall.WALL_Z-0.5,-Hall.ROW_Z,-Hall.ROW_Z*0.5,0.0,Hall.ROW_Z*0.5,Hall.ROW_Z,Hall.WALL_Z+0.5]
		if p.roof != "open":
			var gone: Array = []
			if p.roof == "broken":
				while gone.size() < 2:
					var k := rng.randi_range(1,4)
					if not k in gone: gone.append(k)
			for k in range(6):
				if k in gone: continue
				var z0: float = edges[k]
				var z1: float = edges[k+1]
				_far_block(b,RuinKit._box(b,Vector3(Hall.BAY*0.5,Hall.SLAB*0.5,(z1-z0)*0.5),0.0),Vector3(x0+Hall.BAY*0.5,soffit+Hall.SLAB*0.5,(z0+z1)*0.5),0.96+rng.randf_range(-0.06,0.06))
		# The walls.
		var breach: Vector2i = p.breach
		var heads := Vector2.ZERO
		for k in range(2):
			var z := (k*2-1)*Hall.WALL_Z
			var kind: String = Hall.BREACHES[breach[k]]
			var high := Hall.ROOF_TOP+1.0
			if p.roof == "open": high = 7.5
			if torn != 0: high = 3.8
			if kind == "low": high = 1.4
			elif kind == "collapse": high = 0.8
			var half := Vector3(Hall.BAY*0.5,0.0,Hall.WALL_THICK*0.5)
			if kind in ["arch","door"]:
				var w: float = (Hall.ARCH.x if kind == "arch" else Hall.DOOR.x)*0.5
				var spring: float = Hall.ARCH.z if kind == "arch" else Hall.DOOR.z
				var side := (Hall.BAY*0.5-w)*0.5
				for s: float in [-1.0,1.0]:
					_far_block(b,RuinKit._box(b,Vector3(side,high*0.5,half.z),0.0),Vector3(x0+Hall.BAY*0.5+s*(w+side),high*0.5,z),0.94)
				var head := spring+w+0.5
				if high > head: _far_block(b,RuinKit._box(b,Vector3(w,(high-head)*0.5,half.z),0.0),Vector3(x0+Hall.BAY*0.5,(high+head)*0.5,z),0.94)
			else:
				_far_block(b,RuinKit._box(b,Vector3(half.x,high*0.5,half.z),0.0),Vector3(x0+Hall.BAY*0.5,high*0.5,z),0.94)
			heads[k] = high
		SunderedGrowth.far_bay(b,x0,heads,grow_rng)
	# The podium's faces.
	var length: float = piece.length
	for s: float in [-1.0,1.0]:
		var x := 0.0
		while x < length-0.1:
			var x1 := minf(x+Hall.BAY,length)
			var depth := PODIUM_COURSE*rng.randf_range(2.0,3.5)
			_far_block(b,RuinKit._box(b,Vector3((x1-x)*0.5,depth*0.5,0.6),0.0),Vector3((x+x1)*0.5,PODIUM_TOP-depth*0.5,s*PODIUM_Z),0.82)
			x = x1
	if piece.last: _far_apse(b,piece,rng)
	if int(plans[0].get("torn",0)) & 1 != 0: SunderedGrowth.far_torn(b,0.0,-1.0,PODIUM_TOP,Hall.WALL_Z,grow_rng)
	if int(plans[bays-1].get("torn",0)) & 2 != 0: SunderedGrowth.far_torn(b,length,1.0,PODIUM_TOP,Hall.WALL_Z,grow_rng)
	return _far_mesh(b)

## A far build's mesh (its node let go).
static func _far_mesh(b: Build) -> ArrayMesh:
	var node := b.finish()
	var mesh: ArrayMesh = (node.get_node("Mesh") as MeshInstance3D).mesh
	if mesh.has_meta("arrays"): mesh.remove_meta("arrays")
	node.free()
	return mesh

## One plain block of the far detail: `planes` stood at `at` (no wear, no
## growth, no hull), its stone toned `tone`.
static func _far_block(b: Build, planes: Array[Plane], at: Vector3, tone: float) -> void:
	b.solid(planes,Transform3D(Basis.IDENTITY,at),RuinKit._stone(b,tone),false,false,[],-1,1.0,false)

## A gable's planes over the roof beam's top at y 0: a triangle across the
## section, GABLE_RISE high, a course thick.
static func _gable_planes() -> Array[Plane]:
	var half := Hall.WALL_Z+0.4
	var rise := Hall.GABLE_RISE
	var out: Array[Plane] = [Plane(Vector3.DOWN,0.0),Plane(Vector3.RIGHT,0.6),Plane(Vector3.LEFT,0.6)]
	for s: float in [-1.0,1.0]:
		var n := Vector3(0.0,half,s*rise).normalized()
		out.append(Plane(n,n.dot(Vector3(0.0,rise,0.0))))
	return out

static func _far_apse(b: Build, piece: Dictionary, rng: RandomNumberGenerator) -> void:
	var length: float = piece.length
	for c: Vector3 in apse_columns(piece):
		_far_block(b,RuinKit._prism(FAR_SIDES,Hall.COLUMN_R*1.04,Hall.COLUMN_R,0.0,c.y),Vector3(c.x,0.0,c.z),0.92)
	var high := TOWER_HIGH.y
	_far_block(b,RuinKit._box(b,Vector3(TOWER_HALF,high*0.5,TOWER_HALF),0.0),Vector3(length+TOWER_AT.x,high*0.5,TOWER_AT.z),0.9)

## The apse's ring of columns past the hall's end (path space x, snapped
## height in y, z): a half ring round its middle, none on the line's way
## out (the lane's side, where the line climbs away).
static func apse_columns(piece: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piece.seed)+31
	var length: float = piece.length
	var out: Array = []
	var middle := Vector2(length+APSE_PAST,0.0)
	for k in range(7):
		var a := lerpf(-1.45,1.45,k/6.0)
		var p := middle+Vector2(cos(a),sin(a))*APSE_RADIUS
		if absf(p.y-Sundered.LANE_MID) < 4.6 and p.x > length: continue
		out.append(Vector3(p.x,rng.randf_range(3.0,8.5),p.y))
	return out

## The aqueduct's far detail, in the run's frame: its piers, its deck.
static func _far_aqueduct(plan: Dictionary) -> ArrayMesh:
	var b := Build.new(int(plan.aqueduct.seed),0.0,"AqueductFar")
	b.lean = true
	var spans: int = plan.aqueduct.run.spans
	for i in range(spans+1):
		_far_block(b,RuinKit._box(b,Vector3(Aqueduct.PIER.x*0.5,Aqueduct.DECK*0.5,Aqueduct.PIER.y*0.5),0.0),Vector3(Aqueduct.SPAN*i,Aqueduct.DECK*0.5-1.0,0.0),0.94)
	var length := Aqueduct.SPAN*spans
	_far_block(b,RuinKit._box(b,Vector3(length*0.5,1.4,Aqueduct.DECK_WIDTH*0.5),0.0),Vector3(length*0.5,Aqueduct.DECK-1.0,0.0),0.98)
	return _far_mesh(b)

# --- Near detail -----------------------------------------------------------------

## A piece's near detail, in its hall frame (on a worker): the kit's bays
## at in-world detail, the podium, the torn ends, the apse; merged.
static func near(piece: Dictionary) -> Node3D:
	RuinKit.set_detail(Hall.IN_WORLD)
	var root := Node3D.new()
	root.name = "SunderedNear%d" % int(piece.index)
	var path: HallPath = piece.path
	var curved := path.curved()
	var plans: Array = piece.plans
	var seed_value: int = piece.seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[],"breaches":[],"doors":[],"open":[]}
	var growth: float = SunderedGrowth.ACTS.get(piece.act,1.0)
	for i in range(plans.size()):
		var x0 := Hall.BAY*i
		# The overgrowth (scripts/sundered_growth.gd) dresses each bay.
		var bay_plan: Dictionary = plans[i]
		if SunderedGrowth.amount > 0.0:
			bay_plan = bay_plan.duplicate()
			bay_plan.growth = growth
			bay_plan.dress = func(b: Build, p: Dictionary) -> void: SunderedGrowth.bay(b,p)
		var node := Hall.bay(seed_value*31+i,clampf(Sundered.WEATHERED+rng.randf_range(-0.12,0.12),0.0,1.0),bay_plan,Callable(),path.shifted(x0) if curved else null)
		node.name = "Bay%d" % i
		if not curved: node.position.x = x0
		root.add_child(node)
		var w: Dictionary = node.get_meta("weave")
		for key: String in weave:
			for item: Variant in w[key]: weave[key].append(Hall._moved(item,Vector3(x0,0.0,0.0)))
	root.add_child(_podium(piece))
	if piece.last: root.add_child(_apse(piece))
	RuinKit.merge(root)
	RuinKit.forget_arrays(root)
	_chunk_body(root)
	root.set_meta("weave",weave)
	root.set_meta("path",path)
	RuinKit.set_detail(1.0)
	return root

## Splits a built ruin's one body into bodies of at most CHUNK hulls each
## (RUIN_LAYER), held out of the tree in the root's "bodies" meta: stood
## one a frame (`advance`), so no frame takes in thousands of hulls.
static func _chunk_body(root: Node3D) -> void:
	var body := root.get_node_or_null("Body") as StaticBody3D
	var chunks: Array = []
	if body != null:
		root.remove_child(body)
		var shapes := body.get_children()
		var k := 0
		while k < shapes.size():
			var chunk := StaticBody3D.new()
			chunk.name = "Body%d" % chunks.size()
			chunk.collision_layer = RUIN_LAYER
			chunk.collision_mask = 0
			for j in range(k,mini(k+CHUNK,shapes.size())):
				body.remove_child(shapes[j])
				chunk.add_child(shapes[j])
			chunks.append(chunk)
			k += CHUNK
		body.free()
	root.set_meta("bodies",chunks)

## The podium the hall stands on (path space, bent with the path): coursed
## faces down each side under the floor, two to four courses, its torn
## ends hanging ragged over the sky with paving slabs tipping off the edge.
static func _podium(piece: Dictionary) -> Node3D:
	var b := Build.new(int(piece.seed)+5,Sundered.WEATHERED,"Podium")
	b.lean = true
	b.cull = true
	b.settle = Hall.SETTLE
	var path: HallPath = piece.path
	b.path = path if path.curved() else null
	var length: float = piece.length
	b.shelter = func(_p: Vector3, _n: Vector3) -> float: return 0.0
	# No ground under it as built: its faces all stand below the floor (y 0),
	# which Build takes as buried with no terrain (they were culled), and
	# its vines hang on down past them.
	b.terrain = func(_x: float, _z: float) -> float: return -1000.0
	for s: float in [-1.0,1.0]:
		var x := 0.0
		while x < length-0.3:
			var run := minf(PODIUM_BLOCK*b.rng.randf_range(0.8,1.25),length-x)
			var n := b.rng.randi_range(PODIUM_COURSES.x,PODIUM_COURSES.y)
			for k in range(n):
				var y := PODIUM_TOP-(k+0.5)*PODIUM_COURSE
				var lost := k == n-1 and b.rng.randf() < 0.35
				if lost: continue
				b.solid(RuinKit._box(b,Vector3(run*0.5-0.02,PODIUM_COURSE*0.5-0.01,0.7)),RuinKit._settle(b,Vector3(x+run*0.5,y,s*PODIUM_Z),0.4),RuinKit._stone(b,0.86))
			x += run
	# The core's underside, seen from under a torn end.
	var x2 := 0.0
	while x2 < length-0.3:
		var run2 := minf(Hall.BAY,length-x2)
		b.solid(RuinKit._box(b,Vector3(run2*0.5,0.6,PODIUM_Z-0.6),0.0),Transform3D(Basis.IDENTITY,Vector3(x2+run2*0.5,PODIUM_TOP-PODIUM_COURSE*2.0-0.6,0.0)),RuinKit._stone(b,0.8),false,false,[],-1,1.0,false)
		x2 += run2
	var plans: Array = piece.plans
	var torn_start := int(plans[0].get("torn",0)) & 1 != 0
	var torn_end := int(plans[plans.size()-1].get("torn",0)) & 2 != 0
	if torn_start: _torn(b,0.0,-1.0)
	if torn_end: _torn(b,length,1.0)
	# The overgrowth: ivy down the faces, long vines off the torn lips.
	var growth: float = SunderedGrowth.ACTS.get(piece.act,1.0)
	SunderedGrowth.podium(b,length,PODIUM_TOP,PODIUM_Z+0.7,growth)
	if torn_start: SunderedGrowth.torn(b,0.0,-1.0,PODIUM_TOP,Hall.WALL_Z,growth)
	if torn_end: SunderedGrowth.torn(b,length,1.0,PODIUM_TOP,Hall.WALL_Z,growth)
	return b.finish()

## A torn end at path x `x` (`out` +1 past it, -1 before it): the podium's
## end in hanging stacks of blocks, ragged, deeper here and there; paving
## slabs tipping off the edge; a few blocks hung under the lip.
static func _torn(b: Build, x: float, out: float) -> void:
	var z := -PODIUM_Z
	while z < PODIUM_Z:
		var w := PODIUM_BLOCK*b.rng.randf_range(0.7,1.2)
		var n := b.rng.randi_range(1,5)
		for k in range(n):
			var y := PODIUM_TOP-(k+0.5)*PODIUM_COURSE
			var stick := b.rng.randf_range(-0.6,0.9)*out
			b.solid(RuinKit._box(b,Vector3(0.7,PODIUM_COURSE*0.5-0.01,w*0.5-0.02)),RuinKit._settle(b,Vector3(x-out*0.7+stick,y,z+w*0.5),0.8),RuinKit._stone(b,0.84),true,true,[],-1,1.6)
		z += w
	# Paving slabs tipping off the edge, and stones hung under it.
	for k in range(b.rng.randi_range(4,7)):
		var at := Vector3(x+out*b.rng.randf_range(-0.4,0.8),0.0,b.rng.randf_range(-Hall.WALL_Z+1.0,Hall.WALL_Z-1.0))
		var tip := b.rng.randf_range(0.18,0.6)
		var lie := Basis(Vector3.UP,b.rng.randf_range(-0.3,0.3))*Basis(Vector3.BACK,-tip*out)
		at.y = -0.1-sin(tip)*0.8
		b.solid(RuinKit._box(b,Vector3(b.rng.randf_range(0.8,1.3),Hall.PAVING.x,b.rng.randf_range(0.7,1.2))),Transform3D(lie,at),RuinKit._stone(b,1.0),true,true,[],-1,1.4)
	for k in range(b.rng.randi_range(3,6)):
		var at := Vector3(x+out*b.rng.randf_range(0.0,1.2),PODIUM_TOP-PODIUM_COURSE*b.rng.randf_range(3.0,5.2),b.rng.randf_range(-PODIUM_Z+1.0,PODIUM_Z-1.0))
		var lie := Basis(Vector3(b.rng.randf_range(-1,1),0.2,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.2,0.7))
		b.solid(RuinKit._box(b,Vector3(b.rng.randf_range(0.4,0.8),b.rng.randf_range(0.3,0.6),b.rng.randf_range(0.4,0.8))),Transform3D(lie,at),RuinKit._stone(b,0.82),false,true,[],-1,2.0)

## The apse past the last bay: its ring of snapped columns, paving under
## it, and the snapped tower beside the end (path space; straight past
## the end, as the path runs on).
static func _apse(piece: Dictionary) -> Node3D:
	var b := Build.new(int(piece.seed)+9,Sundered.WEATHERED,"Apse")
	b.settle = Hall.SETTLE
	b.lean = true
	b.cull = true
	b.ground = -0.3
	var path: HallPath = piece.path
	var end := path.xform(float(piece.length))
	b.frame = end*Transform3D(Basis.IDENTITY,Vector3(-float(piece.length),0.0,0.0))
	for c: Vector3 in apse_columns(piece):
		b.rigid = true
		Hall._column(b,Transform3D(Basis.IDENTITY,Vector3(c.x,0.0,c.z)),Hall.COLUMN_H,c.y)
		b.rigid = false
		RuinKit._drift(b,Vector3(c.x+b.rng.randf_range(-1.5,1.5),0.0,c.z+b.rng.randf_range(-1.5,1.5)),1.4,4)
	# The tower: four walls, its head torn ragged, an arch in its face to
	# the nave, a great notch torn out of one side.
	var length: float = piece.length
	var middle := Vector3(length+TOWER_AT.x,0.0,TOWER_AT.z)
	var high := b.rng.randf_range(TOWER_HIGH.x,TOWER_HIGH.y)
	for k in range(4):
		var turn := Basis(Vector3.UP,PI*0.5*k)
		var pose := Transform3D(turn,middle+turn*Vector3(0.0,0.0,TOWER_HALF))
		var h := high*b.rng.randf_range(0.72,1.0)
		var opening := Hall.ARCH if k == 0 else (Hall.LANCET if k == 2 else Vector4.ZERO)
		Hall._wall(b,pose,TOWER_HALF+0.6,h,opening,h*b.rng.randf_range(0.45,0.7))
	RuinKit._drift(b,middle+Vector3(TOWER_HALF+2.0,0.0,1.0),2.4,10)
	var f := b.frame
	b.frame = Transform3D.IDENTITY
	SunderedGrowth.apse(b,f,middle,TOWER_HALF,high,apse_columns(piece),SunderedGrowth.ACTS.get("apse",1.0))
	return b.finish()

## The aqueduct's near detail in its island's frame (on a worker): the
## run (its head, AQ_SPANS spans) on the island's ground, and the snapped
## stub past its last pier; {node, lip (where its water leaves, island
## frame), out}.
static func near_aqueduct(plan: Dictionary, shape: RefCounted) -> Node3D:
	RuinKit.set_detail(Hall.IN_WORLD)
	var run_info: Dictionary = plan.aqueduct.run
	var origin: Vector3 = run_info.origin
	var ground := func(x: float, z: float) -> float:
		var p := Vector2(origin.x+x,z)
		return (float(shape.ground_at(p)) if shape.on_land(p) else origin.y-4.0)-origin.y
	var root := Node3D.new()
	root.name = "AqueductNear"
	var run := Aqueduct.run(int(plan.aqueduct.seed),Sundered.WEATHERED,int(run_info.spans),-1,true,ground,true)
	root.add_child(run)
	var length := Aqueduct.SPAN*int(run_info.spans)
	var b := Build.new(int(plan.aqueduct.seed)+3,Sundered.WEATHERED,"AqueductStub")
	b.settle = Aqueduct.SETTLE
	Aqueduct._deck(b,length,length+AQ_STUB,Aqueduct.DECK,Callable(),true)
	var stub := b.finish()
	Aqueduct._water(stub,length-0.2,length+AQ_STUB-0.3,Aqueduct.DECK+Aqueduct.WATER)
	root.add_child(stub)
	RuinKit.merge(root)
	RuinKit.forget_arrays(root)
	_chunk_body(root)
	root.position = origin
	RuinKit.set_detail(1.0)
	return root

# --- Standing and streaming ------------------------------------------------------

## Stands a member's far detail (and, for the aqueduct, its water's fall to
## the sea) under its island's node; gives the live record of the piece.
static func furnish(node: Node3D, member: Dictionary, plan: Dictionary, made: Dictionary, home_y: float) -> Dictionary:
	var far_node := MeshInstance3D.new()
	far_node.name = "HallFar"
	far_node.mesh = made.far
	far_node.set_meta("skip_reflection",true)
	node.add_child(far_node)
	var live := {"node":node,"member":member,"far":far_node,"near":null,"task":-1,"out":{},"samples":[]}
	if member.role == "aqueduct":
		var origin: Vector3 = plan.aqueduct.run.origin
		far_node.position = origin
		var length := Aqueduct.SPAN*int(plan.aqueduct.run.spans)
		var lip := origin+Vector3(length+AQ_STUB-0.35,Aqueduct.DECK+Aqueduct.WATER-0.02,0.0)
		var spill := Node3D.new()
		spill.name = "AqueductSpill"
		node.add_child(spill)
		var foot := Aqueduct._spill(spill,lip,Vector3.RIGHT,int(plan.aqueduct.seed),lip.y-14.0)
		var sea := SkyFallThread.SEA-home_y-float((member.offset as Vector3).y)
		var thread := SkyFallThread.plan(lip,Vector3.RIGHT,Aqueduct.CHANNEL*0.32,sea,int(plan.aqueduct.seed),13.0,1.0,0.4)
		spill.add_child(SkyFallThread.node_from(thread))
		live.samples = [node.position]
	else:
		far_node.transform = member.hall
		var piece: Dictionary = plan.pieces[int(member.piece)]
		var path: HallPath = piece.path
		var s := 0.0
		while s <= float(piece.length)+0.1:
			live.samples.append(member.hall*path.point(Vector3(s,0.0,0.0)))
			s += Hall.BAY*2.0
	return live

## Each frame for a standing sundered cluster: near detail built for the
## nearest piece within NEAR_BUILD (one task at a time), stood when made
## (within the frame budget), shown within NEAR_SHOW, let go past
## NEAR_FORGET. `eye` in home coordinates (the islets' own frame, where
## their nodes stand).
static func advance(lives: Array, plan: Dictionary, eye: Vector3) -> void:
	# Held near everywhere (captures: plan "keep_near").
	if plan.get("keep_near",false): return
	var busy := false
	for live: Dictionary in lives:
		if int(live.task) >= 0: busy = true
	var nearest: Variant = null
	var best := INF
	for live: Dictionary in lives:
		var node: Node3D = live.node
		if not is_instance_valid(node): continue
		var d := _distance(live,eye)
		live.distance = d
		if int(live.task) >= 0 and WorkerThreadPool.is_task_completed(live.task):
			if SkyCommits.open():
				WorkerThreadPool.wait_for_task_completion(live.task)
				live.task = -1
				var began := Time.get_ticks_usec()
				_stand_near(live)
				SkyCommits.spend("sundered",Time.get_ticks_usec()-began)
		if not (live.get("bodies",[]) as Array).is_empty() and SkyCommits.open():
			var began_body := Time.get_ticks_usec()
			_stand_body(live)
			SkyCommits.spend("sundered body",Time.get_ticks_usec()-began_body)
		var near_node: Variant = live.near
		if near_node != null and is_instance_valid(near_node):
			var show := d < NEAR_SHOW
			(near_node as Node3D).visible = show
			(live.far as Node3D).visible = not show
			if d > NEAR_FORGET:
				(near_node as Node3D).queue_free()
				for chunk: Node in live.get("bodies",[]): chunk.free()
				live.bodies = []
				live.near = null
				(live.far as Node3D).visible = true
		elif near_node == null and int(live.task) < 0 and d < NEAR_BUILD and d < best:
			best = d
			nearest = live
	if not busy and nearest != null: _start_near(nearest,plan)

static func _distance(live: Dictionary, eye: Vector3) -> float:
	var node: Node3D = live.node
	var local := node.transform.affine_inverse()*eye
	var best := INF
	for p: Vector3 in live.samples:
		best = minf(best,local.distance_to(p) if live.member.role != "aqueduct" else local.length())
	return best

static func _start_near(live: Dictionary, plan: Dictionary) -> void:
	var member: Dictionary = live.member
	var out := {}
	live.out = out
	if member.role == "aqueduct":
		var shape: RefCounted = member.shape
		live.task = WorkerThreadPool.add_task(func() -> void: out.node = near_aqueduct(plan,shape),false,"Sundered aqueduct")
	else:
		var piece: Dictionary = plan.pieces[int(member.piece)]
		live.task = WorkerThreadPool.add_task(func() -> void:
			var began := Time.get_ticks_usec()
			out.node = near(piece)
			out.usec = Time.get_ticks_usec()-began,false,"Sundered piece")

## Builds a member's near detail now, on this thread (tests, captures).
static func build_now(live: Dictionary, plan: Dictionary) -> void:
	if live.near != null: return
	if int(live.task) >= 0:
		WorkerThreadPool.wait_for_task_completion(live.task)
		live.task = -1
	else:
		_start_near(live,plan)
		WorkerThreadPool.wait_for_task_completion(live.task)
		live.task = -1
	_stand_near(live)
	while _stand_body(live): pass

static func _stand_near(live: Dictionary) -> void:
	var node: Node3D = live.node
	var made: Variant = (live.out as Dictionary).get("node")
	if made == null or not is_instance_valid(node):
		if made != null: (made as Node).free()
		return
	var near_node: Node3D = made
	if live.member.role != "aqueduct": near_node.transform = live.member.hall
	node.add_child(near_node)
	live.near = near_node
	live.bodies = (near_node.get_meta("bodies",[]) as Array).duplicate()
	near_node.remove_meta("bodies")
	live.build_usec = int((live.out as Dictionary).get("usec",0))
	live.out = {}

## Stands the next of a near piece's pending body chunks; false when none
## is left.
static func _stand_body(live: Dictionary) -> bool:
	var pending: Array = live.get("bodies",[])
	if pending.is_empty() or live.near == null or not is_instance_valid(live.near): return false
	(live.near as Node3D).add_child(pending.pop_back())
	return true

## Lets a cluster's live pieces go (waits on their workers).
static func release(lives: Array) -> void:
	for live: Dictionary in lives:
		if int(live.task) >= 0:
			WorkerThreadPool.wait_for_task_completion(live.task)
			live.task = -1
			var made: Variant = (live.out as Dictionary).get("node")
			if made != null:
				for chunk: Node in (made as Node).get_meta("bodies",[]): chunk.free()
				(made as Node).free()
		for chunk: Node in live.get("bodies",[]): chunk.free()
		live.bodies = []
