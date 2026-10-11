extends SceneTree
## Nothing the aqueduct isle's sky made on a worker outlives it
## (docs/design/consolidation-audit.md, "Round 2 done"), headless: the scene
## freed while its pierced isle (scripts/sky_pierced.gd) stands its parts a
## frame at a time, the lid up and the ruins not yet, takes the ruins' node
## tree (made whole on a worker, colliders and all) with it. Left behind, it
## was 4276 objects, 13 bodies and 2087 shapes "leaked at exit", which the
## packaged check (tools/verify_desktop_export.py) fails on.
##   godot --headless --path . --script tests/test_isle_teardown.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	LaunchArgs.set_override(PackedStringArray(["--no-title"]))
	var scene: Node = load("res://studies/aqueduct_isle.tscn").instantiate()
	root.add_child(scene)
	var ruins_id := 0
	var deadline := Time.get_ticks_msec()+150000
	while ruins_id == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
		var sky: Variant = scene.get("sky")
		if sky == null or sky.get("pierced") == null: continue
		for key in sky.pierced.isles:
			var s: Dictionary = sky.pierced.isles[key]
			if s.has("b") and "ruins" in (s.get("stage",[]) as Array) and s.out.get("ruins") is Node3D:
				ruins_id = (s.out.ruins as Node3D).get_instance_id()
	check(ruins_id != 0,"Caught the pierced isle with its lid up and its ruins not yet")
	var bodies := 0
	if ruins_id != 0:
		var ruins: Node3D = instance_from_id(ruins_id)
		bodies = ruins.find_children("*","CollisionObject3D",true,false).size()
		check(ruins.get_parent() == null,"The ruins' tree stands nowhere yet (%d bodies)" % bodies)
	scene.free()
	await process_frame
	check(ruins_id == 0 or not is_instance_id_valid(ruins_id),"Freed with the scene")
	LaunchArgs.set_override(null)
	print("isle teardown: %d failures" % failures)
	quit(1 if failures else 0)
