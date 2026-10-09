extends SceneTree
## The flight study's bench (tools/flight_bench.gd), headless: the sharp bot
## clears the gentle arc; a run's recorded inputs, fed back through a fresh
## run as a person's keys would be, fly the same line (the recorder keeps
## everything the plane was given); a run saves and reads back as JSON; and
## a short bench of the gentle arc lands it in a band and writes the bands
## file the study's report reads; the Sundered hall station stands and the
## sharp bot clears it; so does the flowing hall (sundered_flow), whose
## reference line hardly ever flies straight; the knife-edge bot threads a
## lone slit on edge (and bumps it held level); the mixed hall
## (sundered_mix) stands on the - key and the sharp bot clears it; the
## nature pack (scripts/flight_pack_nature.gd) stands, keyless, and the
## sharp bot clears each of its stations clean.
##   godot --headless --path . --script tests/test_flight_bench.gd
const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Log = preload("res://scripts/flight_log.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const DIR := "user://flight_runs_test"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("flight bench test timed out"); quit(2))
	var stage := Node3D.new()
	root.add_child(stage)
	var arc := Course.station("gentle_arc")
	Course.build(arc,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	# The sharp bot clears the gentle arc.
	var sharp := Bench.fly(arc,"sharp",Bot.skill("sharp"),7,space)
	var m: Dictionary = sharp.metrics
	check(m.cleared and int(m.collected) == arc.tokens.size(),"The sharp bot clears the gentle arc (%d/%d in %.2f s)" % [m.collected,m.total,m.duration])
	check(float(m.duration) > 4.0 and float(m.duration) < 10.0,"It takes a few seconds (%.2f s)" % m.duration)
	check(sharp.ticks.t.size() == sharp.ticks.in_turn.size() and sharp.ticks.t.size() > 200,"Every tick is recorded (%d)" % sharp.ticks.t.size())
	check(float(m.turn_need_peak) > 0.1 and float(m.turn_need_peak) < 0.6,"The arc asks a gentle turn of the line (%.2f of TURN_RATE)" % m.turn_need_peak)
	# Replayed through a fresh run as plain input dicts, the same line.
	var replay := Run.new(arc,"human",{},space)
	var tk: Dictionary = sharp.ticks
	for i in range(1,tk.t.size()):
		var dt := float(tk.t[i])-float(tk.t[i-1])
		replay.tick(dt,{"turn":tk.in_turn[i],"pitch":tk.in_pitch[i],"boost":tk.in_boost[i],"brake":tk.in_brake[i],"lean":tk.in_lean[i],"roll":tk.in_roll[i]})
	var end := Vector3(tk.x.back(),tk.y.back(),tk.z.back())
	check(replay.plane.position.distance_to(end) < 0.3 and replay.collected() == int(m.collected),"Its inputs replayed fly the same line (%.3f m apart, %d tokens)" % [replay.plane.position.distance_to(end),replay.collected()])
	# Saved and read back.
	var path := Log.save(sharp,DIR)
	var back := Log.read(path)
	check(str(back.get("station","")) == "gentle_arc" and str(back.get("pilot","")) == "bot:sharp" and str(back.get("station_hash","")) == Course.station_hash(arc),"A run saves as JSON and reads back (%s)" % path.get_file())
	check((back.ticks.t as Array).size() == tk.t.size() and back.metrics.has("curve") and back.has("started"),"With its ticks, its numbers and when it was flown")
	# A short bench: a band, and the bands file.
	var bench: Dictionary = Bench.bench(PackedStringArray(["gentle_arc"]),PackedStringArray(["sloppy","sharp","perfect"]),2,space,DIR,true)
	var row: Dictionary = bench.stations.gentle_arc
	check(str(row.band) in ["easy","medium","hard"],"The gentle arc lands in a band a bot clears (%s)" % row.band)
	check(float(row.clears.sharp) >= 1.0 and float(row.clears.perfect) >= 1.0,"Sharp and perfect clear it every time")
	var bands := Log.bands(DIR)
	check(bands.has("gentle_arc") and str(bands.gentle_arc.hash) == Course.station_hash(arc),"The bands file keeps it by the station's hash")
	# The Sundered hall's greybox stands and the sharp bot threads it.
	var hall := Course.station("sundered")
	var built := Course.build(hall,stage)
	check(built.get_child_count() == Course.solids(hall).size() and built.get_child_count() > 100,"The Sundered hall station stands (%d solids)" % built.get_child_count())
	await physics_frame
	await physics_frame
	var through := Bench.fly(hall,"sharp",Bot.skill("sharp"),3,space)
	var hm: Dictionary = through.metrics
	check(hm.cleared,"The sharp bot clears the Sundered hall (%d/%d in %.2f s, %d bumps)" % [hm.collected,hm.total,hm.duration,hm.bumps])
	check(float(hm.duration) > 10.0 and float(hm.duration) < 20.0,"It takes 10-20 s (%.2f s)" % hm.duration)
	check(float(hm.threading_share) > 0.25,"Most of the hall is threaded (%.2f of the run)" % hm.threading_share)
	# The flowing hall: stands, the sharp bot clears it, and it keeps
	# swinging (the perfect line's still share and longest straight).
	var flow := Course.station("sundered_flow")
	var flowing := Course.build(flow,stage)
	check(flowing.get_child_count() == Course.solids(flow).size() and flowing.get_child_count() > 100,"The flowing hall stands (%d solids)" % flowing.get_child_count())
	check(Course.station_by_key(0) == flow,"Key 0 is the flowing hall")
	await physics_frame
	await physics_frame
	var swept := Bench.fly(flow,"sharp",Bot.skill("sharp"),3,space)
	var fm: Dictionary = swept.metrics
	check(fm.cleared,"The sharp bot clears the flowing hall (%d/%d in %.2f s, %d bumps)" % [fm.collected,fm.total,fm.duration,fm.bumps])
	check(float(fm.duration) > 10.0 and float(fm.duration) < 20.0,"It takes 10-20 s (%.2f s)" % fm.duration)
	var params := Bot.skill("perfect")
	params.look = 7.0
	var ref: Dictionary = Bench.fly(flow,"perfect",params,0,space).metrics
	check(float(ref.still_share) <= 0.1 and float(ref.longest_straight) < 0.5,"The perfect line hardly flies straight (still %.2f, longest %.2f s)" % [ref.still_share,ref.longest_straight])
	# The knife edge on a tiny layout: one hall bay whose screen stands
	# across the way, the middle token in its 1.15 m slit. The line there is
	# a knife zone; the sharp bot leans on edge in time and threads it
	# clean; told never to lean, it bumps the screen (the bump's slab turns
	# with the bank, so only a plane on edge fits).
	var slit := {"id":"knife_test","key":-1,"name":"One slit","intent":"","parts":[
		["bay",Vector3(6.0,-2.65,-24.0),0.0,{"roof":"open","screen":true,"inner":[-2.6]}],
	],"tokens":[Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-24.0),Vector3(0.0,0.0,-36.0)]}
	Course.build(slit,stage)
	await physics_frame
	await physics_frame
	var slit_line := Metrics.line(Course.origin(slit),0.0,Course.tokens(slit))
	var zones := Course.knife_zones(slit,slit_line)
	check(zones.size() == 1 and int(zones[0].gap) == 1,"The slit is one knife zone, in the gap to the middle token (%d)" % zones.size())
	var edge := Bench.fly(slit,"sharp",Bot.skill("sharp"),1,space)
	var em: Dictionary = edge.metrics
	check(em.cleared and int(em.bumps) == 0 and int(em.knife_clean) == 1,"The sharp bot threads the slit on edge (%d/%d, %d bumps, %d clean)" % [em.collected,em.total,em.bumps,em.knife_clean])
	check(em.knife_lead != null and float(em.knife_lead) > 0.2 and float(em.on_edge_s) > 0.3,"It was on edge before it got there (%s s ahead, %.2f s on edge)" % [str(em.knife_lead),em.on_edge_s])
	var level := Bot.skill("sharp")
	level.knife_lead = 0.0
	var lm: Dictionary = Bench.fly(slit,"sharp",level,1,space).metrics
	check(int(lm.bumps) > 0 and int(lm.knife_clean) == 0,"Held level the same bot bumps the screen (%d bumps)" % lm.bumps)
	# The mixed hall: stands, `-` is its key, the sharp bot clears it, and
	# its perfect line keeps swinging, mostly sideways, through both slits.
	var mix := Course.station("sundered_mix")
	var mixed := Course.build(mix,stage)
	check(mixed.get_child_count() == Course.solids(mix).size() and mixed.get_child_count() > 200,"The mixed hall stands (%d solids)" % mixed.get_child_count())
	check(Course.station_by_key(Course.MINUS_KEY) == mix and Course.key_name(mix) == "-","The - key is the mixed hall")
	await physics_frame
	await physics_frame
	var mm: Dictionary = Bench.fly(mix,"sharp",Bot.skill("sharp"),3,space).metrics
	check(mm.cleared and int(mm.knife_clean) == 2,"The sharp bot clears the mixed hall, both slits on edge (%d/%d in %.2f s, %d bumps)" % [mm.collected,mm.total,mm.duration,mm.bumps])
	var mix_params := Bot.skill("perfect")
	mix_params.look = 7.0
	var mref: Dictionary = Bench.fly(mix,"perfect",mix_params,0,space).metrics
	check(float(mref.still_share) <= 0.08 and float(mref.longest_straight) <= 0.5 and float(mref.yaw_share) >= 0.68,
		"Its perfect line hardly flies straight and swings mostly sideways (still %.2f, longest %.2f s, sideways %.2f)" % [mref.still_share,mref.longest_straight,mref.yaw_share])
	check(int(mref.knife_moments) == 2 and int(mref.knife_clean) == 2 and float(mref.duration) > 15.0 and float(mref.duration) < 22.0,
		"Two knife slits, both threaded, in %.1f s" % mref.duration)
	# The nature pack: no digit key, N cycles inside it (--pack=nature), its
	# part kinds stand, the sharp bot clears each station without a bump,
	# and each perfect line keeps swinging and goes through things.
	var pack := Course.pack("nature")
	check(pack.size() == 5 and str(pack[0].id) == "nature_canyon","The nature pack has its five stations (%d)" % pack.size())
	for st: Dictionary in pack:
		check(Course.key_name(st) == "" and Course.station_by_key(int(st.key)).is_empty(),"%s has no key" % st.id)
		var stood := Course.build(st,stage)
		check(stood.get_child_count() == Course.solids(st).size() and stood.get_child_count() > 100,"%s stands (%d solids)" % [st.id,stood.get_child_count()])
	await physics_frame
	await physics_frame
	for st: Dictionary in pack:
		var nm: Dictionary = Bench.fly(st,"sharp",Bot.skill("sharp"),3,space).metrics
		check(nm.cleared and int(nm.bumps) == 0,"The sharp bot clears %s clean (%d/%d in %.2f s, %d bumps)" % [st.id,nm.collected,nm.total,nm.duration,nm.bumps])
		var np := Bot.skill("perfect")
		np.look = 9.0
		var nr: Dictionary = Bench.fly(st,"perfect",np,0,space).metrics
		check(float(nr.still_share) <= 0.1 and float(nr.longest_straight) <= 0.8 and float(nr.threading_share) >= 0.1,
			"%s: the perfect line keeps swinging and threads (still %.2f, longest %.2f s, threading %.2f)" % [st.id,nr.still_share,nr.longest_straight,nr.threading_share])
	print("flight bench: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
