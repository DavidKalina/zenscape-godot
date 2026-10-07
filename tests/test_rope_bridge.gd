extends SceneTree
## Rope bridges alive (scripts/rope_bridge_sim.gd, scripts/rope_bridge.gd):
## at rest the sim is the static bridge exactly (all zero, asleep, a deck's
## height the static one through Footbridge `deck_at` and SkyIslet
## `deck_y`); the pilot stood at the middle sinks it about SAG_UNDER, less
## toward an end, and stood to one side rolls the planks; a landing bounces
## it down and back up past where it rests, and it settles; wind sways it
## sideways; minutes of walking, landing, gusts and shudders keep it finite
## and in bounds, the same inputs always give the same bridge, and left
## alone it comes back to rest and sleeps. Live in the tree, the walker's
## weight (`tread`) sinks the deck the walker reads, and `hold` keeps him
## between the hand ropes.
const Sim = preload("res://scripts/rope_bridge_sim.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Solver = preload("res://scripts/cluster_solver.gd")
const FRAME := 1.0/60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	_rest()
	_load()
	_landing()
	_wind()
	_long_run()
	_static_decks()
	await _live_in_tree()
	print("PASS: rope bridge" if failures == 0 else "FAIL: rope bridge")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run(sim: RefCounted, seconds: float, load := Vector3.INF) -> void:
	for i in range(roundi(seconds/FRAME)):
		if load != Vector3.INF: sim.load(load.x,load.y,load.z)
		sim.step(FRAME)

func _rest() -> void:
	var sim := Sim.new(12.0)
	_run(sim,10.0)
	check(not sim.awake and sim.drop(0.5,0.0) == 0.0 and sim.deepest() == 0.0,"Left alone it is the static bridge (asleep, all zero)")
	var deck := PackedVector4Array()
	var hand := PackedVector4Array()
	sim.pack(deck,hand)
	check(deck.size() == Sim.NODES_MAX+1 and deck[5] == Vector4.ZERO and hand[5] == Vector4.ZERO,"Its shader samples at rest are zero")

func _load() -> void:
	for span: float in [7.0,12.0,19.5]:
		var sim := Sim.new(span)
		_run(sim,8.0,Vector3(0.5,0.0,1.0))
		var mid: float = -sim.drop(0.5,0.0)
		check(absf(mid-Sim.SAG_UNDER) < Sim.SAG_UNDER*0.2,"%.1f m: stood at the middle it sinks %.3f m (want about %.2f)" % [span,mid,Sim.SAG_UNDER])
		check(sim.awake and sim.sound(),"%.1f m: loaded it stays awake and finite" % span)
	var sim := Sim.new(12.0)
	_run(sim,8.0,Vector3(0.2,0.0,1.0))
	var under: float = -sim.drop(0.2,0.0)
	check(under < Sim.SAG_UNDER*0.85 and under > Sim.SAG_UNDER*0.4,"Toward an end it sinks less (%.3f m at t 0.2)" % under)
	sim = Sim.new(12.0)
	_run(sim,8.0,Vector3(0.5,0.25,1.0))
	check(sim.drop(0.5,0.3) < sim.drop(0.5,-0.3)-0.03,"Stood to one side, that side sinks more: the planks roll (%.3f vs %.3f)" % [sim.drop(0.5,0.3),sim.drop(0.5,-0.3)])

func _landing() -> void:
	var sim := Sim.new(12.0)
	_run(sim,8.0,Vector3(0.5,0.0,1.0))
	var rest: float = sim.drop(0.5,0.0)
	sim.land(0.5,0.0,11.0)
	var low := rest
	var high := -INF
	var t := 0.0
	var bottomed := false
	while t < 3.0:
		sim.load(0.5,0.0,1.0)
		sim.step(FRAME)
		t += FRAME
		var y: float = sim.drop(0.5,0.0)
		low = minf(low,y)
		if y > low+0.02: bottomed = true
		if bottomed: high = maxf(high,y)
	check(rest-low > 0.12,"A hard landing bounces it down (%.3f m more)" % (rest-low))
	check(high > rest+0.04,"and it springs back up past its rest (%.3f m over)" % (high-rest))
	_run(sim,6.0,Vector3(0.5,0.0,1.0))
	check(absf(sim.drop(0.5,0.0)-rest) < 0.01,"and settles again within seconds")

func _wind() -> void:
	var sim := Sim.new(14.0)
	var most := 0.0
	for i in range(roundi(12.0/FRAME)):
		sim.wind(3.0)
		sim.step(FRAME)
		most = maxf(most,absf(sim.sway(0.5)))
	check(most > 0.08 and most < Sim.SWAY_MOST*1.6,"A 3 m/s wind across sways it (%.3f m at most)" % most)
	var still := Sim.new(14.0)
	for i in range(roundi(12.0/FRAME)):
		still.wind(0.6)
		still.step(FRAME)
	check(absf(still.sway(0.5)) < most,"a breeze less")
	sim.shudder(1.0)
	_run(sim,0.3)
	check(sim.sound(),"A plane's shudder stays finite")

## Minutes of play, fed the same seeded inputs twice.
func _long_run() -> void:
	var a := _played(1234)
	var b := _played(1234)
	check(a.sound() and b.sound(),"Minutes of walking, landing, gusts and shudders: finite")
	var same := true
	for k in range(a.nodes+1):
		if a.yl[k] != b.yl[k] or a.x[k] != b.x[k] or a.hxr[k] != b.hxr[k]: same = false
	check(same,"The same inputs give the same bridge")
	check(_peak < 0.6,"and it never swings near its guard (%.3f m at most)" % _peak)
	var t := 0.0
	while a.awake and t < 60.0:
		a.wind(0.0)
		a.step(FRAME)
		t += FRAME
	check(not a.awake and a.deepest() == 0.0,"Left alone after, it settles and sleeps (%.1f s)" % t)

var _peak := 0.0

func _played(seed_value: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sim := Sim.new(16.0,0.74,seed_value)
	var at := 0.0
	var way := 1.0
	_peak = 0.0
	for i in range(roundi(150.0/FRAME)):
		at += way*FRAME*(4.0 if (i/600) % 2 == 0 else 2.0)/16.0
		if at > 1.0 or at < 0.0:
			way = -way
			at = clampf(at,0.0,1.0)
		var side := sin(i*0.01)*0.2
		sim.load(at,side,1.0)
		if i % 20 == 0: sim.step_on(at,side,rng.randf(),(i/20) % 2)
		if i % 300 == 150: sim.land(at,side,rng.randf_range(4.0,13.0))
		if i % 900 == 400: sim.shudder(rng.randf_range(0.3,1.4))
		sim.wind(rng.randf_range(-1.0,1.0)*(6.0 if (i/240) % 3 == 0 else 1.5))
		sim.step(FRAME*(1.0 if i % 97 else 4.0))
		for k in range(sim.nodes+1): _peak = maxf(_peak,maxf(absf(sim.yl[k]),absf(sim.x[k])))
	return sim

## The decks the walker reads: with an asleep sim, the static heights; with
## a loaded one, sunk by the sim's drop.
func _static_decks() -> void:
	var plan := Solver.solve("showcase",1)
	var found := {}
	for m: Dictionary in plan.members:
		for deck: Dictionary in m.shape.decks:
			if float(deck.bow) < 0.0:
				found = {"shape":m.shape,"deck":deck}
				break
		if not found.is_empty(): break
	check(not found.is_empty(),"The showcase has a rope bridge's deck")
	if found.is_empty(): return
	var shape: RefCounted = found.shape
	var deck: Dictionary = found.deck
	var a: Vector3 = deck.a
	var b: Vector3 = deck.b
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	var samples := []
	for k in range(1,20):
		var p := Vector2(a.x,a.z).lerp(Vector2(b.x,b.z),k/20.0)
		samples.append([p,shape.deck_y(p)])
	var sim := Sim.new(span)
	deck["sim"] = sim
	var same := true
	for s: Array in samples:
		if not is_equal_approx(shape.deck_y(s[0]),s[1]): same = false
	check(same,"An islet's rope deck at rest reads its static height")
	_run(sim,8.0,Vector3(0.5,0.0,1.0))
	var mid := Vector2(a.x,a.z).lerp(Vector2(b.x,b.z),0.5)
	var sunk: float = float(samples[9][1])-shape.deck_y(mid)
	check(absf(sunk-(-sim.drop(0.5,0.0))) < 0.005 and sunk > 0.1,"and loaded, the walker reads it sunk with the sim (%.3f m)" % sunk)
	deck.erase("sim")
	# The plate's decks: Footbridge deck_at with an asleep sim and without.
	var plate: Array[Dictionary] = [{"a":Vector3(0.0,1.0,0.0),"b":Vector3(10.0,1.4,0.0),"span":10.0,"rails":true,"sim":Sim.new(10.0)}]
	var bare: Array[Dictionary] = [{"a":Vector3(0.0,1.0,0.0),"b":Vector3(10.0,1.4,0.0),"span":10.0,"rails":true}]
	same = true
	for k in range(1,20):
		for side: float in [-0.3,0.0,0.3]:
			var p := Vector2(k*0.5,side)
			if not is_equal_approx(float(Footbridge.deck_at(plate,p).y),float(Footbridge.deck_at(bare,p).y)): same = false
	check(same,"A plate rope deck at rest reads its static height")

## A live bridge in the tree: `tread` with the feet on its deck sinks it
## under them, and `hold` keeps them in.
func _live_in_tree() -> void:
	var frame := Node3D.new()
	root.add_child(frame)
	frame.position = Vector3(5.0,20.0,-3.0)
	var a := Vector3(0.0,1.0,0.0)
	var b := Vector3(12.0,1.0,0.0)
	var record := {"a":a,"b":b,"width":Footbridge.WIDTH,"bow":Footbridge.bow(12.0)}
	var bridge := Footbridge.live(Footbridge.build_mesh(a,b,3),a,b,3,record)
	frame.add_child(bridge)
	check(record.get("sim") == bridge.sim,"Live in the tree, its deck record carries its sim")
	var deck_y := func(p: Vector2) -> float:
		var t := p.x/12.0
		var side: float = p.y-float(bridge.sim.sway(t))
		return 1.0+Footbridge.bow(12.0)*pow(sin(PI*t),2.0)+float(bridge.sim.drop(t,side))
	var rest: float = deck_y.call(Vector2(6.0,0.0))
	for i in range(240):
		var feet := Vector3(6.0,deck_y.call(Vector2(6.0,0.0)),0.0)
		RopeBridge.tread(frame,feet,true,{},{},0.0)
		await process_frame
	var sunk: float = rest-deck_y.call(Vector2(6.0,0.0))
	check(sunk > Sim.SAG_UNDER*0.6,"Tread on, it sinks under the feet (%.3f m)" % sunk)
	var feet := Vector3(6.0,deck_y.call(Vector2(6.0,0.0)),0.0)
	var held: Vector2 = RopeBridge.hold(frame,feet,Vector2(6.0,0.9))
	check(absf(held.y) < Footbridge.WIDTH*0.5,"The hand ropes keep a step to the side on the deck (%.2f m off the middle)" % held.y)
	var free: Vector2 = RopeBridge.hold(frame,feet+Vector3.UP*1.2,Vector2(6.0,0.9))
	check(is_equal_approx(free.y,0.9),"Jumped clear over them, he is let over")
	var past: Vector2 = RopeBridge.hold(frame,Vector3(0.5,1.0,0.0),Vector2(-0.3,0.9))
	check(is_equal_approx(past.y,0.9),"Off its end, no hold")
	frame.queue_free()
	await process_frame
	check(not record.has("sim"),"Out of the tree, its deck is the static one again")
