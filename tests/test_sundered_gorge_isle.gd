extends SceneTree
## The Sundered gorge isle (studies/sundered_gorge_isle.tscn), headless: its
## routes driven as a player would (scripted inputs through the study's own
## pilot): over the broken bridge and its live rope bridge both ways, walking
## and running; the expert's crossing over the crown stones; the lower
## crossing as a loop both ways (down the kit's flights cut in the west wall,
## over the fragments caught in the gap, up the ramp on the east wall); the
## split pillar's chimney kicked up; the gate tower's fallen quarter climbed
## to its crown; both tors' ramps walked to their tops; the mist stone by
## the fall; the drop from the break onto the fallen crown, the lodestone
## picked up there and the plane boarded out of the gorge. Every on-foot
## token is taken along the way. The ground has no hole, every floating
## stone stands where it is drawn, the kit's flights walk sound from every
## approach, the pool is wadeable, and the isle builds within its budget.
##   godot --headless --path . --script tests/test_sundered_gorge_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const AqArt = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const GorgeSky = preload("res://studies/sundered_gorge_isle_sky.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const DT := 1.0/60.0
const BUDGET := 900000
const PLANT_BUDGET := 1300000
var failures := 0
var study: Node3D
var m: PilotMotor
## Below this he has fallen off a line (world y).
var floor_y := 20.0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("sundered gorge test timed out"); quit(2))
	study = load("res://studies/sundered_gorge_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	while study.life == null: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d static triangles (budget %d)" % [tris,BUDGET])
	var plants := int(study.flora.get_meta("triangles"))+int(study.life.undergrowth.get_meta("triangles"))
	check(plants < PLANT_BUDGET,"Its grass, flowers and undergrowth draw at most %d instanced triangles (budget %d)" % [plants,PLANT_BUDGET])
	_start_stands()
	_bridge()
	_crown_stones()
	_lower_loop()
	_chimney()
	_tower()
	_tors()
	_slump()
	_mist()
	_crown_drop()
	_plane_line()
	_ground_sound()
	_flights_sound()
	_pool()
	_tokens()
	print("PASS: sundered gorge isle" if failures == 0 else "FAIL: sundered gorge isle (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving (as tests/test_aqueduct_isle.gd) ----------------------------------------

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

func settle(at: Vector3, face: Vector2) -> void:
	study.place(at,face)
	for i in range(30):
		tick(Vector2.ZERO)
		if m.grounded and i > 8: break

## Walks through `points` (x, z) from where he stands, the stick only (a
## hop up anything over a step): {ok, fell (times in the air over 0.25 s),
## lowest}.
func walk(points: Array, pace := 1.0, frames := 4000) -> Dictionary:
	var i := 0
	var air := 0
	var fell := 0
	var lowest := INF
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < (0.45 if i == points.size()-1 else 0.8):
			i += 1
			if i >= points.size(): break
			continue
		tick(off.normalized()*pace)
		air = 0 if m.grounded else air+1
		if air == 15: fell += 1
		lowest = minf(lowest,m.feet.y)
		if m.feet.y < floor_y: break
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"lowest":lowest,"reached":i}

## Placed at `from`, runs at `to` (y the top wanted, or under 0 any stand at
## least -y high, within 1.8 m) by `tech`: "walk", "jump", "jump_twirl",
## "kick" (wall kicks across x) (as the aqueduct isle's test).
func line(from: Vector3, to: Vector3, tech: String, pace := 1.0) -> bool:
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
		tick(way*pace,jump,false,twirl)
		if m.feet.y < floor_y: return false
		if m.grounded and not m.on_ledge():
			var high: bool = (m.feet.y >= -to.y-0.12) if to.y < 0.0 else absf(m.feet.y-to.y) < 0.15
			if high and off.length() < 1.8: return true
			if jumped and tech != "kick" and i > 30 and m.speed() < 0.2: return false
	return false

## From `a`'s far side (a run-up on it) a jump to `b`.
func hop(a: Vector3, b: Vector3, tech := "jump") -> bool:
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	return line(a-Vector3(way.x,0.0,way.y)*0.7,b,tech)

## Walks up through `points` from `from`, climbing what he catches.
func climb(from: Vector3, points: Array) -> bool:
	settle(from,(points[0]-Vector2(from.x,from.z)).normalized())
	var i := 0
	var holding := 0
	for f in range(1800):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < 0.45 and m.grounded and not m.on_ledge():
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
		if m.feet.y < floor_y: return false
	return false

func stone(name: String) -> Vector3:
	return Gorge.platform(name).at

func frag_top(name: String) -> Vector3:
	var f: Array = Gorge.fragment(name)
	return Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)

func on_west(x: float, z: float) -> Vector3:
	return Vector3(x,Gorge.ground_w(x,z),z)

func on_east(x: float, z: float) -> Vector3:
	return Vector3(x,Gorge.ground_e(x,z),z)

# --- Routes -------------------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	check(m.grounded and absf(m.feet.y-Gorge.start().y) < 0.08,"Set down at the start he stands on the west half's road (feet %s)" % m.feet)

## Over the bridge: from the start through the gate, out along the west
## half-arch's deck, over the rope bridge and the east deck onto the east
## top; back the other way at a run; again slanting across the rope deck
## (its hand ropes keep him on it).
func _bridge() -> void:
	var ends: PackedVector3Array = Gorge.rope_ends()
	var over := [Vector2(72.0,-15.0),Vector2(80.0,-15.0),Vector2(ends[0].x,-15.0),Vector2(ends[1].x,-15.0),Vector2(97.0,-15.0),Vector2(101.5,-15.0)]
	study.respawn()
	for i in range(20): tick(Vector2.ZERO)
	var on_rope := 0
	var lowest_on_rope := INF
	var walked := walk(over,0.5)
	check(walked.ok and walked.fell == 0 and absf(m.feet.y-Gorge.E_TOP) < 0.12,"Bridge: walked from the start through the gate, along the west deck, over the rope bridge and the east deck onto the east top, never falling (%d of %d points, feet %s)" % [walked.reached,over.size(),m.feet])
	var back := over.duplicate()
	back.reverse()
	back.append(Vector2(64.0,-15.0))
	var ran := walk(back,1.0)
	check(ran.ok and ran.fell == 0 and absf(m.feet.y-Gorge.plane_w(64.0)) < 0.12,"Bridge: run back over it to the start (feet %s, lowest %.2f)" % [m.feet,ran.lowest])
	# Slanting across the rope deck: held between its hand ropes.
	settle(Vector3(ends[0].x-0.4,ends[0].y,-15.0),Vector2(1.0,0.0))
	var strayed := 0.0
	var off_deck := 0
	for f in range(400):
		var way := Vector2(1.0,0.55 if (f/60)%2 == 0 else -0.55).normalized()
		tick(way)
		var x := m.feet.x
		if x > ends[0].x+0.3 and x < ends[1].x-0.3:
			strayed = maxf(strayed,absf(m.feet.z+15.0))
			var deck: Dictionary = Footbridge.deck_at([study.rope_deck] as Array[Dictionary],flat(m.feet))
			if deck.is_empty() or m.feet.y < float(deck.y)-0.1: off_deck += 1
		if m.feet.x > ends[1].x+1.0: break
	check(off_deck == 0 and strayed < Footbridge.WIDTH*0.5 and m.feet.x > ends[1].x and m.grounded,"Bridge: zigzagging over the rope deck he is held between its hand ropes, never off it (strayed %.2f m from its middle, %d frames off, feet %s)" % [strayed,off_deck,m.feet])
	on_rope += 0
	lowest_on_rope = lowest_on_rope

## The expert's crossing: twirled jumps from the west deck's snapped end
## over the crown stones to the east deck's.
func _crown_stones() -> void:
	var w := Gorge.west_bridge_frame()*Vector3(Gorge.WEST_BREAK-0.45,Gorge.DECK_LIFT,1.1)
	var e := Gorge.east_bridge_frame()*Vector3(Gorge.EAST_BREAK-0.6,Gorge.DECK_LIFT,-1.1)
	var ok := line(w,stone("crown_1"),"jump_twirl")
	var got := 1 if ok else 0
	ok = ok and hop(stone("crown_1"),stone("crown_2"),"jump")
	if ok: got += 1
	ok = ok and hop(stone("crown_2"),e,"jump_twirl")
	check(ok,"Crown stones: from the west deck's end over both hanging crown stones to the east deck's, twirled jumps (%d stones, feet %s)" % [got,m.feet])

## The lower crossing as a loop: from the west top down the two kit flights
## to the lower ledge, over both fragments to the east landing, up the ramp
## to the east top; and back the other way.
func _lower_loop() -> void:
	var fa: Transform3D = Gorge.flight_frame(Gorge.FLIGHTS[1])
	var fb: Transform3D = Gorge.flight_frame(Gorge.FLIGHTS[0])
	var run := Gorge.KIT_RUN*0.5
	var a_head := fa*Vector3(0.0,0.0,-run-0.9)
	var a_foot := fa*Vector3(0.0,0.0,run+0.9)
	var b_head := fb*Vector3(0.0,0.0,-run-0.9)
	var b_foot := fb*Vector3(0.0,0.0,run+0.9)
	var lip := Gorge.lip_at(Gorge.WEST_LIP,-46.6)
	floor_y = 20.0
	settle(on_west(73.0,-27.4),Vector2(1.0,0.0))
	var down := walk([Vector2(a_head.x,-27.2),flat(a_head),flat(a_foot),flat(b_head),flat(b_foot),Vector2(lip+1.8,-46.6)],0.6)
	var l2 := Gorge.plane_w(lip+1.8)-2.0*Gorge.FLIGHT
	check(down.ok and down.fell == 0 and absf(m.feet.y-l2) < 0.25,"Lower loop: down the kit's two flights cut in the west wall to the lower ledge, no jump, never falling (feet %s, ledge %.2f)" % [m.feet,l2])
	var east_rim := Gorge.lip_at(Gorge.EAST_LIP,-46.6)-3.0
	var landing := Vector3(east_rim+1.4,Gorge.E_TOP-2.0*Gorge.FLIGHT,-47.4)
	var ok := line(Vector3(lip+2.4,l2,-46.8),frag_top("chain_1"),"jump")
	var n := 1 if ok else 0
	ok = ok and hop(frag_top("chain_1"),frag_top("chain_2"),"jump")
	if ok: n += 1
	ok = ok and hop(frag_top("chain_2"),landing,"jump")
	check(ok,"Lower loop: running jumps over the two fragments caught in the gap to the east landing (%d of 2, feet %s)" % [n,m.feet])
	var lip_e := Gorge.lip_at(Gorge.EAST_LIP,-37.0)
	var up := walk([Vector2(lip_e-1.5,-44.0),Vector2(Gorge.lip_at(Gorge.EAST_LIP,-30.0)-1.5,-30.0),Vector2(Gorge.lip_at(Gorge.EAST_LIP,-27.0)-1.2,-27.0),Vector2(100.5,-25.0)],0.6)
	check(up.ok and up.fell == 0 and absf(m.feet.y-Gorge.E_TOP) < 0.12,"Lower loop: up the ramp along the east wall onto the east top, no jump (feet %s)" % m.feet)
	# Back: down the ramp, over the fragments west, up the flights.
	var back := walk([Vector2(Gorge.lip_at(Gorge.EAST_LIP,-27.0)-1.2,-27.0),Vector2(Gorge.lip_at(Gorge.EAST_LIP,-30.0)-1.5,-30.0),Vector2(lip_e-1.5,-44.0),Vector2(east_rim+1.2,-47.0)],0.6)
	ok = back.ok and line(Vector3(east_rim+0.6,landing.y,-46.8),frag_top("chain_2"),"jump")
	ok = ok and hop(frag_top("chain_2"),frag_top("chain_1"),"jump")
	ok = ok and hop(frag_top("chain_1"),Vector3(lip+1.8,l2,-46.6),"jump")
	var climbed: bool = ok and walk([flat(b_foot),flat(b_head),flat(a_foot),flat(a_head),Vector2(a_head.x,-27.2),Vector2(73.0,-27.4)],0.6).ok
	check(climbed and absf(m.feet.y-Gorge.plane_w(73.0)) < 0.15,"Lower loop: back down the ramp, over the fragments west and up the flights to the west top (feet %s)" % m.feet)

## The split pillar on the east landing: wall kicks up its slot onto the
## inner slab, then onto the east top.
func _chimney() -> void:
	var ch: Array = Gorge.chimney()
	var slot := ((ch[0][1] as float)+(ch[1][0] as float))*0.5
	var z := (Gorge.CHIMNEY_Z.x+Gorge.CHIMNEY_Z.y)*0.5
	var ok := line(Vector3(slot,float(ch[2]),z),Vector3(slot+1.0,-(Gorge.E_TOP-0.2),z),"kick")
	var top := m.feet.y
	ok = ok and walk([Vector2(Gorge.lip_at(Gorge.EAST_LIP,z)+2.0,z)]).ok and absf(m.feet.y-Gorge.E_TOP) < 0.12
	check(ok,"Chimney: kicked up the split pillar's %.1f m slot from the east landing onto its inner slab (%.2f m) and off onto the east top (feet %s)" % [float(ch[1][0])-float(ch[0][1]),top,m.feet])

## The gate tower's fallen quarter: 1.6 m a step, each a jump caught, to
## its crown.
func _tower() -> void:
	var xf := Gorge.tower_frame()
	var pts: Array = []
	# Each step's point on its own top (the tower leans: a point at its foot
	# drifts off the step it means at height).
	for l: Vector3 in [Vector3(-3.4,1.6,1.5),Vector3(-1.8,3.2,1.6),Vector3(-0.3,4.8,1.6),Vector3(1.5,6.4,1.6),Vector3(1.5,8.0,-0.2),Vector3(-1.0,9.6,-1.6)]:
		var w := xf*l
		pts.append(Vector2(w.x,w.z))
	var from := xf*Vector3(-6.4,0.0,1.5)
	var ok := climb(Vector3(from.x,Gorge.ground_w(from.x,from.z),from.z),pts)
	var crown := (xf*Vector3(-1.0,9.6,-1.6)).y
	check(ok and absf(m.feet.y-crown) < 0.2,"Tower: up the gate tower's fallen quarter, five jumps caught, to its crown at %.2f m (feet %s)" % [crown,m.feet])

## Both tors walked up their ramps, no jump.
func _tors() -> void:
	settle(on_west(52.3,-4.5),Vector2(0.0,-1.0))
	var tp: Vector2 = Gorge.TOR_PIER+Vector2(-1.6,1.4)
	var w := walk([Vector2(52.2,-12.0),Vector2(52.2,-24.0),tp],0.6)
	var top := Gorge.ground_w(tp.x,tp.y)
	check(w.ok and w.fell == 0 and absf(m.feet.y-top) < 0.2,"Tors: up the west tor's ramp to its top by the broken pier at %.2f m (feet %s)" % [top,m.feet])
	settle(on_east(100.5,-32.0),Vector2(1.0,0.0))
	var e := walk([Vector2(108.0,-34.0),Vector2(117.0,-35.8),Vector2(122.5,-36.5)],0.6)
	check(e.ok and e.fell == 0 and absf(m.feet.y-(Gorge.E_TOP+float(Gorge.EAST_TOR[1]))) < 0.2,"Tors: up the east crag's ramp to its top (feet %s)" % m.feet)

## The east half's slumped terraces: walked down their ramp to the lowest,
## then back up both steps by jumps caught.
func _slump() -> void:
	var rx := (Gorge.SLUMP_RAMP.x+Gorge.SLUMP_RAMP.y)*0.5
	settle(on_east(rx,-6.0),Vector2(0.0,1.0))
	var down := walk([Vector2(rx,4.0),Vector2(rx,17.0)],0.6)
	check(down.ok and down.fell == 0 and absf(m.feet.y-(Gorge.E_TOP-2.0*Gorge.SLUMP)) < 0.15,"Slump: walked down the ramp through both slumped terraces, no jump (feet %s)" % m.feet)
	var x := 108.0
	var e := Gorge.slump_edges(x)
	var ok := climb(on_east(x,e.y+2.5),[Vector2(x,e.y-1.5),Vector2(x,e.x-1.5)])
	check(ok and absf(m.feet.y-Gorge.E_TOP) < 0.15,"Slump: back up both 1.6 m steps by jumps caught (feet %s)" % m.feet)

## The mist stone by the curtain, off the lower ledge's north end.
func _mist() -> void:
	var x := Gorge.lip_at(Gorge.WEST_LIP,-48.5)+1.6
	var ok := line(Vector3(x,Gorge.plane_w(x)-2.0*Gorge.FLIGHT,-48.2),stone("mist"),"jump")
	var back := ok and hop(stone("mist"),Vector3(x,Gorge.plane_w(x)-2.0*Gorge.FLIGHT,-47.8),"jump")
	check(ok and back,"Mist: from the lower ledge's north end onto the stone by the fall and back (feet %s)" % m.feet)

## Off the west deck's snapped end (beside the rope bridge) down onto the
## fallen crown deep in the gorge; the lodestone picked up there, the plane
## boarded out of the gorge (not in stone).
func _crown_drop() -> void:
	floor_y = 10.0
	var from := Gorge.west_bridge_frame()*Vector3(Gorge.WEST_BREAK-1.4,Gorge.DECK_LIFT,1.0)
	var top := frag_top("crown")
	var ok := line(from,Vector3(top.x+0.5,top.y,top.z+0.3),"jump")
	check(ok,"Crown: off the west deck's snapped end down onto the fallen crown at %.2f m (feet %s)" % [top.y,m.feet])
	var f: Array = Gorge.fragment("crown")
	var token := Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)+Gorge.CROWN_TOKEN*Vector3(1.0,0.0,1.0)
	var w := walk([flat(token)],0.4)
	var lode: Vector3 = study.lode_rest-Vector3.UP*study.LODE_HOVER
	var reach := walk([flat(lode)],0.3)
	for i in range(20): tick(Vector2.ZERO)
	var can: bool = study.can_pick()
	check(w.ok and reach.ok and can,"Crown: walked round the fallen crown to the lodestone, which can be picked up (feet %s, stone %s)" % [m.feet,study.lode_rest])
	study.board()
	var clear: bool = study.flying and not study._in_stone()
	for i in range(90): study.fly_step(DT,{"turn":0.0,"pitch":0.0,"look":Vector2.ZERO,"lean":0.0,"boost":0.0,"brake":0.0,"roll":0.0})
	check(clear and study.flying,"Crown: boarded there, the plane flies clear in the gorge (at %s, bumps %d)" % [study.plane.position,study.bumps])
	study.leave_plane(Gorge.start())
	study.respawn()
	floor_y = 20.0

## The plane's line: launched north of the gorge, flown south down it by a
## steering bot through the gorge line's token points (in at the north
## mouth, under the lower crossing, under the broken bridge, out past the
## spur), never bumping stone, each point passed within a token's reach.
func _plane_line() -> void:
	var points: Array = GorgeSky.GORGE_TOKENS[0][3]
	study.respawn()
	for i in range(10): tick(Vector2.ZERO)
	study.board()
	var first: Vector3 = points[0]
	study.plane.launch(Vector3(first.x,first.y+3.0,first.z-26.0),PI,SkyPlane.CRUISE_SPEED,false)
	study.plane.velocity = study.plane.forward()*float(study.plane.speed)
	study.bumps = 0
	var nearest: Array[float] = []
	for p in points: nearest.append(INF)
	var k := 0
	for f in range(60*25):
		var at: Vector3 = study.plane.position
		var goal: Vector3 = points[k]
		var to := goal-at
		var want := atan2(-to.x,-to.z)
		var turn := clampf(wrapf(want-float(study.plane.heading),-PI,PI)*-3.0,-1.0,1.0)
		var climb := clampf((goal.y-at.y)*0.35-study.plane.velocity.y*0.15,-1.0,1.0)
		study.fly_step(DT,{"turn":turn,"pitch":climb,"look":Vector2.ZERO,"lean":0.0,"boost":0.0,"brake":0.0,"roll":0.0})
		for i in range(points.size()): nearest[i] = minf(nearest[i],study.plane.position.distance_to(points[i]))
		if to.z < 0.0:
			k += 1
			if k >= points.size(): break
	var worst := 0.0
	for d in nearest: worst = maxf(worst,d)
	check(k >= points.size() and study.bumps == 0 and worst < Lines.PLANE_REACH+0.6,"Plane: down the gorge from the north mouth, under the lower crossing and the broken bridge, out south, through all %d of the gorge line's tokens (nearest misses %s m, %d bumps)" % [points.size(),str(nearest),study.bumps])
	study.leave_plane(Gorge.start())
	study.respawn()

# --- Soundness -------------------------------------------------------------------

## No hole in either half's ground (a ray from high above stands at least on
## the ground), every floating stone's top where it is drawn.
func _ground_sound() -> void:
	var holes := 0
	var probes := 0
	var first := ""
	for half: Node3D in [study.west_half,study.east_half]:
		var poly: PackedVector2Array = half.get_meta("outline")
		var fn: Callable = Gorge.ground_w if half == study.west_half else Gorge.ground_e
		var box := Rect2(poly[0],Vector2.ZERO)
		for p in poly: box = box.expand(p)
		var x := box.position.x
		while x < box.end.x:
			var z := box.position.y
			while z < box.end.y:
				var p := Vector2(x,z)
				z += 0.53
				if not Geometry2D.is_point_in_polygon(p,poly) or AqArt._edge_distance(p,poly) < 0.6: continue
				var g: float = fn.call(p.x,p.y)
				var steep := false
				for d: Vector2 in [Vector2(0.9,0.0),Vector2(-0.9,0.0),Vector2(0.0,0.9),Vector2(0.0,-0.9)]:
					if absf(float(fn.call(p.x+d.x,p.y+d.y))-g) > 0.25: steep = true
				if steep: continue
				probes += 1
				var hit: float = study.ground._down(p,80.0)
				if hit < g-0.35:
					holes += 1
					if first == "": first = " first at %s: %.2f under %.2f" % [p,hit,g]
			x += 0.53
	check(probes > 15000 and holes == 0,"Ground: no hole in either half's tops, ledges, ramp, tors or pool at %d probes (%d)%s" % [probes,holes,first])
	var off := 0
	for s: Dictionary in Gorge.platforms():
		var size: Vector3 = s.size
		var basis := Basis(Vector3.UP,float(s.yaw))
		for u: float in [-0.4,0.0,0.4]:
			for v: float in [-0.4,0.0,0.4]:
				var q: Vector3 = s.at+basis*Vector3(u*size.x,0.0,v*size.z)
				var hit_y: float = study.ground._down(Vector2(q.x,q.z),s.at.y+0.4)
				if absf(hit_y-s.at.y) > 0.03: off += 1
	check(off == 0,"Floating stones: every one stands where its top is drawn (%d of %d probes off)" % [off,Gorge.platforms().size()*9])

## The kit's flights down the west wall: their treads' ground is their tops,
## and driven onto from every side, up and down, walking and running, never
## under a tread nor off the ledges.
func _flights_sound() -> void:
	var front := Gorge.KIT_RUN*0.5
	var tread_at := func(l: Vector3) -> float:
		if absf(l.x) > RuinKit.STAIR_WIDTH*0.5-0.01: return NAN
		var d := front-l.z
		if d < 0.0 or d > Gorge.KIT_RUN: return NAN
		return (mini(int(d/RuinKit.TREAD),RuinKit.STEPS-1)+1)*RuinKit.RISER
	var off := 0
	var probes := 0
	var under := 0
	var lost := 0
	var runs := 0
	for flight: Node3D in study.flights:
		var xf: Transform3D = flight.transform
		var inv := xf.affine_inverse()
		var lx := -RuinKit.STAIR_WIDTH*0.5+0.12
		while lx <= RuinKit.STAIR_WIDTH*0.5-0.12:
			var lz := front-0.01
			while lz > -front+0.01:
				var t: float = tread_at.call(Vector3(lx,0.0,lz))
				var w := xf*Vector3(lx,t,lz)
				var g: float = study.ground.height_from(Vector2(w.x,w.z),w.y-0.2)
				probes += 1
				var lo: float = tread_at.call(Vector3(lx,0.0,lz+0.03))
				var hi: float = tread_at.call(Vector3(lx,0.0,lz-0.03))
				var low_y := (xf*Vector3(lx,0.0 if is_nan(lo) else lo,lz)).y
				var high_y := (xf*Vector3(lx,t if is_nan(hi) else hi,lz)).y
				if g < low_y-0.06 or g > high_y+0.06: off += 1
				lz -= 0.02
			lx += 0.08
		var foot := xf*Vector3(0.0,0.0,front+1.2)
		var head := xf*Vector3(0.0,RuinKit.STEPS*RuinKit.RISER,-front-1.0)
		var ledge_low := xf.origin.y-1.0
		for pace: float in [0.5,1.0]:
			for slant: float in [-15.0,0.0,15.0]:
				for across: float in [-0.5,0.0,0.5]:
					for going_up: bool in [true,false]:
						runs += 1
						var way3 := xf.basis*(Vector3(0.0,0.0,-1.0) if going_up else Vector3(0.0,0.0,1.0))
						var way := Vector2(way3.x,way3.z).normalized().rotated(deg_to_rad(slant))
						var side := xf.basis*Vector3(across,0.0,0.0)
						settle((foot if going_up else head)+side,way)
						for f in range(200):
							tick(way*pace)
							var l: Vector3 = inv*m.feet
							if absf(l.z) > front+1.6 or absf(l.x) > 2.6: break
							var t: float = tread_at.call(l+Vector3(0.0,0.0,0.15))
							if not is_nan(t) and l.y < t-0.25:
								under += 1
								break
							# Off the stair itself (not stepped off the narrow ledge
							# beside it into the gorge).
							if m.feet.y < ledge_low and absf(l.x) < RuinKit.STAIR_WIDTH*0.5:
								lost += 1
								break
							if m.feet.y < ledge_low: break
	check(probes > 4000 and off == 0,"Flights: both kit flights' treads' ground is their tops at all %d probes (%d off)" % [probes,off])
	check(under == 0 and lost == 0,"Flights: driven on from %d approaches never under a tread nor off the ledges (%d under, %d lost)" % [runs,under,lost])

## The pool: he wades its water by the lip where it spills.
func _pool() -> void:
	settle(on_west(Gorge.POOL.x-Gorge.POOL_R-2.0,Gorge.POOL.y),Vector2(1.0,0.0))
	var waded := 0.0
	for f in range(240):
		tick(Vector2(1.0,0.0)*0.5)
		waded = maxf(waded,m.wade)
		if m.feet.x > Gorge.POOL.x+1.0: break
	check(waded > 0.0,"Pool: walked into the spring pool, he wades (wade %.2f)" % waded)

## Every on-foot token was taken along the routes.
func _tokens() -> void:
	var tokens: Node = study.life.tokens
	var left: Array = []
	for t: Dictionary in tokens.tokens:
		if not tokens.taken.has(t.name): left.append(t.name)
	check(left.is_empty(),"Tokens: all %d on-foot tokens taken along the routes (left: %s)" % [tokens.tokens.size(),", ".join(left)])
