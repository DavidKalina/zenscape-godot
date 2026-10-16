extends RefCounted
## Turf lips: the turf's edge rolled over where the ground drops away, over
## a crag's top and round an isle's rim, so the turf ends as sod hanging
## over the drop instead of a cut, with now and then a root hanging under
## it (HangingRoots). Read from a KitLand land's drawn meshes ("Ground"
## and "Crags", land-local): a turf face's edge that no other turf face
## shares, where the rock under it falls at least MIN_DROP or where it runs
## along the outline. Each such edge hangs a lip out along the way it
## faces: a top in the ground's own material and tone, rolling over a
## crest and down a ragged face of earth in the rock's (unweathered), its
## reach and droop from a noise of world position, so neighbouring edges
## meet. Drawn only: never collided, no shadows.
##
##   TurfLips.dress(land, seed)   adds "TurfLips" (and "LipRoots") under land

const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")

## A lip's samples along its edge (m).
const STEP := 0.45
## How far a lip reaches out past the edge (m), least to most.
const REACH := Vector2(0.14, 0.38)
## How far its face hangs down below the turf (m), least to most.
const DROOP := Vector2(0.22, 0.6)
## Now and then a tongue of sod hangs this much lower (m).
const TONGUE := 0.25
## How far a lip's top starts back on the turf (m), covering the seam.
const BACK := 0.12
## The least fall under a turf edge (m) that makes it a crag's top.
const MIN_DROP := 0.6
## An outline edge: within this of the land's outline (m).
const RIM_NEAR := 0.6
## The earth under the sod (linear) and the sod's dark band under its crest.
const EARTH := Color(0.045, 0.032, 0.022)
const SOD_DARK := 0.16
## The roll over the crest, a little darker than the turf it carries on.
const ROLL_DARK := 0.5
## Each sample's own tear: reach, droop (m, either way of the noise's).
const JITTER := Vector2(0.12, 0.3)
## The tatters under a lip's foot: torn sod and grass hanging in strands,
## this many to a sample, this long (m).
const TATTERS := 3
const TATTER_LONG := Vector2(0.08, 0.38)
## Share of a hem's strands torn away.
const TATTER_GAP := 0.4
## Roots under the lips over a fall of at least this (m), about this far apart.
const ROOT_DROP := 2.5
const ROOT_APART := 5.5
const ROOT_LONG := Vector2(1.2, 3.8)

static var _lip_material: ShaderMaterial

## The lips (and their roots) under `land`; the lips' node, or null with none.
static func dress(land: Node3D, seed_value: int) -> Node3D:
	var ground := land.get_node_or_null("Ground") as MeshInstance3D
	if ground == null or ground.mesh == null: return null
	var crags := land.get_node_or_null("Crags") as MeshInstance3D
	var outline: Variant = land.get_meta("outline", null)
	var edges := rim_edges(ground.mesh, crags.mesh if crags != null else null, outline)
	if edges.is_empty(): return null
	var built := _build(edges)
	var holder := Node3D.new()
	holder.name = "TurfLips"
	land.add_child(holder)
	holder.add_child(_drawn("Sod", built.top, KitLook.ground_material()))
	holder.add_child(_drawn("Face", built.face, lip_material()))
	if not built.roots.is_empty():
		var roots := HangingRoots.batch(built.roots, seed_value)
		roots.name = "LipRoots"
		holder.add_child(roots)
	holder.set_meta("edges", edges.size())
	return holder

## The rock's material, unweathered: the lip's face is earth, not basalt.
static func lip_material() -> ShaderMaterial:
	if _lip_material == null:
		_lip_material = KitLook.rock_material().duplicate()
		_lip_material.set_shader_parameter("stone_weather", 0.0)
	return _lip_material

## The turf's edges over a drop: [a, b, out (x, z), tone a, tone b, fall].
static func rim_edges(ground: Mesh, crags: Mesh, outline: Variant) -> Array:
	var g := ground.surface_get_arrays(0)
	var gv: PackedVector3Array = g[Mesh.ARRAY_VERTEX]
	var gc: PackedColorArray = g[Mesh.ARRAY_COLOR]
	# Every turf edge, counted, with the face it came from.
	var turf := {}
	for t in range(0, gv.size(), 3):
		for k in 3:
			var key := _edge(gv[t+k], gv[t+(k+1)%3])
			if turf.has(key): turf[key] = -1
			else: turf[key] = t*3+k
	# The rock faces' edges: their third point's height.
	var rock := {}
	if crags != null:
		var rv: PackedVector3Array = crags.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for t in range(0, rv.size(), 3):
			for k in 3:
				var key := _edge(rv[t+k], rv[t+(k+1)%3])
				var third := rv[t+(k+2)%3].y
				rock[key] = minf(float(rock.get(key, INF)), third)
	var poly := PackedVector2Array(outline) if outline != null else PackedVector2Array()
	var out: Array = []
	for key: Variant in turf:
		var at: int = turf[key]
		if at < 0: continue
		var t := at/9
		var k := at%9
		t *= 3
		var a := gv[t+k]
		var b := gv[t+(k+1)%3]
		var c := gv[t+(k+2)%3]
		var low := minf(a.y, b.y)
		var fall := 0.0
		if rock.has(key):
			fall = low-float(rock[key])
			if fall < MIN_DROP: continue
		else:
			var mid := Vector2((a.x+b.x)*0.5, (a.z+b.z)*0.5)
			if poly.size() < 3 or KitLand.edge_distance(mid, poly) > RIM_NEAR: continue
			fall = 3.0
		var along := Vector2(b.x-a.x, b.z-a.z)
		if along.length() < 0.05 or absf(b.y-a.y) > along.length()*0.8: continue
		var side := Vector2(-along.y, along.x).normalized()
		var from_c := Vector2((a.x+b.x)*0.5-c.x, (a.z+b.z)*0.5-c.z)
		if side.dot(from_c) < 0.0: side = -side
		out.append([a, b, side, gc[t+k], gc[t+(k+1)%3], fall])
	return out

## The lips' meshes and roots over `edges` (rim_edges).
static func _build(edges: Array) -> Dictionary:
	# Each rim point's way out, the mean of its edges', so lips meet.
	var ways := {}
	for e: Array in edges:
		for p: Vector3 in [e[0], e[1]]:
			var key := _point(p)
			ways[key] = (ways.get(key, Vector2.ZERO) as Vector2)+(e[2] as Vector2)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roots: Array = []
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var wa := (ways[_point(a)] as Vector2).normalized()
		var wb := (ways[_point(b)] as Vector2).normalized()
		var steps := maxi(1, ceili(a.distance_to(b)/STEP))
		var rows: Array = []
		for s in steps+1:
			var f := float(s)/steps
			var p := a.lerp(b, f)
			var w := wa.lerp(wb, f).normalized()
			if w == Vector2.ZERO: w = e[2]
			rows.append(_profile(p, Vector3(w.x, 0.0, w.y), (e[3] as Color).lerp(e[4], f)))
		for s in steps:
			var r0: Dictionary = rows[s]
			var r1: Dictionary = rows[s+1]
			var out := Vector3((r0.out as Vector3).x+(r1.out as Vector3).x, 0.0, (r0.out as Vector3).z+(r1.out as Vector3).z)
			_quad(top, r0.back, r1.back, r1.crest, r0.crest, r0.tone, r1.tone, r1.tone, r0.tone, Vector3.UP)
			_quad(face, r0.crest, r1.crest, r1.mid, r0.mid, r0.roll, r1.roll, r1.sod, r0.sod, out)
			_quad(face, r0.mid, r1.mid, r1.foot, r0.foot, r0.sod, r1.sod, r1.earth, r0.earth, out)
			_tatters(face, r0, r1, out)
		if float(e[5]) >= ROOT_DROP:
			for s in steps:
				var p: Vector3 = (rows[s] as Dictionary).mid
				if _noise(p*0.37+Vector3(7.1, 0.0, 3.3)) > 1.0-2.0*STEP/ROOT_APART:
					roots.append(Vector4(p.x, p.y, p.z, lerpf(ROOT_LONG.x, ROOT_LONG.y, _noise(p*1.3)*0.5+0.5)))
	top.generate_normals()
	face.generate_normals()
	return {"top":_ground_arrays(top.commit()), "face":face.commit(), "roots":roots}

## A lip's cross-section at rim point `p` turned out along `out`.
static func _profile(p: Vector3, out: Vector3, tone: Color) -> Dictionary:
	var n := _noise(p)*0.5+0.5
	var reach := lerpf(REACH.x, REACH.y, n)
	var droop := lerpf(DROOP.x, DROOP.y, _noise(p*1.9+Vector3(3.0, 0.0, 9.0))*0.5+0.5)
	if _noise(p*0.8+Vector3(11.0, 0.0, 5.0)) > 0.55: droop += TONGUE
	# Each sample's own tear, so the hem is ragged, not a bevel.
	reach += (_hash(p, 1.0)-0.5)*JITTER.x
	droop += (_hash(p, 2.0)-0.5)*JITTER.y
	# The sod under the crest: the turf's colour gone dark, half earth.
	var sod := Color(tone.r*SOD_DARK, tone.g*SOD_DARK, tone.b*SOD_DARK).lerp(EARTH, 0.5)
	return {
		"back": p-out*BACK+Vector3.UP*0.01,
		"crest": p+out*reach+Vector3.UP*0.02,
		"roll": Color(tone.r*ROLL_DARK, tone.g*ROLL_DARK, tone.b*ROLL_DARK),
		"mid": p+out*(reach*1.05)-Vector3.UP*(0.12+droop*0.25),
		"foot": p+out*(reach*0.7)-Vector3.UP*droop,
		"tone": tone, "sod": sod, "earth": EARTH,
		"out": out,
	}

## The torn hem under the foot between rows `r0` and `r1`: narrow strands
## of sod and grass hanging, a little out, dark green to earth.
static func _tatters(st: SurfaceTool, r0: Dictionary, r1: Dictionary, out: Vector3) -> void:
	var a: Vector3 = r0.foot
	var b: Vector3 = r1.foot
	var way := out.normalized()
	for i in TATTERS:
		# Now and then none: a hem torn unevenly.
		if _hash(a, 13.0+i) < TATTER_GAP: continue
		var u := (i+_hash(a, 3.0+i))/TATTERS
		var at := a.lerp(b, u)
		var half := a.distance_to(b)/TATTERS*lerpf(0.12, 0.3, _hash(at, 7.0))
		var along := (b-a).normalized()*half
		var long := lerpf(TATTER_LONG.x, TATTER_LONG.y, _hash(at, 5.0))
		var tip := at-Vector3.UP*long+way*long*0.25+along*(_hash(at, 9.0)-0.5)
		var root: Color = (r0.sod as Color).lerp(r1.sod, u).lerp(EARTH, 0.5)
		var end: Color = EARTH*0.7
		var order := [0, 2, 1] if (2.0*along).cross(tip-(at-along)).dot(way) > 0.0 else [0, 1, 2]
		var pts := [at-along, at+along, tip]
		var cols := [root, root, end]
		for k: int in order:
			st.set_color(cols[k])
			st.add_vertex(pts[k])

## Two faces between rows: near (n0, n1, coloured cn0, cn1) and far (f1,
## f0, coloured cf1, cf0), wound to face `toward`.
static func _quad(st: SurfaceTool, n0: Vector3, n1: Vector3, f1: Vector3, f0: Vector3, cn0: Color, cn1: Color, cf1: Color, cf0: Color, toward: Vector3) -> void:
	for t: Array in [[n0, n1, f1, cn0, cn1, cf1], [n0, f1, f0, cn0, cf1, cf0]]:
		var q0: Vector3 = t[0]
		var q1: Vector3 = t[1]
		var q2: Vector3 = t[2]
		# SurfaceTool's normals face the clockwise side (Godot's front).
		var order := [0, 2, 1] if (q1-q0).cross(q2-q0).dot(toward) > 0.0 else [0, 1, 2]
		for i: int in order:
			st.set_color(t[3+i])
			st.add_vertex(t[i])

## The sod top as the ground's own mesh draws it (KitLook.GroundMesh: the
## grown UV, its height in UV2), so the ground material reads it as turf.
static func _ground_arrays(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for p in v:
		uv.append(Vector2(0.0, 1.0))
		uv2.append(Vector2(0.5, p.y))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

static func _drawn(label: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	mesh.surface_set_material(0, material)
	var drawn := MeshInstance3D.new()
	drawn.name = label
	drawn.mesh = mesh
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return drawn

## A smooth noise of world position, -1..1 (sums of sines, continuous, so
## two edges meeting at a point give it the same lip).
static func _noise(p: Vector3) -> float:
	return sin(p.x*1.7+p.z*0.9)*0.45+sin(p.x*0.63-p.z*2.3+1.3)*0.35+sin(p.x*3.1+p.z*2.7+0.4)*0.2

## A stable hash of world position and `salt`, 0..1.
static func _hash(p: Vector3, salt: float) -> float:
	var h := sin(p.x*127.1+p.y*311.7+p.z*74.7+salt*19.19)*43758.5453
	return h-floorf(h)

static func _point(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x*200.0), roundi(p.y*200.0), roundi(p.z*200.0))

static func _edge(a: Vector3, b: Vector3) -> Array:
	var ka := _point(a)
	var kb := _point(b)
	if ka.x < kb.x or (ka.x == kb.x and (ka.z < kb.z or (ka.z == kb.z and ka.y < kb.y))): return [ka, kb]
	return [kb, ka]
