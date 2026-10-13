extends SceneTree
## The Tumble Run (scripts/traps/trap_tumble_run.gd) in the trap yard,
## headless:
##   - the layout: a few Tumbling Blocks staggered across x, up and down,
##     each hop within his jump (a running small hop's reach at that rise, a
##     climb within a lip a jump catches), no two blocks swinging into each
##     other, the first and the last reachable from the decks;
##   - a scripted rider through the real play loop (the study's own frames,
##     the stick and the jump pressed as input actions, the camera held along
##     the route) hops from the start deck onto block 1, rides it, hops on to
##     block 2 and is carried by it, each block carrying him only while he
##     is on it; and a fall into the void puts him back at the start with
##     the blocks as built.
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
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var reach := Run.reach(p,float(r.dy))
		worst = maxf(worst,float(r.gap)/reach)
		var rise_ok: bool = float(r.dy) <= jump*Run.HOP_UP+0.001 or (bool(r.climb) and float(r.dy) <= RuinKit.GRAB_TOP*0.75 and float(r.gap) <= jump)
		var gap_ok: bool = float(r.gap) <= reach*0.85 and float(r.gap) > 0.2
		hops_ok = hops_ok and rise_ok and gap_ok
		report += " %d:%.2fm/%+.2fm%s" % [i+1,float(r.gap),float(r.dy),"^" if bool(r.climb) else ""]
	var last: Dictionary = rows[rows.size()-1]
	var exit_ok: bool = float(laid.exit_gap) <= Run.reach(p,float(laid.exit_dy))*0.85
	check(hops_ok and exit_ok,"Every hop is within his jump (a running small hop at that rise: gaps at most %.0f%% of its reach, rises a hop or a climb a lip catches):%s, out %.2fm" % [worst*100.0,report,float(laid.exit_gap)])
	var shares := []
	for r: Dictionary in rows: shares.append(float(r.gap)/Run.reach(p,float(r.dy)))
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

func _distinct(values: Array) -> int:
	var seen := {}
	for v: float in values: seen[v] = true
	return seen.size()

# --- The scripted rider through the real play loop ---

var _jump_left := 0

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
	var c: Vector3 = b.to_global(b.centre())
	var half := float(b.knob("size"))*0.5
	var dx := maxf(absf(m.feet.x-c.x)-half,0.0)
	var dz := maxf(absf(m.feet.z-c.z)-half,0.0)
	return Vector2(dx,dz).length()

## Hop from `src` (the block he stands on; null for the start deck) to block
## `b` across a gap of `gap` m: from the deck, straight on at it; from a block,
## walk to the far side of it level with the strip the two share (in z), then
## run at the other and jump at the edge. True once he stands on `b`.
func _hop(src: Node3D, b: Node3D, gap: float, limit: float) -> bool:
	var t := 0.0
	var on := 0
	var lined := src == null
	var stuck := 0.0
	var last_d := INF
	while t < limit:
		var tc: Vector3 = b.to_global(b.centre())
		var bh := float(b.knob("size"))*0.5
		var way := Vector2.ZERO
		var jump := false
		var goal := Vector2.ZERO
		if src == null:
			way = Vector2(clampf(tc.x-m.feet.x,-bh+1.0,bh-1.0),-6.0)
			jump = m.grounded and _dist_to(b) <= gap+0.12 and not b.riding()
		else:
			var sc: Vector3 = src.to_global(src.centre())
			var sh := float(src.knob("size"))*0.5
			var line_z := (maxf(sc.z-sh,tc.z-bh)+minf(sc.z+sh,tc.z+bh))*0.5
			var side := signf(tc.x-sc.x)
			var start := Vector2(sc.x-side*(sh-1.0),line_z)
			if not lined and Vector2(m.feet.x,m.feet.z).distance_to(start) < 0.5: lined = true
			goal = start
			if not lined: way = start-Vector2(m.feet.x,m.feet.z)
			else:
				goal = Vector2(tc.x,line_z)
				way = Vector2(side*3.0,clampf(line_z-m.feet.z,-0.5,0.5))
				jump = m.grounded and _dist_to(b) <= gap+0.12 and not b.riding()
		# Pressing on and not getting on over the stone: hop what blocks him
		# (the sweeper's bar).
		var d := Vector2(m.feet.x,m.feet.z).distance_to(goal)
		stuck = stuck+1.0/60.0 if m.grounded and d > last_d-m.walk*0.3/60.0 and src != null else 0.0
		last_d = d
		if stuck > 0.15: jump = true
		_play(way,jump)
		t += await _frame()
		on = on+1 if m.grounded and b.riding() else 0
		if OS.get_environment("TRACE") != "":
			if src != null: print("    src %s %.2f roll %.2f riding %s slide %.2f off %s" % [src.phase,src.phase_t,src.roll,src.riding(),src.slide,src.put_off])
			print("  t %.2f feet %s grounded %s lined %s dist %.2f riding %s rt %.2f phase %s %.2f vel %s" % [t,m.feet.snapped(Vector3.ONE*0.01),m.grounded,lined,_dist_to(b),b.riding(),b.riding_time,b.phase,b.phase_t,m.velocity.snapped(Vector3.ONE*0.1)])
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
	while t < seconds:
		_play(Vector2.ZERO,false)
		t += await _frame()
		drift = maxf(drift,b.block_local(m.feet).distance_to(local))
		moved = maxf(moved,m.feet.distance_to(world))
	_let_go()
	return {"ok":b.riding(),"drift":drift,"moved":moved,"phase":b.phase}

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
	var go := await _hop(b1,b2,float(laid.rows[1].gap),8.0)
	var in2: Node3D = run_trap.riding_block()
	check(go and in2 == b2,"...hopped from block 1 across to block 2 (on block %d; %.1f s on 1, %.1f on 2)" % [run_trap.blocks.find(in2)+1,b1.riding_time,b2.riding_time])
	var s2 := await _stand(b2,0.8)
	check(s2.ok and float(s2.drift) < 0.3,"...and block 2 carries him in turn (%.2f m of drift, %.2f m moved with it in the world, %s)" % [s2.drift,s2.moved,s2.phase])
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
