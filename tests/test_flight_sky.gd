extends SceneTree
## The flight study's sky pack (scripts/flight_pack_sky.gd), headless: its
## stations come after the course's own, with no digit key, reachable as a
## pack; each keeps its pinned hash; each stands, the sharp bot clears it
## without a bump, and its perfect line keeps swinging (the round-3 flow
## numbers) while threading something. A spiral's late tokens aren't missed
## on the first tick (its `miss_near`).
##   godot --headless --path . --script tests/test_flight_sky.gd
const Course = preload("res://scripts/flight_course.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Run = preload("res://scripts/flight_run.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("flight sky test timed out"); quit(2))
	var pack := Course.pack("sky")
	check(pack.size() >= 3,"The sky pack has its stations (%d)" % pack.size())
	check(Course.STATIONS[10].id == "sundered_mix" and Course.STATIONS.find(pack[0]) > 10,"They come after the course's own, which keep their places")
	for s: Dictionary in pack:
		check(str(s.id).begins_with("sky_") and Course.key_name(s) == "","%s: a sky_ id and no digit key" % s.id)
	check(Course.station_by_key(Course.PackSky.NO_KEY).is_empty(),"No key reaches a pack's station")
	var pinned := {"sky_weave":"96e136265314","sky_spire":"848860adf76c","sky_spans":"05b9767b3537","sky_pierced":"14e3dda676fe"}
	for id: String in pinned:
		check(Course.station_hash(Course.station(id)) == pinned[id],"%s keeps its hash %s (%s)" % [id,pinned[id],Course.station_hash(Course.station(id))])
	var stage := Node3D.new()
	root.add_child(stage)
	for s: Dictionary in pack: Course.build(s,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	for s: Dictionary in pack:
		var fresh := Run.new(s,"bot:sharp",{},space)
		fresh.tick(1.0/60.0,{})
		check(fresh.next_token() == 0 and fresh.events.filter(func(e: Dictionary) -> bool: return e.kind == "miss").is_empty(),"%s: no token is missed on the first tick" % s.id)
		var m: Dictionary = Bench.fly(s,"sharp",Bot.skill("sharp"),3,space).metrics
		check(m.cleared and int(m.bumps) == 0,"%s: the sharp bot clears it clean (%d/%d in %.2f s, %d bumps)" % [s.id,m.collected,m.total,m.duration,m.bumps])
		var params := Bot.skill("perfect")
		params.look = 7.0
		var ref: Dictionary = Bench.fly(s,"perfect",params,0,space).metrics
		check(float(ref.still_share) <= 0.15 and float(ref.longest_straight) <= 1.2,"%s: the perfect line keeps swinging (still %.2f, longest %.2f s)" % [s.id,ref.still_share,ref.longest_straight])
		check(float(ref.threading_share) >= 0.15 and float(ref.openings_per_s) >= 0.25,"%s: and threads things (%.2f of the run, %.2f openings/s)" % [s.id,ref.threading_share,ref.openings_per_s])
	print("flight sky: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
