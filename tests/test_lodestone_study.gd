extends SceneTree
## The lodestone look study (studies/lodestone_study.tscn,
## docs/design/lodestone-study.md) loads and builds: the stone with its
## miniature, its swirl and its glow; every miniature builds from the set
## pieces' code inside its triangle budget; each of the three views takes
## the stone (on the sill, in the pilot's hands, in the plane's cradle,
## streaming). Headless: the look itself is GPU work.
const Minis = preload("res://scripts/lodestone_miniatures.gd")
## The miniatures' triangle budgets (the hall's far detail, the aqueduct's
## kit stone at the least growth).
const BUDGET := {"sundered":6000,"aqueduct":36000}
var failures := 0

func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ")+what)
	if not ok: failures += 1

func _initialize() -> void:
	var study: Node3D = load("res://studies/lodestone_study.tscn").instantiate()
	root.add_child(study)
	for i in range(10): await process_frame
	var stone: Node3D = study._stone
	check(stone != null and stone.is_inside_tree(),"the lodestone is in the scene")
	check(stone.get_node_or_null("Turn/Miniature/Stone") != null,"the stone is built under its miniature")
	check(stone.get_node_or_null("Ribbons") is MultiMeshInstance3D and stone.get_node_or_null("Motes") is MultiMeshInstance3D,"the swirl's strokes and riders are built")
	for kind: String in Minis.KINDS:
		stone.set_miniature(kind)
		var tris: int = stone.info.triangles
		check(tris > 500 and tris < int(BUDGET[kind]),"%s builds: %d triangles (budget %d)" % [kind,tris,BUDGET[kind]])
		var shards := stone.find_children("Shard","MeshInstance3D",true,false)
		check(shards.size() >= 1,"%s has its shard of island" % kind)
	check(stone.find_children("Thread","MeshInstance3D",true,false).size() == 1,"the aqueduct spills its thread of water")
	for view: String in ["world","inspect","cradle"]:
		study._set_view(view)
		for i in range(30): await process_frame
		check(stone.is_inside_tree(),"%s: the stone is in the scene" % view)
		if view == "cradle":
			check(stone.get_parent() == study._seat,"cradle: the stone sits in the gimbal's seat")
			check(stone.stream > 0.0,"cradle: the swirl streams (%.2f)" % stone.stream)
		elif view == "inspect":
			check(study._pick > 0.0 and stone.hum > 0.0,"inspect: the pickup runs and the stone hums")
	study._set_view("world")
	study._held_near = 1.6
	study._along = 1.6
	for i in range(90): await process_frame
	check(stone.hum > 0.5,"world: the stone hums with the pilot beside it (%.2f)" % stone.hum)
	study.queue_free()
	await process_frame
	print("PASS: lodestone study" if failures == 0 else "FAIL: lodestone study")
	quit(1 if failures else 0)
