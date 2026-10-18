extends SceneTree
## The Stair to the Clouds (studies/stair_clouds_isle.tscn), headless: the
## whole climb walked with the stick only, never a jump, from the lawn up the
## eight flights and across each landing to the summit and its gate; the
## terraces reached from their landings; the rope bridge crossed to the
## pinnacle; the foot tokens taken on the way; the plane's lines laid and
## clear; the lawn sound; the isle within its triangle budget.
##   godot --headless --path . --script tests/test_stair_clouds_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Stair = preload("res://studies/stair_clouds_isle_art.gd")
const DT := 1.0/60.0
const BUDGET := 450000
const T := Stair.TOP
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("stair clouds test timed out"); quit(2))
	study = load("res://studies/stair_clouds_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	check(study.stair.get_child_count() == 8,"Eight grand flights wind round the mesa")
	_the_climb()
	_terraces()
	_the_bridge()
	_life_and_sky()
	_lawn()
	print("PASS: stair to the clouds" if failures == 0 else "FAIL: stair to the clouds (%d)" % failures)
	quit(1 if failures else 0)

func tick(want: Vector2) -> void:
	study.script_want = want
	study.script_jump = false
	study.script_crouch = false
	study.script_twirl = false
	study.bridge._process(DT)
	study.tick(DT)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

## Walked through `points` (world x, z) from `from`, the stick only.
func walk(from: Vector3, points: Array, frames := 12000) -> Dictionary:
	study.place(from,(points[0]-flat(from)).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 0
	var highest := from.y
	for f in range(frames):
		var off: Vector2 = points[i]-flat(m.feet)
		if off.length() < (0.5 if i == points.size()-1 else 0.9):
			i += 1
			if i >= points.size(): return {"ok":m.grounded,"top":highest}
			continue
		tick(off.normalized())
		if OS.has_environment("SC_TRACE") and f%15 == 0: print("   walk f%d i%d feet %s grounded %s" % [f,i,m.feet,m.grounded])
		highest = maxf(highest,m.feet.y)
		if m.feet.y < T-20.0: break
	return {"ok":false,"top":highest,"at":i,"feet":m.feet}

func _the_climb() -> void:
	# Up each flight's middle, round each landing's inner side (where its
	# token stands, inside the pads' piers), to the summit and its gate.
	var points: Array = []
	for s in range(Stair.LEGS):
		points.append(Stair.side_at(s,-Stair.RUN*0.5-0.6,Stair.MID))
		points.append(Stair.side_at(s,Stair.RUN*0.5+0.9,Stair.MID))
		points.append(Stair.vertex_at(s+1,22.0))
	points.append(Stair.side_at(Stair.SIDES-1,-2.0,-6.0))
	points.append(Stair.side_at(Stair.SIDES-1,Stair.GATE_AT.x,Stair.GATE_AT.y))
	var from: Vector3 = study.start
	var r := walk(from,points)
	var feet: Vector3 = m.feet
	check(r.ok and absf(feet.y-(T+Stair.SUMMIT)) < 0.6,"The climb: lawn to the summit on foot, no jump (feet %s, reached %.1f of %.1f; %s)" % [str(feet),float(r.top)-T,Stair.SUMMIT,str(r.get("at",""))])

func _terraces() -> void:
	# From each even landing onto the terrace it is flush with.
	for spec: Array in [[2,2.0*Stair.STEP,13.0],[4,4.0*Stair.STEP,13.0],[6,6.0*Stair.STEP,13.0]]:
		var i: int = spec[0]
		var from := Stair.vertex_at(i,24.3)
		var to := O_dir(i,float(spec[2]))
		var r := walk(Vector3(from.x,T+float(spec[1])+0.3,from.y),[to])
		check(r.ok and absf(m.feet.y-(T+float(spec[1]))) < 0.6,"Landing %d walks onto its terrace (feet y %.2f over the lawn, want %.2f)" % [i,m.feet.y-T,float(spec[1])])

## A point inside the core `r` from O, turned a little off vertex i toward
## the terrace it hugs.
func O_dir(i: int, r: float) -> Vector2:
	return Stair.vertex_at(i,r,-0.4)

func _the_bridge() -> void:
	var ends := Stair.bridge_ends()
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var from := Vector3(a.x,a.y,a.z)-Vector3(Stair.normal_of(8).x,0.0,Stair.normal_of(8).y)*1.5
	var r := walk(from,[Stair.pinnacle_at()])
	check(r.ok and absf(m.feet.y-b.y) < 1.0,"The rope bridge: the summit's rim to the pinnacle on foot (feet %s, the pinnacle's top %.1f)" % [str(m.feet),b.y])

func _life_and_sky() -> void:
	var life: Node = study.get("life")
	check(life != null and life.birds != null and life.birds.flocks.size() >= 2,"Life: songbird flocks perched on the shrines (%d)" % (life.birds.flocks.size() if life != null and life.birds != null else -1))
	check(life != null and life.tokens.tokens.size() >= 6,"Life: %d on-foot tokens" % (life.tokens.tokens.size() if life != null else 0))
	var taken: Array = life.tokens.taken
	check(taken.has("gate") and taken.has("landing_5") and taken.has("pinnacle") and taken.size() >= 4,"Life: tokens taken on the climb: %s" % str(taken))
	var lines: Array = Stair.plane_tokens()
	check(lines.size() == 2 and (lines[0][3] as PackedVector3Array).size() >= 4 and (lines[1][3] as PackedVector3Array).size() >= 8,"Sky: the slot and the corkscrew are laid")
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.9
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	var blocked := 0
	for l: Array in lines:
		for p: Vector3 in l[3]:
			q.transform = Transform3D(Basis.IDENTITY,p)
			if not space.intersect_shape(q,1).is_empty():
				blocked += 1
				print("     blocked: %s %s" % [l[0],p])
	check(blocked == 0,"Sky: every plane token stands in open air, 0.9 m clear (%d not)" % blocked)

func _lawn() -> void:
	var holes := 0
	var probes := 0
	for gx in range(-9,10):
		for gz in range(-9,10):
			var p := Stair.side_at(Stair.SIDES-1,gx*1.1,Stair.LAWN_AT+gz*1.1)
			if p.distance_to(Stair.side_at(Stair.SIDES-1,0.0,Stair.LAWN_AT)) > Stair.LAWN_R-1.6 or Stair.locate(p)[2] < Stair.W+0.5: continue
			probes += 1
			var hit: float = study.ground._down(p,T+1.0)
			if hit == INF: continue   # the parked plane's
			if absf(hit-T) > 0.35:
				holes += 1
				print("     off at %s: %.2f" % [p,hit-T])
	check(probes > 100 and holes == 0,"Ground: the lawn is sound at %d probes (%d off)" % [probes,holes])
