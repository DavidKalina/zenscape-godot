extends "res://tools/film_god_mode_playground.gd"
var caption := Label.new()
var stone: RigidBody3D
var log_body: RigidBody3D
var boulder: RigidBody3D
var max_skips := 0
var _log_wait := 0
var log_swimming := false
var log_recovered := false
var observed_hits := {"stone":0,"log":0,"boulder":0}
var max_dodges := 0
func _run() -> void:
	await super._run()
	stone = scene.loose_props.bodies[0]
	log_body = scene.loose_props.bodies[3]
	boulder = scene.loose_props.bodies[4]
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(caption)
	caption.position = Vector2(80,70)
	caption.add_theme_font_size_override("font_size",40)
	caption.add_theme_color_override("font_color",Color("ffe8bd"))
	caption.add_theme_color_override("font_shadow_color",Color("193126"))
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
func _frame() -> void:
	frame += 1
	if frame>=360 and frame<=720:
		if scene.creature.state == CreatureActor.State.SWIMMING: log_swimming = true
		if log_swimming and scene.creature.can_roam(): log_recovered = true
	# Give the log-to-water recovery its complete performance before the next setup.
	if frame == 720 and _log_wait<240:
		frame = 719
		_log_wait += 1
		return
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440,960)
		root.content_scale_factor = 1.0
	if frame == 30:
		scene.reset_creature()
		scene._attention_time = 100.0
		caption.text = "A stone. A flick. A strongly worded look."
	if frame == 60:
		scene.loose_props.begin_grab(stone,scene.camera.unproject_position(stone.global_position))
	if frame>=90 and frame<104:
		var props = scene.loose_props
		var offset := Vector3(0.7,0,-1.15)*float(frame-90)/13.0
		props.move_grab(scene.camera.unproject_position(props._origin+offset))
	if frame == 104: scene.loose_props.release()
	if frame == 360:
		scene.reset_creature()
		scene._attention_time = 100.0
		caption.text = "A rolling log rearranges his afternoon."
		log_body.global_position = scene.creature.global_position+Vector3(0,0.45,2.7)
		log_body.release(Vector3(0,0,-8))
	if frame == 720:
		scene.reset_creature()
		scene._attention_time = 100.0
		caption.text = "Low and fast: skipping stones."
		stone.global_position = Vector3(2.0,0.4,0)
		stone.release(Vector3(6,-0.8,0))
	if frame == 930:
		caption.text = "The log would rather float."
		log_body.global_position = Vector3(3,1.0,0)
		log_body.release(Vector3(0.2,0,0))
	if frame == 1260:
		scene.reset_creature()
		scene._attention_time = 100.0
		caption.text = "He sees the boulder coming."
		boulder.global_position = scene.creature.global_position+Vector3(0,0.85,4.5)
		boulder.release(Vector3(0,0,-4.5))
	if frame == 1530:
		scene.reset_creature()
		scene._attention_time = 0.0
		caption.text = "Something new to investigate."
		stone.global_position = Vector3(3.2,0.5,5.0)
		stone.release(Vector3.ZERO)
	max_skips = maxi(max_skips,stone.skip_count)
	max_dodges = maxi(max_dodges,scene.loose_props.dodges)
	for key in observed_hits: observed_hits[key] = maxi(observed_hits[key],scene.loose_props.hits[key])
	if frame == 2040:
		scene.reset_creature()
		scene._attention_time = 100.0
		caption.text = "A little heft. Then let gravity do the work."
	if frame == 2070:
		scene.loose_props.begin_grab(boulder,scene.camera.unproject_position(boulder.global_position))
	if frame>=2070 and frame<2110:
		scene.loose_props.move_grab(scene.camera.unproject_position(scene.loose_props._origin+Vector3(0.6,0,0)))
	if frame == 2130: scene.loose_props.release()
	if frame == 2460:
		print("LOOSE FILM ",JSON.stringify({"log_swimming":log_swimming,"log_recovered":log_recovered,"hits":observed_hits,"skips":max_skips,"dodges":max_dodges,"investigations":scene.loose_props.investigations}))
		physics_frame.disconnect(_frame)
		scene.queue_free()
		await process_frame
		quit(0 if observed_hits.stone>0 and observed_hits.log>0 and max_skips>0 and max_dodges>0 and log_recovered else 1)
