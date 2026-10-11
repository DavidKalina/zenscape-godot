extends RefCounted
## The launch flags every scene reads (the user args after `--`), with a way
## to change them for a scene opened in-game (docs/design/scene-picker.md).
## The command line can't change once the game runs, so the scene picker
## (scripts/scene_picker.gd) sets `override` before it changes scene, and
## everything that used to call OS.get_cmdline_user_args() calls `user_args`
## instead. With no override, it's the command line, as before.
##
## Caveat: a script that reads the flags into a `static var` keeps what it read
## the first time it loaded (before the title, usually). None of the picker's
## entries pass such a flag; an entry that needs one wants that read moved.

static var override: Variant = null

## The user args in force: the override if one is set, else the command line's.
static func user_args() -> PackedStringArray:
	if override != null: return override
	return OS.get_cmdline_user_args()

## True while a scene runs on args the picker gave it.
static func overridden() -> bool:
	return override != null

## Sets the args the next scene reads; `null` goes back to the command line's.
static func set_override(args: Variant) -> void:
	override = null if args == null else PackedStringArray(args)

## Changes to `scene` with `args` as its launch flags. `--no-title` is
## among them unless `own_title` (the builder's entry, which opens on its own
## title: scripts/scene_catalog.gd), so a scene that has a title (studies/
## cozy_worlds.tscn, studies/zenscape.tscn) goes straight in. Returns the
## change_scene error.
static func open_scene(tree: SceneTree, scene: String, args: PackedStringArray, own_title := false) -> Error:
	var given := PackedStringArray(args)
	if not own_title and not "--no-title" in given: given.insert(0,"--no-title")
	set_override(given)
	return tree.change_scene_to_file(scene)

## The flags for coming back to the title: the command line's (or `from`),
## without the ones that skip it.
static func title_args(from: Variant = null) -> PackedStringArray:
	var out := PackedStringArray()
	var args: PackedStringArray = OS.get_cmdline_user_args() if from == null else PackedStringArray(from)
	var skip := false
	for arg: String in args:
		if skip:
			skip = false
			continue
		# "--seed N": the seed and its value.
		if arg == "--seed":
			skip = true
			continue
		if arg in ["--no-title","--resume","--generated","--atlas","--verify-desktop-build"]: continue
		out.append(arg)
	return out
