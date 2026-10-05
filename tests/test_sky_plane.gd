extends SceneTree
## The little plane (scripts/sky_plane.gd) keeps the glide's rules and flies
## like a toy: it never stalls with the nose held up; Boost speeds it up and
## Brake slows it, never under SLOW; a held bank turns it and it rolls level
## when let go; a barrel roll goes all the way round in ROLL_TIME and comes
## out level on its heading; it skims the ground, slides under an island and
## a long fall is caught. Its figure (scripts/plane_figure.gd) builds and
## follows it through a roll, and the chase camera (scripts/glide_camera.gd)
## stays steady and leans no further than ROLL_MAX through one.
const SkyPlane = preload("res://scripts/sky_plane.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_cruise()
	_never_stalls()
	_throttle()
	_turns()
	_barrel_roll()
	_skim()
	_under_island()
	_caught()
	_lands()
	_figure()
	_camera()
	print("PASS: sky plane" if failures == 0 else "FAIL: sky plane")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func fly(plane: SkyPlane, seconds: float, input: Dictionary, ground := Callable(self,"air")) -> void:
	for i in range(int(seconds/DT)): plane.step(DT,input,ground)

func flying() -> SkyPlane:
	var plane := SkyPlane.new()
	plane.launch(Vector3(0.0,20.0,0.0),0.0,6.0,false)
	return plane

func finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

## Left alone it holds its cruise, level, and an island goes by in seconds.
func _cruise() -> void:
	var plane := flying()
	var from := plane.position
	fly(plane,6.0,{})
	check(absf(plane.speed-SkyPlane.CRUISE_SPEED) < 0.5,"It settles to its cruise (%.1f m/s)" % plane.speed)
	check(plane.speed > SkyPlane.CRUISE*2.0,"Well quicker than the glide's cruise")
	check(absf(plane.velocity.y) < 0.2,"It holds its height under power (%.2f m/s)" % plane.velocity.y)
	check(48.0/plane.speed > 2.0 and 48.0/plane.speed < 6.0,"A 48 m island takes %.1f s to cross" % (48.0/plane.speed))
	check(plane.position.distance_to(from) > 60.0,"It flies on")

func _never_stalls() -> void:
	var plane := flying()
	var slowest := INF
	for i in range(int(10.0/DT)):
		plane.step(DT,{"pitch":1.0},air)
		slowest = minf(slowest,plane.speed)
	check(slowest >= SkyPlane.SLOW-0.001,"Nose held up, it never drops under SLOW (%.2f m/s)" % slowest)
	check(plane.velocity.length() > SkyPlane.SLOW*0.9,"And it still flies (%.1f m/s)" % plane.velocity.length())

func _throttle() -> void:
	var plane := flying()
	fly(plane,3.0,{})
	var cruise := plane.speed
	fly(plane,4.0,{"boost":1.0})
	check(plane.speed > cruise+4.0,"Boost speeds it up (%.1f to %.1f m/s)" % [cruise,plane.speed])
	var slowest := INF
	for i in range(int(10.0/DT)):
		plane.step(DT,{"brake":1.0,"pitch":0.6},air)
		slowest = minf(slowest,plane.speed)
	check(plane.speed < cruise-2.0,"Brake slows it (%.1f m/s)" % plane.speed)
	check(slowest >= SkyPlane.SLOW-0.001,"Never under SLOW, even braking nose up (%.2f m/s)" % slowest)

func _turns() -> void:
	var plane := flying()
	fly(plane,1.0,{})
	var from := plane.heading
	fly(plane,0.1,{"turn":1.0})
	var early := absf(angle_difference(from,plane.heading))
	fly(plane,1.9,{"turn":1.0})
	var turned := absf(angle_difference(from,plane.heading))
	check(plane.bank > 0.7,"Held right, it banks right (%.2f rad)" % plane.bank)
	check(turned > 1.5,"And the bank turns it (%.2f rad in 2 s)" % turned)
	check(early < 0.05,"The bank comes first, then the turn (%.3f rad at 0.1 s)" % early)
	check(plane.heading < from,"Right turns right")
	fly(plane,2.0,{})
	check(absf(plane.bank) < 0.05,"Let go, it rolls level (%.2f rad)" % plane.bank)
	var left := flying()
	fly(left,1.0,{"turn":-1.0})
	check(left.bank < -0.5 and left.heading > 0.0,"Held left, it banks and turns left")
	var mouse := flying()
	mouse.step(DT,{"look":Vector2(0.05,0.0)},air)
	check(mouse.heading < 0.0,"Mouse right turns right")

## A roll goes all the way round in ROLL_TIME, hops sideways a little, and
## comes out level on the heading it went in on.
func _barrel_roll() -> void:
	for dir: float in [1.0,-1.0]:
		var plane := flying()
		fly(plane,1.0,{})
		var heading := plane.heading
		var start := plane.position
		plane.step(DT,{"roll":dir},air)
		check(plane.rolling,"A roll starts on the press (%s)" % ("right" if dir > 0.0 else "left"))
		var most := 0.0
		var steps := 1
		var flaps := plane.flaps
		while plane.rolling and steps < 600:
			plane.step(DT,{},air)
			most = maxf(most,absf(plane.spin))
			steps += 1
		var seconds := steps*DT
		check(absf(seconds-SkyPlane.ROLL_TIME) < 0.05,"It takes %.2f s" % seconds)
		check(most > TAU*0.97,"It goes all the way round (%.2f rad)" % most)
		check(plane.spin == 0.0 and absf(plane.bank) < 0.05,"It comes out level (bank %.3f)" % plane.bank)
		check(absf(angle_difference(heading,plane.heading)) < 0.05,"On the heading it went in on (%.3f rad off)" % absf(angle_difference(heading,plane.heading)))
		var side := Vector3(cos(heading),0.0,-sin(heading))
		var hop: float = (plane.position-start).dot(side)*dir
		check(hop > 0.3 and hop < 3.0,"With a little hop the way it rolled (%.2f m)" % hop)
		check(flaps == plane.flaps,"One roll at a time")
	var twice := flying()
	twice.step(DT,{"roll":1.0},air)
	twice.step(DT,{"roll":-1.0},air)
	check(twice.roll_dir == 1.0,"A press mid-roll does not turn it back")

func flat(_p: Vector3) -> Variant:
	return 2.0

func _skim() -> void:
	var plane := flying()
	plane.position.y = 6.0
	var lowest := INF
	var skims := 0
	for i in range(int(4.0/DT)):
		plane.step(DT,{"pitch":-1.0},flat)
		lowest = minf(lowest,plane.position.y)
		if plane.skimming: skims += 1
	check(lowest >= 2.0+SkyPlane.SKIM-0.001,"Diving into the ground skims over it (lowest %.2f m)" % lowest)
	check(skims > 0 and plane.speed >= SkyPlane.SLOW,"It keeps going along it (%.1f m/s)" % plane.speed)
	fly(plane,2.0,{"pitch":1.0},flat)
	check(plane.position.y > 2.0+SkyPlane.SKIM+2.0,"Nose up, it climbs off again (%.1f m)" % plane.position.y)

## A plate 28 m square, ground at 2 m, rock down to -10 m.
func island(p: Vector3) -> Variant:
	if absf(p.x) >= 14.0 or absf(p.z) >= 14.0: return null
	return Vector2(2.0,-10.0)

func inside(p: Vector3) -> bool:
	return absf(p.x) < 14.0 and absf(p.z) < 14.0 and p.y > -10.0-SkyPlane.CLEAR+0.01 and p.y < 2.0+SkyPlane.SKIM-0.01

func _under_island() -> void:
	var plane := SkyPlane.new()
	plane.launch(Vector3(-40.0,-18.0,0.0),-PI*0.5,14.0,false)
	var was_inside := false
	var below := 0
	for i in range(int(5.0/DT)):
		plane.step(DT,{},island)
		was_inside = was_inside or inside(plane.position)
		if absf(plane.position.x) < 14.0 and plane.position.y < 0.0: below += 1
	check(not was_inside and below > 60,"It passes beneath an island (%d frames under)" % below)
	check(plane.position.x > 14.0,"And out the far side (x %.1f m)" % plane.position.x)
	plane.launch(Vector3(-10.0,-13.0,0.0),-PI*0.5,10.0,false)
	var under_rock := false
	for i in range(int(1.0/DT)):
		plane.step(DT,{"pitch":1.0},island)
		was_inside = was_inside or inside(plane.position)
		under_rock = under_rock or plane.under_rock
	check(under_rock and not was_inside,"Pulled up under the rock, it slides along under it")

func _caught() -> void:
	var plane := flying()
	var lowest := INF
	for i in range(int(60.0/DT)):
		plane.step(DT,{"pitch":-1.0,"boost":1.0},air)
		lowest = minf(lowest,plane.position.y)
	check(lowest > SkyPlane.FLOOR-60.0,"A long dive is caught under the floor (lowest %.1f m)" % lowest)
	fly(plane,20.0,{})
	check(plane.position.y > SkyPlane.FLOOR-25.0,"Let go, the cushion lifts it back towards the band (%.1f m)" % plane.position.y)

## Braked to a skim, it is slow enough to land (the wanderer's LAND_SPEED
## is 10 m/s); coming in with F it slows to land by itself.
func _lands() -> void:
	var plane := flying()
	plane.position.y = 4.0
	fly(plane,4.0,{"brake":1.0,"pitch":-0.3},flat)
	check(plane.skimming and plane.speed < 10.0,"Braked onto the ground it skims slow enough to land (%.1f m/s)" % plane.speed)
	var coming := flying()
	coming.approach = true
	fly(coming,6.0,{},flat)
	check(coming.speed < 10.0,"Coming in to land it slows to %.1f m/s" % coming.speed)
	coming.step(DT,{"boost":1.0},flat)
	check(not coming.approach,"Boost calls the landing off")

func _figure() -> void:
	var plane := flying()
	var figure: Node3D = PlaneFigure.new()
	root.add_child(figure)
	figure.reset(plane)
	var ground := func(_p: Vector3) -> Variant: return Vector2(plane.position.y-5.0,-50.0)
	plane.step(DT,{"roll":1.0},air)
	var ok := true
	var turned := 0.0
	var up_was := figure.basis.y
	for i in range(90):
		plane.step(DT,{"turn":0.5},air)
		figure.update(DT,plane,0.0,ground,true,0.5,0.3)
		ok = ok and finite(figure.position) and finite(figure.basis.x) and finite(figure.basis.y) and finite(figure.basis.z)
		turned += up_was.angle_to(figure.basis.y)
		up_was = figure.basis.y
	check(ok,"Through a roll its transform stays finite")
	check(turned > TAU*0.9,"It is drawn turning all the way round (%.2f rad)" % turned)
	check(figure.position.distance_to(plane.position) < 0.6,"The plane rides with the flight")
	var mark: MeshInstance3D = figure._mark
	check(mark.visible and absf(mark.position.y-(plane.position.y-5.0)) < 0.2,"Near the ground its mark shows on it")
	var scarf_tail: Vector3 = figure._scarf_points[figure.SCARF-1]
	check((scarf_tail-plane.position).dot(plane.forward()) < -0.5,"Its scarf streams behind")
	var high := func(_p: Vector3) -> Variant: return Vector2(plane.position.y-200.0,-300.0)
	figure.update(DT,plane,0.0,high,false)
	check(not mark.visible,"High up, no mark")
	figure.free()

func _camera() -> void:
	var plane := flying()
	var cam := GlideCamera.new()
	cam.reset(plane,plane.position+Vector3(0.0,2.0,5.0))
	for i in range(60):
		plane.step(DT,{},air)
		cam.step(DT,plane,0.0)
	var ok := true
	var most := 0.0
	for roll: float in [1.0,-1.0]:
		plane.step(DT,{"roll":roll},air)
		for i in range(int(1.2/DT)):
			plane.step(DT,{"turn":roll},air)
			cam.step(DT,plane,0.0)
			ok = ok and finite(cam.eye) and finite(cam.look) and is_finite(cam.roll) and is_finite(cam.fov)
			most = maxf(most,absf(cam.roll))
	check(ok,"Through barrel rolls the camera stays finite")
	check(most <= GlideCamera.ROLL_MAX+0.0001,"It leans no further than ROLL_MAX (%.3f rad)" % most)
	var back := (cam.eye-plane.position).dot(-plane.forward())
	check(back > 2.0 and back < 9.0,"And it still trails behind (%.1f m)" % back)
