extends Node3D
## Ruin kit gallery: the gothic ruin kit's thirteen pieces (scripts/
## ruin_kit.gd) on a floating plate, each intact and weathered side by side,
## laid close in three rows (the tall gable, arch and window at the back,
## the turret, vault, buttress and pier in the middle, the low pieces in
## front) so the whole view is ruins, not lawn. Lit as the game is: its sky,
## sun and grade (scripts/landscape_lighting.gd, studies/celestial.gd) and
## its look pass (scripts/look_pass.gd: the cloud sea and cloud volume under
## the plate, the hour's grade, the night style the player chose), at the
## game's own noon and midnight (the look tour's hours, tools/
## capture_look_tour.gd). The pilot on foot (scripts/pilot_figure.gd)
## stands about for scale and the plane (scripts/plane_figure.gd) hangs in
## the pointed arch.
##   Drag            orbit          Wheel     zoom
##   1-9 0 - = \     frame a piece  Left/Right the next piece
##   Space or Tab    the whole layout
##   W               pairs, intact only, weathered only
##   R               reseed the weathering     N  day or night
##   ./run-ruin-kit.command [--piece=2] [--night] [--show=intact|weathered] [--seed=3]
##   godot --path . res://studies/ruin_kit_gallery.tscn -- --no-title --capture=out.png
## --capture=<png> waits for the sky to settle, saves the view and quits;
## --yaw=, --pitch= and --distance= set the view for it.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")

## The rows, back to front, and where each stands (z, m).
const ROWS := [["rose_gable","arch","lancet_wall"],["turret","vault","buttress","pier"],["wall","stairs","fallen_pier","tomb_chest","floor","glyph_stone"]]
const ROW_Z := [-13.0,-1.5,9.0]
## The room between a pair's two (m) and between pairs.
const PAIR_GAP := 0.8
const SLOT_GAP := 2.6
## The hours (studies/celestial.gd phase): a late morning, the sun high
## enough to be the game's day and low enough to model the faces; midnight.
const DAY := 0.45
const NIGHT := 0.0
## The game's own look at its noon, as the look tour logged it (tools/
## capture_look_tour.gd, the opening world, 2026-10-08): the scene look
## (scripts/scene_look.gd) a world is made with, its sky, ambient and
## exposure. Without it the celestial rig runs on the bare defaults, whose
## sky is a quarter as bright and reads as a dusky purple at noon (the
## ancient gallery's), which misjudges every colour under it. The sky's
## cloud deck as the game has it then: cover CLOUD, foot and depth DECK (m).
const GAME_LOOK := {"version":1,"palette":"Custom","colors":{"grass":[0.3647,0.6196,0.3255],"foliage":[0.2784,0.4627,0.2902],
	"rock":[0.5529,0.5216,0.4667],"earth":[0.4157,0.3137,0.2431],"water":[0.2235,0.4902,0.4745],"sun":[0.9804,0.8392,0.6863],
	"ambient":[0.5608,0.7020,0.8510],"bounce":[0.2902,0.3216,0.2510],"rim":[0.4980,0.6588,0.7882],"fog":[0.8627,0.8863,0.8745],
	"sky":[0.4784,0.6,0.8],"horizon":[0.7529,0.7922,0.7961],"glow":[0.9529,0.7843,0.6667]},
	"settings":{"strength":0.7416,"sun_energy":1.041,"ambient_energy":1.3539,"exposure":1.0896}}
const CLOUD := 0.14
const DECK := Vector2(20.0,12.0)
## The plate: faceted grass, CELL m triangles, MARGIN round the pieces, its
## rock sides DEPTH deep.
const GRASS := [Color("5a7540"),Color("57723d"),Color("5d7842"),Color("55703c")]
const ROCK := Color("4d4640")
const CELL := 1.6
const MARGIN := 3.5
const DEPTH := 4.0
## How far round from the light the layout is turned (radians): the sun over
## the viewer's left shoulder, the fronts lit at a slant so their sides read.
const SIDE := 0.55
const SHOWS := ["pairs","intact","weathered"]
const KEYS := [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL,KEY_BACKSLASH]

## What the look pass reads off the scene it dresses (scripts/look_pass.gd).
var _environment: Environment
var _lighting: LandscapeLighting
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _motion_time := 0.0

var _seed := 1
var _show := 0
var _night := false
var _frame := -1
var _slots: Array[Dictionary] = []
var _layout: Node3D
var _camera: Camera3D
var _celestial: RefCounted
var _look: Node
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.42
var _distance := 60.0
var _distance_goal := 60.0
var _label: Label
var _capture := ""
var _pilots: Array[Node3D] = []
var _sun: DirectionalLight3D
var _layout_yaw := 0.0
var _bounds := Rect2()

func _ready() -> void:
	var start_piece := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--piece="): start_piece = int(arg.get_slice("=",1))-1
		elif arg == "--night": _night = true
		elif arg.begins_with("--show="): _show = maxi(0,SHOWS.find(arg.get_slice("=",1)))
		elif arg.begins_with("--seed="): _seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
	_build_world()
	_set_night(_night)
	_build_layout()
	_frame_piece(start_piece)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="): _yaw = float(arg.get_slice("=",1))
		elif arg.begins_with("--pitch="): _pitch = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="): _distance_goal = float(arg.get_slice("=",1))
	_distance = _distance_goal
	_focus = _focus_goal
	if not _capture.is_empty():
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture)
		get_tree().quit()

func _build_world() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 120.0
	_sun = _lighting.lights[0]
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.cloud = CLOUD
	_celestial.look.restore(GAME_LOOK)
	# As the game does when its look changes (studies/fidelity.gd
	# `_update_scene_look`): the exposure follows the look's.
	var exposure: float = float(source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)
	_look = LookPass.new()
	_look.setup(self)
	_look.apply_tier(_look.tier)
	preload("res://scripts/render_resolution.gd").attach(get_viewport())
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.1
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0,18.0)
	_label.add_theme_font_size_override("font_size",20)
	_label.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.85))
	_label.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.4))
	layer.add_child(_label)
	var help := Label.new()
	help.text = "Drag orbit · Wheel zoom · 1-9 0 - = \\ frame a piece · ←/→ next · Space/Tab whole layout · W intact/weathered · R reseed · N night"
	help.add_theme_font_size_override("font_size",15)
	help.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.5))
	help.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.3))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24.0,-34.0)
	layer.add_child(help)

## The layout: every pair in its row, the labels, the plate under them all,
## the scale figures.
func _build_layout() -> void:
	if _layout != null: _layout.free()
	_layout = Node3D.new()
	_layout.name = "Layout"
	_layout.rotation.y = _layout_yaw
	add_child(_layout)
	_slots.clear()
	_pilots.clear()
	var index := {}
	for i in range(RuinKit.PIECES.size()): index[RuinKit.PIECES[i]] = i
	var bounds := Rect2()
	var first := true
	for r in range(ROWS.size()):
		var row: Array = ROWS[r]
		var built: Array = []
		var width := 0.0
		for id: String in row:
			var pair: Array = []
			var spans: Array = []
			for k in range(2):
				var node := _piece(id,int(index[id]),float(k))
				var box := _extent(node)
				pair.append(node)
				spans.append(box)
			var slot_w: float = spans[0].size.x+spans[1].size.x+PAIR_GAP
			built.append([id,pair,spans,slot_w])
			width += slot_w
		width += SLOT_GAP*(row.size()-1)
		var x := -width*0.5
		for entry: Array in built:
			var id: String = entry[0]
			var pair: Array = entry[1]
			var spans: Array = entry[2]
			var slot := {"id":id,"index":int(index[id]),"pieces":pair,"x":x+float(entry[3])*0.5,"z":float(ROW_Z[r]),"width":float(entry[3]),"spans":spans,"homes":[]}
			var at := x
			for k in range(2):
				var node: Node3D = pair[k]
				var box: AABB = spans[k]
				var home := Vector3(at-box.position.x,0.0,float(ROW_Z[r]))
				node.position = home
				slot.homes.append(home)
				_layout.add_child(node)
				var foot := Rect2(Vector2(home.x+box.position.x,home.z+box.position.z),Vector2(box.size.x,box.size.z))
				bounds = foot if first else bounds.merge(foot)
				first = false
				_tag("intact" if k == 0 else "weathered",Vector3(home.x,0.02,home.z+box.end.z+0.5),0.5)
				at += box.size.x+PAIR_GAP
			var front := maxf((spans[0] as AABB).end.z,(spans[1] as AABB).end.z)
			_tag("%d  %s" % [int(index[id])+1,RuinKit.NAMES[id]],Vector3(slot.x,0.02,float(ROW_Z[r])+front+1.2),1.0)
			_slots.append(slot)
			x += float(entry[3])+SLOT_GAP
	_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	_bounds = bounds.grow(MARGIN)
	_plate(_bounds)
	_figures()
	_apply_show()

## A piece as the gallery shows it.
func _piece(id: String, index: int, weathered: float) -> Node3D:
	var seed_value := _seed*101+index
	if id == "glyph_stone": return RuinKit.glyph_stone(seed_value,weathered,RuinKit.GLYPHS[(_seed+int(weathered)*3)%RuinKit.GLYPHS.size()])
	return RuinKit.piece(id,seed_value,weathered)

## A piece's extent, its rubble's far strays left out (the stone near its
## middle).
func _extent(node: Node3D) -> AABB:
	var mesh := (node.get_node("Mesh") as MeshInstance3D).mesh
	var box := mesh.get_aabb()
	var shape_box := AABB()
	var first := true
	for holder in node.get_node("Body").get_children():
		var shape := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
		for p in shape.points:
			if first:
				shape_box = AABB(p,Vector3.ZERO)
				first = false
			else: shape_box = shape_box.expand(p)
	if first: return box
	# The body without far rubble: the hulls' box, which the scatter (not
	# solid) never widens.
	return shape_box.grow(0.3)

func _tag(text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.007*size
	label.position = at+Vector3(0.0,0.3*size,0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.modulate = Color(1.0,0.97,0.88,0.85 if size >= 1.0 else 0.6)
	label.outline_size = 12
	label.outline_modulate = Color(0.08,0.1,0.06,0.45)
	_layout.add_child(label)

## The plate: faceted grass a touch uneven, triangle by triangle, under the
## pieces; dark rock sides hanging under it, so it floats as an islet does.
func _plate(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var nx := int(ceil(rect.size.x/CELL))
	var nz := int(ceil(rect.size.y/CELL))
	var heights := {}
	for i in range(nx+1):
		for j in range(nz+1):
			var edge := i == 0 or j == 0 or i == nx or j == nz
			heights[Vector2i(i,j)] = -0.12 if edge else rng.randf_range(-0.07,-0.015)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var at := func(i: int, j: int) -> Vector3:
		return Vector3(rect.position.x+i*rect.size.x/nx,heights[Vector2i(i,j)],rect.position.y+j*rect.size.y/nz)
	# Each triangle wound to face `toward` (front faces are clockwise).
	var add := func(t: Array, colour: Color, toward: Vector3) -> void:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		if (p1-p0).cross(p2-p0).dot(toward) > 0.0:
			var swap := p1
			p1 = p2
			p2 = swap
		var normal := (p2-p0).cross(p1-p0).normalized()
		for p: Vector3 in [p0,p1,p2]:
			v.append(p)
			n.append(normal)
			c.append(colour.srgb_to_linear())
	for i in range(nx):
		for j in range(nz):
			var a: Vector3 = at.call(i,j)
			var b: Vector3 = at.call(i+1,j)
			var d: Vector3 = at.call(i,j+1)
			var e: Vector3 = at.call(i+1,j+1)
			for t: Array in [[a,b,d],[b,e,d]]:
				var tone: Color = GRASS[rng.randi()%GRASS.size()]*rng.randf_range(0.92,1.06)
				add.call(t,tone,Vector3.UP)
	# The sides: the rim's points dropped, jagged, toward a keel.
	var rim: Array[Vector3] = []
	for i in range(nx): rim.append(at.call(i,0))
	for j in range(nz): rim.append(at.call(nx,j))
	for i in range(nx,0,-1): rim.append(at.call(i,nz))
	for j in range(nz,0,-1): rim.append(at.call(0,j))
	var centre := Vector3(rect.get_center().x,0.0,rect.get_center().y)
	var keel := Vector3(centre.x,-DEPTH*3.0,centre.z)
	var drops: Array[Vector3] = []
	for p: Vector3 in rim: drops.append(p.lerp(Vector3(centre.x,0.0,centre.z),rng.randf_range(0.06,0.16))+Vector3(0.0,-DEPTH*rng.randf_range(0.7,1.3),0.0))
	for k in range(rim.size()):
		var k1 := (k+1)%rim.size()
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[k1]
		var q0: Vector3 = drops[k]
		var q1: Vector3 = drops[k1]
		var tone := ROCK*rng.randf_range(0.85,1.12)
		var out := ((p0+p1)*0.5-centre)*Vector3(1.0,0.0,1.0)
		add.call([p0,q0,p1],tone,out)
		add.call([p1,q0,q1],tone*0.95,out)
		add.call([q0,keel,q1],tone*0.8,out+Vector3.DOWN*out.length())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = mesh
	plate.material_override = RuinKit.materials().stone
	_layout.add_child(plate)

## The pilot by the pier, on the wall's head, at the stair's foot, on the
## buttress's first set-off and in the weathered window's sill; the plane
## in the pointed arch.
func _figures() -> void:
	var slot := func(id: String) -> Dictionary:
		for s in _slots:
			if s.id == id: return s
		return {}
	var pier: Dictionary = slot.call("pier")
	_pilot(pier,0,Vector3(0.95,RuinKit.SUB_BASE.x,0.45),0.4)
	var wall: Dictionary = slot.call("wall")
	_pilot(wall,0,Vector3(0.9,RuinKit.WALL_HEIGHT,0.0),-0.3)
	var stairs: Dictionary = slot.call("stairs")
	_pilot(stairs,0,Vector3(0.3,0.0,3.2),0.2)
	var buttress: Dictionary = slot.call("buttress")
	_pilot(buttress,0,Vector3(1.9,RuinKit.SET_OFF,0.0),0.0)
	var window: Dictionary = slot.call("lancet_wall")
	_pilot(window,1,Vector3(-0.6,RuinKit.WINDOW.y,0.15),0.5)
	var arch: Dictionary = slot.call("arch")
	var plane := PlaneFigure.new()
	plane.name = "Plane"
	(arch.pieces[0] as Node3D).add_child(plane)
	plane.position = Vector3(0.0,2.6,0.6)
	plane.rotation = Vector3(0.0,0.35,-0.1)
	plane.show_pilot(true)
	plane._mark.visible = false
	plane._vapour.visible = false

func _pilot(slot: Dictionary, k: int, at: Vector3, turn: float) -> void:
	var pilot := PilotFigure.new()
	(slot.pieces[k] as Node3D).add_child(pilot)
	pilot.position = at
	pilot.rotation.y = turn
	pilot.settle()
	_pilots.append(pilot)

## Which of each pair shows (W): both, or one alone standing in its pair's
## middle.
func _apply_show() -> void:
	for slot in _slots:
		for k in range(2):
			var node: Node3D = slot.pieces[k]
			var shown: bool = _show == 0 or _show-1 == k
			# Framing one piece, the rows in front of it stand aside.
			if _frame >= 0 and float(slot.z) > float(_slots[_frame].z)+0.5: shown = false
			node.visible = shown
			node.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
			var home: Vector3 = slot.homes[k]
			if _show != 0:
				var box: AABB = slot.spans[k]
				home.x = float(slot.x)-box.position.x-box.size.x*0.5
			node.position = home
	_say()

func _frame_piece(index: int) -> void:
	_frame = index
	if index < 0 or index >= _slots.size():
		_frame = -1
		_focus_goal = Vector3(_bounds.get_center().x,2.2,_bounds.get_center().y+1.5)
		_distance_goal = maxf(_bounds.size.x,_bounds.size.y*1.4)*0.9
		_pitch = 0.5
		_yaw = 0.0
	else:
		var slot := _slots[index]
		var spans: Array = slot.spans
		var tall := maxf((spans[0] as AABB).size.y,(spans[1] as AABB).size.y)
		var across: float = slot.width if _show == 0 else (spans[_show-1] as AABB).size.x
		_focus_goal = Vector3(slot.x,minf(tall*0.42,4.0),slot.z)
		_distance_goal = maxf(across*1.25,tall*1.9)+3.0
		_pitch = 0.3
		_yaw = 0.0
	if not _slots.is_empty(): _apply_show()

func _say() -> void:
	if _label == null: return
	var what := "The gothic ruin kit" if _frame < 0 else "%d · %s" % [_frame+1,RuinKit.NAMES[_slots[_frame].id]]
	_label.text = "%s   ·   %s   ·   %s   ·   seed %d" % [what,SHOWS[_show],"night" if _night else "day",_seed]

func _set_night(on: bool) -> void:
	_night = on
	_celestial.set_phase(NIGHT if on else DAY)
	_face_sun()
	RuinKit.set_night(1.0 if on else 0.0)
	_say()

## Turns the layout so the sun (by night the moon) comes from over the
## viewer's left shoulder onto the pieces' fronts (+Z); the camera orbits in
## the layout's frame.
func _face_sun() -> void:
	var toward: Vector3 = _sun.global_basis.z
	var flat := Vector2(toward.x,toward.z)
	if flat.length() < 0.01: return
	_layout_yaw = atan2(flat.x,flat.y)-SIDE
	if _layout != null: _layout.rotation.y = _layout_yaw

func _process(delta: float) -> void:
	_motion_time += delta
	_celestial.advance(delta,true)
	for pilot in _pilots:
		if pilot.is_visible_in_tree(): pilot._advance(delta)
	var ease := minf(1.0,delta*4.0)
	_focus = _focus.lerp(_focus_goal,ease)
	_distance = lerpf(_distance,_distance_goal,ease)
	var frame := Transform3D(Basis(Vector3.UP,_layout_yaw),Vector3.ZERO)
	_camera.position = frame*(_focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance)
	_camera.look_at(frame*_focus)
	RenderingServer.global_shader_parameter_set("zs_camera_position",_camera.global_position)
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	_look.update(_camera,_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,DECK.x,DECK.y))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.006
		_pitch = clampf(_pitch+event.relative.y*0.005,-0.1,1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance_goal = maxf(3.0,_distance_goal*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance_goal = minf(250.0,_distance_goal*1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in KEYS:
			_frame_piece(KEYS.find(event.keycode))
			return
		match event.keycode:
			KEY_RIGHT: _frame_piece((_frame+1)%_slots.size())
			KEY_LEFT: _frame_piece((_frame+_slots.size()-1)%_slots.size() if _frame >= 0 else _slots.size()-1)
			KEY_SPACE, KEY_TAB: _frame_piece(-1)
			KEY_R:
				_seed += 1
				_build_layout()
				_frame_piece(_frame)
			KEY_W:
				_show = (_show+1)%SHOWS.size()
				_apply_show()
				_frame_piece(_frame)
			KEY_N: _set_night(not _night)
