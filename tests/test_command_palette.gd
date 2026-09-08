extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1; push_error(message)
func settle() -> void:
 await create_timer(0.3).timeout
func key(code: Key, command := false) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 event.ctrl_pressed = command
 root.push_input(event)
func click(point: Vector2) -> void:
 for down in [true,false]:
  var event := InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  event.position = root.get_final_transform()*point
  event.global_position = event.position
  root.push_input(event)
func run() -> void:
 root.size = Vector2i(1800,1200)
 var scene: Node3D = load("res://studies/nursery_preview.tscn").instantiate()
 root.add_child(scene)
 var palette: NativeBuildPalette = scene._build_palette
 var editor: NativeChunkEditor = scene._chunk_editor
 editor.reactions_enabled = false
 await settle()
 check(not palette._bar.visible,"The landscape starts clear")
 key(KEY_K,true)
 await settle()
 check(palette._bar.visible and palette._search.has_focus(),"Command K opens focused search")
 check(palette._matches.size() == palette._entries.size(),"Every catalog item is reachable")
 check(palette._tabs.get_child_count() == 7,"Seven fixed categories")
 click(Vector2(5,5))
 check(palette._bar.visible,"Veil clicks do not dismiss")
 key(KEY_UP)
 check(palette._focus_index == palette._matches.size()-1,"Up wraps to the final result")
 key(KEY_DOWN)
 check(palette._focus_index == 0,"Down wraps to the first result")
 key(KEY_TAB)
 check(palette._entries[palette._matches[palette._focus_index]].group == "Water","Tab jumps to the next group")
 for query in ["grass","pine","pond","bigfoot"]:
  palette._search.text = query
  palette._refresh_results()
  check(not palette._matches.is_empty() and palette._entries[palette._matches[0]].title.to_lower() == query,"Exact name leads search for "+query)
 palette._search.text = ""
 palette._refresh_results()
 check(palette._entries[palette._matches[0]].group == "Terrain","Clearing search restores category order")
 palette._browse("Flora")
 palette._search.text = "pine"
 palette._search.text_changed.emit("pine")
 await settle()
 check(palette._matches == ["tree"],"Substring search and category filtering compose")
 check(palette._detail_preview.texture != null,"The selected miniature has a live preview")
 key(KEY_ENTER)
 check(palette._placing == "tree" and not palette._launcher.visible,"Enter takes the miniature into hand")
 var before := editor.data.objects.size()
 var point: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(0,editor.data.height_at(0,0),0)))
 click(point)
 check(editor.data.objects.size() == before+1,"World click places exactly one tree")
 check(palette._placing == "tree" and editor.mode == "tree","Placement keeps the tree tool active")
 check(palette._hand.accepted and palette._hand.reaction > 0.0,"Successful placement triggers the glove squeeze")
 click(point)
 check(editor.data.objects.size() == before+2,"A second click places another tree")
 palette.open_palette()
 palette._choose("tree")
 key(KEY_ESCAPE)
 check(palette._placing.is_empty() and editor.data.objects.size() == before+2,"Escape cancels without placement")
 # Tool families retain their own choices, independently of the item catalog.
 palette._choose("flower")
 check(palette._tool_rail.family == "Place" and palette._tool_rail.trail.visible,"Flowers offer contextual trail placement")
 palette._tool_rail.activate("Sculpt")
 palette._tool_rail.activate("Place")
 check(editor.mode == "flower","Returning to Place restores the flower")
 palette.open_palette()
 key(KEY_ESCAPE)
 check(not palette._bar.visible and editor.mode == "flower","Closing search preserves the tool")
 editor.set_process(false)
 var flower_count := editor.data.objects.size()
 var press := InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 press.position = root.get_final_transform()*point
 root.push_input(press)
 check(editor._painting,"Mouse-down keeps the flower stroke open")
 var origin: Vector2 = editor._trail_point
 editor.continue_trail(origin+Vector2(3,0))
 var painted_count := editor.data.objects.size()
 check(painted_count > flower_count+1,"Dragging plants spaced flowers")
 editor.continue_trail(origin+Vector2(3,0))
 check(editor.data.objects.size() == painted_count,"Holding still does not pile up flowers")
 press.pressed = false
 root.push_input(press)
 check(not editor._painting and editor.mode == "flower","Release ends the stroke and retains the flower")
 editor.undo()
 check(editor.data.objects.size() == flower_count,"One undo removes the entire flower stroke")
 editor.redo()
 check(editor.data.objects.size() == painted_count,"Redo restores the entire stroke")
 palette._tool_rail.trail.button_pressed = false
 click(point)
 check(editor.data.objects.size() == painted_count+1 and not editor._painting,"Stamp mode plants one flower per click")
 palette._choose("raise")
 press.pressed = true
 root.push_input(press)
 check(editor._painting and editor.mode == "raise","Sculpting stays active after mouse-down")
 press.pressed = false
 root.push_input(press)
 check(not editor._painting and editor.mode == "raise","Sculpting ends on release without deselecting")
 palette._choose("mountain")
 editor.placement_trail = true
 var original_heights := editor.data.heights.duplicate()
 press.pressed = true
 root.push_input(press)
 check(editor._painting,"Mountains support a held stroke")
 editor.continue_trail(Vector2(5,0))
 press.pressed = false
 root.push_input(press)
 check(editor.data.heights != original_heights,"A mountain stroke shapes the terrain")
 editor.undo()
 check(editor.data.heights == original_heights,"One undo restores terrain before the mountain stroke")
 var rail_point: Vector2 = palette._tool_rail.get_global_rect().get_center()
 check(not editor.pointer_in_world(rail_point),"The rail shields terrain from edits")
 key(KEY_ESCAPE)
 palette.open_palette()
 palette._search.text = "zzzzzz"
 palette._refresh_results()
 check(palette._empty.visible and palette._matches.is_empty(),"Empty search has an explicit state")
 key(KEY_ENTER)
 check(palette._bar.visible,"Enter on empty results does nothing")
 key(KEY_ESCAPE)
 root.size = Vector2i(960,640)
 palette.open_palette()
 await settle()
 check(palette._bar.size == Vector2(880,540),"The panel keeps fixed proportions on small screens")
 check(is_equal_approx(palette._fit_wrapper.scale.x,palette._fit_wrapper.scale.y),"Fit scaling is uniform")
 check(root.get_visible_rect().encloses(palette._bar.get_global_rect()),"The panel fits the small window")
 for scroll in palette.find_children("*","ScrollBar",true,false):
  check(not scroll.is_visible_in_tree(),"No visible scrollbars")
 palette._browse("Creatures")
 palette._take_special("bigfoot")
 point = scene.camera.unproject_position(editor.terrain.to_global(Vector3(0,editor.data.height_at(0,0),0)))
 check(palette._place_special(point),"Bigfoot can be set down in the world")
 palette._finish_placing()
 check(is_instance_valid(palette._inhabitant),"Bigfoot uses the existing animated actor")
 var inhabitant = palette._inhabitant
 palette._take_special("bigfoot")
 click(point)
 check(palette._placing.is_empty() and editor.mode == "select","Bigfoot placement returns to selection")
 check(palette._inhabitant == inhabitant,"Placing Bigfoot again repositions the same actor")
 root.size = Vector2i(1440,1000)
 palette._choose("flower")
 await settle()
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("/tmp/zenscape-tool-rail.png")
 palette._hand.take()
 palette._hand.show_at(Vector2(100,100),true,0.1)
 check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"The glove replaces the system pointer over the world")
 check(palette._hand.grip > 0.0,"Carrying curls the fingers")
 palette.open_palette()
 check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not palette._hand.visible,"Opening the palette restores the system pointer")
 palette._hand.show_at(Vector2(100,100),true,0.1)
 palette._hand.release(false)
 check(not palette._hand.accepted,"Cancellation uses a release instead of a placement pulse")
 palette._hand.hide_pointer()
 check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Leaving the world restores the system pointer")
 print("Command palette: ",failures," failures")
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
