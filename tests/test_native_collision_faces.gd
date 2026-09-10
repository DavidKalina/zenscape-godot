extends SceneTree
## CPU collision faces must retain the engine's snapped triangle geometry.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func compare(data: NativeTerrainData, label: String) -> void:
	var faces: PackedVector3Array = data.call("play_collision_faces")
	var reference := data.play_mesh().create_trimesh_shape().get_faces()
	check(faces.to_byte_array() == reference.to_byte_array(),label+": CPU faces equal the original collider bytes")
	# Caller mutation must detach from cached geometry.
	if not faces.is_empty(): faces[0] += Vector3.ONE
	check(data.call("play_collision_faces").to_byte_array() == reference.to_byte_array(),label+": callers cannot mutate cached faces")
func run() -> void:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	check(data.has_method("play_collision_faces"),"Terrain supplies collision faces from its CPU geometry")
	if failures:
		quit(1)
		return
	compare(data,"imported")
	data.begin_stroke()
	data.brush(Vector2.ZERO,3.0,0.3,"raise",0.0)
	data.end_stroke()
	compare(data,"sculpted")
	data.undo()
	compare(data,"undo to imported source")
	data.redo()
	compare(data,"redo sculpt")
	data.reset_flat()
	await data.form_foundation(1.0,1.0)
	await data.build_mesh_budgeted(true,self)
	compare(data,"worker mesh")
	# Exercise open, sealed and removed tunnel cache transitions with a bore
	# through the flat fixture; the separate tunnel suite checks actual physics.
	data.tunnels.append({"start":[0.0,0.0,-2.0],"heading":0.0,"width":2.0,"height":2.2,"length":4.0,"sealed":false})
	compare(data,"open tunnel")
	data.tunnels[0].sealed = true
	compare(data,"sealed tunnel")
	data.tunnels[0].sealed = false
	compare(data,"reopened tunnel")
	data.tunnels.clear()
	compare(data,"removed tunnel")
	print("Native collision faces: ",failures," failures")
	quit(1 if failures else 0)
