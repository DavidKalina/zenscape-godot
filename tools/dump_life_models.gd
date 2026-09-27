extends SceneTree
## Dumps the pond life's meshes (scripts/life_models.gd, and the Fidelity frog
## for comparison) as painted triangles, each with the instance tint the game
## multiplies it by, for tools/render_life_models.py to render in Blender.
##   godot --headless --path . -s res://tools/dump_life_models.gd -- --out=/tmp/zs-life-models/models.json

const Models = preload("res://scripts/life_models.gd")

func _initialize() -> void:
	var out := "/tmp/zs-life-models/models.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var specimens := []
	var reference: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var frog_source := reference.find_child("mesh-40",true,false) as MultiMeshInstance3D
	if frog_source != null:
		var tints := []
		for i in range(frog_source.multimesh.instance_count): tints.append(frog_source.multimesh.get_instance_color(i))
		for i in range(mini(4,tints.size())):
			specimens.append(_specimen("fidelity frog %d" % i,"frog",frog_source.multimesh.mesh,tints[i],1.5))
	reference.free()
	var models: Script = load("res://scripts/life_models.gd")
	if models.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "specimens"):
		for entry: Dictionary in models.call("specimens",null): specimens.append(_specimen(entry.name,entry.group,entry.mesh,entry.get("tint",Color.WHITE),entry.get("scale",1.0)))
	else:
		var colors := [Color(0.88,0.47,0.16),Color(0.92,0.74,0.32),Color(0.72,0.74,0.72),Color(0.94,0.9,0.82)]
		for i in range(colors.size()): specimens.append(_specimen("fish %d" % i,"fish",Models.fish(null),colors[i],1.05))
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(specimens))
	file.close()
	print("dumped %d specimens to %s" % [specimens.size(),out])
	quit()

func _specimen(label: String, group: String, mesh: Mesh, tint: Color, scale: float) -> Dictionary:
	var positions := []
	var colors := []
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var painted: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var order: Array = Array(indices) if not indices.is_empty() else range(vertices.size())
		for i: int in order:
			var v := vertices[i]*scale
			positions.append_array([v.x,v.y,v.z])
			var c: Color = painted[i] if i < painted.size() else Color.WHITE
			colors.append_array([c.r,c.g,c.b])
	return {"name":label,"group":group,"tint":[tint.r,tint.g,tint.b],"positions":positions,"colors":colors}
