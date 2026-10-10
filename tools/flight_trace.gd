extends SceneTree
## Traces bot runs of one flight-study station (tools/flight_bench.gd does
## many and bands them; this shows why one went as it did): each run's
## tokens, misses and bumps with their times, the per-gap numbers
## (FlightMetrics `summarise`), and with `trace`, the pose and input every
## quarter second. Nothing is saved.
##   godot --headless --path . -s tools/flight_trace.gd -- <station> <skill> [runs] [look] [trace]
##   godot --headless --path . -s tools/flight_trace.gd -- hidden_turn decent 3
##   godot --headless --path . -s tools/flight_trace.gd -- mixed_spike perfect 1 7 trace
const Course = preload("res://scripts/flight_course.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Bot = preload("res://scripts/flight_bot.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <station> <skill> [runs] [look] [trace]")
		quit(1)
		return
	var id := args[0]
	var skill := args[1]
	var s := Course.station(id)
	if s.is_empty() or not Bot.SKILLS.has(skill):
		push_error("no station %s or skill %s" % [id,skill])
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	Course.build(s,stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	for n in range(int(args[2]) if args.size() > 2 else 3):
		var p := Bot.skill(skill)
		if args.size() > 3: p.look = float(args[3])
		var r: Dictionary = Bench.fly(s,skill,p,hash([id,skill,n]),space)
		var m: Dictionary = r.metrics
		var ev := []
		for e: Dictionary in r.events:
			# Bumps are summed up as spells below.
			if e.kind == "bump" and r.has("moments"): continue
			ev.append("%s%s@%.2f" % [e.kind,str(e.get("token",e.get("bonus",e.get("moment",e.get("why",""))))),e.t])
		print("%s %s: %d/%d bumps %d time %.2f ended %s | %s" % [id,skill,m.collected,m.total,m.bumps,m.duration,r.result.ended," ".join(ev)])
		if r.has("moments"):
			# A moments station: the spells spent scraping stone, when and where (local).
			var tk: Dictionary = r.ticks
			var at := Course.origin(s)
			var spells := PackedStringArray()
			var from := -1
			for i in range(tk.t.size()+1):
				# A scrape: bumping now or within 15 ticks (a quarter second).
				var on := false
				for k in range(i,mini(i+15,tk.t.size())):
					if int(tk.bump[k]) == 1: on = true
				if on and i < tk.t.size() and int(tk.bump[i]) == 0 and from < 0: on = false
				if on and from < 0: from = i
				if not on and from >= 0:
					var j := (from+i-1)/2
					spells.append("%.2f-%.2f s at (%.0f %.0f %.0f)" % [tk.t[from],tk.t[i-1],float(tk.x[j])-at.x,float(tk.y[j])-at.y,float(tk.z[j])-at.z])
					from = -1
			print("   free %d/%d, challenge best %d/%d, scraping: %s" % [m.free_taken,m.free_total,m.challenge_taken,m.challenge_total,", ".join(spells)])
		if args.size() > 4:
			var tk: Dictionary = r.ticks
			for i in range(0,tk.t.size(),15):
				print("    t %.2f at %.1f %.1f %.1f heading %.2f pitch %.2f speed %.1f turn %.2f pitch in %.2f brake %.0f" % [tk.t[i],tk.x[i],tk.y[i],tk.z[i],tk.heading[i],tk.pitch[i],tk.speed[i],tk.in_turn[i],tk.in_pitch[i],tk.in_brake[i]])
		for g: Dictionary in m.gaps:
			print("   gap %d %s turn %.2f pitch %.2f commit %.2f warning %s room %.2f demand %.2f" % [g.token,g.kind,g.turn,g.pitch,g.commit,str(g.warning),g.room,g.demand])
	quit(0)
