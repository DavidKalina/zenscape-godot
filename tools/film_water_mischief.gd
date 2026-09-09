extends "res://tools/film_god_mode_playground.gd"
var water_states: Array[int] = []
var dunk_position := Vector3.ZERO
func _frame() -> void:
	frame += 1
	if frame == 60:
		scene.reset_creature()
		scene._attention_time = 30.0
		scene._begin_carry(scene.camera.unproject_position(scene.creature.global_position+Vector3.UP*2.7))
		scene.set_process(false)
	if frame >= 60 and frame < 180:
		var point: Vector3 = scene._home.lerp(Vector3(3,-0.2,0),smoothstep(60.0,130.0,float(frame)))
		scene._update_carry(scene.camera.unproject_position(point),1.0/60.0)
		scene.water_play.advance(1.0/60.0)
	if frame == 180:
		dunk_position = scene.creature.global_position
		scene._drop(scene.camera.unproject_position(Vector3(3,-0.2,0)))
		scene.set_process(true)
	if scene.creature.state not in water_states: water_states.append(scene.creature.state)
	if frame in [150,205,300,410,490,720]: _capture(frame)
	if frame == 900:
		print("WATER FILM ",JSON.stringify({"states":water_states,"dunk_position":str(dunk_position),"final_position":str(scene.creature.global_position),"splashes":scene.water_play.splash_count}))
		physics_frame.disconnect(_frame)
		scene.queue_free()
		await process_frame
		quit(0 if CreatureActor.State.SWIMMING in water_states and CreatureActor.State.SHAKING in water_states else 1)
