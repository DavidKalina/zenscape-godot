extends SceneTree
## Headless regression of the isolated embrace using the real actor and IK.
const Fixture = preload("res://tests/test_bigfoot_environment.gd")
const HUG = preload("res://scripts/bigfoot_tree_hug.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error(message)
func fixture() -> Dictionary:
	var world := Fixture.World.new()
	var life = Fixture.LIFE.new()
	root.add_child(world)
	for child in [world.creature,world.brain,world.routine,world._lightning,life]: world.add_child(child)
	world.creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	world.creature.set_process(false)
	var source := preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	world.navigation.rebuild(data,func(p: Vector3) -> bool: return absf(p.x)>0.76 or absf(p.z)>0.76)
	world.creature._ground_probe = world.navigation._ground
	world.creature.reset_at(Vector3(0,0,-2.5))
	world.habitat.interests = [{"id":"oak","kind":"tree","position":Vector3.ZERO,"bounds":AABB(Vector3(-0.25,0,-0.25),Vector3(0.5,4,0.5))}]
	world.brain.setup(world.creature,world.navigation,func() -> Array: return world.habitat.interests)
	life.setup(world)
	life.autonomous = false
	check(life.request("tree_hug"),"Tree hug route is reachable")
	for frame in range(900):
		life.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
		if life.phase == "perform": break
	check(life.phase == "perform","Real navigation reaches isolated performance")
	return {"world":world,"life":life}
func bone_point(actor: CreatureActor, name: String) -> Vector3:
	return actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(name)).origin)
func authored_wrist(animation: Animation, side: String) -> Quaternion:
	return authored_rotation(animation,"Hand_"+side)
func authored_rotation(animation: Animation, bone_name: String) -> Quaternion:
	for track in range(animation.get_track_count()):
		var path := animation.track_get_path(track)
		if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and path.get_subname_count()>0 and str(path.get_subname(0))==bone_name:
			return animation.track_get_key_value(track,0)
	check(false,"Neutral base supplies the authored local rotation for "+bone_name)
	return Quaternion.IDENTITY
func run() -> void:
	check(HUG.make_variant(4707)==HUG.make_variant(4707),"A performance seed reproduces identical variation")
	check(HUG.make_variant(4707)!=HUG.make_variant(4708),"Different performances vary coherently")
	var f := fixture()
	var actor: CreatureActor = f.world.creature
	var life = f.life
	check(actor.player.current_animation == "TreeHugBase","Hug selects its own neutral base")
	var neutral: Animation = actor.player.get_animation("TreeHugBase")
	var no_glances := neutral.get_track_count()>0
	for track in range(neutral.get_track_count()):
		no_glances = no_glances and neutral.track_get_key_count(track)==1
	check(no_glances,"Neutral base cannot play unrelated authored Idle glances")
	var feet := {"R":bone_point(actor,"Foot_R"),"L":bone_point(actor,"Foot_L")}
	var previous := {"R":actor.hand_position("R"),"L":actor.hand_position("L")}
	var locked := {}
	var resting_palms := previous.duplicate()
	var resting_wrists := {"R":authored_wrist(neutral,"R"),"L":authored_wrist(neutral,"L")}
	var resting_arm_rotations := {}
	var settled_arm_samples := {"R":0,"L":0}
	var max_settled_arm_error := 0.0
	for side in ["R","L"]:
		for part in ["UpperArm_","Forearm_","Hand_"]:
			resting_arm_rotations[part+side] = authored_rotation(neutral,part+side)
	var release_lowest := {}
	var max_rebound := 0.0
	var max_flourish := 0.0
	var max_late_wrist_error := 0.0
	var wrist_samples := {"R":0,"L":0}
	var early_wrist_samples := {"R":0,"L":0}
	var max_early_wrist_error := 0.0
	var max_lock_drift := 0.0
	var max_contact_error := 0.0
	var max_foot_drift := 0.0
	var max_jump := 0.0
	var max_jump_time := 0.0
	var max_foot_time := 0.0
	var initial_root := actor.global_transform
	for frame in range(600):
		life.advance(1.0/60.0)
		actor.advance(1.0/60.0)
		if life.phase != "perform": break
		var normalized_age: float = actor._age / life._duration
		for side in ["R","L"]:
			var palm := actor.hand_position(side)
			var release_motion: Dictionary = actor.environment_motion.get("hands",{}).get(side,{})
			if palm.distance_to(previous[side])>max_jump: max_jump_time = actor._age
			max_jump = maxf(max_jump,palm.distance_to(previous[side]))
			previous[side] = palm
			if bone_point(actor,"Foot_"+side).distance_to(feet[side])>max_foot_drift: max_foot_time = actor._age
			max_foot_drift = maxf(max_foot_drift,bone_point(actor,"Foot_"+side).distance_to(feet[side]))
			if normalized_age>0.34 and float(release_motion.get("approach",0.0))>=1.0 and float(release_motion.get("release",1.0))<=0.0:
				if not locked.has(side): locked[side] = palm
				max_lock_drift = maxf(max_lock_drift,palm.distance_to(locked[side]))
				max_contact_error = maxf(max_contact_error,palm.distance_to(actor.hand_targets[side].point))
			# Before turning toward bark, a rising forearm must carry its neutral
			# wrist naturally; pinning fingers downward in world space folds it.
			var hand_target: Dictionary = actor.hand_targets.get(side,{})
			# Returning to authored joint rotations must happen before the IK
			# weight disappears, not as a last-frame snap when ownership clears.
			if float(release_motion.get("release",0.0))>=1.0 and float(hand_target.get("weight",0.0))>0.99:
				for part in ["UpperArm_","Forearm_","Hand_"]:
					var bone_name: String = part+side
					var actual := actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone(bone_name))
					max_settled_arm_error = maxf(max_settled_arm_error,actual.angle_to(resting_arm_rotations[bone_name]))
				settled_arm_samples[side] += 1
			if normalized_age<0.30 and palm.distance_to(resting_palms[side])>0.035 and float(hand_target.get("weight",0.0))>0.999 and float(hand_target.get("palm_weight",1.0))<0.0001:
				var actual := actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("Hand_"+side))
				max_early_wrist_error = maxf(max_early_wrist_error,actual.angle_to(resting_wrists[side]))
				early_wrist_samples[side] += 1
			# Observe solved world-space geometry, independently of the sampler's
			# release curves: a disengaged palm should fall toward its resting hand.
			if normalized_age>0.66 and locked.has(side) and palm.y<float(locked[side].y)-0.015:
				var lowest: float = release_lowest.get(side,palm.y)
				max_rebound = maxf(max_rebound,palm.y-lowest)
				release_lowest[side] = minf(lowest,palm.y)
				var outward := -1.0 if side == "R" else 1.0
				var rest_x: float = actor.to_local(resting_palms[side]).x*outward
				var contact_x: float = actor.to_local(locked[side]).x*outward
				max_flourish = maxf(max_flourish,actor.to_local(palm).x*outward-maxf(rest_x,contact_x))
				# The wrist relaxes relative to its forearm while IK still owns
				# the arm. A fixed world orientation would fold the wrist as the
				# forearm moves, even if it eventually matches the standing pose.
				if palm.distance_to(resting_palms[side])<0.10 and float(actor.hand_targets[side].weight)>0.999:
					var actual := actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("Hand_"+side))
					var resting: Quaternion = resting_wrists[side]
					max_late_wrist_error = maxf(max_late_wrist_error,actual.angle_to(resting))
					wrist_samples[side] += 1
	print("HUG ARM HANDOFF local_joint_error=",max_settled_arm_error," full_weight_samples=",settled_arm_samples)
	check(settled_arm_samples.R>1 and settled_arm_samples.L>1 and max_settled_arm_error<0.005,"Shoulders, elbows and wrists reach authored neutral while IK still has over 99 percent weight")
	print("HUG EARLY REACH local_wrist_radians=",max_early_wrist_error," samples=",early_wrist_samples)
	check(early_wrist_samples.R>2 and early_wrist_samples.L>2 and max_early_wrist_error<0.10,"Rising forearms retain authored local wrists before rotating toward bark")
	print("HUG RELEASE rebound=",max_rebound," outward_excess=",max_flourish," late_wrist_radians=",max_late_wrist_error," samples=",wrist_samples)
	check(release_lowest.size()==2 and max_rebound<0.015,"Released palms descend without a visible vertical rebound")
	check(max_flourish<0.045,"Release stays within the contact-to-rest width without an outward flourish")
	check(wrist_samples.R>2 and wrist_samples.L>2 and max_late_wrist_error<0.10,"Both wrists regain authored local rotation before full-weight IK fades")
	print("HUG METRICS lock_drift=",max_lock_drift," contact_error=",max_contact_error," foot_drift=",max_foot_drift," max_frame_step=",max_jump," at=",max_jump_time," max_foot_at=",max_foot_time)
	check(locked.size()==2 and max_lock_drift<0.025,"Both world-space palms stay locked during body settle and hold")
	check(max_contact_error<0.055,"Actual palms meet their bark contact targets")
	check(max_foot_drift<0.005 and actor.global_transform.is_equal_approx(initial_root),"Embrace keeps feet and root planted")
	check(max_jump<0.065,"Entering, reaching and releasing have no abrupt hand jumps at 60 Hz")
	check(not life.busy() and actor.hand_targets.is_empty() and actor.environment_motion.is_empty(),"Completion clears environmental ownership and IK")
	f.world.free()
	var rates := {}
	for fps in [30,60,120]:
		f = fixture()
		actor = f.world.creature
		life = f.life
		rates[fps] = []
		for frame in range(fps*8):
			life.advance(1.0/float(fps))
			actor.advance(1.0/float(fps))
			if (frame+1) % (fps/2)==0:
				rates[fps].append(actor.hand_position("R"))
				rates[fps].append(actor.hand_position("L"))
				rates[fps].append(bone_point(actor,"Head"))
		actor.pick_up()
		check(not life.busy() and actor.hand_targets.is_empty() and actor.environment_pose.is_empty() and actor.environment_motion.is_empty(),"Pickup clears hug ownership at %d Hz" % fps)
		f.world.free()
	var rate_error := 0.0
	for fps in [30,120]:
		for bone in range(rates[60].size()): rate_error = maxf(rate_error,rates[fps][bone].distance_to(rates[60][bone]))
	print("HUG FRAME RATE ERROR ",rate_error)
	check(rate_error<0.025,"30/60/120 Hz produce matching reach, hold, release and head poses")
	print("BIGFOOT TREE HUG: failures=",failures)
	await process_frame
	quit(1 if failures else 0)
