extends SceneTree
## The skydive (scripts/sky_dive.gd), as plain maths, headless:
##   - the pop out of the plane kicks up, keeps some of the plane's way,
##     and tumbles onto the belly into the fall;
##   - the fall holds its terminal speed: tucked faster, spread slower;
##   - left and right turn it, forward tracks across the ground;
##   - Jump opens the pocket sail (scripts/pocket_sail.gd): it kicks once,
##     catches the fall to its sink, steers, floats braked, folds with Jump
##     again and opens again with no kick;
##   - nothing opens by itself: left alone it lands hard (a bump), over the
##     ground and over water; under the sail the touch is soft;
##   - off an edge on foot it falls upright under the walker's gravity, the
##     walker's sail carried on into it, open and kick spent;
##   - an island's side holds the fall off, and its top is landed on;
##   - its sail (scripts/pocket_sail_figure.gd) and camera (scripts/
##     dive_camera.gd) build and follow it.
##   godot --headless --path . --script tests/test_sky_dive.gd
const SkyDive = preload("res://scripts/sky_dive.gd")
const DiveCamera = preload("res://scripts/dive_camera.gd")
const PocketSailFigure = preload("res://scripts/pocket_sail_figure.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_pop()
	_terminal()
	_steer()
	_sail()
	_no_auto_open()
	_no_auto_open_water()
	_step_off()
	_island_side()
	_figure_and_camera()
	print("PASS: sky dive" if failures == 0 else "FAIL: sky dive")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func nothing(_p: Vector3) -> Variant:
	return null

## Flat ground at 0 everywhere, its rock 20 m deep.
func flat(_p: Vector3) -> Variant:
	return Vector2(0.0,-20.0)

## An island 160 m across round the origin, its top at 0.
const HALF := 80.0
func island(p: Vector3) -> Variant:
	return Vector2(0.0,-12.0) if absf(p.x) < HALF and absf(p.z) < HALF else null

func fall(dive: SkyDive, seconds: float, input: Dictionary, ground := Callable(self,"nothing")) -> Array:
	var seen := []
	for i in range(int(seconds/DT)):
		var out := dive.fall(DT,input,ground)
		for k in out: if not k in seen: seen.append(k)
		if dive.phase == SkyDive.DOWN: break
	return seen

func _pop() -> void:
	var dive := SkyDive.new()
	var plane_v := Vector3(0.0,0.0,-14.0)
	dive.eject(Vector3(0.0,100.0,0.0),plane_v,0.0)
	check(dive.phase == SkyDive.POP and dive.velocity.y > 3.0,"Ejecting pops it up (%.1f m/s)" % dive.velocity.y)
	var top := dive.position.y
	for i in range(30):
		dive.fall(DT,{},Callable(self,"nothing"))
		top = maxf(top,dive.position.y)
	check(top > 100.5 and top < 103.0,"A small kick up: %.2f m" % (top-100.0))
	check(dive.position.z < -2.0,"It keeps some of the plane's way (%.1f m on)" % -dive.position.z)
	fall(dive,1.0,{})
	check(dive.phase == SkyDive.FREEFALL,"And falls")
	check(absf(dive.tilt-PI*0.5) < 0.35,"Tumbled onto its belly (tilt %.2f)" % dive.tilt)
	fall(dive,2.0,{})
	check(Vector2(dive.velocity.x,dive.velocity.z).length() < 1.5,"The plane's way fades out (%.1f m/s across)" % Vector2(dive.velocity.x,dive.velocity.z).length())

func _terminal() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(0.0,2000.0,0.0),0.0,0.0)
	fall(dive,6.0,{})
	check(absf(-dive.velocity.y-SkyDive.TERMINAL) < 0.6,"Belly-down it falls at %.1f m/s" % -dive.velocity.y)
	fall(dive,4.0,{"boost":1.0})
	check(-dive.velocity.y > SkyDive.TERMINAL_TUCK-2.0,"Tucked it dives at %.1f m/s" % -dive.velocity.y)
	check(dive.tilt > PI*0.5+0.4,"Head-down (tilt %.2f)" % dive.tilt)
	fall(dive,4.0,{"brake":1.0})
	check(absf(-dive.velocity.y-SkyDive.TERMINAL_SPREAD) < 1.0,"Spread it slows to %.1f m/s" % -dive.velocity.y)
	check(dive.phase == SkyDive.FREEFALL,"Over open air it never opens by itself")

func _steer() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(0.0,2000.0,0.0),0.0)
	var heading := dive.heading
	fall(dive,1.0,{"turn":1.0})
	check(dive.heading < heading-1.5,"Right turns it (%.2f rad)" % (heading-dive.heading))
	check(dive.bank < -0.2,"Banking into the turn")
	dive.drop(Vector3(0.0,2000.0,0.0),0.0)
	fall(dive,3.0,{"pitch":-1.0})
	check(dive.velocity.z < -SkyDive.TRACK*0.8,"Forward tracks across the ground (%.1f m/s)" % -dive.velocity.z)

func _sail() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(0.0,2000.0,0.0),0.0)
	fall(dive,3.0,{})
	var falling := dive.velocity.y
	var seen := fall(dive,DT,{"open":true})
	check("opened" in seen and dive.sailing(),"Jump: the sail comes out")
	check(dive.velocity.y > falling+PocketSail.KICK-0.5,"With its kick (%.1f to %.1f m/s)" % [falling,dive.velocity.y])
	fall(dive,4.0,{})
	check(absf(-dive.velocity.y-PocketSail.SINK) < 0.2,"Coasting down at %.2f m/s" % -dive.velocity.y)
	check(absf(Vector2(dive.velocity.x,dive.velocity.z).length()-PocketSail.PACE) < 0.4,"Gliding on at %.1f m/s" % Vector2(dive.velocity.x,dive.velocity.z).length())
	check(absf(dive.tilt) < 0.2,"Hanging upright under it (tilt %.2f)" % dive.tilt)
	var heading := dive.heading
	fall(dive,1.0,{"turn":-1.0})
	check(dive.heading > heading+1.0,"Left steers it round")
	fall(dive,3.0,{"brake":1.0})
	check(-dive.velocity.y < PocketSail.SINK-0.2,"Braked it floats (%.2f m/s)" % -dive.velocity.y)
	seen = fall(dive,DT,{"open":true})
	check("folded" in seen and dive.falling(),"Jump again folds it")
	fall(dive,1.0,{})
	var dropping := dive.velocity.y
	seen = fall(dive,DT,{"open":true})
	check("opened" in seen and dive.velocity.y < dropping+1.0,"Opened again, no second kick (%.1f to %.1f m/s)" % [dropping,dive.velocity.y])

func _no_auto_open() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(0.0,120.0,0.0),0.0)
	var touch := {}
	for i in range(int(60.0/DT)):
		var out := dive.fall(DT,{},Callable(self,"flat"))
		if out.has("touched"): touch = out.touched
		if dive.phase == SkyDive.DOWN: break
	check(not touch.is_empty() and touch.hard,"Left alone nothing opens: it lands hard, a bump")
	check(absf(dive.position.y-SkyDive.HIPS) < 0.01,"Stood on the ground")
	var soft := SkyDive.new()
	soft.drop(Vector3(0.0,40.0,0.0),0.0)
	fall(soft,1.0,{},Callable(self,"flat"))
	fall(soft,DT,{"open":true},Callable(self,"flat"))
	fall(soft,60.0,{},Callable(self,"flat"))
	check(soft.phase == SkyDive.DOWN and not soft.touched.hard and float(soft.touched.speed) < PocketSail.PACE+1.0,"Under the sail it touches down soft (%.1f m/s)" % float(soft.touched.get("speed",99.0)))

func _no_auto_open_water() -> void:
	var dive := SkyDive.new()
	dive.water = -50.0
	dive.drop(Vector3(0.0,100.0,0.0),0.0)
	fall(dive,60.0,{},Callable(self,"nothing"))
	check(dive.phase == SkyDive.DOWN and dive.touched.get("water",false) and dive.touched.hard,"Over open water it comes down on it, unopened")

func _step_off() -> void:
	var walker := PocketSail.new()
	walker.rest()
	walker.peak = 10.0
	var moving := Vector3(-PilotMotor.RUN,-1.0,0.0)
	walker.deploy(moving,PI*0.5,10.0)
	var dive := SkyDive.new()
	dive.step_off(Vector3(0.0,9.0,0.0),moving,PI*0.5,walker,PilotMotor.GRAVITY*PilotMotor.FALL,PilotMotor.TERMINAL)
	check(dive.sailing() and dive.sail == walker and walker.kicked,"Sailed off an edge, the walker's sail carries on, its kick spent")
	var plain := SkyDive.new()
	plain.step_off(Vector3(0.0,200.0,0.0),Vector3(-PilotMotor.RUN,0.0,0.0),PI*0.5,null,PilotMotor.GRAVITY*PilotMotor.FALL,PilotMotor.TERMINAL)
	fall(plain,0.3,{})
	check(plain.falling() and plain.upright and absf(plain.tilt) < 0.5,"Walked off, it falls upright (tilt %.2f)" % plain.tilt)
	check(plain.velocity.x < -PilotMotor.RUN*0.7,"Carried on out the way he ran (%.1f m/s)" % -plain.velocity.x)
	fall(plain,2.0,{})
	check(absf(-plain.velocity.y-PilotMotor.TERMINAL) < 1.5,"At the walker's fastest fall (%.1f m/s)" % -plain.velocity.y)
	var seen := fall(plain,DT,{"open":true})
	check("opened" in seen and plain.sail.kicked,"Jump opens the sail, with its kick")

func _island_side() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(HALF+3.0,-5.0,0.0),PI*0.5)
	var inside := false
	for i in range(int(4.0/DT)):
		dive.fall(DT,{"pitch":-1.0},Callable(self,"island"))
		var p := dive.position
		if absf(p.x) < HALF and absf(p.z) < HALF and p.y-SkyDive.HIPS < 0.0 and p.y > -12.0: inside = true
	check(not inside,"Beside an island, its side holds the fall off")
	var top := SkyDive.new()
	top.drop(Vector3(0.0,60.0,0.0),0.0)
	fall(top,60.0,{},Callable(self,"island"))
	check(top.phase == SkyDive.DOWN and not top.touched.get("water",true) and absf(float(top.touched.top)) < 0.01,"Over it, it lands on its top")

func _figure_and_camera() -> void:
	var dive := SkyDive.new()
	dive.drop(Vector3(0.0,200.0,0.0),0.0)
	var camera := DiveCamera.new()
	camera.reset(dive,Vector3(0.0,205.0,6.0),70.0)
	for i in range(120):
		dive.fall(DT,{"boost":1.0},Callable(self,"nothing"))
		camera.step(DT,dive)
	check(camera.eye.y > dive.position.y+1.0 and camera.look.y < dive.position.y,"Falling, the camera rides over the shoulders looking down past them")
	check(camera.fov > DiveCamera.FOV+5.0,"Its view widens with the fall (%.0f deg)" % camera.fov)
	dive.open_sail()
	for i in range(int(4.0/DT)):
		dive.fall(DT,{},Callable(self,"nothing"))
		camera.step(DT,dive)
	var behind := Vector2(camera.eye.x-dive.position.x,camera.eye.z-dive.position.z)
	check(behind.length() > 3.0 and camera.eye.y < dive.position.y+4.0,"Under the sail it falls back behind")
	var figure := PocketSailFigure.new()
	root.add_child(figure)
	for i in range(30): figure.update(DT,dive.sailing(),0.5)
	check(figure.visible and figure.out >= 1.0 and figure.get_child_count() > 0,"The sail's figure builds and pops out")
	for i in range(30): figure.update(DT,false)
	check(not figure.visible,"Folded, it goes")
	figure.queue_free()
