extends SceneTree
## Three seconds of placement reactions, one per class: a tree sprouts, a rock
## drops and squashes, a log lands and rocks to rest, a stump settles with a
## wisp of dust and the old tree sprouts with its thump. Frames land in
## /tmp for ffmpeg:
## ffmpeg -y -framerate 30 -i /private/tmp/drop-reaction-frames/%04d.jpg \
##   -c:v libx264 -pix_fmt yuv420p -crf 23 docs/garden/drop-reactions.mp4
const FPS := 30.0
const FRAMES := 90

func _initialize() -> void:
	call_deferred("run")

func place(editor: NativeChunkEditor, kind: String, point: Vector2, size: float) -> void:
	editor.mode = kind
	editor.object_scale = size
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = editor.scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
	editor.handle_input(event)
	event.pressed = false
	editor.handle_input(event)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.hide()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	editor.data.begin_stroke()
	editor.data.grass.fill(0.8)
	editor.data.end_stroke()
	editor.refresh()
	editor.reactions.set_process(false)
	editor.set_process(false)
	var camera: Camera3D = scene.camera
	camera.global_position = Vector3(-1.0,3.6,9.5)
	camera.look_at(Vector3(0.0,1.0,0.0))
	RenderingServer.global_shader_parameter_set("zs_camera_position",camera.global_position)
	if scene._display_fog != null:
		scene._display_fog.update_view()
	var directory := "/private/tmp/drop-reaction-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	var rest := camera.transform
	var cues := {4:["tree",Vector2(-3.2,0.4),1.3],22:["rock",Vector2(-0.8,1.4),1.1],38:["log",Vector2(1.4,0.8),1.0],52:["stump",Vector2(3.2,-0.2),1.0],64:["bigfoot_tree",Vector2(6.0,-4.0),0.4]}
	for i in range(FRAMES):
		if cues.has(i):
			var cue: Array = cues[i]
			place(editor,cue[0],cue[1],cue[2])
		editor.reactions.advance(1.0/FPS)
		scene._tremor.advance(1.0/FPS,false)
		camera.transform = scene._tremor.apply(rest)
		RenderingServer.force_draw(false)
		await process_frame
		root.get_texture().get_image().save_jpg(directory.path_join("%04d.jpg" % i),0.94)
	print("Drop reaction film: ",FRAMES," frames at ",FPS," fps")
	scene.queue_free()
	await process_frame
	quit()
