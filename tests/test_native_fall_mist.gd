extends SceneTree
## The landscape fall's mist matches the source and shares the scene's depth
## texture (a RenderingDevice texture, none headless); undo and reopen keep it.
## suite: gpu
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.content.set_process(false)
	editor.start_flat()
	editor.form_range()
	editor.fill_landscape_waterfall()
	var generated: Dictionary=preload("res://scripts/native_fall_mist.gd").build(editor.data.waterfall_strands(),editor.data._recipe.source.g.chute.flow)
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-mist.json"))
	var error:=absf(generated.rise-expected.rise)
	for key in ["positions","velocity","phase","size"]:
		if generated[key].size()!=expected[key].size(): error=INF
		else:
			for i in range(generated[key].size()): error=maxf(error,absf(generated[key][i]-expected[key][i]))
	await process_frame
	await process_frame
	editor.content._process(0.0)
	var mist=editor.content._landscape_mists[0]
	var shared: CompositorEffect=scene._display_fog.depth if scene._display_fog!=null else scene.get_node("WaterfallSpray").fallback_depth
	var depth_shared: bool=mist.fallback_depth==null and shared.texture.texture_rd_rid.is_valid() and mist.material.get_shader_parameter("surface_depth")==shared.texture
	var baseline: Dictionary=editor.data.to_document()
	editor.data.undo()
	editor.refresh()
	var removed: bool=editor.content._landscape_mists.is_empty()
	var reopened: bool=editor.data.load_document(JSON.parse_string(JSON.stringify(baseline,"",true,true)))
	editor.refresh()
	reopened=reopened and editor.content._landscape_mists.size()==1 and editor.content._landscape_mists[0].particle_count==expected.phase.size()
	print("Mist particles ",generated.phase.size(),"; source attribute error ",error,"; shared depth ",depth_shared,"; undo removes ",removed,"; reopen restores ",reopened)
	var ok: bool=error<0.000001 and depth_shared and removed and reopened
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
