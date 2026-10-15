extends RefCounted
## The Face's colossus (scripts/kit_isle/greybox/gb_face.gd): a seated Olmec
## lord the size of a hill, cut out of a basalt cliff over the abyss. STAND-IN
## for a kit piece (the card's "Kit asks"): a Blender model (art/blender/
## face_colossus/colossus_build.py -> assets/models/face_colossus.glb) dressed
## in the city's stone as the relief is (CityLight2 `_dressed_relief`: its
## baked occlusion and convexity in the vertex colours, moss on what faces
## up, the grain on its rest place, LODs), collided as one trimesh from its
## coarse hull: his lane, he climbs any of it. The city kit's real pieces
## stand in notches cut in him (the skin wall, the lap, the relief, the
## shoulder, the knee daises, the crown: the build script's NOTCH).
##
## The model is authored in metres at the wanderer's size 1: it doesn't follow
## `--wanderer-scale` (the kit pieces in its notches do).
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityLight2 = preload("res://scripts/city_kit_light2.gd")
const MODEL := "res://assets/models/face_colossus.glb"

static var _mesh: Mesh = null
static var _holds: Array = []
static var _bosses: Mesh = null
static var _shape: Shape3D = null
static var _tris := 0
static var _lock := Mutex.new()

## The dressed mesh and the hull's shape, made once (main thread: `warm`).
static func warm() -> void:
	_lock.lock()
	if _mesh == null:
		var model: Node3D = (load(MODEL) as PackedScene).instantiate()
		var src := _find(model,"Colossus")
		var hull := _find(model,"Hull")
		if CityStone._stone == null: CityStone.warm()
		_mesh = CityLight2._dressed_relief(src.mesh,CityStone.stone_colour())
		_shape = hull.mesh.create_trimesh_shape()
		# Her bosses up the head's west flank (the model's Hold_NN empties:
		# place the box's middle, scale its size), foot first.
		_holds.clear()
		for n: Node in model.find_children("Hold_*","Node3D",true,false):
			var e := n as Node3D
			_holds.append({"i":int(String(n.name).substr(5)),"box":AABB(e.position-e.scale*0.5,e.scale)})
		_holds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.i) < int(b.i))
		var m := CityStone.Mesher.new(CityStone.stone_colour(),0.25)
		for h: Dictionary in _holds:
			var b: AABB = h.box
			m.solid(CityStone.box(Transform3D(Basis.IDENTITY,b.get_center()),b.size*0.5,0.08),NAN,0.95+0.03*(int(h.i)%3))
		_bosses = CityStone.mesh_of(m,"stair")
		_tris = m.triangles()
		for s in (src.mesh as ArrayMesh).get_surface_count():
			var n := (src.mesh as ArrayMesh).surface_get_array_index_len(s)
			_tris += (n if n > 0 else (src.mesh as ArrayMesh).surface_get_array_len(s))/3
		model.free()
	_lock.unlock()

static func _find(n: Node, want: String) -> MeshInstance3D:
	for c: Node in n.find_children("*","MeshInstance3D",true,false):
		if String(c.name).begins_with(want): return c
	return null

## The colossus, drawn and collided, in the motif's frame.
static func stand() -> Node3D:
	warm()
	var root := Node3D.new()
	root.name = "Colossus"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _mesh
	mi.material_override = CityStone.wear("pier")
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	body.add_child(cs)
	root.add_child(body)
	if _bosses != null:
		var bm := MeshInstance3D.new()
		bm.name = "Bosses"
		bm.mesh = _bosses
		root.add_child(bm)
	var hers := StaticBody3D.new()
	hers.name = "Holds"
	for h: Dictionary in _holds:
		var b: AABB = h.box
		var c := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b.size
		c.shape = box
		c.position = b.get_center()
		hers.add_child(c)
	WalkerOnly.mark(hers)
	root.add_child(hers)
	root.set_meta("triangles",_tris)
	return root

## Her bosses: [{i, box (AABB, motif frame)}], foot first.
static func holds() -> Array:
	warm()
	return _holds
