extends SceneTree
## Headless probe of the Mountain's range (scripts/clay_tools/mountain.gd), on
## the real cozy worlds scene, driven by synthesized input through hand_reach.
## Checks: a pull straight up is the single peak, round, and a little sideways
## jitter on the way up leaves exactly that peak; a pull up and sideways
## stretches it into a range along the drag, at least RANGE_ASPECT times as
## long as it is wide, with several summits along its crest, standing about as
## tall as the peak, with the range's rock along it; each is one undo step one
## undo takes back exactly, tint and all. In Draw mode a stroke draws a
## range instead: nothing rises while it is drawn, and let go it grows
## along the drawn bend, all of it near the path and reaching both its ends,
## to about the spec's `drawn` height, with its rock, shuddering as it grows,
## as one undo step.
##
## `--peak-ref=<path>`: the straight pull's heights are compared with the file
## at `path` when it exists (a run before a change), else written there.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_mountain_range.gd -- --modeless --no-title [--peak-ref=/tmp/peak.bin]
const Mountain = preload("res://scripts/clay_tools/mountain.gd")
const RANGE_ASPECT := 3.0
## How far along the ground the range is dragged (m), and the pointer's
## travel up the screen for both pulls (px).
const RANGE_LENGTH := 16.0
const RISE_PIXELS := 150.0
## Metres two pulls' heights may differ by and still be the same peak: the
## camera settles by a fraction of a pixel between pulls, so the pointer's
## rise in metres differs by a hair (3e-4 m measured).
const PEAK_SAME := 0.002
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

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

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

## A pull from `from`: up RISE_PIXELS and across `across` pixels in `steps`
## moves, each `wobble` pixels off the straight line, alternately. Returns
## the frame times (ms) while it was held.
func pull(from: Vector2, across: float, steps := 30, wobble := 0.0) -> Array[float]:
	var times: Array[float] = []
	button(from,true)
	await frames(2)
	var last := from
	for k in range(steps):
		var share := float(k+1)/steps
		var to := from+Vector2(across*share+(wobble if k%2 == 0 else -wobble)*float(k < steps-1),-RISE_PIXELS*share)
		motion(to,to-last)
		last = to
		var started := Time.get_ticks_usec()
		await frames(1)
		times.append((Time.get_ticks_usec()-started)/1000.0)
	await frames(10)
	button(last,false)
	await settled()
	return times

## Points the last pull raised at least `least` metres over `base`.
func raised(base: PackedFloat32Array, least: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var heights := editor.data.heights
	for i in range(base.size()):
		if heights[i]-base[i] >= least: out.append(i)
	return out

## The raised points' extent along `axis` and across it (m).
func extents(points: PackedInt32Array, axis: Vector2) -> Vector2:
	var across := Vector2(-axis.y,axis.x)
	var low := Vector2.INF
	var high := -Vector2.INF
	for i in points:
		var p: Vector2 = editor.data.points[i]
		var v := Vector2(p.dot(axis),p.dot(across))
		low = low.min(v)
		high = high.max(v)
	return high-low

## The raised points' main axis (unit), by their spread.
func main_axis(points: PackedInt32Array) -> Vector2:
	var mean := Vector2.ZERO
	for i in points: mean += editor.data.points[i]
	mean /= maxi(points.size(),1)
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for i in points:
		var d: Vector2 = editor.data.points[i]-mean
		xx += d.x*d.x
		xy += d.x*d.y
		yy += d.y*d.y
	var angle := 0.5*atan2(2.0*xy,xx-yy)
	return Vector2(cos(angle),sin(angle))

## The tint layer's weight at plate point `p`.
func tint_weight(tint: PackedFloat32Array, p: Vector2) -> float:
	var side := NativeTerrainData.MEADOW_CELLS
	var cell := Vector2i(((p+Vector2.ONE*14.0)/NativeTerrainData.MEADOW_STEP).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	return NativeTerrainTint.weight_at(tint,cell.y*side+cell.x)

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("mountain range probe timed out"); quit(2))
	var peak_ref := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--peak-ref="): peak_ref = arg.get_slice("=",1)
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-range-probe-%d/places.json" % Time.get_ticks_usec()
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
	var undo0: int = data._undo.size()
	materials.select_tool("mountain")
	await frames(10)
	# A bare spot with RANGE_LENGTH of ground beside it on its screen row,
	# inside the plate's edge fade.
	var at := Vector2.INF
	var across := 0.0
	for candidate in [Vector2(-5,1),Vector2(-4,-2),Vector2(5,1),Vector2(-6,3),Vector2(0,-3),Vector2(-2,0),Vector2(3,-3)]:
		var s := screen(candidate)
		if not bare(s): continue
		for way in [1.0,-1.0]:
			for px in range(20,900,4):
				var p: Variant = plate(s+Vector2(way*px,0))
				if p == null: break
				if (p as Vector2).distance_to(candidate) >= RANGE_LENGTH:
					if absf(p.x) < 11.0 and absf(p.y) < 11.0:
						at = candidate
						across = way*px
					break
			if at != Vector2.INF: break
		if at != Vector2.INF: break
	check("found a bare spot with room for a range",at != Vector2.INF,[at,across])
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01)," range drag ",across," px")

	# --- (a) Straight up: the single peak ---
	var base := data.heights.duplicate()
	var tint0 := data.tint.duplicate()
	var before := height(at)
	var peak_times := await pull(spot,0.0)
	peak_times.sort()
	var peak_heights := data.heights.duplicate()
	var peak := 0.0
	for i in range(base.size()): peak = maxf(peak,peak_heights[i]-base[i])
	var round_pts := raised(base,peak*0.1)
	var round_ext := extents(round_pts,Vector2.RIGHT)
	print("PEAK ",JSON.stringify({"top":snappedf(peak,0.01),"at_press":snappedf(height(at)-before,0.01),"extent_x":snappedf(round_ext.x,0.1),"extent_z":snappedf(round_ext.y,0.1),"raised":round_pts.size(),"frame_ms_p50":snappedf(peak_times[peak_times.size()/2],0.1),"frame_ms_max":snappedf(peak_times.back(),0.1)}))
	check("a pull straight up is one peak",peak > 4.0 and data._undo.size() == undo0+1,[peak,data._undo.size()-undo0])
	check("round: as wide one way as the other",maxf(round_ext.x,round_ext.y)/maxf(minf(round_ext.x,round_ext.y),0.01) < 1.5,round_ext)
	if not peak_ref.is_empty():
		if FileAccess.file_exists(peak_ref):
			var ref := FileAccess.get_file_as_bytes(peak_ref).to_float32_array()
			var worst := INF if ref.size() != peak_heights.size() else 0.0
			if ref.size() == peak_heights.size():
				for i in range(ref.size()): worst = maxf(worst,absf(ref[i]-peak_heights[i]))
			check("the peak is the same as the reference's",worst < PEAK_SAME,worst)
		else:
			var file := FileAccess.open(peak_ref,FileAccess.WRITE)
			file.store_buffer(peak_heights.to_byte_array())
			file.close()
			print("wrote the peak's heights to ",peak_ref)
	editor.undo()
	await settled()
	check("one undo takes the peak back exactly",data.heights == base and data.tint == tint0 and data._undo.size() == undo0)

	# --- A little sideways jitter on the way up is still that peak ---
	await pull(spot,8.0,30,10.0)
	var worst := 0.0
	for i in range(base.size()): worst = maxf(worst,absf(data.heights[i]-peak_heights[i]))
	check("sideways jitter under the dead zone leaves the same peak",worst < PEAK_SAME and not clay.tool.ranged,[worst,clay.tool.ranged])
	editor.undo()
	await settled()

	# --- (b) Up and sideways: a range ---
	var end: Vector2 = plate(spot+Vector2(across,0))
	var drag := (end-at).normalized()
	var times := await pull(spot,across,40)
	var range_top := 0.0
	for i in range(base.size()): range_top = maxf(range_top,data.heights[i]-base[i])
	var ridge_pts := raised(base,range_top*0.1)
	var axis := main_axis(ridge_pts)
	var ext := extents(ridge_pts,axis)
	# The crest: the highest rise in each 0.5 m slice along the axis.
	var low := INF
	var high := -INF
	for i in ridge_pts:
		low = minf(low,data.points[i].dot(axis))
		high = maxf(high,data.points[i].dot(axis))
	var bins := ceili((high-low)/0.5)+1
	var crest := PackedFloat32Array()
	crest.resize(bins)
	var crest_at := []
	crest_at.resize(bins)
	for i in ridge_pts:
		var b := floori((data.points[i].dot(axis)-low)/0.5)
		var rise := data.heights[i]-base[i]
		if rise > crest[b]:
			crest[b] = rise
			crest_at[b] = data.points[i]
	# Summits: crest slices higher than every slice within 1 m, standing at
	# least 0.4 m over the lowest ground between them and the next one.
	var tops: Array[int] = []
	for b in range(bins):
		var top := true
		for o in range(-2,3):
			if o != 0 and b+o >= 0 and b+o < bins and crest[b+o] > crest[b]: top = false
		if top and crest[b] > range_top*0.3: tops.append(b)
	var summits: Array[int] = []
	for b in tops:
		if summits.is_empty():
			summits.append(b)
			continue
		var last: int = summits.back()
		var saddle := INF
		for k in range(last,b+1): saddle = minf(saddle,crest[k])
		if minf(crest[last],crest[b])-saddle >= 0.4: summits.append(b)
		elif crest[b] > crest[last]: summits[-1] = b
	# The range's rock along its crest, in each third.
	var thirds := [0,0,0]
	var stretch := 0
	for b in range(bins):
		if crest_at[b] == null or crest[b] < range_top*0.3: continue
		stretch += 1
		var third := mini(int(3.0*b/bins),2)
		var p: Vector2 = crest_at[b]
		var rock := false
		for o in [Vector2.ZERO,Vector2(0.5,0),Vector2(-0.5,0),Vector2(0,0.5),Vector2(0,-0.5)]:
			if tint_weight(data.tint,p+o)-tint_weight(tint0,p+o) > 0.1: rock = true
		if rock: thirds[third] += 1
	times.sort()
	print("RANGE ",JSON.stringify({"top":snappedf(range_top,0.01),"length":snappedf(ext.x,0.1),"width":snappedf(ext.y,0.1),"axis":axis,"drag":drag,
		"summits":summits.size(),"summit_heights":summits.map(func(b: int) -> float: return snappedf(crest[b],0.01)),
		"crest":Array(crest).map(func(h: float) -> float: return snappedf(h,0.1)),"rock_thirds":thirds,"frame_ms_p50":snappedf(times[times.size()/2],0.1),"frame_ms_max":snappedf(times.back(),0.1)}))
	check("a pull up and sideways is one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("the range runs along the drag",absf(axis.dot(drag)) > 0.9,[axis,drag])
	check("at least %d times as long as it is wide" % RANGE_ASPECT,ext.x >= RANGE_ASPECT*ext.y,ext)
	check("several summits along its crest",summits.size() >= 3,summits.size())
	check("about as tall as the peak",range_top > peak*0.75 and range_top < peak*1.25,[range_top,peak])
	check("its ends taper: the crest falls toward both ends",crest[0] < range_top*0.5 and crest[bins-1] < range_top*0.5,[crest[0],crest[bins-1]])
	check("the range's rock along it, in every third",thirds[0] > 0 and thirds[1] > 0 and thirds[2] > 0,thirds)
	editor.undo()
	await settled()
	check("one undo takes the range back exactly",data.heights == base and data.tint == tint0 and data._undo.size() == undo0)

	# --- (c) Draw mode: a range along a bend ---
	materials.set_mode("draw")
	await frames(2)
	check("Draw is in hand",clay.tool.mode == "draw",clay.tool.mode)
	var drawn_times: Array[float] = []
	var bend: Array[Vector2] = []
	for k in range(41):
		var share := float(k)/40.0
		bend.append(spot+Vector2(across*share,-90.0*sin(PI*share)))
	button(bend[0],true)
	await frames(1)
	for k in range(1,bend.size()):
		motion(bend[k],bend[k]-bend[k-1])
		var started := Time.get_ticks_usec()
		await frames(1)
		drawn_times.append((Time.get_ticks_usec()-started)/1000.0)
	var still := 0.0
	for i in range(base.size()): still = maxf(still,absf(data.heights[i]-base[i]))
	check("a Draw stroke draws: the land is untouched while it is drawn",clay.state == clay.State.DRAG and clay.verb == "drawn_range" and still < 1e-5,[clay.state,clay.verb,still])
	var shudder: Node = scene.get("clay_tremor")
	var kicks0: int = shudder.kicks if shudder != null else 0
	button(bend[-1],false)
	await frames(1)
	check("let go, it grows",clay.tool.busy(),clay.tool.busy())
	await settled()
	var grow_kicks: int = (shudder.kicks if shudder != null else 0)-kicks0
	check("the land shudders as it grows, as under a pull",shudder != null and grow_kicks >= 10,grow_kicks)
	var path: PackedVector2Array = clay.tool.range_path()
	var drawn_top := 0.0
	for i in range(base.size()): drawn_top = maxf(drawn_top,data.heights[i]-base[i])
	var drawn_pts := raised(base,drawn_top*0.1)
	var reach_m: float = float(Mountain.PEAK.max_radius)*Mountain.HORN_REACH+0.5
	var stray := 0
	for i in drawn_pts:
		var p: Vector2 = data.points[i]
		var d := INF
		for j in range(path.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1])))
		if d > reach_m: stray += 1
	# Raised ground near each end of the path and at its middle.
	var near_ends := [false,false,false]
	for i in drawn_pts:
		var p: Vector2 = data.points[i]
		for e in range(3):
			var at_e: Vector2 = path[[0,path.size()/2,path.size()-1][e]]
			if p.distance_to(at_e) < 2.5 and data.heights[i]-base[i] > drawn_top*0.25: near_ends[e] = true
	# The drawn bend leaves its chord: its middle stands off the line between its ends.
	var chord_off := Geometry2D.get_closest_point_to_segment(path[path.size()/2],path[0],path[-1]).distance_to(path[path.size()/2])
	var drawn_rock := 0
	for p in path:
		if tint_weight(data.tint,p)-tint_weight(tint0,p) > 0.1: drawn_rock += 1
	drawn_times.sort()
	print("DRAWN ",JSON.stringify({"top":snappedf(drawn_top,0.01),"raised":drawn_pts.size(),"stray":stray,"path_points":path.size(),"ends":near_ends,"chord_off":snappedf(chord_off,0.1),"rock_on_path":drawn_rock,"frame_ms_p50":snappedf(drawn_times[drawn_times.size()/2],0.1),"frame_ms_max":snappedf(drawn_times.back(),0.1)}))
	check("a drawn range is one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("about the spec's drawn height",drawn_top > float(Mountain.PEAK.drawn)*0.75 and drawn_top < float(Mountain.PEAK.drawn)*1.25,drawn_top)
	check("the path was drawn as a bend",chord_off > 2.0,chord_off)
	check("everything it raised is near the drawn path",stray == 0,stray)
	check("it reaches both ends and the middle of the path",near_ends[0] and near_ends[1] and near_ends[2],near_ends)
	check("the drawn range's rock along it",drawn_rock > path.size()/3,[drawn_rock,path.size()])
	editor.undo()
	await settled()
	check("one undo takes the drawn range back exactly",data.heights == base and data.tint == tint0 and data._undo.size() == undo0)

	print("MOUNTAIN RANGE PROBE: ",failures.size()," failures ",failures)
	quit(1 if not failures.is_empty() else 0)
