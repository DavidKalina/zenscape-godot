extends SceneTree
## The aqueduct isle (studies/aqueduct_isle.tscn), headless: the ruins
## archipelago's aqueduct station dressed in the ruin kit keeps the routes
## proven on its greybox (tests/test_island_pack_ruins_archipelago.gd,
## station 2), driven end to end with scripted inputs; the lines round it
## (the castellum's summit, the stumps back from the far island) driven as
## a player would; the henge (the terrace up the grand stair, the fallen
## corner and a buttress; the stone circle's lintel ring up the leaning
## stone and the fallen trilithon, run round as a loop; the great
## trilithon's summit); the station's saved recordings replayed here; and
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
	_henge()
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

# --- The henge: the grand stair, the terrace, the stone circle ---------------------------

## A point of the stone circle's (its frame) in the world.
func on_circle(p: Vector3) -> Vector3:
	return study.circle.transform*p

## The middle of the ring's lintel `k`'s top in the world, and whether it stands.
func lintel(k: int) -> Array:
	var l: Array = (study.circle.get_meta("ring").lintels as Array)[k]
	return [on_circle(l[0]),l[1]]

## Over the middle of the ring's sarsen `j` (where two lintels meet), in the world.
func joint(j: int) -> Vector3:
	var a := (j%RuinKit.CIRCLE_STONES+0.5)*TAU/RuinKit.CIRCLE_STONES
	return on_circle(Vector3(sin(a),0.0,cos(a))*RuinKit.CIRCLE_RADIUS)

## The henge's landmarks, each reached more than one way, as a player
## would: the terrace up the grand stair, up the fallen corner's heap and
## up a buttress's set-offs; the circle's lintel ring up the leaning stone
## and up the fallen trilithon (its lying partner, its stub), then run
## round as a loop (twirled over the fallen lintels); the great trilithon
## from the ring's back lintel.
func _henge() -> void:
	var terrace_y: float = 30.0+Art.TERRACE_TOP
	var foot: Vector3 = study.stair.transform*(study.stair.get_meta("foot") as Vector3)
	var head: Vector3 = study.stair.transform*(study.stair.get_meta("head") as Vector3)
	var ok := line(foot+Vector3(1.5,0.0,0.0),Vector3(head.x-2.0,terrace_y,head.z),"walk")
	check(ok,"Henge: up the grand stair, both flights, onto the terrace at %.2f m (feet %s)" % [terrace_y,m.feet])
	ok = climb(Vector3(65.0,30.0,-19.0),[Vector2(65.0,-15.6),Vector2(65.0,-13.6),Vector2(65.0,-10.5)])
	check(ok and absf(m.feet.y-terrace_y) < 0.1,"Henge: up the fallen corner's heap, 1.5 m a step, onto the terrace (feet %s)" % m.feet)
	var out := Vector2(cos(TAU/16.0*2.0),sin(TAU/16.0*2.0))
	var at := func(r: float) -> Vector2: return Art.HENGE+out*r
	ok = climb(Vector3(at.call(16.4).x,30.0,at.call(16.4).y),[at.call(14.2),at.call(13.0),at.call(10.8)])
	check(ok and absf(m.feet.y-terrace_y) < 0.1,"Henge: up a buttress's set-offs onto the terrace (feet %s)" % m.feet)
	var ring: Dictionary = study.circle.get_meta("ring")
	var ring_y: float = study.circle.transform.origin.y+float(ring.top)
	var lean_foot := on_circle(ring.lean_foot)
	var lean_head := on_circle(ring.lean_head)
	var onto: Vector3 = lintel(RuinKit.LEAN_AT)[0]
	ok = climb(lean_foot,[Vector2(lean_head.x,lean_head.z),Vector2(onto.x,onto.z)])
	check(ok and absf(m.feet.y-ring_y) < 0.12,"Circle: up the leaning stone and a jump onto the lintels at %.2f m (feet %s)" % [ring_y,m.feet])
	var lying := on_circle(ring.lying)
	var stub := on_circle(ring.stub)
	onto = lintel(RuinKit.STUB_AT)[0]
	var toward := Vector2(lying.x-stub.x,lying.z-stub.z).normalized()
	var start := Vector2(lying.x,lying.z)+toward*3.4
	ok = climb(Vector3(start.x,terrace_y,start.y),[Vector2(lying.x,lying.z),Vector2(stub.x,stub.z)])
	ok = ok and line(m.feet,onto,"jump")
	check(ok and absf(m.feet.y-ring_y) < 0.12,"Circle: up the fallen trilithon, its lying stone then its stub, onto the lintels (feet %s)" % m.feet)
	_ring_loop(ring_y)
	var back: Vector3 = lintel(RuinKit.CIRCLE_STONES/2-1)[0]
	var summit := on_circle(ring.trilithon)
	ok = line(back,summit,"jump")
	check(ok,"Circle: from the back lintel a jump up onto the great trilithon at %.2f m, the isle's summit (feet %s)" % [summit.y,m.feet])

## Round the lintel ring from the lintel over the leaning stone back to it:
## walked from lintel to lintel, a twirled jump over each fallen one.
func _ring_loop(ring_y: float) -> void:
	var n := RuinKit.CIRCLE_STONES
	var first := RuinKit.LEAN_AT
	var here: Vector3 = lintel(first)[0]
	study.place(here,Vector2(1.0,0.0))
	for i in range(30): tick(Vector2.ZERO)
	var ok := m.grounded and absf(m.feet.y-ring_y) < 0.12
	var twirls := 0
	var k := first
	var steps := 0
	while ok and steps < n:
		var next := (k+1)%n
		var l: Array = lintel(next)
		if l[1]:
			var mid: Vector3 = l[0]
			ok = climb(m.feet,[flat(joint(next)),flat(mid)]) and absf(m.feet.y-ring_y) < 0.12
			k = next
			steps += 1
		else:
			# Over the fallen lintel: from near the end of this one along the
			# fallen one's line to the start of the one after.
			var after := (next+1)%n
			var from := joint(k+1)+(joint(k)-joint(k+1)).normalized()*1.2
			var to := joint(k+2)+(joint(k+3)-joint(k+2)).normalized()*1.2
			from.y = ring_y
			to.y = ring_y
			ok = climb(m.feet,[flat(from)]) and line(m.feet,to,"jump_twirl")
			twirls += 1
			k = after
			steps += 2
	check(ok and k == first and twirls == (study.circle.get_meta("ring").fallen as Array).size(),"Circle: round the lintel ring as a loop, %d twirled jumps over fallen lintels (feet %s)" % [twirls,m.feet])

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
		if m.grounded and holding == 0 and ahead(way) > m.feet.y+0.45: holding = 14
		if holding > 0:
			jump = true
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
