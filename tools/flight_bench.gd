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
##            --pack lines|nature|sky|tokens (every station of a pack,
##            scripts/flight_pack_*.gd; docs/design/flight-study-packs.md)
##            --out user://dir (default user://flight_runs)   --no-save (no run files)
##            --no-bonus (bots ignore bonus tokens and moments: the main line alone)
##            --moment-ease E (every moment but the starter at reach E, a
##            layout sweep; use with --no-save)
##            --crash hard|any (crash and restart, scripts/flight_crash.gd;
##            default off: bump and recover, every number as before)
##            --restart checkpoint|ring|entry   --crash-speed M (stone's
##            hard threshold, m/s into the face)
##   With crashing on, run files aren't saved (the bump-and-recover record
##   stays as it is); bands.json gets the station's crash bands under
##   "<id>:<tag>" (FlightCrash `tag`), which the study's report reads when
##   it flies the same crash rules. The crash table gives each skill's mean
##   crashes, the share of runs that ran out of time, and where on the line
##   (s at cruise) the crashes were.
##   A moments station (--pack moments, scripts/flight_pack_moments.gd) has
##   nothing to clear: its band is "moments", and each collectible gets its
##   own (the least skill getting it in 60% of runs; moments_table).
##   A station with token lines (FlightCourse `flown`) is benched per line:
##   id@yellow flies its yellow line; `all` and --pack take every line.
##
## Writes each run's JSON, a summary (bench_<when>.json) and the bands
## (bands.json, read by the study's end-of-run report), and prints a table.

const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Log = preload("res://scripts/flight_log.gd")
const Moments = preload("res://scripts/flight_moments.gd")
const Crash = preload("res://scripts/flight_crash.gd")

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
	if args.has("pack"): ids = PackedStringArray(Course.pack(str(args.pack)).map(func(s: Dictionary) -> String: return str(s.id)))
	if str(args.station) == "all" or args.has("pack"): ids = with_lines(ids)
	var skills := str(args.skills).split(",")
	var stage := Node3D.new()
	root.add_child(stage)
	var built := {}
	for id in ids:
		var s := Course.station(id)
		if s.is_empty():
			push_error("no station %s" % id)
			quit(1)
			return
		var base := Course.base_of(s)
		if built.has(base.id): continue
		built[base.id] = true
		Course.build(base,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	var crash := Crash.rules({"mode":str(args.get("crash","off")),"restart":str(args.get("restart","checkpoint")),"hard":float(args.get("crash-speed",0.0))})
	summary = bench(ids,skills,int(args.runs),space,str(args.out),bool(args.save),bool(args.get("bonus",true)),float(args.get("moment-ease",0.0)),crash)
	quit(0)

## `ids` with every token line of each station that has more than one
## (id, id@yellow, id@red: FlightCourse `line_names`).
static func with_lines(ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		var s := Course.station(id)
		if s.is_empty() or s.has("base"):
			out.append(id)
			continue
		for line in Course.line_names(s):
			out.append(str(Course.flown(s,line).id))
	return out

## Flies every station in `ids` with every skill; returns the summary.
static func bench(ids: PackedStringArray, skills: PackedStringArray, runs: int, space: PhysicsDirectSpaceState3D, dir: String, save: bool, bonus := true, moment_ease := 0.0, crash := {}) -> Dictionary:
	var tag := Crash.tag(crash)
	var began := Time.get_ticks_msec()
	var stations := {}
	var bands := {}
	for id in ids:
		var s := Course.station(id)
		if moment_ease > 0.0 and s.has("moments"): s = with_moment_ease(s,moment_ease)
		var row := {"id":id,"name":s.name,"intent":s.intent,"hash":Course.station_hash(s)+(":"+tag if tag != "" else ""),"skills":{}}
		var clears := {}
		# A moments station: every run per skill (the perfect bot's at each
		# look-ahead too), for each collectible's get rate.
		var every := {}
		for name in skills:
			var flown := []
			if name == "perfect":
				var best := {}
				every[name] = []
				for look: float in Bot.PERFECT_LOOKS:
					var params := Bot.skill("perfect")
					params.look = look
					if not bonus: params.merge({"bonus":false,"moments":false},true)
					var r := fly(s,"perfect",params,0,space,crash)
					every[name].append(r)
					if best.is_empty() or _better(r,best): best = r
				flown.append(best)
			else:
				for n in range(runs):
					var params := Bot.skill(name)
					if not bonus: params.merge({"bonus":false,"moments":false},true)
					flown.append(fly(s,name,params,hash([id,name,n]),space,crash))
				every[name] = flown
			if save and tag == "":
				for r: Dictionary in flown: Log.save(r,dir)
			var stats := _stats(flown)
			row.skills[name] = stats
			clears[name] = stats.clear_rate
			if name == "perfect": row["reference"] = _reference(flown[0])
			if tag != "": row.skills[name].merge(crash_stats(every[name]),true)
		row["band"] = Metrics.band(clears)
		row["clears"] = clears
		if s.has("moments"):
			# Nothing to clear: its bands are its collectibles'.
			row["band"] = "moments"
			row["moments"] = moment_rows(s,every,space)
			row["moment_skills"] = moment_skills(every)
		stations[id] = row
		bands[id if tag == "" else id+":"+tag] = {"hash":row.hash,"band":row.band,"clears":clears,"when":Time.get_datetime_string_from_system(true)+"Z",
			"reference":row.get("reference",{})}
		if row.has("moments"): bands[id if tag == "" else id+":"+tag]["moments"] = row.moments
	var out := {"kind":"bench","when":Time.get_datetime_string_from_system(true)+"Z","runs":runs,"skills":Array(skills),"stations":stations,
		"seconds":snappedf((Time.get_ticks_msec()-began)/1000.0,0.01)}
	if tag != "": out["crash"] = crash
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
	var moments := moments_table(out)
	if moments != "": print(moments)
	if tag != "": print(crash_table(out))
	return out

## Crashing on: per skill its runs' mean crashes, the share that ran out of
## time (TIME_LIMIT), the mean speed into the face, and each crash's place
## on the line (s at cruise).
static func crash_stats(runs: Array) -> Dictionary:
	var crashes := 0.0
	var timeouts := 0
	var into := 0.0
	var spots := []
	for r: Dictionary in runs:
		var m: Dictionary = r.metrics
		crashes += float(m.get("crashes",0))
		into += float(m.get("crash_into",0.0))*float(m.get("crashes",0))
		spots.append_array(m.get("crash_spots",[]))
		if str(r.get("result",{}).get("ended","")) == "timeout": timeouts += 1
	var n := maxf(runs.size(),1)
	return {"crashes":snappedf(crashes/n,0.01),"timeouts":snappedf(timeouts/n,0.01),"crash_into":snappedf(into/maxf(crashes,1.0),0.01),"crash_spots":spots}

## The crash table (crashing on): per station and skill sl/de/sh/pf the mean
## crashes a run and the share timed out, the mean speed into the face, then
## the line's crash spots (s along the line at cruise, crashes there over
## every skill's runs).
static func crash_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["crashes (%s; per skill sl/de/sh/pf; perfect = its runs at every look-ahead)" % Crash.tag(out.get("crash",{}))])
	lines.append("%-16s  %-23s  %-23s  %-6s  %s" % ["station","crashes/run","timed out","into","spots: line s x crashes"])
	for id: String in out.stations:
		var row: Dictionary = out.stations[id]
		var per := func(key: String) -> String:
			var bits := PackedStringArray()
			for k: String in Metrics.SKILLS:
				bits.append(("%.2f" % float(row.skills[k].get(key,0.0))) if row.skills.has(k) else "-")
			return "/".join(bits)
		var spots := {}
		var into := 0.0
		var total := 0.0
		for k: String in row.skills:
			for x: Variant in row.skills[k].get("crash_spots",[]):
				var at := snappedf(float(x),0.5)
				spots[at] = int(spots.get(at,0))+1
			var many := float(row.skills[k].get("crashes",0.0))*float(row.skills[k].get("runs",1))
			into += float(row.skills[k].get("crash_into",0.0))*many
			total += many
		var keys := spots.keys()
		keys.sort_custom(func(a: float, b: float) -> bool: return spots[a] > spots[b])
		var top := PackedStringArray()
		for at: float in keys.slice(0,6): top.append("%.1fs x%d" % [at,int(spots[at])])
		lines.append("%-16s  %-23s  %-23s  %6.1f  %s" % [id,per.call("crashes"),per.call("timeouts"),into/maxf(total,0.001),", ".join(top)])
	return "\n".join(lines)

## Moments station `s` with every collectible but the starter at pickup
## reach `ease` (--moment-ease: a sweep for laying them out; its own hash).
static func with_moment_ease(s: Dictionary, ease: float) -> Dictionary:
	var out := s.duplicate(true)
	for m: Dictionary in out.moments:
		if str(m.get("role","free")) != "starter": m["ease"] = ease
	return out

## Per collectible of moments station `s` (scripts/flight_moments.gd): its
## fit, react and reach, and per skill the share of runs that got it (a
## challenge one: of the runs that took the starter), and its band.
static func moment_rows(s: Dictionary, every: Dictionary, space: PhysicsDirectSpaceState3D) -> Array:
	var out := []
	for m: Dictionary in Moments.measure(s,space):
		var rates := {}
		for name: String in every:
			var got := 0
			var tried := 0
			for r: Dictionary in every[name]:
				var mm: Dictionary = r.metrics
				if m.role == "challenge" and int(mm.get("challenge_tries",0)) == 0: continue
				tried += 1
				if int(m.i) in (mm.get("moments_got",[]) as Array): got += 1
			rates[name] = snappedf(float(got)/tried,0.001) if tried > 0 else 0.0
		out.append({"i":m.i,"role":m.role,"kind":m.kind,"note":m.note,"fit":snappedf(float(m.fit),0.01),"knife":m.knife,
			"react":snappedf(float(m.react),0.01),"reach":snappedf(float(m.off),0.01),"beyond":snappedf(float(m.beyond),0.01),
			"pickup":snappedf(float(m.reach),0.01),"at_s":snappedf(float(m.at_s),0.01),"rates":rates,"band":Moments.band(rates)})
	return out

## Per skill on a moments station: mean free taken, the share of runs that
## started the challenge and that completed it, and mean bumps.
static func moment_skills(every: Dictionary) -> Dictionary:
	var out := {}
	for name: String in every:
		var runs: Array = every[name]
		var free := 0.0
		var started := 0
		var complete := 0
		var best := 0.0
		var bumps := 0.0
		var crashes := 0.0
		for r: Dictionary in runs:
			var m: Dictionary = r.metrics
			free += float(m.get("free_taken",0))
			if int(m.get("challenge_tries",0)) > 0: started += 1
			if bool(m.get("challenge_complete",false)): complete += 1
			best += float(m.get("challenge_taken",0))
			bumps += float(m.get("bumps",0))
			crashes += float(m.get("crashes",0))
		var n := maxf(runs.size(),1)
		out[name] = {"runs":runs.size(),"free":snappedf(free/n,0.01),"started":snappedf(started/n,0.01),"complete":snappedf(complete/n,0.01),
			"challenge":snappedf(best/n,0.01),"bumps":snappedf(bumps/n,0.01),"crashes":snappedf(crashes/n,0.01)}
	return out

## The moments pack's per-collectible table: each collectible's fit (m of
## room, k: only on a knife edge), react (s from first seen to commit, off
## the natural line), reach (m off the line), its get rate per skill and
## its band; then per skill the free ones got, the challenge started and
## completed. "" when no moments station was benched.
static func moments_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["moments (per collectible; get rate sl/de/sh/pf, challenge ones of the runs that took the starter)"])
	var any := false
	for id: String in out.stations:
		var row: Dictionary = out.stations[id]
		if not row.has("moments"): continue
		any = true
		lines.append("%s  (%s)" % [id,row.hash])
		lines.append("  %2s %-9s %-5s %6s %6s %6s %6s  %-23s %-7s  %s" % ["#","role","kind","fit m","react","reach","at s","got sl/de/sh/pf","band","note"])
		for m: Dictionary in row.moments:
			var rates: Dictionary = m.rates
			lines.append("  %2d %-9s %-5s %6s %6.2f %6.2f %6.2f  %-23s %-7s  %s" % [int(m.i),m.role,m.kind,"%.2f%s" % [float(m.fit),"k" if m.knife else ""],
				float(m.react),float(m.reach),float(m.at_s),"/".join(Metrics.SKILLS.map(func(k: String) -> String: return ("%.2f" % float(rates[k])) if rates.has(k) else "-")),m.band,m.note])
		var sk: Dictionary = row.moment_skills
		var per := func(key: String) -> String: return "/".join(Metrics.SKILLS.map(func(k: String) -> String: return ("%.2f" % float(sk[k][key])) if sk.has(k) else "-"))
		lines.append("  free got %s · challenge started %s · completed %s · challenge got %s · bumps %s%s" % [per.call("free"),per.call("started"),per.call("complete"),per.call("challenge"),per.call("bumps"),
			" · crashes %s" % per.call("crashes") if not (out.get("crash",{}) as Dictionary).is_empty() else ""])
	return "\n".join(lines) if any else ""

## One bot run of station `s`.
static func fly(s: Dictionary, name: String, params: Dictionary, seed_value: int, space: PhysicsDirectSpaceState3D, crash := {}) -> Dictionary:
	var r := Run.new(s,"bot:"+name,params,space)
	if not crash.is_empty(): r.set_crash(crash)
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

## The token-placement comparison, for the tokens pack's stations
## (scripts/flight_pack_tokens.gd): per station its style, tokens to take
## (guides not counted) and bonus tokens, the clear rate per skill, the
## perfect reference's threading, flow and demand, and per skill the mean
## bonus tokens seen and taken, and bumps. "" when no station in the bench
## is the tokens pack's.
static func pack_table(out: Dictionary) -> String:
	var lines := PackedStringArray(["token placement (reference = perfect; per skill sl/de/sh/pf)"])
	lines.append("%-14s %-8s %4s %4s  %-19s %6s %6s %6s %6s %6s %6s %6s  %-15s %-15s %-19s" % ["station","style","req","bon","clear","time","thread","open/s","still","longst","dPeak","dMean","bonus taken","bonus seen","bumps"])
	var any := false
	for id: String in out.stations:
		var s := Course.station(id)
		if str(s.get("pack","")) != "tokens": continue
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
