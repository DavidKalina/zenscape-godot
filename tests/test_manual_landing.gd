extends SceneTree
## The hand-flown landing (scripts/manual_landing.gd) and its study
## (studies/landing_study.tscn), headless:
##   - the touch's judge: slow, shallow, level is good; fast, steep, banked,
##     nose first or on rough ground is a bounce;
##   - a good touch settles, rolls out under the brakes and stops; stopped,
##     it stays stopped until Exit is asked (never out by itself); Exit in
##     the air or rolling is refused; once stopped it gets out;
##   - a hot touch and a steep one bounce back up into the air, never into
##     the ground; Boost on the roll lifts off again (a touch-and-go); rolled
##     off the land's edge it flies again;
##   - flaps slow the plane under SLOW; without them it flies as ever;
##   - in the study: the sharp bot lands and stops and the run is saved;
##     out of the plane, a hop is only a hop, walking off the edge opens the
##     canopy and never flies, the plane staying parked; stranded, the pilot
##     is brought back beside the plane, still on foot; Space by the plane
##     boards it and takes off, flying again.
##   godot --headless --path . --script tests/test_manual_landing.gd
const ManualLanding = preload("res://scripts/manual_landing.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const Course = preload("res://scripts/landing_course.gd")
const DT := 1.0/60.0
## A flat test field: ground at 0 over |x| < 30, -100 < z < 0; open air
## elsewhere.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

static func field_floor(p: Vector2) -> float:
	return 0.0 if absf(p.x) < 30.0 and p.y < 0.0 and p.y > -100.0 else NAN

static func field_ground(p: Vector3) -> Variant:
	return Vector2(0.0,-10.0) if not is_nan(field_floor(Vector2(p.x,p.z))) else null

## A plane flying north at `speed` m/s, `height` m over the field's start,
## nose at `pitch`, and the landing in charge of it.
func approach(speed: float, height: float, pitch: float, z := -5.0) -> ManualLanding:
	var plane := SkyPlane.new()
	plane.launch(Vector3(0.0,SkyPlane.SKIM+height,z),0.0,speed,false)
	plane.speed = speed
	plane.pitch = pitch
	var ml := ManualLanding.new()
	ml.begin(plane)
	return ml

## Steps `ml` with `input` until `until` (a Callable(ml, out) -> bool) or
## `most` s; returns every event seen (merged) and the lowest the plane's
## wheels went under the land.
func fly(ml: ManualLanding, input: Dictionary, most: float, until := Callable()) -> Dictionary:
	var seen := {}
	var lowest := INF
	var t := 0.0
	while t < most:
		var out := ml.step(DT,input,field_ground,field_floor)
		seen.merge(out,true)
		var land := field_floor(Vector2(ml.plane.position.x,ml.plane.position.z))
		if not is_nan(land): lowest = minf(lowest,float(ml.plane.position.y)-land)
		t += DT
		if until.is_valid() and bool(until.call(ml,out)): break
	seen["_lowest"] = lowest
	seen["_t"] = t
	return seen

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("manual landing test timed out"); quit(2))
	_judge()
	_good_touch()
	_bounces()
	_touch_and_go()
	_edge()
	_flaps()
	var finished: bool = await _study()
	check(finished,"The study's checks ran to the end")
	print("PASS: manual landing" if failures == 0 else "FAIL: manual landing (%d)" % failures)
	quit(1 if failures else 0)

func _judge() -> void:
	check(ManualLanding.judge(8.0,0.8,0.05,-0.05,0.0) == "","Slow, shallow, level, on flat ground: a good touch")
	check(ManualLanding.judge(13.0,0.8,0.0,0.0,0.0) == "fast","Too fast: a bounce (fast)")
	check(ManualLanding.judge(8.0,3.0,0.0,-0.1,0.0) == "sink","Sinking too hard: a bounce (sink)")
	check(ManualLanding.judge(8.0,0.5,0.6,0.0,0.0) == "bank","A wing down: a bounce (bank)")
	check(ManualLanding.judge(8.0,0.5,0.0,0.0,0.0,true) == "bank","Mid barrel roll: a bounce (bank)")
	check(ManualLanding.judge(8.0,0.5,0.0,-0.6,0.0) == "nose","Nose first: a bounce (nose)")
	check(ManualLanding.judge(8.0,0.5,0.0,0.0,0.6) == "rough","Onto ground too steep: a bounce (rough)")

func _good_touch() -> void:
	# Slow and shallow, brakes on: touches, rolls, stops.
	var ml := approach(8.0,0.25,-0.1)
	var input := {"brake":1.0,"flaps":0.0}
	var seen := fly(ml,input,6.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	check(seen.has("touch") and str(seen.touch.result) == "good","A slow shallow touch is good (%.1f m/s, sink %.2f)" % [float(seen.get("touch",{}).get("speed",0)),float(seen.get("touch",{}).get("sink",0))])
	check(seen.has("settled") and not seen.has("bounce"),"It settles, no bounce")
	check(ml.phase == ManualLanding.STOPPED and seen.has("stopped"),"It rolls out under the brakes and stops (%.1f s)" % float(seen._t))
	check(float(ml.stats.rollout) > 1.0 and float(ml.stats.rollout) < 14.0,"The rollout is measured (%.1f m)" % float(ml.stats.rollout))
	check(float(seen._lowest) > 0.2,"The wheels never go into the ground (lowest %.2f m)" % float(seen._lowest))
	# Exit while rolling was refused: try again from a fresh roll.
	var ml2 := approach(8.0,0.25,-0.1)
	fly(ml2,{},3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.ROLL)
	var refused := ml2.step(DT,{"exit":true},field_ground,field_floor)
	check(refused.has("not_yet") and ml2.phase == ManualLanding.ROLL,"Exit while rolling is refused: stop first")
	var ml3 := approach(10.0,8.0,0.0)
	var refused_air := ml3.step(DT,{"exit":true},field_ground,field_floor)
	check(refused_air.has("not_yet") and ml3.flying(),"Exit in the air is refused")
	# Stopped, it waits: never out by itself.
	fly(ml,{"brake":0.0},5.0)
	check(ml.phase == ManualLanding.STOPPED and ml.can_exit(),"Stopped, it stays stopped and waits for Exit (5 s)")
	var out := fly(ml,{"exit":true},0.05)
	check(ml.phase == ManualLanding.EXIT,"Exit asked once stopped: getting out")
	out = fly(ml,{},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.done())
	check(ml.done() and out.has("out") and is_equal_approx(ml.hop,1.0) and ml.engine == 0.0,"The engine spins down and the pilot is out")
	check(int(ml.stats.early_exits) == 0,"The early exits are counted per landing (none on this one)")

func _bounces() -> void:
	# Hot: at cruise, low over the field.
	var ml := approach(14.0,0.2,-0.1)
	var seen := fly(ml,{},0.6,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("bounce"))
	check(seen.has("bounce") and str(seen.bounce.reason) == "fast","A touch at cruise bounces (fast)")
	var y0: float = ml.plane.position.y
	var up := fly(ml,{},0.6)
	check(ml.flying() and float(ml.plane.position.y) > y0+0.3,"The bounce throws it back up into the air (%.2f m up)" % (float(ml.plane.position.y)-y0))
	check(float(up._lowest) > 0.2,"Never into the ground after the bounce")
	check(int(ml.stats.bounces) == 1,"One bounce counted")
	# Steep: diving at the ground slow.
	var steep := approach(8.0,3.0,-0.6)
	var hit := fly(steep,{"brake":1.0,"pitch":-0.3},2.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("touch"))
	check(hit.has("bounce") and str(hit.bounce.reason) in ["sink","nose","fast"],"A steep dive onto the field bounces (%s, sink %.1f)" % [str(hit.get("bounce",{}).get("reason","none")),float(hit.get("touch",{}).get("sink",0.0))])
	check(steep.flying(),"And it is flying, not crashed")
	# Bounced, then flown level, it can come down good and stop.
	var again := fly(steep,{"brake":1.0,"flaps":1.0},14.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	check(steep.phase == ManualLanding.STOPPED and again.has("settled"),"After the bounce it settles and stops (%.1f s)" % float(again._t))

func _touch_and_go() -> void:
	var ml := approach(9.0,0.25,-0.1)
	fly(ml,{},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.ROLL)
	var seen := fly(ml,{"boost":1.0},5.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("lifted"))
	check(seen.has("lifted") and ml.flying(),"Boost on the roll lifts it off again (a touch-and-go)")
	var climb := fly(ml,{"boost":1.0},1.5)
	check(float(ml.plane.position.y) > SkyPlane.SKIM+0.5 and not climb.has("touch"),"And it climbs away, the wheels not counting a moment (%.1f m)" % float(ml.plane.position.y))

func _edge() -> void:
	# Touching near the field's far end with no brakes: off the edge.
	var ml := approach(9.0,0.25,-0.1,-93.0)
	var seen := fly(ml,{},4.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("off_edge"))
	check(seen.has("settled") and seen.has("off_edge") and ml.flying(),"Rolled off the edge it is flying again")
	check(int(ml.stats.off_edge) == 1,"Counted")

func _flaps() -> void:
	var plain := SkyPlane.new()
	plain.launch(Vector3(0.0,50.0,0.0),0.0,8.0,false)
	var down := SkyPlane.new()
	down.launch(Vector3(0.0,50.0,0.0),0.0,8.0,false)
	var none := func(_p: Vector3) -> Variant: return null
	for i in range(600):
		plain.step(DT,{"brake":1.0},none)
		down.step(DT,{"brake":1.0,"flaps":1.0},none)
	check(plain.speed >= SkyPlane.SLOW-0.01 and plain.speed < SkyPlane.BRAKE_SPEED+0.3,"Flaps up it brakes to its usual speed (%.1f m/s)" % plain.speed)
	check(down.speed < SkyPlane.SLOW and down.speed >= SkyPlane.FLAP_SLOW-0.01,"Flaps down it flies slower than SLOW (%.1f m/s)" % down.speed)

# --- The study -----------------------------------------------------------------------

func _study() -> bool:
	var study: Node3D = load("res://studies/landing_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://landing_runs_test"
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	check(study.find_children("Station_*","",false,false).size() == Course.STATIONS.size(),"Every station stands")
	var arrays := Course.pad_mesh(Course.STATIONS[0].pads[0]).surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(normals[0].y > 0.9,"A field's top faces up (%s)" % str(normals[0]))
	# The sharp bot lands the long field and stops.
	study.pilot = "sharp"
	study.start(Course.station("long_field"))
	var frames := 0
	while not study.run.done and frames < 60*60:
		study.tick(DT)
		frames += 1
	check(study.run.done and study.run.ended == "stopped","The sharp bot lands and stops (%.1f s)" % study.run.t)
	check(study._report.visible and FileAccess.file_exists(study.last_path),"The report is up and the run saved")
	# The bot gets out once stopped.
	frames = 0
	while study.mode == "plane" and frames < 60*5:
		study.tick(DT)
		frames += 1
	check(study.mode == "foot" and study.parked,"Out of the plane on foot, the plane parked")
	var parked_at: Vector3 = study.run.plane.position
	# Away from the plane (west, off its left side), a hop is only a hop.
	study._foot_yaw = PI*0.5
	for i in range(60): study.tick(DT,{"move":Vector2(0.0,1.0)})
	check(study.mode == "foot" and not study.by_plane(),"Walked away from the plane")
	study.tick(DT,{"jump":true,"move":Vector2.ZERO})
	var feet_y: float = study.feet.y
	for i in range(10): study.tick(DT,{})
	check(study.mode == "foot" and study.feet.y > feet_y,"Space away from the plane hops, it does not fly")
	for i in range(60): study.tick(DT,{})
	# On west, off the field's side.
	frames = 0
	while study.mode == "foot" and frames < 60*12:
		study.tick(DT,{"move":Vector2(0.0,1.0)})
		frames += 1
	check(study.mode == "canopy","Walked off the edge: the canopy, not a flight")
	check(study.parked and study.run.plane.position.distance_to(parked_at) < 0.01,"The plane stays parked where it was")
	frames = 0
	while study.mode == "canopy" and frames < 60*60:
		study.tick(DT,{})
		frames += 1
	check(study.mode == "stranded","Down off the plane's field: stranded (%s)" % study.mode)
	frames = 0
	while study.mode == "stranded" and frames < 60*10:
		study.tick(DT,{})
		frames += 1
	check(study.mode == "foot" and study.parked and study.by_plane(),"Stranded a while, then back on foot beside the parked plane")
	check(not study.run.ml.flying() or study.run.ml.on_ground() or study.run.ml.done(),"The plane did not fly off by itself")
	# Space by the plane boards it and takes off.
	study.tick(DT,{"jump":true})
	check(study.mode == "takeoff" and not study.parked,"Space by the plane: in, and the takeoff")
	frames = 0
	while study.mode == "takeoff" and frames < 60*15:
		study.tick(DT,{})
		frames += 1
	check(study.mode == "plane" and study.run.ml.flying(),"Flying again after the takeoff (%.1f s)" % (frames*DT))
	var land := Course.floor_at(Vector2(study.run.plane.position.x,study.run.plane.position.z))
	check(is_nan(land) or study.run.plane.position.y > land+1.5,"Off the ground and climbing")
	# Every station's sharp bot run stops.
	for s: Dictionary in Course.STATIONS:
		study.start(s)
		frames = 0
		while not study.run.done and frames < 60*120:
			study.tick(DT)
			frames += 1
		check(study.run.ended == "stopped","Sharp bot stops on %s (%.1f s, bounces %d)" % [s.id,study.run.t,int(study.run.ml.stats.bounces)])
	study.queue_free()
	return true
