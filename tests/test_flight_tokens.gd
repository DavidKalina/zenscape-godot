extends SceneTree
## The flight study's token-placement pack (scripts/flight_pack_tokens.gd),
## headless: it comes after the main stations, which keep their order; its
## stations have no key and their own origins, copy their geometry's parts
## unchanged and differ only in their tokens; guides shape the line but
## aren't counted; bonus tokens are taken on the way, never missed, not
## needed to clear, and the bot goes for one only when that costs it no
## token; the study keeps N inside the pack and draws neither guides nor
## taken bonus tokens.
##   godot --headless --path . --script tests/test_flight_tokens.gd
const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("flight tokens test timed out"); quit(2))
	# The pack: after the main stations, keyless, at its own origins.
	var pack := Course.pack("tokens")
	check(pack.size() == 9,"The tokens pack has 9 stations (%d)" % pack.size())
	check(Course.STATIONS[10].id == "sundered_mix" and Course.STATIONS.find(pack[0]) > 10,"It comes after the main stations, which keep their order")
	var origins := {}
	var keyless := true
	for s: Dictionary in pack:
		keyless = keyless and str(s.id).begins_with("tokens_") and int(s.key) == Course.NO_KEY and Course.key_name(s) == ""
		origins[Course.origin(s)] = true
	check(keyless and Course.station_by_key(Course.NO_KEY).is_empty(),"Its stations are tokens_*, with no key")
	check(origins.size() == pack.size() and Course.origin(pack[0]) == pack[0].origin,"Each stands at its own origin")
	# Same geometry, different tokens.
	var hall := Course.station("sundered_flow")
	var swoop := Course.station("open_swoop")
	var same := true
	for s: Dictionary in pack:
		var source: Dictionary = hall if str(s.id).begins_with("tokens_hall") else swoop
		same = same and s.parts == source.parts
	check(same,"Every pack station copies its geometry's parts unchanged")
	var dense := Course.station("tokens_hall_dense")
	check(dense.tokens == hall.tokens and Course.station_hash(dense) == Course.station_hash(hall),"The hall's dense baseline is sundered_flow's own trail (same hash)")
	var gates := Course.station("tokens_hall_gates")
	check(gates.tokens == hall.tokens and Course.station_hash(gates) != Course.station_hash(hall),"Gate-only shares the route; its guides change the hash")
	for s: Dictionary in pack:
		var all := Course.solids(s)
		var inside := 0
		for p in Course.bonus(s):
			if Course.clearance(all,p) < 0.5: inside += 1
		check(inside == 0,"%s: every bonus token stands clear of the solids" % s.id)
	# Guides: the sharp bot clears the gate-only hall, counting only the 9.
	var stage := Node3D.new()
	root.add_child(stage)
	Course.build(gates,stage)
	var lane := {"id":"tokens_test","key":-1,"pack":"tokens_test","origin":Vector3(0.0,40.0,-3000.0),"name":"Bonus lane","intent":"","parts":[],
		"tokens":[Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-24.0),Vector3(0.0,0.0,-36.0),Vector3(0.0,0.0,-58.0)],"guides":[1],
		"bonus":[Vector3(0.6,0.0,-30.0),Vector3(2.8,0.0,-42.0),Vector3(40.0,0.0,-20.0)]}
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	var g: Dictionary = Bench.fly(gates,"sharp",Bot.skill("sharp"),3,space)
	check(g.metrics.cleared and int(g.metrics.total) == 9 and int(g.result.total) == 9 and g.guides.size() == 12,
		"The sharp bot clears gate-only: %d/%d tokens, the 12 guides not counted" % [g.metrics.collected,g.metrics.total])
	# Bonus tokens: one on the way (taken), one a little off it (the bot
	# goes for it), one far off (never); none needed to clear.
	var b: Dictionary = Bench.fly(lane,"sharp",Bot.skill("sharp"),1,space)
	var bm: Dictionary = b.metrics
	check(bm.cleared and int(bm.total) == 3 and int(bm.bonus_total) == 3 and int(bm.bonus_taken) == 2,
		"Straight down the lane: 3/3 tokens, 2 of 3 bonus (%d/%d, bonus %d)" % [bm.collected,bm.total,bm.bonus_taken])
	var shy := Bot.skill("sharp")
	shy["bonus"] = false
	var sm: Dictionary = Bench.fly(lane,"sharp",shy,1,space).metrics
	check(sm.cleared and int(sm.bonus_taken) == 1,"Told to ignore them, it takes only the one on its way (%d)" % sm.bonus_taken)
	var flat := lane.duplicate(true)
	flat.erase("bonus")
	var fm: Dictionary = Bench.fly(flat,"sharp",Bot.skill("sharp"),1,space).metrics
	check(not fm.has("bonus_total") and not Metrics.summarise(g).has("bonus_total"),"A station with no bonus tokens gets no bonus numbers")
	# The bot never trades a token it needs for a bonus.
	var greedy := lane.duplicate(true)
	greedy.tokens = [Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-24.0),Vector3(0.0,0.0,-36.0)]
	greedy.guides = []
	greedy.bonus = [Vector3(6.0,0.0,-26.0)]
	var gm: Dictionary = Bench.fly(greedy,"sharp",Bot.skill("sharp"),1,space).metrics
	check(gm.cleared and int(gm.bonus_taken) == 0,"A bonus behind a token it needs isn't worth a miss (%d/%d, bonus %d)" % [gm.collected,gm.total,gm.bonus_taken])
	# The study: N stays inside the pack; guides and taken bonus not drawn.
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_test_tokens"
	root.add_child(study)
	while not study.flight_ready: await process_frame
	study.pack = "tokens"
	study.start(pack.back())
	study.next_station()
	check(study.station == pack[0],"With --pack=tokens, N from the last pack station wraps to its first")
	study.start(Course.station("tokens_hall_hidden"))
	var shown: int = study._token_nodes.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()
	check(shown == 9 and study._bonus_nodes.size() == 5,"Only the 9 tokens and the 5 bonus are drawn (%d shown)" % shown)
	study.pack = ""
	study.start(Course.station("sundered_mix"))
	study.next_station()
	check(study.station == pack[0],"Without --pack, N goes on from the main stations into the pack")
	print("flight tokens: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
