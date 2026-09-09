class_name CreatureActor
extends Node3D
## A small interaction contract shared by animated inhabitants. Asset clips own
## performance; this node owns carrying, safe placement and attention.
enum State { IDLE, HELD, LANDING, ALERT, WIND, RECOVERING, WALKING, ACTION, STUMBLING, SWIMMING, SHAKING }
signal state_changed(value: State)
signal landed()
signal footstep(point: Vector3)
signal action_finished(clip: String, cancelled: bool)
const PERSONALITY = preload("res://scripts/bigfoot_personality.gd")
var personality_active := false
var _original_clips := {}
var _personality_clips := {}
const HAND_REACH = preload("res://scripts/creature_hand_reach.gd")
signal water_splash(point: Vector3, strength: float)
var water_level := 0.0
var water_exit := Vector3.ZERO
var _paddle_time := 0.0
var hand_targets := {}
var environment_pose := ""
var environment_motion := {}
var tree_peek = preload("res://scripts/creature_tree_peek.gd").new()
var action_tempo := 1.0
var locomotion_tempo := 1.0
var _pending_tremor := 0.0
var _stumble_strength := 0.0
var _stumble_duration := 0.0
var action_clip := ""
var _action_duration := 0.0
var state := State.IDLE
var actor: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var land_position := Vector3.ZERO
var grasp_height := 2.70
var _safe_position := Vector3.ZERO
var _visual := Node3D.new()
var _head := -1
var wet_coat: Node3D
var _breath: Node3D
var _mouth: Node3D
var _mouth_offset := Transform3D.IDENTITY
var _gaze := Vector3.ZERO
var _gaze_weight := 0.0
var _gaze_yaw := 0.0
var _gaze_pitch := 0.0
var _age := 0.0
var _vertical_speed := 0.0
var _touchdown := false
var _sway := Vector2.ZERO
var wind_body: RigidBody3D
var _wind_field: Node
var _ground_probe: Callable
var _safe_landing: Callable
var _settled_time := 0.0
var blast_airborne := false
var _recover_from := Transform3D.IDENTITY
var _recover_to := Transform3D.IDENTITY
var _brace := Vector2.ZERO
var _standing_basis := Basis.IDENTITY
const WALK_SPEED_MPS := 0.54/(0.62*3.6)
const WIND_BODY = preload("res://scripts/creature_wind_body.gd")

## Navigation uses the same effective speed as the walking step.
func walking_speed(base_speed: float) -> float:
	return base_speed*locomotion_tempo

## Navigation supplies a nearby, already validated point. Animation owns the
## stride while this actor owns facing, locomotion and its latest safe feet.
func can_roam() -> bool:
	return player != null and state in [State.IDLE,State.ALERT,State.WALKING]

## True means this waypoint was reached; keep the stride continuous until the
## controller calls stop_walking at the final destination. False means progressing
## or rejected by can_roam/input. Gait is selected when entering WALKING;
## stop_walking before changing it during a journey. Speed is the calm baseline;
## temper scales both displacement and animation cadence here.
func walk_step(destination: Vector3, speed: float, delta: float, gait := "Walk") -> bool:
	if not can_roam() or not destination.is_finite() or not is_finite(speed) or not is_finite(delta) or speed <= 0.0 or delta <= 0.0:
		return false
	speed = walking_speed(speed)
	var offset := destination-global_position
	var horizontal := Vector2(offset.x,offset.z).length()
	var dt := minf(delta,0.05)
	var distance := minf(speed*dt,horizontal)
	var next_feet := destination if horizontal <= 0.001 else global_position+offset*(distance/horizontal)
	if _ground_probe.is_valid():
		var ground: Variant = _ground_probe.call(next_feet)
		if not ground is Vector3 or not ground.is_finite():
			stop_walking()
			return false
		next_feet.y = ground.y
	if horizontal <= 0.001:
		global_position = next_feet
		_safe_position = next_feet
		land_position = next_feet
		return true
	if state != State.WALKING:
		_state(State.WALKING)
		_play(gait)
	var yaw := atan2(offset.x,offset.z)
	var facing := global_rotation.y
	global_basis = Basis(Vector3.UP,lerp_angle(facing,yaw,1.0-exp(-7.0*dt)))
	_standing_basis = global_basis
	global_position = next_feet
	_safe_position = global_position
	land_position = global_position
	player.speed_scale = speed/WALK_SPEED_MPS
	if distance >= horizontal:
		return true
	return false

## Small planted stepping turn, used before reaching for a nearby object.
func turn_step(yaw: float, delta: float) -> bool:
	if not can_roam(): return false
	var error := angle_difference(global_rotation.y,yaw)
	if absf(error)<0.015:
		stop_walking()
		return true
	if state != State.WALKING:
		_state(State.WALKING)
		_play("Walk")
	player.speed_scale = 0.6
	global_rotation.y += clampf(error,-1.2*delta,1.2*delta)
	_standing_basis = global_basis
	return false

## An authored one-shot or timed loop owns motion until completion/interruption.
func perform_action(clip: String, duration := -1.0) -> bool:
	if not can_roam() or not player.has_animation(clip): return false
	stop_walking()
	_state(State.ACTION)
	action_clip = clip
	_action_duration = player.get_animation(clip).length if duration < 0.0 else duration
	_gaze_weight = 0.0
	_play(clip)
	return true

func cancel_action() -> void:
	if state != State.ACTION: return
	_state(State.IDLE)
	_play("Idle")

func hand_position(side := "R") -> Vector3:
	return HAND_REACH.palm(skeleton,side)

func reach_hand(point: Vector3, weight: float, side := "R", elbow: Variant = null, palm_basis: Variant = null, palm_weight := 1.0) -> void:
	hand_targets[side] = {"point":point,"weight":weight,"elbow":elbow,"basis":palm_basis,"palm_weight":palm_weight}

func clear_hand_targets() -> void:
	hand_targets.clear()

func stop_walking() -> void:
	if state != State.WALKING: return
	_state(State.IDLE)
	_play("Idle")

## Queue on the event; consume on the actor clock so pause defers the reaction.
func queue_tremor(strength: float) -> void:
	if not is_finite(strength) or strength<0.2: return
	if state in [State.HELD,State.LANDING,State.WIND,State.RECOVERING,State.SWIMMING,State.SHAKING]: return
	_pending_tremor = maxf(_pending_tremor,clampf(strength,0.0,1.0))

func _start_stumble(strength: float) -> void:
	if state in [State.HELD,State.LANDING,State.WIND,State.RECOVERING,State.SWIMMING,State.SHAKING]: return
	_stumble_strength = maxf(_stumble_strength,strength) if state == State.STUMBLING else strength
	_stumble_duration = 1.1+_stumble_strength*1.2
	_gaze_weight = 0.0
	_state(State.STUMBLING)
	_play("Tremor" if personality_active else "Land")
	if personality_active: player.speed_scale = 2.3/_stumble_duration

func _pose_stumble() -> void:
	if personality_active: return
	var fade := smoothstep(0.0,0.12,_age)*(1.0-smoothstep(_stumble_duration-0.6,_stumble_duration,_age))
	var response := fade*_stumble_strength
	var spine := skeleton.find_bone("Spine")
	var roll := sin(_age*9.0)*exp(-_age*0.8)*response*0.65
	if spine>=0:
		HAND_REACH._rotate(skeleton,spine,Vector3.UP,Basis.from_euler(Vector3(response*0.12,0,roll))*Vector3.UP,1.0)
	for side in ["R","L"]:
		var upper := skeleton.find_bone("UpperArm_"+side)
		var lower := skeleton.find_bone("Forearm_"+side)
		if upper<0 or lower<0: continue
		skeleton.force_update_all_bone_transforms()
		var arm := skeleton.get_bone_global_pose(lower).origin-skeleton.get_bone_global_pose(upper).origin
		var sign := -1.0 if side == "R" else 1.0
		var direction := Vector3(sign,0.1+sin(_age*7.0+sign)*0.2,0.3)
		HAND_REACH._rotate(skeleton,upper,arm,direction,response)

func enable_wind(field: Node, ground_probe: Callable, safe_landing: Callable) -> void:
	_standing_basis = global_basis.orthonormalized()
	_wind_field = field
	_ground_probe = ground_probe
	_safe_landing = safe_landing
	if wind_body == null:
		wind_body = WIND_BODY.new()
		add_child(wind_body)
		wind_body.top_level = true
		wind_body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	wind_body.field = field

## Environmental contact enters the same physical tumble/recovery as wind.
func receive_impulse(impulse: Vector3) -> bool:
	if wind_body == null or not impulse.is_finite() or impulse.length() < 0.1:
		return false
	if state in [State.HELD, State.LANDING, State.RECOVERING, State.SWIMMING, State.SHAKING]: return false
	if state != State.WIND: _start_physical_tumble()
	wind_body.apply_impulse(impulse.limit_length(300.0), Vector3.UP*0.65)
	return true

## Blast strength is a velocity change, independent of the resident's mass.
func receive_blast(velocity: Vector3) -> bool:
	if wind_body == null or not velocity.is_finite() or velocity.length() < 0.1 or is_held(): return false
	if state != State.WIND: _start_physical_tumble()
	blast_airborne = true
	_age = 0.0
	_settled_time = 0.0
	_pending_tremor = 0.0
	wind_body.blast_flight = true
	wind_body.linear_damp = 0.15
	wind_body.linear_velocity = (wind_body.linear_velocity+velocity).limit_length(40.0)
	wind_body.angular_velocity = Vector3(velocity.z,0,-velocity.x).limit_length(2.5)
	return true

func _start_physical_tumble() -> void:
	if state != State.RECOVERING: _standing_basis = global_basis.orthonormalized()
	wind_body.start(global_transform)
	_settled_time = 0.0
	_visual.transform = Transform3D.IDENTITY
	_state(State.WIND)
	_play("Airborne")

func _physics_process(delta: float) -> void:
	if wind_body == null or not is_instance_valid(_wind_field): return
	if state in [State.HELD, State.LANDING, State.SWIMMING, State.SHAKING]: return
	var wind: Vector3 = _wind_field.sample(global_position+Vector3.UP*1.4)
	var strength := wind.length()
	_brace = Vector2(clampf(wind.z*0.016,-0.14,0.14),clampf(-wind.x*0.016,-0.14,0.14))
	if state != State.WIND and strength >= 7.0:
		_start_physical_tumble()
	if state == State.WIND:
		var quiet: bool = strength < 4.0 and wind_body.get_contact_count() > 0 and wind_body.linear_velocity.length() < 0.65 and wind_body.angular_velocity.length() < 0.85
		_settled_time = _settled_time+delta if quiet else 0.0
		if blast_airborne:
			# Let a mountain fall reach lower ground; an off-island fall respawns.
			var ground: Variant = _ground_probe.call(wind_body.global_position) if _ground_probe.is_valid() else null
			if wind_body.global_position.y < -18.0 or (_age > 12.0 and ground == null):
				var center: Variant = _safe_landing.call(Vector3.ZERO) if _safe_landing.is_valid() else null
				if center is Vector3 and center.is_finite(): reset_at(center)
				else: reset_at(_safe_position)
			elif (_age > 1.0 and _settled_time > 0.55) or _age > 12.0:
				_begin_recovery()
		elif (_age > 1.0 and _settled_time > 0.55) or wind_body.global_position.y < _safe_position.y-12.0:
			_begin_recovery()

func _begin_recovery() -> void:
	_recover_from = wind_body.feet_transform()
	var location: Variant = null
	if _ground_probe.is_valid(): location = _ground_probe.call(wind_body.global_position)
	if location is Vector3 and _safe_landing.is_valid(): location = _safe_landing.call(location)
	var destination: Vector3 = location if location is Vector3 and location.is_finite() else _safe_position
	_recover_to = Transform3D(_standing_basis,destination)
	wind_body.stop()
	global_transform = _recover_from
	_state(State.RECOVERING)
	_play("Land")


func setup(asset_path: String) -> void:
	add_child(_visual)
	actor = load(asset_path).instantiate()
	_visual.add_child(actor)
	player = actor.find_child("AnimationPlayer",true,false)
	var rigs := actor.find_children("*","Skeleton3D",true,false)
	assert(player != null and rigs.size() == 1,"An inhabitant needs an animation player and one skeleton")
	skeleton = rigs[0]
	wet_coat = preload("res://scripts/bigfoot_wetness.gd").new()
	add_child(wet_coat)
	wet_coat.setup(actor,skeleton)
	add_to_group("personality_actors")
	# Keep each actor's library private: profile changes must not mutate imports.
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("",library)
	for clip in ["Walk","Idle","Held"]:
		_original_clips[clip] = library.get_animation(clip).duplicate()
		_original_clips[clip].loop_mode = Animation.LOOP_LINEAR
	library.add_animation("Airborne",_original_clips["Held"].duplicate())
	_personality_clips = PERSONALITY.clips_for(player,skeleton)
	# A hug owns its acting. Freeze the neutral authored stance so Idle's
	# independent glances and weight shifts cannot fight the embrace.
	var hug_base := Animation.new()
	hug_base.length = 5.2
	hug_base.loop_mode = Animation.LOOP_LINEAR
	var idle_base: Animation = _personality_clips["Idle"]
	for track in range(idle_base.get_track_count()):
		if idle_base.track_get_key_count(track) == 0: continue
		var index := hug_base.add_track(idle_base.track_get_type(track))
		hug_base.track_set_path(index,idle_base.track_get_path(track))
		hug_base.track_insert_key(index,0.0,idle_base.track_get_key_value(track,0))
	library.add_animation("TreeHugBase",hug_base)
	library.add_animation("Tremor",_personality_clips["Tremor"])
	install_action_personality()
	_head = skeleton.find_bone("Head")
	_mouth = actor.find_child("BreathOrigin",true,false) as Node3D
	if _mouth != null:
		_mouth_offset = skeleton.get_bone_global_rest(_head).affine_inverse()*skeleton.global_transform.affine_inverse()*_mouth.global_transform
		_breath = preload("res://scripts/bigfoot_breath.gd").new()
		add_child(_breath)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["Idle","Held","Land","Alert","Walk"]:
		assert(player.has_animation(clip),"Missing inhabitant clip: "+clip)
	for clip in ["Idle","Held","Walk"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in ["Sit","Sleep"]:
		if player.has_animation(clip): player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in ["Land","Alert"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_safe_position = global_position
	land_position = _safe_position
	_play("Idle")

func install_action_personality() -> void:
	var library := player.get_animation_library("")
	for clip in PERSONALITY.ACTIONS:
		if library.has_animation(clip) and not _original_clips.has(clip):
			_original_clips[clip] = library.get_animation(clip).duplicate()
	set_personality(PERSONALITY.enabled)

## Preserve the settled feet of this arrival rather than blending the legs
## back to an unrelated frame of Idle. Upper-body acting stays neutral.
func prepare_tree_hug_base() -> void:
	var base: Animation = player.get_animation("TreeHugBase")
	var spine := skeleton.find_bone("Spine")
	for track in range(base.get_track_count()):
		var path := base.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := skeleton.find_bone(str(path.get_subname(0)))
		if bone<0: continue
		var ancestor := bone
		while ancestor>=0 and ancestor != spine: ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor == spine: continue
		match base.track_get_type(track):
			Animation.TYPE_POSITION_3D: base.track_set_key_value(track,0,skeleton.get_bone_pose_position(bone))
			Animation.TYPE_ROTATION_3D: base.track_set_key_value(track,0,skeleton.get_bone_pose_rotation(bone))
			Animation.TYPE_SCALE_3D: base.track_set_key_value(track,0,skeleton.get_bone_pose_scale(bone))

func set_personality(enabled: bool) -> void:
	if _original_clips.is_empty(): return
	var current := player.current_animation
	var position := player.current_animation_position if not current.is_empty() else 0.0
	var tempo := player.speed_scale
	var replacing := _original_clips.has(current)
	if replacing: player.stop()
	var library := player.get_animation_library("")
	for clip in _original_clips:
		library.remove_animation(clip)
		library.add_animation(clip,_personality_clips[clip] if enabled else _original_clips[clip])
	personality_active = enabled
	if replacing:
		player.play(current,0.15)
		player.seek(fposmod(position,player.get_animation(current).length),true)
		player.speed_scale = tempo

func _process(delta: float) -> void:
	advance(delta)

func _play(clip: String) -> void:
	player.speed_scale = 1.0
	player.play(clip,0.12)
	player.advance(0.0)

func _state(value: State) -> void:
	var cancelled_clip := action_clip if state == State.ACTION and value != State.ACTION else ""
	if not cancelled_clip.is_empty():
		action_clip = ""
		clear_hand_targets()
	state = value
	_age = 0.0
	state_changed.emit(value)
	if not cancelled_clip.is_empty(): action_finished.emit(cancelled_clip,true)

func is_held() -> bool:
	return state == State.HELD

func pick_up() -> bool:
	if state == State.HELD or player == null:
		return false
	blast_airborne = false
	if wind_body != null:
		if state == State.WIND: global_transform = wind_body.feet_transform()
		var head_world := to_global(Vector3(0,grasp_height,0.04))
		wind_body.stop()
		global_basis = _standing_basis
		global_position = head_world-_standing_basis*Vector3(0,grasp_height,0.04)
		_visual.transform = Transform3D.IDENTITY
	_sway = Vector2.ZERO
	_vertical_speed = 0.0
	_touchdown = false
	_state(State.HELD)
	_play("Held")
	return true

func move_held(world_position: Vector3, delta: float) -> void:
	if not is_held() or not world_position.is_finite():
		return
	var dt := maxf(delta,0.001)
	var velocity := (world_position-global_position)/dt
	_sway = Vector2(clampf(velocity.z*0.018,-0.24,0.24),clampf(-velocity.x*0.018,-0.24,0.24))
	global_position = world_position

## Invalid ground returns to the last safe spot; it never drops into the void.
func release_at(point: Variant) -> bool:
	if not is_held():
		return false
	if point is Vector3 and _safe_landing.is_valid(): point = _safe_landing.call(point)
	var valid: bool = point is Vector3 and point.is_finite()
	land_position = point if valid else _safe_position
	global_position.y = maxf(global_position.y,land_position.y+0.12)
	_vertical_speed = 0.0
	_touchdown = false
	_state(State.LANDING)
	return valid

## Sustained attention updates gaze without restarting an authored reaction.
func track_gaze(point: Vector3) -> void:
	if not point.is_finite(): return
	_gaze = point
	_gaze_weight = 1.0

func notice(point: Vector3) -> void:
	if not point.is_finite(): return
	track_gaze(point)
	if state == State.IDLE or state == State.ALERT:
		_state(State.ALERT)
		_play("Alert")

func reset_at(point: Vector3) -> void:
	if not point.is_finite(): return
	blast_airborne = false
	if _breath != null: _breath.clear()
	if wet_coat != null: wet_coat.clear_drops()
	if wind_body != null:
		wind_body.stop()
		global_basis = _standing_basis
	global_position = point
	land_position = point
	_safe_position = point
	_pending_tremor = 0.0
	_touchdown = false
	_sway = Vector2.ZERO
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	_state(State.IDLE)
	_play("Idle")

## The playground supplies a checked, unobstructed route to dry shore.
func enter_water(level: float, shore: Vector3) -> bool:
	if not is_held() or not is_finite(level) or not shore.is_finite(): return false
	water_level = level
	water_exit = shore
	_paddle_time = 0.0
	_sway = Vector2.ZERO
	_visual.transform = Transform3D.IDENTITY
	_state(State.SWIMMING)
	_play("Airborne")
	water_splash.emit(Vector3(global_position.x,level,global_position.z),1.0)
	return true

func _advance_water(dt: float) -> void:
	if state == State.SWIMMING:
		var offset := water_exit-global_position
		offset.y = 0.0
		if offset.length() > 0.05:
			global_rotation.y = lerp_angle(global_rotation.y,atan2(offset.x,offset.z),1.0-exp(-3.0*dt))
		if _age > 1.0:
			global_position += offset.limit_length(1.3*dt)
		var ground: Variant = _ground_probe.call(global_position) if _ground_probe.is_valid() else null
		var floor_height: float = ground.y if ground is Vector3 else water_level-2.0
		var floating := maxf(floor_height,water_level-1.65+sin(_age*5.0)*0.09)
		global_position.y = lerpf(global_position.y,floating,1.0-exp(-8.0*dt))
		_paddle_time += dt
		if _paddle_time > 0.42:
			_paddle_time = 0.0
			water_splash.emit(Vector3(global_position.x,water_level,global_position.z),0.25)
		if offset.length() < 0.08:
			global_position = water_exit
			_safe_position = water_exit
			land_position = water_exit
			_standing_basis = global_basis
			_state(State.SHAKING)
			_play("Land")
	elif state == State.SHAKING:
		if _age < 1.5:
			_visual.rotation.z = sin(_age*32.0)*0.16*sin(PI*minf(_age/1.5,1.0))
			if int(_age*12.0) != int((_age-dt)*12.0):
				water_splash.emit(global_position+Vector3.UP*1.5,0.18)
		else:
			_visual.transform = Transform3D.IDENTITY
			_state(State.ALERT)
			_play("Alert")

func advance(delta: float) -> void:
	if player == null or delta <= 0.0: return
	var dt := minf(delta,0.05)
	if _pending_tremor>0.0:
		_start_stumble(_pending_tremor)
		_pending_tremor = 0.0
	if state == State.ACTION: dt *= action_tempo
	_age += dt
	if state == State.STUMBLING and _age>=_stumble_duration:
		_state(State.ALERT)
		_play("Alert")
	if state == State.ACTION and _age >= _action_duration:
		var finished := action_clip
		clear_hand_targets()
		action_clip = ""
		_state(State.IDLE)
		_play("Idle")
		action_finished.emit(finished,false)
	if state == State.WIND:
		global_transform = wind_body.feet_transform()
	elif state == State.RECOVERING:
		var progress := clampf(_age/1.15,0.0,1.0)
		var ease := progress*progress*(3.0-2.0*progress)
		global_transform = _recover_from.interpolate_with(_recover_to,ease)
		if progress >= 1.0:
			_safe_position = global_position
			land_position = global_position
			blast_airborne = false
			_state(State.ALERT)
			_play("Alert")
	elif state == State.LANDING:
		if not _touchdown:
			_vertical_speed += 12.0*dt
			global_position.x = move_toward(global_position.x,land_position.x,16.0*dt)
			global_position.z = move_toward(global_position.z,land_position.z,16.0*dt)
			global_position.y = maxf(land_position.y,global_position.y-_vertical_speed*dt)
			if global_position.y <= land_position.y+0.001 and Vector2(global_position.x-land_position.x,global_position.z-land_position.z).length() < 0.01:
				global_position = land_position
				_safe_position = land_position
				_touchdown = true
				_age = 0.0
				_play("Land")
				landed.emit()
		elif _age >= player.get_animation("Land").length:
			_state(State.IDLE)
			_play("Idle")
	elif state == State.ALERT and _age >= player.get_animation("Alert").length:
		_state(State.IDLE)
		_play("Idle")
	if state in [State.SWIMMING,State.SHAKING]: _advance_water(dt)
	var walk_before := player.current_animation_position if state == State.WALKING else -1.0
	player.advance(dt)
	_pose_environment()
	if walk_before >= 0.0 and state == State.WALKING:
		var length := player.current_animation_length
		var after := walk_before+dt*player.speed_scale
		# Exported Walk and carrying gaits plant L halfway through, R at wrap.
		for contact in [length*0.5,length]:
			if walk_before < contact and after >= contact:
				var bone := skeleton.find_bone("Foot_L" if contact < length else "Foot_R")
				footstep.emit(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin) if bone >= 0 else global_position)
	var response := 1.0-exp(-10.0*dt)
	var goal := _sway if state == State.HELD else (_brace if state == State.IDLE or state == State.ALERT else Vector2.ZERO)
	_visual.rotation.x = lerpf(_visual.rotation.x,goal.x,response)
	_visual.rotation.z = lerpf(_visual.rotation.z,goal.y,response)
	var grip := Vector3(0,grasp_height,0.04)
	_visual.position = grip-_visual.basis*grip if is_held() else _visual.position.lerp(Vector3.ZERO,response)
	_sway = _sway.lerp(Vector2.ZERO,1.0-exp(-4.0*dt))
	# Small additive head turns layer over authored poses. Re-read the animated
	# bone each frame rather than accumulating rotations into the animation.
	if _head >= 0:
		var local := to_local(_gaze)-Vector3.UP*2.15
		var weight := _gaze_weight if state != State.HELD else 0.0
		_gaze_yaw = lerpf(_gaze_yaw,clampf(atan2(local.x,local.z),-0.45,0.45)*weight,response)
		var pitch_limit := 0.5 if not environment_pose.is_empty() else 0.18
		_gaze_pitch = lerpf(_gaze_pitch,clampf(-atan2(local.y,maxf(Vector2(local.x,local.z).length(),0.1)),-pitch_limit,pitch_limit)*weight,response)
		var base := skeleton.get_bone_pose_rotation(_head)
		skeleton.set_bone_pose_rotation(_head,base*Quaternion.from_euler(Vector3(_gaze_pitch,_gaze_yaw,0)))
	_gaze_weight = maxf(0.0,_gaze_weight-dt*0.18)
	if environment_pose == "tree_hug": tree_peek.correct_head_clearance(self,environment_motion)
	if state == State.SWIMMING:
		for side in ["R","L"]:
			var phase := _age*6.0+(0.0 if side == "R" else PI)
			HAND_REACH.apply(skeleton,to_global(Vector3(0.85 if side == "R" else -0.85,1.6+sin(phase)*0.25,0.5+cos(phase)*0.45)),0.85,side)
	if state == State.STUMBLING: _pose_stumble()
	if state in [State.ACTION,State.WALKING]:
		for side: String in hand_targets:
			var contact: Dictionary = hand_targets[side]
			var resting_arm := {}
			var release := 0.0
			if environment_pose == "tree_hug":
				release = float(environment_motion.get("hands",{}).get(side,{}).get("release",0.0))
				for part in ["UpperArm_","Forearm_","Hand_"]:
					var bone := skeleton.find_bone(part+side)
					resting_arm[bone] = skeleton.get_bone_pose_rotation(bone)
			var palm: Variant = contact.get("basis")
			var palm_weight := clampf(float(contact.get("palm_weight",1.0)),0.0,1.0)
			if palm != null and palm_weight<0.999:
				# First let the authored local wrist follow this frame's arm.
				# Then turn toward the surface, without feeding back last frame's
				# solved wrist or pinning a relaxed hand to a world orientation.
				HAND_REACH.apply(skeleton,contact.point,contact.weight,side,contact.get("elbow"))
				var natural := (skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.find_bone("Hand_"+side)).basis).orthonormalized()
				palm = natural.slerp(palm,palm_weight)
			HAND_REACH.apply(skeleton,contact.point,contact.weight,side,contact.get("elbow"),palm)
			# Finish in the authored joint pose before a nearly straight arm
			# makes the IK elbow plane unstable. The shoulder settles first;
			# the forearm follows, with the wrist staying relative to it.
			for bone: int in resting_arm:
				var start := 0.55 if skeleton.get_bone_name(bone).begins_with("UpperArm_") else 0.65
				var settle := smoothstep(start,1.0,release)
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(resting_arm[bone],settle))

	skeleton.force_update_all_bone_transforms()
	wet_coat.advance(minf(delta,0.05))
	if _breath != null:
		skeleton.force_update_all_bone_transforms()
		var idle := (state==State.IDLE or not environment_pose.is_empty()) and player.current_animation in ["Idle","TreeHugBase"]
		var breath_duration := 5.2 if personality_active else player.get_animation("Idle").length
		var phase := fposmod(player.current_animation_position,breath_duration)/breath_duration if idle else 0.0
		var wind := Vector3.ZERO
		var mouth := skeleton.global_transform*skeleton.get_bone_global_pose(_head)*_mouth_offset
		if is_instance_valid(_wind_field): wind = _wind_field.sample(mouth.origin)
		_breath.advance(dt,mouth,phase,idle,wind)

## Sagittal (knee/hip) bend on the bone's own axis, additive on the animation.
func _bend_leg(bone: int, angle: float) -> void:
	if bone<0: return
	skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.RIGHT,angle))

## Additive torso performance on the current authored pose, never the root/feet.
func _pose_environment() -> void:
	if environment_pose.is_empty() or state != State.ACTION: return
	var spine := skeleton.find_bone("Spine")
	if spine<0: return
	var weight := smoothstep(0.0,0.3,_age)*(1.0-smoothstep(_action_duration-1.0,_action_duration,_age))
	var pose := Vector3.ZERO
	if environment_pose == "tree_hug" and not environment_motion.is_empty():
		# Small chest compression and tilt provide weight with planted feet.
		# Pelvis/root are untouched; hand IK runs after this body performance.
		pose = environment_motion.get("spine",Vector3.ZERO)
		var position := skeleton.get_bone_pose_position(spine)
		position.y -= float(environment_motion.get("compression",0.0))
		skeleton.set_bone_pose_position(spine,position)
		var head_pose: Vector3 = environment_motion.get("head",Vector3.ZERO)
		if _head>=0:
			skeleton.set_bone_pose_rotation(_head,skeleton.get_bone_pose_rotation(_head)*Quaternion.from_euler(head_pose))
		skeleton.set_bone_pose_rotation(spine,skeleton.get_bone_pose_rotation(spine)*Quaternion.from_euler(pose))
		var offset: Vector3 = environment_motion.get("body_offset",Vector3.ZERO)
		tree_peek.offset_upper_body(self,global_basis*offset)
		return
	if environment_pose == "fire_warm" and not environment_motion.is_empty():
		# A real crouch, not a compressed torso: the hip flexes, the knee
		# counter-flexes twice as far and the ankle returns the difference, so
		# the sole stays flat. The rest leg is not a straight two-link chain, so
		# the pelvis drop is measured from where the folded leg actually put the
		# foot rather than computed from segment lengths.
		var bend := float(environment_motion.get("bend",0.0))
		var pelvis := skeleton.find_bone("Pelvis")
		var sole := skeleton.find_bone("Foot_L")
		if bend>0.0 and pelvis>=0 and sole>=0:
			var planted := skeleton.get_bone_global_pose(sole).origin.y
			for side in ["L","R"]:
				_bend_leg(skeleton.find_bone("Thigh_"+side),-bend)
				_bend_leg(skeleton.find_bone("Calf_"+side),2.0*bend)
				_bend_leg(skeleton.find_bone("Foot_"+side),-bend)
			skeleton.force_update_all_bone_transforms()
			var seat := skeleton.get_bone_pose_position(pelvis)
			seat.y += planted-skeleton.get_bone_global_pose(sole).origin.y
			skeleton.set_bone_pose_position(pelvis,seat)
		if _head>=0:
			skeleton.set_bone_pose_rotation(_head,skeleton.get_bone_pose_rotation(_head)*Quaternion.from_euler(environment_motion.get("head",Vector3.ZERO)))
		skeleton.set_bone_pose_rotation(spine,skeleton.get_bone_pose_rotation(spine)*Quaternion.from_euler(environment_motion.get("spine",Vector3.ZERO)))
		return
	match environment_pose:
		"shock": pose = Vector3(-0.12,sin(_age*62.0)*0.07,sin(_age*75.0)*0.09)
		"fire_watch": pose = Vector3(-0.075,0,sin(_age*0.9)*0.014)
		"startle": pose = Vector3(0.22,0,sin(_age*7.0)*0.025)*exp(-_age*0.7)
		"dry": pose = Vector3(0.04,sin(_age*18.0)*0.15,sin(_age*18.0+0.7)*0.055)
		"rain": pose = Vector3(0.08,0,-0.035)
		"tree_hug": pose = Vector3(0.035,0,sin(_age*1.1)*0.012)
	var base := skeleton.get_bone_pose_rotation(spine)
	skeleton.set_bone_pose_rotation(spine,base*Quaternion.from_euler(pose*weight))
