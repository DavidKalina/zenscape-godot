extends SceneTree
var failures := 0
var contacts := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	# Install carrying as BigfootMischief does, including the legacy loop flag.
	var source := preload("res://assets/models/zenscape-bigfoot-log.glb").instantiate()
	var author: AnimationPlayer=source.find_child("AnimationPlayer",true,false)
	var carrying := author.get_animation("LogCarry").duplicate() as Animation
	carrying.loop_mode=Animation.LOOP_LINEAR
	actor.player.get_animation_library("").add_animation("LogCarry",carrying)
	actor.install_action_personality()
	source.free()
	actor.set_process(false)
	actor.footstep.connect(func(_point: Vector3) -> void: contacts+=1)
	check(actor.gait_step_count()==4,"Heavy gait declares four foot contacts")
	for profile in [true,false]:
		actor.set_personality(profile)
		for gait in ["Walk","LogCarry"]:
			actor.reset_at(Vector3.ZERO)
			contacts=0
			var speed := actor.gait_reference_speed(gait)
			var duration := actor.player.get_animation(gait).length
			for frame in range(roundi(duration*60)+1):
				actor.walk_step(Vector3(0,0,100),speed,1.0/60.0,gait)
				actor.advance(1.0/60.0)
			check(is_equal_approx(actor.player.speed_scale,1.0),"Authored speed plays at 1x: "+gait)
			check(contacts==actor.gait_step_count(gait),"Every contact fires exactly once across loop wrap: "+gait+" profile="+str(profile))
			if gait=="LogCarry":check(is_equal_approx(speed,CreatureActor.WALK_SPEED_MPS),"Carrying keeps its existing stride calibration")
	# Sample the actual controller during both stance halves of the four-step loop.
	actor.set_personality(true)
	actor.reset_at(Vector3.ZERO)
	var previous := {}
	var drift := 0.0
	for frame in range(240):
		actor.walk_step(Vector3(0,0,100),.85,1.0/60.0)
		actor.advance(1.0/60.0)
		actor.skeleton.force_update_all_bone_transforms()
		var time := (frame+1)/60.0
		for side in ["R","L"]:
			var phase := time/1.5+(0.0 if side=="R" else .5)
			if time<.25 or fposmod(phase,1)<.04 or fposmod(phase,1)>.62:continue
			var point := actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Foot_"+side)).origin)
			var key: String=side+str(floori(phase))
			if not previous.has(key):previous[key]=point
			drift=maxf(drift,point.distance_to(previous[key]))
	check(drift<.003,"Gameplay Heavy walk keeps planted feet within 3 mm")
	print("Heavy walk: ",failures," failures; stance drift=",drift," m")
	actor.free()
	quit(1 if failures else 0)
