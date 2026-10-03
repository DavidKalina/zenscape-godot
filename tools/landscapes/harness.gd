extends SceneTree
## Landscape builds (2026-09-30): a player's build of one landscape, scripted
## through the real tools. Each build is a script in tools/landscapes/ that
## extends this one and overrides `build()`. It takes tools and materials from
## the HUD by clicking them, and works the land with the same mouse gestures a
## player makes (tap, drag, hold-then-drag, Shift, the size pips), sent through
## Input as window-pixel events, as tools/film_everything.gd does. Then the
## world gets time to answer (water runs, life arrives), and the build saves
## stills from named views plus a report of what it measured.
##
## Run one with tools/landscapes/run.sh <name> (it takes the GPU lock and
## guards the run). By hand:
##   Godot --windowed --path . --resolution 1280x720 \
##     -s res://tools/landscapes/<name>.gd -- --modeless --no-title
## Output goes to /private/tmp/zs-landscapes/<name>/: NN-<view>.png and
## report.txt. Headless it still builds and reports, but saves no stills.
##
## Positions are plate metres (x, z), the plate running about -13.7..13.7 on
## each side; (0,0) is the middle. Pixels are viewport pixels (1280x720).

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var clay: Node
var materials: Node
var hand: Node3D
var pointer := Vector2(640,360)
var dot := Control.new()
var out_dir := ""
var report_lines: PackedStringArray = []
var shot := 0
var started_usec := 0
## Extra water sim steps a frame while waiting; water runs LAPSE+1 times as fast.
var lapse := 0
## Verbs the clay reported, in order: [verb, kept].
var worked: Array = []

## The build's name (its output folder). Override.
func title() -> String: return "untitled"
## The steps of the build. Override.
func build() -> void: pass
## Seconds the whole run may take before it gives up.
func budget() -> float: return 420.0


func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	Input.use_accumulated_input = false
	create_timer(budget(),true,false,true).timeout.connect(func() -> void:
		log_line("TIMED OUT after %.0f s" % budget())
		_write_report()
		quit(2))
	root.size = Vector2i(1280,720)
	out_dir = "/private/tmp/zs-landscapes/%s" % title()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.get_extension() == "png" or f == "report.txt": DirAccess.remove_absolute(out_dir.path_join(f))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-landscape-%s-%d/places.json" % [title(),Time.get_ticks_usec()]
	root.add_child(scene)
	current_scene = scene
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.draw.connect(func() -> void:
		dot.draw_circle(pointer,6.0,Color(1,1,1,0.9))
		dot.draw_arc(pointer,6.0,0.0,TAU,24,Color(0,0,0,0.6),1.5))
	layer.add_child(dot)
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	reach = scene.hand_reach
	editor = scene._chunk_editor
	clay = scene.get("land_clay")
	hand = scene.get("god_hand") as Node3D
	materials = reach.get("materials")
	if clay == null or materials == null:
		log_line("FAIL: no land clay or materials tray (run with -- --modeless --no-title)")
		_write_report()
		quit(1)
		return
	clay.worked.connect(func(verb: String, kept: bool) -> void: worked.append([verb,kept]))
	scene.world_clock.running = false
	scene._celestial.set_phase(0.32)
	scene._overview()
	for i in range(180):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	await seconds(1.0)
	log_line("start: plate points %d, ground %s, flow %s" % [editor.data.points.size(),_height_range(),editor.flow != null and editor.flow.ready])
	await build()
	log_line("done in %.0f s" % ((Time.get_ticks_usec()-started_usec)/1e6))
	_write_report()
	quit(0)


# --- Time ---

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor != null and editor.flow != null: editor.flow.run(lapse)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

## Let the world answer: water runs `water_speed` times as fast, and time (life
## arriving) `life_speed` times, for `secs` seconds of the run.
func let_world_run(secs: float, water_speed := 4, life_speed := 4.0) -> void:
	lapse = maxi(0,water_speed-1)
	Engine.time_scale = life_speed
	await seconds(secs)
	Engine.time_scale = 1.0
	lapse = 0

func settle() -> void:
	var quiet := 0
	var waited := 0
	while quiet < 20 and waited < 600:
		await frames(1)
		waited += 1
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1


# --- Input (viewport pixels in, window pixels out: 2x on a Retina window) ---

func window(at: Vector2) -> Vector2:
	return root.get_final_transform()*at

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = window(at)
	event.global_position = window(at)
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shift(pressed: bool) -> void:
	key(KEY_SHIFT,pressed)

func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = window(at)
	event.global_position = window(at)
	event.relative = window(at)-window(pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer = at
	reach.pointer_override = at
	editor.pointer_override = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	dot.queue_redraw()

func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),held)
		await frames(1)

func click_screen(at: Vector2) -> void:
	await glide(at,20)
	button(at,true)
	await frames(3)
	button(at,false)
	await frames(3)


# --- The plate ---

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

## The screen point over plate point `p`.
func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

## Metres up the screen per pixel, standing at plate point `p` (for holds).
func metres_per_pixel(p: Vector2) -> float:
	var a := editor.terrain.to_global(Vector3(p.x,height(p),p.y))
	var b := a+Vector3.UP
	return 1.0/maxf(1.0,absf(scene.camera.unproject_position(a).y-scene.camera.unproject_position(b).y))


# --- The HUD: tools, materials, size ---

## Take a tool from the roll: "hand" (the Modeller), "hills", "mountain",
## "crater", "wire" (the Ravine), "chisel", "paddle", "feather".
func take_tool(id: String) -> void:
	var roll: Control = materials.roll
	# A click on the pocket of the tool already in hand puts it down.
	if roll.tool == id and materials.held.is_empty():
		log_line("take tool %s: already in hand" % id)
		return
	await glide(Vector2(30,360),15)
	for i in range(90):
		if roll.shown > 0.99: break
		await frames(1)
	var pocket: Vector2 = roll._cell(roll.TOOLS.find(id)).get_center()
	await click_screen(pocket)
	var ok: bool = roll.tool == id
	log_line("take tool %s: %s" % [id,"ok" if ok else "FAILED (roll has %s)" % roll.tool])

## Pick a mode on the fan of the tool in hand ("slice", "mesa", "shelf",
## "plane", ...), as Q and E would.
func take_mode(mode: String) -> void:
	materials.set_mode(mode)
	await frames(2)
	var clay: Node = scene.get("land_clay")
	var ok: bool = clay != null and clay.tool.mode == mode
	log_line("take mode %s: %s" % [mode,"ok" if ok else "FAILED"])

## Take a material from the bar: oak, pine, willow, wildflower, dandelion,
## reed, water, stone.
func take_material(id: String) -> void:
	await glide(Vector2(640,700),15)
	for i in range(90):
		if materials.tray.shown > 0.99: break
		await frames(1)
	# The case fans a group out under a resting pointer (scripts/materials_tray.gd).
	materials.tray.pointer_override = materials.tray.compartment_centre(id)
	for i in range(120):
		if materials.tray.showing(id): break
		await frames(1)
	await click_screen(materials.tray.specimen_centre(id))
	materials.tray.pointer_override = null
	var ok: bool = materials.held == id
	log_line("take material %s: %s" % [id,"ok" if ok else "FAILED (holding '%s')" % materials.held])

## Put whatever is in hand down (Esc): back to the bare Modeller.
func put_down() -> void:
	key(KEY_ESCAPE,true)
	await frames(2)
	key(KEY_ESCAPE,false)
	await frames(2)

## The size pips: 1 (0.6x), 2 (1x), 3 (1.5x). Pressed as the keys.
func size(level: int) -> void:
	var code: Key = [KEY_1,KEY_2,KEY_3][clampi(level,1,3)-1]
	var roll: Control = materials.roll
	await glide(Vector2(30,360),15)
	for i in range(90):
		if roll.shown > 0.6: break
		await frames(1)
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)
	log_line("size %d: scale %.1f" % [level,clay.size_scale])


# --- Gestures (plate points in) ---

## A tap at plate point `p`. `press` is how long the button stays down (a
## stone grows with it; past 0.3 s the clay reads a hold).
func tap(p: Vector2, fine := false, press := 0.05) -> void:
	await glide(screen(p),25)
	if fine: shift(true)
	button(pointer,true)
	await seconds(press)
	button(pointer,false)
	if fine: shift(false)
	await frames(4)
	await settle()

## A drag along plate points `path` at `speed` metres a second. The screen
## path is fixed at the press, as a hand's would be.
func drag(path: Array, speed := 3.0, fine := false) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	var verbs_before := worked.size()
	await glide(points[0],25)
	if fine: shift(true)
	button(pointer,true)
	await frames(2)
	# Paced by the game's own clock (frame delta), the clock the clay times
	# holds by: below 60 fps a frame-stepped drag moved too little in the
	# clay's first HOLD_SECONDS and was read as a hold.
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var span := maxf(a.distance_to(b)/speed,1.0/60.0)
		var elapsed := 0.0
		while true:
			var t := minf(1.0,elapsed/span)
			move(points[i].lerp(points[i+1],t),true)
			await frames(1)
			elapsed += root.get_process_delta_time()
			if t >= 1.0: break
	await frames(2)
	var px := 0.0
	for k in range(points.size()-1): px += points[k].distance_to(points[k+1])
	button(pointer,false)
	if fine: shift(false)
	await frames(2)
	await settle()
	log_line("drag %s %.0f px at %.1f m/s -> %s" % [path[0],px,speed,str(worked.back()) if worked.size() > verbs_before else ("material " + materials.held if not materials.held.is_empty() else "no clay verb")])

## Press and hold still at `p` past the hold threshold, then pull the pointer
## `pixels` up the screen (negative) or down (positive), and let go.
func hold_drag(p: Vector2, pixels: float, fine := false, pull_frames := 60) -> void:
	await glide(screen(p),25)
	if fine: shift(true)
	button(pointer,true)
	await seconds(0.45)
	var from := pointer
	var span := pull_frames/60.0
	var elapsed := 0.0
	while true:
		var t := minf(1.0,elapsed/span)
		move(from+Vector2(0,pixels*smoothstep(0.0,1.0,t)),true)
		await frames(1)
		elapsed += root.get_process_delta_time()
		if t >= 1.0: break
	await seconds(0.25)
	button(pointer,false)
	if fine: shift(false)
	await frames(2)
	await settle()

## As hold_drag, but the "player" watches the ground at `p` and lets go once
## it reaches `target` metres (or the pull runs out). Logs where it stopped.
func hold_to(p: Vector2, target: float, fine := false, most_pixels := 400.0) -> void:
	await glide(screen(p),25)
	if fine: shift(true)
	button(pointer,true)
	await seconds(0.45)
	var start := height(p)
	var dir := -1.0 if target > start else 1.0
	var from := pointer
	var moved := 0.0
	while moved < most_pixels:
		moved += 3.0
		move(from+Vector2(0,dir*moved),true)
		await frames(1)
		var h := height(p)
		if (dir < 0 and h >= target) or (dir > 0 and h <= target): break
	await seconds(0.2)
	button(pointer,false)
	if fine: shift(false)
	await frames(2)
	await settle()
	log_line("hold_to %s: %.2f -> %.2f m (wanted %.2f, %d px)" % [p,start,height(p),target,int(moved)])

## The Hills in hand: scrub back and forth across `p`, `reach` metres either
## side, and let go once the ground at `p` stands at `target` (or after
## `most` passes), as a player watching a rolling hill come up. Logs it.
func scrub_to(p: Vector2, target: float, reach := 3.0, most := 24) -> void:
	var start := height(p)
	var ends: Array[Vector2] = [screen(p+Vector2(-reach,0.0)),screen(p+Vector2(reach,0.0))]
	await glide(ends[0],25)
	button(pointer,true)
	await frames(2)
	var passes := 0
	var done := false
	while passes < most and not done:
		var a: Vector2 = ends[passes%2]
		var b: Vector2 = ends[(passes+1)%2]
		var steps := maxi(1,int(reach*2.0/6.0*60.0))
		for k in range(steps):
			move(a.lerp(b,float(k+1)/steps),true)
			await frames(1)
			if height(p) >= target:
				done = true
				break
		passes += 1
	button(pointer,false)
	await frames(2)
	await settle()
	log_line("scrub_to %s: %.2f -> %.2f m (wanted %.2f, %d passes)" % [p,start,height(p),target,passes])

## The Ravine in hand: draw a closed loop of `radius` metres round `p`, so the
## inside sinks to a lake basin (Shift: the shallower one).
func loop(p: Vector2, radius: float, fine := false) -> void:
	var path := []
	for k in range(25): path.append(p+Vector2.from_angle(TAU*k/24.0)*radius)
	var start := height(p)
	# The drag's settle waits out the cut drawing through.
	await drag(path,4.0,fine)
	log_line("loop %s r %.1f: %.2f -> %.2f m" % [p,radius,start,height(p)])

## Water from the bar, held over `p` for `secs` (the ball grows while held),
## then let go. Waits for the ball to land.
func pour(p: Vector2, secs := 2.5) -> void:
	if materials.held != "water": await take_material("water")
	var outcome := {}
	var got := func(o: Dictionary) -> void: outcome.merge(o)
	if editor.has_signal("ball_settled"): editor.ball_settled.connect(got)
	await glide(screen(p),30)
	button(pointer,true)
	await seconds(secs)
	button(pointer,false)
	for i in range(300):
		await frames(1)
		if not outcome.is_empty(): break
	if editor.has_signal("ball_settled"): editor.ball_settled.disconnect(got)
	log_line("pour at %s (%.1f s): %s" % [p,secs,outcome])

## Sow with the material in hand along `path` (seeds flick along a drag;
## flowers, reeds and stones scatter).
func sow(id: String, path: Array, speed := 4.0) -> void:
	if materials.held != id: await take_material(id)
	await drag(path,speed)

## Taps with the material in hand at each point (flowers, reeds, stones).
func set_down(id: String, points: Array, press := 0.05) -> void:
	if materials.held != id: await take_material(id)
	for p: Vector2 in points: await tap(p,false,press)

## A pull on the near rim of `pixels` (down positive), as a hand would.
func rim_pull(pixels: float) -> void:
	var from := _lip_point()
	if from == Vector2.ZERO:
		log_line("rim pull: no rim point found")
		return
	await glide(from,30)
	button(pointer,true)
	await frames(2)
	for i in range(40):
		move(from+Vector2(0.0,pixels*smoothstep(0.0,1.0,float(i+1)/40)),true)
		await frames(1)
	await seconds(0.4)
	button(pointer,false)
	await frames(1)
	await settle()
	log_line("rim pull %d px from %s" % [int(pixels),from])

func _lip_point() -> Vector2:
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var h: Variant = editor.data.ground_height(edge)
			if h == null: continue
			var world := editor.terrain.to_global(Vector3(edge.x,float(h),edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			var tall := root.get_visible_rect().size.y
			if at.y > best.y and at.y < tall*0.58 and at.y > tall*0.46: best = at
	return best


# --- Camera and stills ---

## Move the camera to look at plate point `p` (its ground), from `distance`
## metres, at `yaw` and `polar` (radians; polar ~0.8 high, ~1.3 low).
func view(p: Vector2, distance: float, yaw: float, polar: float, secs := 1.5) -> void:
	var target := editor.terrain.to_global(Vector3(p.x,height(p),p.y))
	var from := [scene.target,scene.distance,scene.yaw,scene.polar]
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = from[0].lerp(target,t)
		scene.distance = lerpf(from[1],distance,t)
		scene.yaw = lerp_angle(from[2],yaw,t)
		scene.polar = lerpf(from[3],polar,t)
		scene._update_camera()
		await frames(1)

## The building view: the scene's own overview.
func overview(secs := 1.0) -> void:
	var was := [scene.target,scene.distance,scene.yaw,scene.polar]
	scene._overview()
	var to := [scene.target,scene.distance,scene.yaw,scene.polar]
	scene.target = was[0]; scene.distance = was[1]; scene.yaw = was[2]; scene.polar = was[3]
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = was[0].lerp(to[0],t)
		scene.distance = lerpf(was[1],to[1],t)
		scene.yaw = lerp_angle(was[2],to[2],t)
		scene.polar = lerpf(was[3],to[3],t)
		scene._update_camera()
		await frames(1)

## Save a clean still (no HUD, no hand, no pointer) as NN-<label>.png.
func still(label: String) -> void:
	# The pointer goes to the sky first, so the tool's prop, its ground mark and
	# any hover label clear the shot.
	var back := pointer
	await glide(Vector2(640,12),12)
	await frames(40)
	var hidden: Array = []
	# The camera rig's hover label and ring draw in the scene's UI, not a layer.
	for item: Variant in [scene.get("_ui"),scene.camera_rig.label if scene.get("camera_rig") != null else null]:
		if item is CanvasItem and item.visible:
			item.visible = false
			hidden.append(item)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false):
		if overlay.visible:
			overlay.visible = false
			hidden.append(overlay)
	var dot_was := dot.visible
	dot.visible = false
	var hand_was := hand.visible if hand != null else false
	if hand != null: hand.visible = false
	await frames(3)
	shot += 1
	var path := out_dir.path_join("%02d-%s.png" % [shot,label])
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(path)
		log_line("still %s" % path.get_file())
	for overlay: Node in hidden: overlay.visible = true
	dot.visible = dot_was
	if hand != null: hand.visible = hand_was
	move(back,false)


# --- Measures ---

func log_line(text: String) -> void:
	var stamped := "[%5.1f s] %s" % [(Time.get_ticks_usec()-started_usec)/1e6,text]
	print("LANDSCAPE ",stamped)
	report_lines.append(stamped)

func _write_report() -> void:
	if out_dir.is_empty(): return
	var file := FileAccess.open(out_dir.path_join("report.txt"),FileAccess.WRITE)
	if file == null: return
	file.store_string("\n".join(report_lines)+"\n")

func _height_range() -> String:
	var lo := INF
	var hi := -INF
	for h in editor.data.heights:
		lo = minf(lo,h)
		hi = maxf(hi,h)
	return "%.2f..%.2f m" % [lo,hi]

## Water standing within `radius` of `center`: {volume m³, area m² deeper than 5 cm, deepest m}.
func water_near(center: Vector2, radius: float) -> Dictionary:
	var flow: RefCounted = editor.flow
	if flow == null: return {"volume":0.0,"area":0.0,"deepest":0.0}
	var depths: PackedFloat32Array = flow.depths()
	var volume := 0.0
	var area := 0.0
	var deepest := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			if (flow.origin+Vector2(i+0.5,j+0.5)*flow.cell).distance_to(center) >= radius: continue
			var d := depths[j*flow.width+i]
			volume += d
			if d > 0.05: area += 1.0
			deepest = maxf(deepest,d)
	var cell2: float = flow.cell*flow.cell
	return {"volume":snappedf(volume*cell2,0.01),"area":snappedf(area*cell2,0.1),"deepest":snappedf(deepest,0.01)}

## Objects on the plate within `radius` of `center` (the whole plate if
## radius <= 0), counted by asset.
func life_near(center := Vector2.ZERO, radius := 0.0) -> Dictionary:
	var counts := {}
	for o: Dictionary in editor.data.objects:
		if radius > 0.0 and Vector2(o.x,o.z).distance_to(center) >= radius: continue
		counts[o.asset] = counts.get(o.asset,0)+1
	return counts

## Log the ground height at each named plate point: {"name": Vector2}.
func heights_at(points: Dictionary) -> void:
	var parts: PackedStringArray = []
	for name: String in points: parts.append("%s %.2f" % [name,height(points[name])])
	log_line("heights: "+", ".join(parts))

func measure_water(label: String, center: Vector2, radius: float) -> void:
	var w := water_near(center,radius)
	log_line("water %s: %.2f m³ over %.1f m², deepest %.2f m (all water %.1f m³)" % [label,w.volume,w.area,w.deepest,editor.flow.volume() if editor.flow != null else 0.0])

func measure_life(label: String, center := Vector2.ZERO, radius := 0.0) -> void:
	log_line("life %s: %s" % [label,life_near(center,radius)])

func measure_verbs() -> void:
	log_line("clay verbs so far: %s" % [worked])
