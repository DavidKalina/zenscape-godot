extends SceneTree
## Exercise interrupted interactions and imported skeletal clips without input
## timing: a failed drop must never strand the creature outside its safe place.
const ACTOR_SCRIPT = preload("res://scripts/creature_actor.gd")
const ASSET := "res://assets/models/zenscape-bigfoot-interactions.glb"
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func step(creature: Node3D, seconds: float, hz: float = 60.0) -> void:
	for i in range(int(ceil(seconds*hz))):
		creature.advance(1.0/hz)

func finite_pose(creature: Node3D) -> bool:
	if not creature.global_transform.is_finite():
		return false
	var rig: Skeleton3D = creature.skeleton
	for i in range(rig.get_bone_count()):
		if not rig.get_bone_global_pose(i).is_finite():
			return false
	return true

func check_head_grip_clip(creature: Node3D) -> void:
	var rig: Skeleton3D = creature.skeleton
	var player: AnimationPlayer = creature.player
	var tracked := ["Head","Hand_R","Hand_L","Foot_R","Foot_L"]
	for bone: String in tracked:
		check(rig.find_bone(bone) >= 0,"Held performance includes "+bone)
		if rig.find_bone(bone) < 0: return
	player.play("Held",0.0)
	var duration: float = player.get_animation("Held").length
	var samples: Array[Dictionary] = []
	for i in range(25):
		player.seek(duration*float(i)/25.0,true)
		rig.force_update_all_bone_transforms()
		var pose := {}
		for bone: String in tracked:
			pose[bone] = rig.get_bone_global_pose(rig.find_bone(bone))
		check(pose.Hand_R.origin.y < pose.Head.origin.y and pose.Hand_L.origin.y < pose.Head.origin.y,"Held hands remain below the head grip at sample %d" % i)
		check(finite_pose(creature),"Held clip remains finite at sample %d" % i)
		samples.append(pose)
	var head_drift := 0.0
	for sample: Dictionary in samples:
		head_drift = maxf(head_drift,sample.Head.origin.distance_to(samples[0].Head.origin))
	check(head_drift < 0.001,"The head stays anchored while the hanging limbs flail")
	for bone: String in ["Hand_R","Hand_L","Foot_R","Foot_L"]:
		var excursion := 0.0
		for sample: Dictionary in samples:
			excursion = maxf(excursion,sample[bone].origin.distance_to(samples[0][bone].origin))
		check(excursion > 0.05,"Held "+bone+" moves visibly rather than remaining in a static pose")
	player.seek(duration-0.00001,true)
	rig.force_update_all_bone_transforms()
	for bone: String in tracked:
		var ending := rig.get_bone_global_pose(rig.find_bone(bone))
		var start: Transform3D = samples[0][bone]
		check(ending.origin.distance_to(start.origin) < 0.001 and ending.basis.get_rotation_quaternion().angle_to(start.basis.get_rotation_quaternion()) < 0.002,"Held loop returns continuously for "+bone)
	player.play("Idle",0.0)
	player.advance(0.0)

func _run() -> void:
	var creature: Node3D = ACTOR_SCRIPT.new()
	root.add_child(creature)
	creature.set_process(false)
	creature.setup(ASSET)
	check(creature.actor != null and creature.player != null and creature.skeleton != null,"Imported Bigfoot supplies a visual model, animation player and skeleton")
	if creature.actor == null or creature.player == null or creature.skeleton == null:
		quit(1)
		return
	for clip in ["Idle","Held","Land","Alert"]:
		check(creature.player.has_animation(clip),"Imported interaction clip exists: "+clip)
	check_head_grip_clip(creature)
	check(creature.state == ACTOR_SCRIPT.State.IDLE and not creature.is_held(),"Bigfoot begins available for interaction")
	var home: Vector3 = creature.land_position
	check(creature.pick_up() and creature.is_held(),"An idle creature can be picked up")
	var held_point := home+Vector3(2,3,-1)
	creature.move_held(held_point,1.0/60.0)
	creature.advance(1.0/60.0)
	var grip := Vector3(0,creature.grasp_height,0.04)
	check(creature.actor.to_global(grip).distance_to(creature.to_global(grip)) < 0.001,"Carry sway pivots around the head grip without pulling the scalp away")
	step(creature,0.5)
	check(creature.is_held() and finite_pose(creature),"Holding keeps a finite animated pose without timing out")
	check(not creature.release_at(null),"A release with no valid ground is rejected")
	step(creature,4.0)
	check(creature.state == ACTOR_SCRIPT.State.IDLE,"A cancelled drop settles back to idle")
	check(creature.global_position.is_equal_approx(home),"A cancelled drop returns to the prior safe feet position")
	check(creature.land_position.is_equal_approx(home),"A cancelled drop preserves its safe destination")

	var destination := home+Vector3(1,0.7,2)
	check(creature.pick_up(),"Bigfoot can be picked up again after cancellation")
	creature.move_held(destination+Vector3.UP*2.0,1.0/60.0)
	check(creature.release_at(destination),"A valid terrain point accepts the drop")
	check(creature.state == ACTOR_SCRIPT.State.LANDING,"A valid drop starts landing")
	creature.advance(1.0/120.0)
	check(creature.pick_up() and creature.is_held(),"Picking up during landing interrupts it immediately")
	creature.release_at(destination)
	step(creature,4.0,120.0)
	check(creature.state == ACTOR_SCRIPT.State.IDLE,"Landing resolves at high refresh rates")
	check(creature.global_position.is_equal_approx(destination),"Landing settles exactly onto the accepted ground point")
	check(creature.land_position.is_equal_approx(destination),"Successful placement becomes the new safe destination")
	creature.notice(destination+Vector3(2,1,1))
	check(creature.state == ACTOR_SCRIPT.State.ALERT,"A click requests an attention reaction")
	step(creature,4.0,30.0)
	check(creature.state == ACTOR_SCRIPT.State.IDLE and finite_pose(creature),"Attention returns to a finite idle pose at low refresh rates")
	check(creature.global_position.is_equal_approx(destination),"An attention reaction does not move the grounded creature")
	creature.free()
	print("Creature actor: ",failures," failures")
	quit(1 if failures else 0)
