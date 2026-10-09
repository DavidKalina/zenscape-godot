extends SceneTree
## Probe: everything a pierced isle is made of (scripts/sky_pierced.gd
## `make`, as the worker makes it): the plan, the lid, the rock near and
## far, the ruins; each part's time and triangles, for a few seeds.
##   godot --headless --path . --script tools/probe_pierced_make.gd -- [--seeds=1-3]
const SkyPierced = preload("res://scripts/sky_pierced.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const PiercedRuins = preload("res://scripts/pierced_ruins.gd")
const PiercedMesh = preload("res://scripts/pierced_mesh.gd")

func _initialize() -> void:
	var lo := 1
	var hi := 3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			var parts := a.trim_prefix("--seeds=").split("-")
			lo = int(parts[0])
			hi = int(parts[1]) if parts.size() > 1 else lo
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	SkyIslets.catalog(null)
	SkyIslets._prepare()
	PiercedRuins.prepare()
	PiercedMesh.material()
	for s in range(lo,hi+1):
		var out := {}
		SkyPierced.make(s,SkyIslet.plain_palette(),50.0,out)
		var plan: RefCounted = out.plan
		var lid_top := (out.lid.top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		var lid_sides := (out.lid.sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		var plants := 0
		for k in out.lid.plants: plants += int(out.lid.plants[k].count)
		var ruins: Node3D = out.ruins
		var ruin_tris := PiercedRuins.triangles(ruins)
		var hulls := 0
		if ruins != null:
			for body in ruins.find_children("*","CollisionObject3D",true,false): hulls += (body as Node).get_child_count()
		print("seed %d draw %d: %.2f s (lid %.2f s, near %.2f s, far %.2f s); tris lid top %d, lid wall %d, rock near %d, rock far %d, ruins %d (%s); hulls %d; plants %d; problems %s" % [s,plan.draw,out.usec/1.0e6,out.stats.lid_usec/1.0e6,
			out.stats.near.usec/1.0e6,out.stats.far.usec/1.0e6,lid_top,lid_sides,out.stats.near.faces,out.stats.far.faces,ruin_tris,
			", ".join(plan.ruins.map(func(r: Dictionary) -> String: return r.kind)),hulls,plants,str(plan.problems)])
		if ruins != null:
			for child in ruins.get_children(): print("   %s: %d tris" % [child.name,PiercedRuins.triangles(child)])
			ruins.free()
	PiercedMesh.release()
	quit()
