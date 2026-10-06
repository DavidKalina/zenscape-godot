extends RefCounted
## Read the original Fidelity triangles. Conservative solid bounds keep the
## creature clear of trunks, dead wood, boulders and the landmark.
const Ground = preload("res://scripts/reference_ground.gd")
var ground = Ground.new()
var native_data: NativeTerrainData
var _prop_bounds := {}
var walkways = preload("res://scripts/log_walkways.gd").new()
var ponds: Array[Dictionary] = []
var streams: Array[Dictionary] = []
var objects: Array[Dictionary] = []
var waters: Array[RefCounted] = []
var solids: Array[AABB] = []
const PARTING_TREES := ["tree","layered_tree","redwood","broadleaf","birch","willow","juniper"]

## Restored from the stitched world's foliage wake: keep a solid trunk core.
static func trunk_core(box: AABB) -> AABB:
	var center := box.get_center()
	var half := clampf(minf(box.size.x,box.size.z)*0.25,0.05,0.30)
	return AABB(Vector3(center.x-half,box.position.y,center.z-half),Vector3(half*2.0,box.size.y,half*2.0))
const SOLID_CELL := 2.0
var _solid_cells := {}
var interests: Array[Dictionary] = []

func setup(geometry: Node3D, data: NativeTerrainData = null) -> void:
	native_data = data
	waters.clear()
	solids.clear()
	walkways.surfaces.clear()
	interests.clear()
	ponds.assign(data.ponds if data != null else [])
	streams.assign(data.streams if data != null else [])
	objects.assign(data.objects if data != null else [])
	if data == null: ground.setup(geometry.get_node("terrain"))
	if data != null and data.blank:
		_add_authored(data)
		_index_solids()
		return
	for node in geometry.get_children():
		if node is MeshInstance3D and node.visible:
			var material := node.get_active_material(0) as ShaderMaterial
			if material != null and material.shader.resource_path.ends_with("reference_water.gdshader"):
				var water = Ground.new()
				water.setup(node)
				waters.append(water)
	for key in ["mesh-8","mesh-11","logs","stumps","snags","mesh-4","mesh-5","mesh-6","mesh-7","landmark-arch"]:
		var node: Node3D = geometry.get_node(key)
		if node is MultiMeshInstance3D:
			for i in range(node.multimesh.instance_count):
				if data != null and "%s:%d" % [key,i] in data.source_replacements: continue
				_add_solid(node.transform*node.multimesh.get_instance_transform(i),node.multimesh.mesh,str(key)+":"+str(i))
		elif node is MeshInstance3D:
			if data != null and key+":0" in data.source_replacements: continue
			_add_solid(node.transform,node.mesh,key)

	if data != null: _add_authored(data)
	_index_solids()

func _add_solid(pose: Transform3D, mesh: Mesh, id: String) -> void:
	var box: AABB = pose*mesh.get_aabb()
	if box.size.length() < 0.01: return
	solids.append(trunk_core(box) if id.begins_with("mesh-8:") or id.begins_with("mesh-11:") else box)
	var center := box.get_center()
	var height: Variant = ground_height(Vector2(center.x,center.z))
	if height != null:
		interests.append({"id":id,"position":Vector3(center.x,height,center.z),"bounds":box,"kind":"tree" if id.begins_with("mesh-8:") or id.begins_with("mesh-11:") else "scenery"})

func ground_height(point: Vector2) -> Variant:
	return native_data.ground_height(point) if native_data != null else ground.height_at(point.x,point.y)

func navigation_height(point: Vector2) -> Variant:
	var terrain: Variant = ground_height(point)
	var deck: Dictionary = walkways.at(point)
	if terrain == null: return float(deck.height)+0.015 if not deck.is_empty() else null
	return maxf(terrain,float(deck.height)+0.015) if not deck.is_empty() else terrain

func narrow_support(point: Vector3) -> bool:
	var deck: Dictionary = walkways.at(Vector2(point.x,point.z))
	return not deck.is_empty() and absf(point.y-float(deck.height)-0.015)<0.02

func pond_surface(pond: Dictionary) -> PackedVector3Array:
	return native_data.pond_surface(pond)

func waterfall_impacts() -> Array[Dictionary]:
	if native_data != null: return native_data.waterfall_impacts()
	var empty: Array[Dictionary] = []
	return empty

func _add_authored(data: NativeTerrainData) -> void:
	if _prop_bounds.is_empty():
		var catalog := NativePlayCollisions.new()
		catalog._load_bounds()
		_prop_bounds = catalog._bounds.duplicate()
		if not catalog._arch_faces.is_empty():
			var arch_bounds := AABB(catalog._arch_faces[0],Vector3.ZERO)
			for vertex in catalog._arch_faces: arch_bounds = arch_bounds.expand(vertex)
			_prop_bounds.arch = arch_bounds
		catalog.free()
	for item: Dictionary in data.objects:
		var location := data.object_position(item)
		interests.append({"id":"object:%d" % item.id,"position":location,"kind":item.asset})
		if not _prop_bounds.has(item.asset): continue
		var basis := NativeObjectPose.decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*float(item.scale))
		if item.asset == "rock": location.y += 0.24*float(item.scale)
		var box: AABB = Transform3D(basis,location)*_prop_bounds[item.asset]
		if item.asset == "log": walkways.add(int(item.id),Transform3D(basis,location),box,ground_height)
		solids.append(trunk_core(box) if item.asset in PARTING_TREES else box)
		interests[-1]["bounds"] = box

func clear_at(point: Vector3) -> bool:
	var deck: Dictionary = walkways.at(Vector2(point.x,point.z))
	for offset in [Vector2.ZERO,Vector2(0.5,0),Vector2(-0.5,0),Vector2(0,0.5),Vector2(0,-0.5),Vector2(0.35,0.35),Vector2(-0.35,0.35),Vector2(0.35,-0.35),Vector2(-0.35,-0.35)]:
		for water in waters:
			var height: Variant = water.height_at(point.x+offset.x,point.z+offset.y)
			if height != null and height >= point.y-0.15: return false
	for box: AABB in _solid_cells.get(Vector2i(floori(point.x/SOLID_CELL),floori(point.z/SOLID_CELL)),[]):
		if not deck.is_empty() and deck.bounds == box and point.y>=float(deck.height): continue
		var low_step := false
		for surface in walkways.surfaces:
			if surface.bounds == box and walkways.low_edge(surface,point):
				low_step = true
				break
		if low_step: continue
		if point.y+2.8 < box.position.y or point.y > box.end.y: continue
		var footprint := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(0.5)
		if footprint.has_point(Vector2(point.x,point.z)): return false
	return true

func _index_solids() -> void:
	_solid_cells.clear()
	for box in solids:
		var footprint := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(0.5)
		for z in range(floori(footprint.position.y/SOLID_CELL),floori(footprint.end.y/SOLID_CELL)+1):
			for x in range(floori(footprint.position.x/SOLID_CELL),floori(footprint.end.x/SOLID_CELL)+1):
				var cell := Vector2i(x,z)
				if not _solid_cells.has(cell): _solid_cells[cell] = []
				_solid_cells[cell].append(box)

## Explicit data-only provider for background navigation. Static clearance uses
## copied bounds and water triangles, with no scene nodes or rendering queries.
func navigation_snapshot() -> RefCounted:
	var result = get_script().new()
	result.native_data = preload("res://scripts/native_terrain_snapshot.gd").for_queries(native_data) if native_data != null else null
	result.ground = ground.query_snapshot()
	for water in waters: result.waters.append(water.query_snapshot())
	result._solid_cells = _solid_cells.duplicate(true)
	result.walkways.surfaces.assign(walkways.surfaces.duplicate(true))
	result.walkways.disabled = walkways.disabled.duplicate()
	return result
