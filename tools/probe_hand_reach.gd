extends SceneTree
## Headless check of the hand's reach (scripts/hand_reach.gd) without the
## Fidelity scene: a stand-in scene with the real sky rig (studies/celestial.gd),
## world clock and God Hand, a flat 28 m plate for the editor, and a stand-in
## mood. Presses, drags and releases are pushed through the viewport, so the
## probe sees whether the hand takes them before the scene would.
##   Godot --headless --fixed-fps 60 --path . --script res://tools/probe_hand_reach.gd

const Reach = preload("res://scripts/hand_reach.gd")
const Mood = preload("res://scripts/mood_look.gd")
const Shell = preload("res://scripts/lantern_shell.gd")
const Living = preload("res://scripts/living_weather.gd")

## The scene: it counts the pointer events that reach it, as the camera's
## orbit and the brushes (studies/fidelity.gd) would see them.
const FakeScene := """
extends Node3D
var _chunk_editor: Node
var camera: Camera3D
var distance := 43.0
var _celestial: RefCounted
var world_clock: WorldClock
var _season_shown := -1.0
var mood_look: Node
var god_hand: Node3D
var creation_palette: Node
var seen := 0
func _input(event: InputEvent) -> void:
	if event is InputEventMouse: seen += 1
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse: seen += 1
"""
## A flat plate, its top at 0, 28 m square, under the terrain node.
const FakeEditor := """
extends Node
var active := false
var forming := false
var mode := "land"
var pointer_hit: Variant = null
var data: Object
var terrain: Node3D
var scene: Node3D
var blocked := false
var status := ""
func hand_gesture() -> String: return ""
func pointer_in_world(_point: Vector2) -> bool: return not blocked
func pick(point: Vector2) -> Variant:
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := camera.project_ray_normal(point)
	if direction.y >= -0.0001: return null
	var at := origin+direction*(-origin.y/direction.y)
	if absf(at.x) > 14.0 or absf(at.z) > 14.0: return null
	return at
func _set_status(text: String) -> void: status = text
"""
const FakeGround := """
extends RefCounted
func ground_height(_p: Vector2) -> Variant: return 0.0
"""
## Mood pins as scripts/mood_look.gd keeps them, without the world to rebuild.
const FakeMood := """
extends Node
var pins := {}
var hours: Array[float] = []
var seasons: Array[String] = []
func busy() -> bool: return false
func finish_fade() -> void: pass
func pinned(control: String) -> bool: return pins.has(control)
func value(control: String) -> String: return str(pins.get(control,""))
func pin(control: String, id: String) -> void:
	pins[control] = id
	if control == "season": seasons.append(id)
func unpin(control: String) -> void: pins.erase(control)
func pin_hour(phase: float) -> void:
	pins["time"] = "at:%.4f" % phase
	hours.append(phase)
"""
const FakeShell := """
extends Node
var hints: Array[String] = []
func reach_hint(text: String) -> void: hints.append(text)
"""

var failures := 0
var scene: Node3D
var reach: Node
var camera: Camera3D
var editor: Node
var mood: Node
var hand: Node3D
var grabs := []
var drags := []
var releases := 0

func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _press(at: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event)

func _move(at: Vector2, from: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at-from
	root.push_input(event)

## Drag from `from` to `to` in `steps` moves, a frame apart.
func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	var last := from
	for i in range(1,steps+1):
		var at := from.lerp(to,float(i)/steps)
		_move(at,last)
		last = at
		await process_frame

func _screen(local: Vector3) -> Vector2:
	return camera.unproject_position(editor.terrain.to_global(local))

func _run() -> void:
	_statics()
	# Headless opens a 64 px root; the reach works in screen pixels.
	root.size = Vector2i(1280,720)
	scene = _script(FakeScene).new()
	root.add_child(scene)
	var lights: Array[DirectionalLight3D] = [DirectionalLight3D.new(),DirectionalLight3D.new()]
	for light in lights: scene.add_child(light)
	scene._celestial = preload("res://studies/celestial.gd").new()
	scene._celestial.setup(lights)
	scene.world_clock = WorldClock.new()
	scene._celestial.attach_clock(scene.world_clock)
	camera = Camera3D.new()
	camera.fov = 40.0
	scene.add_child(camera)
	camera.current = true
	scene.camera = camera
	editor = _script(FakeEditor).new()
	scene.add_child(editor)
	scene._chunk_editor = editor
	editor.scene = scene
	editor.data = _script(FakeGround).new()
	editor.terrain = Node3D.new()
	scene.add_child(editor.terrain)
	mood = _script(FakeMood).new()
	scene.add_child(mood)
	scene.mood_look = mood
	scene.creation_palette = _script(FakeShell).new()
	scene.add_child(scene.creation_palette)
	hand = preload("res://scripts/god_hand.gd").new()
	editor.terrain.add_child(hand)
	hand.setup(scene)
	scene.god_hand = hand
	reach = Reach.new()
	scene.add_child(reach)
	reach.setup(scene)
	reach.rim_grabbed.connect(func(at: Vector2) -> void: grabs.append(at))
	reach.rim_dragged.connect(func(d: Vector2, dt: float) -> void: drags.append([d,dt]))
	reach.rim_released.connect(func() -> void: releases += 1)
	await _frames(3)
	print("viewport ",root.get_visible_rect().size)
	await _sun()
	await _moon()
	await _rim()
	_check(not Shell.scrubber_wanted(),"the bottom scrubber is hidden without --scrubber")
	print("probe_hand_reach: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The dial's arithmetic and the held hour's pin, without a scene.
func _statics() -> void:
	var worst := 0.0
	for s in [0.02,0.14,0.2,0.375,0.5,0.64,0.7,0.87,0.95]:
		worst = maxf(worst,absf(angle_difference(Reach.season_for_dial(Reach.dial_for_season(s))*TAU,s*TAU)/TAU))
	_check(worst < 0.0005,"the season dial maps seasons to dial and back (worst %.5f)" % worst)
	var detents := true
	for i in range(4): detents = detents and is_equal_approx(Reach.season_for_dial(float(i)),float(Living.SEASONS[i]))
	_check(detents,"the dial's detents sit on the four mid-seasons")
	var near := absf(Reach.season_for_dial(1.05)-Reach.season_for_dial(1.0))
	var between := absf(Reach.season_for_dial(1.55)-Reach.season_for_dial(1.5))
	_check(near < between*0.5,"the detents stick: a nudge at summer moves the season %.4f, between seasons %.4f" % [near,between])
	_check(Reach.season_id(2.4) == "autumn" and Reach.season_id(-0.4) == "spring" and Reach.season_id(3.6) == "spring","the nearest detent names its season")
	var id := Mood.held_hour(0.52301)
	_check(id == "at:0.5230" and is_equal_approx(float(Mood.option("time",id).phase),0.523),"a held hour pins as %s" % id)
	_check(Mood._valid_pin("time",id) and not Mood._valid_pin("time","at:1.5") and not Mood._valid_pin("time","at:x"),"held hours validate like any pin")

func _sun() -> void:
	# Early morning, the camera turned to the sun, a little above the plate.
	scene._celestial.set_phase(0.3)
	scene.world_clock.running = false
	var sun: Vector3 = reach.body_direction("sun",0.3)
	camera.position = Vector3(-sun.x,0.0,-sun.z).normalized()*30.0+Vector3.UP*6.0
	camera.look_at(camera.position+sun.lerp(Vector3.DOWN,0.12).normalized())
	await _frames(2)
	var disc: Vector2 = reach._screen(sun)
	print("sun on screen at ",disc)
	_check(reach.reach_at(disc) == "sun","the pointer on the sun's disc reaches the sun")
	_check(reach.reach_at(disc+Vector2(40,25)) == "sun","a generous grab round the disc")
	_check(reach.reach_at(disc+Vector2(0,-200)) == "","empty sky away from it is not the sun")
	reach._hover(disc)
	_check(scene.creation_palette.hints.back() == Reach.SUN_HINT,"the hint names the sun near it")
	editor.blocked = true
	scene.seen = 0
	_press(disc)
	await process_frame
	_check(reach.holding == "" and scene.seen == 2,"over a UI panel the press is left for the UI")
	_press(disc,false)
	editor.blocked = false
	scene.seen = 0
	_press(disc)
	await process_frame
	_check(reach.holding == "sun","a press on the sun takes hold of it")
	_check(scene.seen == 0,"the press never reaches the scene's orbit or brushes")
	await _frames(2)
	_check(hand.reach_gesture == "sun" and String(hand.player.current_animation) == "ReachIn","the hand reaches up: reach_gesture sun, playing %s" % hand.player.current_animation)
	var ray: Vector3 = hand.reach_point-editor.terrain.to_local(camera.global_position)
	_check(absf(ray.length()-Reach.SUN_REACH) < 0.01 and ray.normalized().dot(sun) > 0.999,"the hand holds the sun %.1f m out along the ray to it" % ray.length())
	# Drag the disc along its arc to where the sun is at 0.34, a frame a move.
	var goal: Vector2 = reach._screen(reach.body_direction("sun",0.34))
	await _drag(disc,goal,12)
	var dragged := float(scene._celestial.phase)
	_check(absf(dragged-0.34) < 0.004,"dragging along the arc sets the hour (phase %.4f, wanted 0.34)" % dragged)
	_check(not scene.world_clock.running,"the clock waits while the sun is held")
	_check(scene.seen == 0,"the drag never reaches the scene")
	await _frames(60)
	_check(String(hand.player.current_animation) == "ReachHold","the hand holds it: %s" % hand.player.current_animation)
	# One last quick move, then let go: it drifts on, slowing, and the hour is held.
	await _drag(goal,reach._screen(reach.body_direction("sun",0.35)),2)
	var speed := float(reach.phase_speed)
	_press(goal,false)
	await process_frame
	_check(scene.seen == 0 and reach.holding == "","the release is the hand's too")
	var let_go := float(scene._celestial.phase)
	_check(reach.drifting and speed > 0.0,"let go, it drifts on (%.4f phase/s)" % speed)
	var steps: Array[float] = []
	var last := let_go
	for i in range(400):
		await process_frame
		steps.append(float(scene._celestial.phase)-last)
		last = float(scene._celestial.phase)
		if not reach.drifting: break
	_check(steps[0] > 0.0 and steps.slice(0,4).max() > steps.slice(steps.size()-4).max(),"the drift slows (%.5f per frame at first, %.5f at the end)" % [steps[0],steps.back()])
	_check(not reach.drifting and mood.hours.size() == 1 and absf(mood.hours[0]-float(scene._celestial.phase)) < 0.0001,"it comes to rest and the hour is held through the mood (%s)" % mood.pins.get("time","none"))
	_check(float(scene._celestial.phase) > let_go+0.001,"it came to rest past where it was let go (%.4f from %.4f)" % [scene._celestial.phase,let_go])
	await _frames(2)
	_check(hand.reach_gesture == "" and hand.reach_point == null,"letting go clears the hand's reach")
	# A day that was turning turns on from the new hour, unpinned.
	scene.world_clock.running = true
	var pins_before: int = mood.hours.size()
	disc = reach._screen(reach.body_direction("sun",float(scene._celestial.phase)))
	_press(disc)
	await process_frame
	await _drag(disc,disc+Vector2(-30,10),4)
	_press(disc+Vector2(-30,10),false)
	for i in range(400):
		await process_frame
		if not reach.drifting: break
	_check(scene.world_clock.running and mood.hours.size() == pins_before,"on a turning day the day turns on from where the sun is left")
	scene.world_clock.running = false

func _moon() -> void:
	# Night: the moon is up where the sun was, on its own ring.
	scene._celestial.set_phase(0.8)
	var moon: Vector3 = reach.body_direction("moon",0.8)
	camera.position = Vector3(-moon.x,0.0,-moon.z).normalized()*30.0+Vector3.UP*6.0
	camera.look_at(camera.position+moon.lerp(Vector3.DOWN,0.25).normalized())
	await _frames(2)
	var disc: Vector2 = reach._screen(moon)
	_check(reach.reach_at(disc) == "sun" and reach._body_at(disc) == "moon","by night the moon is in reach")
	_press(disc)
	await process_frame
	_check(reach.holding == "sun" and reach.body == "moon","a press on the moon holds it")
	await _drag(disc,reach._screen(reach.body_direction("moon",0.84)),10)
	_check(absf(float(scene._celestial.phase)-0.84) < 0.004,"dragging the moon along its ring turns the night (phase %.4f)" % scene._celestial.phase)
	_press(disc,false)
	for i in range(400):
		await process_frame
		if not reach.drifting: break

func _rim() -> void:
	# The game camera: 25 degrees up, 43 m out, on the plate's +z side.
	camera.position = Vector3(0.0,sin(deg_to_rad(25.0)),cos(deg_to_rad(25.0)))*43.0
	camera.look_at(Vector3.ZERO)
	await _frames(2)
	scene.world_clock.season_override = float(Living.SEASONS[1])
	var near := _screen(Vector3(-6.0,0.0,14.0))
	_check(reach.reach_at(near) == "rim","the near rim is in reach")
	_check(reach.reach_at(near+Vector2(0,14)) == "rim","just outside the rim, over the block's wall")
	_check(reach.reach_at(_screen(Vector3(0,0,0))) == "","the middle of the land is the camera's and the brushes'")
	_check(reach.reach_at(_screen(Vector3(-6.0,0.0,12.2))) == "","land a couple of metres in from the rim is the land's")
	reach._hover(near)
	_check(scene.creation_palette.hints.back() == Reach.RIM_HINT,"the hint names the rim near it")
	scene.seen = 0
	_press(near)
	await process_frame
	_check(reach.holding == "rim" and scene.seen == 0 and grabs.size() == 1,"a press on the rim takes hold of it, before the scene sees it")
	await _frames(2)
	_check(hand.reach_gesture == "rim" and String(hand.player.current_animation) == "RimIn","the hand grips the rim: playing %s" % hand.player.current_animation)
	_check(hand.reach_point.distance_to(Vector3(-6.0,0.0,14.0)) < 0.3,"the hand works at the rim under the pointer")
	# A small nudge at summer's detent barely moves the season.
	var start := float(scene.world_clock.season)
	await _drag(near,_screen(Vector3(-5.0,0.0,14.0)),3)
	var nudged := float(scene.world_clock.season)-start
	# Push the near rim to the right, along it: the season turns on.
	var far := _screen(Vector3(8.0,0.0,14.0))
	await _drag(_screen(Vector3(-5.0,0.0,14.0)),far,16)
	var turned: float = reach.dial-1.0
	var expected := (atan2(8.0,14.0)-atan2(-6.0,14.0))/TAU*4.0
	_check(absf(turned-expected) < 0.02,"pushing the near rim right turns the dial on (%.3f of a season, the rim turned %.3f)" % [turned,expected])
	_check(nudged >= 0.0 and nudged < 0.01,"at the detent the first nudge sticks (%.4f)" % nudged)
	_check(drags.size() >= 19 and scene.seen == 0,"each move reaches rim_dragged (%d), none the scene" % drags.size())
	_press(far,false)
	await process_frame
	_check(releases == 1 and reach.settling,"let go, the dial settles")
	for i in range(400):
		await process_frame
		if not reach.settling: break
	_check(not reach.settling and is_equal_approx(reach.dial,2.0) and mood.seasons.back() == "autumn","it settles into autumn's detent and pins it (%s)" % mood.seasons.back())
	_check(is_equal_approx(scene.world_clock.season_override,float(Living.SEASONS[2])) and is_equal_approx(scene._season_shown,scene.world_clock.season),"the world clock shows autumn at once")
	await _frames(2)
	_check(hand.reach_gesture == "" and String(hand.player.current_animation).begins_with("Rim"),"letting go plays %s" % hand.player.current_animation)
	# A shake while the rim is held (the snow globe) puts the season back.
	mood.seasons.clear()
	var back := _screen(Vector3(8.0,0.0,14.0))
	_press(back)
	await process_frame
	await _drag(back,_screen(Vector3(-8.0,0.0,14.0)),12)
	_check(reach.dial < 1.6,"turning back toward summer (%.2f)" % reach.dial)
	reach.revert_season_to_grab()
	_check(is_equal_approx(reach.dial,2.0) and is_equal_approx(scene.world_clock.season_override,float(Living.SEASONS[2])),"revert_season_to_grab puts the dial and the season back")
	_press(back,false)
	await _frames(30)
	_check(mood.seasons.is_empty() and mood.pins.season == "autumn","after a shake the let-go leaves the season as it was")
	# Letting go of nothing, and a press elsewhere, are the scene's.
	scene.seen = 0
	_press(_screen(Vector3.ZERO))
	_press(_screen(Vector3.ZERO),false)
	await process_frame
	_check(scene.seen == 4 and reach.holding == "","a press on the land goes on to the camera and the brushes")
