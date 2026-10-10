extends SceneTree
## The aqueduct isle (studies/aqueduct_isle.tscn), headless: the ruins
## archipelago's aqueduct station dressed in the ruin kit keeps the routes
## proven on its greybox (tests/test_island_pack_ruins_archipelago.gd,
## station 2), driven end to end with scripted inputs; the lines round it
## (the castellum's summit, the stumps back from the far island) driven as
## a player would; the hill (its lower tier up the grand stair and both
## buttresses; the summit walked up the winding way with no jump, up the
## south floating stones, and up the drift of stones from the castellum's
## crown, which is also run down; out to both islets; the tilted stone
## circle's lintel ring up the leaning stone and the fallen trilithon, run
## round as a loop over the floating sarsen; the great trilithon's
## summit); the ground has no hole and every floating stone stands where
## it is drawn; the kit stair up the crag and the grand stair walk sound
## (no gap or pit in its
## treads or cheeks, never fallen through from any approach, walking,
## running or jumping, up or down) and smooth (the figure and the camera
## never pop a riser); the station's saved recordings replayed here; and
## the isle builds within its triangle budget.
##   godot --headless --path . --script tests/test_aqueduct_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Recording = preload("res://scripts/character_recording.gd")
const DT := 1.0/60.0
## The most triangles the isle may draw.
const BUDGET := 900000
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("aqueduct isle test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	check(study.stations.size() == 1 and study.start.distance_to(Vector3(100.0,30.0,9.0)) < 0.01,"Station 2 alone, started at the rubble slope's foot")
	_start_stands()
	_aqueduct_easy()
	_aqueduct_wallrun()
	_free_play()
	_hill()
	_ground_sound()
	_kit_stairs_sound()
	_stair_sound()
	_stair_smooth()
	_replays()
	print("PASS: aqueduct isle" if failures == 0 else "FAIL: aqueduct isle (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving (as tests/test_island_pack_ruins_archipelago.gd) -----------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func begin() -> void:
	study.respawn()
	for i in range(10): tick(Vector2.ZERO)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func walk(points: Array, pace := 1.0, frames := 1500) -> bool:
	var i := 0
	var holding := 0
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		var last := i == points.size()-1
		if off.length() < (0.4 if last else 0.6) and (not last or (m.grounded and not m.on_ledge())):
			i += 1
			if i >= points.size(): return true
			continue
		var way := off.normalized()
		var jump := false
		if m.grounded and holding == 0 and ahead(way) > m.feet.y+0.45: holding = 14
		if holding > 0:
			jump = true
			holding -= 1
		tick(way*pace,jump)
	return false

## Set down at the start, he stands on the turf at the station's height.
func _start_stands() -> void:
	begin()
	for i in range(30): tick(Vector2.ZERO)
	check(m.grounded and absf(m.feet.y-30.0) < 0.05,"Set down at the start he stands on the island (feet %s)" % m.feet)

# --- The station's routes -----------------------------------------------------------

## Easy: up the rubble slope onto the blind wall, along the channel
## (wading its water), a running jump twirled over the fallen span, on
## across the sky to the far island and down its rubble.
func _aqueduct_easy() -> void:
	begin()
	var ok := walk([Vector2(100.0,8.0),Vector2(100.0,-31.0)])
	var waded: bool = m.wade > 0.0
	check(ok and waded,"2 Aqueduct: up the rubble and along the channel, wading its water (feet %s, wade %.2f)" % [m.feet,m.wade])
	var way := Vector2(0.0,-1.0)
	var twirled := false
	for i in range(240):
		var jump: bool = m.feet.z < -32.1 and (m.grounded or m.velocity.y > 0.0) and not twirled
		var twirl: bool = not m.grounded and m.velocity.y < 0.0 and not twirled and m.feet.z < -32.0
		twirled = twirled or twirl
		tick(way,jump,false,twirl)
		if twirled and m.grounded: break
	ok = ok and twirled and m.grounded and m.feet.z < -35.5 and absf(m.feet.y-36.0) < 0.05
	check(ok,"2 Aqueduct: a twirled running jump over the 3 m fallen span (feet %s)" % m.feet)
	ok = ok and walk([Vector2(100.0,-44.0),Vector2(100.0,-58.0)])
	check(ok and absf(m.feet.y-30.0) < 0.05,"2 Aqueduct: on across the sky and down the rubble to the far island (feet %s)" % m.feet)

## Expert: a running jump along the blind wall's east face into a wall
## run, kicked off it to the buttress, then kicks between the two up to the
## channel's top.
func _aqueduct_wallrun() -> void:
	begin()
	var ok := walk([Vector2(103.5,8.0),Vector2(102.1,7.0)],0.4)
	for i in range(10): tick(Vector2.ZERO)
	var ran := false
	var kicks := 0
	var on := 0
	var side := Vector2(1.0,0.0)
	var was := ""
	for i in range(900):
		on = on+1 if m.move == "wall" else 0
		var want := Vector2(0.0,-1.0)
		var jump := false
		if m.feet.z < -0.6 and not ran and (m.grounded or m.velocity.y > 0.0): jump = true
		if m.feet.z < -0.4 and not ran: want = Vector2(-0.25,-1.0).normalized()
		if m.move == "wallrun":
			ran = true
			jump = m.feet.z < -5.5
		elif ran:
			want = side
			if m.move == "wall": jump = on >= 3
		if m.move == "kick" and was != "kick":
			kicks += 1
			if kicks > 1: side = -side
		was = m.move
		tick(want,jump)
		if ran and m.grounded: break
	ok = ok and ran and m.grounded and m.feet.y > 35.0
	check(ok,"2 Aqueduct: a wall run along the blind wall, kicked to the buttress and up between them to the top (%d kicks, feet %s)" % [kicks,m.feet])

# --- The playground round it ------------------------------------------------------

## The lines a player finds round the station, each driven from a standing
## start as a player would (`line`): the castellum's summit three ways, the
## stumps back from the far island, the cloister's wall tops, the broken
## piers' heads.
func _free_play() -> void:
	var ok := climb(Vector3(95.8,30.0,6.5),[Vector2(95.9,4.0),Vector2(95.9,2.0),Vector2(95.9,0.0),Vector2(96.0,-2.0),Vector2(94.0,-2.0)])
	check(ok and absf(m.feet.y-37.8) < 0.05,"Summit: up the castellum's fallen quarter, 1.6 m a step, to its crown at 7.8 m (feet %s)" % m.feet)
	check(line(Vector3(100.6,36.0,-2.6),Vector3(96.0,36.2,-2.6),"jump"),"Summit: from the channel a running jump to the castellum's 6.2 m step (feet %s)" % m.feet)
	check(line(Vector3(96.7,36.2,-2.0),Vector3(94.0,37.8,-2.0),"walk"),"Summit: and up onto the crown (feet %s)" % m.feet)
	check(line(Vector3(93.3,37.8,-2.0),Vector3(100.0,36.0,-2.4),"jump_twirl"),"Summit: off the crown a twirled jump down onto the channel (feet %s)" % m.feet)
	check(line(Vector3(95.2,36.2,-2.0),Vector3(100.0,36.0,-2.6),"jump"),"Summit: from the 6.2 m step a running jump back to the channel (feet %s)" % m.feet)
	check(line(Vector3(98.0,30.0,-2.6),Vector3(99.5,-35.0,-2.6),"kick"),"Kicks up the slot between the castellum and the blind wall to the channel (feet %s)" % m.feet)
	var back := line(Vector3(92.0,30.0,-44.5),Vector3(92.0,30.2,-37.2),"jump_twirl")
	back = back and line(m.feet,Vector3(92.0,29.8,-31.6),"jump_twirl")
	back = back and line(m.feet,Vector3(92.0,30.4,-27.7),"jump")
	back = back and line(m.feet,Vector3(92.0,30.0,-21.0),"jump")
	check(back,"Stumps: back from the far island over three broken piers, two twirled and two running jumps (feet %s)" % m.feet)

# --- The hill: the way up, the floating stones, the stone circle ----------------------------

## A point of the stone circle's (its frame) in the world.
func on_circle(p: Vector3) -> Vector3:
	return study.circle.transform*p

## The middle of the ring's lintel `k`'s top in the world, and whether it stands.
func lintel(k: int) -> Array:
	var l: Array = (study.circle.get_meta("ring").lintels as Array)[k]
	return [on_circle(l[0]),l[1]]

## Over the middle of the ring's sarsen `j` (where two lintels meet), at
## the lintels' top, in the world.
func joint(j: int) -> Vector3:
	var a := (j%RuinKit.CIRCLE_STONES+0.5)*TAU/RuinKit.CIRCLE_STONES
	return on_circle(Vector3(sin(a)*RuinKit.CIRCLE_RADIUS,RuinKit.SARSEN.y+RuinKit.LINTEL.y,cos(a)*RuinKit.CIRCLE_RADIUS))

## On the summit at angle `t` (degrees), `r` from the hill's middle.
func on_summit(t: float, r: float) -> Vector3:
	var p: Vector2 = Art.at_polar(t,r)
	return Vector3(p.x,Art.summit(p.x,p.y),p.y)

## The floating stone `name`'s top middle.
func stone(name: String) -> Vector3:
	return Art.platform(name).at

## From stone `a`'s far side (a run-up on it) a jump to `b`'s top (a
## stone's name or a point).
func hop(a: Vector3, b: Vector3, tech := "jump") -> bool:
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	return line(a-Vector3(way.x,0.0,way.y)*0.7,b,tech)

## Walked up the hill from the grand stair's foot to the summit through
## the way's points, the stick only, never a jump: true there, standing on
## the summit; `fell` the frames he was in the air over 0.25 s at a time.
func walk_up(points: Array) -> Dictionary:
	study.place(Vector3(points[0].x,30.0,points[0].y),(points[1]-points[0]).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 1
	var air := 0
	var fell := 0
	var lowest := INF
	for f in range(5000):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < (0.5 if i == points.size()-1 else 1.0):
			i += 1
			if i >= points.size(): break
			continue
		tick(off.normalized())
		air = 0 if m.grounded else air+1
		if air == 15: fell += 1
		if m.on_ledge(): fell += 1
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"reached":i}

## The hill's landmarks, each reached more than one way, as a player
## would: the lower tier up the grand stair and a buttress's set-offs; the
## summit walked up the winding way (no jump), up the south stones, and up
## the drift from the castellum's crown; the drift run down; the islets;
## the circle's lintel ring up the leaning stone and the fallen trilithon,
## run round as a loop over the floating sarsen; the great trilithon.
func _hill() -> void:
	var t1: float = 30.0+Art.T1
	var foot: Vector3 = study.stair.transform*(study.stair.get_meta("foot") as Vector3)
	var head: Vector3 = study.stair.transform*(study.stair.get_meta("head") as Vector3)
	var ok := line(foot+Vector3(1.5,0.0,0.0),Vector3(head.x-2.0,t1,head.z),"walk")
	check(ok,"Hill: up the grand stair, both flights, onto the lower tier at %.2f m (feet %s)" % [t1,m.feet])
	for side: float in [-1.0,1.0]:
		var z: float = side*8.41
		ok = climb(Vector3(81.8,30.0,z),[Vector2(79.5,z),Vector2(78.4,z),Vector2(76.0,z)])
		check(ok and absf(m.feet.y-t1) < 0.1,"Hill: up the %s buttress's set-offs onto the lower tier (feet %s)" % ["north" if side < 0.0 else "south",m.feet])
	# The winding way, walked.
	var way: Array = Art.way_up()
	var walked := walk_up(way)
	var end: Vector2 = way[way.size()-1]
	var top: float = Art.summit(end.x,end.y)
	check(walked.ok and walked.fell == 0 and absf(m.feet.y-top) < 0.15,"Way up: walked from the grand stair's foot round the hill, up the ramp, along the ledge and up the kit stair to the summit at %.2f m, no jump, never falling (%d of %d points, %d falls, feet %s)" % [top,walked.reached,way.size(),walked.fell,m.feet])
	# The south stones: up from the lower tier to the bite's lip.
	var p: Vector2 = Art.at_polar(338.0,14.2)
	ok = line(Vector3(p.x,t1,p.y),stone("south_1"),"jump")
	var stones := 0
	for k in range(2,5):
		if ok:
			stones += 1
			ok = hop(stone("south_%d" % (k-1)),stone("south_%d" % k))
	if ok: stones += 1
	var lip := on_summit(285.0,Art.edge_r(285.0)-1.3)
	ok = ok and hop(stone("south_4"),Vector3(lip.x,-(lip.y-0.1),lip.z))
	check(ok,"South stones: from the lower tier up %d floating stones, 1.35 m a jump caught, onto the summit at the bite (feet %s)" % [stones,m.feet])
	# The drift: down from the summit's north-east edge to the castellum's
	# crown, and back up.
	var from := on_summit(32.0,11.3)
	var down := line(from,stone("drift_1"),"jump")
	for k in range(2,7):
		down = down and hop(stone("drift_%d" % (k-1)),stone("drift_%d" % k))
	down = down and hop(stone("drift_6"),Vector3(94.3,37.8,-1.4))
	check(down,"Drift: down from the summit over six floating stones to the castellum's crown (feet %s)" % m.feet)
	var up := line(Vector3(94.6,37.8,-1.6),stone("drift_6"),"jump")
	for k in range(5,0,-1):
		up = up and hop(stone("drift_%d" % (k+1)),stone("drift_%d" % k))
	up = up and hop(stone("drift_1"),on_summit(30.0,11.0))
	check(up,"Drift: up from the castellum's crown over the six stones to the summit, a third way up (feet %s)" % m.feet)
	# The islets.
	var shelf: Vector2 = Art.at_polar(180.0,Art.r1(180.0)-1.6)
	ok = line(Vector3(shelf.x,30.0+Art.T2,0.5),stone("west_1"),"jump")
	ok = ok and hop(stone("west_1"),Vector3(Art.WEST_ISLET.x,Art.WEST_TOP,Art.WEST_ISLET.y))
	ok = ok and line(Vector3(Art.WEST_ISLET.x-1.0,Art.WEST_TOP,0.5),stone("west_1"),"jump")
	ok = ok and hop(stone("west_1"),Vector3(shelf.x,30.0+Art.T2,0.5))
	check(ok,"West islet: out from the west shelf over a floating stone and back (feet %s)" % m.feet)
	ok = line(Vector3(121.5,30.0,-6.3),stone("east_0"),"jump")
	ok = ok and hop(stone("east_0"),stone("east_1"))
	ok = ok and hop(stone("east_1"),Vector3(Art.EAST_ISLET.x-2.6,Art.EAST_TOP,Art.EAST_ISLET.y))
	check(ok,"East islet: off the meadow's east edge up a fallen stone and a floating one onto it (feet %s)" % m.feet)
	_circle()

## The stone circle on the crag: onto its lintels up the leaning stone and
## up the fallen trilithon; round them as a loop; the great trilithon.
func _circle() -> void:
	var ring: Dictionary = study.circle.get_meta("ring")
	var lean_foot := on_circle(ring.lean_foot)
	var lean_head := on_circle(ring.lean_head)
	var onto: Vector3 = lintel(RuinKit.LEAN_AT)[0]
	var ok := climb(lean_foot,[Vector2(lean_head.x,lean_head.z)]) and line(m.feet,onto,"jump")
	check(ok and absf(m.feet.y-onto.y) < 0.15,"Circle: up the leaning stone and a jump onto the lintels at %.2f m (feet %s)" % [onto.y,m.feet])
	var lying := on_circle(ring.lying)
	var stub := on_circle(ring.stub)
	onto = lintel(RuinKit.STUB_AT)[0]
	var toward := Vector2(lying.x-stub.x,lying.z-stub.z).normalized()
	var start := Vector2(lying.x,lying.z)+toward*3.4
	ok = climb(Vector3(start.x,Art.summit(start.x,start.y),start.y),[Vector2(lying.x,lying.z),Vector2(stub.x,stub.z)])
	var caught := -1
	if ok:
		for k: int in [RuinKit.STUB_AT,RuinKit.STUB_AT-1,RuinKit.STUB_AT+1]:
			var l: Vector3 = lintel(k)[0]
			var end := joint(k+1) if k < RuinKit.STUB_AT else (joint(k) if k > RuinKit.STUB_AT else l)
			if hop(stub,end.lerp(l,0.3)):
				caught = k
				break
	ok = ok and caught >= 0
	check(ok,"Circle: up the fallen trilithon, its lying stone then its stub, onto the lintels (lintel %d, feet %s)" % [caught,m.feet])
	_ring_loop()
	var back: Vector3 = lintel(RuinKit.CIRCLE_STONES/2-1)[0]
	var summit := on_circle(ring.trilithon)
	ok = line(back,summit,"jump")
	check(ok,"Circle: from the back lintel a jump up onto the great trilithon at %.2f m, the isle's summit (feet %s)" % [summit.y,m.feet])

## Round the lintel ring from the lintel over the leaning stone back to it:
## walked lintel to lintel, a twirled jump over each fallen one, and over
## the bite by the floating sarsen (a twirled jump onto it, one off).
func _ring_loop() -> void:
	var n := RuinKit.CIRCLE_STONES
	var ring: Dictionary = study.circle.get_meta("ring")
	var gone: Array = ring.gone
	var first := RuinKit.LEAN_AT
	var here: Vector3 = lintel(first)[0]
	study.place(here,Vector2(1.0,0.0))
	for i in range(30): tick(Vector2.ZERO)
	var ok := m.grounded and absf(m.feet.y-here.y) < 0.15
	var twirls := 0
	var floated := false
	var k := first
	var steps := 0
	var failed := ""
	while ok and steps < n:
		var next := (k+1)%n
		var l: Array = lintel(next)
		if l[1]:
			var mid: Vector3 = l[0]
			ok = climb(m.feet,[flat(joint(next)),flat(mid)]) and absf(m.feet.y-mid.y) < 0.15
			k = next
			steps += 1
		elif next in gone:
			# Over the bite: from this lintel's end onto the floating sarsen,
			# then onto the lintel past the gap.
			var after := (next+gone.size())%n
			var from := joint(k+1)+(joint(k)-joint(k+1)).normalized()*1.2
			var to := joint(after)+(joint(after+1)-joint(after)).normalized()*1.2
			var floating := stone("ring_sarsen")
			ok = climb(m.feet,[flat(from)]) and line(m.feet,floating,"jump_twirl")
			ok = ok and hop(floating,to,"jump_twirl")
			floated = ok
			twirls += 2
			k = after
			steps += 1+gone.size()
		else:
			var after := (next+1)%n
			var from := joint(k+1)+(joint(k)-joint(k+1)).normalized()*1.2
			var to := joint(k+2)+(joint(k+3)-joint(k+2)).normalized()*1.2
			ok = climb(m.feet,[flat(from)]) and line(m.feet,to,"jump_twirl")
			twirls += 1
			k = after
			steps += 2
		if not ok and failed == "": failed = " (stuck after lintel %d, feet %s)" % [k,m.feet]
	check(ok and k == first and floated,"Circle: round the tilted lintel ring as a loop, over %d fallen lintels and the bite by the floating sarsen, %d twirled jumps%s" % [(ring.fallen as Array).size(),twirls,failed])

## The ground has no hole: everywhere on the near island's top a ray from
## high above stands on the ground at least (or on what is built on it),
## and every floating stone's top is where it looks.
func _ground_sound() -> void:
	var holes := 0
	var probes := 0
	var first := ""
	var poly: PackedVector2Array = study.art.get_node("NearIsland").get_meta("outline")
	var x := 36.0
	while x < 128.0:
		var z := -27.0
		while z < 25.0:
			var p := Vector2(x,z)
			z += 0.37
			if not Geometry2D.is_point_in_polygon(p,poly) or Art._edge_distance(p,poly) < 0.6: continue
			var g: float = Art.ground(p.x,p.y)
			var steep := false
			for d: Vector2 in [Vector2(0.9,0.0),Vector2(-0.9,0.0),Vector2(0.0,0.9),Vector2(0.0,-0.9)]:
				if absf(Art.ground(p.x+d.x,p.y+d.y)-g) > 0.2: steep = true
			if steep: continue
			probes += 1
			var hit: float = study.ground._down(p,60.0)
			if hit < g-0.35:
				holes += 1
				print("     hole %s: %.2f under %.2f" % [p,hit,g])
				if first == "": first = " first at %s: %.2f under %.2f" % [p,hit,g]
		x += 0.37
	check(probes > 20000 and holes == 0,"Ground: no hole in the hill's tiers, ramp, summit or the meadow at %d probes (%d)%s" % [probes,holes,first])
	var off := 0
	for s: Dictionary in Art.platforms():
		var size: Vector3 = s.size
		var basis := Basis(Vector3.UP,float(s.yaw))
		for u: float in [-0.4,0.0,0.4]:
			for v: float in [-0.4,0.0,0.4]:
				var q: Vector3 = s.at+basis*Vector3(u*size.x,0.0,v*size.z)
				var hit_y: float = study.ground._down(Vector2(q.x,q.z),s.at.y+0.4)
				if absf(hit_y-s.at.y) > 0.03:
					off += 1
					print("     stone %s off at %s: %.3f vs %.3f" % [s.name,q,hit_y,s.at.y])
	check(off == 0,"Floating stones: every one stands where its top is drawn (%d of %d probes off)" % [off,Art.platforms().size()*9])

## The kit stair up the crag is sound: its treads' ground their tops (no
## gap a ray drops through), and driven onto from every side, up and down,
## walking and running, never under a tread nor off the hill.
func _kit_stairs_sound() -> void:
	var xf: Transform3D = study.kit_stairs.transform
	var inv := xf.affine_inverse()
	var front := Art.KIT_RUN*0.5
	var tread_at := func(l: Vector3) -> float:
		if absf(l.x) > RuinKit.STAIR_WIDTH*0.5-0.01: return NAN
		var d := front-l.z
		if d < 0.0 or d > Art.KIT_RUN: return NAN
		return (mini(int(d/RuinKit.TREAD),RuinKit.STEPS-1)+1)*RuinKit.RISER
	var base_y := xf.origin.y
	var off := 0
	var probes := 0
	var lx := -RuinKit.STAIR_WIDTH*0.5+0.1
	while lx <= RuinKit.STAIR_WIDTH*0.5-0.1:
		var lz := front-0.01
		while lz > -front+0.01:
			var t: float = tread_at.call(Vector3(lx,0.0,lz))
			var w := xf*Vector3(lx,0.0,lz)
			var g: float = study.ground.height_from(Vector2(w.x,w.z),base_y+t-0.2)-base_y
			probes += 1
			var lo: float = tread_at.call(Vector3(lx,0.0,lz+0.03))
			var hi: float = tread_at.call(Vector3(lx,0.0,lz-0.03))
			if g < (0.0 if is_nan(lo) else lo)-0.05 or g > (t if is_nan(hi) else hi)+0.05: off += 1
			lz -= 0.013
		lx += 0.05
	check(probes > 10000 and off == 0,"Kit stair: its treads' ground is their tops at all %d probes (%d off)" % [probes,off])
	var runs := 0
	var under := 0
	var lost := 0
	var first := ""
	var foot := xf*Vector3(0.0,0.0,front+1.2)
	var head := xf*Vector3(0.0,RuinKit.STEPS*RuinKit.RISER,-front-1.0)
	for pace: float in [0.5,1.0]:
		for slant: float in [-40.0,-20.0,0.0,20.0,40.0]:
			for across: float in [-0.6,0.0,0.6]:
				for going_up: bool in [true,false]:
					runs += 1
					var way3 := xf.basis*(Vector3(0.0,0.0,-1.0) if going_up else Vector3(0.0,0.0,1.0))
					var way := Vector2(way3.x,way3.z).normalized().rotated(deg_to_rad(slant))
					var side := xf.basis*Vector3(across,0.0,0.0)
					study.place((foot if going_up else head)+side,way)
					for i in range(20): tick(Vector2.ZERO)
					for f in range(240):
						tick(way*pace)
						var l: Vector3 = inv*m.feet
						if absf(l.z) > front+2.0 or absf(l.x) > 3.0: break
						var t: float = tread_at.call(l+Vector3(0.0,0.0,0.15))
						if not is_nan(t) and m.feet.y < base_y+t-0.25:
							under += 1
							if first == "": first = " first: pace %.1f slant %.0f across %.1f %s: feet %s" % [pace,slant,across,"up" if going_up else "down",m.feet]
							break
						if m.feet.y < 30.0+Art.T1-1.0:
							lost += 1
							break
	check(under == 0 and lost == 0,"Kit stair: driven on from %d approaches never under a tread nor off the ledge (%d under, %d lost)%s" % [runs,under,lost,first])

## Placed at `from` (dropped onto what is under it), runs at `to` (x, z;
## y the top wanted, or under 0 any stand at least -y high, within 1.8 m)
## by `tech`: "walk" (stepping up, climbing what he catches), "jump" (a
## running jump at the edge, held, a caught lip climbed), "jump_twirl" (and
## twirled as it falls), "kick" (wall kicks between two faces across x).
func line(from: Vector3, to: Vector3, tech: String) -> bool:
	var target := Vector2(to.x,to.z)
	study.place(from,(target-Vector2(from.x,from.z)).normalized())
	for i in range(90):
		tick(Vector2.ZERO)
		if m.grounded and i > 10: break
	var jumped := false
	var twirled := false
	var holding := 0
	var on := 0
	var kicks := 0
	var side := 1.0
	var was := ""
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
			"kick":
				on = on+1 if m.move == "wall" else 0
				jump = (m.grounded and i < 3) or (not m.grounded and m.move != "wall" and m.velocity.y > 0.0 and kicks == 0) or on >= 3
				if m.on_ledge(): jump = i%20 < 3
				way = Vector2(side,0.0)
				if m.move == "kick" and was != "kick":
					kicks += 1
					side = -side
				was = m.move
		jumped = jumped or (jump and tech != "walk")
		twirled = twirled or twirl
		tick(way,jump,false,twirl)
		if m.feet.y < 20.0: return false
		if m.grounded and not m.on_ledge():
			var high: bool = (m.feet.y >= -to.y-0.12) if to.y < 0.0 else absf(m.feet.y-to.y) < 0.12
			if high and off.length() < 1.8: return true
			if jumped and tech != "kick" and i > 30 and m.speed() < 0.2: return false
	return false

## Walks up through `points` from `from`, climbing what he catches; true
## stood at the last.
func climb(from: Vector3, points: Array) -> bool:
	study.place(from,(points[0]-Vector2(from.x,from.z)).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 0
	var holding := 0
	for f in range(1500):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < 0.5 and m.grounded and not m.on_ledge():
			i += 1
			if i >= points.size(): return true
			continue
		var way := off.normalized()
		var jump := false
		if m.grounded and holding == 0 and ahead(way) > m.feet.y+0.45: holding = 18
		if holding > 0:
			jump = holding > 4
			holding -= 1
		if m.on_ledge(): jump = f%20 < 3
		tick(way,jump)
	return false

## The station's saved route recordings (studies/character_runs/, F6 here)
## replay in the art scene to where they ended on the greybox.
func _replays() -> void:
	var runs: PackedStringArray = study._pack_runs()
	check(runs.size() >= 2,"The station's %d recordings are offered for F6" % runs.size())
	for path in runs:
		study.respawn()
		var ok: bool = study.begin_replay(Recording.read(path))
		while ok and study.replay_step(): pass
		var off := float(study.replay_verdict().off) if ok else INF
		study._replay = {}
		check(ok and off < 0.05,"Replayed here, %s ends %.3f m from where it was recorded to" % [path.get_file(),off])

# --- The grand stair: sound and smooth ------------------------------------------------

## The stair's frame point `l` in the world.
func on_stair(l: Vector3) -> Vector3:
	return study.stair.transform*l

## The tread's top under stair point `l` (its frame), NAN off the treads.
func tread(l: Vector3) -> float:
	var n := RuinKit.GRAND_STEPS
	var run1 := (n-1)*RuinKit.GRAND_TREAD+RuinKit.GRAND_LANDING
	var run2 := (n-1)*RuinKit.GRAND_TREAD+RuinKit.LANDING
	var front := (run1+run2)*0.5
	if absf(l.x) > RuinKit.GRAND_WIDTH*0.5-0.01: return NAN
	var d := front-l.z
	if d < 0.0 or d > run1+run2: return NAN
	if d < run1: return (mini(int(d/RuinKit.GRAND_TREAD),n-1)+1)*RuinKit.GRAND_RISER
	return (n+mini(int((d-run1)/RuinKit.GRAND_TREAD),n-1)+1)*RuinKit.GRAND_RISER

## Its ground is sound: probed every 13 mm along and 5 cm across (clear of
## the newels and copings over its edges), each tread's ground is its top
## (no joint, settled slab or worn nosing a ray drops through); along each
## cheek's top no pit opens to the ground. Then driven onto it from every
## side, up and down, walking and running, straight and slanting, jumping
## and not: never under a tread.
func _stair_sound() -> void:
	var off_top := 0
	var probes := 0
	var x := -RuinKit.GRAND_WIDTH*0.5+0.12
	while x <= RuinKit.GRAND_WIDTH*0.5-0.12:
		var z := 6.2
		while z >= -6.2:
			var t := tread(Vector3(x,0.0,z))
			if not is_nan(t):
				var w := on_stair(Vector3(x,0.0,z))
				var g: float = study.ground.height_from(Vector2(w.x,w.z),30.0+t-0.2)-30.0
				probes += 1
				# Right on a nosing, either tread's top.
				var low := tread(Vector3(x,0.0,z+0.03))
				var high := tread(Vector3(x,0.0,z-0.03))
				if g < (0.0 if is_nan(low) else low)-0.05 or g > (t if is_nan(high) else high)+0.05:
					off_top += 1
					if off_top < 6: print("     off: stair x %.3f z %.3f tread %.2f ground %.3f" % [x,z,t,g])
			z -= 0.013
		x += 0.05
	check(probes > 50000 and off_top == 0,"Stair: its treads' ground is their tops at all %d probes (%d off)" % [probes,off_top])
	var pits := 0
	for side: float in [-1.0,1.0]:
		var cx := side*(RuinKit.GRAND_WIDTH*0.5+RuinKit.CHEEK.x*0.5)
		var heights: Array[float] = []
		var z := 6.2
		while z >= -6.0:
			var w := on_stair(Vector3(cx,0.0,z))
			heights.append(study.ground.top_from(Vector2(w.x,w.z),30.0)-30.0)
			z -= 0.05
		for k in range(1,heights.size()-1):
			if heights[k] < 0.2 or heights[k] < minf(heights[k-1],heights[k+1])-0.3: pits += 1
	check(pits == 0,"Stair: along both cheeks' tops no pit opens to the ground (%d)" % pits)
	var foot: Vector3 = on_stair(study.stair.get_meta("foot"))
	var head: Vector3 = on_stair(study.stair.get_meta("head"))
	var inv: Transform3D = study.stair.transform.affine_inverse()
	var runs := 0
	var under := 0
	var lost := 0
	var first := ""
	for pace: float in [0.5,1.0]:
		for slant: float in [-50.0,-35.0,-20.0,-8.0,0.0,8.0,20.0,35.0,50.0]:
			for across: float in [-1.8,-0.9,0.0,0.9,1.8]:
				for up: bool in [true,false]:
					for jumping: bool in [false,true]:
						runs += 1
						var way := (Vector2(-1.0,0.0) if up else Vector2(1.0,0.0)).rotated(deg_to_rad(slant))
						study.place((foot+Vector3(2.0,0.0,across)) if up else (head+Vector3(-1.0,0.0,across)),way)
						for i in range(20): tick(Vector2.ZERO)
						for f in range(360):
							tick(way*pace,jumping and m.grounded and f%25 == 0)
							var l: Vector3 = inv*m.feet
							if absf(l.z) > 8.6 or absf(l.x) > 5.0: break
							# Its tread, a little back toward the foot (a nosing's
							# reach), the feet never more than a riser under.
							var t := tread(l+Vector3(0.0,0.0,0.15))
							if absf(l.x) < RuinKit.GRAND_WIDTH*0.5-0.01 and not is_nan(t) and m.feet.y < 30.0+t-0.25:
								under += 1
								if first == "": first = "pace %.1f slant %.0f across %.1f %s%s: feet %s at stair %s, tread %.2f" % [pace,slant,across,"up" if up else "down"," jumping" if jumping else "",m.feet,l,t]
								break
							if m.feet.y < 29.0:
								lost += 1
								break
	check(under == 0 and lost == 0,"Stair: driven on from %d approaches (9 slants, 5 lines, up and down, walking and running, jumping and not) never under a tread nor off the isle (%d under, %d lost)%s" % [runs,under,lost,"" if first == "" else " first: "+first])

## Up and down the grand stair, straight and slanting, walking and running:
## the figure and the camera rise and fall smoothly, never popping a
## riser (the feet do: they stand on each tread), and the figure stays
## within a half riser and a little of the feet.
func _stair_smooth() -> void:
	var foot: Vector3 = on_stair(study.stair.get_meta("foot"))
	var head: Vector3 = on_stair(study.stair.get_meta("head"))
	var inv: Transform3D = study.stair.transform.affine_inverse()
	var worst := {"feet":0.0,"figure":0.0,"camera":0.0,"distance":0.0,"off":0.0}
	for pace: float in [0.5,1.0]:
		for up: bool in [true,false]:
			for slant: float in [0.0,30.0]:
				var way := (Vector2(-1.0,0.0) if up else Vector2(1.0,0.0)).rotated(deg_to_rad(slant))
				study.place((foot+Vector3(2.0,0.0,0.0)) if up else (head+Vector3(-1.0,0.0,0.0)),way)
				for i in range(60): tick(Vector2.ZERO)
				var series := {"feet":[],"figure":[],"camera":[],"distance":[]}
				for f in range(400):
					tick(way*pace)
					var l: Vector3 = inv*m.feet
					if absf(l.z) > 9.0 or absf(l.x) > 2.0: break
					if absf(l.z) > 7.0: continue
					series.feet.append(m.feet.y)
					series.figure.append(study.figure.global_position.y)
					series.camera.append(study.camera.global_position.y)
					series.distance.append(study._cam_distance)
					worst.off = maxf(worst.off,absf(study.figure.global_position.y-m.feet.y))
				for key: String in series:
					var a: Array = series[key]
					for k in range(2,a.size()): worst[key] = maxf(worst[key],absf((a[k]-a[k-1])-(a[k-1]-a[k-2])))
	print("     stair, the most a frame's rise changes frame to frame (m): feet %.3f, figure %.4f, camera %.4f, camera's distance %.4f; figure off the feet at most %.3f m" % [worst.feet,worst.figure,worst.camera,worst.distance,worst.off])
	check(worst.feet > 0.15,"Stair: the feet stand each tread in turn (they pop %.2f m)" % worst.feet)
	check(worst.figure < 0.02 and worst.camera < 0.015 and worst.distance < 0.02,"Stair: the figure and the camera climb smoothly, never popping a riser (figure %.4f, camera %.4f, distance %.4f m a frame squared)" % [worst.figure,worst.camera,worst.distance])
	check(worst.off < RuinKit.GRAND_RISER*0.5+0.06,"Stair: the figure drawn within half a riser of the feet (%.3f m)" % worst.off)

