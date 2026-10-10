extends SceneTree
## Every scene picker entry (scripts/scene_catalog.gd) opened in turn in one
## run, headless, as the picker opens it (its flags through
## scripts/launch_args.gd, with --no-title), and run for a while: no script
## error while it makes itself and runs. The game's own scene waits for its
## shell, with its saves in a scratch folder. One process for all of them, as
## the picker and its way back would load them.
##   godot --headless --path . --script tests/test_scene_picker_entries.gd [-- --only=id,id]
## Takes a few minutes headless.
## suite: slow
const Catalog = preload("res://scripts/scene_catalog.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0

## Counts script errors (and pushes) from the moment it is added.
class Errors extends Logger:
	var count := 0
	var last := ""
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		# Leak reports at exit and the dummy renderer's are not the entry's.
		if file.begins_with("servers/") or file.begins_with("drivers/"): return
		count += 1
		last = "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code,file,line,function]

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func run() -> void:
	create_timer(1500).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	var errors := Errors.new()
	OS.add_logger(errors)
	for entry: Dictionary in Catalog.ENTRIES:
		if not only.is_empty() and not str(entry.id) in only: continue
		var started := Time.get_ticks_msec()
		var before := errors.count
		var args := PackedStringArray(entry.args)
		if not "--no-title" in args: args.insert(0,"--no-title")
		LaunchArgs.set_override(args)
		var scene: Node = load(str(entry.scene)).instantiate()
		var game := "places_path" in scene
		if game:
			var dir := "/private/tmp/scene-picker-entries-%s-%d" % [entry.id,Time.get_ticks_usec()]
			DirAccess.make_dir_recursive_absolute(dir)
			scene.places_path = dir.path_join("places.json")
		root.add_child(scene)
		current_scene = scene
		if game: check(await until(func() -> bool: return scene.shell_ready,300.0),"%s: the game's shell is up" % entry.id)
		await until(func() -> bool: return false,6.0)
		check(is_instance_valid(scene) and scene.is_inside_tree(),"%s: runs" % entry.id)
		check(errors.count == before,"%s: no script errors (%s)" % [entry.id,errors.last if errors.count > before else "%.1f s" % ((Time.get_ticks_msec()-started)/1000.0)])
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		scene.queue_free()
		current_scene = null
		await frames(10)
	OS.remove_logger(errors)
	LaunchArgs.set_override(null)
	print("scene picker entries: %d failures" % failures)
	quit(1 if failures else 0)
