extends RefCounted
## waterfall.js foam clusters: source growth gates, bob and per-update tumble.
var blobs: Array = []
var nodes: Array[Node3D] = []
func setup(geometry: Node3D, data: Dictionary) -> void:
	blobs = data.blobs.duplicate(true)
	nodes.clear()
	for blob: Dictionary in blobs:
		var node: Node3D = geometry.get_node(blob.mesh)
		node.set_meta("source_foam",true)
		nodes.append(node)
func advance(time: float, paused: bool, ice: float, front: float, terrain_ready: bool) -> void:
	var still := 1.0-clampf(ice,0.0,1.0)
	for i in range(blobs.size()):
		var blob: Dictionary = blobs[i]
		var node := nodes[i]
		var growth := clampf((front-float(blob.gate))/0.12,0.0,1.0)
		node.visible = terrain_ready and growth > 0.001
		if not paused:
			blob.position[1] = float(blob.baseY)+absf(sin(time*2.0+i*1.7))*0.08*still
			# Source adds .004 per update, not per second. Preserve that behavior.
			blob.rotation[1] += 0.004*still
		var rotation := Vector3(blob.rotation[0],blob.rotation[1],blob.rotation[2])
		var origin := Vector3(blob.position[0],blob.position[1],blob.position[2])
		node.transform = Transform3D(Basis.from_euler(rotation,EULER_ORDER_XYZ).scaled(Vector3.ONE*maxf(0.0001,growth)),origin)
