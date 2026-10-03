extends SceneTree
## Headless probe of the edge spring's amplify (scripts/edge_spring.gd
## `_build_amplify`, docs/scenic/modeless.md "Edge rework"), on the real cozy
## worlds scene with synthesized input through hand_reach:
## - the blank plate's relief is measured and a pull there still springs a
##   random range;
## - the clay sculpts a peak (the Mountain's pull: the Modeller's pinch tops
##   out at 1.5 m since 2026-10-02), a groove (the Modeller's slow thumb, its
##   groove mode) and a basin (its palm mode); a gentle and then a hard edge pull amplify them: peak height and
##   prominence, groove and basin depth before and after, the rim unmoved, the
##   groove's dirt unpainted, one undo step each restoring heights and tint
##   exactly, and an undo mid-spring;
## - the CPU ms of the build at release and of the release frame.
## Nothing is rendered: how any of it looks is not checked.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/probe_edge_amplify.gd -- --modeless
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var spring: Node
var clay: Node
var flip: Node
var failures := []

const PEAK := Vector2(-4.0,-3.5)
const GROOVE := [Vector2(1.5,-5.5),Vector2(5.5,1.5)]
const BASIN := Vector2(-3.0,5.0)

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

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func settled() -> void:
	var quiet := 0
	var n := 0
	while quiet < 20 and n < 3000:
		await process_frame
		n += 1
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or spring.state != 0 or spring.waiting or flip.active() or clay.state != 0 or scene.places.busy or editor.forming
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	var h: Variant = editor.data.sample(p,editor.data.heights)
	return float(h) if h != null else 0.0

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

## Mean ground over points between `r0` and `r1` metres of `c`, or the max.
func ring(c: Vector2, r0: float, r1: float, top := false) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	var best := -INF
	for i in range(data.points.size()):
		var d: float = data.points[i].distance_to(c)
		if d < r0 or d >= r1: continue
		total += data.heights[i]
		best = maxf(best,data.heights[i])
		count += 1
	return best if top else total/maxi(count,1)

## Mean depth of the groove: the banks 2.6 m either side less the line, at
## stations along its middle 60 %.
func groove_depth() -> float:
	var a: Vector2 = GROOVE[0]
	var b: Vector2 = GROOVE[1]
	var side := (b-a).normalized().orthogonal()
	var total := 0.0
	for k in range(7):
		var p := a.lerp(b,0.2+0.6*k/6.0)
		total += (height(p+side*2.6)+height(p-side*2.6))*0.5-height(p)
	return total/7.0

func measure() -> Dictionary:
	return {"peak":ring(PEAK,0.0,1.5,true),"prominence":ring(PEAK,0.0,1.5,true)-ring(PEAK,7.0,8.0),
		"groove":groove_depth(),"basin":ring(BASIN,5.0,6.0)-ring(BASIN,0.0,1.5),"tallest":ring(Vector2.ZERO,0.0,40.0,true)}

## Mean |laplacian| over points within 3 m of the peak, per metre of its prominence.
func peak_roughness() -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		if data.points[i].distance_to(PEAK) >= 3.0: continue
		var around: PackedInt32Array = data._neighbors[i]
		if around.is_empty(): continue
		var mean := 0.0
		for j in around: mean += data.heights[j]
		total += absf(data.heights[i]-mean/around.size())
		count += 1
	return total/maxi(count,1)

func lip_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var h: Variant = editor.data.ground_height(edge)
			if h == null: continue
			var world := terrain.to_global(Vector3(edge.x,float(h),edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if at.y > best.y and at.y < root.size.y-300 and at.y > 330: best = at
	return best

## Pull the rim down `pixels` and let go; returns the release frame's ms.
func edge_pull(pixels: float, seed := -1) -> float:
	var from := lip_point()
	spring.next_seed = seed
	button(from,true)
	await frames(1)
	var at := from
	for i in range(24):
		at += Vector2(0.0,pixels/24.0)
		motion(at,Vector2(0.0,pixels/24.0))
		await frames(1)
	await frames(10)
	var t0 := Time.get_ticks_usec()
	button(at,false)
	await process_frame
	return (Time.get_ticks_usec()-t0)/1000.0

func pinch(p: Vector2, pixels: float) -> void:
	var at := screen(p)
	button(at,true)
	await frames(30)
	for i in range(40):
		motion(at+Vector2(0,-pixels*(i+1)/40.0),Vector2(0,-pixels/40.0))
		await frames(1)
	await frames(5)
	button(at+Vector2(0,-pixels),false)
	await settled()

## A drag along plate points `path`, `px` screen pixels a frame (slow: a groove).
func drag(path: Array, px: float) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	button(points[0],true)
	await frames(1)
	var at := points[0]
	for k in range(points.size()-1):
		var steps := maxi(1,int(points[k].distance_to(points[k+1])/px))
		for s in range(steps):
			var next := points[k].lerp(points[k+1],float(s+1)/steps)
			motion(next,next-at)
			at = next
			await frames(1)
	await frames(2)
	button(at,false)
	await settled()

func palm(c: Vector2, reach_m: float) -> void:
	var path: Array = [c]
	for i in range(25):
		var a := i*0.9
		path.append(c+Vector2(cos(a),sin(a))*(0.4+reach_m*float(i)/24.0))
	shift(true)
	await drag(path,5.0)
	shift(false)

## Largest |change| in heights between `a` and `b` for points past `edge`.
func rim_change(a: PackedFloat32Array, b: PackedFloat32Array, edge: float, upto := 99.0) -> float:
	var worst := 0.0
	for i in range(a.size()):
		var p: Vector2 = editor.data.points[i]
		var out := maxf(absf(p.x),absf(p.y))
		if out >= edge and out < upto: worst = maxf(worst,absf(b[i]-a[i]))
	return worst

## Tint cells locked as bare earth, and how many changed between `a` and `b`.
func dirt_changed(a: PackedFloat32Array, b: PackedFloat32Array) -> Array:
	var lock: PackedByteArray = spring._bare_cells(editor.data)
	var locked := 0
	var changed := 0
	for cell in range(lock.size()):
		if lock[cell] == 0: continue
		locked += 1
		for k in range(4):
			if absf(a[cell*4+k]-b[cell*4+k]) > 1e-6:
				changed += 1
				break
	return [locked,changed]

func amplify(label: String, pixels: float, before: Dictionary, s0: PackedFloat32Array, t0: PackedFloat32Array, keep := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var rough0 := peak_roughness()
	var release_ms := await edge_pull(pixels)
	var peak_x := 0.0
	var peak_h := 0.0
	while spring.state == 2 or spring.waiting or flip.active():
		await process_frame
		peak_x = maxf(peak_x,spring.spring_x)
		peak_h = maxf(peak_h,ring(PEAK,0.0,1.5,true))
	await settled()
	var info: Dictionary = spring.last_amplify
	var after := measure()
	var rough1 := peak_roughness()
	print("%s: pull %.2f factor %.3f jag %.2f relief %.2f m | peak %.2f -> %.2f m (spring max %.2f, x max %.2f), prominence %.2f -> %.2f, groove %.2f -> %.2f m, basin %.2f -> %.2f m, tallest %.2f, lift top %.2f deepest %.2f, roughness %.4f -> %.4f | base %.1f ms, build %.1f ms, release frame %.1f ms, %d points" % [
		label,spring._size,info.get("factor",0.0),info.get("jag",0.0),info.relief,before.peak,after.peak,peak_h,peak_x,before.prominence,after.prominence,
		before.groove,after.groove,before.basin,after.basin,after.tallest,info.get("top",0.0),info.get("deepest",0.0),rough0,rough1,info.base_ms,info.get("build_ms",0.0),release_ms,data.points.size()])
	var moat := 0.0
	for i in range(data.points.size()):
		var q: Vector2 = data.points[i]
		var d := q.distance_to(PEAK)
		if d < 4.0 or d >= 6.0: continue
		if Geometry2D.get_closest_point_to_segment(q,GROOVE[0],GROOVE[1]).distance_to(q) < 2.5: continue
		moat = minf(moat,data.heights[i]-s0[i])
	print("%s: most the ground 4-6 m round the peak sank (the base's halo) %.3f m" % [label,moat])
	print("%s: roughness per metre of prominence %.4f -> %.4f" % [label,rough0/before.prominence,rough1/after.prominence])
	check("%s: amplified, not a range" % label,spring.last_range.is_empty() and info.has("factor"))
	check("%s: the peak rises" % label,after.prominence > before.prominence+0.3,[before.prominence,after.prominence])
	check("%s: the groove deepens" % label,after.groove > before.groove+0.05,[before.groove,after.groove])
	check("%s: the basin deepens" % label,after.basin > before.basin+0.05,[before.basin,after.basin])
	check("%s: it springs (overshoots)" % label,peak_x > 1.05,peak_x)
	check("%s: the rim's last metres do not move" % label,rim_change(s0,data.heights,13.6) < 1e-4,rim_change(s0,data.heights,13.6))
	print("%s: most change 11.4..13.6 m out %.3f m, 9..11.4 m out %.3f m" % [label,rim_change(s0,data.heights,11.4,13.6),rim_change(s0,data.heights,9.0,11.4)])
	var dirt := dirt_changed(t0,data.tint)
	check("%s: the groove's dirt is not painted over" % label,dirt[0] > 0 and dirt[1] == 0,dirt)
	check("%s: one undo step" % label,data._undo.size() == undo0+1,data._undo.size()-undo0)
	var shaped := data.heights.duplicate()
	if not keep:
		editor.undo()
		await settled()
		check("%s: one undo restores heights and tint exactly" % label,data.heights == s0 and data.tint == t0,[data.heights == s0,data.tint == t0])
	after["release_ms"] = release_ms
	after["heights"] = shaped
	return after

func run() -> void:
	create_timer(380).timeout.connect(func() -> void: push_error("amplify probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-edge-amplify-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	reach = scene.hand_reach
	spring = scene.get("edge_spring")
	clay = scene.get("land_clay")
	flip = scene.get("flip")
	check("run with --modeless: the edge spring and the clay are built",spring != null and clay != null and flip != null)
	if spring == null or clay == null:
		quit(1)
		return
	scene.world_clock.running = false
	scene._overview()
	await frames(60)
	await settled()
	var data := editor.data

	# --- The blank plate still grows a range ---------------------------------------
	var blank := data.heights.duplicate()
	var blank_tint := data.tint.duplicate()
	var ms := await edge_pull(288.0,5)
	await settled()
	print("blank: relief %.3f m (under %.2f), range %s peaks, top %.2f m, release frame %.1f ms, build %.1f ms" % [spring.last_amplify.relief,spring.RELIEF_MIN,
		spring.last_range.get("peaks",[]).size(),spring.last_range.get("top",0.0),ms,spring.last_range.get("build_ms",0.0)])
	check("a blank plate springs a random range",not spring.last_range.is_empty() and spring.last_amplify.relief < spring.RELIEF_MIN)
	editor.undo()
	await settled()
	check("and one undo takes it back",data.heights == blank and data.tint == blank_tint)

	# --- Sculpt ---------------------------------------------------------------------
	var worked := []
	clay.worked.connect(func(verb: String, kept: bool) -> void: worked.append([verb,kept]))
	print("sculpt spots on screen: peak %s groove %s basin %s; bare %s" % [screen(PEAK),screen(GROOVE[0]),screen(BASIN),[reach.reach_at(screen(PEAK)),reach._prop_at(screen(PEAK)),reach.reach_at(screen(BASIN)),reach._prop_at(screen(BASIN))]])
	var materials: Node = reach.get("materials")
	materials.select_tool("mountain")
	await frames(10)
	await pinch(PEAK,18.0)
	materials.select_tool("hand")
	await frames(10)
	materials.set_mode("groove")
	await drag(GROOVE,3.0)
	materials.set_mode("palm")
	await palm(BASIN,1.8)
	await palm(BASIN,1.8)
	print("clay worked: ",worked)
	var s0 := data.heights.duplicate()
	var t0 := data.tint.duplicate()
	var before := measure()
	print("sculpted: peak %.2f m, prominence %.2f, groove %.2f m, basin %.2f m, tallest %.2f" % [before.peak,before.prominence,before.groove,before.basin,before.tallest])
	check("the sculpt shows a peak, a groove and a basin",before.prominence > 1.5 and before.groove > 0.3 and before.basin > 0.15,before)

	# --- Gentle, hard ---------------------------------------------------------------
	var gentle := await amplify("gentle",70.0,before,s0,t0)
	var hard := await amplify("hard",288.0,before,s0,t0)
	check("a hard pull amplifies more than a gentle one",hard.prominence > gentle.prominence+0.5 and hard.groove > gentle.groove and hard.basin > gentle.basin,[gentle.prominence,hard.prominence])
	check("under the ceiling",hard.tallest <= spring.CEILING+0.05,hard.tallest)

	# --- Twice, stacked --------------------------------------------------------------
	var twice := await amplify("hard, kept",288.0,before,s0,t0,true)
	var again := measure()
	var twice_s: PackedFloat32Array = data.heights.duplicate()
	var twice_t: PackedFloat32Array = data.tint.duplicate()
	await amplify("hard again",288.0,again,twice_s,twice_t)
	editor.undo()
	await settled()
	check("undo back to the sculpt",data.heights == s0 and data.tint == t0)

	# --- Undo mid-spring --------------------------------------------------------------
	await edge_pull(288.0)
	for i in range(40):
		await frames(1)
		if spring.state == 2 and spring.spring_x > 0.5: break
	check("mid-spring (x %.2f)" % spring.spring_x,spring.state == 2)
	editor.undo()
	await settled()
	check("an undo mid-spring lands it and takes it back exactly",data.heights == s0 and data.tint == t0)

	print("failures: %d %s" % [failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
