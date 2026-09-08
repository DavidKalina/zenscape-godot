extends "res://tools/capture_compare.gd"
## Same capture arguments; --out is a frame directory. Four-second yaw sweep,
## with the paused world fixed, for visual evidence (not a realtime benchmark).
var recorded := 0
var base_yaw := 0.0
var capturing := false
var poses: Array[Dictionary] = []
var base_target := Vector3.ZERO
var base_distance := 18.0
var base_polar := 1.13

func _start() -> void:
	super._start()
	base_yaw = scene.yaw
	base_target = scene.target
	base_distance = scene.distance
	base_polar = scene.polar
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	DirAccess.make_dir_recursive_absolute(out)

func _frame() -> void:
	if capturing: return
	frames += 1
	if frames < settle: return
	capturing = true
	scene._paused = true
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	scene.target = base_target
	scene.distance = base_distance
	scene.polar = base_polar
	scene.yaw = base_yaw + 0.08 * sin(float(recorded) / 119.0 * TAU)
	scene._process(0.0)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_jpg(out.path_join("%04d.jpg" % recorded), 0.97)
	poses.append({"frame":recorded,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance,"target":str(scene.target),"camera":str(scene.camera.transform),"size":str(root.size)})
	if result != OK:
		push_error("Cannot save shadow film frame")
		quit(1)
		return
	recorded += 1
	capturing = false
	if recorded == 120:
		FileAccess.open(out.path_join("poses.json"), FileAccess.WRITE).store_string(JSON.stringify(poses, "\t"))
		print("SHADOW FILM wrote 120 frames to ", out)
		quit()
