extends SceneTree
## The colonnade spine (studies/colonnade_spine_isle.tscn), headless: its
## ways driven as a player would, with scripted inputs (the aqueduct isle's
## test's helpers, tests/test_aqueduct_isle.gd):
## - the processional way, walked the length of the crest from the start
##   up every terrace's stair (no jump) through the temple gate to the
##   altar, over the cleft on the fallen lintel's balance beam;
## - the north shelf, walked from the tail's ridge up to the head's plaza
##   (no jump): a second easy way up, a loop with the way;
## - the cleft hopped on the drums wedged in it;
## - the lintels: up the drum and the stub onto the low terrace's lintels,
##   along them and over the cross lintel to the other row (a loop on the
##   lintels); onto a lower terrace's lintels from the terrace above;
##   along the plaza's north row from the podium;
## - the south slabs: up from the bench over the jutting shelves to the
##   crest;
## - the tail: off the ridge's tip over the stones, round the fragments,
##   over both rope bridges (the second back up to the bench: a loop);
## - the ground has no hole and the stones stand where drawn; the isle
##   builds within its triangle budget.
##   godot --headless --path . --script tests/test_colonnade_spine_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const DT := 1.0/60.0
const BUDGET := 900000
const T := Spine.TOP
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("colonnade spine test timed out"); quit(2))
	study = load("res://studies/colonnade_spine_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	if OS.has_environment("CS_ONLY"):
		call(OS.get_environment("CS_ONLY"))
		quit(1 if failures else 0)
		return
	_start_stands()
	_the_way()
	_north_shelf()
	_cleft_drums()
	_lintels()
	_south_slabs()
	_tail()
	_ground_sound()
	print("PASS: colonnade spine" if failures == 0 else "FAIL: colonnade spine (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving (the aqueduct isle test's) ----------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func at(x: float, d: float, h: float) -> Vector3:
	return Spine.at3(x,d,T+h)

## Walked through `points` (world x, z) from `from`, the stick only, never a
## jump: {ok, air (the longest time off the ground, s), lowest (feet y)}.
func walk(from: Vector3, points: Array, pace := 1.0, frames := 9000, near := 0.9) -> Dictionary:
	study.place(from,(points[0]-flat(from)).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 0
	var air := 0
	var most := 0
	var lowest := INF
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < (0.5 if i == points.size()-1 else near):
			i += 1
			if i >= points.size(): return {"ok":m.grounded,"air":most*DT,"lowest":lowest}
			continue
		tick(off.normalized()*pace)
		if OS.has_environment("CS_TRACE") and f%10 == 0: print("   walk f%d i%d feet %s d %.2f move %s" % [f,i,m.feet,m.feet.z-Spine.zc(m.feet.x),m.move])
		air = 0 if m.grounded else air+1
		most = maxi(most,air)
		lowest = minf(lowest,m.feet.y)
		if m.feet.y < T-20.0: break
	return {"ok":false,"air":most*DT,"lowest":lowest,"at":i}

func line(from: Vector3, to: Vector3, tech: String) -> bool:
	var target := Vector2(to.x,to.z)
	study.place(from,(target-Vector2(from.x,from.z)).normalized())
	for i in range(90):
		tick(Vector2.ZERO)
		if m.grounded and i > 10: break
	var jumped := false
	var twirled := false
	var holding := 0
	for i in range(900):
		var off := target-flat(m.feet)
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var jump := false
		var twirl := false
		match tech:
			"walk":
				if m.grounded and holding == 0 and ahead(way) > m.feet.y+0.45: holding = 14
				if holding > 0:
					jump = true
					holding -= 1
				if m.on_ledge(): jump = i%20 < 3
			"jump","jump_twirl":
				var edge: bool = m.grounded and ahead(way,0.35) < m.feet.y-0.45
				var wall: bool = m.grounded and ahead(way,0.6) > m.feet.y+0.45
				if not jumped and (edge or wall): jump = true
				jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
				twirl = tech == "jump_twirl" and jumped and not twirled and not m.grounded and m.velocity.y < 0.5
		jumped = jumped or (jump and tech != "walk")
		twirled = twirled or twirl
		tick(way,jump,false,twirl)
		if OS.has_environment("CS_TRACE") and i%6 == 0: print("   line i%d feet %s v %s move %s grounded %s jumped %s" % [i,m.feet,m.velocity,m.move,m.grounded,jumped])
		if m.feet.y < T-20.0: return false
		if m.grounded and not m.on_ledge():
			if absf(m.feet.y-to.y) < 0.15 and off.length() < 1.6: return true
			if jumped and i > 30 and m.speed() < 0.2: return false
	return false

## From `a` (backed off a run-up) a jump to `b`.
func hop(a: Vector3, b: Vector3, tech := "jump") -> bool:
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	return line(a-Vector3(way.x,0.0,way.y)*0.7,b,tech)

## Climbs through `points` (world: each stood on at its height) from
## `from`, jumping at what is ahead.
func climb(from: Vector3, points: Array) -> bool:
	study.place(from,(flat(points[0])-Vector2(from.x,from.z)).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 0
	var holding := 0
	for f in range(1500):
		var to: Vector2 = flat(points[i])
		var off: Vector2 = to-flat(m.feet)
		if off.length() < 0.5 and m.grounded and not m.on_ledge() and absf(m.feet.y-(points[i] as Vector3).y) < 0.2:
			i += 1
			if i >= points.size(): return true
			continue
		var way := off.normalized()
		var jump := false
		var higher := (points[i] as Vector3).y > m.feet.y+0.45
		var edge := ahead(way,0.4) < m.feet.y-0.45
		if m.grounded and holding == 0 and (maxf(ahead(way),ahead(way,1.1)) > m.feet.y+0.45 or (higher and edge)): holding = 18
		if holding > 0:
			jump = holding > 4
			holding -= 1
		if m.on_ledge(): jump = f%20 < 3
		tick(way,jump)
		if OS.has_environment("CS_TRACE") and f%10 == 0: print("   climb f%d i%d feet %s move %s ledge %s ahead %.2f" % [f,i,m.feet,m.move,m.on_ledge(),ahead(way)])
	return false

# --- The ways ------------------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	check(m.grounded and absf(m.feet.y-(T+Spine.L0)) < 0.05,"Set down at the start he stands on the way's low terrace (feet %s)" % m.feet)

## The processional way: from the start west the length of the crest, no
## jump: the cleft on its fallen lintel, the knife-edge, three stairs, the
## gate's door, the cella, to the altar.
func _the_way() -> void:
	var cb: Dictionary = study.colonnade.get_meta("cleft_beam")
	var pts: Array = [Spine.at(126.0,0.0),Spine.at(119.0,0.0),Spine.at(115.0,0.0),flat(cb.b as Vector3)+Vector2(0.6,0.0),flat(cb.a as Vector3)-Vector2(0.6,0.0),
		Spine.at(104.0,0.0),Spine.at(101.5,0.6),Spine.at(98.9,-0.2),Spine.at(96.5,-1.3),Spine.at(93.5,0.0),Spine.at(89.0,0.0),Spine.at(76.0,0.0),Spine.at(69.0,0.0),Spine.at(60.0,0.0),
		Spine.at(47.5,0.0),Spine.at(44.0,0.0),Spine.at(38.0,0.0),Spine.at(Spine.ALTAR_X+2.4,0.0)]
	var r := walk(study.start,pts)
	check(r.ok and absf(m.feet.y-(T+Spine.PODIUM)) < 0.1 and float(r.air) < 0.4,"The way: walked from the start the length of the crest, over the cleft's lintel, up three stairs and through the gate to the altar, no jump (feet %s, longest in the air %.2f s, %s)" % [m.feet,float(r.air),r])

## The north shelf: from the tail's ridge down onto it, walked west and up
## to the head's plaza.
func _north_shelf() -> void:
	var pts: Array = []
	var x := 140.0
	while x >= 54.0:
		pts.append(flat(Spine.shelf_point(x)))
		x -= 4.0
	pts.append(Spine.at(51.0,-4.4))
	var r := walk(Spine.shelf_point(144.0),pts)
	check(r.ok and absf(m.feet.y-(T+Spine.L3)) < 0.1 and float(r.air) < 0.4,"North shelf: walked up from the tail's ridge to the head's plaza, no jump (feet %s, longest in the air %.2f s, %s)" % [m.feet,float(r.air),r])

## The cleft: down onto the first drum wedged in it, over to the second, up
## onto the far lip.
func _cleft_drums() -> void:
	var w: Array = study.colonnade.get_meta("wedged")
	var west := Spine.at3(Spine.CLEFT.x-Spine.CLEFT.y-0.3,0.6,0.0)
	west.y = Spine.ground(west.x,west.z)
	var east := Spine.at3(Spine.CLEFT.x+Spine.CLEFT.y+0.6,-0.6,0.0)
	east.y = Spine.ground(east.x,east.z)
	var ok := line(west,w[0],"jump")
	check(ok,"Cleft: a hop down from its west lip onto the first wedged drum (feet %s, drum %s)" % [m.feet,w[0]])
	ok = ok and hop(w[0],w[1])
	check(ok,"Cleft: over to the second drum (feet %s)" % m.feet)
	ok = ok and hop(w[1],east)
	check(ok,"Cleft: up onto the east lip (feet %s)" % m.feet)

## The lintels.
func _lintels() -> void:
	var stubs: Array = study.colonnade.get_meta("stubs")
	var drums: Array = study.colonnade.get_meta("drums")
	var top0 := T+Spine.L0+Spine.LINTEL_TOP
	# Up the drum and the stub onto the south row's lintel by the start.
	var stub: Vector3 = stubs[stubs.size()-2].at
	var drum: Vector3 = drums[drums.size()-2].at
	var ok := climb(Spine.at3(126.5,-1.0,T+Spine.L0),[drum,stub,Spine.at3(126.5,Spine.ROW,top0)])
	check(ok and absf(m.feet.y-top0) < 0.1,"Lintels: up the drum and the stub onto the low terrace's south lintels (feet %s)" % m.feet)
	# Along them west, over the cross lintel to the north row, along it to
	# the portal: a loop on the lintels.
	var r := walk(m.feet,[Spine.at(123.5,Spine.ROW),Spine.at(123.5,0.0),Spine.at(123.5,-Spine.ROW),Spine.at(118.6,-Spine.ROW)],0.5,9000,0.25)
	check(r.ok and absf(m.feet.y-top0) < 0.1,"Lintels: along the south row, over the cross lintel and along the north row to the portal (feet %s)" % m.feet)
	# From the L2 terrace's edge onto L1's north lintels (a catch), along.
	var from := Spine.at3(Spine.STEP_L2-0.4,-Spine.ROW,T+Spine.L2)
	ok = line(from,Spine.at3(92.6,-Spine.ROW,T+Spine.L1+Spine.LINTEL_TOP),"jump")
	r = walk(m.feet,[Spine.at(102.0,-Spine.ROW)],0.5) if ok else {"ok":false}
	check(ok and r.ok and absf(m.feet.y-(T+Spine.L1+Spine.LINTEL_TOP)) < 0.1,"Lintels: from the terrace above, a catch onto the next terrace's lintels and along them (feet %s)" % m.feet)
	# From the podium's edge down onto the plaza's north row, along it.
	from = Spine.at3(Spine.STEP_PODIUM-0.4,-Spine.ROW,T+Spine.PODIUM)
	ok = line(from,Spine.at3(49.0,-Spine.ROW,T+Spine.L3+Spine.LINTEL_TOP),"walk")
	r = walk(m.feet,[Spine.at(66.6,-Spine.ROW)],0.5) if ok else {"ok":false}
	check(ok and r.ok and absf(m.feet.y-(T+Spine.L3+Spine.LINTEL_TOP)) < 0.1,"Lintels: off the podium onto the plaza's north row and along it to the portal (feet %s)" % m.feet)

## The south slabs: the bench, the two jutting shelves, the crest.
func _south_slabs() -> void:
	var tops: Array = []
	for name: String in ["south_1","south_2","south_3"]:
		var s := Spine.slab(name)
		var p := Spine.slab_at(s)
		tops.append(Vector3(p.x,T+float(s[4]),p.y))
	var ok := line(Spine.bench_point(101.0),tops[0],"jump")
	check(ok,"South slabs: from the bench's west end a jump-catch onto the first jutting shelf (feet %s)" % m.feet)
	ok = ok and hop(tops[0],tops[1])
	ok = ok and hop(tops[1],tops[2])
	check(ok,"South slabs: up the second and the third (feet %s)" % m.feet)
	ok = ok and hop(tops[2],Spine.at3(92.6,2.0,T+Spine.L1))
	check(ok,"South slabs: up onto the crest (feet %s)" % m.feet)

## The tail: the stones and fragments round the curl, both rope bridges.
func _tail() -> void:
	var f := func(name: String) -> Vector3:
		var s := Spine.slab(name)
		var c := Spine.slab_at(s)
		return Vector3(c.x,T+float(s[4]),c.y)
	var ok := chain("tip",Spine.tail_tip(),f.call("frag_1"))
	check(ok,"Tail: off the ridge's tip over the stones onto the first fragment (feet %s)" % m.feet)
	ok = ok and chain("f12",f.call("frag_1"),f.call("frag_2"))
	check(ok,"Tail: over the stones to the second (feet %s)" % m.feet)
	var ends: Array = Spine.bridge_ends()
	var e0: Array = ends[0]
	var r := walk((e0[0] as Vector3)-((e0[1] as Vector3)-(e0[0] as Vector3)).normalized()*1.2,[flat(e0[0]),flat(e0[1]),flat(f.call("frag_3"))],0.6)
	check(r.ok and absf(m.feet.y-(T-0.8)) < 0.1,"Tail: walked over the first rope bridge to the third fragment (feet %s, lowest %.2f)" % [m.feet,float(r.lowest)])
	ok = chain("f34",f.call("frag_3"),f.call("frag_4"))
	ok = ok and chain("f45",f.call("frag_4"),f.call("frag_5"))
	check(ok,"Tail: over the stones round the curl to the last fragment (feet %s)" % m.feet)
	var e1: Array = ends[1]
	r = walk(f.call("frag_5"),[flat(e1[0]),flat(e1[1]),flat(Spine.bench_point(127.0))],0.6)
	check(r.ok and m.feet.y > T+1.0,"Tail: back up the second rope bridge to the south bench, a loop (feet %s)" % m.feet)

## Hopped from `from` over chain `name`'s stones to `to`.
func chain(name: String, from: Vector3, to: Vector3) -> bool:
	var points: Array = [from]
	for s: Dictionary in Spine.platforms():
		if s.chain == name: points.append(s.at)
	points.append(to)
	for i in range(points.size()-1):
		if not hop(points[i],points[i+1]):
			print("     %s: missed hop %d %s -> %s (feet %s)" % [name,i,points[i],points[i+1],m.feet])
			return false
	return true

# --- Sound ground --------------------------------------------------------------------

func _ground_sound() -> void:
	var holes := 0
	var probes := 0
	var first := ""
	var poly: PackedVector2Array = study.spine.get_meta("outline")
	var x := 10.0
	while x < 152.0:
		var z := -40.0
		while z < 15.0:
			var p := Vector2(x,z)
			z += 0.41
			if not Geometry2D.is_point_in_polygon(p,poly) or Art._edge_distance(p,poly) < 0.6: continue
			var g: float = Spine.ground(p.x,p.y)
			var steep := false
			for d: Vector2 in [Vector2(0.9,0.0),Vector2(-0.9,0.0),Vector2(0.0,0.9),Vector2(0.0,-0.9)]:
				if absf(Spine.ground(p.x+d.x,p.y+d.y)-g) > 0.2: steep = true
			if steep: continue
			probes += 1
			var hit: float = study.ground._down(p,g+1.0)
			if hit < g-0.35:
				holes += 1
				if first == "": first = " first at %s: %.2f under %.2f" % [p,hit,g]
		x += 0.41
	check(probes > 5000 and holes == 0,"Ground: no hole in the spine's flats at %d probes (%d)%s" % [probes,holes,first])
	var off := 0
	for s: Dictionary in Spine.platforms():
		var size: Vector3 = s.size
		var basis := Basis(Vector3.UP,float(s.yaw))
		for u: float in [-0.4,0.0,0.4]:
			for v: float in [-0.4,0.0,0.4]:
				var q: Vector3 = s.at+basis*Vector3(u*size.x,0.0,v*size.z)
				var hit_y: float = study.ground._down(Vector2(q.x,q.z),s.at.y+0.4)
				if absf(hit_y-s.at.y) > 0.03:
					off += 1
					print("     stone %s off at %s: %.3f vs %.3f" % [s.name,q,hit_y,s.at.y])
	check(off == 0,"Stepping stones: every one stands where its top is drawn (%d probes off)" % off)
