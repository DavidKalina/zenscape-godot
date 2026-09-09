extends "res://tools/film_god_mode_playground.gd"
var boulder: RigidBody3D
var hill_start := Vector3.ZERO
func _run() -> void:
	await super._run()
	boulder = scene.loose_props.bodies[4]
	hill_start = boulder.global_position
func _frame() -> void:
	frame += 1
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440,960)
		root.content_scale_factor = 1.0
	if frame == 60:
		scene.loose_props.begin_grab(boulder,scene.camera.unproject_position(boulder.global_position))
	if frame>=60 and frame<100:
		scene.loose_props.move_grab(scene.camera.unproject_position(scene.loose_props._origin+Vector3(0.6,0,0)))
	if frame == 150: scene.loose_props.release()
	if frame == 600:
		print("BOULDER FILM ",JSON.stringify({"start":str(hill_start),"finish":str(boulder.global_position),"displacement":boulder.global_position.distance_to(hill_start)}))
		physics_frame.disconnect(_frame)
		scene.queue_free()
		await process_frame
		quit()
