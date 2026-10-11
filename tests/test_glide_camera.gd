extends SceneTree
## The glide's chase camera (scripts/glide_camera.gd): it trails behind and
## above the glider at a cruise, swings out wider at the float and pulls in
## close in a dive; it hangs on a spring, so a turn swings it out and it
## catches up; the free look turns it round the glider and it swings back
## when let go, at once or, lingering, only after a while without a turn;
## it never goes into rock; first person puts it in the head.
## The plane (scripts/plane_figure.gd) follows the glide and its mark
## shows near the ground.
const SkyGlide = preload("res://scripts/sky_glide.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_trails()
	_breathes()
	_swings()
	_free_look()
	_keeps_out()
	_first_person()
	_figure()
	print("PASS: glide camera" if failures == 0 else "FAIL: glide camera")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func open_air(_p: Vector3) -> Variant:
	return null

func flying() -> SkyGlide:
	var glide := SkyGlide.new()
	glide.launch(Vector3(0.0,20.0,0.0),0.0,6.0,false)
	return glide

func run(glide: SkyGlide, cam: GlideCamera, seconds: float, input: Dictionary, solid := Callable()) -> void:
	for i in range(int(seconds/DT)):
		glide.step(DT,input,open_air)
		cam.step(DT,glide,float(input.get("dive",0.0)),solid)

## Behind (+Z when heading 0), above, a few metres off, looking ahead.
func _trails() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,4.0,{})
	var off := cam.eye-glide.position
	var back := off.dot(-glide.forward())
	check(back > 3.5 and back < 7.0,"At a cruise it trails behind (%.1f m back)" % back)
	check(off.y > 0.6,"And above (%.1f m up)" % off.y)
	check((cam.look-glide.position).dot(glide.forward()) > 1.0,"It looks ahead of the glider")

func _breathes() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,3.0,{})
	var cruise := cam.eye.distance_to(glide.position)
	run(glide,cam,3.0,{"dive":1.0})
	var dive := cam.eye.distance_to(glide.position)
	check(dive < cruise*0.6,"In a dive it pulls in close (%.1f m from %.1f)" % [dive,cruise])
	# Out of the dive and up into the float.
	var wide := 0.0
	var hang := 0.0
	for i in range(int(10.0/DT)):
		glide.step(DT,{"pitch":1.0} if i < 90 else {},open_air)
		cam.step(DT,glide,0.0)
		wide = maxf(wide,cam.eye.distance_to(glide.position))
		hang = maxf(hang,glide.hang)
	check(hang > 0.3 and wide > cruise+1.0,"At the float it swings out wide (%.1f m, hang %.2f)" % [wide,hang])

func _swings() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,3.0,{})
	run(glide,cam,0.5,{"turn":1.0})
	check(cam.roll < -0.1,"It leans with the glider's bank (%.2f rad)" % cam.roll)
	var behind := -glide.forward()
	var off := (cam.eye-glide.position).normalized()
	var lag := Vector2(off.x,off.z).normalized().angle_to(Vector2(behind.x,behind.z).normalized())
	check(absf(lag) > 0.15,"In a turn it swings out and lags (%.2f rad)" % lag)
	run(glide,cam,3.0,{})
	off = (cam.eye-glide.position).normalized()
	behind = -glide.forward()
	lag = Vector2(off.x,off.z).normalized().angle_to(Vector2(behind.x,behind.z).normalized())
	check(absf(lag) < 0.1,"Then it catches up behind (%.2f rad)" % lag)

func _free_look() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,3.0,{})
	cam.free_held = true
	cam.turn(Vector2(PI*0.5,0.0))
	run(glide,cam,2.0,{})
	var off := cam.eye-glide.position
	check(absf(off.dot(glide.forward().cross(Vector3.UP).normalized())) > 2.5,"The free look turns it round to the side (%.1f m)" % off.dot(glide.forward().cross(Vector3.UP)))
	cam.free_held = false
	run(glide,cam,3.0,{})
	off = cam.eye-glide.position
	check(off.dot(-glide.forward()) > 3.0,"Let go, it swings back behind")
	var held := flying()
	var pan := GlideCamera.new()
	pan.linger = 2.5
	pan.reset(held,held.position)
	run(held,pan,3.0,{})
	pan.turn(Vector2(PI*0.5,0.0))
	run(held,pan,2.0,{})
	check(pan.free.x > PI*0.5-0.01,"Lingering, a pan holds after the turn (%.2f rad)" % pan.free.x)
	run(held,pan,3.0,{})
	check(absf(pan.free.x) < 0.3,"Then it swings back behind (%.2f rad)" % pan.free.x)

func _keeps_out() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	# A wall just behind the glider.
	var wall := func(p: Vector3) -> bool: return p.z > glide.position.z+1.5
	run(glide,cam,3.0,{},wall)
	check(not wall.call(cam.eye),"It never goes into rock (eye %.2f m behind)" % (cam.eye.z-glide.position.z))

func _first_person() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	cam.first_person = true
	run(glide,cam,1.0,{"turn":1.0})
	check(cam.eye.is_equal_approx(glide.position),"First person puts the eye in the glider's head")
	check(is_equal_approx(cam.roll,-glide.bank),"And leans with its whole bank")

func _figure() -> void:
	var glide := flying()
	var figure: Node3D = PlaneFigure.new()
	root.add_child(figure)
	figure.reset(glide)
	var ground := func(_p: Vector3) -> Variant: return Vector2(glide.position.y-5.0,-50.0)
	for i in range(60):
		glide.step(DT,{"rise":1.0},open_air)
		figure.update(DT,glide,0.0,ground,true)
	check(figure.position.distance_to(glide.position) < 0.6,"The plane rides with the glide")
	var mark: MeshInstance3D = figure._mark
	check(mark.visible and absf(mark.position.y-(glide.position.y-5.0)) < 0.2,"Near the ground its mark shows on it")
	var scarf_tail: Vector3 = figure._scarf_points[figure.SCARF-1]
	check((scarf_tail-glide.position).dot(glide.forward()) < -0.5,"Its scarf streams behind")
	var high := func(_p: Vector3) -> Variant: return Vector2(glide.position.y-200.0,-300.0)
	figure.update(DT,glide,0.0,high,false)
	check(not mark.visible,"High up, no mark")
	figure.free()
