extends SceneTree
## The pocket sail on the aqueduct isle (studies/aqueduct_isle.tscn, a kit
## isle: studies/kit_isle.gd), headless: the pilot there flies the motor's
## own sail (scripts/pocket_sail.gd), so Space again in the air with room
## under him opens it, drawn over him, and it coasts down at its sink; the
## isle's air (studies/atmosphere.gd, read by PocketSail `atmosphere_air`)
## reaches it: its breeze, and a gust front (B) pushing it harder.
##   godot --headless --path . --script tests/test_aqueduct_isle_sail.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func steps(n: int, jump := false) -> void:
	study.script_jump = jump
	for i in range(n): study.tick(DT)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("aqueduct isle sail test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	var m: PilotMotor = study.motor
	check(m.air.is_valid(),"The isle gives the motor its air")
	# High over open sky beside the isle.
	study.place(Vector3(0.0,Art.TOP+60.0,260.0),Vector2(0.0,-1.0))
	steps(20)
	steps(1,true)
	steps(1)
	check(m.move == "sail" and m.sail.kicked,"Space again in the air: the sail, with its kick")
	check(study.sail_wing.visible,"Drawn over him")
	steps(150)
	check(m.move == "sail" and absf(-m.velocity.y-PocketSail.SINK) < 0.8,"Coasting down near its sink (%.2f m/s)" % -m.velocity.y)
	var breeze: Vector3 = m.air.call(m.feet).get("wind",Vector3.ZERO)
	check(Vector2(breeze.x,breeze.z).length() > 0.5,"The isle's breeze reaches it (%.1f m/s)" % Vector2(breeze.x,breeze.z).length())
	# A gust front (B) across what the camera looks at.
	study._send_gust()
	var strongest := 0.0
	for i in range(60*8):
		study.tick(DT)
		# The air moves on in the isle's own frame (its _process).
		await process_frame
		var w: Vector3 = m.air.call(m.feet).get("wind",Vector3.ZERO)
		strongest = maxf(strongest,Vector2(w.x,w.z).length())
	print("MEASURE: breeze %.2f m/s, gust at its strongest %.2f m/s" % [Vector2(breeze.x,breeze.z).length(),strongest])
	check(strongest > Vector2(breeze.x,breeze.z).length()+1.0,"A gust front pushes harder (%.1f m/s)" % strongest)
	# Gone before the quit, so nothing of the isle is left over at exit.
	study.queue_free()
	for i in range(5): await process_frame
	print("PASS: aqueduct isle sail" if failures == 0 else "FAIL: aqueduct isle sail (%d)" % failures)
	quit(1 if failures > 0 else 0)
