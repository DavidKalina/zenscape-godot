extends Node
## The enemies of a scene (docs/design/roguelike/ideas-enemies.md), stepped
## beside the pilot's motor the way scripts/interactables/foot_pieces.gd
## steps the on-foot pieces: hooked into a character study as its
## `foot_pieces` (studies/character_study.gd calls `before`, `after`,
## `pose`), so a study with enemies needs nothing else.
##
## `before` (ahead of the motor's step): every enemy thinks and moves, and
## the pilot stood on one is carried by what it moved. `after` (the step
## done): each enemy tests contact with him (scripts/enemies/enemy.gd
## `touch`), judged by the pace he had going into the step, then shoves him
## out of its body if it moved into him (`push_out`: its body is a stone to
## him, but he is nothing to it). A pilot stood on one is carried by it
## unless it `bucks()` (a charge runs out from under him).
## The pilot's numbers an enemy sizes itself from are `numbers()`: nothing
## here copies a size (AGENTS.md, Sizes).
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

var study: Node3D
var motor: PilotMotor
## The live enemies.
var enemies: Array = []
## Below this height an enemy is gone (the study's `lost`).
var lost := -20.0
## The sounds the enemies called for, as [name, at]; a scene with sound
## sets `sound_hook` (name, at) to play them. Greybox: only logged.
var sounds: Array = []
var sound_hook := Callable()
## Specs for `reset`: [script, at, face (x, z), knob overrides].
var specs: Array = []
## Enemies that fell and are gone, counted.
var gone_count := 0
var _ray := PhysicsRayQueryParameters3D.new()
## The pilot's horizontal velocity going into the last few steps, newest
## first: a slide into an enemy is stopped by it, so the pace to judge a
## push by is the one before.
var _v_pre: Array = []
const HISTORY := 4

func _init() -> void:
	name = "EnemyField"

## Hooked into `scene` (a character study): stepped by its frame.
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	lost = scene.lost
	scene.foot_pieces = self
	scene.add_child(self)

## What an enemy sizes itself from: the pilot's own numbers.
func numbers() -> Dictionary:
	return {"run":motor.run,"walk":motor.walk,"unit":study.ground.head_top,"gravity":motor.gravity,
		"fall":motor.fall,"jump":float(motor.jumps[0]),"size":motor.size,"step_up":PilotMotor.STEP_UP,
		"radius":PhysicsGround.RADIUS*motor.size,"skid":PilotMotor.TUMBLE_SKID}

## An enemy of `script` set down at `at`, facing `face` (x, z), `overrides`
## over its knobs (a tier's). Remembered for `reset`.
func spawn(script: GDScript, at: Vector3, face: Vector2, overrides := {}) -> Node3D:
	specs.append([script,at,face,overrides])
	return _make(script,at,face,overrides)

## An enemy set down now and not remembered: `reset` takes it away (a
## scene's own spawns, made as it plays).
func add(script: GDScript, at: Vector3, face: Vector2, overrides := {}) -> Node3D:
	return _make(script,at,face,overrides)

func _make(script: GDScript, at: Vector3, face: Vector2, overrides: Dictionary) -> Node3D:
	var e: Node3D = script.new()
	e.setup(self,at,face,overrides)
	add_child(e)
	enemies.append(e)
	return e

## Every enemy back as it was spawned.
func reset() -> void:
	for e: Node3D in enemies:
		# Out of the physics space now, not at the frame's end: a body left
		# standing till then is a stone where it last was.
		if is_instance_valid(e):
			if e.get_parent() == self: remove_child(e)
			e.queue_free()
	enemies.clear()
	for s: Array in specs: _make(s[0],s[1],s[2],s[3])

## Every enemy gone, and none to come back on `reset`.
func clear() -> void:
	specs.clear()
	reset()

func sound(sound_name: StringName, at: Vector3) -> void:
	sounds.append([sound_name,at])
	if sound_hook.is_valid(): sound_hook.call(sound_name,at)

# --- The world, as an enemy asks ------------------------------------------------

## The height of the first thing under `p` (looked for from `up` over it
## to `down` under it), -INF if there is nothing; `exclude` (a body's RID)
## is not looked at.
func floor_under(p: Vector3, up: float, down: float, exclude := RID()) -> float:
	_ray.from = p+Vector3.UP*up
	_ray.to = p-Vector3.UP*down
	_ray.collision_mask = WalkerOnly.strip(study.ground.mask)
	_ray.exclude = [exclude] if exclude.is_valid() else []
	var hit := study.get_world_3d().direct_space_state.intersect_ray(_ray)
	return -INF if hit.is_empty() else (hit.position as Vector3).y

## Whether something stands from `from` along `along`.
func blocked(from: Vector3, along: Vector3, exclude := RID()) -> bool:
	_ray.from = from
	_ray.to = from+along
	_ray.collision_mask = WalkerOnly.strip(study.ground.mask)
	_ray.exclude = [exclude] if exclude.is_valid() else []
	return not study.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

## The body under the pilot's feet, or an empty RID.
func under_pilot() -> RID:
	_ray.from = motor.feet+Vector3.UP*0.3
	_ray.to = motor.feet-Vector3.UP*0.35
	_ray.collision_mask = study.ground.mask
	_ray.exclude = []
	var hit := study.get_world_3d().direct_space_state.intersect_ray(_ray)
	return hit.rid if not hit.is_empty() else RID()

## Whether what the pilot stands on is walker-only (scripts/walker_only.gd):
## off the enemies' ground (a shockwave runs under him).
func pilot_on_walker_only() -> bool:
	_ray.from = motor.feet+Vector3.UP*0.3
	_ray.to = motor.feet-Vector3.UP*0.35
	_ray.collision_mask = study.ground.mask
	_ray.exclude = []
	var hit := study.get_world_3d().direct_space_state.intersect_ray(_ray)
	return not hit.is_empty() and WalkerOnly.marked(hit.collider)

# --- The frame -------------------------------------------------------------------

func before(delta: float) -> void:
	_v_pre.push_front(Vector3(motor.velocity.x,0.0,motor.velocity.z))
	if _v_pre.size() > HISTORY: _v_pre.pop_back()
	# Untyped: a freed enemy can't be passed as a Node3D.
	enemies = enemies.filter(func(e) -> bool: return is_instance_valid(e) and not e.gone)
	var standing := RID()
	if motor.grounded and motor.rider == null and not motor.swimming: standing = under_pilot()
	for e: Node3D in enemies:
		var on: bool = standing.is_valid() and standing == e.body.get_rid()
		var held: bool = motor.on_ledge() and e.holds(motor.lip)
		e.step(delta)
		if not (on or held) or e.gone: continue
		# Stood on (or hung from), he rides it; a charging back bucks him
		# off behind it.
		if e.bucks(): e.buck(motor)
		elif e.moved != Vector3.ZERO: motor.carry(Transform3D(Basis.IDENTITY,e.moved),0.0)

func after(_delta: float, _events: Dictionary) -> void:
	for e: Node3D in enemies:
		if e.gone: continue
		e.touch(motor,_best_pre(e))
		# It moved or turned into him: he is shoved out of its body.
		e.push_out(motor,study.ground.slide,PhysicsGround.BODY_LOW,study.ground.head_top)

## The pilot's recent velocity most toward `e`.
func _best_pre(e: Node3D) -> Vector3:
	var to := Vector3(e.position.x-motor.feet.x,0.0,e.position.z-motor.feet.z).normalized()
	var best := Vector3.ZERO
	var most := -INF
	for v: Vector3 in _v_pre:
		var d := v.dot(to)
		if d > most:
			most = d
			best = v
	return best

## Enemies don't pose the figure.
func pose(_figure: Node3D) -> void:
	pass
