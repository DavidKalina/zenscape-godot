extends SceneTree
const ACTOR = preload("res://scripts/creature_actor.gd")
class Wind extends Node:
	var velocity := Vector3.ZERO
	func sample(_point: Vector3) -> Vector3: return velocity
var failures := 0
var creature: Node3D
var wind := Wind.new()
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		creature.advance(1.0/60.0)
func ground(point: Vector3) -> Variant:
	return Vector3(point.x,0,point.z) if absf(point.x)<18 and absf(point.z)<18 else null
func safe(point: Vector3) -> Variant: return ground(point)
func _run() -> void:
	root.add_child(wind)
	var floor_body := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40,1,40)
	var collision := CollisionShape3D.new()
	collision.shape = box
	floor_body.add_child(collision)
	root.add_child(floor_body)
	floor_body.position.y = -0.5
	creature = ACTOR.new()
	root.add_child(creature)
	creature.setup("res://assets/models/zenscape-bigfoot-interactions.glb")
	creature.set_process(false)
	creature.enable_wind(wind,ground,safe)
	wind.velocity = Vector3(3,0,0)
	await ticks(30)
	check(creature.state == ACTOR.State.IDLE,"Light wind braces without throwing Bigfoot")
	check(creature.global_position.length()<0.01,"Light gust keeps his footing")
	wind.velocity = Vector3(15,0,0)
	await ticks(25)
	check(creature.state == ACTOR.State.WIND,"Strong wind activates physics")
	check(creature.wind_body.linear_velocity.x>0.5,"Solver displacement follows wind force")
	check(absf(creature.wind_body.global_basis.y.dot(Vector3.UP))<0.97,"Off-center force causes a real tumble")
	var moved: float = creature.wind_body.global_position.x
	check(moved>0.15,"Gust moves Bigfoot through the physical world")
	wind.velocity = Vector3.ZERO
	await ticks(400)
	check(creature.state != ACTOR.State.WIND and creature.state != ACTOR.State.RECOVERING,"Settling completes recovery")
	check(absf(creature.global_position.y)<0.02 and creature.global_basis.y.dot(Vector3.UP)>0.999,"Recovery returns feet to ground and body upright")
	wind.velocity = Vector3(-15,0,0)
	await ticks(20)
	check(creature.pick_up(),"Pickup interrupts physical tumble")
	check(creature.wind_body.freeze and creature.wind_body.collision_layer==0,"Pickup removes active physical proxy")
	creature.move_held(Vector3(30,5,0),1.0/60.0)
	check(not creature.release_at(Vector3(30,0,0)),"Invalid placement is rejected by terrain validator")
	wind.velocity = Vector3.ZERO
	await ticks(300)
	check(absf(creature.global_position.x)<18 and creature.state==ACTOR.State.IDLE,"Invalid drop returns to safe position")
	wind.velocity = Vector3(15,0,0)
	await ticks(20)
	wind.velocity = Vector3.ZERO
	var entered_recovery := false
	for i in range(360):
		await ticks(1)
		if creature.state == ACTOR.State.RECOVERING:
			entered_recovery = true
			break
	check(entered_recovery,"A second fall reaches recovery")
	wind.velocity = Vector3(-15,0,0)
	await ticks(3)
	check(creature.state == ACTOR.State.WIND,"A repeated gust interrupts recovery with physics")
	creature.reset_at(Vector3.ZERO)
	check(creature.wind_body.freeze and creature.wind_body.collision_mask==0,"Reset clears physics and collision state")
	check(creature.global_transform.is_finite(),"Interrupted interactions keep a finite pose")
	# A tall obstacle must stop the collision proxy, not merely its visual model.
	wind.velocity = Vector3(18,0,0)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1,10,10)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	root.add_child(wall)
	wall.position = Vector3(2.5,4,0)
	await ticks(100)
	check(creature.wind_body.global_position.x < 1.65,"Continuous collision blocks a strong gust at a solid obstacle")
	check(creature.wind_body.global_position.y > -0.1,"Physical terrain supports the tumbling body")
	wall.free()
	creature.free()
	floor_body.free()
	wind.free()
	print("Creature wind: ",failures," failures")
	quit(1 if failures else 0)
