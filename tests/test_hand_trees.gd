extends SceneTree
## suite: serial
## Trees painted from the hand (scripts/tree_paint.gd, docs/scenic/handful.md
## "Tree seed"). Headless, in the cozy scene with the hand scheme's real input:
##
## - The tree slots are painted, not sown as a veil, and say so.
## - A tap with oak in hand sets one oak where it is pressed, at once, marked
##   hand work, in one undo step; no veil.
## - A drag paints a stand of that kind under the brush and nowhere else, its
##   trees at least GAP apart, shown with no refresh while the button is
##   down; a second pass over it fills it in.
## - None on live water.
## - Shift-drag thins the trees under the brush; undo brings them back.
##   perl -e 'alarm 600; exec @ARGV' Godot --headless --path . \
##     --script res://tests/test_hand_trees.gd
const TreePaint = preload("res://scripts/tree_paint.gd")
const Materials = preload("res://scripts/hand_materials.gd")
const Emergence = preload("res://scripts/emergence.gd")

var failures := 0
## The scene's world: a plain's seed is drawn with randi(), and a random plain
## put the fixed paths on its shore (a press there is the rim's) or left one
## pass's draws short; this one is fixed with the paths well inland.
const WORLD_SEED := 6
## The most a stroke's settle is waited for (ms): its worker sampling took
## over 10 s with several suites running at once.
const SETTLE_MS := 30000
var scene: Node3D
var editor: Node
var reach: Node
var materials: Node

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

## Where `point` (plate) shows on screen: on the ground, or on the live water
## standing over it (a pit's floor can be hidden behind the ground before it,
## so a press aimed at the floor would land there instead).
func screen_of(point: Vector2) -> Vector2:
	var data: NativeTerrainData = editor.data
	var water: float = editor.flow.depth_at(point) if editor.flow != null and editor.flow.ready else 0.0
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights))+water,point.y)))

func button(at: Vector2, pressed: bool, shift := false) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

## Paint `slot` along `path` (plate) over `seconds` through the hand, `passes`
## times back and forth (0 seconds: a tap). {"summary", "drawn",
## "refreshed", "veil"}.
func paint(slot: String, path: Array, seconds: float, shift := false, passes := 1) -> Dictionary:
	var out := {"drawn":0,"refreshed":false,"veil":false}
	check(materials.take(slot) and materials.held == slot,"%s is taken in hand" % slot)
	var start := screen_of(path[0])
	point(start)
	for i in range(20): await process_frame
	button(start,true,shift)
	await process_frame
	check(reach.holding == Materials.PAINT and editor.flower_paint is TreePaint,"A press on the land with %s in hand paints trees" % slot)
	out.drawn = editor.content.paint_preview_count()
	var was := start
	for k in range(passes):
		var began := Time.get_ticks_msec()
		var a: Vector2 = path[0] if k%2 == 0 else path[-1]
		var b: Vector2 = path[-1] if k%2 == 0 else path[0]
		while seconds > 0.0 and (Time.get_ticks_msec()-began)/1000.0 < seconds:
			var t := (Time.get_ticks_msec()-began)/1000.0/seconds
			var at := screen_of(a.lerp(b,clampf(t,0.0,1.0)))
			motion(at,at-was)
			was = at
			await process_frame
			out.drawn = maxi(out.drawn,editor.content.paint_preview_count())
			if int(editor.refresh_pending) > 0: out.refreshed = true
			if editor._handful_holding: out.veil = true
	button(was,false,shift)
	await process_frame
	out.summary = editor.last_paint
	# The settle samples on a worker and publishes when it is done, slower on
	# a loaded machine: wait for it (and the preview it clears), not N frames.
	var waited := Time.get_ticks_msec()
	while (int(editor.refresh_pending) > 0 or editor.content.paint_preview_count() > 0) and Time.get_ticks_msec()-waited < SETTLE_MS: await process_frame
	for i in range(4): await process_frame
	materials.put_back()
	return out

static func trees_of(data: NativeTerrainData, ids: Array) -> Array:
	return data.objects.filter(func(item: Dictionary) -> bool: return int(item.id) in ids)

static func trees_near(data: NativeTerrainData, centre: Vector2, reach_m: float) -> int:
	return data.objects.filter(func(item: Dictionary) -> bool: return str(item.asset) in Emergence.TREES and Vector2(item.x,item.z).distance_to(centre) < reach_m).size()

static func off_path(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(path.size()-1):
		best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1])))
	return best

func run() -> void:
	create_timer(560).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	for seed: String in ["oak","pine","willow"]:
		check(Materials.paints(seed) and Materials.plants_trees(seed) and not Materials.sows(seed),"%s is painted as trees" % seed)
	root.size = Vector2i(1440,900)
	seed(WORLD_SEED)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = OS.get_temp_dir().path_join("zs-hand-trees-%d/places.json" % Time.get_ticks_usec())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	check(editor.active,"The land takes presses")
	scene.world_clock.running = false
	reach = scene.hand_reach
	materials = reach.get("materials")
	if materials == null:
		check(false,"The hand scheme's materials are in the scene")
		quit(1)
		return
	check(materials.take("oak") and materials.hint("land")[1] == Materials.TREE_HINT,"Oak's hint says to plant and paint")
	materials.put_back()
	var data: NativeTerrainData = editor.data
	# Clear ground to paint on: the plain's own trees out of the way.
	data.objects.assign(data.objects.filter(func(item: Dictionary) -> bool: return not str(item.asset) in Emergence.TREES))
	data.objects_revision += 1
	for i in range(60): await process_frame
	while int(editor.refresh_pending) > 0: await process_frame
	var steps: int = data._undo.size()

	# A tap: one oak where it is pressed.
	var spot := Vector2(-2.0,1.0)
	var tap: Dictionary = await paint("oak",[spot],0.0)
	var placed: Array = tap.summary.get("placed",[])
	var oaks := trees_of(data,placed)
	print("tap: %s" % str(tap.summary.get("kinds",{})))
	check(placed.size() == 1 and oaks.size() == 1 and str(oaks[0].asset) == "broadleaf","A tap sets one oak (%d placed)" % placed.size())
	if oaks.size() == 1:
		check(Vector2(oaks[0].x,oaks[0].z).distance_to(spot) < 0.3,"It stands where it was pressed (%.2f m off)" % Vector2(oaks[0].x,oaks[0].z).distance_to(spot))
		check(str(oaks[0].get("source","")) == "hand" and oaks[0].has("born"),"It is hand work and grows in")
	check(tap.drawn > 0,"The tap's own frame shows it")
	check(not tap.veil,"No veil was flicked")
	check(data._undo.size() == steps+1,"One undo step for the tap")
	editor.undo()
	for i in range(4): await process_frame
	check(trees_near(data,spot,1.0) == 0,"Undo takes the tree away")

	# A drag: a stand of pines along the path.
	var path := [Vector2(-6.0,3.0),Vector2(4.0,3.0)]
	var one: Dictionary = await paint("pine",path,1.2)
	var first: Array = one.summary.get("placed",[])
	var pines := trees_of(data,first)
	print("one pass: %d trees %s, refused %d" % [first.size(),str(one.summary.get("kinds",{})),int(one.summary.get("refused",0))])
	check(first.size() >= 5,"One pass paints a stand (%d trees)" % first.size())
	check(pines.all(func(item: Dictionary) -> bool: return str(item.asset) == "tree"),"Every one is a pine")
	check(one.drawn > 0 and not one.refreshed,"They show as they are painted, with no refresh while the button is down")
	var stray := pines.filter(func(item: Dictionary) -> bool: return off_path(Vector2(item.x,item.z),path) > TreePaint.TREE_RADIUS*materials.size_scale()+0.5).size()
	check(stray == 0,"Every tree stands under the brush's path (%d far from it)" % stray)
	var close := 0
	for a: Dictionary in pines:
		for b: Dictionary in pines:
			if int(a.id) < int(b.id) and Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)) < TreePaint.GAP-0.01: close += 1
	check(close == 0,"No two stand nearer than %.1f m (%d pairs)" % [TreePaint.GAP,close])
	var again: Dictionary = await paint("pine",path,1.2,false,2)
	var more: Array = again.summary.get("placed",[])
	print("two more passes: %d more trees" % more.size())
	check(more.size() > 0,"Going over the stand again fills it in (%d more)" % more.size())

	# Shift thins.
	var middle := Vector2(-1.0,3.0)
	var before := trees_near(data,middle,2.5)
	var steps_thin: int = data._undo.size()
	var thinning: Dictionary = await paint("pine",[Vector2(-3.0,3.0),Vector2(1.0,3.0)],1.0,true,3)
	var after := trees_near(data,middle,2.5)
	print("thinning: %d to %d in the middle, %d taken" % [before,after,thinning.summary.get("removed",[]).size()])
	check(after < before and thinning.summary.get("placed",[1]).is_empty(),"Shift-drag thins the trees under the brush (%d to %d)" % [before,after])
	check(data._undo.size() == steps_thin+1,"The thinning is one undo step")
	editor.undo()
	for i in range(4): await process_frame
	check(trees_near(data,middle,2.5) == before,"Undo brings the thinned trees back")

	# None on water.
	var wet := Vector2(5.0,-4.0)
	if editor.flow != null and editor.flow.ready:
		# A pit there, so the water stands.
		var dug := data.heights.duplicate()
		for i in range(dug.size()):
			var d: float = (data.points[i] as Vector2).distance_to(wet)
			dug[i] -= 1.2*(1.0-smoothstep(1.0,3.0,d))
		data.heights = dug
		await editor.refresh(self)
		editor.flow.taps["test"] = [wet.x,wet.y,1.5,6.0]
		for i in range(240): await process_frame
		editor.flow.taps.erase("test")
		for i in range(30): await process_frame
		var wet_tap: Dictionary = await paint("willow",[wet],0.0)
		var depth: float = editor.flow.depth_at(wet)
		check(depth >= 0.1,"The pit holds water (%.2f m)" % depth)
		check(wet_tap.summary.get("placed",[]).is_empty(),"No tree is set in standing water (%.2f m deep, %d placed)" % [depth,wet_tap.summary.get("placed",[]).size()])
	print("Hand trees: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)
