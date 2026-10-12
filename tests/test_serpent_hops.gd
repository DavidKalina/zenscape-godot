extends SceneTree
## Hopping and twirling on the rune serpent's back through its dip
## (scripts/kit_isle/serpent_rider.gd), headless, in the aqueduct isle's
## sky: stood on its spine with the stick let go, he hops (and twirls at
## the top of most hops) every second or so from the aqueduct isle's south
## rim down the dip toward the cloud sea and up again, at an even frame
## rate and at an uneven one (with a hitch now and then). Every hop comes
## down on its back; none counts as off the isle's edge, none strands him,
## nothing moves him home (or anywhere) in a frame, and the respawn floor
## stays set aside the whole way. (Its back used to slide out from under a
## hop and twirl as it slithered and turned in the dip: he came down past
## its flank and was set back beside the plane;
## docs/design/serpent-teleports-sail/round1.md.)
##   godot --headless --path . --script tests/test_serpent_hops.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
## The uneven frames' lengths (s), in turn.
const UNEVEN := [1.0/60.0,1.0/30.0,1.0/60.0,1.0/45.0,0.1,1.0/60.0,1.0/40.0]
## How long a ride (s) and how often a hop (s).
const RIDE := 40.0
const HOP_EVERY := 1.15
var failures := 0
var study: Node3D
var route: Node3D
var serpent: Node3D
var rider: Node3D
var m: RefCounted

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("serpent hops test timed out"); quit(2))
	LaunchArgs.set_override(["--no-life","--no-flora"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	route = study.sky.get("route")
	check(route != null,"The serpent flies the route between the isles")
	if route == null:
		_finish()
		return
	serpent = route.serpent
	rider = route.rider
	m = study.motor
	study.sky.flush()
	route.build_all()
	for i in range(3): await physics_frame
	serpent.set_process(false)
	rider.manual = true
	_ride("even frames",false)
	_ride("uneven frames",true)
	_finish()

func _finish() -> void:
	LaunchArgs.set_override(null)
	print("PASS: serpent hops" if failures == 0 else "FAIL: serpent hops (%d)" % failures)
	quit(1 if failures > 0 else 0)

## One frame of the game, in its order (the serpent's step held to its
## longest, as its own `_process` holds it).
func frame(dt: float) -> void:
	serpent.advance(minf(dt,0.1))
	route._process(dt)
	rider.step(dt)
	study.tick(dt)

## Set on its spine past the aqueduct isle's ledge, before the dip; hop and
## twirl the whole way down it and up again.
func _ride(label: String, uneven: bool) -> void:
	var home := float(serpent.marks()["home"])
	serpent.place(fposmod(home+80.0,float(serpent.route_length)))
	rider.reset()
	rider._set_live(true)
	study._end_fall()
	var a := 40.0
	study.place(rider.back.place(rider.back.top(a)),rider.back.ahead(a))
	study._last_stood = m.feet
	study.script_want = Vector2.ZERO
	study.script_jump = false
	study.script_twirl = false
	for i in range(10): frame(DT)
	check(rider.riding_on == "serpent","%s: set on its spine past the aqueduct isle's ledge" % label)
	var t := 0.0
	var next_hop := 0.5
	var held := 0.0
	var hops := 0
	var twirls := 0
	var air := false
	var landings := 0
	var off := false
	var stranded := false
	var jumped := 0.0
	var lowest := INF
	var lost_aside := true
	var twirled := false
	var n := 0
	while t < RIDE:
		var dt: float = UNEVEN[n%UNEVEN.size()] if uneven else DT
		n += 1
		if t >= next_hop and m.grounded and rider.riding_on == "serpent":
			held = 0.25
			next_hop = t+HOP_EVERY
			hops += 1
			twirled = hops%3 == 0
		study.script_jump = held > 0.0
		study.script_twirl = not m.grounded and m.velocity.y < 1.0 and not twirled
		if study.script_twirl:
			twirled = true
			twirls += 1
		held = maxf(held-dt,0.0)
		var was: Vector3 = m.feet
		frame(dt)
		t += dt
		jumped = maxf(jumped,m.feet.distance_to(was))
		lowest = minf(lowest,m.feet.y)
		if study.off_edge: off = true
		if study._stranded_left >= 0.0: stranded = true
		if not is_inf(float(study.lost)): lost_aside = false
		if rider.riding_on == "air": air = true
		elif air:
			air = false
			if rider.riding_on == "serpent": landings += 1
	study.script_jump = false
	study.script_twirl = false
	for i in range(30): frame(DT)
	print("MEASURE %s: %d hops (%d twirled), %d landings on its back, lowest %.1f m, the most moved in a frame %.2f m, off the edge %s, stranded %s, on %s" % [label,hops,twirls,landings,lowest,jumped,str(off),str(stranded),rider.riding_on])
	check(hops >= 25 and lowest < -5.0,"%s: he hopped %d times and twirled %d riding it down the dip (to %.0f m)" % [label,hops,twirls,lowest])
	check(landings >= hops-1 and rider.riding_on == "serpent","%s: every hop comes down on its back (%d of %d)" % [label,landings,hops])
	check(not off and not stranded,"%s: no hop counts as off the isle's edge or strands him" % [label])
	check(jumped < 3.0,"%s: nothing moves him in a frame (at most %.2f m)" % [label,jumped])
	check(lost_aside,"%s: the respawn floor stays set aside while he rides and hops" % label)
