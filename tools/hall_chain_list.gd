extends SceneTree
## The hall chain's numbers, for tuning (docs/design/hall-chain.md), headless:
##   godot --headless --path . -s tools/hall_chain_list.gd [-- <chain and rise flags>] [--halls=8] [--fly=4]
## Prints the first `halls` placements (each hall's turn, climb, the gap's
## arc and how far it is from the trigger to the next gate), then, with
## --fly=<n>, flies the study's autopilot through n halls and prints, for
## each hall it set rising, when (s after the trigger) its gate broke
## through, stopped and was still, and when the plane got to the gate, and
## each hall's main-thread hand-over.
const Chain = preload("res://scripts/hall_chain.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const DT := 1.0/60.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := preload("res://scripts/launch_args.gd").user_args()
	var count := 8
	var fly := 0
	for a: String in args:
		if a.begins_with("--halls="): count = int(a.get_slice("=",1))
		elif a.begins_with("--fly="): fly = int(a.get_slice("=",1))
	var study: Node3D = load("res://studies/hall_chain.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	var chain: Node3D = study.chain
	var cfg: Dictionary = chain.cfg
	var line_len := ChainPlan.line_length()
	print("hall line %.1f m, in at %.1f deg, out at %.1f deg (%.0f deg right through the hall); the way in %.0f m before the line" % [line_len,rad_to_deg(ChainPlan.in_head()),rad_to_deg(ChainPlan.out_head()),rad_to_deg(ChainPlan.in_head()-ChainPlan.out_head()),ChainPlan.LEAD_IN])
	print("next at %.0f%%, gap %.0f m, turn +-%.0f deg, climb +-%.1f m, keep %d, seed %d" % [float(cfg.at)*100.0,cfg.gap,cfg.turn,cfg.climb,cfg.keep,cfg.seed])
	# Placements, on a plain rng like the chain's (no build).
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)*7919+11
	var first: Dictionary = chain.first_pose()
	var poses := [first]
	for k in range(1,count):
		poses.append(ChainPlan.next_pose(poses[-1],rng,cfg,chain.y_range(),poses.slice(maxi(0,poses.size()-maxi(1,int(cfg.keep)))),chain.boxes()))
	var gate := _gate(chain)
	for k in range(1,poses.size()):
		var a: Dictionary = poses[k-1]
		var b: Dictionary = poses[k]
		var arc := ChainPlan.arc(a,b)
		var arc_len := 0.0
		var pts: Array[Vector3] = [ChainPlan.exit_of(a)[0]]
		pts.append_array(arc)
		pts.append(ChainPlan.approach_of(b))
		for i in range(1,pts.size()): arc_len += pts[i].distance_to(pts[i-1])
		var swing := rad_to_deg(wrapf(ChainPlan.in_heading(b)-float(ChainPlan.exit_of(a)[1]),-PI,PI))
		var to := ChainPlan.xform(b)*ChainPlan.local(ChainPlan.line()[0],ChainPlan.hand_of(b))-(ChainPlan.exit_of(a)[0] as Vector3)
		var off_nose := rad_to_deg(wrapf(ChainPlan.heading_of(to)-float(ChainPlan.exit_of(a)[1]),-PI,PI))
		var to_gate := (1.0-float(cfg.at))*line_len+arc_len+ChainPlan.approach().distance_to(ChainPlan.line()[0])
		print("hall %2d  %s  turn %+5.1f deg  climb %+4.1f m  arc %5.1f m (swings %+5.1f deg)  its gate %+5.1f deg off the nose at the exit  trigger to gate %5.1f m = %4.1f s at 14 m/s" % [k,"right" if ChainPlan.hand_of(b) > 0 else "left ",rad_to_deg(float(b.turn)),float(b.climb),arc_len,swing,off_nose,to_gate,to_gate/14.0])
	if fly > 0: await _fly(study,fly)
	study.queue_free()
	await process_frame
	quit(0)

static func _gate(chain: Node3D) -> Dictionary:
	for c: Dictionary in chain.template.chunks:
		if c.id == "gate": return c
	return chain.template.chunks[-1]

## Flies the autopilot through `n` halls, timing each next hall against
## the plane.
func _fly(study: Node3D, n: int) -> void:
	var chain: Node3D = study.chain
	study.autopilot = true
	var arrived := {}
	var trig := {}
	var bumps := 0
	await physics_frame
	var steps := 0
	while steps < int((20.0+22.0*n)/DT):
		study.tick(DT)
		steps += 1
		if steps % 4 == 0: await physics_frame
		for h: Dictionary in chain.halls:
			var i := int(h.index)
			if not trig.has(i): trig[i] = chain.clock
			if not arrived.has(i):
				var local: Vector3 = (h.rise as Node3D).to_local(study.plane.position)
				if ChainPlan.local(local,ChainPlan.hand_of(h.pose)).distance_to(ChainPlan.line()[0]) < 8.0: arrived[i] = chain.clock
		if arrived.size() > n: break
	for i: int in arrived:
		var h: Dictionary = chain.hall(i)
		var g := _gate(chain)
		var spawn := {}
		for s: Dictionary in chain.spawns:
			if int(s.index) == i: spawn = s
		var rise_g := {}
		if not h.is_empty():
			for c: Dictionary in h.rise.chunks:
				if c.id == "gate": rise_g = c
		if rise_g.is_empty(): rise_g = g
		var breaks := -1.0
		for k in range(3000):
			if RisePlan.height_at(rise_g,k*0.01)+float(rise_g.top) > float(h.rise.sea_y if not h.is_empty() else 0.0):
				breaks = float(rise_g.start)+k*0.01
				break
		print("hall %2d  risen at %6.2f s  plane at its gate %5.2f s later  (gate breaks through %5.2f, stops %5.2f, still %5.2f)  hand-over: setup %.2f ms, worst frame %.2f ms, all %.2f ms" % [i,trig[i],float(arrived[i])-float(trig[i]),breaks,RisePlan.stops(rise_g),RisePlan.settles(rise_g),
			float(spawn.get("setup",0))/1000.0,float(spawn.get("frame",0))/1000.0,float(spawn.get("total",0))/1000.0])
	print("bumps %d  halls made %d  most standing %d" % [study.bumps,chain.made,chain.most])
