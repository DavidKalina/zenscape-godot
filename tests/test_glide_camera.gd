extends SceneTree
## The glide's chase camera (scripts/glide_camera.gd): it trails behind and
## above the glider at a cruise, swings out wider at the float and pulls in
## close in a dive; it hangs on a spring, so a turn swings it out and it
## catches up; the free look turns it round the glider and it swings back
## when let go, at once or, lingering, only after a while without a turn;
## it never goes into rock; first person puts it in the head.
## Framed (the game's plane, docs/design/flight-camera.md): through chained
## full-stick turns, boosted turns, mouse flicks and a dive the plane stays
## inside the safe part of the view; with rock behind it swings round or
## lifts over, and never comes nearer than its least; it leads into a turn;
## and it reads speed against the plane's cruise, easing back at boost.
## The plane (scripts/plane_figure.gd) follows the glide and its mark
## shows near the ground.
const SkyGlide = preload("res://scripts/sky_glide.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
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
	_framed_turns()
	_framed_rock()
	_framed_lead()
	_framed_speed()
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
	var high := func(_p: Vector3) -> Variant: return Vector2(glide.position.y-200.0,-300.0)
	figure.update(DT,glide,0.0,high,false)
	check(not mark.visible,"High up, no mark")
	figure.free()

# --- Framed: the game's plane ----------------------------------------------------

## A plane at the game's size and speed and its framed camera, settled.
func framed_plane() -> Array:
	var size := WorldScale.plane
	var plane := SkyPlane.new()
	plane.use_game_speed()
	plane.launch(Vector3(0.0,200.0,0.0),0.0,plane.cruise(),false)
	var cam := GlideCamera.new()
	cam.framed = true
	cam.size = size
	cam.near = WorldScale.TOY_SPAN*size*GlideCamera.NEAR_SPANS
	cam.extent = WorldScale.TOY_SPAN*size*0.5
	cam.cruise = plane.cruise()
	cam.reset(plane,plane.position+Vector3(0.0,3.0,10.0))
	fly_framed(plane,cam,3.0,{})
	return [plane,cam]

## Flies `plane` and its camera; the most the plane's edge was out in the view.
func fly_framed(plane: SkyPlane, cam: GlideCamera, seconds: float, input: Dictionary, solid := Callable()) -> float:
	var most := 0.0
	for i in range(int(seconds/DT)):
		plane.step(DT,input,open_air)
		cam.step(DT,plane,0.0,solid)
		most = maxf(most,on_screen(cam,plane.position))
	return most

## How far out the plane's edge is in the view, as a share of the
## half-screen (the larger way; 16:9; behind the eye: 9).
func on_screen(cam: GlideCamera, at: Vector3) -> float:
	var basis := Basis.looking_at(cam.look-cam.eye,Vector3.UP)*Basis(Vector3.FORWARD,cam.roll)
	var p := basis.inverse()*(at-cam.eye)
	if p.z > -0.05: return 9.0
	var half := tan(deg_to_rad(cam.fov)*0.5)
	var pad := cam.extent/-p.z
	return maxf((absf(p.x/-p.z)+pad)/(half*cam.aspect),(absf(p.y/-p.z)+pad)/half)

func _framed_turns() -> void:
	var got := framed_plane()
	var plane: SkyPlane = got[0]
	var cam: GlideCamera = got[1]
	var most := 0.0
	for turn in [-1.0,1.0,-1.0,1.0]: most = maxf(most,fly_framed(plane,cam,2.5,{"turn":turn}))
	for turn in [-1.0,1.0]: most = maxf(most,fly_framed(plane,cam,2.0,{"turn":turn,"boost":1.0}))
	for flick in [0.12,-0.12,0.12]: most = maxf(most,fly_framed(plane,cam,0.4,{"look":Vector2(flick,0.0)}))
	most = maxf(most,fly_framed(plane,cam,1.2,{"pitch":-1.0}))
	most = maxf(most,fly_framed(plane,cam,1.5,{"pitch":1.0,"turn":1.0}))
	check(most <= GlideCamera.EDGE+0.01,"Framed, through chained turns, flicks and a dive the plane stays in the view's safe part (its edge out to %.2f of the half-screen, EDGE %.2f)" % [most,GlideCamera.EDGE])

func _framed_rock() -> void:
	var got := framed_plane()
	var plane: SkyPlane = got[0]
	var cam: GlideCamera = got[1]
	# A slab over and behind the plane, where the eye trails: it lifts over
	# or swings round rather than drawing in.
	var slab := func(p: Vector3) -> bool:
		var rel: Vector3 = p-plane.position
		return rel.z > 3.0 and rel.z < 6.0 and rel.y > 0.5 and rel.y < 4.0 and absf(rel.x) < 3.0
	var nearest := INF
	var inside := 0
	for i in range(int(2.0/DT)):
		plane.step(DT,{},open_air)
		cam.step(DT,plane,0.0,slab)
		nearest = minf(nearest,cam.eye.distance_to(plane.position))
		if slab.call(cam.eye): inside += 1
	check(inside == 0 and nearest > cam.near*1.5,"A slab where it trails: it goes round or over, not in (nearest %.1f m, least %.1f, %d frames in it)" % [nearest,cam.near,inside])
	# A wall all the way behind: it comes in, but never nearer than its least.
	var wall := func(p: Vector3) -> bool: return p.z > plane.position.z+2.0
	nearest = INF
	var most := 0.0
	for i in range(int(2.0/DT)):
		plane.step(DT,{},open_air)
		cam.step(DT,plane,0.0,wall)
		nearest = minf(nearest,cam.eye.distance_to(plane.position))
		most = maxf(most,on_screen(cam,plane.position))
	check(nearest >= cam.near-0.01,"Rock all round behind: never nearer than %.1f m (nearest %.1f)" % [cam.near,nearest])
	check(most <= GlideCamera.EDGE+0.01,"And the plane stays in view (%.2f)" % most)
	# Clear again, it eases back out.
	fly_framed(plane,cam,2.0,{})
	check(cam.eye.distance_to(plane.position) > cam.near*1.8,"Clear again, it eases back out (%.1f m)" % cam.eye.distance_to(plane.position))

func _framed_lead() -> void:
	var got := framed_plane()
	var plane: SkyPlane = got[0]
	var cam: GlideCamera = got[1]
	fly_framed(plane,cam,1.5,{"turn":-1.0})
	# Turning left (heading growing), the look ahead swings left of its way.
	var on := cam.look-plane.position
	var way: Vector3 = cam._way
	var left := Vector3(way.z,0.0,-way.x).normalized()
	check(on.dot(left) > 0.5 and absf(cam._yaw_rate) > 1.0,"In a turn the view leads into it (%.1f m to the turn's side)" % on.dot(left))

func _framed_speed() -> void:
	var got := framed_plane()
	var plane: SkyPlane = got[0]
	var cam: GlideCamera = got[1]
	var cruise_fov := cam.fov
	var cruise_back := cam.eye.distance_to(plane.position)
	fly_framed(plane,cam,4.0,{"boost":1.0})
	check(cam.fov > cruise_fov+2.0,"At boost the view widens (%.1f deg from %.1f)" % [cam.fov,cruise_fov])
	check(cam.eye.distance_to(plane.position) > cruise_back*1.04,"And it eases back rather than tucking in (%.1f m from %.1f)" % [cam.eye.distance_to(plane.position),cruise_back])
	# Read against the cruise: a toy-speed plane at its cruise has the same view.
	var toy := SkyPlane.new()
	toy.launch(Vector3(0.0,200.0,0.0),0.0,toy.cruise(),false)
	var cam2 := GlideCamera.new()
	cam2.framed = true
	cam2.cruise = toy.cruise()
	cam2.reset(toy,toy.position+Vector3(0.0,3.0,10.0))
	fly_framed(toy,cam2,3.0,{})
	check(absf(cam2.fov-cruise_fov) < 0.3,"At cruise the view is the same whatever the plane's speed (%.1f, %.1f deg)" % [cam2.fov,cruise_fov])
