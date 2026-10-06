extends Node
## A continuous offer transfers one existing prop from the cursor to his palm.
## This controller owns only the exchange; free objects keep their usual physics.
signal completed(outcome: String)
var scene: Node
var phase := ""
var target: RigidBody3D
var held: RigidBody3D
var outcome := ""
var last_cancel := ""
var history: Array[String] = []
var _age := 0.0
var _steady := 0.0
var _cooldown := 0.0
var _previous := Vector3.ZERO
var _grip := Vector3.ZERO
var _pose := Basis.IDENTITY
var _end := Vector3.ZERO
var _released := false
var _teases := 0
var _was_reachable := false

func setup(play: Node) -> void:
	scene = play

func busy() -> bool:
	return not phase.is_empty()

func accepts(body: RigidBody3D) -> bool:
	return is_instance_valid(body) and body.kind == "stone" and body.radius <= 0.36

func _available() -> bool:
	var owner: Node = scene.owner_scene
	return not scene._habitat_blocked and not scene._carrying and not scene.gust_tool and not scene._tree_drag and not scene.mischief.busy() and not scene.loose_props.busy() and owner.routine.active.is_empty() and (owner.environment_life == null or not owner.environment_life.busy())

func advance(delta: float) -> void:
	if scene._paused: return
	_cooldown = maxf(0.0,_cooldown-delta)
	if not busy():
		var offered: RigidBody3D = scene.loose_props.grabbed
		if _cooldown>0.0 or not accepts(offered) or not _available() or not scene.creature.can_roam(): return
		if scene.creature.global_position.distance_to(offered.global_position)>3.5: return
		target = offered
		_previous = target.global_position
		phase = "watch"
		_age = 0.0
		_steady = 0.0
		_teases = 0
		_was_reachable = false
		_released = false
		last_cancel = ""
		scene.brain.reset_behavior()
		scene.brain.enabled = false
		scene.creature.notice(target.global_position)
		scene._show_reaction("?","Hold it within reach. He wants a closer look.")
	if not is_instance_valid(target) or not _available():
		cancel("exchange interrupted")
		return
	_age += delta
	var actor: CreatureActor = scene.creature
	if phase == "watch" or phase == "reach":
		_watch(delta)
		return
	if actor.state != CreatureActor.State.ACTION or (not _released and held != target):
		cancel("actor or grip interrupted")
		return
	actor.track_gaze(target.global_position)
	if phase == "inspect":
		var chest: Vector3 = actor.to_global(Vector3(-0.48,1.95,0.7))
		var point := _grip.lerp(chest,smoothstep(0.0,0.65,_age))
		point += actor.global_basis.x*sin(maxf(0.0,_age-0.65)*2.5)*0.06
		_hold(point)
		held.global_basis = _pose*Basis(Vector3.UP,sin(_age*2.1)*0.5)*Basis(Vector3.RIGHT,sin(_age*1.5)*0.25)
		if _age>=2.8: _choose()
	elif phase == "resolve":
		_resolve()

func _watch(delta: float) -> void:
	var actor: CreatureActor = scene.creature
	if scene.loose_props.grabbed != target or (not actor.can_roam() and not (actor.state == CreatureActor.State.ACTION and actor.action_clip == "Idle")) or _age>12.0:
		cancel("offer withdrawn")
		return
	var point := target.global_position
	if actor.global_position.distance_to(point)>4.0:
		cancel("out of sight")
		return
	actor.track_gaze(point)
	var offset := point-actor.global_position
	var facing := atan2(offset.x,offset.z)
	var aligned: bool = absf(angle_difference(actor.global_rotation.y,facing))<0.22
	if not aligned:
		actor.cancel_action()
		actor.clear_hand_targets()
		actor.turn_step(facing,delta)
	elif actor.can_roam():
		actor.perform_action("Idle",20.0)
	var local := actor.to_local(point)
	var reachable := aligned and local.y>=0.9 and local.y<=2.8 and local.z>=0.35 and local.z<=1.25 and absf(local.x)<0.8
	var speed := point.distance_to(_previous)/maxf(delta,0.001)
	_previous = point
	if _was_reachable and not reachable:
		_teases += 1
		if _teases == 2: scene._show_reaction("…","He is beginning to suspect this is a game.")
	_was_reachable = reachable
	if not reachable or speed>0.85:
		_steady = 0.0
	else: _steady += delta
	phase = "reach" if _steady>0.15 else "watch"
	if aligned: _hand(point,smoothstep(0.1,0.7,_steady))
	# Both an intentional pause and actual palm contact are required. Never
	# teleport a moving/out-of-reach offering into an outstretched hand.
	if not reachable or speed>0.85 or _steady<0.9 or actor.hand_position().distance_to(_palm(point))>0.22: return
	if actor.state != CreatureActor.State.ACTION:
		cancel("cannot take offer")
		return
	held = scene.loose_props.take_offered(target)
	if held == null:
		cancel("offer lost before contact")
		return
	_grip = held.global_position
	_pose = held.global_basis
	phase = "inspect"
	_age = 0.0
	scene._show_reaction("?","He turns it over in his hand.")

func _palm(point: Vector3) -> Vector3:
	return point-Vector3.UP*target.radius*0.75

func _hand(point: Vector3, weight := 1.0) -> void:
	var actor: CreatureActor = scene.creature
	var right := actor.global_basis.x
	actor.reach_hand(_palm(point),weight,"R",actor.to_global(Vector3(-0.95,1.85,0.1)),Basis(right,Vector3.UP.cross(right),Vector3.UP))

func _hold(point: Vector3) -> void:
	held.global_position = point
	_hand(point)

func _choose() -> void:
	# A kept rock remains special for this visit. Teasing can still earn a toss.
	outcome = "keep" if target.get_meta("bigfoot_favorite",false) else ["keep","play","throw"].pick_random()
	if _teases>=2: outcome = "throw"
	_grip = held.global_position
	var ground: Variant = scene._probe_ground(scene.creature.to_global(Vector3(-0.65,0,1.0)))
	if ground == null or not scene.valid_landing(ground) or scene.water_play.surface_at(ground)!=null:
		outcome = "throw"
	else: _end = ground+Vector3.UP*(target.radius+0.03)
	# Reuse the authored crouch and windup. Sampling its pickup in reverse
	# lets him lower a gift with his whole body rather than stretch one arm.
	scene.creature.cancel_action()
	if not scene.creature.perform_action("StoneHeave",20.0):
		cancel("resolution animation unavailable")
		return
	scene.creature.player.play("StoneHeave",0.0)
	scene.creature.player.speed_scale = 0.0
	scene.creature.player.seek(1.85,true)
	_hand(_grip)
	scene.creature.track_gaze(_grip)
	phase = "resolve"
	_age = 0.0
	scene._show_reaction("…",{"keep":"This one can stay nearby.","play":"Let's see how it rolls.","throw":"He has somewhere else in mind for it."}[outcome])

func _resolve() -> void:
	var actor: CreatureActor = scene.creature
	var sample := 1.85+_age if outcome == "throw" else 1.9-0.95*smoothstep(1.3 if outcome == "play" else 0.2,2.2 if outcome == "play" else 1.6,_age)
	if _released: sample = 2.95+_age if outcome == "throw" else 0.95*(1.0-smoothstep(0.0,0.65,_age))
	actor.player.seek(sample,true)
	if _released:
		_hand(_end,1.0-smoothstep(0.0,0.5,_age))
		if _age>0.65:
			var result := outcome
			_finish()
			history.append(result)
			completed.emit(result)
		return
	if outcome == "throw":
		var cocked := actor.to_global(Vector3(-0.6,2.55,-0.1))
		_end = actor.to_global(Vector3(-0.55,2.3,1.2))
		var point := _grip.lerp(cocked,smoothstep(0.0,0.65,_age))
		if _age>0.8: point = cocked.lerp(_end,pow(clampf((_age-0.8)/0.3,0,1),2))
		_hold(point)
		if _age>=1.1: _release(actor.global_basis.z*7.5+Vector3.UP*3.0)
	elif outcome == "play":
		var point := _grip
		# Test its heft with a couple of little hand bobs, then bowl it away.
		point.y += sin(_age*TAU*1.5)*0.12*(1.0-smoothstep(1.0,1.5,_age))
		point = point.lerp(_end,smoothstep(1.3,2.2,_age))
		_hold(point)
		if _age>=2.2: _release(actor.global_basis.z*2.8)
	else:
		_hold(_grip.lerp(_end,smoothstep(0.2,1.6,_age)))
		if _age>=1.7:
			target.set_meta("bigfoot_favorite",true)
			_release(Vector3.ZERO)

func _release(velocity: Vector3) -> void:
	held.release(velocity)
	held.hit_cooldown = 1.2
	held = null
	_released = true
	_age = 0.0

func cancel(reason := "player interruption") -> void:
	if not busy(): return
	last_cancel = reason
	if is_instance_valid(held):
		held.release(Vector3.ZERO)
		held.hit_cooldown = 1.2
	_finish()

func _finish() -> void:
	scene.creature.cancel_action()
	scene.creature.clear_hand_targets()
	scene.creature.stop_walking()
	scene.brain.reset_behavior()
	held = null
	target = null
	phase = ""
	_cooldown = 2.5
