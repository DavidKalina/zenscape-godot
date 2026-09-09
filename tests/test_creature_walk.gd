extends SceneTree
const ACTOR = preload("res://scripts/creature_actor.gd")
class Gust extends Node:
	func sample(_point: Vector3) -> Vector3: return Vector3(15,0,0)
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var creature := ACTOR.new()
	root.add_child(creature)
	creature.setup("res://assets/models/zenscape-bigfoot-interactions.glb")
	creature.set_process(false)
	check(creature.can_roam(),"Idle creature can roam")
	var speeds := [0.5,0.85,1.5]
	for speed: float in speeds:
		creature.reset_at(Vector3.ZERO)
		for i in range(60):
			creature.walk_step(Vector3(0,0,10),speed,1.0/60.0)
			creature.advance(1.0/60.0)
		check(absf(creature.position.z-speed)<0.0001,"Ground travel matches requested speed "+str(speed))
		check(creature.state==ACTOR.State.WALKING and creature.player.current_animation=="Walk","Locomotion plays the authored Walk loop")
		check(absf(creature.player.speed_scale-speed/creature.gait_reference_speed())<0.001,"Walk cadence matches source stride")
		var expected_phase := fposmod(speed/creature.gait_reference_speed(),creature.player.get_animation("Walk").length)
		check(absf(creature.player.current_animation_position-expected_phase)<0.001,"Manual animation advance respects matched walking cadence")
		check(creature.land_position.is_equal_approx(creature.global_position),"Walking updates saved safe feet")
	creature.reset_at(Vector3.ZERO)
	creature.walk_step(Vector3(10,0,0),0.85,1.0/60.0)
	check(creature.global_basis.z.x>0 and creature.global_basis.z.x<0.5,"Facing turns gradually toward +Z model forward")
	for i in range(100): creature.walk_step(Vector3(10,0,0),0.85,1.0/60.0)
	check(creature.global_basis.z.x>0.99,"Facing converges to walking direction")
	var current := creature.global_position
	var near := current+Vector3(0.001,0.002,0.001)
	check(creature.walk_step(near,1.5,1.0/60.0),"Final step reports arrival")
	check(creature.global_position.is_equal_approx(near),"Final step does not overshoot its safe target")
	check(creature.state==ACTOR.State.WALKING,"Waypoint arrival keeps the stride active")
	creature.reset_at(Vector3.ZERO)
	var walk_speed := 0.85
	var walk_duration := creature.player.get_animation("Walk").length
	for index in range(30):
		# Each frame reaches its nearby waypoint, like a subdivided navigation path.
		var waypoint := creature.global_position+Vector3(0,0,walk_speed/80.0)
		check(creature.walk_step(waypoint,walk_speed,1.0/60.0),"Short route waypoint is reached")
		creature.advance(1.0/60.0)
	var continuous_phase := fposmod(0.5*walk_speed/creature.gait_reference_speed(),walk_duration)
	check(absf(creature.player.current_animation_position-continuous_phase)<0.001,"Adjacent short waypoints preserve continuous gait phase")
	creature.stop_walking()
	check(creature.state==ACTOR.State.IDLE and creature.player.speed_scale==1,"Controller final arrival restores idle animation timing")
	creature.walk_step(Vector3(5,0,5),0.85,1.0/60.0)
	var safe := creature.global_position
	check(creature.pick_up() and not creature.can_roam(),"Head pickup interrupts walking")
	check(creature.player.current_animation=="Held" and creature.player.speed_scale==1,"Pickup restores authored flailing cadence")
	check(not creature.walk_step(Vector3.ZERO,1,0.05),"Held actor rejects locomotion")
	creature.release_at(null)
	check(not creature.can_roam(),"Landing actor rejects roaming")
	for i in range(240): creature.advance(1.0/60.0)
	check(creature.global_position.is_equal_approx(safe),"Invalid drop returns to last walked safe position")
	for value in [ACTOR.State.WIND,ACTOR.State.RECOVERING]:
		creature.state=value
		check(not creature.can_roam() and not creature.walk_step(Vector3.ZERO,1,0.05),"Physics and recovery cannot be overwritten by walking")
	creature.reset_at(Vector3.ZERO)
	creature.walk_step(Vector3(0,0,5),1.5,0.01)
	creature.stop_walking()
	check(creature.state==ACTOR.State.IDLE and creature.player.speed_scale==1,"Explicit stopping clears locomotion timing")
	creature.walk_step(Vector3(0,0,5),1.5,0.01)
	creature.reset_at(Vector3.ZERO)
	check(creature.state==ACTOR.State.IDLE and creature.player.speed_scale==1,"Reset interrupts locomotion")
	check(not creature.walk_step(Vector3(INF,0,0),1,0.01),"Invalid destination is rejected")
	creature.reset_at(Vector3.ZERO)
	creature._ground_probe = func(point: Vector3) -> Variant:
		if point.z > 4.05: return null
		return Vector3(point.x,0.3*sin(PI*point.z/4.0),point.z)
	var peak := 0.0
	for i in range(300):
		var arrived := creature.walk_step(Vector3(0,0,4),1,1.0/60.0)
		var expected_y := 0.3*sin(PI*creature.global_position.z/4.0)
		check(absf(creature.global_position.y-expected_y)<0.0001,"Feet follow ground across a gentle hump with equal-height endpoints")
		check(creature._safe_position.is_equal_approx(creature.global_position) and creature.land_position.is_equal_approx(creature.global_position),"Ground-projected movement keeps recovery destinations grounded")
		peak = maxf(peak,creature.global_position.y)
		if arrived: break
	check(peak>0.29 and creature.global_position.distance_to(Vector3(0,0,4))<0.001,"Walking climbs the hump then reaches its far side")
	creature.walk_step(Vector3(0,0,8),1,0.05)
	var edge := creature.global_position
	check(not creature.walk_step(Vector3(0,0,8),1,0.05) and creature.global_position.is_equal_approx(edge),"Missing next-step ground rejects motion and retains safe feet")
	creature._ground_probe = Callable()
	var gust := Gust.new()
	root.add_child(gust)
	creature.enable_wind(gust,Callable(),Callable())
	creature.walk_step(Vector3(0,0,5),1.5,0.01)
	creature._physics_process(1.0/60.0)
	check(creature.state==ACTOR.State.WIND and creature.player.speed_scale==1,"A real gust transition interrupts walking and restores flail timing")
	creature.free()
	gust.free()
	print("Creature walk: ",failures," failures")
	quit(1 if failures else 0)
