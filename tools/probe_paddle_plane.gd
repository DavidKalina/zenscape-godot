extends SceneTree
## Headless probe of the Paddle's Plane (scripts/clay_tools/paddle.gd) on the
## real cozy worlds scene, driven by synthesized input through hand_reach.
## A Mountain pulls a peak and lays its rock, the Brush paints rock over the
## summit too; then the Plane, drawn across the peak from one flank to the
## other, must: fan out as the paddle's first mode with four surface swatches
## and no picker, grass in hand; bring the ground along the stroke to the
## press's height and leave the ground past its rim alone; replace the rock
## paint with grass at full weight, cover up and hand-made; take one undo
## step that one undo takes back exactly (heights, tint, cover, meadow,
## blades, provenance). A second Plane with the sand swatch lays the
## palette's sand and leaves the cells bare.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_paddle_plane.gd -- --modeless --no-title
const Paddle = preload("res://scripts/clay_tools/paddle.gd")
const Brush = preload("res://scripts/clay_tools/brush.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var failures := []

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
	var c := Vector2i(((p+Vector2.ONE*14.0)/NativeTerrainData.MEADOW_STEP).floor())
	return c.y*NativeTerrainData.MEADOW_CELLS+c.x

func tint_color(cell: int) -> Color:
	return NativeTerrainTint.color_at(editor.data.tint,cell)

func weight(cell: int) -> float:
	return NativeTerrainTint.weight_at(editor.data.tint,cell)

func near_color(a: Color, b: Color) -> bool:
	return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length() < 0.02

## A drag through the screen points of plate points `line`. Returns the path
## the clay laid, read off it as it goes (the press, then the path's end each
## frame, and the dabs' quarter points between): a peak's arête can stand in
## front of the line and take a pick toward the camera, so the line itself is
## only roughly the path.
func drag_along(line: Array) -> Array:
	var points: Array = line.map(func(p: Vector2) -> Vector2: return screen(p))
	button(points[0],true)
	await frames(2)
	var path: Array = [clay.center]
	for k in range(1,points.size()+10):
		if k < points.size(): motion(points[k],points[k]-points[k-1])
		await frames(1)
		if clay.last_plate == null or clay.last_plate == path[-1]: continue
		var from: Vector2 = path[-1]
		for j in range(1,5): path.append(from.lerp(clay.last_plate,j/4.0))
	button(points[-1],false)
	await settled()
	return path

func snapshot() -> Dictionary:
	var data := editor.data
	return {"heights":data.heights.duplicate(),"tint":data.tint.duplicate(),"grass":data.grass.duplicate(),"meadow":data.meadow.duplicate(),"blades":data.blades.duplicate(),"provenance":data.provenance.duplicate()}

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("plane probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-plane-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
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
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-140,0)) and bare(s+Vector2(140,0)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	at = plate(screen(at))
	var cell := cell_of(at)
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame

	# The stroke's line: across `at`, at right angles to the view, so no point
	# on it hides behind the peak.
	var right3: Vector3 = editor.terrain.global_basis.inverse()*scene.camera.global_basis.x
	var right := Vector2(right3.x,right3.z).normalized()
	var line: Array = []
	for k in range(41): line.append(at+right*lerpf(-5.0,5.0,k/40.0))

	# --- A rocky peak: the Mountain's pull, the Brush's rock over its summit ---
	materials.select_tool("mountain")
	await frames(10)
	var spot := screen(at)
	var foot := height(at)
	button(spot,true)
	await frames(2)
	for k in range(14):
		motion(spot-Vector2(0,6*(k+1)),Vector2(0,-6))
		await frames(1)
	button(spot-Vector2(0,84),false)
	await settled()
	materials.select_tool("brush")
	await frames(10)
	materials.set_mode("rock")
	await drag_along(line)
	var palette: NativeTerrainPalette = data._palette
	var rock: Color = palette.rock[0 if palette.patch(at) > 0.5 else 1]
	print("PEAK ",JSON.stringify({"rise":snappedf(height(at)-foot,0.01),"weight":snappedf(weight(cell),0.01),"grass":snappedf(data.grass[cell],0.01)}))
	check("the peak stands up",height(at)-foot > 1.5,height(at)-foot)
	check("its summit is painted rock",weight(cell) > 0.9 and near_color(tint_color(cell),rock) and data.grass[cell] < 0.15,[weight(cell),tint_color(cell),rock,data.grass[cell]])

	# --- The paddle's fan: the Plane, its swatches ---
	materials.select_tool("paddle")
	await frames(30)
	check("the paddle fans out the plane",roll.modes == ["plane","pat"],roll.modes)
	materials.set_mode("plane")
	await frames(30)
	check("the plane shows four surface swatches and no picker",roll.swatches == Paddle.SURFACE_SWATCHES and not roll.picker,[roll.swatches.size(),roll.picker])
	check("the swatch past the last is not a cell",roll.swatch_at(roll._swatch_cell(roll.swatches.size()).get_center()) == -1)
	check("grass is in hand",clay.tool.surface() == "grass" and roll.colour.is_equal_approx(Paddle.SURFACE_SWATCHES[0]),[clay.tool.surface(),roll.colour])

	# --- Plane across the peak, flank to flank ---
	var before := snapshot()
	var undo0: int = data._undo.size()
	var path: Array = await drag_along(line)
	var level := float(data.sample(path[0],before.heights))
	var worst_before := 0.0
	var worst := 0.0
	var mean := 0.0
	for p: Vector2 in path:
		worst_before = maxf(worst_before,absf(float(data.sample(p,before.heights))-level))
		worst = maxf(worst,absf(height(p)-level))
		mean += absf(height(p)-level)/path.size()
	var crossing := INF
	for p: Vector2 in path: crossing = minf(crossing,p.distance_to(at))
	check("the path crosses the summit's cell in the blade's core",crossing < Paddle.PLANE_RADIUS*Paddle.PLANE_CORE*clay.size_scale-0.4,crossing)
	var grass_colour: Color = Brush.surface_colour("grass",palette,data.meadow_position(cell%NativeTerrainData.MEADOW_CELLS,cell/NativeTerrainData.MEADOW_CELLS)+Vector2.ONE*NativeTerrainData.MEADOW_STEP*0.5)
	print("PLANE ",JSON.stringify({"level":snappedf(level,0.01),"tool_level":snappedf(clay.tool._level,0.01),"off_line_before":snappedf(worst_before,0.01),"off_line_after":snappedf(worst,0.001),"mean_off":snappedf(mean,0.001),"weight":snappedf(weight(cell),0.001),"laid":tint_color(cell).to_html(false),"grass_colour":grass_colour.to_html(false),"grass":snappedf(data.grass[cell],0.01),"provenance":data.provenance[cell]}))
	check("the level is the press's ground",absf(clay.tool._level-level) < 0.05,[clay.tool._level,level])
	check("the stroke's ground converges to it",worst_before > 1.0 and worst < 0.1 and mean < 0.03,[worst_before,worst,mean])
	# The shoulder and the ground past the rim, out from the summit across
	# the path, measured from the path as it was laid.
	var radius: float = Paddle.PLANE_RADIUS*clay.size_scale
	var across: Vector2 = right.orthogonal()
	var shoulder := Vector2.INF
	var off := Vector2.INF
	for k in range(1,240):
		var p: Vector2 = at+across*k*0.05
		var gap := INF
		for q: Vector2 in path: gap = minf(gap,p.distance_to(q))
		if shoulder == Vector2.INF and gap >= radius*0.75: shoulder = p
		if gap >= radius+0.3:
			off = p
			break
	var shoulder_before := float(data.sample(shoulder,before.heights))
	var eased := (shoulder_before-height(shoulder))/(shoulder_before-level)
	check("the shoulder is eased partway to it, not cut",eased > 0.05 and eased < 0.98,[shoulder_before,height(shoulder),eased])
	check("ground past the rim is left alone",off != Vector2.INF and absf(height(off)-float(data.sample(off,before.heights))) < 0.001,[off,height(off)])
	check("the rock paint is gone, grass laid at full weight",weight(cell) > 0.999 and near_color(tint_color(cell),grass_colour),[weight(cell),tint_color(cell),grass_colour])
	check("the grass cover is up",data.grass[cell] > 0.99,data.grass[cell])
	check("the cells are hand-made",data.provenance[cell] == NativeTerrainData.SOURCE_HAND)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	var after := snapshot()
	var restored: Array = []
	for field: String in before:
		if after[field] != before[field]: restored.append(field)
	check("one undo restores everything",restored.is_empty() and data._undo.size() == undo0,restored)

	# --- Sand: the swatch strip's last, laid bare ---
	await click(roll._swatch_cell(3).get_center())
	check("clicking the sand swatch takes it",clay.tool.surface() == "sand",clay.tool.surface())
	data.meadow[cell] = 1.0
	data.blades[cell] = 1.0
	await drag_along(line)
	print("SAND ",JSON.stringify({"weight":snappedf(weight(cell),0.001),"laid":tint_color(cell).to_html(false),"sand":palette.sand.to_html(false),"grass":data.grass[cell],"meadow":data.meadow[cell],"blades":data.blades[cell]}))
	check("sand is laid at full weight",weight(cell) > 0.999 and near_color(tint_color(cell),palette.sand),[weight(cell),tint_color(cell),palette.sand])
	check("and leaves the cells bare",data.grass[cell] == 0.0 and data.meadow[cell] == 0.0 and data.blades[cell] == 0.0,[data.grass[cell],data.meadow[cell],data.blades[cell]])
	editor.undo()
	await settled()
	print("PADDLE PLANE PROBE ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
