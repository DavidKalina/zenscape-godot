extends SceneTree
## The flight study's bench: CPU pilots (scripts/flight_bot.gd) fly the
## stations (scripts/flight_course.gd), headless, every run recorded and
## measured as a person's is (scripts/flight_run.gd), and each station gets
## its band: the least skill that clears it (FlightMetrics `band`). Each
## skill but the perfect reference flies `--runs` times with its own noise;
## the perfect reference flies once at each of FlightBot PERFECT_LOOKS and
## its best run is kept (the reference line in the report).
##
##   godot --headless --path . -s tools/flight_bench.gd -- --station all --runs 10
##   options: --station id[,id] | all   --runs N (default 10; 20 gives
##            steadier bands, about 7 s)   --skills sloppy,decent,...
##            --out user://dir (default user://flight_runs)   --no-save (no run files)
##            --pack name (a pack's stations, e.g. tokens)   --no-bonus (bots
##            ignore bonus tokens: the main line alone)
##
## Writes each run's JSON, a summary (bench_<when>.json) and the bands
## (bands.json, read by the study's end-of-run report), and prints a table.

const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Log = preload("res://scripts/flight_log.gd")

const DT := 1.0/60.0

## The last bench's summary, for tests.
var summary := {}

func _initialize() -> void:
	run.call_deferred()

func _args() -> Dictionary:
	var out := {"station":"all","runs":10,"skills":",".join(Metrics.SKILLS),"out":Log.DIR,"save":true}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a == "--no-save": out.save = false
		elif a == "--no-bonus": out["bonus"] = false
		elif a.begins_with("--") and i+1 < args.size():
			var key := a.substr(2)
			var value := args[i+1]
			if a.contains("="):
				key = a.substr(2,a.find("=")-2)
				value = a.substr(a.find("=")+1)
			else:
				i += 1
			out[key] = value
		elif a.begins_with("--") and a.contains("="):
			out[a.substr(2,a.find("=")-2)] = a.substr(a.find("=")+1)
		i += 1
	return out

func run() -> void:
	var args := _args()
	var ids: PackedStringArray = Course.ids() if str(args.station) == "all" else str(args.station).split(",")
	if args.has("pack"): ids = PackedStringArray(Course.pack(str(args.pack)).map(func(s: Dictionary) -> String: return s.id))
	var skills := str(args.skills).split(",")
	var stage := Node3D.new()
	root.add_child(stage)
	for id in ids:
		var s := Course.station(id)
		if s.is_empty():
			push_error("no station %s" % id)
			quit(1)
			return
		Course.build(s,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	summary = bench(ids,skills,int(args.runs),space,str(args.out),bool(args.save),bool(args.get("bonus",true)))
	quit(0)

## Flies every station in `ids` with every skill; returns the summary.
static func bench(ids: PackedStringArray, skills: PackedStringArray, runs: int, space: PhysicsDirectSpaceState3D, dir: String, save: bool, bonus := true) -> Dictionary:
	var began := Time.get_ticks_msec()
	var stations := {}
	var bands := {}
	for id in ids:
		var s := Course.station(id)
		var row := {"id":id,"name":s.name,"intent":s.intent,"hash":Course.station_hash(s),"skills":{}}
		var clears := {}
		for name in skills:
			var flown := []
			if name == "perfect":
				var best := {}
				for look: float in Bot.PERFECT_LOOKS:
					var params := Bot.skill("perfect")
					params.look = look
					if not bonus: params["bonus"] = false
					var r := fly(s,"perfect",params,0,space)
					if best.is_empty() or _better(r,best): best = r
				flown.append(best)
			else:
				for n in range(runs):
					var params := Bot.skill(name)
					if not bonus: params["bonus"] = false
					flown.append(fly(s,name,params,hash([id,name,n]),space))
			if save:
				for r: Dictionary in flown: Log.save(r,dir)
			var stats := _stats(flown)
			row.skills[name] = stats
			clears[name] = stats.clear_rate
			if name == "perfect": row["reference"] = _reference(flown[0])
		row["band"] = Metrics.band(clears)
		row["clears"] = clears
		stations[id] = row
		bands[id] = {"hash":row.hash,"band":row.band,"clears":clears,"when":Time.get_datetime_string_from_system(true)+"Z",
			"reference":row.get("reference",{})}
	var out := {"kind":"bench","when":Time.get_datetime_string_from_system(true)+"Z","runs":runs,"skills":Array(skills),"stations":stations,
		"seconds":snappedf((Time.get_ticks_msec()-began)/1000.0,0.01)}
	if save:
		var stamp := str(out.when).replace(":","").replace("-","").replace("Z","")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		Log.write("%s/bench_%s.json" % [dir,stamp],out)
		Log.save_bands(bands,dir)
		print("flight bench saved: %s" % ProjectSettings.globalize_path("%s/bench_%s.json" % [dir,stamp]))
	print(table(out))
	print(flow_table(out))
	print(knife_table(out))
	var tokens := pack_table(out)
	if tokens != "": print(tokens)
	return out

## One bot run of station `s`.
static func fly(s: Dictionary, name: String, params: Dictionary, seed_value: int, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var r := Run.new(s,"bot:"+name,params,space)
	var bot := Bot.new(params,seed_value)
	while not r.done: r.tick(DT,bot.input(r,DT))
	var out := r.finish()
	out["seed"] = seed_value
	return out

## Is run `a` better than `b`: cleared, more tokens, fewer bumps, quicker.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	var ma: Dictionary = a.metrics
	var mb: Dictionary = b.metrics
	if int(ma.collected) != int(mb.collected): return int(ma.collected) > int(mb.collected)
	if int(ma.bumps) != int(mb.bumps): return int(ma.bumps) < int(mb.bumps)
	return float(ma.duration) < float(mb.duration)

static func _stats(flown: Array) -> Dictionary:
	var keys := ["duration","collected","bumps","demand_peak","demand_mean","turn_flown_peak","pitch_flown_peak","reversals_per_s","effort","full_share","threading_share","openings_per_s"]+Metrics.FLOW_KEYS+["knife_clean","on_edge_s","edge_spells","total","bonus_taken","bonus_seen","bonus_total"]
	var sums := {}
	for k: String in keys: sums[k] = 0.0
	var cleared := 0
	for r: Dictionary in flown:
		var m: Dictionary = r.metrics
		if m.cleared: cleared += 1
		for k: String in keys: sums[k] += float(m.get(k,0.0))
	var out := {"runs":flown.size(),"clear_rate":snappedf(float(cleared)/maxf(flown.size(),1),0.001)}
	for k: String in keys: out[k] = snappedf(sums[k]/maxf(flown.size(),1),0.001)
	if flown.size() == 1 and flown[0].skill.has("look"): out["look"] = flown[0].skill.look
	return out

## The perfect run's numbers, without its ticks.
static func _reference(r: Dictionary) -> Dictionary:
	var m: Dictionary = r.metrics.duplicate()
	m["look"] = r.skill.get("look",0.0)
	return m

## The bench as a plain-text table.
static func table(out: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("%-13s %-7s %-8s  %-23s  %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s" % ["station","intent","band","clear sl/de/sh/pf","time","dPeak","dMean","spike","warnMn","room","thread","open/s","still","longst"])
	for id: String in out.stations:
		var row: Dictionary = out.stations[id]
		var c: Dictionary = row.clears
		var ref: Dictionary = row.get("reference",{})
		lines.append("%-13s %-7s %-8s  %-23s  %6.2f %6.2f %6.2f %6.2f %6s %6.2f %6.2f %6.2f %6.2f %6.2f" % [id,row.intent,row.band,
			"/".join(Metrics.SKILLS.map(func(k: String) -> String: return ("%.1f" % float(c[k])) if c.has(k) else "-")),
			float(ref.get("duration",0.0)),float(ref.get("demand_peak",0.0)),float(ref.get("demand_mean",0.0)),float(ref.get("demand_spike",0.0)),
			("%.2f" % float(ref.warning_min)) if ref.get("warning_min") != null else "-",float(ref.get("room_min",0.0)) if ref.get("room_min") != null else 0.0,
			float(ref.get("threading_share",0.0)),float(ref.get("openings_per_s",0.0)),float(ref.get("still_share",0.0)),float(ref.get("longest_straight",0.0))])
	return "\n".join(lines)

## Flow per station (FlightMetrics `flow`): the perfect reference's line,
## its demand beside it, then each skill's mean still share and swing
## reversals (the jerkiness guard: a wobbling bot reverses often).
static func flow_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["flow (perfect reference; still/rev per skill sl/de/sh)"])
	lines.append("%-13s %6s %6s %6s  %6s %5s %6s %6s %6s %6s %6s  %-17s %-17s" % ["station","time","dPeak","dMean","still","str","longst","swing","yaw","rev/s","open/s","still sl/de/sh","rev/s sl/de/sh"])
	for id: String in out.stations:
		var row: Dictionary = out.stations[id]
		var ref: Dictionary = row.get("reference",{})
		var per := func(key: String, fmt: String) -> String:
			var bits := PackedStringArray()
			for k: String in ["sloppy","decent","sharp"]:
				bits.append((fmt % float(row.skills[k][key])) if row.skills.has(k) else "-")
			return "/".join(bits)
		lines.append("%-13s %6.2f %6.2f %6.2f  %5d%% %5d %6.2f %6.1f %5d%% %6.2f %6.2f  %-17s %-17s" % [id,float(ref.get("duration",0.0)),float(ref.get("demand_peak",0.0)),
			float(ref.get("demand_mean",0.0)),roundi(float(ref.get("still_share",0.0))*100.0),int(ref.get("straights",0)),float(ref.get("longest_straight",0.0)),
			float(ref.get("swing_mean",0.0)),roundi(float(ref.get("yaw_share",0.0))*100.0),float(ref.get("swing_reversals_per_s",0.0)),float(ref.get("openings_per_s",0.0)),
			per.call("still_share","%.2f"),per.call("swing_reversals_per_s","%.1f")])
	return "\n".join(lines)

## The knife edge per station with knife zones (FlightMetrics `knife`): the
## zones, the perfect reference's warning before them and how long it was
## on edge on arrival, then each skill's mean zones passed clean and time on
## edge.
static func knife_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["knife edge (perfect reference; clean zones and s on edge per skill sl/de/sh/pf)"])
	lines.append("%-13s %6s %7s %7s %6s  %-23s %-23s" % ["station","zones","warnMn","warnAv","lead","clean sl/de/sh/pf","on edge s sl/de/sh/pf"])
	var any := false
	for id: String in out.stations:
		var row: Dictionary = out.stations[id]
		var ref: Dictionary = row.get("reference",{})
		if int(ref.get("knife_moments",0)) == 0: continue
		any = true
		var per := func(key: String) -> String:
			var bits := PackedStringArray()
			for k: String in Metrics.SKILLS:
				bits.append(("%.2f" % float(row.skills[k][key])) if row.skills.has(k) else "-")
			return "/".join(bits)
		var num := func(v: Variant) -> String: return ("%.2f" % float(v)) if v != null else "-"
		lines.append("%-13s %6d %7s %7s %6s  %-23s %-23s" % [id,int(ref.knife_moments),num.call(ref.get("knife_warning_min")),num.call(ref.get("knife_warning_mean")),
			num.call(ref.get("knife_lead")),per.call("knife_clean"),per.call("on_edge_s")])
	if not any: lines.append("(no station with knife zones)")
	return "\n".join(lines)

## The token-placement comparison, for a pack's stations (FlightCourse
## `pack`; scripts/flight_pack_tokens.gd): per station its style, tokens to
## take (guides not counted) and bonus tokens, the clear rate per skill, the
## perfect reference's threading, flow and demand, and per skill the mean
## bonus tokens seen and taken, and bumps. "" when no station in the bench
## is a pack's.
static func pack_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["token placement (reference = perfect; per skill sl/de/sh/pf)"])
	lines.append("%-14s %-8s %4s %4s  %-19s %6s %6s %6s %6s %6s %6s %6s  %-15s %-15s %-19s" % ["station","style","req","bon","clear","time","thread","open/s","still","longst","dPeak","dMean","bonus taken","bonus seen","bumps"])
	var any := false
	for id: String in out.stations:
		var s := Course.station(id)
		if not s.has("pack"): continue
		any = true
		var row: Dictionary = out.stations[id]
		var ref: Dictionary = row.get("reference",{})
		var per := func(key: String, fmt: String) -> String:
			var bits := PackedStringArray()
			for k: String in Metrics.SKILLS:
				bits.append((fmt % float(row.skills[k].get(key,0.0))) if row.skills.has(k) else "-")
			return "/".join(bits)
		var bonus := (s.get("bonus",[]) as Array).size()
		lines.append("%-14s %-8s %4d %4d  %-19s %6.2f %5d%% %6.2f %5d%% %6.2f %6.2f %6.2f  %-15s %-15s %-19s" % [id.trim_prefix("tokens_"),str(s.get("style","")),
			(s.tokens as Array).size()-(s.get("guides",[]) as Array).size(),bonus,per.call("clear_rate","%.2f"),float(ref.get("duration",0.0)),
			roundi(float(ref.get("threading_share",0.0))*100.0),float(ref.get("openings_per_s",0.0)),roundi(float(ref.get("still_share",0.0))*100.0),
			float(ref.get("longest_straight",0.0)),float(ref.get("demand_peak",0.0)),float(ref.get("demand_mean",0.0)),
			per.call("bonus_taken","%.1f") if bonus > 0 else "-",per.call("bonus_seen","%.1f") if bonus > 0 else "-",per.call("bumps","%.1f")])
	return "\n".join(lines) if any else ""
