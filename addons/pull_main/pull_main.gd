@tool
extends EditorPlugin
## Play in the editor runs the latest main, as tools/play.py's launchers do:
## before each run a checkout on main is fast-forwarded to origin's main
## (`git pull --ff-only`). When commits come in, that run is called off,
## the editor rescans and reimports what changed, and the main scene runs
## once the import is done. On another branch, offline, or with local changes
## in the way, it says so in Output and plays what's here.

const WAIT := 0.25

## The run started after a pull, which goes ahead without pulling again.
var _replay := false

func _build() -> bool:
	if _replay:
		_replay = false
		return true
	if _pull() == 0: return true
	var files := EditorInterface.get_resource_filesystem()
	files.scan()
	_play_when_imported.call_deferred()
	return false

## Commits fast-forwarded into the checkout at `root` (the project's by
## default; 0: none, or no pull).
func _pull(root := "") -> int:
	OS.set_environment("GIT_TERMINAL_PROMPT","0")
	if root.is_empty(): root = ProjectSettings.globalize_path("res://")
	var branch := _git(root,["rev-parse","--abbrev-ref","HEAD"])
	if branch.is_empty(): return 0
	if branch != "main":
		print("Pull main: on branch %s, not main: playing what's here" % branch)
		return 0
	var before := _git(root,["rev-parse","HEAD"])
	# Files git only thinks changed (Windows line endings) never block the pull.
	_git(root,["update-index","-q","--refresh"])
	var out: Array = []
	var code := OS.execute("git",["-C",root,"pull","--ff-only","--quiet","origin","main"],out,true)
	if code != 0:
		var why := "git failed"
		for line: String in "\n".join(PackedStringArray(out)).split("\n"):
			if line.strip_edges().begins_with("fatal:") or line.strip_edges().begins_with("error:"):
				why = line.strip_edges()
				break
		push_warning("Pull main: couldn't pull main (%s); playing what's here" % why)
		return 0
	var after := _git(root,["rev-parse","HEAD"])
	if after == before:
		print("Pull main: main is up to date")
		return 0
	# (A "before..after" argument fails to parse when Godot runs git on Windows.)
	var count := int(_git(root,["rev-list","--count",after,"--not",before]))
	print("Pull main: pulled %d new commit(s); latest: %s. Importing, then playing." % [count,_git(root,["log","-1","--format=%s",after]).left(120)])
	return maxi(count,1)

## The main scene, run once the rescan and its imports are done.
func _play_when_imported() -> void:
	var files := EditorInterface.get_resource_filesystem()
	# The reimports start on the frames after the scan.
	for i in 3: await get_tree().process_frame
	while files.is_scanning() or files.is_importing():
		await get_tree().create_timer(WAIT).timeout
	_replay = true
	EditorInterface.play_main_scene()

static func _git(root: String, args: Array) -> String:
	var out: Array = []
	var code := OS.execute("git",["-C",root]+args,out,true)
	return "\n".join(PackedStringArray(out)).strip_edges() if code == 0 else ""
