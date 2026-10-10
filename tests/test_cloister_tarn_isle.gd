extends SceneTree
## The cloister tarn (studies/cloister_tarn_isle.tscn), headless: the isle
## builds within its triangle budget and the pilot starts on the cloister
## walk; the ways round it, driven as a player would: the easy way onto the
## wall-walk (walked, no jump); the wall-walk round as a loop (over the
## water gate, across the west gap by a twirl between the stubs); the
## gap's heaps and the buttresses up onto it; the stepping stones and the
## lavabo's drums; wading and swimming the tarn; the crag walked up the
## ridge and the kit stair, and climbed by the north face's tiers; the
## leap over the north alley; each rope bridge walked across and back on
## its live deck; the floating stones' chains; the spill channel; no hole
## in the ground; every stone's walked top where it is drawn.
##   godot --headless --path . --script tests/test_cloister_tarn_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const DT := 1.0/60.0
## The most triangles the isle may draw (the aqueduct isle's cap).
const BUDGET := 900000
var failures := 0
var study: Node3D
var m: PilotMotor
var debug := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("cloister tarn test timed out"); quit(2))
	study = load("res://studies/cloister_tarn_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	_start_stands()
	_way_to_walk()
	_walk_loop()
	_gap_heaps()
	_buttress()
	_lavabo()
	_swim()
	_crag()
	_north_tiers()
	_bridges()
	_stones()
	_channel()
	_ground_sound()
	_platforms_true()
	_tokens()
	print("PASS: cloister tarn" if failures == 0 else "FAIL: cloister tarn (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving ---------------------------------------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func settle(at: Vector3, face: Vector2) -> void:
	study.place(at,face)
	for i in range(20): tick(Vector2.ZERO)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func top() -> float:
	return TarnArt.K+TarnArt.WALK

func feet() -> String:
	return "feet %s" % m.feet

## Walked through `points` (world x, z) with the stick only: {ok, fell
## (times in the air over 0.25 s, or hanging), reached}.
func walk_only(points: Array, frames := 6000) -> Dictionary:
	var i := 0
	var air := 0
	var fell := 0
	for f in range(frames):
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
		if m.feet.y < TarnArt.W-20.0: break
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"reached":i}

## Through `points`, jumping at what rises ahead and climbing what he
## catches (from where he stands, or set down at `from`).
func climb(points: Array, from := Vector3.INF) -> bool:
	if from != Vector3.INF: settle(from,(points[0]-Vector2(from.x,from.z)).normalized())
	var i := 0
	var holding := 0
	var stuck := 0
	var was := flat(m.feet)
	for f in range(2400):
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
		# Stuck at a rise: back off a step and go again.
		stuck = stuck+1 if m.grounded and flat(m.feet).distance_to(was) < 0.005 else 0
		was = flat(m.feet)
		if stuck > 60:
			# The rise ahead is out of the feet's rays' sight (a wall's top
			# over a step): back off a step and jump at it.
			for k in range(10): tick(-way)
			stuck = 0
			holding = 18
			continue
		tick(way,jump)
		if m.feet.y < TarnArt.W-20.0: return false
		if debug and f > 2300 and f%10 == 0: print("  climb stuck: %s move %s ledge %s v %s jump %s" % [m.feet,m.move,m.on_ledge(),m.velocity,jump])
	return false

## A jump from where he stands (or `from`) to `to` (a top's middle): run at
## it, jump at the edge (or the rise), hold it rising, twirl past the top
## if asked; true landed on it.
func leap(to: Vector3, tech := "jump", from := Vector3.INF, speed := 1.0) -> bool:
	var target := Vector2(to.x,to.z)
	if from != Vector3.INF: settle(from,(target-Vector2(from.x,from.z)).normalized())
	var jumped := false
	var twirled := false
	for i in range(600):
		var off := target-flat(m.feet)
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var edge: bool = m.grounded and ahead(way,0.35) < m.feet.y-0.45
		var wall: bool = m.grounded and ahead(way,0.6) > m.feet.y+0.45
		var close: bool = m.grounded and off.length() < 1.9 and (absf(to.y-m.feet.y) > 0.2 or ahead(way,0.6) < m.feet.y-0.25)
		var jump := tech != "drop" and not jumped and (edge or wall or close)
		if tech == "drop" and not m.grounded: jumped = true
		jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
		var twirl: bool = tech == "twirl" and jumped and not twirled and not m.grounded and m.velocity.y < 0.5
		jumped = jumped or jump
		twirled = twirled or twirl
		var pace := speed
		tick(way*(0.0 if off.length() < 0.2 and m.grounded else pace),jump,false,twirl)
		if m.feet.y < TarnArt.W-20.0: return false
		if jumped and m.grounded and not m.on_ledge() and absf(m.feet.y-to.y) < 0.12 and off.length() < 1.2: return true
	if debug: print("  leap to %s failed: %s grounded %s ledge %s move %s v %s" % [to,m.feet,m.grounded,m.on_ledge(),m.move,m.velocity])
	return false

# --- The routes ------------------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	check(m.grounded and absf(m.feet.y-TarnArt.K) < 0.05,"Start: he stands on the cloister walk (%s)" % feet())

## The easy way onto the wall-walk, walked, never a jump: up the south-east
## slope to the crest, along it to the south terrace, over the slab bridge.
func _way_to_walk() -> void:
	var way: Array = TarnArt.way_to_walk()
	settle(Vector3(way[0].x,TarnArt.K,way[0].y),Vector2(0.0,-1.0))
	var walked := walk_only(way)
	check(walked.ok and walked.fell == 0 and absf(m.feet.y-top()) < 0.1,"Walk: up the south-east slope, along the crest, over the terrace and the slab bridge onto the wall-walk at %.2f m, no jump (%d of %d points, %d falls, %s)" % [top(),walked.reached,way.size(),walked.fell,feet()])

## Round the wall-walk as a loop from the slab bridge: east along the south
## range, north over the water gate, west along the north range, south to
## the west gap; across it on the stubs (a twirl from one to the other), up
## onto the wall-walk past it, on round to the slab bridge.
func _walk_loop() -> void:
	var c := TarnArt.C
	var a := TarnArt.ARC
	settle(Vector3(c.x,top(),c.y+a),Vector2(1.0,0.0))
	var walked := walk_only([c+Vector2(a,a),c+Vector2(a,0.0),c+Vector2(a,-a),c+Vector2(-a,-a),c+Vector2(-a,-6.0)])
	check(walked.ok and walked.fell == 0 and absf(m.feet.y-top()) < 0.1,"Loop: round the wall-walk from the slab bridge over the water gate's raised walk to the west gap's north end, walked (%d falls, %s)" % [walked.fell,feet()])
	var heap_n := Vector3(c.x-a-0.05,TarnArt.K+3.0,c.y-3.95)
	var stub4 := Vector3(c.x-a,TarnArt.K+2.4,c.y-1.8)
	var stub3 := Vector3(c.x-a,TarnArt.K+3.0,c.y+1.8)
	var heap_s := Vector3(c.x-a-0.05,TarnArt.K+3.0,c.y+3.95)
	var ok := leap(heap_n,"drop")
	check(ok,"Loop: down off the north end onto the fallen chunk (%s)" % feet())
	ok = ok and leap(stub4,"jump",Vector3.INF,0.5)
	check(ok,"Loop: on down onto the lower stub (%s)" % feet())
	ok = ok and leap(stub3)
	check(ok,"Loop: a running jump from stub to stub over the gap's middle, 2.7 m and 0.6 m up (%s)" % feet())
	ok = ok and leap(heap_s,"jump",Vector3.INF,0.5)
	ok = ok and climb([c+Vector2(-a,6.5)])
	check(ok and absf(m.feet.y-top()) < 0.1,"Loop: onto the south chunk and up onto the wall-walk past the gap (%s)" % feet())
	walked = walk_only([c+Vector2(-a,a),c+Vector2(0.0,a)])
	check(ok and walked.ok and walked.fell == 0 and absf(m.feet.y-top()) < 0.1,"Loop: on round to the slab bridge, the loop closed (%s)" % feet())

## The gap's heaps from the alley floor: the block, the chunk, the
## wall-walk.
func _gap_heaps() -> void:
	var c := TarnArt.C
	var a := TarnArt.ARC
	for s: float in [1.0,-1.0]:
		var ok := climb([c+Vector2(-a-1.3,s*3.9),c+Vector2(-a-0.05,s*3.95),c+Vector2(-a,s*6.5)],Vector3(c.x-a-3.2,TarnArt.K,c.y+s*3.9))
		check(ok and absf(m.feet.y-top()) < 0.1,"Heap: up the %s heap at the gap from the alley onto the wall-walk (%s)" % ["south" if s > 0.0 else "north",feet()])

## The north range's buttresses from the garth: their set-offs, then the
## wall-walk.
func _buttress() -> void:
	var c := TarnArt.C
	for x: float in [-9.0,9.0]:
		var ok := climb([c+Vector2(x,-10.6),c+Vector2(x,-11.5),c+Vector2(x,-12.6)],Vector3(c.x+x,TarnArt.K,c.y-8.6))
		check(ok and absf(m.feet.y-top()) < 0.1,"Buttress: up the %s buttress's set-offs onto the north wall-walk (%s)" % ["west" if x < 0.0 else "east",feet()])

## Out over the tarn's stepping stones to the little isle, dry-shod; up the
## lavabo's fallen drums onto its top.
func _lavabo() -> void:
	var c := TarnArt.C
	settle(Vector3(c.x-8.4,TarnArt.K,c.y-8.8),Vector2(1.0,0.4).normalized())
	var ok := true
	var wet := false
	for k in range(3):
		ok = ok and leap(TarnArt.platform("tarn_%d" % (k+1)).at,"jump",Vector3.INF,0.6)
		wet = wet or m.wade > 0.0
	var isle := TarnArt.world(TarnArt.SHRINE)+Vector2(-2.0,-1.0)
	ok = ok and leap(Vector3(isle.x,TarnArt.SHRINE_TOP,isle.y))
	check(ok and not wet,"Lavabo: over the three stepping stones onto its isle, dry-shod (%s)" % feet())
	var l := TarnArt.world(TarnArt.SHRINE)
	ok = climb([l+Vector2(3.7,-1.2),l+Vector2(2.75,-1.2),l+Vector2(2.55,0.0),l+Vector2(0.4,0.0)],Vector3(l.x+3.6,TarnArt.SHRINE_TOP,l.y-2.4))
	check(ok and absf(m.feet.y-(TarnArt.SHRINE_TOP+TarnArt.WALK)) < 0.1,"Lavabo: up its fallen drums onto its top (%s)" % feet())

## Into the tarn from the south garth: he wades, then swims; across to the
## lavabo's isle and out onto it.
func _swim() -> void:
	var c := TarnArt.C
	settle(Vector3(c.x-2.0,TarnArt.K,c.y+11.6),Vector2(0.0,-1.0))
	var waded := false
	var swam := false
	for i in range(500):
		tick(Vector2(0.0,-1.0))
		waded = waded or m.wade > 0.0
		swam = swam or m.swimming
		if m.feet.z < c.y+3.0: break
	check(waded and swam,"Tarn: walked in from the garth he wades, then swims (wade %s, swim %s, %s)" % [waded,swam,feet()])
	var out := false
	for i in range(1200):
		var off := TarnArt.world(TarnArt.SHRINE)+Vector2(0.0,1.0)-flat(m.feet)
		tick(off.normalized(),i%30 < 2)
		if m.grounded and not m.swimming and m.feet.y > TarnArt.W+0.3:
			out = true
			break
	check(out,"Tarn: swum across to the lavabo's isle and out onto it (%s)" % feet())

## The crag, walked: out of the west door, over the saddle, up the ridge
## and the kit stair onto the summit.
func _crag() -> void:
	var way: Array = TarnArt.way_to_crag()
	settle(Vector3(way[0].x,TarnArt.K,way[0].y),Vector2(-1.0,0.0))
	var walked := walk_only(way)
	var want := TarnArt.K+TarnArt.CRAG_TOP
	check(walked.ok and walked.fell == 0 and absf(m.feet.y-want) < 0.15,"Crag: walked from the west door over the saddle, up the ridge and the kit stair onto the summit at %.2f m, no jump (%d of %d points, %d falls, %s)" % [want,walked.reached,way.size(),walked.fell,feet()])

## The north face's rock tiers from the alley, a jump-catch each, onto the
## crest; the leap across the alley from the wall-walk onto a tier.
func _north_tiers() -> void:
	var c := TarnArt.C
	var pts: Array = []
	var n := ceili((TarnArt.ground(c.x,c.y-22.6)-TarnArt.K)/TarnArt.TIER)
	var depth := (TarnArt.RIM-TarnArt.CREST_W-TarnArt.BACK)/n
	for k in range(n): pts.append(c+Vector2(0.0,-(TarnArt.BACK+depth*(k+0.5))))
	pts.append(c+Vector2(0.0,-22.6))
	var ok := climb(pts,Vector3(c.x,TarnArt.K,c.y-14.6))
	var crest: float = TarnArt.ground(c.x,c.y-22.6)
	check(ok and absf(m.feet.y-crest) < 0.15,"Tiers: up the north face's %d rock tiers from the alley, a jump-catch each, onto the crest at %.2f m (%s)" % [n,crest,feet()])

## Each rope bridge walked across from the mother's head to the
## satellite's and back, on its live deck all the way.
func _bridges() -> void:
	for b: Dictionary in TarnArt.bridges():
		var a: Vector3 = b.a
		var e: Vector3 = b.b
		var dir := Vector2(e.x-a.x,e.z-a.z).normalized()
		var span := Vector2(e.x-a.x,e.z-a.z).length()
		settle(a-Vector3(dir.x,0.0,dir.y)*0.9,dir)
		var lowest := INF
		var walked := walk_only([Vector2(e.x,e.z)+dir*1.2])
		var there: bool = walked.ok and walked.fell == 0 and absf(m.feet.y-e.y) < 0.15
		walked = walk_only([Vector2(a.x,a.z)-dir*1.2])
		var back: bool = walked.ok and walked.fell == 0 and absf(m.feet.y-a.y) < 0.15
		check(there and back and span > 6.0,"Bridge: %s, a %.1f m rope bridge, walked across and back on its deck, never falling (%s)" % [b.name,span,feet()])
		if b.name == "northeast_bridge":
			# A jump on the deck's middle: he lands back on it, the deck sags.
			walk_only([Vector2(a.x,a.z).lerp(Vector2(e.x,e.z),0.5)])
			var deck_y := m.feet.y
			var landed := false
			for i in range(120):
				tick(Vector2.ZERO,i < 14)
				if i > 20 and m.grounded:
					landed = true
					break
			for i in range(30): tick(Vector2.ZERO)
			var t := (flat(m.feet)-Vector2(a.x,a.z)).dot(dir)/span
			var straight := lerpf(a.y,e.y,clampf(t,0.0,1.0))
			check(landed and m.grounded and t > 0.1 and t < 0.9 and m.feet.y < straight-0.1 and deck_y < (a.y+e.y)*0.5-0.2,"Bridge: a jump on the north-east bridge's sagging middle (%.2f m, under its heads' line) lands back on its deck (%s)" % [deck_y,feet()])

## The floating stones: the west chain from the west isle down to the
## south-west isle; the north chain from the crag down to the north isle;
## on from it to the north-east isle.
func _stones() -> void:
	for chain: Array in [["west","west","southwest"],["north","","north"],["northeast","north","northeast"]]:
		var stones: Array = TarnArt.platforms().filter(func(p: Dictionary) -> bool: return p.chain == chain[0])
		var first: Vector3 = stones[0].at
		var from: Vector3
		if chain[1] == "":
			var s := TarnArt.world(TarnArt.way(126.0)*TarnArt.RIM/TarnArt.sq(TarnArt.way(126.0)))
			from = Vector3(s.x,TarnArt.K+TarnArt.CRAG_TOP,s.y)
		else:
			var sat: Array = TarnArt.satellite(chain[1])
			var mid := TarnArt.world(sat[1])
			var rim := mid+(Vector2(first.x,first.z)-mid).normalized()*(float(sat[2])-1.6)
			from = Vector3(rim.x,TarnArt.satellite_ground(sat,rim.x,rim.y),rim.y)
		settle(from,Vector2(first.x-from.x,first.z-from.z).normalized())
		var ok := true
		var n := 0
		for p: Dictionary in stones:
			ok = ok and leap(p.at)
			if ok: n += 1
		var sat2: Array = TarnArt.satellite(chain[2])
		var mid2 := TarnArt.world(sat2[1])
		var last: Vector3 = stones[-1].at
		var into := (mid2-Vector2(last.x,last.z)).normalized()
		var land := mid2-into*(float(sat2[2])-1.8)
		ok = ok and leap(Vector3(land.x,TarnArt.satellite_ground(sat2,land.x,land.y),land.y))
		check(ok,"Stones: the %s chain hopped, %d of %d stones, and onto the %s isle (%s)" % [chain[0],n,stones.size(),chain[2],feet()])

## The spill channel: its two stepping slabs cross it in the alley
## dry-shod; stepped down into it, he wades.
func _channel() -> void:
	var c := TarnArt.C
	var x0 := c.x+TarnArt.ARC+TarnArt.ARC_D
	settle(Vector3(x0+0.7,TarnArt.K,c.y+3.4),Vector2(0.0,-1.0))
	var ok := leap(TarnArt.platform("channel_1").at,"jump",Vector3.INF,0.5)
	ok = ok and leap(TarnArt.platform("channel_2").at,"jump",Vector3.INF,0.5)
	ok = ok and leap(Vector3(x0+2.1,TarnArt.K,c.y-3.4))
	check(ok and m.wade <= 0.0,"Channel: across the spill in the alley on its two slabs, dry-shod (%s)" % feet())
	settle(Vector3(x0+1.4,TarnArt.K,c.y+3.4),Vector2(0.0,-1.0))
	var waded := false
	for i in range(120):
		tick(Vector2(0.0,-1.0) if m.feet.z > c.y else Vector2.ZERO)
		waded = waded or (m.wade > 0.0 and not m.swimming)
	check(waded,"Channel: stepped down into the spill he wades it (%s)" % feet())

## No hole in the mother's ground: a ray down anywhere on it lands within
## 0.35 m of the ground's lowest close by (the cliffs' faces slant).
func _ground_sound() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	var outline := PackedVector2Array(TarnArt.outline())
	var probes := 0
	var holes := 0
	var worst := Vector3.ZERO
	var x := TarnArt.C.x-32.0+0.173
	while x < TarnArt.C.x+32.0:
		var z := TarnArt.C.y-32.0+0.291
		while z < TarnArt.C.y+32.0:
			var p := Vector2(x,z)
			z += 0.61
			if not Geometry2D.is_point_in_polygon(p,outline) or Art._edge_distance(p,outline) < 1.0: continue
			var low := INF
			for d: Vector2 in [Vector2.ZERO,Vector2(0.7,0.0),Vector2(-0.7,0.0),Vector2(0.0,0.7),Vector2(0.0,-0.7)]: low = minf(low,TarnArt.ground(p.x+d.x,p.y+d.y))
			ray.from = Vector3(p.x,TarnArt.W+30.0,p.y)
			ray.to = Vector3(p.x,TarnArt.W-20.0,p.y)
			var hit := space.intersect_ray(ray)
			probes += 1
			if hit.is_empty() or (hit.position as Vector3).y < low-0.35:
				holes += 1
				worst = Vector3(p.x,(hit.position as Vector3).y if not hit.is_empty() else -INF,p.y)
		x += 0.61
	check(holes == 0,"Ground: no hole in the mother's ground (%d probes, %d holes, e.g. %s)" % [probes,holes,worst])

## Every stepping and floating stone's walked top stands where it is drawn.
func _platforms_true() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var off := 0
	for p: Dictionary in TarnArt.platforms():
		var a: Vector3 = p.at
		ray.from = a+Vector3.UP*2.0
		ray.to = a+Vector3.DOWN*2.0
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf((hit.position as Vector3).y-a.y) > 0.03: off += 1
	check(off == 0,"Stones: every stone's walked top is where it is drawn (%d of %d off)" % [off,TarnArt.platforms().size()])


## The on-foot tokens the routes above took on their way (each stands where
## a move takes it; the ones no route here passes stay unproven).
func _tokens() -> void:
	var life: Node = study.get("life")
	if life == null or life.tokens == null:
		check(false,"Tokens: the isle's life and its tokens are there")
		return
	var all: Array = life.tokens.tokens.map(func(t: Dictionary) -> String: return t.name)
	var taken: Array = life.tokens.taken
	check(taken.size() >= 5,"Tokens: the routes took %d of %d on-foot tokens (%s; not taken: %s)" % [taken.size(),all.size(),", ".join(taken),", ".join(all.filter(func(n: String) -> bool: return not taken.has(n)))])
