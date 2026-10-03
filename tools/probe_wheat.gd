extends SceneTree
## Headless probe of wheat (docs/scenic/wheat.md): the crop painted from the
## hand like the flowers (scripts/flower_paint.gd, FlowerSowing SLOTS "wheat").
##
## On a flat plate: a stroke paints wheat and only wheat under the brush, in
## rows square to the plate, hand work, one undo step, the ground warmed
## under it; Shift thins it (a pass takes some, passes clear it, undo brings
## it back); one undo takes a stroke back whole; it saves and reopens as it
## was; a field-scale stroke stays cheap a frame, and every clump is one
## instance of one mesh. Its wiring: tray, icon, palette, pluck, trash can,
## the ripening material.
##
## In the cozy scene, through real input: a wheat stroke shows as it is
## painted and settles in one undo step; Shift-drag thins; undo; a
## Shift-press plucks a clump (one undo step, undo brings it back); the trash
## can sweeps it (one undo step, undo brings it back); the world saves and
## reopens with it.
##   godot --headless --path . -s res://tools/probe_wheat.gd [-- --only=unit|scene]
const FlowerPaint = preload("res://scripts/flower_paint.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Kit = preload("res://scripts/meadow_flower_mesh.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Materials = preload("res://scripts/hand_materials.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Reach = preload("res://scripts/hand_reach.gd")
const Trash = preload("res://scripts/clay_tools/trash.gd")
const SceneLook = preload("res://scripts/scene_look.gd")

var failures: Array[String] = []
var only := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: print("FAIL timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if only.is_empty() or only == "unit":
		wiring()
		painting()
		field()
	if only.is_empty() or only == "scene":
		await in_scene()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

# --- On a flat plate ------------------------------------------------------------------

func _flat_data() -> NativeTerrainData:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	source.free()
	return data

## One stroke of `slot` along `path` at `speed` m/s, `passes` times back and
## forth, the brush `size` times its own, thinning when `thinning`: its
## summary, with "changed" (one undo step), "frame_usec" (the worst frame's
## painting) and "stroke".
func paint_on(data: NativeTerrainData, slot: String, path: Array, speed := 3.0, passes := 1, size := 1.0, thinning := false, salt := 1) -> Dictionary:
	var stroke = FlowerPaint.new(FlowerSowing.new(data,slot,4242),size,thinning,salt)
	data.begin_stroke()
	var worst := 0
	stroke.press(path[0])
	for k in range(passes):
		var leg: Array = path.duplicate()
		if k%2 == 1: leg.reverse()
		for i in range(leg.size()-1):
			var a: Vector2 = leg[i]
			var b: Vector2 = leg[i+1]
			var frames := maxi(1,ceili(a.distance_to(b)/(speed/60.0)))
			for f in range(1,frames+1):
				var began := Time.get_ticks_usec()
				stroke.stroke(a.lerp(b,float(f)/frames),1.0/60.0)
				worst = maxi(worst,Time.get_ticks_usec()-began)
	var summary: Dictionary = stroke.finish()
	summary.changed = data.end_stroke()
	summary.frame_usec = worst
	summary.stroke = stroke
	return summary

func _wheat(data: NativeTerrainData) -> Array:
	return data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "wheat")

static func near(data: NativeTerrainData, centre: Vector2, reach: float) -> int:
	return data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "wheat" and Vector2(item.x,item.z).distance_to(centre) < reach).size()

func wiring() -> void:
	var ids: Array = Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id)
	check("wheat" in ids and ids.find("wheat") == ids.find("sunflower")+1,"Wheat has a tray specimen, after the sunflower")
	check(FlowerSowing.has("wheat") and Materials.paints("wheat") and not Materials.sows("wheat"),"Wheat is painted under the brush, as the flowers are")
	var item := Icons.item("wheat")
	check(not item.is_empty() and str(item.label) == "Wheat · Field" and Icons.texture("wheat","icon",44.0) != null,"Wheat has its faceted icon and name (%s)" % item.get("label",""))
	check(Palette.SEEDS.any(func(entry: Array) -> bool: return entry[0] == "wheat"),"Wheat is in the command palette")
	check(Reach.pluckable("wheat"),"A Shift-press plucks wheat, as it plucks a flower")
	check(Trash.takes("wheat") and Trash.takes("wheat",true),"The trash can takes wheat, Shift or not (it is small stuff)")
	check(FlowerPaint.is_flower("wheat"),"Wheat thins under Shift as the flowers do")
	check("wheat" in NativeTerrainData.ASSETS and MeadowTypes.asset("wheat") == "wheat","Wheat is its own asset, saved by name")
	var mesh: ArrayMesh = Kit.mesh("wheat")
	var triangles: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	var material: ShaderMaterial = mesh.surface_get_material(0)
	print("wheat clump: %d triangles, %.2f m tall" % [triangles,mesh.get_aabb().end.y])
	check(triangles <= 300,"A clump of five straws is cheap (%d triangles)" % triangles)
	check(material.get_shader_parameter("flower_ripen") == true and material.get_shader_parameter("flower_heads") == true and material.get_shader_parameter("sway_enabled") == true,"Its material sways with the flowers and ripens with the year")
	check(SceneLook.leaf_season("wheat:meadow-flower-wheat") == Vector4.ZERO,"No autumn paint or die-back over it: it ripens and is cut its own way")
	check(not Kit.casts_shadow("wheat"),"A field casts no per-clump shadows (cost)")

func painting() -> void:
	var radius := FlowerPaint.RADIUS
	var leak := FlowerPaint.CELL*1.5
	var data := _flat_data()
	var path := [Vector2(-5.0,0.0),Vector2(5.0,0.0)]
	var one: Dictionary = paint_on(data,"wheat",path,3.0,2)
	var wheat := _wheat(data)
	var meadow: RefCounted = one.stroke.sowing.meadow
	var outside := wheat.filter(func(w: Dictionary) -> bool: return absf(float(w.z)) > radius+leak or absf(float(w.x)) > 5.0+radius+leak).size()
	var rowed := wheat.filter(func(w: Dictionary) -> bool: return meadow.on_row(Vector2(w.x,w.z),"wheat")).size()
	var core := wheat.filter(func(w: Dictionary) -> bool: return absf(float(w.z)) < 0.6 and absf(float(w.x)) < 4.0).size()/(8.0*1.2)
	print("two wheat passes, 10 m: %d clumps %s, core %.1f clumps a m² (%.0f straws), %d cells washed, rows along %s" % [one.placed.size(),str(one.kinds),core,core*5.0,one.washed,str(meadow._row)])
	check(one.placed.size() >= 100 and wheat.size() == one.placed.size() and data.objects.size() == wheat.size(),"A stroke paints wheat and only wheat (%d clumps)" % wheat.size())
	check(outside == 0,"Every clump stands under the brush (%d outside)" % outside)
	check(rowed == wheat.size(),"Every clump stands on its rows (%d of %d)" % [rowed,wheat.size()])
	check(meadow._row in [Vector2.RIGHT,Vector2.DOWN],"The rows run square to the plate's sides (%s)" % str(meadow._row))
	check(core >= 8.0,"The patch is dense at its middle (%.1f clumps a m²)" % core)
	check(one.changed and wheat.all(func(w: Dictionary) -> bool: return w.get("source") == "hand"),"One undo step, and the wheat is hand work")
	check(int(one.washed) > 0,"The ground under the patch is warmed toward stubble gold (%d cells)" % one.washed)
	# Rows read as rows: across them, the furrows between hold few clumps.
	var across := Vector2(-meadow._row.y,meadow._row.x)
	var bins := PackedInt32Array()
	bins.resize(10)
	for w: Dictionary in wheat:
		var f := fposmod(across.dot(Vector2(w.x,w.z))/0.5,1.0)
		bins[mini(int(f*10.0),9)] += 1
	print("clumps across a row, by tenth of its 0.5 m: %s" % str(bins))
	check(bins[0]+bins[9] <= wheat.size()*0.05,"Clear furrows run between the rows (%d of %d clumps in the furrows' middle fifth)" % [bins[0]+bins[9],wheat.size()])
	# Undo takes the stroke back whole.
	data.undo()
	check(_wheat(data).is_empty(),"One undo takes the whole stroke back")
	data.redo()
	check(_wheat(data).size() == wheat.size(),"Redo brings it again")

	# Shift thins: a pass takes some, passes clear it, nothing outside; undo.
	var thinned := _flat_data()
	paint_on(thinned,"wheat",path,3.0,4)
	var before := near(thinned,Vector2.ZERO,0.6)
	var aside := thinned.objects.filter(func(w: Dictionary) -> bool: return absf(float(w.x)) > 2.0+radius+leak).size()
	var thin_path := [Vector2(-2.0,0.0),Vector2(2.0,0.0)]
	var first: Dictionary = paint_on(thinned,"wheat",thin_path,3.0,1,1.0,true)
	var after_one := near(thinned,Vector2.ZERO,0.6)
	paint_on(thinned,"wheat",thin_path,3.0,3,1.0,true)
	var after_more := near(thinned,Vector2.ZERO,0.6)
	var aside_after := thinned.objects.filter(func(w: Dictionary) -> bool: return absf(float(w.x)) > 2.0+radius+leak).size()
	print("thinning the middle: %d, one pass %d, four %d (%d taken in the first)" % [before,after_one,after_more,first.removed.size()])
	check(after_one < before*0.75 and after_one > 0,"Shift thins: one pass takes some (%d of %d left)" % [after_one,before])
	check(after_more <= before*0.05,"Going over it clears it (%d left)" % after_more)
	check(aside_after == aside,"Thinning touches nothing outside the brush (%d, %d)" % [aside,aside_after])
	check(first.placed.is_empty(),"Thinning places nothing")
	thinned.undo()
	check(near(thinned,Vector2.ZERO,0.6) == after_one,"One undo brings a thinning stroke's wheat back")

	# Saves: ordinary object records, reopened as they were.
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))),"A world with painted wheat saves and reopens")
	var same := reopened.objects.size() == data.objects.size()
	for i in range(mini(reopened.objects.size(),data.objects.size())):
		var a: Dictionary = data.objects[i].duplicate()
		a.erase("born")
		if JSON.stringify(a) != JSON.stringify(reopened.objects[i]): same = false
	check(same and reopened.tint == data.tint and _wheat(reopened).size() == wheat.size(),"Its wheat and the warmed ground reopen as they were (%d clumps)" % _wheat(reopened).size())
	# The ground decides, as for flowers: none on water.
	var wet := _flat_data()
	wet.ponds.append({"x":0.0,"z":0.0,"level":0.4})
	var drowned: Dictionary = paint_on(wet,"wheat",[Vector2(-0.4,0.0),Vector2(0.4,0.0)],1.0,3,0.6)
	check(drowned.placed.is_empty(),"No wheat on water (%d)" % drowned.placed.size())

## A field: a 10 m by 8 m patch painted in one stroke, back and forth with the
## wide brush. Its frames stay cheap, and every clump draws as one instance
## of the one wheat mesh (GardenView batches a part per kind).
func field() -> void:
	var data := _flat_data()
	var path := []
	for k in range(5):
		var z := -4.0+2.0*k
		path.append(Vector2(-5.0 if k%2 == 0 else 5.0,z))
		path.append(Vector2(5.0 if k%2 == 0 else -5.0,z))
	var began := Time.get_ticks_usec()
	var made: Dictionary = paint_on(data,"wheat",path,4.0,2,1.5)
	var took := (Time.get_ticks_usec()-began)/1000.0
	var clumps := _wheat(data).size()
	var triangles: int = Kit.mesh("wheat").surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	var sampled := preload("res://scripts/garden_instance_samples.gd").build(data,{"wheat":["meadow-flower-wheat"]},{"meadow-flower-wheat":Transform3D.IDENTITY},{})
	var batch: int = sampled.transforms.get("meadow-flower-wheat",[]).size()
	print("field 10 x 8 m: %d clumps (%d straws, %.1f clumps a m²), %d triangles before distance thinning; stroke %.0f ms, worst frame %.2f ms; finish %d cells washed" % [clumps,clumps*5,clumps/80.0,clumps*triangles,took,made.frame_usec/1000.0,made.washed])
	check(clumps >= 600,"A field-scale patch (%d clumps)" % clumps)
	check(made.frame_usec < 16000,"Painting a field stays under a frame's budget (worst %.2f ms)" % (made.frame_usec/1000.0))
	check(batch == clumps,"Every clump is one instance in the wheat batch (%d of %d)" % [batch,clumps])

# --- In the cozy scene ---------------------------------------------------------------

var scene: Node3D
var editor: Node
var reach: Node
var materials: Node
var clay: Node

func screen_of(p: Vector2) -> Vector2:
	var data: NativeTerrainData = editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,float(data.sample(p,data.heights)),p.y)))

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

func frames(count: int) -> void:
	for i in range(count): await process_frame

func settle() -> void:
	var began := Time.get_ticks_msec()
	while int(editor.refresh_pending) > 0 and Time.get_ticks_msec()-began < 10000: await process_frame
	await frames(4)

## Paints wheat along `path` (plate) over `seconds` through the hand.
func paint(path: Array, seconds: float, shift := false) -> Dictionary:
	var out := {"drawn":0,"refreshed":false}
	check(materials.take("wheat") and materials.held == "wheat","Wheat is taken in hand")
	var start := screen_of(path[0])
	point(start)
	await frames(20)
	button(start,true,shift)
	await process_frame
	check(reach.holding == Materials.PAINT and editor.flower_paint != null,"A press on the land with wheat in hand paints%s" % (" (Shift)" if shift else ""))
	var began := Time.get_ticks_msec()
	var was := start
	while (Time.get_ticks_msec()-began)/1000.0 < seconds:
		var t := (Time.get_ticks_msec()-began)/1000.0/maxf(seconds,0.001)
		var at := screen_of(Vector2(path[0]).lerp(path[-1],clampf(t,0.0,1.0)))
		motion(at,at-was)
		was = at
		await process_frame
		out.drawn = maxi(out.drawn,editor.content.paint_preview_count())
		if int(editor.refresh_pending) > 0: out.refreshed = true
	button(was,false,shift)
	await process_frame
	out.summary = editor.last_paint
	await settle()
	materials.put_back()
	return out

func has(id: int) -> bool:
	return editor.data._object_index(id) >= 0

func in_scene() -> void:
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-wheat-probe-%d/places.json" % Time.get_ticks_usec()
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
	clay = scene.get("land_clay")
	check(materials != null and clay != null,"The hand scheme's materials and clay are in the scene")
	if materials == null or clay == null: return
	var data: NativeTerrainData = editor.data
	await frames(60)
	await settle()
	var steps: int = data._undo.size()
	var path := [Vector2(-4.0,3.0),Vector2(3.0,3.0)]
	var stroke: Dictionary = await paint(path,1.2)
	var placed: Array = stroke.summary.get("placed",[])
	print("scene wheat stroke: %d clumps %s; preview drew up to %d" % [placed.size(),str(stroke.summary.get("kinds",{})),stroke.drawn])
	# One quick pass lays a loose patch (its count varies with the frames the
	# headless run gets); the flat-plate checks above measure its density.
	check(placed.size() >= 30 and int(stroke.summary.get("kinds",{}).get("wheat",0)) == placed.size(),"A wheat stroke paints a wheat patch (%d clumps)" % placed.size())
	check(stroke.drawn > 0 and not stroke.refreshed,"Wheat shows as it is painted, with no refresh while the button is down")
	check(data._undo.size() == steps+1,"One undo step for the stroke (%d)" % (data._undo.size()-steps))
	check(editor.content.paint_preview_count() == 0,"Once settled the land's own batches draw it")
	# Shift thins it; undo brings it back.
	var before := near(data,Vector2(0.0,3.0),1.0)
	var thinning: Dictionary = await paint([Vector2(-1.0,3.0),Vector2(1.0,3.0)],0.8,true)
	var after := near(data,Vector2(0.0,3.0),1.0)
	print("scene thinning: %d to %d in the middle, %d taken" % [before,after,thinning.summary.get("removed",[]).size()])
	check(after < before and data._undo.size() == steps+2,"Shift-drag thins the wheat under the brush, its own undo step (%d to %d)" % [before,after])
	editor.undo()
	await settle()
	check(near(data,Vector2(0.0,3.0),1.0) == before,"Undo brings the thinned wheat back")
	# A Shift-press plucks one clump: one undo step, undo brings it back.
	var standing := placed.filter(func(id: int) -> bool: return has(id))
	var target: int = standing[standing.size()/2]
	var undo_before: int = data._undo.size()
	check(reach.pluck(target) and not has(target) and data._undo.size() == undo_before+1,"A pluck takes one clump of wheat, one undo step")
	await settle()
	editor.undo()
	await settle()
	check(has(target),"Undo puts the plucked clump back")
	# The trash can sweeps wheat away: one undo step, undo brings it back.
	materials.select_tool("trash")
	await frames(10)
	check(clay.tool_id == "trash","The trash can is in hand")
	var count := _wheat(data).size()
	undo_before = data._undo.size()
	var from := screen_of(Vector2(-1.5,3.0))
	var to := screen_of(Vector2(1.5,3.0))
	button(from,true)
	await frames(2)
	for k in range(24):
		var at := from.lerp(to,float(k+1)/24.0)
		motion(at,(to-from)/24.0)
		await frames(1)
	await frames(10)
	button(to,false)
	await frames(30)
	await settle()
	var swept := count-_wheat(data).size()
	print("scene trash sweep: %d of %d clumps taken" % [swept,count])
	check(swept > 0 and near(data,Vector2(0.0,3.0),0.8) == 0 and data._undo.size() == undo_before+1,"The trash can sweeps the wheat off its line, one undo step (%d taken)" % swept)
	editor.undo()
	await settle()
	check(_wheat(data).size() == count,"Undo brings the swept wheat back")
	materials.select_tool(Materials.FREE)
	# Saves and reopens with it.
	var reopened := NativeTerrainData.new()
	reopened.setup(data.source_mesh)
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))) and _wheat(reopened).size() == _wheat(data).size(),"The world saves and reopens with its wheat (%d clumps)" % _wheat(reopened).size())
	scene.queue_free()
	await frames(2)
