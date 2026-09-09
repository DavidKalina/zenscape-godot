extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func pose(actor: CreatureActor, time: float) -> Dictionary:
	actor.player.seek(time,true)
	actor.skeleton.force_update_all_bone_transforms()
	var result := {}
	for bone in ["Head","Pelvis","Hand_R","Hand_L","Foot_R","Foot_L"]:
		result[bone] = actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)).origin
	return result
func _run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	actor.set_process(false)
	actor.pick_up()
	actor.player.play("Held",0.0)
	actor.player.advance(0.0)
	var start := pose(actor,0.0)
	var low := INF
	var high := -INF
	var front := -INF
	var back := INF
	var saw_right_up := false
	var saw_left_up := false
	for i in range(24):
		var a := pose(actor,i*.3)
		var b := pose(actor,i*.3+.15)
		check(a.Foot_R.distance_to(b.Foot_R)+a.Foot_L.distance_to(b.Foot_L)>.12,"Feet keep scrambling throughout the held loop")
		check(a.Hand_R.distance_to(b.Hand_R)+a.Hand_L.distance_to(b.Hand_L)>.06,"Arms keep scooping throughout the held loop")
		check(a.Head.distance_to(start.Head)<.001,"Head anchor remains stable under continuous struggle")
		low = minf(low,a.Foot_R.y)
		high = maxf(high,a.Foot_R.y)
		front = maxf(front,a.Foot_R.z)
		back = minf(back,a.Foot_R.z)
		saw_right_up = saw_right_up or a.Foot_R.y-a.Foot_L.y>.3
		saw_left_up = saw_left_up or a.Foot_L.y-a.Foot_R.y>.3
	check(high-low>.45 and front-back>.55,"Foot strokes form broad cycling arcs")
	check(saw_right_up and saw_left_up,"Feet take turns instead of hopping together")
	check(actor.player.get_animation("Airborne").length==actor._original_clips.Held.length,"Swimming/tumbling retain original flail")
	actor.release_at(Vector3.ZERO)
	for i in range(120): actor.advance(1.0/60.0)
	check(actor.state==CreatureActor.State.IDLE,"Release still lands and returns to idle")
	actor.free()
	print("Held personality: ",failures," failures")
	quit(1 if failures else 0)
