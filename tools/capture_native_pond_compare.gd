extends SceneTree
## Controlled lake comparison on identical editor-generated terrain.
## -- --imported-control swaps only the water mesh/transform to the reference.
## This is a diagnostic control, never a saved authored-world reconstruction.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var reference: MeshInstance3D=scene.get_node("Reference/mesh-30")
	var reference_mesh:=reference.mesh
	var reference_transform:=reference.global_transform
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.form_range()
	editor.cover_grass()
	var pool: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json")).pool
	if not editor.data.add_pond(Vector2(pool.x,pool.z),pool.waterY):
		push_error("Comparison pond placement failed")
		quit(1)
		return
	editor.refresh()
	var control: bool="--imported-control" in OS.get_cmdline_user_args()
	if control:
		editor.content._water.mesh=reference_mesh
		editor.content._water.global_transform=reference_transform
	scene._celestial.set_phase(0.4)
	scene._paused=true
	scene._ui.visible=false
	scene._capture="res://docs/garden/pond-imported-control.png" if control else "res://docs/garden/pond-generated-control.png"
	scene.set_process(true)
