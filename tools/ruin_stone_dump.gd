extends SceneTree
## Builds every ruin piece (both weatherings), a 12-bay hall and an aqueduct
## run in a stone look, and prints a digest of each one's mesh and hulls and
## its triangles: for checking that the classic look is unchanged by the
## stone looks' switch (scripts/ruin_stone_style.gd), and for the looks'
## costs (docs/scenic/ruin-stone.md).
##   Godot --headless --path . -s res://tools/ruin_stone_dump.gd -- --stone=mass [--digest]
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")

func _initialize() -> void:
	var stone := "classic"
	var digest := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stone="): stone = arg.get_slice("=",1)
		elif arg == "--digest": digest = true
	var Style = load("res://scripts/ruin_stone_style.gd")
	if Style != null: Style.use(stone)
	var total := 0
	for id: String in RuinKit.ALL_PIECES:
		for w: float in [0.0,1.0]:
			var node := RuinKit.piece(id,7+RuinKit.ALL_PIECES.find(id),w)
			total += _report("%s w%d" % [id,int(w)],node,digest)
	RuinKit.set_detail(0.25)
	for s: int in [12,20]:
		var started := Time.get_ticks_msec()
		var hall := Hall.hall(s,0.6,12)
		print("  built in %d ms" % (Time.get_ticks_msec()-started))
		var corridors: Array = hall.get_meta("corridors")
		print("  corridors %d plans %s" % [corridors.size(),str(hash(str(hall.get_meta("plans"))))])
		_report("hall12 seed%d in-world" % s,hall,digest)
	RuinKit.set_detail(1.0)
	var run := Aqueduct.run(5,0.55,4,2)
	_report("run4",run,digest)
	print("pieces total triangles ",total)
	quit()

func _report(label: String, root: Node, digest: bool) -> int:
	var tris := RuinKit.triangles(root)
	var stone_tris := 0
	var hulls := 0
	var h := 0
	for node in [root]+root.get_children():
		var mesh := (node as Node).get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			stone_tris += mesh.mesh.surface_get_array_len(0)/3
			if digest:
				for s in range(mesh.mesh.get_surface_count()):
					var a: Array = mesh.mesh.surface_get_arrays(s)
					h = hash([h,a[Mesh.ARRAY_VERTEX],a[Mesh.ARRAY_COLOR]])
		var body := (node as Node).get_node_or_null("Body")
		if body != null:
			for holder in body.get_children():
				hulls += 1
				if digest: h = hash([h,((holder as CollisionShape3D).shape as ConvexPolygonShape3D).points])
	print("%-28s tris %7d stone %7d hulls %5d %s" % [label,tris,stone_tris,hulls,("digest %d" % h) if digest else ""])
	if root is Node and not root.is_queued_for_deletion(): root.free()
	return tris
