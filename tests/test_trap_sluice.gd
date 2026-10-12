extends SceneTree
## Sluice Flush (scripts/traps/trap_sluice.gd) in the trap yard, headless,
## the pilot driven by scripted input:
##   - the tell (gurgle, water to a trickle) precedes the wave by tell_time;
##   - a pilot standing in the channel is carried along by the wave, and
##     goes off the open end;
##   - one on the refuge shelf, above the wave's height, is not.
##   godot --headless --path . --script tests/test_trap_sluice.gd
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: Object
var trap: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("trap sluice test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	trap = study.traps.named("sluice")
	var p := Trap.pilot()
	check(trap != null and trap.danger() == 4 and float(trap.knob("speed")) > p.run and float(trap.knob("wave_height")) < trap.refuge_top(),"The yard has the Sluice: faster than a run, the shelf over the wave")
	await physics_frame
	await physics_frame
	_tell_first()
	_carried_along()
	_shelf()
	print("trap sluice: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

## Set standing at trap-local `at`.
func _set_at(at: Vector3) -> void:
	study.place(trap.to_global(at),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	_tick(2)

func _tell_first() -> void:
	_set_at(Vector3(0.0,0.0,-float(trap.knob("plate_at"))))
	check(trap.state == trap.TELLING and trap.heard.size() >= 1,"Stood on the plate, the tell begins (gurgle heard %d)" % trap.heard.size())
	var tt: float = trap.knob("tell_time")
	_tick(int(tt*60.0*0.5))
	check(trap.state == trap.TELLING and trap.waves_run == 0 and trap.heard.size() >= 2,"...and the wave has not come half way through it")
	_tick(int(tt*60.0*0.5)+4)
	check(trap.waves_run == 1 and str(trap.heard.back()[0]) == "surge" and str(trap.heard[0][0]).begins_with("gurgle"),"...the gurgle sounds, then the surge, after the tell (%.1f s)" % tt)

func _carried_along() -> void:
	_set_at(Vector3(0.0,0.0,-2.0))
	trap.trigger()
	_tick(int(float(trap.knob("tell_time"))*60.0)-6)
	check(absf(to_local_z()+2.0) < 0.3 and trap.waves_run == 0,"Waiting in the channel through the tell, he is not moved")
	var start: float = to_local_z()
	var carried := false
	var low := 0.0
	for i in range(240):
		_tick(1)
		low = minf(low,m.feet.y)
		if trap.waves_run == 1 and to_local_z() < start-1.0: carried = true
		if m.feet.y < -2.0: break
	check(carried,"The wave carries him down the channel (z %.1f from %.1f)" % [to_local_z(),start])
	check(low < -2.0 or to_local_z() < -float(trap.channel_length()),"...and off the open end over the drop (lowest y %.1f)" % low)

func _shelf() -> void:
	var at: Vector3 = trap.refuge_at()
	_set_at(at)
	check(m.grounded and m.feet.y > float(trap.knob("wave_height")),"The refuge shelf stands over the wave's height (y %.2f)" % m.feet.y)
	var z0: float = to_local_z()
	trap.trigger()
	_tick(int((float(trap.knob("tell_time"))+float(trap.channel_length())/float(trap.knob("speed")))*60.0)+30)
	check(trap.waves_run == 1 and absf(to_local_z()-z0) < 0.2 and m.grounded and m.feet.y > 0.5,"Up on the shelf the wave passes under: he is not carried (z %.2f from %.2f)" % [to_local_z(),z0])

func to_local_z() -> float:
	return trap.to_local(m.feet).z
