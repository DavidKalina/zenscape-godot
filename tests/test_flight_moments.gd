extends SceneTree
## The flight study's moments pack (scripts/flight_pack_moments.gd), headless:
## it comes after the other packs, keyless, at its own origins, each station
## a liked station's stone and trail unchanged, the trail all guides (the
## natural line), its hashes pinned; free moments are taken on the way and
## never missed, challenge ones only once the starter is taken; the
## challenge ends complete, timed out, left or with the pass, never as a
## penalty, and "chain" brings its collectibles one at a time; the three
## axes are measured (scripts/flight_moments.gd); the sharp bot flies every
## station without getting stuck; the bench gives each collectible a band;
## the study draws the three roles and counts "free x/y, challenge x/y".
##   godot --headless --path . --script tests/test_flight_moments.gd
const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Moments = preload("res://scripts/flight_moments.gd")
const DT := 1.0/60.0
## The pack's stations, their sources and pinned hashes.
const SOURCES := {"moments_hall":"tokens_hall_gates","moments_bend":"lines_bend","moments_cave":"nature_cave",
	"moments_pierced":"sky_pierced","moments_crest":"lines_crest"}
const PINS := {"moments_hall":"bebd38402d9e","moments_bend":"2933e851fa40","moments_cave":"9519bf433092","moments_pierced":"9c9d823d5783","moments_crest":"1efe8caa5e81"}
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## A straight lane north for made-up moments: its line of tokens (all
## guides), no stone.
func lane(moments: Array, challenge := {}) -> Dictionary:
	var s := {"id":"moments_test","key":-1,"pack":"moments_test","origin":Vector3(0.0,40.0,-4000.0),"name":"Moments lane","intent":"","parts":[],
		"tokens":[Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-30.0),Vector3(0.0,0.0,-50.0),Vector3(0.0,0.0,-70.0),Vector3(0.0,0.0,-90.0)],"moments":moments}
	if not challenge.is_empty(): s["challenge"] = challenge
	return s

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("flight moments test timed out"); quit(2))
	# The pack: after the other packs, keyless, at its own origins.
	var pack := Course.pack("moments")
	check(pack.size() == SOURCES.size(),"The moments pack has %d stations (%d)" % [SOURCES.size(),pack.size()])
	check(Course.STATIONS.find(pack[0]) > Course.STATIONS.find(Course.pack("tokens").back()),"It comes after the other packs")
	var origins := {}
	var plain := true
	for s: Dictionary in pack:
		plain = plain and str(s.id).begins_with("moments_") and int(s.key) == Course.NO_KEY and Course.key_name(s) == ""
		origins[Course.origin(s)] = true
	check(plain and origins.size() == pack.size(),"Its stations are moments_*, with no key, each at its own origin")
	# The liked stations' stone and trail, unchanged; the trail all guides.
	for id: String in SOURCES:
		var s := Course.station(id)
		var from := Course.station(SOURCES[id])
		# As laid, the source's stone and line; in the game, the same re-laid in
		# the game's hall (FlightCourse `_game_hall`: a hall station's bays at
		# the game's BAY and ROW_Z).
		var laid: Dictionary = Course.LAID.filter(func(l: Dictionary) -> bool: return l.id == id)[0]
		var laid_from: Dictionary = Course.LAID.filter(func(l: Dictionary) -> bool: return l.id == SOURCES[id])[0]
		check(laid.parts == laid_from.parts and laid.tokens == laid_from.tokens and str(s.from) == SOURCES[id],"%s keeps %s's stone and line" % [id,SOURCES[id]])
		check(s == Course._game_hall(laid),"%s stands in the game's hall (its bays %.2f m)" % [id,Course.Hall.BAY])
		check(Course.guides(s).size() == (s.tokens as Array).size(),"%s: its line is all guides" % id)
		var roles := (s.moments as Array).map(func(m: Dictionary) -> String: return str(m.get("role","free")))
		check(roles.count("starter") == 1 and roles.count("free") >= 2 and roles.count("free") <= 5 and roles.count("challenge") >= 2,
			"%s: one starter, 2-5 free moments, challenge ones (%s)" % [id,roles])
		var kinds := (s.moments as Array).filter(func(m: Dictionary) -> bool: return str(m.get("role","")) != "starter").map(func(m: Dictionary) -> String: return str(m.kind))
		check(kinds.all(func(k: String) -> bool: return k in Moments.KINDS),"%s: every moment is fit, react or reach" % id)
		var all := Course.solids(s)
		var inside := (Course.moments(s) as Array).filter(func(m: Dictionary) -> bool: return Course.clearance(all,m.at) < 0.25)
		check(inside.is_empty(),"%s: every moment stands clear of the stone" % id)
		# The pin is the station as laid (re-laid in the game's hall its hash
		# follows the plane's and the opening ratio's sizes).
		var laid_s: Dictionary = Course.LAID.filter(func(l: Dictionary) -> bool: return l.id == id)[0]
		if PINS[id] != "": check(Course.station_hash(laid_s) == PINS[id],"%s keeps its hash %s as laid (%s)" % [id,PINS[id],Course.station_hash(laid_s)])
	var stage := Node3D.new()
	root.add_child(stage)
	for s: Dictionary in pack: Course.build(s,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	# A pass: the free one on the way taken, a challenge one before the
	# starter not there to take, the starter, a challenge one after it.
	var line := lane([
		{"at":Vector3(0.0,0.0,-20.0),"role":"challenge","kind":"fit"},
		{"at":Vector3(0.0,0.0,-34.0),"role":"starter","kind":""},
		{"at":Vector3(0.0,0.0,-55.0),"role":"challenge","kind":"reach"},
		{"at":Vector3(0.3,0.0,-64.0),"role":"free","kind":"react"},
		{"at":Vector3(40.0,0.0,-40.0),"role":"free","kind":"reach"},
	])
	var r: Dictionary = Bench.fly(line,"sharp",Bot.skill("sharp"),1,space)
	var m: Dictionary = r.metrics
	check(int(r.result.total) == 0 and int(m.total) == 0 and str(r.result.ended) == "done","Nothing to clear: the line is all guides, flown to its end")
	check(int(m.free_total) == 2 and int(m.free_taken) == 1,"Free: the one on the way taken, the far one not (%d/%d)" % [m.free_taken,m.free_total])
	check(int(m.challenge_total) == 2 and int(m.challenge_taken) == 1 and int(m.challenge_tries) == 1,"Challenge: started once, the one after the starter taken, the one before never there (%d/%d)" % [m.challenge_taken,m.challenge_total])
	check(str(r.result.challenge_ended) == "over" and 0 not in (m.moments_got as Array),"It ends with the pass, the early one never taken (%s)" % r.result.challenge_ended)
	# Complete: every challenge collectible taken.
	var both := lane([{"at":Vector3(0.0,0.0,-34.0),"role":"starter"},{"at":Vector3(0.0,0.0,-50.0),"role":"challenge","kind":"fit"},{"at":Vector3(0.0,0.0,-66.0),"role":"challenge","kind":"fit"}])
	r = Bench.fly(both,"sharp",Bot.skill("sharp"),1,space)
	check(str(r.result.challenge_ended) == "complete" and bool(r.metrics.challenge_complete),"Taking every challenge collectible completes it")
	# Timed: 0.5 s is not enough to reach the next 16 m on; the starter
	# stands again and the challenge ones go.
	var timed := both.duplicate(true)
	timed["challenge"] = {"time":0.5}
	var tr := Run.new(timed,"bot:sharp",Bot.skill("sharp"),space)
	var bot := Bot.new(Bot.skill("sharp"),1)
	var ended := ""
	var starter_back := false
	while not tr.done:
		tr.tick(DT,bot.input(tr,DT))
		if ended == "" and tr.challenge == "timeout":
			ended = tr.challenge
			starter_back = tr.moment_state[0] == 0 and tr.moment_live[1] == 0 and tr.moment_live[2] == 0
	check(ended == "timeout" and starter_back,"With a time limit it ends; the starter stands again and the challenge ones go")
	check(not Course.station_hash(timed) == Course.station_hash(both),"A timed variant is its own record (hash)")
	# Left: a challenge collectible far off the line, the area small: going
	# for it leaves the area, and the challenge ends.
	var far := lane([{"at":Vector3(0.0,0.0,-30.0),"role":"starter"},{"at":Vector3(9.0,0.0,-55.0),"role":"challenge","kind":"reach"}],{"area":4.0})
	r = Bench.fly(far,"sharp",Bot.skill("sharp"),1,space)
	check(str(r.result.challenge_ended) == "left" and int(r.metrics.challenge_taken) == 0,"Straying past its area ends it (%s)" % r.result.challenge_ended)
	# Chain: one challenge collectible at a time.
	var chain := both.duplicate(true)
	chain["challenge"] = {"mode":"chain"}
	var cr := Run.new(chain,"bot:sharp",Bot.skill("sharp"),space)
	var cb := Bot.new(Bot.skill("sharp"),1)
	var one_at_a_time := false
	while not cr.done:
		cr.tick(DT,cb.input(cr,DT))
		if cr.challenge == "on" and cr.moment_state[1] == 0: one_at_a_time = cr.moment_live[1] == 1 and cr.moment_live[2] == 0
	check(one_at_a_time and cr.challenge == "complete","Chain: the next only after the one before, and it completes")
	# Old stations get no moment numbers.
	var old: Dictionary = Bench.fly(Course.station("gentle_arc"),"sharp",Bot.skill("sharp"),1,null)
	check(not old.metrics.has("free_total") and not old.has("moments") and old.metrics.cleared,"A station without moments flies and counts as before")
	# The three axes.
	var probe := lane([{"at":Vector3(4.0,0.0,-50.0),"role":"free","kind":"reach"},{"at":Vector3(0.0,0.0,-70.0),"role":"free","kind":"fit"}])
	var rows := Moments.measure(probe,null)
	check(absf(float(rows[0].off)-4.0) < 0.1 and absf(float(rows[0].beyond)-(4.0-Course.REACH)) < 0.1 and float(rows[0].fit) == Moments.OPEN,
		"Reach: 4 m off the line, %.2f beyond the pickup; fit open (%.2f, %.2f)" % [4.0-Course.REACH,rows[0].off,rows[0].fit])
	check(float(rows[0].react) > 2.0 and float(rows[1].react) > float(rows[0].react),"React: seen from the entry, seconds to spare (%.2f, %.2f)" % [rows[0].react,rows[1].react])
	var walled := probe.duplicate(true)
	walled.parts = [["box",Vector3(3.0,0.0,-46.0),Vector3(4.0,10.0,1.0),0.0]]
	rows = Moments.measure(walled,null)
	check(float(rows[0].react) < 0.0 and not rows[0].seen,"Behind a wall it is never seen from the line: react below 0 (%.2f)" % rows[0].react)
	check(Moments.band({"sloppy":0.2,"decent":0.6,"sharp":1.0}) == "medium" and Moments.band({"sloppy":0.0,"decent":0.0,"sharp":0.0,"perfect":0.0}) == "none","A collectible's band: the least skill getting it in 60% of runs")
	# The sharp bot flies every station to its end, never stuck.
	for s: Dictionary in pack:
		var flown: Dictionary = Bench.fly(s,"sharp",Bot.skill("sharp"),7,space)
		check(str(flown.result.ended) == "done" and int(flown.metrics.free_taken) >= 1,"%s: the sharp bot flies it to the end (%s, %.1f s, free %d/%d, challenge %d/%d)" % [s.id,flown.result.ended,
			float(flown.metrics.duration),flown.metrics.free_taken,flown.metrics.free_total,flown.metrics.challenge_taken,flown.metrics.challenge_total])
	# The bench: a band per collectible.
	var bench: Dictionary = Bench.bench(PackedStringArray(["moments_cave"]),PackedStringArray(["sharp","perfect"]),2,space,"user://flight_runs_test_moments",false)
	var row: Dictionary = bench.stations.moments_cave
	check(str(row.band) == "moments" and (row.moments as Array).size() == (Course.station("moments_cave").moments as Array).size(),"The bench bands each collectible, not the station")
	check(Bench.moments_table(bench).contains("moments_cave"),"And prints them as a table")
	# The study: three looks, the challenge ones hidden until the starter.
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_test_moments"
	root.add_child(study)
	while not study.flight_ready: await process_frame
	study.pack = "moments"
	study.start(Course.station("moments_cave"))
	for i in range(2): study.tick(DT)
	var shown: int = study._moment_nodes.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()
	var cave: Array = Course.station("moments_cave").moments
	var challenges := cave.filter(func(x: Dictionary) -> bool: return x.role == "challenge").size()
	check(study._moment_nodes.size() == cave.size() and shown == cave.size()-challenges,"Free ones and the starter drawn, the challenge ones not yet (%d shown)" % shown)
	check(study._moment_nodes.filter(func(n: MeshInstance3D) -> bool: return n.mesh is TorusMesh).size() == 1,"The starter is a ring")
	check(study.moment_line(study.run.live()).begins_with("free 0/%d, challenge 0/%d" % [cave.size()-challenges-1,challenges]),"The count reads \"free x/y, challenge x/y\"")
	study.challenge_override = {"time":12.0}
	study.start(Course.station("moments_cave"))
	check(float(study.run.challenge_rules.time) == 12.0 and float(Course.challenge(Course.station("moments_cave")).time) == 0.0,"--challenge-time flies a timed variant; the station's own has none")
	study.challenge_override = {}
	study.start(pack.back())
	study.next_station()
	check(study.station == pack[0],"With --pack=moments, N from the last pack station wraps to its first")
	print("flight moments: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
