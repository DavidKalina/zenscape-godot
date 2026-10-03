extends SceneTree
## Headless probe of the Ravine's drawn line (id `wire`,
## scripts/clay_tools/wire.gd; docs/design/tools/PLAN.md "The roll, revised")
## on the cozy worlds scene, driving the clay's own press, pull and release
## along plate paths. Each drawing is one undo step that one undo takes back
## exactly. Checks:
## - An open line: the path is cut down into a gorge.
## - A closed loop: a level basin inside the outline, the outline's outside
##   untouched; the watering can's gush fills it.
## (Its Range, Hill, Trees and Flowers modes were removed on 2026-10-02.)
##   perl -e 'alarm 600; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_wire_draw.gd -- --no-title --no-rain-runoff
const Wire = preload("res://scripts/clay_tools/wire.gd")

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

## Draw `path` (plate points, a few metres apart) with the Ravine:
## press at its start, pull through points every 0.3 m along it, let go, and
## wait for the build to run and settle. {"base", "undo0", "drawn"}.
func draw(path: Array) -> Dictionary:
	var base := editor.data.heights.duplicate()
	var undo0: int = editor.data._undo.size()
	check(clay.press(screen(path[0])),"The press takes")
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

func undo_exact(stroke: Dictionary, what: String) -> void:
	check(editor.data._undo.size() == int(stroke.undo0)+1,"%s is one undo step (%d)" % [what,editor.data._undo.size()-int(stroke.undo0)])
	editor.undo()
	await settled()
	check(editor.data.heights == stroke.base,"one undo takes the %s back exactly" % what)

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
	create_timer(560).timeout.connect(func() -> void: push_error("Ravine draw probe timed out"); quit(2))
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
	check(clay != null and clay.set_tool("wire"),"The Ravine is taken")
	check(clay.tool.modes().is_empty() and clay.tool.press_kind() == "drag","It has no fan; a press is a drag at once")

	# An open line: a gorge.
	var line := [Vector2(-6.0,2.0),Vector2(0.0,3.0),Vector2(5.0,2.0)]
	var gorge := await draw(line)
	var cut := change(gorge,line,0.6,4.0)
	print("gorge: %s" % str(cut))
	check(cut.down < -1.5 and cut.up < 0.01,"Gorge: cut along the path (%.2f m)" % cut.down)
	await undo_exact(gorge,"gorge")

	# A loop: a lake basin.
	var lake := circle(Vector2(0.0,1.0),5.0)
	var basin := await draw(lake)
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

	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
