extends SceneTree
## suite: slow
## The Tumble Run (scripts/traps/trap_tumble_run.gd) in the trap yard,
## headless. Round 3, the ferries: the blocks spread out, each hop open only
## in a window as the blocks slide along the route against each other.
##   - the layout: a few Tumbling Blocks staggered across x, up and down,
##     each hop at its window within a running small hop (a climb within a
##     lip it catches), held shut past his jump (the pump, caught by the
##     lip: `Run.leap`, stepped through the motor), no two blocks ever
##     meeting through their motion; each block meaner than the single cube
##     with its own personality;
##   - the windows, the blocks stepped through two beats: every hop opens
##     once a beat for about a second (a running small hop makes it), is
##     past his jump most of the beat, and the next hop opens only after it
##     has shut, so he must ride each block between;
##   - through the real play loop (the study's own frames, the stick and the
##     jump pressed as input actions): a rider who chains running jumps
##     from A without waiting falls into the void early; a rider who waits
##     for each window (keeping his block's station, jumping its lurches)
##     crosses from A;
##   - each block carries him alone; a rider who just stands there is put
##     off every block sooner than the same block calmed; a fall resets.
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
	create_timer(400.0).timeout.connect(func() -> void: push_error("tumble run test timed out"); quit(2))
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
	await _windows()
	await _chainer()
	await _waiter()
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
	var ok := true
	var report := ""
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var rise_ok: bool = float(r.dy_worst) <= jump*Run.HOP_UP+0.001 or (bool(r.climb) and float(r.dy_worst) <= RuinKit.GRAB_TOP*0.75)
		var open_ok: bool = float(r.gap) <= float(r.open_reach)*0.85 and float(r.gap) > 0.3
		var shut_ok: bool = float(r.shut) > float(r.jump_reach)*1.15
		ok = ok and rise_ok and open_ok and shut_ok
		report += " %d: %.2f m open (a hop %.2f), %.2f m shut (his jump %.2f, twirled %.2f), %+.2f m%s;" % [i+1,float(r.gap),float(r.open_reach),float(r.shut),float(r.jump_reach),float(r.twirl_reach),float(r.dy)," climb" if bool(r.climb) else ""]
	var exit_ok: bool = float(laid.exit_gap) <= float(laid.exit_open_reach)*0.85 and float(laid.exit_shut) > float(laid.exit_jump_reach)*1.15
	report += " out: %.2f m open (%.2f), %.2f m shut (%.2f, twirled %.2f)" % [float(laid.exit_gap),float(laid.exit_open_reach),float(laid.exit_shut),float(laid.exit_jump_reach),float(laid.exit_twirl_reach)]
	check(ok and exit_ok,"Every hop at its window is within a running small hop (at most 85%% of it, a climb within a lip he catches), and held shut it is past his jump (the pump caught by the lip, by 15%%):%s" % report)
	var last: Dictionary = rows[rows.size()-1]
	var clear := true
	for i in range(rows.size()):
		for j in range(i+1,rows.size()):
			if not Run.clear_of(rows[i],rows[j]): clear = false
	check(clear,"No two blocks swing into each other (apart across x, or a swing apart)")
	var half: float = Yard.DECK_WIDE*0.5
	var first: Dictionary = rows[0]
	check(absf(float(first.x))-float(first.size)*0.5 < half and absf(float(last.x))-float(last.size)*0.5 < half,"The first block is hopped onto from the start deck and the last off onto the far deck (both over the deck's width)")
	check(absf(float(laid.length)-run_trap.length()) < 0.001 and absf(-(float(last.z)-float(last.ferry)-float(last.size)*0.5)+float(laid.exit_gap)-run_trap.length()) < 0.001,"...the far deck is the exit hop past the last block held on (%.1f m of route)" % run_trap.length())
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
		placed = placed and absf(at.x-float(rows[i].x)) < 0.01 and absf(at.z-float(rows[i].z)) < 0.01 and absf(at.y-float(rows[i].top)) < 0.01 and absf(float(b.knob("shuttle"))-float(rows[i].ferry)) < 0.01
	check(placed,"...and each laid where the plan puts its flat top")
	# Meaner than the single cube, each its own way.
	var cube: Dictionary = preload("res://scripts/traps/trap_tumble.gd").new().defaults()
	var meaner := true
	var traits := {}
	for b: Node3D in run_trap.blocks:
		meaner = meaner and float(b.knob("tip")) > float(cube.tip) and float(b.knob("tip")) < float(b.knob("throw_at")) and float(b.knob("lurch")) < float(cube.lurch) and float(b.knob("throw")) > float(cube.throw) and float(b.knob("ramp")) > float(cube.ramp)
		for t: String in ["wake","feint","double","dip","bob","drift","sway","shuttle"]:
			if float(b.knob(t)) > 0.0: traits[t] = int(traits.get(t,0))+1
	check(meaner,"Every block is meaner than the single cube: a steeper tip (still under the throw), a quicker lurch, a harder throw, a faster ramp")
	check(traits.size() >= 7,"...with personalities across the run: %s" % str(traits))

func _distinct(values: Array) -> int:
	var seen := {}
	for v: float in values: seen[v] = true
	return seen.size()

# --- The scripted rider through the real play loop ---

var _jump_left := 0
var _pressed_for := 0
var jumped_lurch := 0

## The stick toward world direction `way` (x right, y the way on: -z is up
## the screen) and a fresh jump press held a few frames.
func _play(way: Vector2, jump: bool, hold := 10) -> void:
	for action: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right"]: Input.action_release(action)
	if way.length() > 0.01:
		# Full stick from a metre off; nearer, eased (he slows into place).
		var d := way.normalized()*clampf(way.length(),0.35,1.0)
		if d.y < 0.0: Input.action_press(&"move_forward",-d.y)
		elif d.y > 0.0: Input.action_press(&"move_back",d.y)
		if d.x < 0.0: Input.action_press(&"move_left",-d.x)
		elif d.x > 0.0: Input.action_press(&"move_right",d.x)
	if jump and _jump_left <= -2:
		_jump_left = hold
		_pressed_for = 0
	# Still holding an old press and back on the ground: let go, to press anew.
	elif jump and _jump_left > 0 and m.grounded and _pressed_for > 8: _jump_left = 0
	_pressed_for += 1
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

## The middle of block `b`'s flat top (world) as the run starts (its ferry
## where its clock 0 puts it).
func _top_at_start(b: Node3D) -> Vector3:
	return b.top_point()+Vector3(0.0,0.0,float(b.knob("shuttle"))*float(b.shuttle_wave(0.0)))

# --- The windows: the blocks stepped through two beats ---

## A hop counted open: within 85% of a running small hop at its rise (a
## climb: caught by the lip).
func _open(h: Dictionary) -> bool:
	return float(h.gap) <= Run.open_reach(float(h.dy))*0.85

## The spans (s) of a frame series' true runs, joining runs a blip apart
## (a lurch's quarter turn reads oddly for a frame or two).
func _runs(flags: Array, dt: float) -> Array:
	var out := []
	var from := -1.0
	var gap := 0.0
	for k in range(flags.size()):
		var t := float(k)*dt
		if flags[k]:
			if from < 0.0: from = t
			gap = 0.0
		elif from >= 0.0:
			gap += dt
			if gap > 0.2:
				out.append([from,t-gap])
				from = -1.0
				gap = 0.0
	if from >= 0.0: out.append([from,float(flags.size())*dt])
	# Under 0.4 s is no window (a lurch's quarter turn swinging an edge by).
	return out.filter(func(r: Array) -> bool: return float(r[1])-float(r[0]) >= 0.4 or float(r[0]) < 0.05 or float(r[1]) > float(flags.size())*dt-0.05)

func _windows() -> void:
	var trap: Node3D = Run.new()
	root.add_child(trap)
	await process_frame
	var n: int = trap.blocks.size()+1
	var dt := 1.0/60.0
	var beat := Run.beat()
	var open := []
	var reach := []
	var twirl := []
	for i in range(n):
		open.append([])
		reach.append([])
		twirl.append([])
	# A hop counts if it is in reach both as he leaves and as he comes down
	# (the two blocks go on sliding while he is in the air, and he keeps
	# his own block's slide): his airtime later, as a frame count.
	var frames := int(beat*2.0/dt)
	var p := Trap.pilot()
	var lag := {"open":int(Run.air(p,0.0)/dt),"jump":int(Run.air(p,0.0)*1.4/dt),"twirl":int(Run.air(p,0.0)*2.4/dt)}
	var raw := {"open":[],"jump":[],"twirl":[]}
	for k: String in raw:
		for i in range(n): raw[k].append([])
	var t := 0.0
	while t < beat*2.0+1.5:
		for b: Node3D in trap.blocks: b.before(dt)
		t += dt
		for i in range(n):
			var h: Dictionary = trap.hop_now(i)
			raw.open[i].append(_open(h))
			raw.jump[i].append(float(h.gap) <= Run.leap("jump",float(h.dy)))
			raw.twirl[i].append(float(h.gap) <= Run.leap("twirl",float(h.dy)))
	trap.queue_free()
	for i in range(n):
		for k in range(frames):
			open[i].append(bool(raw.open[i][k]) and bool(raw.open[i][k+int(lag.open)]))
			reach[i].append(bool(raw.jump[i][k]) and bool(raw.jump[i][k+int(lag.jump)]))
			twirl[i].append(bool(raw.twirl[i][k]) and bool(raw.twirl[i][k+int(lag.twirl)]))
	var each_ok := true
	var shut_ok := true
	var report := ""
	var opens := []
	for i in range(n):
		var runs := _runs(open[i],dt)
		var lens: Array = runs.map(func(r: Array) -> float: return float(r[1])-float(r[0]))
		# Every window (whole ones: not cut by the sampling's ends) a human
		# can take, once a beat.
		var whole: Array = runs.filter(func(r: Array) -> bool: return float(r[0]) > 0.05 and float(r[1]) < beat*2.0-0.05)
		var whole_ok := whole.all(func(r: Array) -> bool: return float(r[1])-float(r[0]) >= 0.8 and float(r[1])-float(r[0]) <= 2.0)
		var recur := runs.size() >= 2 and runs.size() <= 3 and whole.size() >= 1
		for k in range(1,runs.size()):
			recur = recur and absf(float(runs[k][0])+float(runs[k][1])-float(runs[k-1][0])-float(runs[k-1][1])-beat*2.0) < beat*0.3
		each_ok = each_ok and whole_ok and recur
		var reach_share := float(reach[i].count(true))/float(reach[i].size())
		var twirl_share := float(twirl[i].count(true))/float(twirl[i].size())
		shut_ok = shut_ok and reach_share <= 0.5
		opens.append(runs)
		report += " %d: open %s s a beat, within his jump %.0f%% of it, twirled %.0f%%;" % [i,str(lens.map(func(l: float) -> String: return "%.1f" % l)),reach_share*100.0,twirl_share*100.0]
	check(each_ok,"Every hop opens once a beat (%.1f s) for 0.8 to 2 s (a running small hop makes it), at the same place in each beat:%s" % [beat,report])
	check(shut_ok,"...and is past his jump (the pump caught by the lip) at least half of every beat")
	# No chaining: hop i+1 opens only after hop i has shut, a ride later.
	var ride := INF
	var apart := true
	for i in range(n-1):
		var a: Array = opens[i]
		var b: Array = opens[i+1]
		for x: Array in a:
			for y: Array in b:
				if float(y[0]) < float(x[1]) and float(y[1]) > float(x[0]): apart = false
				if float(y[0]) >= float(x[1]): ride = minf(ride,float(y[0])-float(x[1]))
	check(apart and ride >= 1.0,"...and no two hops in a row are open at once: the next opens at least %.1f s after the last shuts, so he rides each block between" % ride)

# --- Riders through the real play loop ---

## In the trap's frame.
func _local(p: Vector3) -> Vector3:
	return run_trap.to_local(p)

## Seconds of the beat to hop `i`'s window's middle (0 if it is now).
func _to_window(i: int) -> float:
	var beat := Run.beat()
	var clock: float = run_trap.blocks[0]._clock
	var t := fposmod((Run.FIRST+0.5*float(i))*beat-clock,beat)
	return 0.0 if t > beat-0.6 else t

## Seconds since hop `i`'s window's middle, on the beat (0 to a beat).
func _since_window(i: int) -> float:
	var beat := Run.beat()
	return fposmod(float(run_trap.blocks[0]._clock)-(Run.FIRST+0.5*float(i))*beat,beat)

## Hop `i` (0 the deck onto block 1, n the last block onto the far deck),
## as a player would: if `waits`, he keeps his block's station (riding its
## lurch: a hop as the shudder ends and the pump off the landing, high up
## the slope) till the window draws near, goes to its front end by the edge
## facing the next, and runs across and jumps once the hop is open, before
## the window's middle (and he'd not land in the other's lurch); if not, he
## goes straight away, running jumps. "on" once he stands on
## the next, "fell" into the void, or "timeout".
func _cross(i: int, waits: bool, limit: float) -> String:
	var src: Node3D = run_trap.blocks[i-1] if i > 0 else null
	var tgt: Node3D = run_trap.blocks[i] if i < run_trap.blocks.size() else null
	var far: float = run_trap.length()
	var t := 0.0
	var on := 0
	var going := not waits
	var stuck := 0.0
	var last_on := Vector3.INF
	var lurch_hop := 0
	var leaping := false
	var side := 0.0
	var low := INF
	for r: Dictionary in run_trap.plan_rows: low = minf(low,float(r.top))
	while t < limit:
		var feet := _local(m.feet)
		if feet.y < low-3.0: return "fell"
		var h: Dictionary = run_trap.hop_now(i)
		var open := _open(h)
		var way := Vector2.ZERO
		var jump := false
		var goal := Vector2(m.feet.x,m.feet.z)
		var landing_ok: bool = tgt == null or (tgt.phase != "lurch" and tgt.until_lurch() > 0.75)
		if src == null:
			# The start deck: wait back from its edge, then run at block 1.
			var tc: Vector3 = _local(tgt.middle())
			if not going and (open or _to_window(i) < 0.5): going = true
			if going:
				way = Vector2(clampf(tc.x-feet.x,-2.0,2.0),-6.0)
				jump = m.grounded and feet.z < 0.15 and feet.z > -0.5
			else:
				goal = Vector2(m.feet.x,run_trap.to_global(Vector3(0.0,0.0,1.6)).z)
				way = goal-Vector2(m.feet.x,m.feet.z)
				if way.length() < 0.2: way = Vector2.ZERO
		else:
			var sc: Vector3 = _local(src.middle())
			var sh := float(src.knob("size"))*0.5
			# Where he goes from: his block's front end, 1.2 m in from the
			# edge facing the next.
			var span: Dictionary = src.top_span()
			# Its usable top: past the pocket when the pocket's face is up
			# (it lies at the face's trailing end, the front).
			var from_z := float(span.z0)+(float(src.knob("pocket")) if src.top_face() == src.POCKET_FACE else 0.0)
			var off := Vector3(sc.x,0.0,from_z+1.0)
			var aim := off.z
			if tgt != null:
				side = signf(_local(tgt.middle()).x-sc.x)
				off.x = sc.x+side*(sh-1.2)
				# The strip the two share at the window lies at his block's
				# front end, `meet` deep: wait there (in its own frame, so
				# early, before the next comes), and aim into the next's
				# back end.
				var meet: float = float(run_trap.plan_rows[i].row.get("meet",1.0))*_height()
				off.z = maxf(float(span.z0)+meet*0.5,from_z+0.4)
				var b: Dictionary = tgt.top_span()
				aim = clampf(off.z,float(b.z0)+0.6,float(b.z1)-0.6)
			else:
				off.z = from_z+0.6
			var in_strip: bool = tgt == null or absf(feet.z-off.z) < 0.5
			var lead := Vector2(feet.x,feet.z).distance_to(Vector2(off.x,off.z))/m.run+0.6
			# He goes when the window draws near and his block won't lurch
			# under him on the way (if it will, he rides the lurch first).
			if waits and not going and (open or _to_window(i) <= lead+1.2) and src.phase != "lurch" and src.until_lurch() > lead+0.3: going = true
			if waits and going and not open and _to_window(i) > lead+1.0:
				going = false
				leaping = false
			if not going:
				# Waiting: by the edge facing the next, high up the slope as
				# it tips (for the lurch), at the front end as it rests.
				var xs := side*(sh-1.2) if tgt != null else 0.0
				if src.phase == "tip": goal = _station(src,xs,_uphill(src))
				else:
					var at := run_trap.to_global(Vector3(off.x,0.0,maxf(off.z,from_z+2.2)))
					goal = Vector2(at.x,at.z)
				way = goal-Vector2(m.feet.x,m.feet.z)
				if way.length() < 0.3: way = Vector2.ZERO
			else:
				var at := run_trap.to_global(off)
				goal = Vector2(at.x,at.z)
				# Committed once he runs for it: the hop open, his block not
				# about to lurch before he is off it, the next not lurching
				# as he lands.
				var edge := (sh-absf(feet.x-sc.x))/m.run+0.3 if tgt != null else (feet.z-(sc.z-sh))/m.run+0.3
				if leaping and waits and m.grounded and src.riding() and (not open or (not in_strip and absf(feet.x-sc.x) < sh-1.5)): leaping = false
				# Not past the window's middle (its blocks about to part): a
				# late one is let go for the next beat.
				var since := _since_window(i)
				var timely := since < 0.45 or since > Run.beat()-1.5
				if not waits or (open and timely and in_strip and landing_ok and src.phase != "lurch" and src.until_lurch() > edge+0.15): leaping = true
				if leaping:
					# Across at the next along the strip (or on to the far deck).
					if tgt != null:
						way = Vector2(side*3.0,clampf((aim-feet.z)*2.0,-1.5,1.5))
						jump = m.grounded and absf(feet.x-sc.x) > sh-0.15
					else:
						# On to the far deck, letting go once over it.
						way = Vector2(clampf(-feet.x*0.3,-1.0,1.0),-3.0) if feet.z > -far-1.5 else Vector2.ZERO
						jump = m.grounded and feet.z < from_z+0.15 and feet.z > -far+0.5
				else:
					# A lurch on its way first, on a block whose front tips down
					# (it turns the other way): ride it up the slope, then go.
					if float(src.knob("dir")) < 0.0 and src.phase == "tip" and src.until_lurch() < 1.3: goal = _station(src,side*(sh-1.2) if tgt != null else 0.0,_uphill(src))
					way = goal-Vector2(m.feet.x,m.feet.z)
					if way.length() < 0.25: way = Vector2.ZERO
		# On the next: stand and find his feet.
		if tgt != null and tgt.riding():
			way = Vector2.ZERO
			jump = false
		# Running and not getting on over his block's stone: hop what blocks
		# him (the sweeper's bar).
		var near_lurch: bool = src != null and src.phase == "tip" and src.until_lurch() < 0.9
		var on_src: Vector3 = src.block_local(m.feet) if src != null else m.feet
		var d := on_src.distance_to(last_on) if last_on != Vector3.INF else INF
		last_on = on_src
		stuck = stuck+1.0/60.0 if lurch_hop == 0 and not near_lurch and way.length() > 0.01 and m.grounded and Vector2(m.velocity.x,m.velocity.z).length() > m.walk*0.5 and d < m.walk*0.3/60.0 and src != null and not jump else 0.0
		# The sweeper's bar coming at him along its face: hop it.
		if src != null and m.grounded and lurch_hop == 0 and not near_lurch and src.riding() and src.top_face() == src.SWEEP_FACE and src.face_at(m.feet) == src.SWEEP_FACE:
			var ahead := (float(src.face_local(src.SWEEP_FACE,m.feet).z)-float(src.sweep))*signf(float(src.knob("dir")))
			if ahead > -0.1 and ahead < 0.75: stuck = 1.0
		var hold := 30
		if stuck > 0.2:
			jump = true
			hold = 12
		# Hanging from a lip (a climb's, or one he dropped to): climb up.
		if m.on_ledge(): way = Vector2(-m.lip_out.x,-m.lip_out.y)
		# The lurch: its ridge sweeps up over the top higher than a small
		# jump, so he hops as the shudder ends and pumps off the landing,
		# over it (the pump's height), holding his station.
		if src != null and not leaping and src.riding() and m.grounded and src.phase == "tip" and src.until_lurch() <= 0.46 and lurch_hop == 0:
			jump = true
			hold = 8
			lurch_hop = 1
			jumped_lurch += 1
		elif lurch_hop == 1 and m.grounded:
			jump = true
			lurch_hop = 2
			leaping = false
		elif lurch_hop == 2 and m.grounded and src != null and src.phase == "rest": lurch_hop = 0
		if lurch_hop > 0 and src != null and not jump:
			going = false
			goal = _station(src,side*(float(src.knob("size"))*0.5-1.2) if tgt != null else 0.0,_uphill(src))
			way = goal-Vector2(m.feet.x,m.feet.z)
		_play(way,jump,hold)
		t += await _frame()
		if tgt != null: on = on+1 if m.grounded and tgt.riding() else 0
		else: on = on+1 if m.grounded and _local(m.feet).z < -far+0.2 else 0
		if OS.get_environment("TRACE") != "":
			print("  hop %d t %.2f feet %s grounded %s going %s leaping %s open %s gap %.2f dy %.2f window in %.2f" % [i,t,_local(m.feet).snapped(Vector3.ONE*0.01),m.grounded,going,leaping,open,float(h.gap),float(h.dy),_to_window(i)])
		if on >= 12:
			_let_go()
			return "on"
	_let_go()
	return "timeout"

## Where on his block's top he rides its lurch (a share of the half side
## up its fall line): as it tips, high up the slope, under its ridge, so the
## lurch's ridge swings back away from him and the face coming up rises
## under him, not over him.
func _uphill(b: Node3D) -> float:
	return -0.6 if b.phase == "tip" else 0.0

func _height() -> float:
	return preload("res://scripts/pilot_physics_ground.gd").HEAD*preload("res://scripts/world_scale.gd").wanderer

func _start() -> void:
	_let_go()
	study.place(run_trap.position+Vector3(0.0,0.0,run_trap.run_up()),Vector2(0.0,-1.0))
	await physics_frame

## A rider who chains running jumps from A, never waiting: on at once, off
## at once.
func _chainer() -> void:
	study.scripted = false
	await _start()
	var got := []
	var how := ""
	var t0: float = run_trap.blocks[0]._clock
	for i in range(run_trap.blocks.size()+1):
		how = await _cross(i,false,8.0)
		got.append(how)
		if how != "on": break
	var made := got.count("on")
	check(how == "fell" and made <= 2,"A rider who chains running jumps from A without waiting falls into the void early: %s (made %d hop(s) in %.1f s)" % [str(got),made,float(run_trap.blocks[0]._clock)-t0])

## A rider who waits for each window crosses: A, 1, 2, 3 ... B. The play
## loop's frame times vary run to run (headless, real time), so he has up
## to three tries from A, each from the run as built; the best counts.
func _waiter() -> void:
	var best := {}
	var tries := []
	for attempt in range(3):
		await _start()
		var got := []
		var times := []
		var t0: float = run_trap.blocks[0]._clock
		jumped_lurch = 0
		for i in range(run_trap.blocks.size()+1):
			var how := await _cross(i,true,Run.beat()*2.5)
			got.append(how)
			times.append("%.1f" % (float(run_trap.blocks[0]._clock)-t0))
			if how != "on": break
		var made := got.count("on")
		var rode: Array = run_trap.blocks.map(func(b: Node3D) -> String: return "%.1f" % float(b.riding_time))
		var lurched: Array = run_trap.blocks.map(func(b: Node3D) -> int: return int(b.lurches))
		var r := {"made":made,"got":got,"times":times,"rode":rode,"lurched":lurched,"jumped":jumped_lurch}
		tries.append("%d" % made)
		if best.is_empty() or made > int(best.made): best = r
		if made == run_trap.blocks.size()+1: break
	check(int(best.made) >= 3,"A rider who waits for each window crosses from A onto 1, 2, 3: %s, reached at %s s (%d of %d hops; rode %s s; the blocks lurched %s; he jumped %d lurch(es); hops made by try %s)" % [str(best.got),str(best.times),best.made,run_trap.blocks.size()+1,str(best.rode),str(best.lurched),best.jumped,str(tries)])
	check(int(best.made) == run_trap.blocks.size()+1,"...all the way to the far deck B (%s s)" % (best.times[best.times.size()-1] if int(best.made) == run_trap.blocks.size()+1 else "-"))

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

## Each block in turn, with him set down on it as it begins to tip: it alone
## carries him (his place on it holds, the world moves), the others none.
func _carry_each() -> void:
	var worst := 0.0
	var least := INF
	var alone := true
	for i in range(run_trap.blocks.size()):
		var b: Node3D = run_trap.blocks[i]
		var at: Vector3 = _top_at_start(b)+Vector3(0.0,0.0,float(b.knob("size"))*0.3)
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
	for k: String in ["tip","lurch","throw","jolt","ramp","ramp_top","wake","feint","double","dip","bob","drift","sway","shuttle"]:
		was[k] = b.knobs[k]
		b.knobs[k] = cube[k]
	return was

## Landed on block `b` at the middle of its top (the blocks as built, its
## rest from the start) and stood still: seconds till he is in the void, and
## how he was put off.
func _stander(b: Node3D, limit: float) -> Dictionary:
	_let_go()
	study.place(_top_at_start(b)+Vector3.UP*0.3,Vector2(0.0,-1.0))
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
