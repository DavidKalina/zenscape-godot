extends SceneTree
## Locking onto an isle from the plane (scripts/isle_lock.gd, studies/
## kit_isle.gd `toggle_lock`), headless, on the aqueduct isle: out of reach
## R3 only puts the camera back; in reach Tab locks on and shows the isle's
## card (scripts/isle_splash.gd); locked, the plane flies itself round the
## isle on its ring (held near the ring, never in stone, a good way round in
## the band of sky), the stick draws the ring out and raises it; R3 lets go
## and the card fades; leaving the plane lets go too. Near a motif isle in
## the aqueduct isle's sky (docs/scenic/motif-sky.md), Tab locks onto it,
## its card shows, and the plane circles it clear of its stone.
##   godot --headless --path . --script tests/test_isle_lock.gd
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(180.0).timeout.connect(func() -> void: push_error("isle lock test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	study.board()
	var circle: Vector3 = study.isle_circle()
	print("isle circle: middle (%.0f, %.0f), radius %.0f m" % [circle.x,circle.y,circle.z])
	var middle := Vector3(circle.x,study.isle_top(),circle.y)
	# Far out: no lock, R3 is the camera reset still.
	study.fly_from(middle+Vector3(2000.0,30.0,0.0),0.0)
	_r3()
	check(study.isle_lock != null and not study.isle_lock.locked,"Out of reach R3 does not lock")
	# In reach, heading roughly along the ring.
	var ring: float = study.isle_lock.ring_rest()
	study.fly_from(middle+Vector3(ring*1.6,25.0,0.0),0.0)
	_tab()
	check(study.isle_lock.locked,"In reach Tab locks on")
	check(study.splash != null and study.splash.visible and str(study.splash._name.text) == "THE AQUEDUCT OF VEYL","The isle's card shows its name")
	check(str(study._switch_hint.text).contains("Circling"),"The hint says it is circling")
	var lock: RefCounted = study.isle_lock
	var in_stone := 0
	var swept := 0.0
	var worst := 0.0
	var low := INF
	var last := _angle(middle)
	for i in range(int(50.0/DT)):
		study.fly_step(DT,study._fly_input(DT))
		study.splash._process(DT)
		if study._in_stone(): in_stone += 1
		var a := _angle(middle)
		swept += angle_difference(last,a)
		last = a
		if i*DT > 15.0:
			worst = maxf(worst,absf(lock.off_ring(study.plane.position)))
			low = minf(low,float(study.plane.position.y)-study.isle_top())
	check(absf(swept) > PI,"Locked, it flies round the isle (%.0f deg in 50 s)" % rad_to_deg(absf(swept)))
	check(worst < 25.0,"It holds the ring (worst %.1f m off after settling, ring %.0f m)" % [worst,lock.ring])
	check(in_stone == 0,"Never in stone (%d frames)" % in_stone)
	check(low > lock.BAND.x-4.0,"It keeps the band of sky (lowest %.1f m over the top)" % low)
	check(float(lock.framing) >= 1.0,"The camera frames the isle")
	check(not study.splash.visible,"The card has faded by itself")
	# The stick draws the ring out and raises it.
	var was_ring: float = lock.ring
	var was_height: float = lock.height
	Input.action_press(&"move_right",1.0)
	Input.action_press(&"move_back",1.0)
	for i in range(int(2.0/DT)): study.fly_step(DT,study._fly_input(DT))
	Input.action_release(&"move_right")
	Input.action_release(&"move_back")
	check(float(lock.ring) > was_ring+20.0 and float(lock.height) > was_height+5.0,"Right draws the ring out, S raises it (%.0f m, %.0f m)" % [float(lock.ring)-was_ring,float(lock.height)-was_height])
	_r3()
	check(not lock.locked,"R3 lets go")
	for i in range(int(1.0/DT)): study.fly_step(DT,study._fly_input(DT))
	check(float(lock.framing) < 0.1,"The camera lets go of the isle")
	_tab()
	check(lock.locked and study.splash.visible,"Tab locks on again and the card shows again")
	study.leave_plane()
	check(not lock.locked,"Leaving the plane lets go")
	await _motif_lock()
	print("PASS: isle lock" if failures == 0 else "FAIL: isle lock (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The bell spires, placed in the sky: in reach of it (and out of the
## aqueduct isle's), Tab locks onto it and its card shows; it circles it.
func _motif_lock() -> void:
	study.sky.flush()
	await physics_frame
	var bell: Node3D = study.motifs.isles[0]
	var c: Vector3 = bell.circle()
	var middle := Vector3(c.x,bell.isle_top(),c.y)
	study.board()
	study.fly_from(middle+Vector3(150.0,25.0,0.0),0.0)
	_tab()
	var lock: RefCounted = study.isle_lock
	check(lock.locked and Vector2(lock.centre.x-c.x,lock.centre.z-c.y).length() < 1.0,"By the bell spires Tab locks onto them (ring round (%.0f, %.0f))" % [lock.centre.x,lock.centre.z])
	check(study.splash.visible and str(study.splash._name.text) == "SPIRES OF THE SILENT BELL","Their card shows (%s)" % str(study.splash._name.text))
	var in_stone := 0
	var swept := 0.0
	var last := _angle(middle)
	for i in range(int(30.0/DT)):
		study.fly_step(DT,study._fly_input(DT))
		if study._in_stone(): in_stone += 1
		var a := _angle(middle)
		swept += angle_difference(last,a)
		last = a
	check(lock.locked and absf(swept) > PI*0.5 and in_stone == 0,"It circles them, never in stone (%.0f deg in 30 s, %d frames in stone)" % [rad_to_deg(absf(swept)),in_stone])
	_r3()

func _angle(middle: Vector3) -> float:
	var p: Vector3 = study.plane.position
	return atan2(p.z-middle.z,p.x-middle.x)

func _r3() -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_RIGHT_STICK
	press.pressed = true
	study._unhandled_input(press)

func _tab() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	study._unhandled_input(key)
