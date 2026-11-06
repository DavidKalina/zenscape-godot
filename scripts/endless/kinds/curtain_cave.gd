extends RefCounted
## The space behind a curtain (scripts/endless/kinds/curtain.gd): the cave
## through the hill from behind the sheet to the exit's gully, as its land
## lays it out (curtain_land.gd `cave_at`, `cave_point`, `cave_roof`). The
## chunks draw the hill whole over it with holes in its two faces; this piece
## draws its rock (a tube of the cave's section along its path, in the land's
## rock look: the ground material with no turf, RockShape's carved shape) and
## the faces round its two mouths over the holes, and holds them solid:
## a StaticBody on layer 1 (the near misses' rays) and meta `solid` (a
## BoxSolid of the rock over the cave's roof, up to the hill's drawn surface:
## placed_sites.gd hands it to the flight's crash test). The land field has
## the cave as a trench, so its floor and walls are the field's.
##
## Built on the main thread with the site's field (LandField `surface`).

const Land = preload("res://scripts/endless/kinds/curtain_land.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

## The section's points: FLOOR_SEGS across the floor, WALL_SEGS up each wall,
## ARCH_SEGS over the roof; a ring every RING m along the path.
const FLOOR_SEGS := 6
const WALL_SEGS := 3
const ARCH_SEGS := 12
const RING := 2.5
## The walls and roof stand back into the rock by up to BUMP m (never into
## the cave: the field's walls and the roof's solid are its plain section),
## in lumps LUMP m along.
const BUMP := 0.8
const LUMP := 7.0
## Each mouth's face reaches FACE_PAD m past the cave's sides, stands
## FACE_PROUD m out of the hill's face and stops FACE_UNDER m under its top.
## The hill's top edge over a face is read FACE_TOP m back from its strip;
## a face is found STEP m at a time along the path, then REFINE halvings.
const FACE_PAD := 3.0
const FACE_PROUD := 0.3
## A face is FACE_BANDS bands from the rim out to its edge, each ring laid
## on the hill, so it follows the hill's face rather than cutting a chord
## behind it (where the chunk's cliff triangles stood in front as teeth).
const FACE_BANDS := 4
const FACE_UNDER := 0.3
const FACE_TOP := 0.6
const STEP := 1.0
const REFINE := 3
## The roof's solid: columns COLUMN m square.
const COLUMN := 1.0
const LAYER := 1
const ROCK := Color(0.5,0.46,0.42)

static var _bare := {}

## Adds the cave of shape `c` (curtain_land.gd) to curtain `root` (its frame
## the site's: origin the foot, -Z its heading).
static func build(root: Node3D, site: Dictionary, c: PackedFloat32Array) -> void:
	if not Land.has_cave(c): return
	var field: Object = site.get("field")
	var foot_y := c[Land.I_Y]
	var section := _section(c)
	var length := Land.cave_length(c)
	var surface := func(q: Vector2) -> float:
		# The hill's drawn height at site-frame q (s, f), over the foot.
		var w := _world(c,q)
		return (float(field.surface(w.x,w.y)) if field != null else c[Land.I_LIP])-foot_y
	var floor_y := c[Land.I_CAVE_FLOOR]-foot_y
	var top_a := _tops(c,surface,Land.WALL+FACE_TOP)
	var top_b := _tops(c,surface,length-Land.WALL-FACE_TOP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	# The rings: the first and last cut by their faces.
	var rings: Array[PackedVector3Array] = []
	var ts: Array[float] = [0.0]
	var k := 1
	while k*RING < length-Land.WALL-0.5:
		if k*RING > Land.WALL+0.5: ts.append(k*RING)
		k += 1
	ts.append(length)
	for i in ts.size():
		var ring := PackedVector3Array()
		for j in section.size():
			var pt: Vector3 = section[j]
			var t: float = ts[i]
			var bump := 0.0
			if i == 0: t = _face_t(c,surface,pt.x,pt.y,false)
			elif i == ts.size()-1: t = _face_t(c,surface,pt.x,pt.y,true)
			else: bump = _bump(t,pt.z)
			ring.append(_at(c,t,Vector2(pt.x,pt.y)+Vector2(pt.x,pt.y-floor_y).normalized()*bump*pt.z if pt.z > 0.0 else Vector2(pt.x,pt.y)))
		rings.append(ring)
	for i in rings.size()-1:
		for j in section.size()-1:
			_quad(st,faces,rings[i][j],rings[i+1][j],rings[i+1][j+1],rings[i][j+1])
	# The faces round each mouth.
	_face(st,faces,c,surface,section,rings[0],top_a,false)
	_face(st,faces,c,surface,section,rings[rings.size()-1],top_b,true)
	st.index()
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	var colours := PackedColorArray()
	colours.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colours.fill(ROCK)
	arrays[Mesh.ARRAY_COLOR] = colours
	RockShape.bake(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},RockShape.format(arrays))
	mesh.surface_set_material(0,_material(site))
	var mi := MeshInstance3D.new()
	mi.name = "Cave"
	mi.mesh = mesh
	# Both sides: the hill over it is the chunks', so the cave's own rock
	# keeps the sun out.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "CaveBody"
	body.collision_layer = LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# The rays meet its faces from inside (their back, to physics).
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	root.set_meta("solid",_solid(c,surface,floor_y))
	root.set_meta("cave",{"tris":faces.size()/3,"rings":rings.size(),"length":length})

## The section (x: u, y: over the foot, z: 1 where it may stand back into
## the rock, 0 on the floor): from the floor's left corner up the left wall,
## over the arch, down the right wall, back across the floor.
static func _section(c: PackedFloat32Array) -> PackedVector3Array:
	var half := c[Land.I_CAVE_HALF]
	var tall := c[Land.I_CAVE_TALL]
	var wall := tall*Land.WALL_SHARE
	var y0 := c[Land.I_CAVE_FLOOR]-c[Land.I_Y]
	var out := PackedVector3Array()
	for i in WALL_SEGS:
		out.append(Vector3(-half,y0+wall*i/WALL_SEGS,0.0 if i == 0 else 1.0))
	for i in ARCH_SEGS+1:
		var a := PI-PI*i/ARCH_SEGS
		out.append(Vector3(half*cos(a),y0+wall+(tall-wall)*sin(a),1.0))
	for i in range(WALL_SEGS-1,-1,-1):
		out.append(Vector3(half,y0+wall*i/WALL_SEGS,0.0 if i == 0 else 1.0))
	for i in range(1,FLOOR_SEGS+1):
		out.append(Vector3(half-2.0*half*i/FLOOR_SEGS,y0,0.0))
	return out

## How far the rock stands back at `t` m along, round the section at height
## `y` (a smooth lump field; 0 near the mouths, where the faces meet it).
static func _bump(t: float, w: float) -> float:
	var v := 0.5+0.3*sin(t/LUMP*TAU*0.61+1.3)+0.2*sin(t/LUMP*TAU*1.37+w*2.1)
	return BUMP*clampf(v,0.0,1.0)

## The point `t` m along the path, `q` (u, y over the foot) on its section,
## in the piece's frame (x s, z -f).
static func _at(c: PackedFloat32Array, t: float, q: Vector2) -> Vector3:
	var p: Array = Land.cave_point(c,t)
	var at: Vector2 = p[0]+(p[2] as Vector2)*q.x
	return Vector3(at.x,q.y,-at.y)

## World (x, z) of site-frame point q (s, f).
static func _world(c: PackedFloat32Array, q: Vector2) -> Vector2:
	var fwd := Vector2(c[Land.I_FX],c[Land.I_FZ])
	var right := Vector2(-fwd.y,fwd.x)
	return Vector2(c[Land.I_X],c[Land.I_Z])+right*q.x+fwd*q.y

## The hill's drawn height over the foot along a face's top edge, `t` m
## along the path: [u0, du, heights] across FACE_PAD past the cave's sides.
static func _tops(c: PackedFloat32Array, surface: Callable, t: float) -> Array:
	var w := c[Land.I_CAVE_HALF]+FACE_PAD
	var hs := PackedFloat32Array()
	var n := 16
	for i in n+1:
		var u := -w+2.0*w*i/n
		var p: Array = Land.cave_point(c,t)
		hs.append(float(surface.call(p[0]+(p[2] as Vector2)*u)))
	return [-w,2.0*w/n,hs]

static func _top(tops: Array, u: float) -> float:
	var hs: PackedFloat32Array = tops[2]
	var k := clampf((u-float(tops[0]))/float(tops[1]),0.0,hs.size()-1.001)
	var i := floori(k)
	return lerpf(hs[i],hs[i+1],k-i)

## Where a face stands at height `y` (over the foot), `u` m off the path:
## the first point in from the open side (the mouth's, the exit's) where
## the hill's drawn height reaches it, FACE_PROUD out from there.
static func _face_t(c: PackedFloat32Array, surface: Callable, u: float, y: float, exit: bool) -> float:
	var foot := Land.cave_length(c)
	var start := -0.5 if not exit else foot+0.5
	var last := Land.WALL+Land.WALL*0.5 if not exit else foot-Land.WALL*1.5
	var way := 1.0 if not exit else -1.0
	var reached := func(at: float) -> bool:
		var p: Array = Land.cave_point(c,at)
		return float(surface.call(p[0]+(p[2] as Vector2)*u)) >= y+0.05
	var t := start
	while (t < last) if not exit else (t > last):
		if reached.call(t):
			if t != start:
				# Between the last step short of it and this one.
				var short := t-STEP*way
				for i in REFINE:
					var mid := (short+t)*0.5
					if reached.call(mid): t = mid
					else: short = mid
			break
		t += STEP*way
	return t+FACE_PROUD if exit else t-FACE_PROUD

## A face round a mouth: from the mouth's rim (`ring`, its section's points
## but the floor) out to FACE_PAD past the sides and up to the hill's top
## edge, laid on the hill's face FACE_PROUD out of it.
static func _face(st: SurfaceTool, faces: PackedVector3Array, c: PackedFloat32Array, surface: Callable, section: PackedVector3Array, ring: PackedVector3Array, tops: Array, exit: bool) -> void:
	var m := section.size()-FLOOR_SEGS
	var w := c[Land.I_CAVE_HALF]+FACE_PAD
	var y0: float = section[0].y
	var left := _top(tops,-w)-FACE_UNDER-y0
	var right := _top(tops,w)-FACE_UNDER-y0
	var span := left+2.0*w+right
	var inner_len := 0.0
	for j in m-1: inner_len += Vector2(section[j+1].x-section[j].x,section[j+1].y-section[j].y).length()
	var run := 0.0
	var edge: Array[Vector2] = []
	for j in m:
		if j > 0: run += Vector2(section[j].x-section[j-1].x,section[j].y-section[j-1].y).length()
		var d := run/inner_len*span
		var q: Vector2
		if d <= left: q = Vector2(-w,y0+d)
		elif d <= left+2.0*w:
			var u := -w+(d-left)
			q = Vector2(u,_top(tops,u)-FACE_UNDER)
		else: q = Vector2(w,y0+right-(d-left-2.0*w))
		edge.append(q)
	var inner := ring
	for b in range(1,FACE_BANDS+1):
		var outer := PackedVector3Array()
		for j in m:
			var q := Vector2(section[j].x,section[j].y).lerp(edge[j],float(b)/FACE_BANDS)
			outer.append(_at(c,_face_t(c,surface,q.x,q.y,exit),q))
		for j in m-1:
			if exit: _quad(st,faces,inner[j],outer[j],outer[j+1],inner[j+1])
			else: _quad(st,faces,outer[j],inner[j],inner[j+1],outer[j+1])
		inner = outer

## A quad a, b, c, d (its front the cave's side), into `st` and `faces`.
static func _quad(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a,c,b,a,d,c]:
		st.add_vertex(v)
		faces.append(v)

## The rock over the cave's roof up to the hill's drawn surface, as BoxSolid
## columns in the piece's frame: {g, reach}.
static func _solid(c: PackedFloat32Array, surface: Callable, floor_y: float) -> Dictionary:
	var half := c[Land.I_CAVE_HALF]
	var length := Land.cave_length(c)
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var t := 0.0
	while t <= length:
		for u: float in [-half,half]:
			var p: Array = Land.cave_point(c,t)
			var q: Vector2 = p[0]+(p[2] as Vector2)*u
			lo = lo.min(q)
			hi = hi.max(q)
		t += 1.0
	var boxes: Array = []
	var reach := 0.0
	var s := floorf(lo.x)
	while s < hi.x+1.0:
		var f := floorf(lo.y)
		while f < hi.y+1.0:
			var q := Vector2(s+COLUMN*0.5,f+COLUMN*0.5)
			var tu := Land.cave_at(c,q)
			if not is_nan(tu.x) and tu.x >= 0.0 and tu.x <= length and absf(tu.y) < half:
				var bottom := floor_y+Land.cave_roof(c,tu.y)
				var top := float(surface.call(q))
				if top > bottom:
					boxes.append(AABB(Vector3(s,bottom,-f-COLUMN),Vector3(COLUMN,top-bottom,COLUMN)))
					reach = maxf(reach,q.length()+COLUMN)
			f += COLUMN
		s += COLUMN
	return {"g":BoxSolid.build(boxes),"reach":reach,"boxes":boxes.size()}

## The land's rock with no turf (as LandRocks `bare`), from the site's
## ground material (placed_sites.gd); a plain one without it.
static func _material(site: Dictionary) -> Material:
	var ground: Material = site.get("ground")
	if ground is ShaderMaterial:
		if not _bare.has(ground):
			var b := (ground as ShaderMaterial).duplicate() as ShaderMaterial
			b.set_shader_parameter("rock_up",1.2)
			b.set_shader_parameter("thin_up",1.3)
			b.set_shader_parameter("peak_ice_solid",-1.0)
			_bare[ground] = b
		return _bare[ground]
	var plain := StandardMaterial3D.new()
	plain.vertex_color_use_as_albedo = true
	plain.vertex_color_is_srgb = true
	plain.roughness = 1.0
	return plain
