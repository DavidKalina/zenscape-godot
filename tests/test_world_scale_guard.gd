extends SceneTree
## The game's sizes live in one file (scripts/world_scale.gd, AGENTS.md
## "Sizes"), headless, a text scan of scripts/ and studies/: only
## world_scale.gd parses `--plane-scale=` / `--wanderer-scale=` /
## `--opening-ratio=` (and no file the old `--room-scale=`), and only it
## and plane_figure.gd read the toy span (PlaneFigure.SPAN); everyone else
## asks WorldScale (`span`, `gap(room)`, or `TOY_SPAN` for a toy-sized base
## they scale themselves). Comment lines are skipped.
##   godot --headless --path . --script tests/test_world_scale_guard.gd
const WorldScale = preload("res://scripts/world_scale.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")

const ROOTS := ["res://scripts","res://studies"]
const SIZES := "res://scripts/world_scale.gd"
const FIGURE := "res://scripts/plane_figure.gd"
## Files allowed past a rule, each with its reason: {path: reason}.
const ALLOW_FLAGS := {}
const ALLOW_SPAN := {}

var failures := 0

func _initialize() -> void:
	var flags := RegEx.create_from_string("--(plane|wanderer|room)-scale=|--opening-ratio=")
	var span := RegEx.create_from_string("PlaneFigure\\.SPAN\\b|plane_figure\\.gd\"\\)\\.SPAN\\b")
	var files := _gd_files()
	var hits_flags: Array[String] = []
	var hits_span: Array[String] = []
	for path in files:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"): continue
			if path != SIZES and not ALLOW_FLAGS.has(path) and flags.search(line) != null:
				hits_flags.append("%s:%d  %s" % [path,n,line.strip_edges()])
			if path != SIZES and path != FIGURE and not ALLOW_SPAN.has(path) and span.search(line) != null:
				hits_span.append("%s:%d  %s" % [path,n,line.strip_edges()])
	check(files.size() > 100 and SIZES in files,"scanned %d .gd files under scripts/ and studies/" % files.size())
	check(hits_flags.is_empty(),"only world_scale.gd parses --plane-scale= / --wanderer-scale= / --opening-ratio=%s" % _list(hits_flags))
	check(not "--room-scale=" in FileAccess.get_file_as_string(SIZES),"the temporary --room-scale= is gone")
	check(hits_span.is_empty(),"only world_scale.gd and plane_figure.gd read PlaneFigure.SPAN%s" % _list(hits_span))
	check(is_equal_approx(WorldScale.TOY_SPAN,PlaneFigure.SPAN),"WorldScale.TOY_SPAN is plane_figure.gd's SPAN (%.2f)" % PlaneFigure.SPAN)
	print("PASS: world scale guard" if failures == 0 else "FAIL: world scale guard (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _list(hits: Array[String]) -> String:
	return "" if hits.is_empty() else ":\n    "+"\n    ".join(hits)

func _gd_files() -> Array[String]:
	var out: Array[String] = []
	var dirs: Array = ROOTS.duplicate()
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if not sub.begins_with("."): dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"): out.append(dir.path_join(file))
	return out
