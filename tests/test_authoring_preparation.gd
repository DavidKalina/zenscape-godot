extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	check(scene._look_editor != null and scene._landscape_editor != null,"Authoring panels are prepared before interaction")
	check(not scene._build_palette._thumbs.is_empty(),"Object thumbnails are prepared before interaction")
	if scene._look_editor != null:
		check(not scene._look_editor.visible and not scene._landscape_editor.visible,"Prepared panels start hidden")
	if scene.has_method("prepare_authoring_ui"):
		var before: Dictionary = scene._chunk_editor.data.to_document()
		var panel_id: int = scene._look_editor.get_instance_id()
		scene.prepare_authoring_ui()
		check(scene._look_editor.get_instance_id() == panel_id and before == scene._chunk_editor.data.to_document(),"Repeated preparation reuses panels and leaves world data unchanged")
	var palette = scene._build_palette
	scene._chunk_editor.set_active(true)
	palette.open_palette()
	var row_id: int = palette._row_buttons.flower.get_instance_id()
	palette.close_palette()
	palette.open_palette()
	check(palette._row_buttons.flower.get_instance_id() == row_id,"Reopening reuses result rows")
	palette._search.text = "flower"
	palette._refresh_results()
	check(palette._matches.has("flower") and not palette._matches.has("rock"),"Cached rows respect filtering")
	palette._search.text = ""
	palette._refresh_results()
	check(palette._row_buttons.flower.get_instance_id() == row_id and palette._row_buttons.has("rock"),"Clearing search restores cached rows")
	check(scene._menu.visible and not scene._has_world,"Preparation leaves the initial world/menu state intact")
	scene.free()
	print("AUTHORING PREPARATION failures=",failures)
	quit(failures)
