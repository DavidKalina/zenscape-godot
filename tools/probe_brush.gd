extends SceneTree
## Headless probe of the Brush (scripts/clay_tools/brush.gd) on the real cozy
## worlds scene, driven by synthesized input through hand_reach. Checks: the
## Brush has a pocket and fans out grass/rock/earth/wipe; a Rock drag lays the
## world's rock into the tint, clears the grass cover and the meadow, moves
## no ground and recolours the mesh; Grass over it turns it green; Shift
## wipes it back off; Q and E step the modes; each stroke is one undo step
## that takes the tint back exactly.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_brush.gd -- --modeless --no-title
const Brush = preload("res://scripts/clay_tools/brush.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var hand: Node
var failures := []
var worked: Array = []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at)

func cell_of(p: Vector2) -> int:
	var data := editor.data
	var step := NativeTerrainData.MEADOW_STEP
	var c := Vector2i(((p+Vector2.ONE*14.0)/step).floor())
	return c.y*NativeTerrainData.MEADOW_CELLS+c.x

func tint_color(cell: int) -> Color:
	return NativeTerrainTint.color_at(editor.data.tint,cell)

func weight(cell: int) -> float:
	return NativeTerrainTint.weight_at(editor.data.tint,cell)

## The mesh's colour at the vertex nearest plate point `p`.
func mesh_color(p: Vector2) -> Color:
	var arrays: Array = editor.terrain.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var best := 0
	var best_d := INF
	for i in range(vertices.size()):
		var d := Vector2(vertices[i].x,vertices[i].z).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return colors[best]

func stroke(spot: Vector2) -> void:
	var from := spot+Vector2(-120,0)
	button(from,true)
	await frames(2)
	for k in range(24):
		motion(from+Vector2(10*(k+1),0),Vector2(10,0))
		await frames(1)
	await frames(10)
	button(from+Vector2(240,0),false)
	await settled()

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("brush probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-brush-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	hand = scene.get("god_hand")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay and the materials tray exist",clay != null and materials != null)
	if clay == null or materials == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	var roll: Control = materials.roll
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-140,0)) and bare(s+Vector2(140,0)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	at = plate(spot)
	var cell := cell_of(at)
	print("spot ",at," on screen ",spot)
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("brush")).get_center()
	check("the brush has a pocket",roll.tool_at(pocket) == "brush",roll.tool_at(pocket))
	await click(pocket)
	await frames(30)
	check("pressing it takes the brush and fans its modes",clay.tool_id == "brush" and roll.modes == ["grass","rock","earth","colour","wipe"] and roll.mode == "grass",[clay.tool_id,roll.modes,roll.mode])
	await key(KEY_E)
	check("E steps to rock",roll.mode == "rock" and clay.tool.mode == "rock",[roll.mode,clay.tool.mode])

	# --- Rock: the world's rock into the tint, cover gone, ground unmoved ---
	var undo0: int = data._undo.size()
	var heights0 := data.heights.duplicate()
	var tint0 := data.tint.duplicate()
	var meadow0 := data.meadow.duplicate()
	var mesh0 := Color()
	data.meadow[cell] = 1.0
	editor.force_refresh()
	await settled()
	mesh0 = mesh_color(at)
	await stroke(spot)
	var rock: Color = data._palette.rock[0 if data._palette.patch(at) > 0.5 else 1]
	var laid := tint_color(cell)
	print("ROCK ",JSON.stringify({"weight":snappedf(weight(cell),0.01),"laid":laid.to_html(false),"rock":rock.to_html(false),"grass":snappedf(data.grass[cell],0.01),"mesh_before":mesh0.to_html(false),"mesh_after":mesh_color(at).to_html(false)}))
	check("a rock stroke lays rock at full weight",weight(cell) > 0.9 and Vector3(laid.r-rock.r,laid.g-rock.g,laid.b-rock.b).length() < 0.02,[weight(cell),laid,rock])
	check("and clears the grass cover and the meadow",data.grass[cell] < 0.15 and data.meadow[cell] == 0.0,[data.grass[cell],data.meadow[cell]])
	check("it moves no ground",data.heights == heights0)
	check("the mesh shows it",not mesh_color(at).is_equal_approx(mesh0),[mesh0,mesh_color(at)])
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)

	# --- Grass over it ---
	materials.set_mode("grass")
	await stroke(spot)
	var green := tint_color(cell)
	check("grass over rock turns it green",green.g > green.r and green.g > green.b and data.grass[cell] > 0.9,[green,data.grass[cell]])

	# --- Shift wipes ---
	shift(true)
	await stroke(spot)
	await stroke(spot)
	shift(false)
	check("shift wipes the paint off",weight(cell) < 0.05,weight(cell))
	check("three more undo steps",data._undo.size() == undo0+4,data._undo.size()-undo0)

	# --- Colour: the swatch strip, a swatch laid, the full picker ---
	materials.set_mode("colour")
	await frames(30)
	check("the colour mode shows the swatch strip",roll.swatches.size() == Brush.SWATCHES.size(),roll.swatches.size())
	var swatch_cell: Vector2 = roll._swatch_cell(2).get_center()
	check("a swatch is under the pointer",roll.swatch_at(swatch_cell) == 2,roll.swatch_at(swatch_cell))
	await click(swatch_cell)
	check("clicking it takes its colour",clay.tool.colour.is_equal_approx(Brush.SWATCHES[2]) and roll.colour.is_equal_approx(Brush.SWATCHES[2]),clay.tool.colour)
	var grass_before: float = data.grass[cell]
	await stroke(spot)
	var own: Color = Brush.SWATCHES[2].srgb_to_linear()
	var painted := tint_color(cell)
	check("a colour stroke lays it",weight(cell) > 0.9 and Vector3(painted.r-own.r,painted.g-own.g,painted.b-own.b).length() < 0.02,[weight(cell),painted,own])
	check("and leaves the grass cover",is_equal_approx(data.grass[cell],grass_before),[grass_before,data.grass[cell]])
	await click(roll._swatch_cell(roll.swatches.size()).get_center())
	await frames(5)
	check("the strip's last cell opens the full picker",roll.picker_open())
	roll._picker_popup.hide()
	materials.set_mode("grass")
	await frames(5)
	check("another mode hides the strip",roll.swatches.is_empty())
	for k in range(5):
		editor.undo()
		await settled()
	check("undo takes the tint back exactly",data.tint == tint0 and data._undo.size() == undo0,data._undo.size()-undo0)
	data.meadow = meadow0
	print("BRUSH PROBE ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
