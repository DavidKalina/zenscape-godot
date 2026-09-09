extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	# Spatial playback starts on the physics tick, after the node's _ready.
	await physics_frame
	await process_frame
	var ambience = scene._ambient_audio
	var calm: Vector3 = ambience.target_gains(0.4,0,0,0,1,1)
	var rain: Vector3 = ambience.target_gains(2,1,0,0,1,1)
	var frozen: Vector3 = ambience.target_gains(2,1,1,1,1,1)
	check(rain.x > calm.x and rain.y > calm.y,"Wind and rain increase the native mix")
	check(frozen.y == 0.0 and frozen.z == 0.0,"Snow is quiet and frozen falls stop")
	check(ambience.target_gains(1,0,0,0,1,0).z == 0.0,"Empty water has no waterfall sound")
	check(ambience.target_gains(1,0,0,0,0.5,1).z == 0.0,"Unfinished land has no floating waterfall sound")
	ambience.update_state(1.0,false,2,1,0,0,1,1)
	var before: Vector3 = ambience.gains
	ambience.update_state(1.0,true,0,0,1,1,1,1)
	check(ambience.gains == before,"Pause freezes mix envelopes")
	for player in [ambience.wind_player,ambience.rain_player,ambience.water_player]:
		check(player.stream_paused,"Pause stops each audio stream")
		check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end > 0,"Native bed is a populated looping stream")
	ambience.muted = true
	ambience.update_state(0.1,false,2,1,0,0,1,1)
	check(ambience.wind_player.stream_paused and ambience.rain_player.stream_paused and ambience.water_player.stream_paused,"Ambient mute covers every bed")
	ambience.muted = false
	ambience.update_state(0.1,false,2,1,0,0,1,1)
	check(not ambience.water_player.stream_paused,"Unmuting resumes ambience")
	# Exercise the production scene wiring, then remove all water through the editor.
	ambience.water_layout.refresh_in = 0.0
	ambience.update_world(0.05,false,scene)
	check(ambience.water_layout.points.has("fall"),"Imported waterfall is found in rendered geometry")
	check(ambience.water_player.global_position == ambience.water_layout.points.get("fall"),"Waterfall sound follows its actual surface")
	scene._chunk_editor.start_flat()
	ambience.water_layout.refresh_in = 0.0
	ambience.update_world(1.0,false,scene)
	check(ambience.water_layout.points.is_empty(),"Deleting water removes every water emitter")
	check(ambience.nature.beds.stream.volume_db <= -79 and ambience.nature.beds.shore.volume_db <= -79,"Dry land does not play stream or shore noise")
	var editor = scene._chunk_editor
	editor.data.begin_stroke()
	editor.data.mountain(Vector2(-5,0),7.0,10.0)
	editor.data.brush(Vector2(3,0),3.0,1.0,"lower",0.0)
	editor.data.end_stroke()
	check(editor.data.add_pond(Vector2(3,0),-0.2),"Create authored pond for sound")
	editor.refresh()
	ambience.water_layout.refresh_in = 0.0
	ambience.update_world(0.05,false,scene)
	check(ambience.water_layout.points.has("shore"),"Authored pond receives a shore emitter")
	editor.start_flat()
	for i in range(editor.data.points.size()):
		editor.data.heights[i] = 2.5-editor.data.points[i].x*0.3
	check(editor.data.add_waterfall(Vector2(-4,0),Vector2(4,0),0.5),"Create authored fall for sound")
	editor.refresh()
	ambience.water_layout.refresh_in = 0.0
	ambience.update_world(0.05,false,scene)
	check(ambience.water_layout.points.has("fall"),"Authored waterfall receives an emitter")
	editor.start_flat()
	editor.form_range()
	editor.fill_landscape_streams()
	ambience.water_layout.refresh_in = 0.0
	ambience.update_world(0.05,false,scene)
	check(ambience.water_layout.points.has("stream"),"Authored landscape stream receives its own emitter")
	ambience.update_world(0.05,true,scene)
	for player in ambience.nature.beds.values(): check(player.stream_paused,"Scene pause reaches new sound beds")
	scene.queue_free()
	await process_frame
	print("PASS: ambience weather, growth, loops, pause and mute" if failures == 0 else "FAIL: ambience")
	quit(1 if failures else 0)
