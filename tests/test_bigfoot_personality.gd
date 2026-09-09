extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	for asset in ["interactions","breathing","routine"]:
		var actor := CreatureActor.new()
		root.add_child(actor)
		actor.setup("res://assets/models/zenscape-bigfoot-"+asset+".glb")
		actor.set_process(false)
		check(actor.personality_active,"New clips installed on "+asset)
		check(absf(actor.player.get_animation("Walk").length-3.6)<0.001,"Stride duration preserved")
		check(absf(actor.player.get_animation("Idle").length-15.6)<0.001,"Full idle sequence available")
		actor.player.play("Walk",0.0)
		actor.player.advance(0.0)
		var foot := actor.skeleton.find_bone("Foot_R")
		actor.player.seek(.1,true)
		actor.skeleton.force_update_all_bone_transforms()
		var a := actor.skeleton.get_bone_global_pose(foot).origin
		actor.player.seek(.6,true)
		actor.skeleton.force_update_all_bone_transforms()
		var b := actor.skeleton.get_bone_global_pose(foot).origin
		check((b-a+Vector3(0,0,CreatureActor.WALK_SPEED_MPS*.5)).length()<0.003,"Retargeted stance stays planted on "+asset)
		actor.player.speed_scale = 2.0
		actor.set_personality(false)
		check(actor.player.get_animation("Walk").loop_mode == Animation.LOOP_LINEAR and actor.player.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR,"Original comparison still loops")
		check(not actor.personality_active and actor.player.current_animation=="Walk","Switch retains walk")
		check(absf(actor.player.current_animation_position-.6)<0.001 and actor.player.speed_scale==2.0,"A/B preserves walk phase and tempo")
		actor.pick_up()
		actor.set_personality(true)
		check(actor.is_held() and actor.player.current_animation=="Held","Profile switch does not interrupt a held performance")
		actor.free()
	print("Bigfoot personality: ",failures," failures")
	quit(1 if failures else 0)
