extends SceneTree
const LIFE = preload("res://scripts/bigfoot_environment.gd")
var failures := 0
class Flash extends Node:
	signal struck(point: Vector3)
class Routine extends Node:
	var active := ""
	func cancel(_reason := "") -> void: active = ""
class World extends Node3D:
	var creature := CreatureActor.new()
	var navigation := CreatureNavigation.new()
	var brain := CreatureBrain.new()
	var routine := Routine.new()
	var _lightning := Flash.new()
	var _celestial = preload("res://studies/celestial.gd").new()
	var _precipitation := {"state":Vector4.ZERO}
	var habitat := {"interests":[]}
	var _paused := false
	var resident_enabled := true
	var owned := false
	func resident_activity_owned() -> bool: return owned
var world := World.new()
var life = LIFE.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ",message)
func tick(seconds: float) -> void:
	for frame in range(roundi(seconds*60)):
		life.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
func run() -> void:
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
	check(life.request("tree_hug"),"Reachable trunk invites a hug")
	for frame in range(900):
		life.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
		if life.phase == "perform" and world.creature._age>2.0: break
	check(life.phase == "perform","Approach and stepping turn arrive without teleporting")
	check(world.navigation.is_safe(world.creature.position),"Tree contact keeps the feet outside the trunk")
	for side in ["R","L"]:
		var contact: Dictionary = world.creature.hand_targets.get(side,{})
		check(not contact.is_empty(),"Hug uses "+side+" arm")
		if not contact.is_empty():
			var error := world.creature.hand_position(side).distance_to(contact.point)
			print("PALM ERROR ",side," ",error)
			check(error<0.18,"Palm reaches the actual trunk surface")
	tick(8)
	check("tree_hug" in life.history and world.creature.can_roam(),"Hug releases hands and resumes ordinary life")
	life._cooldowns.clear()
	check(life.request("tree_touch"),"One-arm variant is available")
	world.habitat.interests.clear()
	tick(0.1)
	check(not life.busy() and world.creature.hand_targets.is_empty(),"Deleting the approached tree cancels cleanly")
	world.creature.reset_at(Vector3(8,0,1))
	check(life.request("horizon"),"Overlook plans a route to a safe edge inset")
	tick(24)
	check("horizon" in life.history and world.navigation.is_safe(world.creature.position),"Landscape watching completes on safe ground")
	life._on_strike(world.creature.position)
	world._paused = true
	life.advance(1.0)
	check(not life.busy() and life._pending_strike,"Pause defers lightning reaction")
	world._paused = false
	tick(0.5)
	check(life.active == "shock" and life._sparks.visible,"Direct strike produces a visible electrical reaction")
	world.creature.pick_up()
	check(not life.busy() and not life._sparks.visible and world.creature.environment_pose.is_empty(),"Carrying immediately interrupts and clears electrical pose")
	world.creature.reset_at(Vector3(8,0,1))
	world.owned = true
	life._on_strike(world.creature.position)
	tick(0.1)
	check(not life.busy(),"Lightning does not steal another interaction's actor")
	world.owned = false
	life.autonomous = true
	life._next = 0
	world.brain._wait = 0
	world._precipitation.state.x = 0.8
	tick(8)
	check("rain" in life.history,"Real rain triggers a protective hand and an open palm")
	world._precipitation.state.x = 0
	life._next = 0
	world.brain._wait = 0
	tick(6)
	check("dry" in life.history,"Clearing rain triggers a drying shake")
	life.cancel()
	world._celestial.state = {"zs_night":1.0,"zs_celestial_clear":1.0,"zs_bow":0.0}
	var found := false
	for window in range(80):
		world._celestial.sample_sky_motion(window*5.0+0.2)
		var meteor: Dictionary = world._celestial.meteor
		if meteor.is_empty() or meteor.head.y<0.05: continue
		world.creature.rotation.y = atan2(meteor.head.x,meteor.head.z)
		life.advance(1.0/60.0)
		check(life.active == "meteor","Visible forward shooting star catches his attention")
		world._celestial.sample_sky_motion(window*5.0+0.45)
		life.advance(1.0/60.0)
		check(world.creature._gaze.distance_to(world.creature.position+world._celestial.meteor.head*80)<0.001,"Gaze follows the moving shader trajectory")
		found = true
		break
	check(found,"Night sky supplies above-horizon meteor events")
	life.cancel()
	world._celestial.state = {"zs_sun_direction":Vector3(0,0.25,0.97).normalized(),"zs_bow":0.8}
	world._celestial.meteor = {}
	world._celestial._rainbow_growth = 1.0
	life._next = 0
	world.brain._wait = 0
	tick(0.1)
	check(life.active == "rainbow","Visible rainbow invites a look")
	var axis: Vector3 = -world._celestial.state.zs_sun_direction
	check(absf(rad_to_deg(acos(axis.dot(world._celestial.rainbow_direction())))-41.45)<0.01,"Rainbow gaze lands on its rendered ring")
	life.world_changed()
	check(not life.busy() and world.creature.hand_targets.is_empty(),"World changes release all environmental ownership")
	print("BIGFOOT ENVIRONMENT: failures=",failures)
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
