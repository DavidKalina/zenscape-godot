extends "res://studies/fidelity.gd"
## Isolated entry point for the nursery UI iteration; uses the live game assets.
func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Quick create"
	_chunk_editor.set_active(true)
	_chunk_editor.select_tool("arch")
