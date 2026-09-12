extends Node3D
## PROTOTYPE: does building a home and carrying its inhabitant into a neighboring
## biome feel like one continuous toy? Native Godot study; no save-file writes.
const Chunk = preload("res://scripts/cozy_chunk_prototype.gd")
const EDGE_PEEK := 0.16
const EDGE_TURN := 0.06
const EDGE_DWELL := 0.55
const TURN_SECONDS := 0.8
const PEEK_TRAVEL := 8.0
var chunks: Array[Node3D] = []
var selected_chunk := 0
var view_chunk := 0
var edge_direction := 0
var edge_dwell := 0.0
var edge_armed := true
var peek_amount := 0.0
var turn_time := -1.0
var turn_from := 0
var turn_to := 0
var turn_direction := 1
var queued_drop := false
var queued_drop_mouse := Vector2.ZERO
var edge_hint := Label.new()
var edge_progress := ProgressBar.new()
var resident_chunk := 0
var creature := CreatureActor.new()
var camera := Camera3D.new()
var marker := MeshInstance3D.new()
var marker_material := StandardMaterial3D.new()
var reaction := Label3D.new()
var hud := CanvasLayer.new()
var toolbar: PanelContainer
var bottom: PanelContainer
var status := Label.new()
var selection_label := Label.new()
var tool_buttons: Dictionary = {}
var landscape_buttons: Array[Button] = []
var places_label := Label.new()
var undo_button: Button
var tool := "hand"
var history: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var pressed_creature := false
var press_at := Vector2.ZERO
var carry_origin := Vector3.ZERO
var carry_grab_offset := Vector2.ZERO
var carry_target: Variant = null
var camera_yaw := 0.28
var camera_pitch := 0.70
var camera_size := 20.0
var camera_target := Vector3(0,0.7,0)
var walking_to: Variant = null
var next_action := ""
var next_interest := 4.0
var reaction_time := 0.0
var arrival_pending := false
var arrival_from := 0
var has_visited_snow := false
var _elapsed := 0.0
var snow_act_time := -1.0
var snowball := MeshInstance3D.new()

func _ready() -> void:
	get_window().title = "ZenScape · A home for Bigfoot"
	get_window().content_scale_size = Vector2i(1440,900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	rng.randomize()
	_build_world()
	_add_chunk(false)
	_add_chunk(true)
	add_child(creature)
	creature.name = "Bigfoot"
	creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	var coat := StandardMaterial3D.new()
	coat.vertex_color_use_as_albedo = true
	coat.roughness = 0.95
	for mesh: MeshInstance3D in creature.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	snowball.mesh = SphereMesh.new()
	snowball.scale = Vector3.ONE*0.20
	var snow_material := StandardMaterial3D.new()
	snow_material.albedo_color = Color("e4edf0")
	snowball.material_override = snow_material
	add_child(snowball)
	snowball.hide()
	creature._ground_probe = _ground
	creature.reset_at(chunks[0].ground(Vector3(0,0,1.4)))
	creature.landed.connect(_landed)
	creature.add_child(reaction)
	reaction.position.y = 3.35
	reaction.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reaction.font_size = 48
	reaction.pixel_size = 0.006
	reaction.modulate = Color("fff3d4")
	reaction.no_depth_test = true
	reaction.hide()
	_build_ui()
	_frame_world()
	_say("Home and snow are ready. Pick Bigfoot up and carry toward either side to peek.")
	get_window().focus_exited.connect(_cancel_carry)

func _build_world() -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 200.0
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("d9ddd0")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e7eddf")
	world.environment.ambient_light_energy = 0.4
	world.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment.ssao_enabled = true
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52,-32,0)
	light.light_color = Color("fff0d3")
	light.light_energy = 0.9
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 65
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color("d4e4ef")
	fill.light_energy = 0.2
	add_child(fill)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_node.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("c8cfbf")
	floor_node.material_override = floor_mat
	floor_node.position.y = -1.4
	add_child(floor_node)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.53
	marker.mesh = ring
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.hide()

func _add_chunk(snow: bool) -> void:
	var chunk := Chunk.new()
	add_child(chunk)
	chunk.visible = chunks.is_empty()
	chunk.setup(snow, 12 if not snow else 38)
	chunks.append(chunk)

func _panel(parent: Node, at_top: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f0e5")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if at_top else Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 22
	panel.offset_right = -22
	if at_top: panel.offset_top = 20
	else:
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		panel.offset_top = -158
		panel.offset_bottom = -20
	return panel

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	add_child(hud)
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color","Label",Color("374b3c"))
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal":Color("e4e8d9"),"hover":Color("d0dbc3"),"pressed":Color("688361"),"disabled":Color("efede5")}[state]
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		theme.set_stylebox(state,"Button",style)
		theme.set_color("font_"+state+"_color","Button",Color("f8f4e8") if state == "pressed" else Color("374b3c"))
	theme.set_color("font_color","Button",Color("374b3c"))
	toolbar = _panel(hud, true)
	toolbar.theme = theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	toolbar.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "A home for Bigfoot"
	title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header,"Center this place",_frame_world)
	places_label.text = "Home  ·  Snow"
	header.add_child(places_label)
	var landscapes := HFlowContainer.new()
	landscapes.add_theme_constant_override("h_separation",8)
	column.add_child(landscapes)
	selection_label.custom_minimum_size = Vector2(150,36)
	landscapes.add_child(selection_label)
	for entry in [["Clearing",0],["Gentle hills",1],["Empty patch",2]]:
		var style: int = entry[1]
		landscape_buttons.append(_button(landscapes,entry[0],func() -> void: _generate(style, false)))
	landscape_buttons.append(_button(landscapes,"Roll another",func() -> void: _generate(chunks[selected_chunk].layout, true)))
	bottom = _panel(hud, false)
	bottom.theme = theme
	var lower := VBoxContainer.new()
	lower.add_theme_constant_override("separation",8)
	bottom.add_child(lower)
	var tools_row := HFlowContainer.new()
	tools_row.add_theme_constant_override("h_separation",8)
	lower.add_child(tools_row)
	for entry in [["hand","Hand"],["tree","Tree"],["flowers","Flowers"],["pond","Pond"],["log","Log"],["hill","Little hill"]]:
		var kind: String = entry[0]
		var button := _button(tools_row,entry[1],func() -> void: _select_tool(kind))
		button.toggle_mode = true
		tool_buttons[kind] = button
	undo_button = _button(tools_row,"Undo",_undo)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 22
	lower.add_child(status)
	var hint := Label.new()
	hint.text = "Carry Bigfoot to either screen edge to turn the world · Move inward to drop · Right drag orbits · Esc returns"
	hint.add_theme_font_size_override("font_size",12)
	lower.add_child(hint)
	edge_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edge_hint.add_theme_color_override("font_color",Color("374b3c"))
	edge_hint.add_theme_font_size_override("font_size",20)
	hud.add_child(edge_hint)
	edge_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_progress.show_percentage = false
	edge_progress.max_value = EDGE_DWELL
	hud.add_child(edge_progress)
	edge_hint.hide()
	edge_progress.hide()
	_update_ui()

func _update_ui() -> void:
	selection_label.text = "Editing: " + ("Snowy patch" if selected_chunk == 1 else "Home patch")
	for kind in tool_buttons: tool_buttons[kind].set_pressed_no_signal(tool == kind)
	undo_button.disabled = history.is_empty() or creature.is_held()
	for button in landscape_buttons: button.disabled = creature.is_held()


func _select_tool(kind: String) -> void:
	_cancel_carry()
	tool = kind
	_update_ui()
	_say("Click an open spot to place " + {"tree":"a tree.","flowers":"flowers.","pond":"a little pond.","log":"a resting log.","hill":"a gentle hill."}.get(kind,"your attention. Drag Bigfoot whenever you like."))

func _remember() -> void:
	var snapshots: Array[Dictionary] = []
	for chunk in chunks: snapshots.append(chunk.snapshot())
	history.append({"chunks":snapshots,"selected":selected_chunk,"resident":resident_chunk,"feet":creature.land_position})
	if history.size() > 30: history.pop_front()

func _generate(style: int, randomize_layout: bool) -> void:
	if creature.is_held(): return
	_remember()
	var chunk: Node3D = chunks[selected_chunk]
	chunk.generate(rng.randi_range(1,99999) if randomize_layout else chunk.landscape_seed, style)
	_rehome_after_edit()
	_update_ui()
	_say("A fresh little possibility. Undo brings the previous landscape back.")

func _undo() -> void:
	if history.is_empty() or creature.is_held(): return
	var previous: Dictionary = history.pop_back()
	while chunks.size() > previous.chunks.size():
		var removed: Node3D = chunks.pop_back()
		remove_child(removed)
		removed.queue_free()
	for i in range(chunks.size()): chunks[i].restore(previous.chunks[i])
	selected_chunk = previous.selected
	resident_chunk = previous.resident
	view_chunk = resident_chunk
	selected_chunk = view_chunk
	_layout_places()
	walking_to = null
	next_action = ""
	arrival_pending = false
	snow_act_time = -1.0
	snowball.hide()
	creature.reset_at(_safe_near(resident_chunk,previous.feet))
	_frame_world()
	_update_ui()
	_say("Back to how it was.")

func _rehome_after_edit() -> void:
	if selected_chunk != resident_chunk: return
	walking_to = null
	next_action = ""
	arrival_pending = false
	snow_act_time = -1.0
	snowball.hide()
	creature.reset_at(_safe_near(resident_chunk,creature.global_position))
	next_interest = 1.5

func _safe_near(index: int, point: Vector3) -> Vector3:
	var chunk: Node3D = chunks[index]
	if chunk.is_safe(point): return chunk.ground(point)
	for radius in range(1,20):
		for spoke in range(24):
			var angle := spoke*TAU/24
			var candidate := point+Vector3(cos(angle),0,sin(angle))*radius*0.4
			if chunk.is_safe(candidate): return chunk.ground(candidate)
	return chunk.ground(chunk.global_position+Vector3(0,0,3.8))

func _chunk_at(point: Vector3) -> int:
	return view_chunk if chunks[view_chunk].contains(point) else -1

func _ground(point: Vector3) -> Variant:
	var index := _chunk_at(point)
	return chunks[index].ground(point) if index >= 0 else null

func _over_ui(mouse: Vector2) -> bool:
	return toolbar.get_global_rect().has_point(mouse) or bottom.get_global_rect().has_point(mouse)

func _pick_ground(mouse: Vector2) -> Variant:
	if _over_ui(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	var ray_origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	# Ray-march the actual height field; the gap and the diorama's sides are not land.
	var previous: Variant = null
	for i in range(600):
		var point := ray_origin+ray*i*0.15
		var ground: Variant = _ground(point)
		if ground != null and point.y <= ground.y and previous != null and previous.y > ground.y:
			var low: Vector3 = point
			var high: Vector3 = previous
			for j in range(8):
				var mid := (low+high)*0.5
				var mid_ground: Variant = _ground(mid)
				if mid_ground == null or mid.y > mid_ground.y: high = mid
				else: low = mid
			return _ground(low)
		previous = point
	return null

func _pick_creature(mouse: Vector2) -> bool:
	if _over_ui(mouse): return false
	var inverse := creature.global_transform.affine_inverse()
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	var hit: Variant = AABB(Vector3(-0.65,0,-0.5),Vector3(1.3,3.0,1.0)).intersects_ray(inverse*origin,(inverse.basis*ray).normalized())
	if hit == null: return false
	var ground: Variant = _pick_ground(mouse)
	return ground == null or origin.distance_to(creature.global_transform*hit) <= origin.distance_to(ground)+0.1

func _begin_carry(mouse: Vector2) -> void:
	if turn_time >= 0: return
	carry_origin = _safe_near(resident_chunk,creature.land_position)
	edge_armed = true
	edge_dwell = 0.0
	edge_direction = 0
	arrival_from = resident_chunk
	if not creature.pick_up(): return
	walking_to = null
	next_action = ""
	arrival_pending = false
	snow_act_time = -1.0
	snowball.hide()
	# Keep the original grab point under the cursor; lift without an initial jump.
	carry_grab_offset = camera.unproject_position(creature.global_position+Vector3.UP*creature.grasp_height)-mouse
	_update_ui()
	_say("Carry toward a side to peek at the next place. Hold at the edge to turn.")

func _update_carry(mouse: Vector2, delta: float) -> void:
	carry_target = null
	if not _over_ui(mouse):
		var plane := Plane(Vector3.UP, 3.8)
		# The edge gesture can reach the border while his dangling arms remain visible.
		var grip := mouse+carry_grab_offset
		grip.x = clampf(grip.x,72,get_viewport().get_visible_rect().size.x-72)
		var at: Variant = plane.intersects_ray(camera.project_ray_origin(grip),camera.project_ray_normal(grip))
		if at != null:
			var destination: Vector3 = at-Vector3.UP*creature.grasp_height
			var floor_point: Variant = _ground(destination)
			if floor_point != null:
				destination.y = maxf(destination.y,floor_point.y+0.65)
				if get_viewport().get_visible_rect().has_point(mouse): carry_target = floor_point
			creature.move_held(creature.global_position.lerp(destination,1-exp(-18*delta)),delta)
	if turn_time >= 0 or edge_direction != 0 or peek_amount > 0.01: carry_target = null
	marker.visible = carry_target != null
	if carry_target != null:
		marker.position = carry_target+Vector3.UP*0.06
		marker.scale = Vector3.ONE
		var valid: bool = chunks[_chunk_at(carry_target)].is_safe(carry_target)
		marker_material.albedo_color = Color("b2dd91") if valid else Color("d5ac72")

func _drop(mouse: Vector2) -> void:
	if not creature.is_held(): return
	if turn_time >= 0:
		queued_drop = true
		queued_drop_mouse = mouse
		pressed_creature = false
		return
	_update_carry(mouse,0.001)
	var valid: bool = carry_target != null and chunks[_chunk_at(carry_target)].is_safe(carry_target)
	if valid:
		resident_chunk = _chunk_at(carry_target)
		selected_chunk = resident_chunk
		arrival_pending = true
		creature.release_at(carry_target)
		_say("Finding his feet...")
	else:
		_return_to_origin()
		_say("A little more room, please. Back to his last safe spot.")
	pressed_creature = false
	_clear_edge()
	marker.hide()
	_update_ui()

func _cancel_carry() -> void:
	pressed_creature = false
	if creature.is_held():
		_return_to_origin()
		arrival_pending = false
		marker.hide()
		_update_ui()
		_say("Back to his safe spot.")

func _landed() -> void:
	if not arrival_pending: return
	arrival_pending = false
	if resident_chunk != arrival_from:
		if resident_chunk == 1:
			next_action = "snow"
			_say("Cold toes. A curious handful of snow." if not has_visited_snow else "Back for another handful of snow.")
			has_visited_snow = true
		else:
			next_action = "home"
			_say("Home again. He takes a moment to settle in.")
	else: next_action = "look"
	next_interest = 0.1

func _place(point: Vector3) -> void:
	var index := _chunk_at(point)
	if index < 0: return
	selected_chunk = index
	_update_ui()
	if tool == "hand":
		_say("Snowy patch selected." if index == 1 else "Home patch selected.")
		return
	var clearance: float = {"pond":2.1,"tree":1.3,"log":1.7,"flowers":0.9,"hill":1.8}.get(tool,1.2)
	if not chunks[index].can_place(tool,point) or point.distance_to(creature.global_position)<clearance:
		_say("Leave a little room around Bigfoot and the things already here.")
		return
	_remember()
	chunks[index].place(tool,point)
	_rehome_after_edit()
	if index == resident_chunk:
		var near := _safe_near(index,point+Vector3(0,0,clearance+0.3))
		if _clear_path(creature.global_position,near): walking_to = near
		creature.track_gaze(point+Vector3.UP*0.6)
		next_action = "rest" if tool == "log" else "inspect"
		_say("He noticed. Let's see what he makes of it.")
	else: _say("Something for him to discover when he visits.")
	_update_ui()

func _clear_path(from: Vector3, to: Vector3) -> bool:
	for i in range(1,31):
		var point := from.lerp(to,float(i)/30)
		if not chunks[resident_chunk].is_safe(point): return false
	return true

func _show_reaction(text: String) -> void:
	reaction.text = text
	reaction.show()
	reaction_time = 3.0

func _act(kind: String) -> void:
	match kind:
		"snow":
			creature.perform_action("Sit",4.5)
			snow_act_time = 0.0
			creature.track_gaze(creature.global_position+Vector3(0,0.3,1))
			_show_reaction("Oh!")
		"home", "rest":
			creature.perform_action("Sit",4.0)
			_show_reaction("... ahh")
		"inspect":
			creature.notice(creature.global_position+creature.global_basis.z*2+Vector3.UP*0.3)
			_show_reaction("?")
		_:
			creature.notice(camera.global_position)
	next_interest = rng.randf_range(4.0,7.0)

func _process(delta: float) -> void:
	if creature.player == null: return
	_elapsed += delta
	reaction_time -= delta
	if reaction_time <= 0: reaction.hide()
	if creature.is_held():
		_update_wheel(get_viewport().get_mouse_position(),delta)
		if not creature.is_held(): return
		_update_carry(get_viewport().get_mouse_position(),minf(delta,0.05))
		return
	if snow_act_time >= 0:
		snow_act_time += delta
		if creature.state != CreatureActor.State.ACTION:
			snow_act_time = -1.0
			snowball.hide()
		else:
			var lift := smoothstep(1.0,2.5,snow_act_time)
			var hand := creature.to_global(Vector3(0.45,lerpf(0.18,1.1,lift),0.85))
			creature.reach_hand(hand,0.9,"R")
			creature.track_gaze(hand)
			snowball.position = creature.hand_position("R")
			snowball.visible = snow_act_time > 1.4 and snow_act_time < 4.0
	_update_placement_preview()
	if not creature.can_roam(): return
	if walking_to != null:
		if not _clear_path(creature.global_position,walking_to):
			walking_to = null
			creature.stop_walking()
		elif creature.walk_step(walking_to,0.65,delta):
			walking_to = null
			creature.stop_walking()
		return
	next_interest -= delta
	if next_interest > 0: return
	if not next_action.is_empty():
		_act(next_action)
		next_action = ""
		return
	var chunk: Node3D = chunks[resident_chunk]
	for attempt in range(12):
		var destination: Vector3 = chunk.ground(creature.global_position+Vector3(rng.randf_range(-2.4,2.4),0,rng.randf_range(-2.4,2.4)))
		if _clear_path(creature.global_position,destination):
			walking_to = destination
			break
	next_action = "rest" if rng.randf() < 0.25 else "look"
	next_interest = 3.0

func _update_placement_preview() -> void:
	marker.hide()
	if tool == "hand": return
	var point: Variant = _pick_ground(get_viewport().get_mouse_position())
	if point == null: return
	marker.show()
	marker.position = point+Vector3.UP*0.08
	marker.scale = Vector3.ONE*({"pond":1.6,"tree":0.65,"log":1.1,"hill":1.4,"flowers":0.6}[tool]/0.5)
	var clearance: float = {"pond":2.1,"tree":1.3,"log":1.7,"flowers":0.9,"hill":1.8}[tool]
	var valid: bool = chunks[_chunk_at(point)].can_place(tool,point) and point.distance_to(creature.global_position)>=clearance
	marker_material.albedo_color = Color("b2dd91") if valid else Color("d5ac72")

func _input(event: InputEvent) -> void:
	if creature.player == null: return
	if event is InputEventMouseMotion and pressed_creature:
		if not creature.is_held() and event.position.distance_to(press_at) >= 5: _begin_carry(press_at)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pressed_creature:
		if creature.is_held(): _drop(event.position)
		else: creature.notice(camera.global_position)
		pressed_creature = false
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_carry()
			_select_tool("hand")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_undo()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _pick_creature(event.position):
				pressed_creature = true
				press_at = event.position
			else:
				var point: Variant = _pick_ground(event.position)
				if point != null: _place(point)
		elif event.pressed and not creature.is_held() and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_size = clampf(camera_size*(0.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1),10,42)
			_update_camera()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT and not creature.is_held():
		camera_yaw -= event.relative.x*0.006
		camera_pitch = clampf(camera_pitch+event.relative.y*0.005,0.35,1.2)
		_update_camera()

func _frame_world() -> void:
	if creature.is_held(): return
	camera_target = Vector3(0,0.7,0)
	camera_size = 20.0
	camera_yaw = 0.18
	camera_pitch = 0.72
	_update_camera()

func _update_camera() -> void:
	camera.size = camera_size
	camera.position = camera_target+Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*40
	camera.look_at(camera_target)

func _say(message: String) -> void:
	status.text = message


func _layout_places() -> void:
	for i in range(chunks.size()):
		chunks[i].position = Vector3.ZERO
		chunks[i].rotation = Vector3.ZERO
		chunks[i].scale = Vector3.ONE
		chunks[i].visible = i == view_chunk

func _clear_edge() -> void:
	edge_direction = 0
	edge_dwell = 0.0
	peek_amount = 0.0
	turn_time = -1.0
	queued_drop = false
	edge_hint.hide()
	edge_progress.hide()
	_layout_places()

func _return_to_origin() -> void:
	view_chunk = arrival_from
	resident_chunk = arrival_from
	selected_chunk = view_chunk
	_clear_edge()
	# Both patches have local coordinates around the origin. Cancel restores the
	# original habitat first, then its safe feet, without flying through a tile.
	creature.reset_at(carry_origin)

func _wheel_span() -> float:
	return camera.size*get_viewport().get_visible_rect().size.aspect()*0.5+8.0

func _neighbor(direction: int) -> int:
	return posmod(view_chunk+direction,chunks.size())

func _update_wheel(mouse: Vector2, delta: float) -> void:
	if turn_time >= 0:
		turn_time = minf(turn_time+delta,TURN_SECONDS)
		var t := turn_time/TURN_SECONDS
		var eased := t*t*(3.0-2.0*t)
		var axis := camera.global_basis.x*turn_direction
		var span := _wheel_span()
		chunks[turn_from].position = -axis*span*eased-Vector3.UP*sin(t*PI)*0.8
		chunks[turn_to].position = axis*(span-PEEK_TRAVEL*peek_amount)*(1.0-eased)-Vector3.UP*sin(t*PI)*0.8
		chunks[turn_from].scale = Vector3.ONE*(1.0-0.08*sin(t*PI))
		chunks[turn_to].scale = chunks[turn_from].scale
		if t >= 1:
			view_chunk = turn_to
			selected_chunk = view_chunk
			turn_time = -1.0
			peek_amount = 0.0
			edge_direction = 0
			_layout_places()
			_update_ui()
			_say("Snowy patch. Move inward to set him down." if view_chunk == 1 else "Home again. Move inward to set him down.")
			if queued_drop:
				queued_drop = false
				_drop(queued_drop_mouse)
		return
	var size := get_viewport().get_visible_rect().size
	var inside := Rect2(Vector2.ZERO,size).has_point(mouse) and not _over_ui(mouse)
	var fraction := mouse.x/size.x
	var direction := (-1 if fraction < EDGE_PEEK else 1 if fraction > 1.0-EDGE_PEEK else 0) if inside else 0
	if direction == 0:
		if inside and fraction > EDGE_PEEK+0.04 and fraction < 1.0-EDGE_PEEK-0.04: edge_armed = true
		edge_direction = 0
		edge_dwell = 0.0
		peek_amount = move_toward(peek_amount,0.0,delta*5)
		if peek_amount <= 0.001:
			_layout_places()
			edge_hint.hide()
			edge_progress.hide()
		elif chunks.size()>1:
			chunks[turn_to].position = camera.global_basis.x*turn_direction*(_wheel_span()-PEEK_TRAVEL*peek_amount)
		return
	if not edge_armed or chunks.size()<2:
		edge_dwell = 0.0
		return
	if direction != edge_direction:
		_layout_places()
		edge_dwell = 0.0
		peek_amount = 0.0
	edge_direction = direction
	turn_direction = direction
	turn_to = _neighbor(direction)
	var depth := clampf((EDGE_PEEK-minf(fraction,1-fraction))/(EDGE_PEEK-EDGE_TURN),0,1)
	peek_amount = move_toward(peek_amount,depth,delta*5)
	chunks[turn_to].show()
	chunks[turn_to].position = camera.global_basis.x*direction*(_wheel_span()-PEEK_TRAVEL*peek_amount)
	var at_edge := fraction <= EDGE_TURN or fraction >= 1.0-EDGE_TURN
	edge_dwell = edge_dwell+minf(delta,0.05) if at_edge else 0.0
	edge_hint.text = ("‹  " if direction<0 else "")+("Snowy patch" if turn_to==1 else "Home patch")+("  ›" if direction>0 else "")+"\n"+("Hold to turn" if at_edge else "A little farther...")
	edge_hint.size = Vector2(220,60)
	edge_hint.position = Vector2(24 if direction<0 else size.x-244,size.y*0.30)
	edge_hint.show()
	edge_progress.size = Vector2(180,7)
	edge_progress.position = edge_hint.position+Vector2(20,65)
	edge_progress.value = edge_dwell
	edge_progress.visible = at_edge
	if edge_dwell >= EDGE_DWELL:
		turn_from = view_chunk
		turn_time = 0.0
		edge_armed = false
		edge_dwell = 0.0
		edge_hint.hide()
		edge_progress.hide()
		_say("Coming around... keep hold of him.")
