extends SceneTree
## Bakes the Hollow Child's clay (scripts/city_hollow_child_mesh.gd: a
## signed distance field meshed by surface nets, its paint channels in the
## vertex colours) to art/hollow_child/hollow_child_body.res and
## hollow_child_head.res, with generated LODs. Run again when the figure's
## primitives change:
##   python tools/godot.py --script tools/bake_hollow_child.gd [-- --cell=0.022]
const Mesh_ = preload("res://scripts/city_hollow_child_mesh.gd")

func _init() -> void:
	var cell := 0.022
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cell="): cell = float(a.get_slice("=",1))
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/hollow_child"))
	for pair: Array in [[false,Mesh_.BODY_RES],[true,Mesh_.HEAD_RES]]:
		var t := Time.get_ticks_msec()
		var m: ArrayMesh = Mesh_.build(pair[0],cell,true)
		var tris := m.surface_get_array_index_len(0)/3
		var err := ResourceSaver.save(m,pair[1],ResourceSaver.FLAG_COMPRESS)
		print("hollow child: %s %d tris, %d verts, lods %d, aabb %s, %d ms, saved %s (%d)" % ["head" if pair[0] else "body",tris,m.surface_get_array_len(0),m.surface_get_lod_count(0) if m.has_method("surface_get_lod_count") else -1,str(m.get_aabb()),Time.get_ticks_msec()-t,pair[1],err])
	print("hollow child: baked in %d ms" % (Time.get_ticks_msec()-t0))
	quit()
