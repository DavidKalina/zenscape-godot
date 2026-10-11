extends SceneTree
## The game's hand landing on a kit isle (studies/kit_isle.gd, scripts/
## manual_landing.gd), headless, on the aqueduct isle: it starts on foot
## with the plane parked on open turf near the start, solid to walk into;
## F on foot away from it flies nothing; Space by it climbs in and takes off
## (BOARD, TAXI, ROLL, LIFT) and the hand landing has it aloft; a hot touch
## on the turf sticks (no hop) and slides on its wheels; asking out rolling
## is refused, braked it stops, and only then F gets out; the plane stays
## parked where it stopped, the pilot beside it; boarding it again takes
## off; walked off the isle he drops into the canopy, is stranded and then
## back beside the plane. Round 3: low over the turf the hint says what a
## touch now would get; a near-vertical slam onto the turf bounces back up
## (never into it) and flies on; stopped, Shift held backs it up, steering
## as a car backs, and let go it stops; nosed into stone it stops short,
## then a turn on the spot and backing up get it free to roll on.
##   godot --headless --path . --script tests/test_kit_isle_landing.gd
const ManualLanding = preload("res://scripts/manual_landing.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("kit isle landing test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	await physics_frame
	_parked_at_start()
	_f_on_foot_flies_nothing()
	_solid()
	_take_off()
	_slam()
	_hot_touch()
	_stop_and_get_out()
	_board_again()
	_free_from_stone()
	_off_the_edge()
	print("PASS: kit isle landing" if failures == 0 else "FAIL: kit isle landing (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	study._unhandled_input(key)

func _turf_under(p: Vector3) -> float:
	var top: Variant = study.plane_ground(p+Vector3.UP*0.5)
	return NAN if top == null else float(top)

## Next to the parked plane, at its hop-out spot.
func _beside_plane() -> void:
	var spot: Vector3 = study._hop_spot(study.parked_at,study.parked_heading)
	study.place(spot,Vector2(0.0,-1.0))
	study._last_stood = spot
	study.tick(DT)

func _parked_at_start() -> void:
	check(not study.flying and study.parked,"It starts on foot, the plane parked")
	var at: Vector3 = study.parked_at
	var across := Vector2(at.x-study.start.x,at.z-study.start.z).length()
	check(across >= study.HOME_NEAR-0.5 and across <= study.HOME_FAR+0.5,"Parked near the start (%.1f m off)" % across)
	check(absf(_turf_under(at)-at.y) < 0.3,"On the turf (%.2f m off it)" % absf(_turf_under(at)-at.y))
	check(study.plane_figure != null and bool(study.plane_figure.parked) and study.plane_figure.is_inside_tree(),"Its figure stands parked")
	check(study._park_body != null,"With the column the walker keeps off")
	check(str(study._switch_hint.text).contains("Walk to your plane"),"The hint says to walk to the plane: '%s'" % str(study._switch_hint.text).get_slice("\n",0))

func _f_on_foot_flies_nothing() -> void:
	check(not study.by_plane(),"At the start he is not by the plane")
	_key(KEY_F)
	for i in range(10): study.tick(DT)
	check(not study.flying,"F on foot away from the plane flies nothing")
	_key(KEY_SPACE)
	check(not study.flying,"Nor does Space away from it")

## Walked straight at the parked plane's middle: held off it.
func _solid() -> void:
	var at: Vector3 = study.parked_at
	var from := at+Vector3(3.0,0.0,0.0)
	var top := _turf_under(from)
	if is_nan(top): from = at+Vector3(-3.0,0.0,0.0)
	top = _turf_under(from)
	study.place(Vector3(from.x,top,from.z),Vector2(at.x-from.x,at.z-from.z).normalized())
	var nearest := INF
	for i in range(int(1.5/DT)):
		var to := Vector2(at.x-study.motor.feet.x,at.z-study.motor.feet.z)
		study.script_want = to.normalized()
		study.tick(DT)
		nearest = minf(nearest,Vector2(study.motor.feet.x-at.x,study.motor.feet.z-at.z).length())
	study.script_want = Vector2.ZERO
	check(nearest >= study.PARKED_ROOM-0.05,"Walked into it, he is held off its middle (nearest %.2f m)" % nearest)
	check(not study.flying,"Walking into it boards nothing")

func _take_off() -> void:
	_beside_plane()
	check(study.by_plane(),"Beside it he is by the plane")
	check(str(study._switch_hint.text).contains("Space (pad A)  climb in"),"The hint offers to climb in")
	_key(KEY_SPACE)
	check(study.flying and study.takeoff != null and not study.parked,"Space by it: in, taking off, no longer parked")
	check(study._park_body == null,"Its column is gone")
	var phases := {}
	var t := 0.0
	while study.flying and study.takeoff != null and t < 10.0:
		phases[PlaneLanding.NAMES[study.takeoff.phase]] = true
		study.fly_step(DT,{})
		t += DT
	check(phases.has("board") and phases.has("roll"),"Board, (taxi,) roll and lift: %s" % ", ".join(phases.keys()))
	check(study.takeoff == null and study.hand_landing.flying(),"Off in %.1f s, the hand landing has it aloft" % t)
	for i in range(int(1.0/DT)): study.fly_step(DT,{"pitch":0.3})
	var over: float = float(study.plane.position.y)-_turf_under(study.plane.position) if not is_nan(_turf_under(study.plane.position)) else 99.0
	check(study.hand_landing.flying() and over > 1.0,"Flying clear of the turf (%.1f m over it)" % over)

## A stretch of open, nearly flat turf RUN m long: {at (its top), way}.
const RUN := 34.0
func _open_run() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	for gx in range(20):
		for gz in range(16):
			var top: Vector3 = study._turf_top(space,40.0+gx*5.0,-30.0+gz*4.0)
			if top == Vector3.INF: continue
			for d in range(8):
				var way := Vector3(cos(TAU*d/8.0),0.0,sin(TAU*d/8.0))
				var ok := true
				for s in range(1,18):
					var p := top+way*RUN*s/17.0
					var there: Vector3 = study._turf_top(space,p.x,p.z)
					if there == Vector3.INF or absf(there.y-top.y) > 0.6: ok = false
				if not ok: continue
				var turn := Basis(Vector3.UP,atan2(-way.x,-way.z))
				for s in range(0,18):
					var p := top+way*RUN*s/17.0
					if study._stone_at(p+Vector3.UP*0.6,turn): ok = false
				if ok: return {"at":top,"way":way}
	return {}

var _run := {}

func _hot_touch() -> void:
	_run = _open_run()
	check(not _run.is_empty(),"Open turf %d m long to land on found" % RUN)
	if _run.is_empty(): return
	var way: Vector3 = _run.way
	var plane: RefCounted = study.plane
	study.fly_from((_run.at as Vector3)+Vector3.UP*2.0,atan2(-way.x,-way.z))
	var touched := false
	var t := 0.0
	while t < 3.0 and study.hand_landing.flying():
		study.fly_step(DT,{"pitch":-0.6})
		t += DT
	var ml: RefCounted = study.hand_landing
	var touches: Array = ml.stats.touches
	check(not touches.is_empty(),"Nosed down at cruise, it touches the turf (after %.1f s)" % t)
	if touches.is_empty(): return
	var first: Dictionary = touches[0]
	print("  touch: %s at %.1f m/s, sinking %.2f" % [first.grade,first.speed,first.sink])
	check(float(first.speed) > ManualLanding.TOUCH_FAST and str(first.grade) in ["hot","hard"],"A hot touch (%s, %.1f m/s)" % [first.grade,first.speed])
	check(ml.on_ground() and int(ml.stats.bounces) == 0,"It sticks: on its wheels, no hop")
	check(study.flying and not bool(study.plane_figure.parked),"Still in the plane, not parked")
	check(study.spray != null,"The wheels' spray is out")
	var over: float = float(plane.position.y)-_turf_under(plane.position)
	check(over > 0.0 and over < 1.0,"Sat on the turf, never in it (%.2f m over)" % over)

## Dived near-vertically at the open turf: the hint warns low down, the
## touch bounces ("slam"), and it flies on, never into the turf.
func _slam() -> void:
	_run = _open_run()
	if _run.is_empty(): return
	var way: Vector3 = _run.way
	study.fly_from((_run.at as Vector3)+Vector3.UP*14.0,atan2(-way.x,-way.z))
	var ml: RefCounted = study.hand_landing
	study.plane.pitch = -1.25
	var warned := false
	var lowest := INF
	var t := 0.0
	while t < 4.0 and int(ml.stats.bounces) == 0 and ml.flying():
		study.fly_step(DT,{"pitch":-1.0})
		if str(study._switch_hint.text).contains("Too steep"): warned = true
		t += DT
	check(warned,"Low over the turf in a steep dive, the hint warns it will bounce")
	var reasons: Dictionary = ml.stats.bounce_reasons
	check(int(reasons.get("slam",0)) == 1 and ml.flying(),"A near-vertical slam onto the turf bounces back up, flying (%s)" % str(reasons))
	check(str(study._switch_hint.text).contains("Bounced"),"The hint says why: '%s'" % str(study._switch_hint.text).get_slice("\n",0))
	for i in range(int(1.0/DT)):
		study.fly_step(DT,{})
		var under := _turf_under(study.plane.position)
		if not is_nan(under): lowest = minf(lowest,float(study.plane.position.y)-under)
	check(ml.flying() and lowest > 0.3,"It flies on, never into the turf (lowest %.2f m over it)" % lowest)

## Stopped on the turf, Shift held backs it up, the stick turning it as a
## car backs; let go, it stops.
func _back_up() -> void:
	if _run.is_empty(): return
	var ml: RefCounted = study.hand_landing
	var t := 0.0
	while study.flying and ml.phase == ManualLanding.ROLL and t < 8.0:
		study.fly_step(DT,{"brake":1.0})
		t += DT
	if ml.phase != ManualLanding.STOPPED: return
	var at: Vector3 = study.plane.position
	var h0 := float(study.plane.heading)
	var fwd := Vector2(-sin(h0),-cos(h0))
	for i in range(int(1.6/DT)): study.fly_step(DT,{"brake":1.0,"turn":0.6})
	var moved := Vector2(study.plane.position.x-at.x,study.plane.position.z-at.z)
	check(ml.reversing and moved.dot(fwd) < -0.6,"Stopped, Shift held backs it up (%.1f m back)" % -moved.dot(fwd))
	check(float(study.plane.heading) > h0+0.15,"The stick turns it backing up, as a car backs (%.2f rad)" % (float(study.plane.heading)-h0))
	check(str(study._switch_hint.text).contains("Backing up"),"The hint says so")
	t = 0.0
	while ml.phase != ManualLanding.STOPPED and t < 2.0:
		study.fly_step(DT,{})
		t += DT
	check(ml.phase == ManualLanding.STOPPED and not ml.reversing,"Let go of Shift, it stops (%.1f s)" % t)

## Turf running up to stone: {at (the turf's top), way} with clear turf to
## start from and stone across the way within a few metres.
func _stone_ahead() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var c: Vector3 = study.isle_circle()
	for gx in range(-12,13):
		for gz in range(-12,13):
			var top: Vector3 = study._turf_top(space,c.x+gx*3.0,c.y+gz*3.0)
			if top == Vector3.INF: continue
			for d in range(8):
				var way := Vector3(cos(TAU*d/8.0),0.0,sin(TAU*d/8.0))
				var turn := Basis(Vector3.UP,atan2(-way.x,-way.z))
				if study._stone_at(top+Vector3.UP*0.6,turn): continue
				# Room behind to back into.
				var room := true
				for b in range(1,7):
					var back: Vector3 = study._turf_top(space,top.x-way.x*b*0.5,top.z-way.z*b*0.5)
					if back == Vector3.INF or absf(back.y-top.y) > 0.3 or study._stone_at(back+Vector3.UP*0.6,turn): room = false
				if not room: continue
				for k in range(1,12):
					var p := top+way*k*0.5
					var there: Vector3 = study._turf_top(space,p.x,p.z)
					if there == Vector3.INF or absf(there.y-top.y) > 0.3: break
					if study._stone_at(there+Vector3.UP*0.6,turn):
						if k >= 3: return {"at":top,"way":way}
						break
	return {}

## Stood on the turf facing stone: rolled into it, it stops short; then
## a turn on the spot and backing up get it free, and it rolls on.
func _free_from_stone() -> void:
	var spot := _stone_ahead()
	check(not spot.is_empty(),"Turf running up to stone found")
	if spot.is_empty() or not study.flying: return
	var ml: RefCounted = study.hand_landing
	var way: Vector3 = spot.way
	var at: Vector3 = spot.at
	var heading := atan2(-way.x,-way.z)
	var plane: RefCounted = study.plane
	study.takeoff = null
	plane.launch(at,heading,SkyPlane.SLOW,false)
	plane.heading = heading
	plane.position = Vector3(at.x,at.y+0.6,at.z)
	plane.speed = 0.0
	plane.velocity = Vector3.ZERO
	ml.begin(plane,true)
	for i in range(3): study.fly_step(DT,{})
	var t := 0.0
	var hit := false
	var moved := 0.0
	while t < 5.0:
		var before: Vector3 = plane.position
		study.fly_step(DT,{"boost":0.4})
		moved = Vector2(plane.position.x-at.x,plane.position.z-at.z).length()
		if ml.roll_speed() < 0.01 and t > 0.5 and before.distance_to(plane.position) < 0.001:
			hit = true
			break
		t += DT
	check(hit and ml.on_ground(),"Rolled at the stone, it stops short (%.1f m on)" % moved)
	var stopped_at: Vector3 = plane.position
	# Shift, Space and the stick: round on the spot.
	t = 0.0
	while t < 0.5 and ml.phase != ManualLanding.STOPPED:
		study.fly_step(DT,{"brake":1.0})
		t += DT
	var h0 := float(plane.heading)
	for i in range(int(1.0/DT)): study.fly_step(DT,{"brake":1.0,"boost":1.0,"turn":1.0})
	check(ml.phase == ManualLanding.STOPPED and absf(angle_difference(h0,float(plane.heading))) > 0.6,"Shift, Space and a turn: round on the spot (%.2f rad)" % absf(angle_difference(h0,float(plane.heading))))
	# Turned back to the stone, Shift held backs it off.
	plane.heading = heading
	for i in range(int(0.3/DT)): study.fly_step(DT,{})
	for i in range(int(2.0/DT)): study.fly_step(DT,{"brake":1.0})
	var back := Vector2(plane.position.x-stopped_at.x,plane.position.z-stopped_at.z)
	check(back.dot(Vector2(way.x,way.z)) < -1.0,"Shift held backs it off the stone (%.1f m)" % -back.dot(Vector2(way.x,way.z)))
	# Free: turned away and rolled on.
	t = 0.0
	while t < 1.0 and ml.phase != ManualLanding.STOPPED:
		study.fly_step(DT,{})
		t += DT
	for i in range(int(1.5/DT)): study.fly_step(DT,{"brake":1.0,"boost":1.0,"turn":1.0})
	var from: Vector3 = plane.position
	for i in range(int(1.5/DT)): study.fly_step(DT,{"boost":0.5})
	check(plane.position.distance_to(from) > 1.0 and ml.on_ground(),"Turned away, it rolls on free (%.1f m)" % plane.position.distance_to(from))

func _stop_and_get_out() -> void:
	if _run.is_empty(): return
	var ml: RefCounted = study.hand_landing
	study.fly_step(DT,{"exit":true})
	check(study.flying and ml.phase == ManualLanding.ROLL and int(ml.stats.early_exits) >= 1,"Asking out while rolling is refused (stop first)")
	var t := 0.0
	while study.flying and ml.phase == ManualLanding.ROLL and t < 8.0:
		study.fly_step(DT,{"brake":1.0})
		t += DT
	check(ml.phase == ManualLanding.STOPPED,"Braked, it stops (%.1f s, %.1f m from the touch)" % [t,float(ml.stats.rollout)])
	if ml.phase != ManualLanding.STOPPED: return
	_back_up()
	for i in range(30): study.fly_step(DT,{})
	check(study.flying and ml.phase == ManualLanding.STOPPED,"Stopped, it never gets out by itself")
	check(str(study._switch_hint.text).contains("get out"),"The hint offers the way out")
	var stood: Vector3 = study.plane.position
	study.fly_step(DT,{"exit":true})
	t = 0.0
	while study.flying and t < 3.0:
		study.fly_step(DT,{})
		t += DT
	check(not study.flying,"F stopped: out (%.2f s)" % t)
	check(study.parked and Vector2(study.parked_at.x-stood.x,study.parked_at.z-stood.z).length() < 0.3,"The plane stays parked where it stopped")
	check(bool(study.plane_figure.parked) and study._park_body != null,"Its figure parked, solid again")
	var feet: Vector3 = study.motor.feet
	check(Vector2(feet.x-stood.x,feet.z-stood.z).length() < 2.6 and study.figure.visible,"He stands beside it (%.1f m)" % Vector2(feet.x-stood.x,feet.z-stood.z).length())
	for i in range(20): study.tick(DT)
	check(study.motor.grounded and study.by_plane(),"On his feet, by the plane")

func _board_again() -> void:
	if not study.parked: return
	_beside_plane()
	_key(KEY_SPACE)
	var t := 0.0
	while study.flying and study.takeoff != null and t < 10.0:
		study.fly_step(DT,{})
		t += DT
	check(study.flying and study.takeoff == null and study.hand_landing.flying(),"Boarded again, it takes off (%.1f s)" % t)

## Walked off the isle over open sky: the canopy, stranded, back by the plane.
func _off_the_edge() -> void:
	# Out in the air (R's way): the plane goes back to its home.
	study.leave_plane()
	check(study.parked and not study.flying,"Out in the air, the plane is parked at its home")
	var circle: Vector3 = study.isle_circle()
	var out := Vector3(circle.x,study.isle_top()+2.0,circle.y)+Vector3(circle.z+60.0,0.0,0.0)
	study.place(out,Vector2(1.0,0.0))
	study._last_stood = out
	var dived := false
	var opened := false
	var stranded := false
	var t := 0.0
	while t < 20.0:
		study.tick(DT)
		t += DT
		if study.diving:
			dived = true
			if study.dive.under_canopy(): opened = true
			if study._stranded_left >= 0.0: stranded = true
		elif dived: break
	check(dived,"Off the edge he drops into the dive")
	check(opened,"The canopy opens by itself")
	check(stranded,"Well under the edge, stranded")
	check(not study.diving and not study.flying,"Then on foot again (%.1f s)" % t)
	check(study.by_plane(),"Beside the parked plane")
