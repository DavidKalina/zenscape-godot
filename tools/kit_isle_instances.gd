extends SceneTree
## How many drawn instances (and surfaces) a kit isle stands, by part: its
## art (land, rock, ruins), the flora, the life, the sky. Draw calls follow
## these (each visible surface, and again in each shadow pass).
##   godot --headless --path . --script tools/kit_isle_instances.gd -- res://studies/cloister_tarn_isle.tscn
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("res://"): path = a
	var study: Node = load(path).instantiate()
	study.set("scripted",true)
	root.add_child(study)
	while not study.get("walk_ready"): await process_frame
	for i in range(10): await process_frame
	var art: Node = study.get("art")
	var parts := {"art":art,"life":study.get("life"),"sky":study.get("sky")}
	for name: String in parts:
		var node: Node = parts[name]
		if node == null: continue
		var c := {"mesh":0,"multimesh":0,"surfaces":0,"other":0}
		_count(node,c,name == "art")
		print("INST %s %s" % [name,c])
	if art != null:
		var by := {}
		for child in art.get_children():
			var c := {"mesh":0,"multimesh":0,"surfaces":0,"other":0}
			_count(child,c,false)
			var key := str(child.name).rstrip("0123456789_@")
			if not by.has(key): by[key] = {"nodes":0,"surfaces":0}
			by[key].nodes += 1
			by[key].surfaces += int(c.surfaces)
		var keys := by.keys()
		keys.sort_custom(func(a,b): return by[a].surfaces > by[b].surfaces)
		for k in keys.slice(0,25): print("INST art/%s %s" % [k,by[k]])
	quit(0)

func _count(node: Node, c: Dictionary, skip_flora: bool) -> void:
	if skip_flora and node.name == &"Flora": return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as Node3D).visible:
		c.mesh += 1
		c.surfaces += (node as MeshInstance3D).mesh.get_surface_count()
	elif node is MultiMeshInstance3D and (node as Node3D).visible:
		c.multimesh += 1
		c.surfaces += 1
	elif node is GeometryInstance3D and (node as Node3D).visible:
		c.other += 1
		c.surfaces += 1
	for child in node.get_children(): _count(child,c,skip_flora)
