extends RefCounted
## The wreck cluster's overgrowth (docs/design/wreck-cluster/spec-wreck-
## colonnade.md, "overgrowth on the isles' sides"): moss, ivy, ferns,
## shrubs, the odd clinging tree, roots and vines on the sides and keels of
## every land mass and on the ruin where it meets the rock, so the cluster
## reads as old earth torn up and hung in the sky.
##
## Read from what is drawn, not coded spot by spot: every rock triangle of
## each land (its keel and sides, "Mesh"; its crag faces, "Crags") and of
## the placed ruin pieces is a place things grow, by its area and how it
## faces:
##   a wall      a moss shell (a skin a few cm off the rock, cut into
##               ragged patches by a noise in its shader), heavier where
##               shaded (facing down or north) and high on the keel; moss
##               and ivy cushions in the band under the rim; now and then a
##               fern out of a crack (crags: the shell only, they are climbed)
##   a ledge     on the keels only (never the walked turf or crags): ferns,
##               shrubs, a few small trees leaning out
##   an underside  roots hanging into the haze
##   the rims    green vines trailing down off each land's turf edge
##   the ruin    moss and ivy low on its faces, near the ground it stands
##               on; on the flank walks' decks only thin moss pads, toward
##               the edges (the walk line reads clear)
## All drawn only: no collision, no shadows; multimeshes (one a land and
## kind) faded out by range. Nothing within SPOT_CLEAR of a part spot or
## cache. The strip's runway is turf, which nothing here touches.
##
##   Overgrowth.grow(lands, pieces, flank_pieces, spots, seed) -> Node3D
##     lands: [land node, its top]; pieces: placed ruin Node3Ds; spots:
##     world points kept clear. The node's meta: "triangles", "counts".
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Samples = preload("res://scripts/garden_instance_samples.gd")
const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")

## Moss clumps a square metre of wall at the fullest weight, the pads in a
## clump (they overlap into one cushion) and its reach (m); ivy's share.
const MOSS := 0.12
## Cushions grow in this band under a land's top (m); lower down the moss is
## the shell's (a skin over the rock, cut into patches by a noise).
const CUSHION_BAND := 7.0
## The shell: how far it stands off the rock (m); its cover high on the keel
## and how it thins down it (m under the top to its least).
const SHELL_OFF := 0.05
const SHELL_COVER := Vector2(0.76,0.34)
const SHELL_THIN := 40.0
const CLUMP := Vector2i(8,16)
const CLUMP_REACH := Vector2(0.9,2.2)
const IVY_SHARE := 0.3
## A moss pad's size (m across) and thickness (m).
const PAD := Vector2(0.5,1.3)
const PAD_THICK := Vector2(0.03,0.08)
## Ferns out of a wall's cracks, a square metre.
const WALL_FERNS := 0.012
## A keel ledge's plants a square metre: ferns, shrubs, trees.
const LEDGE_FERNS := 0.18
const LEDGE_SHRUBS := 0.06
const LEDGE_TREES := 0.006
## Roots under an underside a square metre, and their length (m).
const UNDER_ROOTS := 0.035
const ROOT_LONG := Vector2(1.5,7.0)
## Vines off the rims: about this far apart (m), this long.
const VINE_APART := 3.2
const VINE_LONG := Vector2(2.0,11.0)
## The ruin: moss up to this high over the ground under it (m), full weight
## to the first share of it.
const RUIN_MOSS_UP := 3.0
## A flank deck's top: moss within this of its edge (m) at full weight, the
## rest at DECK_MIDDLE of it.
const DECK_EDGE := 0.55
const DECK_MIDDLE := 0.2
## Kept clear round a part spot or cache (m).
const SPOT_CLEAR := 2.6
## Ranges (m) the kinds draw to.
const MOSS_RANGE := 260.0
const PLANT_RANGE := 120.0
const TREE_RANGE := 260.0
## Moss tones (linear-ish albedo): old moss, fresh moss, ivy.
const MOSS_OLD := Color(0.11,0.15,0.05)
const MOSS_FRESH := Color(0.2,0.26,0.075)
const IVY := Color(0.06,0.12,0.04)
## The vines' tint over the roots' bark.
const VINE_TINT := Color(0.75,1.75,0.55)

## The overgrowth node (under the caller), all of it built at once.
static func grow(lands: Array, pieces: Array, flank_pieces: Array, spots: Array, seed_value: int) -> Node3D:
	var job := Job.new(spots,seed_value)
	var out := Node3D.new()
	out.name = "Overgrowth"
	var li := 0
	for entry: Array in lands:
		var land: Node3D = entry[0]
		job.begin()
		job.ground_from(land)
		for called in ["Mesh","Crags"]:
			var mi := land.get_node_or_null(called) as MeshInstance3D
			if mi != null and mi.mesh != null: job.rock(mi,float(entry[1]),called == "Crags")
		job.vines(land)
		job.flush(out,"land_%d" % li)
		li += 1
	job.begin()
	for land_entry: Array in lands: job.ground_from(land_entry[0])
	for piece: Node3D in pieces: job.ruin(piece,piece in flank_pieces)
	job.flush(out,"ruin")
	out.set_meta("triangles",job.triangles)
	out.set_meta("counts",job.counts)
	return out

class Job extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var noise := FastNoiseLite.new()
	var spots: Array
	var pads: Array = []
	var shell_v := PackedVector3Array()
	var shell_n := PackedVector3Array()
	var shell_c := PackedColorArray()
	var pad_colours: Array = []
	var plants := {}
	var plant_colours := {}
	var roots: Array = []
	var vine_roots: Array = []
	var ground := {}
	var triangles := 0
	var counts := {}
	var _catalog: Dictionary
	var _plain := KitFlora.Ground.new()

	func _init(spot_points: Array, seed_value: int) -> void:
		spots = spot_points
		rng.seed = seed_value
		noise.seed = seed_value
		noise.frequency = 0.07
		_catalog = SkyIslets.catalog()

	func begin() -> void:
		pads = []
		shell_v = PackedVector3Array()
		shell_n = PackedVector3Array()
		shell_c = PackedColorArray()
		pad_colours = []
		plants = {}
		plant_colours = {}
		roots = []
		vine_roots = []
		ground = {}

	## The land's turf heights on a 2 m grid (the highest under each cell).
	func ground_from(land: Node3D) -> void:
		var g := land.get_node_or_null("Ground") as MeshInstance3D
		if g == null or g.mesh == null: return
		var xf := Overgrowth_xf(g)
		for v: Vector3 in g.mesh.get_faces():
			var w := xf*v
			var k := Vector2i(floori(w.x/2.0),floori(w.z/2.0))
			ground[k] = maxf(float(ground.get(k,-INF)),w.y)

	func ground_at(x: float, z: float) -> float:
		var k := Vector2i(floori(x/2.0),floori(z/2.0))
		var best := -INF
		for dx in range(-1,2):
			for dz in range(-1,2):
				best = maxf(best,float(ground.get(k+Vector2i(dx,dz),-INF)))
		return best

	func clear_of_spots(p: Vector3) -> bool:
		for s: Vector3 in spots:
			if s.distance_squared_to(p) < SPOT_CLEAR*SPOT_CLEAR: return false
		return true

	## The drawn triangles of `mi` (world): a, b, c and the face's normal,
	## turned to agree with the drawn (lit) normals, so it faces out.
	func oriented(mi: MeshInstance3D) -> PackedVector3Array:
		var out := PackedVector3Array()
		var xf := Overgrowth_xf(mi)
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: Variant = arr[Mesh.ARRAY_NORMAL]
			var has_n: bool = ns is PackedVector3Array and (ns as PackedVector3Array).size() == vs.size()
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			var ids := PackedInt32Array()
			if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0: ids = idx
			else:
				ids.resize(vs.size())
				for k in vs.size(): ids[k] = k
			for k in range(0,ids.size()-2,3):
				var a := xf*vs[ids[k]]
				var b := xf*vs[ids[k+1]]
				var c := xf*vs[ids[k+2]]
				var n := (b-a).cross(c-a)
				if n.length_squared() < 1e-10: continue
				n = n.normalized()
				if has_n:
					var drawn := nb*((ns as PackedVector3Array)[ids[k]]+(ns as PackedVector3Array)[ids[k+1]]+(ns as PackedVector3Array)[ids[k+2]])
					if drawn.dot(n) < 0.0: n = -n
				out.append_array([a,b,c,n])
		return out

	## A count from an expected number (its fraction a chance).
	func many(expected: float) -> int:
		var n := floori(expected)
		if rng.randf() < expected-n: n += 1
		return n

	## A land's rock: walls, ledges (keels only), undersides.
	func rock(mi: MeshInstance3D, top: float, crags: bool) -> void:
		var tri := oriented(mi)
		for i in range(0,tri.size(),4):
			var a := tri[i]
			var b := tri[i+1]
			var c := tri[i+2]
			var n := tri[i+3]
			var area := (b-a).cross(c-a).length()*0.5
			if area < 0.0005: continue
			var mid := (a+b+c)/3.0
			var depth := clampf((top-mid.y)/30.0,0.0,1.0)
			var patch := noise.get_noise_3dv(mid)*0.5+0.5
			if absf(n.y) < 0.6 or crags:
				if crags and n.y > 0.55: continue
				var shade := 0.6+0.6*maxf(0.0,-n.y)+0.3*maxf(0.0,-n.z)
				_shell(a,b,c,n,top,shade*(0.85 if crags else 1.0))
				var w := shade*(lerpf(1.3,0.3,depth)+(1.6 if top-mid.y < CUSHION_BAND else 0.0))*smoothstep(0.4,0.66,patch)*(0.55 if crags else 1.0)
				# Cushions only in the band under the rim, spilling over it.
				if top-mid.y < CUSHION_BAND and not crags:
					for k in many(area*MOSS*w): _pad(a,b,c,n,depth)
				if not crags:
					for k in many(area*WALL_FERNS*w): _plant("fern",_on(a,b,c),(n*0.75+Vector3.UP*0.55).normalized(),rng.randf_range(0.45,0.85))
			elif n.y >= 0.6 and not crags:
				var w := smoothstep(0.2,0.6,patch)
				for k in many(area*LEDGE_FERNS*w): _plant("fern",_on(a,b,c),(Vector3.UP*0.8+_flat(n)*0.2).normalized(),rng.randf_range(0.6,1.1))
				for k in many(area*LEDGE_SHRUBS*w): _plant("shrub",_on(a,b,c),(Vector3.UP*0.8+_flat(n)*0.2).normalized(),rng.randf_range(0.5,0.95))
				for k in many(area*LEDGE_TREES*w):
					var out := _flat(mid-_centre_hint(mid))
					_plant("tree",_on(a,b,c),(Vector3.UP+out*rng.randf_range(0.35,0.8)).normalized(),rng.randf_range(0.28,0.5))
			if n.y < -0.35 and not crags:
				for k in many(area*UNDER_ROOTS*lerpf(1.0,0.5,depth)):
					var p := _on(a,b,c)
					if clear_of_spots(p): roots.append(Vector4(p.x,p.y+0.15,p.z,rng.randf_range(ROOT_LONG.x,ROOT_LONG.y)))

	## Where on the land "out" is: the turf grid's middle is good enough.
	var _centre := Vector3.ZERO
	var _centre_for := -1
	func _centre_hint(_p: Vector3) -> Vector3:
		if _centre_for != ground.size():
			var s := Vector2.ZERO
			for k: Vector2i in ground: s += Vector2(k)*2.0+Vector2.ONE
			s /= maxf(1.0,float(ground.size()))
			_centre = Vector3(s.x,0.0,s.y)
			_centre_for = ground.size()
		return _centre

	## Vines off the land's turf edge (its outline), green strands.
	func vines(land: Node3D) -> void:
		var outline: Variant = land.get_meta("outline",null)
		if outline == null or (outline as Array).size() < 3: return
		var pts: Array = []
		for p: Vector2 in outline: pts.append(p)
		pts.append(pts[0])
		var area := 0.0
		for k in range(pts.size()-1): area += (pts[k] as Vector2).cross(pts[k+1])
		var y_of := func(x: float, z: float) -> float:
			var h := ground_at(x,z)
			return h if is_finite(h) else NAN
		var got := HangingRoots.along(pts,y_of,VINE_APART,VINE_LONG,-0.35 if area > 0.0 else 0.35,rng.randi())
		for r: Vector4 in got:
			if clear_of_spots(Vector3(r.x,r.y,r.z)): vine_roots.append(r)

	## A ruin piece: moss and ivy low on its faces; a flank deck's top thin
	## moss toward its edges.
	func ruin(piece: Node3D, flank: bool) -> void:
		var inv := piece.global_transform.affine_inverse() if piece.is_inside_tree() else piece.transform.affine_inverse()
		var box := AABB()
		var first := true
		var meshes: Array = []
		for mi: Node in piece.find_children("*","MeshInstance3D",true,false):
			if (mi as MeshInstance3D).mesh == null or not (mi as MeshInstance3D).visible: continue
			meshes.append(mi)
		if flank:
			for mi: MeshInstance3D in meshes:
				var local: Transform3D = inv*Overgrowth_xf(mi)
				var b2 := local*mi.mesh.get_aabb()
				box = b2 if first else box.merge(b2)
				first = false
		for mi: MeshInstance3D in meshes:
			var tri := oriented(mi)
			for i in range(0,tri.size(),4):
				var a := tri[i]
				var b := tri[i+1]
				var c := tri[i+2]
				var n := tri[i+3]
				var area := (b-a).cross(c-a).length()*0.5
				if area < 0.002: continue
				var mid := (a+b+c)/3.0
				var patch := smoothstep(0.2,0.65,noise.get_noise_3dv(mid*1.3)*0.5+0.5)
				if absf(n.y) < 0.6:
					var under := ground_at(mid.x,mid.z)
					var up := mid.y-under if is_finite(under) else RUIN_MOSS_UP*0.5
					if flank: up = minf(up,RUIN_MOSS_UP*0.4)
					var w := (1.0-smoothstep(RUIN_MOSS_UP*0.35,RUIN_MOSS_UP,up))*patch*(0.45+0.55*maxf(0.0,-n.z))
					for k in many(area*MOSS*0.5*w): _pad(a,b,c,n,0.0,false,0.4)
				elif flank and n.y >= 0.8:
					var l := inv*mid
					var edge := minf(minf(l.x-box.position.x,box.end.x-l.x),minf(l.z-box.position.z,box.end.z-l.z))
					var w := (1.0 if edge < DECK_EDGE else DECK_MIDDLE)*patch
					for k in many(area*MOSS*0.3*w): _pad(a,b,c,n,0.0,true,0.5)

	## The triangle in the moss shell: stood off the rock, each corner's
	## cover (alpha) from how high it is and the face's shade.
	func _shell(a: Vector3, b: Vector3, c: Vector3, n: Vector3, top: float, shade: float) -> void:
		for v: Vector3 in [a,b,c]:
			var cover := lerpf(SHELL_COVER.x,SHELL_COVER.y,clampf((top-v.y)/SHELL_THIN,0.0,1.0))*shade
			var near_spot := not clear_of_spots(v)
			shell_v.append(v+n*SHELL_OFF)
			shell_n.append(n)
			shell_c.append(Color(1.0,1.0,1.0,0.0 if near_spot else clampf(cover,0.0,1.0)))

	## A moss (or ivy) pad on the triangle, lying on it.
	func _pad(a: Vector3, b: Vector3, c: Vector3, n: Vector3, depth: float, flat := false, reach_scale := 1.0) -> void:
		var centre := _on(a,b,c)
		if not clear_of_spots(centre): return
		var ivy := not flat and rng.randf() < IVY_SHARE
		var u := (b-a).normalized()
		var v := n.cross(u)
		var reach := rng.randf_range(CLUMP_REACH.x,CLUMP_REACH.y)*(0.6 if flat else 1.0)*reach_scale
		var tone_at := rng.randf()
		for k in rng.randi_range(CLUMP.x,CLUMP.y):
			var off := Vector2.from_angle(rng.randf()*TAU)*reach*sqrt(rng.randf())
			# The clump's middle pads bigger, its edge ones small.
			var edge := off.length()/maxf(reach,0.01)
			_one_pad(centre+u*off.x+v*off.y,n,depth,flat,ivy,tone_at,lerpf(1.0,0.45,edge))

	func _one_pad(p: Vector3, n: Vector3, depth: float, flat: bool, ivy: bool, tone_at: float, grade: float) -> void:
		# Its long axis down the face (a streak) where it's a wall.
		var down := (Vector3.DOWN-n*n.dot(Vector3.DOWN))
		if down.length() < 0.2: down = n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.FORWARD)
		down = down.normalized()
		var side := n.cross(down).normalized()
		var size := rng.randf_range(PAD.x,PAD.y)*(0.6 if flat else 1.0)*grade
		var stretch := 1.0 if flat else rng.randf_range(1.0,1.45)
		var thick := rng.randf_range(PAD_THICK.x,PAD_THICK.y)*(0.4 if flat else 1.0)
		var turn := Basis(n,rng.randf_range(-0.5,0.5))
		var basis := turn*Basis(side*size,n*thick,down*size*stretch)
		pads.append(Transform3D(basis,p+n*(0.01-thick*0.3)+down*size*stretch*0.12))
		var tone := MOSS_OLD.lerp(MOSS_FRESH,clampf(tone_at*0.6+rng.randf()*0.25+depth*0.15,0.0,1.0)) if not ivy else IVY*rng.randf_range(0.85,1.2)
		pad_colours.append(tone)

	## A catalog plant at `p`, its up `up`.
	func _plant(asset: String, p: Vector3, up: Vector3, size: float) -> void:
		if not clear_of_spots(p): return
		var data: Dictionary = _catalog.data
		var item := {"id":1,"asset":asset,"x":0.0,"z":0.0,"angle":rng.randf()*TAU,"scale":size}
		_plain.heights[1] = 0.0
		var transforms := {}
		var sources := {}
		var tints := {}
		Samples.add_item(item,_plain,data.parts,data.poses,data.tints,data.world,false,transforms,sources,tints)
		var tilt := Basis(Quaternion(Vector3.UP,up))
		var place := Transform3D(tilt,p-up*0.12)
		for key: String in transforms:
			var list: Array = transforms[key]
			if list.is_empty() or not (_catalog.meshes as Dictionary).has(key): continue
			if not plants.has(key):
				plants[key] = []
				plant_colours[key] = []
			var cols: Array = tints[key]
			for j in list.size():
				(plants[key] as Array).append(place*(list[j] as Transform3D))
				(plant_colours[key] as Array).append(cols[j] if j < cols.size() else Color.WHITE)

	func _on(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
		var u := rng.randf()
		var v := rng.randf()
		if u+v > 1.0:
			u = 1.0-u
			v = 1.0-v
		return a+(b-a)*u+(c-a)*v

	func _flat(v: Vector3) -> Vector3:
		var f := Vector3(v.x,0.0,v.z)
		return f.normalized() if f.length() > 0.001 else Vector3.ZERO

	## What was gathered drawn under `out` as `label`'s batches.
	func flush(out: Node3D, label: String) -> void:
		if not shell_v.is_empty():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = shell_v
			arrays[Mesh.ARRAY_NORMAL] = shell_n
			arrays[Mesh.ARRAY_COLOR] = shell_c
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var node := MeshInstance3D.new()
			node.name = "MossShell_"+label
			node.mesh = mesh
			node.material_override = WreckOvergrowthPad.shell_material()
			_drawn(node,MOSS_RANGE)
			out.add_child(node)
			_count("shell_tris",shell_v.size()/3,shell_v.size()/3)
		if not pads.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = Overgrowth_pad_mesh()
			mm.instance_count = pads.size()
			mm.buffer = KitFlora.batch_buffer(pads,pad_colours)
			var node := MultiMeshInstance3D.new()
			node.name = "Moss_"+label
			node.multimesh = mm
			node.material_override = Overgrowth_pad_material()
			_drawn(node,MOSS_RANGE)
			out.add_child(node)
			_count("moss",pads.size(),pads.size()*_pad_tris())
		for key: String in plants:
			var list: Array = plants[key]
			var node := KitFlora.batch_node(key,Vector2i.ZERO,list.size(),KitFlora.batch_buffer(list,plant_colours[key]))
			node.name = "%s_%s" % [label,key.replace(":","_")]
			var is_tree := key.begins_with("tree")
			_drawn(node,TREE_RANGE if is_tree else PLANT_RANGE)
			out.add_child(node)
			_count(key.get_slice(":",0),list.size(),KitFlora._mesh_triangles(_catalog.meshes[key])*list.size())
		if not roots.is_empty():
			var node := HangingRoots.batch(roots,rng.randi())
			node.name = "Roots_"+label
			out.add_child(node)
			_count("roots",roots.size(),roots.size()*HangingRoots.triangles())
		if not vine_roots.is_empty():
			var node := HangingRoots.batch(vine_roots,rng.randi())
			node.name = "Vines_"+label
			var mm := node.multimesh
			for i in mm.instance_count: mm.set_instance_color(i,VINE_TINT*rng.randf_range(0.75,1.1))
			out.add_child(node)
			_count("vines",vine_roots.size(),vine_roots.size()*HangingRoots.triangles())

	func _drawn(node: GeometryInstance3D, far: float) -> void:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = far
		node.visibility_range_end_margin = far*0.15
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	func _count(kind: String, n: int, tris: int) -> void:
		counts[kind] = int(counts.get(kind,0))+n
		triangles += tris

	func _pad_tris() -> int:
		return Overgrowth_pad_mesh().get_faces().size()/3

	## A node's transform under the cluster (its global one, read as built).
	func Overgrowth_xf(node: Node3D) -> Transform3D:
		if node.is_inside_tree(): return node.global_transform
		var xf := node.transform
		var p := node.get_parent() as Node3D
		while p != null:
			xf = p.transform*xf
			p = p.get_parent() as Node3D
		return xf

	func Overgrowth_pad_mesh() -> ArrayMesh:
		return WreckOvergrowthPad.mesh()

	func Overgrowth_pad_material() -> ShaderMaterial:
		return WreckOvergrowthPad.material()

## The moss pad: a low, lumpy dome a unit across (local y its height, one
## unit), darker at its foot; drawn from both sides so a pad on a side
## wound either way shows.
class WreckOvergrowthPad:
	const SIDES := 6
	static var _mesh: ArrayMesh = null
	static var _material: ShaderMaterial = null

	static func mesh() -> ArrayMesh:
		if _mesh != null: return _mesh
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outer: Array = []
		var inner: Array = []
		for k in SIDES:
			var t := k*TAU/SIDES
			var r := 0.5*(0.8+0.2*sin(k*2.3))
			outer.append(Vector3(cos(t)*r,0.0,sin(t)*r))
			inner.append(Vector3(cos(t+0.3)*r*0.55,0.75+0.2*cos(k*1.7),sin(t+0.3)*r*0.55))
		var top := Vector3(0.0,1.0,0.0)
		var foot := Color(0.6,0.6,0.6)
		var mid := Color(0.95,0.95,0.95)
		var crown := Color(1.0,1.0,1.0)
		for k in SIDES:
			var j := (k+1)%SIDES
			for tri: Array in [[outer[k],inner[k],outer[j],foot,mid,foot],[outer[j],inner[k],inner[j],foot,mid,mid],[inner[k],top,inner[j],mid,crown,mid]]:
				# Godot's front faces wind clockwise seen from outside.
				for q in [0,2,1]:
					st.set_color(tri[3+q])
					st.add_vertex(tri[q])
		st.index()
		st.generate_normals()
		_mesh = st.commit()
		return _mesh

	static func material() -> ShaderMaterial:
		if _material != null: return _material
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		return _material

	static var _shell: ShaderMaterial = null
	static func shell_material() -> ShaderMaterial:
		if _shell != null: return _shell
		var sh := Shader.new()
		sh.code = SHELL_SHADER
		_shell = ShaderMaterial.new()
		_shell.shader = sh
		return _shell

	## The moss shell: a skin over the rock, kept where a noise of where it is
	## clears the corner's cover (COLOR.a), so it lies in patches with ragged
	## edges and thins down the keel; old dark moss in the patches' hearts,
	## fresher at their edges.
	const SHELL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 old_moss : source_color = vec3(0.22, 0.27, 0.13);
uniform vec3 fresh_moss : source_color = vec3(0.4, 0.45, 0.2);
uniform float lift = 0.3;
varying vec3 wp;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Patches (stretched down the face a little: moss runs with the wet).
	vec3 q = wp * vec3(1.0, 0.4, 1.0);
	float m = n3(q * 0.2) * 0.5 + n3(q * 0.6) * 0.3 + n3(q * 2.4) * 0.2;
	float keep = m - (1.0 - COLOR.a);
	if (keep < 0.0) discard;
	// A torn fringe at the edge, not a cut line.
	if (keep < 0.06 && h(floor(wp * 18.0)) > keep / 0.06) discard;
	float heart = smoothstep(0.0, 0.18, keep);
	float grain = n3(wp * 7.0) * 0.6 + n3(wp * 21.0) * 0.4;
	vec3 c = mix(fresh_moss, old_moss, heart) * (0.7 + 0.55 * grain);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * lift;
}
"""

	## Moss: the instance's tone, mottled by a fine noise of where it is,
	## lit softly (the rock's own shader lifts its shade with the sky; this
	## lifts the moss as much, so it reads as growth, not holes).
	const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float lift = 0.3;
varying vec3 wp;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float m = n3(wp * 2.5) * 0.45 + n3(wp * 9.0) * 0.35 + n3(wp * 31.0) * 0.2;
	vec3 c = COLOR.rgb * (0.55 + 0.9 * m);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * lift;
}
"""
