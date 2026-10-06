extends SceneTree
## A first-time player's session, captured: a new world on a quiet plain is
## shaped, watered, planted and furnished through the real hand (synthesized
## input through hand_reach, the tools taken from the roll and the case as
## their pockets would), then left to run into dusk and night, and toured.
## Numbered PNGs with the HUD showing land in /tmp/zs-impressions/.
## Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/play_impressions.gd -- --modeless --no-title

const OUT := "/private/tmp/zs-impressions"
const LAPSE := 4

var scene: Node3D
var editor: Node
var reach: Node
var clay: Node
var materials: Node
var pointer := Vector2(640,360)
var lapse := 0
var shots := 0
var notes: Array[String] = []

func _initialize() -> void: run.call_deferred()

func note(text: String) -> void:
	notes.append(text)
	print("PLAY ",text)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor != null and editor.flow != null: editor.flow.run(lapse)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

## Viewport units to the window pixels Input expects (2x on a Retina window).
func window(at: Vector2) -> Vector2:
	return root.get_final_transform()*at

func point(at: Vector2) -> void:
	pointer = at
	reach.pointer_override = at
	editor.pointer_override = at

func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = window(at)
	event.global_position = window(at)
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = window(at)
	event.global_position = window(at)
	event.relative = window(at)-window(pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	point(at)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),held)
		await frames(1)

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func settled() -> void:
	var quiet := 0
	var began := Time.get_ticks_msec()
	while quiet < 20 and Time.get_ticks_msec()-began < 15000:
		await frames(1)
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1

## Press, then drag along plate points `path` at `speed` m/s, the screen
## point read afresh each frame (the land may move under it), then let go.
func stroke(path: Array, speed: float, hold_first := 0.0) -> void:
	await glide(screen(path[0]),20)
	button(pointer,true)
	await frames(3)
	if hold_first > 0.0: await seconds(hold_first)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var steps := maxi(2,int(a.distance_to(b)/speed*60.0))
		for k in range(steps):
			move(screen(a.lerp(b,float(k+1)/steps)),true)
			await frames(1)
	await frames(3)
	button(pointer,false)
	await frames(2)

## Press at plate `p`, hold a beat, pull the screen by `pixels` (up negative).
func pull(p: Vector2, pixels: float, count := 50) -> void:
	await glide(screen(p),20)
	var from := pointer
	button(from,true)
	await seconds(0.3)
	for i in range(count):
		move(from+Vector2(0,pixels*smoothstep(0.0,1.0,float(i+1)/count)),true)
		await frames(1)
	await seconds(0.3)
	button(pointer,false)
	await frames(2)

func loop(at: Vector2, radius: Vector2, steps := 48, start := 0.0) -> Array:
	var out := []
	for k in range(steps+1):
		var a := start+TAU*float(k)/steps
		out.append(at+Vector2(cos(a)*radius.x,sin(a)*radius.y))
	return out

func zigzag(from: Vector2, to: Vector2, rows: int, across: float) -> Array:
	var out := []
	for k in range(rows):
		var off := Vector2(0,across*k)
		if k%2 == 0:
			out.append(from+off)
			out.append(to+off)
		else:
			out.append(to+off)
			out.append(from+off)
	return out

func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shots += 1
	var path := "%s/%02d-%s.png" % [OUT,shots,label]
	image.save_png(path)
	print("SHOT ",path)

func camera_to(target: Vector3, distance: float, yaw: float, polar: float, secs: float) -> void:
	var from := [scene.target,scene.distance,scene.yaw,scene.polar]
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = from[0].lerp(target,t)
		scene.distance = lerpf(from[1],distance,t)
		scene.yaw = lerpf(from[2],yaw,t)
		scene.polar = lerpf(from[3],polar,t)
		scene._update_camera()
		await frames(1)

func world(p: Vector2, lift := 0.0) -> Vector3:
	return editor.terrain.to_global(Vector3(p.x,height(p)+lift,p.y))

func overview() -> void:
	scene._overview()
	scene._update_camera()
	await frames(20)

func tool(id: String, mode := "") -> void:
	materials.select_tool(id)
	await frames(10)
	if not mode.is_empty():
		materials.set_mode(mode)
		await frames(4)
	if clay.tool_id != id: note("tool %s did not come to hand (in hand: %s)" % [id,clay.tool_id])

func take(id: String) -> bool:
	var ok: bool = materials.take(id)
	await frames(8)
	if not ok or materials.held != id: note("material %s could not be taken (held: %s)" % [id,materials.held])
	return ok and materials.held == id

func count_assets(asset: String) -> int:
	return editor.data.objects.filter(func(item: Dictionary) -> bool: return str(item.asset) == asset).size()

func asset_census() -> Dictionary:
	var out := {}
	for item: Dictionary in editor.data.objects: out[str(item.asset)] = int(out.get(str(item.asset),0))+1
	return out

const MOUNTAIN_A := Vector2(-8.5,-9.0)
const MOUNTAIN_B := Vector2(-1.5,-11.0)
const CRATER := Vector2(9.5,1.0)
const LAKE := Vector2(0.5,5.0)
const LAKE_R := Vector2(4.8,4.0)
const ISLE := Vector2(0.2,5.2)
var isle_west := Vector2.INF

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(900).timeout.connect(func() -> void: push_error("play impressions timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-impressions-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	point(Vector2(640,360))
	await seconds(3.0)
	print("PLAY clock day %d hour %.2f, objects %s" % [scene.world_clock.day,scene.world_clock.hour,asset_census()])

	# 1. The new world as it opens.
	await snap("fresh-world")
	# Keep the build in daylight: the clock runs on, from mid-morning.
	scene.world_clock.set_time(scene.world_clock.day,9.5)
	while editor.flow == null or not editor.flow.ready: await process_frame
	await settled()

	# 2. Sculpt: two peaks pulled, rolling hills, a crater.
	await tool("mountain","pull")
	await pull(MOUNTAIN_A,-95.0)
	await settled()
	await pull(MOUNTAIN_B,-60.0)
	await settled()
	print("PLAY peaks: A %.2f m, B %.2f m" % [height(MOUNTAIN_A),height(MOUNTAIN_B)])
	await tool("hills")
	await stroke(zigzag(Vector2(5.0,-11.0),Vector2(12.0,-11.0),6,1.4),5.0)
	await settled()
	print("PLAY hills at (8,-8): %.2f m" % height(Vector2(8,-8)))
	await tool("crater","pull")
	await pull(CRATER,90.0,40)
	await settled()
	print("PLAY crater floor %.2f m" % height(CRATER))
	await glide(Vector2(640,690),20)
	await seconds(1.0)
	await snap("sculpted")

	# 3. Water: a lake bed drawn with the Crater, filled from the case's water
	# and the watering can, then an isle drawn in it.
	await tool("crater","draw")
	clay.worked.connect(func(verb: String, kept: bool) -> void: print("PLAY worked ",verb," ",kept))
	await stroke(loop(LAKE,LAKE_R,48,PI),9.0)
	await settled()
	await seconds(0.5)
	print("PLAY lake bed %.2f m at its middle" % height(LAKE))
	var rim := INF
	var shore_line: PackedVector2Array = clay.tool.lake_shore() if clay.tool != null and clay.tool.has_method("lake_shore") else PackedVector2Array()
	for p: Vector2 in shore_line: rim = minf(rim,height(p))
	if shore_line.is_empty():
		for p: Vector2 in loop(LAKE,LAKE_R,32): rim = minf(rim,height(p))
	print("PLAY lake rim's lowest ground %.2f m" % rim)
	await tool("can")
	await glide(screen(LAKE+Vector2(1.0,0.5)),20)
	button(pointer,true)
	var poured := 0
	while poured < 60*40 and height(LAKE)+editor.flow.depth_at(LAKE) < rim-0.6:
		await frames(1)
		poured += 1
	button(pointer,false)
	await seconds(4.0)
	print("PLAY can poured %.1f s: water %.1f m³, lake middle %.2f m deep, level %.2f (rim %.2f)" % [poured/60.0,editor.flow.volume(),editor.flow.depth_at(LAKE),height(LAKE)+editor.flow.depth_at(LAKE),rim])
	if editor.flow.depth_at(LAKE) < 0.4: note("the can left the lake shallow (%.2f m)" % editor.flow.depth_at(LAKE))
	# The case's water: scooped from the lake, carried and let go over the hills.
	if await take("water"):
		var outcome := {}
		var got := func(o: Dictionary) -> void: outcome.merge(o)
		editor.ball_settled.connect(got)
		var vol0: float = editor.flow.volume()
		await glide(screen(LAKE),20)
		button(pointer,true)
		await seconds(2.0)
		await glide(screen(Vector2(8.0,-8.0)),40,true)
		await seconds(0.5)
		button(pointer,false)
		for i in range(420):
			await frames(1)
			if not outcome.is_empty(): break
		editor.ball_settled.disconnect(got)
		print("PLAY water ball: %s; water %.1f m³ (was %.1f)" % [outcome,editor.flow.volume(),vol0])
		if outcome.is_empty(): note("the scooped water ball never settled")
		materials.put_back()
		await frames(5)
	await tool("island","draw")
	await stroke(loop(ISLE,Vector2(1.4,1.2),36),6.0)
	await settled()
	if clay.tool != null and clay.tool.has_method("isle_shore"):
		for q: Vector2 in clay.tool.isle_shore():
			if q.x < isle_west.x: isle_west = q
	print("PLAY isle's west shore ",isle_west)
	await seconds(2.0)
	print("PLAY isle top %.2f m, water there %.2f m" % [height(ISLE),editor.flow.depth_at(ISLE)])
	await tool("hand")
	await glide(Vector2(640,690),20)
	await seconds(2.0)
	await snap("water")

	# 4. Vegetation: pines under the peaks, oaks and birches on the hills'
	# foot, wildflowers and poppies, grass brushed onto the crater, wheat.
	var before := asset_census()
	if await take("pine"):
		await stroke([Vector2(-12.0,-3.5),Vector2(-4.0,-5.0),Vector2(-11.0,-1.5),Vector2(-5.0,-3.0)],3.0)
		await settled()
	if await take("redwood"):
		await stroke([Vector2(-11.5,-11.5),Vector2(-11.0,-6.0)],3.0)
		await settled()
	if await take("oak"):
		await stroke([Vector2(7.0,-6.0),Vector2(12.0,-5.0),Vector2(9.0,-3.0)],3.0)
		await settled()
	if await take("birch"):
		await stroke([Vector2(4.0,-6.0),Vector2(5.5,-3.0)],3.0)
		await settled()
	if await take("wildflower"):
		await stroke(zigzag(Vector2(7.0,7.0),Vector2(12.0,7.5),3,1.4),3.0)
		await settled()
	if await take("poppy"):
		await stroke([Vector2(6.5,11.5),Vector2(11.5,12.0)],3.0)
		await settled()
	if await take("sunflower"):
		await stroke([Vector2(-1.5,11.0),Vector2(2.5,12.0)],3.0)
		await settled()
	if await take("wheat"):
		await stroke(zigzag(Vector2(-12.0,6.5),Vector2(-6.5,6.5),5,1.2),4.0)
		await settled()
	if await take("reed"):
		await stroke([LAKE+Vector2(-4.6,1.5),LAKE+Vector2(-4.2,3.0)],2.0)
		await settled()
	materials.put_back()
	await frames(5)
	await tool("brush","grass")
	await stroke(zigzag(Vector2(-12.0,-11.0),Vector2(-9.0,-11.0),3,1.0),4.0)
	await settled()
	await tool("hand")
	var after := asset_census()
	print("PLAY planted: before %s after %s" % [before,after])
	await glide(Vector2(640,690),20)
	await seconds(2.0)
	await snap("planted")

	# 5. Placeables: a pen round the wheat, a footbridge to the isle, a row of
	# stone lamps up to it, a few stones.
	if await take("fence"):
		var pen := [Vector2(-12.8,5.6),Vector2(-5.8,5.6),Vector2(-5.8,11.8),Vector2(-12.8,11.8),Vector2(-12.8,5.6)]
		await stroke(pen,4.0)
		await settled()
		print("PLAY fences: %d" % editor.data.fences.size())
		if editor.data.fences.is_empty(): note("the fence drag laid no fence")
	if await take("bridge"):
		# From the west shore across to the isle.
		var isle := ISLE
		var shore := Vector2(LAKE.x-LAKE_R.x-0.6,ISLE.y)
		if isle_west.is_finite():
			isle = isle_west+Vector2(0.7,0.0)
			shore = isle_west-Vector2(3.5,0.0)
		await glide(screen(shore),20)
		button(pointer,true)
		await frames(3)
		for k in range(30):
			move(screen(shore.lerp(isle,float(k+1)/30)),true)
			await frames(1)
		await frames(4)
		button(pointer,false)
		await settled()
		print("PLAY bridge: %d laid, last %s" % [count_assets("bridge"),materials.bridge_last])
		if count_assets("bridge") == 0:
			# A second try, shore to isle further in along its line.
			var plan_a := shore+Vector2(0.8,0.0)
			var plan_b := isle+Vector2(-0.5,0.0)
			await glide(screen(plan_a),20)
			button(pointer,true)
			await frames(3)
			for k in range(30):
				move(screen(plan_a.lerp(plan_b,float(k+1)/30)),true)
				await frames(1)
			await frames(4)
			button(pointer,false)
			await settled()
			print("PLAY bridge retry: %d laid, last %s" % [count_assets("bridge"),materials.bridge_last])
			if count_assets("bridge") == 0: note("the footbridge would not lay: %s" % materials.bridge_last)
	if await take("lamp"):
		await stroke([Vector2(-7.0,-2.0),Vector2(-6.2,1.5),Vector2(-5.0,4.0)],1.5)
		await settled()
		print("PLAY lamps: %d" % count_assets("stone_lamp"))
	if await take("stone"):
		for p in [Vector2(5.5,1.0),Vector2(-1.5,0.5),Vector2(7.5,4.0)]:
			await glide(screen(p),15)
			button(pointer,true)
			await seconds(0.6)
			button(pointer,false)
			await frames(10)
		await settled()
	materials.put_back()
	await frames(5)
	print("PLAY census %s" % asset_census())
	await glide(Vector2(640,690),20)
	await seconds(2.0)
	await snap("furnished")

	# 6. Time runs: golden hour, dusk, night.
	scene.world_clock.set_time(scene.world_clock.day,17.4)
	await seconds(6.0)
	await snap("golden-hour")
	scene.world_clock.set_time(scene.world_clock.day,18.25)
	await seconds(6.0)
	await snap("dusk")
	scene.world_clock.set_time(scene.world_clock.day,23.0)
	await seconds(6.0)
	await snap("night")
	var lit: Node = editor.get("lamps")
	if lit != null: print("PLAY night lamps glow %.2f, lit %d" % [lit.glow,lit.lit().size()])

	# 7. Back to day; the tour: low by the lake and the bridge, the wheat pen,
	# the peaks, a wide view; then the HUD woken.
	scene.world_clock.set_time(scene.world_clock.day+1,10.5)
	await seconds(5.0)
	await glide(Vector2(260,90),20)
	await camera_to(world(LAKE,0.0),15.0,scene.yaw+0.35,1.18,4.0)
	await seconds(1.5)
	await snap("close-lake-bridge")
	await camera_to(world(Vector2(-9.0,8.5),0.5),12.0,scene.yaw-0.9,1.25,4.0)
	await seconds(1.5)
	await snap("close-wheat-pen")
	await camera_to(world(Vector2(-2.0,1.0),1.0),26.0,scene.yaw+0.5,1.36,4.0)
	await seconds(1.5)
	await snap("low-peaks-pines")
	scene._overview()
	var wide_yaw: float = scene.yaw
	scene.yaw = wide_yaw-0.4
	scene._update_camera()
	await camera_to(scene.target,scene.distance*1.15,wide_yaw+0.9,0.95,4.0)
	await seconds(1.5)
	await snap("wide")
	await overview()
	await tool("mountain","pull")
	await glide(Vector2(30,330),30)
	await seconds(1.5)
	await snap("hud-tool-roll")
	await tool("hand")
	if await take("oak"):
		await glide(Vector2(640,705),30)
		await seconds(1.5)
		await snap("hud-materials-case")
	materials.put_back()
	print("PLAY notes: ",notes)
	print("PLAY done")
	quit(0)
