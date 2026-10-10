extends SceneTree
## The moments pack's layout check (scripts/flight_pack_moments.gd), headless,
## no flying: each moment's fit, react and reach off the station's natural
## line (scripts/flight_moments.gd `measure`), where on the line it is, and
## the time on to the next moment and the next tight stretch. With --scan, a
## design aid: spots round any station's line (its own tokens as the line),
## sorted into fit, react and reach candidates.
##
##   godot --headless --path . -s tools/flight_moments_check.gd -- [--station id[,id]]
##   godot --headless --path . -s tools/flight_moments_check.gd -- --scan lines_bend [--every 4]

const Course = preload("res://scripts/flight_course.gd")
const Moments = preload("res://scripts/flight_moments.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

var pick_spec := ""
var bucket_s := 2.0

func _initialize() -> void:
	main.call_deferred()

func main() -> void:
	var args := OS.get_cmdline_user_args()
	var ids := PackedStringArray(Course.pack("moments").map(func(s: Dictionary) -> String: return str(s.id)))
	var scan := ""
	var every := 4.0
	for i in range(args.size()):
		if args[i] == "--station" and i+1 < args.size(): ids = args[i+1].split(",")
		if args[i] == "--scan" and i+1 < args.size(): scan = args[i+1]
		if args[i] == "--every" and i+1 < args.size(): every = float(args[i+1])
		if args[i] == "--pick" and i+1 < args.size(): pick_spec = args[i+1]
		if args[i] == "--bucket" and i+1 < args.size(): bucket_s = float(args[i+1])
	var stage := Node3D.new()
	root.add_child(stage)
	if scan != "": ids = PackedStringArray([scan])
	for id in ids: Course.build(Course.base_of(Course.station(id)),stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	if scan != "":
		_scan(Course.station(scan),space,every)
	else:
		for id in ids: print(table(Course.station(id),Moments.measure(Course.station(id),space)))
	quit(0)

## One station's moments as a table.
static func table(s: Dictionary, rows: Array) -> String:
	var lines := PackedStringArray(["%s (%s)" % [s.id,Course.station_hash(s)]])
	lines.append("  %2s %-9s %-5s %6s %6s %6s %6s %5s  %6s %6s %6s  %s" % ["#","role","kind","fit m","react","reach","beyond","r","at s","next s","tight","note"])
	for r: Dictionary in rows:
		lines.append("  %2d %-9s %-5s %6s %6.2f %6.2f %6.2f %5.2f  %6.2f %6s %6s  %s" % [int(r.i),r.role,r.kind,
			("%.2f%s" % [float(r.fit),"k" if r.knife else ""]),float(r.react),float(r.off),float(r.beyond),float(r.reach),
			float(r.at_s),_s(float(r.next_s)),_s(float(r.tight_s)),r.note])
	return "\n".join(lines)

static func _s(x: float) -> String:
	return "-" if not is_finite(x) else "%.2f" % x

## Spots round station `s`'s line, every `every` m along it: across and up
## in the line's frame. Each clear of the stone, with a clear way from the
## line to it, measured as a moment; printed by kind.
func _scan(s: Dictionary, space: PhysicsDirectSpaceState3D, every: float) -> void:
	var entry := Course.entry(s)
	var line := Metrics.line(entry.position,entry.heading,Course.tokens(s))
	var all := Course.solids(s)
	var at := Course.origin(s)
	var spots := []
	var stride := maxi(1,roundi(every/Metrics.STEP))
	for i in range(stride,line.size()-1,stride):
		var p: Vector3 = line[i].p
		var way := Moments._way(line,i)
		var side := way.cross(Vector3.UP).normalized()
		var up := side.cross(way).normalized()
		for across: float in [-8.0,-6.0,-4.5,-3.0,-1.5,0.0,1.5,3.0,4.5,6.0,8.0]:
			for high: float in [-5.0,-3.0,-1.5,0.0,1.5,3.0,5.0,7.0]:
				var q := p+side*across+up*high
				if Course.clearance(all,q) < 0.25: continue
				if not Course.line_clear(space,p,q): continue
				spots.append({"at":q-at,"role":"free","kind":"","note":"s%d %+.1f/%+.1f" % [roundi(float(i)*Metrics.STEP),across,high]})
	var probe := s.duplicate()
	probe["origin"] = at
	probe["moments"] = spots
	var rows := Moments.measure(probe,space)
	if pick_spec != "":
		_pick(s,rows,line,space,pick_spec)
		return
	var fits := rows.filter(func(r: Dictionary) -> bool: return float(r.fit) < 0.45 and float(r.fit) > -0.2 and float(r.beyond) > 0.3 and float(r.off) < 5.0 and float(r.react) > 0.3)
	var reacts := rows.filter(func(r: Dictionary) -> bool: return float(r.react) < 0.9 and float(r.react) > 0.1 and float(r.off) > 2.0 and float(r.off) < 6.5 and float(r.fit) > 0.3)
	var reaches := rows.filter(func(r: Dictionary) -> bool: return float(r.beyond) > 2.5 and float(r.beyond) < 6.5 and float(r.react) > 1.0 and float(r.fit) > 0.5)
	print("%s: %d spots, line %.1f s" % [s.id,rows.size(),float(line.size())*Metrics.STEP/Metrics.CRUISE])
	for pair: Array in [["fit (room -0.2-0.45 m, 0.3+ m beyond the pickup, within 5 m)",fits],["react (0.1-0.9 s to commit, 2-6.5 m off)",reacts],["reach (2.5-6.5 m beyond the pickup, 1+ s to commit)",reaches]]:
		print("-- %s: %d" % [pair[0],(pair[1] as Array).size()])
		var shown := {}
		for r: Dictionary in pair[1]:
			# One per `bucket` s of line (--bucket, 2 by default), the best of its kind.
			var bucket := floori(float(r.at_s)/bucket_s)
			if not shown.has(bucket) or _better(str(pair[0]),r,shown[bucket]): shown[bucket] = r
		var keys := shown.keys()
		keys.sort()
		for b: int in keys:
			var r: Dictionary = shown[b]
			print("  at %5.2f s  local %s  fit %5.2f%s react %5.2f reach %5.2f beyond %5.2f tight in %s  %s" % [float(r.at_s),Metrics.arr((r.at as Vector3)-at),float(r.fit),"k" if r.knife else " ",
				float(r.react),float(r.off),float(r.beyond),_s(float(r.tight_s)),r.note])

## Layouts for --pick: per moment [role, kind, from, to (shares of the
## line's time), target (fit: room m; react: s; reach and starter: m beyond
## the pickup)], picked in this order.
const PICKS := {
	"standard":[
		["free","reach",0.06,0.3,3.0],
		["free","fit",0.2,0.5,0.25],
		["starter","",0.3,0.5,1.0],
		["free","react",0.45,0.75,0.6],
		["challenge","fit",0.5,0.7,0.05],
		["challenge","react",0.62,0.85,0.35],
		["challenge","reach",0.75,0.97,5.0],
	],
}
## Picked moments stand at least this long apart along the line (s), at
## least RECOVER s before the line's next tight stretch, and the way from
## each back to the line RETURN s on is clear.
const SPACING := 1.2
const RECOVER := 1.0
const RETURN := 1.2

## Picks moments from the scanned spots `rows` (see PICKS) and prints them
## as the pack's lines.
func _pick(s: Dictionary, rows: Array, line: Array, space: PhysicsDirectSpaceState3D, spec: String) -> void:
	var arc := PackedFloat32Array([0.0])
	for i in range(1,line.size()): arc.append(arc[i-1]+(line[i].p as Vector3).distance_to(line[i-1].p))
	var total := float(arc[arc.size()-1])/Metrics.CRUISE
	var at := Course.origin(s)
	var chosen := []
	for want: Array in PICKS[spec]:
		var role := str(want[0])
		var kind := str(want[1])
		var target := float(want[4])
		var best := {}
		var best_score := INF
		for r: Dictionary in rows:
			var when := float(r.at_s)/total
			if when < float(want[2]) or when > float(want[3]): continue
			if float(r.tight_s) < RECOVER: continue
			if chosen.any(func(c: Dictionary) -> bool: return absf(float(c.at_s)-float(r.at_s)) < SPACING): continue
			var score := INF
			match kind:
				"fit":
					if float(r.react) < 0.6 or float(r.beyond) < 0.3 or float(r.beyond) > 3.5: continue
					score = absf(float(r.fit)-target)
				"react":
					if float(r.off) < 2.0 or float(r.off) > 6.5 or float(r.fit) < 0.3 or float(r.beyond) < 0.8: continue
					score = absf(float(r.react)-target)
				"reach":
					if float(r.react) < 1.0 or float(r.fit) < 0.6: continue
					score = absf(float(r.beyond)-target)
				_:
					if float(r.react) < 1.5 or float(r.fit) < 1.5: continue
					score = absf(float(r.beyond)-target)
			if score >= best_score: continue
			# The way back to the line, RETURN s on.
			var k := arc.bsearch(float(r.at_s)*Metrics.CRUISE+RETURN*Metrics.CRUISE)
			if not Course.line_clear(space,r.at,line[mini(k,line.size()-1)].p): continue
			best_score = score
			best = r
		if best.is_empty():
			print("  # no %s %s found in %.2f-%.2f" % [role,kind,float(want[2]),float(want[3])])
			continue
		best["role"] = role
		best["kind"] = kind
		chosen.append(best)
	for r: Dictionary in chosen:
		var p: Vector3 = (r.at as Vector3)-at
		print("\t\t\t{\"at\":Vector3(%.2f,%.2f,%.2f),\"role\":\"%s\",\"kind\":\"%s\",\"note\":\"%s\"},   # at %.2f s, fit %.2f%s, react %.2f, reach %.2f (beyond %.2f), tight in %s" % [p.x,p.y,p.z,
			r.role,r.kind,r.note,float(r.at_s),float(r.fit),"k" if r.knife else "",float(r.react),float(r.off),float(r.beyond),_s(float(r.tight_s))])

static func _better(kind: String, a: Dictionary, b: Dictionary) -> bool:
	if kind.begins_with("fit"): return float(a.fit) < float(b.fit)
	if kind.begins_with("react"): return float(a.react) < float(b.react)
	return float(a.beyond) > float(b.beyond)
