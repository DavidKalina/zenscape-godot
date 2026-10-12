extends SceneTree
## Wind (scripts/traps/trap_wind.gd) in the trap yard (studies/trap_yard.tscn),
## headless, the pilot driven by scripted input:
##   - vent: during a burst the wind pushes him across and through `air_at`;
##     between bursts it does not;
##   - blaster: stepping on the plate starts an inhale (no push), the blast
##     comes after its delay; a pilot who stopped is shoved off the deck, one
##     who kept running clears it.
##   godot --headless --path . --script tests/test_trap_wind.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var vent: Node3D
var blaster: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("trap wind test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	vent = study.traps.named("wind")
	blaster = study.traps.named("wind_blaster")
	check(vent != null and blaster != null and blaster.is_blaster() and not vent.is_blaster(),"The yard has the wind in both modes")
	var p := Trap.pilot()
	check(float(vent.knob("force")) > p.run,"The wind pushes harder than the run (%.1f > %.1f m/s)" % [vent.knob("force"),p.run])
	await _frames(2)
	_vent()
	_blaster_stopped()
	_blaster_running()
	print("trap wind: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n): await physics_frame

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

func _input(want: Vector2) -> void:
	study.script_want = want

## Set standing on the deck at local (0, z).
func _set_at(trap: Node3D, z: float) -> void:
	study.place(trap.to_global(Vector3(0.0,0.0,z)),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)

func _vent() -> void:
	var z := -float(vent.knob("reach"))
	# Between bursts: quiet, he stays.
	_set_at(vent,z)
	vent.clock = 2.0
	var x0: float = vent.to_local(m.feet).x
	_tick(20)
	check(vent.air_at(m.feet).is_empty() and absf(vent.to_local(m.feet).x-x0) < 0.01,"Vent between bursts: no wind, he stays (dx %.3f)" % (vent.to_local(m.feet).x-x0))
	# Into a burst: the wind reads at his feet and moves him across.
	vent.clock = 0.0
	_tick(1)
	check(not vent.air_at(m.feet).is_empty(),"Vent in a burst: air_at gives wind at his feet")
	var wind: Vector3 = vent.air_at(m.feet).get("wind",Vector3.ZERO)
	check(vent.to_global(Vector3.RIGHT*1.0).x > vent.to_global(Vector3.ZERO).x and wind.x > m.run,"...across the lane, faster than his run (%.1f)" % wind.x)
	_tick(20)
	var dx: float = vent.to_local(m.feet).x-x0
	check(dx > 1.0,"...and a third of a second moves him across (dx %.2f)" % dx)
	# The burst keeps going: he is off the deck.
	_tick(40)
	check(m.feet.y < -0.5 or vent.to_local(m.feet).x > float(vent.knob("width"))*0.5,"...off the edge by the end of the burst (x %.1f, y %.1f)" % [vent.to_local(m.feet).x,m.feet.y])
	# The inhale is seen and heard before a burst.
	vent.reset()
	vent.clock = float(vent.knob("on"))+float(vent.knob("off"))-float(vent.knob("tell"))*0.5
	vent.heard.clear()
	_tick(2)
	var inhaled := false
	for h: Array in vent.heard:
		if h[0] == &"inhale": inhaled = true
	check(inhaled,"Vent: a sharp inhale sounds before the burst")

func _blaster_stopped() -> void:
	var delay: float = blaster.knob("delay")
	# Set on the plate, standing still.
	_set_at(blaster,-float(blaster.knob("plate_at")))
	check(blaster.blaster_state == blaster.COUNTDOWN,"Blaster: stepping on the plate starts the countdown (state %d)" % blaster.blaster_state)
	var x0: float = blaster.to_local(m.feet).x
	_tick(int(delay*60.0*0.6))
	check(absf(blaster.to_local(m.feet).x-x0) < 0.01 and blaster.air_at(m.feet).is_empty(),"...the inhale first: nothing pushes him yet")
	var inhaled := false
	for h: Array in blaster.heard:
		if h[0] == &"inhale": inhaled = true
	check(inhaled,"...and the mouths inhale (heard)")
	_tick(int(delay*60.0*0.6))
	check(blaster.blaster_state == blaster.BLAST,"...then the blast, after its delay (%.2f s)" % delay)
	_tick(60)
	check(m.feet.y < -0.5 or blaster.to_local(m.feet).x > float(blaster.knob("width"))*0.5,"A pilot who stopped is shoved off the deck (x %.1f, y %.1f)" % [blaster.to_local(m.feet).x,m.feet.y])

func _blaster_running() -> void:
	study.place(blaster.to_global(Vector3(0.0,0.0,3.0)),Vector2(0.0,-1.0))
	blaster.reset()
	_tick(2)
	var end_z: float = blaster.exit().origin.z-0.5
	var low := 0.0
	var worst := 0.0
	var tripped := false
	for i in range(300):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		low = minf(low,m.feet.y)
		worst = maxf(worst,absf(blaster.to_local(m.feet).x))
		if blaster.blaster_state != blaster.ARMED: tripped = true
		if m.feet.z < end_z: break
	check(tripped,"Running: he trips the plate on the way")
	check(m.feet.z < end_z and low > -0.3 and worst < float(blaster.knob("width"))*0.5,"...and keeps moving: the blast lands behind him and he clears the lane (z %.1f, lowest y %.2f, widest x %.2f)" % [m.feet.z,low,worst])
