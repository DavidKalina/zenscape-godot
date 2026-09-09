extends SceneTree
## Bigfoot and fire, against a REAL FireField on a small flat plot: he flees
## away from the flames without ever crossing burning ground, watches from
## safety, and thirty seconds after the fire is out he walks to the ash and
## warms his hands. Temper answers fire at his resting spot. A scene with no
## `_fire_field` runs none of it.

const FIRE = preload("res://scripts/bigfoot_fire.gd")
const LIFE = preload("res://scripts/bigfoot_environment.gd")
const WARM = preload("res://scripts/bigfoot_warm_hands.gd")
var failures := 0

class Flash extends Node:
	signal struck(point: Vector3)

class Habits extends RefCounted:
	var home: Variant = null
	func preferred() -> Variant: return home

class Routine extends Node:
	var active := ""
	var habits := Habits.new()
	var last_cancel := ""
	var _clock := 0.0
	var _next_action := 0.0
	func cancel(reason := "") -> void:
		active = ""
		last_cancel = reason

class Temper extends Node:
	var provocations := 0
	var heat := 0.0
	func provoke(amount := 0.4) -> void:
		provocations += 1
		heat += amount

class Play extends Node:
	var temper := Temper.new()

class Air extends RefCounted:
	var wind := Vector3.ZERO
	func sample(_position: Vector3) -> Vector3: return wind

class Wind extends RefCounted:
	var field := Air.new()

class World extends Node3D:
	var creature := CreatureActor.new()
	var navigation := CreatureNavigation.new()
	var brain := CreatureBrain.new()
	var routine := Routine.new()
	var world_play := Play.new()
	var _lightning := Flash.new()
	var _resident_wind := Wind.new()
	var _celestial = preload("res://studies/celestial.gd").new()
	var _precipitation := {"state":Vector4.ZERO}
	var habitat := {"interests":[]}
	var _fire_field: FireField = null
	var _paused := false
	var resident_enabled := true
	var owned := false
	func resident_activity_owned() -> bool: return owned

var world := World.new()
var life = LIFE.new()
var data := NativeTerrainData.new()
var air := Air.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
		print("FAIL: ",message)
	else: print("PASS: ",message)

func fire() -> Node: return life.fire

## The scene's hand order: fire field, then the environmental controller, then
## the brain when nothing above it owns the actor, then the actor itself.
func tick(seconds: float, step := 1.0/60.0) -> void:
	for frame in range(roundi(seconds/step)):
		if world._fire_field != null: world._fire_field.advance(step,world._paused)
		var owning: bool = life.advance(step)
		if not owning and not world.owned: world.brain.advance(step)
		world.creature.advance(step)

## Grass only where the test wants something to burn; everywhere else is bare
## so a fire stays a bounded event.
func fuel_patch(center: Vector2, radius: float) -> void:
	for index in range(data.grass.size()):
		var side := data.meadow_side()
		var point := data.meadow_position(index%side,index/side)+Vector2.ONE*data.meadow_step()*0.5
		if point.distance_to(center) <= radius: data.grass[index] = 1.0

## Distance from his feet to the nearest burning cell, or INF when nothing burns.
func threat() -> float:
	var field: FireField = world._fire_field
	var best := INF
	for index in field.burning_cells():
		best = minf(best,world.creature.position.distance_to(field.cell_center(index)))
	return best

func standing_in_fire() -> bool:
	var field: FireField = world._fire_field
	var cell: int = field.cell_at(world.creature.position)
	return cell >= 0 and field.burn[cell] > 0.0

func run() -> void:
	root.add_child(world)
	for child in [world.creature,world.brain,world.routine,world.world_play,world._lightning,life]: world.add_child(child)
	world.world_play.add_child(world.world_play.temper)
	world.creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	world.creature.set_process(false)
	var source := preload("res://assets/zen_reference/geometry.scn").instantiate()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	fuel_patch(Vector2(3,0),3.5)
	world.navigation.rebuild(data,func(_p: Vector3) -> bool: return true)
	world.creature._ground_probe = world.navigation._ground
	world.creature.reset_at(Vector3(0,0,0))
	world.brain.setup(world.creature,world.navigation,func() -> Array: return world.habitat.interests)
	life.setup(world)
	life.autonomous = false

	# ------------------------------------------------------------ no field
	tick(1.0)
	check(not fire().busy() and fire().field() == null,"A scene with no fire field runs no fire behaviour")
	check(world.world_play.temper.provocations == 0,"No field means no provocation")

	# ------------------------------------------------------------ flee
	var field := FireField.new()
	# Wind blows toward +X, so upwind is -X and that is where he should run.
	air.wind = Vector3(4,0,0)
	world._resident_wind.field.wind = air.wind
	field.setup(data,air.sample,Callable(),Callable(),11)
	world._fire_field = field
	field.ignite(Vector3(3.0,0,0),1.2,1.0)
	tick(0.6)
	check(fire().field() == field,"The behaviour binds to the scene's fire field")
	var before := threat()
	check(before < FIRE.CELL_RADIUS,"The test lights the fire inside his alarm radius")
	check(fire().active == "flee","A fire beside him starts a flee")
	check(world.creature.environment_pose == "startle","Fleeing opens with a startle")
	var entered := false
	var walked := false
	for frame in range(60*26):
		field.advance(1.0/60.0)
		var owning: bool = life.advance(1.0/60.0)
		if not owning and not world.owned: world.brain.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
		if standing_in_fire(): entered = true
		if fire().phase == "run":
			walked = true
			check_tempo()
		if fire().active == "watch": break
	var after := threat()
	print("THREAT before=",before," after=",after," at=",world.creature.position)
	check(walked,"He plans and runs an escape route")
	check(after > before+1.0,"Fleeing increases the distance to the nearest burning cell")
	check(not entered,"He never sets foot on a burning cell")
	check(world.creature.position.x < 0.0,"He runs upwind, away from the way the fire is travelling")
	check(fire().active == "watch","Reaching safety turns into a watch")
	tick(4.5)
	var flame: Vector3 = fire()._threat
	var toward := Vector3(flame.x,0,flame.z)-Vector3(world.creature.position.x,0,world.creature.position.z)
	var facing := world.creature.global_basis.z
	var error := rad_to_deg(absf(angle_difference(atan2(toward.x,toward.z),atan2(facing.x,facing.z))))
	print("WATCH facing error ",error," degrees")
	check(error < 30.0,"He watches with the fire within thirty degrees of his facing")
	check(world.creature.environment_pose == "fire_watch" and world.creature.hand_targets.has("R"),"The watch holds the alert shading pose")

	# ------------------------------------------------------------ temper
	world.routine.habits.home = Vector3(3.0,0,0)
	fire()._temper_wait = 0.0
	tick(0.5)
	check(world.world_play.temper.provocations > 0,"Fire at his resting spot provokes his temper")
	check(world.world_play.temper.heat >= 0.6,"Provocation carries the design's 0.6")
	world.routine.habits.home = null
	var counted := world.world_play.temper.provocations
	fire()._temper_wait = 0.0
	tick(0.5)
	check(world.world_play.temper.provocations == counted,"Fire away from anything of his leaves him calm")

	# ------------------------------------------------------------ curiosity
	# Burn the patch out. Only the field needs the time; extinguish reaches the
	# behaviour through the signal, not through the actor.
	for step in range(400):
		field.advance(0.5)
		if not field.active(): break
	check(not field.active(),"The grass patch burns itself out")
	var ash: Vector3 = field.ash_center()
	check(ash.distance_to(Vector3(3,0,0)) < 2.5,"The ash centre sits where the fire was")
	life.cancel()
	fire().cancel()
	world.creature.reset_at(Vector3(-4,0,0))
	fire()._ash_wait = FIRE.CURIOSITY_DELAY
	fire()._warm_cooldown = 0.0
	tick(FIRE.CURIOSITY_DELAY-4.0,1.0/30.0)
	check(fire().active.is_empty(),"He leaves the ash alone until the thirty seconds are up")
	tick(6.0)
	print("CURIOSITY ",fire().active," brain=",CreatureBrain.Phase.keys()[world.brain.phase])
	check(fire().active in ["approach","warm"],"Thirty seconds after the fire is out he goes to look")
	var warmed := false
	for frame in range(60*70):
		var owning: bool = life.advance(1.0/60.0)
		if not owning and not world.owned: world.brain.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
		if world.creature.environment_pose == "fire_warm":
			warmed = true
			break
	check(warmed,"He crouches into the warm hands clip at the embers")
	var crouched := 0.0
	var reached := 0.0
	var shook := 0.0
	for frame in range(roundi(WARM.DURATION*60.0)):
		life.advance(1.0/60.0)
		world.creature.advance(1.0/60.0)
		var motion: Dictionary = world.creature.environment_motion
		if motion.is_empty(): continue
		crouched = maxf(crouched,float(motion.crouch))
		reached = maxf(reached,float(motion.reach.R))
		shook = maxf(shook,absf(float(motion.shake)))
	print("WARM crouch=",crouched," reach=",reached," shake=",shook)
	check(crouched > 0.9,"The clip reaches a full crouch")
	check(reached > 0.9,"Both palms come out to the embers")
	check(shook > 0.7,"One slow head shake plays")
	check("warm_hands" in fire().history,"The warm hands performance completes")
	check(world.creature.environment_pose.is_empty() and world.creature.hand_targets.is_empty(),"He stands up and gives the actor back")

	# ------------------------------------------------------------ ownership
	world._fire_field = null
	fire()._bind()
	check(fire().field() == null and not fire().busy(),"Losing the field clears the behaviour")
	world._fire_field = field
	# The first patch is spent; give the last section unburnt grass of its own.
	fuel_patch(Vector2(-8,-8),3.0)
	field.rebuild()
	world.creature.reset_at(Vector3(-8.6,0,-8.0))
	world.owned = true
	field.ignite(Vector3(-7.0,0,-8.0),1.0,1.0)
	tick(1.0)
	check(not fire().busy(),"Another interaction owning the resident blocks the fire reaction")
	world.owned = false
	world._paused = true
	tick(0.5)
	check(not fire().busy(),"Pause defers the reaction rather than running it")
	world._paused = false
	tick(0.6)
	check(fire().active == "flee","The deferred fire reaction runs once the scene resumes")

	print("BIGFOOT FIRE: failures=",failures)
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func check_tempo() -> void:
	if world.creature.locomotion_tempo < FIRE.FLEE_TEMPO-0.001:
		failures += 1
		push_error("FAIL: flee runs at locomotion tempo "+str(world.creature.locomotion_tempo))
