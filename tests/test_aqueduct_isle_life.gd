extends SceneTree
## The aqueduct isle's life (studies/aqueduct_isle_life.gd, docs/scenic/
## aqueduct-isle-life.md), headless: the undergrowth grows at the ruins'
## feet and off the paths; butterflies come to the flower patches and stay
## by them; fireflies light only at dusk; the breeze ribbons ride the gust
## fronts over the isle (not the world's zero) and the loose leaves and
## chaff lie on its turf; songbirds perch on the stones, flush when the
## pilot comes close, settle elsewhere and come home once he has gone; and
## every on-foot token stands in open air and is taken by the move it asks
## for, driven as a player would, the readout climbing to the full line.
##   godot --headless --path . --script tests/test_aqueduct_isle_life.gd
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Life = preload("res://studies/aqueduct_isle_life.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var life: Node3D
var m

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("aqueduct isle life test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready or study.life == null: await process_frame
	life = study.life
	m = study.motor
	_flags()
	_undergrowth()
	_butterflies()
	_fireflies()
	_wind()
	_birds()
	_tokens()
	print("PASS: aqueduct isle life" if failures == 0 else "FAIL: aqueduct isle life (%d)" % failures)
	quit(1 if failures else 0)

## The life's own frames, `seconds` of them (the look's too, so the air and
## the light move on).
func live(seconds: float) -> void:
	for i in range(int(seconds/DT)):
		study._advance_look(DT)
		life.advance(DT)

func _flags() -> void:
	var all: Dictionary = Life.wanted(PackedStringArray())
	check(all.values().all(func(v: bool) -> bool: return v),"Every part of the isle's life is on by default")
	var some: Dictionary = Life.wanted(PackedStringArray(["--no-birds","--no-tokens"]))
	check(not some.birds and not some.tokens and some.butterflies and some.wind,"--no-birds and --no-tokens leave only those out")
	var none: Dictionary = Life.wanted(PackedStringArray(["--no-life"]))
	check(none.values().all(func(v: bool) -> bool: return not v),"--no-life leaves it all out")

# --- Undergrowth --------------------------------------------------------------------

func _undergrowth() -> void:
	var node: Node3D = life.undergrowth
	check(node != null,"The undergrowth grows")
	if node == null: return
	var counts: Dictionary = node.get_meta("counts")
	for kind in ["fern","shrub","mushroom","log","leaf_bed"]:
		check(int(counts.get(kind,0)) > 0,"Undergrowth: %d %s" % [int(counts.get(kind,0)),kind])
	var instances: Dictionary = node.get_meta("instances")
	check(instances.size() >= 5,"Undergrowth: drawn as %d catalog parts, %d multimeshes, %d triangles" % [instances.size(),node.get_child_count(),int(node.get_meta("triangles"))])
	var on_path := 0
	var at_foot := 0
	var records: Array = node.get_meta("records")
	for item: Dictionary in records:
		var p := Vector2(float(item.x),float(item.z))
		if Art.path_wear(p) > 0.3: on_path += 1
		for k in range(8):
			if life.standing_at(p+Vector2.from_angle(k*TAU/8.0)*2.5) or life.ground_at(p+Vector2.from_angle(k*TAU/8.0)*2.5) == null:
				at_foot += 1
				break
	check(on_path == 0,"Undergrowth: nothing on the worn paths (%d)" % on_path)
	check(at_foot > records.size()*0.7,"Undergrowth: most of it by the ruins' feet or the rims (%d of %d)" % [at_foot,records.size()])

# --- Butterflies and fireflies --------------------------------------------------------

func _butterflies() -> void:
	study.apply_look("alpine_morning",false)
	check(life.meadows.size() >= 2,"Butterflies: %d flower patches have them" % life.meadows.size())
	if life.meadows.is_empty(): return
	live(45.0)
	var showing := 0
	var strays := 0
	for meadow: Node3D in life.meadows:
		var flies: Node3D = meadow.flies
		showing += flies.showing()
		for fly: Dictionary in flies.flies:
			if float(fly.fade) <= 0.0: continue
			var p: Vector3 = fly.pos
			var near := INF
			for s: Vector2 in meadow.survey.flower_spots: near = minf(near,s.distance_to(Vector2(p.x,p.z)))
			var g: Variant = life.ground_at(Vector2(p.x,p.z))
			if near > 6.0 or (g != null and p.y < float(g)) or p.y > Art.TOP+20.0: strays += 1
	check(showing >= 4,"Butterflies: %d out over the patches in Alpine morning" % showing)
	check(strays == 0,"Butterflies: every one keeps near its patch's flowers and over the ground (%d strays)" % strays)
	study.apply_look("first_snow",false)
	live(6.0)
	var left := 0
	for meadow: Node3D in life.meadows: left += meadow.flies.showing()
	check(left == 0,"Butterflies: gone in First snow (%d left)" % left)
	study.apply_look("alpine_morning",false)

func _fireflies() -> void:
	var flies: MultiMeshInstance3D = life.fireflies
	check(flies != null and flies.multimesh.instance_count >= 40,"Fireflies: %d over the undergrowth" % (flies.multimesh.instance_count if flies != null else 0))
	if flies == null: return
	live(0.5)
	check(flies.activity < 0.01,"Fireflies: dark by day (activity %.2f)" % flies.activity)
	var night := ""
	for id: String in SceneLookPresets.PRESETS:
		if id.contains("night"): night = id
	if night != "":
		study.apply_look(night,false)
		live(1.0)
		check(flies.activity > 0.2,"Fireflies: lit in %s (activity %.2f)" % [night,flies.activity])
		study.apply_look("alpine_morning",false)
		live(1.0)

# --- The wind made visible ----------------------------------------------------------

func _wind() -> void:
	var trails: Node = study._atmosphere.wind_trails
	check(trails != null and trails.has_method("carry_front"),"Wind: the breeze ribbons ride the isle's air")
	if trails == null: return
	study.camera.global_position = Vector3(100.0,34.0,14.0)
	study.camera.look_at(Vector3(100.0,32.0,-10.0))
	var seen := 0
	var low := 0
	for k in range(4):
		study._send_gust()
		for i in range(int(4.0/DT)):
			study._advance_look(DT)
			life.advance(DT)
			for r: Dictionary in trails.ribbons:
				seen = maxi(seen,trails.ribbons.size())
				if (r.pos as Vector3).y < Art.TOP-3.0: low += 1
	check(seen >= 2,"Wind: gust fronts bring ribbons over the isle (%d at once)" % seen)
	check(low == 0,"Wind: no ribbon sinks under the isle (%d frames)" % low)
	check(trails.heads.size() > 0,"Wind: the ribbons' heads are published for the grass and vines to bow")
	var leaves: MultiMeshInstance3D = life.leaf_litter
	var chaff: MultiMeshInstance3D = life.grass_chaff
	check(leaves.leaves.size() >= 20,"Wind: %d loose leaves at the ruins' feet" % leaves.leaves.size())
	check(chaff.leaves.size() >= 30,"Wind: %d bits of chaff on the meadow" % chaff.leaves.size())
	var off := 0
	for leaf: Dictionary in leaves.leaves+chaff.leaves:
		if leaf.lost: continue
		var p: Vector3 = leaf.position
		var g: Variant = life.ground_at(Vector2(p.x,p.z))
		if g == null or p.y < float(g)-0.2 or p.y > float(g)+4.0: off += 1
	check(off == 0,"Wind: every leaf and blade lies on the turf or rides just over it (%d off)" % off)

# --- Songbirds ------------------------------------------------------------------------

func _birds() -> void:
	var birds: Node3D = life.birds
	check(birds != null,"Songbirds: on the isle")
	if birds == null: return
	var groups: Dictionary = birds.groups
	var perches := 0
	for name: String in groups: perches += (groups[name].perches as Array).size()
	check(groups.size() >= 5 and perches >= 40,"Songbirds: %d perch groups, %d perches on the stone (%s)" % [groups.size(),perches,", ".join(groups.keys())])
	check(birds.flocks.size() >= 3 and birds.birds.size() >= 10,"Songbirds: %d flocks, %d birds" % [birds.flocks.size(),birds.birds.size()])
	study.place(Vector3(118.0,30.0,14.0),Vector2(0.0,-1.0))
	live(10.0)
	# Over 20 s: the most sat at once, and every sitter on stone.
	var sat := 0
	var off_stone := 0
	var states := {}
	for k in range(40):
		live(0.5)
		var now := 0
		for bird: Dictionary in birds.birds:
			states[bird.state] = int(states.get(bird.state,0))+1
			if bird.state != "perched": continue
			now += 1
			var p: Vector3 = bird.p
			var g: Variant = life.ground_at(Vector2(p.x,p.z))
			if g != null and p.y < float(g)+0.7: off_stone += 1
		sat = maxi(sat,now)
	var forage := {}
	for name: String in groups: forage[name] = (groups[name].forage as Array).size()
	print("     states over 20 s %s, forage spots %s" % [states,forage])
	var on_stone := sat if off_stone == 0 else -1
	check(sat >= 5 and on_stone == sat,"Songbirds: %d perched, all on stone over the turf (%d)" % [sat,on_stone])
	var lively: Dictionary = birds.counts
	live(40.0)
	check(int(birds.counts.get("take_off",0)) > 0 and int(birds.counts.get("hop",0)) > 0 and int(birds.counts.get("land_ground",0)) > 0,"Songbirds: they flit, hop and forage by themselves (%s)" % birds.counts)
	# The pilot walks up to a settled flock's perched bird.
	var flock: Dictionary = {}
	var bird_at := Vector3.INF
	for i in range(600):
		for f: Dictionary in birds.flocks:
			if f.state != "settled" or f.group != f.home: continue
			for bird: Dictionary in birds._members(f):
				if bird.state == "perched":
					flock = f
					bird_at = bird.p
		if not flock.is_empty(): break
		live(0.1)
	flock.calm_until = 0.0
	var flushes := int(birds.counts.get("flush",0))
	study.place(bird_at+Vector3(2.0,0.0,0.0),Vector2(-1.0,0.0))
	for i in range(6):
		study.tick(DT)
		life.advance(DT)
	check(int(birds.counts.get("flush",0)) > flushes,"Songbirds: the pilot coming close flushes the %s (%d flushes)" % [flock.species,int(birds.counts.get("flush",0))])
	var home: String = flock.home
	live(10.0)
	check(flock.group != home,"Songbirds: they settle away from him, at the %s" % flock.group)
	study.place(Vector3(60.0,Art.ground(60.0,20.0),20.0),Vector2(0.0,-1.0))
	live(50.0)
	check(flock.group == home,"Songbirds: with him gone they come home to the %s" % home)
	# A strong gust (B) reaching a flock flushes it.
	var before := int(birds.counts.get("flush",0))
	for f: Dictionary in birds.flocks: f.calm_until = 0.0
	study.camera.global_position = (birds.groups[birds.flocks[1].group].middle as Vector3)+Vector3(0.0,4.0,22.0)
	study.camera.look_at(birds.groups[birds.flocks[1].group].middle)
	study._send_gust()
	live(8.0)
	check(int(birds.counts.get("flush",0)) > before,"Songbirds: a gust sent at them flushes them (%d)" % (int(birds.counts.get("flush",0))-before))
	var night := ""
	for id: String in SceneLookPresets.PRESETS:
		if id.contains("night"): night = id
	if night != "":
		study.apply_look(night,false)
		live(25.0)
		check(birds.visible_birds().is_empty(),"Songbirds: gone for the night in %s (%d seen)" % [night,birds.visible_birds().size()])
		study.apply_look("alpine_morning",false)
		live(30.0)
		check(birds.visible_birds().size() >= 6,"Songbirds: back by morning (%d seen)" % birds.visible_birds().size())

# --- Tokens -----------------------------------------------------------------------------

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

## As tests/test_aqueduct_isle.gd `line`: from `from`, a way to `to` by
## `tech` ("walk", "jump", "jump_twirl", "kick").
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

func on_circle(p: Vector3) -> Vector3:
	return study.circle.transform*p

func lintel(k: int) -> Vector3:
	return on_circle(((study.circle.get_meta("ring").lintels as Array)[k] as Array)[0])

func joint(j: int) -> Vector3:
	var a := (j%RuinKit.CIRCLE_STONES+0.5)*TAU/RuinKit.CIRCLE_STONES
	return on_circle(Vector3(sin(a)*RuinKit.CIRCLE_RADIUS,RuinKit.SARSEN.y+RuinKit.LINTEL.y,cos(a)*RuinKit.CIRCLE_RADIUS))

func taken(name: String) -> bool:
	return (life.tokens.taken as Array).has(name)

func _tokens() -> void:
	var tokens: Node3D = life.tokens
	check(tokens != null,"Tokens: on the isle")
	if tokens == null: return
	var count: int = tokens.tokens.size()
	check(count >= 5 and count <= 8,"Tokens: %d on the whole isle" % count)
	var space := study.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	for t: Dictionary in tokens.tokens:
		query.transform = Transform3D(Basis.IDENTITY,t.at)
		check(space.intersect_shape(query,1).is_empty(),"Tokens: %s stands in open air at %s" % [t.name,t.at])
		# Not taken standing on the turf under it, nor by a pump jump there.
		# The buried one is low, but under the turf till a slam breaks it
		# open (tests/test_slam.gd takes it that way).
		var g: Variant = life.ground_at(Vector2((t.at as Vector3).x,(t.at as Vector3).z))
		if t.get("buried",false):
			check(tokens.buried.has(t.name) and tokens.buried[t.name].covered(),"Tokens: %s is buried, out of reach till a slam" % t.name)
		elif g != null:
			check((t.at as Vector3).y-float(g) > 1.5+0.55+0.95,"Tokens: %s is out of a jump's reach from the turf under it (%.1f m up)" % [t.name,(t.at as Vector3).y-float(g)])
	# The slot: kicked up between the castellum and the blind wall.
	line(Vector3(98.0,30.0,-2.6),Vector3(99.5,-(Art.TOP+Art.DECK-1.0),-2.6),"kick")
	check(taken("slot"),"Tokens: the slot's, wall-kicked up between the castellum and the blind wall")
	# The wall run along the blind wall's east face.
	study.respawn()
	for i in range(10): tick(Vector2.ZERO)
	walk([Vector2(103.5,Art.START.z),Vector2(103.5,8.0),Vector2(102.1,7.0)],0.4)
	for i in range(10): tick(Vector2.ZERO)
	var ran := false
	for i in range(240):
		var want := Vector2(0.0,-1.0)
		var jump := false
		if m.feet.z < -0.6 and not ran and (m.grounded or m.velocity.y > 0.0): jump = true
		if m.feet.z < -0.4 and not ran: want = Vector2(-0.25,-1.0).normalized()
		if m.move == "wallrun": ran = true
		tick(want,jump)
		if ran and m.grounded: break
	check(ran and taken("wallrun"),"Tokens: the wall run's, at the top of a run along the blind wall")
	# Two plain running jumps along the same face don't reach it.
	# The fallen span: run off the snapped end, twirl as he sinks, up onto
	# the far lip.
	study.respawn()
	for i in range(10): tick(Vector2.ZERO)
	walk([Vector2(100.0,Art.START.z-1.0),Vector2(100.0,-(Art.SNAP-1.5))])
	var deck := Art.TOP+Art.DECK
	var twirled := false
	for i in range(240):
		var twirl: bool = not m.grounded and m.feet.y < deck-0.6 and not twirled
		twirled = twirled or twirl
		tick(Vector2(0.0,-1.0),m.on_ledge() and i%20 < 3,false,twirl)
		if m.grounded and m.feet.z < -(Art.RESUME+0.1) and not m.on_ledge(): break
	check(taken("span") and m.feet.z < -Art.RESUME and absf(m.feet.y-deck) < 0.1,"Tokens: the fallen span's, dropped into and twirled out of onto the far deck (feet %s)" % m.feet)
	# The floating sarsen: from the lintel before the bite, a twirled jump
	# from the sarsen's top along the broken lintel's end (as the ring loop
	# in tests/test_aqueduct_isle.gd).
	var ring: Dictionary = study.circle.get_meta("ring")
	var n := RuinKit.CIRCLE_STONES
	var gone: Array = ring.gone
	if not gone.is_empty():
		var k := posmod(int(gone[0])-1,n)
		var from := joint(k+1)
		study.place(lintel(k),Vector2(1.0,0.0))
		for i in range(30): tick(Vector2.ZERO)
		var ok := climb(m.feet,[flat(from)]) and line(m.feet,Art.platform("ring_sarsen").at,"jump_twirl")
		check(ok and taken("sarsen"),"Tokens: the floating sarsen's, a twirled jump from the ring's lintels")
	# The great trilithon: from the back lintel, a jump up.
	var back := lintel(n/2-1)
	var ok := line(back,on_circle(ring.trilithon),"jump")
	check(ok and taken("trilithon"),"Tokens: the great trilithon's, a jump up from the back lintel")
	# The drift lintel: stepped off its north lip, hung, shimmied along.
	var stone: Dictionary = Art.platform("drift_3")
	var basis := Basis(Vector3.UP,float(stone.yaw))
	var north := basis.z if basis.z.z < 0.0 else -basis.z
	var along := basis.x
	study.place((stone.at as Vector3)-along*0.7,Vector2(north.x,north.z).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var hung := false
	for i in range(150):
		tick(Vector2(north.x,north.z).normalized()*0.25)
		if m.on_ledge():
			hung = true
			break
	var was: float = tokens.left()
	for i in range(240):
		if taken("drift") or not m.on_ledge(): break
		tick(Vector2(along.x,along.z).normalized())
	check(hung and taken("drift"),"Tokens: the drift lintel's, hung off its north lip and shimmied along (hung %s)" % hung)
	# The stumps: from the far island, a running jump out over the sky.
	var last: Array = Art.stumps()[-1]
	var stumps := line(Vector3(Art.STUMPS_X,30.0,float(last[2])-5.4),Vector3(Art.STUMPS_X,float(last[3]),(float(last[1])+float(last[2]))*0.5),"jump_twirl")
	check(stumps and taken("stumps"),"Tokens: the stumps', jumped out over the sky from the far island")
	# The buried one off the north path: a slam onto it from a height (crouch
	# pressed fresh 6 m up) breaks it open, and it's taken up out of the turf.
	var dig: Node3D = tokens.buried.get("buried")
	if dig != null:
		var under: Vector3 = dig.global_position
		study.place(under,Vector2(0.0,-1.0))
		for i in range(5): tick(Vector2.ZERO)
		m.feet.y += 6.0
		m.grounded = false
		for i in range(120):
			tick(Vector2.ZERO,false,true)
			if m.grounded and i > 2: break
		for i in range(60): dig.advance(DT)
		study.place(under,Vector2(0.0,-1.0))
		for i in range(5): tick(Vector2.ZERO)
	check(dig != null and taken("buried"),"Tokens: the buried one, broken open with a slam and taken")
	check(tokens.left() == 0,"Tokens: all %d taken (%d left)" % [count,tokens.left()])
	var hud: CanvasLayer = tokens.hud
	check(hud._got == count and hud._of == count,"Tokens: the readout counts the line whole (%d of %d)" % [hud._got,hud._of])
