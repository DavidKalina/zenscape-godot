extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func snapshot(falls: NativeGardenFalls) -> Array:
	var result := []
	for mesh in falls.get_children():
		if mesh is MeshInstance3D:
			var uniforms := []
			for key in ["centers_tau","axis_a_width","axis_b_thick","aer_steep","height_range"]:
				uniforms.append(mesh.material_override.get_shader_parameter(key))
			result.append([mesh.mesh.surface_get_arrays(0),uniforms])
	for spray in falls._sprays:
		result.append([spray.particle_count,spray.material.get_shader_parameter("origins"),spray.material.get_shader_parameter("motion"),spray.material.get_shader_parameter("rise_height")])
	return result
func fresh_matches(data: NativeTerrainData,falls: NativeGardenFalls,label: String) -> void:
	var fresh := NativeGardenFalls.new()
	fresh.set_process(false)
	root.add_child(fresh)
	fresh._mist_recipe = falls._mist_recipe.duplicate(true)
	fresh.rebuild(data)
	check(snapshot(falls) == snapshot(fresh),label)
	fresh.free()
func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	for i in range(data.points.size()):
		var p := data.points[i]
		data.heights[i] = 5.0*(1.0-smoothstep(-5.0,1.0,p.x))*(1.0-smoothstep(1.5,5.5,absf(p.y)))*smoothstep(-12.0,-8.0,p.x)-1.1*(1.0-smoothstep(0.0,3.0,p.distance_to(Vector2(3,0))))
	check(data.add_pond(Vector2(3,0),-0.2) and data.add_waterfall(Vector2(-4,0),Vector2(3,0),1.0),"Fixture has real authored waterfall")
	var falls := NativeGardenFalls.new()
	falls.set_process(false)
	root.add_child(falls)
	falls.rebuild(data)
	var original := snapshot(falls)
	var forced_id := falls.get_child(0).get_instance_id()
	falls.discard_cache()
	falls.rebuild(data)
	check(falls.get_child(0).get_instance_id() != forced_id and snapshot(falls) == original,"Explicit discard reconstructs identical fresh nodes")
	var mesh_id := falls.get_child(0).get_instance_id()
	var spray_id := falls._sprays[0].get_instance_id()
	falls.rebuild(data)
	check(falls.get_child(0).get_instance_id() == mesh_id and falls._sprays[0].get_instance_id() == spray_id,"Warm rebuild keeps geometry and spray nodes")
	data.begin_stroke()
	data.brush(Vector2(10,10),1.0,0.6,"raise",0.0)
	data.end_stroke()
	falls.rebuild(data)
	check(falls.get_child(0).get_instance_id() == mesh_id and falls._sprays[0].get_instance_id() == spray_id,"Distant sculpt preserves live geometry and spray")
	fresh_matches(data,falls,"Distant reuse equals a complete fresh build")
	data.begin_stroke()
	data.brush(Vector2(-2,0),1.0,0.3,"raise",0.0)
	data.end_stroke()
	falls.rebuild(data)
	check(snapshot(falls) != original,"Editing the course updates or suspends the fall")
	fresh_matches(data,falls,"Changed course equals a fresh build")
	data.undo()
	falls.rebuild(data)
	check(snapshot(falls) == original,"Undo restores exact geometry and spray")
	data.objects[0].scale = 1.2
	falls.rebuild(data)
	fresh_matches(data,falls,"Width change equals fresh geometry")
	check(snapshot(falls) != original,"Width changes rendered state")
	data.ponds[0].level = -0.1
	falls.rebuild(data)
	fresh_matches(data,falls,"Changed receiving pond equals fresh geometry")
	var before_mist := falls.rebuilt_falls
	falls._mist_recipe.size[0] *= 1.1
	falls.rebuild(data)
	check(falls.rebuilt_falls > before_mist,"Mist recipe change invalidates retained spray")
	fresh_matches(data,falls,"Changed spray recipe equals fresh result")
	var first_id := falls.get_child(0).get_instance_id()
	var second := data.objects[0].duplicate(true)
	second.id = 2
	data.objects.append(second)
	falls.rebuild(data)
	check(falls.get_child_count() == 4 and falls.get_child(0).get_instance_id() == first_id,"Adding another fall preserves existing geometry")
	data.objects[1].scale = 0.7
	falls.rebuild(data)
	check(falls.get_child(0).get_instance_id() == first_id,"Changing one fall leaves its neighbor intact")
	fresh_matches(data,falls,"Multiple fall order and outputs match fresh build")
	data.objects.remove_at(0)
	falls.rebuild(data)
	fresh_matches(data,falls,"Removing first fall preserves deterministic remaining child order")
	data.objects.clear()
	falls.rebuild(data)
	check(falls.get_child_count() == 0 and falls._sprays.is_empty(),"Deleting fall removes geometry and spray")
	print("Fall semantic reuse: ",failures," failures; retained ",falls.reused_falls," rebuilt ",falls.rebuilt_falls)
	falls.free()
	quit(1 if failures else 0)
