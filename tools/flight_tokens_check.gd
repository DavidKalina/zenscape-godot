extends SceneTree
## Checks a flight-study station's token placement without flying it
## (scripts/flight_pack_tokens.gd, tools/flight_tokens_layout.py): per route
## point (token or guide) where it stands (station metres), its gap's turn
## and pitch need on the line (FlightMetrics `profile`), the gap's room and
## where along the gap the line comes closest to a solid; per bonus token
## its clearance, whether level wings fit round it (FlightCourse `tight`),
## and how long it is in view from the station's line at cruise (the run's
## seen rule: within FlightRun CONE of the line's way, SIGHT m, no solid in
## between), so a hidden token reads as 0 s. Nothing is flown or saved.
##   godot --headless --path . -s tools/flight_tokens_check.gd -- tokens_hall_hidden [more ids]
##   godot --headless --path . -s tools/flight_tokens_check.gd -- --pack tokens
const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Run = preload("res://scripts/flight_run.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var ids := []
	if args.size() >= 2 and args[0] == "--pack":
		for s: Dictionary in Course.pack(args[1]): ids.append(s.id)
	else:
		ids = Array(args)
	for id: String in ids:
		var s := Course.station(id)
		if s.is_empty():
			push_error("no station %s" % id)
			quit(1)
			return
		print(report(s))
	quit(0)

## The check of station `s`, as text.
static func report(s: Dictionary) -> String:
	var at := Course.origin(s)
	var tokens := Course.tokens(s)
	var guides := Course.guides(s)
	var line := Metrics.line(at,0.0,tokens)
	var gaps := Metrics.profile(line,tokens.size())
	var rooms := Course.rooms(s,line)
	var all := Course.solids(s)
	var out := PackedStringArray(["%s (%s): %d route points, %d guides, %d bonus, hash %s" % [s.id,s.get("style",""),tokens.size(),guides.size(),
		(s.get("bonus",[]) as Array).size(),Course.station_hash(s)]])
	# Where each gap's line comes closest to a solid.
	var least := {}
	for sample: Dictionary in line:
		var g := int(sample.gap)
		var c := Course.clearance(all,sample.p)
		if g >= 0 and (not least.has(g) or c < float(least[g].c)): least[g] = {"c":c,"p":sample.p}
	for i in range(tokens.size()):
		var g: Dictionary = gaps[i]
		var near: Dictionary = least.get(i,{"c":INF,"p":tokens[i]})
		out.append("  %2d %-5s %-22s turn %.2f pitch %.2f  room %5.2f%s  closest %5.2f at %s" % [i,"guide" if i in guides else "token",_v(tokens[i]-at),
			float(g.turn_peak),float(g.pitch_peak),float(rooms[i].room)," knife" if rooms[i].get("knife",false) else "",float(near.c),_v((near.p as Vector3)-at)])
	var bonus := Course.bonus(s)
	var tight := Course.tight(s,bonus)
	for i in range(bonus.size()):
		var sight := sight_seconds(all,line,bonus[i])
		out.append("  bonus %d %-22s clearance %5.2f%s  in view from the line %.1f s%s" % [i,_v(bonus[i]-at),Course.clearance(all,bonus[i]),
			" TIGHT (knife edge)" if tight[i] == 1 else "",float(sight.seconds),"" if sight.first < 0.0 else " (first %.1f s in)" % float(sight.first)])
	return "\n".join(out)

## How long (s at cruise) point `p` is in view from the line, and when it
## first is (s, or -1).
static func sight_seconds(all: Array, line: Array, p: Vector3) -> Dictionary:
	var seen := 0
	var first := -1.0
	for i in range(1,line.size()):
		var from: Vector3 = line[i].p
		var way := (from-(line[i-1].p as Vector3)).normalized()
		var d := p-from
		if d.length() > Run.SIGHT or d.length() < 0.01 or way.angle_to(d) > Run.CONE: continue
		var dir := d.normalized()
		var blocked := false
		for solid: Dictionary in all:
			if Metrics.ray_hits(solid,from,dir,d.length()-0.7):
				blocked = true
				break
		if blocked: continue
		seen += 1
		if first < 0.0: first = i*Metrics.STEP/Metrics.CRUISE
	return {"seconds":seen*Metrics.STEP/Metrics.CRUISE,"first":first}

static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x,p.y,p.z]
