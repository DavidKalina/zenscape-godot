extends SceneTree
## The hall chain study (studies/hall_chain.gd, scripts/hall_chain.gd,
## scripts/hall_chain_plan.gd, docs/design/hall-chain.md), headless: the
## halls alternate hands (every other one mirrored); each next hall stands
## off the one before's exit, its gate near dead ahead, within the turn and
## height limits, its way in `gap` from the exit on an arc tangent at both
## ends, never on a hall already up; the cruise lane keeps its clearance;
## reaching the trigger sets exactly one next hall rising; past the cap the
## oldest sinks, the rise reversed, colliding with nothing, and is freed;
## the hand-over per hall is small; and the autopilot flies through 3+
## halls in a row, never stuck and never inside stone, the next hall up
## through the cloud dead ahead as it leaves each one, and each gate
## settling (or settled) as it gets there.
##   godot --headless --path . --script tests/test_hall_chain.gd
const Chain = preload("res://scripts/hall_chain.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const Course = preload("res://scripts/flight_course.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("hall chain test timed out"); quit(2))
	_lane()
	study = load("res://studies/hall_chain.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	_placement()
	await _trigger()
	await _cap()
	await _flies()
	study.queue_free()
	await process_frame
	print("PASS: hall chain" if failures == 0 else "FAIL: hall chain (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The cruise lane: the line's ground track, LANE_CLEAR off every stone,
## climbing no more than LANE_SLOPE a sample, inside the hall's height.
func _lane() -> void:
	var lane := ChainPlan.lane()
	var solids := Plan.local_solids(RisePlan.LAYOUT)
	var worst := INF
	var steep := 0.0
	for k in range(lane.size()):
		for q: Dictionary in solids: worst = minf(worst,Course.distance(q,lane[k]))
		if k > 0: steep = maxf(steep,absf(lane[k].y-lane[k-1].y))
	check(lane.size() > 40 and worst >= ChainPlan.LANE_CLEAR-1e-3,"The cruise lane keeps %.2f m off stone (%d points)" % [worst,lane.size()])
	check(steep <= ChainPlan.LANE_SLOPE+1e-3,"It climbs at most %.1f m a sample" % steep)

## 40 placements: the hands alternating; each next way in within the turn
## limit of the heading you leave on and its gate as near dead ahead of
## the exit, within the height limit; its way in `gap` from the exit along
## the arc's chord, the arc tangent to both ends; none on another; the
## chain never drifting round.
func _placement() -> void:
	var chain: Node3D = study.chain
	var cfg: Dictionary = chain.cfg
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var first: Dictionary = chain.first_pose()
	var poses := [first]
	for k in range(1,40): poses.append(ChainPlan.next_pose(poses[-1],rng,cfg,chain.y_range(),poses.slice(maxi(0,poses.size()-int(cfg.keep))),chain.boxes()))
	var limit := deg_to_rad(float(cfg.turn))+1e-4
	var worst_turn := 0.0
	var worst_climb := 0.0
	var gap_off := 0.0
	var tangent := 0.0
	var off_course := 0.0
	var off_nose := 0.0
	var alternate := true
	var y_ok := true
	var yr: Vector2 = chain.y_range()
	for k in range(1,poses.size()):
		var a: Dictionary = poses[k-1]
		var b: Dictionary = poses[k]
		if ChainPlan.hand_of(b) == ChainPlan.hand_of(a): alternate = false
		worst_turn = maxf(worst_turn,absf(wrapf(ChainPlan.in_heading(b)-float(ChainPlan.exit_of(a)[1]),-PI,PI)))
		var gate := ChainPlan.xform(b)*ChainPlan.local(ChainPlan.line()[0],ChainPlan.hand_of(b))-(ChainPlan.exit_of(a)[0] as Vector3)
		off_nose = maxf(off_nose,absf(wrapf(ChainPlan.heading_of(gate)-float(ChainPlan.exit_of(a)[1]),-PI,PI)))
		worst_climb = maxf(worst_climb,absf(float(b.origin.y)-float(a.origin.y)))
		if float(b.origin.y) < yr.x-1e-3 or float(b.origin.y) > yr.y+1e-3: y_ok = false
		var p: Vector3 = ChainPlan.exit_of(a)[0]
		var q := ChainPlan.approach_of(b)
		gap_off = maxf(gap_off,absf(Vector2(q.x-p.x,q.z-p.z).length()-float(cfg.gap)))
		var arc := ChainPlan.arc(a,b)
		var lead := ChainPlan.heading_of(arc[0]-p)
		var into := ChainPlan.heading_of(q-arc[-1])
		var x := float(ChainPlan.exit_of(a)[1])
		var i := ChainPlan.in_heading(b)
		# A chord on a circle leaves at half the step off the tangent.
		var step := wrapf(i-x,-PI,PI)/float(arc.size()+1)
		tangent = maxf(tangent,maxf(absf(wrapf(lead-x-step*0.5,-PI,PI)),absf(wrapf(into-i+step*0.5,-PI,PI))))
		off_course = maxf(off_course,absf(float(b.drift)))
	check(alternate,"The hands alternate (every other hall mirrored)")
	check(worst_turn <= limit,"Each next way in swings at most %.1f deg off the heading you leave on (limit %.0f)" % [rad_to_deg(worst_turn),cfg.turn])
	check(off_nose <= limit,"Each next gate stands within %.1f deg of the nose at the exit" % rad_to_deg(off_nose))
	check(worst_climb <= float(cfg.climb)+1e-3 and y_ok,"Each stands at most %.1f m over or under the one before (limit %.1f), %.0f-%.0f m over the cloud" % [worst_climb,cfg.climb,ChainPlan.CLEAR_RANGE.x,ChainPlan.CLEAR_RANGE.y])
	check(gap_off < 0.01,"Each way in is %.0f m from the exit before (off %.4f m)" % [cfg.gap,gap_off])
	check(tangent < deg_to_rad(1.0),"The arc between leaves the exit and meets the way in on their headings (off %.2f deg)" % rad_to_deg(tangent))
	check(off_course < deg_to_rad(30.0),"The chain wanders but never drifts round (the turns add up to at most %.0f deg)" % rad_to_deg(off_course))
	var overlap := 0
	for k in range(poses.size()):
		if ChainPlan.overlaps(poses[k],poses.slice(0,k),chain.boxes()): overlap += 1
	check(overlap == 0,"No hall stands within %.0f m of any before it, over 40 (%d do)" % [ChainPlan.APART,overlap])
	var again := RandomNumberGenerator.new()
	again.seed = 5
	var same: Dictionary = ChainPlan.next_pose(first,again,cfg,chain.y_range(),[first],chain.boxes())
	check(same.origin == poses[1].origin and is_equal_approx(float(same.yaw),float(poses[1].yaw)),"The same seed places the same")

## The plane along the first hall's line: no next hall before `at`, exactly
## one once it is past, and still one as it flies on to the end; the new
## hall rises on its own (hidden, then risen and solid).
func _trigger() -> void:
	var chain: Node3D = study.chain
	study.leave()
	chain.reset()
	var at := float(chain.cfg.at)
	var line := ChainPlan.line()
	var t: Transform3D = ChainPlan.xform(chain.halls[0].pose)
	var before := 0
	var after := 0
	var cum := PackedFloat32Array([0.0])
	for k in range(1,line.size()): cum.append(cum[-1]+line[k].distance_to(line[k-1]))
	var total := cum[-1]
	var first_at := -1.0
	for s in range(201):
		var share := float(s)/200.0
		var want := share*total
		var k := 1
		while k < line.size()-1 and cum[k] < want: k += 1
		var p := line[k-1].lerp(line[k],clampf((want-cum[k-1])/maxf(cum[k]-cum[k-1],1e-6),0.0,1.0))
		chain.advance(DT,t*p)
		if share < at-0.01 and chain.made > 1: before += 1
		if chain.made > 1 and first_at < 0.0: first_at = share
	after = chain.made-1
	check(before == 0,"No next hall before %.0f%% of the line" % (at*100.0))
	check(after == 1 and absf(first_at-at) <= 0.011,"Exactly one next hall, set rising at %.0f%% (made %d)" % [first_at*100.0,chain.made])
	# Off the line (far to the side) never triggers.
	chain.reset()
	for s in range(200): chain.advance(DT,t*(line[mini(int(s/10.0),line.size()-1)]+Vector3(200.0,0.0,0.0)))
	check(chain.made == 1,"Far off the line it doesn't")
	# The next hall rises: on the newest's own plan, solid once settled.
	chain.spawn_next()
	var h: Dictionary = chain.halls[-1]
	var rise: Node3D = h.rise
	var hidden_first := true
	for i in range(rise.chunks.size()):
		if rise.nodes[i] != null and (rise.nodes[i] as Node3D).visible: hidden_first = false
	var waited := 0.0
	while float(rise.done_at) < 0.0 and waited < 30.0:
		chain.advance(DT,null)
		waited += DT
		if int(waited/DT) % 30 == 0: await process_frame
	check(hidden_first and float(rise.done_at) > 0.0 and rise._all_set(),"The next hall rises from under the cloud and settles, solid (%.2f s)" % rise.done_at)
	var turn := absf(wrapf(ChainPlan.in_heading(h.pose)-float(ChainPlan.exit_of(chain.halls[0].pose)[1]),-PI,PI))
	check(turn <= deg_to_rad(float(chain.cfg.turn))+1e-4 and absf(float(h.pose.origin.y)-float(chain.halls[0].pose.origin.y)) <= float(chain.cfg.climb)+1e-3,"Placed off the first's exit within the limits (turn %.1f deg, climb %.1f m)" % [rad_to_deg(turn),float(h.pose.origin.y)-float(chain.halls[0].pose.origin.y)])
	var s: Dictionary = chain.spawns[-1]
	check(int(s.setup) < 4000 and int(s.frame) < 4000,"Its main-thread hand-over: setup %.2f ms, worst frame %.2f ms, all %.2f ms" % [float(s.setup)/1000.0,float(s.frame)/1000.0,float(s.total)/1000.0])

## Keep 2: the third hall sinks the oldest, which stops colliding at once,
## goes down the rise reversed (each chunk where its rise had it, the
## gate first), hides and is freed; the count stays bounded however many
## more come.
func _cap() -> void:
	var chain: Node3D = study.chain
	chain.cfg.keep = 2
	chain.reset()
	for i in range(int(14.0/DT)):
		chain.advance(DT,null)
		if i % 30 == 0: await process_frame
	chain.spawn_next()
	for i in range(int(14.0/DT)):
		chain.advance(DT,null)
		if i % 30 == 0: await process_frame
	var oldest: Node3D = chain.halls[0].rise
	check(not oldest.sinking and chain.standing_count() == 2,"Two halls up, none sinking")
	chain.spawn_next()
	check(oldest.sinking and chain.standing_count() == 2,"The third sets the oldest sinking (standing %d)" % chain.standing_count())
	var solid := 0
	for i in range(oldest.chunks.size()):
		if (oldest.nodes[i].get_node(^"Body") as StaticBody3D).collision_layer != 0: solid += 1
	check(solid == 0,"Sinking, it collides with nothing")
	# Reversed: at sink time s each chunk stands where the rise had it at
	# length - s.
	var length := float(oldest.plan.length)
	var off := 0.0
	var gate_first := true
	var first_down := -1
	var sampled := 0
	var freed := false
	var t := 0.0
	var under_by: float = oldest.sink_length()
	while t < under_by+1.0:
		chain.advance(DT,null)
		t += DT
		if int(t/DT) % 30 == 0: await process_frame
		if not is_instance_valid(oldest) or not oldest.is_inside_tree():
			freed = true
			break
		for i in range(oldest.chunks.size()):
			var c: Dictionary = oldest.chunks[i]
			if oldest.state[i] != "sinking": continue
			var rise_t: float = length-float(oldest.sink_clock)-float(c.start)
			if rise_t >= RisePlan.settles(c)-float(c.start): continue
			if first_down < 0: first_down = i
			off = maxf(off,absf((oldest.nodes[i] as Node3D).position.y-RisePlan.height_at(c,rise_t)))
			sampled += 1
	check(sampled > 100 and off < 0.05,"Each chunk goes down the way it came up (worst %.3f m off, %d samples)" % [off,sampled])
	check(first_down == oldest.chunks.size()-1 and gate_first,"The last up (the %s) goes down first" % (oldest.chunks[maxi(first_down,0)].id))
	check(freed and chain.sunk_count == 1,"Under in %.1f s and freed (%d sunk)" % [under_by,chain.sunk_count])
	for k in range(5):
		chain.spawn_next()
		for i in range(int(3.0/DT)):
			chain.advance(DT,null)
			if i % 30 == 0: await process_frame
	for i in range(int(14.0/DT)):
		chain.advance(DT,null)
		if i % 30 == 0: await process_frame
	check(chain.halls.size() == 2 and chain.get_child_count() == 2 and chain.made == 8,"Five more: still two up (%d halls, %d nodes, %d made, %d sunk)" % [chain.halls.size(),chain.get_child_count(),chain.made,chain.sunk_count])
	check(chain.route.size() < 3*(ChainPlan.lane().size()+60),"The route is trimmed with them (%d points)" % chain.route.size())
	chain.cfg.keep = int(ChainPlan.CHAIN.keep)

## From the start, the autopilot flies the route through four halls: never
## stuck, never inside stone, each next gate settling or settled when it
## gets there.
func _flies() -> void:
	var chain: Node3D = study.chain
	chain.reset()
	study.board(true)
	study.autopilot = true
	await physics_frame
	var stuck := 0
	var shut := 0
	var last: Vector3 = study.plane.position
	var through := {}
	var arrived := {}
	var gate_ok := 0
	var gate_late := []
	var left := {}
	var exits_ok := 0
	var exits_bad := []
	var steps := 0
	while through.size() < 4 and steps < int(110.0/DT):
		study.tick(DT)
		steps += 1
		if steps % 4 == 0:
			await physics_frame
			if study._inside_stone(study.plane.position): shut += 1
		if steps % 60 == 59:
			if study.plane.position.distance_to(last) < 6.0: stuck += 1
			last = study.plane.position
		for h: Dictionary in chain.halls:
			var i := int(h.index)
			var rise: Node3D = h.rise
			var local: Vector3 = rise.to_local(study.plane.position)
			if not arrived.has(i) and ChainPlan.local(local,ChainPlan.hand_of(h.pose)).distance_to(ChainPlan.line()[0]) < 8.0:
				arrived[i] = true
				# The gate: the last chunk up.
				var g: int = rise.chunks.size()-1
				var c: Dictionary = rise.chunks[g]
				var t := float(rise.clock)-float(rise.began_at[g])
				var easing: bool = rise.state[g] != "waiting" and (rise.state[g] != "moving" or t >= float(c.t_in)+float(c.t_run))
				if easing: gate_ok += 1
				else: gate_late.append(i)
			if float(h.progress) >= 0.97: through[i] = true
			# Leaving: the next hall up (all four through the cloud) dead ahead.
			if float(h.progress) >= 0.99 and not left.has(i):
				left[i] = true
				var nxt: Dictionary = chain.hall(i+1)
				if nxt.is_empty():
					exits_bad.append(i)
					continue
				var up := 0
				for b in nxt.rise.broke: up += b
				var gate_at := ChainPlan.xform(nxt.pose)*ChainPlan.local(ChainPlan.line()[0],ChainPlan.hand_of(nxt.pose))
				var off := absf(wrapf(ChainPlan.heading_of(gate_at-study.plane.position)-float(study.plane.heading),-PI,PI))
				if up == nxt.rise.chunks.size() and off < deg_to_rad(15.0): exits_ok += 1
				else: exits_bad.append([i,up,snappedf(rad_to_deg(off),0.1)])
	var in_row := 0
	while through.has(in_row): in_row += 1
	check(in_row >= 3,"The autopilot flies through %d halls in a row (%d made, %.0f s)" % [in_row,chain.made,steps*DT])
	check(stuck == 0 and float(study.plane.speed) >= 6.9,"Never stuck (bumps %d)" % study.bumps)
	check(shut == 0,"Never inside stone")
	check(exits_bad.is_empty() and exits_ok >= 3,"Leaving each hall, the next is up through the cloud dead ahead (%d; not: %s)" % [exits_ok,exits_bad])
	check(gate_late.is_empty() and gate_ok >= 3,"Each gate easing in or settled as the plane gets to it (%d of %d; early at %s)" % [gate_ok,arrived.size(),gate_late])
	study.leave()
