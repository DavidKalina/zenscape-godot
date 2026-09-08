extends RefCounted
## Read-only shelter affordances from the scenery the player arranged.
## Canopy bounds approximate shade; navigation still decides whether he fits.
var canopies: Array[AABB] = []
var screens: Array[AABB] = []
var head_clearance := 2.8
func refresh(scene: Node) -> void:
	head_clearance = 2.8*scene.creature.actor.scale.y
	canopies.clear()
	screens.clear()
	if not scene._chunk_editor.data.blank:
		for key in ["mesh-9","broadleaf-canopies"]:
			var node := scene.get_node_or_null("Reference/"+key) as MultiMeshInstance3D
			if node == null or not node.visible: continue
			for i in range(node.multimesh.instance_count):
				canopies.append(node.transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb())
	for part in scene._chunk_editor.selection.parts():
		var record: Dictionary = scene._chunk_editor.data.object_by_id(int(part.id))
		var kind: String = record.get("asset","")
		var box: AABB = part.transform*part.mesh.get_aabb()
		if kind in ["tree","broadleaf","bigfoot_tree"]: canopies.append(box)
		elif kind in ["shrub","rock","boulder_1","boulder_2","boulder_3","boulder_4","log"]: screens.append(box)

func shade(point: Vector3) -> float:
	var patch := Rect2(Vector2(point.x,point.z)-Vector2.ONE*0.65,Vector2.ONE*1.3)
	var best := 0.0
	for box in canopies:
		if box.position.y < point.y+head_clearance or box.end.y < point.y+head_clearance: continue
		var roof := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
		best = maxf(best,patch.intersection(roof).get_area()/patch.get_area())
	return best

func quality(point: Vector3) -> float:
	var cover := shade(point)
	if cover < 0.3: return 0.0
	var nearby := 0.0
	for box in screens:
		if box.end.y < point.y+0.4 or box.position.y > point.y+2.8: continue
		var distance := Vector2(point.x-box.get_center().x,point.z-box.get_center().z).length()
		if distance > 1.0 and distance < 3.5: nearby += (3.5-distance)/2.5
	return cover*4.0+minf(nearby,2.0)
