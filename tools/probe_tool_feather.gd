extends SceneTree
## Headless probe of the Feather, "Gust" (scripts/clay_tools/feather.gd for
## its prop, scripts/hand_materials.gd "The Feather" for its gestures,
## docs/design/tools/PLAN.md "The Feather") on the real cozy worlds scene,
## driven by synthesized mouse and key input through hand_reach, as
## tools/probe_tool_paddle.gd drives the Paddle. Checks: the roll shows the
## Feather after a divider under the Hammer and its pocket takes it; the hand
## grips the stand-in quill in the tint, leaning -18°; a swipe on the land
## is one live wake along the swipe, as wide as the pips say, and sends no
## gust; the quill follows the pointer through the whole press, drag and
## release; a curved drag's wake (read through WindGust `blow_at`, the
## shaders' mirror) leans foliage at and behind the feather along the path's
## tangent, springs back past rest, leaves foliage off the path and far ahead
## alone, carries leaves along the path, lays ribbons on the curve, and dies
## away after release; a still press held 400 ms bursts and a shorter one
## sends nothing; a drag from the sky onto the land puts the Feather in hand,
## its pocket pressed; the faint marks show at rest and under the feather
## (hotspot) and during the hold (ring), under the alpha cap; the Feather adds
## no undo step and leaves the heights as they were; taking a material and
## Esc give back the Hand.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_feather.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the grip, the
## prop and the marks are checked as data only.
const Feather = preload("res://scripts/clay_tools/feather.gd")
const Marks = preload("res://scripts/ground_marks.gd")
const Materials = preload("res://scripts/hand_materials.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var marks: Node
var hand: Node
var roll: Control
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## Input through the Input singleton, so its button state is what the wind
## tool reads each frame (NativeChunkEditor `_gust_process`).
func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func frames(count: int) -> void:
	for i in range(count): await process_frame

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at) and not materials.tray_under(at)

func faint() -> bool:
	return marks.line_alpha_now() <= Marks.FAINT_CAP+1e-4 and Marks.LINE_ALPHA <= Marks.FAINT_CAP and Marks.FILL_ALPHA <= Marks.FAINT_CAP

## Empty sky: void, no cloud.
func empty_sky() -> Vector2:
	for y in [30,60,100,140]:
		for x in [400,600,720,900,1100]:
			var at := Vector2(x,y)
			if reach.void_at(at) and reach._cloud_at(at) == null: return at
	return Vector2.INF

func gust() -> Node:
	return editor.get("gust")

## Rest the hand over `spot` with nothing pressed, long enough for the hover
## and the mark to settle.
func hover(spot: Vector2) -> void:
	motion(spot,Vector2.ZERO,false)
	await frames(20)

## Swipe `pixels` along screen x from `start` in `steps` frames and let go.
## Returns [the wake let go or {}, the mark seen mid-swipe, the plate way,
## lane gusts sent meanwhile].
func swipe(start: Vector2, pixels: float, steps := 10) -> Array:
	var sent: int = int(materials.feather_sent.wake)
	var lanes: int = gust().gusts.size() if gust() != null else 0
	await hover(start)
	button(start,true)
	await frames(1)
	var p := start
	var seen := {}
	for i in range(steps):
		p += Vector2(pixels/steps,0)
		motion(p,Vector2(pixels/steps,0))
		await frames(1)
		if i == steps-2: seen = {"kind":marks.kind,"shown":marks.shown,"visible":marks.node.visible,"half":marks.half,"centre":marks.centre,"under":plate(p),"alpha":marks.line_alpha_now(),"holding":reach.holding}
	button(p,false)
	await frames(2)
	var way: Vector2 = (plate(p)-plate(start)).normalized()
	var g: Dictionary = gust().wakes.back() if gust() != null and not gust().wakes.is_empty() and int(materials.feather_sent.wake) > sent else {}
	return [g,seen,way,gust().gusts.size()-lanes]

func world_of(p: Vector2) -> Vector3:
	return editor.terrain.to_global(Vector3(p.x,height(p),p.y))

## The wind tool's lean on foliage at plate `p` (WindGust `blow_at`, as the
## shaders' zs_blow_at reads the published globals): [lean along plate `way`,
## angle off it (degrees), size].
func lean_at(p: Vector2, way: Vector2) -> Array:
	var world := world_of(p)
	var reading: Vector3 = gust().blow_at(Vector2(world.x,world.z),float(scene.get("_motion_time")))
	var lean := Vector2(reading.x,reading.y)
	var w := editor.terrain.global_basis*Vector3(way.x,0.0,way.y)
	var ref := Vector2(w.x,w.z).normalized()
	return [lean.dot(ref),rad_to_deg(absf(lean.angle_to(ref))) if lean.length() > 0.001 else 0.0,lean.length()]

## A point on the curved drag's arc at `k` (0..1) of the way, and its tangent.
func arc(c: Vector2, r: float, k: float) -> Array:
	var a := lerpf(-0.9,0.9,k)
	return [c+Vector2(cos(a),sin(a))*r,Vector2(-sin(a),cos(a))]

## Plate points on the Feather's rows of motes and ribbon vertices, as drawn
## this frame (world, back to plate).
func drawn_motes() -> Array:
	var out := []
	var multimesh: MultiMesh = gust()._mote_node.multimesh
	for i in range(multimesh.visible_instance_count):
		if i >= gust()._motes.size(): break
		if not is_same(gust()._motes[i].gust,gust().wakes.back()): continue
		var local := editor.terrain.to_local(multimesh.get_instance_transform(i).origin)
		out.append(Vector2(local.x,local.z))
	return out

func ribbon_points(w: Dictionary) -> Array:
	var out := []
	var nodes: Array = w.chunks.duplicate()
	nodes.append(w.tail)
	for node: MeshInstance3D in nodes:
		if node == null or node.mesh == null: continue
		var arrays: Array = (node.mesh as ArrayMesh).surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(vertices.size()):
			var local := editor.terrain.to_local(vertices[i])
			out.append(Vector3(local.x,local.z,uvs[i].x))
	return out

## The live wake on a curved drag, read as the shaders read it (WindGust
## `blow_at`): a quarter-ish arc of radius 7 m in about 1.2 s, then let go.
func wake_checks(at: Vector2) -> void:
	var r := 7.0
	var c := Vector2.INF
	for centre: Vector2 in [at-Vector2(r,0),at+Vector2(r,0),at-Vector2(0,r),at+Vector2(0,r)]:
		var ok := true
		for i in range(11):
			var s := screen(arc(centre,r,i/10.0)[0])
			if not bare(s): ok = false
		if ok:
			c = centre
			break
	check("found bare land for a curved drag",c != Vector2.INF,at)
	if c == Vector2.INF: return
	var lanes: int = gust().gusts.size()
	var wakes: int = int(materials.feather_sent.wake)
	var start: Vector2 = arc(c,r,0.0)[0]
	var last := screen(start)
	await hover(last)
	button(last,true)
	await frames(1)
	var prop: Node3D = clay.get("_prop")
	var steps := 72
	var shown := 0
	var worst_tip := 0.0
	var worst_usec := 0
	var watch: Array = arc(c,r,0.3)
	var follow := {"peak":0.0,"back":0.0}
	var mid := {}
	for i in range(1,steps+1):
		var k := float(i)/steps
		var s := screen(arc(c,r,k)[0])
		motion(s,s-last)
		last = s
		await frames(1)
		if prop != null and prop.visible: shown += 1
		var hit: Variant = editor.pointer_hit
		var tip: Vector3 = clay.get("_prop_motion").tip
		if i > 6 and hit != null: worst_tip = maxf(worst_tip,Vector2(tip.x,tip.z).distance_to(Vector2(hit.x,hit.z)))
		worst_usec = maxi(worst_usec,int(gust().last_usec))
		var here: float = lean_at(watch[0],watch[1])[0]
		follow.peak = maxf(follow.peak,here)
		if follow.peak > 0.1: follow.back = minf(follow.back,here)
		if i == int(steps*0.65):
			var w: Dictionary = gust().wakes.back()
			var metres := 1.8*r
			var behind := {}
			for back in [0.5,1.5,3.0]:
				var b: Array = arc(c,r,k-back/metres)
				var reading := lean_at(b[0],b[1])
				behind[back] = [snappedf(reading[0],0.01),snappedf(reading[1],0.1)]
			var ahead: Array = arc(c,r,minf(k+2.0/metres,1.0))
			var feather: Array = arc(c,r,k)
			var outward: Vector2 = (Vector2(feather[0])-c).normalized()
			mid = {"k":k,"behind":behind,"ahead_2m":snappedf(lean_at(ahead[0],ahead[1])[2],0.01),
				"centre_7m_off":snappedf(lean_at(c,feather[1])[2],0.01),"outside_6m_off":snappedf(lean_at(Vector2(feather[0])+outward*6.0,feather[1])[2],0.01),
				"heading_off":snappedf(rad_to_deg(absf(Vector2(w.heading).angle_to(feather[1]))),0.1),"power":snappedf(float(w.power),0.01),"air":snappedf(float(w.air),0.01),
				"speed":snappedf(float(w.speed),0.1),"lanes_sent":gust().gusts.size()-lanes,"points":gust()._wake_points.size()}
			var motes := drawn_motes()
			var mote_off := 0.0
			for q: Vector2 in motes: mote_off = maxf(mote_off,absf(q.distance_to(c)-r))
			mid["motes_on_wake"] = motes.size()
			mid["mote_off_path_m"] = snappedf(mote_off,0.01)
			var ribbon := ribbon_points(w)
			var ribbon_off := 0.0
			var ribbon_uv := 0.0
			for q: Vector3 in ribbon:
				ribbon_off = maxf(ribbon_off,absf(Vector2(q.x,q.y).distance_to(c)-r))
				ribbon_uv = maxf(ribbon_uv,q.z)
			mid["ribbon_chunks"] = w.chunks.size()
			mid["ribbon_vertices"] = ribbon.size()
			mid["ribbon_off_path_m"] = snappedf(ribbon_off,0.01)
			mid["ribbon_uv_max"] = snappedf(ribbon_uv,0.01)
			mid["path_m"] = snappedf(float(w.dist),0.01)
			mid["local_gusts"] = w.local.size()
			mid["parcel"] = w.slot
	var mid_hold := {"prop_shown":prop != null and prop.visible}
	button(last,false)
	await frames(1)
	var let_go: Dictionary = gust().wakes.back() if not gust().wakes.is_empty() else {}
	var shown_after := 0
	var peaks := [0.0,0.0,0.0]
	var probes := [arc(c,r,0.3),arc(c,r,0.6),arc(c,r,0.95)]
	var at_1s := 0.0
	for f in range(200):
		await frames(1)
		if f < 20 and prop != null and prop.visible: shown_after += 1
		for j in range(probes.size()):
			var size: float = lean_at(probes[j][0],probes[j][1])[2]
			if f == 60: at_1s = maxf(at_1s,size)
			if f >= 170: peaks[j] = maxf(peaks[j],size)
		var here: float = lean_at(watch[0],watch[1])[0]
		follow.back = minf(follow.back,here)
	var published: Vector4 = gust().blow[gust().WAKE_AT]
	print("WAKE ",JSON.stringify({"mid":mid,"follow":{"peak":snappedf(follow.peak,0.01),"swings_back":snappedf(follow.back,0.01)},"prop_shown_frames":[shown,steps],
		"tip_gap_max_m":snappedf(worst_tip,0.01),"gust_ms_max":snappedf(worst_usec/1000.0,0.001),"lean_1s_after":snappedf(at_1s,0.01),"lean_3s_after":peaks,"published_points_after":published.y,"wakes_after":gust().wakes.size()}))
	check("the quill shows through the whole drag (%d of %d frames)" % [shown,steps],shown == steps and bool(mid_hold.prop_shown),[shown,steps])
	check("  its tip stays on the pointer (%.2f m at most)" % worst_tip,worst_tip < 1.0,worst_tip)
	check("  and after release it stays, hovering (%d of 20 frames)" % shown_after,shown_after == 20,shown_after)
	check("a curved drag is one live wake, no gust sent",int(materials.feather_sent.wake) == wakes+1 and gust().gusts.size() == lanes and let_go.get("kind","") == "wake",[materials.feather_sent,gust().gusts.size()-lanes])
	if mid.is_empty(): return
	var behind: Dictionary = mid.behind
	check("  foliage leans at and behind the feather: %s" % str(behind),float(behind[0.5][0]) > 0.3 and float(behind[1.5][0]) > 0.25 and float(behind[3.0][0]) > 0.15,behind)
	check("  along the curve's tangent (under 25° off)",float(behind[0.5][1]) < 25.0 and float(behind[1.5][1]) < 25.0 and float(behind[3.0][1]) < 25.0,behind)
	check("  the feather's heading follows the curve (%.1f° off)" % float(mid.heading_off),float(mid.heading_off) < 20.0,mid.heading_off)
	check("  nothing leans far off the path (%.2f at 7 m, %.2f at 6 m)" % [mid.centre_7m_off,mid.outside_6m_off],float(mid.centre_7m_off) < 0.01 and float(mid.outside_6m_off) < 0.01,mid)
	check("  and only a stir 2 m ahead (%.2f)" % float(mid.ahead_2m),float(mid.ahead_2m) < 0.1,mid.ahead_2m)
	check("  it springs back past rest after the feather (%.2f)" % float(follow.back),float(follow.back) < -0.03,follow)
	check("  leaves ride along the path (%d, %.2f m off it)" % [mid.motes_on_wake,mid.mote_off_path_m],int(mid.motes_on_wake) >= 3 and float(mid.mote_off_path_m) < float(let_go.get("half",3.0))+0.6,mid)
	check("  ribbons lie on the curve (%.2f m off, %d chunks)" % [mid.ribbon_off_path_m,mid.ribbon_chunks],int(mid.ribbon_vertices) > 0 and float(mid.ribbon_off_path_m) < 0.7*float(let_go.get("half",3.0))+0.7 and absf(float(mid.ribbon_uv_max)-float(mid.path_m)) < 0.6,mid)
	check("  the air rides at the feather (a steered local gust)",int(mid.local_gusts) == 1,mid.local_gusts)
	check("let go, the wake dies away (%.2f after 1 s)" % at_1s,at_1s < 0.3,at_1s)
	check("  and is gone after 3 s",peaks.max() < 0.01 and published.y < 1.5 and gust().wakes.is_empty(),[peaks,published,gust().wakes.size()])
	# A slow drag blows gently: the same lean read 0.5 m behind the feather.
	var from := arc(c,r,0.0)
	var slow_start: Vector2 = from[0]
	var slow_way: Vector2 = from[1]
	last = screen(slow_start)
	await hover(last)
	button(last,true)
	await frames(1)
	var slow := 0.0
	for i in range(1,91):
		var p := slow_start+slow_way*3.0*i/90.0
		var s := screen(p)
		motion(s,s-last)
		last = s
		await frames(1)
		if i == 70: slow = float(lean_at(p-slow_way*0.5,slow_way)[0])
	button(last,false)
	await frames(3)
	print("SLOW ",JSON.stringify({"lean_0.5m_behind":snappedf(slow,0.01),"fast":behind[0.5][0],"power":snappedf(float(gust().wakes.back().power),0.01)}))
	check("a slow drag blows gently (%.2f against %.2f fast)" % [slow,float(behind[0.5][0])],slow > 0.05 and slow < float(behind[0.5][0])*0.8,[slow,behind[0.5][0]])
	await frames(180)

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("feather probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-feather-probe-%d/places.json" % Time.get_ticks_usec()
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
	marks = reach.get("marks")
	scene.world_clock.running = false
	check("land clay, the materials tray and the marks exist",clay != null and materials != null and marks != null)
	if clay == null or materials == null or marks == null:
		quit(1)
		return
	roll = materials.roll
	var data := editor.data
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-60)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," hand ",hand != null)
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()

	# --- The roll: the Feather after a divider, and its pocket takes it ---
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var index: int = roll.TOOLS.find("feather")
	check("the roll holds the Feather last, after the Hammer",index == roll.TOOLS.size()-1 and roll.TOOLS[index-1] == "hammer",roll.TOOLS)
	check("  with a divider before it",index in roll.DIVIDER_BEFORE,roll.DIVIDER_BEFORE)
	var gap: float = roll._cell(index).position.y-roll._cell(index-1).end.y
	check("  the divider opens the gap under the Hammer (%.0f px)" % gap,gap >= (roll.GAP+roll.DIVIDER)*roll.ui_scale-1.0,gap)
	check("  built, with its icon",roll.discovered("feather") and str(preload("res://scripts/hud_icons.gd").item("feather").get("label","")) == "Feather · Gust")
	var pocket: Vector2 = roll._cell(index).get_center()
	check("  its pocket hit-tests to it",roll.tool_at(pocket) == "feather",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the Feather",roll.tool == "feather" and clay.tool_id == "feather",[roll.tool,clay.tool_id])

	# --- The prop and the grip ---
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	var tinted := parts.any(func(p: MeshInstance3D) -> bool: return (p.material_override as StandardMaterial3D).albedo_color == Color("cbb994"))
	check("its stand-in quill is built, faceted, in the tint #cbb994",parts.size() >= 3 and (parts[0] as MeshInstance3D).mesh is ArrayMesh and tinted,parts.size())
	check("  leaning -18°",is_equal_approx(clay.tool.prop_tilt(),-18.0),clay.tool.prop_tilt())
	await hover(spot)
	check("the hand grips the Feather over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	if prop != null and prop.visible:
		var lean := rad_to_deg(prop.transform.basis.y.normalized().angle_to(Vector3.UP))
		check("  the quill rides in the shown hand, leaning %.1f°" % lean,absf(lean-18.0) < 0.5,lean)
	else:
		check("  the quill rides only in a shown hand",hand == null or prop.visible == (hand.visible and float(hand.opacity) > 0.3),[prop.visible if prop != null else null])

	# --- At rest: the hotspot ---
	check("at rest the mark is the hotspot",marks.kind == "feather" and marks.shown > 0.99 and marks.node.visible and marks.half.distance_to(Marks.FEATHER_HOTSPOT) < 1e-4,[marks.kind,marks.shown,marks.half,marks.reason])
	check("  faint: line alpha %.2f <= %.2f" % [marks.line_alpha_now(),Marks.FAINT_CAP],faint())

	# --- Swipe: one lane along the swipe, as wide as the pips ---
	var widths := {}
	for level in [1,2,0]:
		materials.set_size(level)
		var want: float = Materials.FEATHER_HALF*float(roll.SIZES[level].scale)
		var result := await swipe(spot+Vector2(-120,0),240.0)
		var g: Dictionary = result[0]
		var seen: Dictionary = result[1]
		var way: Vector2 = result[2]
		widths[level] = float(g.get("half",0.0))
		print("SWIPE ",JSON.stringify({"size":roll.SIZES[level].scale,"kind":g.get("kind",""),"half":snappedf(float(g.get("half",0.0)),0.01),"power":snappedf(float(g.get("power",0.0)),0.01),"path_m":snappedf(float(g.get("dist",0.0)),0.01),"lanes_sent":result[3],"mark":seen.get("kind",""),"mark_half":seen.get("half",Vector2.ZERO),"alpha":snappedf(float(seen.get("alpha",0.0)),0.01)}))
		check("size %.1f: a swipe is one live wake" % roll.SIZES[level].scale,g.get("kind","") == "wake" and materials.feather_last == "wake",[g.get("kind",""),materials.feather_last])
		check("  and sends no lane gust",int(result[3]) == 0,result[3])
		if g.is_empty(): continue
		var off := absf(rad_to_deg((g.heading as Vector2).angle_to(way)))
		check("  along the swipe (%.1f° off)" % off,off < 15.0,[g.heading,way])
		check("  its wake %.1f m either side" % want,absf(float(g.half)-want) < 1e-3,g.half)
		var under: Variant = seen.get("under")
		var off_mark: float = Vector2(seen.centre.x,seen.centre.z).distance_to(under) if under != null and seen.has("centre") else INF
		check("  mid-swipe the mark is the hotspot under the feather (%.2f m off), held %s" % [off_mark,seen.get("holding","")],seen.get("kind","") == "feather" and bool(seen.get("visible",false)) and off_mark < 0.5,seen)
		check("  faint: %.2f" % float(seen.get("alpha",1.0)),float(seen.get("alpha",1.0)) <= Marks.FAINT_CAP+1e-4 and Marks.FILL_ALPHA <= Marks.FAINT_CAP)
		await frames(20)
	check("the pips widen the wake 0.6 / 1 / 1.5",widths.size() == 3 and float(widths[0]) < float(widths[1]) and float(widths[1]) < float(widths[2]),widths)
	materials.set_size(1)
	await wake_checks(at)

	# --- Hold still: a burst at 400 ms, nothing sooner ---
	await hover(spot)
	var none: int = int(materials.feather_sent.none)
	var bursts: int = int(materials.feather_sent.burst)
	button(spot,true)
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5))
	button(spot,false)
	await frames(3)
	check("a still press let go before 400 ms sends nothing",int(materials.feather_sent.none) == none+1 and int(materials.feather_sent.burst) == bursts and not gust().aiming(),materials.feather_sent)
	await hover(spot)
	button(spot,true)
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5))
	var early := {"kind":marks.kind,"shown":marks.shown}
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5)+6)
	var first := {"kind":marks.kind,"radius":marks.half.x,"alpha":marks.line_alpha_now(),"holding":reach.holding}
	await frames(60)
	var grown := {"kind":marks.kind,"radius":marks.half.x,"alpha":marks.line_alpha_now()}
	var half: float = materials.feather_half()
	print("HOLD ",JSON.stringify({"before":early,"at_0.5s":first,"at_1.5s":grown,"lane_half":half,"promise":gust().promise()}))
	check("held still, the hotspot stays until 400 ms",early.kind == "feather" and float(early.shown) > 0.99,early)
	check("  then the burst ring (held %s), from the wake's half-width" % first.holding,first.kind == "feather_burst" and float(first.radius) >= half-1e-3 and float(first.radius) < half*1.2,first)
	check("  growing to 1.5x it",grown.kind == "feather_burst" and float(grown.radius) > float(first.radius) and float(grown.radius) <= half*Materials.FEATHER_RING+1e-3,grown)
	check("  faint: %.2f" % float(grown.alpha),float(grown.alpha) <= Marks.FAINT_CAP+1e-4)
	button(spot,false)
	await frames(3)
	check("let go, it bursts",int(materials.feather_sent.burst) == bursts+1 and materials.feather_last == "burst" and gust().gusts.back().kind == "burst",[materials.feather_sent,materials.feather_last])
	await frames(30)

	# --- No land changed, no undo step ---
	check("the Feather adds no undo step",data._undo.size() == undo0,[undo0,data._undo.size()])
	check("and leaves the heights as they were",data.heights == base)

	# --- Taking a material gives back the Hand ---
	for i in range(60):
		if materials.tray.shown > 0.99: break
		await process_frame
	# The case fans a group out under a resting pointer (scripts/materials_tray.gd).
	materials.tray.pointer_override = materials.tray.compartment_centre("stone")
	for i in range(120):
		if materials.tray.showing("stone"): break
		await process_frame
	await click(materials.tray.specimen_centre("stone"))
	materials.tray.pointer_override = null
	check("taking a stone puts the Feather back",materials.held == "stone" and roll.tool == "hand" and clay.tool_id == "hand",[materials.held,roll.tool,clay.tool_id])
	await key(KEY_ESCAPE)
	check("Esc puts the stone down",materials.held.is_empty())

	# --- Dragging wind from the sky onto the land puts the Feather in hand ---
	var sky := empty_sky()
	check("found empty sky",sky != Vector2.INF,sky)
	if sky != Vector2.INF:
		var wakes: int = int(materials.feather_sent.wake)
		# Counted as they go: the array also retires settled gusts.
		var went := []
		gust().sent.connect(func(g: Dictionary) -> void: went.append(g.kind))
		await hover(sky)
		button(sky,true)
		await frames(1)
		var p := sky
		for i in range(12):
			var step := (spot-sky)/12.0
			p += step
			motion(p,step)
			await frames(1)
			if gust().aiming(): break
		await frames(2)
		check("dragged from the sky onto the land, the Feather is in hand",roll.tool == "feather" and clay.tool_id == "feather" and gust().aiming(),[roll.tool,clay.tool_id,gust().aiming()])
		check("  its pocket pressed in the roll",roll.tool == "feather" and not roll.material_held,[roll.tool,roll.material_held])
		check("  the wake is the Feather's width",gust().aiming() and absf(float(gust().promise().get("half",0.0))-materials.feather_half()) < 1e-3,gust().promise().get("half",0.0))
		var on := p
		for i in range(6):
			on += Vector2(0,20)
			motion(on,Vector2(0,20))
			await frames(1)
		check("  the drag on is a wake, the hotspot under the feather",gust().promise().get("kind","") == "wake" and marks.kind == "feather" and marks.node.visible,[gust().promise().get("kind",""),marks.kind,marks.reason])
		button(on,false)
		await frames(3)
		check("  let go, the one wake dies away, nothing sent",went == ["wake"] and not gust().aiming() and not gust().wakes.back().live,went)
		check("  and the Feather stays in hand",roll.tool == "feather" and int(materials.feather_sent.wake) == wakes,roll.tool)
		await frames(20)

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc puts the Feather back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop gives way to the Modeller's",not is_instance_valid(prop) and clay.get("_prop") is Node3D and (clay.get("_prop") as Node3D).find_children("*","MeshInstance3D",true,false).size() >= 3)
	await hover(spot)
	check("the hand hovers ready to pinch again",hand == null or hand.reach_gesture == "pinch",hand.reach_gesture if hand != null else "")
	check("still no undo step, heights unchanged",data._undo.size() == undo0 and data.heights == base)
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
