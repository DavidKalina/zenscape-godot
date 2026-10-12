extends SceneTree
## Where the plane sits in the chase camera's frame (scripts/glide_camera.gd,
## docs/design/flight-camera.md): flies a fixed set of hard manoeuvres
## (chained full-stick turns, boosted turns, a dive and pull-up, mouse
## flicks, knife-edge drifts, barrel rolls, a loop) and, every frame, puts
## the plane's middle, wingtips, nose and tail through the camera's
## projection (16:9). Prints, per run and per manoeuvre, how often the
## middle is off screen and how often any of the plane is outside the safe
## margin (MARGIN of the half-screen in from each edge), the closest the eye
## came, the plane's span as a share of the screen's width, and what was
## going on in the frames it was lost (stone stopping the eye, the tuck,
## the spring lagging its goal).
##
## `open`: the bare maths (SkyPlane + GlideCamera, no stone), at plane
## sizes 1 (the old toy) and WorldScale.plane. `isle`: the aqueduct isle
## (studies/aqueduct_isle.tscn), the game's camera and stone, the same
## manoeuvres low over the isle, then pursuit routes hard by its stone (a
## weave round its ruins, the stumps' slot under the aqueduct, a wall hug,
## through the stone circle), also counting the frames the plane's middle
## is hidden from the eye by stone or turf. Both headless.
## `lead`: turning, where the plane is now in the view of LEAD_BACK frames
## ago (|x| in half-screens; smaller: that view looked where it went).
## Options: `unframed` (open: the camera as the glide has it, no framing),
## `speed=<x>` (open), `routes` (isle: the routes only), `move=<name>` and
## `only=<route>` (isle: one manoeuvre or route), `lost` (print each frame
## lost or hidden), `trace` (each route lap's progress). The game's flags
## pass through (--plane-scale=, --plane-speed=, --plane-turn=, --cam-*).
## The isle runs aren't exactly repeatable (its life and sky move on their
## own); compare whole runs. docs/design/flight-camera.md has the numbers.
##   godot --headless --path . -s tools/flight_frame.gd -- open [unframed] [speed=1.15]
##   godot --headless --path . -s tools/flight_frame.gd -- isle [--plane-scale=1]
const SkyPlane = preload("res://scripts/sky_plane.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const DT := 1.0/60.0
const ASPECT := 16.0/9.0
## The safe box: a point past this share of the half-screen is in the margin.
const MARGIN := 0.8

## The manoeuvres: [name, [seconds, input]...].
static func moves() -> Array:
	var L := {"turn":-1.0}
	var R := {"turn":1.0}
	return [
		["cruise",[[3.0,{}]]],
		["chained turns",[[2.5,L],[2.5,R],[2.5,L],[2.5,R],[1.5,{}]]],
		["boosted turns",[[1.0,{"boost":1.0}],[2.0,{"turn":-1.0,"boost":1.0}],[2.0,{"turn":1.0,"boost":1.0}],[2.0,{"turn":-1.0,"boost":1.0}],[1.5,{}]]],
		["dive and pull",[[1.2,{"pitch":-1.0}],[1.0,{}],[1.8,{"pitch":1.0,"turn":-1.0}],[1.5,{}]]],
		["mouse flicks",[[0.6,{"look":Vector2(0.05,0.0)}],[0.6,{"look":Vector2(-0.05,0.0)}],[0.6,{"look":Vector2(0.05,0.0)}],[0.6,{"look":Vector2(-0.05,0.0)}],[1.5,{}]]],
		["knife drifts",[[2.0,{"lean":-1.0,"turn":-1.0}],[0.5,{}],[2.0,{"lean":1.0,"turn":1.0}],[1.5,{}]]],
		["barrel rolls",[[0.02,{"roll":-1.0}],[1.0,{}],[0.02,{"roll":1.0}],[1.0,{}],[0.02,{"roll":-1.0,"turn":-1.0}],[1.2,{"turn":-1.0}],[1.0,{}]]],
		["climb and loop",[[1.5,{"pitch":1.0}],[3.0,{"turn":-1.0,"pitch":0.6}],[2.0,{}]]],
		["braked turns",[[2.0,{"brake":1.0,"turn":1.0}],[2.0,{"brake":1.0,"turn":-1.0}],[1.0,{}]]],
	]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "open"
	var speed := -1.0
	for a in args:
		if a.begins_with("speed="): speed = float(a.substr(6))
	if mode == "isle": await _isle()
	else:
		for size in [1.0,WorldScale.plane]: _open(size,speed)
	quit(0)

## The plane's points to frame: middle, wingtips, nose, tail (global).
static func points(middle: Vector3, basis: Basis, span: float) -> Array:
	var half := span*0.5
	return [middle,middle+basis.x*half,middle-basis.x*half,middle-basis.z*half*0.75,middle+basis.z*half*0.85]

## A camera's basis looking from `eye` at `look`, rolled `roll` (as kit_isle
## `_frame_plane`: look_at then rotate_object_local(FORWARD, roll)).
static func cam_basis(eye: Vector3, look: Vector3, roll: float) -> Basis:
	var b := Basis.looking_at(look-eye,Vector3.UP)
	return b*Basis(Vector3.FORWARD,roll)

## A point in normalised screen coordinates (-1..1 each way; behind the eye:
## far off).
static func screen(basis: Basis, eye: Vector3, fov: float, p: Vector3) -> Vector2:
	var c := basis.inverse()*(p-eye)
	if c.z > -0.05: return Vector2(9.0,9.0)
	var t := tan(deg_to_rad(fov)*0.5)
	return Vector2(c.x/(-c.z)/(t*ASPECT),c.y/(-c.z)/t)

## The view LEAD_BACK frames ago, for the lead metric.
const LEAD_BACK := 45
var _views: Array = []
var _last_heading := NAN

func _remember(basis: Basis, eye: Vector3, fov: float, middle: Vector3, heading: float, tallies: Array) -> void:
	_views.append([basis,eye,fov])
	if _views.size() > LEAD_BACK: _views.pop_front()
	var rate := 0.0 if is_nan(_last_heading) else absf(angle_difference(_last_heading,heading))/DT
	_last_heading = heading
	if _views.size() < LEAD_BACK or rate < 0.8: return
	var v: Array = _views[0]
	var x := absf(screen(v[0],v[1],v[2],middle).x)
	for t: Tally in tallies:
		t.lead_sum += minf(x,2.0)
		t.lead_n += 1

func _forget() -> void:
	_views.clear()
	_last_heading = NAN

class Tally:
	var frames := 0
	var off := 0
	var margin := 0
	var worst := 0.0
	var closest := INF
	var span_sum := 0.0
	## Turning: where the plane is now in the view of LEAD_BACK frames ago
	## (|x|, half-screens): small if that view looked where it went.
	var lead_sum := 0.0
	var lead_n := 0
	var clipped := 0
	var tucked := 0
	var lagged := 0
	var short := 0
	var log_lost := OS.get_cmdline_user_args().has("lost")
	## Frames the plane's middle is hidden from the eye by stone or turf
	## (isle only).
	var hidden := 0
	func add(pts: Array, eye: Vector3, middle: Vector3, cam: RefCounted) -> void:
		frames += 1
		var c: Vector2 = pts[0]
		if absf(c.x) > 1.0 or absf(c.y) > 1.0: off += 1
		var most := 0.0
		for p: Vector2 in pts: most = maxf(most,maxf(absf(p.x),absf(p.y)))
		worst = maxf(worst,most)
		var d := eye.distance_to(middle)
		closest = minf(closest,d)
		span_sum += minf((pts[1] as Vector2).distance_to(pts[2])*0.5,2.0)
		if most > MARGIN:
			margin += 1
			if cam.clipped: clipped += 1
			if float(cam.tuck) > 0.25: tucked += 1
			var off3: Vector3 = cam._offset
			var goal: Vector3 = cam.goal
			if off3.length() > 0.1 and goal.length() > 0.1 and off3.angle_to(goal) > 0.35: lagged += 1
			if off3.length() < goal.length()*0.75: short += 1
			if log_lost: print("      lost fr %d: most %.2f centre %s dist %.1f goal %.1f off %.1f ang %.2f clipped %s tuck %.2f fov %.0f speed %.1f bank %.2f" % [frames,most,str((pts[0] as Vector2).snapped(Vector2.ONE*0.01)),d,goal.length(),off3.length(),off3.angle_to(goal) if off3.length() > 0.1 and goal.length() > 0.1 else 0.0,str(cam.clipped),float(cam.tuck),float(cam.fov),0.0,0.0])
	func line(name: String) -> String:
		var n := maxf(frames,1)
		return "%-16s %5d fr  off %5.1f%%  margin %5.1f%%  hidden %5.1f%%  worst %5.2f  closest %5.1f m  span %4.2f  lead %4.2f  | lost: stone %d tuck %d lag %d short %d" % [name,frames,100.0*off/n,100.0*margin/n,100.0*hidden/n,worst,closest,span_sum/n,lead_sum/maxf(lead_n,1),clipped,tucked,lagged,short]

func _open(size: float, speed: float) -> void:
	_forget()
	var plane := SkyPlane.new()
	plane.floor_y = -1000.0
	plane.use_game_speed()
	if speed > 0.0:
		plane.speed_scale = speed
		plane.turn_scale = speed
	plane.launch(Vector3(0.0,300.0,0.0),0.0,plane.cruise(),false)
	var cam := GlideCamera.new()
	cam.size = size
	if not OS.get_cmdline_user_args().has("unframed"):
		cam.framed = true
		cam.near = WorldScale.TOY_SPAN*size*GlideCamera.NEAR_SPANS
		cam.extent = WorldScale.TOY_SPAN*size*0.5
		cam.cruise = plane.cruise()
	cam.reset(plane,plane.position+Vector3(0.0,2.0,6.0)*size)
	var open_air := func(_p: Vector3) -> Variant: return null
	for i in range(120):
		plane.step(DT,{},open_air)
		cam.step(DT,plane,0.0)
	print("open air, plane size %.1f, speed x%.2f" % [size,plane.speed_scale])
	var all := Tally.new()
	for move: Array in moves():
		var t := Tally.new()
		for seg: Array in move[1]:
			for i in range(maxi(1,int(float(seg[0])/DT))):
				var input: Dictionary = seg[1]
				if input.has("roll") and i > 0: input = {}
				plane.step(DT,input,open_air)
				cam.step(DT,plane,0.0)
				var basis := Basis.from_euler(Vector3(float(plane.pitch),float(plane.heading),-float(plane.bank)-float(plane.spin)),EULER_ORDER_YXZ)
				var middle: Vector3 = plane.position+cam.lift
				var cb := cam_basis(cam.eye,cam.look,cam.roll)
				var pts := []
				for p: Vector3 in points(middle,basis,WorldScale.TOY_SPAN*size): pts.append(screen(cb,cam.eye,cam.fov,p))
				t.add(pts,cam.eye,middle,cam)
				all.add(pts,cam.eye,middle,cam)
				_remember(cb,cam.eye,cam.fov,middle,float(plane.heading),[t,all])
		print("  "+t.line(move[0]))
	print("  "+all.line("all"))

# --- On the aqueduct isle ----------------------------------------------------------------

var study: Node3D

func _isle() -> void:
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	study.board()
	print("aqueduct isle, plane size %.1f, speed x%.2f, cam size %.2f" % [WorldScale.plane,float(study.plane.speed_scale),float(study.chase.size)])
	var all := Tally.new()
	# Low over the isle along the aqueduct (x 100, z 0 to -44), the
	# manoeuvres each from the same start, heading north.
	var starts := [[Vector3(110.0,Art.TOP+5.0,20.0),0.0],[Vector3(70.0,Art.TOP+6.0,30.0),0.0],[Vector3(140.0,Art.TOP+4.0,-10.0),PI*0.5]]
	var pick := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("move="): pick = arg.substr(5)
	for move: Array in ([] if OS.get_cmdline_user_args().has("routes") else moves()):
		if pick != "" and not str(move[0]).begins_with(pick): continue
		var t := Tally.new()
		for s: Array in starts:
			study.fly_from(s[0],s[1])
			_forget()
			for i in range(90): _isle_step({},null)
			for seg: Array in move[1]:
				for i in range(maxi(1,int(float(seg[0])/DT))):
					var input: Dictionary = seg[1]
					if input.has("roll") and i > 0: input = {}
					_isle_step(input,[t,all])
				if not study.flying: break
		print("  "+t.line(move[0]))
	# Pursuit routes close by stone: a weave round the isle's ruins, low;
	# threading the aqueduct's arches (4 m clear, its deck over them); along
	# its east face 3 m off, then hard over it; through the stone circle.
	var a := Art.TOP+1.8
	var ring := Art.TOP+Art.T2+2.5
	var routes := [
		["isle weave",Vector3(150.0,Art.TOP+6.0,-28.0),PI*0.5,[Vector3(120.0,Art.TOP+4.0,-28.0),Vector3(80.0,Art.TOP+3.5,-28.0),Vector3(61.0,Art.TOP+12.0,-5.0),Vector3(75.0,Art.TOP+5.0,25.0),Vector3(100.0,Art.TOP+3.0,10.0),Vector3(100.0,Art.TOP+3.0,-10.0),Vector3(125.0,Art.TOP+5.0,5.0)]],
		["arch threads",Vector3(135.0,a,-28.0),PI*0.5,[Vector3(112.0,a,-28.0),Vector3(88.0,a,-28.0),Vector3(70.0,a+2.0,-36.0),Vector3(80.0,a,-40.0),Vector3(112.0,a,-40.0),Vector3(130.0,a+2.0,-28.0),Vector3(125.0,a,-16.0),Vector3(112.0,a,-16.0),Vector3(88.0,a,-16.0)]],
		["wall hug",Vector3(104.5,Art.TOP+3.0,15.0),0.0,[Vector3(104.5,Art.TOP+3.0,-5.0),Vector3(104.5,Art.TOP+2.5,-30.0),Vector3(96.0,Art.TOP+8.0,-36.0),Vector3(95.0,Art.TOP+3.0,-10.0),Vector3(104.5,Art.TOP+7.5,0.0),Vector3(112.0,Art.TOP+3.0,-20.0)]],
		["stone circle",Vector3(95.0,ring,0.0),PI*0.5,[Vector3(75.0,ring,0.0),Vector3(61.0,ring,0.0),Vector3(48.0,ring,2.0),Vector3(55.0,ring,14.0),Vector3(61.0,ring,0.0),Vector3(64.0,ring,-14.0),Vector3(75.0,ring,-4.0)]],
	]
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="): only = arg.substr(5)
	for r: Array in routes:
		if only != "" and not str(r[0]).begins_with(only): continue
		var t := Tally.new()
		for lap in range(2):
			study.fly_from(r[1],r[2])
			_forget()
			for i in range(90): _isle_step({},null)
			var at := 0
			var time := 0.0
			var landed := 0
			var pinned := 0.0
			var settle := 0
			var pins := 0
			var route: Array = r[3]
			while at < route.size() and time < 40.0 and study.flying:
				var p: Vector3 = study.plane.position
				var to: Vector3 = route[at]-p
				# Reached, or passed it (behind the nose and near).
				# Pinned on stone a second: give that point up.
				pinned = pinned+DT if float(study.plane.speed) < SkyPlane.SLOW+0.6 else 0.0
				if to.length() < 4.0 or (to.length() < 12.0 and to.dot(study.plane.forward()) < 0.0) or pinned > 1.0:
					if pinned > 1.0: pins += 1
					pinned = 0.0
					at += 1
				if at >= route.size(): break
				# Touched down (the hand landing sticks a touch): back up and on.
				if not study.hand_landing.flying():
					landed += 1
					var on: Vector3 = route[at]-p
					study.fly_from(p+Vector3.UP*4.0,atan2(-on.x,-on.z))
					_forget()
					settle = 90
				settle -= 1
				_isle_step(_toward(route[at],1.0 if lap == 1 else 0.0),[t,all] if settle < 0 else null)
				time += DT
				if OS.get_cmdline_user_args().has("trace2") and int(time/DT) % 30 == 0: print("      t %.1f at %s speed %.1f heading %.2f phase %s flying %s" % [time,str(study.plane.position.snapped(Vector3.ONE*0.1)),float(study.plane.speed),float(study.plane.heading),str(study.hand_landing.phase),str(study.flying)])
			if OS.get_cmdline_user_args().has("trace"): print("    %s lap %d: %d/%d points in %.1f s, %d touches, %d pins, at %s" % [r[0],lap,at,route.size(),time,landed,pins,str(study.plane.position.round())])
		print("  "+t.line(r[0]))
	print("  "+all.line("all"))

const Art = preload("res://studies/aqueduct_isle_art.gd")

## Pure pursuit at `aim` (as tests/test_isle_hall_chain.gd `_toward`), hard.
func _toward(aim: Vector3, boost: float) -> Dictionary:
	var plane: RefCounted = study.plane
	var to: Vector3 = aim-plane.position
	var want := atan2(-to.x,-to.z)
	var off := angle_difference(float(plane.heading),want)
	var climb := atan2(to.y,Vector2(to.x,to.z).length())
	return {"turn":clampf(-off*2.5,-1.0,1.0),"pitch":clampf((climb-float(plane.pitch))*2.0,-1.0,1.0),"boost":boost}

func _isle_step(input: Dictionary, tallies: Variant) -> void:
	if not study.flying: return
	study.fly_step(DT,input)
	if tallies == null: return
	var cam: Camera3D = study.camera
	var fig: Node3D = study.plane_figure
	var basis := fig.global_basis
	var span := WorldScale.TOY_SPAN*basis.x.length()
	var middle: Vector3 = study.plane.position+study.chase.lift
	var cb := cam.global_basis.orthonormalized()
	var pts := []
	for p: Vector3 in points(middle,basis.orthonormalized(),span): pts.append(screen(cb,cam.global_position,cam.fov,p))
	var ray := PhysicsRayQueryParameters3D.create(cam.global_position,middle,study.plane_mask())
	var blocked := not study.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	_remember(cb,cam.global_position,cam.fov,middle,float(study.plane.heading),tallies)
	for t: Tally in tallies:
		t.add(pts,cam.global_position,middle,study.chase)
		if blocked: t.hidden += 1
		if blocked and t.log_lost and t == tallies[0]: print("      hidden: plane %s eye %s dist %.1f dodge %s reach %.1f near %.1f ground %s" % [str(study.plane.position.snapped(Vector3.ONE*0.1)),str(cam.global_position.snapped(Vector3.ONE*0.1)),cam.global_position.distance_to(middle),str(study.chase._dodge),float(study.chase._reach),float(study.chase.near),str(study.plane_ground(study.plane.position))])
