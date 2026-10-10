extends SceneTree
## The sky village island pack (studies/island_packs/sky_village.gd),
## headless: the study opened on the pack, and at every station a route
## driven end to end with scripted inputs (the stick in the world's x, z,
## Jump, crouch, twirl), checking he ends where the route goes: the easy
## way, and the expert line where it is proven. Run with `-- --save`, each
## proven route is also saved as a recording under studies/character_runs/
## (replacing the last one saved with its label), for the study's F6 and
## tests/test_character_recordings.gd.
##   godot --headless --path . --script tests/test_island_pack_sky_village.gd
##   godot --headless --path . --script tests/test_island_pack_sky_village.gd -- --save
const Recording = preload("res://scripts/character_recording.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
const PACK := "sky_village"
var failures := 0
var study: Node3D
var m: PilotMotor
var saving := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("sky village test timed out"); quit(2))
	saving = "--save" in OS.get_cmdline_user_args()
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	study.pack = PACK
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	check(study.pack == PACK and study.stations.size() >= 6,"The pack loads, %d stations" % study.stations.size())
	_market()
	_chimney()
	_bell()
	_laundry()
	_roofline()
	_towers()
	_gate()
	_without()
	print("PASS: sky village" if failures == 0 else "FAIL: sky village (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving -------------------------------------------------------------------

func tk(want := Vector2.ZERO, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func flat() -> Vector2:
	return Vector2(m.feet.x,m.feet.z)

## The way to `p` from the feet (x, z).
func to(p: Vector2) -> Vector2:
	var d := p-flat()
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO

## Run on the ground to `p` (at `pace` of the stick); false if he fell or
## never got there.
func run_to(p: Vector2, near := 0.3, frames := 900, pace := 1.0) -> bool:
	for i in range(frames):
		if flat().distance_to(p) < near: return true
		tk(to(p)*pace)
		if m.feet.y < 39.0: return false
	return false

## Stood still a while.
func settle(frames := 20) -> void:
	for i in range(frames): tk()

## Climbing out of a hang, the stick held towards the wall.
func climb_out(frames := 90) -> bool:
	for i in range(frames):
		if not m.on_ledge() and m.grounded: return true
		var into := -(m.lip_out as Vector2) if m.on_ledge() else Vector2.ZERO
		tk(into)
	return m.grounded and not m.on_ledge()

## A route begun at station `key`: set down at its spawn, recorded.
func begin(key: int) -> void:
	study.go_to(key)
	settle(10)
	study._rec = Recording.new(m,key,study._feel_now(),PACK)

## The route done: recorded under `label` (saved with --save).
func finish(label: String) -> void:
	var rec: RefCounted = study._rec
	study._rec = null
	rec.label = label
	if not saving: return
	for path in Recording.paths():
		var data := Recording.read(path)
		if str(data.get("pack","")) == PACK and str(data.get("label","")) == label: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	rec.save()

func on(y: float) -> bool:
	return m.grounded and absf(m.feet.y-y) < 0.03

# --- 1 Market square -------------------------------------------------------------

func _market() -> void:
	# Easy: through the gate, round the fountain's south, up the steps.
	begin(1)
	var ok := run_to(Vector2(-16.5,0.0)) and run_to(Vector2(-8.0,-5.0)) and run_to(Vector2(6.0,-5.75)) and run_to(Vector2(12.2,-5.75))
	finish("village 1: through the gate, up the hall steps (easy)")
	check(ok and on(42.0),"Market: through the gate and up the steps to the hall terrace (feet %s)" % m.feet)
	# Expert: a long jump chain from the gate round the fountain's north,
	# a side flip up onto the covered market, a long jump to the terrace.
	begin(1)
	ok = run_to(Vector2(-15.2,0.0),0.4)
	var hops := 0
	var aim := Vector2(-2.0,4.6)
	for i in range(600):
		if not ok: break
		if flat().x > -6.0: aim = Vector2(10.0,4.6)
		var chaining := flat().x < 1.0
		var jump := false
		if m.grounded and m.move != "long" and hops == 0: jump = i%2 == 0
		elif not m.grounded and m.velocity.y < 0.0 and chaining: jump = i%2 == 0
		var was_air: bool = not m.grounded
		tk(to(aim),jump,chaining or hops == 0,false)
		if was_air and m.grounded: hops += 1
		if m.grounded and not chaining and hops > 0: break
		if m.feet.y < 39.0: ok = false
	var chained: int = study.long_chain
	ok = ok and run_to(Vector2(6.5,5.3),0.4) and run_to(Vector2(9.7,5.3),0.3)
	# Running at the post line: stick back across, Jump in the skid.
	var flipped := false
	for i in range(120):
		if not ok: break
		var back := Vector2(-0.7,0.7).normalized()
		tk(back,m.skidding and not flipped)
		flipped = flipped or m.move == "flip"
		if m.on_ledge(): climb_out()
		if flipped and m.grounded and i > 5: break
	var roof := on(41.8)
	# Off the roof's east edge in a long jump to the terrace.
	if roof:
		roof = run_to(Vector2(4.5,6.6),0.3)
		settle(10)
		var jumped := false
		for i in range(150):
			var go := flat().x > 8.3 and not jumped
			tk(to(Vector2(12.5,6.0)),go,go)
			jumped = jumped or m.move == "long"
			if jumped and m.grounded: break
	finish("village 1: long jump chain round the fountain, side flip, terrace (expert)")
	check(ok and hops >= 3 and roof and on(42.0),"Market: chained %d long jumps (%d chained), side-flipped onto the market roof (%s), long-jumped onto the terrace (feet %s)" % [hops,chained,roof,m.feet])

# --- 2 Chimney alley -------------------------------------------------------------

func _chimney() -> void:
	# Easy: jump and catch up the balconies, zig-zag, to the roof.
	begin(2)
	var ok := run_to(Vector2(65.8,-1.8))
	var tops := [41.2,42.4,43.6,44.8,46.0,47.2]
	var ways := [Vector2(0.0,-1.0),Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(0.0,-1.0)]
	var reached := 0
	for k in range(tops.size()):
		if not ok: break
		ok = _jump_up(ways[k],float(tops[k]))
		if ok: reached += 1
	finish("village 2: up the balconies to the roof (easy)")
	check(ok and on(47.2),"Chimney alley: jumped and caught up %d balconies to the 7.2 m roof (feet %s)" % [reached,m.feet])
	# Expert: kicked up the alley, 1.0 m clear, to the roof.
	begin(2)
	ok = run_to(Vector2(63.5,-2.5),0.2)
	var kicks := _slot_climb(Vector2(63.5,-5.0),Vector2(-1.0,0.0),47.2)
	finish("village 2: kicked up the chimney alley (expert)")
	check(ok and kicks >= 3 and on(47.2),"Chimney alley: kicked up the alley %d times and climbed onto the 7.2 m roof (feet %s)" % [kicks,m.feet])

## A short run along `way` from where he stands, a jump, a catch of the top
## at `top` and a climb onto it; whether he stands on it.
func _jump_up(way: Vector2, top: float) -> bool:
	var grabbed := false
	for i in range(150):
		var jump := i >= 8 and i < 30
		tk(way,jump)
		if m.on_ledge(): grabbed = true
		if grabbed and m.on_ledge(): continue
		if grabbed or (i > 10 and m.grounded): break
	if grabbed: climb_out()
	settle(6)
	return on(top)

## Up a slot between two walls along x: into it at `inside` (x, z), kicked
## from wall to wall (the stick held at the wall he goes to, first `side`),
## to the lip at `top` and climbed out. The kicks.
func _slot_climb(inside: Vector2, side: Vector2, top: float) -> int:
	var on_wall := 0
	var kicks := 0
	var was := ""
	for i in range(900):
		on_wall = on_wall+1 if m.move == "wall" else 0
		var in_slot := flat().distance_to(inside) < 0.6 or not m.grounded
		var want := side if in_slot else to(inside)
		if m.on_ledge(): want = -(m.lip_out as Vector2)
		var jump := (m.grounded and in_slot and m.feet.y < top-1.0) or (m.move != "wall" and m.velocity.y > 0.0 and not m.on_ledge()) or on_wall >= 5
		tk(want,jump)
		if m.move == "kick" and was != "kick":
			kicks += 1
			side = -side
		was = m.move
		if m.grounded and m.feet.y > top-0.1: break
	settle(6)
	return kicks

# --- 3 Bell tower ----------------------------------------------------------------

func _bell() -> void:
	# Easy: the nave's steps to its roof, a jump and a catch into the belfry.
	begin(3)
	var ok := run_to(Vector2(128.4,4.8)) and run_to(Vector2(138.5,4.8)) and run_to(Vector2(139.5,0.0)) and run_to(Vector2(140.8,0.0))
	ok = ok and _jump_up(Vector2(1.0,0.0),45.2)
	finish("village 3: the nave steps and into the belfry (easy)")
	check(ok and m.feet.x > 142.0,"Bell tower: up the nave's steps, a jump and a catch into the belfry (feet %s)" % m.feet)
	# Expert: pumped up onto the porch, then up the tower's face: jump,
	# kick off, twirl back to it, catch the belfry's sill.
	begin(3)
	ok = run_to(Vector2(147.6,6.0))
	var jumps := 0
	for i in range(200):
		if not ok: break
		# Jump at a run, held; again on the touch: the pump.
		var jump: bool = (m.grounded and flat().y < 5.4 and i%2 == 0) or (not m.grounded and m.velocity.y > 0.0)
		tk(Vector2(0.0,-1.0),jump)
		if m.on_ledge():
			climb_out()
			break
		if on(42.4): break
	var porch := on(42.4)
	ok = ok and porch and run_to(Vector2(149.1,0.0),0.2)
	settle(10)
	var kicked := false
	var twirled := false
	var grabbed := false
	var on_wall := 0
	for i in range(240):
		if not ok: break
		on_wall = on_wall+1 if m.move == "wall" else 0
		var jump: bool = (m.grounded and flat().x < 148.5) or (m.move == "jump" and m.velocity.y > 0.0) or (on_wall >= 4 and on_wall%2 == 0 and not kicked)
		var twirl: bool = kicked and m.move == "kick" and m.velocity.y < 2.0
		tk(Vector2(-1.0,0.0),jump,false,twirl)
		kicked = kicked or m.move == "kick"
		twirled = twirled or m.move == "twirl"
		if m.on_ledge():
			grabbed = true
			climb_out()
			break
		if kicked and m.grounded: break
	finish("village 3: porch, kick, twirl back to the belfry (expert)")
	check(porch and kicked and twirled and on(45.2) and m.feet.x < 147.0,"Bell tower: pumped onto the porch (%s), kicked off the tower, twirled back over the belfry sill (%s, feet %s)" % [porch,"caught it" if grabbed else "stepped onto it",m.feet])

# --- 4 Laundry lane --------------------------------------------------------------

func _laundry() -> void:
	# Easy: down the lane, across the rope bridge.
	begin(4)
	var ok := run_to(Vector2(208.0,0.0)) and run_to(Vector2(210.5,5.6)) and run_to(Vector2(222.0,5.6))
	finish("village 4: down the lane, over the rope bridge (easy)")
	check(ok and on(40.0) and m.feet.x > 219.5,"Laundry lane: down the lane and over the rope bridge (feet %s)" % m.feet)
	# Expert: a long jump along the gallery wall into a wall run over the
	# gap, kicked off it to the square.
	begin(4)
	ok = run_to(Vector2(196.0,-2.6),0.3)
	var ran := false
	var kicked := false
	for i in range(300):
		if not ok: break
		var go := m.grounded and flat().x > 209.5 and not ran
		var jump := go or (m.move == "wallrun" and m._wallrun < 0.1)
		var want := Vector2(1.0,-0.05) if not m.grounded else Vector2(1.0,0.0)
		if kicked: want = to(Vector2(225.0,2.0))
		tk(want,jump,go)
		ran = ran or m.move == "wallrun"
		kicked = kicked or (ran and m.move == "kick")
		if ran and m.grounded: break
	finish("village 4: long jump into a wall run over the gap (expert)")
	check(ok and ran and kicked and on(40.0) and m.feet.x > 219.0,"Laundry lane: long-jumped into a wall run along the gallery and kicked off it across the 6.5 m gap (feet %s)" % m.feet)

# --- 5 Roofline ------------------------------------------------------------------

func _roofline() -> void:
	# Easy: down the stair, hopped across the planters, a pump on each.
	begin(5)
	var ok := run_to(Vector2(258.0,5.75)) and run_to(Vector2(273.0,5.75)) and run_to(Vector2(273.5,0.0),0.2)
	settle(10)
	var hops := 0
	for i in range(400):
		if not ok: break
		var was_air := not m.grounded
		tk(Vector2(1.0,0.0),m.grounded and flat().x > 275.2 and i%2 == 0)
		if was_air and m.grounded: hops += 1
		if m.feet.x > 287.5 and m.grounded: break
		if m.feet.y < 38.0: ok = false
	settle(10)
	finish("village 5: down the stair, over the planters (easy)")
	check(ok and on(39.0) and m.feet.x > 286.0,"Roofline: down the stair and hopped over the planters, %d landings (feet %s)" % [hops,m.feet])
	# Expert: off the terrace onto the barn roof crouched, surfed down it,
	# long-jumped off the street's edge with the pace kept, twirled over.
	begin(5)
	var top := 0.0
	var longed := false
	var twirled := false
	for i in range(600):
		var crouch := flat().x > 258.0
		var jump: bool = not m.grounded and flat().x > 270.0 and m.velocity.y < -1.0 and not longed and i%2 == 0
		var twirl: bool = longed and m.velocity.y < 0.0
		tk(Vector2(1.0,0.0),jump,crouch,twirl)
		if m.move == "slide": top = maxf(top,m.speed())
		longed = longed or m.move == "long"
		twirled = twirled or m.move == "twirl"
		if longed and m.grounded: break
		if m.feet.y < 36.0: break
	settle(10)
	finish("village 5: surf the barn roof, long jump and twirl to the garden (expert)")
	check(on(39.0) and longed and twirled and m.feet.x > 286.0,"Roofline: surfed the barn roof (to %.1f m/s), long-jumped off the street and twirled onto the garden island (feet %s)" % [top,m.feet])

## From where he stands, a run `run` metres along `way`, then a jump (a
## long jump, crouched, if `long`), held while it rises, twirled just past
## its top if `twirl`; a lip caught is climbed. Done once he stands again
## (and has braked); whether he caught a lip on the way.
func _leap(way: Vector2, run: float, long: bool, twirl: bool) -> bool:
	var from := flat()
	var jumped := false
	var caught := false
	for i in range(300):
		var go := not jumped and m.grounded and (flat()-from).dot(way) >= run
		var jump: bool = go or (jumped and not m.grounded and m.velocity.y > 0.0 and m.move != "twirl")
		tk(way,jump,long and go,twirl and jumped and m.velocity.y < 0.0)
		jumped = jumped or not m.grounded
		if m.on_ledge():
			caught = true
			climb_out()
			break
		if jumped and m.grounded: break
	# Landed with his pace: braked, the stick back against it.
	for i in range(40):
		if m.speed() < 0.3: break
		tk(-way if m.speed() > 2.0 else Vector2.ZERO)
	settle(8)
	return caught

# --- 6 Water towers --------------------------------------------------------------

func _towers() -> void:
	# Easy: round the big tank's catwalk, a lap and a half, onto its top.
	begin(6)
	var ok := run_to(Vector2(347.0,-2.9))
	for p: Vector2 in [Vector2(353.4,-2.9),Vector2(353.4,2.9),Vector2(347.6,2.9),Vector2(347.6,-2.9),Vector2(353.4,-2.9),Vector2(353.4,2.9),Vector2(351.0,2.3)]:
		ok = ok and run_to(p,0.25,600,0.5)
	settle(10)
	finish("village 6: round the big tank's catwalk (easy)")
	check(ok and on(47.2),"Water towers: round the catwalk, a lap and a half, onto the big tank (feet %s)" % m.feet)
	# Expert: up the warehouse steps, then tank to tank, each a long jump
	# 1.2 m up from near the rim, caught or landed, and braked.
	begin(6)
	ok = run_to(Vector2(321.3,-6.8)) and run_to(Vector2(330.6,-6.8)) and run_to(Vector2(328.0,0.0))
	settle(10)
	var tops := []
	if ok:
		var c := _leap(Vector2(1.0,0.0),3.6,true,false)
		tops.append("%.1f %s" % [m.feet.y,"caught" if c else "landed"])
		ok = run_to(Vector2(335.2,0.0),0.2,300,0.4)
		settle(10)
	if ok and on(44.8):
		var c := _leap(Vector2(1.0,0.0),2.9,true,false)
		tops.append("%.1f %s" % [m.feet.y,"caught" if c else "landed"])
		ok = run_to(Vector2(342.2,0.0),0.2,300,0.4)
		settle(10)
	if ok and on(46.0):
		var c := _leap(Vector2(1.0,0.0),2.9,true,false)
		tops.append("%.1f %s" % [m.feet.y,"caught" if c else "landed"])
	finish("village 6: tank to tank, long jumps (expert)")
	check(ok and on(47.2),"Water towers: off the warehouse roof and tank to tank, each a long jump, onto the big tank (%s, feet %s)" % [tops,m.feet])

# --- 7 Town gate -----------------------------------------------------------------

func _gate() -> void:
	# Easy: the steps up inside the wall to the wall walk, along it over
	# the gate.
	begin(7)
	var ok := run_to(Vector2(397.4,-3.3)) and run_to(Vector2(397.4,-12.6),0.3,900,0.6) and run_to(Vector2(399.2,-12.6),0.3,900,0.6) and run_to(Vector2(399.2,0.0))
	finish("village 7: up the steps to the wall walk, over the gate (easy)")
	check(ok and on(44.0),"Town gate: up the steps to the wall walk and along it over the gate (feet %s)" % m.feet)
	# Expert: into the lane, a wall run along the town wall, kicked across
	# to catch the guardhouse roof; back across with a jump to catch the
	# wall walk.
	begin(7)
	ok = run_to(Vector2(397.5,-3.0),0.2) and run_to(Vector2(397.5,0.5),0.2)
	var ran := false
	var kicked := false
	var caught := false
	for i in range(300):
		if not ok: break
		var go := m.grounded and flat().y > 2.2 and not ran
		var jump: bool = go or (m.move == "jump" and m.velocity.y > 0.0) or (m.move == "wallrun" and m._wallrun < 0.35)
		var want := Vector2(0.0,1.0) if not kicked else Vector2(-1.0,0.4).normalized()
		tk(want,jump)
		ran = ran or m.move == "wallrun"
		kicked = kicked or (ran and m.move == "kick")
		if m.on_ledge():
			caught = true
			climb_out()
			break
		if ran and m.grounded: break
	var roof := on(42.8)
	var back := false
	if roof:
		ok = run_to(Vector2(393.6,m.feet.z),0.2,300,0.5)
		settle(10)
		back = _leap(Vector2(1.0,0.0),2.1,false,false)
	finish("village 7: wall run, kick to the guardhouse, back to the wall walk (expert)")
	check(ok and ran and kicked and roof and on(44.0),"Town gate: wall run along the lane, kicked across onto the guardhouse roof (%s), jumped back to the wall walk (%s, feet %s)" % ["caught" if caught else "landed","caught" if back else "landed",m.feet])

# --- Without the move ------------------------------------------------------------

## Set down at `at` facing `face`, driven by `inputs` (each tick: the
## tick's number, giving [stick, jump, crouch, twirl]) until he stands
## again after leaving the ground: the highest the feet went, where he
## ended, and whether he fell under the islands.
func _try(at: Vector3, face: Vector2, inputs: Callable) -> Dictionary:
	study.place(at,face)
	settle(5)
	var top := at.y
	var left := false
	var low := at.y
	for i in range(400):
		var a: Array = inputs.call(i)
		tk(a[0],a[1],a[2],a[3])
		if m.on_ledge(): climb_out()
		top = maxf(top,m.feet.y)
		low = minf(low,m.feet.y)
		if not m.grounded: left = true
		elif left: break
	return {"top":snappedf(top,0.01),"end":m.feet.snappedf(0.01),"fell":low < 36.0 or m.feet.distance_to(at) > 40.0}

## Each expert line's key move left out, from where it is made: it should
## fall short, so the move is what makes the line.
func _without() -> void:
	# Bell tower: off the porch, the kick without the twirl back.
	var r := _try(Vector3(149.1,42.4,0.0),Vector2(-1.0,0.0),func(i: int) -> Array:
		return [Vector2(-1.0,0.0),(m.grounded and m.feet.x < 148.5) or (m.move == "jump" and m.velocity.y > 0.0) or (m.move == "wall" and i%2 == 0),false,false])
	check(r.top < 45.0 and not on(45.2),"Without the twirl back the kick off the tower peaks at %.2f, under the belfry's 45.2 (ends %s)" % [r.top,r.end])
	# Laundry lane: a long jump off the lane's end clear of the wall.
	r = _try(Vector3(205.0,40.0,1.5),Vector2(1.0,0.0),func(i: int) -> Array:
		var go := m.grounded and m.feet.x > 211.2
		return [Vector2(1.0,0.0),go or (m.move == "long" and m.velocity.y > 0.0),go,false])
	check(r.fell,"Without the wall run a long jump off the lane's end falls into the gap (ends %s)" % [r.end])
	r = _try(Vector3(205.0,40.0,1.5),Vector2(1.0,0.0),func(i: int) -> Array:
		var go := m.grounded and m.feet.x > 211.2
		return [Vector2(1.0,0.0),go,go,not m.grounded and m.velocity.y < 0.0])
	print("INFO Laundry lane: a long jump and a twirl off the lane's end, no wall run: %s" % ("falls" if r.fell else "crosses, ends %s" % r.end))
	# Roofline: a long jump and a twirl off the street without the surf.
	r = _try(Vector3(271.0,40.0,0.0),Vector2(1.0,0.0),func(i: int) -> Array:
		var go := m.grounded and m.feet.x > 275.4
		return [Vector2(1.0,0.0),go,go,not m.grounded and m.velocity.y < 0.0])
	check(not on(39.0) or m.feet.x < 286.0,"Without the surf's pace a long jump and a twirl off the street falls short of the garden (ends %s)" % [r.end])
	# Water towers: a running jump and a twirl, tank to tank.
	r = _try(Vector3(335.2,44.8,0.0),Vector2(1.0,0.0),func(i: int) -> Array:
		return [Vector2(1.0,0.0),m.grounded and m.feet.x > 337.9 or (not m.grounded and m.velocity.y > 0.0 and m.move == "jump"),false,not m.grounded and m.velocity.y < 0.0])
	print("INFO Water towers: a running jump and a twirl from the low tank to the middle one: %s" % ("falls" if r.fell else "ends %s" % r.end))
	# Market square: a plain running jump off the covered market's roof.
	r = _try(Vector3(5.0,41.8,6.6),Vector2(1.0,0.0),func(i: int) -> Array:
		return [Vector2(1.0,0.0),m.grounded and m.feet.x > 8.6 or (not m.grounded and m.velocity.y > 0.0),false,false])
	print("INFO Market square: a running jump off the covered market's roof to the terrace: ends %s" % [r.end])
