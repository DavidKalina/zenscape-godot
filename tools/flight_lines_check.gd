extends SceneTree
## Static check of a station's token lines (scripts/flight_pack_lines.gd,
## tools/flight_lines_layout.py): per line, each gap's room along the smooth
## line through its tokens (FlightCourse `rooms`), its knife zones, the
## tokens' clearance, and the line's turn and pitch needs (FlightMetrics
## `profile`). Nothing is flown or saved.
##   godot --headless --path . -s tools/flight_lines_check.gd -- lines_bend [lines_stitch ...]
const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

func _initialize() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty(): ids = PackedStringArray(Course.pack("lines").map(func(s: Dictionary) -> String: return str(s.id)))
	for id in ids:
		var base := Course.station(id)
		if base.is_empty():
			push_error("no station %s" % id)
			continue
		var all := Course.solids(base)
		print("== %s (%d solids)" % [id,all.size()])
		for line in Course.line_names(base):
			var s := Course.flown(base,line)
			var tokens := Course.tokens(s)
			var smooth := Metrics.line(Course.origin(s),0.0,tokens)
			var gaps := Metrics.profile(smooth,tokens.size())
			var rooms := Course.rooms(s,smooth)
			var zones := Course.knife_zones(s,smooth)
			var least := INF
			var bits := PackedStringArray()
			var turn := 0.0
			var pitch := 0.0
			for g in range(tokens.size()):
				var r := float(rooms[g].room)
				least = minf(least,r)
				turn = maxf(turn,float(gaps[g].turn_peak))
				pitch = maxf(pitch,float(gaps[g].pitch_peak))
				bits.append("%d:%.1f%s" % [g,r,"k" if rooms[g].get("knife",false) else ""])
			var inside := 0
			var stone := PackedStringArray()
			for i in range(tokens.size()):
				var c := Course.clearance(all,tokens[i])
				if c < 0.5:
					inside += 1
					stone.append("%d (%.2f m)" % [i,c])
			print("  %-6s %s  %d tokens · room least %.2f · turn need %.2f · pitch need %.2f · knife zones %d · tokens in stone %d" % [line,Course.station_hash(s),tokens.size(),least,turn,pitch,zones.size(),inside])
			print("         rooms "+" ".join(bits))
			if not stone.is_empty(): print("         tokens in stone: "+", ".join(stone))
			# The tightest point of each tight gap, and what it skims.
			var worst := {}
			for sample: Dictionary in smooth:
				var g := int(sample.gap)
				if g < 0 or float(rooms[g].room) >= 0.6: continue
				var p: Vector3 = sample.p
				for solid: Dictionary in all:
					var d := Course.distance(solid,p)
					if not worst.has(g) or d < float(worst[g].d): worst[g] = {"d":d,"p":p,"solid":solid}
			for g: int in worst:
				var w: Dictionary = worst[g]
				var o := Course.origin(s)
				var sd: Dictionary = w.solid
				print("         gap %d tightest at %s: %.2f m from a %s at %s%s" % [g,str(((w.p as Vector3)-o).snapped(Vector3.ONE*0.1)),float(w.d),sd.kind,
					str(((sd.middle as Vector3)-o).snapped(Vector3.ONE*0.1))," size "+str((sd.size as Vector3).snapped(Vector3.ONE*0.1)) if sd.kind == "box" else " r %.1f h %.1f" % [float(sd.radius),float(sd.height)]])
			for z: Dictionary in zones:
				print("         knife zone gap %d, %.1f m long, room %.2f" % [int(z.gap),float(z.length),float(z.room)])
	quit(0)
