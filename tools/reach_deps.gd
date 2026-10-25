extends SceneTree
## Writes scratch/reach_deps.txt for tools/reach.py: a line DEP <file>
## <dependency> for every resource file under res:// that Godot can name
## dependencies for (binary scenes, imported models, .tres).
##   python tools/godot.py -s res://tools/reach_deps.gd
var _out: FileAccess
func _init() -> void:
	_out = FileAccess.open("res://scratch/reach_deps.txt", FileAccess.WRITE)
	_walk("res://")
	_out.close()
	print("reach_deps: wrote scratch/reach_deps.txt")
	quit()
func _walk(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for sub in d.get_directories():
		if sub in [".godot", "scratch", ".git", ".claude", "captures", "native"]: continue
		_walk(dir.path_join(sub))
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid") or f.ends_with(".gd") or f.ends_with(".md"): continue
		var p := dir.path_join(f)
		if not ResourceLoader.exists(p): continue
		for dep in ResourceLoader.get_dependencies(p):
			_out.store_line("DEP %s %s" % [p, dep])
