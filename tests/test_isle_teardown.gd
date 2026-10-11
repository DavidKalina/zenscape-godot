extends SceneTree
## Nothing the aqueduct isle's sky made off the tree outlives it
## (docs/design/consolidation-audit.md, "Round 2 done"; docs/scenic/
## motif-sky.md), headless: the scene freed while a motif isle (scripts/
## kit_isle/motif_isle.gd) stands its parts a frame at a time, its art
## built whole (colliders and all) and partly stood, takes the parts not
## yet stood with it. Left behind, such a tree was thousands of objects,
## bodies and shapes "leaked at exit", which the packaged check
## (tools/verify_desktop_export.py) fails on. (Round 2's case was the
## pierced isle's ruins, built on a worker; the pierced isle has left the
## aqueduct isle's sky, and the motif isles stand the same way.)
##   godot --headless --path . --script tests/test_isle_teardown.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	# Headless the motif isles are built when the eye comes near: now.
	LaunchArgs.set_override(PackedStringArray(["--no-title","--motifs-now"]))
	var scene: Node = load("res://studies/aqueduct_isle.tscn").instantiate()
	root.add_child(scene)
	var staging_id := 0
	var stood := 0
	var deadline := Time.get_ticks_msec()+150000
	while staging_id == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
		var motifs: Variant = scene.get("motifs")
		if motifs == null: continue
		for isle: Node3D in motifs.isles:
			var staging: Variant = isle.get("_staging")
			if isle.stage == "standing" and staging is Node3D and (staging as Node3D).get_child_count() > 1 and isle.art.get_child_count() > 0:
				staging_id = (staging as Node3D).get_instance_id()
				stood = isle.art.get_child_count()
				break
	check(staging_id != 0,"Caught a motif isle with its art partly stood (%d parts up)" % stood)
	var bodies := 0
	if staging_id != 0:
		var staging: Node3D = instance_from_id(staging_id)
		bodies = staging.find_children("*","CollisionObject3D",true,false).size()
		check(staging.get_parent() == null and bodies > 0,"The parts not yet stood stand nowhere yet (%d bodies)" % bodies)
	scene.free()
	await process_frame
	check(staging_id == 0 or not is_instance_id_valid(staging_id),"Freed with the scene")
	LaunchArgs.set_override(null)
	print("isle teardown: %d failures" % failures)
	quit(1 if failures else 0)
