extends SceneTree
## A helper process that builds one motif isle and keeps it in the isle
## store (scripts/roguelike/isle_store.gd; docs/design/roguelike/
## loading-screen-round2.md). The game starts several at once while its
## loading screen is up: this engine runs one process's GDScript one thread
## at a time, so isles built on the game's workers wait on each other, while
## each helper has its own. Headless, its own main thread, then quits.
##   Godot --headless --path <project> -s res://scripts/roguelike/isle_forge.gd -- \
##     <the game's own flags> --forge-motif=<script> --forge-seed=<n> \
##     --forge-bells=<0|1> --forge-style=<look> --forge-out=<file>
## The game's flags are passed through so a build reads what the game's does
## (the plane and wanderer sizes, the stone look). Answers exit code 0 once
## the file is written.
const IsleStore = preload("res://scripts/roguelike/isle_store.gd")
const RuinLod = preload("res://scripts/ruin_lod.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

func _initialize() -> void:
	var motif_path := ""
	var seed_value := -1
	var bells := false
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--forge-motif="): motif_path = a.get_slice("=",1)
		elif a.begins_with("--forge-seed="): seed_value = int(a.get_slice("=",1))
		elif a.begins_with("--forge-bells="): bells = a.get_slice("=",1) == "1"
		elif a.begins_with("--forge-style="): Style.use(a.get_slice("=",1))
		elif a.begins_with("--forge-out="): out = a.trim_prefix("--forge-out=")
	var began := Time.get_ticks_msec()
	var motif: RefCounted = load(motif_path).new()
	if seed_value >= 0: motif.configure(seed_value)
	if motif.get("still_bells") != null: motif.set("still_bells",bells)
	motif.warm()
	var root := Node3D.new()
	root.name = "Staging"
	motif.build(root)
	RuinLod.add(root)
	var built := Time.get_ticks_msec()-began
	var why := IsleStore.save(motif,root,out)
	print("isle forge: %s seed %d built in %d ms, kept in %d ms%s" % [str(motif.id()),seed_value,built,Time.get_ticks_msec()-began-built," ("+why+")" if why != "" else ""])
	root.free()
	motif = null
	quit(0 if why == "" else 1)
