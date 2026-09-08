extends RefCounted
## Memory is separate from the editable bed. Once a player changes that record,
## Bigfoot relinquishes it and leaves that area alone, including after undo/load.
var scene: Node
var home: Variant = null
var visits := 0
var stage := 0
var bed := {}
var avoided: Array[Vector2] = []
var writing := false
var _cover: Array[AABB] = []
var shelter = preload("res://scripts/bigfoot_shelter.gd").new()
var sheltered_home := false

func setup(owner_scene: Node) -> void:
	scene = owner_scene

func allows(point: Vector3) -> bool:
	for spot in avoided:
		if spot.distance_to(Vector2(point.x,point.z)) < 3.0: return false
	return true

func rest_candidates(points: Array, origin: Vector3) -> Array:
	shelter.refresh(scene)
	_cover.clear()
	for name in ["mesh-10","mesh-13","mesh-14","mesh-15"]:
		var node: MultiMeshInstance3D = scene.get_node("Reference/"+name)
		if not node.visible: continue
		for i in range(node.multimesh.instance_count):
			_cover.append(node.transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb())
	for part in scene._chunk_editor.selection.parts():
		var record: Dictionary = scene._chunk_editor.data.object_by_id(int(part.id))
		if record.get("asset") != "leaf_bed": _cover.append(part.transform*part.mesh.get_aabb())
	var ranked: Array = []
	for point: Vector3 in points:
		var covered := 0.0
		var footprint := Rect2(Vector2(point.x,point.z)-Vector2.ONE*0.65,Vector2.ONE*1.3)
		for box in _cover:
			if box.end.y<point.y+0.2 or box.position.y>point.y+1.5: continue
			var patch := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
			covered += footprint.intersection(patch).get_area() if footprint.intersects(patch) else 0.0
		ranked.append({"point":point,"score":covered*12.0+point.distance_to(origin)*0.35-shelter.quality(point)*3.0})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score<b.score)
	return ranked.map(func(item: Dictionary) -> Vector3: return item.point)

func preferred() -> Variant:
	if home == null: return null
	shelter.refresh(scene)
	if sheltered_home and shelter.quality(home)<=0.0:
		forget(false)
		return null
	var ground: Variant = scene.navigation._ground(home)
	if ground == null or ground.distance_to(home)>0.18 or not scene.routine._rest_stance(ground):
		forget()
		return null
	return ground

func forget(avoid := true) -> void:
	if home != null and avoid:
		avoided.append(Vector2(home.x,home.z))
		if avoided.size()>16: avoided.pop_front()
	home = null
	sheltered_home = false
	visits = 0
	stage = 0
	bed = {}

func world_changed() -> void:
	if writing or bed.is_empty(): return
	var current: Dictionary = scene._chunk_editor.data.object_by_id(int(bed.id))
	# JSON numbers are floats; loaded garden IDs are ints. Compare field values
	# so serialization's numeric types are not mistaken for a player edit.
	if current.size() != bed.size():
		forget()
		return
	for key in bed:
		if not current.has(key) or current[key] != bed[key]:
			forget()
			return
	bed = current

func can_claim(point: Vector3) -> bool:
	return not sheltered_home and allows(point) and shelter.quality(point)>0.0

func claim(point: Vector3) -> bool:
	if not can_claim(point): return false
	if home == null or home.distance_to(point)>0.2:
		visits = 0
		stage = 0
		bed = {}
	home = point
	sheltered_home = true
	return true

func rested(point: Vector3) -> void:
	if home == null and allows(point):
		home = point
		sheltered_home = shelter.quality(point)>0.0
	if home != null and point.distance_to(home)<0.2: visits = mini(visits+1,1000000)

func can_tend(point: Vector3) -> bool:
	return home != null and point.distance_to(home)<0.2 and (visits>0 or sheltered_home) and stage<3

func tend(point: Vector3, normal: Vector3, yaw: float) -> void:
	if not can_tend(point): return
	var editor: NativeChunkEditor = scene._chunk_editor
	# Never merge an autonomous change into the player's in-progress stroke.
	if not editor.data._before.is_empty() or editor._selection_edit: return
	world_changed()
	if not can_tend(point): return
	var size := [0.60,0.82,1.0][stage] as float
	var pose := NativeObjectPose.make((Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)).scaled(Vector3.ONE*size),0.02)
	writing = true
	editor.data.begin_stroke()
	var id := int(bed.get("id",-1))
	if id < 0:
		id = editor.data.place("leaf_bed",Vector2(point.x,point.z),yaw,size,pose)
	else:
		editor.data.update_object(id,{"scale":size,"pose":pose})
	if id >= 0:
		bed = editor.data.object_by_id(id)
		stage += 1
	editor.data.end_stroke()
	editor.refresh()
	writing = false

func capture() -> Dictionary:
	return {"version":2,"sheltered_home":sheltered_home,"home":[] if home == null else [home.x,home.y,home.z],"visits":visits,"stage":stage,"bed":bed.duplicate(true),"avoided":avoided.map(func(p: Vector2) -> Array: return [p.x,p.y])}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or (value.get("version") != 1 and value.get("version") != 2): return false
	if value.version == 2 and not value.get("sheltered_home") is bool: return false
	if not value.get("home") is Array or value.home.size() not in [0,3]: return false
	for number in value.home:
		if not GardenData._number(number,-1000,1000): return false
	for key in ["visits","stage"]:
		if not GardenData._integer(value.get(key)) or not GardenData._number(value[key],0,1000000 if key=="visits" else 3): return false
	if not value.get("bed") is Dictionary: return false
	if not value.bed.is_empty():
		if not GardenData._integer(value.bed.get("id")) or value.bed.id<1 or value.bed.get("asset")!="leaf_bed": return false
		for key in ["x","z","angle","scale"]:
			if not GardenData._number(value.bed.get(key),-1000,1000): return false
		if not NativeObjectPose.valid(value.bed.get("pose")): return false
	if (value.stage>0) != (not value.bed.is_empty()) or (value.home.is_empty() and (value.visits>0 or value.stage>0)): return false
	if value.get("sheltered_home",false) and value.home.is_empty(): return false
	if not value.get("avoided") is Array or value.avoided.size()>16: return false
	for point in value.avoided:
		if not point is Array or point.size()!=2: return false
		for number in point:
			if not GardenData._number(number,-1000,1000): return false
	return true

func restore(value: Dictionary) -> void:
	home = null
	sheltered_home = false
	visits = 0
	stage = 0
	bed = {}
	avoided.clear()
	if value.is_empty(): return
	if not value.home.is_empty(): home = Vector3(value.home[0],value.home[1],value.home[2])
	sheltered_home = bool(value.get("sheltered_home",false))
	visits = int(value.visits)
	stage = int(value.stage)
	bed = value.bed.duplicate(true)
	for point in value.avoided: avoided.append(Vector2(point[0],point[1]))
	world_changed()
	preferred()
