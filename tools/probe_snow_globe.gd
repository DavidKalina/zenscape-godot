extends SceneTree
## Headless check of the snow globe (scripts/snow_globe.gd) against stand-ins
## for the Fidelity scene: a flat plate with its earth block, the camera, the
## real tremor and God Hand, and a stand-in precipitation. Drags are fed at a
## steady 60 Hz and everything is stepped by hand, so the numbers repeat.
## Proves: which presses hold the rim, that a slow drag along it is no shake
## and a vigorous one is, that the fall is snow in the cold and rain
## otherwise, grows with how hard and long the shake was and fades on its own,
## that the jiggle rings down to rest, and that the hand grips the lip, shakes
## faster with a harder shake and lets go.
##   Godot --headless --path . --script res://tools/probe_snow_globe.gd

const FakeData := """
extends RefCounted
var level := 1.0
func ground_height(p: Vector2) -> Variant:
	return level if absf(p.x) <= 14.0 and absf(p.y) <= 14.0 else null
func ray_hit(origin: Vector3, direction: Vector3) -> Variant:
	if absf(direction.y) < 0.0001: return null
	var t := (level-origin.y)/direction.y
	if t <= 0.0: return null
	var p := origin+direction*t
	return p if absf(p.x) <= 14.0 and absf(p.z) <= 14.0 else null
"""
const FakeEditor := """
extends Node
var active := false
var forming := false
var mode := "land"
var pointer_hit: Variant = null
var ball: Node3D
var handful: Node3D
var data: RefCounted
var terrain: Node3D
func hand_gesture() -> String: return ""
func pointer_in_world(_p: Vector2) -> bool: return true
"""
const FakeWeather := """
extends RefCounted
var snow_phase := 0.0
"""
const FakePrecipitation := """
extends Node
var state := Vector4(0.0,0.0,0.06,0.0)
var surface_weather: RefCounted
"""
const FakeScene := """
extends Node3D
var _chunk_editor: Node
var camera: Camera3D
var distance := 43.0
var _tremor: RefCounted
var _precipitation: Node
var god_hand: Node3D
"""

const DT := 1.0/60.0

var failures := 0
var scene: Node3D
var globe: Node
var hand: Node3D
var weather: RefCounted
var precipitation: Node
var height := 1080.0

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

func _run() -> void:
	scene = _script(FakeScene).new()
	root.add_child(scene)
	var editor: Node = _script(FakeEditor).new()
	scene.add_child(editor)
	scene._chunk_editor = editor
	editor.data = _script(FakeData).new()
	var terrain := Node3D.new()
	scene.add_child(terrain)
	editor.terrain = terrain
	var camera := Camera3D.new()
	scene.add_child(camera)
	scene.camera = camera
	camera.position = Vector3(0.0,30.0,40.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	scene._tremor = preload("res://scripts/reference_tremor.gd").new()
	precipitation = _script(FakePrecipitation).new()
	weather = _script(FakeWeather).new()
	precipitation.surface_weather = weather
	scene.add_child(precipitation)
	scene._precipitation = precipitation
	hand = preload("res://scripts/god_hand.gd").new()
	terrain.add_child(hand)
	hand.setup(scene)
	hand.set_process(false)
	hand.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	scene.god_hand = hand
	globe = preload("res://scripts/snow_globe.gd").new()
	globe.setup(scene)
	scene.add_child(globe)
	globe.set_process(false)
	await process_frame
	height = globe._screen_height()
	print("  screen height %d px" % int(height))

	# Which presses hold the rim.
	_check(not globe.rim_at(camera.unproject_position(Vector3(0.0,1.0,0.0))) != null,"a press on the land is the camera's")
	_check(not globe.rim_at(camera.unproject_position(Vector3(0.0,1.0,11.0))) != null,"so is one well inside the edge")
	_check(globe.rim_at(camera.unproject_position(Vector3(3.0,1.0,13.4))) != null,"a press on the plate's top by its edge holds the rim")
	_check(globe.rim_at(camera.unproject_position(Vector3(-2.0,-1.5,14.2))) != null,"so does one on the earth block's wall")
	_check(not globe.rim_at(camera.unproject_position(Vector3(0.0,12.0,-30.0))) != null,"the sky is nothing to hold")
	var lip: Array = globe.rim_at(camera.unproject_position(Vector3(-2.0,-1.5,14.2)))
	_check(lip[0].distance_to(Vector3(-2.0,1.0,14.2)) < 0.3 and lip[1].is_equal_approx(Vector3(0.0,0.0,-1.0)),
		"the grip goes to the lip above, reaching in (%s, %s)" % [lip[0],lip[1]])
	var side: Array = globe.rim_at(camera.unproject_position(Vector3(13.5,1.0,-4.0)))
	_check(side[1].is_equal_approx(Vector3(-1.0,0.0,0.0)) and absf(side[0].x-14.2) < 0.01,"and on the side the pointer is nearest")
	var near := camera.unproject_position(Vector3(0.0,1.0,13.4))

	# A slow, steady drag along the rim is no shake, and barely moves the world.
	globe.grab(near)
	var biggest := 0.0
	for i in range(150):
		globe.feed(Vector2(3.0,0.0)*height/1080.0,DT)
		_step()
		biggest = maxf(biggest,globe.jiggle.length())
	_check(not globe.decided,"a slow drag along the rim is not a shake")
	var slow_jiggle := biggest
	# Nor is slowly working it back and forth, as a dial would be.
	for i in range(240):
		var dir := 1.0 if (i/48)%2 == 0 else -1.0
		globe.feed(Vector2(4.0*dir,0.0)*height/1080.0,DT)
		_step()
		biggest = maxf(biggest,globe.jiggle.length())
	_check(not globe.decided,"nor is slowly working it back and forth (0.8 s strokes)")
	_check(globe.amount() == 0.0 and precipitation.state.y == 0.0,"and nothing falls")
	_check(hand.reach_gesture == "shake","the hand holds the rim meanwhile")
	globe.release()
	_settle(4.0)

	# A gentle shake counts, but brings little.
	weather.snow_phase = 1.0
	var gentle := _shake(near,0.02,2.5,2.0)
	_check(gentle.decided,"a gentle shake is a shake (decided after %.2f s)" % gentle.after)
	print("  gentle: fall %.3f, jiggle %.4f screens" % [gentle.amount,gentle.jiggle])
	_settle(60.0)
	_check(globe.amount() == 0.0 and precipitation.state.y == 0.0 and globe.airborne == 0.0,"a gentle shake's fall is over by itself")

	# A firm shake brings a flurry, and a longer one more.
	var firm := _shake(near,0.07,4.0,2.0)
	_check(firm.decided and firm.after < 0.6,"a firm shake is a shake at once (after %.2f s)" % firm.after)
	print("  firm: fall %.3f, jiggle %.4f screens, pace %.2f" % [firm.amount,firm.jiggle,firm.pace])
	_check(firm.amount > 4.0*gentle.amount and firm.amount > 0.25,"a firm shake brings a flurry (%.3f against %.3f)" % [firm.amount,gentle.amount])
	_check(precipitation.state.y > 0.2,"into the precipitation's shake channel (%.3f)" % precipitation.state.y)
	_check(globe.kind() == "snow","in the cold it snows")
	_check(firm.jiggle > 3.0*slow_jiggle and firm.jiggle > 0.01,"the diorama jiggles with the shake (%.4f), a slow drag barely (%.4f)" % [firm.jiggle,slow_jiggle])
	_check(firm.camera_moved,"the camera moves with the jiggle")
	_check(firm.jiggle > 2.0*gentle.jiggle,"harder than with a gentle one (%.4f)" % gentle.jiggle)
	_check(firm.pace > gentle.pace+0.3,"the hand shakes faster the harder it is shaken (%.2f, %.2f)" % [firm.pace,gentle.pace])
	_check(hand.player.current_animation == "ShakeHold","the hand is in ShakeHold")
	var reach: Vector3 = Basis(Vector3.UP,hand.yaw)*Vector3.BACK
	_check(reach.dot(globe.rim_inward) > 0.95,"its reach leads in across the lip")
	_check(hand.anchor.distance_to(globe.rim_point) < 0.05,"it holds the lip (%.3f m off)" % hand.anchor.distance_to(globe.rim_point))
	var tip: Vector3 = hand._bone_at(hand.skeleton.find_bone("Middle3"))
	var inward: float = (tip-globe.rim_point).dot(globe.rim_inward)
	print("  middle fingertip joint: %.2f m in from the lip, %.2f m over it" % [inward,tip.y-globe.rim_point.y])
	_check(inward > 0.0 and absf(tip.y-globe.rim_point.y) < 0.4,"its fingers hook over onto the plate's top")

	# Release: the jiggle rings down, the fall thins away by itself.
	globe.release()
	var crossings := 0
	var last_x: float = globe.jiggle.x
	var falls: Array[float] = []
	var out_seen := false
	for i in range(int(3.0/DT)):
		_step()
		if signf(globe.jiggle.x) != signf(last_x) and absf(globe.jiggle.x) > 0.0: crossings += 1
		last_x = globe.jiggle.x
		falls.append(globe.amount())
		if hand.player.current_animation == "ShakeOut": out_seen = true
	_check(hand.reach_gesture == "" and hand.reach_point == null and hand.reach_facing == null,"letting go clears the hand's reach")
	_check(out_seen,"the hand plays ShakeOut")
	_check(String(hand.player.current_animation).begins_with("Idle"),"and floats home to Idle")
	_check(crossings >= 2,"the jiggle rings through rest (%d crossings)" % crossings)
	_check(globe.jiggle == Vector2.ZERO and scene._tremor.jiggle == Vector3.ZERO,"and comes to rest within 3 s")
	var falling := true
	for i in range(30,falls.size()):
		if falls[i] > falls[i-1]+0.0001: falling = false
	_check(falling and falls[-1] > 0.0 and falls[-1] < firm.amount,"the fall thins away after release (%.3f after 3 s)" % falls[-1])
	var snow_left := _settle(10.0)
	_settle(60.0)
	_check(globe.amount() == 0.0 and precipitation.state.y == 0.0,"and is over on its own")

	# A long firm shake brings more than a short one.
	var long := _shake(near,0.07,4.0,5.0)
	_check(long.amount > firm.amount+0.1,"a longer shake brings more (%.3f against %.3f)" % [long.amount,firm.amount])
	globe.release()
	_settle(80.0)

	# Out of the cold it rains, and rain is sooner gone.
	weather.snow_phase = 0.0
	var wet := _shake(near,0.07,4.0,2.0)
	_check(globe.kind() == "rain","otherwise it rains")
	_check(absf(wet.amount-firm.amount) < 0.15,"as much as snow for the same shake (%.3f)" % wet.amount)
	globe.release()
	_settle(3.0)
	var rain_left := _settle(10.0)
	_check(rain_left < snow_left,"rain clears sooner than snow drifts down (%.3f against %.3f after 13 s)" % [rain_left,snow_left])
	_settle(60.0)

	# The seam hands the hand back: gripping only once decided, if asked.
	globe.claim_grip = false
	globe.grab(near)
	_step()
	_check(hand.reach_gesture == "","with claim_grip off the hand waits for a shake")
	var decided_at := -1.0
	for i in range(60):
		if globe.feed(Vector2(0.07*height*TAU*4.0*cos(TAU*4.0*i*DT)*DT,0.0),DT) and decided_at < 0.0: decided_at = i*DT
		_step()
	_check(decided_at >= 0.0 and hand.reach_gesture == "shake","and grips once it is one")
	globe.release()
	_step()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)

## Shake the rim sideways at `amplitude` screen heights and `hz` for
## `seconds`. Returns what it did, at the end, still held.
func _shake(at: Vector2, amplitude: float, hz: float, seconds: float) -> Dictionary:
	globe.grab(at)
	var result := {"decided":false,"after":-1.0,"jiggle":0.0,"camera_moved":false,"pace":0.0}
	for i in range(int(seconds/DT)):
		var speed := amplitude*height*TAU*hz*cos(TAU*hz*i*DT)
		if globe.feed(Vector2(speed*DT,0.0),DT) and not result.decided:
			result.decided = true
			result.after = i*DT
		_step()
		result.jiggle = maxf(result.jiggle,globe.jiggle.length())
		var moved: Transform3D = scene._tremor.apply(scene.camera.transform)
		if moved.origin.distance_to(scene.camera.transform.origin) > 0.05: result.camera_moved = true
		result.pace = maxf(result.pace,hand.reach_pace)
	result.amount = globe.amount()
	return result

## Let `seconds` pass, returning the fall's amount then.
func _settle(seconds: float) -> float:
	for i in range(int(seconds/DT)): _step()
	return globe.amount()

func _step() -> void:
	globe.advance(DT)
	hand._process(DT)
	hand.player.advance(DT)
