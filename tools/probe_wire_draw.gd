extends SceneTree
## Headless probe of the Wire's drawing modes (scripts/clay_tools/wire.gd,
## 2026-10-02) on the cozy worlds scene, driving the clay's own press, pull
## and release along plate paths. Each drawing is one undo step that one undo
## takes back exactly. Checks:
## - Gorge, open: the path is cut down (as before).
## - Gorge, a closed loop: a level basin inside the outline, the outline's
##   outside untouched; the watering can's gush fills it.
## - Range: peaks raised along a bent path, both legs, nothing far off it.
## - Hill: a soft ridge along the path, lower than the range; a loop raises
##   one hill, highest in its middle.
## - Trees: a row along the path, about one every Wire.TREE_STEP m.
## - Flowers: a border of flowers along the path.
##   perl -e 'alarm 600; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_wire_draw.gd -- --no-title --no-rain-runoff
const Wire = preload("res://scripts/clay_tools/wire.gd")
const Emergence = preload("res://scripts/emergence.gd")
const FlowerPaint = preload("res://scripts/flower_paint.gd")

var scene: Node3D
var editor: NativeChunkEditor
var clay: Node
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func height(p: Vector2, heights := PackedFloat32Array()) -> float:
	return float(editor.data.sample(p,editor.data.heights if heights.is_empty() else heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.land_settling or editor.refresh_pending > 0 or clay.state != 0
		quiet = 0 if busy else quiet+1

## Draw `path` (plate points, a few metres apart) with the wire in `mode`:
## press at its start, pull through points every 0.3 m along it, let go, and
## wait for the build to run and settle. {"base", "undo0", "drawn"}.
func draw(mode: String, path: Array) -> Dictionary:
	clay.tool.mode = mode
	var base := editor.data.heights.duplicate()
	var undo0: int = editor.data._undo.size()
	check(clay.press(screen(path[0])),"%s: the press takes" % mode)
	await process_frame
	for j in range(path.size()-1):
		var a: Vector2 = path[j]
		var b: Vector2 = path[j+1]
		var steps := maxi(1,ceili(a.distance_to(b)/0.3))
		for k in range(1,steps+1):
			clay.pull(screen(a.lerp(b,float(k)/steps)))
			await process_frame
	var drawn: PackedVector2Array = clay.tool.drawn()
	clay.release(screen(path[-1]))
	await settled()
	return {"base":base,"undo0":undo0,"drawn":drawn}

func undo_exact(stroke: Dictionary, what: String, objects := -1) -> void:
	check(editor.data._undo.size() == int(stroke.undo0)+1,"%s is one undo step (%d)" % [what,editor.data._undo.size()-int(stroke.undo0)])
	editor.undo()
	await settled()
	check(editor.data.heights == stroke.base and (objects < 0 or editor.data.objects.size() == objects),"one undo takes the %s back exactly" % what)

static func circle(centre: Vector2, radius: float, count := 24) -> Array:
	var out := []
	for k in count+1: out.append(centre+Vector2.from_angle(TAU*k/count)*radius)
	return out

static func off_path(path: Array, p: Vector2) -> float:
	var best := INF
	for j in range(path.size()-1): best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1])))
	return best

## The most any point within `near` m of `path` rose (or, negative, sank),
## and the most any point beyond `far` m from it moved at all.
func change(stroke: Dictionary, path: Array, near: float, far: float) -> Dictionary:
	var data := editor.data
	var up := 0.0
	var down := 0.0
	var stray := 0.0
	for i in range(data.points.size()):
		var d := data.heights[i]-float(stroke.base[i])
		var off := off_path(path,data.points[i])
		if off <= near:
			up = maxf(up,d)
			down = minf(down,d)
		elif off >= far: stray = maxf(stray,absf(d))
	return {"up":up,"down":down,"stray":stray}

func run() -> void:
	create_timer(560).timeout.connect(func() -> void: push_error("Wire draw probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wire-draw-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	clay = scene.get("land_clay")
	scene.world_clock.running = false
	if not editor.active: scene.set_building(false)
	check(clay != null and clay.set_tool("wire"),"The wire is taken")
	var modes: Array = clay.tool.modes().map(func(spec: Dictionary) -> String: return spec.id)
	check(modes == ["gorge","range","hill","trees","flowers","slice"],"Its fan: %s" % str(modes))
	for id: String in modes: check(not preload("res://scripts/hud_icons.gd").item("wire_"+id).is_empty(),"wire_%s has an icon" % id)
	# The plain's own trees out of the way, so the plants have room.
	editor.data.objects.assign(editor.data.objects.filter(func(item: Dictionary) -> bool: return not str(item.asset) in Emergence.TREES))
	editor.data.objects_revision += 1
	await settled()

	# Gorge, open: as before.
	var line := [Vector2(-6.0,2.0),Vector2(0.0,3.0),Vector2(5.0,2.0)]
	var gorge := await draw("gorge",line)
	var cut := change(gorge,line,0.6,4.0)
	print("gorge: %s" % str(cut))
	check(cut.down < -1.5 and cut.up < 0.01,"Gorge: cut along the path (%.2f m)" % cut.down)
	await undo_exact(gorge,"gorge")

	# Gorge, a loop: a lake basin.
	var lake := circle(Vector2(0.0,1.0),5.0)
	var basin := await draw("gorge",lake)
	check((basin.drawn as PackedVector2Array)[0] == (basin.drawn as PackedVector2Array)[-1],"A loop's drawn path closes")
	var middle: float = height(Vector2(0.0,1.0))-height(Vector2(0.0,1.0),basin.base)
	var floor_spread := 0.0
	var floor_at := height(Vector2(0.0,1.0))
	for p: Vector2 in [Vector2(-1.5,1.0),Vector2(1.5,1.0),Vector2(0.0,-0.5),Vector2(0.0,2.5)]: floor_spread = maxf(floor_spread,absf(height(p)-floor_at))
	var outside := change(basin,circle(Vector2(0.0,1.0),8.5),1.5,99.0)
	print("basin: middle %.2f m, floor spread %.3f m, ring outside moved %.3f" % [middle,floor_spread,outside.down])
	check(middle < -1.5,"Gorge loop: the middle sinks into a basin (%.2f m)" % middle)
	check(floor_spread < 0.25,"Its floor is level (%.3f m)" % floor_spread)
	check(absf(outside.down) < 0.01 and outside.up < 0.01,"Outside the outline is untouched")
	if editor.flow != null and editor.flow.ready:
		var screen_at := screen(Vector2(0.0,1.0))
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = screen_at
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		editor.can_in_hand(screen_at,1.0,false)
		var held := 0.0
		while held < 40.0 and editor.flow.depth_at(Vector2(0.0,1.0)) < absf(middle)*0.9:
			for i in range(60): await process_frame
			held += 1.0
		editor.can.release()
		print("can over the basin: %.0f s held, %.2f m deep, gush %.2f" % [held,editor.flow.depth_at(Vector2(0.0,1.0)),editor.can.gush])
		check(editor.flow.depth_at(Vector2(0.0,1.0)) >= absf(middle)*0.9,"The can fills the drawn lake to its brim within 40 s (%.0f s)" % held)
		editor.flow.drain(Vector2(0.0,1.0),8.0)
	await undo_exact(basin,"basin")

	# Range along an L.
	var bend := [Vector2(-6.0,-1.0),Vector2(0.0,-1.0),Vector2(0.0,5.0)]
	var range_stroke := await draw("range",bend)
	var leg_a := change(range_stroke,[Vector2(-5.0,-1.0),Vector2(-2.0,-1.0)],0.6,99.0)
	var leg_b := change(range_stroke,[Vector2(0.0,2.0),Vector2(0.0,4.0)],0.6,99.0)
	var whole := change(range_stroke,bend,1.0,Wire.RANGE_HALF*1.6)
	print("range: legs %.2f and %.2f m, highest %.2f, stray %.3f" % [leg_a.up,leg_b.up,whole.up,whole.stray])
	check(leg_a.up > 2.5 and leg_b.up > 2.5,"Range: peaks raised along both legs (%.2f, %.2f m)" % [leg_a.up,leg_b.up])
	check(whole.up > 4.0 and whole.up <= Wire.RANGE_HEIGHT+0.01,"Its highest summit (%.2f m)" % whole.up)
	check(whole.stray < 0.01 and whole.down > -0.01,"Nothing far off the path moves, nothing sinks")
	await undo_exact(range_stroke,"range")

	# Hill along a line, then round a loop.
	var hill := await draw("hill",line)
	var ridge := change(hill,line,0.6,Wire.HILL_HALF+0.8)
	print("hill: %s" % str(ridge))
	check(ridge.up > 1.4 and ridge.up < Wire.HILL_HEIGHT+0.01 and ridge.stray < 0.01,"Hill: a soft ridge along the path (%.2f m)" % ridge.up)
	await undo_exact(hill,"hill")
	var ring := circle(Vector2(0.0,1.0),5.0)
	var mound := await draw("hill",ring)
	var top: float = height(Vector2(0.0,1.0))-height(Vector2(0.0,1.0),mound.base)
	var shoulder: float = height(Vector2(3.0,1.0))-height(Vector2(3.0,1.0),mound.base)
	print("mound: middle %.2f m, 3 m out %.2f m" % [top,shoulder])
	check(top > 1.2 and top > shoulder and shoulder > 0.0,"Hill loop: one hill filling the outline, highest in its middle (%.2f, %.2f m)" % [top,shoulder])
	await undo_exact(mound,"mound")

	# A row of trees.
	var objects: int = editor.data.objects.size()
	var row := [Vector2(-6.0,3.0),Vector2(6.0,3.0)]
	var trees := await draw("trees",row)
	var planted: Array = editor.data.objects.slice(objects).filter(func(item: Dictionary) -> bool: return str(item.asset) in Emergence.TREES)
	var wander := 0.0
	for item: Dictionary in planted: wander = maxf(wander,off_path(row,Vector2(item.x,item.z)))
	print("trees: %d %s, %.2f m off the line at most" % [planted.size(),str(planted.map(func(item: Dictionary) -> String: return str(item.asset))),wander])
	check(planted.size() >= 3 and planted.size() <= ceili(12.0/Wire.TREE_STEP)+1,"Trees: a row along the path (%d)" % planted.size())
	check(wander <= Wire.TREE_WANDER+0.01,"Each on the line (%.2f m off)" % wander)
	check(trees.base == editor.data.heights,"No ground moved")
	await undo_exact(trees,"row of trees",objects)

	# A border of flowers.
	var border := await draw("flowers",row)
	var flowers: Array = editor.data.objects.slice(objects).filter(func(item: Dictionary) -> bool: return FlowerPaint.is_flower(str(item.asset)))
	var spread := 0.0
	for item: Dictionary in flowers: spread = maxf(spread,off_path(row,Vector2(item.x,item.z)))
	print("flowers: %d, %.2f m off the line at most" % [flowers.size(),spread])
	check(flowers.size() >= 30,"Flowers: a border along the path (%d)" % flowers.size())
	check(spread <= FlowerPaint.RADIUS*Wire.FLOWER_SIZE+0.3,"A narrow one (%.2f m off)" % spread)
	await undo_exact(border,"border of flowers",objects)
	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
