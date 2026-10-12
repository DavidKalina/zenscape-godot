extends SceneTree
## The Sluice Flush in context (scripts/traps/sluice_aqueduct.gd,
## trap_sluice.gd) on the aqueduct isle with --sluice, headless, through the
## real play loop (the study unscripted, its own frames) and real input
## (InputMap actions pressed):
##   - --sluice=head starts him at the top of the rubble slope;
##   - it is sized from the isle as drawn: its channel the clear between
##     the parapets to the snap, its gap the fallen span's, its floor past it
##     the far run;
##   - walking up the channel from the head he steps on the plate; the tell
##     (the channel's water draining away down its length, the leaf, the
##     spray, the rumble, the gurgles) precedes the wave by its tell_time;
##   - standing in the channel he is swept down it toward the gap and,
##     carried off the snap, drops through the fallen span;
##   - on a refuge (the gatehouse's top, the block over the first pier) the
##     wave passes under him; from the plate he reaches the gatehouse in the
##     tell;
##   - a rider who runs on into the wave and jumps at the gap keeps the
##     water's pace and lands on the far run.
##   godot --headless --path . --script tests/test_trap_sluice_aqueduct.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
var failures := 0
var study: Node3D
var m: Object
var trap: Node3D
var deck := 0.0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("trap sluice aqueduct test timed out"); quit(2))
	LaunchArgs.set_override(PackedStringArray(["--sluice=head"]))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready or not study.walk_ready: await process_frame
	m = study.motor
	var hook: Node = study.foot_pieces
	check(hook != null and hook.name == "Sluice" and hook.get("trap") != null,"--sluice lays the trap in the study's foot pieces slot")
	trap = hook.trap
	deck = Art.TOP+Art.DECK
	var head: Vector3 = trap.to_local(m.feet)
	check(absf(head.x) < 0.3 and absf(m.feet.y-deck) < 0.3 and head.z > 0.0 and head.z < 2.0,"--sluice=head starts him on the channel's head behind the gate (%s)" % head.snapped(Vector3.ONE*0.01))
	_sizes()
	await physics_frame
	await physics_frame
	await _tell_and_swept()
	await _refuges()
	await _reach()
	await _ride()
	_let_go()
	LaunchArgs.set_override(null)
	print("trap sluice aqueduct: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _sizes() -> void:
	var gate := trap.global_position
	check(absf(gate.x-Art.MID_X) < 0.01 and absf(gate.y-deck) < 0.01 and gate.z < -Art.HEAD and gate.z > -Art.HEAD-1.0,"The gate stands on the channel's floor at its head (%s)" % gate)
	check(absf(trap.channel_length()-(Art.SNAP+gate.z)) < 0.01 and absf(float(trap.knob("gap"))-(Art.RESUME-Art.SNAP)) < 0.01 and absf(trap.run_end()-(Art.END+gate.z)) < 0.01,
		"The channel runs to the snap (%.1f m), the gap is the fallen span (%.1f m), the far run to the deck's end" % [trap.channel_length(),float(trap.knob("gap"))])
	check(absf(trap.channel()-(Art.PARAPET_Z-Art.PARAPET.x)*2.0) < 0.01 and float(trap.knob("wave_height")) > Art.PARAPET.y and trap.refuge_top() > float(trap.knob("wave_height")),
		"Its width is the clear between the parapets (%.2f), the wave over them (%.2f > %.2f), the refuges over the wave (%.2f)" % [trap.channel(),float(trap.knob("wave_height")),Art.PARAPET.y,trap.refuge_top()])

# --- The real play loop ---------------------------------------------------------

var _jump_left := 0

## This frame's input: the stick along the channel (-1 forward, +1 back,
## `side` -1 left), the jump pressed fresh and held a few frames.
func _play(way: float, jump: bool, side := 0.0) -> void:
	for action: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right"]: Input.action_release(action)
	if way < 0.0: Input.action_press(&"move_forward",-way)
	elif way > 0.0: Input.action_press(&"move_back",way)
	if side < 0.0: Input.action_press(&"move_left",-side)
	elif side > 0.0: Input.action_press(&"move_right",side)
	if jump and _jump_left <= -2: _jump_left = 12
	if _jump_left > 0: Input.action_press(&"walk_jump")
	else: Input.action_release(&"walk_jump")
	_jump_left -= 1
	# The camera held looking down the channel (-z), as a player would.
	study.set("_yaw",0.0)

func _let_go() -> void:
	for action: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump"]: Input.action_release(action)
	_jump_left = 0

## One real frame; its seconds.
func _frame() -> float:
	await process_frame
	return study.get_process_delta_time()

func _local() -> Vector3:
	return trap.to_local(m.feet)

## Set standing at trap-local `at` (scripted, still), then the real loop.
func _stand(at: Vector3) -> void:
	study.scripted = true
	_let_go()
	study.place(trap.to_global(at),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	for i in range(3): study.tick(1.0/60.0)
	study.scripted = false

## Waits (real frames, no input) till the trap is idle again.
func _quiet() -> void:
	study.scripted = true
	var t := 0.0
	while trap.state != trap.IDLE and t < 30.0:
		await process_frame
		study.tick(1.0/60.0)
		t += 1.0/60.0
	trap.reset()

# --- The checks -------------------------------------------------------------------

func _tell_and_swept() -> void:
	_stand(Vector3(0.0,0.0,-0.6))
	var t := 0.0
	while trap.state == trap.IDLE and t < 5.0:
		_play(-0.5,false)
		t += await _frame()
	check(trap.state == trap.TELLING,"Walking up the channel from the head he steps on the plate (%.1f m down, %.1f s)" % [-_local().z,t])
	_let_go()
	var host: Node3D = trap._host_water
	check(host != null and not host.visible and trap._water.visible and trap._rumble.playing and trap._gate_spray.emitting,"The tell: the channel's own water gives way to the draining film, the rumble plays, spray at the gate")
	var tell := 0.0
	var half := -1.0
	var leaf_moved := false
	while trap.waves_run == 0 and tell < 10.0:
		tell += await _frame()
		if half < 0.0 and tell >= float(trap.knob("tell_time"))*0.5: half = trap.drained/trap.channel_length()
		if trap._leaf.position.distance_to(trap._leaf_home) > 0.01: leaf_moved = true
	var tt := float(trap.knob("tell_time"))
	check(absf(tell-tt) < 0.1,"The wave comes %.2f s after the tell began (tell_time %.1f)" % [tell,tt])
	check(half > 0.4 and leaf_moved,"Half way through the tell the water has drained %.0f%% of the way down the channel; the leaf rattles" % (half*100.0))
	check(str(trap.heard[0][0]) == "gurgle_low" and str(trap.heard.back()[0]) == "surge","The gurgles, then the surge (%d sounds)" % trap.heard.size())
	var z0 := _local().z
	var carried := false
	var fell_at := INF
	t = 0.0
	while t < 12.0:
		t += await _frame()
		if trap.carrying(): carried = true
		if OS.get_environment("TRACE") != "": print("  t %.2f z %.2f y %.2f g %s carried %s move %s hold %s v %s" % [t,-_local().z,m.feet.y-deck,m.grounded,trap.carrying(),m.move,m.hold,m.velocity.snapped(Vector3.ONE*0.01)])
		if m.feet.y < deck-2.0:
			fell_at = -_local().z
			break
	var L: float = trap.channel_length()
	check(carried and fell_at > L-0.5 and fell_at < INF,"Standing in the channel he is swept down it from %.1f m to the gap (%.1f m)" % [-z0,fell_at])
	check(fell_at > L-0.5 and fell_at < trap.far_start()+0.3 and trap.spills >= 1,"...carried off the snap, he drops through the fallen span (%.1f m down, the gap %.1f to %.1f)" % [fell_at,L,trap.far_start()])
	_let_go()
	# Fallen: back on his feet (the isle's stranding puts him back) first.
	study.scripted = true
	t = 0.0
	while t < 20.0 and (not m.grounded or float(study.get("_stranded_left")) >= 0.0 or m.feet.y < deck-2.0 and study.get("off_edge")):
		await process_frame
		study.tick(1.0/60.0)
		t += 1.0/60.0
	await _quiet()

func _refuges() -> void:
	var spots: Array = trap.refuge_spots()
	check(spots.size() >= 2,"Two refuges: the gatehouse's top and the block over the first pier")
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		_stand(at)
		var was: Vector3 = m.feet
		check(m.grounded and m.feet.y-deck > float(trap.knob("wave_height")),"Refuge %d stands over the wave (%.2f m over the deck)" % [k,m.feet.y-deck])
		trap.trigger()
		var t := 0.0
		var wet := false
		var limit: float = float(trap.knob("tell_time"))+trap.run_end()/float(trap.knob("speed"))+1.0
		while t < limit:
			_play(0.0,false)
			t += await _frame()
			if trap.carrying(): wet = true
		var moved := Vector2(m.feet.x-was.x,m.feet.z-was.z).length()
		check(trap.waves_run >= 1 and not wet and moved < 0.2 and m.grounded and absf(m.feet.y-was.y) < 0.05,"...the wave passes under him: not carried (moved %.2f m)" % moved)
		await _quiet()

## From the plate, back to the gatehouse and up it in the tell: back along
## the channel, across onto the west parapet, up on top.
func _reach() -> void:
	_stand(Vector3(0.0,0.0,-float(trap.knob("plate_at"))-0.4))
	var t := 0.0
	while trap.state == trap.IDLE and t < 3.0:
		_play(0.4,false)
		t += await _frame()
	check(trap.state == trap.TELLING,"Stepped back onto the plate, the tell begins")
	var house: Vector3 = trap.refuge_spots()[0]
	# Back to the channel floor beside the gatehouse's face, then up it:
	# a jump onto the parapet and the pump, toward its top.
	var foot := Vector3(-trap.channel()*0.3,0.0,house.z-Sluice.HOUSE_LONG*0.5-0.5)
	t = 0.0
	var up := false
	var climbing := false
	var tt := float(trap.knob("tell_time"))
	var up_at := -1.0
	while trap.waves_run == 0 and t < tt+1.0:
		var here := _local()
		var goal := house if climbing else foot
		var d := Vector2(goal.x-here.x,goal.z-here.z)
		if not climbing and d.length() < 0.3: climbing = true
		var dir := d.normalized()*minf(d.length()*2.0,1.0) if d.length() > 0.05 else Vector2.ZERO
		# Jumps from his feet only (the floor, the parapet): never the sail.
		_play(dir.y,climbing and not up and m.grounded,dir.x)
		t += await _frame()
		if OS.get_environment("TRACE") != "": print("  reach t %.2f at %s climbing %s g %s move %s hold %s" % [t,_local().snapped(Vector3.ONE*0.01),climbing,m.grounded,m.move,m.hold])
		if m.grounded and m.feet.y-deck > float(trap.knob("wave_height")) and not up:
			up = true
			up_at = t
	check(up and up_at < tt and m.grounded and m.feet.y-deck > float(trap.knob("wave_height")),"From the plate he is up on the gatehouse %.1f s into the %.1f s tell, and stays (%.1f m over the deck)" % [up_at,tt,m.feet.y-deck])
	_let_go()
	await _quiet()

func _ride() -> void:
	_stand(Vector3(0.0,0.0,-0.6))
	var L: float = trap.channel_length()
	var t := 0.0
	var took := -1.0
	var pace := 0.0
	var landed := -1.0
	var landed_y := 0.0
	while t < 20.0:
		var here := -_local().z
		var jump: bool = took < 0.0 and m.grounded and here > L-1.0
		_play(-1.0,jump)
		t += await _frame()
		if jump and took < 0.0:
			took = here
		if took >= 0.0 and pace == 0.0 and not m.grounded: pace = Vector2(m.velocity.x,m.velocity.z).length()
		if took >= 0.0 and not m.grounded: continue
		if took >= 0.0 and m.grounded and t > 0.0 and -_local().z > took+0.5:
			landed = -_local().z
			landed_y = m.feet.y
			break
		if m.feet.y < deck-2.0: break
	check(trap.swept > 0.3,"Running on up the channel, the wave catches him and carries him (%.1f s)" % trap.swept)
	check(took > L-1.5 and pace > Trap.pilot().run*1.5,"He jumps at the gap (%.1f m down) at the water's pace (%.1f m/s)" % [took,pace])
	check(landed > trap.far_start() and absf(landed_y-deck) < 0.3,"...and clears the fallen span, landing on the far run (%.1f m down, past %.1f)" % [landed,trap.far_start()])
	_let_go()
