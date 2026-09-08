extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var wind := LocalWindField.new()
	root.add_child(wind)
	var visuals = preload("res://scripts/wind_gust_visuals.gd").new()
	root.add_child(visuals)
	visuals.setup(wind)
	var id := wind.emit_gust(Vector3(1,2,3),Vector3.FORWARD,20,8,1.4)
	check(visuals.trails.has(id),"Emitting wind creates feedback through the shared field")
	wind.advance(0.3)
	var node: MeshInstance3D = visuals.trails[id]
	var material := node.material_override as ShaderMaterial
	check(node.basis.x.is_equal_approx(Vector3.FORWARD),"Ribbon flow is aligned to the actual wind direction")
	check(is_equal_approx(material.get_shader_parameter("clock"),0.3),"Shader time matches physical gust age")
	var age: float = material.get_shader_parameter("clock")
	for i in range(5): await process_frame
	check(material.get_shader_parameter("clock")==age,"Rendering alone cannot advance a paused gust")
	wind.advance(1.1)
	check(visuals.trails.is_empty(),"Expired gust removes its visual representation")
	for i in range(20): wind.emit_gust(Vector3.ZERO,Vector3.RIGHT,5,4,2)
	check(visuals.trails.size()==LocalWindField.CAPACITY,"Rapid gestures remain bounded by field capacity")
	wind.clear()
	await process_frame
	check(visuals.trails.is_empty() and visuals.get_child_count()==1,"Clearing wind removes every ribbon")
	visuals.set_aim(Vector3.ZERO,Vector3(4,0,0))
	check(visuals.aim.mesh != null,"Drag produces a visible aiming shape")
	visuals.clear_aim()
	check(visuals.aim.mesh == null,"Cancelled aim disappears")
	print("Wind gust visuals: ",failures," failures")
	visuals.free()
	wind.free()
	quit(1 if failures else 0)
