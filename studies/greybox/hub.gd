extends Node
## The greybox hub: one window for every greybox study in this folder.
## It loads the first (or `--start=<slug>`) and leaves a switcher on the
## tree's root, which outlives each scene change: Page Down the next,
## Page Up the one before, its name in the corner and the window's title.
##   godot --path . res://studies/greybox/hub.tscn -- --no-title [--start=benchfall]
## A new greybox joins by one line in GREYBOXES.

## [slug, name]: the scene is res://studies/greybox/<slug>.tscn.
const GREYBOXES := [
	["wardens_well","The Warden's Well"],
	["benchfall","Benchfall"],
	["noon_weir","The Noon Weir"],
	["sunken_giant","The Sunken Giant"],
	["tithe_wheel","The Tithe Wheel"],
	["lidstack","Lidstack"],
	["astronomers_hush","The Astronomer's Hush"],
	["vigil_bellows","The Vigil of the Bellows"],
	["plumb_well","The Plumb Well"],
	["washing_rite","The Washing Rite"],
]

func _ready() -> void:
	var start := 0
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--start="):
			var slug := arg.get_slice("=",1)
			for i in GREYBOXES.size():
				if GREYBOXES[i][0] == slug: start = i
	var switcher := Switcher.new()
	switcher.name = "GreyboxSwitcher"
	get_tree().root.add_child.call_deferred(switcher)
	switcher.go.call_deferred(start)

class Switcher extends Node:
	var at := 0
	var label: Label

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		label = Label.new()
		label.position = Vector2(16.0,12.0)
		label.add_theme_font_size_override("font_size",20)
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",6)
		layer.add_child(label)

	func go(i: int) -> void:
		var count: int = GREYBOXES.size()
		at = posmod(i,count)
		var entry: Array = GREYBOXES[at]
		label.text = "%d/%d  %s   ·   PgUp / PgDn switch greybox" % [at+1,count,entry[1]]
		DisplayServer.window_set_title("Greybox: %s" % entry[1])
		get_tree().change_scene_to_file("res://studies/greybox/%s.tscn" % entry[0])

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo: return
		if key.keycode == KEY_PAGEDOWN:
			get_viewport().set_input_as_handled()
			go(at+1)
		elif key.keycode == KEY_PAGEUP:
			get_viewport().set_input_as_handled()
			go(at-1)
