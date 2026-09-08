extends SceneTree
var actors: Array[CreatureActor] = []
var titles: Array[Label] = []
var frame := 0
const BEATS := {1:"SitDown",85:"Sit",211:"StandUp",310:"StoneThrow",580:"TreeShake",850:"FishCatch",1150:"SitDown",1234:"Sleep",1640:"StandUp"}
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var layout := HBoxContainer.new()
	root.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(2):
		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(640,720)
		container.stretch = true
		layout.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640,720)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.33,0.39,0.36)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.8,0.86,1.0)
		environment.environment.ambient_light_energy = 0.6
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-35,0)
		light.light_energy = 1.6
		light.shadow_enabled = true
		world.add_child(light)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40,40)
		floor_mesh.mesh = plane
		world.add_child(floor_mesh)
		var actor := CreatureActor.new()
		world.add_child(actor)
		actor.setup("res://assets/models/zenscape-bigfoot-routine.glb")
		var coat := StandardMaterial3D.new()
		coat.vertex_color_use_as_albedo = true
		coat.roughness = 1.0
		for mesh: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
			if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
		actor.set_process(false)
		actors.append(actor)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(4.0,2.8,6.2)
		camera.look_at(Vector3(0,1.4,0))
		camera.fov = 35
		camera.current = true
		var label := Label.new()
		label.position = Vector2(20,20)
		label.add_theme_font_size_override("font_size",24)
		viewport.add_child(label)
		titles.append(label)
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	if BEATS.has(frame):
		actors[0].cancel_action()
		actors[0].perform_action(BEATS[frame],20.0 if BEATS[frame] in ["Sit","Sleep"] else -1.0)
		titles[0].text = "Action · "+BEATS[frame]
		titles[1].text = "Control · Idle"
		print("ACTION FILM ",frame," ",BEATS[frame])
	for actor in actors: actor.advance(1.0/60.0)
	if frame in [130,375,450,670,960,1400]: _capture.call_deferred(frame)
	if frame >= 1740: quit()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/fidelity-life/actions/pose-%04d.png" % at)
