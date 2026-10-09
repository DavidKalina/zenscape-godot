extends SceneTree
## The flight study's numbers (scripts/flight_metrics.gd) on made-up runs
## with known answers: reversals and stick effort from a fixed input
## pattern; the line's needed turn on a straight trail (none) and round a
## circle (cruise over the radius); the warning of a token seen long before
## versus one seen only on arrival; the demand formula's ends; the bands;
## the live slack; the course's signed distances and its hash (every
## station pinned); threading past walls, under a lintel and by a lone pillar;
## flow on a run that flies straight, turns, then flies straight again, and
## on a wobble.
##   godot --headless --path . --script tests/test_flight_metrics.gd
const Metrics = preload("res://scripts/flight_metrics.gd")
const Course = preload("res://scripts/flight_course.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func near(a: float, b: float, by: float) -> bool:
	return absf(a-b) <= by

## A run flown straight north at 14 m/s for `seconds`, ticks every `dt`,
## `turns` the turn input per tick (cycled), tokens every 14 m from 14 m,
## each seen at `seen[i]` and taken on arrival.
func straight_run(seconds: float, dt: float, turns: Array, tokens: int, seen: Array) -> Dictionary:
	var ticks := {}
	for key: String in ["t","x","y","z","heading","pitch","bank","speed","in_turn","in_pitch","in_boost","in_brake","in_lean","in_roll","bump"]:
		ticks[key] = []
	var n := roundi(seconds/dt)+1
	for i in range(n):
		var t := i*dt
		ticks.t.append(t)
		ticks.x.append(0.0)
		ticks.y.append(40.0)
		ticks.z.append(-14.0*t)
		for key: String in ["heading","pitch","bank","in_pitch","in_boost","in_brake","in_lean","in_roll","bump"]: ticks[key].append(0.0)
		ticks.speed.append(14.0)
		ticks.in_turn.append(turns[i%turns.size()])
	var token_list := []
	var events := []
	for k in range(tokens):
		token_list.append([0.0,40.0,-14.0*(k+1)])
		events.append({"t":seen[k],"token":k,"kind":"seen"})
		events.append({"t":float(k+1),"token":k,"kind":"hit"})
	return {"entry":{"position":[0.0,40.0,0.0],"heading":0.0},"tokens":token_list,"reach":1.7,"ticks":ticks,"events":events,
		"result":{"duration":seconds}}

func run() -> void:
	# Reversals: past the dead zone only, a small wobble does not count.
	check(Metrics.reversals([0.5,-0.5,0.1,-0.6,0.7,0.15,-0.1,0.9]) == 2,"Reversals count sign changes past the dead zone (2)")
	check(Metrics.reversals([1.0,1.0,0.0,1.0]) == 0,"Holding one way is no reversal")
	# A straight trail: nothing to turn, the stick pattern measured.
	var straight := straight_run(3.0,0.1,[1.0,1.0,-1.0,-1.0,0.0],3,[0.0,0.0,0.0])
	var m := Metrics.summarise(straight)
	check(m.cleared and int(m.collected) == 3 and near(float(m.duration),3.0,0.001),"A straight run clears 3/3 in 3.0 s")
	check(float(m.turn_need_peak) < 0.01 and float(m.pitch_need_peak) < 0.01,"A straight trail needs no turn or pitch (%.3f, %.3f)" % [m.turn_need_peak,m.pitch_need_peak])
	check(float(m.turn_flown_peak) < 0.001,"Flown straight, no flown turn (%.3f)" % m.turn_flown_peak)
	# The pattern 1,1,-1,-1,0 over 31 ticks: travel 2+1+1 per 5 ticks.
	var turns: Array = straight.ticks.in_turn
	var travel := 0.0
	var reversed := 0
	var last := 0.0
	var full := 0
	for i in range(turns.size()):
		if i > 0: travel += absf(float(turns[i])-float(turns[i-1]))
		if absf(float(turns[i])) > 0.8: full += 1
		if absf(float(turns[i])) > 0.2:
			if last != 0.0 and signf(turns[i]) != last: reversed += 1
			last = signf(turns[i])
	check(int(m.turn_reversals) == reversed and reversed == 12,"Turn reversals from the pattern: %d (12)" % m.turn_reversals)
	check(near(float(m.effort),travel/3.0,0.001),"Effort is the stick's travel a second (%.3f = %.3f)" % [m.effort,travel/3.0])
	check(near(float(m.full_share),float(full)/turns.size(),0.001),"Full stick share %.3f (%d of %d ticks)" % [m.full_share,full,turns.size()])
	# Warning on a straight trail: nothing to commit to, so it is the time
	# from seeing a token to reaching it.
	var w: Array = m.gaps.map(func(g: Dictionary) -> float: return float(g.warning))
	check(near(w[0],1.0,0.01) and near(w[1],2.0,0.01) and near(w[2],3.0,0.01),"Warnings, all seen at the start, are 1, 2, 3 s (%s)" % [w])
	# Demand on a straight, open trail: the room's share alone.
	var open_demand := Metrics.W_ROOM*(1.0-1.7/Metrics.ROOM_EASY)
	check(near(float(m.demand_peak),open_demand,0.002),"A straight open trail's demand is the room's share alone (%.3f = %.3f)" % [m.demand_peak,open_demand])
	check(m.grade == "easy","It grades easy")
	check(m.curve.size() >= 12 and near(float(m.curve[0][1]),open_demand,0.002),"The demand curve runs every %.2f s (%d samples)" % [Metrics.CURVE_STEP,m.curve.size()])
	# A circle: the needed yaw rate is cruise over the radius.
	var r := 20.0
	var circle := []
	for k in range(1,13):
		var a := k*0.3
		circle.append(Vector3(r*(1.0-cos(a)),0.0,-r*sin(a)))
	var gaps := Metrics.profile(Metrics.line(Vector3.ZERO,0.0,circle),circle.size())
	var want := Metrics.CRUISE/r/Metrics.TURN_RATE
	var middle: Dictionary = gaps[6]
	check(near(float(middle.turn_mean),want,want*0.1),"Round a %.0f m circle the line needs %.3f of TURN_RATE (%.3f)" % [r,want,middle.turn_mean])
	check(near(float(middle.turned),0.3,0.03),"Each gap round it turns 0.3 rad (%.3f)" % middle.turned)
	# A token seen only on arrival has no warning: minus its commit time.
	var late := straight_run(3.0,0.1,[0.0],3,[0.0,0.0,3.0])
	late.tokens[2] = [8.0,40.0,-42.0]
	var lm := Metrics.summarise(late)
	var g2: Dictionary = lm.gaps[2]
	check(float(g2.commit) > 0.3 and near(float(g2.warning),-float(g2.commit),0.001),"A token seen on arrival warns -commit (%.3f vs %.3f)" % [g2.warning,g2.commit])
	check(float(g2.demand) > float(lm.gaps[0].demand),"Its gap's demand stands over the open start (%.3f > %.3f)" % [g2.demand,lm.gaps[0].demand])
	# The demand formula's ends.
	check(near(Metrics.gap_demand(1.0,0.2,0.0,0.0,1.0),1.0,0.0001),"Full turn, no warning, no room: demand 1.0")
	check(near(Metrics.gap_demand(0.0,0.0,10.0,10.0,1.0),0.0,0.0001),"Nothing asked: demand 0")
	check(near(Metrics.gap_demand(0.0,0.0,0.0,10.0,0.0),0.0,0.0001),"No warning but nothing to swing for: no hurry")
	# Bands: the least skill that clears.
	check(Metrics.band({"sloppy":0.2,"decent":0.6,"sharp":1.0,"perfect":1.0}) == "medium","Decent clears first: medium")
	check(Metrics.band({"sloppy":0.8}) == "easy","Sloppy clears: easy")
	check(Metrics.band({"perfect":1.0}) == "expert","Only perfect clears: expert")
	check(Metrics.band({"sloppy":0.0,"perfect":0.0}) == "broken","None clears: broken")
	# Live slack: 28 m dead ahead at 14 m/s is 2 s, nothing to swing.
	check(near(Metrics.slack(Vector3.ZERO,0.0,0.0,14.0,Vector3(0.0,0.0,-28.0)),2.0,0.001),"Slack to a token 28 m dead ahead is 2.0 s")
	check(Metrics.slack(Vector3.ZERO,0.0,0.0,14.0,Vector3(10.0,0.0,2.0)) < 0.0,"Slack to a token beside and behind is negative")
	# The course: signed distances and the hash.
	var box := {"kind":"box","middle":Vector3.ZERO,"size":Vector3(2.0,2.0,2.0),"basis":Basis.IDENTITY}
	check(near(Course.distance(box,Vector3(3.0,0.0,0.0)),2.0,0.0001) and near(Course.distance(box,Vector3.ZERO),-1.0,0.0001),"A box's signed distance (2 outside, -1 at its middle)")
	var turned := {"kind":"box","middle":Vector3.ZERO,"size":Vector3(4.0,2.0,2.0),"basis":Basis(Vector3.UP,PI*0.5)}
	check(near(Course.distance(turned,Vector3(0.0,0.0,3.0)),1.0,0.0001),"A box turned a quarter: its long side along z")
	var cyl := {"kind":"cyl","middle":Vector3.ZERO,"radius":1.0,"height":4.0}
	check(near(Course.distance(cyl,Vector3(3.0,0.0,0.0)),2.0,0.0001) and near(Course.distance(cyl,Vector3(0.0,4.0,0.0)),2.0,0.0001),"A cylinder's signed distance, side and top")
	var s: Dictionary = Course.STATIONS[0].duplicate(true)
	var h := Course.station_hash(s)
	check(h == Course.station_hash(Course.STATIONS[0]) and h.length() == 12,"A station's hash is stable (%s)" % h)
	s.tokens[0] = (s.tokens[0] as Vector3)+Vector3(0.5,0.0,0.0)
	check(Course.station_hash(s) != h,"Moving a token changes the hash")
	# Every station: tokens clear of the solids, the slot's room is tight.
	for st: Dictionary in Course.STATIONS:
		var solids := Course.solids(st)
		var inside := 0
		for p in Course.tokens(st):
			if Course.clearance(solids,p) < 0.5: inside += 1
		check(inside == 0,"%s: every token stands clear of its solids" % st.id)
	var slot := Course.station("tight_slot")
	var rooms := Course.rooms(slot,Metrics.line(Course.origin(slot),0.0,Course.tokens(slot)))
	var mid := Course.clearance(Course.solids(slot),Course.tokens(slot)[3])-Course.SPAN*0.5
	check(near(mid,0.5,0.001),"The 2.4 m slot leaves level wings 0.5 m a side (%.3f)" % mid)
	check(float(rooms[3].room) <= 0.5 and float(rooms[3].room) > 0.3,"The line through it has that room, give or take its curve (%.3f)" % rooms[3].room)
	# Every station keeps the hash its runs (the user's rated ones among
	# them) were flown on.
	var pinned := {"gentle_arc":"ef5c73b6ecd3","slalom":"9e140f831e10","hidden_turn":"08b17c0ca386","tight_slot":"9b4941fb9a24",
		"climb_rings":"4ed82e139779","dive_arch":"005a5bfc75b1","open_swoop":"fe3d869879c8","mixed_spike":"66cc6ea3502b","sundered":"2c94344973d0",
		"sundered_flow":"2a22c9b41180","sundered_mix":"db59c1bb79c5"}
	for id: String in pinned:
		check(Course.station_hash(Course.station(id)) == pinned[id],"%s keeps its hash %s" % [id,pinned[id]])
	# Threading on a made-up run: 4 s north at 14 m/s past two walls either
	# side (z -14 to -28, 2.5 m off: 1 s), a lintel overhead (1 m deep, at
	# z -42: a few ticks) and a pillar on one side only (never).
	var walk := straight_run(4.0,1.0/60.0,[0.0],4,[0.0,0.0,0.0,0.0])
	var walls := [
		{"kind":"box","middle":Vector3(-3.0,40.0,-21.0),"size":Vector3(1.0,10.0,14.0),"basis":Basis.IDENTITY},
		{"kind":"box","middle":Vector3(3.0,40.0,-21.0),"size":Vector3(1.0,10.0,14.0),"basis":Basis.IDENTITY},
		{"kind":"box","middle":Vector3(0.0,45.0,-42.0),"size":Vector3(6.0,1.0,1.0),"basis":Basis.IDENTITY},
		{"kind":"cyl","middle":Vector3(4.0,40.0,-50.0),"radius":1.0,"height":20.0},
	]
	var th := Metrics.summarise(walk,walls)
	check(int(th.openings) == 2 and near(float(th.openings_per_s),0.5,0.001),"Threading: the walls and the lintel are two openings, 0.5 /s (%d)" % th.openings)
	check(near(float(th.threading_share),66.0/241.0,0.01),"Threading: about 1.07 s of 4 s between walls or under the lintel (%.3f)" % th.threading_share)
	check(not Metrics.threading_at(walls,Vector3(0.0,40.0,-50.0),0.0) and Metrics.threading_at(walls,Vector3(0.0,40.0,-21.0),0.0),"A pillar on one side alone isn't threading; walls both sides are")
	check(not Metrics.threading_at(walls,Vector3(0.0,40.0,-21.0),PI*0.5),"Heading along the walls' normal, the side rays run along them: not threading")
	check(not Metrics.summarise(walk).has("threading_share"),"Without solids, no threading numbers")
	# Flow: 1 s straight, 2 s turning at 0.5 rad/s, 1 s straight (60 Hz).
	# The swing is read over the last 0.25 s, so the turn shows 3 ticks
	# late (past 6 deg/s) and the straight after it a quarter second late:
	# still about (1.05 + 0.75) of 4 s, two straights, the longest 1.05 s.
	var bend := straight_run(4.0,1.0/60.0,[0.0],1,[0.0])
	for i in range(bend.ticks.t.size()):
		var at := float(bend.ticks.t[i])
		bend.ticks.heading[i] = 0.5*clampf(at-1.0,0.0,2.0)
	var fl := Metrics.summarise(bend)
	check(near(float(fl.still_share),1.8/4.0,0.02),"Flow: still about 45%% of the run (%.3f)" % fl.still_share)
	check(int(fl.straights) == 2 and near(float(fl.longest_straight),1.05,0.04),"Flow: two straights, the longest about 1.05 s (%d, %.3f)" % [fl.straights,fl.longest_straight])
	check(near(float(fl.yaw_share),1.0,0.001) and near(float(fl.swing_mean),rad_to_deg(0.5)*2.0/4.0,1.0),"Flow: all sideways, mean swing about 14 deg/s (%.2f)" % fl.swing_mean)
	check(int(round(float(fl.swing_reversals_per_s)*4.0)) == 0,"Flow: one steady turn never reverses")
	# A wobble (+-0.1 rad at 2 Hz) is never still but reverses about 4 times a second.
	var wobble := straight_run(4.0,1.0/60.0,[0.0],1,[0.0])
	for i in range(wobble.ticks.t.size()): wobble.ticks.heading[i] = 0.1*sin(TAU*2.0*float(wobble.ticks.t[i]))
	var wf := Metrics.flow(wobble.ticks,4.0)
	check(float(wf.still_share) < 0.1 and float(wf.swing_reversals_per_s) > 3.0,"Flow: a wobble isn't still, but its swing reverses %.1f /s (the jerkiness guard)" % wf.swing_reversals_per_s)
	print("flight metrics: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
