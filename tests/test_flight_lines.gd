extends SceneTree
## The flight study's lines pack (scripts/flight_pack_lines.gd), headless:
## the pack's stations come after the hand-placed ones with no key, each has
## a green, yellow and red token line flown as "id@line" with its own pinned
## hash, the branches leave and rejoin green on its very tokens, every token
## stands clear of the stone, green's orbs reach furthest and red's least;
## the sharp bot clears every line of the bending nave; and in the study N
## stays within --pack and L steps through the lines.
##   godot --headless --path . --script tests/test_flight_lines.gd
const Course = preload("res://scripts/flight_course.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("flight lines test timed out"); quit(2))
	var pack := Course.pack("lines")
	var ids := PackedStringArray(pack.map(func(s: Dictionary) -> String: return str(s.id)))
	check(ids == PackedStringArray(["lines_bend","lines_stitch","lines_crest"]),"The pack's three stations (%s)" % ", ".join(ids))
	check(Course.STATIONS.find(pack[0]) >= 11 and str(Course.STATIONS[10].id) == "sundered_mix","They come after the eleven hand-placed stations, which keep their order")
	for s: Dictionary in pack:
		check(Course.key_name(s) == "" and int(s.key) == Course.NO_KEY,"%s has no key" % s.id)
	check(Course.station_by_key(Course.NO_KEY).is_empty(),"No station answers to the no-key value")
	# Every line's hash, pinned (a changed layout starts a new record).
	var pinned := {
		"lines_bend":"382fb549e7d5","lines_bend@yellow":"21e1757fe3cb","lines_bend@red":"1dc3eb09bd1a",
		"lines_stitch":"5148095846f4","lines_stitch@yellow":"0b8cc8e5f4d2","lines_stitch@red":"cac8509ea864",
		"lines_crest":"2f67018aa042","lines_crest@yellow":"f57294c6b838","lines_crest@red":"ecddc095de46",
	}
	for id: String in pinned:
		var s := Course.station(id)
		check(not s.is_empty() and Course.station_hash(s) == pinned[id],"%s keeps its hash %s (%s)" % [id,pinned[id],Course.station_hash(s) if not s.is_empty() else "missing"])
	var bend := Course.station("lines_bend")
	var red := Course.station("lines_bend@red")
	check(Course.line_names(bend) == PackedStringArray(["green","yellow","red"]),"Green, yellow and red lines")
	check(Course.flown(bend,"green") == bend and Course.line_of(bend) == "green","Green is the station itself")
	check(red.id == "lines_bend@red" and Course.line_of(red) == "red" and Course.base_of(red) == bend,"A line flown is id@line, of its station")
	check(Course.origin(red) == Course.origin(bend) and red.parts == bend.parts,"On the same stone, in the same place")
	check(Course.station("lines_bend@blue").is_empty() and Course.flown(Course.station("slalom"),"red").is_empty(),"No such line, no station")
	check(Course.reach(bend) > Course.REACH and Course.reach(Course.station("lines_bend@yellow")) == Course.REACH and Course.reach(red) < Course.REACH,
		"Green's orbs reach furthest, yellow's as the game's, red's least (%.2f, %.2f, %.2f m)" % [Course.reach(bend),Course.REACH,Course.reach(red)])
	for s: Dictionary in pack:
		var all := Course.solids(s)
		var green := Course.tokens(s)
		for line in Course.line_names(s):
			var f := Course.flown(s,line)
			var tokens := Course.tokens(f)
			var inside := 0
			for p in tokens:
				if Course.clearance(all,p) < 0.5: inside += 1
			check(inside == 0,"%s: every token stands clear of the stone" % f.id)
			if line == "green": continue
			var shared := 0
			for p in tokens:
				if green.has(p): shared += 1
			check(tokens[0] == green[0] or line == "red" and s.id == "lines_stitch","%s starts on green's line" % f.id)
			check(tokens.back() == green.back() and shared >= 1 and shared < tokens.size(),"%s rejoins green on its very tokens (%d shared of %d)" % [f.id,shared,tokens.size()])
	# The sharp bot clears every line of the bending nave.
	var stage := Node3D.new()
	root.add_child(stage)
	Course.build(bend,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	for line in Course.line_names(bend):
		var m: Dictionary = Bench.fly(Course.flown(bend,line),"sharp",Bot.skill("sharp"),5,space).metrics
		check(m.cleared and float(m.duration) > 12.0 and float(m.duration) < 22.0,"The sharp bot clears the bending nave's %s line (%d/%d in %.1f s, %d bumps)" % [line,m.collected,m.total,m.duration,m.bumps])
	# The study: --pack keeps N within the pack, L steps through the lines.
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_test_lines"
	root.add_child(study)
	while not study.flight_ready: await process_frame
	study.pack = "lines"
	study.start(Course.flown(Course.station("lines_crest"),"yellow"))
	check(study._ghosts.size() > 0 and study._token_nodes.size() == Course.tokens(study.station).size(),"The flown line's tokens stand, the other lines' faint ones too (%d)" % study._ghosts.size())
	study.next_station()
	check(study.station.id == "lines_bend@yellow","N wraps round to the pack's first station, on the same line (%s)" % study.station.id)
	study.next_line()
	check(study.station.id == "lines_bend@red" and study.run.tokens.size() == red.tokens.size(),"L flies the next line (%s)" % study.station.id)
	study.next_line()
	check(study.station.id == "lines_bend","And round to green")
	study.pack = ""
	study.start(Course.station("sundered_mix"))
	study.next_station()
	check(study.station.id == "lines_bend","Without a pack, N goes on from the hand-placed stations into the pack")
	print("flight lines: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
