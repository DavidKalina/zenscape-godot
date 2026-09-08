extends SceneTree
## Matched stills inside the current product scene, using a disposable world.
const OUTPUT := "res://docs/bigfoot-woodland"
func _initialize() -> void: run.call_deferred()
func snap(name: String) -> void:
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(name))
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-bigfoot-woodland-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	scene._paused = true
	await scene._chunk_editor.form_landscape("valley","woodland",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	assert(scene.invite_bigfoot(Vector3(3,0,3)),"No safe placement")
	scene.set_building(false)
	scene._paused = true
	scene.creature.actor.visible = true
	scene.creature.player.play("Idle")
	scene.creature.player.seek(0.5,true)
	scene.target = scene.creature.global_position+Vector3(0,1.3,0)
	scene.distance = 8.0
	scene.yaw = -1.5
	scene.polar = 1.32
	scene.frame_creature(8.0,-1.5)
	scene._celestial.set_phase(0.5)
	scene._celestial.look.set_value("ambient_energy",1.5)
	scene._celestial.update_rig()
	await snap("redesigned.png")
	var original = load("res://assets/models/zenscape-bigfoot-routine.glb").instantiate()
	scene.creature.actor.get_parent().add_child(original)
	original.transform = scene.creature.actor.transform
	var coat := ShaderMaterial.new()
	coat.shader = load("res://shaders/reference_surface.gdshader")
	for mesh in original.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	var player: AnimationPlayer = original.find_child("AnimationPlayer",true,false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Idle")
	player.seek(0.5,true)
	scene.creature.actor.visible = false
	await snap("original.png")
	scene.free()
	print("BIGFOOT WOODLAND: captured current diorama, matched original and redesign")
	quit()
