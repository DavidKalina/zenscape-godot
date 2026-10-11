extends SceneTree
## Stills of the on-foot pieces in the interactables yard (studies/
## interactables_yard.tscn, docs/design/foot-interactables.md): the yard
## from above, stood on a bobbing slab, mid-swing on a rope (from the
## side), grinding a balustrade, on the turning slab. Needs a renderer
## (opens a window).
##   godot --path . --script tools/capture_interactables.gd -- --no-title [OUT_DIR]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var study: Node3D
var out := "/tmp/interactables"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func tick(want: Vector2, jump := false, crouch := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.tick(DT)

func shot(name: String, eye := Vector3.INF, at := Vector3.ZERO) -> void:
	if eye != Vector3.INF: study.camera.look_at_from_position(eye,at)
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out,name])
	print("CAPTURE ",name)

func run() -> void:
	study = load("res://studies/interactables_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	for i in range(30): await process_frame
	var m: PilotMotor = study.motor
	var pieces: Node3D = study.pieces
	await shot("yard",Vector3(-2.0,26.0,22.0),Vector3(-2.0,0.0,-12.0))
	# On a bobbing slab.
	var slab: Node3D = pieces.slabs[1]
	study.place(slab.transform*Vector3(0.3,0.0,0.2),Vector2(0.0,-1.0))
	for i in range(60): tick(Vector2.ZERO)
	await shot("bob_slab")
	await shot("bob_slabs_side",Vector3(-21.0,4.0,-6.0),Vector3(-30.0,0.5,-11.0))
	# Mid-swing on the first rope.
	var rope: Node3D = pieces.ropes[0]
	study.place(Vector3(6.0,0.0,-1.0),Vector2(0.0,-1.0))
	tick(Vector2.ZERO)
	m.velocity = Vector3(0.0,0.0,-4.8)
	m.grounded = false
	rope._take(m,rope.anchor+Vector3.DOWN*6.0)
	for i in range(80): tick(Vector2(0.0,-1.0) if rope.velocity.z <= 0.0 else Vector2(0.0,1.0))
	for i in range(200):
		if rope.hands.z < rope.anchor.z-2.0 and rope.velocity.z < 0.0: break
		tick(Vector2(0.0,-1.0) if rope.velocity.z <= 0.0 else Vector2(0.0,1.0))
	await shot("rope_swing")
	await shot("rope_side",Vector3(15.0,3.0,-6.0),Vector3(6.0,3.0,-6.0))
	# Grinding the balustrade.
	var rail: Node3D = pieces.rails[1]
	study.place(rail.point(1.0)+Vector3.UP*0.2,Vector2(0.0,1.0))
	tick(Vector2.ZERO)
	for i in range(40):
		var t: Vector3 = rail.way(rail.s)
		var f := Vector2(t.x,t.z).normalized()
		tick(f*0.3-Vector2(-f.y,f.x)*clampf(float(rail.balance)*2.5,-1.0,1.0),false,true)
	await shot("rail_grind")
	await shot("rail_side",Vector3(33.0,5.0,-6.0),Vector3(24.0,2.5,-7.0))
	# The drifting ones from the side.
	await shot("drift_slabs",Vector3(-2.0,6.0,-14.0),Vector3(-12.0,0.5,-18.0))
	quit()
