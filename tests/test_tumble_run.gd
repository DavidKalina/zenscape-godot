extends SceneTree
## The Tumble Run (scripts/traps/trap_tumble_run.gd) in the trap yard,
## headless:
##   - the layout: a few Tumbling Blocks staggered across x, up and down,
##     each hop within his jump AT THE MOTION'S WORST (the blocks bobbing,
##     drifting, swaying and dipping apart: a running small hop's reach at the
##     highest rise, a climb within a lip a jump catches), never closing shut,
##     no two blocks swinging or moving into each other, the first and the
##     last reachable from the decks; each block meaner than the single cube
##     (steeper, a quicker lurch) with its own personality;
##   - a scripted rider through the real play loop (the study's own frames,
##     the stick and the jump pressed as input actions, the camera held along
##     the route) hops from the start deck onto block 1, rides it, hops on to
##     block 2 and is carried by it (jumping a lurch if it comes, the blocks
##     moving), each block carrying him only while he is on it;
##   - a rider who just stands there, landed on each block: it puts him off
##     into the void sooner than the same block calmed (round 1's rhythm:
##     no wake, feint, double, motion, the single cube's tip, lurch and
##     throw), and thrown, not only slid;
##   - a fall into the void puts him back at the start with the blocks as
##     built.
##   godot --headless --path . --script tests/test_tumble_run.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const Run = preload("res://scripts/traps/trap_tumble_run.gd")
const Yard = preload("res://studies/trap_yard.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
var failures := 0
var study: Node3D
var m: PilotMotor
var run_trap: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("tumble run test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	await physics_frame
	await physics_frame
	run_trap = study.traps.named("tumble_run")
	_layout()
	await _hops()
	await _carry_each()
	await _standers()
	await _fall()
	print("tumble run: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The data list laid out, against his jumps.
func _layout() -> void:
	var p := Trap.pilot()
	var jump := float(p.jumps[0])
	var laid: Dictionary = Run.plan(Run.BLOCKS)
	var rows: Array = laid.rows
	check(run_trap != null and run_trap.blocks.size() == rows.size() and rows.size() >= 4 and rows.size() <= 6,"The yard has the run: %d blocks over open void" % rows.size())
	check(run_trap.open_below() and run_trap.danger() == 5,"...a fall is the void (danger %d)" % run_trap.danger())
	var worst := 0.0
	var hops_ok := true
	var report := ""
	var moving := 0
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var dy := float(r.dy_worst)
		var reach := Run.reach(p,dy)
		worst = maxf(worst,float(r.wide)/reach)
		var rise_ok: bool = dy <= jump*Run.HOP_UP+0.001 or (bool(r.climb) and dy <= RuinKit.GRAB_TOP*0.75 and float(r.wide) <= jump)
		var gap_ok: bool = float(r.wide) <= reach*0.85 and float(r.narrow) > 0.2 and float(r.wide) >= float(r.gap) and float(r.dy_worst) >= float(r.dy)
		hops_ok = hops_ok and rise_ok and gap_ok
		if float(r.wide) > float(r.narrow)+0.01 or float(r.dy_worst) > float(r.dy)+0.01: moving += 1
		report += " %d:%.2f-%.2fm/%+.2f..%+.2fm%s" % [i+1,float(r.narrow),float(r.wide),float(r.dy),dy,"^" if bool(r.climb) else ""]
	var last: Dictionary = rows[rows.size()-1]
	var exit_ok: bool = float(laid.exit_wide) <= Run.reach(p,float(laid.exit_dy_worst))*0.85 and float(laid.exit_gap) > 0.2
	check(hops_ok and exit_ok,"Every hop is within his jump at the motion's worst (a running small hop at the highest rise: the widest gap at most %.0f%% of its reach, the narrowest still open, rises a hop or a climb a lip catches):%s, out %.2f-%.2fm" % [worst*100.0,report,float(laid.exit_gap),float(laid.exit_wide)])
	check(moving >= 4,"...the gaps open and close and the heights move under %d of the %d hops" % [moving,rows.size()])
	var shares := []
	for r: Dictionary in rows: shares.append(float(r.wide)/Run.reach(p,float(r.dy_worst)))
	check(shares.min() < 0.5 and shares.max() >= 0.65,"...some easy (%.0f%% of a running reach), some wanting the run (%.0f%%)" % [float(shares.min())*100.0,float(shares.max())*100.0])
	var clear := true
	for i in range(rows.size()):
		for j in range(i+1,rows.size()):
			if not Run.clear_of(rows[i],rows[j]): clear = false
	check(clear,"No two blocks swing into each other (apart across x, or a swing apart)")
	var half: float = Yard.DECK_WIDE*0.5
	var first: Dictionary = rows[0]
	check(absf(float(first.x))-float(first.size)*0.5 < half and absf(float(last.x))-float(last.size)*0.5 < half,"The first block is hopped onto from the start deck and the last off onto the far deck (both over the deck's width)")
	check(absf(float(laid.length)-run_trap.length()) < 0.001 and absf(-(float(last.z)-float(last.size)*0.5)+float(laid.exit_gap)-run_trap.length()) < 0.001,"...the far deck is the exit hop past the last block (%.1f m of route)" % run_trap.length())
	var xs := rows.map(func(r: Dictionary) -> float: return float(r.x))
	var tops := rows.map(func(r: Dictionary) -> float: return snappedf(float(r.top),0.05))
	var sizes := rows.map(func(r: Dictionary) -> float: return snappedf(float(r.size),0.05))
	var turn: int = run_trap.blocks.filter(func(b: Node3D) -> bool: return float(b.knob("dir")) < 0.0).size()
	var shifts := {}
	for b: Node3D in run_trap.blocks: shifts[snappedf(float(b.phase_t),0.01)] = true
	check(xs.max()-xs.min() > float(first.size) and tops.max()-tops.min() > jump*1.5 and Array(sizes).size() > 0 and _distinct(sizes) >= 3,"Staggered, not a line: %.1f m across x, %.1f m up and down, %d sizes" % [xs.max()-xs.min(),tops.max()-tops.min(),_distinct(sizes)])
	check(shifts.size() == rows.size() and turn == 1,"...each with its own rhythm delay (%d), one turning the other way" % shifts.size())
	var placed := true
	for i in range(rows.size()):
		var b: Node3D = run_trap.blocks[i]
		var at: Vector3 = run_trap.to_local(b.top_point())
		placed = placed and absf(at.x-float(rows[i].x)) < 0.01 and absf(at.z-float(rows[i].z)) < 0.01 and absf(at.y-float(rows[i].top)) < 0.01
	check(placed,"...and each laid where the plan puts its flat top")
	# Meaner than the single cube, each its own way.
	var cube: Dictionary = preload("res://scripts/traps/trap_tumble.gd").new().defaults()
	var meaner := true
	var traits := {}
	for b: Node3D in run_trap.blocks:
		meaner = meaner and float(b.knob("tip")) > float(cube.tip) and float(b.knob("tip")) < float(b.knob("throw_at")) and float(b.knob("lurch")) < float(cube.lurch) and float(b.knob("throw")) > float(cube.throw) and float(b.knob("ramp")) > float(cube.ramp)
		for t: String in ["wake","feint","double","dip","bob","drift","sway"]:
			if float(b.knob(t)) > 0.0: traits[t] = int(traits.get(t,0))+1
	check(meaner,"Every block is meaner than the single cube: a steeper tip (still under the throw), a quicker lurch, a harder throw, a faster ramp")
	check(traits.size() == 7,"...with personalities across the run: %s" % str(traits))

func _distinct(values: Array) -> int:
	var seen := {}
	for v: float in values: seen[v] = true
	return seen.size()

# --- The scripted rider through the real play loop ---

var _jump_left := 0
var jumped_lurch := 0

## The stick toward world direction `way` (x right, y the way on: -z is up
## the screen) and a fresh jump press held a few frames.
func _play(way: Vector2, jump: bool) -> void:
	for action: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right"]: Input.action_release(action)
	if way.length() > 0.01:
		var d := way.normalized()
		if d.y < 0.0: Input.action_press(&"move_forward",-d.y)
		elif d.y > 0.0: Input.action_press(&"move_back",d.y)
		if d.x < 0.0: Input.action_press(&"move_left",-d.x)
		elif d.x > 0.0: Input.action_press(&"move_right",d.x)
	if jump and _jump_left <= -2: _jump_left = 10
	if _jump_left > 0: Input.action_press(&"walk_jump")
	else: Input.action_release(&"walk_jump")
	_jump_left -= 1
	study.set("_yaw",0.0)

func _let_go() -> void:
	for action: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump"]: Input.action_release(action)
	_jump_left = 0

func _frame() -> float:
	await process_frame
	return study.get_process_delta_time()

## Metres from the feet (xz) to block `b`'s flat top (0 over it).
func _dist_to(b: Node3D) -> float:
	var c: Vector3 = b.middle()
	var half := float(b.knob("size"))*0.5
	var dx := maxf(absf(m.feet.x-c.x)-half,0.0)
	var dz := maxf(absf(m.feet.z-c.z)-half,0.0)
	return Vector2(dx,dz).length()

## Hop from `src` (the block he stands on; null for the start deck) to block
## `b` across a gap of `gap` m: from the deck, straight on at it; from a block,
## as a player times it: he keeps the block's station (jumping its lurch)
## till its lurch is far enough off and he'd land on `b` clear of its own,
## then runs across at `b` along the strip the two share (in z) and jumps at
## the edge. True once he stands on `b`.
func _hop(src: Node3D, b: Node3D, gap: float, limit: float) -> bool:
	var t := 0.0
	var on := 0
	# Off a block, he goes when the two rhythms let him; till then he keeps
	# its station and jumps its lurch.
	var going := src == null
	var stuck := 0.0
	var last_d := INF
	while t < limit:
		var tc: Vector3 = b.middle()
		var bh := float(b.knob("size"))*0.5
		var way := Vector2.ZERO
		var jump := false
		var goal := Vector2.ZERO
		if src == null:
			way = Vector2(clampf(tc.x-m.feet.x,-bh+1.0,bh-1.0),-6.0)
			jump = m.grounded and _dist_to(b) <= gap+0.12 and not b.riding()
		else:
			var sc: Vector3 = src.middle()
			var sh := float(src.knob("size"))*0.5
			var line_z := (maxf(sc.z-sh,tc.z-bh)+minf(sc.z+sh,tc.z+bh))*0.5
			var side := signf(tc.x-sc.x)
			# He goes when his own block's lurch is far enough off to cross
			# it, and he'd land on the other clear of its lurch (time to find
			# his feet before it, or once it has gone); and turns back to his
			# station if his own lurch draws near first.
			var due: float = b.until_lurch()
			if not going and src.phase != "lurch" and src.until_lurch() > 1.8 and (due > 2.0 or due < 0.6 or b.phase == "lurch"): going = true
			if going and src.riding() and src.until_lurch() < 0.9: going = false
			if not going:
				# Station as the single cube's skilled rider keeps it: the
				# middle at rest, uphill of it as it tips (the ridge passes
				# under him there when he jumps the lurch).
				goal = _station(src,0.0,-0.3 if src.phase == "tip" else 0.0)
				way = goal-Vector2(m.feet.x,m.feet.z)
				if way.length() < 0.3: way = Vector2.ZERO
			else:
				# Across at the other, along the strip the two share (in z).
				goal = Vector2(tc.x,line_z)
				way = Vector2(side*3.0,clampf((line_z-m.feet.z)*2.0,-2.0,2.0))
				jump = m.grounded and _dist_to(b) <= gap+0.12 and not b.riding()
		# Pressing on and not getting on over the stone: hop what blocks him
		# (the sweeper's bar).
		var d := Vector2(m.feet.x,m.feet.z).distance_to(goal)
		stuck = stuck+1.0/60.0 if way.length() > 0.01 and m.grounded and d > last_d-m.walk*0.3/60.0 and src != null else 0.0
		last_d = d
		if stuck > 0.15: jump = true
		# Hanging from a lip (a step's, or one he dropped to): climb up.
		if src != null and m.on_ledge(): way = Vector2(-m.lip_out.x,-m.lip_out.y)
		# The shudder's end: in the air through the lurch, as a player would.
		if src != null and src.riding() and m.grounded and src.phase == "tip" and src.until_lurch() <= 0.08:
			jump = true
			jumped_lurch += 1
		_play(way,jump)
		t += await _frame()
		on = on+1 if m.grounded and b.riding() else 0
		if OS.get_environment("TRACE") != "":
			if src != null: print("    src %s %.2f ul %.2f roll %.2f riding %s slide %.2f off %s local %s hold %s going %s" % [src.phase,src.phase_t,src.until_lurch(),src.roll,src.riding(),src.slide,src.put_off,src.block_local(m.feet).snapped(Vector3.ONE*0.01),m.hold,going])
			print("  t %.2f feet %s grounded %s going %s dist %.2f riding %s rt %.2f phase %s %.2f vel %s" % [t,m.feet.snapped(Vector3.ONE*0.01),m.grounded,going,_dist_to(b),b.riding(),b.riding_time,b.phase,b.phase_t,m.velocity.snapped(Vector3.ONE*0.1)])
		if on >= 12:
			_let_go()
			return true
	_let_go()
	return false

## Stood still on `b` (once he has settled): carried with it as it turns, his
## place in the block's own frame holding while the block moves in the world.
## Returns {"ok", "drift", "moved"}.
func _stand(b: Node3D, seconds: float) -> Dictionary:
	var t := 0.0
	while t < 1.0 and (Vector2(m.velocity.x,m.velocity.z).length() > 0.2 or not m.grounded):
		_play(Vector2.ZERO,false)
		t += await _frame()
		if OS.get_environment("TRACE") != "": print("  settle %.2f feet %s vel %s riding %s grounded %s %s %.2f off %s" % [t,m.feet.snapped(Vector3.ONE*0.01),m.velocity.snapped(Vector3.ONE*0.1),b.riding(),m.grounded,b.phase,b.phase_t,b.put_off])
	var local: Vector3 = b.block_local(m.feet)
	var world := m.feet
	var drift := 0.0
	var moved := 0.0
	t = 0.0
	# Carried, standing; if its shudder comes he does as a player would:
	# up to the station uphill, jumps the lurch, lands back on it and stands
	# on (his place taken afresh). Only the standing counts.
	var held := 0.0
	var ok := true
	var hops := 0
	var slid := 0.0
	while t < seconds:
		if b.shuddering() and m.grounded:
			hops += 1
			var air := 0.0
			var x := float(b.face_local(b.top_face(),m.feet).x)
			while air < 4.0 and not (b.phase == "lurch" or b.until_lurch() <= 0.08):
				_play(_station(b,x,-0.3)-Vector2(m.feet.x,m.feet.z),false)
				air += await _frame()
				if OS.get_environment("TRACE") != "": print("  station %s ul %.2f local %s grounded %s riding %s hold %s" % [b.phase,b.until_lurch(),b.face_local(b.top_face(),m.feet).snapped(Vector3.ONE*0.01),m.grounded,b.riding(),m.hold])
			_play(Vector2.ZERO,true)
			air += await _frame()
			while air < 4.0 and not (m.grounded and b.riding() and b.phase == "rest"):
				_play(Vector2.ZERO,false)
				air += await _frame()
				if OS.get_environment("TRACE") != "": print("  air %s %.2f local %s grounded %s riding %s off %s" % [b.phase,b.phase_t,b.block_local(m.feet).snapped(Vector3.ONE*0.01),m.grounded,b.riding(),b.put_off])
			local = b.block_local(m.feet)
			world = m.feet
			slid = 0.0
			if not b.riding(): ok = false
			if not ok or hops > 1: break
			continue
		_play(Vector2.ZERO,false)
		var dt := await _frame()
		t += dt
		# What the slick slides him down its fall line is the stone's doing
		# too: the drift is past it.
		slid += float(b.slide)*dt
		drift = maxf(drift,b.block_local(m.feet).distance_to(local)-slid)
		moved = maxf(moved,m.feet.distance_to(world))
		ok = ok and b.riding()
		held = t
	_let_go()
	return {"ok":ok and held >= minf(seconds,0.3),"drift":drift,"moved":moved,"phase":b.phase,"held":held,"hops":hops,"slid":slid}

## A place (world xz) on block `b`'s top face: `x` across it (its own
## frame), `along` a share of the half side up the fall line (-1 the
## uphill edge as it tips, 0 the middle).
func _station(b: Node3D, x: float, along: float) -> Vector2:
	var k: int = b.top_face()
	var half := float(b.knob("size"))*0.5
	# Its top moves toward +z (dir 1): its -z edge is the high one.
	var p: Vector3 = b.to_global(b._transform()*(b._face_basis(k)*Vector3(x,half,along*half*signf(float(b.knob("dir"))))))
	return Vector2(p.x,p.z)

func _hops() -> void:
	study.scripted = false
	var laid: Dictionary = Run.plan(Run.BLOCKS)
	var spawn: Vector3 = run_trap.position+Vector3(0.0,0.0,run_trap.run_up())
	study.place(spawn,Vector2(0.0,-1.0))
	await physics_frame
	var b1: Node3D = run_trap.blocks[0]
	var b2: Node3D = run_trap.blocks[1]
	check(run_trap.riding_block() == null and b1.phase_t <= 0.0,"Set down at the start deck: on no block, the blocks as built")
	var got := await _hop(null,b1,float(laid.rows[0].gap),6.0)
	var in1: Node3D = run_trap.riding_block()
	check(got and in1 == b1,"Hopped from the start deck onto block 1 (the rider is on block %d)" % (run_trap.blocks.find(in1)+1))
	var s1 := await _stand(b1,0.5)
	check(s1.ok and float(s1.drift) < 0.3,"Block 1 carries him: stood still on it he stays where he is on the stone (%.2f m of drift, %.2f m moved with it in the world, %s)" % [s1.drift,s1.moved,s1.phase])
	var go := await _hop(b1,b2,float(laid.rows[1].gap),14.0)
	var in2: Node3D = run_trap.riding_block()
	check(go and in2 == b2,"...hopped from block 1 across to block 2, timed to both blocks' rhythms (on block %d; %.1f s on 1, %.1f on 2; block 1 woke %d, lurched %d, he jumped %d lurch(es))" % [run_trap.blocks.find(in2)+1,b1.riding_time,b2.riding_time,b1.wakes,b1.lurches,jumped_lurch])
	var s2 := await _stand(b2,0.8)
	check(s2.ok and float(s2.drift) < 0.3,"...and block 2 carries him in turn (%.2f m of drift past %.2f m slid on the slick, %.2f m moved with it in the world, %s; its lurch jumped %d time(s))" % [s2.drift,s2.slid,s2.moved,s2.phase,s2.hops])
	check(b1.riding_time > 0.3 and b2.riding_time > 0.3 and run_trap.blocks[2].riding_time == 0.0,"...each block counts only the time he is on it (%.1f s, %.1f s, %.1f s)" % [b1.riding_time,b2.riding_time,run_trap.blocks[2].riding_time])

## Each block in turn, with him set down on it as it begins to tip: it alone
## carries him (his place on it holds, the world moves), the others none.
func _carry_each() -> void:
	var worst := 0.0
	var least := INF
	var alone := true
	for i in range(run_trap.blocks.size()):
		var b: Node3D = run_trap.blocks[i]
		var at: Vector3 = b.top_point()+Vector3(0.0,0.0,float(b.knob("size"))*0.3)
		study.place(at+Vector3.UP*0.05,Vector2(0.0,-1.0))
		b.phase = "tip"
		b.phase_t = 0.0
		b._pose()
		await physics_frame
		var s := await _stand(b,0.6)
		worst = maxf(worst,float(s.drift))
		least = minf(least,float(s.moved))
		for o: Node3D in run_trap.blocks:
			if o != b and o.riding_time > 0.0: alone = false
		if not s.ok: alone = false
	check(alone and worst < 0.3 and least > 0.03,"Each of the %d blocks carries him alone, set on it as it tips (at most %.2f m of drift on the stone, at least %.2f m moved with it in the world; no other block counts him)" % [run_trap.blocks.size(),worst,least])

## The knobs round 2 added or sharpened, as round 1 laid them: the calm block.
func _calm(b: Node3D) -> Dictionary:
	var cube: Dictionary = preload("res://scripts/traps/trap_tumble.gd").new().defaults()
	var was := {}
	for k: String in ["tip","lurch","throw","jolt","ramp","ramp_top","wake","feint","double","dip","bob","drift","sway"]:
		was[k] = b.knobs[k]
		b.knobs[k] = cube[k]
	return was

## Landed on block `b` at the middle of its top (the blocks as built, its
## rest from the start) and stood still: seconds till he is in the void, and
## how he was put off.
func _stander(b: Node3D, limit: float) -> Dictionary:
	_let_go()
	study.place(b.top_point()+Vector3.UP*0.3,Vector2(0.0,-1.0))
	b.phase_t = 0.0
	await physics_frame
	var t := 0.0
	var speed := 0.0
	var landed := false
	while t < limit:
		_play(Vector2.ZERO,false)
		t += await _frame()
		landed = landed or b.riding()
		if b.put_off != "" and speed == 0.0: speed = m.velocity.length()
		if landed and m.feet.y < b.middle().y-0.5 and not b.riding(): break
	_let_go()
	return {"t":t,"how":b.put_off if b.put_off != "" else "slid","speed":speed,"woke":b.wakes,"feints":b.feints,"lurches":b.lurches,"heard":b.heard.map(func(h: Array) -> String: return String(h[0]))}

## A rider who stands there: each block puts him off sooner than calmed.
func _standers() -> void:
	var sooner := true
	var threw := 0
	var report := ""
	var woke := true
	for i in range(run_trap.blocks.size()):
		var b: Node3D = run_trap.blocks[i]
		var mean := await _stander(b,20.0)
		if float(b.knob("wake")) > 0.0: woke = woke and int(mean.woke) == 1 and "wake" in mean.heard
		var was := _calm(b)
		var calm := await _stander(b,20.0)
		b.knobs.merge(was,true)
		sooner = sooner and float(mean.t) < float(calm.t)-0.3 and float(mean.t) < 20.0
		if mean.how in ["thrown","jolted"]: threw += 1
		report += " %d: %.1f s %s %.1f m/s (calm %.1f s %s);" % [i+1,mean.t,mean.how,mean.speed,calm.t,calm.how]
	check(sooner,"A rider who just stands there is put off every block sooner than the same block calmed:%s" % report)
	check(threw >= 3,"...thrown or jolted off, not just slid, by %d of the %d blocks" % [threw,run_trap.blocks.size()])
	check(woke,"...each waking block woke as he landed, told (its \"wake\")")
	study.place(run_trap.position+Vector3(0.0,0.0,run_trap.run_up()),Vector2(0.0,-1.0))
	await physics_frame

## Into the void: set down at the start with the blocks as built.
func _fall() -> void:
	var b1: Node3D = run_trap.blocks[0]
	m.reset(Vector3(run_trap.position.x,study.lost-3.0,-6.0),0.0)
	var t := 0.0
	while t < 3.0 and m.feet.y < study.lost:
		_play(Vector2.ZERO,false)
		t += await _frame()
	_let_go()
	await _frame()
	await _frame()
	var back: bool = m.feet.y > -1.0 and m.feet.z > 0.0 and run_trap.riding_block() == null
	check(back,"A fall into the void sends him back to the start deck (%s)" % str(m.feet.snapped(Vector3.ONE*0.1)))
	check(b1.riding_time == 0.0 and b1.phase == "rest" and b1.lurches == 0 and b1.phase_t <= 0.0,"...with the blocks as built (block 1 at rest, its clock cleared)")
